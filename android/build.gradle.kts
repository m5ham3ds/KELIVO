allprojects {
    repositories {
        // Robolectric runtime artifacts can be very large. Maven Central started
        // returning HTTP 429 for these downloads in CI. Use Google's hosted mirror
        // for the Robolectric group only; keep Google Maven and Maven Central for
        // every other dependency and retain Maven Central as the fallback source.
        maven {
            name = "GoogleHostedMavenCentralMirror"
            url = uri("https://maven-central.storage-download.googleapis.com/maven2/")
            content {
                includeGroup("org.robolectric")
            }
        }
        google()
        mavenCentral()
    }
}

val newBuildDir: Directory = rootProject.layout.buildDirectory.dir("../../build").get()
rootProject.layout.buildDirectory.value(newBuildDir)

subprojects {
    val newSubprojectBuildDir: Directory = newBuildDir.dir(project.name)
    project.layout.buildDirectory.value(newSubprojectBuildDir)
}
subprojects {
    project.evaluationDependsOn(":app")
}

// Flutter's integration_test plugin requests androidx.test:runner:1.2+.
// Dynamic versions query every repo's maven-metadata.xml; a Maven Central
// TLS/404 flake then fails the whole resolve even when Google Maven has it.
subprojects {
    configurations.configureEach {
        resolutionStrategy.eachDependency {
            if (requested.group == "androidx.test" && requested.name == "runner") {
                useVersion("1.5.2")
                because("pin past dynamic 1.2+ metadata fetch")
            }
        }
    }
}

tasks.register<Delete>("clean") {
    delete(rootProject.layout.buildDirectory)
}
