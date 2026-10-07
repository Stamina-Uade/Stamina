-- Se aplica en un despliegue POSTERIOR al que activó desafios_auth.
-- Ni siquiera un rollback de este release puede necesitar las tablas anteriores.
do $$
declare ahora_ms bigint := (extract(epoch from clock_timestamp()) * 1000)::bigint;
begin
  if exists (
    select 1 from codigos_correo
     where consumido_en_ms is null and vence_en_ms > ahora_ms
  ) or exists (
    select 1 from tokens_paso
     where usado_en_ms is null and vence_en_ms > ahora_ms
  ) then
    raise exception 'Quedan desafíos activos de la versión anterior; reintentar luego';
  end if;
end $$;

drop table codigos_correo;
drop table tokens_paso;
