-- Security Migration for Feature Flag System
-- This script adds Row Level Security (RLS) and fixes security issues

-- Step 1: Enable RLS on all feature flag tables
ALTER TABLE products ENABLE ROW LEVEL SECURITY;
ALTER TABLE environments ENABLE ROW LEVEL SECURITY;
ALTER TABLE feature_flags ENABLE ROW LEVEL SECURITY;
ALTER TABLE environment_flag_overrides ENABLE ROW LEVEL SECURITY;
ALTER TABLE user_flag_overrides ENABLE ROW LEVEL SECURITY;

-- Step 2: Create RLS policies
-- Products table - readable by all, writable by none (admin only via dashboard)
CREATE POLICY "Products are viewable by everyone" 
    ON products FOR SELECT 
    USING (true);

-- Environments table - readable by all, writable by none
CREATE POLICY "Environments are viewable by everyone" 
    ON environments FOR SELECT 
    USING (true);

-- Feature flags table - readable by all, writable by none
CREATE POLICY "Feature flags are viewable by everyone" 
    ON feature_flags FOR SELECT 
    USING (true);

-- Environment flag overrides - readable by all, writable by none
CREATE POLICY "Environment overrides are viewable by everyone" 
    ON environment_flag_overrides FOR SELECT 
    USING (true);

-- User flag overrides - users can see their own, admins can see all
CREATE POLICY "Users can view their own overrides" 
    ON user_flag_overrides FOR SELECT 
    USING (
        auth.uid() = user_id 
        OR 
        auth.jwt() ->> 'role' = 'service_role'
    );

-- Step 3: Fix the view security issue (remove SECURITY DEFINER if it exists)
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

-- Step 4: Fix function search path for security
CREATE OR REPLACE FUNCTION get_feature_flags(
    p_product_key TEXT,
    p_environment TEXT,
    p_user_id UUID DEFAULT NULL
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
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

-- Step 5: Drop the upsert function if it exists (we'll manage via dashboard)
DROP FUNCTION IF EXISTS upsert_feature_flags;

-- Step 6: Verify security is enabled
SELECT 
    schemaname,
    tablename,
    rowsecurity
FROM pg_tables
WHERE schemaname = 'public' 
AND tablename IN ('products', 'environments', 'feature_flags', 'environment_flag_overrides', 'user_flag_overrides')
ORDER BY tablename;
