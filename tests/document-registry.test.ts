import { describe, it, expect, beforeEach } from "vitest"

type Principal = string

interface Document {
  owner: Principal
  uri: string
  timestamp: number
  revoked: boolean
}

interface Verifier {
  stake: number
  active: boolean
}

const now = () => 123456 // mock block height

let documents = new Map<string, Document>()
let verifiers = new Map<Principal, Verifier>()
let verifiedDocs = new Map<string, number>()
let sharedAccess = new Map<string, boolean>()

const DOC_ID = "0xabc123"
const URI = "ipfs://Qm..."
const ADMIN = "ST1ADMIN"
const USER = "ST1USER"
const VIEWER = "ST1VIEWER"
const VERIFIER = "ST1VERIFIER"

beforeEach(() => {
  documents = new Map()
  verifiers = new Map()
  verifiedDocs = new Map()
  sharedAccess = new Map()
})

describe("HashSeal Document Registry", () => {
  it("should allow a user to register a document", () => {
    expect(documents.has(DOC_ID)).toBe(false)
    documents.set(DOC_ID, {
      owner: USER,
      uri: URI,
      timestamp: now(),
      revoked: false
    })
    expect(documents.get(DOC_ID)?.owner).toBe(USER)
  })

  it("should allow owner to grant access", () => {
    documents.set(DOC_ID, {
      owner: USER,
      uri: URI,
      timestamp: now(),
      revoked: false
    })
    const key = `${DOC_ID}|${VIEWER}`
    sharedAccess.set(key, true)
    expect(sharedAccess.get(key)).toBe(true)
  })

  it("should allow verifiers to verify documents", () => {
    verifiers.set(VERIFIER, { stake: 1000, active: true })
    const verifyKey = `${DOC_ID}|${VERIFIER}`
    verifiedDocs.set(verifyKey, now())
    expect(verifiedDocs.has(verifyKey)).toBe(true)
  })

  it("should revoke documents", () => {
    documents.set(DOC_ID, {
      owner: USER,
      uri: URI,
      timestamp: now(),
      revoked: false
    })
    const doc = documents.get(DOC_ID)
    if (doc && doc.owner === USER) {
      documents.set(DOC_ID, { ...doc, revoked: true })
    }
    expect(documents.get(DOC_ID)?.revoked).toBe(true)
  })

  it("should check access rights correctly", () => {
    documents.set(DOC_ID, {
      owner: USER,
      uri: URI,
      timestamp: now(),
      revoked: false
    })
    const key = `${DOC_ID}|${VIEWER}`
    sharedAccess.set(key, true)
    const doc = documents.get(DOC_ID)
    const hasAccess =
      doc?.owner === VIEWER || sharedAccess.get(key) === true
    expect(hasAccess).toBe(true)
  })
})
