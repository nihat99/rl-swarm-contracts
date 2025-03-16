// SPDX-License-Identifier: MIT
pragma solidity ^0.8;

import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";

/**
 * @title SwarmCoordinator
 * @dev Manages coordination of a swarm network including round/stage progression,
 * peer registration, bootnode management, and winner selection.
 */
contract SwarmCoordinator is Ownable {
    // .---------------------------------------------------.
    // |  █████████   █████               █████            |
    // | ███░░░░░███ ░░███               ░░███             |
    // |░███    ░░░  ███████    ██████   ███████    ██████ |
    // |░░█████████ ░░░███░    ░░░░░███ ░░░███░    ███░░███|
    // | ░░░░░░░░███  ░███      ███████   ░███    ░███████ |
    // | ███    ░███  ░███ ███ ███░░███   ░███ ███░███░░░  |
    // |░░█████████   ░░█████ ░░████████  ░░█████ ░░██████ |
    // | ░░░░░░░░░     ░░░░░   ░░░░░░░░    ░░░░░   ░░░░░░  |
    // '---------------------------------------------------'

    // Current round number
    uint256 _currentRound = 0;
    // Current stage within the round
    uint256 _currentStage = 0;
    // Total number of stages in a round
    uint256 _stageCount = 0;
    // Maps stage number to its duration in blocks
    mapping(uint256 => uint256) _stageDurations;
    // Block number when current stage started
    uint256 _stageStartBlock;
    // Maps EOA addresses to their corresponding peer IDs
    mapping(address => bytes) _eoaToPeerId;

    // Winner management state
    // Address authorized to manage winners
    address private _winnerManager;
    // Maps round numbers to winner addresses
    mapping(uint256 => address) private _roundWinners;
    // Maps accounts to their total accumulated rewards
    mapping(address => uint256) private _accruedRewards;

    // Bootnode management state
    // Address authorized to manage bootnodes
    address private _bootnodeManager;
    // List of bootnode addresses/endpoints
    string[] private _bootnodes;

    // .-------------------------------------------------------------.
    // | ██████████                                  █████           |
    // |░░███░░░░░█                                 ░░███            |
    // | ░███  █ ░  █████ █████  ██████  ████████   ███████    █████ |
    // | ░██████   ░░███ ░░███  ███░░███░░███░░███ ░░░███░    ███░░  |
    // | ░███░░█    ░███  ░███ ░███████  ░███ ░███   ░███    ░░█████ |
    // | ░███ ░   █ ░░███ ███  ░███░░░   ░███ ░███   ░███ ███ ░░░░███|
    // | ██████████  ░░█████   ░░██████  ████ █████  ░░█████  ██████ |
    // |░░░░░░░░░░    ░░░░░     ░░░░░░  ░░░░ ░░░░░    ░░░░░  ░░░░░░  |
    // '-------------------------------------------------------------'

    event StageAdvanced(uint256 indexed roundNumber, uint256 newStage);
    event RoundAdvanced(uint256 indexed newRoundNumber);
    event PeerRegistered(address indexed eoa, bytes peerId);
    event BootnodeManagerUpdated(address indexed previousManager, address indexed newManager);
    event BootnodesAdded(address indexed manager, uint256 count);
    event BootnodeRemoved(address indexed manager, uint256 index);
    event AllBootnodesCleared(address indexed manager);
    event WinnerManagerUpdated(address indexed previousManager, address indexed newManager);
    event WinnerSubmitted(uint256 indexed roundNumber, address indexed winner, uint256 reward);
    event RewardsAccrued(address indexed account, uint256 newTotal);

    // .----------------------------------------------------------.
    // | ██████████                                               |
    // |░░███░░░░░█                                               |
    // | ░███  █ ░  ████████  ████████   ██████  ████████   █████ |
    // | ░██████   ░░███░░███░░███░░███ ███░░███░░███░░███ ███░░  |
    // | ░███░░█    ░███ ░░░  ░███ ░░░ ░███ ░███ ░███ ░░░ ░░█████ |
    // | ░███ ░   █ ░███      ░███     ░███ ░███ ░███      ░░░░███|
    // | ██████████ █████     █████    ░░██████  █████     ██████ |
    // |░░░░░░░░░░ ░░░░░     ░░░░░      ░░░░░░  ░░░░░     ░░░░░░  |
    // '----------------------------------------------------------'

    error StageDurationNotElapsed();
    error StageOutOfBounds();
    error OnlyBootnodeManager();
    error InvalidBootnodeIndex();
    error OnlyWinnerManager();
    error InvalidRoundNumber();
    error WinnerAlreadySubmitted();

    // .-------------------------------------------------------------------------------------.
    // | ██████   ██████              █████  ███     ██████   ███                            |
    // |░░██████ ██████              ░░███  ░░░     ███░░███ ░░░                             |
    // | ░███░█████░███   ██████   ███████  ████   ░███ ░░░  ████   ██████  ████████   █████ |
    // | ░███░░███ ░███  ███░░███ ███░░███ ░░███  ███████   ░░███  ███░░███░░███░░███ ███░░  |
    // | ░███ ░░░  ░███ ░███ ░███░███ ░███  ░███ ░░░███░     ░███ ░███████  ░███ ░░░ ░░█████ |
    // | ░███      ░███ ░███ ░███░███ ░███  ░███   ░███      ░███ ░███░░░   ░███      ░░░░███|
    // | █████     █████░░██████ ░░████████ █████  █████     █████░░██████  █████     ██████ |
    // |░░░░░     ░░░░░  ░░░░░░   ░░░░░░░░ ░░░░░  ░░░░░     ░░░░░  ░░░░░░  ░░░░░     ░░░░░░  |
    // '-------------------------------------------------------------------------------------'

    // Bootnode manager modifier
    modifier onlyBootnodeManager() {
        if (msg.sender != _bootnodeManager) revert OnlyBootnodeManager();
        _;
    }

    // Winner manager modifier
    modifier onlyWinnerManager() {
        if (msg.sender != _winnerManager) revert OnlyWinnerManager();
        _;
    }

    // .--------------------------------------------------------------------------------------------------------------.
    // |   █████████                               █████                                   █████                      |
    // |  ███░░░░░███                             ░░███                                   ░░███                       |
    // | ███     ░░░   ██████  ████████    █████  ███████   ████████  █████ ████  ██████  ███████    ██████  ████████ |
    // |░███          ███░░███░░███░░███  ███░░  ░░░███░   ░░███░░███░░███ ░███  ███░░███░░░███░    ███░░███░░███░░███|
    // |░███         ░███ ░███ ░███ ░███ ░░█████   ░███     ░███ ░░░  ░███ ░███ ░███ ░░░   ░███    ░███ ░███ ░███ ░░░ |
    // |░░███     ███░███ ░███ ░███ ░███  ░░░░███  ░███ ███ ░███      ░███ ░███ ░███  ███  ░███ ███░███ ░███ ░███     |
    // | ░░█████████ ░░██████  ████ █████ ██████   ░░█████  █████     ░░████████░░██████   ░░█████ ░░██████  █████    |
    // |  ░░░░░░░░░   ░░░░░░  ░░░░ ░░░░░ ░░░░░░     ░░░░░  ░░░░░       ░░░░░░░░  ░░░░░░     ░░░░░   ░░░░░░  ░░░░░     |
    // '--------------------------------------------------------------------------------------------------------------'

    constructor() Ownable(msg.sender) {
        _stageStartBlock = block.number;
        _bootnodeManager = msg.sender; // Initially set the owner as the bootnode manager
        _winnerManager = msg.sender; // Initially set the owner as the winner manager
        emit BootnodeManagerUpdated(address(0), msg.sender);
        emit WinnerManagerUpdated(address(0), msg.sender);
    }

    // .---------------------------------------------------------------.
    // | ███████████                                      █████        |
    // |░░███░░░░░███                                    ░░███         |
    // | ░███    ░███   ██████  █████ ████ ████████    ███████   █████ |
    // | ░██████████   ███░░███░░███ ░███ ░░███░░███  ███░░███  ███░░  |
    // | ░███░░░░░███ ░███ ░███ ░███ ░███  ░███ ░███ ░███ ░███ ░░█████ |
    // | ░███    ░███ ░███ ░███ ░███ ░███  ░███ ░███ ░███ ░███  ░░░░███|
    // | █████   █████░░██████  ░░████████ ████ █████░░████████ ██████ |
    // |░░░░░   ░░░░░  ░░░░░░    ░░░░░░░░ ░░░░ ░░░░░  ░░░░░░░░ ░░░░░░  |
    // '---------------------------------------------------------------'

    /**
     * @dev Returns the current round number
     * @return Current round number
     */
    function currentRound() public view returns (uint256) {
        return _currentRound;
    }

    /**
     * @dev Returns the current stage number within the round
     * @return Current stage number
     */
    function currentStage() public view returns (uint256) {
        return _currentStage;
    }

    /**
     * @dev Sets the duration for a specific stage
     * @param stage_ The stage number to set duration for
     * @param stageDuration_ Duration in blocks for the stage
     */
    function setStageDuration(uint256 stage_, uint256 stageDuration_) public onlyOwner {
        require(stage_ < _stageCount, StageOutOfBounds());
        _stageDurations[stage_] = stageDuration_;
    }

    /**
     * @dev Sets the total number of stages in a round
     * @param stageCount_ New total number of stages
     */
    function setStageCount(uint256 stageCount_) public onlyOwner {
        _stageCount = stageCount_;
    }

    /**
     * @dev Returns the total number of stages in a round
     * @return Number of stages
     */
    function stageCount() public view returns (uint256) {
        return _stageCount;
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

    // .-------------------------------------------------.
    // | ███████████                                     |
    // |░░███░░░░░███                                    |
    // | ░███    ░███  ██████   ██████  ████████   █████ |
    // | ░██████████  ███░░███ ███░░███░░███░░███ ███░░  |
    // | ░███░░░░░░  ░███████ ░███████  ░███ ░░░ ░░█████ |
    // | ░███        ░███░░░  ░███░░░   ░███      ░░░░███|
    // | █████       ░░██████ ░░██████  █████     ██████ |
    // |░░░░░         ░░░░░░   ░░░░░░  ░░░░░     ░░░░░░  |
    // '-------------------------------------------------'

    /**
     * @dev Registers a peer's ID and associates it with the sender's address
     * @param peerId The peer ID to register
     */
    function registerPeer(bytes calldata peerId) external {
        address eoa = msg.sender;

        _eoaToPeerId[eoa] = peerId;

        emit PeerRegistered(eoa, peerId);
    }

    /**
     * @dev Retrieves the peer ID associated with an EOA address
     * @param eoa The EOA address to look up
     * @return The peer ID associated with the EOA address
     */
    function getPeerId(address eoa) external view returns (bytes memory) {
        return _eoaToPeerId[eoa];
    }

    // .----------------------------------------------------------------------------------------.
    // | ███████████                     █████                            █████                 |
    // |░░███░░░░░███                   ░░███                            ░░███                  |
    // | ░███    ░███  ██████   ██████  ███████   ████████    ██████   ███████   ██████   █████ |
    // | ░██████████  ███░░███ ███░░███░░░███░   ░░███░░███  ███░░███ ███░░███  ███░░███ ███░░  |
    // | ░███░░░░░███░███ ░███░███ ░███  ░███     ░███ ░███ ░███ ░███░███ ░███ ░███████ ░░█████ |
    // | ░███    ░███░███ ░███░███ ░███  ░███ ███ ░███ ░███ ░███ ░███░███ ░███ ░███░░░   ░░░░███|
    // | ███████████ ░░██████ ░░██████   ░░█████  ████ █████░░██████ ░░████████░░██████  ██████ |
    // |░░░░░░░░░░░   ░░░░░░   ░░░░░░     ░░░░░  ░░░░ ░░░░░  ░░░░░░   ░░░░░░░░  ░░░░░░  ░░░░░░  |
    // '----------------------------------------------------------------------------------------'

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
     * @notice Only callable by the bootnode manager
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
     * @notice Only callable by the bootnode manager
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
     * @dev Clears all bootnodes from the list
     * @notice Only callable by the bootnode manager
     */
    function clearBootnodes() external onlyBootnodeManager {
        delete _bootnodes;
        emit AllBootnodesCleared(msg.sender);
    }

    /**
     * @dev Returns all registered bootnodes
     * @return Array of all bootnode strings
     */
    function getBootnodes() external view returns (string[] memory) {
        return _bootnodes;
    }

    /**
     * @dev Returns the number of registered bootnodes
     * @return The count of bootnodes
     */
    function getBootnodesCount() external view returns (uint256) {
        return _bootnodes.length;
    }

    // .---------------------------------------------------------------------------.
    // | █████   ███   █████  ███                                                  |
    // |░░███   ░███  ░░███  ░░░                                                   |
    // | ░███   ░███   ░███  ████  ████████   ████████    ██████  ████████   █████ |
    // | ░███   ░███   ░███ ░░███ ░░███░░███ ░░███░░███  ███░░███░░███░░███ ███░░  |
    // | ░░███  █████  ███   ░███  ░███ ░███  ░███ ░███ ░███████  ░███ ░░░ ░░█████ |
    // |  ░░░█████░█████░    ░███  ░███ ░███  ░███ ░███ ░███░░░   ░███      ░░░░███|
    // |    ░░███ ░░███      █████ ████ █████ ████ █████░░██████  █████     ██████ |
    // |     ░░░   ░░░      ░░░░░ ░░░░ ░░░░░ ░░░░ ░░░░░  ░░░░░░  ░░░░░     ░░░░░░  |
    // '---------------------------------------------------------------------------'

    /**
     * @dev Sets a new winner manager
     * @param newManager The address of the new winner manager
     * @notice Only callable by the contract owner
     */
    function setWinnerManager(address newManager) external onlyOwner {
        address oldManager = _winnerManager;
        _winnerManager = newManager;
        emit WinnerManagerUpdated(oldManager, newManager);
    }

    /**
     * @dev Returns the current winner manager address
     * @return The address of the current winner manager
     */
    function winnerManager() external view returns (address) {
        return _winnerManager;
    }

    /**
     * @dev Submits a winner for a specific round and assigns their reward
     * @param roundNumber The round number for which to submit the winner
     * @param winner The address of the winning peer
     * @param reward The reward value for the winner
     * @notice Only callable by the winner manager
     */
    function submitWinner(uint256 roundNumber, address winner, uint256 reward) external onlyWinnerManager {
        // Check if round number is valid (must be less than or equal to current round)
        if (roundNumber > _currentRound) revert InvalidRoundNumber();

        // Check if winner was already submitted for this round
        if (_roundWinners[roundNumber] != address(0)) revert WinnerAlreadySubmitted();

        // Record the winner
        _roundWinners[roundNumber] = winner;

        // Update accrued rewards
        _accruedRewards[winner] += reward;

        emit WinnerSubmitted(roundNumber, winner, reward);
        emit RewardsAccrued(winner, _accruedRewards[winner]);
    }

    /**
     * @dev Gets the winner for a specific round
     * @param roundNumber The round number to query
     * @return The address of the winner for that round (address(0) if no winner set)
     */
    function getRoundWinner(uint256 roundNumber) external view returns (address) {
        return _roundWinners[roundNumber];
    }

    /**
     * @dev Gets the total accrued rewards for an account
     * @param account The address to query
     * @return The total rewards accrued by the account
     */
    function getAccruedRewards(address account) external view returns (uint256) {
        return _accruedRewards[account];
    }
}
