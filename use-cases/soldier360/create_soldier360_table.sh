#!/bin/bash

# Complete Example: Create Soldier 360 HBase Native Table
# This script creates a single HBase-native table using EDIPI as the primary key,
# combining data from multiple Marine Corps systems:
# - JEPES (Junior Enlisted Performance Evaluation System)
# - APES (Automated Performance Evaluation System / Fitness Reports)
# - MCTIMS (Marine Corps Total Information Management System)
# - MHS Genesis (Medical Health System / Medical Readiness)

API_URL="http://localhost:8099/api/phoenix"
TABLE_NAME="SOLDIER_360"
VIEW_NAME="SOLDIER_360"

echo "=========================================="
echo "Create Soldier 360 HBase Table"
echo "=========================================="
echo ""

# Step 1: Create HBase Table
echo "Step 1: Creating HBase table '$TABLE_NAME' with column families..."
echo ""
docker exec -i opdb-docker /opt/hbase/bin/hbase shell <<'EOF'
create 'SOLDIER_360', 'personal', 'jepes', 'apes', 'training', 'medical'
EOF
echo ""

# Wait for table creation
sleep 2

# Step 2: Insert sample data using EDIPI as row key
echo "Step 2: Inserting sample data using EDIPI as row key..."
echo ""

# Marine 1: Junior Enlisted (JEPES data)
# EDIPI: 1002345678 - Rivas, Marco, Cpl
echo "  Inserting EDIPI 1002345678 (Rivas, Marco, Cpl)..."
docker exec -i opdb-docker /opt/hbase/bin/hbase shell <<'EOF'
# Personal Information
put 'SOLDIER_360', '1002345678', 'personal:last_name', 'Rivas'
put 'SOLDIER_360', '1002345678', 'personal:first_name', 'Marco'
put 'SOLDIER_360', '1002345678', 'personal:rank', 'Cpl'
put 'SOLDIER_360', '1002345678', 'personal:unit', '1st Bn 8th Mar'
put 'SOLDIER_360', '1002345678', 'personal:mos', '0311'

# JEPES Data (Junior Enlisted Performance)
put 'SOLDIER_360', '1002345678', 'jepes:pft_score', '285'
put 'SOLDIER_360', '1002345678', 'jepes:cft_score', '290'
put 'SOLDIER_360', '1002345678', 'jepes:rifle_qual', 'Expert'
put 'SOLDIER_360', '1002345678', 'jepes:pme_complete', 'Y'
put 'SOLDIER_360', '1002345678', 'jepes:char_score', '4.0'
put 'SOLDIER_360', '1002345678', 'jepes:mos_score', '4.5'
put 'SOLDIER_360', '1002345678', 'jepes:lead_score', '4.0'

# Training Data (MCTIMS)
put 'SOLDIER_360', '1002345678', 'training:rifle_current', 'Y'
put 'SOLDIER_360', '1002345678', 'training:pft_current', 'Y'
put 'SOLDIER_360', '1002345678', 'training:cft_current', 'Y'
put 'SOLDIER_360', '1002345678', 'training:pme_complete', 'Y'
put 'SOLDIER_360', '1002345678', 'training:annual_training_pct', '100'
put 'SOLDIER_360', '1002345678', 'training:overall_ready', 'Y'

# Medical Data (MHS Genesis)
put 'SOLDIER_360', '1002345678', 'medical:medical_status', 'Deployable'
put 'SOLDIER_360', '1002345678', 'medical:dental_class', 'Class 1'
put 'SOLDIER_360', '1002345678', 'medical:pha_current', 'Y'
put 'SOLDIER_360', '1002345678', 'medical:imr_status', 'Current'
put 'SOLDIER_360', '1002345678', 'medical:profile_status', 'None'
EOF

# Marine 2: Sergeant (APES data)
# EDIPI: 1003456789 - Lee, Sange, Sgt
echo "  Inserting EDIPI 1003456789 (Lee, Sange, Sgt)..."
docker exec -i opdb-docker /opt/hbase/bin/hbase shell <<'EOF'
# Personal Information
put 'SOLDIER_360', '1003456789', 'personal:last_name', 'Lee'
put 'SOLDIER_360', '1003456789', 'personal:first_name', 'Sange'
put 'SOLDIER_360', '1003456789', 'personal:rank', 'Sgt'
put 'SOLDIER_360', '1003456789', 'personal:unit', 'CLB-6'
put 'SOLDIER_360', '1003456789', 'personal:mos', '3531'

# APES Data (Fitness Report)
put 'SOLDIER_360', '1003456789', 'apes:report_occasion', 'Annual'
put 'SOLDIER_360', '1003456789', 'apes:avg_attribute', '4.6'
put 'SOLDIER_360', '1003456789', 'apes:pft_pass', 'Y'
put 'SOLDIER_360', '1003456789', 'apes:cft_pass', 'Y'
put 'SOLDIER_360', '1003456789', 'apes:ht_wt_pass', 'Y'
put 'SOLDIER_360', '1003456789', 'apes:rs_recommend', 'Promote'
put 'SOLDIER_360', '1003456789', 'apes:ro_recommend', 'Left of Center'

# Training Data (MCTIMS)
put 'SOLDIER_360', '1003456789', 'training:rifle_current', 'Y'
put 'SOLDIER_360', '1003456789', 'training:pft_current', 'Y'
put 'SOLDIER_360', '1003456789', 'training:cft_current', 'Y'
put 'SOLDIER_360', '1003456789', 'training:pme_complete', 'Y'
put 'SOLDIER_360', '1003456789', 'training:annual_training_pct', '100'
put 'SOLDIER_360', '1003456789', 'training:overall_ready', 'Y'

# Medical Data (MHS Genesis)
put 'SOLDIER_360', '1003456789', 'medical:medical_status', 'Deployable'
put 'SOLDIER_360', '1003456789', 'medical:dental_class', 'Class 1'
put 'SOLDIER_360', '1003456789', 'medical:pha_current', 'Y'
put 'SOLDIER_360', '1003456789', 'medical:imr_status', 'Current'
put 'SOLDIER_360', '1003456789', 'medical:profile_status', 'None'
EOF

# Marine 3: Lance Corporal (JEPES data)
# EDIPI: 1004567890 - Thompson, Aisha, LCpl
echo "  Inserting EDIPI 1004567890 (Thompson, Aisha, LCpl)..."
docker exec -i opdb-docker /opt/hbase/bin/hbase shell <<'EOF'
# Personal Information
put 'SOLDIER_360', '1004567890', 'personal:last_name', 'Thompson'
put 'SOLDIER_360', '1004567890', 'personal:first_name', 'Aisha'
put 'SOLDIER_360', '1004567890', 'personal:rank', 'LCpl'
put 'SOLDIER_360', '1004567890', 'personal:unit', 'CLB-6'
put 'SOLDIER_360', '1004567890', 'personal:mos', '0411'

# JEPES Data
put 'SOLDIER_360', '1004567890', 'jepes:pft_score', '270'
put 'SOLDIER_360', '1004567890', 'jepes:cft_score', '280'
put 'SOLDIER_360', '1004567890', 'jepes:rifle_qual', 'Sharpshooter'
put 'SOLDIER_360', '1004567890', 'jepes:pme_complete', 'Y'
put 'SOLDIER_360', '1004567890', 'jepes:char_score', '3.5'
put 'SOLDIER_360', '1004567890', 'jepes:mos_score', '4.0'
put 'SOLDIER_360', '1004567890', 'jepes:lead_score', '3.5'

# Training Data (some issues - not fully ready)
put 'SOLDIER_360', '1004567890', 'training:rifle_current', 'Y'
put 'SOLDIER_360', '1004567890', 'training:pft_current', 'N'
put 'SOLDIER_360', '1004567890', 'training:cft_current', 'Y'
put 'SOLDIER_360', '1004567890', 'training:pme_complete', 'Y'
put 'SOLDIER_360', '1004567890', 'training:annual_training_pct', '80'
put 'SOLDIER_360', '1004567890', 'training:overall_ready', 'N'

# Medical Data (non-deployable)
put 'SOLDIER_360', '1004567890', 'medical:medical_status', 'Non-Deployable'
put 'SOLDIER_360', '1004567890', 'medical:dental_class', 'Class 3'
put 'SOLDIER_360', '1004567890', 'medical:pha_current', 'Y'
put 'SOLDIER_360', '1004567890', 'medical:imr_status', 'Current'
put 'SOLDIER_360', '1004567890', 'medical:profile_status', 'None'
EOF

# Marine 4: Sergeant (APES data)
# EDIPI: 1005678901 - Davis, Jamal, Sgt
echo "  Inserting EDIPI 1005678901 (Davis, Jamal, Sgt)..."
docker exec -i opdb-docker /opt/hbase/bin/hbase shell <<'EOF'
# Personal Information
put 'SOLDIER_360', '1005678901', 'personal:last_name', 'Davis'
put 'SOLDIER_360', '1005678901', 'personal:first_name', 'Jamal'
put 'SOLDIER_360', '1005678901', 'personal:rank', 'Sgt'
put 'SOLDIER_360', '1005678901', 'personal:unit', 'HMLA-167'
put 'SOLDIER_360', '1005678901', 'personal:mos', '6111'

# APES Data
put 'SOLDIER_360', '1005678901', 'apes:report_occasion', 'Annual'
put 'SOLDIER_360', '1005678901', 'apes:avg_attribute', '4.8'
put 'SOLDIER_360', '1005678901', 'apes:pft_pass', 'Y'
put 'SOLDIER_360', '1005678901', 'apes:cft_pass', 'Y'
put 'SOLDIER_360', '1005678901', 'apes:ht_wt_pass', 'Y'
put 'SOLDIER_360', '1005678901', 'apes:rs_recommend', 'Promote Now'
put 'SOLDIER_360', '1005678901', 'apes:ro_recommend', 'Far Left'

# Training Data
put 'SOLDIER_360', '1005678901', 'training:rifle_current', 'Y'
put 'SOLDIER_360', '1005678901', 'training:pft_current', 'Y'
put 'SOLDIER_360', '1005678901', 'training:cft_current', 'Y'
put 'SOLDIER_360', '1005678901', 'training:pme_complete', 'Y'
put 'SOLDIER_360', '1005678901', 'training:annual_training_pct', '100'
put 'SOLDIER_360', '1005678901', 'training:overall_ready', 'Y'

# Medical Data
put 'SOLDIER_360', '1005678901', 'medical:medical_status', 'Deployable'
put 'SOLDIER_360', '1005678901', 'medical:dental_class', 'Class 2'
put 'SOLDIER_360', '1005678901', 'medical:pha_current', 'Y'
put 'SOLDIER_360', '1005678901', 'medical:imr_status', 'Current'
put 'SOLDIER_360', '1005678901', 'medical:profile_status', 'None'
EOF

# Marine 5: Private First Class (JEPES data)
# EDIPI: 1006789012 - Patel, Kenji, PFC
echo "  Inserting EDIPI 1006789012 (Patel, Kenji, PFC)..."
docker exec -i opdb-docker /opt/hbase/bin/hbase shell <<'EOF'
# Personal Information
put 'SOLDIER_360', '1006789012', 'personal:last_name', 'Patel'
put 'SOLDIER_360', '1006789012', 'personal:first_name', 'Kenji'
put 'SOLDIER_360', '1006789012', 'personal:rank', 'PFC'
put 'SOLDIER_360', '1006789012', 'personal:unit', '1st Bn 8th Mar'
put 'SOLDIER_360', '1006789012', 'personal:mos', '0311'

# JEPES Data
put 'SOLDIER_360', '1006789012', 'jepes:pft_score', '290'
put 'SOLDIER_360', '1006789012', 'jepes:cft_score', '300'
put 'SOLDIER_360', '1006789012', 'jepes:rifle_qual', 'Marksman'
put 'SOLDIER_360', '1006789012', 'jepes:pme_complete', 'N'
put 'SOLDIER_360', '1006789012', 'jepes:char_score', '3.0'
put 'SOLDIER_360', '1006789012', 'jepes:mos_score', '3.5'
put 'SOLDIER_360', '1006789012', 'jepes:lead_score', '3.0'

# Training Data (not ready - multiple issues)
put 'SOLDIER_360', '1006789012', 'training:rifle_current', 'N'
put 'SOLDIER_360', '1006789012', 'training:pft_current', 'Y'
put 'SOLDIER_360', '1006789012', 'training:cft_current', 'Y'
put 'SOLDIER_360', '1006789012', 'training:pme_complete', 'N'
put 'SOLDIER_360', '1006789012', 'training:annual_training_pct', '50'
put 'SOLDIER_360', '1006789012', 'training:overall_ready', 'N'

# Medical Data (non-deployable - temporary profile)
put 'SOLDIER_360', '1006789012', 'medical:medical_status', 'Non-Deployable'
put 'SOLDIER_360', '1006789012', 'medical:dental_class', 'Class 1'
put 'SOLDIER_360', '1006789012', 'medical:pha_current', 'Y'
put 'SOLDIER_360', '1006789012', 'medical:imr_status', 'Current'
put 'SOLDIER_360', '1006789012', 'medical:profile_status', 'Temporary'
EOF

# Marine 6: Staff Sergeant (APES data)
# EDIPI: 1022334455 - Evans, SSgt
echo "  Inserting EDIPI 1022334455 (Evans, SSgt)..."
docker exec -i opdb-docker /opt/hbase/bin/hbase shell <<'EOF'
# Personal Information
put 'SOLDIER_360', '1022334455', 'personal:last_name', 'Evans'
put 'SOLDIER_360', '1022334455', 'personal:first_name', ''
put 'SOLDIER_360', '1022334455', 'personal:rank', 'SSgt'
put 'SOLDIER_360', '1022334455', 'personal:unit', '3d Rad Bn'
put 'SOLDIER_360', '1022334455', 'personal:mos', ''

# APES Data
put 'SOLDIER_360', '1022334455', 'apes:report_occasion', 'Annual'
put 'SOLDIER_360', '1022334455', 'apes:avg_attribute', '4.9'
put 'SOLDIER_360', '1022334455', 'apes:pft_pass', 'Y'
put 'SOLDIER_360', '1022334455', 'apes:cft_pass', 'Y'
put 'SOLDIER_360', '1022334455', 'apes:ht_wt_pass', 'Y'
put 'SOLDIER_360', '1022334455', 'apes:rs_recommend', 'Promote Now'
put 'SOLDIER_360', '1022334455', 'apes:ro_recommend', 'Far Left'

# Training Data
put 'SOLDIER_360', '1022334455', 'training:rifle_current', 'Y'
put 'SOLDIER_360', '1022334455', 'training:pft_current', 'Y'
put 'SOLDIER_360', '1022334455', 'training:cft_current', 'Y'
put 'SOLDIER_360', '1022334455', 'training:pme_complete', 'Y'
put 'SOLDIER_360', '1022334455', 'training:annual_training_pct', '100'
put 'SOLDIER_360', '1022334455', 'training:overall_ready', 'Y'

# Medical Data (non-deployable - PHA not current)
put 'SOLDIER_360', '1022334455', 'medical:medical_status', 'Non-Deployable'
put 'SOLDIER_360', '1022334455', 'medical:dental_class', 'Class 1'
put 'SOLDIER_360', '1022334455', 'medical:pha_current', 'N'
put 'SOLDIER_360', '1022334455', 'medical:imr_status', 'Current'
put 'SOLDIER_360', '1022334455', 'medical:profile_status', 'None'
EOF

# Marine 7: Captain (APES data)
# EDIPI: 1033445566 - Kim, Capt
echo "  Inserting EDIPI 1033445566 (Kim, Capt)..."
docker exec -i opdb-docker /opt/hbase/bin/hbase shell <<'EOF'
# Personal Information
put 'SOLDIER_360', '1033445566', 'personal:last_name', 'Kim'
put 'SOLDIER_360', '1033445566', 'personal:first_name', ''
put 'SOLDIER_360', '1033445566', 'personal:rank', 'Capt'
put 'SOLDIER_360', '1033445566', 'personal:unit', '1st Bn 8th Mar'
put 'SOLDIER_360', '1033445566', 'personal:mos', ''

# APES Data
put 'SOLDIER_360', '1033445566', 'apes:report_occasion', 'Change of RS'
put 'SOLDIER_360', '1033445566', 'apes:avg_attribute', '4.7'
put 'SOLDIER_360', '1033445566', 'apes:pft_pass', 'Y'
put 'SOLDIER_360', '1033445566', 'apes:cft_pass', 'Y'
put 'SOLDIER_360', '1033445566', 'apes:ht_wt_pass', 'Y'
put 'SOLDIER_360', '1033445566', 'apes:rs_recommend', 'Promote'
put 'SOLDIER_360', '1033445566', 'apes:ro_recommend', 'Left of Center'

# Training Data (not ready - PME incomplete)
put 'SOLDIER_360', '1033445566', 'training:rifle_current', 'Y'
put 'SOLDIER_360', '1033445566', 'training:pft_current', 'Y'
put 'SOLDIER_360', '1033445566', 'training:cft_current', 'Y'
put 'SOLDIER_360', '1033445566', 'training:pme_complete', 'N'
put 'SOLDIER_360', '1033445566', 'training:annual_training_pct', '70'
put 'SOLDIER_360', '1033445566', 'training:overall_ready', 'N'

# Medical Data (non-deployable - permanent profile)
put 'SOLDIER_360', '1033445566', 'medical:medical_status', 'Non-Deployable'
put 'SOLDIER_360', '1033445566', 'medical:dental_class', 'Class 1'
put 'SOLDIER_360', '1033445566', 'medical:pha_current', 'Y'
put 'SOLDIER_360', '1033445566', 'medical:imr_status', 'Current'
put 'SOLDIER_360', '1033445566', 'medical:profile_status', 'Permanent'
EOF

echo ""
sleep 2

# Step 3: Verify data in HBase
echo "Step 3: Verifying data in HBase..."
echo ""
echo "scan 'SOLDIER_360', {LIMIT => 2}" | docker exec -i opdb-docker /opt/hbase/bin/hbase shell | grep -A 10 "ROW  COLUMN" | head -15
echo ""

# Step 4: Create Phoenix View
echo "Step 4: Creating Phoenix view '$VIEW_NAME'..."
echo ""
VIEW_RESPONSE=$(curl -s -X POST "${API_URL}/execute" \
  -H "Content-Type: application/json" \
  -d "{
     \"sql\": \"CREATE VIEW IF NOT EXISTS \\\"SOLDIER_360\\\" (\\\"rowkey\\\" VARCHAR PRIMARY KEY, \\\"personal\\\".\\\"last_name\\\" VARCHAR, \\\"personal\\\".\\\"first_name\\\" VARCHAR, \\\"personal\\\".\\\"rank\\\" VARCHAR, \\\"personal\\\".\\\"unit\\\" VARCHAR, \\\"personal\\\".\\\"mos\\\" VARCHAR, \\\"jepes\\\".\\\"pft_score\\\" VARCHAR, \\\"jepes\\\".\\\"cft_score\\\" VARCHAR, \\\"jepes\\\".\\\"rifle_qual\\\" VARCHAR, \\\"jepes\\\".\\\"pme_complete\\\" VARCHAR, \\\"jepes\\\".\\\"char_score\\\" VARCHAR, \\\"jepes\\\".\\\"mos_score\\\" VARCHAR, \\\"jepes\\\".\\\"lead_score\\\" VARCHAR, \\\"apes\\\".\\\"report_occasion\\\" VARCHAR, \\\"apes\\\".\\\"avg_attribute\\\" VARCHAR, \\\"apes\\\".\\\"pft_pass\\\" VARCHAR, \\\"apes\\\".\\\"cft_pass\\\" VARCHAR, \\\"apes\\\".\\\"ht_wt_pass\\\" VARCHAR, \\\"apes\\\".\\\"rs_recommend\\\" VARCHAR, \\\"apes\\\".\\\"ro_recommend\\\" VARCHAR, \\\"training\\\".\\\"rifle_current\\\" VARCHAR, \\\"training\\\".\\\"pft_current\\\" VARCHAR, \\\"training\\\".\\\"cft_current\\\" VARCHAR, \\\"training\\\".\\\"pme_complete\\\" VARCHAR, \\\"training\\\".\\\"annual_training_pct\\\" VARCHAR, \\\"training\\\".\\\"overall_ready\\\" VARCHAR, \\\"medical\\\".\\\"medical_status\\\" VARCHAR, \\\"medical\\\".\\\"dental_class\\\" VARCHAR, \\\"medical\\\".\\\"pha_current\\\" VARCHAR, \\\"medical\\\".\\\"imr_status\\\" VARCHAR, \\\"medical\\\".\\\"profile_status\\\" VARCHAR)\"
  }")

echo "$VIEW_RESPONSE" | jq .
echo ""

# Wait for view to be registered
sleep 3

# Step 5: Query the Phoenix View
echo "Step 5: Querying the Phoenix view..."
echo ""
QUERY_RESPONSE=$(curl -s -X POST "${API_URL}/query" \
  -H "Content-Type: application/json" \
  -d "{
    \"sql\": \"SELECT * FROM \\\"${VIEW_NAME}\\\" ORDER BY rowkey\"
  }")

echo "Row count: $(echo "$QUERY_RESPONSE" | jq '.rowCount')"
echo ""
echo "$QUERY_RESPONSE" | jq '.rows[] | {edipi: .rowkey, last_name: .last_name, first_name: .first_name, rank: .rank, unit: .unit, ready: .overall_ready, medical: .medical_status}'
echo ""

# Step 6: Example Query - Marines not ready for deployment
echo "Step 6: Example query - Marines not ready for deployment..."
echo ""
FILTER_RESPONSE=$(curl -s -X POST "${API_URL}/query" \
  -H "Content-Type: application/json" \
  -d "{
    \"sql\": \"SELECT * FROM \\\"${VIEW_NAME}\\\" WHERE overall_ready = '\''N'\'' OR medical_status = '\''Non-Deployable'\'' ORDER BY rowkey\"
  }")

echo "Marines not ready: $(echo "$FILTER_RESPONSE" | jq '.rowCount')"
echo ""
echo "$FILTER_RESPONSE" | jq '.rows[] | {edipi: .rowkey, name: .last_name, rank: .rank, unit: .unit, training_ready: .overall_ready, medical_status: .medical_status, dental: .dental_class, training_pct: .annual_training_pct}'
echo ""

# Step 7: Example Query - High performers (APES or JEPES)
echo "Step 7: Example query - High performers..."
echo ""
PERFORMER_RESPONSE=$(curl -s -X POST "${API_URL}/query" \
  -H "Content-Type: application/json" \
  -d "{
    \"sql\": \"SELECT * FROM \\\"${VIEW_NAME}\\\" WHERE ro_recommend = '\''Far Left'\'' OR (CAST(avg_attribute AS DOUBLE) >= 4.5) OR (CAST(char_score AS DOUBLE) >= 4.5) ORDER BY rowkey\"
  }")

echo "High performers: $(echo "$PERFORMER_RESPONSE" | jq '.rowCount')"
echo ""
echo "$PERFORMER_RESPONSE" | jq '.rows[] | {edipi: .rowkey, name: .last_name, rank: .rank, ro_recommend: .ro_recommend, avg_attribute: .avg_attribute, char_score: .char_score}'
echo ""

echo "=========================================="
echo "Done! Soldier 360 table created."
echo "=========================================="
echo ""
echo "Table: $TABLE_NAME"
echo "Primary Key: EDIPI (rowkey)"
echo "Column Families:"
echo "  - personal: Name, Rank, Unit, MOS"
echo "  - jepes: Junior Enlisted Performance data"
echo "  - apes: Fitness Report data (Sergeants/Officers)"
echo "  - training: MCTIMS training & readiness data"
echo "  - medical: MHS Genesis medical readiness data"
echo ""
echo "You can now query the view using:"
echo "  curl -X POST ${API_URL}/query -H 'Content-Type: application/json' \\"
echo "    -d '{\"sql\": \"SELECT * FROM ${VIEW_NAME} WHERE rowkey = '\''1003456789'\''\"}' | jq ."
echo ""

