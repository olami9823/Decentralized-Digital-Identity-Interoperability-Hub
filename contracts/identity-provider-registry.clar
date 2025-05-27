;; Early Warning Contract
;; Alerts regulators to systemic risks and potential threats

(define-constant CONTRACT_OWNER tx-sender)
(define-constant ERR_UNAUTHORIZED (err u500))
(define-constant ERR_INVALID_THRESHOLD (err u501))
(define-constant ERR_ALERT_NOT_FOUND (err u502))

;; Alert severity levels
(define-constant SEVERITY_LOW u1)
(define-constant SEVERITY_MEDIUM u2)
(define-constant SEVERITY_HIGH u3)
(define-constant SEVERITY_CRITICAL u4)

;; Alert types
(define-constant ALERT_LIQUIDITY_CRISIS "liquidity-crisis")
(define-constant ALERT_CREDIT_CONCENTRATION "credit-concentration")
(define-constant ALERT_MARKET_VOLATILITY "market-volatility")
(define-constant ALERT_CONTAGION_RISK "contagion-risk")

;; Risk thresholds
(define-map risk-thresholds
  { metric-type: (string-ascii 50) }
  {
    low-threshold: uint,
    medium-threshold: uint,
    high-threshold: uint,
    critical-threshold: uint
  }
)

;; Active alerts
(define-map alerts
  { alert-id: uint }
  {
    alert-type: (string-ascii 50),
    severity: uint,
    institution-id: uint,
    metric-value: uint,
    threshold-breached: uint,
    description: (string-ascii 500),
    created-at: uint,
    acknowledged: bool,
    resolved: bool
  }
)

;; System-wide alerts
(define-map system-alerts
  { alert-id: uint }
  {
    alert-type: (string-ascii 50),
    severity: uint,
    affected-institutions: uint,
    systemic-risk-score: uint,
    description: (string-ascii 500),
    created-at: uint,
    acknowledged: bool
  }
)

(define-data-var next-alert-id uint u1)

;; Set risk thresholds
(define-public (set-risk-thresholds
  (metric-type (string-ascii 50))
  (low-threshold uint)
  (medium-threshold uint)
  (high-threshold uint)
  (critical-threshold uint))
  (begin
    (asserts! (is-eq tx-sender CONTRACT_OWNER) ERR_UNAUTHORIZED)
    (asserts! (and (< low-threshold medium-threshold)
                   (< medium-threshold high-threshold)
                   (< high-threshold critical-threshold)) ERR_INVALID_THRESHOLD)

    (map-set risk-thresholds
      { metric-type: metric-type }
      {
        low-threshold: low-threshold,
        medium-threshold: medium-threshold,
        high-threshold: high-threshold,
        critical-threshold: critical-threshold
      }
    )
    (ok true)
  )
)

;; Check and create alerts based on risk data
(define-public (check-risk-levels (institution-id uint) (metric-type (string-ascii 50)) (metric-value uint))
  (let (
    (thresholds (unwrap! (map-get? risk-thresholds { metric-type: metric-type }) ERR_INVALID_THRESHOLD))
    (severity (determine-severity metric-value thresholds))
  )
    (if (> severity u0)
      (create-alert institution-id metric-type severity metric-value)
      (ok false)
    )
  )
)

;; Determine alert severity based on thresholds
(define-private (determine-severity (value uint) (thresholds { low-threshold: uint, medium-threshold: uint, high-threshold: uint, critical-threshold: uint }))
  (if (>= value (get critical-threshold thresholds))
    SEVERITY_CRITICAL
    (if (>= value (get high-threshold thresholds))
      SEVERITY_HIGH
      (if (>= value (get medium-threshold thresholds))
        SEVERITY_MEDIUM
        (if (>= value (get low-threshold thresholds))
          SEVERITY_LOW
          u0
        )
      )
    )
  )
)

;; Create a new alert
(define-private (create-alert (institution-id uint) (metric-type (string-ascii 50)) (severity uint) (metric-value uint))
  (let (
    (alert-id (var-get next-alert-id))
    (threshold-breached (get-threshold-for-severity metric-type severity))
  )
    (map-set alerts
      { alert-id: alert-id }
      {
        alert-type: metric-type,
        severity: severity,
        institution-id: institution-id,
        metric-value: metric-value,
        threshold-breached: threshold-breached,
        description: "Risk threshold breached",
        created-at: block-height,
        acknowledged: false,
        resolved: false
      }
    )

    (var-set next-alert-id (+ alert-id u1))
    (ok true)
  )
)

;; Get threshold value for severity level
(define-private (get-threshold-for-severity (metric-type (string-ascii 50)) (severity uint))
  (let ((thresholds (unwrap-panic (map-get? risk-thresholds { metric-type: metric-type }))))
    (if (is-eq severity SEVERITY_CRITICAL)
      (get critical-threshold thresholds)
      (if (is-eq severity SEVERITY_HIGH)
        (get high-threshold thresholds)
        (if (is-eq severity SEVERITY_MEDIUM)
          (get medium-threshold thresholds)
          (get low-threshold thresholds)
        )
      )
    )
  )
)

;; Acknowledge an alert
(define-public (acknowledge-alert (alert-id uint))
  (let ((alert (unwrap! (map-get? alerts { alert-id: alert-id }) ERR_ALERT_NOT_FOUND)))
    (asserts! (is-eq tx-sender CONTRACT_OWNER) ERR_UNAUTHORIZED)

    (map-set alerts
      { alert-id: alert-id }
      (merge alert { acknowledged: true })
    )
    (ok true)
  )
)

;; Resolve an alert
(define-public (resolve-alert (alert-id uint))
  (let ((alert (unwrap! (map-get? alerts { alert-id: alert-id }) ERR_ALERT_NOT_FOUND)))
    (asserts! (is-eq tx-sender CONTRACT_OWNER) ERR_UNAUTHORIZED)

    (map-set alerts
      { alert-id: alert-id }
      (merge alert { resolved: true })
    )
    (ok true)
  )
)

;; Get alert details
(define-read-only (get-alert (alert-id uint))
  (map-get? alerts { alert-id: alert-id })
)

;; Get risk thresholds
(define-read-only (get-risk-thresholds (metric-type (string-ascii 50)))
  (map-get? risk-thresholds { metric-type: metric-type })
)

;; Check if alert exists for institution and metric
(define-read-only (has-active-alert (institution-id uint) (metric-type (string-ascii 50)))
  ;; Simplified check - in real implementation would iterate through alerts
  false
)
