plugins {
    id("com.android.application")
    id("kotlin-android")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
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

    // Codemagic exposes the selected Android keystore and credentials through
    // these environment variables. Do not assume the keystore is in the repo.
    signingConfigs {
        create("release") {
            val keystorePath = System.getenv("CM_KEYSTORE_PATH")
            val keystorePassword = System.getenv("CM_KEYSTORE_PASSWORD")
            val keyAliasValue = System.getenv("CM_KEY_ALIAS")
            val keyPasswordValue = System.getenv("CM_KEY_PASSWORD")

            if (keystorePath.isNullOrBlank() ||
                keystorePassword.isNullOrBlank() ||
                keyAliasValue.isNullOrBlank() ||
                keyPasswordValue.isNullOrBlank()
            ) {
                throw GradleException(
                    "Android release signing is not configured. Select the Android keystore in Codemagic."
                )
            }

            storeFile = file(keystorePath)
            storePassword = keystorePassword
            keyAlias = keyAliasValue
            keyPassword = keyPasswordValue
        }
    }

    buildTypes {
        getByName("release") {
            signingConfig = signingConfigs.getByName("release")
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
