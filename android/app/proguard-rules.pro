# Flutter Proguard Rules
# These rules ensure proper ProGuard processing for Flutter when building in release mode

# Flutter wrapper
-keep class io.flutter.app.** { *; }
-keep class io.flutter.plugin.** { *; }
-keep class io.flutter.util.** { *; }
-keep class io.flutter.view.** { *; }
-keep class io.flutter.** { *; }
-keep class io.flutter.plugins.** { *; }

# Google Play Core (needed for Flutter's deferred components)
-keep class com.google.android.play.** { *; }
-dontwarn com.google.android.play.**

# Flutter embedding
-keep class io.flutter.embedding.** { *; }
-dontwarn io.flutter.embedding.**

# Preserve the Serializers for Gson, Jackson
-keepattributes Signature
-keepattributes *Annotation*
-keepattributes EnclosingMethod
-keepattributes InnerClasses

# Preserve R8/ProGuard specific annotations
-keepattributes SourceFile,LineNumberTable

# Application specific rules - add rules specific to your app dependencies here
# For example, if you're using libraries like Riverpod, GetIt, etc.

# Keep Riverpod
-keep class ** implements androidx.lifecycle.ViewModel {*;}

# Keep GetIt
-keep class org.shields.apps.nook.** { *; }

# Additional Flutter rules
-keep class io.flutter.embedding.engine.** { *; }
-keep class io.flutter.embedding.android.** { *; }

# Keep classes that might be accessed via reflection
-keepclassmembers class * {
    @androidx.annotation.Keep *;
}
