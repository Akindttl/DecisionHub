# DecisionHub

---

## Overview

DecisionHub is a secure and decentralized autonomous organization (DAO) protocol built on Clarity. It empowers communities to govern themselves by providing a robust framework for **proposal creation**, **voting**, and **automatic execution** of approved changes. DecisionHub integrates essential security features such as a **timelock**, **quorum requirements**, and **role-based access control** to ensure transparent and secure governance operations.

## Features

* **Decentralized Governance**: Facilitates community-driven decision-making.
* **Proposal System**: Users can create proposals with a defined title, description, target contract, and optional action data.
* **Token-Based Voting**: Voting power is tied to the amount of governance tokens held by a user.
* **Quorum Enforcement**: Proposals require a minimum percentage of total voting power to be considered valid.
* **Timelock Security**: Approved proposals undergo a timelock period before execution, providing a window for review and preventing hasty actions.
* **Automatic Execution**: Successfully voted-on and timelocked proposals can be automatically executed, streamlining the governance process.
* **Role-Based Access Control**: The contract owner has specific permissions for initial setup and emergency controls (e.g., pausing the contract).
* **Clear Proposal States**: Proposals transition through defined states (Pending, Active, Succeeded, Defeated, Executed) for clear tracking.

---

## Contract Details

### Constants

* `CONTRACT-OWNER`: The principal of the contract deployer.
* `ERR-NOT-AUTHORIZED` (u100): Returned when the caller lacks the necessary permissions.
* `ERR-PROPOSAL-NOT-FOUND` (u101): Returned when a proposal ID does not correspond to an existing proposal.
* `ERR-ALREADY-VOTED` (u102): Returned when a user attempts to vote multiple times on the same proposal.
* `ERR-VOTING-ENDED` (u103): Returned when an action (e.g., voting or executing) is attempted outside the designated voting period.
* `ERR-INSUFFICIENT-TOKENS` (u104): Returned when a user does not have enough tokens to perform an action (e.g., create a proposal or vote).
* `ERR-PROPOSAL-NOT-ACTIVE` (u105): Returned when an execution attempt is made on a proposal that is not in an active or succeeded state.
* `ERR-EXECUTION-FAILED` (u106): Placeholder for an error during contract execution.
* `ERR-TIMELOCK-NOT-EXPIRED` (u107): Returned when a proposal execution is attempted before the timelock period has ended.

### Governance Parameters

* `MIN-PROPOSAL-THRESHOLD` (u1000): The minimum number of governance tokens required to create a new proposal.
* `QUORUM-PERCENTAGE` (u20): The percentage (20%) of total governance tokens that must participate in a vote for a proposal to meet quorum.
* `VOTING-PERIOD` (u1440): The duration in blocks for which a proposal is open for voting (approximately 1 day).
* `TIMELOCK-PERIOD` (u2880): The duration in blocks after voting ends before a successful proposal can be executed (approximately 2 days).
* `MAX-DESCRIPTION-LENGTH` (u256): The maximum character length for a proposal's description.

### Proposal States

* `PROPOSAL-PENDING` (u1): Proposal has been created but voting has not yet started.
* `PROPOSAL-ACTIVE` (u2): Proposal is currently open for voting.
* `PROPOSAL-SUCCEEDED` (u3): Proposal has passed voting and met quorum, awaiting timelock expiration.
* `PROPOSAL-DEFEATED` (u4): Proposal failed to pass voting or meet quorum.
* `PROPOSAL-EXECUTED` (u5): Proposal has been successfully executed.

### Data Maps and Variables

* `proposal-counter` (uint): Tracks the total number of proposals created.
* `total-supply` (uint): Represents the total supply of governance tokens.
* `contract-paused` (bool): A flag to pause contract operations in emergencies (controlled by `CONTRACT-OWNER`).
* `token-balances` (map): Stores the token balance for each user (`{ user: principal }` $\rightarrow$ `{ balance: uint }`).
* `proposals` (map): Stores detailed information for each proposal (`{ proposal-id: uint }` $\rightarrow$ `{ proposer: principal, title: (string-ascii 64), description: (string-ascii 256), target-contract: (optional principal), action-data: (optional (buff 1024)), votes-for: uint, votes-against: uint, start-block: uint, end-block: uint, execution-block: uint, state: uint, created-at: uint }`).
* `user-votes` (map): Records each user's vote on a specific proposal (`{ user: principal, proposal-id: uint }` $\rightarrow$ `{ vote: bool, voting-power: uint, timestamp: uint }`).
* `proposal-voters` (map): Aggregates voting statistics for each proposal (`{ proposal-id: uint }` $\rightarrow$ `{ total-voters: uint, total-voting-power: uint }`).

---

## Public Functions

### `set-token-balance (user principal) (amount uint)`

**(Owner only)** Initializes or sets the token balance for a given user. Primarily for testing or initial distribution.

* **Parameters**:
    * `user` (principal): The address of the user whose balance is to be set.
    * `amount` (uint): The amount of tokens to set.
* **Returns**: `(ok true)` on success, `ERR-NOT-AUTHORIZED` if not called by the contract owner.

### `create-proposal (title (string-ascii 64)) (description (string-ascii 256)) (target-contract (optional principal)) (action-data (optional (buff 1024)))`

Allows eligible users to create new governance proposals.

* **Parameters**:
    * `title` ((string-ascii 64)): The title of the proposal.
    * `description` ((string-ascii 256)): A detailed description of the proposal.
    * `target-contract` ((optional principal)): An optional principal of the contract to be affected by the proposal.
    * `action-data` ((optional (buff 1024))): Optional data (e.g., function call parameters) for the target contract.
* **Returns**: `(ok proposal-id)` on success, `ERR-NOT-AUTHORIZED` if the contract is paused, `ERR-INSUFFICIENT-TOKENS` if the sender's balance is below `MIN-PROPOSAL-THRESHOLD`.

### `vote (proposal-id uint) (support bool)`

Enables users to cast their vote on an active proposal.

* **Parameters**:
    * `proposal-id` (uint): The ID of the proposal to vote on.
    * `support` (bool): `true` for a 'for' vote, `false` for an 'against' vote.
* **Returns**: `(ok true)` on success, `ERR-NOT-AUTHORIZED` if the contract is paused, `ERR-PROPOSAL-NOT-FOUND` if the proposal does not exist, `ERR-INSUFFICIENT-TOKENS` if the user has no tokens, `ERR-ALREADY-VOTED` if the user has already voted, `ERR-VOTING-ENDED` if the voting period has concluded.

### `execute-proposal (proposal-id uint)`

Triggers the execution of a successful proposal after its timelock period has expired.

* **Parameters**:
    * `proposal-id` (uint): The ID of the proposal to execute.
* **Returns**: `(ok { ... })` with an execution summary on success, `ERR-NOT-AUTHORIZED` if the contract is paused, `ERR-PROPOSAL-NOT-FOUND` if the proposal does not exist, `ERR-VOTING-ENDED` if the voting period hasn't ended, `ERR-TIMELOCK-NOT-EXPIRED` if the timelock is still active, `ERR-PROPOSAL-NOT-ACTIVE` if the proposal is not in an executable state.

---

## Read-Only Functions

### `get-proposal (proposal-id uint)`

Retrieves the full details of a specific proposal.

* **Parameters**:
    * `proposal-id` (uint): The ID of the proposal.
* **Returns**: An optional tuple containing proposal details or `none` if not found.

### `get-user-vote (user principal) (proposal-id uint)`

Retrieves a user's vote record for a specific proposal.

* **Parameters**:
    * `user` (principal): The address of the user.
    * `proposal-id` (uint): The ID of the proposal.
* **Returns**: An optional tuple containing vote details (`{ vote: bool, voting-power: uint, timestamp: uint }`) or `none` if no vote is found.

### `get-proposal-count`

Returns the total number of proposals that have been created.

* **Returns**: `uint`.

### `get-balance (user principal)`

Retrieves the governance token balance for a given user.

* **Parameters**:
    * `user` (principal): The address of the user.
* **Returns**: `uint`.

---

## Usage

### Deployment

Deploy the `decision-hub.clar` contract to a Clarity-compatible blockchain.

### Initial Setup

1.  The contract owner (`CONTRACT-OWNER`) should initially set token balances for users using the `set-token-balance` function to distribute governance tokens.

### Creating a Proposal

1.  Ensure you hold at least `MIN-PROPOSAL-THRESHOLD` governance tokens.
2.  Call `create-proposal` with a `title`, `description`, and optionally, a `target-contract` and `action-data` if the proposal involves an on-chain action.

### Voting on a Proposal

1.  Check the proposal's `end-block` using `get-proposal` to ensure the voting period is active.
2.  Call `vote` with the `proposal-id` and your `support` (`true` for 'for', `false` for 'against').
3.  Ensure you haven't already voted on this proposal and hold governance tokens.

### Executing a Proposal

1.  After the `VOTING-PERIOD` has passed and the proposal has potentially succeeded (check `state` via `get-proposal`).
2.  Wait for the `TIMELOCK-PERIOD` to expire (i.e., `block-height >= execution-block`).
3.  Call `execute-proposal` with the `proposal-id`.

---

## Contributing

We welcome contributions to DecisionHub! If you have suggestions for improvements, bug fixes, or new features, please feel free to:

1.  Fork the repository.
2.  Create a new branch for your feature or bug fix.
3.  Submit a pull request with a clear description of your changes.

---

## License

This project is licensed under the MIT License - see the `LICENSE` file for details.

---

## Acknowledgements

* Built with the Clarity smart contract language.
* Inspired by existing decentralized governance models.

---
