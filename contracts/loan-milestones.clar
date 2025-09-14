(define-constant err-milestone-not-found (err u200))
(define-constant err-milestone-already-completed (err u201))
(define-constant err-invalid-milestone (err u202))
(define-constant err-milestone-deadline-passed (err u203))

(define-map loan-milestones
  { loan-id: uint }
  {
    total-milestones: uint,
    completed-milestones: uint,
    milestone-list: (list 10 { 
      milestone-id: uint,
      description: (string-ascii 100),
      target-block: uint,
      completed: bool,
      completed-at: (optional uint),
      photo-hash: (optional (string-ascii 64))
    })
  }
)

(define-map milestone-verifications
  { loan-id: uint, milestone-id: uint }
  { verified-by: (list 5 principal), verification-count: uint }
)

(define-public (set-loan-milestones 
  (loan-id uint) 
  (milestones (list 10 { description: (string-ascii 100), target-block: uint }))
)
  (let
    (
      (milestone-list (map create-milestone-entry milestones))
      (total-count (len milestones))
    )
    (asserts! (> total-count u0) err-invalid-milestone)
    (map-set loan-milestones
      { loan-id: loan-id }
      {
        total-milestones: total-count,
        completed-milestones: u0,
        milestone-list: milestone-list
      }
    )
    (ok true)
  )
)

(define-private (create-milestone-entry (milestone { description: (string-ascii 100), target-block: uint }))
  {
    milestone-id: (+ (len (default-to (list) (get milestone-list (map-get? loan-milestones { loan-id: u0 })))) u1),
    description: (get description milestone),
    target-block: (get target-block milestone),
    completed: false,
    completed-at: none,
    photo-hash: none
  }
)

(define-public (complete-milestone 
  (loan-id uint) 
  (milestone-id uint) 
  (photo-hash (optional (string-ascii 64)))
)
  (let
    (
      (milestone-data (unwrap! (map-get? loan-milestones { loan-id: loan-id }) err-milestone-not-found))
      (updated-list (update-milestone-list (get milestone-list milestone-data) milestone-id photo-hash))
    )
    (map-set loan-milestones
      { loan-id: loan-id }
      (merge milestone-data {
        milestone-list: updated-list,
        completed-milestones: (+ (get completed-milestones milestone-data) u1)
      })
    )
    (ok true)
  )
)

(define-private (update-milestone-list 
  (milestone-list (list 10 { milestone-id: uint, description: (string-ascii 100), target-block: uint, completed: bool, completed-at: (optional uint), photo-hash: (optional (string-ascii 64)) }))
  (target-id uint) 
  (photo-hash (optional (string-ascii 64)))
)
  (map update-milestone-if-match milestone-list (list target-id target-id target-id target-id target-id target-id target-id target-id target-id target-id) (list photo-hash photo-hash photo-hash photo-hash photo-hash photo-hash photo-hash photo-hash photo-hash photo-hash))
)

(define-private (update-milestone-if-match 
  (milestone { milestone-id: uint, description: (string-ascii 100), target-block: uint, completed: bool, completed-at: (optional uint), photo-hash: (optional (string-ascii 64)) })
  (target-id uint) 
  (photo-hash (optional (string-ascii 64)))
)
  (if (is-eq (get milestone-id milestone) target-id)
    (merge milestone {
      completed: true,
      completed-at: (some stacks-block-height),
      photo-hash: photo-hash
    })
    milestone
  )
)

(define-read-only (get-loan-milestones (loan-id uint))
  (map-get? loan-milestones { loan-id: loan-id })
)

(define-read-only (get-milestone-progress (loan-id uint))
  (let
    (
      (milestone-data (map-get? loan-milestones { loan-id: loan-id }))
    )
    (match milestone-data
      data (/ (* (get completed-milestones data) u100) (get total-milestones data))
      u0
    )
  )
)
