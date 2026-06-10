# Data Migration Strategy Document

**Project:** [e.g., MongoDB to PostgreSQL Migration]
**Lead Architect:** [Name]
**Target Cutover Date:** YYYY-MM-DD

## 1. Migration Scope
*   **Source Database:** [e.g., MongoDB Atlas (Cluster 1)]
*   **Target Database:** [e.g., Google Cloud SQL (PostgreSQL 16)]
*   **Data Volume:** [e.g., 500GB / 10 Million Records]
*   **Tolerable Downtime:** [e.g., Maximum 5 minutes during final cutover]

## 2. Extraction & Transformation (ETL) Plan
*How does the data get out of the old system and map to the new schema?*
*   **Tooling:** [e.g., AWS DMS, Custom Python Scripts, Debezium]
*   **Mapping Rules:** 
    *   *Source:* `users.firstName` -> *Target:* `users.first_name`
    *   *Source:* `_id` (ObjectId) -> *Target:* `id` (UUID v4)

## 3. The Dual-Write Phase (The Safe Approach)
*   **Step 1:** Modify the application to write new data to BOTH MongoDB and PostgreSQL simultaneously.
*   **Step 2:** Run the historical backfill (ETL script) to copy old data into Postgres while dual-writing handles new data.
*   **Step 3:** Route 5% of READ traffic to PostgreSQL. Compare the results against MongoDB. Log any mismatches.

## 4. Data Validation Strategy
*How do we prove the data is 100% accurate before deleting the old database?*
*   [e.g., Run a checksum script comparing the total row count and sum of all financial balances between both databases at midnight.]

## 5. Cutover & Rollback Plan
*   **Cutover Steps:**
    1. Enter Maintenance Mode (Block all writes).
    2. Wait for the final replication lag to hit 0.
    3. Flip the feature flag to point the application exclusively to PostgreSQL.
    4. Exit Maintenance Mode.
*   **Rollback Trigger:** If P99 latency spikes above 500ms or error rates exceed 1% within the first 15 minutes, instantly flip the feature flag back to MongoDB.
