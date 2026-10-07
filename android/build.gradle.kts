// Top-level build file where you can add configuration options common to all sub-projects/modules.
plugins {
    alias(libs.plugins.android.application) apply false
    // Sin esta línea, :core pide com.android.library con version y Gradle contesta
    // "the plugin is already on the classpath with an unknown version": el jar de AGP
    // ya entró por android.application, pero como library nunca se declaró acá,
    // Gradle no puede verificar que la version pedida coincida.
    // Declarar los dos en la raiz con `apply false` es el patron estandar de un
    // proyecto Android multi-modulo.
    alias(libs.plugins.android.library) apply false
    alias(libs.plugins.kotlin.compose) apply false
    // Los modelos generados desde openapi.yaml se serializan solos: escribir el
    // parseo de JSON a mano es exactamente lo que 4.2 prohibe.
    alias(libs.plugins.kotlin.serialization) apply false
}
