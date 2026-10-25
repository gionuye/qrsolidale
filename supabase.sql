-- QR Solidale – database della demo
-- Da incollare ed eseguire una sola volta in Supabase: SQL Editor > New query > Run.
-- Nessuno scrive direttamente nelle tabelle: tutto passa da funzioni che controllano
-- chi agisce e scrivono il registro con la catena di impronte SHA-256.

create extension if not exists pgcrypto with schema extensions;

-- ---------- Tabelle ----------
create table if not exists public.beneficiari (
  code          text primary key,
  nome          text not null,
  carta         text not null default '',
  stato         text not null default 'da_attivare'
                check (stato in ('da_attivare','attivo','sospeso','sostituito','chiuso')),
  creato        timestamptz not null default now(),
  sostituisce   text,
  sostituito_da text
);

create table if not exists public.donazioni (
  id      bigint generated always as identity primary key,
  code    text not null references public.beneficiari(code),
  importo numeric(10,2) not null check (importo >= 1 and importo <= 500),
  ts      timestamptz not null default now()
);

create table if not exists public.eventi (
  id        bigint generated always as identity primary key,
  ts_iso    text not null,
  azione    text not null,
  codice    text not null,
  dettaglio text not null default '',
  autore    text not null,
  prev_hash text not null,
  hash      text not null
);

alter table public.beneficiari enable row level security;
alter table public.donazioni   enable row level security;
alter table public.eventi      enable row level security;

-- Solo gli operatori autenticati leggono le tabelle. Nessuno le modifica direttamente.
drop policy if exists op_read_beneficiari on public.beneficiari;
drop policy if exists op_read_donazioni   on public.donazioni;
drop policy if exists op_read_eventi      on public.eventi;
create policy op_read_beneficiari on public.beneficiari for select to authenticated using (true);
create policy op_read_donazioni   on public.donazioni   for select to authenticated using (true);
create policy op_read_eventi      on public.eventi      for select to authenticated using (true);

-- ---------- Registro con catena di impronte ----------
create or replace function public._registra(p_azione text, p_codice text, p_dettaglio text, p_autore text)
returns void language plpgsql security definer set search_path = public as $$
declare
  v_prev text;
  v_ts   text := to_char(clock_timestamp() at time zone 'UTC', 'YYYY-MM-DD"T"HH24:MI:SS.US"Z"');
  v_det  text := coalesce(p_dettaglio, '');
  v_hash text;
begin
  perform pg_advisory_xact_lock(4242);  -- una voce alla volta: la catena resta lineare
  select hash into v_prev from eventi order by id desc limit 1;
  v_prev := coalesce(v_prev, repeat('0', 64));
  v_hash := encode(extensions.digest(
              v_prev || '|' || v_ts || '|' || p_azione || '|' || p_codice || '|' || v_det || '|' || p_autore,
              'sha256'), 'hex');
  insert into eventi(ts_iso, azione, codice, dettaglio, autore, prev_hash, hash)
  values (v_ts, p_azione, p_codice, v_det, p_autore, v_prev, v_hash);
end $$;
revoke all on function public._registra(text,text,text,text) from public, anon, authenticated;

create or replace function public._operatore() returns text
language plpgsql stable security definer set search_path = public as $$
begin
  if auth.uid() is null then
    raise exception 'Accesso riservato agli operatori';
  end if;
  return coalesce(auth.jwt() ->> 'email', 'operatore');
end $$;
revoke all on function public._operatore() from public, anon, authenticated;

create or replace function public._nuovo_codice() returns text
language plpgsql volatile security definer set search_path = public as $$
declare
  alfabeto constant text := '0123456789ABCDEFGHJKMNPQRSTVWXYZ';  -- Crockford Base32
  b bytea; c text; i int;
begin
  loop
    b := extensions.gen_random_bytes(8);
    c := '';
    for i in 0..7 loop
      c := c || substr(alfabeto, (get_byte(b, i) & 31) + 1, 1);
    end loop;
    exit when not exists (select 1 from beneficiari where code = c);
  end loop;
  return c;
end $$;
revoke all on function public._nuovo_codice() from public, anon, authenticated;

-- ---------- Funzioni pubbliche (donatore) ----------
-- Mostra solo nome pubblico e stato di un codice: nessun elenco, nessun dato personale.
create or replace function public.pagina_pubblica(p_code text)
returns table(code text, nome text, stato text)
language sql stable security definer set search_path = public as $$
  select b.code, b.nome, b.stato from beneficiari b where b.code = upper(p_code);
$$;
revoke all on function public.pagina_pubblica(text) from public;
grant execute on function public.pagina_pubblica(text) to anon, authenticated;

-- Donazione simulata: accettata solo se il codice è attivo. Il donatore resta anonimo.
create or replace function public.dona(p_code text, p_importo numeric)
returns void language plpgsql security definer set search_path = public as $$
declare v_stato text; v_code text := upper(p_code);
begin
  select stato into v_stato from beneficiari where code = v_code;
  if v_stato is null then raise exception 'Codice non trovato'; end if;
  if v_stato <> 'attivo' then raise exception 'Codice non attivo'; end if;
  if p_importo is null or p_importo < 1 or p_importo > 500 then raise exception 'Importo non valido'; end if;
  insert into donazioni(code, importo) values (v_code, round(p_importo, 2));
  perform _registra('donazione', v_code, to_char(round(p_importo,2), 'FM999990.00') || ' EUR (simulata)', 'donatore');
end $$;
revoke all on function public.dona(text, numeric) from public;
grant execute on function public.dona(text, numeric) to anon, authenticated;

-- ---------- Funzioni dell'operatore (serve l'accesso) ----------
create or replace function public.crea_beneficiario(p_nome text, p_carta text default '')
returns text language plpgsql security definer set search_path = public as $$
declare v_op text := _operatore(); v_code text; v_nome text := btrim(coalesce(p_nome, ''));
begin
  if length(v_nome) = 0 or length(v_nome) > 30 then raise exception 'Nome pubblico non valido'; end if;
  v_code := _nuovo_codice();
  insert into beneficiari(code, nome, carta) values (v_code, v_nome, left(coalesce(p_carta, ''), 20));
  perform _registra('creazione', v_code, 'Nome pubblico: ' || v_nome, v_op);
  return v_code;
end $$;

create or replace function public.cambia_stato(p_code text, p_azione text)
returns void language plpgsql security definer set search_path = public as $$
declare v_op text := _operatore(); v_stato text; v_nuovo text; v_evento text;
begin
  select stato into v_stato from beneficiari where code = p_code for update;
  if v_stato is null then raise exception 'Codice non trovato'; end if;
  if    p_azione = 'attiva'   and v_stato = 'da_attivare' then v_nuovo := 'attivo';  v_evento := 'attivazione';
  elsif p_azione = 'sospendi' and v_stato = 'attivo'      then v_nuovo := 'sospeso'; v_evento := 'sospensione';
  elsif p_azione = 'riattiva' and v_stato = 'sospeso'     then v_nuovo := 'attivo';  v_evento := 'riattivazione';
  elsif p_azione = 'chiudi'   and v_stato in ('da_attivare','attivo','sospeso') then v_nuovo := 'chiuso'; v_evento := 'chiusura';
  else raise exception 'Operazione non consentita dallo stato %', v_stato;
  end if;
  update beneficiari set stato = v_nuovo where code = p_code;
  perform _registra(v_evento, p_code, '', v_op);
end $$;

create or replace function public.sostituisci(p_code text)
returns text language plpgsql security definer set search_path = public as $$
declare v_op text := _operatore(); v_old beneficiari%rowtype; v_new text;
begin
  select * into v_old from beneficiari where code = p_code for update;
  if v_old.code is null then raise exception 'Codice non trovato'; end if;
  if v_old.stato not in ('attivo','sospeso') then raise exception 'Si sostituiscono solo codici attivi o sospesi'; end if;
  v_new := _nuovo_codice();
  insert into beneficiari(code, nome, carta, stato, sostituisce) values (v_new, v_old.nome, v_old.carta, 'attivo', v_old.code);
  update beneficiari set stato = 'sostituito', sostituito_da = v_new where code = v_old.code;
  perform _registra('creazione', v_new, 'Nome pubblico: ' || v_old.nome || ' (sostituisce ' || v_old.code || ')', v_op);
  perform _registra('sostituzione', v_old.code, 'Sostituito da ' || v_new, v_op);
  return v_new;
end $$;

revoke all on function public.crea_beneficiario(text, text) from public, anon;
revoke all on function public.cambia_stato(text, text)      from public, anon;
revoke all on function public.sostituisci(text)             from public, anon;
grant execute on function public.crea_beneficiario(text, text) to authenticated;
grant execute on function public.cambia_stato(text, text)      to authenticated;
grant execute on function public.sostituisci(text)             to authenticated;

-- ---------- Esempio ----------
do $$
declare c text;
begin
  if not exists (select 1 from beneficiari) then
    c := _nuovo_codice();
    insert into beneficiari(code, nome, carta, stato) values (c, 'Samir (esempio)', 'ID-ESEMPIO', 'attivo');
    perform _registra('creazione',   c, 'Nome pubblico: Samir (esempio)', 'esempio');
    perform _registra('attivazione', c, '', 'esempio');
  end if;
end $$;
