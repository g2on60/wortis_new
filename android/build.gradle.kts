// Fichier android/build.gradle.kts

buildscript {
    repositories {
        google()
        mavenCentral()
    }
    dependencies {
        // Plugin Android Gradle compatible avec Flutter 3.38.x
        classpath("com.android.tools.build:gradle:8.3.2")
        // Plugin Kotlin compatible
        classpath("org.jetbrains.kotlin:kotlin-gradle-plugin:1.9.25")
    }
}

allprojects {
    repositories {
        google()
        mavenCentral()
    }
}

// Redéfinir le dossier build à la racine
val newBuildDir: Directory = rootProject.layout.buildDirectory.dir("../../build").get()
rootProject.layout.buildDirectory.set(newBuildDir)

subprojects {
    // Chaque sous-projet utilise un sous-dossier du build global
    val newSubprojectBuildDir: Directory = newBuildDir.dir(project.name)
    project.layout.buildDirectory.set(newSubprojectBuildDir)

    // Dépendance d’évaluation sur le module app
    evaluationDependsOn(":app")
}

// Tâche clean
tasks.register<Delete>("clean") {
    delete(rootProject.layout.buildDirectory)
}
