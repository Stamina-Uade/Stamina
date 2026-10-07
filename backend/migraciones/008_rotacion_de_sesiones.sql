-- 008_rotacion_de_sesiones.sql
--
-- Decisión 0013: rotar un refresh ya no revoca la sesión vieja, y el reintento de un
-- refresh cuya respuesta se perdió recibe LA MISMA sucesora. Para encontrarla hace
-- falta saber de qué sesión salió cada una.
--
-- Es aditiva: el código anterior no lee la columna y sigue funcionando sobre este
-- esquema, así que la vuelta atrás del despliegue no se rompe.

alter table sesiones
  add column if not exists anterior_id uuid references sesiones(id) on delete set null;

-- Una sesión tiene como mucho UNA sucesora. El canje ya corre con la fila bloqueada;
-- esto es la segunda red: un segundo canje que se colara chocaría acá en vez de abrir
-- dos cadenas de la misma familia.
create unique index if not exists sesiones_anterior on sesiones (anterior_id) where anterior_id is not null;
