# RL Swarm Contracts

This repository contains the smart contracts for the RL Swarm project, focusing on coordinating swarm behavior onchain.

## Deployed contract

### Gensyn testnet

[0x915674138096b84aa3CD05cB0F9c2EEE24b192C5](https://gensyn-testnet.explorer.alchemy.com/address/0x915674138096b84aa3CD05cB0F9c2EEE24b192C5?tab=contract_code)

## Overview

The main contract `SwarmCoordinator` manages a round-based system for coordinating swarm participants, tracking winners, and managing bootnode infrastructure. The contract includes features for:

- Round and stage management
- Peer registration and tracking
- Bootnode management
- Winner submission and reward tracking

## Contract Architecture

### Key Components

1. **Stage and Round Management**
   - Rounds progress through multiple stages
   - Stages are advanced by a designated stage updater
   - No time-based duration checks for stage progression

2. **Peer Management**
   - Users can register their peer IDs by linking them to their EOA
   - EOA addresses are linked to peer IDs (permission-less for now)

3. **Bootnode Infrastructure**
   - Managed by a designated bootnode manager
   - Supports adding, removing, and listing bootnodes
   - Helps maintain network connectivity

4. **Winner Management**
   - Designated winner manager can submit winners for each round
   - Tracks accrued rewards per participant
   - Prevents duplicate winner submissions

## Roles

1. **Owner**
   - Can set stage count
   - Can assign bootnode manager role
   - Can set judge
   - Can set stage updater
   - Initially deployed contract owner

2. **Stage Updater**
   - Can advance stages and rounds
   - Initially set to contract owner

3. **Bootnode Manager**
   - Can add and remove bootnodes
   - Can clear all bootnodes
   - Initially set to contract owner

4. **Judge**
   - Single address authorized to submit winners for completed rounds
   - Can be a smart contract implementing custom consensus logic
   - Initially set to contract owner

## Interacting with the Contract

### For Participants

1. Register your peer:

```solidity
function registerPeer(bytes calldata peerId) external
```

2. Check your accrued rewards:

```solidity
function getAccruedRewards(address account) external view returns (uint256)
```

3. View current round and stage:

```solidity
function currentRound() external view returns (uint256)
function currentStage() external view returns (uint256)
```

4. Check total wins:

```solidity
function getTotalWins(address account) external view returns (uint256)
function getTotalWinsByPeerId(bytes calldata peerId) external view returns (uint256)
```

5. View the leaderboard:

```solidity
function leaderboard(uint256 start, uint256 end) external view returns (address[] memory)
```

Returns a slice of the leaderboard sorted by number of wins (descending). The `start` and `end` parameters define the range of positions to return (inclusive start, exclusive end). The leaderboard tracks up to 100 top winners.

### For Administrators

#### Owner

Manages stages and other managers.

```solidity
function setStageCount(uint256 stageCount_)
function setStageUpdater(address newUpdater)
function setBootnodeManager(address newManager)
function setJudge(address newJudge)
```

#### Stage Updater

Advances stages and rounds.

```solidity
function updateStageAndRound() external returns (uint256, uint256)
```

#### Bootnode manager

Manages bootnode list.

```solidity
function addBootnodes(string[] calldata newBootnodes)
function removeBootnode(uint256 index)
function clearBootnodes()
```

#### Judge

Submits winners. Can be a smart contract implementing custom consensus logic.

```solidity
function submitWinner(uint256 roundNumber, address[] calldata winners)
function getRoundWinners(uint256 roundNumber) external view returns (address[] memory)
function judge() external view returns (address)
```

## Development

### Deploy mock data

One can set up a local environment for testing.

Requirements:

- [foundry](https://book.getfoundry.sh/getting-started/installation)
- [curl](https://curl.se/download.html)

Foundry comes with a local Ethereum node called `anvil`. To set up your local environment:

1. Start the local Ethereum node:

```bash
anvil
```

2. Keep this terminal running and open a new terminal to deploy the mock data:

```bash
forge script script/DeployLocalMockData.s.sol --rpc-url=http://localhost:8545 --broadcast
```

This script will:

- Deploy the SwarmCoordinator contract
- Register mock peers
- Add bootnode entries
- Set up test rounds and winners
- Display contract address and leaderboard

You can now interact with the contract at the address printed in the deployment output.

### Generic framework info

For more information about the development environment:

- [Foundry Book](https://book.getfoundry.sh/)

## FAQ

### How did you generate the ascii sections in the source code?

I used https://www.asciiart.eu/text-to-ascii-art with the DOS Rebel font.
