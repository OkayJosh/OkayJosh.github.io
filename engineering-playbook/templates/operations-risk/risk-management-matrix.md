# Architecture Risk Management Matrix

*Not all risks can be fixed immediately. This matrix forces Lead Engineers to log technical debt and infrastructure risks, score them, and formally decide whether to Mitigate, Transfer, or Accept them.*

**Last Updated:** YYYY-MM-DD
**Owned By:** Chief Architect

## Risk Scoring Guide
*   **Probability:** 1 (Very Unlikely) to 5 (Almost Certain)
*   **Impact:** 1 (Negligible) to 5 (Catastrophic - Company Ending)
*   **Risk Score = Probability x Impact** (Red: 15-25, Yellow: 8-14, Green: 1-7)

## Risk Ledger

| ID | Description of Architectural Risk | Prob. | Impact | Score | Strategy | Owner | Action Plan / Mitigation |
| :--- | :--- | :--- | :--- | :--- | :--- | :--- | :--- |
| **R-01** | The primary PostgreSQL database is a single point of failure. If the primary node crashes, failover takes 30 seconds, causing dropped transactions. | 3 | 5 | **15 (🔴)** | **Mitigate** | DB Team | Implement connection pooling (PgBouncer) with automatic retry logic in the application layer by Q3. |
| **R-02** | We rely on a single SMS vendor (Twilio) for OTP delivery in Nigeria. If they experience routing issues, users cannot log in. | 4 | 4 | **16 (🔴)** | **Mitigate** | Comm Team | Integrate a fallback SMS vendor (e.g., Termii). Build logic to auto-failover if Twilio returns a 5xx error. |
| **R-03** | Our legacy PHP API uses an outdated framework version that is no longer receiving security patches. | 2 | 4 | **8 (🟡)** | **Accept** | Architect | We Accept this risk temporarily because the API is scheduled for complete decommissioning in 2 months (See Deprecation Plan). |
| **R-04** | A massive DDoS attack against our marketing site could saturate our AWS bandwidth. | 2 | 3 | **6 (🟢)** | **Transfer** | SecOps | We transfer this risk to a third party by putting the marketing site entirely behind Cloudflare's DDoS protection network. |

## Governance Rules
*   Any risk scoring **15 or higher (Red)** MUST have an active Jira Epic assigned to mitigate it. It cannot be "Accepted".
*   This matrix must be reviewed at the beginning of every quarter by the Architecture Review Board.
