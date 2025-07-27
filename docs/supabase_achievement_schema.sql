-- Achievement and Sharing Tracking Database Schema
-- This should be run in your Supabase SQL editor

-- Create user_events table for tracking all user actions
CREATE TABLE IF NOT EXISTS user_events (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID REFERENCES auth.users(id) ON DELETE CASCADE,
    event_type TEXT NOT NULL,
    timestamp TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    event_data JSONB DEFAULT '{}',
    device_id TEXT,
    session_id TEXT,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- Create user_achievements table for tracking user achievement progress
CREATE TABLE IF NOT EXISTS user_achievements (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
    achievement_id TEXT NOT NULL,
    achievement_type TEXT NOT NULL,
    name TEXT NOT NULL,
    description TEXT NOT NULL,
    icon_emoji TEXT NOT NULL,
    rarity TEXT NOT NULL DEFAULT 'common',
    points_value INTEGER NOT NULL DEFAULT 0,
    progress_current INTEGER NOT NULL DEFAULT 0,
    progress_required INTEGER NOT NULL DEFAULT 1,
    requirements JSONB DEFAULT '{}',
    is_hidden BOOLEAN DEFAULT FALSE,
    unlocked_at TIMESTAMP WITH TIME ZONE,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    
    -- Ensure each user can only have one instance of each achievement
    UNIQUE(user_id, achievement_type)
);

-- Create indexes for better query performance
CREATE INDEX IF NOT EXISTS idx_user_events_user_id ON user_events(user_id);
CREATE INDEX IF NOT EXISTS idx_user_events_event_type ON user_events(event_type);
CREATE INDEX IF NOT EXISTS idx_user_events_timestamp ON user_events(timestamp);
CREATE INDEX IF NOT EXISTS idx_user_events_user_event_type ON user_events(user_id, event_type);

CREATE INDEX IF NOT EXISTS idx_user_achievements_user_id ON user_achievements(user_id);
CREATE INDEX IF NOT EXISTS idx_user_achievements_type ON user_achievements(achievement_type);
CREATE INDEX IF NOT EXISTS idx_user_achievements_unlocked ON user_achievements(unlocked_at) WHERE unlocked_at IS NOT NULL;
CREATE INDEX IF NOT EXISTS idx_user_achievements_user_unlocked ON user_achievements(user_id, unlocked_at) WHERE unlocked_at IS NOT NULL;

-- Enable Row Level Security
ALTER TABLE user_events ENABLE ROW LEVEL SECURITY;
ALTER TABLE user_achievements ENABLE ROW LEVEL SECURITY;

-- RLS Policies for user_events
CREATE POLICY "Users can view their own events" ON user_events
    FOR SELECT USING (auth.uid() = user_id);

CREATE POLICY "Users can insert their own events" ON user_events
    FOR INSERT WITH CHECK (auth.uid() = user_id);

-- Allow anonymous events for tracking (e.g., share visits before registration)
CREATE POLICY "Allow anonymous event insertion" ON user_events
    FOR INSERT WITH CHECK (user_id IS NULL);

-- RLS Policies for user_achievements
CREATE POLICY "Users can view their own achievements" ON user_achievements
    FOR SELECT USING (auth.uid() = user_id);

CREATE POLICY "Users can update their own achievements" ON user_achievements
    FOR UPDATE USING (auth.uid() = user_id);

CREATE POLICY "Allow achievement initialization" ON user_achievements
    FOR INSERT WITH CHECK (auth.uid() = user_id);

-- Create a function to automatically update the updated_at timestamp
CREATE OR REPLACE FUNCTION update_updated_at_column()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = NOW();
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Create trigger for user_achievements updated_at
CREATE TRIGGER update_user_achievements_updated_at
    BEFORE UPDATE ON user_achievements
    FOR EACH ROW
    EXECUTE FUNCTION update_updated_at_column();

-- Create a view for achievement statistics
CREATE OR REPLACE VIEW user_achievement_stats AS
SELECT 
    user_id,
    COUNT(*) as total_achievements,
    COUNT(*) FILTER (WHERE unlocked_at IS NOT NULL) as unlocked_count,
    SUM(points_value) FILTER (WHERE unlocked_at IS NOT NULL) as total_points,
    ROUND(
        (COUNT(*) FILTER (WHERE unlocked_at IS NOT NULL)::FLOAT / COUNT(*)) * 100, 
        2
    ) as completion_percentage
FROM user_achievements
GROUP BY user_id;

-- Grant necessary permissions
GRANT SELECT ON user_achievement_stats TO authenticated;
GRANT SELECT ON user_achievement_stats TO anon;
