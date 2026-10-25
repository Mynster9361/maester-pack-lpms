Adds the LeastPrivilegedMSGraph permission analysis report to this Maester report.

The report is the interactive page that the LeastPrivilegedMSGraph module writes with `Export-LPMSPermissionAnalysisReport`, filled with the same analysis that MP.LPMS.1001 to MP.LPMS.1004 use. For every service principal it shows the current, optimal, excess and missing permissions, the API calls it made and its throttling, with search, filters and CSV export.

Open it with the **Least Privileged MSGraph** button below, or under **Reports** in the left menu of this report. The report holds the names and permissions of your applications, so share this Maester report as you would the analysis itself. It is left out of a report made with `Invoke-Maester -RedactUserIdentity`.

#### Remediation action

This test only adds the report; it never fails. Act on the findings of MP.LPMS.1001 to MP.LPMS.1004. To leave the report out, disable this test in `maester-config.json`:

```json
{ "TestSettings": [ { "Id": "MP.LPMS.1005", "Enabled": false } ] }
```

#### Related links

* [Export-LPMSPermissionAnalysisReport](https://mynster-it.dk/docs/modules/leastprivilegedmsgraph/commands/Export-LPMSPermissionAnalysisReport)
* [LeastPrivilegedMSGraph module](https://github.com/Mynster9361/LeastPrivilegedMSGraph)

<!--- Results --->
%TestResult%
