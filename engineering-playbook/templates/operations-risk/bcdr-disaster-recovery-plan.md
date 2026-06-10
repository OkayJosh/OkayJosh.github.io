# Business Continuity & Disaster Recovery (BCDR) Plan

*This document defines the exact steps to take during a catastrophic technical failure. Do not write this during an outage; follow it blindly during an outage.*

## 1. Disaster Classification
*   **Level 1 (Major Bug):** A bad deployment breaks checkout. (Handled via standard Git Revert).
*   **Level 2 (Infrastructure Outage):** An AWS Availability Zone goes down.
*   **Level 3 (Catastrophic):** Total loss of the primary AWS Region or a Ransomware attack deleting the primary database. **This document applies to Level 3.**

## 2. Recovery Objectives
*   **RTO (Recovery Time Objective):** [e.g., The system must be back online within 2 hours of declaring a disaster.]
*   **RPO (Recovery Point Objective):** [e.g., We accept a maximum data loss of 15 minutes.]

## 3. Emergency Communication Chain
*   **Incident Commander:** [CTO Name / Phone Number]
*   **Communications Lead:** [Head of PR / Phone Number] (Responsible for updating the Statuspage and emailing users).
*   **Technical Lead:** [Lead SRE / Phone Number]

## 4. Disaster Recovery Execution Plan (The Playbook)
*Example Scenario: Primary Cloud Region (us-east-1) goes completely offline.*
1.  **Declare Disaster:** Incident Commander formally declares a Level 3 disaster in the `#war-room` Slack channel.
2.  **DNS Failover:** SRE logs into Cloudflare and manually routes traffic from `api.dependly.com` to the backup region `eu-west-1`.
3.  **Database Promotion:** DBA executes the script to promote the Read-Replica in `eu-west-1` to become the primary Master database.
4.  **Compute Provisioning:** Run `terraform apply -var="region=eu-west-1"` to spin up the Kubernetes cluster in the backup region.
5.  **Validation:** QA team runs the automated smoke tests against the new region.
6.  **All Clear:** Incident Commander updates the Statuspage to "Resolved".

## 5. Post-Disaster Requirements
*   A mandatory Post-Mortem must be conducted within 48 hours.
*   The primary region must not be failed-back to until it has proven stable for 24 hours.
