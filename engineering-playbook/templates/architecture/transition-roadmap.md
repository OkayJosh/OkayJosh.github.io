# Transition Architecture & Roadmap

**Initiative:** [e.g., Monolith to Microservices Migration]
**Target Completion:** [e.g., Q4 2026]

## 1. Baseline Architecture (Current State)
*Describe the system as it exists today, highlighting the pain points.*
*   [e.g., Massive Python monolith]
*   [e.g., Shared MySQL database with complex joins]
*   [e.g., Deployments take 1 hour and require downtime]

## 2. Transition Phase 1: The Strangler Fig
**Timeline:** [e.g., Months 1-2]
**Objective:** Decouple inbound traffic and extract the easiest domain.
*   **Architecture Changes:**
    *   Deploy API Gateway (Kong/Nginx) in front of the monolith.
    *   Extract the `Notification` domain into a new microservice.
*   **Value Delivered:** Immediate horizontal scalability for notifications.

## 3. Transition Phase 2: Dual-Writing & Data Extraction
**Timeline:** [e.g., Months 3-4]
**Objective:** Extract the hardest domain (e.g., Ledger) without data loss.
*   **Architecture Changes:**
    *   Monolith begins dual-writing `Ledger` data to both MySQL and the new PostgreSQL database.
    *   Read traffic remains on the monolith to verify data integrity.
*   **Value Delivered:** Safe data migration pathway established.

## 4. Transition Phase 3: Traffic Switch
**Timeline:** [e.g., Month 5]
**Objective:** Shift production read/write traffic to the new microservice.
*   **Architecture Changes:**
    *   API Gateway routes all `/ledger` endpoints to the new microservice.
    *   Monolith `Ledger` code is marked as deprecated and put behind a feature flag.
*   **Value Delivered:** Core domain is completely independent.

## 5. Target Architecture (Future State)
**Timeline:** [e.g., Month 6+]
**Objective:** Complete decommissioning of legacy systems.
*   **Architecture Changes:**
    *   Monolith repository is archived.
    *   Legacy MySQL database is dropped after final backup.
*   **Final State Delivered:** 100% containerized, decoupled architecture.
