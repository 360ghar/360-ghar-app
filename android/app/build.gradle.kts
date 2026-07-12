import java.util.Properties
import java.io.FileInputStream

plugins {
    id("com.android.application")
    id("org.jetbrains.kotlin.android")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
    id("com.google.gms.google-services") apply false
    id("com.google.firebase.firebase-perf") apply false
    id("com.google.firebase.crashlytics") apply false
}

if (file("google-services.json").exists()) {
    apply(plugin = "com.google.gms.google-services")
    apply(plugin = "com.google.firebase.firebase-perf")
    apply(plugin = "com.google.firebase.crashlytics")
}

val keystoreProperties = Properties()
val keystorePropertiesFile = rootProject.file("key.properties")
if (keystorePropertiesFile.exists()) {
    keystoreProperties.load(FileInputStream(keystorePropertiesFile))
}

// Only use release signing if a valid keystore is provided.
val hasReleaseKeystore = keystorePropertiesFile.exists() &&
        keystoreProperties.containsKey("keyAlias") &&
        keystoreProperties.containsKey("keyPassword") &&
        keystoreProperties.containsKey("storeFile") &&
        keystoreProperties.containsKey("storePassword")

android {
    namespace = "com.the360ghar.ghar360"
    // Explicitly target Android 15 / API 36 to meet plugin requirements.
    compileSdk = 36
    // maplibre_gl requires NDK 28.x; use highest required (backward compatible).
    ndkVersion = "28.1.13356709"

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_21
        targetCompatibility = JavaVersion.VERSION_21
        isCoreLibraryDesugaringEnabled = true
    }

    kotlinOptions {
        jvmTarget = JavaVersion.VERSION_21.toString()
    }

    defaultConfig {
        // TODO: Specify your own unique Application ID (https://developer.android.com/studio/build/application-id.html).
        applicationId = "com.the360ghar.ghar360"
        // You can update the following values to match your application needs.
        // For more information, see: https://flutter.dev/to/review-gradle-config.
        minSdk = flutter.minSdkVersion
        // Target within 1 year of latest Android release (API 35 in 2025)
        targetSdk = 35
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    signingConfigs {
        if (hasReleaseKeystore) {
            create("release") {
                keyAlias = keystoreProperties["keyAlias"] as String
                keyPassword = keystoreProperties["keyPassword"] as String
                storeFile = file(keystoreProperties["storeFile"] as String)
                storePassword = keystoreProperties["storePassword"] as String
            }
        }
    }

    buildTypes {
        release {
            // If a release keystore is not configured, fall back to the debug keystore
            // so local `flutter run --release` continues to work.
            signingConfig = if (hasReleaseKeystore) {
                signingConfigs.getByName("release")
            } else {
                signingConfigs.getByName("debug")
            }
        }
    }

    // Disable Crashlytics mapping file upload during build to avoid network issues
    tasks.whenTaskAdded {
        if (name == "uploadCrashlyticsMappingFileRelease") {
            enabled = false
        }
    }
}

dependencies {
    coreLibraryDesugaring("com.android.tools:desugar_jdk_libs:2.1.4")

    // Match the Activity 1.11.x line that's now required by transitive deps (AGP bumped to 8.9.1).
    implementation("androidx.activity:activity:1.11.0")
    implementation("androidx.activity:activity-ktx:1.11.0")
}

flutter {
    source = "../.."
}

// Ensure Kotlin uses a compatible JDK toolchain for compilation
kotlin {
    jvmToolchain(21)
}
