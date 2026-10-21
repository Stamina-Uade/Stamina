-- 018_fechas_de_objetivo_en_cero.sql — devuelve a null las fechas de objetivo que
-- la validación convirtió en 0.
--
-- Hasta este despliegue, el esquema de un campo nullable se validaba con anyOf y
-- Fastify valida con `coerceTypes`: la rama del entero convertía el `null` antes de
-- llegar a la otra, y "sin fecha" se guardaba como 0 (scripts/generar-esquemas.mjs
-- lo explica). Para el motor eso es una carrera el 1 de enero de 1970: el bloque
-- terminado nunca se renovaba y la app mostraba "tu plan terminó" una y otra vez.
--
-- 0 no es una fecha de objetivo posible, así que no hay nada que distinguir. El
-- ancla vigente de esas personas guardó el hash con la fecha 1970-01-01; al cambiar
-- a null cambia el hash, y el próximo GET /v1/plan arranca un bloque nuevo desde
-- ese día, que es lo que la persona había pedido.
--
-- 🛑 Lo mismo pasó con `embarazo_o_lactancia`: un null («no respondió») se guardó
-- como false («no»). Eso NO se corrige acá porque no se puede: un false guardado
-- puede ser una respuesta real, y la base no dice cuál es cuál.

update perfiles
   set objetivo_fecha_ms = null
 where objetivo_fecha_ms = 0;

update objetivos_usuario
   set objetivo_fecha_ms = null
 where objetivo_fecha_ms = 0;
