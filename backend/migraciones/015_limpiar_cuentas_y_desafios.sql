-- Las cuentas se borran físicamente con sus filas dependientes. El correo es
-- único entre todas las cuentas existentes; no queda un estado de borrado lógico.
drop index if exists usuarios_email_vivo;
alter table usuarios drop column if exists borrado_en_ms;
create unique index if not exists usuarios_email_unico on usuarios (email);

-- Códigos y permisos de paso temporales viven en Redis privado con TTL. Antes de
-- retirar la tabla, no invalidar desafíos que aún podría estar usando alguien.
do $$
begin
  if exists (select 1 from desafios_auth
              where consumido_en_ms is null
                and vence_en_ms > (extract(epoch from clock_timestamp()) * 1000)::bigint) then
    raise exception 'Quedan desafíos de correo activos; reintentar tras vencer';
  end if;
end $$;
drop table desafios_auth;
