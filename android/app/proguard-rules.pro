# Flutter Wrapper
-keep class io.flutter.app.** { *; }
-keep class io.flutter.plugin.**  { *; }
-keep class io.flutter.util.**  { *; }
-keep class io.flutter.view.**  { *; }
-keep class io.flutter.**  { *; }
-keep class io.flutter.plugins.**  { *; }

# Google Play Services & AdMob
-keep public class com.google.android.gms.ads.** {
   public *;
}
-keep public class com.google.ads.** {
   public *;
}

# Google ML Kit (Vision & Text Recognition)
-keep class com.google.mlkit.** { *; }
-keep class com.google.android.gms.vision.** { *; }

# Syncfusion & PDF Packages
-dontwarn com.syncfusion.**
-keep class com.syncfusion.** { *; }

# Coroutines and AndroidX
-keepattributes *Annotation*,Signature,InnerClasses,EnclosingMethod
-dontwarn sun.misc.Unsafe
-dontwarn java.lang.invoke.**
