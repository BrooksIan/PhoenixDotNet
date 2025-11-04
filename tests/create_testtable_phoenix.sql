-- Phoenix SQL script to create testtable
-- This creates an HBase table through Phoenix Query Server

-- Drop table if exists (for testing - remove in production)
DROP TABLE IF EXISTS testtable;

-- Create testtable with Phoenix SQL
-- Phoenix automatically creates the underlying HBase table
CREATE TABLE testtable (
    id INTEGER NOT NULL,
    name VARCHAR(100),
    email VARCHAR(255),
    age INTEGER,
    created_date DATE,
    active BOOLEAN,
    CONSTRAINT pk_testtable PRIMARY KEY (id)
);

-- Create index on email column for faster lookups
CREATE INDEX idx_testtable_email ON testtable (email);

-- Insert sample test data
UPSERT INTO testtable (id, name, email, age, created_date, active) 
VALUES (1, 'John Doe', 'john.doe@example.com', 30, CURRENT_DATE(), true);

UPSERT INTO testtable (id, name, email, age, created_date, active) 
VALUES (2, 'Jane Smith', 'jane.smith@example.com', 25, CURRENT_DATE(), true);

UPSERT INTO testtable (id, name, email, age, created_date, active) 
VALUES (3, 'Bob Johnson', 'bob.johnson@example.com', 35, CURRENT_DATE(), false);

UPSERT INTO testtable (id, name, email, age, created_date, active) 
VALUES (4, 'Alice Williams', 'alice.williams@example.com', 28, CURRENT_DATE(), true);

-- Query to verify table and data
SELECT * FROM testtable ORDER BY id;

-- Count records
SELECT COUNT(*) as total_records FROM testtable;

