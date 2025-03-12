// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {ECDSA} from "@openzeppelin/contracts/utils/cryptography/ECDSA.sol";

contract SwarmCoordinator is Ownable {
    // Types
    using ECDSA for bytes32;

    // State
    uint256 _currentRound = 0;
    uint256 _currentStage = 0;
    uint256 _stageCount = 0;
    // stage => duration
    mapping(uint256 => uint256) _stageDurations;
    uint256 _stageStartBlock;
    mapping(address => bytes) _eoaToPeerId;

    // Events
    event StageAdvanced(uint256 indexed roundNumber, uint256 newStage);
    event RoundAdvanced(uint256 indexed newRoundNumber);
    event EOALinked(address indexed eoa, bytes peerId);

    // Errors
    error StageDurationNotElapsed();
    error StageOutOfBounds();

    // Constructor
    constructor() Ownable(msg.sender) {
        _stageStartBlock = block.number;
    }

    function setStageDuration(uint256 stage_, uint256 stageDuration_) public onlyOwner {
        require(stage_ < _stageCount, StageOutOfBounds());
        _stageDurations[stage_] = stageDuration_;
    }

    function setStageCount(uint256 stageCount_) public onlyOwner {
        _stageCount = stageCount_;
    }

    function stageCount() public view returns (uint256)  {
        return _stageCount;
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

        if (_currentStage + 1 >= _stageCount) {
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

    function addPeer(
        bytes calldata peerId
    ) external {
        address eoa = msg.sender;

        _eoaToPeerId[eoa] = peerId;

        emit EOALinked(eoa, peerId);
    }

    /**
     * @dev Retrieves the peer ID associated with an EOA address
     * @param eoa The EOA address to look up
     * @return The peer ID associated with the EOA address
     */
    function getPeerId(address eoa) external view returns (bytes memory) {
        return _eoaToPeerId[eoa];
    }
}
