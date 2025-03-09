// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {Test, console} from "forge-std/Test.sol";
import {SwarmCoordinator} from "../src/SwarmCoordinator.sol";

contract SwarmCoordinatorTest is Test {
    SwarmCoordinator public swarmCoordinator;

    uint256[3] public stageDurations = [uint256(100), uint256(100), uint256(100)];

    function setUp() public {
        swarmCoordinator = new SwarmCoordinator();
        swarmCoordinator.setStageDurations(stageDurations);
    }

    function test_SwarmCoordinator_IsCorrectlyDeployed() public {
        assertEq(swarmCoordinator.owner(), address(this));
    }

    function test_Anyone_Can_QueryCurrentRound() public {
        uint256 currentRound = swarmCoordinator.currentRound();
        assertEq(currentRound, 0);
    }

    function test_Anyone_CanAdvanceStage_IfEnoughTimeHasPassed() public {
        uint256 currentStage = uint256(swarmCoordinator.currentStage());

        vm.roll(block.number + stageDurations[currentStage] + 1);
        (, uint256 newStage) = swarmCoordinator.updateStageAndRound();

        assertEq(newStage, currentStage + 1);
    }

    function test_Anyone_CannotAdvanceStage_IfNotEnoughTimeHasPassed() public {
        uint256 currentStage = uint256(swarmCoordinator.currentStage());

        vm.roll(block.number + stageDurations[currentStage] - 1);
        
        vm.expectRevert(SwarmCoordinator.StageDurationNotElapsed.selector);
        swarmCoordinator.updateStageAndRound();
    }

    function test_Anyone_CanAdvanceRound_IfEnoughTimeHasPassed() public {
        uint256 currentRound = uint256(swarmCoordinator.currentRound());

        for (uint256 i = 0; i < stageDurations.length; i++) {
            vm.roll(block.number + stageDurations[i] + 1);
            swarmCoordinator.updateStageAndRound();
        }

        uint256 newRound = uint256(swarmCoordinator.currentRound());
        uint256 newStage = uint256(swarmCoordinator.currentStage());
        assertEq(newRound, currentRound + 1);
        assertEq(newStage, 0);
    }
}
