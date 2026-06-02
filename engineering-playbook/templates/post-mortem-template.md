# Engineering Post-Mortem Template

## Incident: [Short, descriptive title, e.g., "Database Connection Exhaustion outtage"]

**Date of Incident:** YYYY-MM-DD
**Authors:** Joshua Olatunji
**Status:** [Investigating | Resolved | Reviewing]

---

## 1. Executive Summary
*A brief, non-technical summary of what happened, the business impact, and how it was resolved. Keep it under 3 paragraphs.*

## 2. Impact Profile
*   **Duration:** [e.g., 45 minutes]
*   **User Impact:** [e.g., 15% of users experienced 502 Bad Gateway errors during checkout]
*   **Revenue Impact:** [e.g., Estimated $5,000 in delayed processing]

## 3. Root Cause
*A deeply technical explanation of exactly what broke and why. This is where you demonstrate your debugging expertise.*
*Example: A new microservice was deployed with connection pooling misconfigured (max_connections=1000 instead of 100), leading to PostgreSQL running out of available connections when a traffic spike hit at 9:00 AM.*

## 4. Timeline (The "War Story")
*A chronological log of the incident. This highlights your ability to perform under pressure.*
*   **09:00 AM:** PagerDuty alert triggered for High Latency on API Gateway.
*   **09:05 AM:** Joshua Olatunji begins investigation. Noticed high CPU on PostgreSQL via Datadog.
*   **09:12 AM:** Identified `idle in transaction` queries dominating the connection pool.
*   **09:15 AM:** Action taken: Killed long-running queries manually. Service temporarily recovered.
*   **09:22 AM:** Root cause identified in the newly deployed `PayoutService`.
*   **09:30 AM:** Hotfix merged and deployed. System fully stabilized.

## 5. Lessons Learned
*What went well? What went wrong? What did we learn about our architecture?*
*   **What went well:** Monitoring instantly caught the latency spike before complete failure.
*   **What went wrong:** We lacked automated tests to simulate connection pool exhaustion.

## 6. Action Items (Preventative Measures)
*What are the specific engineering tasks required to ensure this never happens again?*
- [ ] Implement PgBouncer for better connection multiplexing. (Ticket #1234)
- [ ] Add an alert for `idle in transaction` queries exceeding 60 seconds. (Ticket #1235)
- [ ] Update onboarding documentation regarding standard database connection limits. (Ticket #1236)
