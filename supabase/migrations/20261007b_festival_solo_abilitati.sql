-- PDE Festival visibile solo agli utenti in elenco (per ora solo alberto.simola@pde.it).
-- Per abilitare altri: insert into public.ff_utenti_abilitati(email) values ('nome@pde.it');
create table public.ff_utenti_abilitati (
  email text primary key,
  created_at timestamptz not null default now()
);
alter table public.ff_utenti_abilitati enable row level security;
insert into public.ff_utenti_abilitati(email) values ('alberto.simola@pde.it');

create or replace function public.ff_abilitato()
returns boolean language sql stable security definer set search_path to 'public' as $$
  select exists (select 1 from public.ff_utenti_abilitati a where lower(a.email) = lower(auth.jwt() ->> 'email'));
$$;
revoke all on function public.ff_abilitato() from anon;

drop policy ff_pratiche_sel on public.ff_pratiche;
drop policy ff_pratiche_ins on public.ff_pratiche;
drop policy ff_pratiche_upd on public.ff_pratiche;
drop policy ff_pratiche_del on public.ff_pratiche;
drop policy ff_righe_all on public.ff_righe;
drop policy ff_ordini_all on public.ff_ordini;
drop policy ff_eventi_sel on public.ff_eventi;
drop policy ff_eventi_ins on public.ff_eventi;

create policy ff_pratiche_all on public.ff_pratiche for all to authenticated using (public.ff_abilitato()) with check (public.ff_abilitato());
create policy ff_righe_all on public.ff_righe for all to authenticated using (public.ff_abilitato()) with check (public.ff_abilitato());
create policy ff_ordini_all on public.ff_ordini for all to authenticated using (public.ff_abilitato()) with check (public.ff_abilitato());
create policy ff_eventi_sel on public.ff_eventi for select to authenticated using (public.ff_abilitato());
create policy ff_eventi_ins on public.ff_eventi for insert to authenticated with check (public.ff_abilitato() and user_id = auth.uid());
