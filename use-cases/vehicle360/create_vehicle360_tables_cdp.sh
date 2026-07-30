#!/bin/bash

# Vehicle 360 — CDP Private Cloud Base 7.1.9
# Creates ENGINE / TRANSMISSION / CHASSIS / VEHICLE on cluster HBase via the
# local HBase client (edge/gateway node). Does NOT use Docker.
#
# Run this on a CDP edge node with HBase client configs deployed.
# User must provide Kerberos credentials (unless --skip-kinit) and, for
# Phoenix views/queries, an API URL reachable from that node.

set -euo pipefail

# ---------------------------------------------------------------------------
# Defaults (CDP 7.1.9 — no Docker; override via flags or env)
# ---------------------------------------------------------------------------
API_URL="${API_URL:-}"
HBASE_BIN="${HBASE_BIN:-}"
HBASE_CONF_DIR="${HBASE_CONF_DIR:-/etc/hbase/conf}"
KRB5_PRINCIPAL="${KRB5_PRINCIPAL:-}"
KRB5_KEYTAB="${KRB5_KEYTAB:-}"
NAMESPACE="${NAMESPACE:-}"
WAIT_SECONDS="${WAIT_SECONDS:-2}"
SKIP_KINIT=false
SKIP_VIEWS=false
SKIP_QUERIES=false

# Prefer CDP parcel path, then PATH
resolve_hbase_bin() {
  if [[ -n "${HBASE_BIN}" ]]; then
    echo "${HBASE_BIN}"
    return
  fi
  if [[ -x /opt/cloudera/parcels/CDH/bin/hbase ]]; then
    echo /opt/cloudera/parcels/CDH/bin/hbase
    return
  fi
  if command -v hbase >/dev/null 2>&1; then
    command -v hbase
    return
  fi
  echo ""
}

usage() {
  cat <<EOF
Usage: $(basename "$0") [options]

Create Vehicle 360 HBase tables on Cloudera Data Platform (CDP) 7.1.9.
Designed for an edge/gateway node with HBase client configuration.

Required for Kerberos clusters (typical on CDP):
  --principal PRINCIPAL   Kerberos principal (e.g. user@EXAMPLE.COM)
  --keytab PATH           Path to keytab for that principal

  Or set env: KRB5_PRINCIPAL, KRB5_KEYTAB
  Or pass --skip-kinit if you already ran kinit.

Options:
  --api-url URL           PhoenixDotNet / Phoenix REST API base URL
                          (required unless --skip-views and --skip-queries)
  --hbase-bin PATH        hbase client binary
                          (default: CDH parcel or hbase on PATH)
  --hbase-conf-dir DIR    HBase client conf dir
                          (default: ${HBASE_CONF_DIR})
  --namespace NAME        Optional HBase namespace (tables become NAME:ENGINE, …)
  --principal PRINCIPAL   Kerberos principal for kinit
  --keytab PATH           Kerberos keytab for kinit
  --skip-kinit            Skip kinit (use existing ticket)
  --skip-views            Skip Phoenix view creation
  --skip-queries          Skip example Phoenix queries
  --wait SECONDS          Wait after create/load (default: ${WAIT_SECONDS})
  -h, --help              Show this help

Environment variables:
  API_URL, HBASE_BIN, HBASE_CONF_DIR, KRB5_PRINCIPAL, KRB5_KEYTAB,
  NAMESPACE, WAIT_SECONDS

Cluster connectivity (ZooKeeper quorum, znode, TLS) must already be present
in hbase-site.xml under --hbase-conf-dir (deployed by Cloudera Manager).

Examples:
  $(basename "$0") \\
    --hbase-bin /opt/cloudera/parcels/CDH/bin/hbase \\
    --principal user@EXAMPLE.COM \\
    --keytab /etc/security/keytabs/user.keytab \\
    --api-url https://phoenix-api.example.com/api/phoenix

  # HBase data only (no Phoenix API)
  $(basename "$0") \\
    --hbase-bin /opt/cloudera/parcels/CDH/bin/hbase \\
    --principal user@EXAMPLE.COM \\
    --keytab /path/to/user.keytab \\
    --skip-views --skip-queries

  # Already authenticated
  kinit -kt /path/to/user.keytab user@EXAMPLE.COM
  $(basename "$0") \\
    --hbase-bin /opt/cloudera/parcels/CDH/bin/hbase \\
    --skip-kinit \\
    --api-url https://host/api/phoenix
EOF
}

table_name() {
  local base="$1"
  if [[ -n "${NAMESPACE}" ]]; then
    echo "${NAMESPACE}:${base}"
  else
    echo "${base}"
  fi
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --api-url)
      API_URL="$2"
      shift 2
      ;;
    --hbase-bin)
      HBASE_BIN="$2"
      shift 2
      ;;
    --hbase-conf-dir)
      HBASE_CONF_DIR="$2"
      shift 2
      ;;
    --namespace)
      NAMESPACE="$2"
      shift 2
      ;;
    --principal)
      KRB5_PRINCIPAL="$2"
      shift 2
      ;;
    --keytab)
      KRB5_KEYTAB="$2"
      shift 2
      ;;
    --skip-kinit)
      SKIP_KINIT=true
      shift
      ;;
    --skip-views)
      SKIP_VIEWS=true
      shift
      ;;
    --skip-queries)
      SKIP_QUERIES=true
      shift
      ;;
    --wait)
      WAIT_SECONDS="$2"
      shift 2
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

HBASE_BIN="$(resolve_hbase_bin)"
ENGINE_T="$(table_name ENGINE)"
TRANSMISSION_T="$(table_name TRANSMISSION)"
CHASSIS_T="$(table_name CHASSIS)"
VEHICLE_T="$(table_name VEHICLE)"

echo "=========================================="
echo "Create Vehicle 360 Tables (CDP 7.1.9)"
echo "=========================================="
echo "HBase binary:   ${HBASE_BIN:-"(not found)"}"
echo "HBase conf:     ${HBASE_CONF_DIR}"
echo "Namespace:      ${NAMESPACE:-"(default)"}"
echo "API URL:        ${API_URL:-"(none — views/queries skipped unless set)"}"
echo "Kerberos:       ${KRB5_PRINCIPAL:-"(skip-kinit or unset)"}"
echo ""

# ---------------------------------------------------------------------------
# Preconditions
# ---------------------------------------------------------------------------
if [[ -z "${HBASE_BIN}" ]]; then
  echo "ERROR: hbase client not found. Install CDP HBase gateway roles or pass --hbase-bin." >&2
  exit 1
fi
if [[ ! -x "${HBASE_BIN}" ]] && ! command -v "${HBASE_BIN}" >/dev/null 2>&1; then
  echo "ERROR: hbase client not executable: ${HBASE_BIN}" >&2
  exit 1
fi


if [[ ! -d "${HBASE_CONF_DIR}" ]]; then
  echo "ERROR: HBase conf dir not found: ${HBASE_CONF_DIR}" >&2
  echo "Pass --hbase-conf-dir pointing at client configs from Cloudera Manager." >&2
  exit 1
fi

export HBASE_CONF_DIR

if [[ "$SKIP_VIEWS" == false || "$SKIP_QUERIES" == false ]]; then
  if [[ -z "${API_URL}" ]]; then
    echo "ERROR: --api-url is required unless both --skip-views and --skip-queries are set." >&2
    exit 1
  fi
fi

if [[ "$SKIP_KINIT" == false ]]; then
  if [[ -z "${KRB5_PRINCIPAL}" || -z "${KRB5_KEYTAB}" ]]; then
    echo "ERROR: Kerberos --principal and --keytab are required (or use --skip-kinit)." >&2
    exit 1
  fi
  if [[ ! -f "${KRB5_KEYTAB}" ]]; then
    echo "ERROR: Keytab not found: ${KRB5_KEYTAB}" >&2
    exit 1
  fi
  if ! command -v kinit >/dev/null 2>&1; then
    echo "ERROR: kinit not found. Install Kerberos client packages on this edge node." >&2
    exit 1
  fi
  echo "Authenticating with Kerberos: ${KRB5_PRINCIPAL}"
  kinit -kt "${KRB5_KEYTAB}" "${KRB5_PRINCIPAL}"
  echo "Kerberos ticket:"
  klist 2>/dev/null | head -5 || true
  echo ""
else
  echo "Skipping kinit (--skip-kinit). Using existing Kerberos ticket (if any)."
  klist 2>/dev/null | head -5 || echo "  (no ticket listed)"
  echo ""
fi

# Optional namespace create (ignore error if it already exists)
if [[ -n "${NAMESPACE}" ]]; then
  echo "Ensuring HBase namespace '${NAMESPACE}' exists..."
  "${HBASE_BIN}" shell -n <<EOF || true
create_namespace '${NAMESPACE}'
EOF
  echo ""
fi

# Run HBase shell on this edge node (CDP client configs via HBASE_CONF_DIR).
hbase_shell() {
  "${HBASE_BIN}" shell -n
}

# Step 1: Create HBase Tables
echo "Step 1: Creating HBase tables..."
echo ""

echo "  Creating ${ENGINE_T}..."
hbase_shell <<EOF
create '${ENGINE_T}', 'specs'
EOF

echo "  Creating ${TRANSMISSION_T}..."
hbase_shell <<EOF
create '${TRANSMISSION_T}', 'specs'
EOF

echo "  Creating ${CHASSIS_T}..."
hbase_shell <<EOF
create '${CHASSIS_T}', 'specs'
EOF

echo "  Creating ${VEHICLE_T}..."
hbase_shell <<EOF
create '${VEHICLE_T}', 'ids', 'info'
EOF

echo ""
sleep "$WAIT_SECONDS"

# Step 2: Insert Component Catalog Data
echo "Step 2: Inserting component catalog data..."
echo ""

echo "  Inserting engines (ENG001-ENG005)..."
hbase_shell <<EOF
put '${ENGINE_T}', 'ENG001', 'specs:manufacturer', 'Honda'
put '${ENGINE_T}', 'ENG001', 'specs:model', 'K24Z7'
put '${ENGINE_T}', 'ENG001', 'specs:displacement_l', '2.4'
put '${ENGINE_T}', 'ENG001', 'specs:cylinders', '4'
put '${ENGINE_T}', 'ENG001', 'specs:horsepower', '185'
put '${ENGINE_T}', 'ENG001', 'specs:fuel_type', 'Gasoline'

put '${ENGINE_T}', 'ENG002', 'specs:manufacturer', 'Toyota'
put '${ENGINE_T}', 'ENG002', 'specs:model', '2GR-FE'
put '${ENGINE_T}', 'ENG002', 'specs:displacement_l', '3.5'
put '${ENGINE_T}', 'ENG002', 'specs:cylinders', '6'
put '${ENGINE_T}', 'ENG002', 'specs:horsepower', '268'
put '${ENGINE_T}', 'ENG002', 'specs:fuel_type', 'Gasoline'

put '${ENGINE_T}', 'ENG003', 'specs:manufacturer', 'Ford'
put '${ENGINE_T}', 'ENG003', 'specs:model', 'EcoBoost 2.3'
put '${ENGINE_T}', 'ENG003', 'specs:displacement_l', '2.3'
put '${ENGINE_T}', 'ENG003', 'specs:cylinders', '4'
put '${ENGINE_T}', 'ENG003', 'specs:horsepower', '310'
put '${ENGINE_T}', 'ENG003', 'specs:fuel_type', 'Gasoline'

put '${ENGINE_T}', 'ENG004', 'specs:manufacturer', 'BMW'
put '${ENGINE_T}', 'ENG004', 'specs:model', 'B58B30'
put '${ENGINE_T}', 'ENG004', 'specs:displacement_l', '3.0'
put '${ENGINE_T}', 'ENG004', 'specs:cylinders', '6'
put '${ENGINE_T}', 'ENG004', 'specs:horsepower', '382'
put '${ENGINE_T}', 'ENG004', 'specs:fuel_type', 'Gasoline'

put '${ENGINE_T}', 'ENG005', 'specs:manufacturer', 'Tesla'
put '${ENGINE_T}', 'ENG005', 'specs:model', 'Dual Motor'
put '${ENGINE_T}', 'ENG005', 'specs:displacement_l', '0'
put '${ENGINE_T}', 'ENG005', 'specs:cylinders', '0'
put '${ENGINE_T}', 'ENG005', 'specs:horsepower', '670'
put '${ENGINE_T}', 'ENG005', 'specs:fuel_type', 'Electric'
EOF

echo "  Inserting transmissions (TRN001-TRN004)..."
hbase_shell <<EOF
put '${TRANSMISSION_T}', 'TRN001', 'specs:manufacturer', 'Honda'
put '${TRANSMISSION_T}', 'TRN001', 'specs:model', 'CVT-7'
put '${TRANSMISSION_T}', 'TRN001', 'specs:type', 'CVT'
put '${TRANSMISSION_T}', 'TRN001', 'specs:gears', '0'
put '${TRANSMISSION_T}', 'TRN001', 'specs:drive_type', 'FWD'

put '${TRANSMISSION_T}', 'TRN002', 'specs:manufacturer', 'Aisin'
put '${TRANSMISSION_T}', 'TRN002', 'specs:model', 'U660E'
put '${TRANSMISSION_T}', 'TRN002', 'specs:type', 'Automatic'
put '${TRANSMISSION_T}', 'TRN002', 'specs:gears', '6'
put '${TRANSMISSION_T}', 'TRN002', 'specs:drive_type', 'AWD'

put '${TRANSMISSION_T}', 'TRN003', 'specs:manufacturer', 'Getrag'
put '${TRANSMISSION_T}', 'TRN003', 'specs:model', 'MT82'
put '${TRANSMISSION_T}', 'TRN003', 'specs:type', 'Manual'
put '${TRANSMISSION_T}', 'TRN003', 'specs:gears', '6'
put '${TRANSMISSION_T}', 'TRN003', 'specs:drive_type', 'RWD'

put '${TRANSMISSION_T}', 'TRN004', 'specs:manufacturer', 'ZF'
put '${TRANSMISSION_T}', 'TRN004', 'specs:model', '8HP50'
put '${TRANSMISSION_T}', 'TRN004', 'specs:type', 'Automatic'
put '${TRANSMISSION_T}', 'TRN004', 'specs:gears', '8'
put '${TRANSMISSION_T}', 'TRN004', 'specs:drive_type', 'RWD'
EOF

echo "  Inserting chassis (CHS001-CHS004)..."
hbase_shell <<EOF
put '${CHASSIS_T}', 'CHS001', 'specs:body_style', 'Sedan'
put '${CHASSIS_T}', 'CHS001', 'specs:material', 'Steel'
put '${CHASSIS_T}', 'CHS001', 'specs:wheelbase_in', '106.3'
put '${CHASSIS_T}', 'CHS001', 'specs:curb_weight_lb', '3200'
put '${CHASSIS_T}', 'CHS001', 'specs:doors', '4'

put '${CHASSIS_T}', 'CHS002', 'specs:body_style', 'SUV'
put '${CHASSIS_T}', 'CHS002', 'specs:material', 'Steel'
put '${CHASSIS_T}', 'CHS002', 'specs:wheelbase_in', '112.2'
put '${CHASSIS_T}', 'CHS002', 'specs:curb_weight_lb', '4100'
put '${CHASSIS_T}', 'CHS002', 'specs:doors', '4'

put '${CHASSIS_T}', 'CHS003', 'specs:body_style', 'Coupe'
put '${CHASSIS_T}', 'CHS003', 'specs:material', 'Aluminum'
put '${CHASSIS_T}', 'CHS003', 'specs:wheelbase_in', '107.1'
put '${CHASSIS_T}', 'CHS003', 'specs:curb_weight_lb', '3700'
put '${CHASSIS_T}', 'CHS003', 'specs:doors', '2'

put '${CHASSIS_T}', 'CHS004', 'specs:body_style', 'Hatchback'
put '${CHASSIS_T}', 'CHS004', 'specs:material', 'Aluminum'
put '${CHASSIS_T}', 'CHS004', 'specs:wheelbase_in', '113.8'
put '${CHASSIS_T}', 'CHS004', 'specs:curb_weight_lb', '4500'
put '${CHASSIS_T}', 'CHS004', 'specs:doors', '4'
EOF

echo ""
echo "Step 3: Inserting vehicles (VIN assembly rows)..."
echo ""

echo "  Inserting 7 vehicles with shared component references..."
hbase_shell <<EOF
put '${VEHICLE_T}', '1HGCM82633A004352', 'ids:engine_id', 'ENG001'
put '${VEHICLE_T}', '1HGCM82633A004352', 'ids:transmission_id', 'TRN001'
put '${VEHICLE_T}', '1HGCM82633A004352', 'ids:chassis_id', 'CHS001'
put '${VEHICLE_T}', '1HGCM82633A004352', 'info:make', 'Honda'
put '${VEHICLE_T}', '1HGCM82633A004352', 'info:model', 'Civic'
put '${VEHICLE_T}', '1HGCM82633A004352', 'info:year', '2022'
put '${VEHICLE_T}', '1HGCM82633A004352', 'info:color', 'Blue'
put '${VEHICLE_T}', '1HGCM82633A004352', 'info:trim', 'EX'

put '${VEHICLE_T}', '1HGCV1F30JA000123', 'ids:engine_id', 'ENG001'
put '${VEHICLE_T}', '1HGCV1F30JA000123', 'ids:transmission_id', 'TRN001'
put '${VEHICLE_T}', '1HGCV1F30JA000123', 'ids:chassis_id', 'CHS001'
put '${VEHICLE_T}', '1HGCV1F30JA000123', 'info:make', 'Honda'
put '${VEHICLE_T}', '1HGCV1F30JA000123', 'info:model', 'Accord'
put '${VEHICLE_T}', '1HGCV1F30JA000123', 'info:year', '2023'
put '${VEHICLE_T}', '1HGCV1F30JA000123', 'info:color', 'Silver'
put '${VEHICLE_T}', '1HGCV1F30JA000123', 'info:trim', 'Sport'

put '${VEHICLE_T}', '5TDKZRFH0KS123456', 'ids:engine_id', 'ENG002'
put '${VEHICLE_T}', '5TDKZRFH0KS123456', 'ids:transmission_id', 'TRN002'
put '${VEHICLE_T}', '5TDKZRFH0KS123456', 'ids:chassis_id', 'CHS002'
put '${VEHICLE_T}', '5TDKZRFH0KS123456', 'info:make', 'Toyota'
put '${VEHICLE_T}', '5TDKZRFH0KS123456', 'info:model', 'Highlander'
put '${VEHICLE_T}', '5TDKZRFH0KS123456', 'info:year', '2021'
put '${VEHICLE_T}', '5TDKZRFH0KS123456', 'info:color', 'White'
put '${VEHICLE_T}', '5TDKZRFH0KS123456', 'info:trim', 'XLE'

put '${VEHICLE_T}', '2T3P1RFV8MW078901', 'ids:engine_id', 'ENG002'
put '${VEHICLE_T}', '2T3P1RFV8MW078901', 'ids:transmission_id', 'TRN002'
put '${VEHICLE_T}', '2T3P1RFV8MW078901', 'ids:chassis_id', 'CHS002'
put '${VEHICLE_T}', '2T3P1RFV8MW078901', 'info:make', 'Toyota'
put '${VEHICLE_T}', '2T3P1RFV8MW078901', 'info:model', 'RAV4'
put '${VEHICLE_T}', '2T3P1RFV8MW078901', 'info:year', '2024'
put '${VEHICLE_T}', '2T3P1RFV8MW078901', 'info:color', 'Black'
put '${VEHICLE_T}', '2T3P1RFV8MW078901', 'info:trim', 'Adventure'

put '${VEHICLE_T}', '1FA6P8CF5L5102345', 'ids:engine_id', 'ENG003'
put '${VEHICLE_T}', '1FA6P8CF5L5102345', 'ids:transmission_id', 'TRN003'
put '${VEHICLE_T}', '1FA6P8CF5L5102345', 'ids:chassis_id', 'CHS003'
put '${VEHICLE_T}', '1FA6P8CF5L5102345', 'info:make', 'Ford'
put '${VEHICLE_T}', '1FA6P8CF5L5102345', 'info:model', 'Mustang'
put '${VEHICLE_T}', '1FA6P8CF5L5102345', 'info:year', '2020'
put '${VEHICLE_T}', '1FA6P8CF5L5102345', 'info:color', 'Red'
put '${VEHICLE_T}', '1FA6P8CF5L5102345', 'info:trim', 'GT'

put '${VEHICLE_T}', 'WBA5U9C05LF345678', 'ids:engine_id', 'ENG004'
put '${VEHICLE_T}', 'WBA5U9C05LF345678', 'ids:transmission_id', 'TRN004'
put '${VEHICLE_T}', 'WBA5U9C05LF345678', 'ids:chassis_id', 'CHS001'
put '${VEHICLE_T}', 'WBA5U9C05LF345678', 'info:make', 'BMW'
put '${VEHICLE_T}', 'WBA5U9C05LF345678', 'info:model', 'M340i'
put '${VEHICLE_T}', 'WBA5U9C05LF345678', 'info:year', '2023'
put '${VEHICLE_T}', 'WBA5U9C05LF345678', 'info:color', 'Gray'
put '${VEHICLE_T}', 'WBA5U9C05LF345678', 'info:trim', 'xDrive'

put '${VEHICLE_T}', '5YJ3E1EA1KF789012', 'ids:engine_id', 'ENG005'
put '${VEHICLE_T}', '5YJ3E1EA1KF789012', 'ids:transmission_id', 'TRN004'
put '${VEHICLE_T}', '5YJ3E1EA1KF789012', 'ids:chassis_id', 'CHS004'
put '${VEHICLE_T}', '5YJ3E1EA1KF789012', 'info:make', 'Tesla'
put '${VEHICLE_T}', '5YJ3E1EA1KF789012', 'info:model', 'Model Y'
put '${VEHICLE_T}', '5YJ3E1EA1KF789012', 'info:year', '2024'
put '${VEHICLE_T}', '5YJ3E1EA1KF789012', 'info:color', 'White'
put '${VEHICLE_T}', '5YJ3E1EA1KF789012', 'info:trim', 'Performance'
EOF

echo ""
sleep "$WAIT_SECONDS"

# Step 4: Verify data in HBase
echo "Step 4: Verifying data in HBase..."
echo ""
echo "scan '${VEHICLE_T}', {LIMIT => 2}" | hbase_shell | grep -A 10 "ROW  COLUMN" | head -15 || true
echo ""

# Phoenix view names (unqualified; API layer must map to cluster tables)
ENGINE_V="ENGINE"
TRANSMISSION_V="TRANSMISSION"
CHASSIS_V="CHASSIS"
VEHICLE_V="VEHICLE"

# Step 5: Create Phoenix Views
if [[ "$SKIP_VIEWS" == true ]]; then
  echo "Step 5: Skipping Phoenix view creation (--skip-views)"
  echo ""
else
  echo "Step 5: Creating Phoenix views via ${API_URL}..."
  echo ""

  if ! command -v curl >/dev/null 2>&1; then
    echo "ERROR: curl is required for Phoenix API calls." >&2
    exit 1
  fi

  echo "  Creating ENGINE view..."
  curl -s -X POST "${API_URL}/execute" \
    -H "Content-Type: application/json" \
    -d "{\"sql\": \"CREATE VIEW IF NOT EXISTS \\\"${ENGINE_V}\\\" (\\\"rowkey\\\" VARCHAR PRIMARY KEY, \\\"specs\\\".\\\"manufacturer\\\" VARCHAR, \\\"specs\\\".\\\"model\\\" VARCHAR, \\\"specs\\\".\\\"displacement_l\\\" VARCHAR, \\\"specs\\\".\\\"cylinders\\\" VARCHAR, \\\"specs\\\".\\\"horsepower\\\" VARCHAR, \\\"specs\\\".\\\"fuel_type\\\" VARCHAR)\"}" | (command -v jq >/dev/null && jq . || cat)

  echo "  Creating TRANSMISSION view..."
  curl -s -X POST "${API_URL}/execute" \
    -H "Content-Type: application/json" \
    -d "{\"sql\": \"CREATE VIEW IF NOT EXISTS \\\"${TRANSMISSION_V}\\\" (\\\"rowkey\\\" VARCHAR PRIMARY KEY, \\\"specs\\\".\\\"manufacturer\\\" VARCHAR, \\\"specs\\\".\\\"model\\\" VARCHAR, \\\"specs\\\".\\\"type\\\" VARCHAR, \\\"specs\\\".\\\"gears\\\" VARCHAR, \\\"specs\\\".\\\"drive_type\\\" VARCHAR)\"}" | (command -v jq >/dev/null && jq . || cat)

  echo "  Creating CHASSIS view..."
  curl -s -X POST "${API_URL}/execute" \
    -H "Content-Type: application/json" \
    -d "{\"sql\": \"CREATE VIEW IF NOT EXISTS \\\"${CHASSIS_V}\\\" (\\\"rowkey\\\" VARCHAR PRIMARY KEY, \\\"specs\\\".\\\"body_style\\\" VARCHAR, \\\"specs\\\".\\\"material\\\" VARCHAR, \\\"specs\\\".\\\"wheelbase_in\\\" VARCHAR, \\\"specs\\\".\\\"curb_weight_lb\\\" VARCHAR, \\\"specs\\\".\\\"doors\\\" VARCHAR)\"}" | (command -v jq >/dev/null && jq . || cat)

  echo "  Creating VEHICLE view..."
  curl -s -X POST "${API_URL}/execute" \
    -H "Content-Type: application/json" \
    -d "{\"sql\": \"CREATE VIEW IF NOT EXISTS \\\"${VEHICLE_V}\\\" (\\\"rowkey\\\" VARCHAR PRIMARY KEY, \\\"ids\\\".\\\"engine_id\\\" VARCHAR, \\\"ids\\\".\\\"transmission_id\\\" VARCHAR, \\\"ids\\\".\\\"chassis_id\\\" VARCHAR, \\\"info\\\".\\\"make\\\" VARCHAR, \\\"info\\\".\\\"model\\\" VARCHAR, \\\"info\\\".\\\"year\\\" VARCHAR, \\\"info\\\".\\\"color\\\" VARCHAR, \\\"info\\\".\\\"trim\\\" VARCHAR)\"}" | (command -v jq >/dev/null && jq . || cat)

  echo ""
  sleep "$((WAIT_SECONDS + 1))"
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
    -d "{\"sql\": \"SELECT \\\"rowkey\\\" as vin, \\\"info\\\".\\\"make\\\", \\\"info\\\".\\\"model\\\", \\\"info\\\".\\\"year\\\", \\\"ids\\\".\\\"engine_id\\\", \\\"ids\\\".\\\"transmission_id\\\", \\\"ids\\\".\\\"chassis_id\\\" FROM \\\"${VEHICLE_V}\\\" WHERE \\\"rowkey\\\" = '1HGCM82633A004352'\"}" \
    | (command -v jq >/dev/null && jq '{rowCount, rows}' || cat)

  echo ""
  echo "Query 2: Complete vehicle view (JOIN all components)"
  echo "=========================================="
  curl -s -X POST "${API_URL}/query" \
    -H "Content-Type: application/json" \
    -d "{\"sql\": \"SELECT v.\\\"rowkey\\\" as vin, v.\\\"info\\\".\\\"make\\\", v.\\\"info\\\".\\\"model\\\", v.\\\"info\\\".\\\"year\\\", e.\\\"specs\\\".\\\"horsepower\\\", t.\\\"specs\\\".\\\"type\\\", t.\\\"specs\\\".\\\"drive_type\\\", c.\\\"specs\\\".\\\"body_style\\\" FROM \\\"${VEHICLE_V}\\\" v JOIN \\\"${ENGINE_V}\\\" e ON v.\\\"ids\\\".\\\"engine_id\\\" = e.\\\"rowkey\\\" JOIN \\\"${TRANSMISSION_V}\\\" t ON v.\\\"ids\\\".\\\"transmission_id\\\" = t.\\\"rowkey\\\" JOIN \\\"${CHASSIS_V}\\\" c ON v.\\\"ids\\\".\\\"chassis_id\\\" = c.\\\"rowkey\\\" WHERE v.\\\"rowkey\\\" = '1HGCM82633A004352'\"}" \
    | (command -v jq >/dev/null && jq '{rowCount, rows}' || cat)

  echo ""
  echo "Query 3: All vehicles using engine ENG001"
  echo "=========================================="
  curl -s -X POST "${API_URL}/query" \
    -H "Content-Type: application/json" \
    -d "{\"sql\": \"SELECT \\\"rowkey\\\" as vin, \\\"info\\\".\\\"make\\\", \\\"info\\\".\\\"model\\\", \\\"info\\\".\\\"year\\\", \\\"ids\\\".\\\"engine_id\\\" FROM \\\"${VEHICLE_V}\\\" WHERE \\\"ids\\\".\\\"engine_id\\\" = 'ENG001' ORDER BY \\\"rowkey\\\"\"}" \
    | (command -v jq >/dev/null && jq '{rowCount, rows}' || cat)
  echo ""
fi

echo "=========================================="
echo "Done! Vehicle 360 tables created on CDP."
echo "=========================================="
echo ""
echo "Configuration used:"
echo "  HBase binary: ${HBASE_BIN}"
echo "  HBase conf:   ${HBASE_CONF_DIR}"
echo "  Namespace:    ${NAMESPACE:-"(default)"}"
echo "  Tables:       ${ENGINE_T}, ${TRANSMISSION_T}, ${CHASSIS_T}, ${VEHICLE_T}"
echo "  API URL:      ${API_URL:-"(n/a)"}"
echo ""
echo "Prerequisites satisfied by user / Cloudera Manager:"
echo "  - Edge node with HBase gateway client configs"
echo "  - ZooKeeper quorum & security settings in hbase-site.xml"
echo "  - Kerberos principal/keytab (or existing ticket)"
echo "  - Ranger (or ACL) rights to create/write these tables"
echo ""
