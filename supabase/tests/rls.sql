-- Run with Supabase local testing after `supabase start`.
-- These checks complement the TypeScript date/streak tests.
begin;
select plan(5);

select has_table('public', 'tasks');
select has_table('public', 'daily_task_completions');
select has_policy('public', 'tasks', 'tasks_read_shared');
select has_policy('public', 'tasks', 'tasks_update_self');
select has_policy('public', 'daily_task_completions', 'completions_insert_self');

select * from finish();
rollback;
