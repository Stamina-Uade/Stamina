-- Unifica los códigos y permisos de paso en un único material efímero.
-- Aditiva: las tablas antiguas quedan hasta que el backend nuevo lleve al menos
-- un ciclo completo de expiración; así un rollback no invalida altas en curso.
create table if not exists desafios_auth (
  id uuid primary key default gen_random_uuid(),
  email text not null,
  proposito text not null check (proposito in ('registro', 'recuperacion')),
  fase text not null check (fase in ('codigo', 'paso')),
  codigo_hash text,
  token_hash text,
  creado_en_ms bigint not null,
  vence_en_ms bigint not null,
  consumido_en_ms bigint,
  reenvio_desde_ms bigint,
  constraint desafios_fase_campos check (
    (fase = 'codigo' and codigo_hash is not null and token_hash is null and reenvio_desde_ms is not null)
    or
    (fase = 'paso' and token_hash is not null and codigo_hash is null and reenvio_desde_ms is null)
  )
);

create unique index if not exists desafios_token_hash on desafios_auth(token_hash) where token_hash is not null;
create index if not exists desafios_codigo_email on desafios_auth(email, proposito, creado_en_ms desc)
  where fase = 'codigo' and consumido_en_ms is null;
create index if not exists desafios_vence on desafios_auth(vence_en_ms);

insert into desafios_auth(id, email, proposito, fase, codigo_hash, creado_en_ms,
                          vence_en_ms, consumido_en_ms, reenvio_desde_ms)
select id, email, proposito, 'codigo', codigo_hash, creado_en_ms,
       vence_en_ms, consumido_en_ms, reenvio_desde_ms
from codigos_correo
on conflict (id) do nothing;

insert into desafios_auth(email, proposito, fase, token_hash, creado_en_ms,
                          vence_en_ms, consumido_en_ms)
select email, proposito, 'paso', token_hash, creado_en_ms,
       vence_en_ms, usado_en_ms
from tokens_paso
on conflict (token_hash) where token_hash is not null do nothing;
