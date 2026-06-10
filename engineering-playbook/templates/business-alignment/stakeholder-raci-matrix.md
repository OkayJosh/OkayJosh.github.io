# Stakeholder Management & RACI Matrix

**Project:** [Project Name]
**Project Lead:** [Name]

*Clear accountability prevents delays and finger-pointing. Use this RACI matrix to define exactly who does what during this architectural shift.*

*   **R - Responsible:** The person doing the actual work.
*   **A - Accountable:** The ultimate decision-maker who owns the success/failure (Only 1 "A" per row).
*   **C - Consulted:** Experts whose opinions are sought before a decision is made (Two-way communication).
*   **I - Informed:** People who are kept up-to-date on progress (One-way communication).

## 1. RACI Matrix
| Project Phase / Task | CTO | Lead Architect | SecOps Lead | DevOps Lead | Product Mgr |
| :--- | :--- | :--- | :--- | :--- | :--- |
| **1. Define Business Requirements** | I | C | I | I | **R / A** |
| **2. Draft Architecture Design (ADD)** | A | **R** | C | C | I |
| **3. Threat Modeling & Security Review** | I | C | **R / A** | C | I |
| **4. Provision Cloud Infrastructure** | I | C | C | **R / A** | I |
| **5. Write Application Code** | I | A | I | I | C |
| **6. Final Production Go-Live Signoff** | **A** | R | R | R | I |

## 2. Communication Cadence
*How and when are stakeholders updated?*
*   **Weekly Async Update:** Every Friday, the Lead Architect posts a bulleted status update in the `#engineering-leadership` Slack channel.
*   **Monthly Executive Review:** A 30-minute presentation to the CEO/CTO reviewing budget burn rate and milestone progress.
*   **Go-Live War Room:** A dedicated Slack channel (`#war-room-project-x`) will be created 48 hours before launch for real-time coordination.
