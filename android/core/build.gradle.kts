// android/core/build.gradle.kts
//
// AGENTS.md §4.1: acá vive lo que comparten el teléfono y el reloj — modelos, red,
// base local y el design system.
//
// Hoy tiene una sola cosa: `tema/TokensGenerados.kt`, que produce
// `scripts/generar-tema.mjs` desde `shared/design/tokens.json` (§10.1.3). Ese
// archivo NO se edita a mano: se regenera con `npm run generar:tema`.
//
// Las versiones NO se declaran acá: salen del catálogo `gradle/libs.versions.toml`,
// que es el mismo que usa `:app`. Dos módulos con versiones distintas de Compose es
// el tipo de divergencia que aparece meses después.

plugins {
    alias(libs.plugins.android.library)
    alias(libs.plugins.kotlin.compose)
    alias(libs.plugins.kotlin.serialization)
}

android {
    namespace = "com.tecladus.trainer.core"
    compileSdk {
        version = release(36) {
            minorApiLevel = 1
        }
    }

    defaultConfig {
        minSdk = 26
    }

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_21
        targetCompatibility = JavaVersion.VERSION_21
    }

    buildFeatures {
        compose = true
    }

    // El generador escribe en src/main/kotlin. Se declara explícito para no depender
    // de que el plugin lo agregue solo.
    sourceSets {
        getByName("main") {
            kotlin.srcDir("src/main/kotlin")
        }
        getByName("test") {
            kotlin.srcDir("src/test/kotlin")
        }
    }

    testOptions {
        unitTests {
            // Los tests de este módulo son matemática pura (contraste WCAG) sobre
            // `androidx.compose.ui.graphics.Color`, que es Kotlin sin android.graphics.
            // Esto está por si alguna dependencia futura roza el framework: que
            // devuelva el default en vez de tirar "not mocked" y esconder el error real.
            isReturnDefaultValues = true
        }
    }
}

kotlin {
    jvmToolchain(21)
}

dependencies {
    // TokensGenerados.kt usa Color, Dp, TextUnit y FontWeight.
    implementation(platform(libs.androidx.compose.bom))
    implementation(libs.androidx.compose.ui)
    implementation(libs.androidx.compose.ui.graphics)
    // El design system: `api` y no `implementation` porque los tipos que expone
    // (Shape, TextStyle, los composables) aparecen en la firma de lo que :app usa.
    // Con `implementation` :app compilaria pero no podria nombrar esos tipos.
    api(libs.androidx.compose.foundation)
    api(libs.androidx.compose.material3)
    implementation(libs.androidx.compose.ui.tooling.preview)
    debugImplementation(libs.androidx.compose.ui.tooling)
    // Los modelos de red se generan desde el contrato y se deserializan solos.
    api(libs.kotlinx.serialization.json)
    // Coil dibuja una foto y un WebP animado con la misma linea, venga de
    // res/raw o de una URL. `api` porque `FuenteDeMedia` aparece en firmas que
    // :app nombra. Ver docs/MEDIA-DE-EJERCICIOS.md.
    api(libs.coil.compose)
    implementation(libs.coil.gif)
    implementation(libs.coil.network)

    testImplementation(libs.junit)
    // El reloj virtual (runTest, advanceTimeBy): los reintentos de una renovación se
    // prueban a los 5, 20 y 60 segundos sin esperarlos. Sólo en los tests.
    testImplementation(libs.kotlinx.coroutines.test)
}
