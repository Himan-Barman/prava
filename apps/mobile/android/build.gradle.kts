import com.android.build.gradle.LibraryExtension

buildscript {
    repositories {
        google()
        mavenCentral()
    }
    dependencies {
        classpath("com.google.gms:google-services:4.4.2")
    }
}


allprojects {
    repositories {
        google()
        mavenCentral()
    }
}

val newBuildDir: Directory =
    rootProject.layout.buildDirectory
        .dir("../../build")
        .get()
rootProject.layout.buildDirectory.value(newBuildDir)

subprojects {
    val newSubprojectBuildDir: Directory = newBuildDir.dir(project.name)
    project.layout.buildDirectory.value(newSubprojectBuildDir)
}
subprojects {
    project.evaluationDependsOn(":app")
}

subprojects {
    plugins.withId("com.android.library") {
        val extension = extensions.findByType<LibraryExtension>()
        if (extension != null) {
            val current = extension.namespace
            if (current == null || current.isBlank()) {
                extension.namespace = "com.prava.${project.name}"
            }
        }
    }
}

subprojects {
    if (name == "isar_flutter_libs") {
        val manifestFile = file("src/main/AndroidManifest.xml")

        val fixManifest = tasks.register("fixIsarManifest") {
            doLast {
                if (!manifestFile.exists()) return@doLast
                val content = manifestFile.readText()
                val updated = content.replace(Regex("\\s*package=\"[^\"]+\""), "")
                if (updated != content) {
                    manifestFile.writeText(updated)
                }
            }
        }

        tasks.matching { it.name.startsWith("process") && it.name.endsWith("Manifest") }
            .configureEach { dependsOn(fixManifest) }
    }
}

tasks.register<Delete>("clean") {
    delete(rootProject.layout.buildDirectory)
}
