# Business Architecture Scenarios

*Abstract architecture diagrams are rarely sufficient. This template forces the engineering team to walk through highly specific, real-world edge cases to prove the architecture is resilient.*

## Scenario 1: The "Happy Path"
*   **Description:** A user successfully initiates a standard transfer.
*   **Actor:** Authenticated User
*   **Trigger:** User clicks "Send Money".
*   **Architectural Flow:**
    1. Mobile App calls API Gateway via HTTPS.
    2. API Gateway validates JWT and routes to `Transfer-Service`.
    3. `Transfer-Service` commits to PostgreSQL and emits a `TransferCreated` event to Kafka.
    4. `Notification-Service` consumes the event and sends an SMS via Twilio.

## Scenario 2: The "Partial Failure" (Resilience Test)
*   **Description:** The internal Ledger database goes offline mid-transaction.
*   **Actor:** Authenticated User
*   **Trigger:** User clicks "Send Money", but PostgreSQL is down.
*   **Architectural Flow / Mitigation:**
    1. API Gateway routes to `Transfer-Service`.
    2. `Transfer-Service` attempts to connect to PostgreSQL and fails.
    3. **Resilience Mechanism:** The service catches the exception, pushes the raw payload to a Redis dead-letter queue (DLQ) for asynchronous retry, and returns a `202 Accepted (Processing Delay)` to the user instead of a `500 Internal Server Error`.

## Scenario 3: The "Malicious Actor" (Security Test)
*   **Description:** An attacker attempts a replay attack using an intercepted, valid API payload.
*   **Actor:** External Attacker
*   **Trigger:** Script rapidly fires the exact same POST request 100 times.
*   **Architectural Flow / Mitigation:**
    1. API Gateway receives the requests.
    2. **Security Mechanism:** The API Gateway checks the `Idempotency-Key` header against the Redis cache.
    3. The first request passes. The subsequent 99 requests are intercepted at the edge and returned as `409 Conflict` without ever reaching the backend microservices.
