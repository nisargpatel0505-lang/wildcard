import java.util.Base64

plugins {
    id("com.android.application")
    // START: FlutterFire Configuration
    id("com.google.gms.google-services")
    // END: FlutterFire Configuration
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

// This branch packages the official app. The separate offline Astra experiment
// remains buildable from its experiment branch, with its own signing identity.
val dartDefines = providers.gradleProperty("dart-defines").orElse("").get()
    .split(",").mapNotNull { encoded ->
        runCatching { String(Base64.getDecoder().decode(encoded)) }.getOrNull()
    }.toSet()
val offlineAstraRequested = "WILDCARD_ASTRA_BUILD=true" in dartDefines
require(!offlineAstraRequested) {
    "The official package cannot use WILDCARD_ASTRA_BUILD=true. Use the separate experiment branch."
}
val ownerNoAdsRequested = "WILDCARD_OWNER_NO_ADS=true" in dartDefines
// The private phone candidate is an APK only. Check the resolved task graph as
// well as direct requests, so invoking bundle via another task cannot bypass it.
gradle.taskGraph.whenReady {
    val createsPlayBundle = allTasks.any { task ->
        task.project.path == project.path && (
            task.name in setOf("bundleRelease", "bundleDebug", "bundleProfile") ||
                task.name.endsWith("Bundle") ||
                task.name.startsWith("publish", ignoreCase = true)
            )
    }
    require(!ownerNoAdsRequested || !createsPlayBundle) {
        "WILDCARD_OWNER_NO_ADS is for owner phone APKs only. Remove it before building or publishing a Play bundle."
    }
}

val productionAdMobAppId = providers.gradleProperty("WILDCARD_ADMOB_APP_ID")
    .orElse("ca-app-pub-3855192091371080~7622357185")
    .get()
val testAdMobAppId = "ca-app-pub-3940256099942544~3347511713"
val useTestAdsForRelease = providers.gradleProperty("WILDCARD_ADS_TESTING")
    .orElse("false")
    .map { it.equals("true", ignoreCase = true) }
    .get()
val releaseAdMobAppId = if (useTestAdsForRelease) testAdMobAppId else productionAdMobAppId
val signingPasswordFile = rootProject.file("../../keystore-password.txt")
val signingKeystoreFile = rootProject.file("../../wildcard-release.keystore")

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

    defaultConfig {
        applicationId = "com.nisarg.wildcard"
        minSdk = 24
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName
        manifestPlaceholders["wildcardAdmobAppId"] = productionAdMobAppId
    }

    signingConfigs {
        create("wildcardRelease") {
            require(signingPasswordFile.isFile) {
                "Missing WILDCARD signing password file"
            }
            require(signingKeystoreFile.isFile) {
                "Missing WILDCARD release keystore"
            }
            val password = signingPasswordFile.readText().trim()
            storeFile = signingKeystoreFile
            storePassword = password
            keyAlias = "wildcard"
            keyPassword = password
        }
    }

    buildTypes {
        debug {
            // Debug remains update-compatible with the phone build so the
            // legacy SharedPreferences migration can be tested in place.
            signingConfig = signingConfigs.getByName("wildcardRelease")
            manifestPlaceholders["wildcardAdmobAppId"] = testAdMobAppId
            buildConfigField("boolean", "WILDCARD_ADS_TESTING", "true")
        }
        getByName("profile") {
            // Profile builds are sideloaded for DevTools frame tracing. They
            // must never generate traffic against owned AdMob units.
            signingConfig = signingConfigs.getByName("wildcardRelease")
            manifestPlaceholders["wildcardAdmobAppId"] = testAdMobAppId
            buildConfigField("boolean", "WILDCARD_ADS_TESTING", "true")
        }
        release {
            signingConfig = signingConfigs.getByName("wildcardRelease")
            // AGP 9/R8 full mode can strip the reflective no-arg constructor
            // from Room-generated databases even when the class name is kept
            // by the library's consumer rules. WorkManager is initialized by
            // AndroidX Startup before Flutter, so preserve that constructor.
            proguardFiles("proguard-rules.pro")
            // Internal Play builds pass both the matching Gradle property and
            // Dart define so the manifest app ID and Dart ad-unit IDs agree.
            manifestPlaceholders["wildcardAdmobAppId"] = releaseAdMobAppId
            buildConfigField(
                "boolean",
                "WILDCARD_ADS_TESTING",
                useTestAdsForRelease.toString(),
            )
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

dependencies {
    implementation("com.google.android.gms:play-services-games-v2:21.0.0")
}
