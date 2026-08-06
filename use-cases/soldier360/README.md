# Soldier 360-Degree View - Use Case

## Overview

This use case demonstrates a comprehensive 360-degree view of a Marine using a **single wide HBase table** with a **Phoenix view** for SQL access. All Marine information (personal, performance, training, medical) is stored in **one row per Marine**, enabling fast single-row lookups without JOINs.

The Soldier 360 view integrates data from multiple Marine Corps systems:
- **JEPES** (Junior Enlisted Performance Evaluation System) - Performance data for E-2 through E-5
- **APES** (Automated Performance Evaluation System) - Fitness Reports for Sergeants and Officers
- **MCTIMS** (Marine Corps Total Information Management System) - Training and readiness data
- **MHS Genesis** (Medical Health System) - Medical readiness data

## Architecture

### Design Approach

**Single Wide HBase Table**: `SOLDIER_360`
- **Row Key**: EDIPI (Electronic Data Interchange Personal Identifier) - 10-digit DoD ID
- **All Marine data in one row per EDIPI**
- **5 Column Families** for logical grouping:
  - `personal` - Personal information (name, rank, unit, MOS)
  - `jepes` - Junior Enlisted Performance data (PFT/CFT scores, character/MOS/leadership scores)
  - `apes` - Fitness Report data (attribute scores, recommendations)
  - `training` - MCTIMS training & readiness data
  - `medical` - MHS Genesis medical readiness data

### Benefits

1. ✅ **Single Row Lookup**: Get complete Marine profile with one query using EDIPI
2. ✅ **No JOINs Required**: All data is in one row
3. ✅ **Fast Queries**: Direct row key access for optimal performance
4. ✅ **Simple Queries**: `SELECT * WHERE rowkey = '1003456789'` gets everything
5. ✅ **Complete 360-Degree View**: All Marine information accessible in one query
6. ✅ **Unified View**: Combines data from multiple systems (JEPES, APES, MCTIMS, MHS Genesis)

## Data Sources

### JEPES (Junior Enlisted Performance Evaluation System)
- **Purpose**: Performance evaluation for Junior Enlisted Marines (E-2 through E-5)
- **Key Data**: PFT/CFT scores, rifle qualification, PME completion, character/MOS/leadership scores
- **Source System**: Used for promotion boards and performance tracking

### APES (Automated Performance Evaluation System)
- **Purpose**: Fitness Reports (FitRep) for Sergeants and Officers (E-6+)
- **Key Data**: 14-attribute scores, RS recommendation, RO recommendation ("Christmas Tree")
- **Source System**: Used for promotion boards and performance evaluation

### MCTIMS (Marine Corps Total Information Management System)
- **Purpose**: Authoritative system for training and readiness
- **Key Data**: Rifle qualification status, PFT/CFT current status, PME completion, annual training percentage, overall readiness
- **Source System**: Source of truth for training & readiness; feeds into JEPES and APES

### MHS Genesis (Medical Health System)
- **Purpose**: DoD electronic health record system
- **Key Data**: Medical deployability status, dental class, PHA status, IMR status, profile status
- **Source System**: Source of truth for medical readiness; feeds into MCTIMS

## Table Structure

### Column Families and Fields

#### Personal Information (`personal`)
- `last_name` - Marine's last name
- `first_name` - Marine's first name
- `rank` - Marine's rank (e.g., "Cpl", "Sgt", "SSgt", "Capt")
- `unit` - Marine's current unit (e.g., "1st Bn 8th Mar", "CLB-6", "HMLA-167")
- `mos` - Military Occupational Specialty (e.g., "0311", "3531", "6111")

#### JEPES Data (`jepes`) - Junior Enlisted Only
- `pft_score` - Physical Fitness Test score (0-300)
- `cft_score` - Combat Fitness Test score (0-300)
- `rifle_qual` - Rifle qualification badge ("Expert", "Sharpshooter", "Marksman")
- `pme_complete` - Professional Military Education complete ("Y"/"N")
- `char_score` - Character score (1.0-5.0)
- `mos_score` - MOS & Mission Accomplishment score (1.0-5.0)
- `lead_score` - Leadership score (1.0-5.0)

**Note**: JEPES data is only populated for Junior Enlisted Marines (E-2 through E-5). For Sergeants and Officers, these fields will be NULL and APES data will be populated instead.

#### APES Data (`apes`) - Sergeants and Officers Only
- `report_occasion` - Report occasion ("Annual", "Change of RS", "Transfer")
- `avg_attribute` - Average of 14 leadership attributes (1.0-5.0)
- `pft_pass` - PFT pass/fail ("Y"/"N")
- `cft_pass` - CFT pass/fail ("Y"/"N")
- `ht_wt_pass` - Height/Weight pass/fail ("Y"/"N")
- `rs_recommend` - Reporting Senior's recommendation ("Promote Now", "Promote", "Do Not Promote")
- `ro_recommend` - Reviewing Officer's recommendation ("Far Left", "Left of Center", "Center", "Right of Center", "Far Right")

**Note**: APES data is only populated for Sergeants and Officers (E-6+). For Junior Enlisted, these fields will be NULL and JEPES data will be populated instead.

#### Training Data (`training`) - MCTIMS
- `rifle_current` - Rifle qualification current ("Y"/"N")
- `pft_current` - PFT current ("Y"/"N")
- `cft_current` - CFT current ("Y"/"N")
- `pme_complete` - PME complete ("Y"/"N")
- `annual_training_pct` - Annual training completion percentage (0-100)
- `overall_ready` - Overall readiness status ("Y"/"N")

#### Medical Data (`medical`) - MHS Genesis
- `medical_status` - Medical deployability status ("Deployable"/"Non-Deployable")
- `dental_class` - Dental classification ("Class 1", "Class 2", "Class 3", "Class 4")
- `pha_current` - Physical Health Assessment current ("Y"/"N")
- `imr_status` - Individual Medical Readiness status ("Current"/"Due")
- `profile_status` - Physical limitation profile ("None"/"Temporary"/"Permanent")

## Implementation

### Script Location

The implementation script is located in this folder:
- `create_soldier360_table.sh` - Creates the HBase table, inserts sample data, and creates the Phoenix view

### Quick Start

1. **Create the HBase table, insert data, and create the Phoenix view**:
   ```bash
   ./create_soldier360_table.sh
   ```

2. **Query the 360-degree view**:
   ```bash
   # Get complete Marine profile (single row)
   curl -X POST http://localhost:8099/api/phoenix/query \
     -H "Content-Type: application/json" \
     -d '{"sql": "SELECT * FROM \"SOLDIER_360\" WHERE \"rowkey\" = '\''1003456789'\''"}'
   ```

> **⚠️ Important Note**: HBase tables and Phoenix views are **ephemeral** and stored in the Docker container's filesystem. If you stop or restart the Docker environment (`docker-compose down`), all HBase tables and Phoenix views will be **lost** and need to be recreated. You will need to run the script again:
> ```bash
> ./create_soldier360_table.sh
> ```
> For production deployments, ensure HBase data is persisted using Docker volumes or persistent storage.

### Manual Setup

#### Step 1: Create HBase Table

```bash
docker exec -i opdb-docker /opt/hbase/bin/hbase shell <<'EOF'
create 'SOLDIER_360', 'personal', 'jepes', 'apes', 'training', 'medical'
EOF
```

#### Step 2: Insert Marine Data

```bash
# Example: Insert data for Marine with EDIPI 1003456789
docker exec -i opdb-docker /opt/hbase/bin/hbase shell <<'EOF'
put 'SOLDIER_360', '1003456789', 'personal:last_name', 'Lee'
put 'SOLDIER_360', '1003456789', 'personal:first_name', 'Sange'
put 'SOLDIER_360', '1003456789', 'personal:rank', 'Sgt'
put 'SOLDIER_360', '1003456789', 'personal:unit', 'CLB-6'
put 'SOLDIER_360', '1003456789', 'personal:mos', '3531'
put 'SOLDIER_360', '1003456789', 'apes:avg_attribute', '4.6'
put 'SOLDIER_360', '1003456789', 'apes:rs_recommend', 'Promote'
put 'SOLDIER_360', '1003456789', 'training:overall_ready', 'Y'
put 'SOLDIER_360', '1003456789', 'medical:medical_status', 'Deployable'
# ... additional fields
EOF
```

#### Step 3: Create Phoenix View

```bash
curl -X POST http://localhost:8099/api/phoenix/execute \
  -H "Content-Type: application/json" \
  -d '{"sql": "CREATE VIEW IF NOT EXISTS \"SOLDIER_360\" (\"rowkey\" VARCHAR PRIMARY KEY, \"personal\".\"last_name\" VARCHAR, \"personal\".\"first_name\" VARCHAR, \"personal\".\"rank\" VARCHAR, \"personal\".\"unit\" VARCHAR, \"personal\".\"mos\" VARCHAR, \"jepes\".\"pft_score\" VARCHAR, \"jepes\".\"cft_score\" VARCHAR, \"jepes\".\"rifle_qual\" VARCHAR, \"jepes\".\"pme_complete\" VARCHAR, \"jepes\".\"char_score\" VARCHAR, \"jepes\".\"mos_score\" VARCHAR, \"jepes\".\"lead_score\" VARCHAR, \"apes\".\"report_occasion\" VARCHAR, \"apes\".\"avg_attribute\" VARCHAR, \"apes\".\"pft_pass\" VARCHAR, \"apes\".\"cft_pass\" VARCHAR, \"apes\".\"ht_wt_pass\" VARCHAR, \"apes\".\"rs_recommend\" VARCHAR, \"apes\".\"ro_recommend\" VARCHAR, \"training\".\"rifle_current\" VARCHAR, \"training\".\"pft_current\" VARCHAR, \"training\".\"cft_current\" VARCHAR, \"training\".\"pme_complete\" VARCHAR, \"training\".\"annual_training_pct\" VARCHAR, \"training\".\"overall_ready\" VARCHAR, \"medical\".\"medical_status\" VARCHAR, \"medical\".\"dental_class\" VARCHAR, \"medical\".\"pha_current\" VARCHAR, \"medical\".\"imr_status\" VARCHAR, \"medical\".\"profile_status\" VARCHAR)"}'
```

## Query Examples

### Query 1: Complete Marine Profile (Single Row)

Get all Marine information in one query:

```sql
SELECT * FROM "SOLDIER_360" WHERE "rowkey" = '1003456789'
```

**Returns**: Complete 360-degree view with all fields in one row.

### Query 2: Marine Summary (Key Fields)

Get key Marine information:

```sql
SELECT 
  "rowkey" as edipi,
  "personal"."first_name",
  "personal"."last_name",
  "personal"."rank",
  "personal"."unit",
  "training"."overall_ready",
  "medical"."medical_status"
FROM "SOLDIER_360"
WHERE "rowkey" = '1003456789'
```

### Query 3: Marines Ready for Deployment

Filter Marines by readiness status:

```sql
SELECT 
  "rowkey" as edipi,
  "personal"."first_name",
  "personal"."last_name",
  "personal"."rank",
  "personal"."unit",
  "training"."overall_ready",
  "medical"."medical_status"
FROM "SOLDIER_360"
WHERE "training"."overall_ready" = 'Y'
  AND "medical"."medical_status" = 'Deployable'
ORDER BY "rowkey"
```

### Query 4: High Performers (APES)

Find Marines with high APES attribute scores:

```sql
SELECT 
  "rowkey" as edipi,
  "personal"."first_name",
  "personal"."last_name",
  "personal"."rank",
  "personal"."unit",
  "apes"."avg_attribute",
  "apes"."ro_recommend"
FROM "SOLDIER_360"
WHERE "apes"."avg_attribute" IS NOT NULL
  AND TO_NUMBER("apes"."avg_attribute") >= 4.5
ORDER BY TO_NUMBER("apes"."avg_attribute") DESC
```

### Query 5: High Performers (JEPES)

Find Junior Enlisted Marines with high scores:

```sql
SELECT 
  "rowkey" as edipi,
  "personal"."first_name",
  "personal"."last_name",
  "personal"."rank",
  "personal"."unit",
  "jepes"."pft_score",
  "jepes"."cft_score",
  "jepes"."char_score"
FROM "SOLDIER_360"
WHERE "jepes"."pft_score" IS NOT NULL
  AND TO_NUMBER("jepes"."pft_score") >= 280
ORDER BY TO_NUMBER("jepes"."pft_score") DESC
```

### Query 6: Marines Not Ready for Deployment

Find Marines with readiness issues:

```sql
SELECT 
  "rowkey" as edipi,
  "personal"."first_name",
  "personal"."last_name",
  "personal"."rank",
  "personal"."unit",
  "training"."overall_ready",
  "training"."annual_training_pct",
  "medical"."medical_status",
  "medical"."dental_class"
FROM "SOLDIER_360"
WHERE "training"."overall_ready" = 'N'
   OR "medical"."medical_status" = 'Non-Deployable'
ORDER BY "rowkey"
```

### Query 7: Marines by Unit

Get all Marines in a specific unit:

```sql
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
ORDER BY "personal"."rank", "rowkey"
```

### Query 8: Marines with Promotion Recommendations

Find Marines recommended for promotion:

```sql
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
   OR "apes"."ro_recommend" = 'Far Left'
ORDER BY TO_NUMBER("apes"."avg_attribute") DESC
```

## Data Model

### Sample Data Structure

```
Row Key: 1003456789
  personal:last_name = "Lee"
  personal:first_name = "Sange"
  personal:rank = "Sgt"
  personal:unit = "CLB-6"
  personal:mos = "3531"
  apes:report_occasion = "Annual"
  apes:avg_attribute = "4.6"
  apes:pft_pass = "Y"
  apes:cft_pass = "Y"
  apes:ht_wt_pass = "Y"
  apes:rs_recommend = "Promote"
  apes:ro_recommend = "Left of Center"
  training:rifle_current = "Y"
  training:pft_current = "Y"
  training:cft_current = "Y"
  training:pme_complete = "Y"
  training:annual_training_pct = "100"
  training:overall_ready = "Y"
  medical:medical_status = "Deployable"
  medical:dental_class = "Class 1"
  medical:pha_current = "Y"
  medical:imr_status = "Current"
  medical:profile_status = "None"
```

### Data Source Notes

**JEPES vs APES Data**: 
- Junior Enlisted Marines (E-2 through E-5) will have JEPES data populated and APES fields will be NULL
- Sergeants and Officers (E-6+) will have APES data populated and JEPES fields will be NULL
- When querying, use conditional logic: `WHERE "jepes"."pft_score" IS NOT NULL OR "apes"."avg_attribute" IS NOT NULL`

**Training and Medical Data**:
- Training data (MCTIMS) and Medical data (MHS Genesis) should be present for all Marines
- These are the authoritative sources for readiness status

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
- You frequently need all Marine information together
- Performance is critical (single row lookup)
- Simplicity is important (no JOINs needed)

### Row Key Design

- **Format**: EDIPI (10-digit DoD ID number)
- **Type**: VARCHAR (string) for flexibility
- **Partitioning**: HBase automatically partitions based on row key
- **Hot Spotting**: EDIPIs are generally well-distributed, but consider hashing if needed

### Column Family Design

- **Logical Grouping**: Related columns grouped in column families
- **Performance**: Queries by column family are faster than scanning all columns
- **Access Patterns**: Design based on how data is accessed together
- **5 Column Families**: Balance between granularity and performance
  - `personal` - Identity and basic info
  - `jepes` - Junior Enlisted performance (E-2 through E-5)
  - `apes` - Fitness Reports (E-6+)
  - `training` - Training & readiness (all Marines)
  - `medical` - Medical readiness (all Marines)

### Data Types

- **All VARCHAR**: HBase native tables store everything as strings
- **Type Conversion**: Use `TO_NUMBER()` for numeric conversions in Phoenix views on HBase tables
  - Example: `TO_NUMBER("jepes"."pft_score") >= 280`
  - **Note**: `CAST()` may not work correctly with Phoenix views on HBase tables - use `TO_NUMBER()` instead
- **Boolean Values**: Store as "Y"/"N" for consistency
- **NULL Handling**: Use IS NOT NULL to filter out null values
  - JEPES fields will be NULL for Sergeants/Officers
  - APES fields will be NULL for Junior Enlisted

### Scalability

- **Horizontal Scaling**: HBase scales horizontally by adding region servers
- **Partitioning**: Row keys are automatically partitioned across regions
- **EDIPI Distribution**: EDIPIs are generally well-distributed (not sequential)
- **Region Distribution**: HBase automatically distributes regions across available servers
- **Load Balancing**: HBase balances load across region servers automatically

## Performance Considerations

### Advantages

1. **Single Row Lookup**: Direct row key access is O(1) operation
2. **No JOINs**: Eliminates JOIN overhead
3. **Atomic Retrieval**: All Marine data retrieved in one operation
4. **Cache-Friendly**: Single row fits in memory cache

### Considerations

1. **Wide Rows**: Each row contains 30+ columns
2. **Memory Usage**: Large rows consume more memory
3. **Update Overhead**: Updating any field touches the entire row
4. **Schema Flexibility**: Adding new fields requires view updates

## Use Cases

### 1. Marine Dashboard
Display complete Marine profile on dashboard:
```sql
SELECT * FROM "SOLDIER_360" WHERE "rowkey" = '1003456789'
```

### 2. Deployment Readiness
Generate readiness reports:
```sql
SELECT 
  "personal"."first_name",
  "personal"."last_name",
  "personal"."rank",
  "personal"."unit",
  "training"."overall_ready",
  "medical"."medical_status"
FROM "SOLDIER_360"
WHERE "personal"."unit" = '1st Bn 8th Mar'
```

### 3. Performance Evaluation
Identify high performers for promotion boards:
```sql
SELECT * FROM "SOLDIER_360"
WHERE "apes"."ro_recommend" = 'Far Left'
   OR ("jepes"."char_score" IS NOT NULL AND TO_NUMBER("jepes"."char_score") >= 4.5)
```

### 4. Readiness Issues
Identify Marines with readiness problems:
```sql
SELECT * FROM "SOLDIER_360"
WHERE "training"."overall_ready" = 'N'
   OR "medical"."medical_status" = 'Non-Deployable'
```

### 5. Unit Readiness Summary
Get unit-level readiness statistics:
```sql
SELECT 
  "personal"."unit",
  COUNT(*) as total_marines,
  SUM(CASE WHEN "training"."overall_ready" = 'Y' THEN 1 ELSE 0 END) as ready_count,
  SUM(CASE WHEN "medical"."medical_status" = 'Deployable' THEN 1 ELSE 0 END) as deployable_count
FROM "SOLDIER_360"
WHERE "personal"."unit" IS NOT NULL
GROUP BY "personal"."unit"
```

## Maintenance

### Adding New Fields

1. **Add to HBase table**: Insert new column family or qualifier
   ```bash
   # Add new column family
   docker exec -i opdb-docker /opt/hbase/bin/hbase shell <<EOF
   alter 'SOLDIER_360', 'new_column_family'
   EOF
   
   # Or just insert data - column qualifiers are created automatically
   put 'SOLDIER_360', '1003456789', 'new_column_family:new_field', 'value'
   EOF
   ```

2. **Update Phoenix view**: Add new column to view definition
   ```sql
   -- Drop existing view
   DROP VIEW "SOLDIER_360";
   
   -- Recreate with new columns
   CREATE VIEW "SOLDIER_360" (
     "rowkey" VARCHAR PRIMARY KEY,
     -- ... existing columns ...
     "new_column_family"."new_field" VARCHAR
   );
   ```

3. **Recreate view**: Drop and recreate view with new columns
   - **Note**: Dropping a view does not delete the underlying HBase table data
   - View is just a SQL schema definition over the HBase table

### Updating Marine Data

```bash
# Update a single field
docker exec -i opdb-docker /opt/hbase/bin/hbase shell <<EOF
put 'SOLDIER_360', '1003456789', 'training:overall_ready', 'Y'
EOF
```

### Querying via API

```bash
# Get complete Marine profile
curl -X POST http://localhost:8099/api/phoenix/query \
  -H "Content-Type: application/json" \
  -d '{"sql": "SELECT * FROM \"SOLDIER_360\" WHERE \"rowkey\" = '\''1003456789'\''"}'
```

## Related Documentation

### Internal Documentation
- [Phoenix Views Documentation](../../Documentation/README_VIEWS.md)
- [HBase vs Phoenix Tables](../../Documentation/HBASE_VS_PHOENIX_TABLES.md)
- [Table Operations Guide](../../Documentation/README_TABLES.md)
- [API Documentation](../../Documentation/README_REST_API.md)

### Data Source Documentation
- [Raw Data Files](rawData/) - Original data source documents (APES, JEPES, MCTIMS, MHS Genesis)

## Example Script

See `create_soldier360_table.sh` in this folder for a complete working example that:
- Creates the HBase table
- Inserts sample data for 7 Marines (different ranks and data sources)
- Creates the Phoenix view
- Demonstrates query examples

## Sample SQL Queries

See `sample_queries.sql` for a comprehensive collection of 47+ sample Phoenix SQL queries including:

- **Basic Queries**: Get Marine profiles, list all Marines
- **Performance Queries**: High PFT/CFT scores, high JEPES scores, high APES scores, promotion recommendations
- **Training & Readiness Queries**: Ready/not ready Marines, expired qualifications, incomplete training
- **Medical Readiness Queries**: Deployable/non-deployable Marines, dental issues, profiles
- **Queries by Rank**: Sergeants, Corporals, Officers
- **Queries by Unit**: Unit-specific queries, MOS queries
- **Complex Queries**: Dashboard views, at-risk Marines, high performers
- **Aggregation Queries**: Readiness by unit, medical status by unit, average scores by rank
- **Filtering Queries**: Search by name, rank with readiness filters, PFT score ranges

### Quick Query Examples

```sql
-- Get complete Marine profile
SELECT * FROM "SOLDIER_360" WHERE "rowkey" = '1003456789';

-- Marines ready for deployment
SELECT "rowkey", "personal"."first_name", "personal"."last_name", 
       "training"."overall_ready", "medical"."medical_status"
FROM "SOLDIER_360"
WHERE "training"."overall_ready" = 'Y' AND "medical"."medical_status" = 'Deployable';

-- High performers (APES)
SELECT "rowkey", "personal"."first_name", "personal"."last_name",
       "apes"."avg_attribute", "apes"."ro_recommend"
FROM "SOLDIER_360"
WHERE "apes"."avg_attribute" IS NOT NULL 
  AND TO_NUMBER("apes"."avg_attribute") >= 4.5;

-- Marines with readiness issues
SELECT "rowkey", "personal"."first_name", "personal"."last_name",
       "training"."overall_ready", "medical"."medical_status"
FROM "SOLDIER_360"
WHERE "training"."overall_ready" = 'N' OR "medical"."medical_status" = 'Non-Deployable';
```

## Best Practices and Production Considerations

### Row Key Design Best Practices

1. **Consistent Format**: Use EDIPI (10-digit DoD ID) consistently
   - Example: "1003456789" (always 10 digits)
   - EDIPIs are generally well-distributed (not sequential)

2. **EDIPI Distribution**: EDIPIs are naturally well-distributed
   - No need for hashing or salting (unlike sequential student IDs)
   - EDIPIs are assigned by DoD and are not sequential

3. **String vs Numeric Row Keys**: 
   - **VARCHAR**: More flexible, easier to read, but larger storage
   - **Numeric**: Smaller storage, but less flexible for future changes
   - **Recommendation**: Use VARCHAR for EDIPI (flexibility and readability)

### Column Family Best Practices

1. **Logical Grouping**: Group related columns together
   - `personal` - Identity information
   - `jepes` / `apes` - Performance data (mutually exclusive by rank)
   - `training` - Training & readiness (all Marines)
   - `medical` - Medical readiness (all Marines)

2. **Column Family Count**: Balance between granularity and simplicity
   - **5 Column Families**: Appropriate for this use case
   - Separates performance data (JEPES vs APES) by rank
   - Groups training and medical data separately

3. **Access Patterns**: Design based on how data is accessed
   - Group frequently accessed columns together
   - Separate rarely accessed columns into their own families

### Data Type Best Practices

1. **Numeric Values**: Store as strings, convert in queries
   - Use `TO_NUMBER()` for comparisons: `TO_NUMBER("jepes"."pft_score") >= 280`
   - Store with appropriate precision: "4.6" not "4.60000000"

2. **Boolean Values**: Store as "Y"/"N" for consistency
   - Consistent capitalization: Always use "Y" or "N"
   - Example: "Y" or "N" (not "yes", "YES", "y", "True", "true")

3. **NULL Handling**: Be explicit about NULL values
   - Use `IS NOT NULL` to filter: `WHERE "jepes"."pft_score" IS NOT NULL`
   - Remember: JEPES fields NULL for Sergeants/Officers, APES fields NULL for Junior Enlisted

4. **Conditional Queries**: Handle mutually exclusive data sources
   ```sql
   -- Query for high performers (handles both JEPES and APES)
   WHERE ("jepes"."char_score" IS NOT NULL AND TO_NUMBER("jepes"."char_score") >= 4.5)
      OR ("apes"."avg_attribute" IS NOT NULL AND TO_NUMBER("apes"."avg_attribute") >= 4.5)
   ```

### Performance Optimization

1. **Query Specific Columns**: Don't use `SELECT *` unless necessary
   ```sql
   -- Good: Query only needed columns
   SELECT "personal"."first_name", "training"."overall_ready" 
   FROM "SOLDIER_360"
   
   -- Avoid: SELECT * (unless you need all 30+ columns)
   SELECT * FROM "SOLDIER_360"
   ```

2. **Use Row Key Lookups**: Always use row key in WHERE clause when possible
   ```sql
   -- Good: Fast row key lookup
   SELECT * FROM "SOLDIER_360" WHERE "rowkey" = '1003456789'
   
   -- Slower: Full table scan
   SELECT * FROM "SOLDIER_360" WHERE "personal"."last_name" = 'Lee'
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
   describe 'SOLDIER_360'
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

The Soldier 360-Degree View use case demonstrates:
- ✅ Single wide HBase table design
- ✅ Phoenix view for SQL access
- ✅ Complete Marine profile in one row
- ✅ Fast single-row lookups using EDIPI
- ✅ No JOINs required (by design)
- ✅ Simple query patterns
- ✅ Comprehensive 360-degree Marine information
- ✅ Unified view of multiple Marine Corps systems (JEPES, APES, MCTIMS, MHS Genesis)

This design is ideal for applications that need quick access to complete Marine profiles with minimal query complexity, enabling rapid deployment readiness assessments, performance evaluations, and unit-level reporting.

