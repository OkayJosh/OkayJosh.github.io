# Architecture Capacity & Performance Planning Model

*Hope is not a strategy. This document forces the team to mathematically calculate when the current architecture will break based on projected business growth, allowing time to provision hardware or refactor.*

**System Component:** [e.g., Primary PostgreSQL Database]
**Date:** YYYY-MM-DD

## 1. Current State (The Baseline)
*   **Current Infrastructure:** [e.g., db.r6g.xlarge (4 vCPU, 32GB RAM)]
*   **Current Average Load:** [e.g., 500 Queries Per Second (QPS)]
*   **Current Peak Load:** [e.g., 1,200 QPS (Black Friday)]
*   **Current Resource Utilization at Peak:** [e.g., 65% CPU, 80% Memory]

## 2. Business Growth Projections
*   **Projected MoM Growth:** [e.g., 15% increase in transaction volume]
*   **Upcoming Major Events:** [e.g., Launching in Kenya in Q3, expecting a sudden 40% spike in concurrent users]

## 3. The Breaking Point Calculation
*At what point does the current architecture fail?*
*   **The Bottleneck:** Memory (Connection pooling limits).
*   **The Math:** If 1,200 QPS = 80% Memory, then 100% Memory = ~1,500 QPS.
*   **Time to Failure:** At 15% MoM growth, we will hit 1,500 QPS peak load in exactly **4.5 months**.

## 4. Remediation Plan
*How do we fix it before it breaks?*
*   **Short-Term Fix (Within 2 months):** Deploy PgBouncer to multiplex database connections. This will reduce memory overhead by 30%.
*   **Long-Term Fix (Within 6 months):** Implement Read-Replicas and split read/write traffic at the ORM level.
*   **Trigger Point:** If CPU utilization stays above 75% for more than 1 hour, immediately upgrade the instance to `db.r6g.2xlarge`.
