# New App Upload Checklist - org.shields.apps.nook

## Before Upload
- [ ] Created PKCS12 keystore successfully
- [ ] Configured android/key.properties with correct paths and passwords
- [ ] Copied assets to assets/images/ directory
- [ ] App builds successfully locally (`flutter build apk --release`)
- [ ] App installs and runs correctly locally

## Google Play Console Setup
- [ ] Created new app in Google Play Console
- [ ] App name set to "Nook"
- [ ] Package name is "org.shields.apps.nook"
- [ ] Default language set to English

## Store Listing
- [ ] Short description added (80 chars max)
- [ ] Full description added (4000 chars max)
- [ ] App icon uploaded (512x512)
- [ ] Feature graphic uploaded (1024x500)
- [ ] Screenshots added (minimum 2)
- [ ] Category set to Games > Puzzle
- [ ] Content rating completed (should be "Everyone")

## Privacy & Legal
- [ ] Privacy policy hosted online
- [ ] Privacy policy URL added to store listing
- [ ] Pricing set to "Free"
- [ ] Target countries selected

## Release
- [ ] Built app bundle (`flutter build appbundle`)
- [ ] AAB file uploaded to Internal Testing
- [ ] Release notes added
- [ ] Test users added to internal testing track
- [ ] Submitted for review

## File Locations
- Keystore: `/home/daniel/upload-keystore.p12`
- Key properties: `/home/daniel/work/puzzgameFlutter/android/key.properties`
- App bundle: `/home/daniel/work/puzzgameFlutter/build/app/outputs/bundle/release/app-release.aab`
- Store descriptions: `/home/daniel/work/puzzgameFlutter/docs/play_store_*.txt`
