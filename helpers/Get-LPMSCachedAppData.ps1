function Get-LPMSCachedAppData {
    <#
    .SYNOPSIS
        Fetches and caches the full LeastPrivilegedMSGraph permission analysis pipeline result.

    .DESCRIPTION
        Runs Get-LPMSAppRoleAssignment | Get-LPMSAppActivityData | Get-LPMSAppThrottlingData |
        Get-LPMSPermissionAnalysis and caches the result so the four LPMS checks share one pipeline run.

        Maester loads the pack's helpers and tests into one private module that lasts for the PowerShell
        session, so the result is cached in its script scope, keyed by the settings and the Azure tenant,
        and reused for LPMSCacheMinutes (default 60). Set LPMSCacheMinutes to 0 to always refresh.

        This is a helper of the pack: the instance source of each Test.MP.LPMS.*.ps1 calls it.

        Configuration is resolved in priority order (first value found wins):
          1. maester-config.json GlobalSettings (read through Get-MtSetting)
          2. Environment variables (preferred for CI/CD pipelines)
          3. Built-in defaults

        GlobalSettings keys:
            LPMSLogAnalyticsWorkspaceId  - Required. Log Analytics workspace GUID.
            LPMSDaysToQuery              - Optional. Days of history to analyse. Default: 30.
            LPMSMaxActivityEntries       - Optional. Max Log Analytics rows per SP. Default: 100000.
            LPMSThrottleLimit            - Optional. Parallel workers for activity fetch. Default: 10.
            LPMSOnlyPrivilegXAndOver     - Optional. Minimum privilege level to include in results. Default: 1.
            LPMSCacheMinutes             - Optional. Minutes the pipeline result is reused. Default: 60.

        Environment variable fallbacks (CI/CD):
          LPMS_LOG_ANALYTICS_WORKSPACE_ID, LPMS_DAYS_TO_QUERY,
          LPMS_MAX_ACTIVITY_ENTRIES, LPMS_THROTTLE_LIMIT,
          LPMS_ONLY_PRIVILEGX_AND_OVER, LPMS_CACHE_MINUTES

    .OUTPUTS
        PSCustomObject with Settings and Apps. Throws when the pipeline cannot run, so Maester reports
        the family as an Error row with the message.
    #>
    [CmdletBinding()]
    [OutputType([PSCustomObject])]
    param()


    $settings = [PSCustomObject]@{
        WorkspaceId  = [string](Get-LPMSSetting -Name 'LPMSLogAnalyticsWorkspaceId' -EnvironmentVariable 'LPMS_LOG_ANALYTICS_WORKSPACE_ID' -Default $null)
        Days         = [int](Get-LPMSSetting -Name 'LPMSDaysToQuery' -EnvironmentVariable 'LPMS_DAYS_TO_QUERY' -Default 30)
        MaxEntries   = [int](Get-LPMSSetting -Name 'LPMSMaxActivityEntries' -EnvironmentVariable 'LPMS_MAX_ACTIVITY_ENTRIES' -Default 100000)
        Throttle     = [int](Get-LPMSSetting -Name 'LPMSThrottleLimit' -EnvironmentVariable 'LPMS_THROTTLE_LIMIT' -Default 10)
        PrivLevel    = [int](Get-LPMSSetting -Name 'LPMSOnlyPrivilegXAndOver' -EnvironmentVariable 'LPMS_ONLY_PRIVILEGX_AND_OVER' -Default 1)
        CacheMinutes = [int](Get-LPMSSetting -Name 'LPMSCacheMinutes' -EnvironmentVariable 'LPMS_CACHE_MINUTES' -Default 60)
    }

    if ([string]::IsNullOrEmpty($settings.WorkspaceId)) {
        throw 'The Log Analytics workspace ID is not configured. Set GlobalSettings.LPMSLogAnalyticsWorkspaceId in maester-config.json or the LPMS_LOG_ANALYTICS_WORKSPACE_ID environment variable.'
    }

    $tenantId = (Get-AzContext).Tenant.Id
    $key = '{0}|{1}|{2}|{3}|{4}' -f $tenantId, $settings.WorkspaceId, $settings.Days, $settings.MaxEntries, $settings.PrivLevel
    $cache = $script:LPMSCache
    if ($cache -and $cache.Key -eq $key -and $cache.Loaded -gt (Get-Date).AddMinutes(-$settings.CacheMinutes)) {
        return [PSCustomObject]@{ Settings = $settings; Apps = $cache.Apps }
    }

    # The LogAnalytics service was added in EntraAuth 1.8.54; maester-pack.json pins a version that has it.
    if (-not (Get-EntraService -Name 'LogAnalytics' -ErrorAction SilentlyContinue)) {
        throw "EntraAuth $((Get-Command Connect-EntraService).Module.Version) has no LogAnalytics service; it needs 1.8.54 or later. Run Restore-MtPack, or Install-MtPack again."
    }
    Connect-EntraService -Service 'LogAnalytics', 'GraphBeta' -AsAzAccount
    $apps = @(
        Get-LPMSAppRoleAssignment |
            Get-LPMSAppActivityData -WorkspaceId $settings.WorkspaceId -Days $settings.Days -MaxActivityEntries $settings.MaxEntries -ThrottleLimit $settings.Throttle |
                Get-LPMSAppThrottlingData -WorkspaceId $settings.WorkspaceId -Days $settings.Days |
                    Get-LPMSPermissionAnalysis |
                        Where-Object { $_.CurrentPermissions.PrivilegeLevel -ge $settings.PrivLevel }
    )

    $script:LPMSCache = [PSCustomObject]@{
        Key    = $key
        Loaded = Get-Date
        Apps   = $apps
    }

    [PSCustomObject]@{ Settings = $settings; Apps = $apps }
}

function Get-LPMSSetting {
    <#
    .SYNOPSIS
        Returns a pack setting from maester-config.json GlobalSettings, else an environment variable, else a default.
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)] [string] $Name,
        [Parameter(Mandatory)] [string] $EnvironmentVariable,
        [Parameter()] [AllowNull()] $Default
    )

    $value = Get-MtSetting -Name $Name
    if ([string]::IsNullOrEmpty($value)) {
        $value = [System.Environment]::GetEnvironmentVariable($EnvironmentVariable)
    }
    if ([string]::IsNullOrEmpty($value)) {
        $value = $Default
    }
    $value
}
