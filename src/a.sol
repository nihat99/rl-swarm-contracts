// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

import "@openzeppelin/contracts/access/Ownable.sol";

contract RLTraining is Ownable {
    // Enums & Structs
    enum Stage { GenerateAnswers, CritiquePeers, PeerVoting }

    struct RoundInfo {
        uint256 startTimeBlock;
    }

    struct RoundResult {
        bytes32 winningPeerPublicKeyHash; // Hash of peer's public key
        uint256 rewardAmount;
    }

    // State Variables
    mapping(uint => RoundInfo) private roundInfos;
    uint public currentRound = 0;

    address[] public initialPeers;          // List of initial peers (stored on-chain)
    mapping(bytes32 => address) public peerToEOA; // Maps hashed peerPublicKey to EOA

    address public executorAddress;         // Address allowed to submit round results
    uint[3] public stageDurations;          // Duration of each stage in blocks
    mapping(uint => RoundResult) private roundWinners;

    // Events
    event RoundStarted(uint indexed roundNumber, Stage initialStage);
    event WinnerRecorded(
        uint indexed round,
        bytes32 winningPeerHash,
        uint rewardAmount
    );

    // Constructor
    constructor(
        address[] memory _initialPeers,
        uint[3] memory _stageDurations
    ) Ownable() {
        require(_initialPeers.length > 0, "Initial peers required");
        initialPeers = _initialPeers;
        stageDurations = _stageDurations;
    }

    /* 
     * Core Functions
     */

    // Get current stage and auto-advance rounds if necessary
    function getCurrentStage() public returns (Stage) {
        _updateCurrentRound();
        
        RoundInfo storage info = roundInfos[currentRound];
        uint passedBlocks = block.number - info.startTimeBlock;
        
        if (passedBlocks < stageDurations[0]) return Stage.GenerateAnswers;
        else if (passedBlocks < 
            stageDurations[0] + stageDurations[1]
        ) {
            return Stage.CritiquePeers;
        } else {
            // Check final stage and round completion
            uint totalDuration = 
                stageDurations[0] + stageDurations[1] + stageDurations[2];
            
            if (passedBlocks < info.startTimeBlock + totalDuration) 
                return Stage.PeerVoting;
            else revert("Round completed");
        }
    }

    // Internal function to advance rounds
    function _updateCurrentRound() internal {
        while (true) {
            RoundInfo storage current = roundInfos[currentRound];
            
            uint totalDuration = 
                stageDurations[0] + 
                stageDurations[1] + 
                stageDurations[2];
            
            if(block.number < current.startTimeBlock + totalDuration) break;
            
            // Advance to next round
            currentRound++;
            RoundInfo storage newRound = roundInfos[currentRound];
            newRound.startTimeBlock = block.number;
        }
    }

    /* 
     * Peer Management
     */

    // Link EOA with peerPublicKey via signature verification
    function linkEOAToPeer(
        bytes calldata peerPublicKey,
        address eoa,
        bytes calldata signature
    ) external {
        // Compute message hash for signing
        bytes32 message = keccak256(abi.encodePacked("Link EOA:", eoa));
        
        (bytes32 r, bytes32 s, uint8 v) = _splitSignature(signature);
        address recoveredAddr = ecrecover(message, v, r, s);

        // Verify the recovered address matches the peerPublicKey's Ethereum-derived address
        bytes32 publicKeyHash = keccak256(peerPublicKey); 
        require(
            recoveredAddr == address(uint160(publicKeyHash)),
            "Invalid signature"
        );
        
        // Store mapping (hashed public key to EOA)
        bytes32 pkHash = keccak256(peerPublicKey);
        peerToEOA[pkHash] = eoa;
    }

    /* 
     * Executor Functions
     */

    function setExecutor(address _executor) external onlyOwner {
        executorAddress = _executor;
    }

    // Record round winner (called by executor)
    function recordRoundWinner(
        uint roundNumber,
        bytes calldata winningPeerPublicKey,
        uint rewardAmount
    ) external {
        require(msg.sender == executorAddress, "Unauthorized");
        
        RoundResult storage result = roundWinners[roundNumber];
        bytes32 pkHash = keccak256(winningPeerPublicKey);
        result.winningPeerPublicKeyHash = pkHash;
        result.rewardAmount = rewardAmount;

        emit WinnerRecorded(roundNumber, pkHash, rewardAmount);
    }

    /* 
     * Helper Functions
     */

    // Split signature into components (r,s,v)
    function _splitSignature(bytes memory sig) private pure returns (
        bytes32 r,
        bytes32 s,
        uint8 v
    ) {
        require(sig.length == 65, "Invalid signature length");
        
        assembly {
            r := mload(add(sig, 32))
            s := mload(add(sig, 64))
            v := byte(0, mload(add(sig, 96)))
        }
        
        if (v < 27) v += 27;
    }

    // Get round winner details
    function getRoundWinner(uint roundNumber)
        external view returns (
            bytes32 winningPeerHash,
            uint rewardAmount
        ) {
        RoundResult storage result = roundWinners[roundNumber];
        return (result.winningPeerPublicKeyHash, result.rewardAmount);
    }
}