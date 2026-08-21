group = "eu.idura.verify.flutter"
version = "1.0-SNAPSHOT"

buildscript {
  val kotlinVersion = "2.4.0"
  repositories {
    google()
    mavenCentral()
  }

  dependencies {
    classpath("com.android.tools.build:gradle:9.1.0")
    classpath("org.jetbrains.kotlin:kotlin-gradle-plugin:$kotlinVersion")
  }
}

allprojects {
  repositories {
    google()
    mavenCentral()
  }
}

plugins {
  id("com.android.library")
}

android {
  namespace = "eu.idura.verify.flutter"

  compileSdk = 36

  // Matches eu.idura:verify rather than the Flutter template's 17. A library
  // compiled to a newer bytecode version cannot be consumed by an app targeting
  // an older one, so staying at the native SDK's floor keeps us usable by apps
  // that have not moved to 17 yet. Nothing here needs a newer language level.
  compileOptions {
    sourceCompatibility = JavaVersion.VERSION_11
    targetCompatibility = JavaVersion.VERSION_11
  }

  sourceSets {
    getByName("main") {
      java.srcDirs("src/main/kotlin")
    }
    getByName("test") {
      java.srcDirs("src/test/kotlin")
    }
  }

  defaultConfig {
    // eu.idura:verify requires 26; consuming apps must raise their own floor to
    // match, since the manifest merger refuses a lower app minSdk.
    minSdk = 26
  }

  testOptions {
    unitTests {
      isIncludeAndroidResources = true
      all {
        it.useJUnitPlatform()

        it.outputs.upToDateWhen { false }

        it.testLogging {
          events("passed", "skipped", "failed", "standardOut", "standardError")
          showStandardStreams = true
        }
      }
    }
  }
}

kotlin {
  compilerOptions {
    jvmTarget = org.jetbrains.kotlin.gradle.dsl.JvmTarget.JVM_11
  }
}

dependencies {
  // `api`, not `implementation`: apps that mix Flutter with native Idura Verify
  // screens should see eu.idura.verify.* on their own compile classpath rather
  // than having to declare the same dependency twice at a version we might
  // disagree with.
  api("eu.idura:verify:2.0.4")

  testImplementation("org.jetbrains.kotlin:kotlin-test")
  testImplementation("org.mockito:mockito-core:5.0.0")
}
