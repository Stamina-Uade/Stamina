import java.util.Properties

plugins {
    alias(libs.plugins.android.application)
    alias(libs.plugins.kotlin.compose)
}

/**
 * La base de la API, según el build. Llega a la app como `BuildConfig.API_BASE`.
 *
 * - **release**: el servidor, siempre ([apiBaseDelServidor], hoy staging). No se puede
 *   sobreescribir: un APK publicado que apunte a otro lado no tiene arreglo sin publicar
 *   otro.
 * - **debug**: la misma por defecto, para que Run en un teléfono real ande sin tocar
 *   nada. Para el backend local desde el emulador:
 *   `-Ptrainer.apiBase=http://10.0.2.2:8082/v1`, o la misma clave en
 *   `local.properties`, que no se commitea (docs/CORRER-LOCAL.md §4).
 *
 * 🛑 Se valida acá, al configurar, y no en la app. Sin el `/v1` cada llamada se lleva un
 * 404 con el sobre bien formado —ya pasó una vez—, y un `http://` a otro host que no sea
 * `10.0.2.2` lo bloquea la configuración de red y se ve como «sin conexión». Mejor que
 * el build falle diciendo por qué.
 */
/**
 * El servidor con el que habla la app. UNA constante, para cambiarlo en un solo lugar.
 *
 * 🛑 **Hoy es staging, no producción.** `trainer.karplast.com.ar` es el host que el
 * contrato (`shared/api/openapi.yaml`, `servers`) declara como staging, en el EC2
 * compartido (decisión 0011). El dominio de producción no está decidido:
 * un release que salga así habla con staging. Cuando exista, se cambia acá.
 */
val apiBaseDelServidor = "https://stamina.com.ar/v1"

val apiBaseDeDebug: String = run {
    val locales = Properties()
    val archivo = rootProject.file("local.properties")
    if (archivo.isFile) archivo.inputStream().use { locales.load(it) }
    val elegida = (findProperty("trainer.apiBase") as String?)
        ?: locales.getProperty("trainer.apiBase")
        ?: apiBaseDelServidor
    val valida = Regex("""^(https://[^/\s"]+|http://10\.0\.2\.2(:\d+)?)/v1$""")
    require(valida.matches(elegida)) {
        "trainer.apiBase=«$elegida» no sirve. Tiene que ser https://<host>/v1, o " +
            "http://10.0.2.2:<puerto>/v1 para el backend local desde el emulador: el " +
            "tráfico en claro sólo se permite con 10.0.2.2, y sin el /v1 todo da 404."
    }
    elegida
}

android {
    namespace = "com.tecladus.trainer"
    compileSdk {
        version = release(36) {
            minorApiLevel = 1
        }
    }

    defaultConfig {
        applicationId = "com.tecladus.trainer"
        minSdk = 26
        targetSdk = 36
        versionCode = 1
        versionName = "1.0"

        testInstrumentationRunner = "androidx.test.runner.AndroidJUnitRunner"
    }

    buildTypes {
        release {
            optimization {
                enable = false
            }
            buildConfigField("String", "API_BASE", "\"$apiBaseDelServidor\"")
        }
        getByName("debug") {
            buildConfigField("String", "API_BASE", "\"$apiBaseDeDebug\"")
        }
    }
    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_21
        targetCompatibility = JavaVersion.VERSION_21
    }
    buildFeatures {
        compose = true
        // `API_BASE`, y el `VERSION_CODE` que la puerta de versión le manda al servidor.
        buildConfig = true
    }

    // La UI NUEVA va en src/main/kotlin; la original se queda en src/main/java hasta
    // que se borre (AGENTS.md 1.2). No es cosmetico: `scripts/verificar-tokens.mjs`
    // excluye src/main/java y NO excluye src/main/kotlin, asi que el limite entre lo
    // que se verifica y lo que no es una carpeta y no la memoria de nadie.
    sourceSets {
        getByName("main") {
            kotlin.srcDir("src/main/kotlin")
        }
    }
}

kotlin {
    jvmToolchain(21)
}

dependencies {
    // El design system y lo compartido con el reloj (§4.1).
    implementation(project(":core"))

    implementation(platform(libs.androidx.compose.bom))
    implementation(libs.androidx.activity.compose)
    implementation(libs.androidx.compose.material3)
    implementation(libs.androidx.compose.ui)
    implementation(libs.androidx.compose.ui.graphics)
    implementation(libs.androidx.compose.ui.tooling.preview)
    implementation(libs.androidx.core.ktx)
    implementation(libs.androidx.lifecycle.runtime.ktx)
    // Reconocimiento de productos: ambos modelos viajan dentro del APK, funcionan sin
    // conexión y no tienen costo ni requieren Play Services.
    implementation(libs.mlkit.barcode.scanning)
    implementation(libs.mlkit.image.labeling)
    testImplementation(libs.junit)
    // El Main de mentira de las corrutinas: prueba en la JVM que la puerta de versión se
    // vuelve a preguntar al volver a primer plano. Sólo en los tests.
    testImplementation(libs.kotlinx.coroutines.test)
    androidTestImplementation(platform(libs.androidx.compose.bom))
    androidTestImplementation(libs.androidx.compose.ui.test.junit4)
    androidTestImplementation(libs.androidx.espresso.core)
    androidTestImplementation(libs.androidx.junit)
    debugImplementation(libs.androidx.compose.ui.test.manifest)
    debugImplementation(libs.androidx.compose.ui.tooling)
}
