# Architecture Compliance Assessment (Scorecard)

*To be completed by the Architecture Team prior to the final production release. If the project scores below 100% on Critical items, the deployment is blocked.*

**Project Name:** [Project Name]
**Reviewed By:** [Architect Name]
**Date:** YYYY-MM-DD

## 1. Technology Stack Compliance
| Check | Requirement | Result (Pass/Fail) | Notes |
| :--- | :--- | :--- | :--- |
| **Critical** | Database matches the approved ADD (e.g., PostgreSQL). | [ ] | |
| **Critical** | Language/Framework matches the approved ADD. | [ ] | |
| **Major** | Uses company standard libraries for logging and tracing. | [ ] | |

## 2. Security & Data Compliance
| Check | Requirement | Result (Pass/Fail) | Notes |
| :--- | :--- | :--- | :--- |
| **Critical** | No hardcoded secrets found in the codebase. | [ ] | |
| **Critical** | All external endpoints require authentication (JWT/OAuth). | [ ] | |
| **Critical** | PII data fields are properly encrypted at rest. | [ ] | |
| **Major** | Input validation is implemented on all POST/PUT routes. | [ ] | |

## 3. Performance & Reliability Compliance
| Check | Requirement | Result (Pass/Fail) | Notes |
| :--- | :--- | :--- | :--- |
| **Critical** | Load tests prove the system can hit the target TPS. | [ ] | |
| **Critical** | Database migrations run cleanly and are rollback-tested. | [ ] | |
| **Major** | Health check endpoint (`/health`) is implemented. | [ ] | |

## 4. Documentation & Handover
| Check | Requirement | Result (Pass/Fail) | Notes |
| :--- | :--- | :--- | :--- |
| **Critical** | Swagger/OpenAPI documentation is complete and accurate. | [ ] | |
| **Major** | Runbooks and alerts have been handed over to Operations. | [ ] | |

## 5. Final Decision
*   [ ] **APPROVED FOR RELEASE**
*   [ ] **APPROVED WITH CONDITIONS** (Fix Major issues within 14 days)
*   [ ] **REJECTED - DO NOT DEPLOY**

**Reasoning:**
[Provide detailed feedback if rejected or conditionally approved.]
