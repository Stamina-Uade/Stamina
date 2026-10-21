-- 017_identidades_sociales.sql — "Continuar con Google" y "Continuar con Apple".
--
-- Una cuenta puede no tener contraseña: la que nació entrando con Google o Apple.
-- Para esa cuenta el login con correo y contraseña contesta `invalid_credentials`
-- (con la verificación de descarte, igual que un correo que no existe), y
-- "¿Olvidaste tu contraseña?" sigue sirviendo para ponerle una.
alter table usuarios alter column password_hash drop not null;

-- Qué persona de qué proveedor entra a qué cuenta. `sujeto` es el `sub` del
-- id_token: el id estable de la persona en ese proveedor. NO se usa el correo para
-- reconocerla: en Apple puede ser un relay privado, y en los dos puede cambiar.
create table if not exists identidades_sociales (
  id            uuid primary key default gen_random_uuid(),
  usuario_id    uuid not null references usuarios(id) on delete cascade,
  proveedor     text not null check (proveedor in ('google', 'apple')),
  sujeto        text not null,
  -- El correo que dio el proveedor al vincular. Informativo: no decide nada.
  email         text,
  creado_en_ms  bigint not null,
  unique (proveedor, sujeto)
);

create index if not exists identidades_sociales_usuario on identidades_sociales (usuario_id);
