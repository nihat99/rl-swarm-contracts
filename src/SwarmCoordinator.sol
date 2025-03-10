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

    // Events
    event StageAdvanced(uint256 indexed roundNumber, uint256 newStage);
    event RoundAdvanced(uint256 indexed newRoundNumber);

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

    // Peer management

    function addPeer(
        bytes calldata pubkeyBytes, // Libp2p public key part of peer ID
        bytes calldata signature
    ) external {
        address eoa = msg.sender;

        // Check signature
        bytes32 eoaHash = keccak256(abi.encodePacked(eoa));
        bytes32 signedMessage = eoaHash.toEthSignedMessageHash();
        address recoveredSigner = signedMessage.recover(signature);
        // require(eoa == recoveredSigner, )
        
        // Extract public key from peer ID string (e.g., parse "/p2p/Qm...") → pubkeyBytes
        require(recoveredAddr == pubkeyToAddress(pubkeyBytes), "Invalid signature");
        
        eoaToPubkey[eoa] = pubkeyBytes;
        emit EOALinked(eoa, pubkeyBytes);
    }

    // Helper to convert public key bytes to address (simplified for example)
    function pubkeyToAddress(bytes memory pubkey) private pure returns (address) {
        // Implement multibase decoding → Ethereum address conversion here
        return abi.decode(pubkey, (address)); // Replace with actual logic
    }       
}
