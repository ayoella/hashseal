// verifier-staking.test.ts

import { describe, it, expect, beforeEach } from "vitest";

type StakeStorage = {
  admin: string;
  paused: boolean;
  stakes: Record<string, number>;
};

let state: StakeStorage;

beforeEach(() => {
  state = {
    admin: "ST123-admin",
    paused: false,
    stakes: {},
  };
});

const isAdmin = (sender: string) => sender === state.admin;

function stake(sender: string, amount: number) {
  if (state.paused) return { err: 103 };
  const current = state.stakes[sender] || 0;
  state.stakes[sender] = current + amount;
  return { ok: true };
}

function unstake(sender: string, amount: number) {
  const current = state.stakes[sender] || 0;
  if (current < amount) return { err: 101 };
  state.stakes[sender] = current - amount;
  return { ok: true };
}

function transferAdmin(sender: string, newAdmin: string) {
  if (!isAdmin(sender)) return { err: 100 };
  if (newAdmin === "SP000000000000000000002Q6VF78") return { err: 102 };
  state.admin = newAdmin;
  return { ok: true };
}

function setStakingPaused(sender: string, paused: boolean) {
  if (!isAdmin(sender)) return { err: 100 };
  state.paused = paused;
  return { ok: paused };
}

function getStake(user: string) {
  return { ok: state.stakes[user] || 0 };
}

describe("verifier-staking (mocked)", () => {
  it("allows staking tokens", () => {
    const res = stake("ST-user", 100);
    expect(res).toEqual({ ok: true });
    expect(state.stakes["ST-user"]).toBe(100);
  });

  it("fails unstaking more than staked", () => {
    const res = unstake("ST-user", 50);
    expect(res).toEqual({ err: 101 });
  });

  it("unstakes tokens properly", () => {
    stake("ST-user", 200);
    const res = unstake("ST-user", 50);
    expect(res).toEqual({ ok: true });
    expect(state.stakes["ST-user"]).toBe(150);
  });

  it("prevents staking when paused", () => {
    setStakingPaused("ST123-admin", true);
    const res = stake("ST-user", 10);
    expect(res).toEqual({ err: 103 });
  });

  it("allows admin transfer", () => {
    const res = transferAdmin("ST123-admin", "ST456-new");
    expect(res).toEqual({ ok: true });
    expect(state.admin).toBe("ST456-new");
  });

  it("rejects admin transfer by non-admin", () => {
    const res = transferAdmin("ST-hacker", "ST789");
    expect(res).toEqual({ err: 100 });
  });

  it("returns stake amount", () => {
    stake("ST-alice", 300);
    const res = getStake("ST-alice");
    expect(res).toEqual({ ok: 300 });
  });
});
