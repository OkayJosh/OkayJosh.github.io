# Incident Communication Templates

*During a SEV-1 outage, you do not have time to draft eloquent emails or status updates. The Communications Lead must copy, paste, and fill in the blanks using these pre-approved templates.*

## 1. Initial Discovery (T+0 Minutes)
**Target Audience:** Public Statuspage / Twitter
**State:** We know something is wrong, but we don't know why.

> **Subject:** Investigating: Intermittent errors with [System Name]
> 
> **Message:** We are currently investigating reports of intermittent failures when attempting to [e.g., process payments/log in]. Our engineering team is actively looking into the root cause. We will provide our next update within 30 minutes.

## 2. Issue Identified (T+30 Minutes)
**Target Audience:** Public Statuspage / Priority Client Emails
**State:** We found the bug and are working on the fix.

> **Subject:** Identified: Degradation of [System Name]
> 
> **Message:** We have identified the root cause of the issue affecting [System Name]. The issue stems from [brief, non-technical explanation, e.g., a connectivity issue with a downstream partner]. Our engineers are currently deploying a mitigation strategy. We expect to have service restored shortly.

## 3. Resolution & Monitoring (T+60 Minutes)
**Target Audience:** Public Statuspage
**State:** The fix is deployed, but we are watching it carefully.

> **Subject:** Monitoring: Service restored for [System Name]
> 
> **Message:** A fix has been deployed and we are seeing [System Name] return to normal operational levels. We will continue monitoring the system closely for the next hour to ensure stability before marking this incident as fully resolved.

## 4. Internal Executive Update (For CEO/CTO only)
**Target Audience:** `#exec-updates` Slack Channel

> **Current Status:** [Investigating / Mitigating / Monitoring]
> **Business Impact:** [e.g., Checkout is down. Estimated 400 failed transactions.]
> **Root Cause (If known):** [e.g., Bad deploy at 14:00 UTC caused a memory leak.]
> **ETA to Fix:** [e.g., Rollback will be completed in 5 minutes.]
