-- Phoenix SQL script to create USERS table
-- This creates an HBase table through Phoenix Query Server

-- Drop table if exists (for testing - remove in production)
DROP TABLE IF EXISTS users;

-- Create users table with Phoenix SQL
-- Phoenix automatically creates the underlying HBase table
CREATE TABLE users (
    id INTEGER NOT NULL,
    username VARCHAR(50),
    email VARCHAR(100),
    created_date DATE,
    CONSTRAINT pk_users PRIMARY KEY (id)
);

-- Create index on email column for faster lookups
CREATE INDEX idx_users_email ON users (email);

-- Insert sample test data
UPSERT INTO users (id, username, email, created_date) 
VALUES (1, 'john_doe', 'john@example.com', CURRENT_DATE());

UPSERT INTO users (id, username, email, created_date) 
VALUES (2, 'jane_smith', 'jane@example.com', CURRENT_DATE());

UPSERT INTO users (id, username, email, created_date) 
VALUES (3, 'bob_johnson', 'bob@example.com', CURRENT_DATE());

-- Query to verify table and data
SELECT * FROM users ORDER BY id;

-- Count records
SELECT COUNT(*) as total_records FROM users;

