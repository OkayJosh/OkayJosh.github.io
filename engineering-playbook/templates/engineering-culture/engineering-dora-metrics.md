# Engineering KPIs & DORA Metrics

*We do not measure engineering productivity by "Lines of Code written" or "Hours worked." We measure velocity and stability using the industry-standard DORA metrics.*

## 1. Deployment Frequency (Velocity)
*   **Definition:** How often do we deploy code to production?
*   **Elite Target:** Multiple times per day (On-Demand).
*   **Why it matters:** Deploying frequently forces the team to keep changes small, reducing the risk of massive, breaking releases.

## 2. Lead Time for Changes (Velocity)
*   **Definition:** How long does it take for code to go from "Committed to Git" to "Running in Production"?
*   **Elite Target:** Less than 1 hour.
*   **Why it matters:** It measures the efficiency of our CI/CD pipelines and automated testing. If Lead Time is 3 days, our pipeline is too slow.

## 3. Change Failure Rate (Stability)
*   **Definition:** What percentage of production deployments cause an outage, rollback, or immediate hotfix?
*   **Elite Target:** 0% - 15%.
*   **Why it matters:** High velocity is useless if every deployment breaks the site. If this metric spikes, we must pause feature work and improve automated testing.

## 4. Mean Time to Restore (MTTR) (Stability)
*   **Definition:** When production goes down, how long does it take to restore service?
*   **Elite Target:** Less than 1 hour.
*   **Why it matters:** Outages are inevitable. MTTR measures how good our observability (Datadog) and rollback procedures are.

## Monthly Review
*These metrics are automatically pulled from GitHub and Jira, and they are reviewed by the Engineering Leadership team on the 1st of every month.*
