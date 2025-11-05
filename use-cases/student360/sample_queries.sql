-- Sample Phoenix SQL Queries for Student 360-Degree View
-- Table: STUDENT_360
-- All queries use the single wide table design with all student data in one row

-- ============================================================
-- BASIC QUERIES
-- ============================================================

-- Query 1: Get complete student profile (all fields in one row)
SELECT * FROM "STUDENT_360" 
WHERE "rowkey" = 'STU001';

-- Query 2: Get basic student information
SELECT 
    "rowkey" as student_id,
    "personal"."first_name",
    "personal"."last_name",
    "contact"."email",
    "demographic"."grade_level",
    "demographic"."status"
FROM "STUDENT_360"
WHERE "rowkey" = 'STU001';

-- Query 3: List all students
SELECT 
    "rowkey" as student_id,
    "personal"."first_name",
    "personal"."last_name",
    "demographic"."grade_level"
FROM "STUDENT_360"
ORDER BY "rowkey";

-- ============================================================
-- ACADEMIC QUERIES
-- ============================================================

-- Query 4: Students with high GPA (3.5 or higher)
-- Note: Use TO_NUMBER() for VARCHAR to numeric conversion in Phoenix views on HBase tables
SELECT 
    "rowkey" as student_id,
    "personal"."first_name",
    "personal"."last_name",
    "demographic"."grade_level",
    "performance"."cumulative_GPA",
    "performance"."SAT_score",
    "performance"."ACT_score"
FROM "STUDENT_360"
WHERE TO_NUMBER("performance"."cumulative_GPA") >= 3.5
ORDER BY TO_NUMBER("performance"."cumulative_GPA") DESC;

-- Query 5: Students with low GPA (below 2.5)
SELECT 
    "rowkey" as student_id,
    "personal"."first_name",
    "personal"."last_name",
    "demographic"."grade_level",
    "performance"."cumulative_GPA",
    "enrollment"."current_courses"
FROM "STUDENT_360"
WHERE TO_NUMBER("performance"."cumulative_GPA") < 2.5
ORDER BY TO_NUMBER("performance"."cumulative_GPA") ASC;

-- Query 6: Students by grade level
SELECT 
    "rowkey" as student_id,
    "personal"."first_name",
    "personal"."last_name",
    "demographic"."grade_level",
    "performance"."cumulative_GPA"
FROM "STUDENT_360"
WHERE "demographic"."grade_level" = '10'
ORDER BY TO_NUMBER("performance"."cumulative_GPA") DESC;

-- Query 7: Students with specific course grades
SELECT 
    "rowkey" as student_id,
    "personal"."first_name",
    "personal"."last_name",
    "grades"."course_MATH101",
    "grades"."course_ENG101",
    "grades"."course_SCI101"
FROM "STUDENT_360"
WHERE "grades"."course_MATH101" = 'A'
   OR "grades"."course_ENG101" = 'A'
ORDER BY "rowkey";

-- Query 8: Students close to graduation (high credits)
SELECT 
    "rowkey" as student_id,
    "personal"."first_name",
    "personal"."last_name",
    "requirements"."credits_earned",
    "requirements"."credits_required",
    "requirements"."graduation_year"
FROM "STUDENT_360"
WHERE TO_NUMBER("requirements"."credits_earned") >= 100
ORDER BY TO_NUMBER("requirements"."credits_earned") DESC;

-- Query 9: Top performing students with SAT scores
SELECT 
    "rowkey" as student_id,
    "personal"."first_name",
    "personal"."last_name",
    "performance"."cumulative_GPA",
    "performance"."SAT_score",
    "performance"."ACT_score"
FROM "STUDENT_360"
WHERE "performance"."SAT_score" IS NOT NULL
  AND TO_NUMBER("performance"."SAT_score") >= 1400
ORDER BY TO_NUMBER("performance"."SAT_score") DESC;

-- ============================================================
-- ATTENDANCE QUERIES
-- ============================================================

-- Query 10: Students with perfect attendance
SELECT 
    "rowkey" as student_id,
    "personal"."first_name",
    "personal"."last_name",
    "attendance"."days_present",
    "attendance"."days_absent",
    "attendance"."attendance_rate"
FROM "STUDENT_360"
WHERE TO_NUMBER("attendance"."days_absent") = 0
ORDER BY TO_NUMBER("attendance"."days_present") DESC;

-- Query 11: Students with attendance issues
SELECT 
    "rowkey" as student_id,
    "personal"."first_name",
    "personal"."last_name",
    "attendance"."days_present",
    "attendance"."days_absent",
    "attendance"."days_tardy",
    "attendance"."attendance_rate"
FROM "STUDENT_360"
WHERE TO_NUMBER("attendance"."days_absent") > 15
   OR TO_NUMBER("attendance"."attendance_rate") < 90.0
ORDER BY TO_NUMBER("attendance"."days_absent") DESC;

-- Query 12: Students by attendance rate
SELECT 
    "rowkey" as student_id,
    "personal"."first_name",
    "personal"."last_name",
    "attendance"."attendance_rate",
    "attendance"."days_present",
    "attendance"."days_absent"
FROM "STUDENT_360"
WHERE "attendance"."attendance_rate" IS NOT NULL
ORDER BY TO_NUMBER("attendance"."attendance_rate") DESC;

-- ============================================================
-- SUPPORT SERVICES QUERIES
-- ============================================================

-- Query 13: Students needing support (low GPA or high absences)
SELECT 
    "rowkey" as student_id,
    "personal"."first_name",
    "personal"."last_name",
    "performance"."cumulative_GPA",
    "attendance"."days_absent",
    "support"."services",
    "support"."interventions"
FROM "STUDENT_360"
WHERE TO_NUMBER("performance"."cumulative_GPA") < 2.5
   OR TO_NUMBER("attendance"."days_absent") > 15
ORDER BY TO_NUMBER("performance"."cumulative_GPA") ASC;

-- Query 14: Students receiving tutoring
SELECT 
    "rowkey" as student_id,
    "personal"."first_name",
    "personal"."last_name",
    "support"."services",
    "performance"."cumulative_GPA"
FROM "STUDENT_360"
WHERE "support"."services" LIKE '%Tutoring%'
ORDER BY "rowkey";

-- Query 15: Students with special education services
SELECT 
    "rowkey" as student_id,
    "personal"."first_name",
    "personal"."last_name",
    "support"."special_education",
    "support"."services"
FROM "STUDENT_360"
WHERE "support"."special_education" = 'Yes'
ORDER BY "rowkey";

-- ============================================================
-- COUNSELING QUERIES
-- ============================================================

-- Query 16: Students with recent counseling sessions
SELECT 
    "rowkey" as student_id,
    "personal"."first_name",
    "personal"."last_name",
    "counseling"."last_session",
    "counseling"."total_sessions",
    "counseling"."concerns"
FROM "STUDENT_360"
WHERE "counseling"."last_session" IS NOT NULL
ORDER BY "counseling"."last_session" DESC;

-- Query 17: Students with multiple counseling sessions
SELECT 
    "rowkey" as student_id,
    "personal"."first_name",
    "personal"."last_name",
    "counseling"."total_sessions",
    "counseling"."concerns"
FROM "STUDENT_360"
WHERE TO_NUMBER("counseling"."total_sessions") >= 10
ORDER BY TO_NUMBER("counseling"."total_sessions") DESC;

-- ============================================================
-- FINANCIAL AID QUERIES
-- ============================================================

-- Query 18: Students receiving financial aid
SELECT 
    "rowkey" as student_id,
    "personal"."first_name",
    "personal"."last_name",
    "financial"."aid_status",
    "financial"."aid_amount",
    "financial"."payment_status"
FROM "STUDENT_360"
WHERE "financial"."aid_status" IS NOT NULL
ORDER BY TO_NUMBER("financial"."aid_amount") DESC;

-- Query 19: Students with payment issues
SELECT 
    "rowkey" as student_id,
    "personal"."first_name",
    "personal"."last_name",
    "financial"."payment_status",
    "financial"."aid_amount"
FROM "STUDENT_360"
WHERE "financial"."payment_status" != 'Current'
   AND "financial"."payment_status" IS NOT NULL
ORDER BY "rowkey";

-- Query 20: Students with scholarships
SELECT 
    "rowkey" as student_id,
    "personal"."first_name",
    "personal"."last_name",
    "financial"."aid_status",
    "financial"."aid_amount",
    "performance"."cumulative_GPA"
FROM "STUDENT_360"
WHERE "financial"."aid_status" LIKE '%Scholarship%'
ORDER BY TO_NUMBER("performance"."cumulative_GPA") DESC;

-- ============================================================
-- ACTIVITIES QUERIES
-- ============================================================

-- Query 21: Students involved in clubs
SELECT 
    "rowkey" as student_id,
    "personal"."first_name",
    "personal"."last_name",
    "activities"."clubs",
    "activities"."sports"
FROM "STUDENT_360"
WHERE "activities"."clubs" IS NOT NULL
ORDER BY "rowkey";

-- Query 22: Student athletes
SELECT 
    "rowkey" as student_id,
    "personal"."first_name",
    "personal"."last_name",
    "activities"."sports",
    "activities"."clubs",
    "performance"."cumulative_GPA"
FROM "STUDENT_360"
WHERE "activities"."sports" IS NOT NULL
ORDER BY "activities"."sports", TO_NUMBER("performance"."cumulative_GPA") DESC;

-- Query 23: Students with high volunteer hours
SELECT 
    "rowkey" as student_id,
    "personal"."first_name",
    "personal"."last_name",
    "activities"."volunteer_hours",
    "activities"."clubs"
FROM "STUDENT_360"
WHERE TO_NUMBER("activities"."volunteer_hours") >= 100
ORDER BY TO_NUMBER("activities"."volunteer_hours") DESC;

-- ============================================================
-- COMPLEX QUERIES
-- ============================================================

-- Query 24: Complete student dashboard (all key metrics)
SELECT 
    "rowkey" as student_id,
    "personal"."first_name",
    "personal"."last_name",
    "contact"."email",
    "demographic"."grade_level",
    "demographic"."status",
    "enrollment"."current_courses",
    "performance"."cumulative_GPA",
    "performance"."SAT_score",
    "attendance"."attendance_rate",
    "attendance"."days_absent",
    "support"."services",
    "financial"."aid_status",
    "activities"."clubs",
    "activities"."sports"
FROM "STUDENT_360"
WHERE "rowkey" = 'STU001';

-- Query 25: Students at risk (multiple factors)
SELECT 
    "rowkey" as student_id,
    "personal"."first_name",
    "personal"."last_name",
    "performance"."cumulative_GPA",
    "attendance"."days_absent",
    "attendance"."attendance_rate",
    "support"."services",
    "counseling"."concerns"
FROM "STUDENT_360"
WHERE (TO_NUMBER("performance"."cumulative_GPA") < 2.5
    OR TO_NUMBER("attendance"."days_absent") > 15
    OR TO_NUMBER("attendance"."attendance_rate") < 85.0)
ORDER BY TO_NUMBER("performance"."cumulative_GPA") ASC;

-- Query 26: High achieving students (GPA + activities + attendance)
SELECT 
    "rowkey" as student_id,
    "personal"."first_name",
    "personal"."last_name",
    "performance"."cumulative_GPA",
    "attendance"."attendance_rate",
    "activities"."clubs",
    "activities"."sports",
    "activities"."volunteer_hours"
FROM "STUDENT_360"
WHERE TO_NUMBER("performance"."cumulative_GPA") >= 3.5
  AND TO_NUMBER("attendance"."attendance_rate") >= 95.0
  AND "activities"."clubs" IS NOT NULL
ORDER BY TO_NUMBER("performance"."cumulative_GPA") DESC;

-- Query 27: Students by graduation year
SELECT 
    "rowkey" as student_id,
    "personal"."first_name",
    "personal"."last_name",
    "requirements"."graduation_year",
    "requirements"."credits_earned",
    "requirements"."credits_required",
    "performance"."cumulative_GPA"
FROM "STUDENT_360"
WHERE "requirements"."graduation_year" = '2026'
ORDER BY TO_NUMBER("requirements"."credits_earned") DESC;

-- Query 28: Students by enrollment date
SELECT 
    "rowkey" as student_id,
    "personal"."first_name",
    "personal"."last_name",
    "demographic"."enrollment_date",
    "demographic"."grade_level",
    "demographic"."status"
FROM "STUDENT_360"
WHERE "demographic"."enrollment_date" >= '2023-09-01'
ORDER BY "demographic"."enrollment_date" DESC;

-- Query 29: Students with specific course enrollment
SELECT 
    "rowkey" as student_id,
    "personal"."first_name",
    "personal"."last_name",
    "enrollment"."current_courses",
    "enrollment"."semester",
    "grades"."course_MATH101"
FROM "STUDENT_360"
WHERE "enrollment"."current_courses" LIKE '%MATH101%'
ORDER BY "rowkey";

-- Query 30: Students by demographic status
SELECT 
    "rowkey" as student_id,
    "personal"."first_name",
    "personal"."last_name",
    "demographic"."status",
    "demographic"."grade_level",
    "demographic"."ethnicity"
FROM "STUDENT_360"
WHERE "demographic"."status" = 'Active'
ORDER BY "demographic"."grade_level", "personal"."last_name";

-- ============================================================
-- AGGREGATION QUERIES
-- ============================================================

-- Query 31: Average GPA by grade level
SELECT 
    "demographic"."grade_level",
    COUNT(*) as student_count,
    AVG(TO_NUMBER("performance"."cumulative_GPA")) as avg_gpa,
    MIN(TO_NUMBER("performance"."cumulative_GPA")) as min_gpa,
    MAX(TO_NUMBER("performance"."cumulative_GPA")) as max_gpa
FROM "STUDENT_360"
WHERE "performance"."cumulative_GPA" IS NOT NULL
GROUP BY "demographic"."grade_level"
ORDER BY "demographic"."grade_level";

-- Query 32: Average attendance rate by grade level
SELECT 
    "demographic"."grade_level",
    COUNT(*) as student_count,
    AVG(TO_NUMBER("attendance"."attendance_rate")) as avg_attendance_rate,
    SUM(TO_NUMBER("attendance"."days_absent")) as total_absences
FROM "STUDENT_360"
WHERE "attendance"."attendance_rate" IS NOT NULL
GROUP BY "demographic"."grade_level"
ORDER BY "demographic"."grade_level";

-- Query 33: Students by support services
SELECT 
    "support"."services",
    COUNT(*) as student_count
FROM "STUDENT_360"
WHERE "support"."services" IS NOT NULL
GROUP BY "support"."services"
ORDER BY COUNT(*) DESC;

-- Query 34: Total financial aid by status
SELECT 
    "financial"."aid_status",
    COUNT(*) as student_count,
    SUM(TO_NUMBER("financial"."aid_amount")) as total_aid
FROM "STUDENT_360"
WHERE "financial"."aid_status" IS NOT NULL
GROUP BY "financial"."aid_status"
ORDER BY SUM(TO_NUMBER("financial"."aid_amount")) DESC;

-- Query 35: Students by activity participation
SELECT 
    "activities"."sports",
    COUNT(*) as student_count,
    AVG(TO_NUMBER("performance"."cumulative_GPA")) as avg_gpa
FROM "STUDENT_360"
WHERE "activities"."sports" IS NOT NULL
GROUP BY "activities"."sports"
ORDER BY COUNT(*) DESC;

-- ============================================================
-- FILTERING AND SEARCH QUERIES
-- ============================================================

-- Query 36: Search students by name
SELECT 
    "rowkey" as student_id,
    "personal"."first_name",
    "personal"."last_name",
    "contact"."email",
    "demographic"."grade_level"
FROM "STUDENT_360"
WHERE "personal"."first_name" LIKE '%John%'
   OR "personal"."last_name" LIKE '%Doe%'
ORDER BY "personal"."last_name";

-- Query 37: Students by email domain
SELECT 
    "rowkey" as student_id,
    "personal"."first_name",
    "personal"."last_name",
    "contact"."email"
FROM "STUDENT_360"
WHERE "contact"."email" LIKE '%@school.edu%'
ORDER BY "rowkey";

-- Query 38: Students in specific grade with specific GPA range
SELECT 
    "rowkey" as student_id,
    "personal"."first_name",
    "personal"."last_name",
    "demographic"."grade_level",
    "performance"."cumulative_GPA"
FROM "STUDENT_360"
WHERE "demographic"."grade_level" = '10'
  AND TO_NUMBER("performance"."cumulative_GPA") BETWEEN 3.0 AND 4.0
ORDER BY TO_NUMBER("performance"."cumulative_GPA") DESC;

-- ============================================================
-- NOTES
-- ============================================================

-- Important Notes:
-- 1. All data types are VARCHAR in HBase, use TO_NUMBER() for numeric comparisons in Phoenix views
-- 2. Use quoted identifiers for column names with column families: "personal"."first_name"
-- 3. Row key is accessed via "rowkey" column in Phoenix views
-- 4. NULL handling: Use IS NOT NULL to filter out null values
-- 5. String comparisons: Use LIKE for pattern matching
-- 6. Date comparisons: Store dates as strings (YYYY-MM-DD) and compare as strings
-- 7. Numeric comparisons: Use TO_NUMBER() for VARCHAR to numeric conversion in Phoenix views on HBase tables

