# Security Architecture & Threat Model (STRIDE)

*Before coding a tier-1 system, the architecture must be analyzed for vulnerabilities using the STRIDE methodology.*

**System Component:** [e.g., Webhook Dispatcher]
**Evaluator:** [Name]

## 1. System Boundaries
*What data crosses a trust boundary?*
*   [e.g., The system reads financial events from internal Kafka (Trusted) and sends HTTPS POST requests to external client servers (Untrusted).]

## 2. STRIDE Threat Analysis

### Spoofing (Impersonating something or someone)
*   **Threat:** A malicious actor sends a fake webhook to a client, pretending to be Dependly, causing the client to release funds prematurely.
*   **Mitigation:** We will sign every webhook payload using HMAC-SHA256 with a client-specific secret. The signature will be included in the `X-Dependly-Signature` header.

### Tampering (Modifying data in transit or at rest)
*   **Threat:** An attacker intercepts the webhook in transit and changes the `amount` field from $10 to $10,000.
*   **Mitigation:** All webhooks must be sent over TLS 1.2+. The HMAC signature (above) will also fail if the payload is modified.

### Repudiation (Claiming you didn't do something)
*   **Threat:** A client claims they never received the "Payment Successful" webhook.
*   **Mitigation:** The Dispatcher will log the exact HTTP response code and timestamp from the client's server into a secure, immutable audit log.

### Information Disclosure (Exposing private data)
*   **Threat:** The webhook payload accidentally includes PII (e.g., the sender's full bank account number).
*   **Mitigation:** The architecture enforces a strict Data Transfer Object (DTO) mapping layer that strips all fields not explicitly marked as "Public" in the Data Dictionary.

### Denial of Service (Crashing the system)
*   **Threat:** A client's server goes down and connections hang, exhausting our server's thread pool and crashing our Dispatcher.
*   **Mitigation:** The Dispatcher will implement a strict 3-second network timeout and a Circuit Breaker pattern. If a client fails 5 times, the circuit opens and we stop sending them webhooks for 15 minutes.

### Elevation of Privilege (Gaining admin rights)
*   **Threat:** An internal developer uses the Dispatcher's database credentials to modify core ledger data.
*   **Mitigation:** The Dispatcher service is granted strictly `READ-ONLY` permissions to the necessary databases. It has no physical ability to execute `UPDATE` or `DELETE` commands.
