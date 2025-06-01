# Updated GitHub Actions Workflow for Multi-Track Deployment

## Enhanced deployment workflow that supports multiple Google Play tracks based on tag patterns and manual selection.

### Key Features:
- **Tag-based automatic track selection**
- **Manual override capability**
- **Flexible naming conventions**
- **Production safety checks**

---

## Proposed Workflow Updates

### 1. Enhanced Track Detection

```yaml
- name: Determine deployment track
  id: track
  run: |
    # Default to internal
    TRACK="internal"
    
    # Check manual input first (highest priority)
    if [ "${{ github.event.inputs.track }}" != "" ]; then
      TRACK="${{ github.event.inputs.track }}"
      echo "Using manual track selection: $TRACK"
    # Check tag pattern for automatic selection
    elif [ "${{ github.event_name }}" = "release" ]; then
      TAG_NAME="${{ github.event.release.tag_name }}"
      echo "Analyzing tag: $TAG_NAME"
      
      if [[ $TAG_NAME =~ ^v[0-9]+\.[0-9]+\.[0-9]+-alpha(\.[0-9]+)?$ ]]; then
        TRACK="alpha"
        echo "Alpha release detected"
      elif [[ $TAG_NAME =~ ^v[0-9]+\.[0-9]+\.[0-9]+-beta(\.[0-9]+)?$ ]]; then
        TRACK="beta"
        echo "Beta release detected (closed testing)"
      elif [[ $TAG_NAME =~ ^v[0-9]+\.[0-9]+\.[0-9]+-rc(\.[0-9]+)?$ ]]; then
        TRACK="beta"
        echo "Release candidate detected (deploying to beta)"
      elif [[ $TAG_NAME =~ ^v[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
        TRACK="production"
        echo "Production release detected"
      else
        TRACK="internal"
        echo "Unknown tag pattern, defaulting to internal"
      fi
    else
      echo "Manual trigger without track specified, using internal"
    fi
    
    echo "TRACK=$TRACK" >> $GITHUB_OUTPUT
    echo "🚀 Deploying to track: $TRACK"

- name: Production release confirmation
  if: steps.track.outputs.TRACK == 'production'
  run: |
    echo "⚠️  PRODUCTION RELEASE DETECTED"
    echo "This will deploy to the production track on Google Play Store"
    echo "Tag: ${{ github.event.release.tag_name }}"
    echo "Proceeding with production deployment..."
```

### 2. Updated Upload Step

```yaml
- name: Upload to Play Store
  uses: r0adkll/upload-google-play@v1
  with:
    serviceAccountJsonPlainText: ${{ secrets.GOOGLE_PLAY_SERVICE_ACCOUNT_JSON }}
    packageName: com.tinkerplexlabs.puzzlebazaar
    releaseFiles: build/app/outputs/bundle/release/app-release.aab
    track: ${{ steps.track.outputs.TRACK }}
    status: completed
    inAppUpdatePriority: 2
    whatsNewDirectory: distribution/whatsnew
    releaseName: ${{ steps.version.outputs.VERSION_NAME }}
```

---

## Google Play Store Track Mapping

### **Internal Track** (Always available)
- **Purpose**: Internal team testing
- **Audience**: Up to 100 internal testers
- **Review**: No review required
- **Tags**: `v1.0.0-internal`, any unmatched pattern, or manual trigger

### **Alpha Track** (Closed Testing)
- **Purpose**: Early alpha testing with limited audience
- **Audience**: Specific testers you invite (up to 100)
- **Review**: No review required for updates
- **Tags**: `v1.0.0-alpha.1`, `v1.2.3-alpha`, etc.

### **Beta Track** (Closed Testing)
- **Purpose**: Beta testing, release candidates
- **Audience**: Larger group of testers (up to 100,000)
- **Review**: No review required for updates
- **Tags**: `v1.0.0-beta.1`, `v1.0.0-rc.1`, etc.

### **Production Track** (Open Testing → Production)
- **Purpose**: Public releases
- **Audience**: All users
- **Review**: Full Google Play review required
- **Tags**: `v1.0.0` (clean version tags only)

---

## Usage Examples

### **Development Workflow**

```bash
# Internal testing (immediate)
git tag v1.0.0-internal
git push origin v1.0.0-internal

# Alpha testing (immediate)
git tag v1.0.0-alpha.1
git push origin v1.0.0-alpha.1

# Beta testing (immediate)
git tag v1.0.0-beta.1
git push origin v1.0.0-beta.1

# Release candidate (goes to beta track)
git tag v1.0.0-rc.1
git push origin v1.0.0-rc.1

# Production release (requires Google review)
git tag v1.0.0
git push origin v1.0.0
```

### **Manual Override**
You can always override the automatic selection:
1. Go to GitHub Actions
2. Click "Run workflow"
3. Select desired track manually
4. Trigger deployment

---

## Enhanced Workflow Features

### **1. Multiple Release Channels**
```yaml
# This supports all Google Play tracks:
# - internal (100 testers, no review)
# - alpha (100 testers, no review) 
# - beta (100k testers, no review)
# - production (everyone, requires review)
```

### **2. Safety Checks**
```yaml
# Production deployments show clear warnings
# Version validation ensures proper formatting
# Track validation prevents invalid deployments
```

### **3. Flexible Versioning**
```yaml
# Supports semantic versioning with pre-release identifiers:
# v1.0.0-alpha.1
# v1.0.0-beta.2  
# v1.0.0-rc.1
# v1.0.0
```

### **4. Release Notes Support**
```yaml
# Automatically uses release notes from:
# - GitHub release description
# - distribution/whatsnew/ directory
# - Manual input override
```

---

## Implementation Steps

### **Step 1: Update Your Workflow File**
Replace the track determination section in `.github/workflows/deploy.yml`

### **Step 2: Set Up Release Note Structure**
Create `distribution/whatsnew/` directories:
```
distribution/
└── whatsnew/
    ├── whatsnew-en-US
    ├── whatsnew-de-DE  (optional)
    └── whatsnew-fr-FR  (optional)
```

### **Step 3: Test the Flow**
```bash
# Test internal deployment
git tag v0.1.11-internal
git push origin v0.1.11-internal

# Test alpha deployment  
git tag v0.1.11-alpha.1
git push origin v0.1.11-alpha.1
```

---

## Advanced Configurations

### **Conditional Production Gates**
```yaml
# Only allow production from main branch
- name: Validate production deployment
  if: steps.track.outputs.TRACK == 'production'
  run: |
    if [ "${{ github.ref }}" != "refs/heads/main" ]; then
      echo "❌ Production releases only allowed from main branch"
      exit 1
    fi
```

### **Rollout Percentage Control**
```yaml
# Start with small rollout for production
- name: Upload to Play Store
  uses: r0adkll/upload-google-play@v1
  with:
    track: ${{ steps.track.outputs.TRACK }}
    userFraction: ${{ steps.track.outputs.TRACK == 'production' && '0.1' || '1.0' }}
    # 10% rollout for production, 100% for testing tracks
```

### **Slack/Discord Notifications**
```yaml
# Notify team of production deployments
- name: Notify team
  if: steps.track.outputs.TRACK == 'production'
  # Add your notification setup here
```

---

## Migration Plan

### **Phase 1: Enhanced Track Selection (Immediate)**
Update workflow with tag-based track detection

### **Phase 2: Release Notes Integration (Next)**
Set up whatsnew directories and automate release notes

### **Phase 3: Advanced Features (Future)**
Add rollout controls, notifications, and advanced gates

---

*This setup gives you the flexibility to deploy to any Google Play track while maintaining safety and automation.*
