# API Gateway Routing & Throttling Standard

*The API Gateway is the front door to the entire company. This document standardizes how inbound traffic is protected, filtered, and routed before it reaches internal microservices.*

## 1. Global Security Rules (Enforced at the Edge)
*All inbound traffic is subject to these rules before routing.*
*   **TLS Enforcement:** All connections must be `HTTPS` (TLS 1.3). Port 80 (`HTTP`) is strictly redirected to 443.
*   **Payload Size Limits:** 
    *   Standard JSON endpoints: Max 2MB.
    *   File Upload endpoints: Max 15MB.
*   **Geo-Blocking:** Traffic originating from OFAC-sanctioned countries is immediately dropped at the WAF level.

## 2. Rate Limiting (Throttling) Policies
*To prevent noisy neighbors and DDoS attacks, strict rate limits apply.*
*   **Unauthenticated Traffic (by IP Address):**
    *   Limit: 30 requests per minute.
    *   Excess Action: Return `429 Too Many Requests`.
*   **Authenticated Traffic (by API Token):**
    *   Limit: 300 requests per minute.
    *   Excess Action: Return `429 Too Many Requests` with a `Retry-After` header.
*   **Intensive Endpoints (e.g., `/reports/export`):**
    *   Limit: 5 requests per hour per user.

## 3. Routing & Versioning Standard
*How the gateway knows where to send the traffic.*
*   **Path-Based Routing:** 
    *   Traffic to `/api/v1/users/*` routes to the `User-Service` cluster.
    *   Traffic to `/api/v1/ledger/*` routes to the `Ledger-Service` cluster.
*   **API Versioning:** Versioning must be in the URI path (e.g., `v1`, `v2`), not in the headers.

## 4. Circuit Breaker Configuration
*If an internal microservice goes down, the gateway must protect it from being crushed by retries.*
*   **Failure Threshold:** If a microservice returns `5xx` errors for 50% of requests within a 10-second window.
*   **Action:** The circuit "opens". The Gateway immediately returns `503 Service Unavailable` for all requests to that service for 30 seconds without hitting the backend.
*   **Recovery:** After 30 seconds, allow 5% of traffic through (Half-Open). If it succeeds, close the circuit.
