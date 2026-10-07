-- El recorrido pertenece a una actividad y se borra con la cuenta.
-- Se guarda separado para no cargar puntos GPS al listar el historial.
create table if not exists recorridos_actividades (
  usuario_id uuid not null,
  actividad_id text not null,
  puntos jsonb not null,
  actualizada_en_ms bigint not null,
  primary key (usuario_id, actividad_id),
  foreign key (usuario_id, actividad_id) references actividades (usuario_id, id) on delete cascade
);
