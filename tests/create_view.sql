-- Create Phoenix views for testtable
-- Views provide a read-only query interface to the underlying table

-- View 1: Active Users View
-- Shows only active users from testtable
CREATE VIEW IF NOT EXISTS active_users_view AS
SELECT 
    id,
    name,
    email,
    age,
    created_date
FROM testtable
WHERE active = true;

-- View 2: User Summary View
-- Provides a simplified view with calculated fields
CREATE VIEW IF NOT EXISTS user_summary_view AS
SELECT 
    id,
    name,
    email,
    age,
    created_date,
    active,
    CASE 
        WHEN age < 30 THEN 'Young'
        WHEN age >= 30 AND age < 50 THEN 'Middle-aged'
        ELSE 'Senior'
    END AS age_group
FROM testtable;

-- View 3: User Details View
-- Comprehensive view with all columns
CREATE VIEW IF NOT EXISTS user_details_view AS
SELECT 
    id,
    name,
    email,
    age,
    created_date,
    active,
    'Active User' AS status
FROM testtable
WHERE active = true

UNION ALL

SELECT 
    id,
    name,
    email,
    age,
    created_date,
    active,
    'Inactive User' AS status
FROM testtable
WHERE active = false;

