// SPDX-License-Identifier: MIT
pragma solidity ^0.8;

import {Script, console2} from "forge-std/Script.sol";
import {SwarmCoordinator} from "../src/SwarmCoordinator.sol";

contract DeployLocalSwarmCoordinator is Script {
    // Define bootnodes
    uint256[] bootnodesPrivateKey;
    address[] mockPeers;
    string[] peerIds;
    string[] bootnodes;
    uint256 deployerPrivateKey;

    // Coordinator instance
    SwarmCoordinator coordinator;

    function setUp() public {
        bootnodesPrivateKey.push(0x59c6995e998f97a5a0044966f0945389dc9e86dae88c7a8412f4603b6b78690d);
        bootnodesPrivateKey.push(0x5de4111afa1a4b94908f83103eb1f1706367c2e68ca870fc3fb9a804cdab365a);
        bootnodesPrivateKey.push(0x7c852118294e51e653712a81e05800f419141751be58f605c371e15141b007a6);

        mockPeers.push(makeAddr("peer1"));
        mockPeers.push(makeAddr("peer2"));
        mockPeers.push(makeAddr("peer3"));

        console2.log("peer1: ", mockPeers[0]);
        console2.log("peer2: ", mockPeers[1]);
        console2.log("peer3: ", mockPeers[2]);

        peerIds.push("QmPeer1");
        peerIds.push("QmPeer2");
        peerIds.push("QmPeer3");

        bootnodes.push("/ip4/127.0.0.1/tcp/4001/p2p/QmBootnode1");
        bootnodes.push("/ip4/127.0.0.1/tcp/4002/p2p/QmBootnode2");
        bootnodes.push("/ip4/127.0.0.1/tcp/4003/p2p/QmBootnode3");

        deployerPrivateKey = vm.envUint("PRIVATE_KEY");
    }

    function deployCoordinator() public {
        // Collect all the transactions
        vm.startBroadcast(deployerPrivateKey);

        // Deploy the contract
        coordinator = new SwarmCoordinator();
        console2.log("SwarmCoordinator deployed at:", address(coordinator));

        // Set up stages (1 stage, each 1 blocks long)
        coordinator.setStageCount(1);

        // Add bootnodes
        coordinator.addBootnodes(bootnodes);

        // Finalize broadcasting
        vm.stopBroadcast();

        // Register peers
        for (uint256 i = 0; i < bootnodesPrivateKey.length; i++) {
            vm.broadcast(bootnodesPrivateKey[i]);
            coordinator.registerPeer(peerIds[i]);
        }
    }

    function submitWinners(SwarmCoordinator coordinator_, uint256 round, string[] calldata winners) public {
        vm.startBroadcast(deployerPrivateKey);

        console2.log("Submitting winners for round:", round);
        for (uint256 i = 0; i < winners.length; i++) {
            console2.log(winners[i]);
        }

        // Submit winners
        coordinator_.submitWinners(round, winners);

        vm.stopBroadcast();
    }

    function logFinalState() public view {
        // Log the final state
        console2.log("\nFinal State:");
        console2.log("Current Round:", coordinator.currentRound());
        console2.log("Current Stage:", coordinator.currentStage());
        console2.log("Total Bootnodes:", coordinator.getBootnodesCount());
        console2.log("Top Winners:");
        string[] memory topWinners = coordinator.winnerLeaderboard(0, 3);
        for (uint256 i = 0; i < topWinners.length; i++) {
            console2.log(topWinners[i], coordinator.getTotalWins(topWinners[i]));
        }

        console2.log("Top Voters:");
        address[] memory topVoters = coordinator.voterLeaderboard(0, 3);
        for (uint256 i = 0; i < topVoters.length; i++) {
            console2.log(topVoters[i], coordinator.getVoterVoteCount(topVoters[i]));
        }
    }
}
