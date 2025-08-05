;;; verifier-staking.clar
;;; Staking contract for verifier reputation scores

(define-constant ERR-NOT-AUTHORIZED u100)
(define-constant ERR-INSUFFICIENT-STAKE u101)
(define-constant ERR-ZERO-ADDRESS u102)
(define-constant ERR-STAKING-PAUSED u103)

(define-data-var admin principal tx-sender)
(define-data-var staking-paused bool false)
(define-map stakes principal uint)

;; Private helper: check admin
(define-private (is-admin)
  (is-eq tx-sender (var-get admin))
)

;; Private helper: assert staking not paused
(define-private (assert-not-paused)
  (asserts! (not (var-get staking-paused)) (err ERR-STAKING-PAUSED))
)

;; Transfer admin
(define-public (transfer-admin (new-admin principal))
  (begin
    (asserts! (is-admin) (err ERR-NOT-AUTHORIZED))
    (asserts! (not (is-eq new-admin 'SP000000000000000000002Q6VF78)) (err ERR-ZERO-ADDRESS))
    (var-set admin new-admin)
    (ok true)
  )
)

;; Pause/unpause staking
(define-public (set-staking-paused (pause bool))
  (begin
    (asserts! (is-admin) (err ERR-NOT-AUTHORIZED))
    (var-set staking-paused pause)
    (ok pause)
  )
)

;; Stake tokens (mock logic - tokens not actually transferred)
(define-public (stake (amount uint))
  (begin
    (assert-not-paused)
    (let ((current (default-to u0 (map-get? stakes tx-sender))))
      (map-set stakes tx-sender (+ current amount))
      (ok true)
    )
  )
)

;; Unstake tokens
(define-public (unstake (amount uint))
  (let ((current (default-to u0 (map-get? stakes tx-sender))))
    (asserts! (>= current amount) (err ERR-INSUFFICIENT-STAKE))
    (map-set stakes tx-sender (- current amount))
    (ok true)
  )
)

;; Read-only: get current stake of a user
(define-read-only (get-stake (user principal))
  (ok (default-to u0 (map-get? stakes user)))
)

;; Read-only: is staking paused
(define-read-only (is-paused)
  (ok (var-get staking-paused))
)

;; Read-only: get admin
(define-read-only (get-admin)
  (ok (var-get admin))
)
