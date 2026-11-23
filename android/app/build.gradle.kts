plugins {
    id("com.android.application")
    id("kotlin-android")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

import java.util.Properties

val localKeystoreProperties = Properties()
val localKeystorePropertiesFile = rootProject.file("key.properties")
if (localKeystorePropertiesFile.exists()) {
    localKeystorePropertiesFile.inputStream().use { localKeystoreProperties.load(it) }
}

// Codemagic environment variables take priority. For local PC builds, fall back
// to android/key.properties. Never commit the keystore or key.properties.
val signingStoreFile = System.getenv("CM_KEYSTORE_PATH")
    ?.takeIf { it.isNotBlank() }
    ?: localKeystoreProperties.getProperty("storeFile")
val signingStorePassword = System.getenv("CM_KEYSTORE_PASSWORD")
    ?.takeIf { it.isNotBlank() }
    ?: localKeystoreProperties.getProperty("storePassword")
val signingKeyAlias = System.getenv("CM_KEY_ALIAS")
    ?.takeIf { it.isNotBlank() }
    ?: localKeystoreProperties.getProperty("keyAlias")
val signingKeyPassword = System.getenv("CM_KEY_PASSWORD")
    ?.takeIf { it.isNotBlank() }
    ?: localKeystoreProperties.getProperty("keyPassword")

val hasReleaseSigning = !signingStoreFile.isNullOrBlank() &&
    !signingStorePassword.isNullOrBlank() &&
    !signingKeyAlias.isNullOrBlank() &&
    !signingKeyPassword.isNullOrBlank()

val isReleaseBuildRequested = gradle.startParameter.taskNames.any {
    it.contains("release", ignoreCase = true)
}

if (isReleaseBuildRequested && !hasReleaseSigning) {
    throw GradleException(
        "Release signing is not configured. Select an Android keystore in Codemagic, " +
            "or create android/key.properties for a local PC build."
    )
}

extensions.configure<com.android.build.api.dsl.ApplicationExtension>("android") {
    namespace = "com.example.billit"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = "28.2.13676358"

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_11
        targetCompatibility = JavaVersion.VERSION_11
    }

    defaultConfig {
        applicationId = "com.example.billit"
        minSdk = flutter.minSdkVersion
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    if (hasReleaseSigning) {
        signingConfigs {
            create("release") {
                storeFile = file(signingStoreFile!!)
                storePassword = signingStorePassword!!
                keyAlias = signingKeyAlias!!
                keyPassword = signingKeyPassword!!
            }
        }
    }

    buildTypes {
        getByName("release") {
            if (hasReleaseSigning) {
                signingConfig = signingConfigs.getByName("release")
            }
        }
    }
}

kotlin {
    compilerOptions {
        jvmTarget = org.jetbrains.kotlin.gradle.dsl.JvmTarget.JVM_11
    }
}

flutter {
    source = "../.."
}
