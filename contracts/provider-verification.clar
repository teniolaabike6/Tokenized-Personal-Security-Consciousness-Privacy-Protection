;; Provider Verification Contract v1.0
;; Validates consciousness privacy providers

(define-constant CONTRACT_OWNER tx-sender)
(define-constant ERR_UNAUTHORIZED (err u100))
(define-constant ERR_PROVIDER_EXISTS (err u101))
(define-constant ERR_PROVIDER_NOT_FOUND (err u102))
(define-constant ERR_INVALID_RATING (err u103))

;; Provider data structure
(define-map providers
  { provider-id: uint }
  {
    address: principal,
    name: (string-ascii 64),
    verified: bool,
    rating: uint,
    verification-date: uint,
    services: (list 10 (string-ascii 32))
  }
)

(define-data-var next-provider-id uint u1)

;; Register a new consciousness privacy provider
(define-public (register-provider (name (string-ascii 64)) (services (list 10 (string-ascii 32))))
  (let ((provider-id (var-get next-provider-id)))
    (asserts! (is-none (map-get? providers { provider-id: provider-id })) ERR_PROVIDER_EXISTS)
    (map-set providers
      { provider-id: provider-id }
      {
        address: tx-sender,
        name: name,
        verified: false,
        rating: u0,
        verification-date: block-height,
        services: services
      }
    )
    (var-set next-provider-id (+ provider-id u1))
    (ok provider-id)
  )
)

;; Verify a provider (only contract owner)
(define-public (verify-provider (provider-id uint))
  (begin
    (asserts! (is-eq tx-sender CONTRACT_OWNER) ERR_UNAUTHORIZED)
    (match (map-get? providers { provider-id: provider-id })
      provider-data
      (begin
        (map-set providers
          { provider-id: provider-id }
          (merge provider-data { verified: true, verification-date: block-height })
        )
        (ok true)
      )
      ERR_PROVIDER_NOT_FOUND
    )
  )
)

;; Rate a provider (1-5 scale)
(define-public (rate-provider (provider-id uint) (rating uint))
  (begin
    (asserts! (and (>= rating u1) (<= rating u5)) ERR_INVALID_RATING)
    (match (map-get? providers { provider-id: provider-id })
      provider-data
      (begin
        (map-set providers
          { provider-id: provider-id }
          (merge provider-data { rating: rating })
        )
        (ok true)
      )
      ERR_PROVIDER_NOT_FOUND
    )
  )
)

;; Get provider information
(define-read-only (get-provider (provider-id uint))
  (map-get? providers { provider-id: provider-id })
)

;; Check if provider is verified
(define-read-only (is-provider-verified (provider-id uint))
  (match (map-get? providers { provider-id: provider-id })
    provider-data (get verified provider-data)
    false
  )
)
