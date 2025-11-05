#!/bin/bash

# Create Single 360-Degree Student View
# This script creates a single wide HBase table that combines all student information
# into one row per student, then creates a Phoenix view for SQL access.
# All student data (demographics, academics, services) is in a single row.

API_URL="http://localhost:8099/api/phoenix"
TABLE_NAME="STUDENT_360"
VIEW_NAME="STUDENT_360"

echo "=========================================="
echo "Create Single 360-Degree Student View"
echo "=========================================="
echo ""

# Step 1: Create Single Wide HBase Table
echo "Step 1: Creating single wide HBase table '$TABLE_NAME'..."
echo ""

docker exec -i opdb-docker /opt/hbase/bin/hbase shell <<'EOF'
create 'STUDENT_360', 
  'personal',      # Personal information
  'contact',       # Contact information
  'demographic',   # Demographic and enrollment data
  'enrollment',    # Current course enrollments
  'grades',        # Historical grades and transcripts
  'performance',   # GPA, test scores, achievements
  'requirements',  # Graduation requirements progress
  'attendance',    # Attendance records and statistics
  'support',       # Support services and interventions
  'counseling',    # Counseling sessions and notes
  'financial',     # Financial aid and payment information
  'activities'     # Extracurricular activities and clubs
EOF

echo ""
sleep 2

# Step 2: Insert Sample Data - All student info in single row
echo "Step 2: Inserting sample data (all info in one row per student)..."
echo ""

# Student 1: John Doe - Complete 360-degree data in single row
echo "  Inserting data for STU001 (John Doe)..."
docker exec -i opdb-docker /opt/hbase/bin/hbase shell <<'EOF'
# Personal Information
put 'STUDENT_360', 'STU001', 'personal:first_name', 'John'
put 'STUDENT_360', 'STU001', 'personal:last_name', 'Doe'
put 'STUDENT_360', 'STU001', 'personal:middle_name', 'Michael'
put 'STUDENT_360', 'STU001', 'personal:date_of_birth', '2005-03-15'
put 'STUDENT_360', 'STU001', 'personal:gender', 'M'

# Contact Information
put 'STUDENT_360', 'STU001', 'contact:email', 'john.doe@school.edu'
put 'STUDENT_360', 'STU001', 'contact:phone', '555-1234'
put 'STUDENT_360', 'STU001', 'contact:address_line1', '123 Main St'
put 'STUDENT_360', 'STU001', 'contact:city', 'Springfield'
put 'STUDENT_360', 'STU001', 'contact:state', 'IL'
put 'STUDENT_360', 'STU001', 'contact:zip', '62701'

# Demographic Information
put 'STUDENT_360', 'STU001', 'demographic:enrollment_date', '2023-09-01'
put 'STUDENT_360', 'STU001', 'demographic:grade_level', '10'
put 'STUDENT_360', 'STU001', 'demographic:status', 'Active'
put 'STUDENT_360', 'STU001', 'demographic:ethnicity', 'Hispanic'

# Enrollment Information
put 'STUDENT_360', 'STU001', 'enrollment:current_courses', 'MATH101,ENG101,SCI101'
put 'STUDENT_360', 'STU001', 'enrollment:semester', 'Fall2024'
put 'STUDENT_360', 'STU001', 'enrollment:credits_attempted', '15'
put 'STUDENT_360', 'STU001', 'enrollment:credits_completed', '12'

# Grades
put 'STUDENT_360', 'STU001', 'grades:course_MATH101', 'A'
put 'STUDENT_360', 'STU001', 'grades:course_ENG101', 'B+'
put 'STUDENT_360', 'STU001', 'grades:course_SCI101', 'A-'
put 'STUDENT_360', 'STU001', 'grades:semester_Fall2024_GPA', '3.67'

# Performance
put 'STUDENT_360', 'STU001', 'performance:cumulative_GPA', '3.75'
put 'STUDENT_360', 'STU001', 'performance:SAT_score', '1450'
put 'STUDENT_360', 'STU001', 'performance:ACT_score', '32'

# Requirements
put 'STUDENT_360', 'STU001', 'requirements:credits_earned', '45'
put 'STUDENT_360', 'STU001', 'requirements:credits_required', '120'
put 'STUDENT_360', 'STU001', 'requirements:graduation_year', '2026'

# Attendance
put 'STUDENT_360', 'STU001', 'attendance:days_present', '165'
put 'STUDENT_360', 'STU001', 'attendance:days_absent', '5'
put 'STUDENT_360', 'STU001', 'attendance:days_tardy', '3'
put 'STUDENT_360', 'STU001', 'attendance:attendance_rate', '97.1'

# Support Services
put 'STUDENT_360', 'STU001', 'support:services', 'Tutoring,ESL Support'
put 'STUDENT_360', 'STU001', 'support:interventions', 'Math Intervention Program'
put 'STUDENT_360', 'STU001', 'support:special_education', 'No'

# Counseling
put 'STUDENT_360', 'STU001', 'counseling:last_session', '2024-10-15'
put 'STUDENT_360', 'STU001', 'counseling:total_sessions', '12'
put 'STUDENT_360', 'STU001', 'counseling:concerns', 'College Planning'

# Financial
put 'STUDENT_360', 'STU001', 'financial:aid_status', 'Pell Grant,Work Study'
put 'STUDENT_360', 'STU001', 'financial:aid_amount', '8500'
put 'STUDENT_360', 'STU001', 'financial:payment_status', 'Current'

# Activities
put 'STUDENT_360', 'STU001', 'activities:clubs', 'Debate,Math Club'
put 'STUDENT_360', 'STU001', 'activities:sports', 'Soccer'
put 'STUDENT_360', 'STU001', 'activities:volunteer_hours', '45'
EOF

# Student 2: Jane Smith
echo "  Inserting data for STU002 (Jane Smith)..."
docker exec -i opdb-docker /opt/hbase/bin/hbase shell <<'EOF'
put 'STUDENT_360', 'STU002', 'personal:first_name', 'Jane'
put 'STUDENT_360', 'STU002', 'personal:last_name', 'Smith'
put 'STUDENT_360', 'STU002', 'personal:date_of_birth', '2006-07-22'
put 'STUDENT_360', 'STU002', 'personal:gender', 'F'
put 'STUDENT_360', 'STU002', 'contact:email', 'jane.smith@school.edu'
put 'STUDENT_360', 'STU002', 'contact:phone', '555-5678'
put 'STUDENT_360', 'STU002', 'demographic:enrollment_date', '2023-09-01'
put 'STUDENT_360', 'STU002', 'demographic:grade_level', '9'
put 'STUDENT_360', 'STU002', 'demographic:status', 'Active'
put 'STUDENT_360', 'STU002', 'enrollment:current_courses', 'MATH090,ENG090,SCI090'
put 'STUDENT_360', 'STU002', 'enrollment:semester', 'Fall2024'
put 'STUDENT_360', 'STU002', 'grades:course_MATH090', 'C+'
put 'STUDENT_360', 'STU002', 'grades:course_ENG090', 'B-'
put 'STUDENT_360', 'STU002', 'performance:cumulative_GPA', '2.45'
put 'STUDENT_360', 'STU002', 'requirements:credits_earned', '25'
put 'STUDENT_360', 'STU002', 'requirements:credits_required', '120'
put 'STUDENT_360', 'STU002', 'attendance:days_present', '150'
put 'STUDENT_360', 'STU002', 'attendance:days_absent', '20'
put 'STUDENT_360', 'STU002', 'attendance:attendance_rate', '88.2'
put 'STUDENT_360', 'STU002', 'support:services', 'Tutoring,Study Hall'
put 'STUDENT_360', 'STU002', 'counseling:last_session', '2024-11-01'
put 'STUDENT_360', 'STU002', 'counseling:total_sessions', '8'
put 'STUDENT_360', 'STU002', 'financial:aid_status', 'Pell Grant'
put 'STUDENT_360', 'STU002', 'financial:aid_amount', '6500'
EOF

# Student 3: Bob Johnson
echo "  Inserting data for STU003 (Bob Johnson)..."
docker exec -i opdb-docker /opt/hbase/bin/hbase shell <<'EOF'
put 'STUDENT_360', 'STU003', 'personal:first_name', 'Bob'
put 'STUDENT_360', 'STU003', 'personal:last_name', 'Johnson'
put 'STUDENT_360', 'STU003', 'personal:date_of_birth', '2004-11-08'
put 'STUDENT_360', 'STU003', 'personal:gender', 'M'
put 'STUDENT_360', 'STU003', 'contact:email', 'bob.johnson@school.edu'
put 'STUDENT_360', 'STU003', 'demographic:enrollment_date', '2022-09-01'
put 'STUDENT_360', 'STU003', 'demographic:grade_level', '12'
put 'STUDENT_360', 'STU003', 'demographic:status', 'Active'
put 'STUDENT_360', 'STU003', 'enrollment:current_courses', 'MATH201,ENG201,SCI201,HIST201'
put 'STUDENT_360', 'STU003', 'enrollment:semester', 'Fall2024'
put 'STUDENT_360', 'STU003', 'grades:course_MATH201', 'A'
put 'STUDENT_360', 'STU003', 'grades:course_ENG201', 'A'
put 'STUDENT_360', 'STU003', 'performance:cumulative_GPA', '3.95'
put 'STUDENT_360', 'STU003', 'performance:SAT_score', '1580'
put 'STUDENT_360', 'STU003', 'performance:ACT_score', '36'
put 'STUDENT_360', 'STU003', 'requirements:credits_earned', '110'
put 'STUDENT_360', 'STU003', 'requirements:credits_required', '120'
put 'STUDENT_360', 'STU003', 'attendance:days_present', '170'
put 'STUDENT_360', 'STU003', 'attendance:days_absent', '0'
put 'STUDENT_360', 'STU003', 'attendance:attendance_rate', '100.0'
put 'STUDENT_360', 'STU003', 'activities:clubs', 'National Honor Society,Debate'
put 'STUDENT_360', 'STU003', 'activities:sports', 'Track and Field'
put 'STUDENT_360', 'STU003', 'activities:volunteer_hours', '120'
put 'STUDENT_360', 'STU003', 'financial:aid_status', 'Scholarship,Merit Award'
put 'STUDENT_360', 'STU003', 'financial:aid_amount', '12000'
EOF

echo ""
sleep 2

# Step 3: Create Single Phoenix View
echo "Step 3: Creating single Phoenix view '$VIEW_NAME'..."
echo ""

# Create view with properly escaped JSON (single line)
curl -s -X POST "${API_URL}/execute" \
  -H "Content-Type: application/json" \
  -d '{"sql": "CREATE VIEW IF NOT EXISTS \"STUDENT_360\" (\"rowkey\" VARCHAR PRIMARY KEY, \"personal\".\"first_name\" VARCHAR, \"personal\".\"last_name\" VARCHAR, \"personal\".\"middle_name\" VARCHAR, \"personal\".\"date_of_birth\" VARCHAR, \"personal\".\"gender\" VARCHAR, \"contact\".\"email\" VARCHAR, \"contact\".\"phone\" VARCHAR, \"contact\".\"address_line1\" VARCHAR, \"contact\".\"city\" VARCHAR, \"contact\".\"state\" VARCHAR, \"contact\".\"zip\" VARCHAR, \"demographic\".\"enrollment_date\" VARCHAR, \"demographic\".\"grade_level\" VARCHAR, \"demographic\".\"status\" VARCHAR, \"demographic\".\"ethnicity\" VARCHAR, \"enrollment\".\"current_courses\" VARCHAR, \"enrollment\".\"semester\" VARCHAR, \"enrollment\".\"credits_attempted\" VARCHAR, \"enrollment\".\"credits_completed\" VARCHAR, \"grades\".\"course_MATH101\" VARCHAR, \"grades\".\"course_ENG101\" VARCHAR, \"grades\".\"course_SCI101\" VARCHAR, \"grades\".\"semester_Fall2024_GPA\" VARCHAR, \"performance\".\"cumulative_GPA\" VARCHAR, \"performance\".\"SAT_score\" VARCHAR, \"performance\".\"ACT_score\" VARCHAR, \"requirements\".\"credits_earned\" VARCHAR, \"requirements\".\"credits_required\" VARCHAR, \"requirements\".\"graduation_year\" VARCHAR, \"attendance\".\"days_present\" VARCHAR, \"attendance\".\"days_absent\" VARCHAR, \"attendance\".\"days_tardy\" VARCHAR, \"attendance\".\"attendance_rate\" VARCHAR, \"support\".\"services\" VARCHAR, \"support\".\"interventions\" VARCHAR, \"support\".\"special_education\" VARCHAR, \"counseling\".\"last_session\" VARCHAR, \"counseling\".\"total_sessions\" VARCHAR, \"counseling\".\"concerns\" VARCHAR, \"financial\".\"aid_status\" VARCHAR, \"financial\".\"aid_amount\" VARCHAR, \"financial\".\"payment_status\" VARCHAR, \"activities\".\"clubs\" VARCHAR, \"activities\".\"sports\" VARCHAR, \"activities\".\"volunteer_hours\" VARCHAR)"}' | jq .

echo ""
sleep 3

# Step 4: Query Examples - Single Row 360-Degree View
echo "Step 4: Example queries - All student info in single row..."
echo ""

echo "Query 1: Complete student profile (single row) - STU001"
echo "=========================================="
curl -s -X POST "${API_URL}/query" \
  -H "Content-Type: application/json" \
  -d '{
    "sql": "SELECT * FROM \"STUDENT_360\" WHERE \"rowkey\" = '\''STU001'\''"
  }' | jq '.rows[]'

echo ""
echo "Query 2: Student summary (key fields only)"
echo "=========================================="
curl -s -X POST "${API_URL}/query" \
  -H "Content-Type: application/json" \
  -d '{
    "sql": "SELECT \"rowkey\" as student_id, \"personal\".\"first_name\", \"personal\".\"last_name\", \"contact\".\"email\", \"demographic\".\"grade_level\", \"performance\".\"cumulative_GPA\", \"attendance\".\"attendance_rate\" FROM \"STUDENT_360\" WHERE \"rowkey\" = '\''STU001'\''"
  }' | jq '.rows[]'

echo ""
echo "Query 3: All students with high GPA (complete profile in one row)"
echo "=========================================="
curl -s -X POST "${API_URL}/query" \
  -H "Content-Type: application/json" \
  -d '{
    "sql": "SELECT \"rowkey\" as student_id, \"personal\".\"first_name\", \"personal\".\"last_name\", \"demographic\".\"grade_level\", \"performance\".\"cumulative_GPA\", \"performance\".\"SAT_score\", \"attendance\".\"attendance_rate\", \"activities\".\"clubs\" FROM \"STUDENT_360\" WHERE CAST(\"performance\".\"cumulative_GPA\" AS DOUBLE) >= 3.5 ORDER BY CAST(\"performance\".\"cumulative_GPA\" AS DOUBLE) DESC"
  }' | jq '.rows[]'

echo ""
echo "Query 4: Students needing support (all info in one row)"
echo "=========================================="
curl -s -X POST "${API_URL}/query" \
  -H "Content-Type: application/json" \
  -d '{
    "sql": "SELECT \"rowkey\" as student_id, \"personal\".\"first_name\", \"personal\".\"last_name\", \"performance\".\"cumulative_GPA\", \"attendance\".\"days_absent\", \"support\".\"services\" FROM \"STUDENT_360\" WHERE CAST(\"performance\".\"cumulative_GPA\" AS DOUBLE) < 2.5 OR CAST(\"attendance\".\"days_absent\" AS INTEGER) > 15"
  }' | jq '.rows[]'

echo ""
echo "Query 5: All students - complete 360-degree view"
echo "=========================================="
curl -s -X POST "${API_URL}/query" \
  -H "Content-Type: application/json" \
  -d '{
    "sql": "SELECT \"rowkey\" as student_id, \"personal\".\"first_name\", \"personal\".\"last_name\", \"contact\".\"email\", \"demographic\".\"grade_level\", \"performance\".\"cumulative_GPA\", \"attendance\".\"attendance_rate\", \"support\".\"services\", \"financial\".\"aid_status\" FROM \"STUDENT_360\" ORDER BY \"rowkey\""
  }' | jq '.rows[]'

echo ""
echo "=========================================="
echo "Done! Single 360-degree student view created."
echo "=========================================="
echo ""
echo "All student information is now in a single row per student!"
echo ""
echo "Example queries:"
echo "  # Get complete student profile (single row)"
echo "  curl -X POST ${API_URL}/query -H 'Content-Type: application/json' \\"
echo "    -d '{\"sql\": \"SELECT * FROM STUDENT_360 WHERE rowkey = '\''STU001'\''\"}' | jq ."
echo ""
echo "  # Get all students"
echo "  curl -X POST ${API_URL}/query -H 'Content-Type: application/json' \\"
echo "    -d '{\"sql\": \"SELECT rowkey, personal.first_name, personal.last_name, performance.cumulative_GPA FROM STUDENT_360\"}' | jq ."


