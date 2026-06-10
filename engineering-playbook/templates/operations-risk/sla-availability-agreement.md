# System Availability & SLA Agreement

*100% uptime is mathematically impossible and financially ruinous to pursue. This document establishes the formal agreement between Engineering and the Business regarding acceptable downtime.*

**Service:** [e.g., Core Banking API]
**Service Owner:** [Name]

## 1. Service Level Indicators (SLIs)
*What exact metrics are we measuring to determine if the system is "healthy"?*
*   **Availability:** The percentage of HTTP requests that return a `200 OK` or `4xx` (Client Error). A `5xx` (Server Error) counts as downtime.
*   **Latency:** The 99th percentile (P99) response time must be less than 200ms.

## 2. Service Level Objective (SLO) & Error Budget
*The internal target for the engineering team.*
*   **Target Uptime:** **99.95%** (per rolling 30-day window).
*   **Permitted Downtime:** 21 minutes and 54 seconds per month.
*   **Error Budget Policy:** 
    *   If the system experiences 22 minutes of downtime in a month, the Error Budget is depleted.
    *   **Consequence:** ALL new feature development must halt immediately. 100% of engineering bandwidth must be redirected to reliability, bug fixes, and paying down technical debt until the rolling 30-day window recovers above 99.95%.

## 3. Service Level Agreement (SLA)
*The external contract with our paying customers. (Usually lower than the SLO to provide a safety buffer).*
*   **Contractual Uptime:** **99.9%** (per calendar month).
*   **Financial Penalties:**
    *   If uptime falls between 99.0% and 99.89%, we issue a 10% service credit.
    *   If uptime falls below 99.0%, we issue a 30% service credit.

## 4. Maintenance Windows
*   **Planned Maintenance:** Does not count against the SLA provided the customer is notified 7 days in advance.
*   **Window:** Sundays between 2:00 AM and 4:00 AM UTC.
