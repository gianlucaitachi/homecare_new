plugins {
    id("com.android.application")
    id("kotlin-android")
    // Flutter plugin phải sau Android + Kotlin
    id("dev.flutter.flutter-gradle-plugin")
}

android {
    namespace = "com.example.homecare_app" // đổi theo package của bạn nếu cần
    compileSdk = 36
    ndkVersion = flutter.ndkVersion

    defaultConfig {
        applicationId = "com.example.homecare_app" // đổi theo package của bạn nếu cần
        minSdk = flutter.minSdkVersion // thường = 23
        targetSdk = 34
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    // ĐẶT Ở ĐÂY (đúng chỗ) — Kotlin DSL
    compileOptions {
        // Bật desugaring cho Java 8+ APIs trên minSdk thấp
        isCoreLibraryDesugaringEnabled = true
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    kotlinOptions {
        jvmTarget = "17"
    }

    buildTypes {
        release {
            // ký tạm bằng debug để flutter run --release hoạt động
            signingConfig = signingConfigs.getByName("debug")
        }
    }
}

dependencies {
    // Thư viện desugar tương thích Java 17 (>= 2.0.4)
    coreLibraryDesugaring("com.android.tools:desugar_jdk_libs:2.0.4")
}

flutter {
    source = "../.."
}
