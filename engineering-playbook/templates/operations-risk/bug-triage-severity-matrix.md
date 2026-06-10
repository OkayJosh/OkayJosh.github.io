# Bug Triage & Severity Matrix

*Not all bugs are emergencies. This matrix dictates exactly how bugs are prioritized and how fast the engineering team must respond. Customer Support and QA must assign a Severity Level (SEV) to every bug ticket.*

## SEV-1: Critical Outage (Drop Everything)
*   **Definition:** The core product is completely unusable, or active financial/data loss is occurring.
*   **Example:** Users cannot log in. The payment gateway is returning 500 errors.
*   **Response Time:** 15 Minutes (24/7/365).
*   **Action:** PagerDuty alerts the On-Call Engineer. The CEO and CTO are notified immediately.

## SEV-2: Major Impact
*   **Definition:** A major feature is broken, but there is a painful workaround. No data loss is occurring.
*   **Example:** The automated report generation is failing, forcing users to export data manually.
*   **Response Time:** 2 Hours (During Business Hours).
*   **Action:** PagerDuty alerts the On-Call Engineer. Added to the top of the current sprint backlog.

## SEV-3: Minor Bug
*   **Definition:** A feature is broken, but it only affects a small subset of users or edge cases.
*   **Example:** The dashboard UI breaks if viewed on a rare Android browser.
*   **Response Time:** Next Sprint Planning.
*   **Action:** Placed in the standard Jira backlog. PM decides when to prioritize it.

## SEV-4: Trivial / Cosmetic
*   **Definition:** Typos, slight CSS misalignments, or feature requests disguised as bugs.
*   **Example:** The "Submit" button is the wrong shade of blue.
*   **Response Time:** When time permits.
*   **Action:** Placed at the bottom of the backlog. Often resolved during "Tech Debt" days.
