// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {Test, console} from "forge-std/Test.sol";
import {SwarmCoordinator} from "../src/SwarmCoordinator.sol";

contract SwarmCoordinatorTest is Test {
    SwarmCoordinator public swarmCoordinator;

    address _owner = makeAddr("owner");
    address _bootnodeManager = makeAddr("bootnodeManager");
    address _winnerManager = makeAddr("winnerManager");
    address _user = makeAddr("user");

    function setUp() public {
        vm.startPrank(_owner);
        swarmCoordinator = new SwarmCoordinator();
        vm.stopPrank();
    }

    function test_SwarmCoordinator_IsCorrectlyDeployed() public view {
        assertEq(swarmCoordinator.owner(), address(_owner));
    }

    function test_Owner_CanSetStageDurations_Successfully() public {
        uint256 stage_ = 5;
        uint256 stageDuration_ = 100;

        vm.startPrank(_owner);
        // We make sure we got enough stages set to avoid an out of bounds error
        swarmCoordinator.setStageCount(stage_ + 1);
        swarmCoordinator.setStageDuration(stage_, stageDuration_);
        vm.stopPrank();
    }

    function test_Owner_CannotSetStageDuration_ForOutOfBoundsStage() public {
        uint256 stageCount_ = 3;

        vm.startPrank(_owner);
        swarmCoordinator.setStageCount(stageCount_);
        vm.expectRevert(SwarmCoordinator.StageOutOfBounds.selector);
        swarmCoordinator.setStageDuration(stageCount_, 100);
        vm.stopPrank();
    }

    function test_Nobody_CanSetStageDurations_Successfully() public {
        vm.expectRevert();
        swarmCoordinator.setStageDuration(0, 1);
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

    function test_Anyone_CanAdvanceStage_IfEnoughTimeHasPassed() public {
        uint256 stageCount_ = 2;
        uint256 stageDuration_ = 100;

        vm.startPrank(_owner);
        swarmCoordinator.setStageCount(stageCount_);
        swarmCoordinator.setStageDuration(0, stageDuration_);
        swarmCoordinator.setStageDuration(1, stageDuration_);
        vm.stopPrank();

        uint256 startingStage = uint256(swarmCoordinator.currentStage());

        vm.roll(block.number + stageDuration_ + 1);
        (, uint256 newStage) = swarmCoordinator.updateStageAndRound();

        assertEq(newStage, startingStage + 1);
    }

    function test_Nobody_CanAdvanceStage_IfNotEnoughTimeHasPassed() public {
        uint256 stageDuration_ = 100;

        vm.startPrank(_owner);
        swarmCoordinator.setStageCount(1);
        swarmCoordinator.setStageDuration(0, stageDuration_);
        vm.stopPrank();

        vm.roll(block.number + stageDuration_ - 1);

        vm.expectRevert(SwarmCoordinator.StageDurationNotElapsed.selector);
        swarmCoordinator.updateStageAndRound();
    }

    function test_Anyone_CanAdvanceRound_IfEnoughTimeHasPassed() public {
        uint256 stageCount_ = 3;
        uint256 stageDuration_ = 100;

        vm.startPrank(_owner);
        swarmCoordinator.setStageCount(stageCount_);
        swarmCoordinator.setStageDuration(0, stageDuration_);
        swarmCoordinator.setStageDuration(1, stageDuration_);
        swarmCoordinator.setStageDuration(2, stageDuration_);
        vm.stopPrank();

        uint256 startingRound = uint256(swarmCoordinator.currentRound());

        for (uint256 i = 0; i < stageCount_; i++) {
            vm.roll(block.number + stageDuration_ + 1);
            swarmCoordinator.updateStageAndRound();
        }

        uint256 newRound = uint256(swarmCoordinator.currentRound());
        uint256 newStage = uint256(swarmCoordinator.currentStage());
        assertEq(newRound, startingRound + 1);
        assertEq(newStage, 0);
    }

    function test_Anyone_CanAddPeer_Successfully() public {
        address user = makeAddr("user");
        bytes memory peerId = bytes("QmYyQSo1c1Ym7orWxLYvCrM2EmxFTANf8wXmmE7DWjhx5N");

        vm.startPrank(user);
        vm.expectEmit(true, true, false, true);
        emit SwarmCoordinator.PeerRegistered(user, peerId);
        swarmCoordinator.registerPeer(peerId);
        vm.stopPrank();

        // Verify the mapping was updated correctly using the getter function
        bytes memory storedPeerId = swarmCoordinator.getPeerId(user);
        assertEq(keccak256(storedPeerId), keccak256(peerId), "Peer ID not stored correctly");
    }

    function test_Anyone_CanRegister_DifferentPeerIds() public {
        address user1 = makeAddr("user1");
        address user2 = makeAddr("user2");
        bytes memory peerId1 = bytes("peerId1");
        bytes memory peerId2 = bytes("peerId2");

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
        bytes memory storedPeerId1 = swarmCoordinator.getPeerId(user1);
        bytes memory storedPeerId2 = swarmCoordinator.getPeerId(user2);
        assertEq(keccak256(storedPeerId1), keccak256(peerId1), "Peer ID 1 not stored correctly");
        assertEq(keccak256(storedPeerId2), keccak256(peerId2), "Peer ID 2 not stored correctly");
    }

    function test_Anyone_CanUpdate_ItsOwnPeerId() public {
        address user = makeAddr("user");
        bytes memory peerId1 = bytes("peerId1");
        bytes memory peerId2 = bytes("peerId2");

        // User registers first peer
        vm.prank(user);
        vm.expectEmit(true, true, false, true);
        emit SwarmCoordinator.PeerRegistered(user, peerId1);
        swarmCoordinator.registerPeer(peerId1);

        // Verify first peer ID was stored correctly
        bytes memory storedPeerId1 = swarmCoordinator.getPeerId(user);
        assertEq(keccak256(storedPeerId1), keccak256(peerId1), "First peer ID not stored correctly");

        // User updates to second peer
        vm.prank(user);
        vm.expectEmit(true, true, false, true);
        emit SwarmCoordinator.PeerRegistered(user, peerId2);
        swarmCoordinator.registerPeer(peerId2);

        // Verify second peer ID overwrote the first one
        bytes memory storedPeerId2 = swarmCoordinator.getPeerId(user);
        assertEq(keccak256(storedPeerId2), keccak256(peerId2), "Second peer ID not stored correctly");
        assertTrue(keccak256(storedPeerId2) != keccak256(peerId1), "Peer ID was not updated");
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

    // Winner manager tests
    function test_SwarmCoordinatorDeployment_SetsWinnerManager_ToOwner() public view {
        assertEq(swarmCoordinator.winnerManager(), _owner);
    }

    function test_Owner_CanSet_WinnerManager() public {
        address manager = makeAddr("manager");

        vm.startPrank(_owner);
        vm.expectEmit(true, true, false, false);
        emit SwarmCoordinator.WinnerManagerUpdated(_owner, manager);
        swarmCoordinator.setWinnerManager(manager);
        vm.stopPrank();

        assertEq(swarmCoordinator.winnerManager(), manager);
    }

    function test_NonOwner_CannotSet_WinnerManager() public {
        address manager = makeAddr("manager");

        vm.prank(_user);
        vm.expectRevert();
        swarmCoordinator.setWinnerManager(manager);
    }

    function test_WinnerManager_CanSubmit_Winner() public {
        address manager = makeAddr("manager");
        address winner = makeAddr("winner");
        uint256 reward = 100;

        // Set up winner manager
        vm.prank(_owner);
        swarmCoordinator.setWinnerManager(manager);

        // Submit winner for round 0
        vm.prank(manager);
        vm.expectEmit(true, true, false, true);
        emit SwarmCoordinator.WinnerSubmitted(0, winner, reward);
        swarmCoordinator.submitWinner(0, winner, reward);

        // Verify winner and accrued rewards
        assertEq(swarmCoordinator.getRoundWinner(0), winner);
        assertEq(swarmCoordinator.getAccruedRewards(winner), reward);
    }

    function test_NonWinnerManager_CannotSubmit_Winner() public {
        address winner = makeAddr("winner");
        uint256 reward = 100;

        vm.prank(_user);
        vm.expectRevert(SwarmCoordinator.OnlyWinnerManager.selector);
        swarmCoordinator.submitWinner(0, winner, reward);
    }

    function test_Nobody_CanSubmitWinner_ForFutureRound() public {
        address manager = makeAddr("manager");
        address winner = makeAddr("winner");
        uint256 reward = 100;

        // Set up winner manager
        vm.prank(_owner);
        swarmCoordinator.setWinnerManager(manager);

        // Try to submit winner for future round
        vm.prank(manager);
        vm.expectRevert(SwarmCoordinator.InvalidRoundNumber.selector);
        swarmCoordinator.submitWinner(1, winner, reward);
    }

    function test_Manager_CannotSubmitWinner_Twice() public {
        address manager = makeAddr("manager");
        address winner = makeAddr("winner");
        uint256 reward = 100;

        // Set up winner manager
        vm.prank(_owner);
        swarmCoordinator.setWinnerManager(manager);

        // Submit winner first time
        vm.startPrank(manager);
        swarmCoordinator.submitWinner(0, winner, reward);

        // Try to submit different winner for same round
        address winner2 = makeAddr("winner2");
        vm.expectRevert(SwarmCoordinator.WinnerAlreadySubmitted.selector);
        swarmCoordinator.submitWinner(0, winner2, reward);
        vm.stopPrank();
    }

    function test_AccruedRewards_Accumulate_Successfully() public {
        address manager = makeAddr("manager");
        address winner = makeAddr("winner");
        uint256 reward1 = 100;
        uint256 reward2 = 200;

        // Set up winner manager
        vm.prank(_owner);
        swarmCoordinator.setWinnerManager(manager);

        // Submit winner for round 0
        vm.prank(manager);
        swarmCoordinator.submitWinner(0, winner, reward1);

        // Advance to round 1
        vm.startPrank(_owner);
        swarmCoordinator.setStageCount(1);
        swarmCoordinator.setStageDuration(0, 100);
        vm.roll(block.number + 101);
        swarmCoordinator.updateStageAndRound();
        vm.stopPrank();

        // Submit winner for round 1
        vm.prank(manager);
        swarmCoordinator.submitWinner(1, winner, reward2);

        // Verify accrued rewards
        assertEq(swarmCoordinator.getAccruedRewards(winner), reward1 + reward2);
    }

    function test_Anyone_CanGetRoundWinner() public {
        address manager = makeAddr("manager");
        address winner = makeAddr("winner");
        uint256 reward = 100;

        // Set up winner manager and submit winner
        vm.prank(_owner);
        swarmCoordinator.setWinnerManager(manager);

        vm.prank(manager);
        swarmCoordinator.submitWinner(0, winner, reward);

        // Get winner as regular user
        vm.prank(_user);
        address roundWinner = swarmCoordinator.getRoundWinner(0);

        // Verify winner
        assertEq(roundWinner, winner);
    }

    function test_Anyone_CanGet_AccruedRewards() public {
        address manager = makeAddr("manager");
        address winner = makeAddr("winner");
        uint256 reward = 100;

        // Set up winner manager and submit winner
        vm.prank(_owner);
        swarmCoordinator.setWinnerManager(manager);

        vm.prank(manager);
        swarmCoordinator.submitWinner(0, winner, reward);

        // Get accrued rewards as regular user
        vm.prank(_user);
        uint256 accruedRewards = swarmCoordinator.getAccruedRewards(winner);

        // Verify rewards
        assertEq(accruedRewards, reward);
    }
}
