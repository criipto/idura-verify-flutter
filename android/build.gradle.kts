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

    // Deliberately no manifestPlaceholders. Setting one here would substitute it
    // into our own manifest and ship that value in the AAR, so ${iduraDomain} and
    // ${iduraClientId} have to reach us unresolved for the consuming app to fill.
  }

  testOptions {
    unitTests {
      // Off so processDebugUnitTestManifest never runs. Unlike a library manifest,
      // the unit-test one merges dependency AARs, so it meets both our own
      // placeholders and eu.idura:verify's ${iduraDomain} and fails on all three.
      // The only alternative is giving them values here, which would then ship in
      // the AAR. Nothing in src/test needs Android resources; adding Robolectric
      // later would mean revisiting this.
      isIncludeAndroidResources = false
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
  api("eu.idura:verify:2.0.7")

  // Pigeon's generated code imports kotlinx.coroutines directly for the @async
  // method, so we declare it rather than leaning on the transitive copy that
  // eu.idura:verify happens to bring along.
  implementation("org.jetbrains.kotlinx:kotlinx-coroutines-android:1.7.1")

  testImplementation("org.jetbrains.kotlin:kotlin-test")
}
