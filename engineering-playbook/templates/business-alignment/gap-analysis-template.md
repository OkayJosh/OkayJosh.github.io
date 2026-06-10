# Gap Analysis Template

*This document highlights the explicit delta between your Current Architecture (Baseline) and your Future Architecture (Target). It is used by Product Managers to understand why infrastructure tasks are required on the roadmap.*

**Project:** [e.g., Transition to Event-Driven Architecture]
**Date:** YYYY-MM-DD

## 1. Capability Gap Assessment
| Capability Required | Baseline (Current State) | Target (Future State) | The Gap (What must be built/bought) |
| :--- | :--- | :--- | :--- |
| **Inter-Service Communication** | Synchronous REST API calls directly between servers. | Asynchronous, decoupled Pub/Sub messaging. | **GAP:** We need to deploy and manage a Kafka or RabbitMQ cluster. |
| **Data Persistence** | Monolithic MySQL database shared by all teams. | Database-per-service pattern. | **GAP:** We need automated database provisioning scripts in Terraform. |
| **Observability** | Greping through raw text files on individual EC2 instances. | Distributed tracing across multiple service hops. | **GAP:** We must instrument all code with OpenTelemetry and buy Datadog. |

## 2. Resource & Skill Gap Assessment
*Do we actually have the team to build the Target architecture?*
*   **Current Skills:** The team is highly proficient in Python/Django and relational modeling.
*   **Target Skills Required:** Kafka stream processing, Kubernetes administration, Go (Golang).
*   **The Gap Mitigation:** We must hire one Senior SRE and provide 2 weeks of dedicated Go training for the current backend engineers before the project begins.

## 3. Recommended Roadmap Injection
*Based on the gaps identified above, the following Epic must be added to Jira before feature development begins:*
*   **Epic:** Provision Base Infrastructure (Kafka & Terraform). Estimated effort: 3 Sprints.
