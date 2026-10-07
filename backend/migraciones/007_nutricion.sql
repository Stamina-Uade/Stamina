-- 007_nutricion.sql — comidas, y los dos datos de perfil que pidió el motor.

-- Qué equipamiento tiene la persona, con los ids de shared/datos/ejercicios.json.
-- null = no lo dijo, y el motor asume "sin equipo" (docs/PROPUESTA-MOTOR.md §4.3):
-- un plan que pide una barra a quien no la tiene no se hace.
alter table perfiles add column if not exists equipamiento jsonb;

-- 🛑 AGENTS.md §9.2: embarazo y lactancia están FUERA del flujo genérico de
-- nutrición. Para saber quién está en ese caso hay que preguntarlo. null = no lo
-- dijo, y sin esa respuesta el servidor NO da objetivos calóricos a quien podría
-- estarlo. Es un dato de salud (§8): va a esta tabla y no a otra.
alter table perfiles add column if not exists embarazo_o_lactancia boolean;

create table if not exists comidas (
  usuario_id         uuid    not null references usuarios(id) on delete cascade,
  -- id del cliente: la comida se registra sin señal y el PUT es idempotente.
  id                 text    not null check (id ~ '^[A-Za-z0-9-]{8,64}$'),
  comida_en_ms       bigint  not null,
  nombre             text    not null check (char_length(nombre) between 1 and 120),
  kcal               integer not null check (kcal between 0 and 5000),
  carbohidratos_g    integer not null check (carbohidratos_g between 0 and 1000),
  proteina_g         integer not null check (proteina_g between 0 and 1000),
  grasa_g            integer not null check (grasa_g between 0 and 1000),
  creada_en_ms       bigint  not null,
  actualizada_en_ms  bigint  not null,
  borrada_en_ms      bigint,
  primary key (usuario_id, id)
);
create index if not exists comidas_por_momento
  on comidas (usuario_id, comida_en_ms) where borrada_en_ms is null;
