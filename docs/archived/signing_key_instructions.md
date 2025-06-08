# Creating a Signing Key for Release

To publish your app to the Google Play Store, you need to create a signing key. This key is used to authenticate your app updates, so it's important to keep it secure and remember the passwords.

## 1. Generate a keystore

Run the following command to generate a new keystore:

```bash
keytool -genkey -v -keystore ~/nook-keystore.jks -keyalg RSA -keysize 2048 -validity 10000 -alias nook
```

When prompted:
- Enter a secure password for the keystore
- Provide your name, organization, and location information
- Enter a secure password for the key (you can use the same as the keystore password)

## 2. Create a key.properties file

Create a file at `android/key.properties` with the following content (replace with your actual paths and passwords):

```
storePassword=your-keystore-password
keyPassword=your-key-password
keyAlias=nook
storeFile=/path/to/your/nook-keystore.jks
```

## 3. Update build.gradle.kts to use the signing configuration

Edit `android/app/build.gradle.kts` to use your signing configuration:

```kotlin
// Add at the top, before the android block
val keystoreProperties = java.util.Properties()
val keystorePropertiesFile = rootProject.file("key.properties")
if (keystorePropertiesFile.exists()) {
    keystoreProperties.load(java.io.FileInputStream(keystorePropertiesFile))
}

android {
    // ... existing configurations

    signingConfigs {
        create("release") {
            keyAlias = keystoreProperties["keyAlias"] as String
            keyPassword = keystoreProperties["keyPassword"] as String
            storeFile = file(keystoreProperties["storeFile"] as String)
            storePassword = keystoreProperties["storePassword"] as String
        }
    }

    buildTypes {
        getByName("release") {
            signingConfig = signingConfigs.getByName("release")
        }
    }
}
```

## 4. Add key.properties to .gitignore

Add the following line to your .gitignore file to avoid committing sensitive information:

```
**/android/key.properties
```

## IMPORTANT WARNINGS:
- NEVER share your keystore or passwords
- KEEP BACKUP COPIES of your keystore file in a secure location
- REMEMBER your passwords - if you lose them, you won't be able to update your app

If you lose your signing key, you'll have to publish a new app with a different package name on the Play Store.
