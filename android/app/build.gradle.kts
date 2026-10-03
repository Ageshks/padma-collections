// Gradle's own `java` extension shadows the `java` package name inside a build
// script, so `java.util.Properties` must be imported rather than qualified.
import java.util.Properties

plugins {
    id("com.android.application")
    id("kotlin-android")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
    // The Google Services plugin injects the OAuth `serverClientId` that Google
    // Sign-In needs on Android, and generates the `values.xml` resources that
    // point the SDK at project `padma-cb65f`.
    //
    // It is declared here (rather than with a conditional `apply()`) because the
    // `plugins {}` block is evaluated by Gradle's plugin *resolver* before any
    // imperative code runs — an `apply()` inside it is a known Kotlin-DSL
    // anti-pattern. google-services.json is committed, so the plugin is
    // unconditionally available.
    id("com.google.gms.google-services")
    // Uploads the R8 mapping file so Crashlytics can symbolicate release
    // stack traces.
    id("com.google.firebase.crashlytics")
}

// Release signing credentials, loaded from android/key.properties (git-ignored).
//
// `Properties` is used unqualified because `java` resolves to Gradle's own
// `java` extension in a build script, shadowing the package name.
val releaseKeystoreFile = file("key.properties")
val releaseKeystore: Properties? = if (releaseKeystoreFile.exists()) {
    Properties().apply {
        releaseKeystoreFile.inputStream().use { load(it) }
    }
} else {
    null
}

android {
    namespace = "com.padmacollections.app"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    // The `kotlinOptions.jvmTarget` form is deprecated and now a hard error on
    // Kotlin 2.2+, so the compilerOptions DSL is used instead.
    kotlin {
        compilerOptions {
            jvmTarget.set(org.jetbrains.kotlin.gradle.dsl.JvmTarget.JVM_17)
        }
    }

    defaultConfig {
        // Google Sign-In requires Android 6.0 (API 23) or newer. Raising this
        // from Flutter's default of 21 is mandatory for the plugin to work.
        applicationId = "com.padmacollections.app"
        minSdk = maxOf(flutter.minSdkVersion, 23)
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    buildTypes {
        release {
            // When android/key.properties is absent (a fresh clone, or CI before
            // secrets are injected) the build still succeeds so that
            // `flutter build apk --release` is usable for smoke tests, but the
            // artifact is debug-signed and the Play Store would reject it.
            signingConfig = if (releaseKeystore != null) {
                signingConfigs.create("release") {
                    storeFile = file(releaseKeystore.getProperty("storeFile"))
                    storePassword = releaseKeystore.getProperty("storePassword")
                    keyAlias = releaseKeystore.getProperty("keyAlias")
                    keyPassword = releaseKeystore.getProperty("keyPassword")
                }
            } else {
                signingConfigs.getByName("debug")
            }

            // R8 shrinking. Required for a small download and the reason
            // Crashlytics can symbolicate crashes.
            isMinifyEnabled = true
            isShrinkResources = true
            proguardFiles(
                getDefaultProguardFile("proguard-android-optimize.txt"),
                "proguard-rules.pro",
            )
        }
    }
}

flutter {
    source = "../.."
}
