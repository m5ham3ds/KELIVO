import java.util.Properties

plugins {
    id("com.android.application")
    // The Flutter Gradle Plugin must be applied after the Android Gradle plugin.
    id("dev.flutter.flutter-gradle-plugin")
}

// The production APK remains ARM64-only. The Android emulator E2E lane
// opts into an x86_64 Debug APK so it can exercise the matching native PRoot.
val kelivoE2E = providers.gradleProperty("kelivoE2E").orNull == "true"
val kelivoAbis = if (kelivoE2E) listOf("x86_64") else listOf("arm64-v8a")
// NDK abiFilters alone did not keep all prebuilt JNI libraries out of the
// final APK. Enforce the same selected ABI again at the packaging boundary.
val kelivoPackagingExcludedAbis = listOf(
    "armeabi",
    "armeabi-v7a",
    "arm64-v8a",
    "x86",
    "x86_64",
    "mips",
    "mips64",
).filterNot { it in kelivoAbis }

// Robolectric downloads Android SDK runtime jars with its own MavenArtifactFetcher.
// Gradle repository declarations in android/build.gradle.kts do not configure that
// downloader. Keep both properties explicit so test JVMs use the hosted mirror
// rather than Robolectric's default repo1.maven.org endpoint.
val robolectricRuntimeRepoUrl = providers.gradleProperty("robolectricDependencyRepoUrl")
    .orElse(providers.environmentVariable("ROBOLECTRIC_DEPENDENCY_REPO_URL"))
    .orElse("https://maven-central.storage-download.googleapis.com/maven2/")
val robolectricRuntimeRepoId = providers.gradleProperty("robolectricDependencyRepoId")
    .orElse(providers.environmentVariable("ROBOLECTRIC_DEPENDENCY_REPO_ID"))
    .orElse("GoogleHostedMavenCentralMirror")


android {
    namespace = "com.psyche.kelivo"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = "28.2.13676358"
    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_11
        targetCompatibility = JavaVersion.VERSION_11
        isCoreLibraryDesugaringEnabled = true
    }

    defaultConfig {
        // TODO: Specify your own unique Application ID (https://developer.android.com/studio/build/application-id.html).
        applicationId = "com.psyche.kelivo"
        // You can update the following values to match your application needs.
        // For more information, see: https://flutter.dev/to/review-gradle-config.
        // flutter_secure_storage 11.x requires API 24; this also exceeds super_clipboard's API 23 minimum.
        minSdk = maxOf(flutter.minSdkVersion, 24)
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName
        // Restrict the APK's packaged native libraries to 64-bit ARM.
        // externalNativeBuild.abiFilters below additionally constrains CMake output.
        ndk {
            abiFilters += kelivoAbis
        }
        // This Android-only build targets 64-bit ARM devices.
        externalNativeBuild {
            cmake {
                abiFilters += kelivoAbis
            }
        }
    }

    externalNativeBuild {
        cmake {
            path = file("src/main/cpp/CMakeLists.txt")
        }
    }

    packaging {
        jniLibs {
            useLegacyPackaging = true
            excludes += kelivoPackagingExcludedAbis.map { "**/$it/**" }
        }
    }

    testOptions {
        unitTests.isReturnDefaultValues = true
        unitTests.isIncludeAndroidResources = true
        unitTests.all {
            it.systemProperty(
                "robolectric.dependency.repo.url",
                robolectricRuntimeRepoUrl.get(),
            )
            it.systemProperty(
                "robolectric.dependency.repo.id",
                robolectricRuntimeRepoId.get(),
            )
        }
    }

    val keystorePropertiesFile = rootProject.file("key.properties")
    val keystoreProperties = Properties()
    if (keystorePropertiesFile.exists()) {
        keystoreProperties.load(keystorePropertiesFile.inputStream())
    }

    signingConfigs {
        create("release") {
            if (keystorePropertiesFile.exists()) {
                storeFile = file(keystoreProperties["storeFile"] as String)
                storePassword = keystoreProperties["storePassword"] as String
                keyAlias = keystoreProperties["keyAlias"] as String
                keyPassword = keystoreProperties["keyPassword"] as String
            }
        }
    }

    buildTypes {
        getByName("release") {
            signingConfig = if (keystorePropertiesFile.exists()) {
                signingConfigs.getByName("release")
            } else {
                // Test builds remain installable without a user-provided upload keystore.
                // Replace with a private upload key only when preparing a public release.
                signingConfigs.getByName("debug")
            }
        }
    }
}

// Log the effective runtime repository in CI so a Robolectric network failure
// can be distinguished from an unnoticed fallback to the default Maven Central.
logger.lifecycle(
    "Robolectric runtime dependency repository: ${robolectricRuntimeRepoId.get()} (${robolectricRuntimeRepoUrl.get()})",
)

kotlin {
    compilerOptions {
        jvmTarget = org.jetbrains.kotlin.gradle.dsl.JvmTarget.JVM_11
    }
}

flutter {
    source = "../.."
}

val requiredProotLibs = listOf(
    "arm64-v8a/libproot_exec.so",
    "arm64-v8a/libproot_loader.so",
    "arm64-v8a/libtalloc.so",
    "arm64-v8a/libandroid-shmem.so",
)

tasks.register<Exec>("fetchProot") {
    val repoRoot = rootProject.projectDir.parentFile
    commandLine("bash", repoRoot.resolve("tool/fetch_proot.sh").absolutePath)
    workingDir = repoRoot
    onlyIf {
        val jniLibs = layout.projectDirectory.dir("src/main/jniLibs")
        requiredProotLibs.any { name ->
            val so = jniLibs.file(name).asFile
            !so.isFile || so.length() == 0L
        }
    }
}

tasks.whenTaskAdded {
    if (name == "preBuild") {
        dependsOn("fetchProot")
    }
}
tasks.findByName("preBuild")?.dependsOn("fetchProot")

dependencies {
    implementation("androidx.browser:browser:1.9.0")
    implementation("org.tukaani:xz:1.10")
    // Required for core library desugaring (used by flutter_local_notifications)
    coreLibraryDesugaring("com.android.tools:desugar_jdk_libs:2.0.4")
    testImplementation("junit:junit:4.13.2")
    testImplementation("org.robolectric:robolectric:4.16.1")
}
