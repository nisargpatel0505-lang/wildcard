plugins {
    id("com.android.application")
    // START: FlutterFire Configuration
    id("com.google.gms.google-services")
    // END: FlutterFire Configuration
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
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
