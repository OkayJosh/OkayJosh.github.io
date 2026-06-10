# Architecture Communications Plan

*A massive architectural shift (e.g., changing API versions, migrating to a new cloud) fails if nobody knows about it. This template plans the internal and external communications.*

**Initiative:** [e.g., Deprecating REST API v1 in favor of GraphQL]
**Lead Communicator:** [Name]

## 1. Internal Engineering Communication
*How do we train our own developers on the new architecture?*
*   **Town Hall Presentation:** A 45-minute live demo of the new GraphQL implementation scheduled for [Date].
*   **Documentation Hub:** The new schemas and querying rules will be published to `docs.internal.company.com` by [Date].
*   **Code Review Enforcement:** Starting on [Date], the CI/CD pipeline will automatically block any PRs that attempt to add new endpoints to the legacy REST v1 folder.

## 2. Internal Business Communication
*How do we explain this to Sales, Marketing, and Customer Success?*
*   **The "Why" Document:** A one-pager translating "GraphQL" into business value (e.g., "This will make the mobile app load 3x faster for users").
*   **CSM Briefing:** Training the Customer Success Managers on how to answer client questions about the upcoming API changes.

## 3. External Partner/Client Communication
*How do we notify external consumers without breaking their integrations?*
*   **T-Minus 6 Months:** Send the "Notice of Deprecation" email to all API consumers. Include the migration guide.
*   **T-Minus 3 Months:** Add a `Warning: Deprecated` HTTP header to all v1 API responses.
*   **T-Minus 1 Month:** Execute a "Brownout" (intentionally turn off the v1 API for 1 hour to see which partners complain, proving they haven't migrated yet).
*   **T-Zero:** Permanently shut down the v1 API and delete the legacy code.
