# Stamina

Monorepo de **Stamina**, una plataforma que integra en una experiencia unificada:
- **Registro de actividad física de resistencia:** running, ciclismo, senderismo y triatlón con seguimiento GPS, métricas, ritmo y recorridos.
- **Nutrición deportiva inteligente:** cálculo periodizado de macronutrientes, calorías y registro diario con guardarraíles de salud.
- **Planes de entrenamiento y fuerza:** periodización automática hacia eventos o metas deportivas y rutinas guiadas de gimnasio.

El proyecto cuenta con clientes móviles nativos para **iOS** (iPhone y Apple Watch) y **Android** (teléfono y Wear OS), impulsados por un backend centralizado.

> **Dominio oficial:** El dominio actual del proyecto y de los servicios es **`stamina.com.ar`** (API en `https://stamina.com.ar/v1`).

---

## 📁 Estructura del Repositorio

El repositorio está organizado como un monorepo para mantener un único contrato de API y tokens de diseño compartidos:

```
Stamina/
├── backend/          # API REST en Node 22 + TypeScript + Fastify + PostgreSQL + Redis
├── ios/              # Clientes nativos iOS (SwiftUI)
│   ├── Trainer/          # App principal para iPhone (iOS 16+)
│   ├── TrainerWatch/     # App complementaria para Apple Watch (watchOS 9+)
│   └── TrainerCore/      # Paquete Swift compartido (modelos, red, offline, diseño)
├── android/          # Clientes nativos Android (Kotlin + Jetpack Compose)
│   ├── app/              # Aplicación móvil para Android
│   ├── core/             # Módulo compartido de UI, tokens y cliente de red
│   └── wear/             # Soporte para Wear OS
├── shared/           # 🔒 Fuente de verdad compartida entre clientes y backend
│   ├── api/              # openapi.yaml: Contrato formal OpenAPI 3.0 v1
│   ├── design/           # tokens.json: Design system unificado (colores, tipografía, espacios)
│   ├── datos/            # Catálogo de ejercicios, parámetros nutricionales y textos legales
│   └── landing/          # Landing page web y páginas legales (stamina.com.ar)
├── scripts/          # Generadores de modelos (Swift, Kotlin, TS), tema y validadores
└── .github/          # Automatización de CI para backend, contrato y diseño
```

---

## 🚀 Cómo Levantar y Probar Cada Módulo Localmente

Todo el desarrollo local se realiza de forma **aislada y autónoma**, sin tocar bases de datos ni servidores externos.

### 1. Backend Local (Node.js + PostgreSQL + Redis)

El backend requiere **Node.js 22+** y **Docker Desktop**. Los servicios de base de datos corren en puertos locales dedicados (Postgres en `5433` y Redis en `6380`) para evitar conflictos con otros proyectos.

#### En macOS / Linux (Bash):

```bash
cd backend
docker compose up -d
cp .env.example .env
npm install
npm run local
```

#### En Windows (PowerShell):

```powershell
cd backend
docker compose up -d
Copy-Item .env.example .env -Force
npm install
npm run local
```

`npm run local` realiza la secuencia completa en el orden correcto:
1. Compila el código TypeScript (`npm run build`).
2. Aplica las migraciones de PostgreSQL (`npm run migrar`).
3. Siembra el catálogo de ejercicios en la base de datos (`npm run sembrar`).
4. Inicia el servidor en `http://localhost:8082`.

Para comprobar que el servicio está activo:

```powershell
curl.exe http://localhost:8082/v1/health
```

#### Pruebas unitarias y de integración del backend:

```bash
cd backend
npm run test:unit          # Pruebas unitarias (sin necesidad de base de datos)
npm run test:integracion   # Pruebas de integración (requiere docker compose activo)
```

---

### 2. Cliente iOS & Apple Watch

- **Requisitos:** macOS con Xcode 16.0 o superior.
- **Ubicación:** `ios/Trainer/Trainer.xcodeproj`.

#### Ejecución y pruebas:
1. Abrir `ios/Trainer/Trainer.xcodeproj` en Xcode.
2. Seleccionar el esquema `Trainer` y un simulador de iPhone (por ejemplo, iPhone 16 Pro).
3. **Apuntar al backend local:** En modo `DEBUG`, puedes apuntar al backend local pasando el argumento `-apiBase http://localhost:8082/v1` en:
   * **Product › Scheme › Edit Scheme › Run › Arguments Passed On Launch**.
4. Para ejecutar las pruebas unitarias del paquete compartido:
   ```bash
   cd ios/TrainerCore
   swift test
   ```

---

### 3. Cliente Android

- **Requisitos:** Android Studio Hedgehog o superior con JDK 17+.
- **Ubicación:** Carpeta `android/`.

#### Ejecución y pruebas:
1. Abrir la carpeta `android/` en Android Studio.
2. Dejar que Gradle sincronice las dependencias.
3. Para apuntar al backend local desde el emulador de Android, agregar en `android/local.properties`:
   ```properties
   trainer.apiBase=http://10.0.2.2:8082/v1
   ```
4. Para correr los tests unitarios de Android:
   ```bash
   cd android
   ./gradlew :core:test :app:testDebugUnitTest
   ```

---

### 4. Scripts de Generación de Código y Tooling

Desde la raíz del repositorio se ejecutan las herramientas que sincronizan el contrato `openapi.yaml` y los tokens con los clientes:

```bash
npm install                  # Instala dependencias de herramientas
npm run lint:contrato        # Valida la especificación OpenAPI con Redocly
npm run generar:esquemas     # Genera validadores de esquemas para el backend
npm run generar:modelos-swift   # Genera modelos de datos en Swift (TrainerCore)
npm run generar:modelos-kotlin  # Genera modelos de datos en Kotlin (Android core)
npm run generar:tema         # Genera el tema y paletas para Compose y SwiftUI
npm run verificar:tokens     # Verifica que ningún archivo tenga colores o fuentes hardcodeadas
npm run test:scripts         # Corre las pruebas del sistema de tooling
```

---

## 🔒 Reglas de Seguridad y Flujo de Contribución

Para proteger la integridad del servidor y la base de datos de producción:

1. **Aislamiento absoluto:**
   * El código desarrollado localmente **nunca interactúa directamente con el servidor de producción**. Todo cambio se prueba primero contra el entorno local (`localhost:8082`).
   * No existen scripts de despliegue directo expuestos en el repositorio.

2. **Flujo de trabajo mediante Pull Requests (PR):**
   * **La rama `main` está protegida.** Nadie puede hacer push directo a `main` ni realizar force-push (`git push --force`).
   * Para agregar o modificar código, crea una rama temática (`git checkout -b feature/mi-cambio` o `fix/mi-correccion`).
   * Al finalizar tus cambios, abre un **Pull Request** hacia `main`.
   * **Revisión obligatoria:** Ningún cambio se incorporará a la rama principal sin la revisión y aprobación previa del maintainer.

3. **Política de Secretos y Archivos Sensibles:**
   * Está estrictamente prohibido commitear archivos `.env` reales, certificados, claves SSH/PEM (`*.pem`, `*.key`), credenciales de bases de datos o tokens de acceso.
   * El archivo `.gitignore` está configurado para excluir automáticamente archivos de entorno y secretos.
   * En caso de requerir nuevas variables de configuración, declararlas en `backend/.env.example` con valores de ejemplo genéricos para desarrollo local.

4. **Calidad y Verificación:**
   * Antes de abrir un PR, asegúrate de que pasen los tests locales (`npm run test:scripts`, tests de backend, tests de iOS o Android según corresponda) y que `npm run verificar:tokens` no arroje errores de tokens de diseño.
