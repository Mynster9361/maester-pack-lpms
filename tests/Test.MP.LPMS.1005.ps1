function Test-LPMSPermissionAnalysisReport {
    <#
    .SYNOPSIS
        Adds the LeastPrivilegedMSGraph permission analysis report to the Maester report.

    .DESCRIPTION
        Uses the same analysis as MP.LPMS.1001-1004 (Get-LPMSCachedAppData runs it once) to fill the report that
        ships with the LeastPrivilegedMSGraph module, and adds it to the Maester report with
        Add-MtReportAttachment, under Reports in its left menu and on this test's result. The result
        summarises what the analysis found.

        Returns $true once the report is added. Skipped as NotApplicable when the analysis found no service
        principals to report on.

    .LINK
        https://github.com/Mynster9361/LeastPrivilegedMSGraph
    #>
    [MaesterTest(
        Id           = 'MP.LPMS.1005',
        Title        = 'Least Privileged MSGraph permission analysis report',
        Product      = 'entra',
        Feature      = 'app-consent',
        Area         = 'applications',
        ResourceType = 'Tenant',
        Severity     = 'Info',
        Mitre        = 'None',
        Service      = 'Azure',
        Permission   = 'Application.Read.All',
        Author       = 'Mynster9361',
        HelpUrl      = 'https://mynster-it.dk/docs/modules/leastprivilegedmsgraph'
    )]
    [CmdletBinding()]
    [OutputType([bool])]
    param()

    $data = Get-LPMSCachedAppData
    $apps = @($data.Apps)
    if ($apps.Count -eq 0) {
        Add-MtTestResultDetail -SkippedBecause NotApplicable
    }

    Add-MtReportAttachment -Name 'Least Privileged MSGraph' -Content (Get-LPMSReportHtml -Apps $apps)

    $withPermissions = @($apps | Where-Object { $_.AppRoleCount -gt 0 })
    $excess = @($withPermissions | Where-Object { $_.ExcessPermissions.Count -gt 0 })
    $noActivity = @($withPermissions | Where-Object { -not ($null -ne $_.Activity -and @($_.Activity).Count -gt 0) })
    $unmatched = @($apps | Where-Object { $_.MatchedAllActivity -eq $false })
    $throttled = @($apps | Where-Object { $null -ne $_.ThrottlingStats -and $_.ThrottlingStats.ThrottlingSeverity -ge 3 })

    $resultMarkdown = "The permission analysis of the last $($data.Settings.Days) days covers **$($apps.Count)** service principal(s). Open **Least Privileged MSGraph** under **Reports** in the left menu of this report for the details of each one.`n`n"
    $resultMarkdown += "| Finding | Service principals | Test |`n"
    $resultMarkdown += "| --- | --- | --- |`n"
    $resultMarkdown += "| Hold permissions they did not use | $($excess.Count) of $($withPermissions.Count) | MP.LPMS.1001 |`n"
    $resultMarkdown += "| Made calls that could not be matched to a permission | $($unmatched.Count) | MP.LPMS.1002 |`n"
    $resultMarkdown += "| Throttled at Warning or Critical level | $($throttled.Count) | MP.LPMS.1003 |`n"
    $resultMarkdown += "| Hold permissions but made no calls | $($noActivity.Count) of $($withPermissions.Count) | MP.LPMS.1004 |`n"

    Add-MtTestResultDetail -Result $resultMarkdown
    return $true
}
