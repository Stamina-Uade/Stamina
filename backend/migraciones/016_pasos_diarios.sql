-- Los pasos de cada día de calendario LOCAL de la persona (contrato 1.3.0).
--
-- `fecha` es el día como lo ve el teléfono que contó los pasos, sin zona: Apple
-- Salud y Health Connect suman por día local, y un instante epoch no dice de qué
-- día es sin saber dónde estaba la persona.
--
-- Una fila por día. Gana la escritura con el `actualizado_ms` más nuevo (ver
-- dominios/pasos/repositorio.ts): la cuenta de hoy crece a lo largo del día, y un
-- reintento viejo que llega tarde no pisa lo que ya se corrigió.
create table if not exists pasos_diarios (
  usuario_id uuid not null references usuarios(id) on delete cascade,
  fecha date not null,
  pasos integer not null check (pasos between 0 and 200000),
  fuente text not null check (fuente in ('healthkit', 'manual', 'health_connect')),
  actualizado_ms bigint not null,
  primary key (usuario_id, fecha)
);
