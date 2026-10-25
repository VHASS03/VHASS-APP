# Minew BeaconSET Plus SDK (from official guide)
# https://docs.minew.com/Android/Android_BeaconPlus_Software_Development_Kit_Guide.html#prepare

-keep public class com.minew.beaconplus.sdk.** { *; }
-keep public class no.nordicsemi.android.** { *; }
# ONNX Runtime rules
-keep class ai.onnxruntime.** { *; }
-keep class com.microsoft.onnxruntime.** { *; }

# openWakeWord rules
-keep class com.rementia.openwakeword.** { *; }
-keepclasseswithmembernames class * {
    native <methods>;
}

# Google Maps rules
-dontwarn io.flutter.plugins.googlemaps.**
-keep class io.flutter.plugins.googlemaps.** { *; }

# Syava AI Native Services, Receivers & Helpers
-keep class com.syava.ai.** { *; }
-keep interface com.syava.ai.** { *; }
-dontwarn com.syava.ai.**

# Flutter Plugins & Core
-keep class io.flutter.** { *; }
-keep class io.flutter.plugins.** { *; }
-keep class io.flutter.embedding.** { *; }
-keep class io.flutter.app.** { *; }
-keepattributes *Annotation*,Signature,InnerClasses,EnclosingMethod
