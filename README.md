# Kinstreak

Private shared 100-day challenge tracker for a small sibling group.

## Stage 1: backend and security

This repository currently contains the backend foundation only. It uses Supabase's free tier for authentication, Postgres, Row Level Security, and Realtime. No paid service is required.

The security boundary is in `supabase/schema.sql`:

- authenticated members can read progress for other members in the same challenge;
- users can insert, update, and delete only their own tasks, completions, summaries, and profile;
- challenge membership changes are restricted to the challenge owner;
- a challenge is constrained to exactly 100 days;
- daily success is derived from all active tasks, so the client cannot mark a day complete by itself;
- server-side helper functions compute challenge day and daily status;
- Realtime is enabled only for the shared task/progress tables.

## Local setup

1. Create a free Supabase project.
2. In the Supabase SQL editor, run `supabase/schema.sql`.
3. Configure Email Auth in Supabase. For a personal app, keep email confirmation enabled.
4. Copy `.env.example` to `.env.local` and fill in the project URL and publishable key.
5. Install dependencies and run the checks:

```bash
npm install
npm run typecheck
npm run dev
```

Never put `SUPABASE_SERVICE_ROLE_KEY` in browser code, commit it, or expose it in `.env.local` files that are shared.

## Planned next stages

The next implementation stage will add the authenticated server actions and data-access layer, followed by the mobile-first dashboard UI and Realtime subscriptions. The SQL schema is deliberately independent of the UI so those layers cannot bypass the RLS policies.
