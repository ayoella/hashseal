;; Verifier Reputation Contract - HashSeal
;; Controls reputation scores for verifiers using upvotes/downvotes
;; Access controlled by a known contract (e.g., document-registry)

(define-constant ERR-NOT-AUTHORIZED u100)
(define-constant ERR-INVALID-ADDRESS u101)
(define-constant ERR-ALREADY-VOTED u102)
(define-constant ERR-NOT-VERIFIER u103)

(define-constant MAX-REPUTATION u100)
(define-constant MIN-REPUTATION u0)

;; Replace this with actual contract principal when known
(define-constant AUTH-CALLER 'ST000000000000000000002AMW42H)

(define-map verifiers principal bool)
(define-map reputation-scores principal uint)
(define-map has-voted {voter: principal, target: principal} bool)

;; ========== PRIVATE HELPERS ==========

(define-private (only-authorized)
  (asserts! (is-eq tx-sender AUTH-CALLER) (err ERR-NOT-AUTHORIZED))
)

(define-private (is-registered-verifier (account principal))
  (default-to false (map-get? verifiers account))
)

(define-private (has-already-voted (voter principal) (target principal))
  (default-to false (map-get? has-voted {voter: voter, target: target}))
)

(define-private (set-voted (voter principal) (target principal))
  (map-set has-voted {voter: voter, target: target} true)
)

;; ========== PUBLIC FUNCTIONS ==========

;; Register a new verifier (only callable by AUTH-CALLER)
(define-public (register-verifier (account principal))
  (begin
    (only-authorized)
    (asserts! (not (is-eq account 'SP000000000000000000002Q6VF78)) (err ERR-INVALID-ADDRESS))
    (map-set verifiers account true)
    (map-set reputation-scores account u50)
    (ok true)
  )
)

;; Upvote a verifier (once per sender)
(define-public (upvote (verifier principal))
  (begin
    (asserts! (is-registered-verifier verifier) (err ERR-NOT-VERIFIER))
    (asserts! (not (has-already-voted tx-sender verifier)) (err ERR-ALREADY-VOTED))
    (let ((current (default-to u0 (map-get? reputation-scores verifier))))
      (let ((new-score (if (< current MAX-REPUTATION) (+ current u1) current)))
        (map-set reputation-scores verifier new-score)
        (set-voted tx-sender verifier)
        (ok new-score)
      )
    )
  )
)

;; Downvote a verifier (once per sender)
(define-public (downvote (verifier principal))
  (begin
    (asserts! (is-registered-verifier verifier) (err ERR-NOT-VERIFIER))
    (asserts! (not (has-already-voted tx-sender verifier)) (err ERR-ALREADY-VOTED))
    (let ((current (default-to u0 (map-get? reputation-scores verifier))))
      (let ((new-score (if (> current MIN-REPUTATION) (- current u1) current)))
        (map-set reputation-scores verifier new-score)
        (set-voted tx-sender verifier)
        (ok new-score)
      )
    )
  )
)

;; Reset a voter's vote record (only callable by AUTH-CALLER)
(define-public (reset-vote (voter principal) (target principal))
  (begin
    (only-authorized)
    (map-delete has-voted {voter: voter, target: target})
    (ok true)
  )
)

;; ========== READ-ONLY FUNCTIONS ==========

(define-read-only (get-reputation (verifier principal))
  (ok (default-to u0 (map-get? reputation-scores verifier)))
)

(define-read-only (is-verifier (account principal))
  (ok (is-registered-verifier account))
)

(define-read-only (did-vote (voter principal) (target principal))
  (ok (has-already-voted voter target))
)
