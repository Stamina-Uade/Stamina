-- 006_entrenamientos.sql — sesiones de gimnasio, series y actividades.
--
-- Las series son la decisión 0006 del lado del servidor:
--   1. la identidad es determinística: (persona, sesión, ejercicio, número)
--   2. `hecha` es monotónica: ninguna sincronización la desmarca
--   3. la fusión es por FILA COMPLETA, y gana la que llegó ÚLTIMA AL SERVIDOR
-- La regla vive en dominios/gimnasio/fusion.ts: es la misma función que
-- ios/TrainerCore/…/Sincronizacion/SerieRegistrada.swift, con los mismos casos.
--
-- `series_gimnasio` es el estado; `series_gimnasio_historial` es TODO lo que llegó,
-- append-only. Es lo que deja auditar una serie corregida (decisión 0006 §2) y lo
-- que se poda a los 90 días (decisión 0006, "Lo que se cerró").

create table if not exists sesiones_gimnasio (
  usuario_id         uuid   not null references usuarios(id) on delete cascade,
  sesion_id          text   not null check (sesion_id ~ '^[a-z0-9][a-z0-9-]{0,63}$'),
  -- YYYY-MM-DD cuando el id es gym-YYYY-MM-DD (ClaveDeSerie.sesionDeGimnasio). Si
  -- el id es otra cosa, null: el servidor no le inventa una fecha.
  fecha              text   check (fecha ~ '^\d{4}-\d{2}-\d{2}$'),
  creada_en_ms       bigint not null,
  actualizada_en_ms  bigint not null,
  primary key (usuario_id, sesion_id)
);
create index if not exists sesiones_gimnasio_orden
  on sesiones_gimnasio (usuario_id, actualizada_en_ms desc, sesion_id desc);

create table if not exists series_gimnasio (
  usuario_id               uuid    not null,
  sesion_id                text    not null,
  ejercicio_id             text    not null check (ejercicio_id ~ '^[a-z0-9][a-z0-9-]{0,63}$'),
  numero                   integer not null check (numero between 1 and 50),
  hecha                    boolean not null,
  repeticiones             integer not null check (repeticiones between 0 and 1000),
  -- gramos (AGENTS.md §5). null = peso corporal.
  peso_g                   integer check (peso_g between 0 and 1000000),
  salteada                 boolean not null,
  es_extra                 boolean not null,
  registrada_local_ms      bigint  not null,
  recibida_en_servidor_ms  bigint  not null,
  dispositivo              text    not null check (dispositivo in ('telefono', 'reloj')),
  primary key (usuario_id, sesion_id, ejercicio_id, numero),
  foreign key (usuario_id, sesion_id) references sesiones_gimnasio (usuario_id, sesion_id) on delete cascade
);
-- La columna PREVIA de la rutina: la última vez que la persona hizo ese ejercicio.
create index if not exists series_gimnasio_por_ejercicio
  on series_gimnasio (usuario_id, ejercicio_id, recibida_en_servidor_ms desc);

create table if not exists series_gimnasio_historial (
  id                       bigserial primary key,
  usuario_id               uuid    not null references usuarios(id) on delete cascade,
  sesion_id                text    not null,
  ejercicio_id             text    not null,
  numero                   integer not null,
  hecha                    boolean not null,
  repeticiones             integer not null,
  peso_g                   integer,
  salteada                 boolean not null,
  es_extra                 boolean not null,
  registrada_local_ms      bigint  not null,
  recibida_en_servidor_ms  bigint  not null,
  dispositivo              text    not null
);
create index if not exists series_historial_poda on series_gimnasio_historial (recibida_en_servidor_ms);

create table if not exists actividades (
  usuario_id          uuid    not null references usuarios(id) on delete cascade,
  -- id del cliente: la actividad nace sin señal y el PUT con el mismo id es
  -- idempotente por construcción (AGENTS.md §5.2).
  id                  text    not null check (id ~ '^[A-Za-z0-9-]{8,64}$'),
  deporte             text    not null check (deporte in ('running', 'ciclismo', 'natacion', 'trekking', 'fuerza', 'otro')),
  inicio_ms           bigint  not null,
  duracion_s          integer not null check (duracion_s between 1 and 172800),
  distancia_m         integer check (distancia_m between 0 and 1000000),
  desnivel_m          integer check (desnivel_m between 0 and 20000),
  fc_media_lpm        integer check (fc_media_lpm between 30 and 250),
  fc_max_lpm          integer check (fc_max_lpm between 30 and 250),
  kcal                integer check (kcal between 0 and 20000),
  dispositivo         text    not null check (dispositivo in ('telefono', 'reloj')),
  creada_en_ms        bigint  not null,
  actualizada_en_ms   bigint  not null,
  -- soft-delete (AGENTS.md §11): TODA lectura filtra por esto.
  borrada_en_ms       bigint,
  primary key (usuario_id, id)
);
create index if not exists actividades_orden
  on actividades (usuario_id, inicio_ms desc, id desc) where borrada_en_ms is null;
