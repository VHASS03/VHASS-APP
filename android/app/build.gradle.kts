import org.jetbrains.kotlin.gradle.tasks.KotlinCompile
import java.io.File
import java.util.Properties

plugins {
    id("com.android.application")
    id("kotlin-android")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

// Minew BeaconSET Plus: add MTBeaconPlus.aar to app/libs/ — see libs/README_MINEW.md
val minewBeaconPlusAar = file("libs/MTBeaconPlus.aar")

android {
    namespace = "com.syava.ai"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion

    val keystorePropertiesFile = rootProject.file("key.properties")
    val keystoreProperties = Properties()
    if (keystorePropertiesFile.exists()) {
        keystoreProperties.load(keystorePropertiesFile.inputStream())
    }

    signingConfigs {
        create("release") {
            keyAlias = keystoreProperties.getProperty("keyAlias")
            keyPassword = keystoreProperties.getProperty("keyPassword")
            storeFile = keystoreProperties.getProperty("storeFile")?.let { project.file(it) }
            storePassword = keystoreProperties.getProperty("storePassword")
        }
    }

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_11
        targetCompatibility = JavaVersion.VERSION_11
        isCoreLibraryDesugaringEnabled = true
    }

    kotlinOptions {
        jvmTarget = JavaVersion.VERSION_11.toString()
    }

    defaultConfig {
        // TODO: Specify your own unique Application ID (https://developer.android.com/studio/build/application-id.html).
        applicationId = "com.syava.ai"
        // You can update the following values to match your application needs.
        // For more information, see: https://flutter.dev/to/review-gradle-config.
        // Minew SDK requires minSdk 24 when MTBeaconPlus.aar is present (official guide).
        minSdk = if (minewBeaconPlusAar.exists()) maxOf(flutter.minSdkVersion, 24) else flutter.minSdkVersion
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName
        
        // Google Maps API Key
        manifestPlaceholders["com.google.android.geo.API_KEY"] = "AIzaSyABObu0QnKEykNF72Zqt_AdcG-wCgN4UQ4"
    }

    aaptOptions {
        noCompress("onnx")
    }

    buildTypes {
        release {
            // Sign release build with the newly configured release keys.
            signingConfig = signingConfigs.getByName("release")
            isMinifyEnabled = true
            isShrinkResources = true
            proguardFiles(
                getDefaultProguardFile("proguard-android-optimize.txt"),
                "proguard-rules.pro"
            )
            ndk {
                debugSymbolLevel = "none"
            }
        }
    }

    packaging {
        jniLibs {
            keepDebugSymbols.add("**/libonnxruntime.so")
            keepDebugSymbols.add("**/libflutter.so")
        }
    }
}

// Omit Minew Kotlin sources until MTBeaconPlus.aar is present (avoid android.sourceSets `java` DSL clash).
tasks.withType<KotlinCompile>().configureEach {
    if (!minewBeaconPlusAar.exists()) {
        exclude("**/minew/MinewBeaconPlusPlugin.kt")
        }
}

dependencies {
    coreLibraryDesugaring("com.android.tools:desugar_jdk_libs:2.0.4")
    if (minewBeaconPlusAar.exists()) {
        implementation(files("libs/MTBeaconPlus.aar"))
    }
    
    // openWakeWord Library (runs ONNX Runtime Mobile internally)
    implementation("xyz.rementia:openwakeword:0.1.5")
}


flutter {
    source = "../.."
}
