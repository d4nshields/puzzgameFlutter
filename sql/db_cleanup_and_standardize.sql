-- Cleanup and Standardization Script for Feature Flag System
-- This script removes old UUID-based tables and standardizes naming conventions

-- Step 1: Update product name to use underscore convention
UPDATE products SET name = 'puzzle_nook' WHERE name = 'Puzzle Nook';

-- Step 2: Standardize feature flag names to use underscore convention
UPDATE feature_flags SET name = 'debug_mode' WHERE name = 'Debug Mode';
UPDATE feature_flags SET name = 'sample_puzzle' WHERE name = 'Sample Puzzle';
UPDATE feature_flags SET name = 'new_hint_system' WHERE name = 'New Hint System';
UPDATE feature_flags SET name = 'enhanced_feedback' WHERE name = 'Enhanced Feedback';
UPDATE feature_flags SET name = 'magnetic_gestures' WHERE name = 'Magnetic Gestures';
UPDATE feature_flags SET name = 'smooth_animations' WHERE name = 'Smooth Animations';
UPDATE feature_flags SET name = 'performance_monitoring' WHERE name = 'Performance Monitoring';

-- Step 3: Drop the old UUID-based tables (they have _old suffix)
DROP TABLE IF EXISTS user_flag_overrides_old CASCADE;
DROP TABLE IF EXISTS environment_flag_overrides_old CASCADE;
DROP TABLE IF EXISTS feature_flags_old CASCADE;
DROP TABLE IF EXISTS environments_old CASCADE;
DROP TABLE IF EXISTS products_old CASCADE;
DROP TABLE IF EXISTS feature_flag_audit CASCADE;

-- Step 4: Create a view for easier feature flag management
DROP VIEW IF EXISTS feature_flag_status;
CREATE VIEW feature_flag_status AS
SELECT 
    p.name as product,
    ff.id as flag_id,
    ff.name as flag_name,
    ff.default_value,
    e.name as environment,
    efo.value as override_value,
    efo.enabled as override_active
FROM feature_flags ff
JOIN products p ON ff.product_id = p.id
LEFT JOIN environment_flag_overrides efo ON ff.id = efo.feature_flag_id
LEFT JOIN environments e ON efo.environment_id = e.id
ORDER BY p.name, ff.name, e.name;

-- Step 5: Verify the migration
SELECT 'Cleanup complete! Testing the function with standardized names:' as status;
SELECT get_feature_flags('puzzle_nook', 'development', NULL) as flags;

-- Step 6: Show current state
SELECT 'Current products:' as info;
SELECT * FROM products;

SELECT 'Current feature flags:' as info;
SELECT id, name, description, default_value FROM feature_flags ORDER BY name;

SELECT 'Current environment overrides:' as info;
SELECT 
    ff.name as flag_name,
    e.name as environment,
    efo.value,
    efo.enabled
FROM environment_flag_overrides efo
JOIN feature_flags ff ON efo.feature_flag_id = ff.id
JOIN environments e ON efo.environment_id = e.id
ORDER BY ff.name, e.name;
