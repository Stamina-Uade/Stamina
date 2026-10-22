-- 019_desactivar_y_borrar_con_gracia.sql — contrato 1.6.0.
--
-- Dos estados nuevos de una cuenta, los dos reversibles con `POST /auth/reactivate`:
--
--   desactivada_en_ms  `POST /me/deactivate`: la persona se toma un descanso. Sus
--                      sesiones se cierran y los datos quedan. No vence nunca.
--   borrar_en_ms       `POST /me/delete`: cuándo se borra DE VERDAD (ahora + 30
--                      días). Hasta entonces la cuenta existe, no se puede usar y
--                      se puede recuperar entera. Pasado el plazo la borra
--                      `npm run purgar` (dominios/cuenta/purgar.ts), por cascada.
--
-- `null` = no está en ese estado. No son un soft-delete de §11: la cuenta sigue
-- viva y el correo sigue ocupado (registrarse con él es "ya registrado"), y lo
-- que se borra, se borra físicamente al final del plazo.
alter table usuarios add column if not exists desactivada_en_ms bigint;
alter table usuarios add column if not exists borrar_en_ms bigint;

-- Lo único que busca por `borrar_en_ms` es la purga diaria, y son pocas filas.
create index if not exists usuarios_por_borrar on usuarios (borrar_en_ms) where borrar_en_ms is not null;
