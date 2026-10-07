-- 004_catalogo.sql — el catálogo de ejercicios, como DATO.
--
-- AGENTS.md §9.1: "El catálogo de ejercicios es dato, no código. Un ejercicio
-- nuevo se agrega sin desplegar." La semilla es shared/datos/ejercicios.json y la
-- carga `npm run sembrar`, que es idempotente: se corre en cada despliegue y sólo
-- escribe lo que cambió.
--
-- Un ejercicio que sale del catálogo NO se borra: se marca retirado. Las series que
-- alguien registró con ese ejercicio lo siguen nombrando, y un DELETE las dejaría
-- apuntando a nada (§11: nada de borrado físico de lo que la persona registró).

create table if not exists ejercicios (
  id                 text   primary key check (id ~ '^[a-z0-9][a-z0-9-]{1,63}$'),
  -- {"es-AR": "...", "en-US": "...", "pt-BR": null, "ja-JP": null}, tal cual la semilla
  nombres            jsonb  not null,
  patron             text   not null,
  equipamiento       text   not null,
  lado               text   not null,
  unidad             text   not null,
  -- [{"id": "pectoral", "rol": "principal"}]
  musculos           jsonb  not null,
  -- [{"id": "flexiones", "tipo": "mismo-patron"}]
  sustitutos         jsonb  not null,
  -- ["hombro", "codo"]: qué CARGA el ejercicio. No es un criterio clínico (§9.1).
  articulaciones     jsonb  not null,
  version_catalogo   text   not null,
  actualizado_en_ms  bigint not null,
  retirado_en_ms     bigint
);

-- Los nombres de patrones, equipamiento, músculos y articulaciones, por idioma.
create table if not exists diccionario_ejercicios (
  tipo     text  not null check (tipo in ('patron', 'equipamiento', 'musculo', 'articulacion')),
  id       text  not null,
  nombres  jsonb not null,
  primary key (tipo, id)
);
