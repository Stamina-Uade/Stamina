-- 020_dias_hechos_a_mano.sql — contrato 1.7.0 ("Adentro de la app", decisión de
-- Iván del 2026-10-23).
--
-- Un día del plan que tocaba entrenar, pasó sin una salida registrada, y la
-- persona dice "lo hice" (la salida existió pero no se grabó). Es una MARCA sobre
-- ese día de calendario, no una actividad: no tiene kilómetros, ni tiempo, ni
-- recorrido, y no se inventa nada de eso.
--
-- Qué cambia con la marca (dominios/plan/servicio.ts):
--   - el día sale `done: true` y `manually_done: true`
--   - cuenta como sesión cumplida de su semana (`done_sessions`), sin sumar metros
--   - la racha NO vuelve: el fueguito sólo cuenta salidas registradas
--
-- `fecha` es el día LOCAL de la persona, con la zona del plan, igual que los días
-- que arma el motor. Una fila por día: marcar dos veces es lo mismo que una.
create table if not exists dias_hechos_a_mano (
  usuario_id uuid not null references usuarios(id) on delete cascade,
  fecha date not null,
  creado_en_ms bigint not null,
  primary key (usuario_id, fecha)
);
