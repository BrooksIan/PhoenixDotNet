#!/bin/bash

# Vehicle 360 — CDP Private Cloud Base 7.1.9
# Type catalogs + DEVICE + build tables + VIN assembly on cluster HBase via the
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

Create Vehicle 360 type catalogs, build tables, and VIN assembly on
Cloudera Data Platform (CDP) 7.1.9 (edge/gateway node; no Docker).

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
ENGINE_BUILD_T="$(table_name ENGINE_BUILD)"
TRANSMISSION_BUILD_T="$(table_name TRANSMISSION_BUILD)"
CHASSIS_BUILD_T="$(table_name CHASSIS_BUILD)"
DEVICE_T="$(table_name DEVICE)"

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

echo "Step 1: Creating HBase type + device + build tables..."
echo ""

echo "  Creating type catalogs..."
hbase_shell <<EOF
create '${ENGINE_T}', 'specs'
create '${TRANSMISSION_T}', 'specs'
create '${CHASSIS_T}', 'specs'
EOF

echo "  Creating DEVICE catalog..."
hbase_shell <<EOF
create '${DEVICE_T}', 'specs'
EOF

echo "  Creating build tables..."
hbase_shell <<EOF
create '${ENGINE_BUILD_T}', 'ids', 'production'
create '${TRANSMISSION_BUILD_T}', 'ids', 'production'
create '${CHASSIS_BUILD_T}', 'ids', 'production'
EOF

echo "  Creating VEHICLE..."
hbase_shell <<EOF
create '${VEHICLE_T}', 'ids', 'info'
EOF

echo ""
sleep "$WAIT_SECONDS"

echo "Step 2: Inserting type catalogs + devices..."
echo ""

echo "  Engines (ENG001-ENG005)..."
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

echo "  Transmissions (TRN001-TRN004)..."
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

echo "  Chassis (CHS001-CHS004)..."
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

echo "  Devices (DEV001-DEV012)..."
hbase_shell <<EOF
put '${DEVICE_T}', 'DEV001', 'specs:name', 'K24 Block Line Robot'
put '${DEVICE_T}', 'DEV001', 'specs:device_type', 'Robot'
put '${DEVICE_T}', 'DEV001', 'specs:manufacturer', 'Fanuc'
put '${DEVICE_T}', 'DEV001', 'specs:model', 'R-2000iC'
put '${DEVICE_T}', 'DEV001', 'specs:plant_code', 'MARYSVILLE'
put '${DEVICE_T}', 'DEV001', 'specs:status', 'ACTIVE'
put '${DEVICE_T}', 'DEV002', 'specs:name', 'Marysville Torque Station'
put '${DEVICE_T}', 'DEV002', 'specs:device_type', 'TorqueStation'
put '${DEVICE_T}', 'DEV002', 'specs:manufacturer', 'Atlas Copco'
put '${DEVICE_T}', 'DEV002', 'specs:model', 'PowerFocus 6000'
put '${DEVICE_T}', 'DEV002', 'specs:plant_code', 'MARYSVILLE'
put '${DEVICE_T}', 'DEV002', 'specs:status', 'ACTIVE'
put '${DEVICE_T}', 'DEV003', 'specs:name', 'Georgetown CNC Cell'
put '${DEVICE_T}', 'DEV003', 'specs:device_type', 'CNC'
put '${DEVICE_T}', 'DEV003', 'specs:manufacturer', 'Mazak'
put '${DEVICE_T}', 'DEV003', 'specs:model', 'INTEGREX i-200'
put '${DEVICE_T}', 'DEV003', 'specs:plant_code', 'GEORGETOWN'
put '${DEVICE_T}', 'DEV003', 'specs:status', 'ACTIVE'
put '${DEVICE_T}', 'DEV004', 'specs:name', 'Georgetown Hot Test Cell'
put '${DEVICE_T}', 'DEV004', 'specs:device_type', 'TestCell'
put '${DEVICE_T}', 'DEV004', 'specs:manufacturer', 'AVL'
put '${DEVICE_T}', 'DEV004', 'specs:model', 'PUMA Open'
put '${DEVICE_T}', 'DEV004', 'specs:plant_code', 'GEORGETOWN'
put '${DEVICE_T}', 'DEV004', 'specs:status', 'ACTIVE'
put '${DEVICE_T}', 'DEV005', 'specs:name', 'Flatrock Stamping Press'
put '${DEVICE_T}', 'DEV005', 'specs:device_type', 'Press'
put '${DEVICE_T}', 'DEV005', 'specs:manufacturer', 'Schuler'
put '${DEVICE_T}', 'DEV005', 'specs:model', 'MSP 400'
put '${DEVICE_T}', 'DEV005', 'specs:plant_code', 'FLATROCK'
put '${DEVICE_T}', 'DEV005', 'specs:status', 'ACTIVE'
put '${DEVICE_T}', 'DEV006', 'specs:name', 'Munich B58 CNC Line'
put '${DEVICE_T}', 'DEV006', 'specs:device_type', 'CNC'
put '${DEVICE_T}', 'DEV006', 'specs:manufacturer', 'DMG Mori'
put '${DEVICE_T}', 'DEV006', 'specs:model', 'NLX 2500'
put '${DEVICE_T}', 'DEV006', 'specs:plant_code', 'MUNICH'
put '${DEVICE_T}', 'DEV006', 'specs:status', 'ACTIVE'
put '${DEVICE_T}', 'DEV007', 'specs:name', 'Fremont Drive Unit Robot'
put '${DEVICE_T}', 'DEV007', 'specs:device_type', 'Robot'
put '${DEVICE_T}', 'DEV007', 'specs:manufacturer', 'KUKA'
put '${DEVICE_T}', 'DEV007', 'specs:model', 'KR QUANTEC'
put '${DEVICE_T}', 'DEV007', 'specs:plant_code', 'FREMONT'
put '${DEVICE_T}', 'DEV007', 'specs:status', 'ACTIVE'
put '${DEVICE_T}', 'DEV008', 'specs:name', 'East Liberty Body Fixture'
put '${DEVICE_T}', 'DEV008', 'specs:device_type', 'Press'
put '${DEVICE_T}', 'DEV008', 'specs:manufacturer', 'Comau'
put '${DEVICE_T}', 'DEV008', 'specs:model', 'SmartCell'
put '${DEVICE_T}', 'DEV008', 'specs:plant_code', 'EAST-LIBERTY'
put '${DEVICE_T}', 'DEV008', 'specs:status', 'MAINTENANCE'
put '${DEVICE_T}', 'DEV009', 'specs:name', 'Aisin Gear Hobber'
put '${DEVICE_T}', 'DEV009', 'specs:device_type', 'CNC'
put '${DEVICE_T}', 'DEV009', 'specs:manufacturer', 'Gleason'
put '${DEVICE_T}', 'DEV009', 'specs:model', 'P90'
put '${DEVICE_T}', 'DEV009', 'specs:plant_code', 'AISIN-IN'
put '${DEVICE_T}', 'DEV009', 'specs:status', 'ACTIVE'
put '${DEVICE_T}', 'DEV010', 'specs:name', 'Getrag Manual Line Robot'
put '${DEVICE_T}', 'DEV010', 'specs:device_type', 'Robot'
put '${DEVICE_T}', 'DEV010', 'specs:manufacturer', 'ABB'
put '${DEVICE_T}', 'DEV010', 'specs:model', 'IRB 6700'
put '${DEVICE_T}', 'DEV010', 'specs:plant_code', 'GETRAG-MI'
put '${DEVICE_T}', 'DEV010', 'specs:status', 'ACTIVE'
put '${DEVICE_T}', 'DEV011', 'specs:name', 'ZF 8HP Torque Station'
put '${DEVICE_T}', 'DEV011', 'specs:device_type', 'TorqueStation'
put '${DEVICE_T}', 'DEV011', 'specs:manufacturer', 'Bosch Rexroth'
put '${DEVICE_T}', 'DEV011', 'specs:model', 'Tightening System'
put '${DEVICE_T}', 'DEV011', 'specs:plant_code', 'ZF-SC'
put '${DEVICE_T}', 'DEV011', 'specs:status', 'ACTIVE'
put '${DEVICE_T}', 'DEV012', 'specs:name', 'Princeton Body Framing Cell'
put '${DEVICE_T}', 'DEV012', 'specs:device_type', 'Robot'
put '${DEVICE_T}', 'DEV012', 'specs:manufacturer', 'Fanuc'
put '${DEVICE_T}', 'DEV012', 'specs:model', 'R-1000iA'
put '${DEVICE_T}', 'DEV012', 'specs:plant_code', 'PRINCETON'
put '${DEVICE_T}', 'DEV012', 'specs:status', 'ACTIVE'
EOF

echo ""
echo "Step 3: Inserting physical builds (production metadata)..."
echo ""

echo "  ENGINE_BUILD rows..."
hbase_shell <<EOF
put '${ENGINE_BUILD_T}', 'EB-ENG001-00001', 'ids:engine_type_id', 'ENG001'
put '${ENGINE_BUILD_T}', 'EB-ENG001-00001', 'ids:device_id', 'DEV001'
put '${ENGINE_BUILD_T}', 'EB-ENG001-00001', 'production:build_date', '2022-03-12'
put '${ENGINE_BUILD_T}', 'EB-ENG001-00001', 'production:plant_code', 'MARYSVILLE'
put '${ENGINE_BUILD_T}', 'EB-ENG001-00001', 'production:line_id', 'L2'
put '${ENGINE_BUILD_T}', 'EB-ENG001-00001', 'production:shift', 'A'
put '${ENGINE_BUILD_T}', 'EB-ENG001-00001', 'production:batch_number', 'H22-031'
put '${ENGINE_BUILD_T}', 'EB-ENG001-00001', 'production:serial_number', '00001'
put '${ENGINE_BUILD_T}', 'EB-ENG001-00001', 'production:qc_status', 'PASS'
put '${ENGINE_BUILD_T}', 'EB-ENG001-00001', 'production:operator_id', 'OP-1042'

put '${ENGINE_BUILD_T}', 'EB-ENG001-00002', 'ids:engine_type_id', 'ENG001'
put '${ENGINE_BUILD_T}', 'EB-ENG001-00002', 'ids:device_id', 'DEV002'
put '${ENGINE_BUILD_T}', 'EB-ENG001-00002', 'production:build_date', '2023-01-18'
put '${ENGINE_BUILD_T}', 'EB-ENG001-00002', 'production:plant_code', 'MARYSVILLE'
put '${ENGINE_BUILD_T}', 'EB-ENG001-00002', 'production:line_id', 'L2'
put '${ENGINE_BUILD_T}', 'EB-ENG001-00002', 'production:shift', 'B'
put '${ENGINE_BUILD_T}', 'EB-ENG001-00002', 'production:batch_number', 'H23-012'
put '${ENGINE_BUILD_T}', 'EB-ENG001-00002', 'production:serial_number', '00002'
put '${ENGINE_BUILD_T}', 'EB-ENG001-00002', 'production:qc_status', 'PASS'
put '${ENGINE_BUILD_T}', 'EB-ENG001-00002', 'production:operator_id', 'OP-1108'

put '${ENGINE_BUILD_T}', 'EB-ENG002-00001', 'ids:engine_type_id', 'ENG002'
put '${ENGINE_BUILD_T}', 'EB-ENG002-00001', 'ids:device_id', 'DEV003'
put '${ENGINE_BUILD_T}', 'EB-ENG002-00001', 'production:build_date', '2021-06-04'
put '${ENGINE_BUILD_T}', 'EB-ENG002-00001', 'production:plant_code', 'GEORGETOWN'
put '${ENGINE_BUILD_T}', 'EB-ENG002-00001', 'production:line_id', 'L1'
put '${ENGINE_BUILD_T}', 'EB-ENG002-00001', 'production:shift', 'A'
put '${ENGINE_BUILD_T}', 'EB-ENG002-00001', 'production:batch_number', 'T21-088'
put '${ENGINE_BUILD_T}', 'EB-ENG002-00001', 'production:serial_number', '00001'
put '${ENGINE_BUILD_T}', 'EB-ENG002-00001', 'production:qc_status', 'PASS'
put '${ENGINE_BUILD_T}', 'EB-ENG002-00001', 'production:operator_id', 'OP-2201'

put '${ENGINE_BUILD_T}', 'EB-ENG002-00002', 'ids:engine_type_id', 'ENG002'
put '${ENGINE_BUILD_T}', 'EB-ENG002-00002', 'ids:device_id', 'DEV004'
put '${ENGINE_BUILD_T}', 'EB-ENG002-00002', 'production:build_date', '2024-02-09'
put '${ENGINE_BUILD_T}', 'EB-ENG002-00002', 'production:plant_code', 'GEORGETOWN'
put '${ENGINE_BUILD_T}', 'EB-ENG002-00002', 'production:line_id', 'L1'
put '${ENGINE_BUILD_T}', 'EB-ENG002-00002', 'production:shift', 'C'
put '${ENGINE_BUILD_T}', 'EB-ENG002-00002', 'production:batch_number', 'T24-019'
put '${ENGINE_BUILD_T}', 'EB-ENG002-00002', 'production:serial_number', '00002'
put '${ENGINE_BUILD_T}', 'EB-ENG002-00002', 'production:qc_status', 'PASS'
put '${ENGINE_BUILD_T}', 'EB-ENG002-00002', 'production:operator_id', 'OP-2215'

put '${ENGINE_BUILD_T}', 'EB-ENG003-00001', 'ids:engine_type_id', 'ENG003'
put '${ENGINE_BUILD_T}', 'EB-ENG003-00001', 'ids:device_id', 'DEV005'
put '${ENGINE_BUILD_T}', 'EB-ENG003-00001', 'production:build_date', '2020-08-21'
put '${ENGINE_BUILD_T}', 'EB-ENG003-00001', 'production:plant_code', 'FLATROCK'
put '${ENGINE_BUILD_T}', 'EB-ENG003-00001', 'production:line_id', 'L4'
put '${ENGINE_BUILD_T}', 'EB-ENG003-00001', 'production:shift', 'A'
put '${ENGINE_BUILD_T}', 'EB-ENG003-00001', 'production:batch_number', 'F20-142'
put '${ENGINE_BUILD_T}', 'EB-ENG003-00001', 'production:serial_number', '00001'
put '${ENGINE_BUILD_T}', 'EB-ENG003-00001', 'production:qc_status', 'PASS'
put '${ENGINE_BUILD_T}', 'EB-ENG003-00001', 'production:operator_id', 'OP-3304'

put '${ENGINE_BUILD_T}', 'EB-ENG004-00001', 'ids:engine_type_id', 'ENG004'
put '${ENGINE_BUILD_T}', 'EB-ENG004-00001', 'ids:device_id', 'DEV006'
put '${ENGINE_BUILD_T}', 'EB-ENG004-00001', 'production:build_date', '2023-05-30'
put '${ENGINE_BUILD_T}', 'EB-ENG004-00001', 'production:plant_code', 'MUNICH'
put '${ENGINE_BUILD_T}', 'EB-ENG004-00001', 'production:line_id', 'L7'
put '${ENGINE_BUILD_T}', 'EB-ENG004-00001', 'production:shift', 'B'
put '${ENGINE_BUILD_T}', 'EB-ENG004-00001', 'production:batch_number', 'B23-077'
put '${ENGINE_BUILD_T}', 'EB-ENG004-00001', 'production:serial_number', '00001'
put '${ENGINE_BUILD_T}', 'EB-ENG004-00001', 'production:qc_status', 'PASS'
put '${ENGINE_BUILD_T}', 'EB-ENG004-00001', 'production:operator_id', 'OP-4410'

put '${ENGINE_BUILD_T}', 'EB-ENG005-00001', 'ids:engine_type_id', 'ENG005'
put '${ENGINE_BUILD_T}', 'EB-ENG005-00001', 'ids:device_id', 'DEV007'
put '${ENGINE_BUILD_T}', 'EB-ENG005-00001', 'production:build_date', '2024-04-02'
put '${ENGINE_BUILD_T}', 'EB-ENG005-00001', 'production:plant_code', 'FREMONT'
put '${ENGINE_BUILD_T}', 'EB-ENG005-00001', 'production:line_id', 'L9'
put '${ENGINE_BUILD_T}', 'EB-ENG005-00001', 'production:shift', 'A'
put '${ENGINE_BUILD_T}', 'EB-ENG005-00001', 'production:batch_number', 'S24-040'
put '${ENGINE_BUILD_T}', 'EB-ENG005-00001', 'production:serial_number', '00001'
put '${ENGINE_BUILD_T}', 'EB-ENG005-00001', 'production:qc_status', 'PASS'
put '${ENGINE_BUILD_T}', 'EB-ENG005-00001', 'production:operator_id', 'OP-5502'
EOF

echo "  TRANSMISSION_BUILD rows..."
hbase_shell <<EOF
put '${TRANSMISSION_BUILD_T}', 'TB-TRN001-00001', 'ids:transmission_type_id', 'TRN001'
put '${TRANSMISSION_BUILD_T}', 'TB-TRN001-00001', 'ids:device_id', 'DEV001'
put '${TRANSMISSION_BUILD_T}', 'TB-TRN001-00001', 'production:build_date', '2022-03-10'
put '${TRANSMISSION_BUILD_T}', 'TB-TRN001-00001', 'production:plant_code', 'MARYSVILLE'
put '${TRANSMISSION_BUILD_T}', 'TB-TRN001-00001', 'production:line_id', 'T1'
put '${TRANSMISSION_BUILD_T}', 'TB-TRN001-00001', 'production:shift', 'A'
put '${TRANSMISSION_BUILD_T}', 'TB-TRN001-00001', 'production:batch_number', 'HT22-030'
put '${TRANSMISSION_BUILD_T}', 'TB-TRN001-00001', 'production:serial_number', '00001'
put '${TRANSMISSION_BUILD_T}', 'TB-TRN001-00001', 'production:qc_status', 'PASS'
put '${TRANSMISSION_BUILD_T}', 'TB-TRN001-00001', 'production:operator_id', 'OP-6101'

put '${TRANSMISSION_BUILD_T}', 'TB-TRN001-00002', 'ids:transmission_type_id', 'TRN001'
put '${TRANSMISSION_BUILD_T}', 'TB-TRN001-00002', 'ids:device_id', 'DEV002'
put '${TRANSMISSION_BUILD_T}', 'TB-TRN001-00002', 'production:build_date', '2023-01-16'
put '${TRANSMISSION_BUILD_T}', 'TB-TRN001-00002', 'production:plant_code', 'MARYSVILLE'
put '${TRANSMISSION_BUILD_T}', 'TB-TRN001-00002', 'production:line_id', 'T1'
put '${TRANSMISSION_BUILD_T}', 'TB-TRN001-00002', 'production:shift', 'B'
put '${TRANSMISSION_BUILD_T}', 'TB-TRN001-00002', 'production:batch_number', 'HT23-011'
put '${TRANSMISSION_BUILD_T}', 'TB-TRN001-00002', 'production:serial_number', '00002'
put '${TRANSMISSION_BUILD_T}', 'TB-TRN001-00002', 'production:qc_status', 'PASS'
put '${TRANSMISSION_BUILD_T}', 'TB-TRN001-00002', 'production:operator_id', 'OP-6108'

put '${TRANSMISSION_BUILD_T}', 'TB-TRN002-00001', 'ids:transmission_type_id', 'TRN002'
put '${TRANSMISSION_BUILD_T}', 'TB-TRN002-00001', 'ids:device_id', 'DEV009'
put '${TRANSMISSION_BUILD_T}', 'TB-TRN002-00001', 'production:build_date', '2021-06-01'
put '${TRANSMISSION_BUILD_T}', 'TB-TRN002-00001', 'production:plant_code', 'AISIN-IN'
put '${TRANSMISSION_BUILD_T}', 'TB-TRN002-00001', 'production:line_id', 'T3'
put '${TRANSMISSION_BUILD_T}', 'TB-TRN002-00001', 'production:shift', 'A'
put '${TRANSMISSION_BUILD_T}', 'TB-TRN002-00001', 'production:batch_number', 'AI21-060'
put '${TRANSMISSION_BUILD_T}', 'TB-TRN002-00001', 'production:serial_number', '00001'
put '${TRANSMISSION_BUILD_T}', 'TB-TRN002-00001', 'production:qc_status', 'PASS'
put '${TRANSMISSION_BUILD_T}', 'TB-TRN002-00001', 'production:operator_id', 'OP-7202'

put '${TRANSMISSION_BUILD_T}', 'TB-TRN002-00002', 'ids:transmission_type_id', 'TRN002'
put '${TRANSMISSION_BUILD_T}', 'TB-TRN002-00002', 'ids:device_id', 'DEV009'
put '${TRANSMISSION_BUILD_T}', 'TB-TRN002-00002', 'production:build_date', '2024-02-07'
put '${TRANSMISSION_BUILD_T}', 'TB-TRN002-00002', 'production:plant_code', 'AISIN-IN'
put '${TRANSMISSION_BUILD_T}', 'TB-TRN002-00002', 'production:line_id', 'T3'
put '${TRANSMISSION_BUILD_T}', 'TB-TRN002-00002', 'production:shift', 'C'
put '${TRANSMISSION_BUILD_T}', 'TB-TRN002-00002', 'production:batch_number', 'AI24-018'
put '${TRANSMISSION_BUILD_T}', 'TB-TRN002-00002', 'production:serial_number', '00002'
put '${TRANSMISSION_BUILD_T}', 'TB-TRN002-00002', 'production:qc_status', 'PASS'
put '${TRANSMISSION_BUILD_T}', 'TB-TRN002-00002', 'production:operator_id', 'OP-7210'

put '${TRANSMISSION_BUILD_T}', 'TB-TRN003-00001', 'ids:transmission_type_id', 'TRN003'
put '${TRANSMISSION_BUILD_T}', 'TB-TRN003-00001', 'ids:device_id', 'DEV010'
put '${TRANSMISSION_BUILD_T}', 'TB-TRN003-00001', 'production:build_date', '2020-08-19'
put '${TRANSMISSION_BUILD_T}', 'TB-TRN003-00001', 'production:plant_code', 'GETRAG-MI'
put '${TRANSMISSION_BUILD_T}', 'TB-TRN003-00001', 'production:line_id', 'T5'
put '${TRANSMISSION_BUILD_T}', 'TB-TRN003-00001', 'production:shift', 'A'
put '${TRANSMISSION_BUILD_T}', 'TB-TRN003-00001', 'production:batch_number', 'GT20-140'
put '${TRANSMISSION_BUILD_T}', 'TB-TRN003-00001', 'production:serial_number', '00001'
put '${TRANSMISSION_BUILD_T}', 'TB-TRN003-00001', 'production:qc_status', 'PASS'
put '${TRANSMISSION_BUILD_T}', 'TB-TRN003-00001', 'production:operator_id', 'OP-8301'

put '${TRANSMISSION_BUILD_T}', 'TB-TRN004-00001', 'ids:transmission_type_id', 'TRN004'
put '${TRANSMISSION_BUILD_T}', 'TB-TRN004-00001', 'ids:device_id', 'DEV011'
put '${TRANSMISSION_BUILD_T}', 'TB-TRN004-00001', 'production:build_date', '2023-05-28'
put '${TRANSMISSION_BUILD_T}', 'TB-TRN004-00001', 'production:plant_code', 'ZF-SC'
put '${TRANSMISSION_BUILD_T}', 'TB-TRN004-00001', 'production:line_id', 'T8'
put '${TRANSMISSION_BUILD_T}', 'TB-TRN004-00001', 'production:shift', 'B'
put '${TRANSMISSION_BUILD_T}', 'TB-TRN004-00001', 'production:batch_number', 'ZF23-075'
put '${TRANSMISSION_BUILD_T}', 'TB-TRN004-00001', 'production:serial_number', '00001'
put '${TRANSMISSION_BUILD_T}', 'TB-TRN004-00001', 'production:qc_status', 'PASS'
put '${TRANSMISSION_BUILD_T}', 'TB-TRN004-00001', 'production:operator_id', 'OP-9404'

put '${TRANSMISSION_BUILD_T}', 'TB-TRN004-00002', 'ids:transmission_type_id', 'TRN004'
put '${TRANSMISSION_BUILD_T}', 'TB-TRN004-00002', 'ids:device_id', 'DEV011'
put '${TRANSMISSION_BUILD_T}', 'TB-TRN004-00002', 'production:build_date', '2024-03-30'
put '${TRANSMISSION_BUILD_T}', 'TB-TRN004-00002', 'production:plant_code', 'ZF-SC'
put '${TRANSMISSION_BUILD_T}', 'TB-TRN004-00002', 'production:line_id', 'T8'
put '${TRANSMISSION_BUILD_T}', 'TB-TRN004-00002', 'production:shift', 'A'
put '${TRANSMISSION_BUILD_T}', 'TB-TRN004-00002', 'production:batch_number', 'ZF24-038'
put '${TRANSMISSION_BUILD_T}', 'TB-TRN004-00002', 'production:serial_number', '00002'
put '${TRANSMISSION_BUILD_T}', 'TB-TRN004-00002', 'production:qc_status', 'PASS'
put '${TRANSMISSION_BUILD_T}', 'TB-TRN004-00002', 'production:operator_id', 'OP-9411'
EOF

echo "  CHASSIS_BUILD rows..."
hbase_shell <<EOF
put '${CHASSIS_BUILD_T}', 'CB-CHS001-00001', 'ids:chassis_type_id', 'CHS001'
put '${CHASSIS_BUILD_T}', 'CB-CHS001-00001', 'ids:device_id', 'DEV008'
put '${CHASSIS_BUILD_T}', 'CB-CHS001-00001', 'production:build_date', '2022-03-08'
put '${CHASSIS_BUILD_T}', 'CB-CHS001-00001', 'production:plant_code', 'EAST-LIBERTY'
put '${CHASSIS_BUILD_T}', 'CB-CHS001-00001', 'production:line_id', 'C1'
put '${CHASSIS_BUILD_T}', 'CB-CHS001-00001', 'production:shift', 'A'
put '${CHASSIS_BUILD_T}', 'CB-CHS001-00001', 'production:batch_number', 'HC22-028'
put '${CHASSIS_BUILD_T}', 'CB-CHS001-00001', 'production:serial_number', '00001'
put '${CHASSIS_BUILD_T}', 'CB-CHS001-00001', 'production:qc_status', 'PASS'
put '${CHASSIS_BUILD_T}', 'CB-CHS001-00001', 'production:operator_id', 'OP-1501'

put '${CHASSIS_BUILD_T}', 'CB-CHS001-00002', 'ids:chassis_type_id', 'CHS001'
put '${CHASSIS_BUILD_T}', 'CB-CHS001-00002', 'ids:device_id', 'DEV008'
put '${CHASSIS_BUILD_T}', 'CB-CHS001-00002', 'production:build_date', '2023-01-14'
put '${CHASSIS_BUILD_T}', 'CB-CHS001-00002', 'production:plant_code', 'EAST-LIBERTY'
put '${CHASSIS_BUILD_T}', 'CB-CHS001-00002', 'production:line_id', 'C1'
put '${CHASSIS_BUILD_T}', 'CB-CHS001-00002', 'production:shift', 'B'
put '${CHASSIS_BUILD_T}', 'CB-CHS001-00002', 'production:batch_number', 'HC23-010'
put '${CHASSIS_BUILD_T}', 'CB-CHS001-00002', 'production:serial_number', '00002'
put '${CHASSIS_BUILD_T}', 'CB-CHS001-00002', 'production:qc_status', 'PASS'
put '${CHASSIS_BUILD_T}', 'CB-CHS001-00002', 'production:operator_id', 'OP-1507'

put '${CHASSIS_BUILD_T}', 'CB-CHS001-00003', 'ids:chassis_type_id', 'CHS001'
put '${CHASSIS_BUILD_T}', 'CB-CHS001-00003', 'ids:device_id', 'DEV006'
put '${CHASSIS_BUILD_T}', 'CB-CHS001-00003', 'production:build_date', '2023-05-26'
put '${CHASSIS_BUILD_T}', 'CB-CHS001-00003', 'production:plant_code', 'DINGOLFING'
put '${CHASSIS_BUILD_T}', 'CB-CHS001-00003', 'production:line_id', 'C6'
put '${CHASSIS_BUILD_T}', 'CB-CHS001-00003', 'production:shift', 'B'
put '${CHASSIS_BUILD_T}', 'CB-CHS001-00003', 'production:batch_number', 'BM23-074'
put '${CHASSIS_BUILD_T}', 'CB-CHS001-00003', 'production:serial_number', '00003'
put '${CHASSIS_BUILD_T}', 'CB-CHS001-00003', 'production:qc_status', 'PASS'
put '${CHASSIS_BUILD_T}', 'CB-CHS001-00003', 'production:operator_id', 'OP-1603'

put '${CHASSIS_BUILD_T}', 'CB-CHS002-00001', 'ids:chassis_type_id', 'CHS002'
put '${CHASSIS_BUILD_T}', 'CB-CHS002-00001', 'ids:device_id', 'DEV012'
put '${CHASSIS_BUILD_T}', 'CB-CHS002-00001', 'production:build_date', '2021-05-30'
put '${CHASSIS_BUILD_T}', 'CB-CHS002-00001', 'production:plant_code', 'PRINCETON'
put '${CHASSIS_BUILD_T}', 'CB-CHS002-00001', 'production:line_id', 'C2'
put '${CHASSIS_BUILD_T}', 'CB-CHS002-00001', 'production:shift', 'A'
put '${CHASSIS_BUILD_T}', 'CB-CHS002-00001', 'production:batch_number', 'TY21-058'
put '${CHASSIS_BUILD_T}', 'CB-CHS002-00001', 'production:serial_number', '00001'
put '${CHASSIS_BUILD_T}', 'CB-CHS002-00001', 'production:qc_status', 'PASS'
put '${CHASSIS_BUILD_T}', 'CB-CHS002-00001', 'production:operator_id', 'OP-1702'

put '${CHASSIS_BUILD_T}', 'CB-CHS002-00002', 'ids:chassis_type_id', 'CHS002'
put '${CHASSIS_BUILD_T}', 'CB-CHS002-00002', 'ids:device_id', 'DEV012'
put '${CHASSIS_BUILD_T}', 'CB-CHS002-00002', 'production:build_date', '2024-02-05'
put '${CHASSIS_BUILD_T}', 'CB-CHS002-00002', 'production:plant_code', 'PRINCETON'
put '${CHASSIS_BUILD_T}', 'CB-CHS002-00002', 'production:line_id', 'C2'
put '${CHASSIS_BUILD_T}', 'CB-CHS002-00002', 'production:shift', 'C'
put '${CHASSIS_BUILD_T}', 'CB-CHS002-00002', 'production:batch_number', 'TY24-017'
put '${CHASSIS_BUILD_T}', 'CB-CHS002-00002', 'production:serial_number', '00002'
put '${CHASSIS_BUILD_T}', 'CB-CHS002-00002', 'production:qc_status', 'PASS'
put '${CHASSIS_BUILD_T}', 'CB-CHS002-00002', 'production:operator_id', 'OP-1711'

put '${CHASSIS_BUILD_T}', 'CB-CHS003-00001', 'ids:chassis_type_id', 'CHS003'
put '${CHASSIS_BUILD_T}', 'CB-CHS003-00001', 'ids:device_id', 'DEV005'
put '${CHASSIS_BUILD_T}', 'CB-CHS003-00001', 'production:build_date', '2020-08-17'
put '${CHASSIS_BUILD_T}', 'CB-CHS003-00001', 'production:plant_code', 'FLATROCK'
put '${CHASSIS_BUILD_T}', 'CB-CHS003-00001', 'production:line_id', 'C4'
put '${CHASSIS_BUILD_T}', 'CB-CHS003-00001', 'production:shift', 'A'
put '${CHASSIS_BUILD_T}', 'CB-CHS003-00001', 'production:batch_number', 'FR20-138'
put '${CHASSIS_BUILD_T}', 'CB-CHS003-00001', 'production:serial_number', '00001'
put '${CHASSIS_BUILD_T}', 'CB-CHS003-00001', 'production:qc_status', 'PASS'
put '${CHASSIS_BUILD_T}', 'CB-CHS003-00001', 'production:operator_id', 'OP-1805'

put '${CHASSIS_BUILD_T}', 'CB-CHS004-00001', 'ids:chassis_type_id', 'CHS004'
put '${CHASSIS_BUILD_T}', 'CB-CHS004-00001', 'ids:device_id', 'DEV007'
put '${CHASSIS_BUILD_T}', 'CB-CHS004-00001', 'production:build_date', '2024-03-28'
put '${CHASSIS_BUILD_T}', 'CB-CHS004-00001', 'production:plant_code', 'FREMONT'
put '${CHASSIS_BUILD_T}', 'CB-CHS004-00001', 'production:line_id', 'C9'
put '${CHASSIS_BUILD_T}', 'CB-CHS004-00001', 'production:shift', 'A'
put '${CHASSIS_BUILD_T}', 'CB-CHS004-00001', 'production:batch_number', 'TS24-036'
put '${CHASSIS_BUILD_T}', 'CB-CHS004-00001', 'production:serial_number', '00001'
put '${CHASSIS_BUILD_T}', 'CB-CHS004-00001', 'production:qc_status', 'PASS'
put '${CHASSIS_BUILD_T}', 'CB-CHS004-00001', 'production:operator_id', 'OP-1908'
EOF

echo ""
echo "Step 4: Inserting vehicles (VIN → build IDs)..."
echo ""

hbase_shell <<EOF
put '${VEHICLE_T}', '1HGCM82633A004352', 'ids:engine_build_id', 'EB-ENG001-00001'
put '${VEHICLE_T}', '1HGCM82633A004352', 'ids:transmission_build_id', 'TB-TRN001-00001'
put '${VEHICLE_T}', '1HGCM82633A004352', 'ids:chassis_build_id', 'CB-CHS001-00001'
put '${VEHICLE_T}', '1HGCM82633A004352', 'info:make', 'Honda'
put '${VEHICLE_T}', '1HGCM82633A004352', 'info:model', 'Civic'
put '${VEHICLE_T}', '1HGCM82633A004352', 'info:year', '2022'
put '${VEHICLE_T}', '1HGCM82633A004352', 'info:color', 'Blue'
put '${VEHICLE_T}', '1HGCM82633A004352', 'info:trim', 'EX'

put '${VEHICLE_T}', '1HGCV1F30JA000123', 'ids:engine_build_id', 'EB-ENG001-00002'
put '${VEHICLE_T}', '1HGCV1F30JA000123', 'ids:transmission_build_id', 'TB-TRN001-00002'
put '${VEHICLE_T}', '1HGCV1F30JA000123', 'ids:chassis_build_id', 'CB-CHS001-00002'
put '${VEHICLE_T}', '1HGCV1F30JA000123', 'info:make', 'Honda'
put '${VEHICLE_T}', '1HGCV1F30JA000123', 'info:model', 'Accord'
put '${VEHICLE_T}', '1HGCV1F30JA000123', 'info:year', '2023'
put '${VEHICLE_T}', '1HGCV1F30JA000123', 'info:color', 'Silver'
put '${VEHICLE_T}', '1HGCV1F30JA000123', 'info:trim', 'Sport'

put '${VEHICLE_T}', '5TDKZRFH0KS123456', 'ids:engine_build_id', 'EB-ENG002-00001'
put '${VEHICLE_T}', '5TDKZRFH0KS123456', 'ids:transmission_build_id', 'TB-TRN002-00001'
put '${VEHICLE_T}', '5TDKZRFH0KS123456', 'ids:chassis_build_id', 'CB-CHS002-00001'
put '${VEHICLE_T}', '5TDKZRFH0KS123456', 'info:make', 'Toyota'
put '${VEHICLE_T}', '5TDKZRFH0KS123456', 'info:model', 'Highlander'
put '${VEHICLE_T}', '5TDKZRFH0KS123456', 'info:year', '2021'
put '${VEHICLE_T}', '5TDKZRFH0KS123456', 'info:color', 'White'
put '${VEHICLE_T}', '5TDKZRFH0KS123456', 'info:trim', 'XLE'

put '${VEHICLE_T}', '2T3P1RFV8MW078901', 'ids:engine_build_id', 'EB-ENG002-00002'
put '${VEHICLE_T}', '2T3P1RFV8MW078901', 'ids:transmission_build_id', 'TB-TRN002-00002'
put '${VEHICLE_T}', '2T3P1RFV8MW078901', 'ids:chassis_build_id', 'CB-CHS002-00002'
put '${VEHICLE_T}', '2T3P1RFV8MW078901', 'info:make', 'Toyota'
put '${VEHICLE_T}', '2T3P1RFV8MW078901', 'info:model', 'RAV4'
put '${VEHICLE_T}', '2T3P1RFV8MW078901', 'info:year', '2024'
put '${VEHICLE_T}', '2T3P1RFV8MW078901', 'info:color', 'Black'
put '${VEHICLE_T}', '2T3P1RFV8MW078901', 'info:trim', 'Adventure'

put '${VEHICLE_T}', '1FA6P8CF5L5102345', 'ids:engine_build_id', 'EB-ENG003-00001'
put '${VEHICLE_T}', '1FA6P8CF5L5102345', 'ids:transmission_build_id', 'TB-TRN003-00001'
put '${VEHICLE_T}', '1FA6P8CF5L5102345', 'ids:chassis_build_id', 'CB-CHS003-00001'
put '${VEHICLE_T}', '1FA6P8CF5L5102345', 'info:make', 'Ford'
put '${VEHICLE_T}', '1FA6P8CF5L5102345', 'info:model', 'Mustang'
put '${VEHICLE_T}', '1FA6P8CF5L5102345', 'info:year', '2020'
put '${VEHICLE_T}', '1FA6P8CF5L5102345', 'info:color', 'Red'
put '${VEHICLE_T}', '1FA6P8CF5L5102345', 'info:trim', 'GT'

put '${VEHICLE_T}', 'WBA5U9C05LF345678', 'ids:engine_build_id', 'EB-ENG004-00001'
put '${VEHICLE_T}', 'WBA5U9C05LF345678', 'ids:transmission_build_id', 'TB-TRN004-00001'
put '${VEHICLE_T}', 'WBA5U9C05LF345678', 'ids:chassis_build_id', 'CB-CHS001-00003'
put '${VEHICLE_T}', 'WBA5U9C05LF345678', 'info:make', 'BMW'
put '${VEHICLE_T}', 'WBA5U9C05LF345678', 'info:model', 'M340i'
put '${VEHICLE_T}', 'WBA5U9C05LF345678', 'info:year', '2023'
put '${VEHICLE_T}', 'WBA5U9C05LF345678', 'info:color', 'Gray'
put '${VEHICLE_T}', 'WBA5U9C05LF345678', 'info:trim', 'xDrive'

put '${VEHICLE_T}', '5YJ3E1EA1KF789012', 'ids:engine_build_id', 'EB-ENG005-00001'
put '${VEHICLE_T}', '5YJ3E1EA1KF789012', 'ids:transmission_build_id', 'TB-TRN004-00002'
put '${VEHICLE_T}', '5YJ3E1EA1KF789012', 'ids:chassis_build_id', 'CB-CHS004-00001'
put '${VEHICLE_T}', '5YJ3E1EA1KF789012', 'info:make', 'Tesla'
put '${VEHICLE_T}', '5YJ3E1EA1KF789012', 'info:model', 'Model Y'
put '${VEHICLE_T}', '5YJ3E1EA1KF789012', 'info:year', '2024'
put '${VEHICLE_T}', '5YJ3E1EA1KF789012', 'info:color', 'White'
put '${VEHICLE_T}', '5YJ3E1EA1KF789012', 'info:trim', 'Performance'
EOF

echo ""
sleep "$WAIT_SECONDS"

echo "Step 5: Verifying data in HBase..."
echo "scan '${ENGINE_BUILD_T}', {LIMIT => 1}" | hbase_shell | grep -A 8 "ROW  COLUMN" | head -12 || true
echo ""

if [[ "$SKIP_VIEWS" == true ]]; then
  echo "Step 6: Skipping Phoenix view creation (--skip-views)"
  echo ""
else
  echo "Step 6: Creating Phoenix views via ${API_URL}..."
  echo ""

  if ! command -v curl >/dev/null 2>&1; then
    echo "ERROR: curl is required for Phoenix API calls." >&2
    exit 1
  fi

  curl -s -X POST "${API_URL}/execute" -H "Content-Type: application/json" \
    -d '{"sql": "CREATE VIEW IF NOT EXISTS \"ENGINE\" (\"rowkey\" VARCHAR PRIMARY KEY, \"specs\".\"manufacturer\" VARCHAR, \"specs\".\"model\" VARCHAR, \"specs\".\"displacement_l\" VARCHAR, \"specs\".\"cylinders\" VARCHAR, \"specs\".\"horsepower\" VARCHAR, \"specs\".\"fuel_type\" VARCHAR)"}' | (command -v jq >/dev/null && jq . || cat)

  curl -s -X POST "${API_URL}/execute" -H "Content-Type: application/json" \
    -d '{"sql": "CREATE VIEW IF NOT EXISTS \"TRANSMISSION\" (\"rowkey\" VARCHAR PRIMARY KEY, \"specs\".\"manufacturer\" VARCHAR, \"specs\".\"model\" VARCHAR, \"specs\".\"type\" VARCHAR, \"specs\".\"gears\" VARCHAR, \"specs\".\"drive_type\" VARCHAR)"}' | (command -v jq >/dev/null && jq . || cat)

  curl -s -X POST "${API_URL}/execute" -H "Content-Type: application/json" \
    -d '{"sql": "CREATE VIEW IF NOT EXISTS \"CHASSIS\" (\"rowkey\" VARCHAR PRIMARY KEY, \"specs\".\"body_style\" VARCHAR, \"specs\".\"material\" VARCHAR, \"specs\".\"wheelbase_in\" VARCHAR, \"specs\".\"curb_weight_lb\" VARCHAR, \"specs\".\"doors\" VARCHAR)"}' | (command -v jq >/dev/null && jq . || cat)

  curl -s -X POST "${API_URL}/execute" -H "Content-Type: application/json" \
    -d '{"sql": "CREATE VIEW IF NOT EXISTS \"DEVICE\" (\"rowkey\" VARCHAR PRIMARY KEY, \"specs\".\"name\" VARCHAR, \"specs\".\"device_type\" VARCHAR, \"specs\".\"manufacturer\" VARCHAR, \"specs\".\"model\" VARCHAR, \"specs\".\"plant_code\" VARCHAR, \"specs\".\"status\" VARCHAR)"}' | (command -v jq >/dev/null && jq . || cat)

  curl -s -X POST "${API_URL}/execute" -H "Content-Type: application/json" \
    -d '{"sql": "CREATE VIEW IF NOT EXISTS \"ENGINE_BUILD\" (\"rowkey\" VARCHAR PRIMARY KEY, \"ids\".\"engine_type_id\" VARCHAR, \"ids\".\"device_id\" VARCHAR, \"production\".\"build_date\" VARCHAR, \"production\".\"plant_code\" VARCHAR, \"production\".\"line_id\" VARCHAR, \"production\".\"shift\" VARCHAR, \"production\".\"batch_number\" VARCHAR, \"production\".\"serial_number\" VARCHAR, \"production\".\"qc_status\" VARCHAR, \"production\".\"operator_id\" VARCHAR)"}' | (command -v jq >/dev/null && jq . || cat)

  curl -s -X POST "${API_URL}/execute" -H "Content-Type: application/json" \
    -d '{"sql": "CREATE VIEW IF NOT EXISTS \"TRANSMISSION_BUILD\" (\"rowkey\" VARCHAR PRIMARY KEY, \"ids\".\"transmission_type_id\" VARCHAR, \"ids\".\"device_id\" VARCHAR, \"production\".\"build_date\" VARCHAR, \"production\".\"plant_code\" VARCHAR, \"production\".\"line_id\" VARCHAR, \"production\".\"shift\" VARCHAR, \"production\".\"batch_number\" VARCHAR, \"production\".\"serial_number\" VARCHAR, \"production\".\"qc_status\" VARCHAR, \"production\".\"operator_id\" VARCHAR)"}' | (command -v jq >/dev/null && jq . || cat)

  curl -s -X POST "${API_URL}/execute" -H "Content-Type: application/json" \
    -d '{"sql": "CREATE VIEW IF NOT EXISTS \"CHASSIS_BUILD\" (\"rowkey\" VARCHAR PRIMARY KEY, \"ids\".\"chassis_type_id\" VARCHAR, \"ids\".\"device_id\" VARCHAR, \"production\".\"build_date\" VARCHAR, \"production\".\"plant_code\" VARCHAR, \"production\".\"line_id\" VARCHAR, \"production\".\"shift\" VARCHAR, \"production\".\"batch_number\" VARCHAR, \"production\".\"serial_number\" VARCHAR, \"production\".\"qc_status\" VARCHAR, \"production\".\"operator_id\" VARCHAR)"}' | (command -v jq >/dev/null && jq . || cat)

  curl -s -X POST "${API_URL}/execute" -H "Content-Type: application/json" \
    -d '{"sql": "CREATE VIEW IF NOT EXISTS \"VEHICLE\" (\"rowkey\" VARCHAR PRIMARY KEY, \"ids\".\"engine_build_id\" VARCHAR, \"ids\".\"transmission_build_id\" VARCHAR, \"ids\".\"chassis_build_id\" VARCHAR, \"info\".\"make\" VARCHAR, \"info\".\"model\" VARCHAR, \"info\".\"year\" VARCHAR, \"info\".\"color\" VARCHAR, \"info\".\"trim\" VARCHAR)"}' | (command -v jq >/dev/null && jq . || cat)

  echo ""
  sleep "$((WAIT_SECONDS + 1))"
  echo "Found views:"
  curl -s "${API_URL}/views" | (command -v jq >/dev/null && jq -r '.rows[] | select(.TABLE_NAME | test("ENGINE|TRANSMISSION|CHASSIS|VEHICLE|DEVICE"; "i")) | .TABLE_NAME' | sort || cat)
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
    | (command -v jq >/dev/null && jq '{rowCount, rows}' || cat)

  echo ""
  echo "Query 2: Engine build with type + device"
  curl -s -X POST "${API_URL}/query" -H "Content-Type: application/json" \
    -d '{"sql": "SELECT eb.\"rowkey\" as engine_build_id, eb.\"ids\".\"engine_type_id\", eb.\"ids\".\"device_id\", eb.\"production\".\"plant_code\", e.\"specs\".\"horsepower\", d.\"specs\".\"name\" as device_name, d.\"specs\".\"device_type\" FROM \"ENGINE_BUILD\" eb JOIN \"ENGINE\" e ON eb.\"ids\".\"engine_type_id\" = e.\"rowkey\" JOIN \"DEVICE\" d ON eb.\"ids\".\"device_id\" = d.\"rowkey\" WHERE eb.\"rowkey\" = '\''EB-ENG001-00001'\''"}' \
    | (command -v jq >/dev/null && jq '{rowCount, rows}' || cat)

  echo ""
  echo "Query 3: Complete build sheet (builds + types + devices)"
  curl -s -X POST "${API_URL}/query" -H "Content-Type: application/json" \
    -d '{"sql": "SELECT v.\"rowkey\" as vin, v.\"info\".\"make\" as make, v.\"info\".\"model\" as model, eb.\"rowkey\" as engine_build_id, e.\"specs\".\"horsepower\" as horsepower, ed.\"rowkey\" as engine_device_id, ed.\"specs\".\"name\" as engine_device_name, tb.\"rowkey\" as transmission_build_id, t.\"specs\".\"type\" as transmission_type, td.\"rowkey\" as transmission_device_id, td.\"specs\".\"name\" as transmission_device_name, cb.\"rowkey\" as chassis_build_id, c.\"specs\".\"body_style\" as body_style, cd.\"rowkey\" as chassis_device_id, cd.\"specs\".\"name\" as chassis_device_name FROM \"VEHICLE\" v JOIN \"ENGINE_BUILD\" eb ON v.\"ids\".\"engine_build_id\" = eb.\"rowkey\" JOIN \"ENGINE\" e ON eb.\"ids\".\"engine_type_id\" = e.\"rowkey\" JOIN \"DEVICE\" ed ON eb.\"ids\".\"device_id\" = ed.\"rowkey\" JOIN \"TRANSMISSION_BUILD\" tb ON v.\"ids\".\"transmission_build_id\" = tb.\"rowkey\" JOIN \"TRANSMISSION\" t ON tb.\"ids\".\"transmission_type_id\" = t.\"rowkey\" JOIN \"DEVICE\" td ON tb.\"ids\".\"device_id\" = td.\"rowkey\" JOIN \"CHASSIS_BUILD\" cb ON v.\"ids\".\"chassis_build_id\" = cb.\"rowkey\" JOIN \"CHASSIS\" c ON cb.\"ids\".\"chassis_type_id\" = c.\"rowkey\" JOIN \"DEVICE\" cd ON cb.\"ids\".\"device_id\" = cd.\"rowkey\" WHERE v.\"rowkey\" = '\''1HGCM82633A004352'\''"}' \
    | (command -v jq >/dev/null && jq '{rowCount, rows}' || cat)
  echo ""
fi

echo "=========================================="
echo "Done! Vehicle 360 type + device + build tables created on CDP."
echo "=========================================="
echo ""
echo "Configuration used:"
echo "  HBase binary: ${HBASE_BIN}"
echo "  HBase conf:   ${HBASE_CONF_DIR}"
echo "  Namespace:    ${NAMESPACE:-"(default)"}"
echo "  Type tables:  ${ENGINE_T}, ${TRANSMISSION_T}, ${CHASSIS_T}"
echo "  Devices:     ${DEVICE_T}"
echo "  Build tables: ${ENGINE_BUILD_T}, ${TRANSMISSION_BUILD_T}, ${CHASSIS_BUILD_T}"
echo "  Assembly:     ${VEHICLE_T} (VIN → *_build_id)"
echo "  API URL:      ${API_URL:-"(n/a)"}"
echo ""
