// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

import "@openzeppelin/contracts/access/Ownable.sol";

contract SwarmCoordinator is Ownable {
    enum Stage {
        GenerateAnswers,
        CritiquePeers,
        PeerVoting
    }

    uint256 _currentRound = 0;
    uint256 _currentStage = 0;
    uint256[3] _stageDurations;
    uint256 _stageStartBlock;

    // Events
    event StageAdvanced(uint256 indexed roundNumber, uint256 newStage);
    event RoundAdvanced(uint256 indexed newRoundNumber);

    // Errors
    error StageDurationNotElapsed();

    // Constructor
    constructor() Ownable(msg.sender) {
        _stageStartBlock = block.number;
    }

    function setStageDurations(uint256[3] memory stageDurations_) public onlyOwner {
        _stageDurations = stageDurations_;
    }

    function currentRound() public view returns (uint256) {
        return _currentRound;
    }

    function currentStage() public view returns (uint256) {
        return _currentStage;
    }

    /**
     * @dev Updates the current stage and round if enough time has passed
     * @return The current stage after any updates
     */
    function updateStageAndRound() public returns (uint256, uint256) {
        // Check if enough time has passed for the current stage
        uint256 stageIndex = _currentStage;
        require(block.number >= _stageStartBlock + _stageDurations[stageIndex], StageDurationNotElapsed());

        if (Stage(_currentStage) == Stage.PeerVoting) {
            // If we're at the last stage, advance to the next round
            _currentRound++;
            _currentStage = 0;
            emit RoundAdvanced(_currentRound);
        } else {
            // Otherwise, advance to the next stage
            _currentStage = _currentStage + 1;
        }

        // Update the stage start block
        _stageStartBlock = block.number;
        emit StageAdvanced(_currentRound, _currentStage);

        return (_currentRound, _currentStage);
    }
}
