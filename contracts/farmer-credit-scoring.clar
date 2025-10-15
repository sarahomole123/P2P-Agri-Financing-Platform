(define-constant err-farmer-not-found (err u500))
(define-constant err-unauthorized (err u501))
(define-constant err-invalid-input (err u502))
(define-constant err-score-exists (err u503))

(define-data-var min-credit-score uint u300)
(define-data-var max-credit-score uint u850)

(define-map credit-scores
  { farmer: principal }
  {
    base-score: uint,
    payment-history-score: uint,
    utilization-score: uint,
    consistency-score: uint,
    early-payment-bonus: uint,
    last-updated: uint,
    total-score: uint
  }
)

(define-map farmer-activity-metrics
  { farmer: principal }
  {
    total-loans-taken: uint,
    on-time-payments: uint,
    late-payments: uint,
    early-payments: uint,
    average-loan-size: uint,
    consecutive-on-time: uint,
    last-loan-block: uint,
    seasonal-loans: uint
  }
)

(define-map score-history
  { farmer: principal, period: uint }
  { score: uint, timestamp: uint }
)

(define-public (initialize-farmer-credit (farmer principal))
  (begin
    (asserts! (is-none (map-get? credit-scores { farmer: farmer })) err-score-exists)
    (map-set credit-scores
      { farmer: farmer }
      {
        base-score: u500,
        payment-history-score: u100,
        utilization-score: u100,
        consistency-score: u100,
        early-payment-bonus: u0,
        last-updated: stacks-block-height,
        total-score: u500
      }
    )
    (map-set farmer-activity-metrics
      { farmer: farmer }
      {
        total-loans-taken: u0,
        on-time-payments: u0,
        late-payments: u0,
        early-payments: u0,
        average-loan-size: u0,
        consecutive-on-time: u0,
        last-loan-block: u0,
        seasonal-loans: u0
      }
    )
    (ok true)
  )
)

(define-public (record-loan-activity (farmer principal) (loan-amount uint) (payment-status (string-ascii 20)))
  (let
    (
      (metrics (unwrap! (map-get? farmer-activity-metrics { farmer: farmer }) err-farmer-not-found))
      (new-total-loans (+ (get total-loans-taken metrics) u1))
      (new-on-time (if (is-eq payment-status "on-time") (+ (get on-time-payments metrics) u1) (get on-time-payments metrics)))
      (new-late (if (is-eq payment-status "late") (+ (get late-payments metrics) u1) (get late-payments metrics)))
      (new-early (if (is-eq payment-status "early") (+ (get early-payments metrics) u1) (get early-payments metrics)))
      (new-consecutive (if (is-eq payment-status "on-time") (+ (get consecutive-on-time metrics) u1) u0))
      (new-avg-size (/ (+ (* (get average-loan-size metrics) (get total-loans-taken metrics)) loan-amount) new-total-loans))
    )
    (map-set farmer-activity-metrics
      { farmer: farmer }
      {
        total-loans-taken: new-total-loans,
        on-time-payments: new-on-time,
        late-payments: new-late,
        early-payments: new-early,
        average-loan-size: new-avg-size,
        consecutive-on-time: new-consecutive,
        last-loan-block: stacks-block-height,
        seasonal-loans: (+ (get seasonal-loans metrics) u1)
      }
    )
    (try! (recalculate-credit-score farmer))
    (ok true)
  )
)

(define-private (recalculate-credit-score (farmer principal))
  (let
    (
      (metrics (unwrap! (map-get? farmer-activity-metrics { farmer: farmer }) err-farmer-not-found))
      (current-score (unwrap! (map-get? credit-scores { farmer: farmer }) err-farmer-not-found))
      (payment-score (calculate-payment-score metrics))
      (utilization-score (calculate-utilization-score metrics))
      (consistency-score (calculate-consistency-score metrics))
      (early-bonus (calculate-early-payment-bonus metrics))
      (total (+ payment-score (+ utilization-score (+ consistency-score early-bonus))))
    )
    (map-set credit-scores
      { farmer: farmer }
      {
        base-score: (get base-score current-score),
        payment-history-score: payment-score,
        utilization-score: utilization-score,
        consistency-score: consistency-score,
        early-payment-bonus: early-bonus,
        last-updated: stacks-block-height,
        total-score: (get-min total (var-get max-credit-score))
      }
    )
    (ok true)
  )
)

(define-private (calculate-payment-score (metrics { total-loans-taken: uint, on-time-payments: uint, late-payments: uint, early-payments: uint, average-loan-size: uint, consecutive-on-time: uint, last-loan-block: uint, seasonal-loans: uint }))
  (if (> (get total-loans-taken metrics) u0)
    (/ (* (get on-time-payments metrics) u250) (get total-loans-taken metrics))
    u100
  )
)

(define-private (calculate-utilization-score (metrics { total-loans-taken: uint, on-time-payments: uint, late-payments: uint, early-payments: uint, average-loan-size: uint, consecutive-on-time: uint, last-loan-block: uint, seasonal-loans: uint }))
  (if (> (get total-loans-taken metrics) u5)
    u200
    (if (> (get total-loans-taken metrics) u2)
      u150
      u100
    )
  )
)

(define-private (calculate-consistency-score (metrics { total-loans-taken: uint, on-time-payments: uint, late-payments: uint, early-payments: uint, average-loan-size: uint, consecutive-on-time: uint, last-loan-block: uint, seasonal-loans: uint }))
  (* (get consecutive-on-time metrics) u10)
)

(define-private (calculate-early-payment-bonus (metrics { total-loans-taken: uint, on-time-payments: uint, late-payments: uint, early-payments: uint, average-loan-size: uint, consecutive-on-time: uint, last-loan-block: uint, seasonal-loans: uint }))
  (* (get early-payments metrics) u20)
)

(define-private (get-min (a uint) (b uint))
  (if (<= a b) a b)
)

(define-read-only (get-farmer-credit-score (farmer principal))
  (map-get? credit-scores { farmer: farmer })
)

(define-read-only (get-farmer-activity-metrics (farmer principal))
  (map-get? farmer-activity-metrics { farmer: farmer })
)

(define-read-only (is-creditworthy (farmer principal) (threshold uint))
  (let
    (
      (score-data (map-get? credit-scores { farmer: farmer }))
    )
    (match score-data
      data (>= (get total-score data) threshold)
      false
    )
  )
)
