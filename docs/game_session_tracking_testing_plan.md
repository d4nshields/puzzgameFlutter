# Game Session Tracking - Testing Plan

## What Has Been Implemented

### 1. Core Service Architecture
- **GameSessionTrackingService** interface defining tracking contracts
- **SupabaseGameSessionTrackingService** implementation for database operations
- Integrated into the existing service locator pattern

### 2. Database Schema Extensions
- **Enhanced game_sessions table** with additional columns:
  - `difficulty` (INTEGER) - puzzle difficulty level
  - `puzzle_id` (TEXT) - identifier for the puzzle being played
  - `grid_size` (INTEGER) - puzzle grid dimensions
- **New app_usage table** for anonymous and authenticated usage tracking
- **game_analytics view** for easy querying of game statistics

### 3. Integration Points

#### Game Lifecycle Tracking
- **App Launch**: Tracked in `main.dart` with device and platform info
- **Game Start**: Recorded when `StartGameUseCase.execute()` is called
- **Game Progress**: Piece placement, pause/resume events tracked in `PuzzleGameSession`
- **Game Completion**: Completion events with timing and score tracking
- **Game End**: Final statistics recorded via `EndGameUseCase.execute()`

#### Data Captured
- Session-level: Score progression, piece placement accuracy, pause/resume events
- User-level: Total playtime, completed puzzles, high scores
- App-level: Launch events, device info, platform statistics
- Anonymous: Device-based tracking for non-authenticated users

## Expected Results

After implementing this system, you should see:

### In Supabase Dashboard
1. **app_usage table** with entries like:
   ```
   id: uuid
   user_id: your-user-id (or null for anonymous)
   action: "app_launch"
   timestamp: recent timestamp
   platform: "android" or "linux"
   usage_data: {"action": "app_launch", "platform": "flutter"}
   ```

2. **game_sessions table** with entries like:
   ```
   id: session-uuid
   user_id: your-user-id
   game: "puzzle_nook"
   puzzle_id: "sample_puzzle_01"
   grid_size: 12
   difficulty: 12
   started_at: session start time
   ended_at: session end time (when completed)
   session_data: {
     "puzzle_id": "sample_puzzle_01",
     "grid_size": 12,
     "total_pieces": 144,
     "pieces_placed": 144,
     "completed": true,
     "final_score": 450,
     "completion_percentage": 100,
     "last_piece_placed": {...},
     "game_progress": {...}
   }
   ```

3. **game_stats table** with aggregated data:
   ```
   user_id: your-user-id
   game: "puzzle_nook"
   total_playtime: 1200 (seconds)
   completed_puzzles: 1
   last_played: recent timestamp
   ```

### Immediate Verification
Run this query after playing a game:
```sql
SELECT 
  'App Usage' as table_name, COUNT(*) as record_count 
FROM app_usage 
WHERE created_at > NOW() - INTERVAL '1 hour'
UNION ALL
SELECT 
  'Game Sessions' as table_name, COUNT(*) as record_count 
FROM game_sessions 
WHERE started_at > NOW() - INTERVAL '1 hour'
UNION ALL
SELECT 
  'Game Stats' as table_name, COUNT(*) as record_count 
FROM game_stats 
WHERE last_played > NOW() - INTERVAL '1 hour';
```

You should see non-zero counts for all three tables.

## Validation Checklist

### Before Release
- [ ] App launches and records usage event
- [ ] Game sessions are created in database
- [ ] Piece placement events update session data
- [ ] Game completion triggers statistics updates
- [ ] Anonymous and authenticated users both work
- [ ] No game performance degradation
- [ ] Database queries are optimized
- [ ] Error handling works (game continues if tracking fails)
- [ ] Privacy settings are respected

### Database Verification
- [ ] `app_usage` table has records with proper device identification
- [ ] `game_sessions` table shows sessions with detailed JSON data
- [ ] `game_stats` table accumulates user statistics correctly
- [ ] New columns (difficulty, puzzle_id, grid_size) are populated
- [ ] RLS policies allow appropriate access
- [ ] Indexes are created for query performance

This implementation provides a solid foundation for understanding how users interact with your puzzle game while respecting privacy and maintaining performance.
