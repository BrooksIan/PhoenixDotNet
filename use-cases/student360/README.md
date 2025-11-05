# Student 360-Degree View - Use Case

## Overview

This use case demonstrates a comprehensive 360-degree view of a student using a **single wide HBase table** with a **Phoenix view** for SQL access. All student information (demographics, academics, services) is stored in **one row per student**, enabling fast single-row lookups without JOINs.

**Note**: For an alternative 3-table design approach (using multiple tables with JOINs), see [student_360_view_design.md](student_360_view_design.md). The single-table design is recommended for 360-degree views due to better performance and simpler queries.

## Architecture

### Design Approach

**Single Wide HBase Table**: `STUDENT_360`
- **Row Key**: Student ID (e.g., "STU001", "STU002", "STU003")
- **All student data in one row per student**
- **12 Column Families** for logical grouping:
  - `personal` - Personal information
  - `contact` - Contact information
  - `demographic` - Demographic and enrollment data
  - `enrollment` - Current course enrollments
  - `grades` - Historical grades and transcripts
  - `performance` - GPA, test scores, achievements
  - `requirements` - Graduation requirements progress
  - `attendance` - Attendance records and statistics
  - `support` - Support services and interventions
  - `counseling` - Counseling sessions and notes
  - `financial` - Financial aid and payment information
  - `activities` - Extracurricular activities and clubs

### Benefits

1. ✅ **Single Row Lookup**: Get complete student profile with one query
2. ✅ **No JOINs Required**: All data is in one row
3. ✅ **Fast Queries**: Direct row key access for optimal performance
4. ✅ **Simple Queries**: `SELECT * WHERE rowkey = 'STU001'` gets everything
5. ✅ **Complete 360-Degree View**: All student information accessible in one query

## Table Structure

### Column Families and Fields

#### Personal Information (`personal`)
- `first_name` - Student's first name
- `last_name` - Student's last name
- `middle_name` - Student's middle name
- `date_of_birth` - Date of birth (YYYY-MM-DD format)
- `gender` - Gender (M/F)

#### Contact Information (`contact`)
- `email` - Email address
- `phone` - Phone number
- `address_line1` - Street address
- `city` - City
- `state` - State
- `zip` - ZIP code

#### Demographic Information (`demographic`)
- `enrollment_date` - Date of enrollment
- `grade_level` - Current grade level
- `status` - Enrollment status (Active/Inactive)
- `ethnicity` - Ethnicity information

#### Enrollment Information (`enrollment`)
- `current_courses` - Comma-separated list of current courses
- `semester` - Current semester
- `credits_attempted` - Credits attempted
- `credits_completed` - Credits completed

#### Grades (`grades`)
- `course_MATH101` - Grade for MATH101
- `course_ENG101` - Grade for ENG101
- `course_SCI101` - Grade for SCI101
- `semester_Fall2024_GPA` - Semester GPA

#### Performance (`performance`)
- `cumulative_GPA` - Cumulative grade point average
- `SAT_score` - SAT test score
- `ACT_score` - ACT test score

#### Requirements (`requirements`)
- `credits_earned` - Total credits earned
- `credits_required` - Credits required for graduation
- `graduation_year` - Expected graduation year

#### Attendance (`attendance`)
- `days_present` - Number of days present
- `days_absent` - Number of days absent
- `days_tardy` - Number of tardy days
- `attendance_rate` - Attendance rate percentage

#### Support Services (`support`)
- `services` - Comma-separated list of support services
- `interventions` - Intervention programs
- `special_education` - Special education status

#### Counseling (`counseling`)
- `last_session` - Date of last counseling session
- `total_sessions` - Total number of sessions
- `concerns` - Counseling concerns/topics

#### Financial (`financial`)
- `aid_status` - Financial aid status
- `aid_amount` - Financial aid amount
- `payment_status` - Payment status

#### Activities (`activities`)
- `clubs` - Comma-separated list of clubs
- `sports` - Sports participation
- `volunteer_hours` - Volunteer hours completed

## Implementation

### Script Location

The implementation script is located at:
```
examples/create_student_360_single_view.sh
```

### Quick Start

1. **Run the script** to create the table, insert data, and create the Phoenix view:
   ```bash
   ./examples/create_student_360_single_view.sh
   ```

2. **Query the 360-degree view**:
   ```bash
   # Get complete student profile (single row)
   curl -X POST http://localhost:8099/api/phoenix/query \
     -H "Content-Type: application/json" \
     -d '{"sql": "SELECT * FROM \"STUDENT_360\" WHERE \"rowkey\" = '\''STU001'\''"}'
   ```

### Manual Setup

#### Step 1: Create HBase Table

```bash
docker exec -i opdb-docker /opt/hbase/bin/hbase shell <<'EOF'
create 'STUDENT_360', 
  'personal', 'contact', 'demographic',
  'enrollment', 'grades', 'performance', 'requirements',
  'attendance', 'support', 'counseling', 'financial', 'activities'
EOF
```

#### Step 2: Insert Student Data

```bash
# Example: Insert data for student STU001
docker exec -i opdb-docker /opt/hbase/bin/hbase shell <<'EOF'
put 'STUDENT_360', 'STU001', 'personal:first_name', 'John'
put 'STUDENT_360', 'STU001', 'personal:last_name', 'Doe'
put 'STUDENT_360', 'STU001', 'contact:email', 'john.doe@school.edu'
put 'STUDENT_360', 'STU001', 'demographic:grade_level', '10'
put 'STUDENT_360', 'STU001', 'performance:cumulative_GPA', '3.75'
put 'STUDENT_360', 'STU001', 'attendance:attendance_rate', '97.1'
# ... additional fields
EOF
```

#### Step 3: Create Phoenix View

```bash
curl -X POST http://localhost:8099/api/phoenix/execute \
  -H "Content-Type: application/json" \
  -d '{"sql": "CREATE VIEW IF NOT EXISTS \"STUDENT_360\" (\"rowkey\" VARCHAR PRIMARY KEY, \"personal\".\"first_name\" VARCHAR, \"personal\".\"last_name\" VARCHAR, \"contact\".\"email\" VARCHAR, \"demographic\".\"grade_level\" VARCHAR, \"performance\".\"cumulative_GPA\" VARCHAR, \"attendance\".\"attendance_rate\" VARCHAR, ...)"}'
```

## Query Examples

### Query 1: Complete Student Profile (Single Row)

Get all student information in one query:

```sql
SELECT * FROM "STUDENT_360" WHERE "rowkey" = 'STU001'
```

**Returns**: Complete 360-degree view with all 48+ fields in one row.

### Query 2: Student Summary (Key Fields)

Get key student information:

```sql
SELECT 
  "rowkey" as student_id,
  "personal"."first_name",
  "personal"."last_name",
  "contact"."email",
  "demographic"."grade_level",
  "performance"."cumulative_GPA",
  "attendance"."attendance_rate"
FROM "STUDENT_360"
WHERE "rowkey" = 'STU001'
```

### Query 3: All Students with High GPA

Filter students by GPA (all info still in one row):

```sql
SELECT 
  "rowkey" as student_id,
  "personal"."first_name",
  "personal"."last_name",
  "demographic"."grade_level",
  "performance"."cumulative_GPA",
  "performance"."SAT_score",
  "attendance"."attendance_rate"
FROM "STUDENT_360"
WHERE TO_NUMBER("performance"."cumulative_GPA") >= 3.5
ORDER BY TO_NUMBER("performance"."cumulative_GPA") DESC
```

### Query 4: Students Needing Support

Find students with low GPA or high absences:

```sql
SELECT 
  "rowkey" as student_id,
  "personal"."first_name",
  "personal"."last_name",
  "performance"."cumulative_GPA",
  "attendance"."days_absent",
  "support"."services"
FROM "STUDENT_360"
WHERE TO_NUMBER("performance"."cumulative_GPA") < 2.5
   OR TO_NUMBER("attendance"."days_absent") > 15
```

### Query 5: All Students - Complete 360-Degree View

Get all students with their complete profiles:

```sql
SELECT 
  "rowkey" as student_id,
  "personal"."first_name",
  "personal"."last_name",
  "contact"."email",
  "demographic"."grade_level",
  "performance"."cumulative_GPA",
  "attendance"."attendance_rate",
  "support"."services",
  "financial"."aid_status"
FROM "STUDENT_360"
ORDER BY "rowkey"
```

## Data Model

### Sample Data Structure

```
Row Key: STU001
  personal:first_name = "John"
  personal:last_name = "Doe"
  personal:date_of_birth = "2005-03-15"
  contact:email = "john.doe@school.edu"
  contact:phone = "555-1234"
  demographic:grade_level = "10"
  demographic:status = "Active"
  enrollment:current_courses = "MATH101,ENG101,SCI101"
  grades:course_MATH101 = "A"
  grades:course_ENG101 = "B+"
  performance:cumulative_GPA = "3.75"
  performance:SAT_score = "1450"
  attendance:days_present = "165"
  attendance:days_absent = "5"
  attendance:attendance_rate = "97.1"
  support:services = "Tutoring,ESL Support"
  counseling:last_session = "2024-10-15"
  financial:aid_status = "Pell Grant,Work Study"
  activities:clubs = "Debate,Math Club"
  activities:sports = "Soccer"
  ... (all 48+ fields in one row)
```

## Key Design Decisions

### Why Single Table Instead of Multiple Tables?

| Aspect | Single Table (This Design) | Multiple Tables |
|--------|---------------------------|-----------------|
| **Query Simplicity** | ✅ Single row lookup | ❌ Requires JOINs |
| **Data Retrieval** | ✅ All data in one query | ❌ Multiple queries or JOINs |
| **Performance** | ✅ Fast single row lookup | ⚠️ JOIN overhead |
| **Data Management** | ⚠️ Wide rows (all data together) | ✅ Better separation |
| **Updates** | ✅ All data in one row | ⚠️ Need to update multiple tables |

**Recommendation**: Use single table for 360-degree view when:
- You frequently need all student information together
- Performance is critical (single row lookup)
- Simplicity is important (no JOINs needed)

### Row Key Design

- **Format**: Use consistent student ID format (e.g., "STU001", "STU002")
- **Type**: VARCHAR (string) for flexibility
- **Partitioning**: HBase automatically partitions based on row key
- **Hot Spotting**: Avoid sequential IDs in production - consider hashing or salting

### Column Family Design

- **Logical Grouping**: Related columns grouped in column families
- **Performance**: Queries by column family are faster than scanning all columns
- **Access Patterns**: Design based on how data is accessed together
- **12 Column Families**: Balance between granularity and performance

### Data Types

- **All VARCHAR**: HBase native tables store everything as strings
- **Type Conversion**: Use `TO_NUMBER()` for numeric conversions in Phoenix views on HBase tables
  - Example: `TO_NUMBER("performance"."cumulative_GPA") >= 3.5`
  - **Note**: `CAST()` may not work correctly with Phoenix views on HBase tables - use `TO_NUMBER()` instead
- **Date Formats**: Store dates as strings (ISO format: "YYYY-MM-DD")
- **String Comparison**: Use LIKE for pattern matching
- **NULL Handling**: Use IS NOT NULL to filter out null values

### Scalability

- **Horizontal Scaling**: HBase scales horizontally by adding region servers
- **Partitioning**: Row keys are automatically partitioned across regions
- **Hot Spotting**: Avoid sequential row keys (e.g., "STU001", "STU002") in production - consider hashing or salting
  - Example: Hash the student ID or use a prefix to distribute data evenly
  - Sequential IDs can cause hot spots on a single region server
- **Region Distribution**: HBase automatically distributes regions across available servers
- **Load Balancing**: HBase balances load across region servers automatically

### Updates and Versions

- **Versioning**: HBase maintains multiple versions of data (configurable via `VERSIONS`)
  - Default: 1 version (only latest value)
  - Can be configured per column family: `alter 'STUDENT_360', {NAME => 'personal', VERSIONS => 3}`
- **Updates**: Use `put` command to update existing data
  - Updates are atomic at the row level
  - Example: `put 'STUDENT_360', 'STU001', 'performance:cumulative_GPA', '3.80'`
- **Timestamps**: HBase automatically tracks timestamps for each cell
  - Can query historical versions if versioning is enabled
  - Timestamps are in milliseconds since epoch
- **Concurrent Updates**: HBase handles concurrent updates to the same row

## Performance Considerations

### Advantages

1. **Single Row Lookup**: Direct row key access is O(1) operation
2. **No JOINs**: Eliminates JOIN overhead
3. **Atomic Retrieval**: All student data retrieved in one operation
4. **Cache-Friendly**: Single row fits in memory cache

### Considerations

1. **Wide Rows**: Each row contains 48+ columns
2. **Memory Usage**: Large rows consume more memory
3. **Update Overhead**: Updating any field touches the entire row
4. **Schema Flexibility**: Adding new fields requires view updates

## Use Cases

### 1. Student Dashboard
Display complete student profile on dashboard:
```sql
SELECT * FROM "STUDENT_360" WHERE "rowkey" = 'STU001'
```

### 2. Academic Reporting
Generate academic reports with all student data:
```sql
SELECT 
  "personal"."first_name",
  "personal"."last_name",
  "performance"."cumulative_GPA",
  "grades"."course_MATH101",
  "attendance"."attendance_rate"
FROM "STUDENT_360"
WHERE "demographic"."grade_level" = '10'
```

### 3. Support Services
Identify students needing support:
```sql
SELECT * FROM "STUDENT_360"
WHERE TO_NUMBER("performance"."cumulative_GPA") < 2.5
   OR TO_NUMBER("attendance"."days_absent") > 15
```

### 4. Financial Aid Management
View financial aid information:
```sql
SELECT 
  "personal"."first_name",
  "personal"."last_name",
  "financial"."aid_status",
  "financial"."aid_amount",
  "financial"."payment_status"
FROM "STUDENT_360"
```

## Maintenance

### Adding New Fields

1. **Add to HBase table**: Insert new column family or qualifier
   ```bash
   # Add new column family
   docker exec -i opdb-docker /opt/hbase/bin/hbase shell <<EOF
   alter 'STUDENT_360', 'new_column_family'
   EOF
   
   # Or just insert data - column qualifiers are created automatically
   put 'STUDENT_360', 'STU001', 'new_column_family:new_field', 'value'
   EOF
   ```

2. **Update Phoenix view**: Add new column to view definition
   ```sql
   -- Drop existing view
   DROP VIEW "STUDENT_360";
   
   -- Recreate with new columns
   CREATE VIEW "STUDENT_360" (
     "rowkey" VARCHAR PRIMARY KEY,
     -- ... existing columns ...
     "new_column_family"."new_field" VARCHAR
   );
   ```

3. **Recreate view**: Drop and recreate view with new columns
   - **Note**: Dropping a view does not delete the underlying HBase table data
   - View is just a SQL schema definition over the HBase table

### Updating Student Data

```bash
# Update a single field
docker exec -i opdb-docker /opt/hbase/bin/hbase shell <<EOF
put 'STUDENT_360', 'STU001', 'performance:cumulative_GPA', '3.80'
EOF
```

### Querying via API

```bash
# Get complete student profile
curl -X POST http://localhost:8099/api/phoenix/query \
  -H "Content-Type: application/json" \
  -d '{"sql": "SELECT * FROM \"STUDENT_360\" WHERE \"rowkey\" = '\''STU001'\''"}'
```

## Related Documentation

### Internal Documentation
- [Phoenix Views Documentation](../../Documentation/README_VIEWS.md)
- [HBase vs Phoenix Tables](../../Documentation/HBASE_VS_PHOENIX_TABLES.md)
- [Table Operations Guide](../../Documentation/README_TABLES.md)
- [API Documentation](../../Documentation/README_REST_API.md)

### Alternative Design
- [student_360_view_design.md](student_360_view_design.md) - **3-Table Design Approach** (alternative design using multiple tables with JOINs)
  - This document describes the 3-table design approach for reference
  - The single-table design (this README) is recommended for 360-degree views
  - Use the 3-table design only if you need different retention policies or independent scaling

## Example Script

See `examples/create_student_360_single_view.sh` for a complete working example that:
- Creates the HBase table
- Inserts sample data for 3 students
- Creates the Phoenix view
- Demonstrates query examples

## Sample SQL Queries

See `sample_queries.sql` for a comprehensive collection of 38+ sample Phoenix SQL queries including:

- **Basic Queries**: Get student profiles, list all students
- **Academic Queries**: High GPA students, low GPA students, course grades, graduation status
- **Attendance Queries**: Perfect attendance, attendance issues, attendance rates
- **Support Services Queries**: Students needing support, tutoring, special education
- **Counseling Queries**: Recent sessions, multiple sessions
- **Financial Aid Queries**: Aid recipients, payment issues, scholarships
- **Activities Queries**: Clubs, sports, volunteer hours
- **Complex Queries**: Dashboard views, at-risk students, high achievers
- **Aggregation Queries**: Average GPA by grade, attendance statistics, financial aid totals
- **Filtering Queries**: Search by name, email domain, GPA ranges

### Quick Query Examples

```sql
-- Get complete student profile
SELECT * FROM "STUDENT_360" WHERE "rowkey" = 'STU001';

-- High GPA students
SELECT "rowkey", "personal"."first_name", "personal"."last_name", 
       "performance"."cumulative_GPA"
FROM "STUDENT_360"
WHERE TO_NUMBER("performance"."cumulative_GPA") >= 3.5;

-- Students needing support
SELECT "rowkey", "personal"."first_name", "personal"."last_name",
       "performance"."cumulative_GPA", "attendance"."days_absent"
FROM "STUDENT_360"
WHERE TO_NUMBER("performance"."cumulative_GPA") < 2.5
   OR TO_NUMBER("attendance"."days_absent") > 15;
```

## Phoenix Views and JOINs

### Can Phoenix Views Join Tables?

**Short Answer**: Phoenix views themselves cannot be defined with JOINs, but you **can** use JOINs in queries that reference Phoenix views.

#### Phoenix View Definition Limitations

- ❌ **Cannot define a view with JOIN**: A Phoenix view definition must be based on a **single underlying table/view**
- ❌ **Cannot create**: `CREATE VIEW joined_view AS SELECT * FROM table1 JOIN table2` (not supported)

#### Phoenix Query JOIN Support

- ✅ **Can JOIN views in queries**: You can use JOINs in SELECT queries that reference Phoenix views
- ✅ **Supports INNER JOIN, LEFT JOIN, RIGHT JOIN**: Standard SQL JOIN operations are supported
- ✅ **Can JOIN multiple views**: You can join multiple Phoenix views together in queries

### Example: JOINing Multiple Phoenix Views

If you had created separate views for the 3-tables design (STUDENT_DEMOGRAPHICS, STUDENT_ACADEMICS, STUDENT_SERVICES), you could join them in queries:

```sql
-- Join multiple Phoenix views in a query
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

### Why Single Table Design is Better for 360-Degree View

This is why the **single wide table design** (STUDENT_360) is recommended for 360-degree views:

1. ✅ **No JOINs needed**: All data in one row
2. ✅ **Single row lookup**: Fast O(1) access
3. ✅ **Simpler queries**: `SELECT * WHERE rowkey = 'STU001'`
4. ✅ **Better performance**: No JOIN overhead
5. ✅ **Atomic retrieval**: All data retrieved together

### Alternative: Multiple Views with JOINs

If you prefer the 3-table design, you can:

1. Create separate Phoenix views for each HBase table
2. Use JOINs in your queries to combine them
3. Accept the JOIN overhead and query complexity

**Example**:
```sql
-- Create views on separate tables
CREATE VIEW "STUDENT_DEMOGRAPHICS" (...);
CREATE VIEW "STUDENT_ACADEMICS" (...);
CREATE VIEW "STUDENT_SERVICES" (...);

-- Then JOIN them in queries
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

**When to Use Multiple Tables**:
- Different data has different retention policies
- Data access patterns are very different
- Need independent scaling of different data types
- Want clear separation of concerns

**When to Use Single Table** (recommended for 360-degree views):
- Frequently need all data together
- Performance is critical (single row lookup)
- Simplicity is important (no JOINs needed)
- Data is logically related and accessed together

### Summary

| Aspect | Phoenix View Definition | Phoenix Queries |
|--------|------------------------|-----------------|
| **JOIN Support** | ❌ Cannot define views with JOINs | ✅ Can JOIN views in queries |
| **Single Table** | ✅ Must be based on one table | ✅ Can query multiple views with JOINs |
| **Complexity** | ⚠️ View definition limited | ✅ Full SQL JOIN support |

**Recommendation**: For 360-degree views, use a single wide table design (like STUDENT_360) to avoid JOINs entirely and get optimal performance.

## Best Practices and Production Considerations

### Row Key Design Best Practices

1. **Consistent Format**: Use consistent student ID format across all records
   - Example: "STU001", "STU002", "STU003" (with zero-padding)
   - Avoid: "STU1", "STU2", "STU10" (inconsistent formatting)

2. **Avoid Sequential IDs in Production**: Sequential row keys can cause hot spots
   - **Problem**: Sequential IDs like "STU001", "STU002" may all land on the same region
   - **Solution**: Use hashing or salting for better distribution
     ```bash
     # Hash the student ID: MD5(student_id)[:8] + student_id
     # Or use a prefix: school_code + student_id
     # Example: "SCH001_STU001" instead of "STU001"
     ```

3. **String vs Numeric Row Keys**: 
   - **VARCHAR**: More flexible, easier to read, but larger storage
   - **Numeric**: Smaller storage, but less flexible for future changes
   - **Recommendation**: Use VARCHAR for student IDs (flexibility and readability)

### Column Family Best Practices

1. **Logical Grouping**: Group related columns together
   - Example: `personal`, `contact`, `demographic` - all related to student identity
   - Example: `grades`, `performance`, `requirements` - all related to academics

2. **Column Family Count**: Balance between granularity and simplicity
   - **Too Few**: All data in one family (harder to query specific data)
   - **Too Many**: Over-fragmentation (harder to manage)
   - **Recommendation**: 10-15 column families for a 360-degree view

3. **Access Patterns**: Design based on how data is accessed
   - Group frequently accessed columns together
   - Separate rarely accessed columns into their own families

### Data Type Best Practices

1. **Numeric Values**: Store as strings, convert in queries
   - Use `TO_NUMBER()` for comparisons: `TO_NUMBER("gpa") >= 3.5`
   - Store with appropriate precision: "3.75" not "3.75000000"

2. **Date Values**: Use ISO format (YYYY-MM-DD)
   - Consistent format: "2024-01-15"
   - Sortable as strings: "2024-01-15" < "2024-12-31"
   - Can be compared as strings: `WHERE "date" >= '2024-01-01'`

3. **Boolean Values**: Store as "Yes"/"No" or "True"/"False"
   - Consistent capitalization: Always use same case
   - Example: "Yes" or "No" (not "yes", "YES", "y", "Y")

4. **NULL Handling**: Be explicit about NULL values
   - Use `IS NOT NULL` to filter: `WHERE "gpa" IS NOT NULL`
   - Check for empty strings: `WHERE "gpa" != '' AND "gpa" IS NOT NULL`

### Performance Optimization

1. **Query Specific Columns**: Don't use `SELECT *` unless necessary
   ```sql
   -- Good: Query only needed columns
   SELECT "personal"."first_name", "performance"."cumulative_GPA" 
   FROM "STUDENT_360"
   
   -- Avoid: SELECT * (unless you need all 48+ columns)
   SELECT * FROM "STUDENT_360"
   ```

2. **Use Row Key Lookups**: Always use row key in WHERE clause when possible
   ```sql
   -- Good: Fast row key lookup
   SELECT * FROM "STUDENT_360" WHERE "rowkey" = 'STU001'
   
   -- Slower: Full table scan
   SELECT * FROM "STUDENT_360" WHERE "personal"."first_name" = 'John'
   ```

3. **Index Considerations**: For frequent queries on non-row key columns, consider:
   - Secondary indexes (if supported in your Phoenix version)
   - Denormalization: Store frequently queried values in multiple places
   - Materialized views: Pre-compute common queries

### Monitoring and Maintenance

1. **Table Statistics**: Monitor table size and region distribution
   ```bash
   # Check table size
   docker exec opdb-docker /opt/hbase/bin/hbase shell <<EOF
   describe 'STUDENT_360'
   EOF
   ```

2. **Query Performance**: Monitor slow queries
   - Use EXPLAIN to understand query plans
   - Optimize frequently used queries
   - Add indexes for common WHERE clauses

3. **Data Backup**: Regular backups of HBase data
   - Use HBase snapshots for point-in-time recovery
   - Export data for offline analysis
   - Replicate to backup cluster

4. **Schema Evolution**: Plan for future changes
   - Design column families for extensibility
   - Document schema changes
   - Version your Phoenix views

## Summary

The Student 360-Degree View use case demonstrates:
- ✅ Single wide HBase table design
- ✅ Phoenix view for SQL access
- ✅ Complete student profile in one row
- ✅ Fast single-row lookups
- ✅ No JOINs required (by design)
- ✅ Simple query patterns
- ✅ Comprehensive 360-degree student information

This design is ideal for applications that need quick access to complete student profiles with minimal query complexity.
