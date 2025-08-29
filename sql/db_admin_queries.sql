-- Feature Flag Admin Helper Queries
-- Save these for easy feature flag management

-- 1. View all flags and their current values for each environment
SELECT 
    p.name as product,
    ff.id,
    ff.name as flag,
    ff.default_value as default,
    MAX(CASE WHEN e.name = 'development' THEN efo.value END) as development,
    MAX(CASE WHEN e.name = 'qa' THEN efo.value END) as qa,
    MAX(CASE WHEN e.name = 'alpha' THEN efo.value END) as alpha,
    MAX(CASE WHEN e.name = 'production' THEN efo.value END) as production
FROM feature_flags ff
JOIN products p ON ff.product_id = p.id
LEFT JOIN environment_flag_overrides efo ON ff.id = efo.feature_flag_id
LEFT JOIN environments e ON efo.environment_id = e.id
WHERE p.name = 'puzzle_nook'
GROUP BY p.name, ff.id, ff.name, ff.default_value
ORDER BY ff.id;

-- 2. Quick toggle for sample_puzzle in development
UPDATE environment_flag_overrides 
SET value = 'true'::jsonb  -- Change to 'false'::jsonb to disable
WHERE feature_flag_id = (SELECT id FROM feature_flags WHERE name = 'sample_puzzle')
AND environment_id = (SELECT id FROM environments WHERE name = 'development');

-- 3. Test what each environment would get
SELECT 'Development:' as env, get_feature_flags('puzzle_nook', 'development', NULL)
UNION ALL
SELECT 'QA:', get_feature_flags('puzzle_nook', 'qa', NULL)
UNION ALL
SELECT 'Alpha:', get_feature_flags('puzzle_nook', 'alpha', NULL)
UNION ALL
SELECT 'Production:', get_feature_flags('puzzle_nook', 'production', NULL);

-- 4. Add a new feature flag
INSERT INTO feature_flags (product_id, name, description, default_value)
VALUES (
    (SELECT id FROM products WHERE name = 'puzzle_nook'),
    'new_feature_name',
    'Description of the feature',
    'false'::jsonb
);

-- 5. Set override for specific environment (using IDs is much simpler now!)
INSERT INTO environment_flag_overrides (feature_flag_id, environment_id, enabled, value)
VALUES (1, 1, true, 'true'::jsonb)  -- Flag ID 1, Environment ID 1
ON CONFLICT (feature_flag_id, environment_id) 
DO UPDATE SET value = EXCLUDED.value;

-- 6. Quick reference: List all IDs
SELECT 'Products:' as type, id, name FROM products
UNION ALL
SELECT 'Environments:', id, name FROM environments
UNION ALL
SELECT 'Flags:', id, name FROM feature_flags ORDER BY type, id;
