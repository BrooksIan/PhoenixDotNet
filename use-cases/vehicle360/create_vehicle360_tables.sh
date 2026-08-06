#!/bin/bash

# Vehicle 360 — Type catalogs + devices + per-unit builds + VIN assembly
# Type tables:  ENGINE, TRANSMISSION, CHASSIS
# Devices:      DEVICE (shared manufacturing equipment catalog)
# Build tables: ENGINE_BUILD, TRANSMISSION_BUILD, CHASSIS_BUILD (production + device_id)
# Assembly:     VEHICLE (VIN → engine_build_id, transmission_build_id, chassis_build_id)
#
# Defaults match the local docker-compose stack. Override via flags or env vars.

set -euo pipefail

API_URL="${API_URL:-http://localhost:8099/api/phoenix}"
HBASE_CONTAINER="${HBASE_CONTAINER:-opdb-docker}"
HBASE_BIN="${HBASE_BIN:-/opt/hbase/bin/hbase}"
DOCKER_BIN="${DOCKER_BIN:-docker}"
WAIT_SECONDS="${WAIT_SECONDS:-2}"
SKIP_VIEWS=false
SKIP_QUERIES=false
RECREATE=false

usage() {
  cat <<EOF
Usage: $(basename "$0") [options]

Create Vehicle 360 type catalogs, build tables, seed data, and Phoenix views.

Options:
  --api-url URL          Phoenix REST API base URL (default: ${API_URL})
  --container NAME       Docker container (default: ${HBASE_CONTAINER})
  --hbase-bin PATH       HBase binary in container (default: ${HBASE_BIN})
  --docker BIN           Docker CLI (default: ${DOCKER_BIN})
  --wait SECONDS         Wait after create/load (default: ${WAIT_SECONDS})
  --recreate             Drop existing Vehicle 360 tables/views first
  --skip-views           Skip Phoenix view creation
  --skip-queries         Skip example queries
  -h, --help             Show this help
EOF
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --api-url) API_URL="$2"; shift 2 ;;
    --container) HBASE_CONTAINER="$2"; shift 2 ;;
    --hbase-bin) HBASE_BIN="$2"; shift 2 ;;
    --docker) DOCKER_BIN="$2"; shift 2 ;;
    --wait) WAIT_SECONDS="$2"; shift 2 ;;
    --recreate) RECREATE=true; shift ;;
    --skip-views) SKIP_VIEWS=true; shift ;;
    --skip-queries) SKIP_QUERIES=true; shift ;;
    -h|--help) usage; exit 0 ;;
    *) echo "Unknown option: $1" >&2; usage >&2; exit 1 ;;
  esac
done

hbase_shell() {
  "$DOCKER_BIN" exec -i "$HBASE_CONTAINER" "$HBASE_BIN" shell
}

echo "=========================================="
echo "Create Vehicle 360 HBase Tables"
echo "=========================================="
echo "API URL:       ${API_URL}"
echo "Container:     ${HBASE_CONTAINER}"
echo "HBase binary:  ${HBASE_BIN}"
echo "Recreate:      ${RECREATE}"
echo ""

if ! command -v "$DOCKER_BIN" >/dev/null 2>&1; then
  echo "ERROR: Docker binary not found: ${DOCKER_BIN}" >&2
  exit 1
fi

if ! "$DOCKER_BIN" inspect "$HBASE_CONTAINER" >/dev/null 2>&1; then
  echo "ERROR: Docker container not found: ${HBASE_CONTAINER}" >&2
  exit 1
fi

if [[ "$RECREATE" == true ]]; then
  echo "Dropping existing Vehicle 360 Phoenix views (if any)..."
  for v in VEHICLE ENGINE_BUILD TRANSMISSION_BUILD CHASSIS_BUILD ENGINE TRANSMISSION CHASSIS DEVICE; do
    curl -s -X POST "${API_URL}/execute" -H "Content-Type: application/json" \
      -d "{\"sql\": \"DROP VIEW IF EXISTS \\\"${v}\\\"\"}" >/dev/null || true
  done
  echo "Dropping existing Vehicle 360 HBase tables (if any)..."
  hbase_shell <<'EOF' || true
disable 'VEHICLE'
drop 'VEHICLE'
disable 'ENGINE_BUILD'
drop 'ENGINE_BUILD'
disable 'TRANSMISSION_BUILD'
drop 'TRANSMISSION_BUILD'
disable 'CHASSIS_BUILD'
drop 'CHASSIS_BUILD'
disable 'ENGINE'
drop 'ENGINE'
disable 'TRANSMISSION'
drop 'TRANSMISSION'
disable 'CHASSIS'
drop 'CHASSIS'
disable 'DEVICE'
drop 'DEVICE'
EOF
  echo ""
  sleep "$WAIT_SECONDS"
fi

echo "Step 1: Creating HBase type + device + build tables..."
echo ""

echo "  Creating type catalogs..."
hbase_shell <<'EOF'
create 'ENGINE', 'specs'
create 'TRANSMISSION', 'specs'
create 'CHASSIS', 'specs'
EOF

echo "  Creating DEVICE catalog..."
hbase_shell <<'EOF'
create 'DEVICE', 'specs'
EOF

echo "  Creating build tables..."
hbase_shell <<'EOF'
create 'ENGINE_BUILD', 'ids', 'production'
create 'TRANSMISSION_BUILD', 'ids', 'production'
create 'CHASSIS_BUILD', 'ids', 'production'
EOF

echo "  Creating VEHICLE..."
hbase_shell <<'EOF'
create 'VEHICLE', 'ids', 'info'
EOF

echo ""
sleep "$WAIT_SECONDS"

echo "Step 2: Inserting type catalogs + devices..."
echo ""

echo "  Engines (ENG001-ENG005)..."
hbase_shell <<'EOF'
put 'ENGINE', 'ENG001', 'specs:manufacturer', 'Honda'
put 'ENGINE', 'ENG001', 'specs:model', 'K24Z7'
put 'ENGINE', 'ENG001', 'specs:displacement_l', '2.4'
put 'ENGINE', 'ENG001', 'specs:cylinders', '4'
put 'ENGINE', 'ENG001', 'specs:horsepower', '185'
put 'ENGINE', 'ENG001', 'specs:fuel_type', 'Gasoline'
put 'ENGINE', 'ENG002', 'specs:manufacturer', 'Toyota'
put 'ENGINE', 'ENG002', 'specs:model', '2GR-FE'
put 'ENGINE', 'ENG002', 'specs:displacement_l', '3.5'
put 'ENGINE', 'ENG002', 'specs:cylinders', '6'
put 'ENGINE', 'ENG002', 'specs:horsepower', '268'
put 'ENGINE', 'ENG002', 'specs:fuel_type', 'Gasoline'
put 'ENGINE', 'ENG003', 'specs:manufacturer', 'Ford'
put 'ENGINE', 'ENG003', 'specs:model', 'EcoBoost 2.3'
put 'ENGINE', 'ENG003', 'specs:displacement_l', '2.3'
put 'ENGINE', 'ENG003', 'specs:cylinders', '4'
put 'ENGINE', 'ENG003', 'specs:horsepower', '310'
put 'ENGINE', 'ENG003', 'specs:fuel_type', 'Gasoline'
put 'ENGINE', 'ENG004', 'specs:manufacturer', 'BMW'
put 'ENGINE', 'ENG004', 'specs:model', 'B58B30'
put 'ENGINE', 'ENG004', 'specs:displacement_l', '3.0'
put 'ENGINE', 'ENG004', 'specs:cylinders', '6'
put 'ENGINE', 'ENG004', 'specs:horsepower', '382'
put 'ENGINE', 'ENG004', 'specs:fuel_type', 'Gasoline'
put 'ENGINE', 'ENG005', 'specs:manufacturer', 'Tesla'
put 'ENGINE', 'ENG005', 'specs:model', 'Dual Motor'
put 'ENGINE', 'ENG005', 'specs:displacement_l', '0'
put 'ENGINE', 'ENG005', 'specs:cylinders', '0'
put 'ENGINE', 'ENG005', 'specs:horsepower', '670'
put 'ENGINE', 'ENG005', 'specs:fuel_type', 'Electric'
EOF

echo "  Transmissions (TRN001-TRN004)..."
hbase_shell <<'EOF'
put 'TRANSMISSION', 'TRN001', 'specs:manufacturer', 'Honda'
put 'TRANSMISSION', 'TRN001', 'specs:model', 'CVT-7'
put 'TRANSMISSION', 'TRN001', 'specs:type', 'CVT'
put 'TRANSMISSION', 'TRN001', 'specs:gears', '0'
put 'TRANSMISSION', 'TRN001', 'specs:drive_type', 'FWD'
put 'TRANSMISSION', 'TRN002', 'specs:manufacturer', 'Aisin'
put 'TRANSMISSION', 'TRN002', 'specs:model', 'U660E'
put 'TRANSMISSION', 'TRN002', 'specs:type', 'Automatic'
put 'TRANSMISSION', 'TRN002', 'specs:gears', '6'
put 'TRANSMISSION', 'TRN002', 'specs:drive_type', 'AWD'
put 'TRANSMISSION', 'TRN003', 'specs:manufacturer', 'Getrag'
put 'TRANSMISSION', 'TRN003', 'specs:model', 'MT82'
put 'TRANSMISSION', 'TRN003', 'specs:type', 'Manual'
put 'TRANSMISSION', 'TRN003', 'specs:gears', '6'
put 'TRANSMISSION', 'TRN003', 'specs:drive_type', 'RWD'
put 'TRANSMISSION', 'TRN004', 'specs:manufacturer', 'ZF'
put 'TRANSMISSION', 'TRN004', 'specs:model', '8HP50'
put 'TRANSMISSION', 'TRN004', 'specs:type', 'Automatic'
put 'TRANSMISSION', 'TRN004', 'specs:gears', '8'
put 'TRANSMISSION', 'TRN004', 'specs:drive_type', 'RWD'
EOF

echo "  Chassis (CHS001-CHS004)..."
hbase_shell <<'EOF'
put 'CHASSIS', 'CHS001', 'specs:body_style', 'Sedan'
put 'CHASSIS', 'CHS001', 'specs:material', 'Steel'
put 'CHASSIS', 'CHS001', 'specs:wheelbase_in', '106.3'
put 'CHASSIS', 'CHS001', 'specs:curb_weight_lb', '3200'
put 'CHASSIS', 'CHS001', 'specs:doors', '4'
put 'CHASSIS', 'CHS002', 'specs:body_style', 'SUV'
put 'CHASSIS', 'CHS002', 'specs:material', 'Steel'
put 'CHASSIS', 'CHS002', 'specs:wheelbase_in', '112.2'
put 'CHASSIS', 'CHS002', 'specs:curb_weight_lb', '4100'
put 'CHASSIS', 'CHS002', 'specs:doors', '4'
put 'CHASSIS', 'CHS003', 'specs:body_style', 'Coupe'
put 'CHASSIS', 'CHS003', 'specs:material', 'Aluminum'
put 'CHASSIS', 'CHS003', 'specs:wheelbase_in', '107.1'
put 'CHASSIS', 'CHS003', 'specs:curb_weight_lb', '3700'
put 'CHASSIS', 'CHS003', 'specs:doors', '2'
put 'CHASSIS', 'CHS004', 'specs:body_style', 'Hatchback'
put 'CHASSIS', 'CHS004', 'specs:material', 'Aluminum'
put 'CHASSIS', 'CHS004', 'specs:wheelbase_in', '113.8'
put 'CHASSIS', 'CHS004', 'specs:curb_weight_lb', '4500'
put 'CHASSIS', 'CHS004', 'specs:doors', '4'
EOF

echo "  Devices (DEV001-DEV012)..."
hbase_shell <<'EOF'
put 'DEVICE', 'DEV001', 'specs:name', 'K24 Block Line Robot'
put 'DEVICE', 'DEV001', 'specs:device_type', 'Robot'
put 'DEVICE', 'DEV001', 'specs:manufacturer', 'Fanuc'
put 'DEVICE', 'DEV001', 'specs:model', 'R-2000iC'
put 'DEVICE', 'DEV001', 'specs:plant_code', 'MARYSVILLE'
put 'DEVICE', 'DEV001', 'specs:status', 'ACTIVE'
put 'DEVICE', 'DEV002', 'specs:name', 'Marysville Torque Station'
put 'DEVICE', 'DEV002', 'specs:device_type', 'TorqueStation'
put 'DEVICE', 'DEV002', 'specs:manufacturer', 'Atlas Copco'
put 'DEVICE', 'DEV002', 'specs:model', 'PowerFocus 6000'
put 'DEVICE', 'DEV002', 'specs:plant_code', 'MARYSVILLE'
put 'DEVICE', 'DEV002', 'specs:status', 'ACTIVE'
put 'DEVICE', 'DEV003', 'specs:name', 'Georgetown CNC Cell'
put 'DEVICE', 'DEV003', 'specs:device_type', 'CNC'
put 'DEVICE', 'DEV003', 'specs:manufacturer', 'Mazak'
put 'DEVICE', 'DEV003', 'specs:model', 'INTEGREX i-200'
put 'DEVICE', 'DEV003', 'specs:plant_code', 'GEORGETOWN'
put 'DEVICE', 'DEV003', 'specs:status', 'ACTIVE'
put 'DEVICE', 'DEV004', 'specs:name', 'Georgetown Hot Test Cell'
put 'DEVICE', 'DEV004', 'specs:device_type', 'TestCell'
put 'DEVICE', 'DEV004', 'specs:manufacturer', 'AVL'
put 'DEVICE', 'DEV004', 'specs:model', 'PUMA Open'
put 'DEVICE', 'DEV004', 'specs:plant_code', 'GEORGETOWN'
put 'DEVICE', 'DEV004', 'specs:status', 'ACTIVE'
put 'DEVICE', 'DEV005', 'specs:name', 'Flatrock Stamping Press'
put 'DEVICE', 'DEV005', 'specs:device_type', 'Press'
put 'DEVICE', 'DEV005', 'specs:manufacturer', 'Schuler'
put 'DEVICE', 'DEV005', 'specs:model', 'MSP 400'
put 'DEVICE', 'DEV005', 'specs:plant_code', 'FLATROCK'
put 'DEVICE', 'DEV005', 'specs:status', 'ACTIVE'
put 'DEVICE', 'DEV006', 'specs:name', 'Munich B58 CNC Line'
put 'DEVICE', 'DEV006', 'specs:device_type', 'CNC'
put 'DEVICE', 'DEV006', 'specs:manufacturer', 'DMG Mori'
put 'DEVICE', 'DEV006', 'specs:model', 'NLX 2500'
put 'DEVICE', 'DEV006', 'specs:plant_code', 'MUNICH'
put 'DEVICE', 'DEV006', 'specs:status', 'ACTIVE'
put 'DEVICE', 'DEV007', 'specs:name', 'Fremont Drive Unit Robot'
put 'DEVICE', 'DEV007', 'specs:device_type', 'Robot'
put 'DEVICE', 'DEV007', 'specs:manufacturer', 'KUKA'
put 'DEVICE', 'DEV007', 'specs:model', 'KR QUANTEC'
put 'DEVICE', 'DEV007', 'specs:plant_code', 'FREMONT'
put 'DEVICE', 'DEV007', 'specs:status', 'ACTIVE'
put 'DEVICE', 'DEV008', 'specs:name', 'East Liberty Body Fixture'
put 'DEVICE', 'DEV008', 'specs:device_type', 'Press'
put 'DEVICE', 'DEV008', 'specs:manufacturer', 'Comau'
put 'DEVICE', 'DEV008', 'specs:model', 'SmartCell'
put 'DEVICE', 'DEV008', 'specs:plant_code', 'EAST-LIBERTY'
put 'DEVICE', 'DEV008', 'specs:status', 'MAINTENANCE'
put 'DEVICE', 'DEV009', 'specs:name', 'Aisin Gear Hobber'
put 'DEVICE', 'DEV009', 'specs:device_type', 'CNC'
put 'DEVICE', 'DEV009', 'specs:manufacturer', 'Gleason'
put 'DEVICE', 'DEV009', 'specs:model', 'P90'
put 'DEVICE', 'DEV009', 'specs:plant_code', 'AISIN-IN'
put 'DEVICE', 'DEV009', 'specs:status', 'ACTIVE'
put 'DEVICE', 'DEV010', 'specs:name', 'Getrag Manual Line Robot'
put 'DEVICE', 'DEV010', 'specs:device_type', 'Robot'
put 'DEVICE', 'DEV010', 'specs:manufacturer', 'ABB'
put 'DEVICE', 'DEV010', 'specs:model', 'IRB 6700'
put 'DEVICE', 'DEV010', 'specs:plant_code', 'GETRAG-MI'
put 'DEVICE', 'DEV010', 'specs:status', 'ACTIVE'
put 'DEVICE', 'DEV011', 'specs:name', 'ZF 8HP Torque Station'
put 'DEVICE', 'DEV011', 'specs:device_type', 'TorqueStation'
put 'DEVICE', 'DEV011', 'specs:manufacturer', 'Bosch Rexroth'
put 'DEVICE', 'DEV011', 'specs:model', 'Tightening System'
put 'DEVICE', 'DEV011', 'specs:plant_code', 'ZF-SC'
put 'DEVICE', 'DEV011', 'specs:status', 'ACTIVE'
put 'DEVICE', 'DEV012', 'specs:name', 'Princeton Body Framing Cell'
put 'DEVICE', 'DEV012', 'specs:device_type', 'Robot'
put 'DEVICE', 'DEV012', 'specs:manufacturer', 'Fanuc'
put 'DEVICE', 'DEV012', 'specs:model', 'R-1000iA'
put 'DEVICE', 'DEV012', 'specs:plant_code', 'PRINCETON'
put 'DEVICE', 'DEV012', 'specs:status', 'ACTIVE'
EOF

echo ""
echo "Step 3: Inserting physical builds (production metadata)..."
echo ""

echo "  ENGINE_BUILD rows..."
hbase_shell <<'EOF'
put 'ENGINE_BUILD', 'EB-ENG001-00001', 'ids:engine_type_id', 'ENG001'
put 'ENGINE_BUILD', 'EB-ENG001-00001', 'ids:device_id', 'DEV001'
put 'ENGINE_BUILD', 'EB-ENG001-00001', 'production:build_date', '2022-03-12'
put 'ENGINE_BUILD', 'EB-ENG001-00001', 'production:plant_code', 'MARYSVILLE'
put 'ENGINE_BUILD', 'EB-ENG001-00001', 'production:line_id', 'L2'
put 'ENGINE_BUILD', 'EB-ENG001-00001', 'production:shift', 'A'
put 'ENGINE_BUILD', 'EB-ENG001-00001', 'production:batch_number', 'H22-031'
put 'ENGINE_BUILD', 'EB-ENG001-00001', 'production:serial_number', '00001'
put 'ENGINE_BUILD', 'EB-ENG001-00001', 'production:qc_status', 'PASS'
put 'ENGINE_BUILD', 'EB-ENG001-00001', 'production:operator_id', 'OP-1042'

put 'ENGINE_BUILD', 'EB-ENG001-00002', 'ids:engine_type_id', 'ENG001'
put 'ENGINE_BUILD', 'EB-ENG001-00002', 'ids:device_id', 'DEV002'
put 'ENGINE_BUILD', 'EB-ENG001-00002', 'production:build_date', '2023-01-18'
put 'ENGINE_BUILD', 'EB-ENG001-00002', 'production:plant_code', 'MARYSVILLE'
put 'ENGINE_BUILD', 'EB-ENG001-00002', 'production:line_id', 'L2'
put 'ENGINE_BUILD', 'EB-ENG001-00002', 'production:shift', 'B'
put 'ENGINE_BUILD', 'EB-ENG001-00002', 'production:batch_number', 'H23-012'
put 'ENGINE_BUILD', 'EB-ENG001-00002', 'production:serial_number', '00002'
put 'ENGINE_BUILD', 'EB-ENG001-00002', 'production:qc_status', 'PASS'
put 'ENGINE_BUILD', 'EB-ENG001-00002', 'production:operator_id', 'OP-1108'

put 'ENGINE_BUILD', 'EB-ENG002-00001', 'ids:engine_type_id', 'ENG002'
put 'ENGINE_BUILD', 'EB-ENG002-00001', 'ids:device_id', 'DEV003'
put 'ENGINE_BUILD', 'EB-ENG002-00001', 'production:build_date', '2021-06-04'
put 'ENGINE_BUILD', 'EB-ENG002-00001', 'production:plant_code', 'GEORGETOWN'
put 'ENGINE_BUILD', 'EB-ENG002-00001', 'production:line_id', 'L1'
put 'ENGINE_BUILD', 'EB-ENG002-00001', 'production:shift', 'A'
put 'ENGINE_BUILD', 'EB-ENG002-00001', 'production:batch_number', 'T21-088'
put 'ENGINE_BUILD', 'EB-ENG002-00001', 'production:serial_number', '00001'
put 'ENGINE_BUILD', 'EB-ENG002-00001', 'production:qc_status', 'PASS'
put 'ENGINE_BUILD', 'EB-ENG002-00001', 'production:operator_id', 'OP-2201'

put 'ENGINE_BUILD', 'EB-ENG002-00002', 'ids:engine_type_id', 'ENG002'
put 'ENGINE_BUILD', 'EB-ENG002-00002', 'ids:device_id', 'DEV004'
put 'ENGINE_BUILD', 'EB-ENG002-00002', 'production:build_date', '2024-02-09'
put 'ENGINE_BUILD', 'EB-ENG002-00002', 'production:plant_code', 'GEORGETOWN'
put 'ENGINE_BUILD', 'EB-ENG002-00002', 'production:line_id', 'L1'
put 'ENGINE_BUILD', 'EB-ENG002-00002', 'production:shift', 'C'
put 'ENGINE_BUILD', 'EB-ENG002-00002', 'production:batch_number', 'T24-019'
put 'ENGINE_BUILD', 'EB-ENG002-00002', 'production:serial_number', '00002'
put 'ENGINE_BUILD', 'EB-ENG002-00002', 'production:qc_status', 'PASS'
put 'ENGINE_BUILD', 'EB-ENG002-00002', 'production:operator_id', 'OP-2215'

put 'ENGINE_BUILD', 'EB-ENG003-00001', 'ids:engine_type_id', 'ENG003'
put 'ENGINE_BUILD', 'EB-ENG003-00001', 'ids:device_id', 'DEV005'
put 'ENGINE_BUILD', 'EB-ENG003-00001', 'production:build_date', '2020-08-21'
put 'ENGINE_BUILD', 'EB-ENG003-00001', 'production:plant_code', 'FLATROCK'
put 'ENGINE_BUILD', 'EB-ENG003-00001', 'production:line_id', 'L4'
put 'ENGINE_BUILD', 'EB-ENG003-00001', 'production:shift', 'A'
put 'ENGINE_BUILD', 'EB-ENG003-00001', 'production:batch_number', 'F20-142'
put 'ENGINE_BUILD', 'EB-ENG003-00001', 'production:serial_number', '00001'
put 'ENGINE_BUILD', 'EB-ENG003-00001', 'production:qc_status', 'PASS'
put 'ENGINE_BUILD', 'EB-ENG003-00001', 'production:operator_id', 'OP-3304'

put 'ENGINE_BUILD', 'EB-ENG004-00001', 'ids:engine_type_id', 'ENG004'
put 'ENGINE_BUILD', 'EB-ENG004-00001', 'ids:device_id', 'DEV006'
put 'ENGINE_BUILD', 'EB-ENG004-00001', 'production:build_date', '2023-05-30'
put 'ENGINE_BUILD', 'EB-ENG004-00001', 'production:plant_code', 'MUNICH'
put 'ENGINE_BUILD', 'EB-ENG004-00001', 'production:line_id', 'L7'
put 'ENGINE_BUILD', 'EB-ENG004-00001', 'production:shift', 'B'
put 'ENGINE_BUILD', 'EB-ENG004-00001', 'production:batch_number', 'B23-077'
put 'ENGINE_BUILD', 'EB-ENG004-00001', 'production:serial_number', '00001'
put 'ENGINE_BUILD', 'EB-ENG004-00001', 'production:qc_status', 'PASS'
put 'ENGINE_BUILD', 'EB-ENG004-00001', 'production:operator_id', 'OP-4410'

put 'ENGINE_BUILD', 'EB-ENG005-00001', 'ids:engine_type_id', 'ENG005'
put 'ENGINE_BUILD', 'EB-ENG005-00001', 'ids:device_id', 'DEV007'
put 'ENGINE_BUILD', 'EB-ENG005-00001', 'production:build_date', '2024-04-02'
put 'ENGINE_BUILD', 'EB-ENG005-00001', 'production:plant_code', 'FREMONT'
put 'ENGINE_BUILD', 'EB-ENG005-00001', 'production:line_id', 'L9'
put 'ENGINE_BUILD', 'EB-ENG005-00001', 'production:shift', 'A'
put 'ENGINE_BUILD', 'EB-ENG005-00001', 'production:batch_number', 'S24-040'
put 'ENGINE_BUILD', 'EB-ENG005-00001', 'production:serial_number', '00001'
put 'ENGINE_BUILD', 'EB-ENG005-00001', 'production:qc_status', 'PASS'
put 'ENGINE_BUILD', 'EB-ENG005-00001', 'production:operator_id', 'OP-5502'
EOF

echo "  TRANSMISSION_BUILD rows..."
hbase_shell <<'EOF'
put 'TRANSMISSION_BUILD', 'TB-TRN001-00001', 'ids:transmission_type_id', 'TRN001'
put 'TRANSMISSION_BUILD', 'TB-TRN001-00001', 'ids:device_id', 'DEV001'
put 'TRANSMISSION_BUILD', 'TB-TRN001-00001', 'production:build_date', '2022-03-10'
put 'TRANSMISSION_BUILD', 'TB-TRN001-00001', 'production:plant_code', 'MARYSVILLE'
put 'TRANSMISSION_BUILD', 'TB-TRN001-00001', 'production:line_id', 'T1'
put 'TRANSMISSION_BUILD', 'TB-TRN001-00001', 'production:shift', 'A'
put 'TRANSMISSION_BUILD', 'TB-TRN001-00001', 'production:batch_number', 'HT22-030'
put 'TRANSMISSION_BUILD', 'TB-TRN001-00001', 'production:serial_number', '00001'
put 'TRANSMISSION_BUILD', 'TB-TRN001-00001', 'production:qc_status', 'PASS'
put 'TRANSMISSION_BUILD', 'TB-TRN001-00001', 'production:operator_id', 'OP-6101'

put 'TRANSMISSION_BUILD', 'TB-TRN001-00002', 'ids:transmission_type_id', 'TRN001'
put 'TRANSMISSION_BUILD', 'TB-TRN001-00002', 'ids:device_id', 'DEV002'
put 'TRANSMISSION_BUILD', 'TB-TRN001-00002', 'production:build_date', '2023-01-16'
put 'TRANSMISSION_BUILD', 'TB-TRN001-00002', 'production:plant_code', 'MARYSVILLE'
put 'TRANSMISSION_BUILD', 'TB-TRN001-00002', 'production:line_id', 'T1'
put 'TRANSMISSION_BUILD', 'TB-TRN001-00002', 'production:shift', 'B'
put 'TRANSMISSION_BUILD', 'TB-TRN001-00002', 'production:batch_number', 'HT23-011'
put 'TRANSMISSION_BUILD', 'TB-TRN001-00002', 'production:serial_number', '00002'
put 'TRANSMISSION_BUILD', 'TB-TRN001-00002', 'production:qc_status', 'PASS'
put 'TRANSMISSION_BUILD', 'TB-TRN001-00002', 'production:operator_id', 'OP-6108'

put 'TRANSMISSION_BUILD', 'TB-TRN002-00001', 'ids:transmission_type_id', 'TRN002'
put 'TRANSMISSION_BUILD', 'TB-TRN002-00001', 'ids:device_id', 'DEV009'
put 'TRANSMISSION_BUILD', 'TB-TRN002-00001', 'production:build_date', '2021-06-01'
put 'TRANSMISSION_BUILD', 'TB-TRN002-00001', 'production:plant_code', 'AISIN-IN'
put 'TRANSMISSION_BUILD', 'TB-TRN002-00001', 'production:line_id', 'T3'
put 'TRANSMISSION_BUILD', 'TB-TRN002-00001', 'production:shift', 'A'
put 'TRANSMISSION_BUILD', 'TB-TRN002-00001', 'production:batch_number', 'AI21-060'
put 'TRANSMISSION_BUILD', 'TB-TRN002-00001', 'production:serial_number', '00001'
put 'TRANSMISSION_BUILD', 'TB-TRN002-00001', 'production:qc_status', 'PASS'
put 'TRANSMISSION_BUILD', 'TB-TRN002-00001', 'production:operator_id', 'OP-7202'

put 'TRANSMISSION_BUILD', 'TB-TRN002-00002', 'ids:transmission_type_id', 'TRN002'
put 'TRANSMISSION_BUILD', 'TB-TRN002-00002', 'ids:device_id', 'DEV009'
put 'TRANSMISSION_BUILD', 'TB-TRN002-00002', 'production:build_date', '2024-02-07'
put 'TRANSMISSION_BUILD', 'TB-TRN002-00002', 'production:plant_code', 'AISIN-IN'
put 'TRANSMISSION_BUILD', 'TB-TRN002-00002', 'production:line_id', 'T3'
put 'TRANSMISSION_BUILD', 'TB-TRN002-00002', 'production:shift', 'C'
put 'TRANSMISSION_BUILD', 'TB-TRN002-00002', 'production:batch_number', 'AI24-018'
put 'TRANSMISSION_BUILD', 'TB-TRN002-00002', 'production:serial_number', '00002'
put 'TRANSMISSION_BUILD', 'TB-TRN002-00002', 'production:qc_status', 'PASS'
put 'TRANSMISSION_BUILD', 'TB-TRN002-00002', 'production:operator_id', 'OP-7210'

put 'TRANSMISSION_BUILD', 'TB-TRN003-00001', 'ids:transmission_type_id', 'TRN003'
put 'TRANSMISSION_BUILD', 'TB-TRN003-00001', 'ids:device_id', 'DEV010'
put 'TRANSMISSION_BUILD', 'TB-TRN003-00001', 'production:build_date', '2020-08-19'
put 'TRANSMISSION_BUILD', 'TB-TRN003-00001', 'production:plant_code', 'GETRAG-MI'
put 'TRANSMISSION_BUILD', 'TB-TRN003-00001', 'production:line_id', 'T5'
put 'TRANSMISSION_BUILD', 'TB-TRN003-00001', 'production:shift', 'A'
put 'TRANSMISSION_BUILD', 'TB-TRN003-00001', 'production:batch_number', 'GT20-140'
put 'TRANSMISSION_BUILD', 'TB-TRN003-00001', 'production:serial_number', '00001'
put 'TRANSMISSION_BUILD', 'TB-TRN003-00001', 'production:qc_status', 'PASS'
put 'TRANSMISSION_BUILD', 'TB-TRN003-00001', 'production:operator_id', 'OP-8301'

put 'TRANSMISSION_BUILD', 'TB-TRN004-00001', 'ids:transmission_type_id', 'TRN004'
put 'TRANSMISSION_BUILD', 'TB-TRN004-00001', 'ids:device_id', 'DEV011'
put 'TRANSMISSION_BUILD', 'TB-TRN004-00001', 'production:build_date', '2023-05-28'
put 'TRANSMISSION_BUILD', 'TB-TRN004-00001', 'production:plant_code', 'ZF-SC'
put 'TRANSMISSION_BUILD', 'TB-TRN004-00001', 'production:line_id', 'T8'
put 'TRANSMISSION_BUILD', 'TB-TRN004-00001', 'production:shift', 'B'
put 'TRANSMISSION_BUILD', 'TB-TRN004-00001', 'production:batch_number', 'ZF23-075'
put 'TRANSMISSION_BUILD', 'TB-TRN004-00001', 'production:serial_number', '00001'
put 'TRANSMISSION_BUILD', 'TB-TRN004-00001', 'production:qc_status', 'PASS'
put 'TRANSMISSION_BUILD', 'TB-TRN004-00001', 'production:operator_id', 'OP-9404'

put 'TRANSMISSION_BUILD', 'TB-TRN004-00002', 'ids:transmission_type_id', 'TRN004'
put 'TRANSMISSION_BUILD', 'TB-TRN004-00002', 'ids:device_id', 'DEV011'
put 'TRANSMISSION_BUILD', 'TB-TRN004-00002', 'production:build_date', '2024-03-30'
put 'TRANSMISSION_BUILD', 'TB-TRN004-00002', 'production:plant_code', 'ZF-SC'
put 'TRANSMISSION_BUILD', 'TB-TRN004-00002', 'production:line_id', 'T8'
put 'TRANSMISSION_BUILD', 'TB-TRN004-00002', 'production:shift', 'A'
put 'TRANSMISSION_BUILD', 'TB-TRN004-00002', 'production:batch_number', 'ZF24-038'
put 'TRANSMISSION_BUILD', 'TB-TRN004-00002', 'production:serial_number', '00002'
put 'TRANSMISSION_BUILD', 'TB-TRN004-00002', 'production:qc_status', 'PASS'
put 'TRANSMISSION_BUILD', 'TB-TRN004-00002', 'production:operator_id', 'OP-9411'
EOF

echo "  CHASSIS_BUILD rows..."
hbase_shell <<'EOF'
put 'CHASSIS_BUILD', 'CB-CHS001-00001', 'ids:chassis_type_id', 'CHS001'
put 'CHASSIS_BUILD', 'CB-CHS001-00001', 'ids:device_id', 'DEV008'
put 'CHASSIS_BUILD', 'CB-CHS001-00001', 'production:build_date', '2022-03-08'
put 'CHASSIS_BUILD', 'CB-CHS001-00001', 'production:plant_code', 'EAST-LIBERTY'
put 'CHASSIS_BUILD', 'CB-CHS001-00001', 'production:line_id', 'C1'
put 'CHASSIS_BUILD', 'CB-CHS001-00001', 'production:shift', 'A'
put 'CHASSIS_BUILD', 'CB-CHS001-00001', 'production:batch_number', 'HC22-028'
put 'CHASSIS_BUILD', 'CB-CHS001-00001', 'production:serial_number', '00001'
put 'CHASSIS_BUILD', 'CB-CHS001-00001', 'production:qc_status', 'PASS'
put 'CHASSIS_BUILD', 'CB-CHS001-00001', 'production:operator_id', 'OP-1501'

put 'CHASSIS_BUILD', 'CB-CHS001-00002', 'ids:chassis_type_id', 'CHS001'
put 'CHASSIS_BUILD', 'CB-CHS001-00002', 'ids:device_id', 'DEV008'
put 'CHASSIS_BUILD', 'CB-CHS001-00002', 'production:build_date', '2023-01-14'
put 'CHASSIS_BUILD', 'CB-CHS001-00002', 'production:plant_code', 'EAST-LIBERTY'
put 'CHASSIS_BUILD', 'CB-CHS001-00002', 'production:line_id', 'C1'
put 'CHASSIS_BUILD', 'CB-CHS001-00002', 'production:shift', 'B'
put 'CHASSIS_BUILD', 'CB-CHS001-00002', 'production:batch_number', 'HC23-010'
put 'CHASSIS_BUILD', 'CB-CHS001-00002', 'production:serial_number', '00002'
put 'CHASSIS_BUILD', 'CB-CHS001-00002', 'production:qc_status', 'PASS'
put 'CHASSIS_BUILD', 'CB-CHS001-00002', 'production:operator_id', 'OP-1507'

put 'CHASSIS_BUILD', 'CB-CHS001-00003', 'ids:chassis_type_id', 'CHS001'
put 'CHASSIS_BUILD', 'CB-CHS001-00003', 'ids:device_id', 'DEV006'
put 'CHASSIS_BUILD', 'CB-CHS001-00003', 'production:build_date', '2023-05-26'
put 'CHASSIS_BUILD', 'CB-CHS001-00003', 'production:plant_code', 'DINGOLFING'
put 'CHASSIS_BUILD', 'CB-CHS001-00003', 'production:line_id', 'C6'
put 'CHASSIS_BUILD', 'CB-CHS001-00003', 'production:shift', 'B'
put 'CHASSIS_BUILD', 'CB-CHS001-00003', 'production:batch_number', 'BM23-074'
put 'CHASSIS_BUILD', 'CB-CHS001-00003', 'production:serial_number', '00003'
put 'CHASSIS_BUILD', 'CB-CHS001-00003', 'production:qc_status', 'PASS'
put 'CHASSIS_BUILD', 'CB-CHS001-00003', 'production:operator_id', 'OP-1603'

put 'CHASSIS_BUILD', 'CB-CHS002-00001', 'ids:chassis_type_id', 'CHS002'
put 'CHASSIS_BUILD', 'CB-CHS002-00001', 'ids:device_id', 'DEV012'
put 'CHASSIS_BUILD', 'CB-CHS002-00001', 'production:build_date', '2021-05-30'
put 'CHASSIS_BUILD', 'CB-CHS002-00001', 'production:plant_code', 'PRINCETON'
put 'CHASSIS_BUILD', 'CB-CHS002-00001', 'production:line_id', 'C2'
put 'CHASSIS_BUILD', 'CB-CHS002-00001', 'production:shift', 'A'
put 'CHASSIS_BUILD', 'CB-CHS002-00001', 'production:batch_number', 'TY21-058'
put 'CHASSIS_BUILD', 'CB-CHS002-00001', 'production:serial_number', '00001'
put 'CHASSIS_BUILD', 'CB-CHS002-00001', 'production:qc_status', 'PASS'
put 'CHASSIS_BUILD', 'CB-CHS002-00001', 'production:operator_id', 'OP-1702'

put 'CHASSIS_BUILD', 'CB-CHS002-00002', 'ids:chassis_type_id', 'CHS002'
put 'CHASSIS_BUILD', 'CB-CHS002-00002', 'ids:device_id', 'DEV012'
put 'CHASSIS_BUILD', 'CB-CHS002-00002', 'production:build_date', '2024-02-05'
put 'CHASSIS_BUILD', 'CB-CHS002-00002', 'production:plant_code', 'PRINCETON'
put 'CHASSIS_BUILD', 'CB-CHS002-00002', 'production:line_id', 'C2'
put 'CHASSIS_BUILD', 'CB-CHS002-00002', 'production:shift', 'C'
put 'CHASSIS_BUILD', 'CB-CHS002-00002', 'production:batch_number', 'TY24-017'
put 'CHASSIS_BUILD', 'CB-CHS002-00002', 'production:serial_number', '00002'
put 'CHASSIS_BUILD', 'CB-CHS002-00002', 'production:qc_status', 'PASS'
put 'CHASSIS_BUILD', 'CB-CHS002-00002', 'production:operator_id', 'OP-1711'

put 'CHASSIS_BUILD', 'CB-CHS003-00001', 'ids:chassis_type_id', 'CHS003'
put 'CHASSIS_BUILD', 'CB-CHS003-00001', 'ids:device_id', 'DEV005'
put 'CHASSIS_BUILD', 'CB-CHS003-00001', 'production:build_date', '2020-08-17'
put 'CHASSIS_BUILD', 'CB-CHS003-00001', 'production:plant_code', 'FLATROCK'
put 'CHASSIS_BUILD', 'CB-CHS003-00001', 'production:line_id', 'C4'
put 'CHASSIS_BUILD', 'CB-CHS003-00001', 'production:shift', 'A'
put 'CHASSIS_BUILD', 'CB-CHS003-00001', 'production:batch_number', 'FR20-138'
put 'CHASSIS_BUILD', 'CB-CHS003-00001', 'production:serial_number', '00001'
put 'CHASSIS_BUILD', 'CB-CHS003-00001', 'production:qc_status', 'PASS'
put 'CHASSIS_BUILD', 'CB-CHS003-00001', 'production:operator_id', 'OP-1805'

put 'CHASSIS_BUILD', 'CB-CHS004-00001', 'ids:chassis_type_id', 'CHS004'
put 'CHASSIS_BUILD', 'CB-CHS004-00001', 'ids:device_id', 'DEV007'
put 'CHASSIS_BUILD', 'CB-CHS004-00001', 'production:build_date', '2024-03-28'
put 'CHASSIS_BUILD', 'CB-CHS004-00001', 'production:plant_code', 'FREMONT'
put 'CHASSIS_BUILD', 'CB-CHS004-00001', 'production:line_id', 'C9'
put 'CHASSIS_BUILD', 'CB-CHS004-00001', 'production:shift', 'A'
put 'CHASSIS_BUILD', 'CB-CHS004-00001', 'production:batch_number', 'TS24-036'
put 'CHASSIS_BUILD', 'CB-CHS004-00001', 'production:serial_number', '00001'
put 'CHASSIS_BUILD', 'CB-CHS004-00001', 'production:qc_status', 'PASS'
put 'CHASSIS_BUILD', 'CB-CHS004-00001', 'production:operator_id', 'OP-1908'
EOF

echo ""
echo "Step 4: Inserting vehicles (VIN → build IDs)..."
echo ""

hbase_shell <<'EOF'
put 'VEHICLE', '1HGCM82633A004352', 'ids:engine_build_id', 'EB-ENG001-00001'
put 'VEHICLE', '1HGCM82633A004352', 'ids:transmission_build_id', 'TB-TRN001-00001'
put 'VEHICLE', '1HGCM82633A004352', 'ids:chassis_build_id', 'CB-CHS001-00001'
put 'VEHICLE', '1HGCM82633A004352', 'info:make', 'Honda'
put 'VEHICLE', '1HGCM82633A004352', 'info:model', 'Civic'
put 'VEHICLE', '1HGCM82633A004352', 'info:year', '2022'
put 'VEHICLE', '1HGCM82633A004352', 'info:color', 'Blue'
put 'VEHICLE', '1HGCM82633A004352', 'info:trim', 'EX'

put 'VEHICLE', '1HGCV1F30JA000123', 'ids:engine_build_id', 'EB-ENG001-00002'
put 'VEHICLE', '1HGCV1F30JA000123', 'ids:transmission_build_id', 'TB-TRN001-00002'
put 'VEHICLE', '1HGCV1F30JA000123', 'ids:chassis_build_id', 'CB-CHS001-00002'
put 'VEHICLE', '1HGCV1F30JA000123', 'info:make', 'Honda'
put 'VEHICLE', '1HGCV1F30JA000123', 'info:model', 'Accord'
put 'VEHICLE', '1HGCV1F30JA000123', 'info:year', '2023'
put 'VEHICLE', '1HGCV1F30JA000123', 'info:color', 'Silver'
put 'VEHICLE', '1HGCV1F30JA000123', 'info:trim', 'Sport'

put 'VEHICLE', '5TDKZRFH0KS123456', 'ids:engine_build_id', 'EB-ENG002-00001'
put 'VEHICLE', '5TDKZRFH0KS123456', 'ids:transmission_build_id', 'TB-TRN002-00001'
put 'VEHICLE', '5TDKZRFH0KS123456', 'ids:chassis_build_id', 'CB-CHS002-00001'
put 'VEHICLE', '5TDKZRFH0KS123456', 'info:make', 'Toyota'
put 'VEHICLE', '5TDKZRFH0KS123456', 'info:model', 'Highlander'
put 'VEHICLE', '5TDKZRFH0KS123456', 'info:year', '2021'
put 'VEHICLE', '5TDKZRFH0KS123456', 'info:color', 'White'
put 'VEHICLE', '5TDKZRFH0KS123456', 'info:trim', 'XLE'

put 'VEHICLE', '2T3P1RFV8MW078901', 'ids:engine_build_id', 'EB-ENG002-00002'
put 'VEHICLE', '2T3P1RFV8MW078901', 'ids:transmission_build_id', 'TB-TRN002-00002'
put 'VEHICLE', '2T3P1RFV8MW078901', 'ids:chassis_build_id', 'CB-CHS002-00002'
put 'VEHICLE', '2T3P1RFV8MW078901', 'info:make', 'Toyota'
put 'VEHICLE', '2T3P1RFV8MW078901', 'info:model', 'RAV4'
put 'VEHICLE', '2T3P1RFV8MW078901', 'info:year', '2024'
put 'VEHICLE', '2T3P1RFV8MW078901', 'info:color', 'Black'
put 'VEHICLE', '2T3P1RFV8MW078901', 'info:trim', 'Adventure'

put 'VEHICLE', '1FA6P8CF5L5102345', 'ids:engine_build_id', 'EB-ENG003-00001'
put 'VEHICLE', '1FA6P8CF5L5102345', 'ids:transmission_build_id', 'TB-TRN003-00001'
put 'VEHICLE', '1FA6P8CF5L5102345', 'ids:chassis_build_id', 'CB-CHS003-00001'
put 'VEHICLE', '1FA6P8CF5L5102345', 'info:make', 'Ford'
put 'VEHICLE', '1FA6P8CF5L5102345', 'info:model', 'Mustang'
put 'VEHICLE', '1FA6P8CF5L5102345', 'info:year', '2020'
put 'VEHICLE', '1FA6P8CF5L5102345', 'info:color', 'Red'
put 'VEHICLE', '1FA6P8CF5L5102345', 'info:trim', 'GT'

put 'VEHICLE', 'WBA5U9C05LF345678', 'ids:engine_build_id', 'EB-ENG004-00001'
put 'VEHICLE', 'WBA5U9C05LF345678', 'ids:transmission_build_id', 'TB-TRN004-00001'
put 'VEHICLE', 'WBA5U9C05LF345678', 'ids:chassis_build_id', 'CB-CHS001-00003'
put 'VEHICLE', 'WBA5U9C05LF345678', 'info:make', 'BMW'
put 'VEHICLE', 'WBA5U9C05LF345678', 'info:model', 'M340i'
put 'VEHICLE', 'WBA5U9C05LF345678', 'info:year', '2023'
put 'VEHICLE', 'WBA5U9C05LF345678', 'info:color', 'Gray'
put 'VEHICLE', 'WBA5U9C05LF345678', 'info:trim', 'xDrive'

put 'VEHICLE', '5YJ3E1EA1KF789012', 'ids:engine_build_id', 'EB-ENG005-00001'
put 'VEHICLE', '5YJ3E1EA1KF789012', 'ids:transmission_build_id', 'TB-TRN004-00002'
put 'VEHICLE', '5YJ3E1EA1KF789012', 'ids:chassis_build_id', 'CB-CHS004-00001'
put 'VEHICLE', '5YJ3E1EA1KF789012', 'info:make', 'Tesla'
put 'VEHICLE', '5YJ3E1EA1KF789012', 'info:model', 'Model Y'
put 'VEHICLE', '5YJ3E1EA1KF789012', 'info:year', '2024'
put 'VEHICLE', '5YJ3E1EA1KF789012', 'info:color', 'White'
put 'VEHICLE', '5YJ3E1EA1KF789012', 'info:trim', 'Performance'
EOF

echo ""
sleep "$WAIT_SECONDS"

echo "Step 5: Verifying data in HBase..."
echo "scan 'ENGINE_BUILD', {LIMIT => 1}" | hbase_shell | grep -A 8 "ROW  COLUMN" | head -12 || true
echo ""

if [[ "$SKIP_VIEWS" == true ]]; then
  echo "Step 6: Skipping Phoenix view creation (--skip-views)"
  echo ""
else
  echo "Step 6: Creating Phoenix views via ${API_URL}..."
  echo ""

  curl -s -X POST "${API_URL}/execute" -H "Content-Type: application/json" \
    -d '{"sql": "CREATE VIEW IF NOT EXISTS \"ENGINE\" (\"rowkey\" VARCHAR PRIMARY KEY, \"specs\".\"manufacturer\" VARCHAR, \"specs\".\"model\" VARCHAR, \"specs\".\"displacement_l\" VARCHAR, \"specs\".\"cylinders\" VARCHAR, \"specs\".\"horsepower\" VARCHAR, \"specs\".\"fuel_type\" VARCHAR)"}' | jq .

  curl -s -X POST "${API_URL}/execute" -H "Content-Type: application/json" \
    -d '{"sql": "CREATE VIEW IF NOT EXISTS \"TRANSMISSION\" (\"rowkey\" VARCHAR PRIMARY KEY, \"specs\".\"manufacturer\" VARCHAR, \"specs\".\"model\" VARCHAR, \"specs\".\"type\" VARCHAR, \"specs\".\"gears\" VARCHAR, \"specs\".\"drive_type\" VARCHAR)"}' | jq .

  curl -s -X POST "${API_URL}/execute" -H "Content-Type: application/json" \
    -d '{"sql": "CREATE VIEW IF NOT EXISTS \"CHASSIS\" (\"rowkey\" VARCHAR PRIMARY KEY, \"specs\".\"body_style\" VARCHAR, \"specs\".\"material\" VARCHAR, \"specs\".\"wheelbase_in\" VARCHAR, \"specs\".\"curb_weight_lb\" VARCHAR, \"specs\".\"doors\" VARCHAR)"}' | jq .

  curl -s -X POST "${API_URL}/execute" -H "Content-Type: application/json" \
    -d '{"sql": "CREATE VIEW IF NOT EXISTS \"DEVICE\" (\"rowkey\" VARCHAR PRIMARY KEY, \"specs\".\"name\" VARCHAR, \"specs\".\"device_type\" VARCHAR, \"specs\".\"manufacturer\" VARCHAR, \"specs\".\"model\" VARCHAR, \"specs\".\"plant_code\" VARCHAR, \"specs\".\"status\" VARCHAR)"}' | jq .

  curl -s -X POST "${API_URL}/execute" -H "Content-Type: application/json" \
    -d '{"sql": "CREATE VIEW IF NOT EXISTS \"ENGINE_BUILD\" (\"rowkey\" VARCHAR PRIMARY KEY, \"ids\".\"engine_type_id\" VARCHAR, \"ids\".\"device_id\" VARCHAR, \"production\".\"build_date\" VARCHAR, \"production\".\"plant_code\" VARCHAR, \"production\".\"line_id\" VARCHAR, \"production\".\"shift\" VARCHAR, \"production\".\"batch_number\" VARCHAR, \"production\".\"serial_number\" VARCHAR, \"production\".\"qc_status\" VARCHAR, \"production\".\"operator_id\" VARCHAR)"}' | jq .

  curl -s -X POST "${API_URL}/execute" -H "Content-Type: application/json" \
    -d '{"sql": "CREATE VIEW IF NOT EXISTS \"TRANSMISSION_BUILD\" (\"rowkey\" VARCHAR PRIMARY KEY, \"ids\".\"transmission_type_id\" VARCHAR, \"ids\".\"device_id\" VARCHAR, \"production\".\"build_date\" VARCHAR, \"production\".\"plant_code\" VARCHAR, \"production\".\"line_id\" VARCHAR, \"production\".\"shift\" VARCHAR, \"production\".\"batch_number\" VARCHAR, \"production\".\"serial_number\" VARCHAR, \"production\".\"qc_status\" VARCHAR, \"production\".\"operator_id\" VARCHAR)"}' | jq .

  curl -s -X POST "${API_URL}/execute" -H "Content-Type: application/json" \
    -d '{"sql": "CREATE VIEW IF NOT EXISTS \"CHASSIS_BUILD\" (\"rowkey\" VARCHAR PRIMARY KEY, \"ids\".\"chassis_type_id\" VARCHAR, \"ids\".\"device_id\" VARCHAR, \"production\".\"build_date\" VARCHAR, \"production\".\"plant_code\" VARCHAR, \"production\".\"line_id\" VARCHAR, \"production\".\"shift\" VARCHAR, \"production\".\"batch_number\" VARCHAR, \"production\".\"serial_number\" VARCHAR, \"production\".\"qc_status\" VARCHAR, \"production\".\"operator_id\" VARCHAR)"}' | jq .

  curl -s -X POST "${API_URL}/execute" -H "Content-Type: application/json" \
    -d '{"sql": "CREATE VIEW IF NOT EXISTS \"VEHICLE\" (\"rowkey\" VARCHAR PRIMARY KEY, \"ids\".\"engine_build_id\" VARCHAR, \"ids\".\"transmission_build_id\" VARCHAR, \"ids\".\"chassis_build_id\" VARCHAR, \"info\".\"make\" VARCHAR, \"info\".\"model\" VARCHAR, \"info\".\"year\" VARCHAR, \"info\".\"color\" VARCHAR, \"info\".\"trim\" VARCHAR)"}' | jq .

  echo ""
  sleep "$((WAIT_SECONDS + 1))"
  echo "Found views:"
  curl -s "${API_URL}/views" | jq -r '.rows[] | select(.TABLE_NAME | test("ENGINE|TRANSMISSION|CHASSIS|VEHICLE|DEVICE"; "i")) | .TABLE_NAME' | sort
  echo ""
fi

if [[ "$SKIP_QUERIES" == true ]]; then
  echo "Step 7: Skipping example queries (--skip-queries)"
  echo ""
else
  echo "Step 7: Example queries..."
  echo ""

  echo "Query 1: Device by ID"
  curl -s -X POST "${API_URL}/query" -H "Content-Type: application/json" \
    -d '{"sql": "SELECT \"rowkey\" as device_id, \"specs\".\"name\", \"specs\".\"device_type\", \"specs\".\"plant_code\", \"specs\".\"status\" FROM \"DEVICE\" WHERE \"rowkey\" = '\''DEV001'\''"}' \
    | jq '{rowCount, rows}'

  echo ""
  echo "Query 2: Engine build with type + device"
  curl -s -X POST "${API_URL}/query" -H "Content-Type: application/json" \
    -d '{"sql": "SELECT eb.\"rowkey\" as engine_build_id, eb.\"ids\".\"engine_type_id\", eb.\"ids\".\"device_id\", eb.\"production\".\"plant_code\", e.\"specs\".\"horsepower\", d.\"specs\".\"name\" as device_name, d.\"specs\".\"device_type\" FROM \"ENGINE_BUILD\" eb JOIN \"ENGINE\" e ON eb.\"ids\".\"engine_type_id\" = e.\"rowkey\" JOIN \"DEVICE\" d ON eb.\"ids\".\"device_id\" = d.\"rowkey\" WHERE eb.\"rowkey\" = '\''EB-ENG001-00001'\''"}' \
    | jq '{rowCount, rows}'

  echo ""
  echo "Query 3: Complete build sheet (builds + types + devices)"
  curl -s -X POST "${API_URL}/query" -H "Content-Type: application/json" \
    -d '{"sql": "SELECT v.\"rowkey\" as vin, v.\"info\".\"make\" as make, v.\"info\".\"model\" as model, eb.\"rowkey\" as engine_build_id, e.\"specs\".\"horsepower\" as horsepower, ed.\"rowkey\" as engine_device_id, ed.\"specs\".\"name\" as engine_device_name, tb.\"rowkey\" as transmission_build_id, t.\"specs\".\"type\" as transmission_type, td.\"rowkey\" as transmission_device_id, td.\"specs\".\"name\" as transmission_device_name, cb.\"rowkey\" as chassis_build_id, c.\"specs\".\"body_style\" as body_style, cd.\"rowkey\" as chassis_device_id, cd.\"specs\".\"name\" as chassis_device_name FROM \"VEHICLE\" v JOIN \"ENGINE_BUILD\" eb ON v.\"ids\".\"engine_build_id\" = eb.\"rowkey\" JOIN \"ENGINE\" e ON eb.\"ids\".\"engine_type_id\" = e.\"rowkey\" JOIN \"DEVICE\" ed ON eb.\"ids\".\"device_id\" = ed.\"rowkey\" JOIN \"TRANSMISSION_BUILD\" tb ON v.\"ids\".\"transmission_build_id\" = tb.\"rowkey\" JOIN \"TRANSMISSION\" t ON tb.\"ids\".\"transmission_type_id\" = t.\"rowkey\" JOIN \"DEVICE\" td ON tb.\"ids\".\"device_id\" = td.\"rowkey\" JOIN \"CHASSIS_BUILD\" cb ON v.\"ids\".\"chassis_build_id\" = cb.\"rowkey\" JOIN \"CHASSIS\" c ON cb.\"ids\".\"chassis_type_id\" = c.\"rowkey\" JOIN \"DEVICE\" cd ON cb.\"ids\".\"device_id\" = cd.\"rowkey\" WHERE v.\"rowkey\" = '\''1HGCM82633A004352'\''"}' \
    | jq '{rowCount, rows}'
  echo ""
fi

echo "=========================================="
echo "Done! Vehicle 360 type + device + build tables created."
echo "=========================================="
echo ""
echo "Type catalogs:  ENGINE, TRANSMISSION, CHASSIS"
echo "Devices:        DEVICE"
echo "Build tables:   ENGINE_BUILD, TRANSMISSION_BUILD, CHASSIS_BUILD"
echo "Assembly:       VEHICLE (VIN → *_build_id)"
echo ""
echo "Or run: ./run_vehicle360_queries.sh"
echo ""
