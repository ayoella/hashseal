import { describe, it, expect, beforeEach } from "vitest"

type Principal = string
type Buff32 = string

interface Dispute {
  docId: Buff32
  reporter: Principal
  verifier: Principal
  reason: string
  status: number
  votesFor: number
  votesAgainst: number
  openedAt: number
}

const STATUS_OPEN = 0
const STATUS_RESOLVED = 1
const STAKE_REQUIRED = 500
const BLOCK = () => 100000

let disputes = new Map<string, Dispute>()
let votes = new Map<string, boolean>()
let stakes = new Map<Principal, number>()

const disputeId = "0xabc123"
const docId = "0xdoc001"
const reporter = "ST1REPORTER"
const verifier = "ST1VERIFIER"
const voter1 = "ST1VOTER1"
const voter2 = "ST1VOTER2"

beforeEach(() => {
  disputes = new Map()
  votes = new Map()
  stakes = new Map()
})

function submitDispute(sender: Principal): boolean | number {
  if ((stakes.get(sender) || 0) < STAKE_REQUIRED) return 104
  disputes.set(disputeId, {
    docId,
    reporter: sender,
    verifier,
    reason: "Forgery suspected",
    status: STATUS_OPEN,
    votesFor: 0,
    votesAgainst: 0,
    openedAt: BLOCK()
  })
  return true
}

function voteDispute(sender: Principal, support: boolean): boolean | number {
  const d = disputes.get(disputeId)
  if (!d) return 100
  if (d.status !== STATUS_OPEN) return 101
  const voteKey = `${disputeId}|${sender}`
  if (votes.has(voteKey)) return 105
  votes.set(voteKey, true)
  if (support) d.votesFor++
  else d.votesAgainst++
  return true
}

function resolveDispute(): string | number {
  const d = disputes.get(disputeId)
  if (!d) return 100
  if (d.status !== STATUS_OPEN) return 101
  d.status = STATUS_RESOLVED
  return d.votesFor > d.votesAgainst ? "dispute-upheld" : "dispute-dismissed"
}

describe("Dispute Resolution", () => {
  it("should require stake to submit dispute", () => {
    stakes.set(reporter, 500)
    const result = submitDispute(reporter)
    expect(result).toBe(true)
    expect(disputes.has(disputeId)).toBe(true)
  })

  it("should allow voting on open disputes", () => {
    stakes.set(reporter, 500)
    submitDispute(reporter)
    const vote1 = voteDispute(voter1, true)
    const vote2 = voteDispute(voter2, false)
    expect(vote1).toBe(true)
    expect(vote2).toBe(true)
    expect(disputes.get(disputeId)?.votesFor).toBe(1)
    expect(disputes.get(disputeId)?.votesAgainst).toBe(1)
  })

  it("should reject double voting", () => {
    stakes.set(reporter, 500)
    submitDispute(reporter)
    voteDispute(voter1, true)
    const doubleVote = voteDispute(voter1, true)
    expect(doubleVote).toBe(105)
  })

  it("should resolve dispute with correct outcome", () => {
    stakes.set(reporter, 500)
    submitDispute(reporter)
    voteDispute(voter1, true)
    voteDispute(voter2, true)
    const result = resolveDispute()
    expect(result).toBe("dispute-upheld")
    expect(disputes.get(disputeId)?.status).toBe(STATUS_RESOLVED)
  })
})
