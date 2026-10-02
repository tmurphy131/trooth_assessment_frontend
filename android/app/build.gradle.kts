plugins {
    id("com.android.application")
    id("kotlin-android")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

// --- Keystore properties (for release signing) ---
import java.util.Properties

val keystoreProperties = Properties()
val keystorePropertiesFile = rootProject.file("key.properties")
if (keystorePropertiesFile.exists()) {
    keystorePropertiesFile.inputStream().use { keystoreProperties.load(it) }
    println("[gradle] Loaded keystore properties for release signing.")
} else {
    println("[gradle] key.properties not found. Release builds will fail; debug builds are fine.")
}

android {
    namespace = "com.trooth.flutterTroothAssessment"
    compileSdk = 36  // Highest required by plugins (backwards compatible)
    ndkVersion = flutter.ndkVersion

    compileOptions {
        // Enable core library desugaring for flutter_local_notifications
        isCoreLibraryDesugaringEnabled = true
        sourceCompatibility = JavaVersion.VERSION_11
        targetCompatibility = JavaVersion.VERSION_11
    }

    kotlinOptions {
        jvmTarget = JavaVersion.VERSION_11.toString()
    }

    defaultConfig {
        // TODO: Specify your own unique Application ID (https://developer.android.com/studio/build/application-id.html).
        applicationId = "com.trooth.flutterTroothAssessment"
        // You can update the following values to match your application needs.
        // For more information, see: https://flutter.dev/to/review-gradle-config.
        minSdk = 24  // Android 7.0 - supports ~98% of devices
        targetSdk = 36  // Android 16 - required by Google Play as of Aug 31, 2026
        versionCode = flutter.versionCode
        versionName = flutter.versionName
        // Required for flutter_local_notifications
        multiDexEnabled = true
    }

    signingConfigs {
        create("release") {
            if (keystoreProperties.isNotEmpty()) {
                val storeFilePath = keystoreProperties["storeFile"] as String?
                if (!storeFilePath.isNullOrBlank()) {
                    storeFile = file(storeFilePath)
                }
                storePassword = (keystoreProperties["storePassword"] as String?)
                keyAlias = (keystoreProperties["keyAlias"] as String?)
                keyPassword = (keystoreProperties["keyPassword"] as String?)
            }
        }
    }

    buildTypes {
        release {
            // Release builds must use the upload key; see the taskGraph check below.
            signingConfig = signingConfigs.getByName("release")
            // R8 shrinking: a release build with it launches fine, but sign-in,
            // Firestore and RevenueCat weren't verified under it yet. Enable after
            // a check on a real device (internal track):
            // isMinifyEnabled = true
            // isShrinkResources = true
            // proguardFiles(getDefaultProguardFile("proguard-android-optimize.txt"))
        }
    }
}

flutter {
    source = "../.."
}

// Fail fast instead of producing a debug-signed release that Play rejects.
gradle.taskGraph.whenReady {
    val buildsRelease = allTasks.any { it.project == project && it.name.contains("Release") }
    if (buildsRelease && keystoreProperties.isEmpty) {
        throw GradleException("android/key.properties is missing: release builds need the upload keystore.")
    }
}

dependencies {
    // Core library desugaring for Java 8+ APIs on older Android versions
    coreLibraryDesugaring("com.android.tools:desugar_jdk_libs:2.1.4")
}
