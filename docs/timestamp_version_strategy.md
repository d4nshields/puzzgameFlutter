# Version Code Strategy: Timestamp-Based with Year Offset

## Overview 📊

Both manual deployments (via `increment_version.sh`) and automated deployments (via GitHub Actions) now use **timestamp-based version codes** in `YYMMDDHHMM` format with 2025 as "year zero".

## How It Works 🕐

### Format: `YYMMDDHHMM`
- **YY**: Years since 2025 (2025=00, 2026=01, 2027=02, etc.)
- **MM**: Month (01-12)
- **DD**: Day (01-31) 
- **HH**: Hour (00-23)
- **MM**: Minute (00-59)

### Examples:
- **2025-07-26 12:34** = `0007261234` (Year 0 + July 26, 12:34)
- **2026-01-01 00:01** = `0101010001` (Year 1 + January 1, 00:01)
- **2030-12-31 23:59** = `0512312359` (Year 5 + December 31, 23:59)

## Benefits ✅

1. **Always Increasing**: Even across year boundaries
2. **No Conflicts**: Manual and automated deployments can't collide
3. **No State Management**: No need to track "last version code"
4. **Multi-Project Friendly**: Same strategy works across all projects
5. **Google Play Compatible**: Max value ~9,912,312,359 (well under 2.1B limit)
6. **Readable**: You can see exactly when a build was made
7. **99-Year Runway**: Works until 2124 (plenty of time!)

## Usage 🚀

### Manual Deployment
```bash
./increment_version.sh patch  # or major, minor
# Generates version code like: 0007261234 (2025-07-26 12:34)
```

### GitHub Actions
- Automatically uses timestamp when deploying releases
- Uses UTC timezone for consistency
- Example: `0007261534` (2025-07-26 15:34 UTC)

### No Coordination Needed!
- ✅ No need to check "last version code"
- ✅ No need to reserve ranges
- ✅ No conflicts between deployment methods
- ✅ Works across multiple projects

## Edge Cases Handled 🛡️

### Multiple Deployments Same Minute
- **Rare**: Would need 2+ deployments in same minute
- **Impact**: Second deployment would fail (version code conflict)
- **Solution**: Wait 1 minute and retry

### Year Rollover ✅ SOLVED
- **Perfect**: 2026-01-01 (`0101010001`) > 2025-12-31 (`0012312359`)
- **Always Increasing**: Year offset ensures proper ordering
- **Long Term**: Works until 2124 (99 years of runway)

### Leading Zeros
- **Handled**: `$((10#$TIMESTAMP))` removes leading zeros
- **Example**: `01011234` becomes `1011234` (valid integer)

## Comparison with Other Strategies 📈

| Strategy | Complexity | Conflicts | Limits | Multi-Project | Year-Safe |
|----------|------------|-----------|--------|--------------|----------|
| **Timestamp+Offset** | ✅ Simple | ✅ None | ✅ ~9.9B max | ✅ Perfect | ✅ 99 years |
| Incremental | ❌ Complex | ❌ Possible | ✅ 2.1B max | ❌ Per-project | ✅ Yes |
| Run Number | ❌ Medium | ❌ Possible | ✅ 2.1B max | ❌ CI-only | ✅ Yes |

## Migration Notes 📝

- **Existing version codes**: Previous codes (like 531) will work fine
- **First timestamp**: Will be much higher (e.g., 0007261234 vs 531)
- **Google Play**: Accepts the jump since new code > old code
- **No data loss**: All existing releases remain valid

This strategy provides the perfect balance of simplicity, reliability, year-safety, and scalability across multiple projects for decades to come! 🎆
