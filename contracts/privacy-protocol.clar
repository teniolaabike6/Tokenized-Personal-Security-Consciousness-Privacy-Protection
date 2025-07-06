;; Privacy Protocol Contract v1.0
;; Manages consciousness privacy protection

(define-constant CONTRACT_OWNER tx-sender)
(define-constant ERR_UNAUTHORIZED (err u200))
(define-constant ERR_PROTOCOL_NOT_FOUND (err u201))
(define-constant ERR_INVALID_LEVEL (err u202))
(define-constant ERR_INSUFFICIENT_PAYMENT (err u203))

;; Privacy protection levels
(define-constant PRIVACY_BASIC u1)
(define-constant PRIVACY_ENHANCED u2)
(define-constant PRIVACY_MAXIMUM u3)

;; Privacy protocol data
(define-map privacy-protocols
  { user: principal }
  {
    protection-level: uint,
    active: bool,
    expiry: uint,
    provider-id: uint,
    encrypted-data-hash: (buff 32)
  }
)

;; Protocol pricing
(define-map protocol-pricing
  { level: uint }
  { cost: uint }
)

;; Initialize pricing
(map-set protocol-pricing { level: PRIVACY_BASIC } { cost: u1000 })
(map-set protocol-pricing { level: PRIVACY_ENHANCED } { cost: u2500 })
(map-set protocol-pricing { level: PRIVACY_MAXIMUM } { cost: u5000 })

;; Activate privacy protection
(define-public (activate-protection (level uint) (provider-id uint) (encrypted-data-hash (buff 32)))
  (let ((cost (get-protocol-cost level)))
    (asserts! (and (>= level u1) (<= level u3)) ERR_INVALID_LEVEL)
    (asserts! (>= (stx-get-balance tx-sender) cost) ERR_INSUFFICIENT_PAYMENT)

    ;; Transfer payment to contract
    (try! (stx-transfer? cost tx-sender (as-contract tx-sender)))

    ;; Set privacy protocol
    (map-set privacy-protocols
      { user: tx-sender }
      {
        protection-level: level,
        active: true,
        expiry: (+ block-height u144000), ;; ~1000 blocks = ~1 week
        provider-id: provider-id,
        encrypted-data-hash: encrypted-data-hash
      }
    )
    (ok true)
  )
)

;; Deactivate privacy protection
(define-public (deactivate-protection)
  (match (map-get? privacy-protocols { user: tx-sender })
    protocol-data
    (begin
      (map-set privacy-protocols
        { user: tx-sender }
        (merge protocol-data { active: false })
      )
      (ok true)
    )
    ERR_PROTOCOL_NOT_FOUND
  )
)

;; Update protection level
(define-public (update-protection-level (new-level uint))
  (let ((cost (get-protocol-cost new-level)))
    (asserts! (and (>= new-level u1) (<= new-level u3)) ERR_INVALID_LEVEL)
    (asserts! (>= (stx-get-balance tx-sender) cost) ERR_INSUFFICIENT_PAYMENT)

    (match (map-get? privacy-protocols { user: tx-sender })
      protocol-data
      (begin
        (try! (stx-transfer? cost tx-sender (as-contract tx-sender)))
        (map-set privacy-protocols
          { user: tx-sender }
          (merge protocol-data { protection-level: new-level })
        )
        (ok true)
      )
      ERR_PROTOCOL_NOT_FOUND
    )
  )
)

;; Get user's privacy protocol
(define-read-only (get-user-protocol (user principal))
  (map-get? privacy-protocols { user: user })
)

;; Get protocol cost
(define-read-only (get-protocol-cost (level uint))
  (default-to u0 (get cost (map-get? protocol-pricing { level: level })))
)

;; Check if protection is active
(define-read-only (is-protection-active (user principal))
  (match (map-get? privacy-protocols { user: user })
    protocol-data
    (and (get active protocol-data) (> (get expiry protocol-data) block-height))
    false
  )
)
