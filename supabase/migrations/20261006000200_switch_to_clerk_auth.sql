-- Convert application user identifiers from Supabase Auth UUIDs to Clerk user IDs.
-- Challenge and record IDs remain UUIDs.
alter table public.profiles drop constraint if exists profiles_id_fkey;
alter table public.challenges drop constraint if exists challenges_created_by_fkey;
alter table public.challenge_members drop constraint if exists challenge_members_user_id_fkey;
alter table public.tasks drop constraint if exists tasks_owner_id_fkey;
alter table public.daily_task_completions drop constraint if exists daily_task_completions_owner_id_fkey;
alter table public.daily_summaries drop constraint if exists daily_summaries_owner_id_fkey;

alter table public.profiles alter column id type text using id::text;
alter table public.challenges alter column created_by type text using created_by::text;
alter table public.challenge_members alter column user_id type text using user_id::text;
alter table public.tasks alter column owner_id type text using owner_id::text;
alter table public.daily_task_completions alter column owner_id type text using owner_id::text;
alter table public.daily_summaries alter column owner_id type text using owner_id::text;

drop trigger if exists on_auth_user_created on auth.users;

create or replace function public.is_challenge_member(target_challenge uuid, target_user text default (auth.jwt() ->> 'sub'))
returns boolean language sql stable security definer set search_path = public as $$
  select exists (select 1 from public.challenge_members where challenge_id = target_challenge and user_id = target_user);
$$;

create or replace function public.is_challenge_owner(target_challenge uuid, target_user text default (auth.jwt() ->> 'sub'))
returns boolean language sql stable security definer set search_path = public as $$
  select exists (select 1 from public.challenge_members where challenge_id = target_challenge and user_id = target_user and role = 'owner');
$$;

-- Recreate policies with Clerk's JWT subject. The current-day triggers remain unchanged.
drop policy if exists profiles_read_shared on public.profiles;
drop policy if exists profiles_update_self on public.profiles;
drop policy if exists profiles_insert_self on public.profiles;
create policy profiles_read_shared on public.profiles for select to authenticated using (exists (select 1 from public.challenge_members mine join public.challenge_members theirs on theirs.challenge_id = mine.challenge_id where mine.user_id = (select auth.jwt() ->> 'sub') and theirs.user_id = profiles.id));
create policy profiles_update_self on public.profiles for update to authenticated using (id = (select auth.jwt() ->> 'sub')) with check (id = (select auth.jwt() ->> 'sub'));
create policy profiles_insert_self on public.profiles for insert to authenticated with check (id = (select auth.jwt() ->> 'sub'));

drop policy if exists challenges_read_member on public.challenges;
drop policy if exists challenges_insert_self on public.challenges;
drop policy if exists challenges_update_owner on public.challenges;
drop policy if exists challenges_delete_owner on public.challenges;
create policy challenges_read_member on public.challenges for select to authenticated using (public.is_challenge_member(id));
create policy challenges_insert_self on public.challenges for insert to authenticated with check (created_by = (select auth.jwt() ->> 'sub'));
create policy challenges_update_owner on public.challenges for update to authenticated using (public.is_challenge_owner(id)) with check (created_by = (select auth.jwt() ->> 'sub'));
create policy challenges_delete_owner on public.challenges for delete to authenticated using (public.is_challenge_owner(id));

drop policy if exists members_read_shared on public.challenge_members;
drop policy if exists members_insert_owner on public.challenge_members;
drop policy if exists members_update_owner on public.challenge_members;
drop policy if exists members_delete_owner on public.challenge_members;
create policy members_read_shared on public.challenge_members for select to authenticated using (public.is_challenge_member(challenge_id));
create policy members_insert_owner on public.challenge_members for insert to authenticated with check (public.is_challenge_owner(challenge_id));
create policy members_update_owner on public.challenge_members for update to authenticated using (public.is_challenge_owner(challenge_id)) with check (public.is_challenge_owner(challenge_id));
create policy members_delete_owner on public.challenge_members for delete to authenticated using (public.is_challenge_owner(challenge_id));

drop policy if exists tasks_read_shared on public.tasks;
drop policy if exists tasks_insert_self on public.tasks;
drop policy if exists tasks_update_self on public.tasks;
drop policy if exists tasks_delete_self on public.tasks;
create policy tasks_read_shared on public.tasks for select to authenticated using (public.is_challenge_member(challenge_id));
create policy tasks_insert_self on public.tasks for insert to authenticated with check (owner_id = (select auth.jwt() ->> 'sub') and public.is_challenge_member(challenge_id));
create policy tasks_update_self on public.tasks for update to authenticated using (owner_id = (select auth.jwt() ->> 'sub') and public.is_challenge_member(challenge_id)) with check (owner_id = (select auth.jwt() ->> 'sub') and public.is_challenge_member(challenge_id));
create policy tasks_delete_self on public.tasks for delete to authenticated using (owner_id = (select auth.jwt() ->> 'sub') and public.is_challenge_member(challenge_id));

drop policy if exists completions_read_shared on public.daily_task_completions;
drop policy if exists completions_insert_self on public.daily_task_completions;
drop policy if exists completions_update_self on public.daily_task_completions;
drop policy if exists completions_delete_self on public.daily_task_completions;
create policy completions_read_shared on public.daily_task_completions for select to authenticated using (public.is_challenge_member((select challenge_id from public.tasks where id = task_id)));
create policy completions_insert_self on public.daily_task_completions for insert to authenticated with check (owner_id = (select auth.jwt() ->> 'sub') and public.is_challenge_today((select challenge_id from public.tasks where id = task_id), completed_on));
create policy completions_update_self on public.daily_task_completions for update to authenticated using (owner_id = (select auth.jwt() ->> 'sub')) with check (owner_id = (select auth.jwt() ->> 'sub') and public.is_challenge_today((select challenge_id from public.tasks where id = task_id), completed_on));
create policy completions_delete_self on public.daily_task_completions for delete to authenticated using (owner_id = (select auth.jwt() ->> 'sub'));

drop policy if exists summaries_read_shared on public.daily_summaries;
drop policy if exists summaries_insert_self on public.daily_summaries;
drop policy if exists summaries_update_self on public.daily_summaries;
drop policy if exists summaries_delete_self on public.daily_summaries;
create policy summaries_read_shared on public.daily_summaries for select to authenticated using (public.is_challenge_member(challenge_id));
create policy summaries_insert_self on public.daily_summaries for insert to authenticated with check (owner_id = (select auth.jwt() ->> 'sub') and public.is_challenge_member(challenge_id));
create policy summaries_update_self on public.daily_summaries for update to authenticated using (owner_id = (select auth.jwt() ->> 'sub') and public.is_challenge_member(challenge_id)) with check (owner_id = (select auth.jwt() ->> 'sub') and public.is_challenge_member(challenge_id));
create policy summaries_delete_self on public.daily_summaries for delete to authenticated using (owner_id = (select auth.jwt() ->> 'sub'));
