-- Kinstreak database foundation.
-- Run this in the Supabase SQL editor after creating a project.

create extension if not exists pgcrypto;

create type public.challenge_member_role as enum ('owner', 'member');
create type public.daily_status as enum ('not_started', 'partial', 'complete', 'missed');

create table public.profiles (
  id uuid primary key references auth.users(id) on delete cascade,
  display_name text not null check (char_length(trim(display_name)) between 1 and 80),
  avatar_color text not null default '#0f766e' check (avatar_color ~ '^#[0-9A-Fa-f]{6}$'),
  timezone text not null default 'UTC' check (char_length(timezone) between 1 and 80),
  created_at timestamptz not null default timezone('utc', now()),
  updated_at timestamptz not null default timezone('utc', now())
);

create or replace function public.handle_new_user()
returns trigger language plpgsql security definer set search_path = public as $$
begin
  insert into public.profiles (id, display_name)
  values (
    new.id,
    coalesce(
      nullif(trim(new.raw_user_meta_data ->> 'display_name'), ''),
      split_part(coalesce(new.email, 'member'), '@', 1)
    )
  )
  on conflict (id) do nothing;
  return new;
end;
$$;

create trigger on_auth_user_created
  after insert on auth.users
  for each row execute function public.handle_new_user();

create table public.challenges (
  id uuid primary key default gen_random_uuid(),
  title text not null default '100 Days Hard' check (char_length(trim(title)) between 1 and 120),
  start_date date not null,
  duration_days integer not null default 100 check (duration_days = 100),
  created_by uuid not null references auth.users(id) on delete restrict,
  created_at timestamptz not null default timezone('utc', now()),
  updated_at timestamptz not null default timezone('utc', now())
);

create table public.challenge_members (
  challenge_id uuid not null references public.challenges(id) on delete cascade,
  user_id uuid not null references auth.users(id) on delete cascade,
  role public.challenge_member_role not null default 'member',
  joined_at timestamptz not null default timezone('utc', now()),
  primary key (challenge_id, user_id)
);

create table public.tasks (
  id uuid primary key default gen_random_uuid(),
  challenge_id uuid not null references public.challenges(id) on delete cascade,
  owner_id uuid not null references auth.users(id) on delete cascade,
  title text not null check (char_length(trim(title)) between 1 and 160),
  description text check (description is null or char_length(description) <= 500),
  sort_order integer not null default 0,
  is_active boolean not null default true,
  created_at timestamptz not null default timezone('utc', now()),
  updated_at timestamptz not null default timezone('utc', now()),
  unique (id, owner_id)
);

create table public.daily_task_completions (
  id uuid primary key default gen_random_uuid(),
  task_id uuid not null references public.tasks(id) on delete cascade,
  owner_id uuid not null references auth.users(id) on delete cascade,
  completed_on date not null,
  completed_at timestamptz,
  note text check (note is null or char_length(note) <= 1000),
  created_at timestamptz not null default timezone('utc', now()),
  updated_at timestamptz not null default timezone('utc', now()),
  unique (task_id, completed_on),
  foreign key (task_id, owner_id) references public.tasks(id, owner_id) on delete cascade
);

create table public.daily_summaries (
  id uuid primary key default gen_random_uuid(),
  challenge_id uuid not null references public.challenges(id) on delete cascade,
  owner_id uuid not null references auth.users(id) on delete cascade,
  summary_date date not null,
  status public.daily_status not null default 'not_started',
  note text check (note is null or char_length(note) <= 2000),
  last_edited_at timestamptz not null default timezone('utc', now()),
  created_at timestamptz not null default timezone('utc', now()),
  updated_at timestamptz not null default timezone('utc', now()),
  unique (challenge_id, owner_id, summary_date)
);

create index challenge_members_user_id_idx on public.challenge_members(user_id);
create index tasks_challenge_owner_idx on public.tasks(challenge_id, owner_id);
create index completions_owner_date_idx on public.daily_task_completions(owner_id, completed_on);
create index summaries_challenge_date_idx on public.daily_summaries(challenge_id, summary_date);

create or replace function public.set_updated_at()
returns trigger language plpgsql security invoker set search_path = public as $$
begin
  new.updated_at = timezone('utc', now());
  return new;
end;
$$;

create or replace function public.add_challenge_owner()
returns trigger language plpgsql security definer set search_path = public as $$
begin
  insert into public.challenge_members (challenge_id, user_id, role)
  values (new.id, new.created_by, 'owner');
  return new;
end;
$$;

create trigger challenges_add_owner after insert on public.challenges
for each row execute function public.add_challenge_owner();

create trigger profiles_set_updated_at before update on public.profiles
for each row execute function public.set_updated_at();
create trigger challenges_set_updated_at before update on public.challenges
for each row execute function public.set_updated_at();
create trigger tasks_set_updated_at before update on public.tasks
for each row execute function public.set_updated_at();
create trigger completions_set_updated_at before update on public.daily_task_completions
for each row execute function public.set_updated_at();
create trigger summaries_set_updated_at before update on public.daily_summaries
for each row execute function public.set_updated_at();

create or replace function public.is_challenge_member(target_challenge uuid, target_user uuid default auth.uid())
returns boolean language sql stable security definer set search_path = public as $$
  select exists (
    select 1 from public.challenge_members
    where challenge_id = target_challenge and user_id = target_user
  );
$$;

create or replace function public.is_challenge_owner(target_challenge uuid, target_user uuid default auth.uid())
returns boolean language sql stable security definer set search_path = public as $$
  select exists (
    select 1 from public.challenge_members
    where challenge_id = target_challenge and user_id = target_user and role = 'owner'
  );
$$;

create or replace function public.challenge_day(target_challenge uuid, on_date date default current_date)
returns integer language sql stable security invoker set search_path = public as $$
  select greatest(0, least(c.duration_days, (on_date - c.start_date) + 1))
  from public.challenges c where c.id = target_challenge;
$$;

create or replace function public.recompute_daily_summary(target_challenge uuid, target_user uuid, target_date date)
returns public.daily_status language plpgsql security definer set search_path = public as $$
declare
  active_count integer;
  completed_count integer;
  result public.daily_status;
begin
  if auth.uid() is distinct from target_user then
    raise exception 'Only the owner can recompute their daily summary';
  end if;

  select count(*) into active_count from public.tasks
  where challenge_id = target_challenge and owner_id = target_user and is_active;

  select count(*) into completed_count
  from public.daily_task_completions c
  join public.tasks t on t.id = c.task_id
  where t.challenge_id = target_challenge and t.owner_id = target_user
    and t.is_active and c.completed_on = target_date and c.completed_at is not null;

  result := case
    when active_count = 0 or completed_count = 0 then 'not_started'::public.daily_status
    when completed_count = active_count then 'complete'::public.daily_status
    else 'partial'::public.daily_status
  end;

  insert into public.daily_summaries (challenge_id, owner_id, summary_date, status, last_edited_at)
  values (target_challenge, target_user, target_date, result, timezone('utc', now()))
  on conflict (challenge_id, owner_id, summary_date) do update
    set status = excluded.status, last_edited_at = excluded.last_edited_at;

  return result;
end;
$$;

alter table public.profiles enable row level security;
alter table public.challenges enable row level security;
alter table public.challenge_members enable row level security;
alter table public.tasks enable row level security;
alter table public.daily_task_completions enable row level security;
alter table public.daily_summaries enable row level security;

create policy profiles_read_shared on public.profiles for select to authenticated
using (exists (
  select 1 from public.challenge_members mine
  join public.challenge_members theirs on theirs.challenge_id = mine.challenge_id
  where mine.user_id = auth.uid() and theirs.user_id = profiles.id
));
create policy profiles_update_self on public.profiles for update to authenticated
using (id = auth.uid()) with check (id = auth.uid());
create policy profiles_insert_self on public.profiles for insert to authenticated
with check (id = auth.uid());

create policy challenges_read_member on public.challenges for select to authenticated
using (public.is_challenge_member(id));
create policy challenges_insert_self on public.challenges for insert to authenticated
with check (created_by = auth.uid());
create policy challenges_update_owner on public.challenges for update to authenticated
using (public.is_challenge_owner(id)) with check (created_by = auth.uid());
create policy challenges_delete_owner on public.challenges for delete to authenticated
using (public.is_challenge_owner(id));

create policy members_read_shared on public.challenge_members for select to authenticated
using (public.is_challenge_member(challenge_id));
create policy members_insert_owner on public.challenge_members for insert to authenticated
with check (public.is_challenge_owner(challenge_id));
create policy members_update_owner on public.challenge_members for update to authenticated
using (public.is_challenge_owner(challenge_id)) with check (public.is_challenge_owner(challenge_id));
create policy members_delete_owner on public.challenge_members for delete to authenticated
using (public.is_challenge_owner(challenge_id));

create policy tasks_read_shared on public.tasks for select to authenticated
using (public.is_challenge_member(challenge_id));
create policy tasks_insert_self on public.tasks for insert to authenticated
with check (owner_id = auth.uid() and public.is_challenge_member(challenge_id));
create policy tasks_update_self on public.tasks for update to authenticated
using (owner_id = auth.uid() and public.is_challenge_member(challenge_id))
with check (owner_id = auth.uid() and public.is_challenge_member(challenge_id));
create policy tasks_delete_self on public.tasks for delete to authenticated
using (owner_id = auth.uid() and public.is_challenge_member(challenge_id));

create policy completions_read_shared on public.daily_task_completions for select to authenticated
using (public.is_challenge_member((select challenge_id from public.tasks where id = task_id)));
create policy completions_insert_self on public.daily_task_completions for insert to authenticated
with check (owner_id = auth.uid());
create policy completions_update_self on public.daily_task_completions for update to authenticated
using (owner_id = auth.uid()) with check (owner_id = auth.uid());
create policy completions_delete_self on public.daily_task_completions for delete to authenticated
using (owner_id = auth.uid());

create policy summaries_read_shared on public.daily_summaries for select to authenticated
using (public.is_challenge_member(challenge_id));
create policy summaries_insert_self on public.daily_summaries for insert to authenticated
with check (owner_id = auth.uid() and public.is_challenge_member(challenge_id));
create policy summaries_update_self on public.daily_summaries for update to authenticated
using (owner_id = auth.uid() and public.is_challenge_member(challenge_id))
with check (owner_id = auth.uid() and public.is_challenge_member(challenge_id));
create policy summaries_delete_self on public.daily_summaries for delete to authenticated
using (owner_id = auth.uid());

-- Keep realtime limited to the shared data needed by the dashboard.
alter publication supabase_realtime add table public.tasks;
alter publication supabase_realtime add table public.daily_task_completions;
alter publication supabase_realtime add table public.daily_summaries;
