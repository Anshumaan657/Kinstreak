# Assumptions

- Challenge day boundaries use `Asia/Kolkata` and are stored on each challenge.
- Google OAuth and persistent sessions are provided by Clerk. Supabase verifies Clerk's session JWT as a third-party auth provider.
- Clerk user IDs are stored as text and compared with `auth.jwt() ->> 'sub'` in RLS policies.
- Google users may authenticate themselves, but only users in `challenge_members` can read or change challenge data.
- Daily completions and summaries are immutable after the challenge-local calendar day ends. Future dates cannot be written.
- Future heatmap cells are intentionally blank and non-editable; they do not count toward streaks.
- A zero-active-task day is not successful.
- Task definitions remain shared and owner-editable; historical daily completion records are the immutable accountability record.
