# IT Landscape & Portfolio Catalog

*This document is the master inventory of all active systems, databases, and third-party SaaS tools used by the company. It prevents "Shadow IT" and orphaned services.*

## 1. Core Microservices Inventory
| Service Name | Primary Language | Data Store | Owning Team | Lifecycle Status | Notes |
| :--- | :--- | :--- | :--- | :--- | :--- |
| **Identity-Service** | Go | PostgreSQL | Auth Squad | 🟢 Active | Critical path for all logins. |
| **Ledger-Service** | Java/Spring | PostgreSQL | Core Fin | 🟢 Active | Handles double-entry accounting. |
| **Legacy-PHP-API** | PHP | MySQL | None | 🔴 Deprecated | Must be decommissioned by Q4. |
| **Fraud-ML-Engine**| Python | Redis | Risk Team | 🟡 Experimental| Currently shadowing production traffic. |

## 2. Third-Party Vendor Inventory (SaaS)
| Vendor Name | Purpose | Annual Cost | Data Classification | Renewal Date |
| :--- | :--- | :--- | :--- | :--- |
| **AWS** | Core Cloud Hosting | $120k | Highly Restricted (PII) | Auto-renews |
| **Auth0** | User Authentication | $15k | Restricted | 2026-05-01 |
| **Twilio** | SMS / OTP Delivery | Variable | Public/Internal | Auto-renews |

## 3. Data Asset Inventory
| Database Name | Engine | Hosted On | RPO / RTO Target | Backups |
| :--- | :--- | :--- | :--- | :--- |
| `prod_ledger_db` | PostgreSQL 16 | Google Cloud SQL | 0 min / 15 min | Hourly (Stored in Multi-Region Bucket) |
| `cache_cluster` | Redis | Memorystore | N/A (Ephemeral) | None |
