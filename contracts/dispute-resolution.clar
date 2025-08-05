;; HashSeal Dispute Resolution Contract
;; Clarity v1

(define-constant ERR-NOT-FOUND u100)
(define-constant ERR-ALREADY-RESOLVED u101)
(define-constant ERR-NOT-INVOLVED u102)
(define-constant ERR-INVALID-STATUS u103)
(define-constant ERR-INSUFFICIENT-STAKE u104)
(define-constant ERR-ALREADY-VOTED u105)

(define-data-var stake-required uint u500)

;; Dispute status enum
(define-constant STATUS-OPEN u0)
(define-constant STATUS-RESOLVED u1)

;; Each dispute is uniquely identified by a hash of doc-id + reporter
(define-map disputes
  (tuple (id (buff 32)))
  (tuple
    doc-id (buff 32)
    reporter principal
    verifier principal
    reason (buff 256)
    status uint
    votes-for uint
    votes-against uint
    opened-at uint
  )
)

;; Votes recorded per dispute per voter
(define-map dispute-votes
  (tuple (dispute-id (buff 32)) (voter principal))
  bool
)

;; Simulate staking via a simple ledger
(define-map user-stakes principal uint)

;; Submit a dispute
(define-public (submit-dispute
  (dispute-id (buff 32))
  (doc-id (buff 32))
  (verifier principal)
  (reason (buff 256)))
  (begin
    ;; Require stake
    (let ((existing-stake (default-to u0 (map-get? user-stakes tx-sender))))
      (asserts! (>= existing-stake (var-get stake-required)) (err ERR-INSUFFICIENT-STAKE))
      (map-set disputes
        { id: dispute-id }
        {
          doc-id: doc-id,
          reporter: tx-sender,
          verifier: verifier,
          reason: reason,
          status: STATUS-OPEN,
          votes-for: u0,
          votes-against: u0,
          opened-at: block-height
        }
      )
      (ok true)
    )
  )
)

;; Cast a vote
(define-public (vote-dispute (dispute-id (buff 32)) (support bool))
  (let ((dispute (map-get? disputes { id: dispute-id })))
    (match dispute
      d
      (begin
        (asserts! (is-eq (get status d) STATUS-OPEN) (err ERR-ALREADY-RESOLVED))
        (asserts! (is-none (map-get? dispute-votes { dispute-id: dispute-id, voter: tx-sender })) (err ERR-ALREADY-VOTED))
        (map-set dispute-votes { dispute-id: dispute-id, voter: tx-sender } true)
        (if support
          (map-set disputes { id: dispute-id }
            (merge d { votes-for: (+ u1 (get votes-for d)) })
          )
          (map-set disputes { id: dispute-id }
            (merge d { votes-against: (+ u1 (get votes-against d)) })
          )
        )
        (ok true)
      )
      (err ERR-NOT-FOUND)
    )
  )
)

;; Resolve a dispute (simply based on majority)
(define-public (resolve-dispute (dispute-id (buff 32)))
  (let ((dispute (map-get? disputes { id: dispute-id })))
    (match dispute
      d
      (begin
        (asserts! (is-eq (get status d) STATUS-OPEN) (err ERR-ALREADY-RESOLVED))
        (let (
          (for (get votes-for d))
          (against (get votes-against d))
        )
          ;; Mark as resolved
          (map-set disputes { id: dispute-id }
            (merge d { status: STATUS-RESOLVED })
          )
          ;; Return result
          (if (> for against)
            (ok "dispute-upheld")
            (ok "dispute-dismissed")
          )
        )
      )
      (err ERR-NOT-FOUND)
    )
  )
)

;; Read-only: Get dispute data
(define-read-only (get-dispute (dispute-id (buff 32)))
  (match (map-get? disputes { id: dispute-id })
    d (ok d)
    (err ERR-NOT-FOUND)
  )
)

;; Fund staking pool (mock)
(define-public (add-stake (amount uint))
  (let ((existing (default-to u0 (map-get? user-stakes tx-sender))))
    (map-set user-stakes tx-sender (+ existing amount))
    (ok true)
  )
)
