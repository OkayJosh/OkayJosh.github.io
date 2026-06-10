# Data Dictionary & Metadata Standard

*To prevent integration chaos, all microservices must use the exact same terminology and data types for core business concepts.*

## 1. Global Field Standards
*   **Primary Keys:** All primary keys must be UUID v4. (No auto-incrementing integers allowed).
*   **Timestamps:** All timestamps must be in UTC, formatted as ISO-8601 strings (e.g., `2024-05-20T14:30:00Z`).
*   **Currency Amounts:** All financial values must be stored and transmitted as Integers in the lowest denomination (e.g., Cents, Kobo). $10.50 is stored as `1050`.
*   **Naming Convention:** JSON payloads must use `snake_case`. Databases must use `snake_case`.

## 2. Core Business Entities

### Entity: `User`
*Represents an individual who has authenticated into the system.*
| Field Name | Data Type | Description | Classification |
| :--- | :--- | :--- | :--- |
| `id` | UUID | Unique identifier. | Public |
| `email` | String | Validated email address. | PII (Encrypted) |
| `kyc_status` | Enum | Must be: `PENDING`, `APPROVED`, `REJECTED`. | Internal |

### Entity: `Transaction`
*Represents a movement of funds between two accounts.*
| Field Name | Data Type | Description | Classification |
| :--- | :--- | :--- | :--- |
| `id` | UUID | Unique identifier. | Public |
| `amount` | Integer | The transaction amount in the lowest denomination. | Internal |
| `currency` | String | 3-letter ISO 4217 code (e.g., `USD`, `NGN`). | Public |
| `source_account_id` | UUID | Reference to the originating account. | Internal |
| `status` | Enum | Must be: `INITIATED`, `PROCESSING`, `SETTLED`, `FAILED`. | Public |

## 3. Data Classification Levels
*   **Public:** Safe to expose in URLs or public APIs (e.g., UUIDs, Status Enums).
*   **Internal:** Safe for internal microservices, but should not be exposed to end-users.
*   **PII / Restricted:** Personally Identifiable Information. Must be encrypted at rest and masked in logs (e.g., Emails, Passwords, National ID Numbers).
