plugins {
  id("com.android.application")
  // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
  id("dev.flutter.flutter-gradle-plugin")
}

android {
  namespace = "eu.idura.verify.flutter.example"
  compileSdk = flutter.compileSdkVersion
  ndkVersion = flutter.ndkVersion

  compileOptions {
    sourceCompatibility = JavaVersion.VERSION_17
    targetCompatibility = JavaVersion.VERSION_17
  }

  defaultConfig {
    // TODO: Specify your own unique Application ID (https://developer.android.com/studio/build/application-id.html).
    applicationId = "eu.idura.verify.flutter.example"
    // You can update the following values to match your application needs.
    // For more information, see: https://flutter.dev/to/review-gradle-config.
    // idura_verify requires 26, above Flutter's default of 24.
    minSdk = 26
    targetSdk = flutter.targetSdkVersion
    // Uses the version code from pubspec.yaml. When using split APKs, 1000 * ABI_VERSION
    // is added automatically by Flutter. (https://developer.android.com/studio/build/configure-apk-splits#configure-APK-versions)
    // You can force using the value of versionCode by specifying the `-P force-version-code-ignoring-abi=true`
    // flag during build.
    versionCode = flutter.versionCode
    versionName = flutter.versionName

    // The only place Idura Verify is configured. Both values land in manifest
    // placeholders that eu.idura:verify and idura_verify leave unresolved — the
    // SDK's for its redirect activity's android:host, the plugin's for the
    // <meta-data> it reads at runtime — so forgetting one fails the build rather
    // than the login. Same tenant the native Android example uses.
    manifestPlaceholders["iduraDomain"] = "samples.test.idura.broker"
    // TODO(phase6): register this client id, along with the applicationId above
    // and the debug signing SHA-256, for the samples tenant in the dashboard.
    manifestPlaceholders["iduraClientId"] = "urn:criipto:samples:idura:verify-flutter"
  }

  buildTypes {
    release {
      // TODO: Add your own signing config for the release build.
      // Signing with the debug keys for now, so `flutter run --release` works.
      signingConfig = signingConfigs.getByName("debug")
    }
  }
}

kotlin {
  compilerOptions {
    jvmTarget = org.jetbrains.kotlin.gradle.dsl.JvmTarget.JVM_17
  }
}

flutter {
  source = "../.."
}
