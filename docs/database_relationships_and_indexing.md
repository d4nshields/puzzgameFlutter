# Database Schema Relationships and Indexing Guide

## Date: July 26, 2025

## Problem Solved: Schema Visualizer Relationships

### Issue:
The Supabase schema visualizer wasn't showing relationship lines between `user_events` and other tables because:

1. **Missing Foreign Key Constraint** - `session_id` had no FK constraint to `game_sessions`
2. **Data Type Mismatch** - `session_id` was TEXT but `game_sessions.id` was UUID
3. **Missing Indexes** - No proper indexes for relationship columns

### Solution Applied:

```sql
-- ✅ Fixed data type mismatch
ALTER TABLE user_events 
ALTER COLUMN session_id TYPE UUID USING session_id::UUID;

-- ✅ Added foreign key constraint for session_id
ALTER TABLE user_events 
ADD CONSTRAINT user_events_session_id_fkey 
FOREIGN KEY (session_id) REFERENCES public.game_sessions(id) ON DELETE SET NULL;

-- ✅ Added performance indexes
CREATE INDEX idx_user_events_session_id ON user_events(session_id);
CREATE INDEX idx_user_events_user_session ON user_events(user_id, session_id);
CREATE INDEX idx_user_events_event_timestamp ON user_events(event_type, timestamp);
```

## Complete Schema Relationships

### 🔗 **Foreign Key Constraints (All Now Visible in Schema Visualizer)**

#### user_events table:
- `user_events.user_id` → `auth.users.id` (CASCADE DELETE)
- `user_events.session_id` → `public.game_sessions.id` (SET NULL on delete)

#### app_usage table: ✅ **FIXED**
- `app_usage.user_id` → `auth.users.id` (CASCADE DELETE) 
- `app_usage.session_id` → `public.game_sessions.id` (SET NULL on delete) ✅ **NEW**

#### Existing relationships (preserved):
- `public.users.id` → `auth.users.id`
- `public.game_sessions.user_id` → `public.users.id` 
- `public.game_stats.user_id` → `public.users.id`
- `public.user_achievements.user_id` → `public.users.id`
- `public.user_achievements.achievement_id` → `public.achievements.id`

## Complete Indexing Strategy

### **user_events table indexes:**
```sql
-- Primary key (automatic)
user_events_pkey ON (id)

-- Foreign key indexes (performance)
idx_user_events_user_id ON (user_id)
idx_user_events_session_id ON (session_id)

-- Query optimization indexes
idx_user_events_event_type ON (event_type)
idx_user_events_timestamp ON (timestamp)
idx_user_events_event_timestamp ON (event_type, timestamp)
idx_user_events_user_event_type ON (user_id, event_type)
idx_user_events_user_session ON (user_id, session_id)
```

### **app_usage table indexes:** ✅ **ADDED**
```sql
-- Primary key (automatic)
app_usage_pkey ON (id)

-- Foreign key indexes (performance)
idx_app_usage_user_id ON (user_id)
idx_app_usage_session_id ON (session_id) ✅ **NEW**

-- Query optimization indexes
idx_app_usage_action ON (action)
idx_app_usage_timestamp ON (timestamp)
idx_app_usage_action_timestamp ON (action, timestamp)
idx_app_usage_user_action ON (user_id, action)
idx_app_usage_user_session ON (user_id, session_id) ✅ **NEW**
```

### **user_achievements table indexes:**
```sql
-- Primary key (automatic)
user_achievements_pkey ON (user_id, achievement_id)

-- Foreign key indexes (performance) 
idx_user_achievements_user_id ON (user_id)
idx_user_achievements_type ON (achievement_type)
idx_user_achievements_unlocked ON (unlocked_at) WHERE unlocked_at IS NOT NULL
```

## Data Type Consistency

### **UUID Columns (Consistent):**
- `auth.users.id` → UUID
- `public.users.id` → UUID  
- `public.game_sessions.id` → UUID
- `user_events.id` → UUID
- `user_events.user_id` → UUID
- `user_events.session_id` → UUID ✅ **(Fixed)**
- `app_usage.id` → UUID
- `app_usage.user_id` → UUID
- `app_usage.session_id` → UUID ✅ **(Fixed)**

### **TEXT Columns:**
- `user_events.event_type` → TEXT
- `user_events.device_id` → TEXT
- `achievements.title` → TEXT
- `achievements.description` → TEXT

### **JSONB Columns:**
- `user_events.event_data` → JSONB
- `achievements.requirements` → JSONB
- `public.users.profile_data` → JSONB

## Schema Visualizer Results

### ✅ **Now Visible in Supabase Schema Visualizer:**

```
auth.users ─────┐
               ├─→ user_events.user_id
               ├─→ app_usage.user_id
public.users ───┘

game_sessions ────────────┐
                           ├─→ user_events.session_id
                           └─→ app_usage.session_id ✅ **NEW**

user_events ────→ [All relationships now render properly]
app_usage ──────→ [All relationships now render properly] ✅ **FIXED**
```

### **Relationship Types:**
- **One-to-Many**: `users` → `user_events` 
- **One-to-Many**: `game_sessions` → `user_events`
- **Many-to-Many**: `users` ↔ `achievements` (via `user_achievements`)

## Query Performance Benefits

### **Fast Lookups (O(log n) with indexes):**
```sql
-- ✅ Optimized: Get user's events
SELECT * FROM user_events WHERE user_id = $1;

-- ✅ Optimized: Get session events  
SELECT * FROM user_events WHERE session_id = $1;

-- ✅ Optimized: Get share events
SELECT * FROM user_events WHERE event_type = 'share';

-- ✅ Optimized: Get user shares
SELECT * FROM user_events WHERE user_id = $1 AND event_type = 'share';

-- ✅ Optimized: Get recent events
SELECT * FROM user_events WHERE timestamp > $1 ORDER BY timestamp DESC;
```

### **Analytics Queries (Optimized):**
```sql
-- Share counts by user (uses idx_user_events_user_event_type)
SELECT user_id, COUNT(*) 
FROM user_events 
WHERE event_type = 'share' 
GROUP BY user_id;

-- Daily share counts (uses idx_user_events_event_timestamp)
SELECT DATE(timestamp), COUNT(*) 
FROM user_events 
WHERE event_type = 'share' 
GROUP BY DATE(timestamp);

-- User session events (uses idx_user_events_user_session)
SELECT ue.*, gs.difficulty, gs.puzzle_id
FROM user_events ue
JOIN game_sessions gs ON ue.session_id = gs.id
WHERE ue.user_id = $1;
```

## Verification Commands

### **Check Foreign Key Constraints:**
```sql
SELECT 
    conname as constraint_name,
    confrelid::regclass as foreign_table,
    a.attname as local_column,
    af.attname as foreign_column
FROM pg_constraint c
JOIN pg_attribute a ON a.attnum = ANY(c.conkey) AND a.attrelid = c.conrelid
JOIN pg_attribute af ON af.attnum = ANY(c.confkey) AND af.attrelid = c.confrelid
WHERE c.conrelid = 'user_events'::regclass AND c.contype = 'f';
```

### **Check Indexes:**
```sql
SELECT indexname, indexdef
FROM pg_indexes 
WHERE tablename = 'user_events'
ORDER BY indexname;
```

### **Test Schema Visualizer:**
1. Go to Supabase Dashboard → Database → Schema Visualizer
2. Look for `user_events` table
3. Should see relationship lines to:
   - `auth.users` (via user_id)
   - `game_sessions` (via session_id)

## Benefits Achieved

### ✅ **Schema Visualizer:**
- All relationships now render properly
- Clear visual representation of data model
- Easy to understand table connections

### ✅ **Query Performance:**
- All foreign key columns indexed
- Composite indexes for common query patterns
- Analytics queries run efficiently

### ✅ **Data Integrity:**
- Foreign key constraints prevent orphaned records
- CASCADE/SET NULL policies handle deletions gracefully
- Type consistency across related columns

### ✅ **Developer Experience:**
- Clear relationship documentation
- Optimized for common access patterns
- Ready for complex analytics queries

The schema now properly shows all relationships in the Supabase visualizer and is optimized for both data integrity and query performance!
