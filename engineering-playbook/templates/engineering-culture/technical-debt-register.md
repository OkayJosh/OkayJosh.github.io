# Technical Debt Register

*Technical debt is inevitable, but unmanaged technical debt is fatal. This register formally tracks debt, quantifies the "interest rate", and ensures it is paid down systematically.*

## 1. Debt Logging Standards
*   **Definition:** Technical debt is code or architecture that was chosen for speed of delivery but requires refactoring later to ensure long-term stability.
*   **Rule:** All technical debt must be logged in this register AND linked to a Jira ticket.
*   **Interest Rate:** How much pain this debt causes every sprint (e.g., "Costs 2 hours of manual testing per release").

## 2. Technical Debt Ledger

| Debt ID | System Component | Description | Interest Rate (Pain) | Owner | Targeted Paydown Date | Jira Link |
| :--- | :--- | :--- | :--- | :--- | :--- | :--- |
| **TD-01** | User Service | Hardcoded the Stripe API keys in the environment variables instead of pulling from Vault. | High (Security Risk) | SecOps | End of Q2 | `[Jira-123]` |
| **TD-02** | Ledger DB | Missing foreign key constraints on the `transactions` table. Requires application-side validation. | Medium (Data Integrity Risk) | Core Team | Next Sprint | `[Jira-124]` |
| **TD-03** | iOS App | Using a deprecated version of Alamofire for network requests. | Low (No immediate impact) | Mobile Team | End of Year | `[Jira-125]` |

## 3. Paydown Policy
*   **The 20% Rule:** Every sprint, 20% of engineering story points must be dedicated exclusively to paying down items in this Technical Debt Register.
*   **Zero-Tolerance Debt:** Any debt causing active data loss or PII security vulnerabilities must be paid down immediately. All feature development stops.
