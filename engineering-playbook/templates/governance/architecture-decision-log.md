# Architecture Decision Log (ADL)

*This document serves as the master index of all major architectural decisions made over the lifetime of the company. It allows new hires to understand "Why we do things this way" in 10 minutes.*

| ADR # | Date | Title / Topic | Status | Primary Decision | Rationale Summary | Link to Full ADR |
| :--- | :--- | :--- | :--- | :--- | :--- | :--- |
| **001** | 2024-01-10 | Cloud Provider Selection | ✅ **Accepted** | Use Google Cloud Platform (GCP). | Better Kubernetes support (GKE) and cheaper network egress compared to AWS. | `[Link]` |
| **002** | 2024-02-15 | Primary Datastore | ✅ **Accepted** | Use PostgreSQL 16. | Strong ACID compliance required for financial ledger. JSONB support reduces need for MongoDB. | `[Link]` |
| **003** | 2024-05-20 | Inter-service Communication | ✅ **Accepted** | Use gRPC for synchronous, Kafka for asynchronous. | gRPC provides strict contracts via Protobuf. Kafka guarantees at-least-once delivery for financial events. | `[Link]` |
| **004** | 2024-08-05 | Monorepo vs Polyrepo | ❌ **Rejected** | Stay with Polyrepo. | A proposal to move to a Monorepo was rejected due to lack of dedicated internal tooling engineers to manage Bazel/Turborepo. | `[Link]` |
| **005** | 2025-01-12 | Frontend Framework | ⚠️ **Deprecated** | Use AngularJS. | *Deprecated by ADR-008.* Originally chosen due to team familiarity. | `[Link]` |
| **008** | 2025-11-30 | Frontend Framework Revision | ✅ **Accepted** | Migrate from Angular to Next.js (React). | AngularJS reached End-of-Life. Next.js provides better Server-Side Rendering (SSR) for SEO. | `[Link]` |
