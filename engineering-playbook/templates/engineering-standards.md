# Engineering Standards & Style Guide

## 1. The Prime Directive
Code is read far more often than it is written. Optimize for readability, debuggability, and maintainability over cleverness.

## 2. Pull Request (PR) Standards
- **Small is Beautiful:** PRs should ideally be under 400 lines of code. Large features should be broken down into smaller, logical, independently reviewable PRs.
- **Descriptive Titles & Context:** Every PR must explain *why* the change is being made. Link to the relevant Jira ticket or RFC.
- **Self-Review First:** Before requesting a review, review your own diff. Ensure you haven't left `console.log` or debugging artifacts.

## 3. Code Review Guidelines
- **Be Kind and Pragmatic:** Do not nitpick for the sake of nitpicking. Focus on architecture, edge cases, and security. 
- **Automate the Nits:** If it can be caught by a linter (Prettier, Black, ESLint), it should be. Don't argue about spacing; let the CI pipeline enforce it.
- **Approval means Shared Ownership:** When you approve a PR, you are taking joint responsibility for that code going into production.

## 4. API Response Standards
*All REST APIs must adhere to a standard envelope response to ensure client consistency.*

**Success:**
```json
{
  "status": "success",
  "data": { ... },
  "meta": { "pagination": { ... } }
}
```

**Error:**
```json
{
  "status": "error",
  "code": "ERR_INSUFFICIENT_FUNDS",
  "message": "User does not have enough balance to complete the transaction.",
  "details": { ... }
}
```
