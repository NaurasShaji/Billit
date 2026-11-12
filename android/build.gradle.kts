allprojects {
    repositories {
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

// The thermal printer plugin declares compileSdk 33, but its AndroidX dependencies
// require API 34+. Override it during AGP's DSL-finalization phase, before variants
// and AAR metadata tasks are configured.
subprojects {
    if (name == "flutter_thermal_printer") {
        plugins.withId("com.android.library") {
            extensions
                .getByType<com.android.build.api.variant.LibraryAndroidComponentsExtension>()
                .finalizeDsl { libraryExtension ->
                    libraryExtension.compileSdk = 36
                }
        }
    }
}

tasks.register<Delete>("clean") {
    delete(rootProject.layout.buildDirectory)
}
