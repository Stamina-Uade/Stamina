-- 002_idempotencia.sql — la tabla de claves de idempotencia.
--
-- AGENTS.md §5.2: toda mutación que el cliente pueda reintentar lleva una clave
-- generada por el cliente, y el servidor devuelve el mismo resultado en vez de
-- crear un duplicado. La app se usa en un sótano de gimnasio y en la ruta.
--
-- La tabla existe DESDE AHORA aunque la v1 casi no la use: donde va a pesar es en
-- la fase 7 —registrar una serie, cerrar una sesión, guardar una comida— y crearla
-- entonces es más caro que crearla ahora, porque para entonces ya va a haber
-- sesiones duplicadas del martes.

create table if not exists idempotencia (
  -- La clave la genera el cliente y llega en el header Idempotency-Key. Se guarda
  -- junto con el usuario y la ruta: la misma clave de dos personas distintas, o
  -- para dos endpoints distintos, son cosas distintas.
  clave          text   not null,
  usuario_id     uuid   not null references usuarios(id) on delete cascade,
  metodo_ruta    text   not null,
  -- Hash del cuerpo: si llega la misma clave con un cuerpo distinto, no es un
  -- reintento, es un error del cliente y hay que gritarlo (409).
  cuerpo_hash    text   not null,
  http_status    integer,
  respuesta      jsonb,
  creado_en_ms   bigint not null,
  vence_en_ms    bigint not null,
  primary key (clave, usuario_id, metodo_ruta)
);

create index if not exists idempotencia_vence on idempotencia (vence_en_ms);
