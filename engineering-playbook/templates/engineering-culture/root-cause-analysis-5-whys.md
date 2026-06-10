# Root Cause Analysis (The 5 Whys)

*When a catastrophic bug or outage occurs, human error is NEVER the root cause. We use the "5 Whys" methodology to discover the systemic or process failure that allowed the human error to occur.*

**Incident Name:** [e.g., Production Database Dropped]
**Date of Incident:** YYYY-MM-DD
**Lead Investigator:** [Name]

## 1. Incident Summary
*What happened and what was the business impact?*
*   [e.g., The production database was deleted, causing a total system outage for 45 minutes. We lost an estimated $12,000 in transaction fees.]

## 2. The 5 Whys Analysis

**Problem Statement:** The production database was dropped.
1.  **Why?** An engineer ran a destructive Terraform `destroy` script.
2.  **Why?** They thought they were connected to the `Staging` AWS account, but they were authenticated to the `Production` AWS account.
3.  **Why?** Both Staging and Production accounts look identical in the terminal, and the script did not require explicit environment confirmation.
4.  **Why?** We have not implemented strict IAM boundary separation or mandatory `prompt-to-confirm` flags in our CI/CD pipelines.
5.  **Why (Root Cause)?** The DevOps team prioritized feature velocity over implementing "Blast Radius" isolation between environments.

## 3. Systemic Root Cause
*   **Human Error is a symptom, not a cause.** The root cause is a lack of IAM isolation and automated safety checks in our IaC pipelines.

## 4. Corrective Action Plan
*What are we fixing so this physically cannot happen again?*
| Action Item | Owner | Deadline | Status |
| :--- | :--- | :--- | :--- |
| Implement mandatory MFA and explicit "Are you sure? Type PROD" prompts for all destructive Terraform scripts. | DevOps Lead | Friday | In Progress |
| Physically separate Staging and Production into completely different AWS Organizations to prevent accidental credential overlap. | Cloud Architect | End of Sprint | To Do |
