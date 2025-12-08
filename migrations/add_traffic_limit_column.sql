-- Migration script to add traffic_limit column to admin_user table
-- This column stores the traffic limit in bytes (BIGINT)
-- NULL means unlimited traffic

-- For MySQL/MariaDB
ALTER TABLE admin_user 
ADD COLUMN IF NOT EXISTS traffic_limit BIGINT DEFAULT NULL 
COMMENT 'Maximum traffic limit for agent in bytes (NULL = unlimited)';

-- For SQLite (IF NOT EXISTS is not supported, so check first)
-- Note: SQLite doesn't support IF NOT EXISTS in ALTER TABLE
-- Use the Python migration script instead for SQLite

