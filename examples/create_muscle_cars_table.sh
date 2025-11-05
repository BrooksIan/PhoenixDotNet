#!/bin/bash

# Complete Example: Create HBase Native Table for Muscle Cars
# This script demonstrates creating an HBase-native table, inserting data,
# and creating a Phoenix view to query it via SQL

API_URL="http://localhost:8099/api/phoenix"
TABLE_NAME="MUSCLE_CARS"
VIEW_NAME="MUSCLE_CARS"

echo "=========================================="
echo "Create Muscle Cars Table and Phoenix View"
echo "=========================================="
echo ""

# Step 1: Create HBase Table
echo "Step 1: Creating HBase table '$TABLE_NAME' with column families..."
echo ""
docker exec -i opdb-docker /opt/hbase/bin/hbase shell <<'EOF'
create 'MUSCLE_CARS', 'info', 'specs', 'details'
EOF
echo ""

# Wait for table creation
sleep 2

# Step 2: Insert 10 rows of muscle car data
echo "Step 2: Inserting 10 rows of muscle car data..."
echo ""
docker exec -i opdb-docker /opt/hbase/bin/hbase shell <<'EOF'
put 'MUSCLE_CARS', '1', 'info:manufacturer', 'Ford'
put 'MUSCLE_CARS', '1', 'info:model', 'Mustang'
put 'MUSCLE_CARS', '1', 'info:year', '2024'
put 'MUSCLE_CARS', '1', 'specs:engine', '5.0L V8'
put 'MUSCLE_CARS', '1', 'specs:hp', '450'
put 'MUSCLE_CARS', '1', 'specs:torque', '410'
put 'MUSCLE_CARS', '1', 'details:price', '42000'
put 'MUSCLE_CARS', '1', 'details:color', 'Grabber Blue'

put 'MUSCLE_CARS', '2', 'info:manufacturer', 'Chevrolet'
put 'MUSCLE_CARS', '2', 'info:model', 'Camaro'
put 'MUSCLE_CARS', '2', 'info:year', '2024'
put 'MUSCLE_CARS', '2', 'specs:engine', '6.2L V8'
put 'MUSCLE_CARS', '2', 'specs:hp', '455'
put 'MUSCLE_CARS', '2', 'specs:torque', '455'
put 'MUSCLE_CARS', '2', 'details:price', '38000'
put 'MUSCLE_CARS', '2', 'details:color', 'Rally Green'

put 'MUSCLE_CARS', '3', 'info:manufacturer', 'Dodge'
put 'MUSCLE_CARS', '3', 'info:model', 'Challenger'
put 'MUSCLE_CARS', '3', 'info:year', '2023'
put 'MUSCLE_CARS', '3', 'specs:engine', '6.4L V8'
put 'MUSCLE_CARS', '3', 'specs:hp', '485'
put 'MUSCLE_CARS', '3', 'specs:torque', '475'
put 'MUSCLE_CARS', '3', 'details:price', '45000'
put 'MUSCLE_CARS', '3', 'details:color', 'Hellraisin'

put 'MUSCLE_CARS', '4', 'info:manufacturer', 'Ford'
put 'MUSCLE_CARS', '4', 'info:model', 'Shelby GT500'
put 'MUSCLE_CARS', '4', 'info:year', '2024'
put 'MUSCLE_CARS', '4', 'specs:engine', '5.2L Supercharged V8'
put 'MUSCLE_CARS', '4', 'specs:hp', '760'
put 'MUSCLE_CARS', '4', 'specs:torque', '625'
put 'MUSCLE_CARS', '4', 'details:price', '78000'
put 'MUSCLE_CARS', '4', 'details:color', 'Twister Orange'

put 'MUSCLE_CARS', '5', 'info:manufacturer', 'Chevrolet'
put 'MUSCLE_CARS', '5', 'info:model', 'Corvette'
put 'MUSCLE_CARS', '5', 'info:year', '2024'
put 'MUSCLE_CARS', '5', 'specs:engine', '6.2L V8'
put 'MUSCLE_CARS', '5', 'specs:hp', '495'
put 'MUSCLE_CARS', '5', 'specs:torque', '470'
put 'MUSCLE_CARS', '5', 'details:price', '65000'
put 'MUSCLE_CARS', '5', 'details:color', 'Arctic White'

put 'MUSCLE_CARS', '6', 'info:manufacturer', 'Dodge'
put 'MUSCLE_CARS', '6', 'info:model', 'Charger'
put 'MUSCLE_CARS', '6', 'info:year', '2024'
put 'MUSCLE_CARS', '6', 'specs:engine', '6.4L V8'
put 'MUSCLE_CARS', '6', 'specs:hp', '485'
put 'MUSCLE_CARS', '6', 'specs:torque', '475'
put 'MUSCLE_CARS', '6', 'details:price', '44000'
put 'MUSCLE_CARS', '6', 'details:color', 'F8 Green'

put 'MUSCLE_CARS', '7', 'info:manufacturer', 'Chevrolet'
put 'MUSCLE_CARS', '7', 'info:model', 'Camaro ZL1'
put 'MUSCLE_CARS', '7', 'info:year', '2024'
put 'MUSCLE_CARS', '7', 'specs:engine', '6.2L Supercharged V8'
put 'MUSCLE_CARS', '7', 'specs:hp', '650'
put 'MUSCLE_CARS', '7', 'specs:torque', '650'
put 'MUSCLE_CARS', '7', 'details:price', '72000'
put 'MUSCLE_CARS', '7', 'details:color', 'Shock Yellow'

put 'MUSCLE_CARS', '8', 'info:manufacturer', 'Ford'
put 'MUSCLE_CARS', '8', 'info:model', 'Mustang GT'
put 'MUSCLE_CARS', '8', 'info:year', '2023'
put 'MUSCLE_CARS', '8', 'specs:engine', '5.0L V8'
put 'MUSCLE_CARS', '8', 'specs:hp', '450'
put 'MUSCLE_CARS', '8', 'specs:torque', '410'
put 'MUSCLE_CARS', '8', 'details:price', '39000'
put 'MUSCLE_CARS', '8', 'details:color', 'Race Red'

put 'MUSCLE_CARS', '9', 'info:manufacturer', 'Dodge'
put 'MUSCLE_CARS', '9', 'info:model', 'Challenger SRT'
put 'MUSCLE_CARS', '9', 'info:year', '2024'
put 'MUSCLE_CARS', '9', 'specs:engine', '6.4L V8'
put 'MUSCLE_CARS', '9', 'specs:hp', '485'
put 'MUSCLE_CARS', '9', 'specs:torque', '475'
put 'MUSCLE_CARS', '9', 'details:price', '47000'
put 'MUSCLE_CARS', '9', 'details:color', 'Plum Crazy'

put 'MUSCLE_CARS', '10', 'info:manufacturer', 'Chevrolet'
put 'MUSCLE_CARS', '10', 'info:model', 'Camaro SS'
put 'MUSCLE_CARS', '10', 'info:year', '2024'
put 'MUSCLE_CARS', '10', 'specs:engine', '6.2L V8'
put 'MUSCLE_CARS', '10', 'specs:hp', '455'
put 'MUSCLE_CARS', '10', 'specs:torque', '455'
put 'MUSCLE_CARS', '10', 'details:price', '41000'
put 'MUSCLE_CARS', '10', 'details:color', 'Rapid Blue'
EOF
echo ""

# Wait for data to be committed
sleep 2

# Step 3: Verify data in HBase
echo "Step 3: Verifying data in HBase..."
echo ""
echo "scan 'MUSCLE_CARS', {LIMIT => 3}" | docker exec -i opdb-docker /opt/hbase/bin/hbase shell | grep -A 5 "ROW  COLUMN" | head -10
echo ""

# Step 4: Create Phoenix View
echo "Step 4: Creating Phoenix view '$VIEW_NAME'..."
echo ""
VIEW_RESPONSE=$(curl -s -X POST "${API_URL}/execute" \
  -H "Content-Type: application/json" \
  -d "{
     \"sql\": \"CREATE VIEW IF NOT EXISTS \\\"MUSCLE_CARS\\\" (\\\"rowkey\\\" VARCHAR PRIMARY KEY, \\\"info\\\".\\\"manufacturer\\\" VARCHAR, \\\"info\\\".\\\"model\\\" VARCHAR, \\\"info\\\".\\\"year\\\" VARCHAR, \\\"specs\\\".\\\"engine\\\" VARCHAR, \\\"specs\\\".\\\"hp\\\" VARCHAR, \\\"specs\\\".\\\"torque\\\" VARCHAR, \\\"details\\\".\\\"price\\\" VARCHAR, \\\"details\\\".\\\"color\\\" VARCHAR)\"
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
     \"sql\": \"SELECT * FROM ${VIEW_NAME} ORDER BY rowkey\"
  }")

echo "$QUERY_RESPONSE" | jq '.rowCount'
echo "$QUERY_RESPONSE" | jq '.rows[] | {rowkey, manufacturer, model, year, engine, hp, price, color}'
echo ""

# Step 6: Example Query - Filter by HP
echo "Step 6: Example query - Cars with HP > 450..."
echo ""
FILTER_RESPONSE=$(curl -s -X POST "${API_URL}/query" \
  -H "Content-Type: application/json" \
  -d "{
     \"sql\": \"SELECT rowkey, manufacturer, model, hp, price FROM ${VIEW_NAME} WHERE hp > '\''450'\'' ORDER BY hp DESC\"
  }")

echo "$FILTER_RESPONSE" | jq '.rows[] | {manufacturer, model, hp, price}'
echo ""

echo "=========================================="
echo "Done! Muscle cars table and view created."
echo "=========================================="
echo ""
echo "You can now query the view using:"
echo "  curl -X POST ${API_URL}/query -H 'Content-Type: application/json' -d '{\"sql\": \"SELECT * FROM ${VIEW_NAME}\"}' | jq ."

