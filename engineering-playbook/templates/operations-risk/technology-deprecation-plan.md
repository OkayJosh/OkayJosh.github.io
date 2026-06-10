# Technology Deprecation & Decommissioning Plan

*Turning things off is just as important as building them. Use this plan to safely kill legacy APIs, databases, or third-party tools without breaking production.*

**Asset to Decommission:** [e.g., The legacy REST API v1]
**Target Decommission Date:** YYYY-MM-DD
**Owner:** [Name]

## 1. Asset Inventory & Dependency Mapping
*What depends on this asset?*
*   [e.g., The legacy iOS app (version < 2.0) still hardcodes calls to API v1.]
*   [e.g., A third-party partner (Bank XYZ) consumes the v1 webhook.]

## 2. The Communication Strategy
*   **T-Minus 90 Days:** Send email to all registered API users stating the exact deprecation date and a link to the v2 migration guide.
*   **T-Minus 60 Days:** Add a custom HTTP header `X-API-Warn: Deprecation pending on YYYY-MM-DD` to all v1 responses.
*   **T-Minus 30 Days:** Direct outreach by Account Managers to the top 10 clients still using v1.

## 3. The "Brownout" Test
*To flush out clients who ignore emails, we will intentionally break the system briefly.*
*   **Date of Brownout:** [e.g., Two weeks before final shutdown].
*   **Action:** The v1 API will be disabled and return `410 Gone` for exactly 2 hours (e.g., 2:00 AM to 4:00 AM EST).
*   **Monitoring:** Log every single IP address/Client ID that hits the 410 error. Reach out to them the next morning.

## 4. Final Shutdown Checklist
*The actual steps to pull the plug.*
*   [ ] Ensure database backups are taken and archived to S3.
*   [ ] Delete the DNS records (`api-v1.dependly.com`).
*   [ ] Scale Kubernetes pods down to 0.
*   [ ] Delete the source code repository or mark it as "Archived".
*   [ ] Remove the infrastructure using Terraform (`terraform destroy -target=module.legacy_api`).
*   [ ] Cancel any associated third-party vendor subscriptions.
