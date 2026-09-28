export type CompletionState = "not_started" | "partial" | "complete" | "missed";

export function challengeDay(startDate: string, date: string): number {
  const start = Date.parse(`${startDate}T00:00:00Z`);
  const target = Date.parse(`${date}T00:00:00Z`);
  return Math.floor((target - start) / 86_400_000) + 1;
}

export function daysLeft(startDate: string, today: string, duration = 100): number {
  return Math.max(0, duration - challengeDay(startDate, today));
}

export function dailyState(activeTasks: number, completedTasks: number): CompletionState {
  if (activeTasks <= 0 || completedTasks <= 0) return "not_started";
  if (completedTasks >= activeTasks) return "complete";
  return "partial";
}

export function currentStreak(states: CompletionState[], todayIndex: number): number {
  let streak = 0;
  for (let index = todayIndex; index >= 0; index -= 1) {
    if (states[index] !== "complete") break;
    streak += 1;
  }
  return streak;
}

export function bestStreak(states: CompletionState[]): number {
  let best = 0;
  let current = 0;
  for (const state of states) {
    current = state === "complete" ? current + 1 : 0;
    best = Math.max(best, current);
  }
  return best;
}
