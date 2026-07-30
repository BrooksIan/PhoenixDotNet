-- Sample Phoenix SQL Queries for Vehicle 360 Use Case
-- Tables: ENGINE, TRANSMISSION, CHASSIS, VEHICLE
-- Pattern: Normalized component catalogs + VIN assembly with JOINs

-- ============================================================
-- BASIC COMPONENT LOOKUPS
-- ============================================================

-- Query 1: Get engine by ID
SELECT *
FROM "ENGINE"
WHERE "rowkey" = 'ENG001';

-- Query 2: Get transmission by ID
SELECT *
FROM "TRANSMISSION"
WHERE "rowkey" = 'TRN002';

-- Query 3: Get chassis by ID
SELECT *
FROM "CHASSIS"
WHERE "rowkey" = 'CHS003';

-- Query 4: List all engines
SELECT
    "rowkey" as engine_id,
    "specs"."manufacturer",
    "specs"."model",
    "specs"."horsepower",
    "specs"."fuel_type"
FROM "ENGINE"
ORDER BY "rowkey";

-- Query 5: List all transmissions
SELECT
    "rowkey" as transmission_id,
    "specs"."manufacturer",
    "specs"."model",
    "specs"."type",
    "specs"."drive_type"
FROM "TRANSMISSION"
ORDER BY "rowkey";

-- Query 6: List all chassis
SELECT
    "rowkey" as chassis_id,
    "specs"."body_style",
    "specs"."material",
    "specs"."doors",
    "specs"."curb_weight_lb"
FROM "CHASSIS"
ORDER BY "rowkey";

-- ============================================================
-- VEHICLE LOOKUPS (IDs + INFO ONLY)
-- ============================================================

-- Query 7: Get vehicle by VIN
SELECT
    "rowkey" as vin,
    "info"."make",
    "info"."model",
    "info"."year",
    "info"."color",
    "info"."trim",
    "ids"."engine_id",
    "ids"."transmission_id",
    "ids"."chassis_id"
FROM "VEHICLE"
WHERE "rowkey" = '1HGCM82633A004352';

-- Query 8: List all vehicles
SELECT
    "rowkey" as vin,
    "info"."make",
    "info"."model",
    "info"."year",
    "info"."color",
    "ids"."engine_id",
    "ids"."transmission_id",
    "ids"."chassis_id"
FROM "VEHICLE"
ORDER BY "info"."make", "info"."model";

-- Query 9: Vehicles by make
SELECT
    "rowkey" as vin,
    "info"."make",
    "info"."model",
    "info"."year",
    "info"."trim"
FROM "VEHICLE"
WHERE "info"."make" = 'Honda'
ORDER BY "info"."year" DESC;

-- Query 10: Vehicles by year
SELECT
    "rowkey" as vin,
    "info"."make",
    "info"."model",
    "info"."year",
    "info"."color"
FROM "VEHICLE"
WHERE "info"."year" = '2024'
ORDER BY "info"."make";

-- ============================================================
-- FULL VEHICLE BUILD (JOINS) — complete vehicle view
-- ============================================================

-- Query 11: Complete vehicle view for one VIN
-- Joins VEHICLE to ENGINE, TRANSMISSION, and CHASSIS by component IDs
SELECT
    v."rowkey" as vin,
    v."info"."make",
    v."info"."model",
    v."info"."year",
    e."specs"."horsepower",
    t."specs"."type",
    t."specs"."drive_type",
    c."specs"."body_style"
FROM "VEHICLE" v
JOIN "ENGINE" e ON v."ids"."engine_id" = e."rowkey"
JOIN "TRANSMISSION" t ON v."ids"."transmission_id" = t."rowkey"
JOIN "CHASSIS" c ON v."ids"."chassis_id" = c."rowkey"
WHERE v."rowkey" = '1HGCM82633A004352';

-- Query 12: Complete vehicle view for all vehicles
SELECT
    v."rowkey" as vin,
    v."info"."make",
    v."info"."model",
    v."info"."year",
    e."specs"."horsepower",
    t."specs"."type",
    t."specs"."drive_type",
    c."specs"."body_style"
FROM "VEHICLE" v
JOIN "ENGINE" e ON v."ids"."engine_id" = e."rowkey"
JOIN "TRANSMISSION" t ON v."ids"."transmission_id" = t."rowkey"
JOIN "CHASSIS" c ON v."ids"."chassis_id" = c."rowkey"
ORDER BY v."info"."make", v."info"."model";

-- Query 12b: Detailed complete vehicle view (all component fields)
SELECT
    v."rowkey" as vin,
    v."info"."make",
    v."info"."model",
    v."info"."year",
    v."info"."color",
    v."info"."trim",
    e."rowkey" as engine_id,
    e."specs"."manufacturer" as engine_mfr,
    e."specs"."model" as engine_model,
    e."specs"."horsepower",
    e."specs"."fuel_type",
    t."rowkey" as transmission_id,
    t."specs"."type" as transmission_type,
    t."specs"."gears",
    t."specs"."drive_type",
    c."rowkey" as chassis_id,
    c."specs"."body_style",
    c."specs"."material",
    c."specs"."doors"
FROM "VEHICLE" v
JOIN "ENGINE" e ON v."ids"."engine_id" = e."rowkey"
JOIN "TRANSMISSION" t ON v."ids"."transmission_id" = t."rowkey"
JOIN "CHASSIS" c ON v."ids"."chassis_id" = c."rowkey"
WHERE v."rowkey" = '1HGCM82633A004352';

-- Query 13: Full build for BMW M340i
SELECT
    v."rowkey" as vin,
    v."info"."make",
    v."info"."model",
    v."info"."trim",
    e."specs"."model" as engine_model,
    e."specs"."horsepower",
    t."specs"."model" as transmission_model,
    t."specs"."type",
    c."specs"."body_style"
FROM "VEHICLE" v
JOIN "ENGINE" e ON v."ids"."engine_id" = e."rowkey"
JOIN "TRANSMISSION" t ON v."ids"."transmission_id" = t."rowkey"
JOIN "CHASSIS" c ON v."ids"."chassis_id" = c."rowkey"
WHERE v."rowkey" = 'WBA5U9C05LF345678';

-- ============================================================
-- COMPONENT REUSE QUERIES
-- ============================================================

-- Query 14: All vehicles using a given engine
SELECT
    "rowkey" as vin,
    "info"."make",
    "info"."model",
    "info"."year",
    "ids"."engine_id"
FROM "VEHICLE"
WHERE "ids"."engine_id" = 'ENG001'
ORDER BY "rowkey";

-- Query 15: All vehicles using a given transmission
SELECT
    "rowkey" as vin,
    "info"."make",
    "info"."model",
    "info"."year",
    "ids"."transmission_id"
FROM "VEHICLE"
WHERE "ids"."transmission_id" = 'TRN002'
ORDER BY "rowkey";

-- Query 16: All vehicles using a given chassis
SELECT
    "rowkey" as vin,
    "info"."make",
    "info"."model",
    "info"."year",
    "ids"."chassis_id"
FROM "VEHICLE"
WHERE "ids"."chassis_id" = 'CHS002'
ORDER BY "rowkey";

-- Query 17: Count vehicles per engine
SELECT
    "ids"."engine_id",
    COUNT(*) as vehicle_count
FROM "VEHICLE"
GROUP BY "ids"."engine_id"
ORDER BY "ids"."engine_id";

-- ============================================================
-- FILTER QUERIES (WITH TO_NUMBER)
-- ============================================================

-- Query 18: High-horsepower vehicles (300+ HP)
-- Note: Use TO_NUMBER() for VARCHAR to numeric conversion
SELECT
    v."rowkey" as vin,
    v."info"."make",
    v."info"."model",
    v."info"."year",
    e."specs"."horsepower",
    e."specs"."fuel_type"
FROM "VEHICLE" v
JOIN "ENGINE" e ON v."ids"."engine_id" = e."rowkey"
WHERE TO_NUMBER(e."specs"."horsepower") >= 300
ORDER BY TO_NUMBER(e."specs"."horsepower") DESC;

-- Query 19: Vehicles with AWD
SELECT
    v."rowkey" as vin,
    v."info"."make",
    v."info"."model",
    t."specs"."type",
    t."specs"."drive_type"
FROM "VEHICLE" v
JOIN "TRANSMISSION" t ON v."ids"."transmission_id" = t."rowkey"
WHERE t."specs"."drive_type" = 'AWD'
ORDER BY v."info"."make";

-- Query 20: Manual transmission vehicles
SELECT
    v."rowkey" as vin,
    v."info"."make",
    v."info"."model",
    v."info"."year",
    t."specs"."type",
    t."specs"."gears"
FROM "VEHICLE" v
JOIN "TRANSMISSION" t ON v."ids"."transmission_id" = t."rowkey"
WHERE t."specs"."type" = 'Manual'
ORDER BY v."rowkey";

-- Query 21: Coupe body style
SELECT
    v."rowkey" as vin,
    v."info"."make",
    v."info"."model",
    c."specs"."body_style",
    c."specs"."doors",
    c."specs"."material"
FROM "VEHICLE" v
JOIN "CHASSIS" c ON v."ids"."chassis_id" = c."rowkey"
WHERE c."specs"."body_style" = 'Coupe'
ORDER BY v."rowkey";

-- Query 22: Electric vehicles
SELECT
    v."rowkey" as vin,
    v."info"."make",
    v."info"."model",
    v."info"."year",
    e."specs"."horsepower",
    e."specs"."fuel_type"
FROM "VEHICLE" v
JOIN "ENGINE" e ON v."ids"."engine_id" = e."rowkey"
WHERE e."specs"."fuel_type" = 'Electric'
ORDER BY v."rowkey";

-- Query 23: Vehicles from 2023 or newer
SELECT
    v."rowkey" as vin,
    v."info"."make",
    v."info"."model",
    v."info"."year",
    e."specs"."horsepower",
    t."specs"."drive_type"
FROM "VEHICLE" v
JOIN "ENGINE" e ON v."ids"."engine_id" = e."rowkey"
JOIN "TRANSMISSION" t ON v."ids"."transmission_id" = t."rowkey"
WHERE TO_NUMBER(v."info"."year") >= 2023
ORDER BY TO_NUMBER(v."info"."year") DESC, v."info"."make";

-- Query 24: Lightweight chassis (under 4000 lb)
SELECT
    v."rowkey" as vin,
    v."info"."make",
    v."info"."model",
    c."specs"."body_style",
    c."specs"."curb_weight_lb"
FROM "VEHICLE" v
JOIN "CHASSIS" c ON v."ids"."chassis_id" = c."rowkey"
WHERE TO_NUMBER(c."specs"."curb_weight_lb") < 4000
ORDER BY TO_NUMBER(c."specs"."curb_weight_lb") ASC;

-- ============================================================
-- AGGREGATION QUERIES
-- ============================================================

-- Query 25: Count vehicles per make
SELECT
    "info"."make",
    COUNT(*) as vehicle_count
FROM "VEHICLE"
GROUP BY "info"."make"
ORDER BY "info"."make";

-- Query 26: Count vehicles per transmission type
SELECT
    t."specs"."type" as transmission_type,
    COUNT(*) as vehicle_count
FROM "VEHICLE" v
JOIN "TRANSMISSION" t ON v."ids"."transmission_id" = t."rowkey"
GROUP BY t."specs"."type"
ORDER BY t."specs"."type";

-- Query 27: Count vehicles per body style
SELECT
    c."specs"."body_style",
    COUNT(*) as vehicle_count
FROM "VEHICLE" v
JOIN "CHASSIS" c ON v."ids"."chassis_id" = c."rowkey"
GROUP BY c."specs"."body_style"
ORDER BY c."specs"."body_style";

-- Query 28: Average horsepower by make
SELECT
    v."info"."make",
    AVG(TO_NUMBER(e."specs"."horsepower")) as avg_horsepower,
    COUNT(*) as vehicle_count
FROM "VEHICLE" v
JOIN "ENGINE" e ON v."ids"."engine_id" = e."rowkey"
GROUP BY v."info"."make"
ORDER BY AVG(TO_NUMBER(e."specs"."horsepower")) DESC;

-- Query 29: Vehicles per fuel type
SELECT
    e."specs"."fuel_type",
    COUNT(*) as vehicle_count
FROM "VEHICLE" v
JOIN "ENGINE" e ON v."ids"."engine_id" = e."rowkey"
GROUP BY e."specs"."fuel_type"
ORDER BY e."specs"."fuel_type";

-- ============================================================
-- DASHBOARD / COMPLEX QUERIES
-- ============================================================

-- Query 30: Vehicle dashboard - complete specs summary
SELECT
    v."rowkey" as vin,
    v."info"."make",
    v."info"."model",
    v."info"."year",
    v."info"."color",
    v."info"."trim",
    e."rowkey" as engine_id,
    e."specs"."horsepower",
    e."specs"."fuel_type",
    t."rowkey" as transmission_id,
    t."specs"."type" as transmission_type,
    t."specs"."drive_type",
    c."rowkey" as chassis_id,
    c."specs"."body_style",
    c."specs"."curb_weight_lb"
FROM "VEHICLE" v
JOIN "ENGINE" e ON v."ids"."engine_id" = e."rowkey"
JOIN "TRANSMISSION" t ON v."ids"."transmission_id" = t."rowkey"
JOIN "CHASSIS" c ON v."ids"."chassis_id" = c."rowkey"
ORDER BY v."info"."make", v."info"."model";

-- Query 31: Performance vehicles (300+ HP, coupe or hatchback)
SELECT
    v."rowkey" as vin,
    v."info"."make",
    v."info"."model",
    e."specs"."horsepower",
    t."specs"."type",
    c."specs"."body_style"
FROM "VEHICLE" v
JOIN "ENGINE" e ON v."ids"."engine_id" = e."rowkey"
JOIN "TRANSMISSION" t ON v."ids"."transmission_id" = t."rowkey"
JOIN "CHASSIS" c ON v."ids"."chassis_id" = c."rowkey"
WHERE TO_NUMBER(e."specs"."horsepower") >= 300
  AND (c."specs"."body_style" = 'Coupe' OR c."specs"."body_style" = 'Hatchback')
ORDER BY TO_NUMBER(e."specs"."horsepower") DESC;

-- Query 32: Find vehicles sharing the same engine and transmission combo
SELECT
    "ids"."engine_id",
    "ids"."transmission_id",
    COUNT(*) as vehicle_count
FROM "VEHICLE"
GROUP BY "ids"."engine_id", "ids"."transmission_id"
ORDER BY "ids"."engine_id", "ids"."transmission_id";
