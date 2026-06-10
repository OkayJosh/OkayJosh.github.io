# IT Service Management (ITSM) Operations Handover

*Developers must complete this form before Operations / DevOps will accept responsibility for monitoring a new service in Production.*

**Service Name:** [e.g., Dependly Fraud Detection Service]
**Developer Lead:** [Name]
**Go-Live Date:** YYYY-MM-DD

## 1. Service Overview
*   **Purpose:** [e.g., Scans inbound transactions for high-risk IP addresses.]
*   **Criticality (Tier 1/2/3):** [e.g., Tier 1 - If this goes down, payments are blocked.]

## 2. Dependencies
*   **Upstream (Who calls this?):** [e.g., API Gateway, Ledger Service]
*   **Downstream (What does this call?):** [e.g., Redis Cache, MaxMind GeoIP API]

## 3. Monitoring & Alerting
*   **Healthcheck Endpoint:** `[e.g., /fraud/v1/health]`
*   **Key Metrics Dashboard:** `[Link to Datadog Dashboard]`
*   **PagerDuty Alerts Configured:**
    *   [ ] CPU > 80% for 5 mins
    *   [ ] 5xx Error Rate > 1%
    *   [ ] Kafka Consumer Lag > 10,000 messages

## 4. Runbooks & Troubleshooting (The 3 AM Guide)
*If PagerDuty goes off at 3 AM, what exactly should the On-Call Engineer do?*
*   **Scenario A:** Kafka Consumer Lag is spiking.
    *   **Action:** Scale the Kubernetes deployment using `kubectl scale deploy fraud-worker --replicas=10`.
*   **Scenario B:** MaxMind GeoIP API returns 429 Too Many Requests.
    *   **Action:** The service should automatically fail-open. Check the logs. If payments are blocking, flip the feature flag `FF_REQUIRE_FRAUD_CHECK` to `false` in LaunchDarkly.

## 5. Operations Sign-Off
*   [ ] **Accepted by Operations Lead:** [Name]
