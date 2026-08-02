allprojects {
    repositories {
        google()
        mavenCentral()
    }
}

// Corriger les plugins anciens qui n'ont pas de namespace (requis depuis AGP 8+)
subprojects {
    afterEvaluate {
        if (project.plugins.hasPlugin("com.android.library")) {
            val android = project.extensions.getByType(com.android.build.gradle.LibraryExtension::class.java)
            if (android.namespace == null || android.namespace!!.isEmpty()) {
                val manifest = file("${project.projectDir}/src/main/AndroidManifest.xml")
                if (manifest.exists()) {
                    val pkg = Regex("package=\"([^\"]+)\"").find(manifest.readText())?.groupValues?.get(1)
                    if (pkg != null) {
                        android.namespace = pkg
                    }
                }
            }
        }
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

tasks.register<Delete>("clean") {
    delete(rootProject.layout.buildDirectory)
}
