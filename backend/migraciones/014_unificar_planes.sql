-- Une las anclas principales y adicionales en una sola tabla. La app sigue en
-- desarrollo: después de copiar y verificar, no se conserva la tabla anterior.
alter table planes add column if not exists objetivo_id uuid references objetivos_usuario(id) on delete cascade;

insert into planes (id, usuario_id, objetivo_id, motor_version, entrada_hash,
                   inicio_fecha, zona_horaria, creado_en_ms, reemplazado_en_ms)
select id, usuario_id, objetivo_id, motor_version, entrada_hash,
       inicio_fecha, zona_horaria, creado_en_ms, reemplazado_en_ms
  from planes_objetivos
on conflict (id) do nothing;

drop index if exists planes_vigente;
create unique index if not exists planes_principal_vigente
  on planes(usuario_id) where objetivo_id is null and reemplazado_en_ms is null;
create unique index if not exists planes_adicional_vigente
  on planes(objetivo_id) where objetivo_id is not null and reemplazado_en_ms is null;

do $$
begin
  if exists (select 1 from planes_objetivos po
              where not exists (select 1 from planes p
                                 where p.id = po.id and p.objetivo_id = po.objetivo_id)) then
    raise exception 'No se copiaron todas las anclas adicionales';
  end if;
end $$;

drop table planes_objetivos;
