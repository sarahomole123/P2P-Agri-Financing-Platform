(define-constant err-not-authorized (err u600))
(define-constant err-badge-exists (err u601))
(define-constant err-invalid-badge (err u602))
(define-constant err-farmer-not-found (err u603))

(define-constant badge-first-loan u1)
(define-constant badge-five-loans u2)
(define-constant badge-perfect-record u3)
(define-constant badge-early-bird u4)
(define-constant badge-seasonal-expert u5)
(define-constant badge-high-value u6)
(define-constant badge-community-builder u7)
(define-constant badge-veteran u8)

(define-data-var contract-admin principal tx-sender)

(define-map farmer-badges
  { farmer: principal }
  {
    badges-earned: (list 20 uint),
    total-badges: uint,
    first-badge-at: (optional uint),
    last-badge-at: (optional uint)
  }
)

(define-map badge-metadata
  { badge-id: uint }
  {
    name: (string-ascii 50),
    description: (string-ascii 200),
    rarity: (string-ascii 20),
    total-awarded: uint
  }
)

(define-map farmer-badge-earned
  { farmer: principal, badge-id: uint }
  { earned-at: uint, verified: bool }
)

(define-private (initialize-badges)
  (begin
    (map-set badge-metadata { badge-id: badge-first-loan }
      { name: "Pioneer Spirit", description: "Successfully completed first loan on the platform", rarity: "common", total-awarded: u0 })
    (map-set badge-metadata { badge-id: badge-five-loans }
      { name: "Seasoned Cultivator", description: "Completed 5 successful loans with full repayment", rarity: "uncommon", total-awarded: u0 })
    (map-set badge-metadata { badge-id: badge-perfect-record }
      { name: "Flawless Steward", description: "Maintained 100% on-time payment record for 10+ loans", rarity: "rare", total-awarded: u0 })
    (map-set badge-metadata { badge-id: badge-early-bird }
      { name: "Early Harvest", description: "Made 3 or more early loan repayments", rarity: "uncommon", total-awarded: u0 })
    (map-set badge-metadata { badge-id: badge-seasonal-expert }
      { name: "Cycle Master", description: "Completed loans across 4 different seasons", rarity: "rare", total-awarded: u0 })
    (map-set badge-metadata { badge-id: badge-high-value }
      { name: "Ambitious Grower", description: "Successfully managed loan over 100 STX", rarity: "epic", total-awarded: u0 })
    true
  )
)

(define-public (award-badge (farmer principal) (badge-id uint))
  (let
    (
      (farmer-badge-data (default-to 
        { badges-earned: (list), total-badges: u0, first-badge-at: none, last-badge-at: none }
        (map-get? farmer-badges { farmer: farmer })))
      (badge-meta (unwrap! (map-get? badge-metadata { badge-id: badge-id }) err-invalid-badge))
    )
    (asserts! (is-none (map-get? farmer-badge-earned { farmer: farmer, badge-id: badge-id })) err-badge-exists)
    
    (map-set farmer-badge-earned
      { farmer: farmer, badge-id: badge-id }
      { earned-at: stacks-block-height, verified: true }
    )
    
    (map-set farmer-badges
      { farmer: farmer }
      {
        badges-earned: (unwrap! (as-max-len? (append (get badges-earned farmer-badge-data) badge-id) u20) err-invalid-badge),
        total-badges: (+ (get total-badges farmer-badge-data) u1),
        first-badge-at: (if (is-none (get first-badge-at farmer-badge-data)) 
          (some stacks-block-height) 
          (get first-badge-at farmer-badge-data)),
        last-badge-at: (some stacks-block-height)
      }
    )
    
    (map-set badge-metadata
      { badge-id: badge-id }
      (merge badge-meta { total-awarded: (+ (get total-awarded badge-meta) u1) })
    )
    
    (ok badge-id)
  )
)

(define-read-only (get-farmer-badges (farmer principal))
  (map-get? farmer-badges { farmer: farmer })
)

(define-read-only (get-badge-details (badge-id uint))
  (map-get? badge-metadata { badge-id: badge-id })
)

(define-read-only (has-badge (farmer principal) (badge-id uint))
  (is-some (map-get? farmer-badge-earned { farmer: farmer, badge-id: badge-id }))
)

(define-read-only (get-badge-earned-date (farmer principal) (badge-id uint))
  (map-get? farmer-badge-earned { farmer: farmer, badge-id: badge-id })
)

(initialize-badges)
