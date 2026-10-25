function Get-LPMSReportHtml {
    <#
    .SYNOPSIS
        Builds the LeastPrivilegedMSGraph permission analysis report as one HTML page for Add-MtReportAttachment.

    .DESCRIPTION
        Fills the report template that ships with the LeastPrivilegedMSGraph module (data/base.html, the page
        Export-LPMSPermissionAnalysisReport writes) with the analysis of this run, without writing a file.

        The Maester report shows an attachment in a sandboxed frame with an origin of its own, so:
        - every value is escaped for the JavaScript string it is written into, including <, > and &, so a
          display name from the tenant cannot end the script block or add markup;
        - values are put in with String.Replace, never -replace, so a $ in a name is kept as it is;
        - localStorage, which throws in that frame, is replaced by an in-memory object before the page's
          scripts run, so the page still follows the viewer's colour scheme and its theme toggle works.

    .OUTPUTS
        System.String
    #>
    [CmdletBinding()]
    [OutputType([string])]
    param(
        # The analysed applications from Get-LPMSCachedAppData.
        [Parameter(Mandatory)] [AllowEmptyCollection()] [object[]] $Apps,

        # The title shown in the report header.
        [Parameter()] [string] $Title = 'Microsoft Graph Permission Analysis Report'
    )

    $module = (Get-Command -Module LeastPrivilegedMSGraph -Name Export-LPMSPermissionAnalysisReport).Module
    $templatePath = Join-Path -Path $module.ModuleBase -ChildPath 'data/base.html'
    if (-not (Test-Path -LiteralPath $templatePath)) {
        throw "The report template of LeastPrivilegedMSGraph $($module.Version) was not found: $templatePath"
    }

    $tenant = try {
        @(Invoke-EntraRequest -Path 'organization' -Method GET -Service 'GraphBeta')[0]
    } catch {
        [PSCustomObject]@{ id = (Get-AzContext).Tenant.Id; displayName = 'Unknown' }
    }

    $values = [ordered]@{
        '{% block app_data %}{% endblock %}'     = (@($Apps) | ConvertTo-Json -Depth 15 -Compress)
        '{% block title %}{% endblock %}'        = $Title
        '{% block tenant_id %}{% endblock %}'    = [string]$tenant.id
        '{% block tenant_name %}{% endblock %}'  = [string]$tenant.displayName
        '{% block generated_on %}{% endblock %}' = (Get-Date -Format 'yyyy-MM-dd HH:mm:ss')
    }
    if (@($Apps).Count -eq 0) {
        $values['{% block app_data %}{% endblock %}'] = '[]'
    }

    $html = Get-Content -LiteralPath $templatePath -Raw
    foreach ($placeholder in $values.Keys) {
        $html = $html.Replace($placeholder, (ConvertTo-LPMSJsStringContent -Value $values[$placeholder]))
    }

    # The <title> is markup, not a script string: HTML-encode it there.
    $html = $html.Replace("<title>$(ConvertTo-LPMSJsStringContent -Value $Title)</title>", "<title>$([System.Net.WebUtility]::HtmlEncode($Title))</title>")

    $storageShim = '<script>try{window.localStorage.getItem("theme")}catch(e){try{Object.defineProperty(window,"localStorage",{configurable:true,value:{}})}catch(e2){}}</script>'
    $headIndex = $html.IndexOf('<head>', [System.StringComparison]::OrdinalIgnoreCase)
    if ($headIndex -ge 0) {
        $html = $html.Insert($headIndex + '<head>'.Length, $storageShim)
    }

    $html
}

function ConvertTo-LPMSJsStringContent {
    <#
    .SYNOPSIS
        Escapes a value for the inside of a double-quoted JavaScript string in an HTML script block.
    #>
    [CmdletBinding()]
    [OutputType([string])]
    param(
        [Parameter(Mandatory)] [AllowEmptyString()] [AllowNull()] [string] $Value
    )

    if ($null -eq $Value) {
        return ''
    }
    $escaped = $Value.Replace('\', '\\').Replace('"', '\"').Replace("`r", '\r').Replace("`n", '\n')
    # <, > and & as \u escapes, so a value cannot end the script block; U+2028 and U+2029 for older parsers.
    foreach ($code in 0x3C, 0x3E, 0x26, 0x2028, 0x2029) {
        $escaped = $escaped.Replace([string][char]$code, ([string][char]0x5C) + 'u' + $code.ToString('x4'))
    }
    $escaped
}
