(define-constant contract-owner tx-sender)
(define-constant err-owner-only (err u100))
(define-constant err-not-found (err u101))
(define-constant err-unauthorized (err u102))
(define-constant err-invalid-amount (err u103))
(define-constant err-already-exists (err u104))
(define-constant err-insufficient-funds (err u105))
(define-constant err-loan-not-active (err u106))
(define-constant err-loan-not-funded (err u107))
(define-constant err-repayment-not-due (err u108))
(define-constant err-already-repaid (err u109))

(define-data-var next-loan-id uint u1)
(define-data-var platform-fee-rate uint u250)

(define-map loans
  { loan-id: uint }
  {
    farmer: principal,
    amount-requested: uint,
    amount-funded: uint,
    interest-rate: uint,
    duration-blocks: uint,
    created-at: uint,
    funded-at: (optional uint),
    repaid-at: (optional uint),
    crop-type: (string-ascii 50),
    farm-location: (string-ascii 100),
    status: (string-ascii 20)
  }
)

(define-map investments
  { loan-id: uint, investor: principal }
  {
    amount: uint,
    invested-at: uint,
    withdrawn: bool
  }
)

(define-map farmer-profiles
  { farmer: principal }
  {
    name: (string-ascii 100),
    farm-size: uint,
    experience-years: uint,
    total-loans: uint,
    successful-repayments: uint,
    reputation-score: uint
  }
)

(define-map investor-profiles
  { investor: principal }
  {
    total-invested: uint,
    active-investments: uint,
    total-returns: uint
  }
)

(define-map loan-investors
  { loan-id: uint }
  { investors: (list 50 principal) }
)

(define-public (create-farmer-profile (name (string-ascii 100)) (farm-size uint) (experience-years uint))
  (begin
    (asserts! (is-none (map-get? farmer-profiles { farmer: tx-sender })) err-already-exists)
    (map-set farmer-profiles
      { farmer: tx-sender }
      {
        name: name,
        farm-size: farm-size,
        experience-years: experience-years,
        total-loans: u0,
        successful-repayments: u0,
        reputation-score: u100
      }
    )
    (ok true)
  )
)

(define-public (create-loan-request 
  (amount-requested uint) 
  (interest-rate uint) 
  (duration-blocks uint) 
  (crop-type (string-ascii 50)) 
  (farm-location (string-ascii 100))
)
  (let
    (
      (loan-id (var-get next-loan-id))
      (farmer-profile (unwrap! (map-get? farmer-profiles { farmer: tx-sender }) err-not-found))
    )
    (asserts! (> amount-requested u0) err-invalid-amount)
    (asserts! (> duration-blocks u0) err-invalid-amount)
    (map-set loans
      { loan-id: loan-id }
      {
        farmer: tx-sender,
        amount-requested: amount-requested,
        amount-funded: u0,
        interest-rate: interest-rate,
        duration-blocks: duration-blocks,
        created-at: stacks-block-height,
        funded-at: none,
        repaid-at: none,
        crop-type: crop-type,
        farm-location: farm-location,
        status: "pending"
      }
    )
    (map-set farmer-profiles
      { farmer: tx-sender }
      (merge farmer-profile { total-loans: (+ (get total-loans farmer-profile) u1) })
    )
    (var-set next-loan-id (+ loan-id u1))
    (ok loan-id)
  )
)

(define-public (invest-in-loan (loan-id uint) (amount uint))
  (let
    (
      (loan (unwrap! (map-get? loans { loan-id: loan-id }) err-not-found))
      (existing-investment (map-get? investments { loan-id: loan-id, investor: tx-sender }))
      (investor-profile (default-to 
        { total-invested: u0, active-investments: u0, total-returns: u0 }
        (map-get? investor-profiles { investor: tx-sender })
      ))
      (current-investors (default-to 
        (list) 
        (get investors (map-get? loan-investors { loan-id: loan-id }))
      ))
    )
    (asserts! (is-eq (get status loan) "pending") err-loan-not-active)
    (asserts! (> amount u0) err-invalid-amount)
    (asserts! (<= (+ (get amount-funded loan) amount) (get amount-requested loan)) err-invalid-amount)
    (asserts! (is-none existing-investment) err-already-exists)
    
    (try! (stx-transfer? amount tx-sender (as-contract tx-sender)))
    
    (map-set investments
      { loan-id: loan-id, investor: tx-sender }
      {
        amount: amount,
        invested-at: stacks-block-height,
        withdrawn: false
      }
    )
    
    (map-set investor-profiles
      { investor: tx-sender }
      {
        total-invested: (+ (get total-invested investor-profile) amount),
        active-investments: (+ (get active-investments investor-profile) u1),
        total-returns: (get total-returns investor-profile)
      }
    )
    
    (map-set loan-investors
      { loan-id: loan-id }
      { investors: (unwrap! (as-max-len? (append current-investors tx-sender) u50) err-invalid-amount) }
    )
    
    (let ((new-funded-amount (+ (get amount-funded loan) amount)))
      (map-set loans
        { loan-id: loan-id }
        (merge loan {
          amount-funded: new-funded-amount,
          status: (if (is-eq new-funded-amount (get amount-requested loan)) "funded" "pending"),
          funded-at: (if (is-eq new-funded-amount (get amount-requested loan)) (some stacks-block-height) none)
        })
      )
    )
    
    (ok true)
  )
)

(define-public (withdraw-loan-funds (loan-id uint))
  (let
    (
      (loan (unwrap! (map-get? loans { loan-id: loan-id }) err-not-found))
    )
    (asserts! (is-eq (get farmer loan) tx-sender) err-unauthorized)
    (asserts! (is-eq (get status loan) "funded") err-loan-not-funded)
    (asserts! (is-eq (get amount-funded loan) (get amount-requested loan)) err-loan-not-funded)
    
    (try! (as-contract (stx-transfer? (get amount-requested loan) tx-sender (get farmer loan))))
    
    (map-set loans
      { loan-id: loan-id }
      (merge loan { status: "active" })
    )
    
    (ok true)
  )
)

(define-public (repay-loan (loan-id uint))
  (let
    (
      (loan (unwrap! (map-get? loans { loan-id: loan-id }) err-not-found))
      (repayment-amount (calculate-repayment-amount loan-id))
      (platform-fee (/ (* repayment-amount (var-get platform-fee-rate)) u10000))
      (investor-payout (- repayment-amount platform-fee))
      (farmer-profile (unwrap! (map-get? farmer-profiles { farmer: (get farmer loan) }) err-not-found))
    )
    (asserts! (is-eq (get farmer loan) tx-sender) err-unauthorized)
    (asserts! (is-eq (get status loan) "active") err-loan-not-active)
    (asserts! (is-none (get repaid-at loan)) err-already-repaid)
    
    (try! (stx-transfer? repayment-amount tx-sender (as-contract tx-sender)))
    (try! (as-contract (stx-transfer? platform-fee tx-sender contract-owner)))
    
    (map-set loans
      { loan-id: loan-id }
      (merge loan { 
        status: "repaid",
        repaid-at: (some stacks-block-height)
      })
    )
    
    (map-set farmer-profiles
      { farmer: (get farmer loan) }
      (merge farmer-profile { 
        successful-repayments: (+ (get successful-repayments farmer-profile) u1),
        reputation-score: (if (>= (+ (get reputation-score farmer-profile) u10) u1000) 
                            u1000 
                            (+ (get reputation-score farmer-profile) u10))
      })
    )
    
    (try! (distribute-returns loan-id investor-payout))
    
    (ok true)
  )
)
(define-private (distribute-returns (loan-id uint) (total-payout uint))
  (let
    (
      (loan (unwrap! (map-get? loans { loan-id: loan-id }) err-not-found))
      (investors-list (default-to (list) (get investors (map-get? loan-investors { loan-id: loan-id }))))
    )
    (fold distribute-to-investor investors-list { loan-id: loan-id, total-amount: (get amount-requested loan), payout: total-payout })
    (ok true)
  )
)

(define-private (distribute-to-investor 
  (investor principal) 
  (context { loan-id: uint, total-amount: uint, payout: uint })
)
  (let
    (
      (investment (unwrap-panic (map-get? investments { loan-id: (get loan-id context), investor: investor })))
      (investor-share (/ (* (get payout context) (get amount investment)) (get total-amount context)))
      (investor-profile (unwrap-panic (map-get? investor-profiles { investor: investor })))
    )
    (unwrap-panic (as-contract (stx-transfer? investor-share tx-sender investor)))
    
    (map-set investments
      { loan-id: (get loan-id context), investor: investor }
      (merge investment { withdrawn: true })
    )
    
    (map-set investor-profiles
      { investor: investor }
      (merge investor-profile {
        active-investments: (- (get active-investments investor-profile) u1),
        total-returns: (+ (get total-returns investor-profile) investor-share)
      })
    )
    
    context
  )
)

(define-read-only (calculate-repayment-amount (loan-id uint))
  (let
    (
      (loan (unwrap! (map-get? loans { loan-id: loan-id }) u0))
      (principal-amount (get amount-requested loan))
      (interest-amount (/ (* principal-amount (get interest-rate loan)) u10000))
    )
    (+ principal-amount interest-amount)
  )
)

(define-read-only (get-loan (loan-id uint))
  (map-get? loans { loan-id: loan-id })
)

(define-read-only (get-farmer-profile (farmer principal))
  (map-get? farmer-profiles { farmer: farmer })
)

(define-read-only (get-investor-profile (investor principal))
  (map-get? investor-profiles { investor: investor })
)

(define-read-only (get-investment (loan-id uint) (investor principal))
  (map-get? investments { loan-id: loan-id, investor: investor })
)

(define-read-only (get-loan-investors (loan-id uint))
  (map-get? loan-investors { loan-id: loan-id })
)

(define-public (set-platform-fee-rate (new-rate uint))
  (begin
    (asserts! (is-eq tx-sender contract-owner) err-owner-only)
    (asserts! (<= new-rate u1000) err-invalid-amount)
    (var-set platform-fee-rate new-rate)
    (ok true)
  )
)

(define-read-only (get-platform-fee-rate)
  (var-get platform-fee-rate)
)

(define-read-only (get-next-loan-id)
  (var-get next-loan-id)
)
