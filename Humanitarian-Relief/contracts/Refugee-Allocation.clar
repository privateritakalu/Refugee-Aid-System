;; Automated Refugee Support System Smart Contract
;; This contract manages transparent allocation of resources to refugees
;; including registration, resource allocation, donations, and distribution tracking

;; Contract owner - typically a humanitarian organization
(define-constant CONTRACT-OWNER tx-sender)

;; Error constants
(define-constant ERR-UNAUTHORIZED-ACCESS (err u1001))
(define-constant ERR-REFUGEE-NOT-FOUND (err u1002))
(define-constant ERR-REFUGEE-ALREADY-REGISTERED (err u1003))
(define-constant ERR-INVALID-RESOURCE-TYPE (err u1004))
(define-constant ERR-INSUFFICIENT-RESOURCES (err u1005))
(define-constant ERR-INVALID-AMOUNT (err u1006))
(define-constant ERR-DONATION-FAILED (err u1007))
(define-constant ERR-ALREADY-VERIFIED (err u1008))
(define-constant ERR-NOT-VERIFIED (err u1009))
(define-constant ERR-INVALID-PRIORITY-LEVEL (err u1010))
(define-constant ERR-RESOURCE-LIMIT-EXCEEDED (err u1011))
(define-constant ERR-INVALID-INPUT (err u1012))
(define-constant ERR-INVALID-STRING-LENGTH (err u1013))
(define-constant ERR-INVALID-AGE (err u1014))
(define-constant ERR-INVALID-FAMILY-SIZE (err u1015))

;; Validation constants
(define-constant MIN-DONATION-AMOUNT u1000000) ;; Minimum 1 STX in microSTX
(define-constant MAX-RESOURCE-ALLOCATION u10000000) ;; Maximum 10 STX worth of resources
(define-constant RESOURCE-TYPES (list "food" "shelter" "medical" "education" "clothing"))
(define-constant MAX-AGE u120)
(define-constant MAX-FAMILY-SIZE u50)
(define-constant MIN-NAME-LENGTH u1)
(define-constant MAX-NAME-LENGTH u50)
(define-constant MIN-LOCATION-LENGTH u1)
(define-constant MAX-LOCATION-LENGTH u100)
(define-constant MIN-ROLE-LENGTH u1)
(define-constant MAX-ROLE-LENGTH u20)
(define-constant MAX-MESSAGE-LENGTH u200)
(define-constant MIN-REQUESTED-AMOUNT u1)
(define-constant MAX-REQUESTED-AMOUNT u1000000)

;; Data structures
;; Refugee profile containing personal information and verification status
(define-map refugees
  { refugee-id: uint }
  {
    wallet-address: principal,
    name: (string-ascii 50),
    age: uint,
    family-size: uint,
    location: (string-ascii 100),
    registration-date: uint,
    verification-status: bool,
    priority-level: uint, ;; 1-5 scale, 5 being highest priority
    total-received: uint
  }
)

;; Resource pool tracking available resources by type
(define-map resource-pool
  { resource-type: (string-ascii 9) }
  {
    available-amount: uint,
    allocated-amount: uint,
    unit-cost: uint ;; Cost per unit in microSTX
  }
)

;; Individual resource allocations to specific refugees
(define-map resource-allocations
  { refugee-id: uint, resource-type: (string-ascii 9) }
  {
    allocated-amount: uint,
    allocation-date: uint,
    status: (string-ascii 11), ;; "pending", "approved", "distributed"
    approver: (optional principal)
  }
)

;; Donation tracking for transparency
(define-map donations
  { donation-id: uint }
  {
    donor: principal,
    amount: uint,
    resource-type: (string-ascii 9),
    donation-date: uint,
    message: (optional (string-ascii 200))
  }
)

;; Authorized personnel who can verify refugees and approve allocations
(define-map authorized-personnel
  { personnel: principal }
  { role: (string-ascii 20), authorized-date: uint }
)

;; Counter variables for generating unique IDs
(define-data-var refugee-counter uint u0)
(define-data-var donation-counter uint u0)

;; Contract statistics for reporting
(define-data-var total-donations uint u0)
(define-data-var total-refugees uint u0)
(define-data-var total-allocations uint u0)

;; Contract pause state for emergency situations
(define-data-var contract-paused bool false)

;; Private helper function to check if caller is authorized personnel
(define-private (is-authorized-personnel (caller principal))
  (is-some (map-get? authorized-personnel { personnel: caller }))
)

;; Private helper function to validate resource type
(define-private (is-valid-resource-type (resource-type (string-ascii 9)))
  (is-some (index-of RESOURCE-TYPES resource-type))
)

;; Private helper function to validate priority level (1-5)
(define-private (is-valid-priority-level (priority uint))
  (and (>= priority u1) (<= priority u5))
)

;; Private helper function to validate string length
(define-private (is-valid-string-length (str (string-ascii 200)) (min-len uint) (max-len uint))
  (let ((str-len (len str)))
    (and (>= str-len min-len) (<= str-len max-len))
  )
)

;; Private helper function to validate age
(define-private (is-valid-age (age uint))
  (and (> age u0) (<= age MAX-AGE))
)

;; Private helper function to validate family size
(define-private (is-valid-family-size (family-size uint))
  (and (>= family-size u1) (<= family-size MAX-FAMILY-SIZE))
)

;; Private helper function to validate refugee ID exists and get data
(define-private (validate-refugee-exists (refugee-id uint))
  (map-get? refugees { refugee-id: refugee-id })
)

;; Private helper function to validate principal is not null/invalid
(define-private (is-valid-principal (principal-to-check principal))
  (not (is-eq principal-to-check 'SP000000000000000000002Q6VF78))
)

;; Private helper function to validate requested amount
(define-private (is-valid-requested-amount (amount uint))
  (and (>= amount MIN-REQUESTED-AMOUNT) (<= amount MAX-REQUESTED-AMOUNT))
)

;; Private helper function to validate message content
(define-private (is-valid-message (message (optional (string-ascii 200))))
  (match message
    some-msg (<= (len some-msg) MAX-MESSAGE-LENGTH)
    true
  )
)

;; Private helper function to calculate resource allocation based on priority and family size
(define-private (calculate-allocation-amount (priority uint) (family-size uint) (base-amount uint))
  (let ((priority-multiplier (if (>= priority u4) u2 u1))
        (family-multiplier (if (> family-size u3) u2 u1)))
    (* base-amount priority-multiplier family-multiplier)
  )
)

;; Private helper function to check if contract is paused
(define-private (check-contract-not-paused)
  (not (var-get contract-paused))
)

;; Public function to add authorized personnel (only contract owner)
(define-public (add-authorized-personnel (personnel principal) (role (string-ascii 20)))
  (begin
    (asserts! (check-contract-not-paused) ERR-UNAUTHORIZED-ACCESS)
    (asserts! (is-eq tx-sender CONTRACT-OWNER) ERR-UNAUTHORIZED-ACCESS)
    (asserts! (is-valid-principal personnel) ERR-INVALID-INPUT)
    (asserts! (is-valid-string-length role MIN-ROLE-LENGTH MAX-ROLE-LENGTH) ERR-INVALID-STRING-LENGTH)
    
    (ok (map-set authorized-personnel 
      { personnel: personnel }
      { role: role, authorized-date: block-height }
    ))
  )
)

;; Public function to register a new refugee
(define-public (register-refugee 
  (name (string-ascii 50))
  (age uint)
  (family-size uint)
  (location (string-ascii 100))
  (priority-level uint)
)
  (let ((new-refugee-id (+ (var-get refugee-counter) u1)))
    (asserts! (check-contract-not-paused) ERR-UNAUTHORIZED-ACCESS)
    (asserts! (is-valid-string-length name MIN-NAME-LENGTH MAX-NAME-LENGTH) ERR-INVALID-STRING-LENGTH)
    (asserts! (is-valid-age age) ERR-INVALID-AGE)
    (asserts! (is-valid-family-size family-size) ERR-INVALID-FAMILY-SIZE)
    (asserts! (is-valid-string-length location MIN-LOCATION-LENGTH MAX-LOCATION-LENGTH) ERR-INVALID-STRING-LENGTH)
    (asserts! (is-valid-priority-level priority-level) ERR-INVALID-PRIORITY-LEVEL)
    (asserts! (is-none (map-get? refugees { refugee-id: new-refugee-id })) ERR-REFUGEE-ALREADY-REGISTERED)
    
    ;; Store refugee information
    (map-set refugees
      { refugee-id: new-refugee-id }
      {
        wallet-address: tx-sender,
        name: name,
        age: age,
        family-size: family-size,
        location: location,
        registration-date: block-height,
        verification-status: false,
        priority-level: priority-level,
        total-received: u0
      }
    )
    
    ;; Update counters
    (var-set refugee-counter new-refugee-id)
    (var-set total-refugees (+ (var-get total-refugees) u1))
    
    (ok new-refugee-id)
  )
)

;; Public function to verify a refugee (only authorized personnel)
(define-public (verify-refugee (refugee-id uint))
  (let ((refugee-data (unwrap! (validate-refugee-exists refugee-id) ERR-REFUGEE-NOT-FOUND)))
    (asserts! (check-contract-not-paused) ERR-UNAUTHORIZED-ACCESS)
    (asserts! (> refugee-id u0) ERR-INVALID-INPUT)
    (asserts! (is-authorized-personnel tx-sender) ERR-UNAUTHORIZED-ACCESS)
    (asserts! (not (get verification-status refugee-data)) ERR-ALREADY-VERIFIED)
    
    ;; Update verification status
    (ok (map-set refugees
      { refugee-id: refugee-id }
      (merge refugee-data { verification-status: true })
    ))
  )
)

;; Public function to initialize resource pool (only contract owner)
(define-public (initialize-resource-pool 
  (resource-type (string-ascii 9))
  (initial-amount uint)
  (unit-cost uint)
)
  (begin
    (asserts! (check-contract-not-paused) ERR-UNAUTHORIZED-ACCESS)
    (asserts! (is-eq tx-sender CONTRACT-OWNER) ERR-UNAUTHORIZED-ACCESS)
    (asserts! (is-valid-resource-type resource-type) ERR-INVALID-RESOURCE-TYPE)
    (asserts! (> initial-amount u0) ERR-INVALID-AMOUNT)
    (asserts! (> unit-cost u0) ERR-INVALID-AMOUNT)
    
    (ok (map-set resource-pool
      { resource-type: resource-type }
      {
        available-amount: initial-amount,
        allocated-amount: u0,
        unit-cost: unit-cost
      }
    ))
  )
)

;; Public function to donate resources to the pool
(define-public (donate-resources 
  (resource-type (string-ascii 9))
  (amount uint)
  (message (optional (string-ascii 200)))
)
  (let ((donation-id (+ (var-get donation-counter) u1))
        (resource-data (unwrap! (map-get? resource-pool { resource-type: resource-type }) ERR-INVALID-RESOURCE-TYPE))
        (donation-amount (* amount (get unit-cost resource-data))))
    
    (asserts! (check-contract-not-paused) ERR-UNAUTHORIZED-ACCESS)
    (asserts! (is-valid-resource-type resource-type) ERR-INVALID-RESOURCE-TYPE)
    (asserts! (> amount u0) ERR-INVALID-AMOUNT)
    (asserts! (>= donation-amount MIN-DONATION-AMOUNT) ERR-INVALID-AMOUNT)
    
    ;; Validate message if provided (FIXED: Added proper validation)
    (asserts! (is-valid-message message) ERR-INVALID-STRING-LENGTH)
    
    ;; Transfer STX from donor to contract
    (unwrap! (stx-transfer? donation-amount tx-sender (as-contract tx-sender)) ERR-DONATION-FAILED)
    
    ;; Record donation (FIXED: Message is now validated before use)
    (map-set donations
      { donation-id: donation-id }
      {
        donor: tx-sender,
        amount: donation-amount,
        resource-type: resource-type,
        donation-date: block-height,
        message: message
      }
    )
    
    ;; Update resource pool
    (map-set resource-pool
      { resource-type: resource-type }
      (merge resource-data { available-amount: (+ (get available-amount resource-data) amount) })
    )
    
    ;; Update counters
    (var-set donation-counter donation-id)
    (var-set total-donations (+ (var-get total-donations) donation-amount))
    
    (ok donation-id)
  )
)

;; Public function to allocate resources to a refugee (only authorized personnel)
(define-public (allocate-resources 
  (refugee-id uint)
  (resource-type (string-ascii 9))
  (requested-amount uint)
)
  (begin
    ;; FIXED: Validate all inputs before using them
    (asserts! (check-contract-not-paused) ERR-UNAUTHORIZED-ACCESS)
    (asserts! (> refugee-id u0) ERR-INVALID-INPUT)
    (asserts! (is-valid-resource-type resource-type) ERR-INVALID-RESOURCE-TYPE)
    (asserts! (is-valid-requested-amount requested-amount) ERR-INVALID-AMOUNT)
    (asserts! (is-authorized-personnel tx-sender) ERR-UNAUTHORIZED-ACCESS)
    
    ;; Now safely get the validated data
    (let ((refugee-data (unwrap! (validate-refugee-exists refugee-id) ERR-REFUGEE-NOT-FOUND))
          (resource-data (unwrap! (map-get? resource-pool { resource-type: resource-type }) ERR-INVALID-RESOURCE-TYPE))
          (calculated-amount (calculate-allocation-amount 
            (get priority-level refugee-data)
            (get family-size refugee-data)
            requested-amount))
          (final-amount (if (<= calculated-amount MAX-RESOURCE-ALLOCATION) calculated-amount requested-amount)))
      
      (asserts! (get verification-status refugee-data) ERR-NOT-VERIFIED)
      (asserts! (>= (get available-amount resource-data) final-amount) ERR-INSUFFICIENT-RESOURCES)
      
      ;; Create allocation record
      (map-set resource-allocations
        { refugee-id: refugee-id, resource-type: resource-type }
        {
          allocated-amount: final-amount,
          allocation-date: block-height,
          status: "approved",
          approver: (some tx-sender)
        }
      )
      
      ;; Update resource pool
      (map-set resource-pool
        { resource-type: resource-type }
        (merge resource-data {
          available-amount: (- (get available-amount resource-data) final-amount),
          allocated-amount: (+ (get allocated-amount resource-data) final-amount)
        })
      )
      
      ;; Update refugee total received
      (map-set refugees
        { refugee-id: refugee-id }
        (merge refugee-data {
          total-received: (+ (get total-received refugee-data) (* final-amount (get unit-cost resource-data)))
        })
      )
      
      ;; Update allocation counter
      (var-set total-allocations (+ (var-get total-allocations) u1))
      
      (ok final-amount)
    )
  )
)

;; Public function to mark resource as distributed (only authorized personnel)
(define-public (mark-resource-distributed 
  (refugee-id uint)
  (resource-type (string-ascii 9))
)
  (let ((allocation-data (unwrap! (map-get? resource-allocations { refugee-id: refugee-id, resource-type: resource-type }) ERR-REFUGEE-NOT-FOUND)))
    (asserts! (check-contract-not-paused) ERR-UNAUTHORIZED-ACCESS)
    (asserts! (> refugee-id u0) ERR-INVALID-INPUT)
    (asserts! (is-valid-resource-type resource-type) ERR-INVALID-RESOURCE-TYPE)
    (asserts! (is-authorized-personnel tx-sender) ERR-UNAUTHORIZED-ACCESS)
    
    (ok (map-set resource-allocations
      { refugee-id: refugee-id, resource-type: resource-type }
      (merge allocation-data { status: "distributed" })
    ))
  )
)

;; Read-only function to get refugee information
(define-read-only (get-refugee-info (refugee-id uint))
  (begin
    (asserts! (> refugee-id u0) ERR-INVALID-INPUT)
    (ok (map-get? refugees { refugee-id: refugee-id }))
  )
)

;; Read-only function to get resource pool status
(define-read-only (get-resource-pool-status (resource-type (string-ascii 9)))
  (begin
    (asserts! (is-valid-resource-type resource-type) ERR-INVALID-RESOURCE-TYPE)
    (ok (map-get? resource-pool { resource-type: resource-type }))
  )
)

;; Read-only function to get allocation details
(define-read-only (get-allocation-details (refugee-id uint) (resource-type (string-ascii 9)))
  (begin
    (asserts! (> refugee-id u0) ERR-INVALID-INPUT)
    (asserts! (is-valid-resource-type resource-type) ERR-INVALID-RESOURCE-TYPE)
    (ok (map-get? resource-allocations { refugee-id: refugee-id, resource-type: resource-type }))
  )
)

;; Read-only function to get donation information
(define-read-only (get-donation-info (donation-id uint))
  (begin
    (asserts! (> donation-id u0) ERR-INVALID-INPUT)
    (ok (map-get? donations { donation-id: donation-id }))
  )
)

;; Read-only function to get contract statistics
(define-read-only (get-contract-stats)
  (ok {
    total-donations: (var-get total-donations),
    total-refugees: (var-get total-refugees),
    total-allocations: (var-get total-allocations),
    current-refugee-counter: (var-get refugee-counter),
    current-donation-counter: (var-get donation-counter),
    contract-paused: (var-get contract-paused)
  })
)

;; Read-only function to check if address is authorized
(define-read-only (is-personnel-authorized (personnel principal))
  (begin
    (asserts! (is-valid-principal personnel) ERR-INVALID-INPUT)
    (ok (is-some (map-get? authorized-personnel { personnel: personnel })))
  )
)

;; Read-only function to get all available resource types
(define-read-only (get-available-resource-types)
  (ok RESOURCE-TYPES)
)

;; Read-only function to check if contract is paused
(define-read-only (is-contract-paused)
  (ok (var-get contract-paused))
)

;; Emergency function to pause/unpause contract operations (only contract owner)
(define-public (toggle-contract-pause)
  (begin
    (asserts! (is-eq tx-sender CONTRACT-OWNER) ERR-UNAUTHORIZED-ACCESS)
    (ok (var-set contract-paused (not (var-get contract-paused))))
  )
)

;; Public function to remove authorized personnel (only contract owner)
(define-public (remove-authorized-personnel (personnel principal))
  (begin
    (asserts! (check-contract-not-paused) ERR-UNAUTHORIZED-ACCESS)
    (asserts! (is-eq tx-sender CONTRACT-OWNER) ERR-UNAUTHORIZED-ACCESS)
    (asserts! (is-valid-principal personnel) ERR-INVALID-INPUT)
    (asserts! (is-some (map-get? authorized-personnel { personnel: personnel })) ERR-REFUGEE-NOT-FOUND)
    
    (ok (map-delete authorized-personnel { personnel: personnel }))
  )
)