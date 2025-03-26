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
    mapping(address => string) _eoaToPeerId;
    // Maps peer IDs to their corresponding EOA addresses
    mapping(string => address) _peerIdToEoa;

    // Winner management state
    // Address authorized to submit winners
    address private _judge;
    // Maps round number to winner addresses
    mapping(uint256 => address[]) private _roundWinners;
    // Maps address to total number of wins
    mapping(address => uint256) private _totalWins;
    // Array of top winners (sorted by wins)
    address[] private _topWinners;
    // Maximum number of top winners to track
    uint256 private constant MAX_TOP_WINNERS = 100;

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
    event PeerRegistered(address indexed eoa, string peerId);
    event BootnodeManagerUpdated(address indexed previousManager, address indexed newManager);
    event BootnodesAdded(address indexed manager, uint256 count);
    event BootnodeRemoved(address indexed manager, uint256 index);
    event AllBootnodesCleared(address indexed manager);
    event JudgeUpdated(address indexed previousJudge, address indexed newJudge);
    event WinnerSubmitted(uint256 indexed roundNumber, address[] winners);

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
    error NotJudge();
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

    // Judge modifier
    modifier onlyJudge() {
        if (msg.sender != _judge) revert NotJudge();
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
        setJudge(msg.sender);

        emit BootnodeManagerUpdated(address(0), msg.sender);
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
    function registerPeer(string calldata peerId) external {
        address eoa = msg.sender;

        // Clear any existing peer ID mapping for this EOA
        string memory oldPeerId = _eoaToPeerId[eoa];
        if (bytes(oldPeerId).length > 0) {
            delete _peerIdToEoa[oldPeerId];
        }

        // Set new mappings
        _eoaToPeerId[eoa] = peerId;
        _peerIdToEoa[peerId] = eoa;

        emit PeerRegistered(eoa, peerId);
    }

    /**
     * @dev Retrieves the peer ID associated with an EOA address
     * @param eoa The EOA address to look up
     * @return The peer ID associated with the EOA address
     */
    function getPeerId(address eoa) external view returns (string memory) {
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
     * @notice Only callable by the contract owner
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
     * @dev Sets a new judge
     * @param newJudge The address of the new judge
     * @notice Only callable by the contract owner
     */
    function setJudge(address newJudge) public onlyOwner {
        address oldJudge = _judge;
        _judge = newJudge;
        emit JudgeUpdated(oldJudge, newJudge);
    }

    /**
     * @dev Returns the current judge
     * @return The address of the current judge
     */
    function judge() external view returns (address) {
        return _judge;
    }

    /**
     * @dev Submits a winner for a specific round
     * @param roundNumber The round number for which to submit the winner
     * @param winners The address of the winning peer
     * @notice Only callable by the judge
     */
    function submitWinner(uint256 roundNumber, address[] calldata winners) external onlyJudge {
        // Check if round number is valid (must be less than or equal to current round)
        if (roundNumber > _currentRound) revert InvalidRoundNumber();

        // Record the winners
        _roundWinners[roundNumber] = winners;

        // Update total wins and maintain top winners list
        for (uint256 i = 0; i < winners.length; i++) {
            address winner = winners[i];
            _totalWins[winner]++;
            _updateTopWinners(winner);
        }

        emit WinnerSubmitted(roundNumber, winners);
    }

    /**
     * @dev Updates the top winners list when a winner's score changes
     * @param winner The address whose score has changed
     */
    function _updateTopWinners(address winner) internal {
        uint256 winnerWins = _totalWins[winner];

        // Find if winner is already in the list
        uint256 currentIndex = type(uint256).max;
        for (uint256 i = 0; i < _topWinners.length; i++) {
            if (_topWinners[i] == winner) {
                currentIndex = i;
                break;
            }
        }

        if (currentIndex == type(uint256).max) {
            // Winner is not in the list
            if (_topWinners.length < MAX_TOP_WINNERS) {
                // List is not full, add to end
                _topWinners.push(winner);
                currentIndex = _topWinners.length - 1;
            } else {
                // List is full, check if winner should be added
                if (_totalWins[_topWinners[_topWinners.length - 1]] < winnerWins) {
                    // Replace last place
                    _topWinners[_topWinners.length - 1] = winner;
                    currentIndex = _topWinners.length - 1;
                } else {
                    // Winner doesn't qualify for top list
                    return;
                }
            }
        }

        // Move winner up in the list if needed
        while (currentIndex > 0 && _totalWins[_topWinners[currentIndex - 1]] < winnerWins) {
            // Swap with previous position
            address temp = _topWinners[currentIndex - 1];
            _topWinners[currentIndex - 1] = _topWinners[currentIndex];
            _topWinners[currentIndex] = temp;
            currentIndex--;
        }
    }

    /**
     * @dev Gets the winners for a specific round
     * @param roundNumber The round number to query
     * @return Array of winner addresses for that round (empty array if no winners set)
     */
    function getRoundWinners(uint256 roundNumber) external view returns (address[] memory) {
        return _roundWinners[roundNumber];
    }

    /**
     * @dev Gets the total number of wins for an address
     * @param account The address to query
     * @return The total number of wins for the address
     */
    function getTotalWins(address account) external view returns (uint256) {
        return _totalWins[account];
    }

    /**
     * @dev Gets the total number of wins for a peer ID
     * @param peerId The peer ID to query
     * @return The total number of wins for the peer ID
     */
    function getTotalWinsByPeerId(string calldata peerId) external view returns (uint256) {
        address eoa = _peerIdToEoa[peerId];
        return eoa == address(0) ? 0 : _totalWins[eoa];
    }

    /**
     * @dev Gets a slice of the leaderboard
     * @param start The starting index (inclusive)
     * @param end The ending index (exclusive)
     * @return Array of addresses sorted by number of wins (descending)
     */
    function leaderboard(uint256 start, uint256 end) external view returns (address[] memory) {
        // Ensure start is not greater than end
        require(start <= end, "Start index must be less than or equal to end index");

        // Ensure end is not greater than the length of the list
        if (end > _topWinners.length) {
            end = _topWinners.length;
        }

        // Ensure start is not greater than the length of the list
        if (start > _topWinners.length) {
            start = _topWinners.length;
        }

        // Create result array with the correct size
        address[] memory result = new address[](end - start);
        for (uint256 i = start; i < end; i++) {
            result[i - start] = _topWinners[i];
        }
        return result;
    }
}
