#!/bin/bash

# Set environment variables
export RPC_URL="http://127.0.0.1:8545"
export PRIVATE_KEY="0xac0974bec39a17e36ba4a6b4d238ff944bacb478cbed5efcae784d7bf4f2ff80"

# Build the project
forge build

# Deploy the Swarm Coordinator and capture the address
DEPLOY_OUTPUT=$(forge script script/DeployLocalSwarmCoordinator.s.sol --rpc-url $RPC_URL --sig "deployCoordinator()" --broadcast --unlocked)

echo $DEPLOY_OUTPUT

# Store the address for future use
CONTRACT_ADDRESS=$(echo "$DEPLOY_OUTPUT" | grep -o "SwarmCoordinator deployed at: 0x[a-fA-F0-9]\{40\}" | cut -d' ' -f4)
echo $CONTRACT_ADDRESS > .contract-address
echo "Contract address: $CONTRACT_ADDRESS"

# Get the peer addresses
PEER_ADDRESS_1=$(echo $DEPLOY_OUTPUT | grep -o "peer1: 0x[a-fA-F0-9]\{40\}" | cut -d' ' -f2)
PEER_ADDRESS_2=$(echo $DEPLOY_OUTPUT | grep -o "peer2: 0x[a-fA-F0-9]\{40\}" | cut -d' ' -f2)
PEER_ADDRESS_3=$(echo $DEPLOY_OUTPUT | grep -o "peer3: 0x[a-fA-F0-9]\{40\}" | cut -d' ' -f2)
echo "PEER1: $PEER_ADDRESS_1"
echo "PEER2: $PEER_ADDRESS_2"
echo "PEER3: $PEER_ADDRESS_3"

# Submit winners for round 0
forge script script/DeployLocalSwarmCoordinator.s.sol --rpc-url $RPC_URL --broadcast --unlocked --sig "submitWinners(address,uint256,address[])" $CONTRACT_ADDRESS "0" "[$PEER_ADDRESS_1, $PEER_ADDRESS_2, $PEER_ADDRESS_3]"

# Roll block number
curl -X POST -H "Content-Type: application/json" --data '{"jsonrpc":"2.0","method":"anvil_mine","params":["0x5"],"id":1}' $RPC_URL

# Update round
echo "Updated round"
cast send --rpc-url $RPC_URL $CONTRACT_ADDRESS "updateStageAndRound()" --private-key $PRIVATE_KEY

# Submit winners for round 1
forge script script/DeployLocalSwarmCoordinator.s.sol --rpc-url $RPC_URL --broadcast --unlocked --sig "submitWinners(address,uint256,address[])" $CONTRACT_ADDRESS "1" "[$PEER_ADDRESS_1]"

# Roll block number
curl -X POST -H "Content-Type: application/json" --data '{"jsonrpc":"2.0","method":"anvil_mine","params":["0x5"],"id":1}' $RPC_URL

# Submit winners for round 1
forge script script/DeployLocalSwarmCoordinator.s.sol --rpc-url $RPC_URL --broadcast --unlocked --sig "submitWinners(address,uint256,address[])" $CONTRACT_ADDRESS "1" "[$PEER_ADDRESS_1, $PEER_ADDRESS_2]"

# Get leaderboard
echo "Leaderboard"
cast call --rpc-url http://localhost:8545 $CONTRACT_ADDRESS "leaderboard(uint,uint)(address[])" "0" "10" --private-key ""

# Show contract address
echo "Contract address: $CONTRACT_ADDRESS"
