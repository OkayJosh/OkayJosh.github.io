# Architecture Capability & Maturity Assessment

*Before adopting a complex new architecture (like microservices or Kubernetes), you must brutally assess whether your engineering organization is mature enough to handle it.*

**Date of Assessment:** YYYY-MM-DD
**Evaluator:** [Chief Architect]

## Level 1: Initial (Ad-Hoc)
*   **Characteristics:** Hero-culture. Deployments are manual scripts run from a developer's laptop. No automated testing.
*   **Architecture Implication:** You are not ready for microservices. Focus on stabilizing the monolith.

## Level 2: Repeatable (The Foundation)
*   **Characteristics:** Basic CI/CD exists. Environments (Dev/Staging/Prod) are separated. Basic centralized logging is in place.
*   **Current State Assessment:** [e.g., We are currently here. We have GitHub Actions, but database migrations are still run manually by the DBA.]

## Level 3: Defined (Standardized)
*   **Characteristics:** Infrastructure as Code (Terraform) is mandatory. Unit and Integration tests block PRs. Data dictionaries are enforced.
*   **Architecture Implication:** You can begin safely decoupling the monolith into coarse-grained services.

## Level 4: Managed (Metrics-Driven)
*   **Characteristics:** SLOs and Error Budgets are strictly enforced. Distributed tracing (OpenTelemetry) is standard. Autoscaling is fully operational.
*   **Target State:** [e.g., We need to reach this level by Q3 to support the new event-driven architecture.]

## Level 5: Optimized (Continuous Improvement)
*   **Characteristics:** Chaos Engineering (intentionally breaking production) is practiced regularly. Self-healing infrastructure requires zero human intervention for standard failures.

---

## Action Plan to Reach Next Level
*   **Gap 1:** We lack automated database migrations.
    *   **Action:** Implement `Flyway` or `golang-migrate` in the CI pipeline by end of month.
*   **Gap 2:** We lack distributed tracing.
    *   **Action:** Purchase Datadog APM and require all new services to include the tracing SDK.
