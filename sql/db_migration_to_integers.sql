-- Feature Flag System Migration: UUID to Integer IDs
-- Run this in your Supabase SQL editor for the tinkerplex project
-- Make sure to backup your data first!

-- Step 1: Drop existing RPC function (we'll recreate it)
DROP FUNCTION IF EXISTS get_feature_flags(text, text, uuid);
DROP FUNCTION IF EXISTS get_feature_flags(text, text, text);

-- Step 2: Drop existing tables (CASCADE will handle foreign keys)
DROP TABLE IF EXISTS user_flag_overrides CASCADE;
DROP TABLE IF EXISTS environment_flag_overrides CASCADE;
DROP TABLE IF EXISTS feature_flags CASCADE;
DROP TABLE IF EXISTS environments CASCADE;
DROP TABLE IF EXISTS products CASCADE;

-- Step 3: Create new tables with integer IDs
CREATE TABLE products (
    id SERIAL PRIMARY KEY,
    name VARCHAR(255) UNIQUE NOT NULL,
    description TEXT,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP
);

CREATE TABLE environments (
    id SERIAL PRIMARY KEY,
    name VARCHAR(100) UNIQUE NOT NULL,
    description TEXT,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP
);

CREATE TABLE feature_flags (
    id SERIAL PRIMARY KEY,
    product_id INTEGER NOT NULL REFERENCES products(id) ON DELETE CASCADE,
    name VARCHAR(255) NOT NULL,
    description TEXT,
    default_value JSONB NOT NULL DEFAULT 'false'::jsonb,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    UNIQUE(product_id, name)
);

CREATE TABLE environment_flag_overrides (
    id SERIAL PRIMARY KEY,
    feature_flag_id INTEGER NOT NULL REFERENCES feature_flags(id) ON DELETE CASCADE,
    environment_id INTEGER NOT NULL REFERENCES environments(id) ON DELETE CASCADE,
    enabled BOOLEAN NOT NULL DEFAULT true,
    value JSONB NOT NULL,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    UNIQUE(feature_flag_id, environment_id)
);

CREATE TABLE user_flag_overrides (
    id SERIAL PRIMARY KEY,
    feature_flag_id INTEGER NOT NULL REFERENCES feature_flags(id) ON DELETE CASCADE,
    user_id UUID NOT NULL,  -- Keep UUID for Supabase auth users
    enabled BOOLEAN NOT NULL DEFAULT true,
    value JSONB NOT NULL,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    UNIQUE(feature_flag_id, user_id)
);

-- Step 4: Create indexes for better performance
CREATE INDEX idx_feature_flags_product_id ON feature_flags(product_id);
CREATE INDEX idx_environment_overrides_flag_id ON environment_flag_overrides(feature_flag_id);
CREATE INDEX idx_environment_overrides_env_id ON environment_flag_overrides(environment_id);
CREATE INDEX idx_user_overrides_flag_id ON user_flag_overrides(feature_flag_id);
CREATE INDEX idx_user_overrides_user_id ON user_flag_overrides(user_id);

-- Step 5: Create updated RPC function
CREATE OR REPLACE FUNCTION get_feature_flags(
    p_product_key TEXT,
    p_environment TEXT,
    p_user_id UUID DEFAULT NULL
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    v_result JSONB := '{}'::jsonb;
    v_product_id INTEGER;
    v_environment_id INTEGER;
    flag_record RECORD;
BEGIN
    -- Get product ID
    SELECT id INTO v_product_id 
    FROM products 
    WHERE name = p_product_key;
    
    IF v_product_id IS NULL THEN
        RAISE EXCEPTION 'Product not found: %', p_product_key;
    END IF;
    
    -- Get environment ID
    SELECT id INTO v_environment_id 
    FROM environments 
    WHERE name = p_environment;
    
    -- Build the result for each flag
    FOR flag_record IN 
        SELECT 
            ff.name,
            ff.description,
            COALESCE(
                -- First priority: User override
                (SELECT value FROM user_flag_overrides 
                 WHERE feature_flag_id = ff.id 
                 AND user_id = p_user_id 
                 AND enabled = true),
                -- Second priority: Environment override
                (SELECT value FROM environment_flag_overrides 
                 WHERE feature_flag_id = ff.id 
                 AND environment_id = v_environment_id 
                 AND enabled = true),
                -- Default: Flag default value
                ff.default_value
            ) as value
        FROM feature_flags ff
        WHERE ff.product_id = v_product_id
    LOOP
        -- Extract the actual value if it's a simple boolean
        IF jsonb_typeof(flag_record.value) = 'boolean' THEN
            v_result := v_result || jsonb_build_object(flag_record.name, flag_record.value);
        ELSE
            -- For complex values, include the whole object
            v_result := v_result || jsonb_build_object(flag_record.name, flag_record.value);
        END IF;
    END LOOP;
    
    RETURN v_result;
END;
$$;

-- Step 6: Insert initial data
INSERT INTO products (name, description) VALUES 
    ('puzzle_nook', 'Puzzle Nook mobile game');

INSERT INTO environments (name, description) VALUES 
    ('development', 'Internal testing channel'),
    ('qa', 'Closed testing channel'),
    ('alpha', 'Open testing channel'),
    ('production', 'Production release');

-- Get the product ID for inserting flags
DO $$ 
DECLARE 
    v_product_id INTEGER;
BEGIN
    SELECT id INTO v_product_id FROM products WHERE name = 'puzzle_nook';
    
    -- Insert feature flags
    INSERT INTO feature_flags (product_id, name, description, default_value) VALUES 
        (v_product_id, 'sample_puzzle', 'Enable sample puzzle on app launch', 'false'::jsonb),
        (v_product_id, 'magnetic_gestures', 'Enable magnetic gesture recognition', 'false'::jsonb),
        (v_product_id, 'enhanced_feedback', 'Enable enhanced haptic and audio feedback', 'false'::jsonb),
        (v_product_id, 'smooth_animations', 'Enable smooth piece animations', 'false'::jsonb),
        (v_product_id, 'puzzle_library', 'Enable puzzle library feature', 'false'::jsonb),
        (v_product_id, 'achievements', 'Enable achievements system', 'false'::jsonb),
        (v_product_id, 'daily_challenges', 'Enable daily puzzle challenges', 'false'::jsonb),
        (v_product_id, 'social_features', 'Enable social features', 'false'::jsonb);
END $$;

-- Step 7: Set up environment overrides for development (internal testing)
INSERT INTO environment_flag_overrides (feature_flag_id, environment_id, enabled, value)
SELECT 
    ff.id,
    e.id,
    true,
    'true'::jsonb
FROM feature_flags ff
CROSS JOIN environments e
WHERE ff.name = 'sample_puzzle'
AND e.name = 'development';

-- Step 8: Grant permissions (adjust based on your needs)
GRANT SELECT ON ALL TABLES IN SCHEMA public TO anon;
GRANT SELECT ON ALL TABLES IN SCHEMA public TO authenticated;
GRANT EXECUTE ON FUNCTION get_feature_flags TO anon;
GRANT EXECUTE ON FUNCTION get_feature_flags TO authenticated;

-- Step 9: Create helper views for easier management
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

-- Verify the migration worked
SELECT 'Migration complete! Testing the function:' as status;
SELECT get_feature_flags('puzzle_nook', 'development', NULL);
