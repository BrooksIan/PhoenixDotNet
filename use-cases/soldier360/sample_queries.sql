-- Sample Phoenix SQL Queries for Soldier 360-Degree View
-- Table: SOLDIER_360
-- All queries use the single wide table design with all Marine data in one row
-- Primary Key: EDIPI (rowkey)
-- Column Families: personal, jepes, apes, training, medical

-- ============================================================
-- BASIC QUERIES
-- ============================================================

-- Query 1: Get complete Marine profile (all fields in one row)
SELECT * FROM "SOLDIER_360" 
WHERE "rowkey" = '1003456789';

-- Query 2: Get basic Marine information
SELECT 
    "rowkey" as edipi,
    "personal"."first_name",
    "personal"."last_name",
    "personal"."rank",
    "personal"."unit",
    "personal"."mos"
FROM "SOLDIER_360"
WHERE "rowkey" = '1003456789';

-- Query 3: List all Marines
SELECT 
    "rowkey" as edipi,
    "personal"."first_name",
    "personal"."last_name",
    "personal"."rank",
    "personal"."unit"
FROM "SOLDIER_360"
ORDER BY "rowkey";

-- ============================================================
-- PERFORMANCE QUERIES (JEPES - Junior Enlisted)
-- ============================================================

-- Query 4: Marines with high PFT scores (280 or higher)
SELECT 
    "rowkey" as edipi,
    "personal"."first_name",
    "personal"."last_name",
    "personal"."rank",
    "personal"."unit",
    "jepes"."pft_score",
    "jepes"."cft_score",
    "jepes"."rifle_qual"
FROM "SOLDIER_360"
WHERE "jepes"."pft_score" IS NOT NULL
  AND TO_NUMBER("jepes"."pft_score") >= 280
ORDER BY TO_NUMBER("jepes"."pft_score") DESC;

-- Query 5: Marines with high CFT scores (290 or higher)
SELECT 
    "rowkey" as edipi,
    "personal"."first_name",
    "personal"."last_name",
    "personal"."rank",
    "personal"."unit",
    "jepes"."cft_score",
    "jepes"."pft_score"
FROM "SOLDIER_360"
WHERE "jepes"."cft_score" IS NOT NULL
  AND TO_NUMBER("jepes"."cft_score") >= 290
ORDER BY TO_NUMBER("jepes"."cft_score") DESC;

-- Query 6: Marines with Expert rifle qualification
SELECT 
    "rowkey" as edipi,
    "personal"."first_name",
    "personal"."last_name",
    "personal"."rank",
    "personal"."unit",
    "jepes"."rifle_qual",
    "jepes"."pft_score",
    "jepes"."cft_score"
FROM "SOLDIER_360"
WHERE "jepes"."rifle_qual" = 'Expert'
ORDER BY "rowkey";

-- Query 7: Marines with high JEPES scores (character, MOS, leadership)
SELECT 
    "rowkey" as edipi,
    "personal"."first_name",
    "personal"."last_name",
    "personal"."rank",
    "personal"."unit",
    "jepes"."char_score",
    "jepes"."mos_score",
    "jepes"."lead_score"
FROM "SOLDIER_360"
WHERE "jepes"."char_score" IS NOT NULL
  AND (TO_NUMBER("jepes"."char_score") >= 4.5
   OR TO_NUMBER("jepes"."mos_score") >= 4.5
   OR TO_NUMBER("jepes"."lead_score") >= 4.5)
ORDER BY TO_NUMBER("jepes"."char_score") DESC;

-- Query 8: Marines with PME incomplete
SELECT 
    "rowkey" as edipi,
    "personal"."first_name",
    "personal"."last_name",
    "personal"."rank",
    "personal"."unit",
    "jepes"."pme_complete"
FROM "SOLDIER_360"
WHERE "jepes"."pme_complete" = 'N'
ORDER BY "rowkey";

-- ============================================================
-- PERFORMANCE QUERIES (APES - Fitness Reports)
-- ============================================================

-- Query 9: Marines with high APES attribute scores (4.5 or higher)
SELECT 
    "rowkey" as edipi,
    "personal"."first_name",
    "personal"."last_name",
    "personal"."rank",
    "personal"."unit",
    "apes"."avg_attribute",
    "apes"."rs_recommend",
    "apes"."ro_recommend"
FROM "SOLDIER_360"
WHERE "apes"."avg_attribute" IS NOT NULL
  AND TO_NUMBER("apes"."avg_attribute") >= 4.5
ORDER BY TO_NUMBER("apes"."avg_attribute") DESC;

-- Query 10: Marines with "Promote Now" recommendation
SELECT 
    "rowkey" as edipi,
    "personal"."first_name",
    "personal"."last_name",
    "personal"."rank",
    "personal"."unit",
    "apes"."rs_recommend",
    "apes"."ro_recommend",
    "apes"."avg_attribute"
FROM "SOLDIER_360"
WHERE "apes"."rs_recommend" = 'Promote Now'
ORDER BY TO_NUMBER("apes"."avg_attribute") DESC;

-- Query 11: Marines with "Far Left" RO recommendation (top performers)
SELECT 
    "rowkey" as edipi,
    "personal"."first_name",
    "personal"."last_name",
    "personal"."rank",
    "personal"."unit",
    "apes"."ro_recommend",
    "apes"."avg_attribute",
    "apes"."rs_recommend"
FROM "SOLDIER_360"
WHERE "apes"."ro_recommend" = 'Far Left'
ORDER BY TO_NUMBER("apes"."avg_attribute") DESC;

-- Query 12: Marines with adverse recommendations
SELECT 
    "rowkey" as edipi,
    "personal"."first_name",
    "personal"."last_name",
    "personal"."rank",
    "personal"."unit",
    "apes"."rs_recommend",
    "apes"."ro_recommend",
    "apes"."pft_pass",
    "apes"."cft_pass",
    "apes"."ht_wt_pass"
FROM "SOLDIER_360"
WHERE "apes"."rs_recommend" = 'Do Not Promote'
   OR "apes"."ro_recommend" LIKE '%Right%'
ORDER BY "rowkey";

-- Query 13: Marines with PFT failures
SELECT 
    "rowkey" as edipi,
    "personal"."first_name",
    "personal"."last_name",
    "personal"."rank",
    "personal"."unit",
    "apes"."pft_pass",
    "apes"."cft_pass",
    "apes"."ht_wt_pass",
    "apes"."rs_recommend"
FROM "SOLDIER_360"
WHERE "apes"."pft_pass" = 'N'
   OR "apes"."cft_pass" = 'N'
   OR "apes"."ht_wt_pass" = 'N'
ORDER BY "rowkey";

-- ============================================================
-- TRAINING & READINESS QUERIES (MCTIMS)
-- ============================================================

-- Query 14: Marines ready for deployment
SELECT 
    "rowkey" as edipi,
    "personal"."first_name",
    "personal"."last_name",
    "personal"."rank",
    "personal"."unit",
    "training"."overall_ready",
    "training"."rifle_current",
    "training"."pft_current",
    "training"."cft_current",
    "training"."pme_complete",
    "training"."annual_training_pct"
FROM "SOLDIER_360"
WHERE "training"."overall_ready" = 'Y'
ORDER BY "rowkey";

-- Query 15: Marines NOT ready for deployment
SELECT 
    "rowkey" as edipi,
    "personal"."first_name",
    "personal"."last_name",
    "personal"."rank",
    "personal"."unit",
    "training"."overall_ready",
    "training"."rifle_current",
    "training"."pft_current",
    "training"."cft_current",
    "training"."pme_complete",
    "training"."annual_training_pct"
FROM "SOLDIER_360"
WHERE "training"."overall_ready" = 'N'
ORDER BY "rowkey";

-- Query 16: Marines with rifle qualification expired
SELECT 
    "rowkey" as edipi,
    "personal"."first_name",
    "personal"."last_name",
    "personal"."rank",
    "personal"."unit",
    "training"."rifle_current",
    "training"."overall_ready"
FROM "SOLDIER_360"
WHERE "training"."rifle_current" = 'N'
ORDER BY "rowkey";

-- Query 17: Marines with PFT/CFT expired
SELECT 
    "rowkey" as edipi,
    "personal"."first_name",
    "personal"."last_name",
    "personal"."rank",
    "personal"."unit",
    "training"."pft_current",
    "training"."cft_current",
    "training"."overall_ready"
FROM "SOLDIER_360"
WHERE "training"."pft_current" = 'N'
   OR "training"."cft_current" = 'N'
ORDER BY "rowkey";

-- Query 18: Marines with incomplete annual training
SELECT 
    "rowkey" as edipi,
    "personal"."first_name",
    "personal"."last_name",
    "personal"."rank",
    "personal"."unit",
    "training"."annual_training_pct",
    "training"."overall_ready"
FROM "SOLDIER_360"
WHERE "training"."annual_training_pct" IS NOT NULL
  AND TO_NUMBER("training"."annual_training_pct") < 100
ORDER BY TO_NUMBER("training"."annual_training_pct") ASC;

-- Query 19: Marines with PME incomplete (training)
SELECT 
    "rowkey" as edipi,
    "personal"."first_name",
    "personal"."last_name",
    "personal"."rank",
    "personal"."unit",
    "training"."pme_complete",
    "training"."overall_ready"
FROM "SOLDIER_360"
WHERE "training"."pme_complete" = 'N'
ORDER BY "rowkey";

-- ============================================================
-- MEDICAL READINESS QUERIES (MHS Genesis)
-- ============================================================

-- Query 20: Deployable Marines
SELECT 
    "rowkey" as edipi,
    "personal"."first_name",
    "personal"."last_name",
    "personal"."rank",
    "personal"."unit",
    "medical"."medical_status",
    "medical"."dental_class",
    "medical"."pha_current",
    "medical"."imr_status",
    "medical"."profile_status"
FROM "SOLDIER_360"
WHERE "medical"."medical_status" = 'Deployable'
ORDER BY "rowkey";

-- Query 21: Non-deployable Marines
SELECT 
    "rowkey" as edipi,
    "personal"."first_name",
    "personal"."last_name",
    "personal"."rank",
    "personal"."unit",
    "medical"."medical_status",
    "medical"."dental_class",
    "medical"."pha_current",
    "medical"."imr_status",
    "medical"."profile_status"
FROM "SOLDIER_360"
WHERE "medical"."medical_status" = 'Non-Deployable'
ORDER BY "rowkey";

-- Query 22: Marines with dental issues (Class 3 or Class 4)
SELECT 
    "rowkey" as edipi,
    "personal"."first_name",
    "personal"."last_name",
    "personal"."rank",
    "personal"."unit",
    "medical"."dental_class",
    "medical"."medical_status"
FROM "SOLDIER_360"
WHERE "medical"."dental_class" = 'Class 3'
   OR "medical"."dental_class" = 'Class 4'
ORDER BY "rowkey";

-- Query 23: Marines with PHA expired
SELECT 
    "rowkey" as edipi,
    "personal"."first_name",
    "personal"."last_name",
    "personal"."rank",
    "personal"."unit",
    "medical"."pha_current",
    "medical"."medical_status"
FROM "SOLDIER_360"
WHERE "medical"."pha_current" = 'N'
ORDER BY "rowkey";

-- Query 24: Marines with IMR due (immunizations)
SELECT 
    "rowkey" as edipi,
    "personal"."first_name",
    "personal"."last_name",
    "personal"."rank",
    "personal"."unit",
    "medical"."imr_status",
    "medical"."medical_status"
FROM "SOLDIER_360"
WHERE "medical"."imr_status" = 'Due'
ORDER BY "rowkey";

-- Query 25: Marines with profiles (temporary or permanent)
SELECT 
    "rowkey" as edipi,
    "personal"."first_name",
    "personal"."last_name",
    "personal"."rank",
    "personal"."unit",
    "medical"."profile_status",
    "medical"."medical_status"
FROM "SOLDIER_360"
WHERE "medical"."profile_status" = 'Temporary'
   OR "medical"."profile_status" = 'Permanent'
ORDER BY "medical"."profile_status", "rowkey";

-- ============================================================
-- QUERIES BY RANK
-- ============================================================

-- Query 26: Marines by rank (Sergeants)
SELECT 
    "rowkey" as edipi,
    "personal"."first_name",
    "personal"."last_name",
    "personal"."rank",
    "personal"."unit",
    "apes"."avg_attribute",
    "training"."overall_ready",
    "medical"."medical_status"
FROM "SOLDIER_360"
WHERE "personal"."rank" = 'Sgt'
ORDER BY "rowkey";

-- Query 27: Marines by rank (Corporals)
SELECT 
    "rowkey" as edipi,
    "personal"."first_name",
    "personal"."last_name",
    "personal"."rank",
    "personal"."unit",
    "jepes"."char_score",
    "training"."overall_ready",
    "medical"."medical_status"
FROM "SOLDIER_360"
WHERE "personal"."rank" = 'Cpl'
ORDER BY "rowkey";

-- Query 28: Officers (Captain and above)
SELECT 
    "rowkey" as edipi,
    "personal"."first_name",
    "personal"."last_name",
    "personal"."rank",
    "personal"."unit",
    "apes"."avg_attribute",
    "apes"."ro_recommend",
    "training"."overall_ready"
FROM "SOLDIER_360"
WHERE "personal"."rank" LIKE 'Capt%'
   OR "personal"."rank" LIKE 'Maj%'
   OR "personal"."rank" LIKE 'LtCol%'
   OR "personal"."rank" LIKE 'Col%'
ORDER BY "rowkey";

-- ============================================================
-- QUERIES BY UNIT
-- ============================================================

-- Query 29: Marines by unit (1st Bn 8th Mar)
SELECT 
    "rowkey" as edipi,
    "personal"."first_name",
    "personal"."last_name",
    "personal"."rank",
    "personal"."unit",
    "training"."overall_ready",
    "medical"."medical_status"
FROM "SOLDIER_360"
WHERE "personal"."unit" = '1st Bn 8th Mar'
ORDER BY "personal"."rank", "rowkey";

-- Query 30: Marines by unit (CLB-6)
SELECT 
    "rowkey" as edipi,
    "personal"."first_name",
    "personal"."last_name",
    "personal"."rank",
    "personal"."unit",
    "training"."overall_ready",
    "medical"."medical_status"
FROM "SOLDIER_360"
WHERE "personal"."unit" = 'CLB-6'
ORDER BY "personal"."rank", "rowkey";

-- Query 31: Marines by MOS
SELECT 
    "rowkey" as edipi,
    "personal"."first_name",
    "personal"."last_name",
    "personal"."rank",
    "personal"."unit",
    "personal"."mos",
    "training"."overall_ready"
FROM "SOLDIER_360"
WHERE "personal"."mos" = '0311'
ORDER BY "rowkey";

-- ============================================================
-- COMPLEX QUERIES
-- ============================================================

-- Query 32: Complete Marine dashboard (all key metrics)
SELECT 
    "rowkey" as edipi,
    "personal"."first_name",
    "personal"."last_name",
    "personal"."rank",
    "personal"."unit",
    "personal"."mos",
    "jepes"."pft_score",
    "jepes"."cft_score",
    "jepes"."rifle_qual",
    "apes"."avg_attribute",
    "apes"."ro_recommend",
    "training"."overall_ready",
    "training"."annual_training_pct",
    "medical"."medical_status",
    "medical"."dental_class"
FROM "SOLDIER_360"
WHERE "rowkey" = '1003456789';

-- Query 33: Marines at risk (multiple factors)
SELECT 
    "rowkey" as edipi,
    "personal"."first_name",
    "personal"."last_name",
    "personal"."rank",
    "personal"."unit",
    "training"."overall_ready",
    "training"."annual_training_pct",
    "medical"."medical_status",
    "apes"."avg_attribute",
    "jepes"."char_score"
FROM "SOLDIER_360"
WHERE ("training"."overall_ready" = 'N'
    OR "medical"."medical_status" = 'Non-Deployable'
    OR ("apes"."avg_attribute" IS NOT NULL AND TO_NUMBER("apes"."avg_attribute") < 3.5)
    OR ("jepes"."char_score" IS NOT NULL AND TO_NUMBER("jepes"."char_score") < 3.0))
ORDER BY "rowkey";

-- Query 34: High performers (training ready + medical ready + high performance)
SELECT 
    "rowkey" as edipi,
    "personal"."first_name",
    "personal"."last_name",
    "personal"."rank",
    "personal"."unit",
    "training"."overall_ready",
    "medical"."medical_status",
    "apes"."avg_attribute",
    "apes"."ro_recommend",
    "jepes"."char_score"
FROM "SOLDIER_360"
WHERE "training"."overall_ready" = 'Y'
  AND "medical"."medical_status" = 'Deployable'
  AND (("apes"."avg_attribute" IS NOT NULL AND TO_NUMBER("apes"."avg_attribute") >= 4.5)
    OR ("jepes"."char_score" IS NOT NULL AND TO_NUMBER("jepes"."char_score") >= 4.5))
ORDER BY "rowkey";

-- Query 35: Marines ready for promotion (high performers + all requirements met)
SELECT 
    "rowkey" as edipi,
    "personal"."first_name",
    "personal"."last_name",
    "personal"."rank",
    "personal"."unit",
    "apes"."rs_recommend",
    "apes"."ro_recommend",
    "apes"."avg_attribute",
    "training"."overall_ready",
    "medical"."medical_status"
FROM "SOLDIER_360"
WHERE "apes"."rs_recommend" IN ('Promote', 'Promote Now')
  AND "training"."overall_ready" = 'Y'
  AND "medical"."medical_status" = 'Deployable'
ORDER BY "apes"."ro_recommend", "rowkey";

-- ============================================================
-- AGGREGATION QUERIES
-- ============================================================

-- Query 36: Readiness status by unit
SELECT 
    "personal"."unit",
    COUNT(*) as total_marines,
    SUM(CASE WHEN "training"."overall_ready" = 'Y' THEN 1 ELSE 0 END) as ready_count,
    SUM(CASE WHEN "training"."overall_ready" = 'N' THEN 1 ELSE 0 END) as not_ready_count,
    ROUND(100.0 * SUM(CASE WHEN "training"."overall_ready" = 'Y' THEN 1 ELSE 0 END) / COUNT(*), 2) as readiness_percent
FROM "SOLDIER_360"
WHERE "personal"."unit" IS NOT NULL
GROUP BY "personal"."unit"
ORDER BY readiness_percent DESC;

-- Query 37: Medical status by unit
SELECT 
    "personal"."unit",
    COUNT(*) as total_marines,
    SUM(CASE WHEN "medical"."medical_status" = 'Deployable' THEN 1 ELSE 0 END) as deployable_count,
    SUM(CASE WHEN "medical"."medical_status" = 'Non-Deployable' THEN 1 ELSE 0 END) as non_deployable_count
FROM "SOLDIER_360"
WHERE "personal"."unit" IS NOT NULL
GROUP BY "personal"."unit"
ORDER BY "personal"."unit";

-- Query 38: Average PFT/CFT scores by rank
SELECT 
    "personal"."rank",
    COUNT(*) as marine_count,
    AVG(TO_NUMBER("jepes"."pft_score")) as avg_pft_score,
    AVG(TO_NUMBER("jepes"."cft_score")) as avg_cft_score
FROM "SOLDIER_360"
WHERE "jepes"."pft_score" IS NOT NULL
  AND "jepes"."cft_score" IS NOT NULL
GROUP BY "personal"."rank"
ORDER BY "personal"."rank";

-- Query 39: Average APES attribute score by rank
SELECT 
    "personal"."rank",
    COUNT(*) as marine_count,
    AVG(TO_NUMBER("apes"."avg_attribute")) as avg_attribute_score,
    SUM(CASE WHEN "apes"."ro_recommend" = 'Far Left' THEN 1 ELSE 0 END) as far_left_count
FROM "SOLDIER_360"
WHERE "apes"."avg_attribute" IS NOT NULL
GROUP BY "personal"."rank"
ORDER BY "personal"."rank";

-- Query 40: Average training completion by unit
SELECT 
    "personal"."unit",
    COUNT(*) as total_marines,
    AVG(TO_NUMBER("training"."annual_training_pct")) as avg_training_pct,
    MIN(TO_NUMBER("training"."annual_training_pct")) as min_training_pct,
    MAX(TO_NUMBER("training"."annual_training_pct")) as max_training_pct
FROM "SOLDIER_360"
WHERE "training"."annual_training_pct" IS NOT NULL
  AND "personal"."unit" IS NOT NULL
GROUP BY "personal"."unit"
ORDER BY avg_training_pct DESC;

-- Query 41: RO recommendation distribution
SELECT 
    "apes"."ro_recommend",
    COUNT(*) as marine_count,
    AVG(TO_NUMBER("apes"."avg_attribute")) as avg_attribute
FROM "SOLDIER_360"
WHERE "apes"."ro_recommend" IS NOT NULL
GROUP BY "apes"."ro_recommend"
ORDER BY 
    CASE "apes"."ro_recommend"
        WHEN 'Far Left' THEN 1
        WHEN 'Left of Center' THEN 2
        WHEN 'Center' THEN 3
        WHEN 'Right of Center' THEN 4
        WHEN 'Far Right' THEN 5
        ELSE 6
    END;

-- Query 42: Dental class distribution
SELECT 
    "medical"."dental_class",
    COUNT(*) as marine_count
FROM "SOLDIER_360"
WHERE "medical"."dental_class" IS NOT NULL
GROUP BY "medical"."dental_class"
ORDER BY 
    CASE "medical"."dental_class"
        WHEN 'Class 1' THEN 1
        WHEN 'Class 2' THEN 2
        WHEN 'Class 3' THEN 3
        WHEN 'Class 4' THEN 4
        ELSE 5
    END;

-- ============================================================
-- FILTERING AND SEARCH QUERIES
-- ============================================================

-- Query 43: Search Marines by name
SELECT 
    "rowkey" as edipi,
    "personal"."first_name",
    "personal"."last_name",
    "personal"."rank",
    "personal"."unit"
FROM "SOLDIER_360"
WHERE "personal"."first_name" LIKE '%Marco%'
   OR "personal"."last_name" LIKE '%Lee%'
ORDER BY "personal"."last_name";

-- Query 44: Marines by rank with specific readiness status
SELECT 
    "rowkey" as edipi,
    "personal"."first_name",
    "personal"."last_name",
    "personal"."rank",
    "personal"."unit",
    "training"."overall_ready",
    "medical"."medical_status"
FROM "SOLDIER_360"
WHERE "personal"."rank" = 'Sgt'
  AND "training"."overall_ready" = 'Y'
  AND "medical"."medical_status" = 'Deployable'
ORDER BY "rowkey";

-- Query 45: Marines with PFT score in specific range
SELECT 
    "rowkey" as edipi,
    "personal"."first_name",
    "personal"."last_name",
    "personal"."rank",
    "personal"."unit",
    "jepes"."pft_score",
    "jepes"."cft_score"
FROM "SOLDIER_360"
WHERE "jepes"."pft_score" IS NOT NULL
  AND TO_NUMBER("jepes"."pft_score") BETWEEN 270 AND 300
ORDER BY TO_NUMBER("jepes"."pft_score") DESC;

-- Query 46: Marines with specific MOS and unit
SELECT 
    "rowkey" as edipi,
    "personal"."first_name",
    "personal"."last_name",
    "personal"."rank",
    "personal"."unit",
    "personal"."mos",
    "training"."overall_ready"
FROM "SOLDIER_360"
WHERE "personal"."mos" = '0311'
  AND "personal"."unit" = '1st Bn 8th Mar'
ORDER BY "rowkey";

-- Query 47: Marines with multiple readiness issues
SELECT 
    "rowkey" as edipi,
    "personal"."first_name",
    "personal"."last_name",
    "personal"."rank",
    "personal"."unit",
    CASE WHEN "training"."rifle_current" = 'N' THEN 1 ELSE 0 END +
    CASE WHEN "training"."pft_current" = 'N' THEN 1 ELSE 0 END +
    CASE WHEN "training"."cft_current" = 'N' THEN 1 ELSE 0 END +
    CASE WHEN "training"."pme_complete" = 'N' THEN 1 ELSE 0 END +
    CASE WHEN "medical"."pha_current" = 'N' THEN 1 ELSE 0 END +
    CASE WHEN "medical"."imr_status" = 'Due' THEN 1 ELSE 0 END as issue_count,
    "training"."overall_ready",
    "medical"."medical_status"
FROM "SOLDIER_360"
WHERE "training"."overall_ready" = 'N'
   OR "medical"."medical_status" = 'Non-Deployable'
ORDER BY issue_count DESC, "rowkey";

-- ============================================================
-- NOTES
-- ============================================================

-- Important Notes:
-- 1. All data types are VARCHAR in HBase, use TO_NUMBER() for numeric comparisons in Phoenix views
-- 2. Use quoted identifiers for column names with column families: "personal"."first_name"
-- 3. Row key (EDIPI) is accessed via "rowkey" column in Phoenix views
-- 4. NULL handling: Use IS NOT NULL to filter out null values
-- 5. String comparisons: Use LIKE for pattern matching
-- 6. Numeric comparisons: Use TO_NUMBER() for VARCHAR to numeric conversion in Phoenix views on HBase tables
-- 7. JEPES data is for Junior Enlisted (E-2 through E-5), APES data is for Sergeants and Officers (E-6+)
-- 8. Some Marines will have JEPES data (NULL in APES fields), others will have APES data (NULL in JEPES fields)
-- 9. Training and Medical data should be present for all Marines
-- 10. Use CASE statements in aggregations for conditional counting

