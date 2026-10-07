-- PDE Festival: richieste Messaggerie per festival e fiere.
-- Flusso: mail Messaggerie -> pratica (FF-AAAA-NNN) -> ordini di rifornimento inviati
-- a Messaggerie con lo stesso motore di BookUp (rpn-sync / rifornimento-order) ->
-- verifica evaso/inevaso -> ordini di recupero sulle quantità inevase.

create table public.ff_contatori (
  anno integer primary key,
  ultimo integer not null default 0
);
alter table public.ff_contatori enable row level security;

create table public.ff_pratiche (
  id bigint generated always as identity primary key,
  numero text unique,
  stato text not null default 'nuova'
    check (stato in ('nuova','ordinata','in_recupero','chiusa')),
  evento text not null,
  luogo text,
  data_inizio date,
  data_fine date,
  cliente_nome text,
  cliente_codice text,
  cliente_account text,
  document_type text not null default 'restock',
  order_reference text,
  destinazione jsonb,
  scadenza_ordine date,
  scadenza_consegna date,
  mitt_nome text,
  mitt_email text,
  mail_oggetto text,
  mail_data timestamptz,
  mail_testo text,
  mail_file_nome text,
  accordo_tardiva boolean not null default false,
  note text,
  created_by uuid default auth.uid() references auth.users(id) on delete set null,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);
alter table public.ff_pratiche enable row level security;

create table public.ff_righe (
  id bigint generated always as identity primary key,
  pratica_id bigint not null references public.ff_pratiche(id) on delete cascade,
  ean text not null,
  titolo text,
  autore text,
  editore text,
  qta_richiesta integer not null default 0,
  qta_evasa integer,
  qta_inevasa integer,
  motivo_inevaso text,
  stato_lavorazione text,
  ristampa text not null default '' check (ristampa in ('','da_verificare','confermata','non_prevista')),
  ristampa_data date,
  note text,
  verificato_at timestamptz,
  created_at timestamptz not null default now(),
  unique (pratica_id, ean)
);
alter table public.ff_righe enable row level security;

create table public.ff_ordini (
  id bigint generated always as identity primary key,
  pratica_id bigint not null references public.ff_pratiche(id) on delete cascade,
  tipo text not null default 'principale' check (tipo in ('principale','recupero')),
  account text not null,
  batch_id bigint,
  numero_interno text,
  n_ordine text,
  document_type text,
  copie integer,
  titoli integer,
  righe jsonb not null default '[]'::jsonb,   -- [{ean, qta}]
  verificato_at timestamptz,
  comunicato_at timestamptz,
  created_by uuid default auth.uid() references auth.users(id) on delete set null,
  created_at timestamptz not null default now()
);
alter table public.ff_ordini enable row level security;

create table public.ff_eventi (
  id bigint generated always as identity primary key,
  pratica_id bigint not null references public.ff_pratiche(id) on delete cascade,
  user_id uuid default auth.uid(),
  utente text default (auth.jwt() ->> 'email'),
  azione text not null,
  dettaglio text,
  created_at timestamptz not null default now()
);
alter table public.ff_eventi enable row level security;

create index ff_righe_pratica_idx on public.ff_righe(pratica_id);
create index ff_ordini_pratica_idx on public.ff_ordini(pratica_id);
create index ff_eventi_pratica_idx on public.ff_eventi(pratica_id, created_at desc);

-- Numerazione pratiche FF-AAAA-NNN
create or replace function public.ff_pratiche_numero()
returns trigger language plpgsql security definer set search_path to 'public' as $$
declare v_anno int := extract(year from now())::int; v_n int;
begin
  if new.numero is null or new.numero = '' then
    insert into public.ff_contatori(anno, ultimo) values (v_anno, 1)
      on conflict (anno) do update set ultimo = ff_contatori.ultimo + 1
      returning ultimo into v_n;
    new.numero := 'FF-' || v_anno || '-' || lpad(v_n::text, 3, '0');
  end if;
  return new;
end $$;
create trigger ff_pratiche_numero before insert on public.ff_pratiche
  for each row execute function public.ff_pratiche_numero();

create or replace function public.ff_touch()
returns trigger language plpgsql as $$
begin new.updated_at := now(); return new; end $$;
create trigger ff_pratiche_touch before update on public.ff_pratiche
  for each row execute function public.ff_touch();

-- Il N. ordine interno Messaggerie lo scrive il cron di rifornimento-order-id in
-- rifornimento_ordini_inviati: lo copiamo sull'ordine della pratica appena arriva.
create or replace function public.ff_ordini_numero_da_inviati()
returns trigger language plpgsql security definer set search_path to 'public' as $$
begin
  if new.order_number is not null then
    update public.ff_ordini set numero_interno = new.order_number
     where account = new.account and batch_id = new.batch_id and numero_interno is null;
  end if;
  return new;
end $$;
create trigger ff_ordini_numero_da_inviati after update of order_number on public.rifornimento_ordini_inviati
  for each row execute function public.ff_ordini_numero_da_inviati();

-- Gli ordini partiti da PDE Festival finiscono anche nello storico ordini di BookUp
alter table public.rifornimento_ordini_inviati drop constraint rifornimento_ordini_inviati_origine_check;
alter table public.rifornimento_ordini_inviati add constraint rifornimento_ordini_inviati_origine_check
  check (origine = any (array['manuale','massivo','festival']));

-- RLS: tutti gli utenti interni (non agenti) lavorano sulle pratiche;
-- eliminare una pratica è riservato agli Admin PDE.
create or replace function public.ff_non_agente()
returns boolean language sql stable as $$
  select coalesce(auth.jwt()->'user_metadata'->>'role','') <> 'agente';
$$;

create policy ff_pratiche_sel on public.ff_pratiche for select to authenticated using (public.ff_non_agente());
create policy ff_pratiche_ins on public.ff_pratiche for insert to authenticated with check (public.ff_non_agente());
create policy ff_pratiche_upd on public.ff_pratiche for update to authenticated using (public.ff_non_agente()) with check (public.ff_non_agente());
create policy ff_pratiche_del on public.ff_pratiche for delete to authenticated using (public._is_admin_pde());

create policy ff_righe_all on public.ff_righe for all to authenticated using (public.ff_non_agente()) with check (public.ff_non_agente());
create policy ff_ordini_all on public.ff_ordini for all to authenticated using (public.ff_non_agente()) with check (public.ff_non_agente());

create policy ff_eventi_sel on public.ff_eventi for select to authenticated using (public.ff_non_agente());
create policy ff_eventi_ins on public.ff_eventi for insert to authenticated
  with check (public.ff_non_agente() and user_id = auth.uid());
