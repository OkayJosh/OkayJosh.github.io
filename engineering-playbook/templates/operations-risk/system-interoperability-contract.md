# System Interoperability Contract

*This document defines the strict agreement required before integrating our internal systems with an external third-party partner or vendor.*

**Integrating Partner:** [e.g., Bank of Nigeria - Core Banking API]
**Internal System:** [e.g., Dependly Settlement Service]
**Date:** YYYY-MM-DD

## 1. Integration Scope & Direction
*   **Direction:** [e.g., Bi-directional. We pull balances from them; they push Webhooks to us.]
*   **Environment URLs:**
    *   *UAT/Sandbox:* `https://sandbox.bank.com/api/v1`
    *   *Production:* `https://api.bank.com/v1`

## 2. Network & Security Contract
*   **Authentication:** [e.g., Mutual TLS (mTLS) required for all connections.]
*   **IP Whitelisting:** [e.g., Partner must whitelist our 3 NAT Gateway Elastic IPs.]
*   **Data Encryption:** All payloads containing account numbers must be encrypted using JWE (JSON Web Encryption).

## 3. SLA & Error Handling Contract
*   **Partner SLA Guarantee:** [e.g., 99.9% uptime. Max response time: 2 seconds.]
*   **Timeout Policy:** If the partner API does not respond within 3 seconds, our system will hard-timeout and return a `504 Gateway Timeout` to our users. We will NOT queue the request indefinitely.
*   **Retry Policy (Idempotency):** Our system will retry `5xx` errors 3 times using Exponential Backoff. We will send a unique `X-Idempotency-Key` header with every POST request to prevent double-charging.

## 4. Failure Modes & Fallbacks
*What happens when the partner goes offline?*
*   **Scenario:** The partner's Webhook server goes down.
*   **Fallback:** Our system will run a CRON job every 15 minutes to actively poll their `GET /status` endpoint to reconcile any missed events.

## 5. Decommissioning & Data Destruction
*If we terminate the relationship with this partner, what happens to the data?*
*   [e.g., We must run a script to purge all cached partner tokens from Redis.]
*   [e.g., The partner must provide a Certificate of Destruction proving they deleted our customer KYC data from their servers.]
