;; prediction market contract

;; constants
(define-constant contract-owner tx-sender)
(define-constant err-owner-only (err u100))
(define-constant err-invalid-market (err u101))
(define-constant err-market-closed (err u102))
(define-constant err-insufficient-balance (err u103))
(define-constant err-invalid-outcome (err u104))

;; data vars
(define-data-var fee-percentage uint u1)

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
        total-liquidity: uint
    }
)

(define-map user-positions
    { market-id: uint, user: principal }
    { yes-shares: uint, no-shares: uint }
)

;; public functions
(define-public (create-market (question (string-ascii 256)) (resolution-time uint))
    (let
        (
            (market-id (+ (var-get next-market-id) u1))
        )
        (if (is-eq tx-sender contract-owner)
            (begin
                (map-set markets market-id {
                    question: question,
                    resolution-time: resolution-time,
                    resolved: false,
                    outcome: none,
                    yes-shares: u0,
                    no-shares: u0,
                    total-liquidity: u0
                })
                (var-set next-market-id market-id)
                (ok market-id)
            )
            err-owner-only
        )
    )
)

(define-public (buy-shares (market-id uint) (yes bool) (amount uint))
    (let
        (
            (market (unwrap! (map-get? markets market-id) err-invalid-market))
            (user-position (default-to { yes-shares: u0, no-shares: u0 }
                (map-get? user-positions { market-id: market-id, user: tx-sender })))
        )
        (asserts! (not (get resolved market)) err-market-closed)
        (if yes
            (map-set user-positions
                { market-id: market-id, user: tx-sender }
                { yes-shares: (+ (get yes-shares user-position) amount),
                  no-shares: (get no-shares user-position) })
            (map-set user-positions
                { market-id: market-id, user: tx-sender }
                { yes-shares: (get yes-shares user-position),
                  no-shares: (+ (get no-shares user-position) amount) })
        )
        (ok true)
    )
)

(define-public (resolve-market (market-id uint) (outcome bool))
    (let
        (
            (market (unwrap! (map-get? markets market-id) err-invalid-market))
        )
        (if (is-eq tx-sender contract-owner)
            (begin
                (map-set markets market-id
                    (merge market {
                        resolved: true,
                        outcome: (some outcome)
                    })
                )
                (ok true)
            )
            err-owner-only
        )
    )
)

(define-public (claim-winnings (market-id uint))
    (let
        (
            (market (unwrap! (map-get? markets market-id) err-invalid-market))
            (user-position (unwrap! (map-get? user-positions
                { market-id: market-id, user: tx-sender }) err-invalid-market))
        )
        (asserts! (get resolved market) err-market-closed)
        (match (get outcome market)
            outcome (ok true)
            err-invalid-outcome
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

;; data vars
(define-data-var next-market-id uint u0)
