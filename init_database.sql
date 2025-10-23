-- Database initialization script for ODBC Cloud SQL POC
-- This script creates the database and a sample table with test data

-- Create database (if it doesn't exist)
CREATE DATABASE IF NOT EXISTS odbc_poc_db
    CHARACTER SET utf8mb4
    COLLATE utf8mb4_unicode_ci;

USE odbc_poc_db;

-- Drop table if it exists (for clean setup)
DROP TABLE IF EXISTS databricks;

-- Create the databricks table
-- Adjust column definitions based on your actual sample data
CREATE TABLE databricks (
    id INT AUTO_INCREMENT PRIMARY KEY,
    name VARCHAR(255) NOT NULL,
    value VARCHAR(255),
    description TEXT,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    INDEX idx_name (name)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- Insert sample data
-- Replace these with your actual sample data
INSERT INTO databricks (name, value, description) VALUES
    ('sample_record_1', 'test_value_1', 'This is a test record for ODBC connectivity verification'),
    ('sample_record_2', 'test_value_2', 'Second test record to ensure multiple rows work'),
    ('sample_record_3', 'test_value_3', 'Third test record for comprehensive testing');

-- Verify data insertion
SELECT COUNT(*) as record_count FROM databricks;

-- Show sample of inserted data
SELECT * FROM databricks LIMIT 3;
