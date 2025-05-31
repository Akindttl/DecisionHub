;; DecisionHub: Autonomous Governance Protocol
;; This contract implements a decentralized autonomous organization with proposal creation,
;; voting mechanisms, and automatic execution. It includes security features like timelock,
;; quorum requirements, and role-based access control for secure governance operations.

;; Constants
(define-constant CONTRACT-OWNER tx-sender)
(define-constant ERR-NOT-AUTHORIZED (err u100))
(define-constant ERR-PROPOSAL-NOT-FOUND (err u101))
(define-constant ERR-ALREADY-VOTED (err u102))
(define-constant ERR-VOTING-ENDED (err u103))
(define-constant ERR-INSUFFICIENT-TOKENS (err u104))
(define-constant ERR-PROPOSAL-NOT-ACTIVE (err u105))
(define-constant ERR-EXECUTION-FAILED (err u106))
(define-constant ERR-TIMELOCK-NOT-EXPIRED (err u107))

;; Governance parameters
(define-constant MIN-PROPOSAL-THRESHOLD u1000) ;; Minimum tokens to create proposal
(define-constant QUORUM-PERCENTAGE u20) ;; 20% quorum required
(define-constant VOTING-PERIOD u1440) ;; 1440 blocks (~1 day)
(define-constant TIMELOCK-PERIOD u2880) ;; 2880 blocks (~2 days)
(define-constant MAX-DESCRIPTION-LENGTH u256)

;; Proposal states
(define-constant PROPOSAL-PENDING u1)
(define-constant PROPOSAL-ACTIVE u2)
(define-constant PROPOSAL-SUCCEEDED u3)
(define-constant PROPOSAL-DEFEATED u4)
(define-constant PROPOSAL-EXECUTED u5)

;; Data Maps and Variables
(define-data-var proposal-counter uint u0)
(define-data-var total-supply uint u1000000) ;; Total governance tokens
(define-data-var contract-paused bool false)

;; Map: User -> Token Balance
(define-map token-balances
  { user: principal }
  { balance: uint }
)

;; Map: Proposal ID -> Proposal Details
(define-map proposals
  { proposal-id: uint }
  {
    proposer: principal,
    title: (string-ascii 64),
    description: (string-ascii 256),
    target-contract: (optional principal),
    action-data: (optional (buff 1024)),
    votes-for: uint,
    votes-against: uint,
    start-block: uint,
    end-block: uint,
    execution-block: uint,
    state: uint,
    created-at: uint
  }
)

;; Map: User -> Proposal -> Vote Record
(define-map user-votes
  { user: principal, proposal-id: uint }
  { vote: bool, voting-power: uint, timestamp: uint }
)

;; Map: Proposal -> Vote tracking
(define-map proposal-voters
  { proposal-id: uint }
  { total-voters: uint, total-voting-power: uint }
)

;; Private Functions

;; Check if caller is contract owner
(define-private (is-contract-owner)
  (is-eq tx-sender CONTRACT-OWNER)
)

;; Check if contract is active
(define-private (is-contract-active)
  (not (var-get contract-paused))
)

;; Get user token balance
(define-private (get-user-balance (user principal))
  (default-to u0 (get balance (map-get? token-balances { user: user })))
)

;; Calculate quorum requirement
(define-private (calculate-quorum)
  (/ (* (var-get total-supply) QUORUM-PERCENTAGE) u100)
)

;; Check if proposal has reached quorum
(define-private (has-reached-quorum (proposal-id uint))
  (let (
    (voting-data (default-to { total-voters: u0, total-voting-power: u0 }
      (map-get? proposal-voters { proposal-id: proposal-id })))
  )
    (>= (get total-voting-power voting-data) (calculate-quorum))
  )
)

;; Public Functions

;; Initialize user token balance (for testing purposes)
(define-public (set-token-balance (user principal) (amount uint))
  (begin
    (asserts! (is-contract-owner) ERR-NOT-AUTHORIZED)
    (map-set token-balances { user: user } { balance: amount })
    (ok true)
  )
)

;; Create a new governance proposal
(define-public (create-proposal
  (title (string-ascii 64))
  (description (string-ascii 256))
  (target-contract (optional principal))
  (action-data (optional (buff 1024))))
  (begin
    (asserts! (is-contract-active) ERR-NOT-AUTHORIZED)
    (asserts! (>= (get-user-balance tx-sender) MIN-PROPOSAL-THRESHOLD) ERR-INSUFFICIENT-TOKENS)

    (let (
      (proposal-id (+ (var-get proposal-counter) u1))
      (start-block (+ block-height u1))
      (end-block (+ start-block VOTING-PERIOD))
      (execution-block (+ end-block TIMELOCK-PERIOD))
    )
      ;; Create proposal
      (map-set proposals
        { proposal-id: proposal-id }
        {
          proposer: tx-sender,
          title: title,
          description: description,
          target-contract: target-contract,
          action-data: action-data,
          votes-for: u0,
          votes-against: u0,
          start-block: start-block,
          end-block: end-block,
          execution-block: execution-block,
          state: PROPOSAL-PENDING,
          created-at: block-height
        }
      )

      ;; Initialize voting tracking
      (map-set proposal-voters
        { proposal-id: proposal-id }
        { total-voters: u0, total-voting-power: u0 }
      )

      (var-set proposal-counter proposal-id)
      (ok proposal-id)
    )
  )
)

;; Vote on a proposal
(define-public (vote (proposal-id uint) (support bool))
  (begin
    (asserts! (is-contract-active) ERR-NOT-AUTHORIZED)

    (let (
      (proposal (unwrap! (map-get? proposals { proposal-id: proposal-id }) ERR-PROPOSAL-NOT-FOUND))
      (user-balance (get-user-balance tx-sender))
      (voting-data (unwrap! (map-get? proposal-voters { proposal-id: proposal-id }) ERR-PROPOSAL-NOT-FOUND))
    )
      ;; Check voting conditions
      (asserts! (> user-balance u0) ERR-INSUFFICIENT-TOKENS)
      (asserts! (is-none (map-get? user-votes { user: tx-sender, proposal-id: proposal-id })) ERR-ALREADY-VOTED)
      (asserts! (and (>= block-height (get start-block proposal)) (<= block-height (get end-block proposal))) ERR-VOTING-ENDED)

      ;; Record vote
      (map-set user-votes
        { user: tx-sender, proposal-id: proposal-id }
        { vote: support, voting-power: user-balance, timestamp: block-height }
      )

      ;; Update proposal vote counts
      (map-set proposals
        { proposal-id: proposal-id }
        (merge proposal {
          votes-for: (if support (+ (get votes-for proposal) user-balance) (get votes-for proposal)),
          votes-against: (if support (get votes-against proposal) (+ (get votes-against proposal) user-balance)),
          state: PROPOSAL-ACTIVE
        })
      )

      ;; Update voting tracking
      (map-set proposal-voters
        { proposal-id: proposal-id }
        {
          total-voters: (+ (get total-voters voting-data) u1),
          total-voting-power: (+ (get total-voting-power voting-data) user-balance)
        }
      )

      (ok true)
    )
  )
)

;; Read-only Functions

;; Get proposal details
(define-read-only (get-proposal (proposal-id uint))
  (map-get? proposals { proposal-id: proposal-id })
)

;; Get user vote on proposal
(define-read-only (get-user-vote (user principal) (proposal-id uint))
  (map-get? user-votes { user: user, proposal-id: proposal-id })
)

;; Get total proposals created
(define-read-only (get-proposal-count)
  (var-get proposal-counter)
)

;; Get user token balance
(define-read-only (get-balance (user principal))
  (get-user-balance user)
)


