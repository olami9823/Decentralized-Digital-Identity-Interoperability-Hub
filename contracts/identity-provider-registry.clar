;; Identity Provider Registry Contract
;; Manages registration and verification of identity providers

(define-constant CONTRACT_OWNER tx-sender)
(define-constant ERR_UNAUTHORIZED (err u100))
(define-constant ERR_PROVIDER_EXISTS (err u101))
(define-constant ERR_PROVIDER_NOT_FOUND (err u102))
(define-constant ERR_INVALID_STATUS (err u103))

;; Provider status constants
(define-constant STATUS_PENDING u0)
(define-constant STATUS_VERIFIED u1)
(define-constant STATUS_SUSPENDED u2)
(define-constant STATUS_REVOKED u3)

;; Data structures
(define-map identity-providers
  { provider-id: (string-ascii 64) }
  {
    name: (string-ascii 128),
    endpoint: (string-ascii 256),
    public-key: (buff 33),
    status: uint,
    registered-at: uint,
    verified-at: (optional uint)
  }
)

(define-map provider-trust-scores
  { provider-id: (string-ascii 64) }
  { score: uint, last-updated: uint }
)

;; Register a new identity provider
(define-public (register-provider
  (provider-id (string-ascii 64))
  (name (string-ascii 128))
  (endpoint (string-ascii 256))
  (public-key (buff 33)))
  (begin
    (asserts! (is-none (map-get? identity-providers { provider-id: provider-id })) ERR_PROVIDER_EXISTS)
    (map-set identity-providers
      { provider-id: provider-id }
      {
        name: name,
        endpoint: endpoint,
        public-key: public-key,
        status: STATUS_PENDING,
        registered-at: block-height,
        verified-at: none
      }
    )
    (ok provider-id)
  )
)

;; Verify an identity provider (admin only)
(define-public (verify-provider (provider-id (string-ascii 64)))
  (let ((provider (unwrap! (map-get? identity-providers { provider-id: provider-id }) ERR_PROVIDER_NOT_FOUND)))
    (asserts! (is-eq tx-sender CONTRACT_OWNER) ERR_UNAUTHORIZED)
    (map-set identity-providers
      { provider-id: provider-id }
      (merge provider {
        status: STATUS_VERIFIED,
        verified-at: (some block-height)
      })
    )
    (ok true)
  )
)

;; Update provider trust score
(define-public (update-trust-score
  (provider-id (string-ascii 64))
  (score uint))
  (begin
    (asserts! (is-eq tx-sender CONTRACT_OWNER) ERR_UNAUTHORIZED)
    (asserts! (is-some (map-get? identity-providers { provider-id: provider-id })) ERR_PROVIDER_NOT_FOUND)
    (map-set provider-trust-scores
      { provider-id: provider-id }
      { score: score, last-updated: block-height }
    )
    (ok true)
  )
)

;; Get provider information
(define-read-only (get-provider (provider-id (string-ascii 64)))
  (map-get? identity-providers { provider-id: provider-id })
)

;; Get provider trust score
(define-read-only (get-trust-score (provider-id (string-ascii 64)))
  (map-get? provider-trust-scores { provider-id: provider-id })
)

;; Check if provider is verified
(define-read-only (is-provider-verified (provider-id (string-ascii 64)))
  (match (map-get? identity-providers { provider-id: provider-id })
    provider (is-eq (get status provider) STATUS_VERIFIED)
    false
  )
)
