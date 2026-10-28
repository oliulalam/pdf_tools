# Flutter wrapper
-keep class io.flutter.app.** { *; }
-keep class io.flutter.plugin.** { *; }
-keep class io.flutter.util.** { *; }
-keep class io.flutter.view.** { *; }
-keep class io.flutter.** { *; }
-keep class io.flutter.plugins.** { *; }

# Syncfusion PDF rules
-keep class com.syncfusion.** { *; }

# PDFium / PDFx rules
-keep class com.shockwave.** { *; }
-keep class com.scer.pdfx.** { *; }
-keep class io.github.espresso3389.pdfrx.** { *; }

# Google Mobile Ads
-keep class com.google.android.gms.ads.** { *; }
-keep class com.google.ads.** { *; }

# Flutter Play Store Split / Deferred Components (Fix for R8 Missing Classes)
-dontwarn com.google.android.play.core.**
-keep class com.google.android.play.core.** { *; }
-keep class io.flutter.embedding.engine.deferredcomponents.** { *; }

# General R8 fixes
-dontwarn android.window.OnBackInvokedCallback
-dontwarn android.window.OnBackInvokedDispatcher
-ignorewarnings
