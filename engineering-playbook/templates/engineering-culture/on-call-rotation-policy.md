# On-Call Rotation & Compensation Policy

*Being on-call is a massive responsibility. It must be sustainable, humane, and fairly compensated. We do not burn out our engineers.*

## 1. Rotation Structure
*   **The Cadence:** Engineers serve a 1-week rotation (Primary) followed by a 1-week rotation (Secondary/Backup).
*   **Frequency:** An engineer should not be on-call more than 1 week out of every 6 weeks. If the rotation becomes smaller than 6 people, we must hire more engineers.
*   **The Handoff:** The on-call handoff occurs every Monday at 10:00 AM via a synchronous 15-minute Zoom meeting to review active alerts and open issues.

## 2. On-Call Responsibilities
*   **Acknowledge SLA:** The Primary on-call engineer must acknowledge PagerDuty alerts within 5 minutes.
*   **No Feature Work:** While on-call, engineers are **exempt** from sprint feature work. Their sole job is monitoring system health, responding to alerts, and paying down technical debt.
*   **Escalation:** If the Primary cannot fix the issue within 15 minutes, they MUST escalate to the Secondary. If the Secondary cannot fix it, they escalate to the Engineering Manager.

## 3. Compensation & Time-Off
*   **Standby Pay:** Engineers receive a flat stipend of $X for simply carrying the pager during their 1-week rotation, regardless of whether it rings.
*   **Incident Pay:** If paged outside of normal business hours (e.g., 2:00 AM), the engineer is paid their hourly rate at 1.5x for a minimum of 2 hours, even if the fix took 5 minutes.
*   **Sleep Recovery:** If an engineer is woken up between 12:00 AM and 6:00 AM, they are strictly forbidden from working the next day. They receive a paid "Recovery Day."

## 4. Alert Fatigue Rules
*   If a specific alert fires more than 3 times in a week without a clear resolution, it must be downgraded to a non-paging Slack notification until the underlying technical debt is fixed. No engineer should suffer from repetitive, unactionable alerts.
