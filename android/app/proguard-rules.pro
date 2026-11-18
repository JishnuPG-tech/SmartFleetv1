# Flutter Core & Plugins
-keep class io.flutter.app.** { *; }
-keep class io.flutter.plugin.**  { *; }
-keep class io.flutter.util.**  { *; }
-keep class io.flutter.view.**  { *; }
-keep class io.flutter.**  { *; }
-keep class io.flutter.plugins.**  { *; }

# SmartFleet App & Installer Channel
-keep class com.smartfleet.app.smartfleet_flutter.** { *; }
-keep class androidx.core.content.FileProvider { *; }

# Preserve Models & Serialization
-keepclassmembers class * {
    @com.google.gson.annotations.SerializedName <fields>;
}

-dontwarn io.flutter.**
-dontwarn javax.annotation.**
