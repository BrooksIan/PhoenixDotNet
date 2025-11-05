# 360-Degree Student View - HBase Table Design

## Overview

> **⚠️ Note**: This document describes the **3-table design approach** for reference. The **final implementation** uses a **single wide table design** (STUDENT_360) which provides better performance and simpler queries. See [use-cases/student360/README.md](README.md) for the implemented single-table design.

This design provides a comprehensive 360-degree view of a student using **3 native HBase tables**, all linked by **Student ID** as the unique identifier (row key). This is an **alternative design** to the single-table approach that requires JOINs for a complete 360-degree view.

## Design Principles

1. **Student ID as Row Key**: All tables use student ID as the row key for fast lookups
2. **Column Families**: Logical grouping of related data within each table
3. **Phoenix Views**: Create views for each table to enable SQL queries
4. **Uppercase Names**: All table and view names must be UPPERCASE (Phoenix requirement)

## Table Structure

### Table 1: STUDENT_DEMOGRAPHICS
**Purpose**: Personal and demographic information

**Row Key**: Student ID (e.g., "STU001", "12345")

**Column Families**:
- `personal`: Basic personal information
- `contact`: Contact information
- `demographic`: Demographic and enrollment data

**Example Data**:
```
Row Key: STU001
  personal:first_name = "John"
  personal:last_name = "Doe"
  personal:middle_name = "Michael"
  personal:date_of_birth = "2005-03-15"
  personal:gender = "M"
  contact:email = "john.doe@school.edu"
  contact:phone = "555-1234"
  contact:address_line1 = "123 Main St"
  contact:city = "Springfield"
  contact:state = "IL"
  contact:zip = "62701"
  demographic:enrollment_date = "2023-09-01"
  demographic:grade_level = "10"
  demographic:status = "Active"
  demographic:ethnicity = "Hispanic"
```

### Table 2: STUDENT_ACADEMICS
**Purpose**: Academic records, grades, courses, GPA

**Row Key**: Student ID (e.g., "STU001", "12345")

**Column Families**:
- `enrollment`: Current course enrollments
- `grades`: Historical grades and transcripts
- `performance`: GPA, test scores, achievements
- `requirements`: Graduation requirements progress

**Example Data**:
```
Row Key: STU001
  enrollment:current_courses = "MATH101,ENG101,SCI101"
  enrollment:semester = "Fall2024"
  enrollment:credits_attempted = "15"
  enrollment:credits_completed = "12"
  grades:course_MATH101 = "A"
  grades:course_ENG101 = "B+"
  grades:course_SCI101 = "A-"
  grades:semester_Fall2024_GPA = "3.67"
  performance:cumulative_GPA = "3.75"
  performance:SAT_score = "1450"
  performance:ACT_score = "32"
  requirements:credits_earned = "45"
  requirements:credits_required = "120"
  requirements:graduation_year = "2026"
```

### Table 3: STUDENT_SERVICES
**Purpose**: Support services, attendance, counseling, financial aid

**Row Key**: Student ID (e.g., "STU001", "12345")

**Column Families**:
- `attendance`: Attendance records and statistics
- `support`: Support services and interventions
- `counseling`: Counseling sessions and notes
- `financial`: Financial aid and payment information
- `activities`: Extracurricular activities and clubs

**Example Data**:
```
Row Key: STU001
  attendance:days_present = "165"
  attendance:days_absent = "5"
  attendance:days_tardy = "3"
  attendance:attendance_rate = "97.1"
  support:services = "Tutoring,ESL Support"
  support:interventions = "Math Intervention Program"
  support:special_education = "No"
  counseling:last_session = "2024-10-15"
  counseling:total_sessions = "12"
  counseling:concerns = "College Planning"
  financial:aid_status = "Pell Grant,Work Study"
  financial:aid_amount = "8500"
  financial:payment_status = "Current"
  activities:clubs = "Debate,Math Club"
  activities:sports = "Soccer"
  activities:volunteer_hours = "45"
```

## Implementation Steps

### Step 1: Create HBase Tables

```bash
# Table 1: Student Demographics
docker exec -i opdb-docker /opt/hbase/bin/hbase shell <<'EOF'
create 'STUDENT_DEMOGRAPHICS', 'personal', 'contact', 'demographic'
EOF

# Table 2: Student Academics
docker exec -i opdb-docker /opt/hbase/bin/hbase shell <<'EOF'
create 'STUDENT_ACADEMICS', 'enrollment', 'grades', 'performance', 'requirements'
EOF

# Table 3: Student Services
docker exec -i opdb-docker /opt/hbase/bin/hbase shell <<'EOF'
create 'STUDENT_SERVICES', 'attendance', 'support', 'counseling', 'financial', 'activities'
EOF
```

### Step 2: Insert Sample Data

```bash
# Student Demographics Example
docker exec -i opdb-docker /opt/hbase/bin/hbase shell <<'EOF'
put 'STUDENT_DEMOGRAPHICS', 'STU001', 'personal:first_name', 'John'
put 'STUDENT_DEMOGRAPHICS', 'STU001', 'personal:last_name', 'Doe'
put 'STUDENT_DEMOGRAPHICS', 'STU001', 'personal:date_of_birth', '2005-03-15'
put 'STUDENT_DEMOGRAPHICS', 'STU001', 'contact:email', 'john.doe@school.edu'
put 'STUDENT_DEMOGRAPHICS', 'STU001', 'contact:phone', '555-1234'
put 'STUDENT_DEMOGRAPHICS', 'STU001', 'demographic:enrollment_date', '2023-09-01'
put 'STUDENT_DEMOGRAPHICS', 'STU001', 'demographic:grade_level', '10'
put 'STUDENT_DEMOGRAPHICS', 'STU001', 'demographic:status', 'Active'
EOF

# Student Academics Example
docker exec -i opdb-docker /opt/hbase/bin/hbase shell <<'EOF'
put 'STUDENT_ACADEMICS', 'STU001', 'enrollment:current_courses', 'MATH101,ENG101,SCI101'
put 'STUDENT_ACADEMICS', 'STU001', 'enrollment:semester', 'Fall2024'
put 'STUDENT_ACADEMICS', 'STU001', 'grades:course_MATH101', 'A'
put 'STUDENT_ACADEMICS', 'STU001', 'grades:course_ENG101', 'B+'
put 'STUDENT_ACADEMICS', 'STU001', 'performance:cumulative_GPA', '3.75'
put 'STUDENT_ACADEMICS', 'STU001', 'performance:SAT_score', '1450'
EOF

# Student Services Example
docker exec -i opdb-docker /opt/hbase/bin/hbase shell <<'EOF'
put 'STUDENT_SERVICES', 'STU001', 'attendance:days_present', '165'
put 'STUDENT_SERVICES', 'STU001', 'attendance:days_absent', '5'
put 'STUDENT_SERVICES', 'STU001', 'attendance:attendance_rate', '97.1'
put 'STUDENT_SERVICES', 'STU001', 'support:services', 'Tutoring,ESL Support'
put 'STUDENT_SERVICES', 'STU001', 'counseling:last_session', '2024-10-15'
put 'STUDENT_SERVICES', 'STU001', 'financial:aid_status', 'Pell Grant,Work Study'
EOF
```

### Step 3: Create Phoenix Views

**⚠️ CRITICAL**: View names must be UPPERCASE and match table names exactly.

```bash
API_URL="http://localhost:8099/api/phoenix"

# View 1: Student Demographics
curl -X POST "${API_URL}/execute" \
  -H "Content-Type: application/json" \
  -d '{
    "sql": "CREATE VIEW IF NOT EXISTS \"STUDENT_DEMOGRAPHICS\" (
      \"rowkey\" VARCHAR PRIMARY KEY,
      \"personal\".\"first_name\" VARCHAR,
      \"personal\".\"last_name\" VARCHAR,
      \"personal\".\"middle_name\" VARCHAR,
      \"personal\".\"date_of_birth\" VARCHAR,
      \"personal\".\"gender\" VARCHAR,
      \"contact\".\"email\" VARCHAR,
      \"contact\".\"phone\" VARCHAR,
      \"contact\".\"address_line1\" VARCHAR,
      \"contact\".\"city\" VARCHAR,
      \"contact\".\"state\" VARCHAR,
      \"contact\".\"zip\" VARCHAR,
      \"demographic\".\"enrollment_date\" VARCHAR,
      \"demographic\".\"grade_level\" VARCHAR,
      \"demographic\".\"status\" VARCHAR,
      \"demographic\".\"ethnicity\" VARCHAR
    )"
  }'

# View 2: Student Academics
curl -X POST "${API_URL}/execute" \
  -H "Content-Type: application/json" \
  -d '{
    "sql": "CREATE VIEW IF NOT EXISTS \"STUDENT_ACADEMICS\" (
      \"rowkey\" VARCHAR PRIMARY KEY,
      \"enrollment\".\"current_courses\" VARCHAR,
      \"enrollment\".\"semester\" VARCHAR,
      \"enrollment\".\"credits_attempted\" VARCHAR,
      \"enrollment\".\"credits_completed\" VARCHAR,
      \"grades\".\"course_MATH101\" VARCHAR,
      \"grades\".\"course_ENG101\" VARCHAR,
      \"grades\".\"course_SCI101\" VARCHAR,
      \"grades\".\"semester_Fall2024_GPA\" VARCHAR,
      \"performance\".\"cumulative_GPA\" VARCHAR,
      \"performance\".\"SAT_score\" VARCHAR,
      \"performance\".\"ACT_score\" VARCHAR,
      \"requirements\".\"credits_earned\" VARCHAR,
      \"requirements\".\"credits_required\" VARCHAR,
      \"requirements\".\"graduation_year\" VARCHAR
    )"
  }'

# View 3: Student Services
curl -X POST "${API_URL}/execute" \
  -H "Content-Type: application/json" \
  -d '{
    "sql": "CREATE VIEW IF NOT EXISTS \"STUDENT_SERVICES\" (
      \"rowkey\" VARCHAR PRIMARY KEY,
      \"attendance\".\"days_present\" VARCHAR,
      \"attendance\".\"days_absent\" VARCHAR,
      \"attendance\".\"days_tardy\" VARCHAR,
      \"attendance\".\"attendance_rate\" VARCHAR,
      \"support\".\"services\" VARCHAR,
      \"support\".\"interventions\" VARCHAR,
      \"support\".\"special_education\" VARCHAR,
      \"counseling\".\"last_session\" VARCHAR,
      \"counseling\".\"total_sessions\" VARCHAR,
      \"counseling\".\"concerns\" VARCHAR,
      \"financial\".\"aid_status\" VARCHAR,
      \"financial\".\"aid_amount\" VARCHAR,
      \"financial\".\"payment_status\" VARCHAR,
      \"activities\".\"clubs\" VARCHAR,
      \"activities\".\"sports\" VARCHAR,
      \"activities\".\"volunteer_hours\" VARCHAR
    )"
  }'
```

## Querying the 360-Degree View

### Query 1: Get All Student Information (JOIN across views)

```sql
-- Get complete student profile
SELECT 
    d."rowkey" as student_id,
    d."personal"."first_name",
    d."personal"."last_name",
    d."contact"."email",
    d."demographic"."grade_level",
    a."performance"."cumulative_GPA",
    a."enrollment"."current_courses",
    s."attendance"."attendance_rate",
    s."support"."services",
    s."financial"."aid_status"
FROM "STUDENT_DEMOGRAPHICS" d
LEFT JOIN "STUDENT_ACADEMICS" a ON d."rowkey" = a."rowkey"
LEFT JOIN "STUDENT_SERVICES" s ON d."rowkey" = s."rowkey"
WHERE d."rowkey" = 'STU001'
```

### Query 2: Find Students Needing Support

```sql
-- Students with low GPA and high absences
SELECT 
    d."rowkey" as student_id,
    d."personal"."first_name",
    d."personal"."last_name",
    a."performance"."cumulative_GPA",
    s."attendance"."days_absent",
    s."support"."services"
FROM "STUDENT_DEMOGRAPHICS" d
INNER JOIN "STUDENT_ACADEMICS" a ON d."rowkey" = a."rowkey"
INNER JOIN "STUDENT_SERVICES" s ON d."rowkey" = s."rowkey"
WHERE TO_NUMBER(a."performance"."cumulative_GPA") < 2.5
  AND TO_NUMBER(s."attendance"."days_absent") > 10
```

### Query 3: Academic Performance Dashboard

```sql
-- Students with high performance
SELECT 
    d."rowkey" as student_id,
    d."personal"."first_name",
    d."personal"."last_name",
    d."demographic"."grade_level",
    a."performance"."cumulative_GPA",
    a."performance"."SAT_score",
    a."enrollment"."current_courses",
    s."activities"."clubs"
FROM "STUDENT_DEMOGRAPHICS" d
INNER JOIN "STUDENT_ACADEMICS" a ON d."rowkey" = a."rowkey"
LEFT JOIN "STUDENT_SERVICES" s ON d."rowkey" = s."rowkey"
WHERE TO_NUMBER(a."performance"."cumulative_GPA") >= 3.5
ORDER BY TO_NUMBER(a."performance"."cumulative_GPA") DESC
```

## Design Considerations

### 1. Row Key Design
- **Use Student ID as Row Key**: Enables fast lookups by student ID
- **Consistent Format**: Use consistent format (e.g., "STU001", "12345")
- **String Type**: Keep as VARCHAR for flexibility

### 2. Column Family Design
- **Logical Grouping**: Group related columns in column families
- **Performance**: Queries by column family are faster than scanning all columns
- **Access Patterns**: Design column families based on how data is accessed together

### 3. Data Types
- **All VARCHAR**: HBase native tables store everything as strings
- **Type Conversion**: Use `TO_NUMBER()` for numeric conversions in Phoenix views on HBase tables (not `CAST()`)
  - Example: `TO_NUMBER("performance"."cumulative_GPA") >= 3.5`
  - **Note**: `CAST()` may not work correctly with Phoenix views on HBase tables - use `TO_NUMBER()` instead
- **Date Formats**: Store dates as strings (ISO format: "YYYY-MM-DD")

### 4. Scalability
- **Horizontal Scaling**: HBase scales horizontally by adding region servers
- **Partitioning**: Row keys are automatically partitioned across regions
- **Hot Spotting**: Avoid sequential row keys (e.g., "STU001", "STU002") - consider hashing or salting

### 5. Updates and Versions
- **Versioning**: HBase maintains multiple versions of data (configurable)
- **Updates**: Use `put` command to update existing data
- **Timestamps**: HBase automatically tracks timestamps

## Alternative Design: Single Table vs Multiple Tables

### Option A: Multiple Tables (Current Design)
**Pros**:
- ✅ Clear separation of concerns
- ✅ Independent scaling of different data types
- ✅ Easier to manage different access patterns
- ✅ Better for different retention policies

**Cons**:
- ❌ Requires JOINs for 360-degree view
- ❌ More complex query patterns

### Option B: Single Table with More Column Families
**Pros**:
- ✅ Simpler queries (no JOINs needed)
- ✅ Single row key lookup gets all data
- ✅ Atomic updates across all student data

**Cons**:
- ❌ Very wide rows (all student data in one row)
- ❌ Harder to manage and scale
- ❌ All data must be retrieved together

## Recommendation

**For 360-Degree Views**: **Use Single Table Design** (see [README.md](README.md) for implementation)

**Use Multiple Tables** when:
1. Different data has different retention policies
2. Data access patterns are very different
3. Need independent scaling of different data types
4. Want clear separation of concerns
5. Don't frequently need all data together

**Use Single Table** (recommended for 360-degree views) when:
1. Frequently need all student information together
2. Performance is critical (single row lookup)
3. Simplicity is important (no JOINs needed)
4. Data is logically related and accessed together

## Next Steps

1. Create the three HBase tables
2. Insert sample data
3. Create Phoenix views for each table
4. Test queries across views
5. Build application layer to aggregate the 360-degree view

