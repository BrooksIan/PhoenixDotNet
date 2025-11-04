-- Phoenix Views for testtable
-- Views provide read-only query interfaces to underlying tables
-- Views are useful for:
-- 1. Simplifying complex queries
-- 2. Providing security by limiting column access
-- 3. Creating logical data structures for applications
-- 4. Abstracting underlying table structure

-- Drop views if they exist (for testing - remove in production)
DROP VIEW IF EXISTS active_users_view;
DROP VIEW IF EXISTS user_summary_view;
DROP VIEW IF EXISTS user_details_view;

-- View 1: Active Users View
-- Shows only active users with essential information
-- This view filters out inactive users and provides a clean interface
CREATE VIEW active_users_view AS
SELECT 
    id,
    name,
    email,
    age,
    created_date
FROM testtable
WHERE active = true;

-- View 2: User Summary View
-- Provides a comprehensive view with calculated age group
-- Useful for reporting and analytics
CREATE VIEW user_summary_view AS
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

-- View 3: User Details View with Status
-- Shows all users with a calculated status field
CREATE VIEW user_details_view AS
SELECT 
    id,
    name,
    email,
    age,
    created_date,
    active,
    CASE 
        WHEN active = true THEN 'Active User'
        ELSE 'Inactive User'
    END AS status
FROM testtable;

-- View 4: User Statistics View
-- Provides aggregated statistics
CREATE VIEW user_statistics_view AS
SELECT 
    COUNT(*) AS total_users,
    SUM(CASE WHEN active = true THEN 1 ELSE 0 END) AS active_users,
    SUM(CASE WHEN active = false THEN 1 ELSE 0 END) AS inactive_users,
    AVG(age) AS average_age,
    MIN(age) AS min_age,
    MAX(age) AS max_age
FROM testtable;

-- Query examples for views:
-- SELECT * FROM active_users_view ORDER BY name;
-- SELECT * FROM user_summary_view WHERE age_group = 'Young';
-- SELECT * FROM user_details_view;
-- SELECT * FROM user_statistics_view;

