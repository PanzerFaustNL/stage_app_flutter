# Stage App (Flutter) — multi-docent + sync (Supabase)

Flutter app (Android + iOS, 1 codebase) voor stage/BPV-begeleiding:

- Excel (`.xlsx`) import (meerdere sheets)
- Lokale opslag in **SQLite** (werkt offline)
- Per student/plaatsing: **1e bezoek** + **2e bezoek** (datum + notities)
- **Multi-docent + sync** via **Supabase** (login + cloud database)
  - Offline werken → later syncen
  - “dirty” indicator per regel

---

## 1) Snel starten (lokaal)

```bash
flutter pub get
flutter run
```

Zonder Supabase draait de app in **local-only** modus.

---

## 2) Supabase aanzetten (login + sync)

### Stap A — maak een Supabase project
1. Maak een nieuw project aan in Supabase.
2. Zet **Auth** aan (Email/Password).

### Stap B — database schema aanmaken (SQL)
Open Supabase → SQL editor → run dit:

```sql
-- Enable extension (optional but handy)
create extension if not exists "uuid-ossp";

create table if not exists public.placements (
  id uuid primary key,
  sheet text not null,

  klas text,
  roepnaam text,
  voorvoegsel text,
  achternaam text,
  crebo text,
  opleiding text,
  cohort text,
  email_school text,
  docent text,

  bpv_bedrijf text,
  bpv_bezoekadres text,
  bpv_status text,
  bpv_begindatum timestamptz,
  bpv_verwachte_einddatum timestamptz,

  bpv_email text,
  opmerkingen text,

  first_visit_date timestamptz,
  first_visit_notes text,
  second_visit_date timestamptz,
  second_visit_notes text,

  owner_id uuid references auth.users(id),
  owner_email text,

  deleted boolean not null default false,

  created_at timestamptz not null,
  updated_at timestamptz not null
);

create index if not exists placements_updated_at_idx on public.placements(updated_at);
create index if not exists placements_owner_id_idx on public.placements(owner_id);

-- Profiles table for roles (teacher vs manager)
create table if not exists public.profiles (
  id uuid primary key references auth.users(id) on delete cascade,
  role text not null default 'teacher' -- 'teacher' or 'manager'
);

-- Auto-create profile row on signup
create or replace function public.handle_new_user()
returns trigger as $$
begin
  insert into public.profiles (id, role) values (new.id, 'teacher')
  on conflict (id) do nothing;
  return new;
end;
$$ language plpgsql security definer;

drop trigger if exists on_auth_user_created on auth.users;
create trigger on_auth_user_created
after insert on auth.users
for each row execute procedure public.handle_new_user();

-- RLS
alter table public.placements enable row level security;
alter table public.profiles enable row level security;

-- Teachers: only their own rows
create policy "placements_select_own"
on public.placements for select
using (
  owner_id = auth.uid()
  OR exists (select 1 from public.profiles p where p.id = auth.uid() and p.role = 'manager')
);

create policy "placements_insert_own"
on public.placements for insert
with check (
  owner_id = auth.uid()
  OR exists (select 1 from public.profiles p where p.id = auth.uid() and p.role = 'manager')
);

create policy "placements_update_own"
on public.placements for update
using (
  owner_id = auth.uid()
  OR exists (select 1 from public.profiles p where p.id = auth.uid() and p.role = 'manager')
)
with check (
  owner_id = auth.uid()
  OR exists (select 1 from public.profiles p where p.id = auth.uid() and p.role = 'manager')
);

-- Profiles: user can read own; manager can read all (handig later)
create policy "profiles_select_own"
on public.profiles for select
using (id = auth.uid() OR exists (select 1 from public.profiles p where p.id = auth.uid() and p.role = 'manager'));

create policy "profiles_update_own"
on public.profiles for update
using (id = auth.uid())
with check (id = auth.uid());
```

> **Manager maken:** zet in `profiles` jouw user op `role = 'manager'` (via Table editor).

### Stap C — app configureren (.env)
Maak in de project-root een `.env`:

```env
SUPABASE_URL=JOUW_URL_HIER
SUPABASE_ANON_KEY=JOUW_ANON_KEY_HIER
```

Daarna:

```bash
flutter pub get
flutter run
```

---

## 3) Werking van sync (simpel & praktisch)

- Alles wordt lokaal in SQLite opgeslagen.
- Elke wijziging markeert een rij als `dirty`.
- **Sync** doet:
  1. Push: dirty rows → `placements` (upsert op `id`)
  2. Pull: remote rows (RLS filtert automatisch op docent/manager) → lokaal upsert
  3. Zet `last_sync_iso` lokaal

Conflict-strategie: **last-write-wins** op basis van `updated_at`.

---

## 4) Belangrijk: eigenaar/docent

De app zet bij import en opslaan automatisch:
- `owner_id = ingelogde docent`
- `owner_email = ingelogde docent`

Dus: **docenten zien standaard alleen hun eigen regels**.
Managers zien alles.

---

## 5) Mappen van Excel-kolommen

De importer gebruikt de **eerste rij als header** en matcht tolerant op bekende namen
(zoals `Docent`, `BPV Bedrijven`, `BPV Bezoekadres`, enz.).
Zie: `lib/services/excel_importer.dart`.

---

## 6) Waar je verder uitbreidt

- Sync: `lib/services/sync_service.dart`
- DB: `lib/services/db.dart`
- Model: `lib/models/placement.dart`
- UI: `lib/screens/*`

Ideeën die je er makkelijk bij prikt:
- export CSV/Excel
- filtering per status/cohort/docent
- extra bezoekmomenten
- realtime updates (Supabase Realtime)
