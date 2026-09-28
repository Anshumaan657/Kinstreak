# Assumptions

- Challenge day boundaries use `Asia/Kolkata` and are stored on each challenge.
- Google OAuth is provided by Supabase Auth. Sessions are persistent and refreshed by Supabase.
- Google users may authenticate themselves, but only users in `challenge_members` can read or change challenge data.
- Daily completions and summaries are immutable after the challenge-local calendar day ends. Future dates cannot be written.
- Future heatmap cells are intentionally blank and non-editable; they do not count toward streaks.
- A zero-active-task day is not successful.
- Task definitions remain shared and owner-editable; historical daily completion records are the immutable accountability record.
