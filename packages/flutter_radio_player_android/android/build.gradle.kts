import org.jetbrains.kotlin.gradle.dsl.JvmTarget

plugins {
    id("com.android.library")
}

group = "me.sithiramunasinghe.flutter.flutter_radio_player"
version = "1.0-SNAPSHOT"

val media3Version = "1.11.1"

android {
    namespace = "me.sithiramunasinghe.flutter.flutter_radio_player"
    compileSdk = 36

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    defaultConfig {
        minSdk = 24
    }

    testOptions {
        unitTests.isIncludeAndroidResources = true
        unitTests.all {
            it.useJUnitPlatform()
            it.outputs.upToDateWhen { false }
            it.testLogging {
                events("passed", "skipped", "failed", "standardOut", "standardError")
                showStandardStreams = true
            }
        }
    }
}

kotlin {
    compilerOptions {
        jvmTarget = JvmTarget.JVM_17
    }
}

dependencies {
    implementation("androidx.media3:media3-exoplayer:$media3Version")
    implementation("androidx.media3:media3-exoplayer-hls:$media3Version")
    implementation("androidx.media3:media3-session:$media3Version")
    implementation("androidx.media3:media3-common:$media3Version")
    implementation("androidx.core:core-ktx:1.18.0")
    implementation("com.google.guava:guava:33.3.1-android")

    testImplementation(platform("org.junit:junit-bom:6.1.3"))
    testImplementation("org.junit.jupiter:junit-jupiter")
    testImplementation("org.jetbrains.kotlin:kotlin-test-junit5")
    testImplementation("org.robolectric:robolectric:4.18.1")
    testImplementation("androidx.media3:media3-test-utils:$media3Version")
    testImplementation("androidx.media3:media3-test-utils-robolectric:$media3Version")
    testRuntimeOnly("org.junit.vintage:junit-vintage-engine")
    testRuntimeOnly("org.junit.platform:junit-platform-launcher")
}
