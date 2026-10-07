-- 001_auth.sql — cuentas, sesiones, códigos y la puerta de versión.
--
-- AGENTS.md §11:
--   - el esquema se versiona en migraciones numeradas, en el repositorio
--   - nunca DELETE físico de entidades de usuario: soft-delete y filtro en TODAS
--     las lecturas. Las excepciones se listan; acá la única es la purga de códigos
--     y sesiones vencidos, que no son entidades de usuario sino material efímero.
--   - en producción, los índices con CREATE INDEX CONCURRENTLY

-- Para gen_random_uuid(). Viene con Postgres 13+.
create extension if not exists pgcrypto;

-- ---------------------------------------------------------------- usuarios --
create table if not exists usuarios (
  id                  uuid primary key default gen_random_uuid(),
  -- Se guarda normalizado en minúsculas: la comparación tiene que ser exacta y
  -- no depender de cómo lo tipeó la persona.
  email               text        not null,
  password_hash       text        not null,
  -- soft-delete (§11). TODA lectura filtra por esto.
  borrado_en_ms       bigint,
  creado_en_ms        bigint      not null,
  actualizado_en_ms   bigint      not null
);

-- Único sólo entre las cuentas vivas: si alguien borra su cuenta, esa dirección
-- se puede volver a registrar.
create unique index if not exists usuarios_email_vivo
  on usuarios (email) where borrado_en_ms is null;

-- ------------------------------------------------------------------ perfil --
-- Separado de `usuarios` a propósito: acá viven los datos de salud de §8 (peso,
-- altura, sexo biológico, nacimiento) y tenerlos en su propia tabla hace posible
-- cifrarlos en reposo, exportarlos y borrarlos como una unidad, sin tocar las
-- credenciales.
create table if not exists perfiles (
  usuario_id                     uuid primary key references usuarios(id) on delete cascade,
  nombre                         text,
  apellido                       text,
  nacimiento_ms                  bigint,
  sexo_biologico                 text check (sexo_biologico in ('femenino','masculino','sin_declarar')),
  peso_g                         integer check (peso_g between 20000 and 400000),
  altura_mm                      integer check (altura_mm between 500 and 2600),
  deporte                        text check (deporte in ('running','ciclismo','trekking','triatlon')),
  nivel                          text check (nivel in ('principiante','intermedio','avanzado')),
  objetivo                       text check (objetivo in ('c5k','c10k','media_maraton','maraton','trail_montana','triatlon_olimpico','volver_sin_lesiones')),
  objetivo_fecha_ms              bigint,
  -- [{weekday:1..7, minute_of_day:0..1439}]. jsonb y no una tabla aparte porque
  -- son como mucho 7 filas que se leen y se escriben siempre juntas.
  dias_entrenamiento             jsonb not null default '[]'::jsonb,
  zona_horaria                   text,
  sistema_unidades               text check (sistema_unidades in ('metrico','imperial')),
  descargo_medico_aceptado_en_ms bigint,
  actualizado_en_ms              bigint not null
);

-- ---------------------------------------------------------------- sesiones --
-- Una fila por refresh token. §12: se guarda HASHEADO, nunca en claro.
create table if not exists sesiones (
  id                 uuid primary key default gen_random_uuid(),
  usuario_id         uuid not null references usuarios(id) on delete cascade,
  -- Todos los refresh que salen de una misma cadena de rotación comparten familia.
  -- Si llega uno ya usado, se revoca la familia entera: es la señal de que alguien
  -- lo copió.
  familia_id         uuid not null,
  refresh_hash       text not null,
  creado_en_ms       bigint not null,
  vence_en_ms        bigint not null,
  usado_en_ms        bigint,
  revocado_en_ms     bigint,
  revocado_motivo    text
);

create unique index if not exists sesiones_refresh_hash on sesiones (refresh_hash);
create index if not exists sesiones_usuario on sesiones (usuario_id) where revocado_en_ms is null;
create index if not exists sesiones_familia on sesiones (familia_id);
-- Para la purga de vencidos.
create index if not exists sesiones_vence on sesiones (vence_en_ms);

-- ------------------------------------------------------- códigos por correo --
-- Registro y recuperación. El código se guarda HASHEADO igual que un token: si
-- alguien lee la tabla, no se lleva códigos usables.
create table if not exists codigos_correo (
  id             uuid primary key default gen_random_uuid(),
  email          text not null,
  proposito      text not null check (proposito in ('registro','recuperacion')),
  codigo_hash    text not null,
  intentos       integer not null default 0,
  creado_en_ms   bigint not null,
  vence_en_ms    bigint not null,
  consumido_en_ms bigint,
  -- Cuándo se puede pedir otro (60 s), para que el reenvío no sea un amplificador
  -- de mails.
  reenvio_desde_ms bigint not null
);

create index if not exists codigos_email_proposito
  on codigos_correo (email, proposito) where consumido_en_ms is null;
create index if not exists codigos_vence on codigos_correo (vence_en_ms);

-- ------------------------------------------------- tokens de paso intermedio --
-- El token de registro (paso 2 -> 3) y el de recuperación (verify -> reset).
-- Hasheados, de vida corta, y de un solo uso.
create table if not exists tokens_paso (
  token_hash    text primary key,
  email         text not null,
  proposito     text not null check (proposito in ('registro','recuperacion')),
  creado_en_ms  bigint not null,
  vence_en_ms   bigint not null,
  usado_en_ms   bigint
);

create index if not exists tokens_paso_vence on tokens_paso (vence_en_ms);

-- -------------------------------------------------- puerta de versión mínima --
-- 🛑 AGENTS.md §5.1 y docs/API.md §4: el mínimo se cambia SIN DESPLEGAR. Por eso
-- está en una tabla y no en una constante compilada ni en una variable de entorno.
-- Cambiar el mínimo es un UPDATE.
create table if not exists app_version_gate (
  plataforma        text primary key check (plataforma in ('android','ios','wear','watchos')),
  minimo_build      bigint not null,
  recomendado_build bigint not null,
  codigo_mensaje    text,
  mensaje           text,
  store_url         text,
  actualizado_en_ms bigint not null
);

-- Valores de arranque: mínimo 1 = no bloquea a nadie. El día que haya que cortar
-- una versión vieja, es un UPDATE de una fila.
insert into app_version_gate (plataforma, minimo_build, recomendado_build, codigo_mensaje, mensaje, store_url, actualizado_en_ms)
values
  ('android', 1, 1, null, null, null, (extract(epoch from now()) * 1000)::bigint),
  ('ios',     1, 1, null, null, null, (extract(epoch from now()) * 1000)::bigint),
  ('wear',    1, 1, null, null, null, (extract(epoch from now()) * 1000)::bigint),
  ('watchos', 1, 1, null, null, null, (extract(epoch from now()) * 1000)::bigint)
on conflict (plataforma) do nothing;
