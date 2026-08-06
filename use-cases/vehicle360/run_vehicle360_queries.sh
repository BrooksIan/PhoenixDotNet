#!/bin/bash

# Vehicle 360 — Query Examples
# Type catalogs + build tables + VIN assembly JOINs.
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

run_query "Query 1: Engine type by ID (ENG001)" \
"SELECT \"rowkey\" as engine_type_id, \"specs\".\"manufacturer\", \"specs\".\"model\", \"specs\".\"horsepower\", \"specs\".\"fuel_type\" FROM \"ENGINE\" WHERE \"rowkey\" = 'ENG001'"

run_query "Query 2: Device by ID (DEV001)" \
"SELECT \"rowkey\" as device_id, \"specs\".\"name\", \"specs\".\"device_type\", \"specs\".\"manufacturer\", \"specs\".\"plant_code\", \"specs\".\"status\" FROM \"DEVICE\" WHERE \"rowkey\" = 'DEV001'"

run_query "Query 3: Engine build with type + device" \
"SELECT eb.\"rowkey\" as engine_build_id, eb.\"ids\".\"engine_type_id\", eb.\"ids\".\"device_id\", eb.\"production\".\"build_date\", eb.\"production\".\"plant_code\", eb.\"production\".\"qc_status\", e.\"specs\".\"horsepower\", d.\"specs\".\"name\" as device_name, d.\"specs\".\"device_type\" FROM \"ENGINE_BUILD\" eb JOIN \"ENGINE\" e ON eb.\"ids\".\"engine_type_id\" = e.\"rowkey\" JOIN \"DEVICE\" d ON eb.\"ids\".\"device_id\" = d.\"rowkey\" WHERE eb.\"rowkey\" = 'EB-ENG001-00001'"

run_query "Query 4: Transmission build by type (TRN001)" \
"SELECT \"rowkey\" as transmission_build_id, \"ids\".\"transmission_type_id\", \"production\".\"plant_code\", \"production\".\"serial_number\", \"production\".\"qc_status\" FROM \"TRANSMISSION_BUILD\" WHERE \"ids\".\"transmission_type_id\" = 'TRN001' ORDER BY \"rowkey\""

run_query "Query 5: Chassis build by type (CHS001)" \
"SELECT \"rowkey\" as chassis_build_id, \"ids\".\"chassis_type_id\", \"production\".\"plant_code\", \"production\".\"batch_number\", \"production\".\"qc_status\" FROM \"CHASSIS_BUILD\" WHERE \"ids\".\"chassis_type_id\" = 'CHS001' ORDER BY \"rowkey\""

run_query "Query 6: Vehicle by VIN (build IDs + info)" \
"SELECT \"rowkey\" as vin, \"info\".\"make\", \"info\".\"model\", \"info\".\"year\", \"info\".\"color\", \"info\".\"trim\", \"ids\".\"engine_build_id\", \"ids\".\"transmission_build_id\", \"ids\".\"chassis_build_id\" FROM \"VEHICLE\" WHERE \"rowkey\" = '1HGCM82633A004352'"

run_query "Query 7: List all vehicles" \
"SELECT \"rowkey\" as vin, \"info\".\"make\", \"info\".\"model\", \"info\".\"year\", \"ids\".\"engine_build_id\", \"ids\".\"transmission_build_id\", \"ids\".\"chassis_build_id\" FROM \"VEHICLE\" ORDER BY \"info\".\"make\", \"info\".\"model\""

run_query "Query 8: Complete build sheet for one VIN" \
"SELECT v.\"rowkey\" as vin, v.\"info\".\"make\", v.\"info\".\"model\", v.\"info\".\"year\", eb.\"rowkey\" as engine_build_id, e.\"specs\".\"horsepower\", ed.\"rowkey\" as engine_device_id, ed.\"specs\".\"name\" as engine_device_name, tb.\"rowkey\" as transmission_build_id, t.\"specs\".\"type\" as transmission_type, td.\"rowkey\" as transmission_device_id, td.\"specs\".\"name\" as transmission_device_name, cb.\"rowkey\" as chassis_build_id, c.\"specs\".\"body_style\", cd.\"rowkey\" as chassis_device_id, cd.\"specs\".\"name\" as chassis_device_name FROM \"VEHICLE\" v JOIN \"ENGINE_BUILD\" eb ON v.\"ids\".\"engine_build_id\" = eb.\"rowkey\" JOIN \"ENGINE\" e ON eb.\"ids\".\"engine_type_id\" = e.\"rowkey\" JOIN \"DEVICE\" ed ON eb.\"ids\".\"device_id\" = ed.\"rowkey\" JOIN \"TRANSMISSION_BUILD\" tb ON v.\"ids\".\"transmission_build_id\" = tb.\"rowkey\" JOIN \"TRANSMISSION\" t ON tb.\"ids\".\"transmission_type_id\" = t.\"rowkey\" JOIN \"DEVICE\" td ON tb.\"ids\".\"device_id\" = td.\"rowkey\" JOIN \"CHASSIS_BUILD\" cb ON v.\"ids\".\"chassis_build_id\" = cb.\"rowkey\" JOIN \"CHASSIS\" c ON cb.\"ids\".\"chassis_type_id\" = c.\"rowkey\" JOIN \"DEVICE\" cd ON cb.\"ids\".\"device_id\" = cd.\"rowkey\" WHERE v.\"rowkey\" = '1HGCM82633A004352'"

run_query "Query 9: Complete build sheet for all vehicles" \
"SELECT v.\"rowkey\" as vin, v.\"info\".\"make\", v.\"info\".\"model\", v.\"info\".\"year\", eb.\"rowkey\" as engine_build_id, e.\"specs\".\"horsepower\", ed.\"specs\".\"name\" as engine_device_name, tb.\"rowkey\" as transmission_build_id, t.\"specs\".\"type\" as transmission_type, td.\"specs\".\"name\" as transmission_device_name, cb.\"rowkey\" as chassis_build_id, c.\"specs\".\"body_style\", cd.\"specs\".\"name\" as chassis_device_name FROM \"VEHICLE\" v JOIN \"ENGINE_BUILD\" eb ON v.\"ids\".\"engine_build_id\" = eb.\"rowkey\" JOIN \"ENGINE\" e ON eb.\"ids\".\"engine_type_id\" = e.\"rowkey\" JOIN \"DEVICE\" ed ON eb.\"ids\".\"device_id\" = ed.\"rowkey\" JOIN \"TRANSMISSION_BUILD\" tb ON v.\"ids\".\"transmission_build_id\" = tb.\"rowkey\" JOIN \"TRANSMISSION\" t ON tb.\"ids\".\"transmission_type_id\" = t.\"rowkey\" JOIN \"DEVICE\" td ON tb.\"ids\".\"device_id\" = td.\"rowkey\" JOIN \"CHASSIS_BUILD\" cb ON v.\"ids\".\"chassis_build_id\" = cb.\"rowkey\" JOIN \"CHASSIS\" c ON cb.\"ids\".\"chassis_type_id\" = c.\"rowkey\" JOIN \"DEVICE\" cd ON cb.\"ids\".\"device_id\" = cd.\"rowkey\" ORDER BY v.\"info\".\"make\", v.\"info\".\"model\""

run_query "Query 10: Vehicles using engine type ENG001 (via builds)" \
"SELECT v.\"rowkey\" as vin, v.\"info\".\"make\", v.\"info\".\"model\", eb.\"rowkey\" as engine_build_id, eb.\"ids\".\"engine_type_id\" FROM \"VEHICLE\" v JOIN \"ENGINE_BUILD\" eb ON v.\"ids\".\"engine_build_id\" = eb.\"rowkey\" WHERE eb.\"ids\".\"engine_type_id\" = 'ENG001' ORDER BY v.\"rowkey\""

run_query "Query 11: VINs that used device DEV008 (any build role)" \
"SELECT v.\"rowkey\" as vin, v.\"info\".\"make\" as make, v.\"info\".\"model\" as model, v.\"info\".\"year\" as year, 'ENGINE' as build_role, eb.\"rowkey\" as build_id, eb.\"ids\".\"device_id\" as device_id, d.\"specs\".\"name\" as device_name FROM \"VEHICLE\" v JOIN \"ENGINE_BUILD\" eb ON v.\"ids\".\"engine_build_id\" = eb.\"rowkey\" JOIN \"DEVICE\" d ON eb.\"ids\".\"device_id\" = d.\"rowkey\" WHERE eb.\"ids\".\"device_id\" = 'DEV008' UNION ALL SELECT v.\"rowkey\" as vin, v.\"info\".\"make\" as make, v.\"info\".\"model\" as model, v.\"info\".\"year\" as year, 'TRANSMISSION' as build_role, tb.\"rowkey\" as build_id, tb.\"ids\".\"device_id\" as device_id, d.\"specs\".\"name\" as device_name FROM \"VEHICLE\" v JOIN \"TRANSMISSION_BUILD\" tb ON v.\"ids\".\"transmission_build_id\" = tb.\"rowkey\" JOIN \"DEVICE\" d ON tb.\"ids\".\"device_id\" = d.\"rowkey\" WHERE tb.\"ids\".\"device_id\" = 'DEV008' UNION ALL SELECT v.\"rowkey\" as vin, v.\"info\".\"make\" as make, v.\"info\".\"model\" as model, v.\"info\".\"year\" as year, 'CHASSIS' as build_role, cb.\"rowkey\" as build_id, cb.\"ids\".\"device_id\" as device_id, d.\"specs\".\"name\" as device_name FROM \"VEHICLE\" v JOIN \"CHASSIS_BUILD\" cb ON v.\"ids\".\"chassis_build_id\" = cb.\"rowkey\" JOIN \"DEVICE\" d ON cb.\"ids\".\"device_id\" = d.\"rowkey\" WHERE cb.\"ids\".\"device_id\" = 'DEV008' ORDER BY vin, build_role"

run_query "Query 12: Count vehicles per engine type" \
"SELECT eb.\"ids\".\"engine_type_id\", COUNT(*) as vehicle_count FROM \"VEHICLE\" v JOIN \"ENGINE_BUILD\" eb ON v.\"ids\".\"engine_build_id\" = eb.\"rowkey\" GROUP BY eb.\"ids\".\"engine_type_id\" ORDER BY eb.\"ids\".\"engine_type_id\""

run_query "Query 13: High-horsepower vehicles (300+ HP)" \
"SELECT v.\"rowkey\" as vin, v.\"info\".\"make\", v.\"info\".\"model\", v.\"info\".\"year\", e.\"specs\".\"horsepower\", e.\"specs\".\"fuel_type\", eb.\"rowkey\" as engine_build_id FROM \"VEHICLE\" v JOIN \"ENGINE_BUILD\" eb ON v.\"ids\".\"engine_build_id\" = eb.\"rowkey\" JOIN \"ENGINE\" e ON eb.\"ids\".\"engine_type_id\" = e.\"rowkey\" WHERE TO_NUMBER(e.\"specs\".\"horsepower\") >= 300 ORDER BY TO_NUMBER(e.\"specs\".\"horsepower\") DESC"

run_query "Query 14: Vehicles with AWD" \
"SELECT v.\"rowkey\" as vin, v.\"info\".\"make\", v.\"info\".\"model\", t.\"specs\".\"type\", t.\"specs\".\"drive_type\", tb.\"rowkey\" as transmission_build_id FROM \"VEHICLE\" v JOIN \"TRANSMISSION_BUILD\" tb ON v.\"ids\".\"transmission_build_id\" = tb.\"rowkey\" JOIN \"TRANSMISSION\" t ON tb.\"ids\".\"transmission_type_id\" = t.\"rowkey\" WHERE t.\"specs\".\"drive_type\" = 'AWD' ORDER BY v.\"info\".\"make\""

run_query "Query 15: Count vehicles per make" \
"SELECT \"info\".\"make\", COUNT(*) as vehicle_count FROM \"VEHICLE\" GROUP BY \"info\".\"make\" ORDER BY \"info\".\"make\""

run_query "Query 16: Vehicles by engine plant" \
"SELECT eb.\"production\".\"plant_code\" as engine_plant, COUNT(*) as vehicle_count FROM \"VEHICLE\" v JOIN \"ENGINE_BUILD\" eb ON v.\"ids\".\"engine_build_id\" = eb.\"rowkey\" GROUP BY eb.\"production\".\"plant_code\" ORDER BY eb.\"production\".\"plant_code\""

echo ""
echo "=========================================="
echo "Done! Vehicle 360 query examples complete."
echo "=========================================="
echo ""
echo "See also: sample_queries.sql for the full SQL collection"
echo ""
