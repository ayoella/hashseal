;; HashSeal Document Registry
;; Clarity v1 - for Stacks blockchain

(define-constant ERR-NOT-AUTHORIZED u100)
(define-constant ERR-NOT-OWNER u101)
(define-constant ERR-DOC-EXISTS u102)
(define-constant ERR-DOC-NOT-FOUND u103)
(define-constant ERR-NOT-VERIFIER u104)
(define-constant ERR-ALREADY-VERIFIED u105)
(define-constant ERR-ACCESS-DENIED u106)

(define-data-var contract-owner principal tx-sender)
(define-data-var verifier-stake uint u1000)

(define-map documents
  { doc-id: (buff 32) }
  {
    owner: principal,
    uri: (buff 256),
    timestamp: uint,
    revoked: bool
  }
)

(define-map verified-docs
  { doc-id: (buff 32), verifier: principal }
  {
    verified-at: uint
  }
)

(define-map verifiers
  principal
  {
    stake: uint,
    active: bool
  }
)

(define-map shared-access
  { doc-id: (buff 32), viewer: principal }
  bool
)

;; Admin: Add verifier
(define-public (register-verifier)
  (begin
    (asserts! (>= (stx-get-balance tx-sender) (var-get verifier-stake)) (err ERR-NOT-AUTHORIZED))
    (map-set verifiers tx-sender { stake: (var-get verifier-stake), active: true })
    (ok true)
  )
)

;; Register a document (hash + metadata URI)
(define-public (register-document (doc-id (buff 32)) (uri (buff 256)))
  (begin
    (asserts! (is-none (map-get? documents { doc-id: doc-id })) (err ERR-DOC-EXISTS))
    (map-set documents
      { doc-id: doc-id }
      {
        owner: tx-sender,
        uri: uri,
        timestamp: block-height,
        revoked: false
      }
    )
    (ok true)
  )
)

;; Grant access to a document
(define-public (grant-access (doc-id (buff 32)) (viewer principal))
  (begin
    (let ((doc (map-get? documents { doc-id: doc-id })))
      (match doc
        doc-data
        (begin
          (asserts! (is-eq tx-sender (get owner doc-data)) (err ERR-NOT-OWNER))
          (map-set shared-access { doc-id: doc-id, viewer: viewer } true)
          (ok true)
        )
        (err ERR-DOC-NOT-FOUND)
      )
    )
  )
)

;; Revoke document (only by owner)
(define-public (revoke-document (doc-id (buff 32)))
  (begin
    (let ((doc (map-get? documents { doc-id: doc-id })))
      (match doc
        doc-data
        (begin
          (asserts! (is-eq tx-sender (get owner doc-data)) (err ERR-NOT-OWNER))
          (map-set documents
            { doc-id: doc-id }
            (merge doc-data { revoked: true })
          )
          (ok true)
        )
        (err ERR-DOC-NOT-FOUND)
      )
    )
  )
)

;; Notarize document (must be a verifier)
(define-public (verify-document (doc-id (buff 32)))
  (begin
    (let ((verifier-data (map-get? verifiers tx-sender)))
      (match verifier-data
        verifier
        (begin
          (asserts! (get active verifier) (err ERR-NOT-VERIFIER))
          (asserts! (is-none (map-get? verified-docs { doc-id: doc-id, verifier: tx-sender })) (err ERR-ALREADY-VERIFIED))
          (map-set verified-docs
            { doc-id: doc-id, verifier: tx-sender }
            { verified-at: block-height }
          )
          (ok true)
        )
        (err ERR-NOT-VERIFIER)
      )
    )
  )
)

;; Read-only: Get document metadata
(define-read-only (get-document (doc-id (buff 32)))
  (match (map-get? documents { doc-id: doc-id })
    doc (ok doc)
    (err ERR-DOC-NOT-FOUND)
  )
)

;; Read-only: Check if verifier has verified a document
(define-read-only (is-verified (doc-id (buff 32)) (verifier principal))
  (is-some (map-get? verified-docs { doc-id: doc-id, verifier: verifier }))
)

;; Read-only: Has viewer access?
(define-read-only (has-access (doc-id (buff 32)) (viewer principal))
  (ok (or
        (is-eq (get owner (unwrap! (map-get? documents { doc-id: doc-id }) (err ERR-DOC-NOT-FOUND))) viewer)
        (default-to false (map-get? shared-access { doc-id: doc-id, viewer: viewer }))
      ))
)
