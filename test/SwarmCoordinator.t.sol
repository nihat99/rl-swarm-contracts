// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {Test, console} from "forge-std/Test.sol";
import {SwarmCoordinator} from "../src/SwarmCoordinator.sol";

contract SwarmCoordinatorTest is Test {
    SwarmCoordinator public swarmCoordinator;

    address _owner = makeAddr("owner");
    address _bootnodeManager = makeAddr("bootnodeManager");
    address _user = makeAddr("user");
    address _stageUpdater = makeAddr("stageUpdater");
    address _user1 = makeAddr("voter1");
    address _user2 = makeAddr("voter2");

    function setUp() public {
        vm.startPrank(_owner);
        swarmCoordinator = new SwarmCoordinator();
        vm.stopPrank();
    }

    function test_SwarmCoordinator_IsCorrectlyDeployed() public view {
        assertEq(swarmCoordinator.owner(), address(_owner));
        assertEq(swarmCoordinator.stageUpdater(), address(_owner));
    }

    function test_Owner_CanSetStageCount_Successfully(uint256 stageCount) public {
        vm.prank(_owner);
        swarmCoordinator.setStageCount(stageCount);
        assertEq(stageCount, swarmCoordinator.stageCount());
    }

    function test_Nobody_CanSetStageCount_Successfully(uint256 stageCount) public {
        vm.expectRevert();
        swarmCoordinator.setStageCount(stageCount);
    }

    function test_Anyone_CanQuery_CurrentRound() public view {
        uint256 currentRound = swarmCoordinator.currentRound();
        assertEq(currentRound, 0);
    }

    function test_StageUpdater_CanAdvanceStage() public {
        uint256 stageCount_ = 2;

        vm.startPrank(_owner);
        swarmCoordinator.setStageCount(stageCount_);
        swarmCoordinator.setStageUpdater(_stageUpdater);
        vm.stopPrank();

        uint256 startingStage = uint256(swarmCoordinator.currentStage());

        vm.prank(_stageUpdater);
        (, uint256 newStage) = swarmCoordinator.updateStageAndRound();

        assertEq(newStage, startingStage + 1);
    }

    function test_NonStageUpdater_CannotAdvanceStage() public {
        uint256 stageCount_ = 2;

        vm.startPrank(_owner);
        swarmCoordinator.setStageCount(stageCount_);
        swarmCoordinator.setStageUpdater(_stageUpdater);
        vm.stopPrank();

        vm.prank(_user);
        vm.expectRevert(SwarmCoordinator.OnlyStageUpdater.selector);
        swarmCoordinator.updateStageAndRound();
    }

    function test_StageUpdater_CanAdvanceRound() public {
        uint256 stageCount_ = 2;

        vm.startPrank(_owner);
        swarmCoordinator.setStageCount(stageCount_);
        swarmCoordinator.setStageUpdater(_stageUpdater);
        vm.stopPrank();

        uint256 startingRound = uint256(swarmCoordinator.currentRound());

        // Advance through all stages to trigger round advancement
        for (uint256 i = 0; i < stageCount_; i++) {
            vm.prank(_stageUpdater);
            swarmCoordinator.updateStageAndRound();
        }

        uint256 newRound = uint256(swarmCoordinator.currentRound());
        uint256 newStage = uint256(swarmCoordinator.currentStage());
        assertEq(newRound, startingRound + 1);
        assertEq(newStage, 0);
    }

    function test_Owner_CanSet_StageUpdater() public {
        vm.startPrank(_owner);
        vm.expectEmit(true, true, false, false);
        emit SwarmCoordinator.StageUpdaterUpdated(_owner, _stageUpdater);
        swarmCoordinator.setStageUpdater(_stageUpdater);
        vm.stopPrank();

        assertEq(swarmCoordinator.stageUpdater(), _stageUpdater);
    }

    function test_NonOwner_CannotSet_StageUpdater() public {
        vm.prank(_user);
        vm.expectRevert();
        swarmCoordinator.setStageUpdater(_stageUpdater);
    }

    function test_Anyone_CanAdvanceRound_IfEnoughTimeHasPassed() public {
        uint256 stageCount_ = 3;

        vm.startPrank(_owner);
        swarmCoordinator.setStageCount(stageCount_);
        swarmCoordinator.setStageUpdater(_stageUpdater);
        vm.stopPrank();

        uint256 startingRound = uint256(swarmCoordinator.currentRound());

        // Advance through all stages to trigger round advancement
        for (uint256 i = 0; i < stageCount_; i++) {
            vm.prank(_stageUpdater);
            swarmCoordinator.updateStageAndRound();
        }

        uint256 newRound = uint256(swarmCoordinator.currentRound());
        uint256 newStage = uint256(swarmCoordinator.currentStage());
        assertEq(newRound, startingRound + 1);
        assertEq(newStage, 0);
    }

    function test_Anyone_CanAddPeer_Successfully() public {
        address user = makeAddr("user");
        string memory peerId = "QmPeer1";

        vm.startPrank(user);
        vm.expectEmit(true, true, false, true);
        emit SwarmCoordinator.PeerRegistered(user, peerId);
        swarmCoordinator.registerPeer(peerId);
        vm.stopPrank();

        // Verify the mapping was updated correctly using the getter function
        string memory storedPeerId = swarmCoordinator.getPeerId(user);
        assertEq(storedPeerId, peerId, "Peer ID not stored correctly");
    }

    function test_Anyone_CanRegister_DifferentPeerIds() public {
        address user1 = makeAddr("user1");
        address user2 = makeAddr("user2");
        string memory peerId1 = "peerId1";
        string memory peerId2 = "peerId2";

        // First user registers peer
        vm.prank(user1);
        vm.expectEmit(true, true, false, true);
        emit SwarmCoordinator.PeerRegistered(user1, peerId1);
        swarmCoordinator.registerPeer(peerId1);

        // Second user registers peer
        vm.prank(user2);
        vm.expectEmit(true, true, false, true);
        emit SwarmCoordinator.PeerRegistered(user2, peerId2);
        swarmCoordinator.registerPeer(peerId2);

        // Verify the mappings were updated correctly
        string memory storedPeerId1 = swarmCoordinator.getPeerId(user1);
        string memory storedPeerId2 = swarmCoordinator.getPeerId(user2);
        assertEq(storedPeerId1, peerId1, "Peer ID 1 not stored correctly");
        assertEq(storedPeerId2, peerId2, "Peer ID 2 not stored correctly");
    }

    function test_Nobody_CanUpdate_ItsOwnPeerId() public {
        address user = makeAddr("user");
        string memory peerId1 = "peerId1";
        string memory peerId2 = "peerId2";

        // User registers first peer
        vm.prank(user);
        vm.expectEmit(true, true, false, true);
        emit SwarmCoordinator.PeerRegistered(user, peerId1);
        swarmCoordinator.registerPeer(peerId1);

        // Verify first peer ID was stored correctly
        string memory storedPeerId1 = swarmCoordinator.getPeerId(user);
        assertEq(storedPeerId1, peerId1, "First peer ID not stored correctly");

        // Try to update to second peer - should fail
        vm.prank(user);
        vm.expectRevert(SwarmCoordinator.PeerIdAlreadyRegistered.selector);
        swarmCoordinator.registerPeer(peerId2);

        // Verify peer ID was not changed
        string memory storedPeerId2 = swarmCoordinator.getPeerId(user);
        assertEq(storedPeerId2, peerId1, "Peer ID should not have changed");
    }

    // Bootnode tests
    function test_SwarmCoordinatorDeployment_SetsBootnodeManager_ToOwner() public view {
        assertEq(swarmCoordinator.bootnodeManager(), _owner);
    }

    function test_Owner_CanSet_BootnodeManager() public {
        vm.startPrank(_owner);
        vm.expectEmit(true, true, false, false);
        emit SwarmCoordinator.BootnodeManagerUpdated(_owner, _bootnodeManager);
        swarmCoordinator.setBootnodeManager(_bootnodeManager);
        vm.stopPrank();

        assertEq(swarmCoordinator.bootnodeManager(), _bootnodeManager);
    }

    function test_NonOwner_CannotSet_BootnodeManager() public {
        vm.prank(_user);
        vm.expectRevert();
        swarmCoordinator.setBootnodeManager(_bootnodeManager);
    }

    function test_BootnodeManager_CanAdd_Bootnodes() public {
        string[] memory newBootnodes = new string[](2);
        newBootnodes[0] = "/ip4/127.0.0.1/tcp/4001/p2p/QmBootnode1";
        newBootnodes[1] = "/ip4/127.0.0.1/tcp/4002/p2p/QmBootnode2";

        vm.prank(_owner);
        vm.expectEmit(true, false, false, true);
        emit SwarmCoordinator.BootnodesAdded(_owner, 2);
        swarmCoordinator.addBootnodes(newBootnodes);

        string[] memory storedBootnodes = swarmCoordinator.getBootnodes();
        assertEq(storedBootnodes.length, 2);
        assertEq(storedBootnodes[0], newBootnodes[0]);
        assertEq(storedBootnodes[1], newBootnodes[1]);
    }

    function test_NonBootnodeManager_CannotAddBootnodes() public {
        string[] memory newBootnodes = new string[](1);
        newBootnodes[0] = "/ip4/127.0.0.1/tcp/4001/p2p/QmBootnode1";

        vm.prank(_user);
        vm.expectRevert(SwarmCoordinator.OnlyBootnodeManager.selector);
        swarmCoordinator.addBootnodes(newBootnodes);
    }

    function test_BootnodeManager_CanRemoveBootnode() public {
        // First add some bootnodes
        string[] memory newBootnodes = new string[](3);
        newBootnodes[0] = "/ip4/127.0.0.1/tcp/4001/p2p/QmBootnode1";
        newBootnodes[1] = "/ip4/127.0.0.1/tcp/4002/p2p/QmBootnode2";
        newBootnodes[2] = "/ip4/127.0.0.1/tcp/4003/p2p/QmBootnode3";

        vm.startPrank(_owner);
        swarmCoordinator.addBootnodes(newBootnodes);

        // Now remove the middle one
        vm.expectEmit(true, false, false, true);
        emit SwarmCoordinator.BootnodeRemoved(_owner, 1);
        swarmCoordinator.removeBootnode(1);
        vm.stopPrank();

        // Verify the bootnode was removed and the array was reorganized
        string[] memory storedBootnodes = swarmCoordinator.getBootnodes();
        assertEq(storedBootnodes.length, 2);
        assertEq(storedBootnodes[0], newBootnodes[0]);
        // The last element should now be at index 1
        assertEq(storedBootnodes[1], newBootnodes[2]);
    }

    function test_BootnodeManager_CannotRemoveInvalidIndex() public {
        vm.prank(_owner);
        vm.expectRevert(SwarmCoordinator.InvalidBootnodeIndex.selector);
        swarmCoordinator.removeBootnode(0); // No bootnodes yet
    }

    function test_NonBootnodeManager_CannotRemoveBootnode() public {
        // First add a bootnode as the owner
        string[] memory newBootnodes = new string[](1);
        newBootnodes[0] = "bootnode1";

        vm.prank(_owner);
        swarmCoordinator.addBootnodes(newBootnodes);

        // Try to remove as non-manager
        vm.prank(_user);
        vm.expectRevert(SwarmCoordinator.OnlyBootnodeManager.selector);
        swarmCoordinator.removeBootnode(0);
    }

    function test_BootnodeManager_CanClearAllBootnodes() public {
        // First add some bootnodes
        string[] memory newBootnodes = new string[](2);
        newBootnodes[0] = "bootnode1";
        newBootnodes[1] = "bootnode2";

        vm.startPrank(_owner);
        swarmCoordinator.addBootnodes(newBootnodes);

        // Now clear them
        vm.expectEmit(true, false, false, false);
        emit SwarmCoordinator.AllBootnodesCleared(_owner);
        swarmCoordinator.clearBootnodes();
        vm.stopPrank();

        // Verify all bootnodes were cleared
        string[] memory storedBootnodes = swarmCoordinator.getBootnodes();
        assertEq(storedBootnodes.length, 0);
    }

    function test_NonBootnodeManager_CannotClearBootnodes() public {
        // First add a bootnode as the owner
        string[] memory newBootnodes = new string[](1);
        newBootnodes[0] = "bootnode1";

        vm.prank(_owner);
        swarmCoordinator.addBootnodes(newBootnodes);

        // Try to clear as non-manager
        vm.prank(_user);
        vm.expectRevert(SwarmCoordinator.OnlyBootnodeManager.selector);
        swarmCoordinator.clearBootnodes();
    }

    function test_Anyone_CanGetBootnodes() public {
        // First add some bootnodes as the owner
        string[] memory newBootnodes = new string[](2);
        newBootnodes[0] = "bootnode1";
        newBootnodes[1] = "bootnode2";

        vm.prank(_owner);
        swarmCoordinator.addBootnodes(newBootnodes);

        // Get bootnodes as a regular user
        vm.prank(_user);
        string[] memory storedBootnodes = swarmCoordinator.getBootnodes();

        // Verify the bootnodes are accessible
        assertEq(storedBootnodes.length, 2);
        assertEq(storedBootnodes[0], newBootnodes[0]);
        assertEq(storedBootnodes[1], newBootnodes[1]);
    }

    function test_Anyone_CanGetBootnodesCount() public {
        // First add some bootnodes as the owner
        string[] memory newBootnodes = new string[](3);
        newBootnodes[0] = "bootnode1";
        newBootnodes[1] = "bootnode2";
        newBootnodes[2] = "bootnode3";

        vm.prank(_owner);
        swarmCoordinator.addBootnodes(newBootnodes);

        // Get bootnode count as a regular user
        vm.prank(_user);
        uint256 count = swarmCoordinator.getBootnodesCount();

        // Verify the count is correct
        assertEq(count, 3);
    }

    function test_Anyone_CanSubmitWinners_Successfully() public {
        string[] memory winners = new string[](2);
        winners[0] = "QmWinner1";
        winners[1] = "QmWinner2";

        // Register peer IDs first
        vm.prank(_user1);
        swarmCoordinator.registerPeer(winners[0]);
        vm.prank(_user2);
        swarmCoordinator.registerPeer(winners[1]);

        // Submit winners for round 0
        vm.prank(_user1);
        vm.expectEmit(true, true, true, true);
        emit SwarmCoordinator.WinnerSubmitted(_user1, 0, winners);
        swarmCoordinator.submitWinners(0, winners);

        // Verify votes
        string[] memory voterVotes = swarmCoordinator.getVoterVotes(0, _user1);
        assertEq(voterVotes.length, 2);
        assertEq(voterVotes[0], winners[0]);
        assertEq(voterVotes[1], winners[1]);

        // Verify vote counts
        assertEq(swarmCoordinator.getPeerVoteCount(0, winners[0]), 1);
        assertEq(swarmCoordinator.getPeerVoteCount(0, winners[1]), 1);
    }

    function test_Nobody_CanSubmitWinners_ForFutureRound() public {
        string[] memory winners = new string[](1);
        winners[0] = "QmWinner1";

        // Register peer ID first
        vm.prank(_user1);
        swarmCoordinator.registerPeer(winners[0]);

        // Try to submit winners for future round
        vm.prank(_user1);
        vm.expectRevert(SwarmCoordinator.InvalidRoundNumber.selector);
        swarmCoordinator.submitWinners(1, winners);
    }

    function test_Nobody_CanVoteTwice_InSameRound() public {
        string[] memory winners = new string[](1);
        winners[0] = "QmWinner1";

        // Register peer ID first
        vm.prank(_user1);
        swarmCoordinator.registerPeer(winners[0]);

        // First vote
        vm.prank(_user1);
        swarmCoordinator.submitWinners(0, winners);

        // Try to vote again
        vm.prank(_user1);
        vm.expectRevert(SwarmCoordinator.WinnerAlreadyVoted.selector);
        swarmCoordinator.submitWinners(0, winners);
    }

    function test_Anyone_CanGetVoterVotes() public {
        string[] memory winners = new string[](2);
        winners[0] = "QmWinner1";
        winners[1] = "QmWinner2";

        // Register peer IDs first
        vm.prank(_user1);
        swarmCoordinator.registerPeer(winners[0]);
        vm.prank(_user2);
        swarmCoordinator.registerPeer(winners[1]);

        // Submit winners
        vm.prank(_user1);
        swarmCoordinator.submitWinners(0, winners);

        // Get votes as another user
        vm.prank(_user2);
        string[] memory voterVotes = swarmCoordinator.getVoterVotes(0, _user1);

        // Verify votes
        assertEq(voterVotes.length, 2);
        assertEq(voterVotes[0], winners[0]);
        assertEq(voterVotes[1], winners[1]);
    }

    function test_Anyone_CanGetPeerVoteCount() public {
        string[] memory winners = new string[](1);
        winners[0] = "QmWinner1";

        // Register peer ID first
        vm.prank(_user1);
        swarmCoordinator.registerPeer(winners[0]);

        // Submit winners
        vm.prank(_user1);
        swarmCoordinator.submitWinners(0, winners);

        // Get vote count as another user
        vm.prank(_user2);
        uint256 voteCount = swarmCoordinator.getPeerVoteCount(0, winners[0]);

        // Verify vote count
        assertEq(voteCount, 1);
    }

    function test_VoterVoteCount_IsTrackedCorrectly() public {
        string[] memory winners = new string[](2);
        winners[0] = "QmWinner1";
        winners[1] = "QmWinner2";

        // Register peer IDs first
        vm.prank(_user1);
        swarmCoordinator.registerPeer(winners[0]);
        vm.prank(_user2);
        swarmCoordinator.registerPeer(winners[1]);

        // Submit winners for round 0
        vm.prank(_user1);
        swarmCoordinator.submitWinners(0, winners);

        // Forward to next round
        vm.startPrank(_owner);
        swarmCoordinator.setStageCount(1);
        swarmCoordinator.setStageUpdater(_stageUpdater);
        vm.stopPrank();

        vm.prank(_stageUpdater);
        swarmCoordinator.updateStageAndRound();

        // Submit winners for round 1
        vm.prank(_user1);
        swarmCoordinator.submitWinners(1, winners);

        // Verify vote count
        assertEq(swarmCoordinator.getVoterVoteCount(_user1), 2);
        assertEq(swarmCoordinator.getVoterVoteCount(_user2), 0);
    }

    function test_VoterLeaderboard_ReturnsCorrectOrder() public {
        string[] memory winners1 = new string[](2);
        winners1[0] = "QmWinner1";
        winners1[1] = "QmWinner2";

        string[] memory winners2 = new string[](1);
        winners2[0] = "QmWinner3";

        // Register peer IDs first
        vm.prank(_user1);
        swarmCoordinator.registerPeer(winners1[0]);
        vm.prank(_user2);
        swarmCoordinator.registerPeer(winners1[1]);
        vm.prank(_user);
        swarmCoordinator.registerPeer(winners2[0]);

        // Set stage count
        vm.startPrank(_owner);
        swarmCoordinator.setStageCount(1);
        swarmCoordinator.setStageUpdater(_stageUpdater);
        vm.stopPrank();

        // Submit winners for round 0
        vm.prank(_user1);
        swarmCoordinator.submitWinners(0, winners1);

        // Forward to next round
        vm.prank(_stageUpdater);
        swarmCoordinator.updateStageAndRound();

        // Submit winners for round 1
        vm.prank(_user2);
        swarmCoordinator.submitWinners(1, winners1);

        // Forward to next round
        vm.prank(_stageUpdater);
        swarmCoordinator.updateStageAndRound();

        // Submit winners for round 2
        vm.prank(_user);
        swarmCoordinator.submitWinners(2, winners2);

        // Get top 3 voters
        address[] memory topVoters = swarmCoordinator.voterLeaderboard(0, 3);

        // Verify order
        assertEq(topVoters.length, 3);
        assertEq(topVoters[0], _user1);
        assertEq(topVoters[1], _user2);
        assertEq(topVoters[2], _user);
        assertEq(swarmCoordinator.getVoterVoteCount(topVoters[0]), 1);
        assertEq(swarmCoordinator.getVoterVoteCount(topVoters[1]), 1);
        assertEq(swarmCoordinator.getVoterVoteCount(topVoters[2]), 1);
    }

    function test_VoterLeaderboard_ReturnsCorrectSlice() public {
        string[] memory winners1 = new string[](2);
        winners1[0] = "QmWinner1";
        winners1[1] = "QmWinner2";

        string[] memory winners2 = new string[](1);
        winners2[0] = "QmWinner3";

        // Register peer IDs first
        vm.prank(_user1);
        swarmCoordinator.registerPeer(winners1[0]);
        vm.prank(_user2);
        swarmCoordinator.registerPeer(winners1[1]);
        vm.prank(_user);
        swarmCoordinator.registerPeer(winners2[0]);

        // Set stage count
        vm.startPrank(_owner);
        swarmCoordinator.setStageCount(1);
        swarmCoordinator.setStageUpdater(_stageUpdater);
        vm.stopPrank();

        // Submit winners for round 0
        vm.prank(_user1);
        swarmCoordinator.submitWinners(0, winners1);

        // Forward to next round
        vm.prank(_stageUpdater);
        swarmCoordinator.updateStageAndRound();

        // Submit winners for round 1
        vm.prank(_user2);
        swarmCoordinator.submitWinners(1, winners1);

        // Forward to next round
        vm.prank(_stageUpdater);
        swarmCoordinator.updateStageAndRound();

        // Submit winners for round 2
        vm.prank(_user);
        swarmCoordinator.submitWinners(2, winners2);

        // Get slice from index 2 to 3
        address[] memory slice = swarmCoordinator.voterLeaderboard(2, 3);
        assertEq(slice.length, 1);
        assertEq(slice[0], _user);
        assertEq(swarmCoordinator.getVoterVoteCount(slice[0]), 1);
    }

    function test_WinnerLeaderboard_ReturnsCorrectOrder() public {
        string[] memory winners1 = new string[](2);
        winners1[0] = "QmWinner1";
        winners1[1] = "QmWinner2";

        string[] memory winners2 = new string[](1);
        winners2[0] = "QmWinner3";

        // Register peer IDs first
        vm.prank(_user1);
        swarmCoordinator.registerPeer(winners1[0]);
        vm.prank(_user2);
        swarmCoordinator.registerPeer(winners1[1]);
        vm.prank(_user);
        swarmCoordinator.registerPeer(winners2[0]);

        // Set stage count
        vm.startPrank(_owner);
        swarmCoordinator.setStageCount(1);
        swarmCoordinator.setStageUpdater(_stageUpdater);
        vm.stopPrank();

        // Submit winners for round 0
        vm.prank(_user1);
        swarmCoordinator.submitWinners(0, winners1);

        // Forward to next round
        vm.prank(_stageUpdater);
        swarmCoordinator.updateStageAndRound();

        // Submit winners for round 1
        vm.prank(_user2);
        swarmCoordinator.submitWinners(1, winners1);

        // Forward to next round
        vm.prank(_stageUpdater);
        swarmCoordinator.updateStageAndRound();

        // Submit winners for round 2
        vm.prank(_user);
        swarmCoordinator.submitWinners(2, winners2);

        // Get top 3 winners
        string[] memory topWinners = swarmCoordinator.winnerLeaderboard(0, 3);

        // Verify order
        assertEq(topWinners.length, 3);
        assertEq(topWinners[0], winners1[0]);
        assertEq(topWinners[1], winners1[1]);
        assertEq(topWinners[2], winners2[0]);
        assertEq(swarmCoordinator.getTotalWins(topWinners[0]), 2);
        assertEq(swarmCoordinator.getTotalWins(topWinners[1]), 2);
        assertEq(swarmCoordinator.getTotalWins(topWinners[2]), 1);
    }

    function test_WinnerLeaderboard_ReturnsCorrectSlice() public {
        string[] memory winners1 = new string[](2);
        winners1[0] = "QmWinner1";
        winners1[1] = "QmWinner2";

        string[] memory winners2 = new string[](1);
        winners2[0] = "QmWinner3";

        // Register peer IDs first
        vm.prank(_user1);
        swarmCoordinator.registerPeer(winners1[0]);
        vm.prank(_user2);
        swarmCoordinator.registerPeer(winners1[1]);
        vm.prank(_user);
        swarmCoordinator.registerPeer(winners2[0]);

        // Set stage count
        vm.startPrank(_owner);
        swarmCoordinator.setStageCount(1);
        swarmCoordinator.setStageUpdater(_stageUpdater);
        vm.stopPrank();

        // Submit winners for round 0
        vm.prank(_user1);
        swarmCoordinator.submitWinners(0, winners1);

        // Forward to next round
        vm.prank(_stageUpdater);
        swarmCoordinator.updateStageAndRound();

        // Submit winners for round 1
        vm.prank(_user2);
        swarmCoordinator.submitWinners(1, winners1);

        // Forward to next round
        vm.prank(_stageUpdater);
        swarmCoordinator.updateStageAndRound();

        // Submit winners for round 2
        vm.prank(_user);
        swarmCoordinator.submitWinners(2, winners2);

        // Get slice from index 2 to 3
        string[] memory slice = swarmCoordinator.winnerLeaderboard(2, 3);
        assertEq(slice.length, 1);
        assertEq(slice[0], winners2[0]);
        assertEq(swarmCoordinator.getTotalWins(slice[0]), 1);
    }

    function test_WinnerLeaderboard_HandlesInvalidIndexes() public {
        string[] memory winners = new string[](1);
        winners[0] = "QmWinner1";

        // Register peer ID first
        vm.prank(_user1);
        swarmCoordinator.registerPeer(winners[0]);

        // Submit winners
        vm.prank(_user1);
        swarmCoordinator.submitWinners(0, winners);

        // Test with start > end
        vm.expectRevert("Start index must be less than or equal to end index");
        swarmCoordinator.winnerLeaderboard(2, 1);

        // Test with start > length
        string[] memory result = swarmCoordinator.winnerLeaderboard(5, 10);
        assertEq(result.length, 0);

        // Test with end > length
        result = swarmCoordinator.winnerLeaderboard(0, 10);
        assertEq(result.length, 1);
        assertEq(result[0], winners[0]);
    }

    function test_WinnerLeaderboard_ReturnsEmptyArray_WhenNoWinners() public {
        string[] memory result = swarmCoordinator.winnerLeaderboard(0, 10);
        assertEq(result.length, 0);
    }

    function test_WinnerLeaderboard_CorrectlyHandlesMoreThanMaxTopWinners() public {
        string[] memory winners = new string[](100);
        address[] memory users = new address[](100);
        for (uint256 i = 0; i < 100; i++) {
            winners[i] = string(abi.encodePacked("QmWinner", abi.encodePacked(i)));
            users[i] = makeAddr(string(abi.encodePacked("user", i)));

            // Register user
            vm.prank(users[i]);
            swarmCoordinator.registerPeer(winners[i]);
        }

        // Register voter
        vm.prank(_user);
        swarmCoordinator.registerPeer("QmUser");

        // Submit winners
        vm.prank(_user);
        swarmCoordinator.submitWinners(0, winners);

        // Get top 100 winners
        string[] memory topWinners = swarmCoordinator.winnerLeaderboard(0, 100);
        assertEq(topWinners.length, 100);
        for (uint256 i = 0; i < 100; i++) {
            assertEq(topWinners[i], winners[i]);
        }

        // Add two votes for a new winner
        string[] memory topWinner = new string[](1);
        topWinner[0] = "QmUser";

        vm.prank(_owner);
        swarmCoordinator.updateStageAndRound();

        vm.prank(_user);
        swarmCoordinator.submitWinners(1, topWinner);

        vm.prank(_owner);
        swarmCoordinator.updateStageAndRound();

        vm.prank(_user);
        swarmCoordinator.submitWinners(2, topWinner);

        // New winner bubbled up the leaderboard
        topWinners = swarmCoordinator.winnerLeaderboard(0, 1);
        assertEq(topWinners[0], "QmUser");
        assertEq(swarmCoordinator.getTotalWins("QmUser"), 2);
    }
}
