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
    
    // Bootnode manager and bootnodes
    address private _bootnodeManager;
    string[] private _bootnodes;

    // Events
    event StageAdvanced(uint256 indexed roundNumber, uint256 newStage);
    event RoundAdvanced(uint256 indexed newRoundNumber);
    event EOALinked(address indexed eoa, bytes peerId);
    event BootnodeManagerUpdated(address indexed previousManager, address indexed newManager);
    event BootnodesAdded(address indexed manager, uint256 count);
    event BootnodeRemoved(address indexed manager, uint256 index);
    event AllBootnodesCleared(address indexed manager);

    // Errors
    error StageDurationNotElapsed();
    error StageOutOfBounds();
    error OnlyBootnodeManager();
    error InvalidBootnodeIndex();

    // Constructor
    constructor() Ownable(msg.sender) {
        _stageStartBlock = block.number;
        _bootnodeManager = msg.sender; // Initially set the owner as the bootnode manager
        emit BootnodeManagerUpdated(address(0), msg.sender);
    }

    // Bootnode manager modifier
    modifier onlyBootnodeManager() {
        if (msg.sender != _bootnodeManager) revert OnlyBootnodeManager();
        _;
    }

    function setStageDuration(uint256 stage_, uint256 stageDuration_) public onlyOwner {
        require(stage_ < _stageCount, StageOutOfBounds());
        _stageDurations[stage_] = stageDuration_;
    }

    function setStageCount(uint256 stageCount_) public onlyOwner {
        _stageCount = stageCount_;
    }

    function stageCount() public view returns (uint256) {
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

    function addPeer(bytes calldata peerId) external {
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

    /**
     * @dev Sets a new bootnode manager
     * @param newManager The address of the new bootnode manager
     */
    function setBootnodeManager(address newManager) external onlyOwner {
        address oldManager = _bootnodeManager;
        _bootnodeManager = newManager;
        emit BootnodeManagerUpdated(oldManager, newManager);
    }

    /**
     * @dev Returns the current bootnode manager
     * @return The address of the current bootnode manager
     */
    function bootnodeManager() external view returns (address) {
        return _bootnodeManager;
    }

    /**
     * @dev Adds multiple bootnodes to the list
     * @param newBootnodes Array of bootnode strings to add
     */
    function addBootnodes(string[] calldata newBootnodes) external onlyBootnodeManager {
        uint256 count = newBootnodes.length;
        for (uint256 i = 0; i < count; i++) {
            _bootnodes.push(newBootnodes[i]);
        }
        emit BootnodesAdded(msg.sender, count);
    }

    /**
     * @dev Removes a bootnode at the specified index
     * @param index The index of the bootnode to remove
     */
    function removeBootnode(uint256 index) external onlyBootnodeManager {
        if (index >= _bootnodes.length) revert InvalidBootnodeIndex();
        
        // Move the last element to the position being deleted (unless it's the last element)
        if (index < _bootnodes.length - 1) {
            _bootnodes[index] = _bootnodes[_bootnodes.length - 1];
        }
        
        // Remove the last element
        _bootnodes.pop();
        
        emit BootnodeRemoved(msg.sender, index);
    }

    /**
     * @dev Clears all bootnodes
     */
    function clearBootnodes() external onlyBootnodeManager {
        delete _bootnodes;
        emit AllBootnodesCleared(msg.sender);
    }

    /**
     * @dev Returns all bootnodes
     * @return Array of all bootnode strings
     */
    function getBootnodes() external view returns (string[] memory) {
        return _bootnodes;
    }

    /**
     * @dev Returns the number of bootnodes
     * @return The count of bootnodes
     */
    function getBootnodesCount() external view returns (uint256) {
        return _bootnodes.length;
    }
}
