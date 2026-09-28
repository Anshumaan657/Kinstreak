import { describe, expect, it } from "vitest";
import { bestStreak, challengeDay, currentStreak, dailyState, daysLeft } from "@/lib/challenge-logic";

describe("challenge dates", () => {
  it("uses an inclusive day one", () => {
    expect(challengeDay("2026-09-28", "2026-09-28")).toBe(1);
    expect(challengeDay("2026-09-28", "2026-10-01")).toBe(4);
  });

  it("never exposes negative days left", () => {
    expect(daysLeft("2026-09-28", "2027-01-05")).toBe(0);
  });
});

describe("strict daily completion", () => {
  it("requires every active task", () => {
    expect(dailyState(3, 2)).toBe("partial");
    expect(dailyState(3, 3)).toBe("complete");
    expect(dailyState(0, 0)).toBe("not_started");
  });

  it("calculates current and best streaks", () => {
    const states = ["complete", "complete", "missed", "complete", "complete"] as const;
    expect(currentStreak([...states], 4)).toBe(2);
    expect(bestStreak([...states])).toBe(2);
  });
});
