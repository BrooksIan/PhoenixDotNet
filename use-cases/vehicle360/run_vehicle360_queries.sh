#!/bin/bash

# Vehicle 360 — Query Examples
# Runs Phoenix SQL examples against ENGINE, TRANSMISSION, CHASSIS, and VEHICLE.
# Prerequisite: tables and views already created (./create_vehicle360_tables.sh)

set -euo pipefail

API_URL="http://localhost:8099/api/phoenix"

run_query() {
  local title="$1"
  local sql="$2"

  echo ""
  echo "=========================================="
  echo "$title"
  echo "=========================================="

  local payload
  payload=$(jq -n --arg sql "$sql" '{sql: $sql}')

  curl -s -X POST "${API_URL}/query" \
    -H "Content-Type: application/json" \
    -d "$payload" | jq '{rowCount, rows}'
}

echo "=========================================="
echo "Vehicle 360 Query Examples"
echo "=========================================="
echo "API: ${API_URL}"

# ----------------------------------------------------------
# Component lookups
# ----------------------------------------------------------

run_query "Query 1: Engine by ID (ENG001)" \
"SELECT \"rowkey\" as engine_id, \"specs\".\"manufacturer\", \"specs\".\"model\", \"specs\".\"horsepower\", \"specs\".\"fuel_type\" FROM \"ENGINE\" WHERE \"rowkey\" = 'ENG001'"

run_query "Query 2: Transmission by ID (TRN002)" \
"SELECT \"rowkey\" as transmission_id, \"specs\".\"manufacturer\", \"specs\".\"model\", \"specs\".\"type\", \"specs\".\"drive_type\" FROM \"TRANSMISSION\" WHERE \"rowkey\" = 'TRN002'"

run_query "Query 3: Chassis by ID (CHS003)" \
"SELECT \"rowkey\" as chassis_id, \"specs\".\"body_style\", \"specs\".\"material\", \"specs\".\"doors\", \"specs\".\"curb_weight_lb\" FROM \"CHASSIS\" WHERE \"rowkey\" = 'CHS003'"

# ----------------------------------------------------------
# Vehicle lookups
# ----------------------------------------------------------

run_query "Query 4: Vehicle by VIN (IDs + info only)" \
"SELECT \"rowkey\" as vin, \"info\".\"make\", \"info\".\"model\", \"info\".\"year\", \"info\".\"color\", \"info\".\"trim\", \"ids\".\"engine_id\", \"ids\".\"transmission_id\", \"ids\".\"chassis_id\" FROM \"VEHICLE\" WHERE \"rowkey\" = '1HGCM82633A004352'"

run_query "Query 5: List all vehicles" \
"SELECT \"rowkey\" as vin, \"info\".\"make\", \"info\".\"model\", \"info\".\"year\", \"ids\".\"engine_id\", \"ids\".\"transmission_id\", \"ids\".\"chassis_id\" FROM \"VEHICLE\" ORDER BY \"info\".\"make\", \"info\".\"model\""

# ----------------------------------------------------------
# Complete vehicle view (JOINs)
# ----------------------------------------------------------

run_query "Query 6: Complete vehicle view for one VIN" \
"SELECT v.\"rowkey\" as vin, v.\"info\".\"make\", v.\"info\".\"model\", v.\"info\".\"year\", e.\"specs\".\"horsepower\", t.\"specs\".\"type\", t.\"specs\".\"drive_type\", c.\"specs\".\"body_style\" FROM \"VEHICLE\" v JOIN \"ENGINE\" e ON v.\"ids\".\"engine_id\" = e.\"rowkey\" JOIN \"TRANSMISSION\" t ON v.\"ids\".\"transmission_id\" = t.\"rowkey\" JOIN \"CHASSIS\" c ON v.\"ids\".\"chassis_id\" = c.\"rowkey\" WHERE v.\"rowkey\" = '1HGCM82633A004352'"

run_query "Query 7: Complete vehicle view for all vehicles" \
"SELECT v.\"rowkey\" as vin, v.\"info\".\"make\", v.\"info\".\"model\", v.\"info\".\"year\", e.\"specs\".\"horsepower\", t.\"specs\".\"type\", t.\"specs\".\"drive_type\", c.\"specs\".\"body_style\" FROM \"VEHICLE\" v JOIN \"ENGINE\" e ON v.\"ids\".\"engine_id\" = e.\"rowkey\" JOIN \"TRANSMISSION\" t ON v.\"ids\".\"transmission_id\" = t.\"rowkey\" JOIN \"CHASSIS\" c ON v.\"ids\".\"chassis_id\" = c.\"rowkey\" ORDER BY v.\"info\".\"make\", v.\"info\".\"model\""

run_query "Query 8: Detailed complete vehicle view (all component fields)" \
"SELECT v.\"rowkey\" as vin, v.\"info\".\"make\", v.\"info\".\"model\", v.\"info\".\"year\", v.\"info\".\"color\", v.\"info\".\"trim\", e.\"rowkey\" as engine_id, e.\"specs\".\"manufacturer\" as engine_mfr, e.\"specs\".\"model\" as engine_model, e.\"specs\".\"horsepower\", e.\"specs\".\"fuel_type\", t.\"rowkey\" as transmission_id, t.\"specs\".\"type\" as transmission_type, t.\"specs\".\"gears\", t.\"specs\".\"drive_type\", c.\"rowkey\" as chassis_id, c.\"specs\".\"body_style\", c.\"specs\".\"material\", c.\"specs\".\"doors\" FROM \"VEHICLE\" v JOIN \"ENGINE\" e ON v.\"ids\".\"engine_id\" = e.\"rowkey\" JOIN \"TRANSMISSION\" t ON v.\"ids\".\"transmission_id\" = t.\"rowkey\" JOIN \"CHASSIS\" c ON v.\"ids\".\"chassis_id\" = c.\"rowkey\" WHERE v.\"rowkey\" = '1HGCM82633A004352'"

# ----------------------------------------------------------
# Component reuse
# ----------------------------------------------------------

run_query "Query 9: Vehicles using engine ENG001" \
"SELECT \"rowkey\" as vin, \"info\".\"make\", \"info\".\"model\", \"info\".\"year\", \"ids\".\"engine_id\" FROM \"VEHICLE\" WHERE \"ids\".\"engine_id\" = 'ENG001' ORDER BY \"rowkey\""

run_query "Query 10: Count vehicles per engine" \
"SELECT \"ids\".\"engine_id\", COUNT(*) as vehicle_count FROM \"VEHICLE\" GROUP BY \"ids\".\"engine_id\" ORDER BY \"ids\".\"engine_id\""

# ----------------------------------------------------------
# Filters and aggregations
# ----------------------------------------------------------

run_query "Query 11: High-horsepower vehicles (300+ HP)" \
"SELECT v.\"rowkey\" as vin, v.\"info\".\"make\", v.\"info\".\"model\", v.\"info\".\"year\", e.\"specs\".\"horsepower\", e.\"specs\".\"fuel_type\" FROM \"VEHICLE\" v JOIN \"ENGINE\" e ON v.\"ids\".\"engine_id\" = e.\"rowkey\" WHERE TO_NUMBER(e.\"specs\".\"horsepower\") >= 300 ORDER BY TO_NUMBER(e.\"specs\".\"horsepower\") DESC"

run_query "Query 12: Vehicles with AWD" \
"SELECT v.\"rowkey\" as vin, v.\"info\".\"make\", v.\"info\".\"model\", t.\"specs\".\"type\", t.\"specs\".\"drive_type\" FROM \"VEHICLE\" v JOIN \"TRANSMISSION\" t ON v.\"ids\".\"transmission_id\" = t.\"rowkey\" WHERE t.\"specs\".\"drive_type\" = 'AWD' ORDER BY v.\"info\".\"make\""

run_query "Query 13: Count vehicles per make" \
"SELECT \"info\".\"make\", COUNT(*) as vehicle_count FROM \"VEHICLE\" GROUP BY \"info\".\"make\" ORDER BY \"info\".\"make\""

run_query "Query 14: Count vehicles per transmission type" \
"SELECT t.\"specs\".\"type\" as transmission_type, COUNT(*) as vehicle_count FROM \"VEHICLE\" v JOIN \"TRANSMISSION\" t ON v.\"ids\".\"transmission_id\" = t.\"rowkey\" GROUP BY t.\"specs\".\"type\" ORDER BY t.\"specs\".\"type\""

echo ""
echo "=========================================="
echo "Done! Vehicle 360 query examples complete."
echo "=========================================="
echo ""
echo "See also: sample_queries.sql for the full SQL collection"
echo ""
