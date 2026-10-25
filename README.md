# Least Privileged MSGraph — Maester Pack

A [Maester Pack](https://maester.dev/docs/next/packs/) that checks every service principal in your tenant follows the **principle of least privilege**, backed by real Microsoft Graph API activity captured in Log Analytics.

| | |
| --- | --- |
| Pack ID | `mynster9361.least-privileged-msgraph` |
| Code | `LPMS` (tests `MP.LPMS.*`) |
| Uses | Azure (Log Analytics), the [LeastPrivilegedMSGraph](https://github.com/Mynster9361/Least_Privileged_MSGraph) module 3.3.0 |
| Requires | Maester 3.0 or later, PowerShell 7.4 or later |

Each check is a **family**: it gives one result row per service principal (`MP.LPMS.1001.<PrincipalId>`), so individual applications appear as separate Pass / Fail / Investigate rows in the Maester report.

---

## Tests

| ID               | Title                | Severity  | Passes when…                                                                                       |
| ---------------- | -------------------- | :-------: | -------------------------------------------------------------------------------------------------- |
| **MP.LPMS.1001** | Excess permissions   | 🟡 Medium | The SP holds only the permissions its Graph activity actually required                             |
| **MP.LPMS.1002** | Unmatched activity   |  🟢 Low   | Every observed API call could be mapped to a known Graph endpoint (permission mapping is complete) |
| **MP.LPMS.1003** | Critical throttling  |  🟢 Low   | The SP is not experiencing Warning (≥ 10 %) or Critical (≥ 25 %) throttle rates                    |
| **MP.LPMS.1004** | No recorded activity | 🟡 Medium | The SP holds permissions and also shows Graph activity in the analysis window                      |
| **MP.LPMS.1005** | Permission analysis report | ⚪ Info | Always: adds the module's interactive report to the Maester report, with a summary of the findings  |

All five need an Azure sign-in (`Service = 'Azure'`); without one they are skipped with `ServiceNotConnected`.

### The permission analysis report

MP.LPMS.1005 adds the interactive report that `Export-LPMSPermissionAnalysisReport` writes to the Maester report, filled with the same analysis as the other tests. Open **Least Privileged MSGraph** under **Reports** in the left menu of the Maester report, or from the result of MP.LPMS.1005. It shows each service principal's current, optimal, excess and missing permissions, its API calls and its throttling, with search, filters and CSV export.

The report holds your applications' names and permissions, so share the Maester report as you would the analysis. `Invoke-Maester -RedactUserIdentity` leaves it out. To leave it out always, disable MP.LPMS.1005 in `TestSettings`.

---

## Prerequisites

### 1 — Log Analytics workspace

The pack queries the **MicrosoftGraphActivityLogs** table in an Azure Monitor Log Analytics workspace.  
Enable the diagnostic setting in Entra ID:

1. **Entra admin center** → *Monitoring & health* → *Diagnostic settings* → **Add diagnostic setting**
2. Select **MicrosoftGraphActivityLogs** under *Logs*
3. Destination: **Send to Log Analytics workspace** → pick or create your workspace
4. Save — logs start flowing within a few minutes

> NOTE: it can take up to 48 hours before logs are ingested, so be patient.

See the [step-by-step setup guide](https://mynster-it.dk/2026/02/26/LeastPrivilegedMSGraphSetup).

### 2 — Permissions

The identity running Maester needs:
- **Monitoring Reader** on the workspace (or a broader role such as Reader on the resource group)
- **Application.Read.All** in Microsoft Graph — already part of a standard Maester setup

---

## Install

```powershell
Install-MtPack Mynster9361/maester-pack-lpms
```

`Install-MtPack` shows what the pack reaches and its risk before you approve it. It saves LeastPrivilegedMSGraph 3.3.0 and the modules it requires (EntraAuth, EntraAuth.Graph, MSGraphPermissions, PSFramework) at pinned versions into Maester's own pack store, so they do not touch your own module installs. The pack is recorded in `maester-config.json` and `maester-packs.lock.json`; commit both.

The scan rates the pack **Medium** because it uses a PowerShell Gallery module. If PowerShell finds your own installs of those modules first, Maester pins them as "externally managed" and shows **High**; set `"PackPolicy": { "AllowExternalEnvironments": false }` to have Maester save every module itself.

---

## Configuration

Add the settings to `GlobalSettings` in `maester-config.json` (see [maester-config.example.json](maester-config.example.json)):

```json
{
  "GlobalSettings": {
    "LPMSLogAnalyticsWorkspaceId": "xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx",
    "LPMSDaysToQuery": 30,
    "LPMSMaxActivityEntries": 100000,
    "LPMSThrottleLimit": 10,
    "LPMSOnlyPrivilegXAndOver": 1,
    "LPMSCacheMinutes": 60
  }
}
```

Only `LPMSLogAnalyticsWorkspaceId` is required. Each setting can also come from an environment variable, which is handy in pipelines; a value in `maester-config.json` wins.

| Setting                       | Environment variable              | Default  | Description                                                                                                                                                                                                                  |
| ----------------------------- | --------------------------------- | -------- | ---------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| `LPMSLogAnalyticsWorkspaceId` | `LPMS_LOG_ANALYTICS_WORKSPACE_ID` | —        | Log Analytics workspace GUID — find it in the workspace's *Overview* blade                                                                                                                                                   |
| `LPMSDaysToQuery`             | `LPMS_DAYS_TO_QUERY`              | `30`     | Days of history to analyse. More days = better coverage, slower run and more memory.                                                                                                                                         |
| `LPMSMaxActivityEntries`      | `LPMS_MAX_ACTIVITY_ENTRIES`       | `100000` | Maximum Log Analytics rows fetched per service principal. Raise this only for very active SPs.                                                                                                                               |
| `LPMSThrottleLimit`           | `LPMS_THROTTLE_LIMIT`             | `10`     | Parallel workers when fetching activity. Reduce if you hit Log Analytics rate limits.                                                                                                                                        |
| `LPMSOnlyPrivilegXAndOver`    | `LPMS_ONLY_PRIVILEGX_AND_OVER`    | `1`      | Only check permissions at this privilege level or higher, based on Microsoft's own [privilege levels](https://github.com/microsoftgraph/microsoft-graph-devx-content/blob/master/permissions/new/permissions.json) (1 to 5). |
| `LPMSCacheMinutes`            | `LPMS_CACHE_MINUTES`              | `60`     | Minutes the analysis is reused across the four checks and across runs in the same PowerShell session. `0` always refreshes.                                                                                                  |

### Severity and disabling checks

Override a severity, or disable a check, in `TestSettings`. A row can target the whole family or a single service principal:

```json
{
  "TestSettings": [
    { "Id": "MP.LPMS.1003", "Severity": "Medium" },
    { "Id": "MP.LPMS.1004.00000000-0000-0000-0000-000000000000", "Enabled": false, "Reason": "Seasonal job, reviewed" }
  ]
}
```

---

## Running the tests

Installing the pack does not add it to every run: name it with `-Pack`.

```powershell
# 1. Connect to Microsoft Graph
Connect-Maester

# 2. Sign in to Azure with the Log Analytics scope.
#    If your tenant enforces MFA for this resource, you will be prompted once per session.
Connect-AzAccount -AuthScope 'https://api.loganalytics.io'

# 3. Run only this pack
Invoke-Maester -Pack LPMS -SkipBuiltIn

# — or Maester's own tests and this pack —
Invoke-Maester -Pack LPMS
```

To run it on every run, turn it on in `maester-config.json`: `"Packs": [ { "Id": "mynster9361.least-privileged-msgraph", "Enabled": true } ]`.

> **Why the extra `Connect-AzAccount` step?**  
> LeastPrivilegedMSGraph uses the Az session to get a Log Analytics token through `Connect-EntraService -AsAzAccount`. Azure caches tokens per resource, so the Log Analytics scope must be signed in at least once per PowerShell session.

### Automated / CI-CD (service principal)

Commit `maester-config.json` and `maester-packs.lock.json`, restore the pack, and sign in as a service principal or managed identity:

```powershell
Restore-MtPack

# Service principal (certificate)
Connect-AzAccount -ServicePrincipal -ApplicationId $clientId -TenantId $tenantId -CertificatePath ./cert.pfx
Connect-MgGraph -AppId $clientId -Certificate $cert -TenantId $tenantId -NoWelcome

# — or a managed identity —
Connect-AzAccount -Identity
Connect-MgGraph -Identity -NoWelcome

Invoke-Maester -Pack LPMS -SkipGraphConnect -NonInteractive
```

---

## Files

| File                                | Purpose                                                                       |
| ----------------------------------- | ----------------------------------------------------------------------------- |
| `maester-pack.json`                 | The pack manifest: ID, code, version, what it reaches and the module it pins |
| `maester-pack.guide.json`           | Install, connect and run steps for the pack's page on the pack index         |
| `tests/suite.json`                  | The pack's suite, `LPMS.LeastPrivilegedMSGraph`                               |
| `tests/Test.MP.LPMS.100x.ps1`       | The checks 1001-1004 and the report 1005; each has an instance source (`Get-LPMS*Instance`) that lists the service principals and a test function that runs once per service principal |
| `tests/Test.MP.LPMS.100x.md`        | Description and remediation guidance shown in the Maester report             |
| `helpers/Get-LPMSCachedAppData.ps1` | Runs the LeastPrivilegedMSGraph pipeline once and caches it for all the tests |
| `helpers/Get-LPMSReportHtml.ps1`    | Fills the module's report template with the analysis for MP.LPMS.1005, escaped for the sandboxed frame it opens in |
| `maester-config.example.json`       | Example `GlobalSettings` block                                                |
| `CHANGELOG.md`                      | What changed in each version                                                  |
| `SECURITY.md`                       | How to report a security problem privately                                    |
| `.github/workflows/check-pack.yml`  | Runs `Test-MtPack` and the tests on every push and pull request                |
| `.github/workflows/bump-version.yml`, `release.yml` | Version each pull request and publish a release when it merges (see below)   |
| `.github/rulesets/main.json`        | The branch protection the release workflows expect                           |

To check the pack while you change it:

```powershell
Test-MtPack .         # the checks Install-MtPack and the index run
Invoke-MtTest -Path . # run the tests from the folder (needs the modules in Uses.Modules installed)
```

---

## Versions and releases

`Install-MtPack Mynster9361/maester-pack-lpms` installs the newest GitHub release once it is older than the 72-hour install cooldown. Releases are immutable, so the cooldown counts from when a release is published.

With the repository variable `PACK_RELEASES` set to `true`, each pull request to `main` gets the next version: [bump-version.yml](.github/workflows/bump-version.yml) raises `Version` in `maester-pack.json` and turns `## Unreleased` in [CHANGELOG.md](CHANGELOG.md) into that version. The label picks the part to raise: `release:major`, `release:minor`, `release:patch` (the default) or `release:none`. Merging publishes the release `v<Version>` with that version's changelog section ([release.yml](.github/workflows/release.yml)). Write what changed under `## Unreleased` in the pull request.

These workflows come from the [Maester demo pack](https://github.com/maester365/maester-pack-demo).
---

## Troubleshooting

### `[LogAnalytics] Failed to connect` warning  

Your Az session doesn't yet have a cached token for `https://api.loganalytics.io`.

```powershell
Connect-AzAccount -AuthScope 'https://api.loganalytics.io'
```

If this fails due to Conditional Access / MFA, either complete the MFA challenge interactively (the token is then cached for the session), or use a service principal / managed identity.

### Tests skipped with `ServiceNotConnected`

There is no Az session. Run `Connect-AzAccount` (see above) before `Invoke-Maester`.

### Tests not run with `PackUnavailable`

The pack is not installed on this computer, or its files changed since you approved them. Run `Restore-MtPack`, or `Install-MtPack` again to review the change.

### Error row `InstanceSourceFailed`: "workspace ID is not configured"

`LPMSLogAnalyticsWorkspaceId` was not found in `maester-config.json` or the `LPMS_LOG_ANALYTICS_WORKSPACE_ID` environment variable. See [Configuration](#configuration).

### Error row `InstanceSourceFailed`: other messages

The LeastPrivilegedMSGraph pipeline threw; the row's message is the error. A version conflict with modules already loaded in your session (for example another EntraAuth version) shows here too: start a new PowerShell session and run Maester first.

### Skipped row `NoInstances`

The pipeline returned no service principals for that check — for example no SP has throttling statistics, or `LPMSOnlyPrivilegXAndOver` filters them all out.

### Pipeline returns no data / all tests investigate

Check that **MicrosoftGraphActivityLogs** is enabled in Entra ID Diagnostic Settings, that data has had time to arrive (up to 48 hours after first enabling), and that the identity running the tests has **Monitoring Reader** on the workspace.

### Results look stale

The analysis is cached for `LPMSCacheMinutes` (default 60) in the PowerShell session. Set it to `0`, or start a new session, to refresh.
