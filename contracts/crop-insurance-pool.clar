(define-constant err-not-found (err u300))
(define-constant err-insufficient-funds (err u301))
(define-constant err-unauthorized (err u302))
(define-constant err-already-insured (err u303))
(define-constant err-claim-exists (err u304))
(define-constant err-invalid-amount (err u305))

(define-data-var pool-balance uint u0)
(define-data-var next-policy-id uint u1)
(define-data-var premium-rate uint u500)

(define-map insurance-policies
  { policy-id: uint }
  {
    farmer: principal,
    loan-id: uint,
    coverage-amount: uint,
    premium-paid: uint,
    active: bool,
    created-at: uint,
    expires-at: uint
  }
)

(define-map farmer-policies
  { farmer: principal, loan-id: uint }
  { policy-id: uint }
)

(define-map insurance-claims
  { policy-id: uint }
  {
    claim-amount: uint,
    reason: (string-ascii 100),
    submitted-at: uint,
    approved: bool,
    paid: bool
  }
)

(define-public (contribute-to-pool (amount uint))
  (begin
    (asserts! (> amount u0) err-invalid-amount)
    (try! (stx-transfer? amount tx-sender (as-contract tx-sender)))
    (var-set pool-balance (+ (var-get pool-balance) amount))
    (ok true)
  )
)

(define-public (purchase-insurance (loan-id uint) (coverage-amount uint))
  (let
    (
      (policy-id (var-get next-policy-id))
      (premium-amount (/ (* coverage-amount (var-get premium-rate)) u10000))
      (expiry-block (+ stacks-block-height u52560))
    )
    (asserts! (> coverage-amount u0) err-invalid-amount)
    (asserts! (is-none (map-get? farmer-policies { farmer: tx-sender, loan-id: loan-id })) err-already-insured)
    (asserts! (<= premium-amount (stx-get-balance tx-sender)) err-insufficient-funds)
    
    (try! (stx-transfer? premium-amount tx-sender (as-contract tx-sender)))
    (var-set pool-balance (+ (var-get pool-balance) premium-amount))
    
    (map-set insurance-policies
      { policy-id: policy-id }
      {
        farmer: tx-sender,
        loan-id: loan-id,
        coverage-amount: coverage-amount,
        premium-paid: premium-amount,
        active: true,
        created-at: stacks-block-height,
        expires-at: expiry-block
      }
    )
    
    (map-set farmer-policies
      { farmer: tx-sender, loan-id: loan-id }
      { policy-id: policy-id }
    )
    
    (var-set next-policy-id (+ policy-id u1))
    (ok policy-id)
  )
)

(define-public (file-claim (policy-id uint) (claim-amount uint) (reason (string-ascii 100)))
  (let
    (
      (policy (unwrap! (map-get? insurance-policies { policy-id: policy-id }) err-not-found))
    )
    (asserts! (is-eq (get farmer policy) tx-sender) err-unauthorized)
    (asserts! (get active policy) err-not-found)
    (asserts! (> (get expires-at policy) stacks-block-height) err-not-found)
    (asserts! (<= claim-amount (get coverage-amount policy)) err-invalid-amount)
    (asserts! (is-none (map-get? insurance-claims { policy-id: policy-id })) err-claim-exists)
    
    (map-set insurance-claims
      { policy-id: policy-id }
      {
        claim-amount: claim-amount,
        reason: reason,
        submitted-at: stacks-block-height,
        approved: false,
        paid: false
      }
    )
    (ok true)
  )
)

(define-public (process-claim (policy-id uint) (approve bool))
  (let
    (
      (claim (unwrap! (map-get? insurance-claims { policy-id: policy-id }) err-not-found))
      (policy (unwrap! (map-get? insurance-policies { policy-id: policy-id }) err-not-found))
    )
    (asserts! (not (get paid claim)) err-not-found)
    
    (if approve
      (begin
        (asserts! (>= (var-get pool-balance) (get claim-amount claim)) err-insufficient-funds)
        (try! (as-contract (stx-transfer? (get claim-amount claim) tx-sender (get farmer policy))))
        (var-set pool-balance (- (var-get pool-balance) (get claim-amount claim)))
        
        (map-set insurance-claims
          { policy-id: policy-id }
          (merge claim { approved: true, paid: true })
        )
        
        (map-set insurance-policies
          { policy-id: policy-id }
          (merge policy { active: false })
        )
      )
      (map-set insurance-claims
        { policy-id: policy-id }
        (merge claim { approved: false })
      )
    )
    (ok approve)
  )
)

(define-read-only (get-pool-balance)
  (var-get pool-balance)
)

(define-read-only (get-policy (policy-id uint))
  (map-get? insurance-policies { policy-id: policy-id })
)

(define-read-only (get-farmer-policy (farmer principal) (loan-id uint))
  (map-get? farmer-policies { farmer: farmer, loan-id: loan-id })
)

(define-read-only (get-claim (policy-id uint))
  (map-get? insurance-claims { policy-id: policy-id })
)

(define-read-only (get-premium-rate)
  (var-get premium-rate)
)
