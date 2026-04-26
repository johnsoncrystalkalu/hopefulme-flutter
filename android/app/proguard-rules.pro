# Keep runtime annotation metadata used by libraries and Kotlin reflection.
-keepattributes *Annotation*,InnerClasses,EnclosingMethod,Signature

# Keep source/line info for stack traces (useful with split-debug-info symbols).
-keepattributes SourceFile,LineNumberTable

# Flutter + plugin classes are usually covered by consumer rules from dependencies.
# This baseline stays conservative to reduce break risk while still enabling shrinking.

# Keep Google Play Services / Firebase safe defaults.
-dontwarn com.google.android.gms.**
-dontwarn com.google.firebase.**

# Keep OneSignal classes referenced by reflection.
-keep class com.onesignal.** { *; }
-dontwarn com.onesignal.**

# Keep webview JavaScript interfaces if any plugin uses reflection hooks.
-keepclassmembers class * {
    @android.webkit.JavascriptInterface <methods>;
}
