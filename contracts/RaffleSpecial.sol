// SPDX-License-Identifier: MIT
pragma solidity ^0.8.27;

import "./RealToken.sol";

/**
 * @title RaffleSystem
 * @dev A secure, upgradeable raffle system that supports multiple rounds, deadlines, and owner withdrawals.
 */
contract RaffleSystem {
    uint256 public entryFee;
    RealToken public nftContract;
    address public owner;
    uint256 public raffleCount;
    bool public raffleOpen;
    uint256 public raffleEndTime;
    uint256 public maxParticipants = 100;
    uint256 public ownerFeePercent = 10;
    bool public paused = false;

    struct RaffleResult {
        address winner;
        uint256 tokenId;
        string tokenURI;
    }

    RaffleResult[] public raffleResults;
    address[] public participants;

    mapping(address => uint256) public refunds;
    mapping(address => uint256) public refundTimestamps;

    event RaffleEntered(address indexed participant);
    event WinnerSelected(address indexed winner);
    event RefundIssued(address indexed participant, uint256 amount);
    event BalanceWithdrawn(address indexed owner, uint256 amount);
    event RaffleStarted(uint256 deadline);
    event Paused(bool status);

    modifier onlyOwner() {
        require(msg.sender == owner, "Only owner can call this function");
        _;
    }

    modifier raffleIsOpen() {
        require(raffleOpen, "Raffle is closed");
        _;
    }

    modifier notPaused() {
        require(!paused, "Contract is paused");
        _;
    }

    constructor(uint256 _entryFee) {
        entryFee = _entryFee;
        nftContract = new RealToken();
        owner = msg.sender;
        raffleOpen = false;
    }

    function startNewRaffleWithDeadline(uint256 durationInSeconds) external onlyOwner notPaused {
        require(!raffleOpen, "Previous raffle still active");
        delete participants;
        raffleOpen = true;
        raffleEndTime = block.timestamp + durationInSeconds;
        emit RaffleStarted(raffleEndTime);
    }

    function enterRaffle() external payable raffleIsOpen notPaused {
        require(block.timestamp <= raffleEndTime, "Raffle deadline passed");
        require(msg.value == entryFee, "Incorrect entry fee");
        require(participants.length < maxParticipants, "Raffle is full");

        participants.push(msg.sender);
        emit RaffleEntered(msg.sender);
    }

    function closeRaffleAndSelectWinner() external onlyOwner notPaused {
        require(raffleOpen, "Raffle not active");
        require(participants.length > 0, "No participants");

        uint256 winnerIndex = uint256(keccak256(abi.encodePacked(block.timestamp, block.prevrandao))) % participants.length;
        address winner = participants[winnerIndex];
        raffleOpen = false;
        raffleCount++;

        nftContract.mint(winner, raffleCount);

        raffleResults.push(RaffleResult({
            winner: winner,
            tokenId: raffleCount,
            tokenURI: nftContract.tokenURI(raffleCount)
        }));

        emit WinnerSelected(winner);

        for (uint256 i = 0; i < participants.length; i++) {
            if (participants[i] != winner) {
                refunds[participants[i]] = entryFee;
                refundTimestamps[participants[i]] = block.timestamp;
            }
        }
    }

    function withdrawRefund() external notPaused {
        require(refunds[msg.sender] > 0, "No refund available");

        uint256 refundAmount = refunds[msg.sender];
        refunds[msg.sender] = 0;
        payable(msg.sender).transfer(refundAmount);

        emit RefundIssued(msg.sender, refundAmount);
    }

    function sweepUnclaimedRefunds() external onlyOwner notPaused {
        for (uint256 i = 0; i < participants.length; i++) {
            address participant = participants[i];
            if (refunds[participant] > 0 && block.timestamp - refundTimestamps[participant] > 7 days) {
                refunds[participant] = 0;
            }
        }
    }

    function withdrawContractBalance() external onlyOwner notPaused {
        require(!raffleOpen, "Raffle still active");
        uint256 balance = address(this).balance;
        uint256 ownerFee = (balance * ownerFeePercent) / 100;
        payable(owner).transfer(ownerFee);
        emit BalanceWithdrawn(owner, ownerFee);
    }

    function pauseContract(bool status) external onlyOwner {
        paused = status;
        emit Paused(status);
    }

    function getParticipants() external view returns (address[] memory) {
        return participants;
    }

    function getRaffleResult(uint256 raffleIndex) external view returns (address, uint256, string memory) {
        require(raffleIndex < raffleResults.length, "Invalid raffle index");
        RaffleResult storage result = raffleResults[raffleIndex];
        return (result.winner, result.tokenId, result.tokenURI);
    }

    function getAllRaffleResults() external view returns (RaffleResult[] memory) {
        return raffleResults;
    }
}
