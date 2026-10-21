# Continuar con Google y con Apple

Contrato 1.4.0 · 2026-10-20

## Cómo funciona

1. El iPhone hace el inicio de sesión con el proveedor y consigue un `id_token`
   (Apple: `AuthenticationServices`; Google: OAuth 2.0 + PKCE en una
   `ASWebAuthenticationSession`, sin SDK). Ver `ios/Trainer/Trainer/Flujo/InicioConProveedor.swift`.
2. Lo manda a `POST /v1/auth/social` con el `nonce` en claro. El servidor verifica firma (JWKS del
   proveedor), emisor, audiencia, vencimiento y nonce (`backend/src/infra/proveedores.ts`), y
   acepta cada id_token **una sola vez** (se recuerda su hash hasta que vence).
3. Tres desenlaces:
   - **La identidad ya estaba vinculada** → entra.
   - **El proveedor es dueño de un correo que ya tiene cuenta** → se vincula a esa cuenta, entra,
     y al dueño le llega un mail avisando. "Dueño" = Apple, o Google con @gmail.com o dominio de
     Workspace (`hd`). Un Google creado con otro correo (p. ej. @hotmail.com) NO vincula: sigue el
     alta, que pide el código. Tampoco vincula si esa cuenta ya tiene otra persona de ese proveedor.
   - **Nadie la conoce** → `signup_required` con un permiso de 30 min. La app abre el alta con
     **nombre, apellido y correo ya escritos** (el correo fijo). Si el proveedor verificó el correo
     (casi siempre), **no hay código**: sigue el aviso de salud, la cuenta se crea con `social_token`
     y vienen los pasos de perfil (13 pasos en la barra). Sólo si el proveedor NO verificó el correo
     se pide el código, como en el alta común.
   - **Ese correo ya tiene cuenta con contraseña y el proveedor no es dueño del correo** → `conflict`:
     "Entrá con tu correo y tu contraseña".
4. Una cuenta creada así no tiene contraseña: el login con correo y contraseña contesta
   `invalid_credentials`, y «¿Olvidaste tu contraseña?» le pone una.

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
- Una cuenta existente creada con contraseña → Continuar con Google con el mismo Gmail → entra a
  esa cuenta (queda vinculada).
- Apple con "Ocultar mi correo" → el código tiene que llegar al correo real (paso 3 de Apple).

## Pendiente

- **Borrar la cuenta con Apple vinculada** (App Review 5.1.1(v)): hay que revocar los tokens de
  Apple (`/auth/revoke`). Para eso el teléfono tiene que mandar `authorizationCode` al vincular y el
  servidor guardarlo. Hoy no se hace.
- Si el permiso social vence en el último paso (más de 30 min), el aviso ofrece «Volver a continuar
  con Google/Apple»: renueva el permiso y crea la cuenta sin volver a pedir el código.
