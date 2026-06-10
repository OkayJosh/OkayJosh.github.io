# Code Review (Pull Request) Standards

*Code reviews are not about finding missing semicolons—the linter does that. Code reviews are about architecture, readability, and shared ownership.*

## 1. The PR Author's Responsibilities
*   **Keep it Small:** PRs must be smaller than 400 lines of code. If it's bigger, break it into smaller PRs. Reviewer fatigue is real.
*   **Self-Review First:** You must read your own diff on GitHub before requesting a review.
*   **Provide Context:** A PR titled `fix-bug` will be rejected. You must link the Jira ticket, explain *why* the change was made, and include screenshots if the UI changed.

## 2. The Reviewer's Responsibilities
*   **Speed:** PRs should not sit unreviewed for more than 24 hours. Code rot kills velocity.
*   **Tone:** Ask questions, don't give commands. (e.g., Instead of *"Move this to a new file"*, use *"What do you think about extracting this logic into a helper file?"*).
*   **Nitpicks:** Prefix minor stylistic suggestions with `[Nit]`. The author is not required to fix nits to get an approval.

## 3. The 5-Point Review Checklist
1.  **Architecture:** Does this code belong in this service? Does it violate any of our Architecture Principles?
2.  **Security:** Are there hardcoded secrets? Is user input sanitized? Are we logging PII?
3.  **Testing:** Did the author add unit tests covering the "Unhappy Paths"?
4.  **Performance:** Are there N+1 database queries? Will this loop crash if the array has 10,000 items?
5.  **Readability:** Can a junior engineer understand this function without asking you to explain it?
