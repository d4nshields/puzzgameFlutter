-- Enable magnetic gestures and related features in development
UPDATE environment_flag_overrides 
SET value = 'true'::jsonb, enabled = true
WHERE feature_flag_id IN (
  SELECT id FROM feature_flags 
  WHERE name IN ('magnetic_gestures', 'enhanced_feedback', 'smooth_animations')
)
AND environment_id = (SELECT id FROM environments WHERE name = 'development');

-- Also ensure sample_puzzle is enabled so we can test
UPDATE environment_flag_overrides 
SET value = 'true'::jsonb, enabled = true
WHERE feature_flag_id = (SELECT id FROM feature_flags WHERE name = 'sample_puzzle')
AND environment_id = (SELECT id FROM environments WHERE name = 'development');

-- Verify all flags
SELECT 
  ff.name as flag_name,
  ff.description,
  e.name as environment,
  efo.value as override_value,
  efo.enabled as is_enabled
FROM feature_flags ff
CROSS JOIN environments e
LEFT JOIN environment_flag_overrides efo 
  ON ff.id = efo.feature_flag_id 
  AND e.id = efo.environment_id
WHERE e.name = 'development'
ORDER BY ff.name;
