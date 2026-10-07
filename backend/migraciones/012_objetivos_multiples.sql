-- Los clientes anteriores conservan el objetivo principal en perfiles.
-- Los adicionales tienen identidad propia y ancla de plan independiente.
create table if not exists objetivos_usuario (
  id uuid primary key default gen_random_uuid(),
  usuario_id uuid not null references usuarios(id) on delete cascade,
  objetivo text not null check (objetivo in
    ('c5k','c10k','media_maraton','maraton','trail_montana','triatlon_olimpico','volver_sin_lesiones')),
  objetivo_fecha_ms bigint,
  orden integer not null check (orden between 1 and 9),
  creado_en_ms bigint not null,
  actualizado_en_ms bigint not null,
  completado_en_ms bigint
);
create index if not exists objetivos_usuario_activos
  on objetivos_usuario(usuario_id, orden) where completado_en_ms is null;

-- El índice de planes principal se conserva: la API anterior sigue funcionando
-- mientras se aplica la migración y se activa la versión nueva.
create table if not exists planes_objetivos (
  id uuid primary key default gen_random_uuid(),
  usuario_id uuid not null references usuarios(id) on delete cascade,
  objetivo_id uuid not null references objetivos_usuario(id) on delete cascade,
  motor_version text not null,
  entrada_hash text not null,
  inicio_fecha text not null check (inicio_fecha ~ '^\d{4}-\d{2}-\d{2}$'),
  zona_horaria text not null,
  creado_en_ms bigint not null,
  reemplazado_en_ms bigint
);
create unique index if not exists planes_objetivos_vigente
  on planes_objetivos(objetivo_id) where reemplazado_en_ms is null;
