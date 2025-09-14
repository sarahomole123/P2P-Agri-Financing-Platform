(define-constant err-unauthorized-oracle (err u400))
(define-constant err-weather-not-found (err u401))
(define-constant err-invalid-severity (err u402))
(define-constant err-already-reported (err u403))

(define-data-var oracle-admin principal tx-sender)

(define-map authorized-oracles
  { oracle: principal }
  { active: bool, reports-count: uint }
)

(define-map weather-events
  { location: (string-ascii 100), date-block: uint }
  {
    event-type: (string-ascii 50),
    severity: uint,
    temperature-low: int,
    temperature-high: int,
    precipitation: uint,
    wind-speed: uint,
    oracle-reporter: principal,
    reported-at: uint,
    verified: bool
  }
)

(define-map location-weather-history
  { location: (string-ascii 100) }
  { event-count: uint, severe-events: uint }
)

(define-public (authorize-oracle (oracle principal))
  (begin
    (asserts! (is-eq tx-sender (var-get oracle-admin)) err-unauthorized-oracle)
    (map-set authorized-oracles
      { oracle: oracle }
      { active: true, reports-count: u0 }
    )
    (ok true)
  )
)

(define-public (report-weather-event 
  (location (string-ascii 100))
  (event-type (string-ascii 50))
  (severity uint)
  (temp-low int)
  (temp-high int)
  (precipitation uint)
  (wind-speed uint)
)
  (let
    (
      (oracle-data (unwrap! (map-get? authorized-oracles { oracle: tx-sender }) err-unauthorized-oracle))
      (event-key { location: location, date-block: stacks-block-height })
      (location-history (default-to { event-count: u0, severe-events: u0 } 
        (map-get? location-weather-history { location: location })))
    )
    (asserts! (get active oracle-data) err-unauthorized-oracle)
    (asserts! (<= severity u10) err-invalid-severity)
    (asserts! (is-none (map-get? weather-events event-key)) err-already-reported)
    
    (map-set weather-events
      event-key
      {
        event-type: event-type,
        severity: severity,
        temperature-low: temp-low,
        temperature-high: temp-high,
        precipitation: precipitation,
        wind-speed: wind-speed,
        oracle-reporter: tx-sender,
        reported-at: stacks-block-height,
        verified: true
      }
    )
    
    (map-set authorized-oracles
      { oracle: tx-sender }
      (merge oracle-data { reports-count: (+ (get reports-count oracle-data) u1) })
    )
    
    (map-set location-weather-history
      { location: location }
      {
        event-count: (+ (get event-count location-history) u1),
        severe-events: (+ (get severe-events location-history) 
          (if (>= severity u7) u1 u0))
      }
    )
    
    (ok true)
  )
)

(define-read-only (check-severe-weather (location (string-ascii 100)) (since-block uint))
  (let
    (
      (current-block stacks-block-height)
    )
    (check-weather-in-range location since-block current-block)
  )
)

(define-read-only (check-weather-in-range (location (string-ascii 100)) (start-block uint) (end-block uint))
  (let
    (
      (weather-data (map-get? weather-events { location: location, date-block: start-block }))
    )
    (match weather-data
      event (and (>= (get severity event) u7) (<= start-block end-block))
      false
    )
  )
)

(define-read-only (get-weather-event (location (string-ascii 100)) (date-block uint))
  (map-get? weather-events { location: location, date-block: date-block })
)

(define-read-only (get-location-weather-summary (location (string-ascii 100)))
  (map-get? location-weather-history { location: location })
)

(define-read-only (is-authorized-oracle (oracle principal))
  (default-to false (get active (map-get? authorized-oracles { oracle: oracle })))
)
