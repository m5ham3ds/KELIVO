pluginManagement {
    val flutterSdkPath = run {
        val properties = java.util.Properties()
        file("local.properties").inputStream().use { properties.load(it) }
        val flutterSdkPath = properties.getProperty("flutter.sdk")
        require(flutterSdkPath != null) { "flutter.sdk not set in local.properties" }
        flutterSdkPath
    }

    includeBuild("$flutterSdkPath/packages/flutter_tools/gradle")

    // Resolve the Kotlin plugin implementation directly from Maven Central.
    // Its marker lives on the Plugin Portal, whose artifact redirects can hit
    // Maven Central's shared HTTP 429 limit even when the mirror is available.
    resolutionStrategy {
        eachPlugin {
            if (requested.id.namespace == "org.jetbrains.kotlin") {
                useModule("org.jetbrains.kotlin:kotlin-gradle-plugin:${requested.version}")
            }
        }
    }

    repositories {
        google()
        // Prefer the hosted Maven Central mirror for Kotlin and its transitive
        // dependencies; keep canonical Central as a fallback.
        maven { url = uri("https://maven-central.storage-download.googleapis.com/maven2/") }
        mavenCentral()
    }
}

plugins {
    id("dev.flutter.flutter-plugin-loader") version "1.0.0"
    id("com.android.application") version "8.12.1" apply false
    id("org.jetbrains.kotlin.android") version "2.2.20" apply false
}

include(":app")
