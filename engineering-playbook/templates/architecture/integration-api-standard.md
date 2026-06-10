# Integration & API Standard (III-RM)

*This document defines the strict protocols for how microservices and external partners communicate. Consistency here prevents "integration spaghetti."*

## 1. API Design Standards (REST)
*   **Base URL Structure:** `https://api.[company].com/[domain]/v[version]/[resource]`
*   **Example:** `https://api.dependly.com/ledger/v1/accounts`
*   **Verbs & Nouns:** Use HTTP methods correctly. Endpoints must be plural nouns (e.g., `POST /users`, NOT `POST /create_user`).

## 2. Standardized Error Responses
*All APIs across the company must return errors using this exact JSON structure (RFC 7807 problem details).*
```json
{
  "error_code": "INSUFFICIENT_FUNDS",
  "message": "The account does not have enough balance to complete the transfer.",
  "status_code": 400,
  "request_id": "req_8f73b92a",
  "docs_url": "https://docs.dependly.com/errors#insufficient_funds"
}
```

## 3. Authentication & Authorization
*   **External Clients:** Must use OAuth 2.0 Bearer Tokens (JWT).
*   **Internal Service-to-Service:** Must use Mutual TLS (mTLS) via the service mesh. No service should trust another service based solely on internal IP address.

## 4. Rate Limiting & Pagination
*   **Rate Limits:** Default to 100 requests per minute per IP/Token. Return `429 Too Many Requests`.
*   **Pagination:** All list endpoints must be paginated using cursor-based pagination (e.g., `?limit=50&after=cursor_xyz`), NOT offset/limit.

## 5. Event Streaming Standards (Kafka/RabbitMQ)
*   **Event Naming:** Must be past-tense verbs (e.g., `AccountCreated`, `TransferInitiated`).
*   **Payload Guarantee:** Events must be backward-compatible. Do not remove fields, only add new optional fields or create a `v2` topic.
