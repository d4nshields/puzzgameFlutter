import java.io.FileInputStream
import java.util.Properties

plugins {
    id("com.android.application")
    id("kotlin-android")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
    id("com.google.gms.google-services")
}

// Load key.properties file if it exists
val keystorePropertiesFile = rootProject.file("key.properties")
val keystoreProperties = Properties()
if (keystorePropertiesFile.exists()) {
    keystoreProperties.load(FileInputStream(keystorePropertiesFile))
}

android {
    namespace = "com.tinkerplexlabs.puzzlenook"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = "28.1.13356709"

    sourceSets {
        getByName("main").java.srcDirs("src/main/kotlin")
    }

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_11
        targetCompatibility = JavaVersion.VERSION_11
    }

    kotlinOptions {
        jvmTarget = JavaVersion.VERSION_11.toString()
    }

    defaultConfig {
        applicationId = "com.tinkerplexlabs.puzzlenook"
        minSdk = flutter.minSdkVersion
        targetSdk = flutter.targetSdkVersion
        versionCode = 7261038
        versionName = "0.6.1"
    }

    signingConfigs {
        // Release signing config - used for Play Store uploads (PKCS12 format)
        if (keystorePropertiesFile.exists()) {
            create("release") {
                keyAlias = keystoreProperties["keyAlias"] as String
                keyPassword = keystoreProperties["keyPassword"] as String
                storeFile = file(keystoreProperties["storeFile"] as String)
                storePassword = keystoreProperties["storePassword"] as String
            }
        }
    }

    buildTypes {
        getByName("debug") {
            signingConfig = signingConfigs.getByName("debug")
            isDebuggable = true
        }
        getByName("release") {
            // Use release signing config if it exists, otherwise use debug
            if (keystorePropertiesFile.exists()) {
                signingConfig = signingConfigs.getByName("release")
            } else {
                signingConfig = signingConfigs.getByName("debug")
            }
            
            // For now, disable minification to avoid R8 issues
            // This is fine for a simple app like yours
            isMinifyEnabled = false
            isShrinkResources = false
            
            // If you want to enable minification later, uncomment these:
            // isMinifyEnabled = true
            // isShrinkResources = true
            // proguardFiles(
            //     getDefaultProguardFile("proguard-android-optimize.txt"), 
            //     "proguard-rules.pro",
            //     "missing_rules.pro"
            // )
        }
    }
}

dependencies {
    // Import the Firebase BoM
    implementation(platform("com.google.firebase:firebase-bom:33.16.0"))
    
    // Firebase Analytics (required for Google services to work properly)
    implementation("com.google.firebase:firebase-analytics")
    
    // Google Play Services Auth (for Google Sign-In)
    implementation("com.google.android.gms:play-services-auth:21.0.0")
}

flutter {
    source = "../.."
}
