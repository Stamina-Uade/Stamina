pluginManagement {
    repositories {
        google {
            content {
                includeGroupByRegex("com\\.android.*")
                includeGroupByRegex("com\\.google.*")
                includeGroupByRegex("androidx.*")
            }
        }
        mavenCentral()
        gradlePluginPortal()
    }
}
plugins {
    id("org.gradle.toolchains.foojay-resolver-convention") version "1.0.0"
}
dependencyResolutionManagement {
    repositoriesMode.set(RepositoriesMode.FAIL_ON_PROJECT_REPOS)
    repositories {
        google()
        mavenCentral()
    }
}

rootProject.name = "Trainer"
include(":app")

// AGENTS.md §4.1: core/ es lo que comparten app y wear — modelos, red, base local
// y el design system. Hasta ahora existía como carpeta pero NO como módulo, así que
// TokensGenerados.kt estaba ahí sin que nada lo compilara.
include(":core")
