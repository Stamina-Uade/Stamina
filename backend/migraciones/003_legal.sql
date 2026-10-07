-- 003_legal.sql — la constancia de que alguien aceptó el aviso de salud.
--
-- 🛑 Esta tabla existe para una sola pregunta, y es una que se hace tarde y una
-- sola vez: "¿qué le dijimos exactamente a esta persona, y cuándo?". Por eso
-- guarda la VERSIÓN del texto y no un booleano. Un `acepto_terminos boolean` no
-- responde nada: los textos cambian, y el día que importe nadie va a poder decir
-- cuál estaba vigente.
--
-- Y por eso es una tabla de HISTORIAL, con una fila por aceptación, y no una
-- columna en `usuarios`: cuando cambien los términos y haya que pedir que los
-- acepten de nuevo, la aceptación vieja no se pisa. Las dos quedan.

create table if not exists aceptaciones_legales (
  id           bigserial primary key,
  usuario_id   uuid        not null references usuarios(id) on delete cascade,

  -- La versión de shared/datos/textos-legales.json que se le mostró.
  version      text        not null,

  -- La hora del SERVIDOR, no la del teléfono. El reloj de un teléfono lo mueve
  -- cualquiera, y una constancia con una fecha que puso la otra parte no es una
  -- constancia.
  aceptado_en_ms bigint    not null,

  -- Para qué la aceptó: 'registro' hoy; mañana 'cambio_de_terminos'.
  motivo       text        not null default 'registro',

  creado_en_ms bigint      not null
);

-- La consulta real es "todo lo que aceptó esta persona, lo más nuevo primero".
create index if not exists aceptaciones_por_usuario
  on aceptaciones_legales (usuario_id, aceptado_en_ms desc);

-- Y la otra: "quiénes aceptaron esta versión".
create index if not exists aceptaciones_por_version
  on aceptaciones_legales (version);
