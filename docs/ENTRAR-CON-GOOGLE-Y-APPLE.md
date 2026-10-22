# Continuar con Google y con Apple

Contrato 1.4.0 · 2026-10-20 · actualizado con la 1.6.0 (2026-10-22)

## Cómo funciona

1. El iPhone hace el inicio de sesión con el proveedor y consigue un `id_token`
   (Apple: `AuthenticationServices`; Google: OAuth 2.0 + PKCE en una
   `ASWebAuthenticationSession`, sin SDK). Ver `ios/Trainer/Trainer/Flujo/InicioConProveedor.swift`.
2. Lo manda a `POST /v1/auth/social` con el `nonce` en claro. El servidor verifica firma (JWKS del
   proveedor), emisor, audiencia, vencimiento y nonce (`backend/src/infra/proveedores.ts`), y
   acepta cada id_token **una sola vez** (se recuerda su hash hasta que vence).
3. Tres desenlaces:
   - **La identidad ya estaba vinculada** → entra.
   - **Ese correo ya tiene una cuenta CON contraseña** (1.6.0) → `account_link_available` con un
     permiso de 10 minutos. La app pregunta "¿Vincular tu cuenta de Google?" (o Apple): "Vincular"
     llama a `POST /auth/social/link`, entra, y desde ahí la cuenta entra con la contraseña o con el
     proveedor; al dueño le llega un mail avisando. Si el proveedor NO es dueño del correo ("dueño" =
     Apple, o Google con @gmail.com o dominio de Workspace `hd`), la alerta pide primero la
     contraseña de la cuenta. "Ahora no" deja a la persona en Iniciar sesión.
   - **Ese correo tiene una cuenta SIN contraseña** (nació con el otro proveedor) y el proveedor es
     dueño del correo → se vincula sola, como antes. Si esa cuenta ya tiene otra persona de ese
     proveedor, `conflict`.
   - **Nadie la conoce** → `signup_required` con un permiso de 30 min. La app abre el alta con
     **nombre, apellido y correo ya escritos** (el correo fijo). Si el proveedor verificó el correo
     (casi siempre), **no hay código**: sigue "Antes de empezar", la cuenta se crea con
     `social_token` y vienen los pasos de perfil (10 pasos en la barra; 11 con el código). Sólo si el
     proveedor NO verificó el correo se pide el código, como en el alta común.
4. Una cuenta creada así no tiene contraseña: el login con correo y contraseña contesta
   `password_not_set` con el proveedor (1.6.0: "Esta cuenta entra con Google"), y «¿Olvidaste tu
   contraseña?» le pone una.
5. Con la identidad ya vinculada, una cuenta desactivada o por borrarse contesta
   `account_deactivated` / `account_pending_deletion`, igual que el login con contraseña.

Tabla nueva: `identidades_sociales` (migración `017_identidades_sociales.sql`, que además deja
`usuarios.password_hash` aceptar `null`).

## Lo que hay que hacer a mano (una sola vez)

### Apple
1. developer.apple.com → Identifiers → `com.tecladus.Trainer` → activar **Sign in with Apple**.
2. Xcode → target Trainer → Signing & Capabilities: tiene que aparecer **Sign in with Apple** (el
   entitlement ya está en `Trainer.entitlements`; si Xcode lo marca en rojo, "+ Capability").
3. Para que el código llegue a quien elige **"Ocultar mi correo"** (relay `@privaterelay.appleid.com`):
   developer.apple.com → Services → **Sign in with Apple for Email Communication** → registrar el
   dominio `stamina.com.ar` y el remitente `no-reply@stamina.com.ar`. El dominio tiene que tener
   SPF (y DKIM de SES) en regla. Sin esto, el relay de Apple descarta el correo.
4. El servidor acepta por defecto el bundle `com.tecladus.Trainer` (`APPLE_CLIENT_IDS`).

### Google
1. console.cloud.google.com → APIs y servicios → **Pantalla de consentimiento OAuth**: tipo
   Externo, nombre "Stamina", logo, dominio `stamina.com.ar`, scopes `openid email profile`.
   Publicarla (si queda en "Prueba", sólo entran los usuarios de prueba cargados).
2. Credenciales → Crear ID de cliente OAuth → **iOS**, bundle `com.tecladus.Trainer`. Copiar el
   client ID (`…apps.googleusercontent.com`).
3. Pegarlo en `ios/Trainer/Trainer-Info.plist` → `GoogleClientID`.
4. En el servidor, `/etc/trainer/trainer.env`: `GOOGLE_CLIENT_IDS=<ese client id>` y reiniciar
   `trainer-api`. Sin esto el botón contesta "todavía no está configurado".
5. Logo oficial: bajar la "G" de la guía de marca de Google
   (developers.google.com/identity/branding-guidelines) y agregarla en `Assets.xcassets` con el
   nombre **`LogoGoogle`**. Mientras no esté, el botón muestra una "G" neutra.

## Probar

- Cuenta nueva con Google → tiene que abrir el alta con nombre/apellido/correo cargados → llega el
  mail con el código → aviso → perfil. Cerrar sesión y volver a entrar con Google: entra derecho.
- Una cuenta existente creada con contraseña → Continuar con Google con el mismo Gmail → aparece
  "¿Vincular tu cuenta de Google?" → "Vincular" entra a esa cuenta (queda vinculada). Con un Google
  armado sobre un @hotmail, la misma alerta pide la contraseña de la cuenta.
- Apple con "Ocultar mi correo" → el código tiene que llegar al correo real (paso 3 de Apple).

## Pendiente

- **Borrar la cuenta con Apple vinculada** (App Review 5.1.1(v)): hay que revocar los tokens de
  Apple (`/auth/revoke`). Para eso el teléfono tiene que mandar `authorizationCode` al vincular y el
  servidor guardarlo. Hoy no se hace.
- Si el permiso social vence (más de 30 min), la app no deja validar, reenviar ni seguir: alerta
  "Pasó demasiado tiempo · Vuelve a continuar con Google" con el botón «Volver a continuar con
  Google/Apple», que renueva el permiso (y en "Antes de empezar" crea la cuenta sin volver a pedir
  el código).
