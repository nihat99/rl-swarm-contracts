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
    // Address authorized to update stages and rounds
    address private _stageUpdater;
    // Maps EOA addresses to their corresponding peer IDs
    mapping(address => string) _eoaToPeerId;
    // Maps peer IDs to their corresponding EOA addresses
    mapping(string => address) _peerIdToEoa;

    // Winner management state
    // Maps round number to winner peer IDs
    mapping(uint256 => string[]) private _roundWinners;
    // Maps peer ID to total number of wins
    mapping(string => uint256) private _totalWins;
    // Array of top winners (sorted by wins)
    string[] private _topWinners;
    // Maximum number of top winners to track
    uint256 private constant MAX_TOP_WINNERS = 100;
    // Maps round number to mapping of voter address to their voted peer IDs
    mapping(uint256 => mapping(address => string[])) private _roundVotes;
    // Maps round number to mapping of peer ID to number of votes received
    mapping(uint256 => mapping(string => uint256)) private _roundVoteCounts;
    // Maps voter address to number of times they have voted
    mapping(address => uint256) private _voterVoteCounts;
    // Array of top voters (sorted by number of votes)
    address[] private _topVoters;

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
    event WinnerSubmitted(address indexed voter, uint256 indexed roundNumber, string[] winners);
    event StageUpdaterUpdated(address indexed previousUpdater, address indexed newUpdater);

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

    error StageOutOfBounds();
    error OnlyBootnodeManager();
    error InvalidBootnodeIndex();
    error InvalidRoundNumber();
    error WinnerAlreadyVoted();
    error OnlyStageUpdater();
    error PeerIdAlreadyRegistered();
    error InvalidPeerId();

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

    // Stage updater modifier
    modifier onlyStageUpdater() {
        if (msg.sender != _stageUpdater) revert OnlyStageUpdater();
        _;
    }

    // Bootnode manager modifier
    modifier onlyBootnodeManager() {
        if (msg.sender != _bootnodeManager) revert OnlyBootnodeManager();
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
        setStageUpdater(msg.sender);
        setBootnodeManager(msg.sender);

        emit BootnodeManagerUpdated(address(0), msg.sender);
    }

    /**
     * @dev Sets a new stage updater
     * @param newUpdater The address of the new stage updater
     * @notice Only callable by the contract owner
     */
    function setStageUpdater(address newUpdater) public onlyOwner {
        address oldUpdater = _stageUpdater;
        _stageUpdater = newUpdater;
        emit StageUpdaterUpdated(oldUpdater, newUpdater);
    }

    /**
     * @dev Returns the current stage updater
     * @return The address of the current stage updater
     */
    function stageUpdater() external view returns (address) {
        return _stageUpdater;
    }

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
     * @dev Updates the current stage and round
     * @return The current round and stage after any updates
     * @notice Only callable by the stage updater
     */
    function updateStageAndRound() external onlyStageUpdater returns (uint256, uint256) {
        if (_currentStage + 1 >= _stageCount) {
            // If we're at the last stage, advance to the next round
            _currentRound++;
            _currentStage = 0;
            emit RoundAdvanced(_currentRound);
        } else {
            // Otherwise, advance to the next stage
            _currentStage = _currentStage + 1;
        }

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

        // Check if the peer ID is already registered
        if (_peerIdToEoa[peerId] != address(0)) revert PeerIdAlreadyRegistered();

        // Check if the EOA already has a peer ID
        if (bytes(_eoaToPeerId[eoa]).length > 0) revert PeerIdAlreadyRegistered();

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
    function setBootnodeManager(address newManager) public onlyOwner {
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
     * @dev Submits a list of winners for a specific round
     * @param roundNumber The round number for which to submit the winners
     * @param winners The list of peer IDs that should win
     */
    function submitWinners(uint256 roundNumber, string[] memory winners) external {
        // Check if round number is valid (must be less than or equal to current round)
        if (roundNumber > _currentRound) revert InvalidRoundNumber();

        // Check if sender has already voted
        if (_roundVotes[roundNumber][msg.sender].length > 0) revert WinnerAlreadyVoted();

        // Validate all peer IDs exist
        for (uint256 i = 0; i < winners.length; i++) {
            if (_peerIdToEoa[winners[i]] == address(0)) revert InvalidPeerId();
        }

        // Record the vote
        _roundVotes[roundNumber][msg.sender] = winners;

        // Update vote counts
        for (uint256 i = 0; i < winners.length; i++) {
            _roundVoteCounts[roundNumber][winners[i]]++;
        }

        // Update how many times each voter has voted
        _voterVoteCounts[msg.sender]++;
        _updateTopVoters(msg.sender);

        // Update total wins and top winners
        for (uint256 i = 0; i < winners.length; i++) {
            _totalWins[winners[i]]++;
            _updateTopWinners(winners[i]);
        }

        emit WinnerSubmitted(msg.sender, roundNumber, winners);
    }

    /**
     * @dev Updates the top voters list when a voter's score changes
     * @param voter The address whose score has changed
     */
    function _updateTopVoters(address voter) internal {
        uint256 voterVotes = _voterVoteCounts[voter];

        // Find if voter is already in the list
        uint256 currentIndex = type(uint256).max;
        for (uint256 i = 0; i < _topVoters.length; i++) {
            if (_topVoters[i] == voter) {
                currentIndex = i;
                break;
            }
        }

        if (currentIndex == type(uint256).max) {
            // Voter is not in the list
            if (_topVoters.length < MAX_TOP_WINNERS) {
                // List is not full, add to end
                _topVoters.push(voter);
                currentIndex = _topVoters.length - 1;
            } else {
                // List is full, check if voter should be added
                if (_voterVoteCounts[_topVoters[_topVoters.length - 1]] < voterVotes) {
                    // Replace last place
                    _topVoters[_topVoters.length - 1] = voter;
                    currentIndex = _topVoters.length - 1;
                } else {
                    // Voter doesn't qualify for top list
                    return;
                }
            }
        }

        // Move voter up in the list if needed
        while (currentIndex > 0 && _voterVoteCounts[_topVoters[currentIndex - 1]] < voterVotes) {
            // Swap with previous position
            address temp = _topVoters[currentIndex - 1];
            _topVoters[currentIndex - 1] = _topVoters[currentIndex];
            _topVoters[currentIndex] = temp;
            currentIndex--;
        }
    }

    /**
     * @dev Updates the top winners list when a winner's score changes
     * @param winner The peer ID whose score has changed
     */
    function _updateTopWinners(string memory winner) internal {
        uint256 winnerWins = _totalWins[winner];

        // Find if winner is already in the list
        uint256 currentIndex = type(uint256).max;
        for (uint256 i = 0; i < _topWinners.length; i++) {
            if (keccak256(bytes(_topWinners[i])) == keccak256(bytes(winner))) {
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
            string memory temp = _topWinners[currentIndex - 1];
            _topWinners[currentIndex - 1] = _topWinners[currentIndex];
            _topWinners[currentIndex] = temp;
            currentIndex--;
        }
    }

    /**
     * @dev Gets the number of times a voter has voted
     * @param voter The address of the voter
     * @return The number of times the voter has voted
     */
    function getVoterVoteCount(address voter) external view returns (uint256) {
        return _voterVoteCounts[voter];
    }

    /**
     * @dev Gets a slice of the voter leaderboard
     * @param start The starting index (inclusive)
     * @param end The ending index (exclusive)
     * @return Array of addresses sorted by number of votes (descending)
     */
    function voterLeaderboard(uint256 start, uint256 end) external view returns (address[] memory) {
        // Ensure start is not greater than end
        require(start <= end, "Start index must be less than or equal to end index");

        // Ensure end is not greater than the length of the list
        if (end > _topVoters.length) {
            end = _topVoters.length;
        }

        // Ensure start is not greater than the length of the list
        if (start > _topVoters.length) {
            start = _topVoters.length;
        }

        // Create result array with the correct size
        address[] memory result = new address[](end - start);
        for (uint256 i = start; i < end; i++) {
            result[i - start] = _topVoters[i];
        }
        return result;
    }

    /**
     * @dev Gets the winners for a specific round
     * @param roundNumber The round number to query
     * @return Array of winner peer IDs for that round (empty array if no winners set)
     */
    function getRoundWinners(uint256 roundNumber) external view returns (string[] memory) {
        return _roundWinners[roundNumber];
    }

    /**
     * @dev Gets the total number of wins for a peer ID
     * @param peerId The peer ID to query
     * @return The total number of wins for the peer ID
     */
    function getTotalWins(string calldata peerId) external view returns (uint256) {
        return _totalWins[peerId];
    }

    /**
     * @dev Gets the votes for a specific round from a specific voter
     * @param roundNumber The round number to query
     * @param voter The address of the voter
     * @return Array of peer IDs that the voter voted for
     */
    function getVoterVotes(uint256 roundNumber, address voter) external view returns (string[] memory) {
        return _roundVotes[roundNumber][voter];
    }

    /**
     * @dev Gets the vote count for a specific peer ID in a round
     * @param roundNumber The round number to query
     * @param peerId The peer ID to query
     * @return The number of votes received by the peer ID in that round
     */
    function getPeerVoteCount(uint256 roundNumber, string calldata peerId) external view returns (uint256) {
        return _roundVoteCounts[roundNumber][peerId];
    }

    /**
     * @dev Gets a slice of the leaderboard
     * @param start The starting index (inclusive)
     * @param end The ending index (exclusive)
     * @return Array of peer IDs sorted by number of wins (descending)
     */
    function winnerLeaderboard(uint256 start, uint256 end) external view returns (string[] memory) {
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
        string[] memory result = new string[](end - start);
        for (uint256 i = start; i < end; i++) {
            result[i - start] = _topWinners[i];
        }
        return result;
    }
}
