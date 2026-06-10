# Cloud Exit Strategy (Vendor Lock-In Mitigation)

*Enterprise clients and regulators often require proof that the company can survive if its primary cloud provider (e.g., AWS, GCP) terminates the account or raises prices astronomically. This plan outlines the escape hatch.*

**Primary Provider:** [e.g., Google Cloud Platform (GCP)]
**Target Secondary Provider:** [e.g., Amazon Web Services (AWS)]

## 1. Vendor Lock-In Assessment
*Which proprietary cloud services are we currently using that DO NOT exist on other clouds?*
| Proprietary Service | Usage Level | Migration Difficulty (1-5) | Open Source Alternative |
| :--- | :--- | :--- | :--- |
| Google Cloud Spanner | Heavy | 5 (Hard) | CockroachDB |
| Google Cloud Pub/Sub | Medium | 3 (Moderate) | Apache Kafka |
| Google Cloud Storage | Heavy | 1 (Easy) | AWS S3 / MinIO |

## 2. Mitigation Principles
*How do we build the architecture today to make leaving easier tomorrow?*
*   **Principle 1 (Compute):** All applications MUST be containerized (Docker) and orchestrated via Kubernetes. We will not use proprietary serverless functions (e.g., AWS Lambda, Google Cloud Functions) for core business logic.
*   **Principle 2 (Infrastructure as Code):** All infrastructure must be provisioned using Terraform. Manual console clicking is prohibited.
*   **Principle 3 (Database Abstraction):** Applications must interact with databases via standard drivers (e.g., JDBC, standard SQL) avoiding proprietary cloud-specific query languages.

## 3. The Emergency Migration Execution Plan
*If we are given 30 days to leave our primary cloud provider, what are the steps?*
1.  **Data Extraction:** Export all PostgreSQL databases using `pg_dump` and transfer backups to the new cloud provider's object storage.
2.  **Infrastructure Provisioning:** Run the Terraform scripts against the secondary cloud provider (changing the provider variables from `gcp` to `aws`).
3.  **Code Migration:** Update the CI/CD pipelines to build and push Docker images to the new cloud's container registry (e.g., ECR).
4.  **DNS Cutover:** Update Cloudflare DNS to point all traffic to the new Kubernetes Ingress controllers.

## 4. Estimated Time & Cost to Exit
*   **Estimated Engineering Effort:** [e.g., 3 SREs for 4 weeks]
*   **Estimated Financial Cost:** [e.g., $15,000 in data egress fees from GCP to AWS]
