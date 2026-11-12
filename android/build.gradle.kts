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

// Correct compileSdk for the thermal printer plugin after all projects are evaluated.
// Its Android module currently declares API 33, but its AndroidX dependencies require API 34+.
gradle.projectsEvaluated {
    val thermalPrinter = findProject(":flutter_thermal_printer")
    thermalPrinter?.extensions
        ?.findByType<com.android.build.api.dsl.LibraryExtension>()
        ?.compileSdk = 36
}

tasks.register<Delete>("clean") {
    delete(rootProject.layout.buildDirectory)
}
