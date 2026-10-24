-- 021_dispositivos_conocidos.sql — contrato 1.7.0.
--
-- Los dispositivos desde los que ya se entró a cada cuenta. Sirven para una sola
-- cosa: mandar "Nuevo inicio de sesión en tu cuenta de Stamina" cuando se entra
-- desde uno que la cuenta nunca vio (infra/plantillas-correo.ts).
--
-- `dispositivo_hash` es el SHA-256 del identificador de la instalación que manda
-- la app (`device.id`, un UUID aleatorio guardado en el llavero o el Keystore):
-- el identificador en claro no se guarda. `modelo` y `sistema` son lo que se lee
-- en el correo ("iPhone 16 · iOS 26.5"). No se guarda la IP.
--
-- El dispositivo con el que se crea la cuenta nace conocido: registrarse no
-- manda el aviso. Se borra con la cuenta, por cascada.
create table if not exists dispositivos_conocidos (
  usuario_id uuid not null references usuarios(id) on delete cascade,
  dispositivo_hash text not null,
  modelo text,
  sistema text,
  primera_vez_ms bigint not null,
  ultima_vez_ms bigint not null,
  primary key (usuario_id, dispositivo_hash)
);
