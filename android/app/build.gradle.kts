import java.io.FileInputStream
import java.util.Properties

plugins {
    id("com.android.application")
    id("kotlin-android")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
    id("com.google.gms.google-services")
}

// Enhanced key.properties loading with keyring integration
fun loadKeystoreProperties(): Properties? {
    val keystorePropertiesFile = rootProject.file("key.properties")
    
    if (!keystorePropertiesFile.exists()) {
        println("⚠️  WARNING: key.properties file not found!")
        println("📁 Expected location: ${keystorePropertiesFile.absolutePath}")
        println("📋 To fix this:")
        println("   1. Run './setup_signing_keyring.sh' for keyring-based setup")
        println("   2. Or run './setup_signing.sh' for manual setup")
        println("   3. Or copy android/key.properties.template to android/key.properties")
        return null
    }
    
    // Check if this is a keyring-based configuration
    val fileContent = keystorePropertiesFile.readText()
    if (fileContent.contains("__FROM_KEYRING__") || fileContent.contains("__keyring_backend=")) {
        println("🔐 Detected keyring-based configuration, loading credentials...")
        
        // Execute the keyring loader script
        val loadScript = rootProject.file("load_keyring_credentials.sh")
        if (loadScript.exists()) {
            try {
                val isWindows = System.getProperty("os.name").lowercase().contains("windows")
                val shell = if (isWindows) listOf("cmd", "/c", "bash") else listOf("sh")
                val process = ProcessBuilder(shell + listOf(loadScript.absolutePath, keystorePropertiesFile.absolutePath))
                    .redirectOutput(ProcessBuilder.Redirect.INHERIT)
                    .redirectError(ProcessBuilder.Redirect.INHERIT)
                    .start()
                
                val exitCode = process.waitFor()
                if (exitCode != 0) {
                    println("❌ Failed to load credentials from keyring")
                    return null
                }
            } catch (e: Exception) {
                println("❌ Error loading keyring credentials: ${e.message}")
                return null
            }
        } else {
            println("❌ Keyring loader script not found: ${loadScript.absolutePath}")
            return null
        }
    }
    
    val properties = Properties().apply {
        FileInputStream(keystorePropertiesFile).use { fis -> load(fis) }
    }
    
    // Validate required properties
    val requiredKeys = listOf("storePassword", "keyPassword", "keyAlias", "storeFile")
    val missingKeys = requiredKeys.filter { properties.getProperty(it).isNullOrBlank() }
    
    if (missingKeys.isNotEmpty()) {
        println("❌ ERROR: key.properties is missing required values:")
        missingKeys.forEach { println("   - $it") }
        println("📋 Please run './setup_signing_keyring.sh' to reconfigure")
        return null
    }
    
    // Validate keystore file exists (with environment variable expansion)
    var storeFilePath = properties.getProperty("storeFile")
    
    // Expand ~ to home directory
    if (storeFilePath.startsWith("~")) {
        storeFilePath = storeFilePath.replaceFirst("~", System.getProperty("user.home"))
    }
    
    // Expand environment variables like ${VAR}
    storeFilePath = System.getenv().entries.fold(storeFilePath) { acc, entry -> 
        acc.replace("\${${entry.key}}", entry.value) 
    }
    
    val storeFile = file(storeFilePath)
    if (!storeFile.exists()) {
        println("❌ ERROR: Keystore file not found:")
        println("   Expected: ${storeFile.absolutePath}")
        println("📋 Please check the storeFile path in key.properties")
        return null
    }
    
    println("✅ Signing configuration loaded successfully")
    return properties
}

val keystoreProperties = loadKeystoreProperties()

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
        versionCode = 8061038
        versionName = "0.8.6"
    }

    signingConfigs {
        // Release signing config - loaded from keyring or direct properties
        if (keystoreProperties != null) {
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
            if (keystoreProperties != null) {
                signingConfig = signingConfigs.getByName("release")
                println("🔐 Using release signing configuration")
            } else {
                // FAIL THE BUILD for release without proper signing
                throw GradleException("""
                    ❌ RELEASE BUILD FAILED: No valid signing configuration!
                    
                    Release builds require a properly configured signing setup.
                    This prevents accidentally publishing debug-signed builds.
                    
                    To fix this:
                    1. Run: ./setup_signing_keyring.sh (recommended - uses system keyring)
                    2. Or run: ./setup_signing.sh (manual setup)
                    3. Or manually create android/key.properties from template
                    
                    For debug builds, use: flutter run --debug
                """.trimIndent())
            }
            
            isMinifyEnabled = false
            isShrinkResources = false
        }
    }
}

dependencies {
    // Import the Firebase BoM
    implementation(platform("com.google.firebase:firebase-bom:33.16.0"))
    
    // Firebase Analytics (required for Google services to work properly)
    // Exclude ads-identifier to remove AD_ID permission
    implementation("com.google.firebase:firebase-analytics") {
        exclude(group = "com.google.android.gms", module = "play-services-ads-identifier")
    }
    
    // Google Play Services Auth (for Google Sign-In)
    // Also exclude ads-identifier if it's being pulled in here
    implementation("com.google.android.gms:play-services-auth:21.0.0") {
        exclude(group = "com.google.android.gms", module = "play-services-ads-identifier")
    }
}

flutter {
    source = "../.."
}
