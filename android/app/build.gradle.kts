plugins {
    id("com.android.application")
    id("kotlin-android")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

android {
    namespace = "com.bookedmic.app" // Ensure this matches your package name in AndroidManifest.xml

    compileSdk = flutter.compileSdkVersion

    ndkVersion = "27.0.12077973"

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_1_8
        targetCompatibility = JavaVersion.VERSION_1_8
    }

    // Correct placement for the dependencies block for compileOptions
    dependencies {
        coreLibraryDesugaring("com.android.tools:desugar_jdk_libs:2.0.4")
    }

    kotlinOptions {
        jvmTarget = JavaVersion.VERSION_1_8.toString()
    }

    defaultConfig {
        applicationId = "com.bookedmic.app" // This should be your unique application ID
        minSdk = 23 
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName
        // You had ndkVersion defined here and above. Keep it in defaultConfig.
        // ndkVersion = "27.0.12077973" // Using flutter.ndkVersion is often preferred if defined
    }

    // --- CORRECT PLACEMENT FOR signingConfigs BLOCK ---
    signingConfigs {
        create("release") { // Use create to define the release signing config
            // Ensure the keystore file name and location are correct
            // If the file is not in the 'android/app' folder, provide the correct path
            storeFile = file("my-new-release-key.keystore")
            storePassword = "104tenfour"
            keyAlias = "my-release-key" // Make sure this is your actual key alias
            keyPassword = "104tenfour" // Using your password "FluffyBunny"
        }
        // If you have a debug signing config, you could define it here as well,
        // but Flutter usually handles the debug signing automatically.
    }
    // --- END signingConfigs BLOCK ---


    buildTypes {
        release {
            // TODO: Add your own signing configuration for release.
            // Follow the instructions at https://flutter.dev/to/build-release-android-app#signing-the-app
            // Assign the release signing config defined above
            signingConfig = signingConfigs.getByName("release")
            // Other release build configurations can go here if needed
            // minifyEnabled true
            // shrinkResources true
        }
        // The debug build type is configured automatically by the Flutter plugin.
    }
}

flutter {
    source = "../.."
}