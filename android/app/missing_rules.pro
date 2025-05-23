# Generated missing rules for R8
# Add these rules to handle missing Play Core classes

-dontwarn com.google.android.play.core.**
-keep class com.google.android.play.core.** { *; }

# Alternative: completely ignore missing Play Core classes
-dontnote com.google.android.play.core.**
-dontwarn com.google.android.play.core.splitcompat.SplitCompatApplication
-dontwarn com.google.android.play.core.splitinstall.**
-dontwarn com.google.android.play.core.tasks.**
