# Architecture Exception (Dispensation) Request

*Use this form when a project team needs to intentionally violate a corporate Architecture Principle, Standard, or Building Block.*

## 1. Exception Details
*   **Project Name:** [e.g., Dependly Analytics Dashboard]
*   **Requested By:** [Name of Lead Engineer]
*   **Date Requested:** YYYY-MM-DD
*   **Rule Being Violated:** [e.g., Architecture Principle 3: "Use PostgreSQL for all relational data."]

## 2. The Exception Request
*What exactly are you asking to do instead?*
*   **Requested Architecture:** [e.g., We want to use MongoDB for the Analytics Dashboard instead of PostgreSQL.]

## 3. Business Justification
*Why is this violation necessary? (Cost, Speed, Third-Party limitation?)*
*   [e.g., The third-party analytics UI library we purchased only supports MongoDB out of the box. Building a translation layer for PostgreSQL will delay the launch by 3 months, missing our Q4 marketing window.]

## 4. Risk Assessment & Mitigation
*What risks does this exception introduce to the company, and how will you mitigate them?*
*   **Risk:** [e.g., The ops team does not know how to manage MongoDB backups.]
*   **Mitigation:** [e.g., We will use MongoDB Atlas (fully managed SaaS) so the ops team does not have to manage the infrastructure.]

## 5. Sunset Clause (Expiration Date)
*Architecture exceptions are NOT permanent. When will this technical debt be repaid?*
*   **Expiration Date:** [e.g., YYYY-MM-DD (6 months from launch)]
*   **Remediation Plan:** [e.g., By the expiration date, we will rewrite the analytics layer to support our standard PostgreSQL data warehouse.]

---
**Architecture Review Board (ARB) Decision:**
- [ ] APPROVED
- [ ] APPROVED WITH MODIFICATIONS
- [ ] REJECTED

**ARB Comments:**
[Insert reasoning from the Chief Architect]
