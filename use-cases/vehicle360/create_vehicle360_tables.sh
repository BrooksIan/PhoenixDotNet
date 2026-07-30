#!/bin/bash

# Complete Example: Create Vehicle 360 HBase Native Tables
# This script demonstrates a normalized component-catalog + assembly pattern:
# 1. ENGINE       - Engine catalog (unique engine IDs)
# 2. TRANSMISSION - Transmission catalog (unique transmission IDs)
# 3. CHASSIS      - Chassis catalog (unique chassis IDs)
# 4. VEHICLE      - Vehicle assembly keyed by VIN, referencing one of each component
#
# Defaults match the local docker-compose stack. Override via flags or env vars.

set -euo pipefail

# ---------------------------------------------------------------------------
# Defaults (overridable by environment or CLI flags)
# ---------------------------------------------------------------------------
API_URL="${API_URL:-http://localhost:8099/api/phoenix}"
HBASE_CONTAINER="${HBASE_CONTAINER:-opdb-docker}"
HBASE_BIN="${HBASE_BIN:-/opt/hbase/bin/hbase}"
DOCKER_BIN="${DOCKER_BIN:-docker}"
WAIT_SECONDS="${WAIT_SECONDS:-2}"
SKIP_VIEWS=false
SKIP_QUERIES=false

usage() {
  cat <<EOF
Usage: $(basename "$0") [options]

Create Vehicle 360 HBase tables, seed sample data, and create Phoenix views.

Options:
  --api-url URL          Phoenix REST API base URL
                         (default: ${API_URL})
  --container NAME       Docker container running HBase
                         (default: ${HBASE_CONTAINER})
  --hbase-bin PATH       Path to hbase binary inside the container
                         (default: ${HBASE_BIN})
  --docker BIN           Docker CLI binary
                         (default: ${DOCKER_BIN})
  --wait SECONDS         Seconds to wait after table create / data load
                         (default: ${WAIT_SECONDS})
  --skip-views           Skip Phoenix view creation
  --skip-queries         Skip example queries at the end
  -h, --help             Show this help

Environment variables (same meaning as flags):
  API_URL, HBASE_CONTAINER, HBASE_BIN, DOCKER_BIN, WAIT_SECONDS

Examples:
  $(basename "$0")
  $(basename "$0") --api-url http://localhost:8099/api/phoenix
  $(basename "$0") --container opdb-docker --api-url http://127.0.0.1:8099/api/phoenix
  API_URL=http://host:8099/api/phoenix HBASE_CONTAINER=my-hbase $(basename "$0")
EOF
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --api-url)
      API_URL="$2"
      shift 2
      ;;
    --container)
      HBASE_CONTAINER="$2"
      shift 2
      ;;
    --hbase-bin)
      HBASE_BIN="$2"
      shift 2
      ;;
    --docker)
      DOCKER_BIN="$2"
      shift 2
      ;;
    --wait)
      WAIT_SECONDS="$2"
      shift 2
      ;;
    --skip-views)
      SKIP_VIEWS=true
      shift
      ;;
    --skip-queries)
      SKIP_QUERIES=true
      shift
      ;;
    -h|--help)
      usage
      exit 0
      ;;
    *)
      echo "Unknown option: $1" >&2
      usage >&2
      exit 1
      ;;
  esac
done

# Run HBase shell commands inside the configured Docker container.
# Usage: hbase_shell <<'EOF'
#          create 'ENGINE', 'specs'
#        EOF
hbase_shell() {
  "$DOCKER_BIN" exec -i "$HBASE_CONTAINER" "$HBASE_BIN" shell
}

echo "=========================================="
echo "Create Vehicle 360 HBase Tables"
echo "=========================================="
echo "API URL:       ${API_URL}"
echo "Container:     ${HBASE_CONTAINER}"
echo "HBase binary:  ${HBASE_BIN}"
echo "Docker binary: ${DOCKER_BIN}"
echo ""

# Sanity checks before writing data
if ! command -v "$DOCKER_BIN" >/dev/null 2>&1; then
  echo "ERROR: Docker binary not found: ${DOCKER_BIN}" >&2
  exit 1
fi

if ! "$DOCKER_BIN" inspect "$HBASE_CONTAINER" >/dev/null 2>&1; then
  echo "ERROR: Docker container not found: ${HBASE_CONTAINER}" >&2
  echo "Start the stack first (e.g. docker-compose up -d), or pass --container NAME." >&2
  exit 1
fi

# Step 1: Create HBase Tables
echo "Step 1: Creating HBase tables..."
echo ""

echo "  Creating ENGINE..."
hbase_shell <<'EOF'
create 'ENGINE', 'specs'
EOF

echo "  Creating TRANSMISSION..."
hbase_shell <<'EOF'
create 'TRANSMISSION', 'specs'
EOF

echo "  Creating CHASSIS..."
hbase_shell <<'EOF'
create 'CHASSIS', 'specs'
EOF

echo "  Creating VEHICLE..."
hbase_shell <<'EOF'
create 'VEHICLE', 'ids', 'info'
EOF

echo ""
sleep "$WAIT_SECONDS"

# Step 2: Insert Component Catalog Data
echo "Step 2: Inserting component catalog data..."
echo ""

echo "  Inserting engines (ENG001-ENG005)..."
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

echo "  Inserting transmissions (TRN001-TRN004)..."
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

echo "  Inserting chassis (CHS001-CHS004)..."
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

echo ""
echo "Step 3: Inserting vehicles (VIN assembly rows)..."
echo ""

# Vehicles reuse component IDs to demonstrate normalization
echo "  Inserting 7 vehicles with shared component references..."
hbase_shell <<'EOF'
# Honda Civic - ENG001 + TRN001 + CHS001
put 'VEHICLE', '1HGCM82633A004352', 'ids:engine_id', 'ENG001'
put 'VEHICLE', '1HGCM82633A004352', 'ids:transmission_id', 'TRN001'
put 'VEHICLE', '1HGCM82633A004352', 'ids:chassis_id', 'CHS001'
put 'VEHICLE', '1HGCM82633A004352', 'info:make', 'Honda'
put 'VEHICLE', '1HGCM82633A004352', 'info:model', 'Civic'
put 'VEHICLE', '1HGCM82633A004352', 'info:year', '2022'
put 'VEHICLE', '1HGCM82633A004352', 'info:color', 'Blue'
put 'VEHICLE', '1HGCM82633A004352', 'info:trim', 'EX'

# Honda Accord - reuses ENG001 + TRN001, different chassis
put 'VEHICLE', '1HGCV1F30JA000123', 'ids:engine_id', 'ENG001'
put 'VEHICLE', '1HGCV1F30JA000123', 'ids:transmission_id', 'TRN001'
put 'VEHICLE', '1HGCV1F30JA000123', 'ids:chassis_id', 'CHS001'
put 'VEHICLE', '1HGCV1F30JA000123', 'info:make', 'Honda'
put 'VEHICLE', '1HGCV1F30JA000123', 'info:model', 'Accord'
put 'VEHICLE', '1HGCV1F30JA000123', 'info:year', '2023'
put 'VEHICLE', '1HGCV1F30JA000123', 'info:color', 'Silver'
put 'VEHICLE', '1HGCV1F30JA000123', 'info:trim', 'Sport'

# Toyota Highlander - ENG002 + TRN002 + CHS002
put 'VEHICLE', '5TDKZRFH0KS123456', 'ids:engine_id', 'ENG002'
put 'VEHICLE', '5TDKZRFH0KS123456', 'ids:transmission_id', 'TRN002'
put 'VEHICLE', '5TDKZRFH0KS123456', 'ids:chassis_id', 'CHS002'
put 'VEHICLE', '5TDKZRFH0KS123456', 'info:make', 'Toyota'
put 'VEHICLE', '5TDKZRFH0KS123456', 'info:model', 'Highlander'
put 'VEHICLE', '5TDKZRFH0KS123456', 'info:year', '2021'
put 'VEHICLE', '5TDKZRFH0KS123456', 'info:color', 'White'
put 'VEHICLE', '5TDKZRFH0KS123456', 'info:trim', 'XLE'

# Toyota RAV4 - reuses ENG002 + TRN002 + CHS002
put 'VEHICLE', '2T3P1RFV8MW078901', 'ids:engine_id', 'ENG002'
put 'VEHICLE', '2T3P1RFV8MW078901', 'ids:transmission_id', 'TRN002'
put 'VEHICLE', '2T3P1RFV8MW078901', 'ids:chassis_id', 'CHS002'
put 'VEHICLE', '2T3P1RFV8MW078901', 'info:make', 'Toyota'
put 'VEHICLE', '2T3P1RFV8MW078901', 'info:model', 'RAV4'
put 'VEHICLE', '2T3P1RFV8MW078901', 'info:year', '2024'
put 'VEHICLE', '2T3P1RFV8MW078901', 'info:color', 'Black'
put 'VEHICLE', '2T3P1RFV8MW078901', 'info:trim', 'Adventure'

# Ford Mustang - ENG003 + TRN003 + CHS003
put 'VEHICLE', '1FA6P8CF5L5102345', 'ids:engine_id', 'ENG003'
put 'VEHICLE', '1FA6P8CF5L5102345', 'ids:transmission_id', 'TRN003'
put 'VEHICLE', '1FA6P8CF5L5102345', 'ids:chassis_id', 'CHS003'
put 'VEHICLE', '1FA6P8CF5L5102345', 'info:make', 'Ford'
put 'VEHICLE', '1FA6P8CF5L5102345', 'info:model', 'Mustang'
put 'VEHICLE', '1FA6P8CF5L5102345', 'info:year', '2020'
put 'VEHICLE', '1FA6P8CF5L5102345', 'info:color', 'Red'
put 'VEHICLE', '1FA6P8CF5L5102345', 'info:trim', 'GT'

# BMW M340i - ENG004 + TRN004 + CHS001
put 'VEHICLE', 'WBA5U9C05LF345678', 'ids:engine_id', 'ENG004'
put 'VEHICLE', 'WBA5U9C05LF345678', 'ids:transmission_id', 'TRN004'
put 'VEHICLE', 'WBA5U9C05LF345678', 'ids:chassis_id', 'CHS001'
put 'VEHICLE', 'WBA5U9C05LF345678', 'info:make', 'BMW'
put 'VEHICLE', 'WBA5U9C05LF345678', 'info:model', 'M340i'
put 'VEHICLE', 'WBA5U9C05LF345678', 'info:year', '2023'
put 'VEHICLE', 'WBA5U9C05LF345678', 'info:color', 'Gray'
put 'VEHICLE', 'WBA5U9C05LF345678', 'info:trim', 'xDrive'

# Tesla Model Y - ENG005 + TRN004 + CHS004 (reuses TRN004 for demo)
put 'VEHICLE', '5YJ3E1EA1KF789012', 'ids:engine_id', 'ENG005'
put 'VEHICLE', '5YJ3E1EA1KF789012', 'ids:transmission_id', 'TRN004'
put 'VEHICLE', '5YJ3E1EA1KF789012', 'ids:chassis_id', 'CHS004'
put 'VEHICLE', '5YJ3E1EA1KF789012', 'info:make', 'Tesla'
put 'VEHICLE', '5YJ3E1EA1KF789012', 'info:model', 'Model Y'
put 'VEHICLE', '5YJ3E1EA1KF789012', 'info:year', '2024'
put 'VEHICLE', '5YJ3E1EA1KF789012', 'info:color', 'White'
put 'VEHICLE', '5YJ3E1EA1KF789012', 'info:trim', 'Performance'
EOF

echo ""
sleep "$WAIT_SECONDS"

# Step 4: Verify data in HBase
echo "Step 4: Verifying data in HBase..."
echo ""
echo "scan 'VEHICLE', {LIMIT => 2}" | hbase_shell | grep -A 10 "ROW  COLUMN" | head -15
echo ""

# Step 5: Create Phoenix Views
if [[ "$SKIP_VIEWS" == true ]]; then
  echo "Step 5: Skipping Phoenix view creation (--skip-views)"
  echo ""
else
  echo "Step 5: Creating Phoenix views via ${API_URL}..."
  echo ""

  echo "  Creating ENGINE view..."
  curl -s -X POST "${API_URL}/execute" \
    -H "Content-Type: application/json" \
    -d '{"sql": "CREATE VIEW IF NOT EXISTS \"ENGINE\" (\"rowkey\" VARCHAR PRIMARY KEY, \"specs\".\"manufacturer\" VARCHAR, \"specs\".\"model\" VARCHAR, \"specs\".\"displacement_l\" VARCHAR, \"specs\".\"cylinders\" VARCHAR, \"specs\".\"horsepower\" VARCHAR, \"specs\".\"fuel_type\" VARCHAR)"}' | jq .

  echo "  Creating TRANSMISSION view..."
  curl -s -X POST "${API_URL}/execute" \
    -H "Content-Type: application/json" \
    -d '{"sql": "CREATE VIEW IF NOT EXISTS \"TRANSMISSION\" (\"rowkey\" VARCHAR PRIMARY KEY, \"specs\".\"manufacturer\" VARCHAR, \"specs\".\"model\" VARCHAR, \"specs\".\"type\" VARCHAR, \"specs\".\"gears\" VARCHAR, \"specs\".\"drive_type\" VARCHAR)"}' | jq .

  echo "  Creating CHASSIS view..."
  curl -s -X POST "${API_URL}/execute" \
    -H "Content-Type: application/json" \
    -d '{"sql": "CREATE VIEW IF NOT EXISTS \"CHASSIS\" (\"rowkey\" VARCHAR PRIMARY KEY, \"specs\".\"body_style\" VARCHAR, \"specs\".\"material\" VARCHAR, \"specs\".\"wheelbase_in\" VARCHAR, \"specs\".\"curb_weight_lb\" VARCHAR, \"specs\".\"doors\" VARCHAR)"}' | jq .

  echo "  Creating VEHICLE view..."
  curl -s -X POST "${API_URL}/execute" \
    -H "Content-Type: application/json" \
    -d '{"sql": "CREATE VIEW IF NOT EXISTS \"VEHICLE\" (\"rowkey\" VARCHAR PRIMARY KEY, \"ids\".\"engine_id\" VARCHAR, \"ids\".\"transmission_id\" VARCHAR, \"ids\".\"chassis_id\" VARCHAR, \"info\".\"make\" VARCHAR, \"info\".\"model\" VARCHAR, \"info\".\"year\" VARCHAR, \"info\".\"color\" VARCHAR, \"info\".\"trim\" VARCHAR)"}' | jq .

  echo ""
  sleep "$((WAIT_SECONDS + 1))"

  # Verify views were created
  echo "Verifying view creation..."
  VIEWS_CHECK=$(curl -s "${API_URL}/views" | jq -r '.rows[] | select(.TABLE_NAME | test("ENGINE|TRANSMISSION|CHASSIS|VEHICLE"; "i")) | .TABLE_NAME' | sort)
  echo "Found views:"
  echo "$VIEWS_CHECK"
  echo ""
fi

# Step 6: Example Queries
if [[ "$SKIP_QUERIES" == true ]]; then
  echo "Step 6: Skipping example queries (--skip-queries)"
  echo ""
else
  echo "Step 6: Example queries..."
  echo ""

  echo "Query 1: Vehicle by VIN (IDs + info only)"
  echo "=========================================="
  curl -s -X POST "${API_URL}/query" \
    -H "Content-Type: application/json" \
    -d '{
      "sql": "SELECT \"rowkey\" as vin, \"info\".\"make\", \"info\".\"model\", \"info\".\"year\", \"ids\".\"engine_id\", \"ids\".\"transmission_id\", \"ids\".\"chassis_id\" FROM \"VEHICLE\" WHERE \"rowkey\" = '\''1HGCM82633A004352'\''"
    }' | jq '.rows[]'

  echo ""
  echo "Query 2: Complete vehicle view (JOIN all components)"
  echo "=========================================="
  curl -s -X POST "${API_URL}/query" \
    -H "Content-Type: application/json" \
    -d '{
      "sql": "SELECT v.\"rowkey\" as vin, v.\"info\".\"make\", v.\"info\".\"model\", v.\"info\".\"year\", e.\"specs\".\"horsepower\", t.\"specs\".\"type\", t.\"specs\".\"drive_type\", c.\"specs\".\"body_style\" FROM \"VEHICLE\" v JOIN \"ENGINE\" e ON v.\"ids\".\"engine_id\" = e.\"rowkey\" JOIN \"TRANSMISSION\" t ON v.\"ids\".\"transmission_id\" = t.\"rowkey\" JOIN \"CHASSIS\" c ON v.\"ids\".\"chassis_id\" = c.\"rowkey\" WHERE v.\"rowkey\" = '\''1HGCM82633A004352'\''"
    }' | jq '{rowCount, rows}'

  echo ""
  echo "Query 3: All vehicles using engine ENG001"
  echo "=========================================="
  curl -s -X POST "${API_URL}/query" \
    -H "Content-Type: application/json" \
    -d '{
      "sql": "SELECT \"rowkey\" as vin, \"info\".\"make\", \"info\".\"model\", \"info\".\"year\", \"ids\".\"engine_id\" FROM \"VEHICLE\" WHERE \"ids\".\"engine_id\" = '\''ENG001'\'' ORDER BY \"rowkey\""
    }' | jq '.rows[]'
  echo ""
fi

echo "=========================================="
echo "Done! Vehicle 360 tables created."
echo "=========================================="
echo ""
echo "Configuration used:"
echo "  API URL:   ${API_URL}"
echo "  Container: ${HBASE_CONTAINER}"
echo "  HBase bin: ${HBASE_BIN}"
echo ""
echo "Tables:"
echo "  - ENGINE       (row key: engine ID)"
echo "  - TRANSMISSION (row key: transmission ID)"
echo "  - CHASSIS      (row key: chassis ID)"
echo "  - VEHICLE      (row key: VIN; references component IDs)"
echo ""
echo "Example: Full vehicle build by VIN"
echo "  curl -X POST ${API_URL}/query -H 'Content-Type: application/json' \\"
echo "    -d '{\"sql\": \"SELECT v.\\\"rowkey\\\" as vin, v.\\\"info\\\".\\\"make\\\", e.\\\"specs\\\".\\\"horsepower\\\" FROM \\\"VEHICLE\\\" v JOIN \\\"ENGINE\\\" e ON v.\\\"ids\\\".\\\"engine_id\\\" = e.\\\"rowkey\\\" WHERE v.\\\"rowkey\\\" = '\\''1HGCM82633A004352'\\''\"}' | jq ."
echo ""
echo "Or run: ./run_vehicle360_queries.sh"
echo ""
