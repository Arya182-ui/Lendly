# Add rules here to keep necessary classes and remove unused code
# Flutter and Dart rules (required)
-keep class io.flutter.app.** { *; }
-keep class io.flutter.plugin.** { *; }
-keep class io.flutter.util.** { *; }
-keep class io.flutter.view.** { *; }
-keep class io.flutter.** { *; }
-keep class com.google.firebase.** { *; }
-keep class com.google.android.gms.** { *; }
-keep class com.example.lendly.** { *; }
-dontwarn io.flutter.embedding.**
-dontwarn io.flutter.plugins.**
# Add additional keep rules for libraries you use if needed
