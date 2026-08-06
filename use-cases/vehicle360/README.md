# Vehicle 360 - Use Case

## Overview

This use case demonstrates a **type catalog → manufacturing device → device session → physical build → VIN assembly** pattern in HBase with Phoenix SQL access. Unlike Student/Soldier 360 (single wide table, no JOINs), Vehicle 360 separates:

1. **Type catalogs** — reusable component definitions (`ENG001`, `TRN001`, `CHS001`)
2. **DEVICE** — shared manufacturing equipment catalog (`DEV001`, …)
3. **DEVICE_SESSION** — production-run log per device session (`SES-DEV008-20220308-001`, …)
4. **Build tables** — individual manufactured units with production metadata + `device_id` + `session_id`
5. **VEHICLE** — VIN row that references **build IDs** (not type IDs)

Full vehicle detail is retrieved with **Phoenix JOINs**: `VEHICLE → *_BUILD → type catalog`, `*_BUILD → DEVICE`, and `*_BUILD → DEVICE_SESSION`.

## Architecture

### Design Approach

Nine HBase tables:

| Table | Row Key | Purpose |
|-------|---------|---------|
| `ENGINE` | Type ID (e.g. `ENG001`) | Engine type catalog |
| `TRANSMISSION` | Type ID (e.g. `TRN001`) | Transmission type catalog |
| `CHASSIS` | Type ID (e.g. `CHS001`) | Chassis type catalog |
| `DEVICE` | Device ID (e.g. `DEV001`) | Manufacturing equipment catalog |
| `DEVICE_SESSION` | Session ID (e.g. `SES-DEV008-20220308-001`) | Production-run log for one device session |
| `ENGINE_BUILD` | Build ID (e.g. `EB-ENG001-00001`) | Physical engine + production + device + session |
| `TRANSMISSION_BUILD` | Build ID (e.g. `TB-TRN001-00001`) | Physical transmission + production + device + session |
| `CHASSIS_BUILD` | Build ID (e.g. `CB-CHS001-00001`) | Physical chassis + production + device + session |
| `VEHICLE` | VIN | Assembled vehicle; stores `*_build_id` refs |

#### Table relationships (all fields)

Nine-table manufacturing-line architecture — component catalogs, device sessions, physical builds, and VIN assembly:

![Vehicle manufacturing line tracking reference architecture](../../images/vehicle360_table_view.png)

Attribute names use `family_qualifier` (HBase `family:qualifier`). Mermaid equivalent of the diagram above:

```mermaid
erDiagram
  ENGINE ||--o{ ENGINE_BUILD : "engine_type_id"
  TRANSMISSION ||--o{ TRANSMISSION_BUILD : "transmission_type_id"
  CHASSIS ||--o{ CHASSIS_BUILD : "chassis_type_id"
  DEVICE ||--o{ DEVICE_SESSION : "device_id"
  DEVICE ||--o{ ENGINE_BUILD : "device_id"
  DEVICE ||--o{ TRANSMISSION_BUILD : "device_id"
  DEVICE ||--o{ CHASSIS_BUILD : "device_id"
  DEVICE_SESSION ||--o{ ENGINE_BUILD : "session_id"
  DEVICE_SESSION ||--o{ TRANSMISSION_BUILD : "session_id"
  DEVICE_SESSION ||--o{ CHASSIS_BUILD : "session_id"
  ENGINE_BUILD ||--o{ VEHICLE : "engine_build_id"
  TRANSMISSION_BUILD ||--o{ VEHICLE : "transmission_build_id"
  CHASSIS_BUILD ||--o{ VEHICLE : "chassis_build_id"

  ENGINE {
    string rowkey PK
    string specs_manufacturer
    string specs_model
    string specs_displacement_l
    string specs_cylinders
    string specs_horsepower
    string specs_fuel_type
  }

  TRANSMISSION {
    string rowkey PK
    string specs_manufacturer
    string specs_model
    string specs_type
    string specs_gears
    string specs_drive_type
  }

  CHASSIS {
    string rowkey PK
    string specs_body_style
    string specs_material
    string specs_wheelbase_in
    string specs_curb_weight_lb
    string specs_doors
  }

  DEVICE {
    string rowkey PK
    string specs_name
    string specs_device_type
    string specs_manufacturer
    string specs_model
    string specs_plant_code
    string specs_status
  }

  DEVICE_SESSION {
    string rowkey PK
    string ids_device_id FK
    string run_start_ts
    string run_end_ts
    string run_plant_code
    string run_line_id
    string run_shift
    string run_operator_id
    string run_status
    string run_units_produced
  }

  ENGINE_BUILD {
    string rowkey PK
    string ids_engine_type_id FK
    string ids_device_id FK
    string ids_session_id FK
    string production_build_date
    string production_plant_code
    string production_line_id
    string production_shift
    string production_batch_number
    string production_serial_number
    string production_qc_status
    string production_operator_id
  }

  TRANSMISSION_BUILD {
    string rowkey PK
    string ids_transmission_type_id FK
    string ids_device_id FK
    string ids_session_id FK
    string production_build_date
    string production_plant_code
    string production_line_id
    string production_shift
    string production_batch_number
    string production_serial_number
    string production_qc_status
    string production_operator_id
  }

  CHASSIS_BUILD {
    string rowkey PK
    string ids_chassis_type_id FK
    string ids_device_id FK
    string ids_session_id FK
    string production_build_date
    string production_plant_code
    string production_line_id
    string production_shift
    string production_batch_number
    string production_serial_number
    string production_qc_status
    string production_operator_id
  }

  VEHICLE {
    string rowkey PK
    string ids_engine_build_id FK
    string ids_transmission_build_id FK
    string ids_chassis_build_id FK
    string info_make
    string info_model
    string info_year
    string info_color
    string info_trim
  }
```

#### Full vehicle JOIN path

One VIN fans out to three builds; each build joins its type catalog, shared `DEVICE`, and `DEVICE_SESSION`:

![Vehicle lineage and device tracking architecture flow](../../images/vehicle360_fullJoin.png)

Mermaid equivalent (`ed` / `es` / … are aliases):

```mermaid
flowchart LR
  VEH["VEHICLE<br/>rowkey = VIN"]

  EB[ENGINE_BUILD]
  TB[TRANSMISSION_BUILD]
  CB[CHASSIS_BUILD]

  ENG[ENGINE]
  TRN[TRANSMISSION]
  CHS[CHASSIS]

  ED["DEVICE<br/>engine device"]
  TD["DEVICE<br/>transmission device"]
  CD["DEVICE<br/>chassis device"]

  ES["DEVICE_SESSION<br/>engine session"]
  TS["DEVICE_SESSION<br/>trans session"]
  CS["DEVICE_SESSION<br/>chassis session"]

  VEH -->|"ids.engine_build_id"| EB
  VEH -->|"ids.transmission_build_id"| TB
  VEH -->|"ids.chassis_build_id"| CB

  EB -->|"ids.engine_type_id"| ENG
  TB -->|"ids.transmission_type_id"| TRN
  CB -->|"ids.chassis_type_id"| CHS

  EB -->|"ids.device_id"| ED
  TB -->|"ids.device_id"| TD
  CB -->|"ids.device_id"| CD

  EB -->|"ids.session_id"| ES
  TB -->|"ids.session_id"| TS
  CB -->|"ids.session_id"| CS

  ES -->|"ids.device_id"| ED
  TS -->|"ids.device_id"| TD
  CS -->|"ids.device_id"| CD
```

### Why This Pattern?

Student/Soldier 360 put all attributes in one row for fast single-key lookups. Vehicles need both shared type definitions and per-unit manufacturing history:

1. Type catalogs avoid duplicating specs across every unit
2. Device sessions log each production run (start/end, shift, operator, status)
3. Build rows capture plant, line, shift, batch, serial, QC, operator, and the session that produced them
4. VIN → build IDs tracks the exact physical parts on a vehicle
5. Demonstrates multi-hop JOINs in Phoenix over HBase-native tables

### Comparison to 360 Wide-Table Design

| Aspect | Wide Table (Student/Soldier 360) | Vehicle 360 (This Design) |
|--------|----------------------------------|---------------------------|
| Tables | One table | Nine tables (3 types + DEVICE + DEVICE_SESSION + 3 builds + VIN) |
| Row key | Entity ID (student/EDIPI) | Type IDs, session IDs, build IDs, VIN |
| Relationships | Denormalized into one row | Type → session → build → VIN |
| Full profile | `SELECT * WHERE rowkey = ...` | JOINs through builds |
| Reuse | Poor (data copied per row) | Strong (shared types/devices; unique builds/sessions) |
| Best for | Dashboard / complete profile | Catalog + manufacturing + assembly |

## Table Structure

### ENGINE (`specs`)

Row key: engine ID

| Qualifier | Description |
|-----------|-------------|
| `manufacturer` | Engine manufacturer |
| `model` | Engine model code |
| `displacement_l` | Displacement in liters |
| `cylinders` | Cylinder count |
| `horsepower` | Horsepower |
| `fuel_type` | Gasoline / Electric / etc. |

### TRANSMISSION (`specs`)

Row key: transmission ID

| Qualifier | Description |
|-----------|-------------|
| `manufacturer` | Transmission manufacturer |
| `model` | Transmission model code |
| `type` | Automatic / Manual / CVT |
| `gears` | Gear count (`0` for CVT) |
| `drive_type` | FWD / RWD / AWD |

### CHASSIS (`specs`)

Row key: chassis ID

| Qualifier | Description |
|-----------|-------------|
| `body_style` | Sedan / SUV / Coupe / Hatchback |
| `material` | Steel / Aluminum |
| `wheelbase_in` | Wheelbase in inches |
| `curb_weight_lb` | Curb weight in pounds |
| `doors` | Door count |

### DEVICE (`specs`)

Row key: device ID (`DEV001`, …)

| Qualifier | Description |
|-----------|-------------|
| `name` | Human-readable device label |
| `device_type` | Robot / CNC / Press / TorqueStation / TestCell |
| `manufacturer` | Equipment OEM |
| `model` | Equipment model |
| `plant_code` | Home plant |
| `status` | ACTIVE / MAINTENANCE |

### DEVICE_SESSION (`ids`, `run`)

Row key: session ID (`SES-{deviceId}-{yyyyMMdd}-{seq}`, e.g. `SES-DEV008-20220308-001`)

**Column family `ids`**:

| Qualifier | Description |
|-----------|-------------|
| `device_id` | References `DEVICE` |

**Column family `run`**:

| Qualifier | Description |
|-----------|-------------|
| `start_ts` | Session start (ISO-8601) |
| `end_ts` | Session end (ISO-8601) |
| `plant_code` | Plant where the run executed |
| `line_id` | Line |
| `shift` | Shift |
| `operator_id` | Operator |
| `status` | `COMPLETE` / `ABORT` |
| `units_produced` | Units completed in the session |

### ENGINE_BUILD / TRANSMISSION_BUILD / CHASSIS_BUILD (`ids`, `production`)

Row key: build ID (`EB-…`, `TB-…`, `CB-…`)

**Column family `ids`**:

| Qualifier | Table | Description |
|-----------|-------|-------------|
| `engine_type_id` | `ENGINE_BUILD` | References `ENGINE` |
| `transmission_type_id` | `TRANSMISSION_BUILD` | References `TRANSMISSION` |
| `chassis_type_id` | `CHASSIS_BUILD` | References `CHASSIS` |
| `device_id` | all build tables | References shared `DEVICE` |
| `session_id` | all build tables | References `DEVICE_SESSION` |

**Column family `production`** (all three build tables):

| Qualifier | Description |
|-----------|-------------|
| `build_date` | Manufacture date |
| `plant_code` | Plant |
| `line_id` | Line |
| `shift` | Shift |
| `batch_number` | Batch |
| `serial_number` | Unit serial |
| `qc_status` | QC result |
| `operator_id` | Operator |

### VEHICLE (`ids`, `info`)

Row key: VIN

**Column family `ids`** (physical build references):

| Qualifier | Description |
|-----------|-------------|
| `engine_build_id` | References `ENGINE_BUILD` |
| `transmission_build_id` | References `TRANSMISSION_BUILD` |
| `chassis_build_id` | References `CHASSIS_BUILD` |

**Column family `info`**: `make`, `model`, `year`, `color`, `trim`

## Sample Data

### Type catalogs

| Engine ID | Manufacturer | Model | HP | Fuel |
|-----------|--------------|-------|-----|------|
| ENG001 | Honda | K24Z7 | 185 | Gasoline |
| ENG002 | Toyota | 2GR-FE | 268 | Gasoline |
| ENG003 | Ford | EcoBoost 2.3 | 310 | Gasoline |
| ENG004 | BMW | B58B30 | 382 | Gasoline |
| ENG005 | Tesla | Dual Motor | 670 | Electric |

Types `TRN001`–`TRN004` and `CHS001`–`CHS004` are unchanged from the original catalogs.

### Vehicles (VIN → build IDs)

| VIN | Make / Model | Engine build | Trans build | Chassis build |
|-----|--------------|--------------|-------------|----------------|
| 1HGCM82633A004352 | Honda Civic 2022 | EB-ENG001-00001 | TB-TRN001-00001 | CB-CHS001-00001 |
| 1HGCV1F30JA000123 | Honda Accord 2023 | EB-ENG001-00002 | TB-TRN001-00002 | CB-CHS001-00002 |
| 5TDKZRFH0KS123456 | Toyota Highlander 2021 | EB-ENG002-00001 | TB-TRN002-00001 | CB-CHS002-00001 |
| 2T3P1RFV8MW078901 | Toyota RAV4 2024 | EB-ENG002-00002 | TB-TRN002-00002 | CB-CHS002-00002 |
| 1FA6P8CF5L5102345 | Ford Mustang 2020 | EB-ENG003-00001 | TB-TRN003-00001 | CB-CHS003-00001 |
| WBA5U9C05LF345678 | BMW M340i 2023 | EB-ENG004-00001 | TB-TRN004-00001 | CB-CHS001-00003 |
| 5YJ3E1EA1KF789012 | Tesla Model Y 2024 | EB-ENG005-00001 | TB-TRN004-00002 | CB-CHS004-00001 |

Multiple VINs can share an engine **type** (e.g. ENG001) while each gets a distinct **build** row.

### Device sessions (sample)

Each build references one session. Example chassis sessions for `DEV008`:

| Session ID | Device | Start | Shift | Status | Build |
|------------|--------|-------|-------|--------|-------|
| `SES-DEV008-20220308-001` | DEV008 | 2022-03-08T06:00:00Z | A | COMPLETE | `CB-CHS001-00001` (Civic) |
| `SES-DEV008-20230114-001` | DEV008 | 2023-01-14T14:00:00Z | B | COMPLETE | `CB-CHS001-00002` (Accord) |

## Implementation

### Script Location

- `create_vehicle360_tables.sh` - Local Docker / docker-compose stack
- `create_vehicle360_tables_cdp.sh` - **CDP Private Cloud Base 7.1.9** (edge node + Kerberos; no Docker)
- [`CDP.md`](CDP.md) - CDP 7.1.9 usage examples for `create_vehicle360_tables_cdp.sh`
- `run_vehicle360_queries.sh` - Runs query examples (including complete vehicle JOIN view)
- `sample_queries.sql` - Full collection of Phoenix SQL queries

### Quick Start

1. **Create tables, data, and views** (local Docker):
   ```bash
   ./create_vehicle360_tables.sh
   ```

   Optional overrides (defaults match local docker-compose):
   ```bash
   ./create_vehicle360_tables.sh --help
   ./create_vehicle360_tables.sh \
     --api-url http://localhost:8099/api/phoenix \
     --container opdb-docker \
     --hbase-bin /opt/hbase/bin/hbase
   ```

2. **Create tables on CDP 7.1.9** (run on an HBase edge/gateway node):
   ```bash
   ./create_vehicle360_tables_cdp.sh --help
   ./create_vehicle360_tables_cdp.sh \
     --hbase-bin /opt/cloudera/parcels/CDH/bin/hbase \
     --principal user@EXAMPLE.COM \
     --keytab /path/to/user.keytab \
     --api-url https://your-phoenix-api.example.com/api/phoenix
   ```

   User must provide Kerberos principal/keytab (or `--skip-kinit`), and an `--api-url` unless skipping views/queries. ZooKeeper and security settings come from Cloudera Manager client configs (`--hbase-conf-dir`, default `/etc/hbase/conf`).

3. **Use the SQL Search GUI** (http://localhost:8100):
   - Open the **Vehicle 360** section
   - Create Phoenix views (Execute Command), then run VIN / JOIN queries (Execute Query)

4. **Or run query examples from the CLI**:
   ```bash
   ./run_vehicle360_queries.sh
   ```

5. **Or query a full vehicle build manually**:
   ```bash
   curl -X POST http://localhost:8099/api/phoenix/query \
     -H "Content-Type: application/json" \
     -d '{"sql": "SELECT v.\"rowkey\" as vin, v.\"info\".\"make\", v.\"info\".\"model\", eb.\"rowkey\" as engine_build_id, e.\"specs\".\"horsepower\", ed.\"specs\".\"name\" as engine_device_name, tb.\"rowkey\" as transmission_build_id, t.\"specs\".\"type\", td.\"specs\".\"name\" as transmission_device_name, cb.\"rowkey\" as chassis_build_id, c.\"specs\".\"body_style\", cd.\"specs\".\"name\" as chassis_device_name FROM \"VEHICLE\" v JOIN \"ENGINE_BUILD\" eb ON v.\"ids\".\"engine_build_id\" = eb.\"rowkey\" JOIN \"ENGINE\" e ON eb.\"ids\".\"engine_type_id\" = e.\"rowkey\" JOIN \"DEVICE\" ed ON eb.\"ids\".\"device_id\" = ed.\"rowkey\" JOIN \"TRANSMISSION_BUILD\" tb ON v.\"ids\".\"transmission_build_id\" = tb.\"rowkey\" JOIN \"TRANSMISSION\" t ON tb.\"ids\".\"transmission_type_id\" = t.\"rowkey\" JOIN \"DEVICE\" td ON tb.\"ids\".\"device_id\" = td.\"rowkey\" JOIN \"CHASSIS_BUILD\" cb ON v.\"ids\".\"chassis_build_id\" = cb.\"rowkey\" JOIN \"CHASSIS\" c ON cb.\"ids\".\"chassis_type_id\" = c.\"rowkey\" JOIN \"DEVICE\" cd ON cb.\"ids\".\"device_id\" = cd.\"rowkey\" WHERE v.\"rowkey\" = '\''1HGCM82633A004352'\''"}'
   ```

> **Important**: HBase tables and Phoenix views are **ephemeral** in the Docker container. If you stop or restart the Docker environment (`docker-compose down`), recreate them:
> ```bash
> ./create_vehicle360_tables.sh --recreate
> ```

### Manual Setup

Prefer `./create_vehicle360_tables.sh --recreate`. Minimal skeleton:

#### Step 1: Create HBase Tables

```bash
docker exec -i opdb-docker /opt/hbase/bin/hbase shell <<'EOF'
create 'ENGINE', 'specs'
create 'TRANSMISSION', 'specs'
create 'CHASSIS', 'specs'
create 'DEVICE', 'specs'
create 'DEVICE_SESSION', 'ids', 'run'
create 'ENGINE_BUILD', 'ids', 'production'
create 'TRANSMISSION_BUILD', 'ids', 'production'
create 'CHASSIS_BUILD', 'ids', 'production'
create 'VEHICLE', 'ids', 'info'
EOF
```

#### Step 2: Insert Sample Data

```bash
docker exec -i opdb-docker /opt/hbase/bin/hbase shell <<'EOF'
put 'ENGINE', 'ENG001', 'specs:manufacturer', 'Honda'
put 'ENGINE', 'ENG001', 'specs:model', 'K24Z7'
put 'ENGINE', 'ENG001', 'specs:horsepower', '185'
put 'DEVICE', 'DEV001', 'specs:name', 'K24 Block Line Robot'
put 'DEVICE_SESSION', 'SES-DEV001-20220312-001', 'ids:device_id', 'DEV001'
put 'DEVICE_SESSION', 'SES-DEV001-20220312-001', 'run:status', 'COMPLETE'
put 'ENGINE_BUILD', 'EB-ENG001-00001', 'ids:engine_type_id', 'ENG001'
put 'ENGINE_BUILD', 'EB-ENG001-00001', 'ids:device_id', 'DEV001'
put 'ENGINE_BUILD', 'EB-ENG001-00001', 'ids:session_id', 'SES-DEV001-20220312-001'
put 'ENGINE_BUILD', 'EB-ENG001-00001', 'production:plant_code', 'MARYSVILLE'
put 'ENGINE_BUILD', 'EB-ENG001-00001', 'production:serial_number', '00001'
put 'TRANSMISSION', 'TRN001', 'specs:type', 'CVT'
put 'TRANSMISSION_BUILD', 'TB-TRN001-00001', 'ids:transmission_type_id', 'TRN001'
put 'CHASSIS', 'CHS001', 'specs:body_style', 'Sedan'
put 'CHASSIS_BUILD', 'CB-CHS001-00001', 'ids:chassis_type_id', 'CHS001'
put 'VEHICLE', '1HGCM82633A004352', 'ids:engine_build_id', 'EB-ENG001-00001'
put 'VEHICLE', '1HGCM82633A004352', 'ids:transmission_build_id', 'TB-TRN001-00001'
put 'VEHICLE', '1HGCM82633A004352', 'ids:chassis_build_id', 'CB-CHS001-00001'
put 'VEHICLE', '1HGCM82633A004352', 'info:make', 'Honda'
put 'VEHICLE', '1HGCM82633A004352', 'info:model', 'Civic'
put 'VEHICLE', '1HGCM82633A004352', 'info:year', '2022'
EOF
```

#### Step 3: Create Phoenix Views

```bash
curl -X POST http://localhost:8099/api/phoenix/execute \
  -H "Content-Type: application/json" \
  -d '{"sql": "CREATE VIEW IF NOT EXISTS \"ENGINE\" (\"rowkey\" VARCHAR PRIMARY KEY, \"specs\".\"manufacturer\" VARCHAR, \"specs\".\"model\" VARCHAR, \"specs\".\"displacement_l\" VARCHAR, \"specs\".\"cylinders\" VARCHAR, \"specs\".\"horsepower\" VARCHAR, \"specs\".\"fuel_type\" VARCHAR)"}'

curl -X POST http://localhost:8099/api/phoenix/execute \
  -H "Content-Type: application/json" \
  -d '{"sql": "CREATE VIEW IF NOT EXISTS \"TRANSMISSION\" (\"rowkey\" VARCHAR PRIMARY KEY, \"specs\".\"manufacturer\" VARCHAR, \"specs\".\"model\" VARCHAR, \"specs\".\"type\" VARCHAR, \"specs\".\"gears\" VARCHAR, \"specs\".\"drive_type\" VARCHAR)"}'

curl -X POST http://localhost:8099/api/phoenix/execute \
  -H "Content-Type: application/json" \
  -d '{"sql": "CREATE VIEW IF NOT EXISTS \"CHASSIS\" (\"rowkey\" VARCHAR PRIMARY KEY, \"specs\".\"body_style\" VARCHAR, \"specs\".\"material\" VARCHAR, \"specs\".\"wheelbase_in\" VARCHAR, \"specs\".\"curb_weight_lb\" VARCHAR, \"specs\".\"doors\" VARCHAR)"}'

curl -X POST http://localhost:8099/api/phoenix/execute \
  -H "Content-Type: application/json" \
  -d '{"sql": "CREATE VIEW IF NOT EXISTS \"VEHICLE\" (\"rowkey\" VARCHAR PRIMARY KEY, \"ids\".\"engine_build_id\" VARCHAR, \"ids\".\"transmission_build_id\" VARCHAR, \"ids\".\"chassis_build_id\" VARCHAR, \"info\".\"make\" VARCHAR, \"info\".\"model\" VARCHAR, \"info\".\"year\" VARCHAR, \"info\".\"color\" VARCHAR, \"info\".\"trim\" VARCHAR)"}'
```

Also create `DEVICE`, `DEVICE_SESSION`, `ENGINE_BUILD`, `TRANSMISSION_BUILD`, and `CHASSIS_BUILD` views (see `sample_queries.sql`).

## Query Examples

### Query 1: Vehicle by VIN (build IDs only)

```sql
SELECT
  "rowkey" as vin,
  "info"."make",
  "info"."model",
  "info"."year",
  "ids"."engine_build_id",
  "ids"."transmission_build_id",
  "ids"."chassis_build_id"
FROM "VEHICLE"
WHERE "rowkey" = '1HGCM82633A004352'
```

### Query 2: Full build sheet (VIN → builds → types / devices / sessions)

```sql
SELECT
  v."rowkey" as vin,
  v."info"."make" as make,
  v."info"."model" as model,
  v."info"."year" as year,
  v."info"."color" as color,
  v."info"."trim" as trim,
  eb."rowkey" as engine_build_id,
  eb."ids"."session_id" as engine_session_id,
  eb."production"."plant_code" as engine_plant,
  e."specs"."horsepower" as horsepower,
  ed."rowkey" as engine_device_id,
  ed."specs"."name" as engine_device_name,
  es."run"."status" as engine_session_status,
  tb."rowkey" as transmission_build_id,
  tb."ids"."session_id" as transmission_session_id,
  t."specs"."type" as transmission_type,
  t."specs"."drive_type" as drive_type,
  td."rowkey" as transmission_device_id,
  td."specs"."name" as transmission_device_name,
  ts."run"."status" as transmission_session_status,
  cb."rowkey" as chassis_build_id,
  cb."ids"."session_id" as chassis_session_id,
  c."specs"."body_style" as body_style,
  cd."rowkey" as chassis_device_id,
  cd."specs"."name" as chassis_device_name,
  cs."run"."status" as chassis_session_status
FROM "VEHICLE" v
JOIN "ENGINE_BUILD" eb ON v."ids"."engine_build_id" = eb."rowkey"
JOIN "ENGINE" e ON eb."ids"."engine_type_id" = e."rowkey"
JOIN "DEVICE" ed ON eb."ids"."device_id" = ed."rowkey"
JOIN "DEVICE_SESSION" es ON eb."ids"."session_id" = es."rowkey"
JOIN "TRANSMISSION_BUILD" tb ON v."ids"."transmission_build_id" = tb."rowkey"
JOIN "TRANSMISSION" t ON tb."ids"."transmission_type_id" = t."rowkey"
JOIN "DEVICE" td ON tb."ids"."device_id" = td."rowkey"
JOIN "DEVICE_SESSION" ts ON tb."ids"."session_id" = ts."rowkey"
JOIN "CHASSIS_BUILD" cb ON v."ids"."chassis_build_id" = cb."rowkey"
JOIN "CHASSIS" c ON cb."ids"."chassis_type_id" = c."rowkey"
JOIN "DEVICE" cd ON cb."ids"."device_id" = cd."rowkey"
JOIN "DEVICE_SESSION" cs ON cb."ids"."session_id" = cs."rowkey"
WHERE v."rowkey" = '1HGCM82633A004352'
```

Garage Bay result for this query (**Build sheet — one VIN** / `completeVehicleOne`):

![Full join view by VIN](../../images/FullJoinByVIN.png)

See [Example Diagrams](#example-diagrams) for the JOIN / lineage architecture diagram.

### Query 3: Vehicles sharing an engine type (via builds)

```sql
SELECT
  v."rowkey" as vin,
  v."info"."make",
  v."info"."model",
  eb."rowkey" as engine_build_id,
  eb."ids"."engine_type_id"
FROM "VEHICLE" v
JOIN "ENGINE_BUILD" eb ON v."ids"."engine_build_id" = eb."rowkey"
WHERE eb."ids"."engine_type_id" = 'ENG001'
ORDER BY v."rowkey"
```

### Query 4: Device session by ID

Look up one production-run log (Garage Bay: **Session SES-DEV008-…** / `sessionById`):

```sql
SELECT
  "rowkey" as session_id,
  "ids"."device_id",
  "run"."start_ts",
  "run"."end_ts",
  "run"."plant_code",
  "run"."line_id",
  "run"."shift",
  "run"."operator_id",
  "run"."status",
  "run"."units_produced"
FROM "DEVICE_SESSION"
WHERE "rowkey" = 'SES-DEV008-20220308-001'
```

![Device session SES-DEV008-20220308-001](../../images/SessionID_Info.png)

This is the Civic chassis session (`DEV008` @ EAST-LIBERTY, shift A) referenced from `CB-CHS001-00001` in the full build sheet above.

### Query 5: VINs / builds from one device session

Trace a production run to the finished vehicle (example: Civic chassis session).

```sql
SELECT
  s."rowkey" as session_id,
  s."ids"."device_id",
  d."specs"."name" as device_name,
  s."run"."start_ts",
  s."run"."end_ts",
  s."run"."status",
  cb."rowkey" as chassis_build_id,
  v."rowkey" as vin,
  v."info"."make",
  v."info"."model",
  v."info"."year"
FROM "DEVICE_SESSION" s
JOIN "DEVICE" d ON s."ids"."device_id" = d."rowkey"
JOIN "CHASSIS_BUILD" cb ON cb."ids"."session_id" = s."rowkey"
JOIN "VEHICLE" v ON v."ids"."chassis_build_id" = cb."rowkey"
WHERE s."rowkey" = 'SES-DEV008-20220308-001'
```

### Query 6: VINs that used the same device

A manufacturing device can appear on engine, transmission, and/or chassis builds. Union the three paths to list every VIN that touched a given `device_id` (example: `DEV008` — East Liberty Body Fixture on Civic and Accord chassis).

```sql
SELECT
  v."rowkey" as vin,
  v."info"."make" as make,
  v."info"."model" as model,
  v."info"."year" as year,
  'ENGINE' as build_role,
  eb."rowkey" as build_id,
  eb."ids"."device_id" as device_id,
  d."specs"."name" as device_name,
  d."specs"."device_type" as device_type
FROM "VEHICLE" v
JOIN "ENGINE_BUILD" eb ON v."ids"."engine_build_id" = eb."rowkey"
JOIN "DEVICE" d ON eb."ids"."device_id" = d."rowkey"
WHERE eb."ids"."device_id" = 'DEV008'
UNION ALL
SELECT
  v."rowkey" as vin,
  v."info"."make" as make,
  v."info"."model" as model,
  v."info"."year" as year,
  'TRANSMISSION' as build_role,
  tb."rowkey" as build_id,
  tb."ids"."device_id" as device_id,
  d."specs"."name" as device_name,
  d."specs"."device_type" as device_type
FROM "VEHICLE" v
JOIN "TRANSMISSION_BUILD" tb ON v."ids"."transmission_build_id" = tb."rowkey"
JOIN "DEVICE" d ON tb."ids"."device_id" = d."rowkey"
WHERE tb."ids"."device_id" = 'DEV008'
UNION ALL
SELECT
  v."rowkey" as vin,
  v."info"."make" as make,
  v."info"."model" as model,
  v."info"."year" as year,
  'CHASSIS' as build_role,
  cb."rowkey" as build_id,
  cb."ids"."device_id" as device_id,
  d."specs"."name" as device_name,
  d."specs"."device_type" as device_type
FROM "VEHICLE" v
JOIN "CHASSIS_BUILD" cb ON v."ids"."chassis_build_id" = cb."rowkey"
JOIN "DEVICE" d ON cb."ids"."device_id" = d."rowkey"
WHERE cb."ids"."device_id" = 'DEV008'
ORDER BY vin, build_role
```

### Query 7: High-horsepower vehicles

```sql
SELECT
  v."rowkey" as vin,
  v."info"."make",
  v."info"."model",
  e."specs"."horsepower",
  eb."rowkey" as engine_build_id
FROM "VEHICLE" v
JOIN "ENGINE_BUILD" eb ON v."ids"."engine_build_id" = eb."rowkey"
JOIN "ENGINE" e ON eb."ids"."engine_type_id" = e."rowkey"
WHERE TO_NUMBER(e."specs"."horsepower") >= 300
ORDER BY TO_NUMBER(e."specs"."horsepower") DESC
```

### Query 8: Count vehicles per transmission type

```sql
SELECT
  t."specs"."type" as transmission_type,
  COUNT(*) as vehicle_count
FROM "VEHICLE" v
JOIN "TRANSMISSION_BUILD" tb ON v."ids"."transmission_build_id" = tb."rowkey"
JOIN "TRANSMISSION" t ON tb."ids"."transmission_type_id" = t."rowkey"
GROUP BY t."specs"."type"
ORDER BY t."specs"."type"
```

## Key Design Decisions

### Row Keys

- **Type catalogs**: Short IDs (`ENG001`, `TRN001`, `CHS001`)
- **DEVICE**: Short IDs (`DEV001`, …)
- **DEVICE_SESSION**: `SES-{deviceId}-{yyyyMMdd}-{seq}`
- **Build tables**: Prefixed unit IDs (`EB-ENG001-00001`, `TB-…`, `CB-…`)
- **VEHICLE**: VIN as row key — natural unique identifier for a finished vehicle
- All keys stored as VARCHAR strings

### Column Families

- Type catalogs and `DEVICE` use a single `specs` family
- `DEVICE_SESSION` uses `ids` (device FK) + `run` (production-run log)
- Build tables use `ids` (type FK + `device_id` + `session_id`) + `production` (manufacturing metadata)
- `VEHICLE` separates `ids` (build refs) from `info` (display fields)

### Data Types

- All HBase values are VARCHAR
- Use `TO_NUMBER()` for numeric comparisons in Phoenix (e.g. horsepower, year, weight)
- HBase does not enforce foreign keys; application/query logic must join on matching ID strings

### Scalability

- Component catalogs stay small and are reused across many vehicles
- Vehicle table grows with fleet size; row-key VIN lookups remain O(1)
- JOIN cost appears only when a full build is needed

## Use Cases

### 1. VIN Lookup Dashboard / Full Build by VIN

Show make/model, component types, build production metadata, manufacturing devices, and device sessions for a single VIN (Query 2 above). In Garage Bay, **Build sheet — one VIN** runs the full JOIN path (see [Example Diagrams](#example-diagrams)).

### 2. Parts Reuse Report

Find every vehicle built with a given engine type (via builds) (Query 3).

### 3. Device Traceability

Find every VIN that used a manufacturing device on any component build (Query 6). Useful for recalls, QC holds, or maintenance impact analysis.

### 4. Session Traceability

Look up a production-run log by session ID (Query 4), then follow it to the finished VIN (Query 5). Useful for shift audits and run-level quality holds.

### 5. Performance Filtering

Filter the fleet by horsepower, drivetrain, or body style via JOINs.

### 6. Catalog Maintenance

Update engine horsepower once in `ENGINE`; all vehicles referencing that ID see the new value on the next JOIN query.

## Example Diagrams

### Table architecture

Reference ER diagram for all nine tables (catalogs → device sessions → builds → VIN):

![Vehicle manufacturing line tracking reference architecture](../../images/vehicle360_table_view.png)

### Full JOIN / lineage flow

VIN-centric lineage through builds, type catalogs, devices, and production sessions:

![Vehicle lineage and device tracking architecture flow](../../images/vehicle360_fullJoin.png)

In Garage Bay, **Build sheet — one VIN** (`completeVehicleOne`) runs this JOIN path for VIN `1HGCM82633A004352` (includes `DEV` / `SES` on each component):

![Full join view by VIN](../../images/FullJoinByVIN.png)

### Device session detail

Garage Bay **Session SES-DEV008-…** (`sessionById`) for the Civic chassis session:

![Device session SES-DEV008-20220308-001](../../images/SessionID_Info.png)

## Related Documentation

- [Student 360 Use Case](../student360/README.md) — single wide-table pattern
- [Soldier 360 Use Case](../soldier360/README.md) — single wide-table pattern
- [Student 360 Multi-Table Design](../student360/student_360_view_design.md) — alternate JOIN design with shared row keys
- [Phoenix Views Documentation](../../Documentation/README_VIEWS.md)
- [HBase vs Phoenix Tables](../../Documentation/HBASE_VS_PHOENIX_TABLES.md)

## Sample SQL Queries

See `sample_queries.sql` for 30+ queries covering:

- Component lookups by ID
- Device session lookups and sessions-by-device
- Vehicle lookups by VIN / make / year
- Full vehicle builds with JOINs (including sessions)
- Device and session traceability
- Component reuse and counts
- Filters with `TO_NUMBER()`
- Aggregations by make, transmission type, body style, fuel type

## Summary

The Vehicle 360 use case demonstrates:

- Separate HBase tables for engine, transmission, and chassis catalogs
- Shared `DEVICE` catalog and `DEVICE_SESSION` production-run logs
- Build rows that reference both `device_id` and `session_id`
- A VIN-keyed `VEHICLE` table that combines one engine, transmission, and chassis **build**
- Phoenix views for SQL access
- JOIN-based full vehicle builds (VIN → builds → types / devices / sessions)
- A clear contrast to the denormalized student/soldier 360 wide-table pattern
