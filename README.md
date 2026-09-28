# Kinstreak

Private shared 100-day challenge tracker for a small sibling group.

## Stage 1: backend and security

This repository currently contains the backend foundation only. It uses Supabase's free tier for Google authentication, Postgres, Row Level Security, and Realtime. No paid service is required.

The security boundary is in `supabase/migrations/20260928000100_initial_schema.sql`:

- authenticated members can read progress for other members in the same challenge;
- users can insert, update, and delete only their own tasks, completions, summaries, and profile;
- challenge membership changes are restricted to the challenge owner;
- a challenge is constrained to exactly 100 days and uses `Asia/Kolkata` for day boundaries;
- only the current challenge day can be edited; past and future daily records are rejected in both RLS and database triggers;
- daily success is derived from all active tasks, so the client cannot mark a day complete by itself;
- server-side helper functions compute challenge day and daily status;
- Realtime is enabled only for the shared task/progress tables.
- New email-authenticated users receive a default profile through a database trigger.
- Magic-link callbacks exchange the auth code on the server in `app/auth/callback/route.ts`.

## Local setup

1. Create a free Supabase project.
2. Install the Supabase CLI and apply the migration with `supabase db push`.
3. Enable Google provider in Supabase Auth and add the app callback URL `/auth/callback`.
4. Copy `.env.example` to `.env.local` and fill in the project URL and publishable key.
5. Install dependencies and run the checks:

```bash
npm install
npm run typecheck
npm test
npm run dev
```

For local database authorization checks, run `supabase start` and execute `supabase test db`. The pgTAP smoke tests live in `supabase/tests/rls.sql`.

Never put `SUPABASE_SERVICE_ROLE_KEY` in browser code, commit it, or expose it in `.env.local` files that are shared.

## Planned next stages

The next implementation stage will add the authenticated server actions and data-access layer, followed by the mobile-first dashboard UI and Realtime subscriptions. The SQL schema is deliberately independent of the UI so those layers cannot bypass the RLS policies.
