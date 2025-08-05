import { describe, it, expect, beforeEach } from "vitest"

type Principal = string
type Buff32 = string

interface VerifierStats {
  totalVerifications: number
  successfulVerifications: number
  totalDisputes: number
  resolvedAgainst: number
  lastUpdated: number
}

const now = () => 99999

let verifierStats = new Map<Principal, VerifierStats>()
let recordedDocs = new Set<string>()

const VERIFIER = "ST1VERIFIER"
const DOC_ID = "0xabc123"

beforeEach(() => {
  verifierStats = new Map()
  recordedDocs = new Set()
})

function recordVerification(verifier: Principal, docId: Buff32, success: boolean): boolean | number {
  const key = `${verifier}|${docId}`
  if (recordedDocs.has(key)) return 101 // Already recorded
  recordedDocs.add(key)

  const stats = verifierStats.get(verifier) || {
    totalVerifications: 0,
    successfulVerifications: 0,
    totalDisputes: 0,
    resolvedAgainst: 0,
    lastUpdated: 0
  }

  verifierStats.set(verifier, {
    ...stats,
    totalVerifications: stats.totalVerifications + 1,
    successfulVerifications: success
      ? stats.successfulVerifications + 1
      : stats.successfulVerifications,
    lastUpdated: now()
  })

  return true
}

function recordDisputeLoss(verifier: Principal): boolean | number {
  const stats = verifierStats.get(verifier)
  if (!stats) return 102 // Not found
  verifierStats.set(verifier, {
    ...stats,
    totalDisputes: stats.totalDisputes + 1,
    resolvedAgainst: stats.resolvedAgainst + 1,
    lastUpdated: now()
  })
  return true
}

function getTrustScore(verifier: Principal): number | string {
  const stats = verifierStats.get(verifier)
  if (!stats) return "err: not found"
  if (stats.totalVerifications < 1) return 0
  const baseScore = (stats.successfulVerifications / stats.totalVerifications) * 100
  const penalty = stats.resolvedAgainst * 5
  const rawScore = baseScore - penalty
  return Math.max(0, Math.min(100, Math.floor(rawScore)))
}

describe("Verifier Reputation", () => {
  it("should record successful verification", () => {
    const result = recordVerification(VERIFIER, DOC_ID, true)
    expect(result).toBe(true)
    const stats = verifierStats.get(VERIFIER)
    expect(stats?.totalVerifications).toBe(1)
    expect(stats?.successfulVerifications).toBe(1)
  })

  it("should prevent double recording", () => {
    recordVerification(VERIFIER, DOC_ID, true)
    const result = recordVerification(VERIFIER, DOC_ID, false)
    expect(result).toBe(101)
  })

  it("should record dispute loss", () => {
    recordVerification(VERIFIER, DOC_ID, true)
    const result = recordDisputeLoss(VERIFIER)
    expect(result).toBe(true)
    const stats = verifierStats.get(VERIFIER)
    expect(stats?.resolvedAgainst).toBe(1)
  })

  it("should calculate trust score", () => {
    recordVerification(VERIFIER, DOC_ID, true)
    recordVerification(VERIFIER, "0x2", true)
    recordVerification(VERIFIER, "0x3", false)
    recordDisputeLoss(VERIFIER)
    const score = getTrustScore(VERIFIER)
    expect(score).toBe(61) // (2/3)*100 = 66.6... - 5 = ~61
  })
})
