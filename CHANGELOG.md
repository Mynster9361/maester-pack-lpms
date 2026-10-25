# Changelog

## 1.0.0

- First release as a Maester Pack (`mynster9361.least-privileged-msgraph`, code `LPMS`).
- Tests `MP.LPMS.1001` (excess permissions), `MP.LPMS.1002` (unmatched activity), `MP.LPMS.1003` (throttling) and
  `MP.LPMS.1004` (no recorded activity), one result per service principal.
- `MP.LPMS.1005` adds the module's interactive permission analysis report to the Maester report, under Reports.
- Pins LeastPrivilegedMSGraph 3.3.0 and EntraAuth 1.8.56. EntraAuth is pinned on its own because EntraAuth.Graph
  accepts 1.8.52, which has no LogAnalytics service (added in 1.8.54).
