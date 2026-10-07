-- 005_plan.sql — el ancla del plan de entrenamiento.
--
-- AGENTS.md §9.1 y docs/PROPUESTA-MOTOR.md §1: el plan es DETERMINÍSTICO. Lo que
-- se guarda NO es el plan —ése se recalcula igual cada vez— sino lo que lo fija en
-- el tiempo: desde qué día corre, en qué zona horaria, y con qué versión del motor.
-- Sin esto, el "hoy" de cada pedido correría el bloque entero y el plan del jueves
-- cambiaría el miércoles.
--
-- Cuando la persona cambia algo ESTRUCTURAL —objetivo, fecha, nivel, deporte, días
-- o zona horaria— el ancla vieja se marca reemplazada y nace una nueva desde ese
-- día. El peso o la edad no cambian la estructura: sólo las kcal, el pulso y el
-- avituallamiento, que se recalculan sobre el mismo ancla. `entrada_hash` es el
-- hash de lo estructural, y es lo que responde "¿por qué me cambió el plan?" con
-- un dato en vez de con una teoría.

create table if not exists planes (
  id                 uuid   primary key default gen_random_uuid(),
  usuario_id         uuid   not null references usuarios(id) on delete cascade,
  motor_version      text   not null,
  entrada_hash       text   not null,
  inicio_fecha       text   not null check (inicio_fecha ~ '^\d{4}-\d{2}-\d{2}$'),
  zona_horaria       text   not null,
  creado_en_ms       bigint not null,
  -- soft: el ancla vieja se conserva para poder explicar el historial.
  reemplazado_en_ms  bigint
);

-- Un solo plan vigente por persona. La carrera de dos pedidos que crean el ancla a
-- la vez la resuelve este índice, no un select previo.
create unique index if not exists planes_vigente on planes (usuario_id) where reemplazado_en_ms is null;
