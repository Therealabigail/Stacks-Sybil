# Identity Verification & Anti-Sybil Defense System Smart Contract

A comprehensive decentralized identity verification system built on Stacks blockchain that prevents Sybil attacks through stake-based verification, peer validation, dynamic reputation scoring, and economic incentives.

## Overview

This smart contract creates a trustworthy network where users build reputation through stake commitment, peer endorsements, and consistent positive behavior over time. The system is designed to prevent malicious actors from creating multiple fake identities (Sybil attacks) by requiring economic commitment and community validation.

## Key Features

- **Stake-Based Verification**: Users must stake STX tokens to participate in the network
- **Peer Endorsement System**: Community members can endorse each other to build trust
- **Dynamic Reputation Scoring**: Reputation scores based on stake, endorsements, and time decay
- **Anti-Sybil Protection**: Multiple layers of defense against fake identity creation
- **Economic Incentives**: Rewards for positive behavior, penalties for malicious actions
- **Administrative Controls**: Governance features for system maintenance

## Core Components

### 1. Stake Management
- **Minimum Stake**: 1 STX (1,000,000 microSTX) required for participation
- **Stake Locking**: Stakes are locked for specified periods to prevent gaming
- **Flexible Withdrawal**: Users can withdraw stakes after lock periods expire

### 2. Peer Endorsement System
- **Endorsement Requirements**: 3 peer endorsements needed for full verification
- **Cooldown Periods**: 24-hour cooldown between endorsements to prevent spam
- **Weighted Endorsements**: Endorsement value based on endorser's reputation
- **Self-Endorsement Prevention**: Users cannot endorse themselves

### 3. Reputation Scoring
- **Multi-Factor Calculation**: Based on stake amount, endorsements, and time
- **Time Decay**: 10% daily reputation decay to encourage ongoing participation
- **Maximum Cap**: Reputation capped at 1000 points
- **Real-time Updates**: Reputation recalculated on each interaction

### 4. Verification Status
- **Comprehensive Checks**: Sufficient endorsements, adequate stake, recent activity
- **30-Day Validity**: Verification expires after 30 days without activity
- **Blacklist Protection**: Blacklisted users cannot achieve verification

## Contract Constants

| Parameter | Default Value | Description |
|-----------|---------------|-------------|
| Minimum Stake | 1,000,000 microSTX | Required stake for participation |
| Required Endorsements | 3 | Peer endorsements needed for verification |
| Endorsement Cooldown | 144 blocks (~24 hours) | Time between endorsements |
| Reputation Decay | 10% | Daily reputation decay rate |
| Verification Validity | 4,320 blocks (~30 days) | Verification expiry period |

## Public Functions

### Stake Management

#### `deposit-participant-stake`
```clarity
(deposit-participant-stake (stake-deposit-amount uint) (stake-lock-duration-blocks uint))
```
Deposit STX tokens as stake to participate in the network.

**Parameters:**
- `stake-deposit-amount`: Amount of STX to stake (in microSTX)
- `stake-lock-duration-blocks`: Number of blocks to lock the stake

#### `withdraw-participant-stake`
```clarity
(withdraw-participant-stake (withdrawal-amount uint))
```
Withdraw staked STX after lock period expires.

**Parameters:**
- `withdrawal-amount`: Amount of STX to withdraw (in microSTX)

### Peer Endorsement

#### `provide-peer-endorsement`
```clarity
(provide-peer-endorsement (endorsed-participant-address principal))
```
Endorse another participant for identity verification.

**Parameters:**
- `endorsed-participant-address`: Address of the participant to endorse

### Reputation Management

#### `refresh-participant-reputation`
```clarity
(refresh-participant-reputation (participant-address principal))
```
Update and retrieve a participant's reputation score.

**Parameters:**
- `participant-address`: Address of the participant

### Community Governance

#### `submit-sybil-attack-challenge`
```clarity
(submit-sybil-attack-challenge (suspected-sybil-address principal) (evidence-description (string-utf8 500)))
```
Submit a challenge against a suspected Sybil attacker.

**Parameters:**
- `suspected-sybil-address`: Address of suspected malicious user
- `evidence-description`: Description of evidence (max 500 characters)

#### `execute-stake-transfer`
```clarity
(execute-stake-transfer (recipient-address principal) (transfer-amount uint))
```
Transfer stake between participants (useful for account migrations).

**Parameters:**
- `recipient-address`: Address to receive the stake
- `transfer-amount`: Amount of stake to transfer

## Read-Only Functions

### Query Functions

#### `verify-participant-sybil-resistance`
```clarity
(verify-participant-sybil-resistance (participant-address principal))
```
Check if a participant meets all Sybil resistance requirements.

#### `query-participant-reputation`
```clarity
(query-participant-reputation (participant-address principal))
```
Get a participant's current reputation score without updating.

#### `query-participant-stake-details`
```clarity
(query-participant-stake-details (participant-address principal))
```
Get detailed information about a participant's stake.

#### `query-current-endorsement-threshold`
```clarity
(query-current-endorsement-threshold)
```
Get the current number of endorsements required for verification.

#### `query-participant-blacklist-status`
```clarity
(query-participant-blacklist-status (participant-address principal))
```
Check if a participant is blacklisted.

## Administrative Functions

*Note: These functions can only be called by the contract administrator.*

#### `configure-endorsement-threshold`
Update the number of endorsements required for verification.

#### `configure-minimum-stake-requirement`
Update the minimum stake requirement for participation.

#### `add-participant-to-blacklist`
Add a malicious participant to the blacklist.

#### `remove-participant-from-blacklist`
Remove a participant from the blacklist.

#### `transfer-administrative-control`
Transfer administrative privileges to a new address.

## Error Codes

| Code | Constant | Description |
|------|----------|-------------|
| u1 | ERROR-UNAUTHORIZED-ACCESS | Caller lacks required permissions |
| u2 | ERROR-DUPLICATE-ENDORSEMENT | Attempting duplicate endorsement |
| u3 | ERROR-INSUFFICIENT-STAKE-BALANCE | Insufficient stake for operation |
| u4 | ERROR-COOLDOWN-PERIOD-ACTIVE | Operation blocked by cooldown period |
| u5 | ERROR-SELF-ENDORSEMENT-PROHIBITED | Cannot endorse yourself |
| u6 | ERROR-ADDRESS-BLACKLISTED | Address is blacklisted |
| u7 | ERROR-REPUTATION-THRESHOLD-NOT-MET | Insufficient reputation for operation |
| u8 | ERROR-VERIFICATION-REQUIREMENTS-UNMET | Does not meet verification criteria |
| u9 | ERROR-INVALID-INPUT-PARAMETER | Invalid input parameter provided |
| u10 | ERROR-ARITHMETIC-OVERFLOW | Arithmetic operation overflow |
| u11 | ERROR-INVALID-PRINCIPAL-ADDRESS | Invalid principal address |
| u12 | ERROR-INVALID-STRING-INPUT | Invalid string input |

## Usage Examples

### Becoming a Verified Participant

1. **Stake STX Tokens**:
   ```clarity
   (contract-call? .identity-verification deposit-participant-stake u2000000 u1440)
   ```
   Stakes 2 STX for 10 days (1440 blocks).

2. **Get Peer Endorsements**:
   Ask 3 verified community members to endorse you:
   ```clarity
   (contract-call? .identity-verification provide-peer-endorsement 'SP1ABC...)
   ```

3. **Check Verification Status**:
   ```clarity
   (contract-call? .identity-verification verify-participant-sybil-resistance 'SP1ABC...)
   ```

### Maintaining Reputation

- **Regular Activity**: Participate in endorsements and community governance
- **Stake Maintenance**: Keep adequate stake levels
- **Avoid Penalties**: Follow community guidelines to avoid blacklisting

## Security Considerations

### Anti-Sybil Mechanisms

1. **Economic Barriers**: Minimum stake requirements make creating multiple identities expensive
2. **Time Locks**: Stake locking prevents rapid identity cycling
3. **Peer Validation**: Community endorsements provide social proof
4. **Reputation Decay**: Inactive accounts lose verification over time
5. **Blacklist System**: Malicious actors can be permanently excluded

### Best Practices

- **Stake Diversification**: Don't put all stakes in one identity
- **Regular Updates**: Refresh reputation scores periodically
- **Community Participation**: Actively endorse legitimate participants
- **Evidence Collection**: Document suspicious behavior for challenges

## Deployment and Configuration

### Initial Setup

1. Deploy the contract to Stacks blockchain
2. Set initial administrator address
3. Configure system parameters (stake requirements, thresholds)
4. Establish initial trusted participants

### Network Bootstrap

1. Core team members stake and endorse each other
2. Gradually onboard new participants through existing network
3. Monitor for Sybil attack attempts
4. Adjust parameters based on network behavior

## Integration Guide

### For DApps

```clarity
;; Check if user is verified before allowing sensitive operations
(let ((is-verified (contract-call? .identity-verification verify-participant-sybil-resistance tx-sender)))
  (if is-verified
    ;; Allow operation
    (ok "Operation allowed")
    ;; Reject operation
    (err "Verification required")))
```

### For Governance Systems

```clarity
;; Weight votes by reputation score
(let ((voter-reputation (contract-call? .identity-verification query-participant-reputation tx-sender)))
  (if (>= voter-reputation u500)
    ;; Allow weighted vote
    (process-vote voter-reputation)
    ;; Require higher threshold
    (err "Insufficient reputation")))
```