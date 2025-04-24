// REMOVED ext block - version defined in settings.gradle.kts is primary
// ext {
//     set("kotlin_version", "1.8.22")
// }

buildscript {
    repositories {
        google()
        mavenCentral()
    }

    dependencies {
        // --- Use the version string directly ---
        // Make sure this version MATCHES the one in settings.gradle.kts plugins block
        classpath("org.jetbrains.kotlin:kotlin-gradle-plugin:1.8.22")
        // --- End Use direct version ---

        // Add AGP and Google Services classpath if needed (check settings.gradle.kts)
        // Example if AGP 8.1.0 is used in settings.gradle.kts:
        classpath("com.android.tools.build:gradle:8.1.0")
        // Example if Google Services 4.4.2 is used in settings.gradle.kts:
        // classpath("com.google.gms:google-services:4.4.2")
     }
 }

allprojects {
    repositories {
        google()
        mavenCentral()
    }
}

// --- Keep these blocks ---
val newBuildDir: Directory = rootProject.layout.buildDirectory.dir("../../build").get()
rootProject.layout.buildDirectory.value(newBuildDir)

subprojects {
    val newSubprojectBuildDir: Directory = newBuildDir.dir(project.name)
    project.layout.buildDirectory.value(newSubprojectBuildDir)
}
subprojects {
    project.evaluationDependsOn(":app")
}

tasks.register<Delete>("clean") {
    delete(rootProject.layout.buildDirectory)
}
// --- End Keep ---