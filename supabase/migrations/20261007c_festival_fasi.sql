-- Fasi della pratica: una richiesta Messaggerie può avere più fasi con regole diverse
-- (es. "Primo impianto" in Ordini Speciali con consegna tassativa, poi "Rifornimenti"
-- in una finestra di date con destinazione alternativa). Titoli e ordini stanno in una fase.

create table public.ff_fasi (
  id bigint generated always as identity primary key,
  pratica_id bigint not null references public.ff_pratiche(id) on delete cascade,
  posizione integer not null default 1,
  nome text not null,
  document_type text not null default 'restock',
  inserire_dal date,
  inserire_entro date,
  consegna_tassativa date,
  consegna_fino date,
  annullo_dal date,
  destinazione jsonb,
  note text,
  created_at timestamptz not null default now()
);
alter table public.ff_fasi enable row level security;
create index ff_fasi_pratica_idx on public.ff_fasi(pratica_id, posizione);
create policy ff_fasi_all on public.ff_fasi for all to authenticated using (public.ff_abilitato()) with check (public.ff_abilitato());

-- Tabelle vuote al momento della migrazione: fase obbligatoria su titoli e ordini
alter table public.ff_righe add column fase_id bigint not null references public.ff_fasi(id) on delete cascade;
alter table public.ff_righe drop constraint ff_righe_pratica_id_ean_key;
alter table public.ff_righe add constraint ff_righe_fase_ean_key unique (fase_id, ean);
create index ff_righe_fase_idx on public.ff_righe(fase_id);

alter table public.ff_ordini add column fase_id bigint not null references public.ff_fasi(id) on delete cascade;
create index ff_ordini_fase_idx on public.ff_ordini(fase_id);

-- Tipo ordine, destinazione e scadenze ora sono per fase
alter table public.ff_pratiche drop column document_type;
alter table public.ff_pratiche drop column destinazione;
alter table public.ff_pratiche drop column scadenza_ordine;
alter table public.ff_pratiche drop column scadenza_consegna;
