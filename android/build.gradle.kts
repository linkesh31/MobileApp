// Top-level build file where you can add configuration options common to all sub-projects/modules.

plugins {
    // Required plugin versions
    id("com.google.gms.google-services") version "4.3.15" apply false
    id("com.android.application") version "8.7.0" apply false
    id("org.jetbrains.kotlin.android") version "1.8.22" apply false
}

allprojects {
    repositories {
        google()
        mavenCentral()
    }
}

// 🔧 Force compatible versions of Firestore and okio (fixes getBuffer() crash)
subprojects {
    configurations.all {
        resolutionStrategy {
            force("com.google.firebase:firebase-firestore-ktx:24.7.1") // ✅ Stable Firestore
            force("com.squareup.okio:okio:3.2.0") // ✅ Compatible okio version
        }
    }
}

// Optional: redirect build directory to outside of /android folder
val newBuildDir = rootProject.layout.buildDirectory.dir("../../build").get()
rootProject.layout.buildDirectory.value(newBuildDir)

subprojects {
    val newSubprojectBuildDir = newBuildDir.dir(project.name)
    project.layout.buildDirectory.value(newSubprojectBuildDir)
    project.evaluationDependsOn(":app")
}

// Clean task for root project
tasks.register<Delete>("clean") {
    delete(rootProject.layout.buildDirectory)
}
