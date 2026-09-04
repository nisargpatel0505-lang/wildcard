plugins {
    id("com.android.application")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

// Astra is an offline, side-by-side experiment. It never loads production
// Google Services configuration or the Play app's signing credentials.
val testAdMobAppId = "ca-app-pub-3940256099942544~3347511713"
val astraDefinePresent = providers.gradleProperty("dart-defines").orElse("").get()
    .split(",").any { encoded ->
        runCatching { String(java.util.Base64.getDecoder().decode(encoded)) }
            .getOrNull() == "WILDCARD_ASTRA_BUILD=true"
    }
require(astraDefinePresent) { "Build this isolated app with --dart-define=WILDCARD_ASTRA_BUILD=true" }

android {
    namespace = "com.nisarg.wildcard"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    buildFeatures {
        buildConfig = true
    }

    signingConfigs {
        getByName("debug") {
            // Experimental key only; never the Google Play signing key.
            storeFile = file(System.getProperty("user.home") + "/.android/wildcard-astra.keystore")
            storePassword = "android"
            keyAlias = "androiddebugkey"
            keyPassword = "android"
        }
    }

    defaultConfig {
        applicationId = "com.nisarg.wildcard.astra"
        minSdk = 24
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName
        manifestPlaceholders["wildcardAdmobAppId"] = testAdMobAppId
        buildConfigField("boolean", "WILDCARD_ASTRA_BUILD", "true")
        buildConfigField("boolean", "WILDCARD_ADS_TESTING", "true")
    }

    buildTypes {
        debug {
            signingConfig = signingConfigs.getByName("debug")
        }
        getByName("profile") {
            signingConfig = signingConfigs.getByName("debug")
        }
        release {
            signingConfig = signingConfigs.getByName("debug")
            // AGP 9/R8 full mode can strip the reflective no-arg constructor
            // from Room-generated databases even when the class name is kept
            // by the library's consumer rules. WorkManager is initialized by
            // AndroidX Startup before Flutter, so preserve that constructor.
            proguardFiles("proguard-rules.pro")
        }
    }
}

kotlin {
    compilerOptions {
        jvmTarget = org.jetbrains.kotlin.gradle.dsl.JvmTarget.JVM_17
    }
}

flutter {
    source = "../.."
}
