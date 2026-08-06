-- Sample Phoenix SQL Queries for Vehicle 360 Use Case
-- Type catalogs: ENGINE, TRANSMISSION, CHASSIS
-- Devices:       DEVICE (shared manufacturing equipment)
-- Sessions:      DEVICE_SESSION (production-run log per device session)
-- Build tables:  ENGINE_BUILD, TRANSMISSION_BUILD, CHASSIS_BUILD
-- Assembly:      VEHICLE (VIN → *_build_id)
--
-- Pattern: DEVICE → DEVICE_SESSION → build → type catalog; VIN JOINs through builds
--
-- Prerequisite: HBase tables must already exist and contain data.
-- Run the CREATE VIEW statements below before the SELECT queries.

-- ============================================================
-- CREATE PHOENIX VIEWS
-- ============================================================

CREATE VIEW IF NOT EXISTS "ENGINE" (
    "rowkey" VARCHAR PRIMARY KEY,
    "specs"."manufacturer" VARCHAR,
    "specs"."model" VARCHAR,
    "specs"."displacement_l" VARCHAR,
    "specs"."cylinders" VARCHAR,
    "specs"."horsepower" VARCHAR,
    "specs"."fuel_type" VARCHAR
);

CREATE VIEW IF NOT EXISTS "TRANSMISSION" (
    "rowkey" VARCHAR PRIMARY KEY,
    "specs"."manufacturer" VARCHAR,
    "specs"."model" VARCHAR,
    "specs"."type" VARCHAR,
    "specs"."gears" VARCHAR,
    "specs"."drive_type" VARCHAR
);

CREATE VIEW IF NOT EXISTS "CHASSIS" (
    "rowkey" VARCHAR PRIMARY KEY,
    "specs"."body_style" VARCHAR,
    "specs"."material" VARCHAR,
    "specs"."wheelbase_in" VARCHAR,
    "specs"."curb_weight_lb" VARCHAR,
    "specs"."doors" VARCHAR
);

CREATE VIEW IF NOT EXISTS "DEVICE" (
    "rowkey" VARCHAR PRIMARY KEY,
    "specs"."name" VARCHAR,
    "specs"."device_type" VARCHAR,
    "specs"."manufacturer" VARCHAR,
    "specs"."model" VARCHAR,
    "specs"."plant_code" VARCHAR,
    "specs"."status" VARCHAR
);

CREATE VIEW IF NOT EXISTS "DEVICE_SESSION" (
    "rowkey" VARCHAR PRIMARY KEY,
    "ids"."device_id" VARCHAR,
    "run"."start_ts" VARCHAR,
    "run"."end_ts" VARCHAR,
    "run"."plant_code" VARCHAR,
    "run"."line_id" VARCHAR,
    "run"."shift" VARCHAR,
    "run"."operator_id" VARCHAR,
    "run"."status" VARCHAR,
    "run"."units_produced" VARCHAR
);

CREATE VIEW IF NOT EXISTS "ENGINE_BUILD" (
    "rowkey" VARCHAR PRIMARY KEY,
    "ids"."engine_type_id" VARCHAR,
    "ids"."device_id" VARCHAR,
    "ids"."session_id" VARCHAR,
    "production"."build_date" VARCHAR,
    "production"."plant_code" VARCHAR,
    "production"."line_id" VARCHAR,
    "production"."shift" VARCHAR,
    "production"."batch_number" VARCHAR,
    "production"."serial_number" VARCHAR,
    "production"."qc_status" VARCHAR,
    "production"."operator_id" VARCHAR
);

CREATE VIEW IF NOT EXISTS "TRANSMISSION_BUILD" (
    "rowkey" VARCHAR PRIMARY KEY,
    "ids"."transmission_type_id" VARCHAR,
    "ids"."device_id" VARCHAR,
    "ids"."session_id" VARCHAR,
    "production"."build_date" VARCHAR,
    "production"."plant_code" VARCHAR,
    "production"."line_id" VARCHAR,
    "production"."shift" VARCHAR,
    "production"."batch_number" VARCHAR,
    "production"."serial_number" VARCHAR,
    "production"."qc_status" VARCHAR,
    "production"."operator_id" VARCHAR
);

CREATE VIEW IF NOT EXISTS "CHASSIS_BUILD" (
    "rowkey" VARCHAR PRIMARY KEY,
    "ids"."chassis_type_id" VARCHAR,
    "ids"."device_id" VARCHAR,
    "ids"."session_id" VARCHAR,
    "production"."build_date" VARCHAR,
    "production"."plant_code" VARCHAR,
    "production"."line_id" VARCHAR,
    "production"."shift" VARCHAR,
    "production"."batch_number" VARCHAR,
    "production"."serial_number" VARCHAR,
    "production"."qc_status" VARCHAR,
    "production"."operator_id" VARCHAR
);

CREATE VIEW IF NOT EXISTS "VEHICLE" (
    "rowkey" VARCHAR PRIMARY KEY,
    "ids"."engine_build_id" VARCHAR,
    "ids"."transmission_build_id" VARCHAR,
    "ids"."chassis_build_id" VARCHAR,
    "info"."make" VARCHAR,
    "info"."model" VARCHAR,
    "info"."year" VARCHAR,
    "info"."color" VARCHAR,
    "info"."trim" VARCHAR
);

-- Optional: drop views if schema changes
-- DROP VIEW IF EXISTS "VEHICLE";
-- DROP VIEW IF EXISTS "ENGINE_BUILD";
-- DROP VIEW IF EXISTS "TRANSMISSION_BUILD";
-- DROP VIEW IF EXISTS "CHASSIS_BUILD";
-- DROP VIEW IF EXISTS "DEVICE_SESSION";
-- DROP VIEW IF EXISTS "ENGINE";
-- DROP VIEW IF EXISTS "TRANSMISSION";
-- DROP VIEW IF EXISTS "CHASSIS";
-- DROP VIEW IF EXISTS "DEVICE";

-- ============================================================
-- TYPE CATALOG LOOKUPS
-- ============================================================

SELECT *
FROM "ENGINE"
WHERE "rowkey" = 'ENG001';

SELECT *
FROM "TRANSMISSION"
WHERE "rowkey" = 'TRN002';

SELECT *
FROM "CHASSIS"
WHERE "rowkey" = 'CHS003';

-- ============================================================
-- DEVICE LOOKUPS
-- ============================================================

SELECT
    "rowkey" as device_id,
    "specs"."name",
    "specs"."device_type",
    "specs"."manufacturer",
    "specs"."model",
    "specs"."plant_code",
    "specs"."status"
FROM "DEVICE"
WHERE "rowkey" = 'DEV001';

SELECT
    "rowkey" as device_id,
    "specs"."name",
    "specs"."device_type",
    "specs"."plant_code",
    "specs"."status"
FROM "DEVICE"
WHERE "specs"."plant_code" = 'MARYSVILLE'
ORDER BY "rowkey";

-- ============================================================
-- DEVICE SESSION LOOKUPS (production-run log)
-- ============================================================

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
WHERE "rowkey" = 'SES-DEV008-20220308-001';

SELECT
    s."rowkey" as session_id,
    s."ids"."device_id",
    d."specs"."name" as device_name,
    s."run"."start_ts",
    s."run"."end_ts",
    s."run"."shift",
    s."run"."status",
    s."run"."units_produced"
FROM "DEVICE_SESSION" s
JOIN "DEVICE" d ON s."ids"."device_id" = d."rowkey"
WHERE s."ids"."device_id" = 'DEV008'
ORDER BY s."run"."start_ts";

-- ============================================================
-- BUILD LOOKUPS (physical unit + production metadata)
-- ============================================================

SELECT
    "rowkey" as engine_build_id,
    "ids"."engine_type_id",
    "ids"."device_id",
    "ids"."session_id",
    "production"."build_date",
    "production"."plant_code",
    "production"."line_id",
    "production"."shift",
    "production"."batch_number",
    "production"."serial_number",
    "production"."qc_status",
    "production"."operator_id"
FROM "ENGINE_BUILD"
WHERE "rowkey" = 'EB-ENG001-00001';

SELECT
    eb."rowkey" as engine_build_id,
    eb."ids"."engine_type_id",
    eb."ids"."device_id",
    eb."ids"."session_id",
    eb."production"."build_date",
    eb."production"."plant_code",
    eb."production"."qc_status",
    e."specs"."manufacturer",
    e."specs"."model",
    e."specs"."horsepower",
    d."specs"."name" as device_name,
    d."specs"."device_type",
    s."run"."start_ts" as session_start,
    s."run"."status" as session_status
FROM "ENGINE_BUILD" eb
JOIN "ENGINE" e ON eb."ids"."engine_type_id" = e."rowkey"
JOIN "DEVICE" d ON eb."ids"."device_id" = d."rowkey"
JOIN "DEVICE_SESSION" s ON eb."ids"."session_id" = s."rowkey"
WHERE eb."rowkey" = 'EB-ENG001-00001';

SELECT
    "rowkey" as transmission_build_id,
    "ids"."transmission_type_id",
    "production"."plant_code",
    "production"."serial_number",
    "production"."qc_status"
FROM "TRANSMISSION_BUILD"
WHERE "ids"."transmission_type_id" = 'TRN001'
ORDER BY "rowkey";

SELECT
    "rowkey" as chassis_build_id,
    "ids"."chassis_type_id",
    "production"."plant_code",
    "production"."batch_number",
    "production"."qc_status"
FROM "CHASSIS_BUILD"
WHERE "ids"."chassis_type_id" = 'CHS001'
ORDER BY "rowkey";

-- ============================================================
-- VEHICLE LOOKUPS
-- ============================================================

SELECT
    "rowkey" as vin,
    "info"."make",
    "info"."model",
    "info"."year",
    "info"."color",
    "info"."trim",
    "ids"."engine_build_id",
    "ids"."transmission_build_id",
    "ids"."chassis_build_id"
FROM "VEHICLE"
WHERE "rowkey" = '1HGCM82633A004352';

SELECT
    "rowkey" as vin,
    "info"."make",
    "info"."model",
    "info"."year",
    "ids"."engine_build_id",
    "ids"."transmission_build_id",
    "ids"."chassis_build_id"
FROM "VEHICLE"
ORDER BY "info"."make", "info"."model";

-- ============================================================
-- COMPLETE BUILD SHEET (VIN → builds → types / devices / sessions)
-- ============================================================

SELECT
    v."rowkey" as vin,
    v."info"."make" as make,
    v."info"."model" as model,
    v."info"."year" as year,
    v."info"."color" as color,
    v."info"."trim" as trim,
    eb."rowkey" as engine_build_id,
    eb."ids"."engine_type_id" as engine_type_id,
    eb."ids"."device_id" as engine_device_id,
    eb."ids"."session_id" as engine_session_id,
    eb."production"."build_date" as engine_build_date,
    eb."production"."plant_code" as engine_plant,
    eb."production"."line_id" as engine_line,
    eb."production"."shift" as engine_shift,
    eb."production"."batch_number" as engine_batch,
    eb."production"."serial_number" as engine_serial,
    eb."production"."qc_status" as engine_qc,
    eb."production"."operator_id" as engine_operator,
    e."specs"."manufacturer" as engine_mfr,
    e."specs"."model" as engine_model,
    e."specs"."displacement_l" as displacement_l,
    e."specs"."cylinders" as cylinders,
    e."specs"."horsepower" as horsepower,
    e."specs"."fuel_type" as fuel_type,
    ed."specs"."name" as engine_device_name,
    ed."specs"."device_type" as engine_device_type,
    ed."specs"."model" as engine_device_model,
    es."run"."start_ts" as engine_session_start,
    es."run"."status" as engine_session_status,
    tb."rowkey" as transmission_build_id,
    tb."ids"."transmission_type_id" as transmission_type_id,
    tb."ids"."device_id" as transmission_device_id,
    tb."ids"."session_id" as transmission_session_id,
    tb."production"."build_date" as transmission_build_date,
    tb."production"."plant_code" as transmission_plant,
    tb."production"."serial_number" as transmission_serial,
    tb."production"."qc_status" as transmission_qc,
    t."specs"."manufacturer" as transmission_mfr,
    t."specs"."model" as transmission_model,
    t."specs"."type" as transmission_type,
    t."specs"."gears" as gears,
    t."specs"."drive_type" as drive_type,
    td."specs"."name" as transmission_device_name,
    td."specs"."device_type" as transmission_device_type,
    ts."run"."start_ts" as transmission_session_start,
    ts."run"."status" as transmission_session_status,
    cb."rowkey" as chassis_build_id,
    cb."ids"."chassis_type_id" as chassis_type_id,
    cb."ids"."device_id" as chassis_device_id,
    cb."ids"."session_id" as chassis_session_id,
    cb."production"."build_date" as chassis_build_date,
    cb."production"."plant_code" as chassis_plant,
    cb."production"."serial_number" as chassis_serial,
    cb."production"."qc_status" as chassis_qc,
    c."specs"."body_style" as body_style,
    c."specs"."material" as material,
    c."specs"."wheelbase_in" as wheelbase_in,
    c."specs"."curb_weight_lb" as curb_weight_lb,
    c."specs"."doors" as doors,
    cd."specs"."name" as chassis_device_name,
    cd."specs"."device_type" as chassis_device_type,
    cs."run"."start_ts" as chassis_session_start,
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
WHERE v."rowkey" = '1HGCM82633A004352';

SELECT
    v."rowkey" as vin,
    v."info"."make" as make,
    v."info"."model" as model,
    v."info"."year" as year,
    eb."rowkey" as engine_build_id,
    e."specs"."horsepower" as horsepower,
    ed."specs"."name" as engine_device_name,
    tb."rowkey" as transmission_build_id,
    t."specs"."type" as transmission_type,
    t."specs"."drive_type" as drive_type,
    td."specs"."name" as transmission_device_name,
    cb."rowkey" as chassis_build_id,
    c."specs"."body_style" as body_style,
    cd."specs"."name" as chassis_device_name
FROM "VEHICLE" v
JOIN "ENGINE_BUILD" eb ON v."ids"."engine_build_id" = eb."rowkey"
JOIN "ENGINE" e ON eb."ids"."engine_type_id" = e."rowkey"
JOIN "DEVICE" ed ON eb."ids"."device_id" = ed."rowkey"
JOIN "TRANSMISSION_BUILD" tb ON v."ids"."transmission_build_id" = tb."rowkey"
JOIN "TRANSMISSION" t ON tb."ids"."transmission_type_id" = t."rowkey"
JOIN "DEVICE" td ON tb."ids"."device_id" = td."rowkey"
JOIN "CHASSIS_BUILD" cb ON v."ids"."chassis_build_id" = cb."rowkey"
JOIN "CHASSIS" c ON cb."ids"."chassis_type_id" = c."rowkey"
JOIN "DEVICE" cd ON cb."ids"."device_id" = cd."rowkey"
ORDER BY v."info"."make", v."info"."model";

-- ============================================================
-- TYPE REUSE VIA BUILDS
-- ============================================================

SELECT
    v."rowkey" as vin,
    v."info"."make",
    v."info"."model",
    eb."rowkey" as engine_build_id,
    eb."ids"."engine_type_id"
FROM "VEHICLE" v
JOIN "ENGINE_BUILD" eb ON v."ids"."engine_build_id" = eb."rowkey"
WHERE eb."ids"."engine_type_id" = 'ENG001'
ORDER BY v."rowkey";

-- ============================================================
-- DEVICE TRACEABILITY (VINs that used the same device)
-- A device can appear on engine, transmission, and/or chassis builds.
-- Example: DEV008 (East Liberty Body Fixture) → Civic + Accord chassis.
-- ============================================================

SELECT
    v."rowkey" as vin,
    v."info"."make" as make,
    v."info"."model" as model,
    v."info"."year" as year,
    'ENGINE' as build_role,
    eb."rowkey" as build_id,
    eb."ids"."device_id" as device_id,
    eb."ids"."session_id" as session_id,
    d."specs"."name" as device_name,
    d."specs"."device_type" as device_type,
    d."specs"."plant_code" as device_plant
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
    tb."ids"."session_id" as session_id,
    d."specs"."name" as device_name,
    d."specs"."device_type" as device_type,
    d."specs"."plant_code" as device_plant
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
    cb."ids"."session_id" as session_id,
    d."specs"."name" as device_name,
    d."specs"."device_type" as device_type,
    d."specs"."plant_code" as device_plant
FROM "VEHICLE" v
JOIN "CHASSIS_BUILD" cb ON v."ids"."chassis_build_id" = cb."rowkey"
JOIN "DEVICE" d ON cb."ids"."device_id" = d."rowkey"
WHERE cb."ids"."device_id" = 'DEV008'
ORDER BY vin, build_role;

-- ============================================================
-- SESSION TRACEABILITY (builds / VINs from one production run)
-- Example: SES-DEV008-20220308-001 → Civic chassis build → VIN
-- ============================================================

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
WHERE s."rowkey" = 'SES-DEV008-20220308-001';

SELECT
    v."rowkey" as vin,
    v."info"."make" as make,
    v."info"."model" as model,
    v."info"."year" as year,
    'ENGINE' as build_role,
    eb."rowkey" as build_id,
    eb."ids"."session_id" as session_id
FROM "VEHICLE" v
JOIN "ENGINE_BUILD" eb ON v."ids"."engine_build_id" = eb."rowkey"
WHERE eb."ids"."session_id" = 'SES-DEV008-20220308-001'
UNION ALL
SELECT
    v."rowkey" as vin,
    v."info"."make" as make,
    v."info"."model" as model,
    v."info"."year" as year,
    'TRANSMISSION' as build_role,
    tb."rowkey" as build_id,
    tb."ids"."session_id" as session_id
FROM "VEHICLE" v
JOIN "TRANSMISSION_BUILD" tb ON v."ids"."transmission_build_id" = tb."rowkey"
WHERE tb."ids"."session_id" = 'SES-DEV008-20220308-001'
UNION ALL
SELECT
    v."rowkey" as vin,
    v."info"."make" as make,
    v."info"."model" as model,
    v."info"."year" as year,
    'CHASSIS' as build_role,
    cb."rowkey" as build_id,
    cb."ids"."session_id" as session_id
FROM "VEHICLE" v
JOIN "CHASSIS_BUILD" cb ON v."ids"."chassis_build_id" = cb."rowkey"
WHERE cb."ids"."session_id" = 'SES-DEV008-20220308-001'
ORDER BY vin, build_role;

-- Distinct VINs only for a device (any build role)
SELECT DISTINCT
    v."rowkey" as vin,
    v."info"."make" as make,
    v."info"."model" as model,
    v."info"."year" as year
FROM "VEHICLE" v
JOIN "ENGINE_BUILD" eb ON v."ids"."engine_build_id" = eb."rowkey"
WHERE eb."ids"."device_id" = 'DEV008'
UNION
SELECT DISTINCT
    v."rowkey" as vin,
    v."info"."make" as make,
    v."info"."model" as model,
    v."info"."year" as year
FROM "VEHICLE" v
JOIN "TRANSMISSION_BUILD" tb ON v."ids"."transmission_build_id" = tb."rowkey"
WHERE tb."ids"."device_id" = 'DEV008'
UNION
SELECT DISTINCT
    v."rowkey" as vin,
    v."info"."make" as make,
    v."info"."model" as model,
    v."info"."year" as year
FROM "VEHICLE" v
JOIN "CHASSIS_BUILD" cb ON v."ids"."chassis_build_id" = cb."rowkey"
WHERE cb."ids"."device_id" = 'DEV008'
ORDER BY make, model;

SELECT
    eb."ids"."engine_type_id",
    COUNT(*) as vehicle_count
FROM "VEHICLE" v
JOIN "ENGINE_BUILD" eb ON v."ids"."engine_build_id" = eb."rowkey"
GROUP BY eb."ids"."engine_type_id"
ORDER BY eb."ids"."engine_type_id";

-- ============================================================
-- FILTERS AND AGGREGATIONS
-- ============================================================

SELECT
    v."rowkey" as vin,
    v."info"."make",
    v."info"."model",
    v."info"."year",
    e."specs"."horsepower",
    e."specs"."fuel_type",
    eb."rowkey" as engine_build_id
FROM "VEHICLE" v
JOIN "ENGINE_BUILD" eb ON v."ids"."engine_build_id" = eb."rowkey"
JOIN "ENGINE" e ON eb."ids"."engine_type_id" = e."rowkey"
WHERE TO_NUMBER(e."specs"."horsepower") >= 300
ORDER BY TO_NUMBER(e."specs"."horsepower") DESC;

SELECT
    v."rowkey" as vin,
    v."info"."make",
    v."info"."model",
    t."specs"."type",
    t."specs"."drive_type",
    tb."rowkey" as transmission_build_id
FROM "VEHICLE" v
JOIN "TRANSMISSION_BUILD" tb ON v."ids"."transmission_build_id" = tb."rowkey"
JOIN "TRANSMISSION" t ON tb."ids"."transmission_type_id" = t."rowkey"
WHERE t."specs"."drive_type" = 'AWD'
ORDER BY v."info"."make";

SELECT
    "info"."make",
    COUNT(*) as vehicle_count
FROM "VEHICLE"
GROUP BY "info"."make"
ORDER BY "info"."make";

SELECT
    eb."production"."plant_code" as engine_plant,
    COUNT(*) as vehicle_count
FROM "VEHICLE" v
JOIN "ENGINE_BUILD" eb ON v."ids"."engine_build_id" = eb."rowkey"
GROUP BY eb."production"."plant_code"
ORDER BY eb."production"."plant_code";
