;; ----------------------------------------------------------
;; Contract: yield-vault.clar
;; Description: A simple STX-based yield vault.
;; Users deposit STX, earn fixed yield, and can withdraw later.
;; ----------------------------------------------------------

(define-constant ERR-ZERO-AMOUNT u100)
(define-constant ERR-NO-DEPOSIT u101)
(define-constant ERR-INSUFFICIENT-FUNDS u102)
(define-constant ERR-NOT-OWNER u103)

;; -------------------------
;; Data Variables and Maps
;; -------------------------

;; Contract owner (admin)
(define-data-var owner (optional principal) none)

;; Fixed annual percentage yield (APY) here set to 10%
(define-data-var yield-rate uint u10)

;; Total deposits (across all users)
(define-data-var total-deposits uint u0)

;; User vault structure
(define-map vaults
  { user: principal }
  { deposit: uint, timestamp: uint })

;; -------------------------
;; Initialization
;; -------------------------

(define-public (initialize (admin principal))
  (match (var-get owner) existing-owner
    (err ERR-NOT-OWNER)
    (begin
      (var-set owner (some admin))
      (ok admin)
    )
  )
)

;; -------------------------
;; Deposit Function
;; -------------------------
;; User deposits STX; their vault record is updated.

(define-public (deposit (amount uint))
  (let (
        (sender tx-sender)
      )
    (if (<= amount u0)
        (err ERR-ZERO-AMOUNT)
        (let (
              (maybe-vault (map-get? vaults { user: sender }))
              (prev-deposit (match maybe-vault v (get deposit v) u0))
             )
          (match (stx-transfer? amount sender (as-contract tx-sender))
            success
              (begin
                (map-set vaults { user: sender } { deposit: (+ prev-deposit amount), timestamp: burn-block-height })
                (var-set total-deposits (+ (var-get total-deposits) amount))
                (ok (+ prev-deposit amount))
              )
            error (err ERR-INSUFFICIENT-FUNDS)
          )
        )
    )
  )
)

;; -------------------------
;; Calculate Yield (read-only)
;; -------------------------
;; Rewards = deposit * rate * timeElapsed / 100

(define-read-only (get-yield (user principal))
  (match (map-get? vaults { user: user }) some-vault
    (let (
          (deposit-amount (get deposit some-vault))
          (start (get timestamp some-vault))
          (time-elapsed (- burn-block-height start))
          (rate (var-get yield-rate))
         )
      ;; simplified formula: yield = deposit * rate * time / 100 / 1000
      (ok (/ (* deposit-amount rate time-elapsed) u1000))
    )
    (ok u0)
  )
)

;; -------------------------
;; Withdraw Function
;; -------------------------
;; Withdraws all funds + yield to the user.

(define-public (withdraw)
  (let ((sender tx-sender))
    (match (map-get? vaults { user: sender }) some-vault
      (let (
            (deposit-amount (get deposit some-vault))
            (start (get timestamp some-vault))
           )
        (if (<= deposit-amount u0)
            (err ERR-NO-DEPOSIT)
            (let (
                  (rewards (unwrap! (get-yield sender) (err ERR-NO-DEPOSIT)))
                  (total (+ deposit-amount rewards))
                 )
              (begin
                (map-delete vaults { user: sender })
                (var-set total-deposits (- (var-get total-deposits) deposit-amount))
                (stx-transfer? total (as-contract tx-sender) sender)
              )
            )
        )
      )
      (err ERR-NO-DEPOSIT)
    )
  )
)

;; -------------------------
;; Owner Control
;; -------------------------

(define-public (set-yield-rate (new-rate uint))
  (match (var-get owner) current-owner
    (if (is-eq tx-sender current-owner)
        (begin
          (var-set yield-rate new-rate)
          (ok new-rate)
        )
        (err ERR-NOT-OWNER)
    )
    (err ERR-NOT-OWNER)
  )
)

;; -------------------------
;; Read-only Helpers
;; -------------------------

(define-read-only (get-total-deposits)
  (ok (var-get total-deposits)))

(define-read-only (get-yield-rate)
  (ok (var-get yield-rate)))

(define-read-only (get-vault (user principal))
  (match (map-get? vaults { user: user }) vault-data
    (ok vault-data)
    (ok { deposit: u0, timestamp: u0 })
  )
)
