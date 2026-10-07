-- Conserva la identidad multideporte de una salida de triatlón en el historial.
-- Aditiva para los clientes: los seis valores previos siguen siendo válidos.
alter table actividades drop constraint if exists actividades_deporte_check;
alter table actividades add constraint actividades_deporte_check
  check (deporte in ('running', 'ciclismo', 'natacion', 'trekking', 'fuerza', 'otro', 'triatlon'));
