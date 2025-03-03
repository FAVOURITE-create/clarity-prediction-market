;; prediction market contract

;; constants
(define-constant contract-owner tx-sender)
(define-constant err-owner-only (err u100))
(define-constant err-invalid-market (err u101))
(define-constant err-market-closed (err u102))
(define-constant err-insufficient-balance (err u103))
(define-constant err-invalid-outcome (err u104))
(define-constant err-unauthorized (err u105))
(define-constant err-already-resolved (err u106))
(define-constant err-invalid-amount (err u107))
(define-constant err-zero-amount (err u108))
(define-constant err-already-claimed (err u109))

;; 1 STX per share
(define-constant stx-per-share u1000000)
;; maximum resolution time (2 years from now)
(define-constant max-resolution-time u105120)

;; data vars
(define-data-var fee-percentage uint u1)
(define-data-var next-market-id uint u0)
(define-data-var total-locked-stx uint u0)

;; data maps
(define-map markets
    uint
    {
        question: (string-ascii 256),
        resolution-time: uint,
        resolved: bool,
        outcome: (optional bool),
        yes-shares: uint,
        no-shares: uint,
        total-liquidity: uint,
        stx-locked: uint
    }
)

(define-map user-positions
    { market-id: uint, user: principal }
    { yes-shares: uint, no-shares: uint, stx-locked: uint, claimed: bool }
)

;; public functions
(define-public (create-market (question (string-ascii 256)) (resolution-time uint))
    (let
        (
            (market-id (+ (var-get next-market-id) u1))
        )
        (asserts! (is-eq tx-sender contract-owner) err-owner-only)
        (asserts! (> resolution-time block-height) err-invalid-market)
        (asserts! (<= (- resolution-time block-height) max-resolution-time) err-invalid-market)
        
        (map-set markets market-id {
            question: question,
            resolution-time: resolution-time,
            resolved: false,
            outcome: none,
            yes-shares: u0,
            no-shares: u0,
            total-liquidity: u0,
            stx-locked: u0
        })
        (var-set next-market-id market-id)
        (ok market-id)
    )
)

(define-public (buy-shares (market-id uint) (yes bool) (amount uint) (stx-amount uint))
    (let
        (
            (market (unwrap! (map-get? markets market-id) err-invalid-market))
            (user-position (default-to { yes-shares: u0, no-shares: u0, stx-locked: u0, claimed: false }
                (map-get? user-positions { market-id: market-id, user: tx-sender })))
        )
        (asserts! (not (get resolved market)) err-market-closed)
        (asserts! (> amount u0) err-zero-amount)
        (asserts! (is-eq stx-amount (* amount stx-per-share)) err-insufficient-balance)
        
        ;; Transfer STX to contract
        (try! (stx-transfer? stx-amount tx-sender (as-contract tx-sender)))
        
        ;; Update positions
        (map-set user-positions
            { market-id: market-id, user: tx-sender }
            { yes-shares: (+ (get yes-shares user-position) (if yes amount u0)),
              no-shares: (+ (get no-shares user-position) (if yes u0 amount)),
              stx-locked: (+ (get stx-locked user-position) stx-amount),
              claimed: false })
        
        ;; Update market state
        (map-set markets market-id
            (merge market {
                yes-shares: (if yes (+ (get yes-shares market) amount) (get yes-shares market)),
                no-shares: (if yes (get no-shares market) (+ (get no-shares market) amount)),
                total-liquidity: (+ (get total-liquidity market) stx-amount),
                stx-locked: (+ (get stx-locked market) stx-amount)
            })
        )
        (ok true)
    )
)

(define-public (resolve-market (market-id uint) (outcome bool))
    (let
        (
            (market (unwrap! (map-get? markets market-id) err-invalid-market))
        )
        (asserts! (is-eq tx-sender contract-owner) err-owner-only)
        (asserts! (not (get resolved market)) err-already-resolved)
        (asserts! (>= block-height (get resolution-time market)) err-market-closed)
        
        (map-set markets market-id
            (merge market {
                resolved: true,
                outcome: (some outcome)
            })
        )
        (ok true)
    )
)

(define-public (claim-winnings (market-id uint))
    (let
        (
            (market (unwrap! (map-get? markets market-id) err-invalid-market))
            (user-position (unwrap! (map-get? user-positions
                { market-id: market-id, user: tx-sender }) err-invalid-market))
            (outcome (unwrap! (get outcome market) err-invalid-outcome))
        )
        (asserts! (get resolved market) err-market-closed)
        (asserts! (not (get claimed user-position)) err-already-claimed)
        
        (let
            (
                (winning-shares (if outcome 
                    (get yes-shares user-position)
                    (get no-shares user-position)))
                (winnings (get stx-locked user-position))
            )
            
            ;; Transfer winnings
            (try! (as-contract (stx-transfer? winnings tx-sender tx-sender)))
            
            ;; Mark position as claimed
            (map-set user-positions 
                { market-id: market-id, user: tx-sender }
                (merge user-position { claimed: true }))
            (ok winnings)
        )
    )
)

;; read only functions
(define-read-only (get-market (market-id uint))
    (ok (map-get? markets market-id))
)

(define-read-only (get-position (market-id uint) (user principal))
    (ok (map-get? user-positions { market-id: market-id, user: user }))
)
