#!/bin/bash

# Complete Example: Create 360-Degree Student View with 3 HBase Native Tables
# This script demonstrates creating 3 HBase-native tables for a comprehensive student view:
# 1. STUDENT_DEMOGRAPHICS - Personal and contact information
# 2. STUDENT_ACADEMICS - Academic records, grades, GPA
# 3. STUDENT_SERVICES - Support services, attendance, counseling, financial

API_URL="http://localhost:8099/api/phoenix"

echo "=========================================="
echo "Create 360-Degree Student View Tables"
echo "=========================================="
echo ""

# Step 1: Create HBase Tables
echo "Step 1: Creating HBase tables..."
echo ""

echo "  Creating STUDENT_DEMOGRAPHICS..."
docker exec -i opdb-docker /opt/hbase/bin/hbase shell <<'EOF'
create 'STUDENT_DEMOGRAPHICS', 'personal', 'contact', 'demographic'
EOF

echo "  Creating STUDENT_ACADEMICS..."
docker exec -i opdb-docker /opt/hbase/bin/hbase shell <<'EOF'
create 'STUDENT_ACADEMICS', 'enrollment', 'grades', 'performance', 'requirements'
EOF

echo "  Creating STUDENT_SERVICES..."
docker exec -i opdb-docker /opt/hbase/bin/hbase shell <<'EOF'
create 'STUDENT_SERVICES', 'attendance', 'support', 'counseling', 'financial', 'activities'
EOF

echo ""
sleep 2

# Step 2: Insert Sample Data for 3 Students
echo "Step 2: Inserting sample data for 3 students..."
echo ""

# Student 1: John Doe
echo "  Inserting data for STU001 (John Doe)..."
docker exec -i opdb-docker /opt/hbase/bin/hbase shell <<'EOF'
# Demographics
put 'STUDENT_DEMOGRAPHICS', 'STU001', 'personal:first_name', 'John'
put 'STUDENT_DEMOGRAPHICS', 'STU001', 'personal:last_name', 'Doe'
put 'STUDENT_DEMOGRAPHICS', 'STU001', 'personal:middle_name', 'Michael'
put 'STUDENT_DEMOGRAPHICS', 'STU001', 'personal:date_of_birth', '2005-03-15'
put 'STUDENT_DEMOGRAPHICS', 'STU001', 'personal:gender', 'M'
put 'STUDENT_DEMOGRAPHICS', 'STU001', 'contact:email', 'john.doe@school.edu'
put 'STUDENT_DEMOGRAPHICS', 'STU001', 'contact:phone', '555-1234'
put 'STUDENT_DEMOGRAPHICS', 'STU001', 'contact:address_line1', '123 Main St'
put 'STUDENT_DEMOGRAPHICS', 'STU001', 'contact:city', 'Springfield'
put 'STUDENT_DEMOGRAPHICS', 'STU001', 'contact:state', 'IL'
put 'STUDENT_DEMOGRAPHICS', 'STU001', 'contact:zip', '62701'
put 'STUDENT_DEMOGRAPHICS', 'STU001', 'demographic:enrollment_date', '2023-09-01'
put 'STUDENT_DEMOGRAPHICS', 'STU001', 'demographic:grade_level', '10'
put 'STUDENT_DEMOGRAPHICS', 'STU001', 'demographic:status', 'Active'
put 'STUDENT_DEMOGRAPHICS', 'STU001', 'demographic:ethnicity', 'Hispanic'

# Academics
put 'STUDENT_ACADEMICS', 'STU001', 'enrollment:current_courses', 'MATH101,ENG101,SCI101'
put 'STUDENT_ACADEMICS', 'STU001', 'enrollment:semester', 'Fall2024'
put 'STUDENT_ACADEMICS', 'STU001', 'enrollment:credits_attempted', '15'
put 'STUDENT_ACADEMICS', 'STU001', 'enrollment:credits_completed', '12'
put 'STUDENT_ACADEMICS', 'STU001', 'grades:course_MATH101', 'A'
put 'STUDENT_ACADEMICS', 'STU001', 'grades:course_ENG101', 'B+'
put 'STUDENT_ACADEMICS', 'STU001', 'grades:course_SCI101', 'A-'
put 'STUDENT_ACADEMICS', 'STU001', 'grades:semester_Fall2024_GPA', '3.67'
put 'STUDENT_ACADEMICS', 'STU001', 'performance:cumulative_GPA', '3.75'
put 'STUDENT_ACADEMICS', 'STU001', 'performance:SAT_score', '1450'
put 'STUDENT_ACADEMICS', 'STU001', 'performance:ACT_score', '32'
put 'STUDENT_ACADEMICS', 'STU001', 'requirements:credits_earned', '45'
put 'STUDENT_ACADEMICS', 'STU001', 'requirements:credits_required', '120'
put 'STUDENT_ACADEMICS', 'STU001', 'requirements:graduation_year', '2026'

# Services
put 'STUDENT_SERVICES', 'STU001', 'attendance:days_present', '165'
put 'STUDENT_SERVICES', 'STU001', 'attendance:days_absent', '5'
put 'STUDENT_SERVICES', 'STU001', 'attendance:days_tardy', '3'
put 'STUDENT_SERVICES', 'STU001', 'attendance:attendance_rate', '97.1'
put 'STUDENT_SERVICES', 'STU001', 'support:services', 'Tutoring,ESL Support'
put 'STUDENT_SERVICES', 'STU001', 'support:interventions', 'Math Intervention Program'
put 'STUDENT_SERVICES', 'STU001', 'support:special_education', 'No'
put 'STUDENT_SERVICES', 'STU001', 'counseling:last_session', '2024-10-15'
put 'STUDENT_SERVICES', 'STU001', 'counseling:total_sessions', '12'
put 'STUDENT_SERVICES', 'STU001', 'counseling:concerns', 'College Planning'
put 'STUDENT_SERVICES', 'STU001', 'financial:aid_status', 'Pell Grant,Work Study'
put 'STUDENT_SERVICES', 'STU001', 'financial:aid_amount', '8500'
put 'STUDENT_SERVICES', 'STU001', 'financial:payment_status', 'Current'
put 'STUDENT_SERVICES', 'STU001', 'activities:clubs', 'Debate,Math Club'
put 'STUDENT_SERVICES', 'STU001', 'activities:sports', 'Soccer'
put 'STUDENT_SERVICES', 'STU001', 'activities:volunteer_hours', '45'
EOF

# Student 2: Jane Smith
echo "  Inserting data for STU002 (Jane Smith)..."
docker exec -i opdb-docker /opt/hbase/bin/hbase shell <<'EOF'
# Demographics
put 'STUDENT_DEMOGRAPHICS', 'STU002', 'personal:first_name', 'Jane'
put 'STUDENT_DEMOGRAPHICS', 'STU002', 'personal:last_name', 'Smith'
put 'STUDENT_DEMOGRAPHICS', 'STU002', 'personal:date_of_birth', '2006-07-22'
put 'STUDENT_DEMOGRAPHICS', 'STU002', 'personal:gender', 'F'
put 'STUDENT_DEMOGRAPHICS', 'STU002', 'contact:email', 'jane.smith@school.edu'
put 'STUDENT_DEMOGRAPHICS', 'STU002', 'contact:phone', '555-5678'
put 'STUDENT_DEMOGRAPHICS', 'STU002', 'demographic:enrollment_date', '2023-09-01'
put 'STUDENT_DEMOGRAPHICS', 'STU002', 'demographic:grade_level', '9'
put 'STUDENT_DEMOGRAPHICS', 'STU002', 'demographic:status', 'Active'

# Academics
put 'STUDENT_ACADEMICS', 'STU002', 'enrollment:current_courses', 'MATH090,ENG090,SCI090'
put 'STUDENT_ACADEMICS', 'STU002', 'enrollment:semester', 'Fall2024'
put 'STUDENT_ACADEMICS', 'STU002', 'grades:course_MATH090', 'C+'
put 'STUDENT_ACADEMICS', 'STU002', 'grades:course_ENG090', 'B-'
put 'STUDENT_ACADEMICS', 'STU002', 'performance:cumulative_GPA', '2.45'
put 'STUDENT_ACADEMICS', 'STU002', 'requirements:credits_earned', '25'
put 'STUDENT_ACADEMICS', 'STU002', 'requirements:credits_required', '120'

# Services
put 'STUDENT_SERVICES', 'STU002', 'attendance:days_present', '150'
put 'STUDENT_SERVICES', 'STU002', 'attendance:days_absent', '20'
put 'STUDENT_SERVICES', 'STU002', 'attendance:attendance_rate', '88.2'
put 'STUDENT_SERVICES', 'STU002', 'support:services', 'Tutoring,Study Hall'
put 'STUDENT_SERVICES', 'STU002', 'counseling:last_session', '2024-11-01'
put 'STUDENT_SERVICES', 'STU002', 'counseling:total_sessions', '8'
put 'STUDENT_SERVICES', 'STU002', 'financial:aid_status', 'Pell Grant'
put 'STUDENT_SERVICES', 'STU002', 'financial:aid_amount', '6500'
EOF

# Student 3: Bob Johnson
echo "  Inserting data for STU003 (Bob Johnson)..."
docker exec -i opdb-docker /opt/hbase/bin/hbase shell <<'EOF'
# Demographics
put 'STUDENT_DEMOGRAPHICS', 'STU003', 'personal:first_name', 'Bob'
put 'STUDENT_DEMOGRAPHICS', 'STU003', 'personal:last_name', 'Johnson'
put 'STUDENT_DEMOGRAPHICS', 'STU003', 'personal:date_of_birth', '2004-11-08'
put 'STUDENT_DEMOGRAPHICS', 'STU003', 'personal:gender', 'M'
put 'STUDENT_DEMOGRAPHICS', 'STU003', 'contact:email', 'bob.johnson@school.edu'
put 'STUDENT_DEMOGRAPHICS', 'STU003', 'demographic:enrollment_date', '2022-09-01'
put 'STUDENT_DEMOGRAPHICS', 'STU003', 'demographic:grade_level', '12'
put 'STUDENT_DEMOGRAPHICS', 'STU003', 'demographic:status', 'Active'

# Academics
put 'STUDENT_ACADEMICS', 'STU003', 'enrollment:current_courses', 'MATH201,ENG201,SCI201,HIST201'
put 'STUDENT_ACADEMICS', 'STU003', 'enrollment:semester', 'Fall2024'
put 'STUDENT_ACADEMICS', 'STU003', 'grades:course_MATH201', 'A'
put 'STUDENT_ACADEMICS', 'STU003', 'grades:course_ENG201', 'A'
put 'STUDENT_ACADEMICS', 'STU003', 'performance:cumulative_GPA', '3.95'
put 'STUDENT_ACADEMICS', 'STU003', 'performance:SAT_score', '1580'
put 'STUDENT_ACADEMICS', 'STU003', 'performance:ACT_score', '36'
put 'STUDENT_ACADEMICS', 'STU003', 'requirements:credits_earned', '110'
put 'STUDENT_ACADEMICS', 'STU003', 'requirements:credits_required', '120'

# Services
put 'STUDENT_SERVICES', 'STU003', 'attendance:days_present', '170'
put 'STUDENT_SERVICES', 'STU003', 'attendance:days_absent', '0'
put 'STUDENT_SERVICES', 'STU003', 'attendance:attendance_rate', '100.0'
put 'STUDENT_SERVICES', 'STU003', 'activities:clubs', 'National Honor Society,Debate'
put 'STUDENT_SERVICES', 'STU003', 'activities:sports', 'Track and Field'
put 'STUDENT_SERVICES', 'STU003', 'activities:volunteer_hours', '120'
put 'STUDENT_SERVICES', 'STU003', 'financial:aid_status', 'Scholarship,Merit Award'
put 'STUDENT_SERVICES', 'STU003', 'financial:aid_amount', '12000'
EOF

echo ""
sleep 2

# Step 3: Create Phoenix Views
echo "Step 3: Creating Phoenix views..."
echo ""

echo "  Creating STUDENT_DEMOGRAPHICS view..."
curl -s -X POST "${API_URL}/execute" \
  -H "Content-Type: application/json" \
  -d '{"sql": "CREATE VIEW IF NOT EXISTS \"STUDENT_DEMOGRAPHICS\" (\"rowkey\" VARCHAR PRIMARY KEY, \"personal\".\"first_name\" VARCHAR, \"personal\".\"last_name\" VARCHAR, \"personal\".\"middle_name\" VARCHAR, \"personal\".\"date_of_birth\" VARCHAR, \"personal\".\"gender\" VARCHAR, \"contact\".\"email\" VARCHAR, \"contact\".\"phone\" VARCHAR, \"contact\".\"address_line1\" VARCHAR, \"contact\".\"city\" VARCHAR, \"contact\".\"state\" VARCHAR, \"contact\".\"zip\" VARCHAR, \"demographic\".\"enrollment_date\" VARCHAR, \"demographic\".\"grade_level\" VARCHAR, \"demographic\".\"status\" VARCHAR, \"demographic\".\"ethnicity\" VARCHAR)"}' | jq .

echo ""
echo "  Creating STUDENT_ACADEMICS view..."
curl -s -X POST "${API_URL}/execute" \
  -H "Content-Type: application/json" \
  -d '{"sql": "CREATE VIEW IF NOT EXISTS \"STUDENT_ACADEMICS\" (\"rowkey\" VARCHAR PRIMARY KEY, \"enrollment\".\"current_courses\" VARCHAR, \"enrollment\".\"semester\" VARCHAR, \"enrollment\".\"credits_attempted\" VARCHAR, \"enrollment\".\"credits_completed\" VARCHAR, \"grades\".\"course_MATH101\" VARCHAR, \"grades\".\"course_ENG101\" VARCHAR, \"grades\".\"course_SCI101\" VARCHAR, \"grades\".\"semester_Fall2024_GPA\" VARCHAR, \"performance\".\"cumulative_GPA\" VARCHAR, \"performance\".\"SAT_score\" VARCHAR, \"performance\".\"ACT_score\" VARCHAR, \"requirements\".\"credits_earned\" VARCHAR, \"requirements\".\"credits_required\" VARCHAR, \"requirements\".\"graduation_year\" VARCHAR)"}' | jq .

echo ""
echo "  Creating STUDENT_SERVICES view..."
curl -s -X POST "${API_URL}/execute" \
  -H "Content-Type: application/json" \
  -d '{"sql": "CREATE VIEW IF NOT EXISTS \"STUDENT_SERVICES\" (\"rowkey\" VARCHAR PRIMARY KEY, \"attendance\".\"days_present\" VARCHAR, \"attendance\".\"days_absent\" VARCHAR, \"attendance\".\"days_tardy\" VARCHAR, \"attendance\".\"attendance_rate\" VARCHAR, \"support\".\"services\" VARCHAR, \"support\".\"interventions\" VARCHAR, \"support\".\"special_education\" VARCHAR, \"counseling\".\"last_session\" VARCHAR, \"counseling\".\"total_sessions\" VARCHAR, \"counseling\".\"concerns\" VARCHAR, \"financial\".\"aid_status\" VARCHAR, \"financial\".\"aid_amount\" VARCHAR, \"financial\".\"payment_status\" VARCHAR, \"activities\".\"clubs\" VARCHAR, \"activities\".\"sports\" VARCHAR, \"activities\".\"volunteer_hours\" VARCHAR)"}' | jq .

echo ""
sleep 3

# Verify views were created
echo "Verifying view creation..."
VIEWS_CHECK=$(curl -s "${API_URL}/views" | jq -r '.rows[] | select(.TABLE_NAME | test("STUDENT_"; "i")) | .TABLE_NAME' | sort)
EXPECTED_VIEWS="STUDENT_ACADEMICS
STUDENT_DEMOGRAPHICS
STUDENT_SERVICES"

if [ "$VIEWS_CHECK" = "$EXPECTED_VIEWS" ]; then
  echo "✓ All 3 views created successfully!"
  echo "  - STUDENT_DEMOGRAPHICS"
  echo "  - STUDENT_ACADEMICS"
  echo "  - STUDENT_SERVICES"
else
  echo "✗ Warning: Some views may not have been created. Found:"
  echo "$VIEWS_CHECK"
fi
echo ""

# Step 4: Query Examples
echo "Step 4: Example queries..."
echo ""

echo "Query 1: Complete student profile (360-degree view)"
echo "=========================================="
curl -s -X POST "${API_URL}/query" \
  -H "Content-Type: application/json" \
  -d '{
    "sql": "SELECT d.\"rowkey\" as student_id, d.\"personal\".\"first_name\", d.\"personal\".\"last_name\", d.\"contact\".\"email\", d.\"demographic\".\"grade_level\", a.\"performance\".\"cumulative_GPA\", s.\"attendance\".\"attendance_rate\" FROM \"STUDENT_DEMOGRAPHICS\" d LEFT JOIN \"STUDENT_ACADEMICS\" a ON d.\"rowkey\" = a.\"rowkey\" LEFT JOIN \"STUDENT_SERVICES\" s ON d.\"rowkey\" = s.\"rowkey\" WHERE d.\"rowkey\" = '\''STU001'\''"
  }' | jq '.rows[]'

echo ""
echo "Query 2: Students with high GPA"
echo "=========================================="
curl -s -X POST "${API_URL}/query" \
  -H "Content-Type: application/json" \
  -d '{
    "sql": "SELECT d.\"rowkey\" as student_id, d.\"personal\".\"first_name\", d.\"personal\".\"last_name\", a.\"performance\".\"cumulative_GPA\", a.\"performance\".\"SAT_score\" FROM \"STUDENT_DEMOGRAPHICS\" d INNER JOIN \"STUDENT_ACADEMICS\" a ON d.\"rowkey\" = a.\"rowkey\" WHERE CAST(a.\"performance\".\"cumulative_GPA\" AS DOUBLE) >= 3.5 ORDER BY CAST(a.\"performance\".\"cumulative_GPA\" AS DOUBLE) DESC"
  }' | jq '.rows[]'

echo ""
echo "Query 3: Students needing support (low GPA or high absences)"
echo "=========================================="
curl -s -X POST "${API_URL}/query" \
  -H "Content-Type: application/json" \
  -d '{
    "sql": "SELECT d.\"rowkey\" as student_id, d.\"personal\".\"first_name\", d.\"personal\".\"last_name\", a.\"performance\".\"cumulative_GPA\", s.\"attendance\".\"days_absent\", s.\"support\".\"services\" FROM \"STUDENT_DEMOGRAPHICS\" d INNER JOIN \"STUDENT_ACADEMICS\" a ON d.\"rowkey\" = a.\"rowkey\" INNER JOIN \"STUDENT_SERVICES\" s ON d.\"rowkey\" = s.\"rowkey\" WHERE CAST(a.\"performance\".\"cumulative_GPA\" AS DOUBLE) < 2.5 OR CAST(s.\"attendance\".\"days_absent\" AS INTEGER) > 15"
  }' | jq '.rows[]'

echo ""
echo "=========================================="
echo "Done! 360-degree student view tables created."
echo "=========================================="
echo ""
echo "You can now query the views using:"
echo "  - STUDENT_DEMOGRAPHICS"
echo "  - STUDENT_ACADEMICS"
echo "  - STUDENT_SERVICES"
echo ""
echo "Example: Get complete student profile"
echo "  curl -X POST ${API_URL}/query -H 'Content-Type: application/json' \\"
echo "    -d '{\"sql\": \"SELECT * FROM STUDENT_DEMOGRAPHICS WHERE rowkey = '\''STU001'\''\"}' | jq ."

