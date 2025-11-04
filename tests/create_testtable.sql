-- Create testtable in Phoenix
-- This table will be created in HBase through Phoenix

CREATE TABLE IF NOT EXISTS testtable (
    id INTEGER PRIMARY KEY,
    name VARCHAR(100),
    email VARCHAR(255),
    age INTEGER,
    created_date DATE,
    active BOOLEAN
);

-- Create index for faster queries (optional)
CREATE INDEX IF NOT EXISTS idx_testtable_email ON testtable (email);

-- Insert sample data
UPSERT INTO testtable (id, name, email, age, created_date, active) 
VALUES (1, 'John Doe', 'john.doe@example.com', 30, CURRENT_DATE(), true);

UPSERT INTO testtable (id, name, email, age, created_date, active) 
VALUES (2, 'Jane Smith', 'jane.smith@example.com', 25, CURRENT_DATE(), true);

UPSERT INTO testtable (id, name, email, age, created_date, active) 
VALUES (3, 'Bob Johnson', 'bob.johnson@example.com', 35, CURRENT_DATE(), false);

-- Query to verify table creation
SELECT * FROM testtable;

