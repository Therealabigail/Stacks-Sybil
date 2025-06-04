;; Identity Verification & Anti-Sybil Defense System Smart Contract
;; A comprehensive decentralized identity verification system that prevents Sybil attacks
;; through stake-based verification, peer validation, dynamic reputation scoring, and economic incentives.
;; This contract creates a trustworthy network where users build reputation through stake commitment,
;; peer endorsements, and consistent positive behavior over time.

;; CONSTANTS & CONFIGURATION

;; Administrative constants
(define-data-var contract-administrator principal tx-sender)
(define-data-var minimum-stake-requirement uint u1000000) ;; Minimum STX stake (1 STX in microSTX)
(define-data-var required-endorsement-count uint u3) ;; Peer endorsements needed for full verification
(define-data-var endorsement-cooldown-blocks uint u144) ;; 24-hour cooldown between endorsements
(define-data-var reputation-decay-percentage uint u10) ;; Daily reputation decay rate
(define-data-var verification-validity-period uint u4320) ;; 30-day verification expiry period

;; Error constants for better debugging
(define-constant ERROR-UNAUTHORIZED-ACCESS u1)
(define-constant ERROR-DUPLICATE-ENDORSEMENT u2)
(define-constant ERROR-INSUFFICIENT-STAKE-BALANCE u3)
(define-constant ERROR-COOLDOWN-PERIOD-ACTIVE u4)
(define-constant ERROR-SELF-ENDORSEMENT-PROHIBITED u5)
(define-constant ERROR-ADDRESS-BLACKLISTED u6)
(define-constant ERROR-REPUTATION-THRESHOLD-NOT-MET u7)
(define-constant ERROR-VERIFICATION-REQUIREMENTS-UNMET u8)
(define-constant ERROR-INVALID-INPUT-PARAMETER u9)
(define-constant ERROR-ARITHMETIC-OVERFLOW u10)
(define-constant ERROR-INVALID-PRINCIPAL-ADDRESS u11)
(define-constant ERROR-INVALID-STRING-INPUT u12)

;; DATA STORAGE MAPS

;; User stake information with lock periods
(define-map participant-stake-records 
  { participant-address: principal } 
  { staked-amount: uint, stake-locked-until-block: uint })

;; Peer endorsement tracking
(define-map participant-endorsement-records 
  { participant-address: principal } 
  { total-endorsements-received: uint, most-recent-endorsement-block: uint })

;; Dynamic reputation scoring system
(define-map participant-reputation-records 
  { participant-address: principal } 
  { current-reputation-score: uint, last-reputation-update-block: uint })

;; Individual endorsement relationship tracking
(define-map peer-endorsement-relationships 
  { endorser-address: principal, endorsed-address: principal } 
  { endorsement-timestamp-block: uint, endorsement-weight-value: uint })

;; Blacklist management for malicious actors
(define-map blacklisted-participant-registry 
  { blacklisted-address: principal } 
  { is-currently-blacklisted: bool, blacklist-reason-description: (string-utf8 100) })

;; UTILITY FUNCTIONS

;; Get current blockchain height
(define-private (get-current-blockchain-height)
  block-height)

;; Safe minimum value comparison
(define-private (calculate-minimum-value (first-value uint) (second-value uint))
  (if (<= first-value second-value) first-value second-value))

;; Overflow-safe addition with error handling
(define-private (perform-safe-addition (addend-one uint) (addend-two uint))
  (let ((addition-result (+ addend-one addend-two)))
    (if (>= addition-result addend-one)
        (ok addition-result)
        (err ERROR-ARITHMETIC-OVERFLOW))))

;; Check blacklist status for any participant
(define-private (check-participant-blacklist-status (participant-address principal))
  (is-some (map-get? blacklisted-participant-registry { blacklisted-address: participant-address })))

;; REPUTATION CALCULATION ENGINE

;; Comprehensive reputation calculation based on multiple factors
(define-read-only (compute-participant-reputation-score (participant-address principal))
  (let
    (
      (participant-stake-data (default-to { staked-amount: u0, stake-locked-until-block: u0 } 
                                          (map-get? participant-stake-records { participant-address: participant-address })))
      (participant-endorsement-data (default-to { total-endorsements-received: u0, most-recent-endorsement-block: u0 } 
                                                (map-get? participant-endorsement-records { participant-address: participant-address })))
      (participant-reputation-data (default-to { current-reputation-score: u0, last-reputation-update-block: u0 } 
                                              (map-get? participant-reputation-records { participant-address: participant-address })))
      (current-blockchain-height block-height)
      (stake-reputation-multiplier (/ (get staked-amount participant-stake-data) (var-get minimum-stake-requirement)))
      (endorsement-reputation-bonus (* (get total-endorsements-received participant-endorsement-data) u10))
      (time-based-decay-amount (if (> current-blockchain-height (get last-reputation-update-block participant-reputation-data))
                                  (calculate-minimum-value u100 
                                    (* (var-get reputation-decay-percentage) 
                                       (/ (- current-blockchain-height (get last-reputation-update-block participant-reputation-data)) u144)))
                                  u0))
      (time-decay-factor (- u100 time-based-decay-amount))
      (base-reputation-calculation (+ (* stake-reputation-multiplier u30) (* endorsement-reputation-bonus u20)))
      (final-reputation-with-decay (/ (* base-reputation-calculation time-decay-factor) u100))
    )
    (calculate-minimum-value u1000 final-reputation-with-decay))) ;; Maximum reputation cap

;; Internal reputation update mechanism
(define-private (execute-reputation-update (participant-address principal))
  (let
    (
      (newly-calculated-score (compute-participant-reputation-score participant-address))
      (current-blockchain-height (get-current-blockchain-height))
    )
    (map-set participant-reputation-records 
      { participant-address: participant-address } 
      { current-reputation-score: newly-calculated-score, last-reputation-update-block: current-blockchain-height })
    newly-calculated-score))

;; STAKE MANAGEMENT FUNCTIONS

;; Add stake to build reputation and network participation
(define-public (deposit-participant-stake (stake-deposit-amount uint) (stake-lock-duration-blocks uint))
  (begin
    ;; Input validation
    (asserts! (> stake-deposit-amount u0) (err ERROR-INVALID-INPUT-PARAMETER))
    (asserts! (> stake-lock-duration-blocks u0) (err ERROR-INVALID-INPUT-PARAMETER))
    
    (let
      (
        (staking-participant tx-sender)
        (existing-stake-record (default-to { staked-amount: u0, stake-locked-until-block: u0 } 
                                           (map-get? participant-stake-records { participant-address: staking-participant })))
        (current-blockchain-height (get-current-blockchain-height))
        (new-stake-lock-expiry (+ current-blockchain-height stake-lock-duration-blocks))
      )
      (begin
        ;; Security checks
        (asserts! (not (check-participant-blacklist-status staking-participant)) (err ERROR-ADDRESS-BLACKLISTED))
        
        ;; Execute stake transfer
        (try! (stx-transfer? stake-deposit-amount staking-participant (as-contract tx-sender)))
        
        ;; Update stake record with overflow protection
        (match (perform-safe-addition (get staked-amount existing-stake-record) stake-deposit-amount)
          updated-stake-amount (begin
            (map-set participant-stake-records 
              { participant-address: staking-participant } 
              { 
                staked-amount: updated-stake-amount, 
                stake-locked-until-block: (if (> (get stake-locked-until-block existing-stake-record) new-stake-lock-expiry)
                                            (get stake-locked-until-block existing-stake-record)
                                            new-stake-lock-expiry)
              })
            
            ;; Update reputation after stake increase
            (execute-reputation-update staking-participant)
            (ok true))
          overflow-error (err overflow-error))))))

;; Withdraw stake after lock period expires
(define-public (withdraw-participant-stake (withdrawal-amount uint))
  (begin
    ;; Input validation
    (asserts! (> withdrawal-amount u0) (err ERROR-INVALID-INPUT-PARAMETER))
    
    (let
      (
        (withdrawing-participant tx-sender)
        (current-stake-record (default-to { staked-amount: u0, stake-locked-until-block: u0 } 
                                          (map-get? participant-stake-records { participant-address: withdrawing-participant })))
        (current-blockchain-height (get-current-blockchain-height))
        (remaining-stake-after-withdrawal (- (get staked-amount current-stake-record) withdrawal-amount))
      )
      (begin
        ;; Security and timing checks
        (asserts! (not (check-participant-blacklist-status withdrawing-participant)) (err ERROR-ADDRESS-BLACKLISTED))
        (asserts! (>= current-blockchain-height (get stake-locked-until-block current-stake-record)) (err ERROR-COOLDOWN-PERIOD-ACTIVE))
        (asserts! (<= withdrawal-amount (get staked-amount current-stake-record)) (err ERROR-INSUFFICIENT-STAKE-BALANCE))
        (asserts! (or (is-eq remaining-stake-after-withdrawal u0) 
                     (>= remaining-stake-after-withdrawal (var-get minimum-stake-requirement))) 
                 (err ERROR-INSUFFICIENT-STAKE-BALANCE))
        
        ;; Execute withdrawal
        (try! (as-contract (stx-transfer? withdrawal-amount (as-contract tx-sender) withdrawing-participant)))
        
        ;; Update stake record
        (map-set participant-stake-records 
          { participant-address: withdrawing-participant } 
          { 
            staked-amount: remaining-stake-after-withdrawal, 
            stake-locked-until-block: (if (is-eq remaining-stake-after-withdrawal u0) u0 (get stake-locked-until-block current-stake-record))
          })
        
        ;; Update reputation after stake change
        (execute-reputation-update withdrawing-participant)
        (ok true)))))

;; PEER ENDORSEMENT SYSTEM

;; Endorse another participant for identity verification
(define-public (provide-peer-endorsement (endorsed-participant-address principal))
  (begin
    ;; Input validation and security checks
    (asserts! (not (is-eq endorsed-participant-address (as-contract tx-sender))) (err ERROR-INVALID-PRINCIPAL-ADDRESS))
    (asserts! (not (check-participant-blacklist-status endorsed-participant-address)) (err ERROR-ADDRESS-BLACKLISTED))
    
    (let
      (
        (endorsing-participant tx-sender)
        (endorser-stake-record (default-to { staked-amount: u0, stake-locked-until-block: u0 } 
                                           (map-get? participant-stake-records { participant-address: endorsing-participant })))
        (endorser-reputation-score (compute-participant-reputation-score endorsing-participant))
        (current-blockchain-height (get-current-blockchain-height))
        (endorsed-participant-endorsements (default-to { total-endorsements-received: u0, most-recent-endorsement-block: u0 } 
                                                       (map-get? participant-endorsement-records { participant-address: endorsed-participant-address })))
        (previous-endorsement-record (default-to { endorsement-timestamp-block: u0, endorsement-weight-value: u0 } 
                                                 (map-get? peer-endorsement-relationships 
                                                          { endorser-address: endorsing-participant, endorsed-address: endorsed-participant-address })))
      )
      (begin
        ;; Endorser qualification checks
        (asserts! (not (is-eq endorsing-participant endorsed-participant-address)) (err ERROR-SELF-ENDORSEMENT-PROHIBITED))
        (asserts! (>= (get staked-amount endorser-stake-record) (var-get minimum-stake-requirement)) (err ERROR-INSUFFICIENT-STAKE-BALANCE))
        (asserts! (not (check-participant-blacklist-status endorsing-participant)) (err ERROR-ADDRESS-BLACKLISTED))
        (asserts! (or (is-eq (get endorsement-timestamp-block previous-endorsement-record) u0)
                     (>= current-blockchain-height (+ (get endorsement-timestamp-block previous-endorsement-record) (var-get endorsement-cooldown-blocks))))
                 (err ERROR-COOLDOWN-PERIOD-ACTIVE))
        
        ;; Calculate endorsement weight based on endorser reputation
        (let
          ((calculated-endorsement-weight (/ endorser-reputation-score u100)))
          
          ;; Record the endorsement relationship
          (map-set peer-endorsement-relationships 
            { endorser-address: endorsing-participant, endorsed-address: endorsed-participant-address } 
            { endorsement-timestamp-block: current-blockchain-height, endorsement-weight-value: calculated-endorsement-weight })
          
          ;; Update endorsed participant's endorsement count
          (match (perform-safe-addition (get total-endorsements-received endorsed-participant-endorsements) u1)
            updated-endorsement-count (begin
              (map-set participant-endorsement-records 
                { participant-address: endorsed-participant-address } 
                { total-endorsements-received: updated-endorsement-count, most-recent-endorsement-block: current-blockchain-height })
              
              ;; Update endorsed participant's reputation
              (execute-reputation-update endorsed-participant-address)
              (ok true))
            overflow-error (err overflow-error)))))))

;; VERIFICATION STATUS CHECKING

;; Comprehensive check for Sybil resistance qualification
(define-read-only (verify-participant-sybil-resistance (participant-address principal))
  (let
    (
      (participant-endorsement-data (default-to { total-endorsements-received: u0, most-recent-endorsement-block: u0 } 
                                                (map-get? participant-endorsement-records { participant-address: participant-address })))
      (participant-stake-data (default-to { staked-amount: u0, stake-locked-until-block: u0 } 
                                          (map-get? participant-stake-records { participant-address: participant-address })))
      (current-blockchain-height (get-current-blockchain-height))
      (verification-expiry-threshold (if (>= current-blockchain-height (var-get verification-validity-period))
                                       (- current-blockchain-height (var-get verification-validity-period))
                                       u0))
      (has-sufficient-endorsements (>= (get total-endorsements-received participant-endorsement-data) (var-get required-endorsement-count)))
      (has-adequate-stake (>= (get staked-amount participant-stake-data) (var-get minimum-stake-requirement)))
      (has-recent-verification (>= (get most-recent-endorsement-block participant-endorsement-data) verification-expiry-threshold))
      (is-not-blacklisted (not (check-participant-blacklist-status participant-address)))
    )
    (and has-sufficient-endorsements has-adequate-stake has-recent-verification is-not-blacklisted)))

;; READ-ONLY QUERY FUNCTIONS

;; Get participant's current reputation without updating
(define-read-only (query-participant-reputation (participant-address principal))
  (compute-participant-reputation-score participant-address))

;; Get participant's current stake information
(define-read-only (query-participant-stake-details (participant-address principal))
  (default-to { staked-amount: u0, stake-locked-until-block: u0 } 
              (map-get? participant-stake-records { participant-address: participant-address })))

;; Get current endorsement threshold requirement
(define-read-only (query-current-endorsement-threshold)
  (var-get required-endorsement-count))

;; Check if participant is blacklisted
(define-read-only (query-participant-blacklist-status (participant-address principal))
  (if (check-participant-blacklist-status participant-address)
      (get is-currently-blacklisted (unwrap-panic (map-get? blacklisted-participant-registry { blacklisted-address: participant-address })))
      false))

;; REPUTATION MANAGEMENT

;; Update and retrieve participant reputation score
(define-public (refresh-participant-reputation (participant-address principal))
  (begin
    ;; Input validation
    (asserts! (not (is-eq participant-address (as-contract tx-sender))) (err ERROR-INVALID-PRINCIPAL-ADDRESS))
    (asserts! (not (check-participant-blacklist-status participant-address)) (err ERROR-ADDRESS-BLACKLISTED))
    
    ;; Execute reputation update
    (ok (execute-reputation-update participant-address))))

;; ADMINISTRATIVE FUNCTIONS

;; Update endorsement threshold (admin only)
(define-public (configure-endorsement-threshold (new-threshold-value uint))
  (begin
    (asserts! (is-eq tx-sender (var-get contract-administrator)) (err ERROR-UNAUTHORIZED-ACCESS))
    (asserts! (> new-threshold-value u0) (err ERROR-INVALID-INPUT-PARAMETER))
    (var-set required-endorsement-count new-threshold-value)
    (ok true)))

;; Update minimum stake requirement (admin only)
(define-public (configure-minimum-stake-requirement (new-minimum-stake uint))
  (begin
    (asserts! (is-eq tx-sender (var-get contract-administrator)) (err ERROR-UNAUTHORIZED-ACCESS))
    (asserts! (> new-minimum-stake u0) (err ERROR-INVALID-INPUT-PARAMETER))
    (var-set minimum-stake-requirement new-minimum-stake)
    (ok true)))

;; Add participant to blacklist (admin only)
(define-public (add-participant-to-blacklist (target-address principal) (blacklist-reason (string-utf8 100)))
  (begin
    (asserts! (is-eq tx-sender (var-get contract-administrator)) (err ERROR-UNAUTHORIZED-ACCESS))
    (asserts! (not (is-eq target-address (var-get contract-administrator))) (err ERROR-INVALID-INPUT-PARAMETER))
    (asserts! (not (is-eq target-address (as-contract tx-sender))) (err ERROR-INVALID-PRINCIPAL-ADDRESS))
    (asserts! (> (len blacklist-reason) u0) (err ERROR-INVALID-STRING-INPUT))
    
    (map-set blacklisted-participant-registry 
      { blacklisted-address: target-address } 
      { is-currently-blacklisted: true, blacklist-reason-description: blacklist-reason })
    (ok true)))

;; Remove participant from blacklist (admin only)
(define-public (remove-participant-from-blacklist (target-address principal))
  (begin
    (asserts! (is-eq tx-sender (var-get contract-administrator)) (err ERROR-UNAUTHORIZED-ACCESS))
    (asserts! (not (is-eq target-address (as-contract tx-sender))) (err ERROR-INVALID-PRINCIPAL-ADDRESS))
    (asserts! (check-participant-blacklist-status target-address) (err ERROR-INVALID-INPUT-PARAMETER))
    
    (map-delete blacklisted-participant-registry { blacklisted-address: target-address })
    (ok true)))

;; Transfer administrative privileges (current admin only)
(define-public (transfer-administrative-control (new-administrator-address principal))
  (begin
    (asserts! (is-eq tx-sender (var-get contract-administrator)) (err ERROR-UNAUTHORIZED-ACCESS))
    (asserts! (not (is-eq new-administrator-address tx-sender)) (err ERROR-INVALID-INPUT-PARAMETER))
    (asserts! (not (is-eq new-administrator-address (as-contract tx-sender))) (err ERROR-INVALID-PRINCIPAL-ADDRESS))
    
    (var-set contract-administrator new-administrator-address)
    (ok true)))

;; COMMUNITY GOVERNANCE FUNCTIONS

;; Submit challenge against suspected Sybil participant
(define-public (submit-sybil-attack-challenge (suspected-sybil-address principal) (evidence-description (string-utf8 500)))
  (begin
    ;; Input validation
    (asserts! (not (is-eq suspected-sybil-address (as-contract tx-sender))) (err ERROR-INVALID-PRINCIPAL-ADDRESS))
    (asserts! (> (len evidence-description) u0) (err ERROR-INVALID-STRING-INPUT))
    (asserts! (not (check-participant-blacklist-status suspected-sybil-address)) (err ERROR-ADDRESS-BLACKLISTED))
    
    (let
      (
        (challenging-participant tx-sender)
        (challenger-stake-record (default-to { staked-amount: u0, stake-locked-until-block: u0 } 
                                             (map-get? participant-stake-records { participant-address: challenging-participant })))
        (challenger-reputation-score (compute-participant-reputation-score challenging-participant))
      )
      (begin
        ;; Challenger qualification requirements
        (asserts! (not (check-participant-blacklist-status challenging-participant)) (err ERROR-ADDRESS-BLACKLISTED))
        (asserts! (>= (get staked-amount challenger-stake-record) (var-get minimum-stake-requirement)) (err ERROR-INSUFFICIENT-STAKE-BALANCE))
        (asserts! (>= challenger-reputation-score u500) (err ERROR-REPUTATION-THRESHOLD-NOT-MET))
        
        ;; Log challenge for administrative review
        (print { 
          event-type: "sybil-challenge-submitted", 
          challenger: challenging-participant, 
          suspected-address: suspected-sybil-address, 
          evidence: evidence-description 
        })
        (ok true)))))

;; Transfer stake between participants (for account migrations)
(define-public (execute-stake-transfer (recipient-address principal) (transfer-amount uint))
  (begin
    ;; Input validation
    (asserts! (> transfer-amount u0) (err ERROR-INVALID-INPUT-PARAMETER))
    (asserts! (not (is-eq recipient-address (as-contract tx-sender))) (err ERROR-INVALID-PRINCIPAL-ADDRESS))
    (asserts! (not (check-participant-blacklist-status recipient-address)) (err ERROR-ADDRESS-BLACKLISTED))
    
    (let
      (
        (transferring-participant tx-sender)
        (sender-stake-record (default-to { staked-amount: u0, stake-locked-until-block: u0 } 
                                         (map-get? participant-stake-records { participant-address: transferring-participant })))
        (recipient-stake-record (default-to { staked-amount: u0, stake-locked-until-block: u0 } 
                                            (map-get? participant-stake-records { participant-address: recipient-address })))
        (remaining-sender-stake (- (get staked-amount sender-stake-record) transfer-amount))
      )
      (begin
        ;; Sender validation and balance checks
        (asserts! (not (check-participant-blacklist-status transferring-participant)) (err ERROR-ADDRESS-BLACKLISTED))
        (asserts! (<= transfer-amount (get staked-amount sender-stake-record)) (err ERROR-INSUFFICIENT-STAKE-BALANCE))
        (asserts! (or (is-eq remaining-sender-stake u0) (>= remaining-sender-stake (var-get minimum-stake-requirement))) 
                 (err ERROR-INSUFFICIENT-STAKE-BALANCE))
        
        ;; Update sender's stake record
        (map-set participant-stake-records 
          { participant-address: transferring-participant } 
          { 
            staked-amount: remaining-sender-stake, 
            stake-locked-until-block: (if (is-eq remaining-sender-stake u0) u0 (get stake-locked-until-block sender-stake-record))
          })
        
        ;; Update recipient's stake record with overflow protection
        (match (perform-safe-addition (get staked-amount recipient-stake-record) transfer-amount)
          updated-recipient-stake (begin
            (map-set participant-stake-records 
              { participant-address: recipient-address } 
              { 
                staked-amount: updated-recipient-stake, 
                stake-locked-until-block: (if (> (get stake-locked-until-block recipient-stake-record) (get stake-locked-until-block sender-stake-record))
                                            (get stake-locked-until-block recipient-stake-record)
                                            (get stake-locked-until-block sender-stake-record))
              })
            
            ;; Update both participants' reputations
            (execute-reputation-update transferring-participant)
            (execute-reputation-update recipient-address)
            (ok true))
          overflow-error (err overflow-error))))))

;; CONTRACT INITIALIZATION

;; Initialize contract with new administrator (one-time setup)
(define-public (initialize-contract-administrator (new-administrator-address principal))
  (begin
    (asserts! (is-eq tx-sender (var-get contract-administrator)) (err ERROR-UNAUTHORIZED-ACCESS))
    (asserts! (not (is-eq new-administrator-address tx-sender)) (err ERROR-INVALID-INPUT-PARAMETER))
    (asserts! (not (is-eq new-administrator-address (as-contract tx-sender))) (err ERROR-INVALID-PRINCIPAL-ADDRESS))
    
    (var-set contract-administrator new-administrator-address)
    (ok true)))