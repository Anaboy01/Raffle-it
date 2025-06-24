// SPDX-License-Identifier: MIT
pragma solidity ^0.8.27;

import "./RealToken.sol";

contract RaffleSystem {
    uint256 public entryFee;
    RealToken public nftContract;
    address[] public participants;
    bool public raffleOpen;
    uint256 public raffleCount;
    address public owner;

    uint256 public totalRefundable; // 👈 new variable to track total refund balance

    struct RaffleResult {
        address winner;
        uint256 tokenId;
        string tokenURI;
    }

    RaffleResult[] public raffleResults; 

    event RaffleEntered(address indexed participant);
    event WinnerSelected(address indexed winner);
    event RefundIssued(address indexed participant, uint256 amount);
    event BalanceWithdrawn(address indexed owner, uint256 amount);

    mapping(address => uint256) public refunds;

    constructor(uint256 _entryFee) {
        entryFee = _entryFee;
        nftContract = new RealToken();
        raffleOpen = true;
        raffleCount = 0;
        owner = msg.sender;
    }

    modifier onlyOwner() {
        require(msg.sender == owner, "Only owner can call this function");
        _;
    }

    modifier raffleIsOpen() {
        require(raffleOpen, "Raffle is closed");
        _;
    }

    function enterRaffle() external payable raffleIsOpen {
        require(msg.value == entryFee, "Incorrect entry fee");
        participants.push(msg.sender);
        emit RaffleEntered(msg.sender);

        if (participants.length == 5) {
            _closeRaffleAndSelectWinner();
        }
    }

    function _closeRaffleAndSelectWinner() internal {
        require(participants.length > 0, "No participants in raffle");

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
            address participant = participants[i];
            if (participant != winner) {
                refunds[participant] += entryFee;
                totalRefundable += entryFee;       
                emit RefundIssued(participant, entryFee);
            }
        }

        delete participants;       
        raffleOpen = true;         
    }

    function closeRaffleAndSelectWinner() external onlyOwner {
        require(raffleOpen, "Raffle already closed");
        _closeRaffleAndSelectWinner();
    }

    function withdrawRefund() external {
        uint256 refundAmount = refunds[msg.sender];
        require(refundAmount > 0, "No refund available");

        refunds[msg.sender] = 0;
        totalRefundable -= refundAmount; 
        payable(msg.sender).transfer(refundAmount);

        emit RefundIssued(msg.sender, refundAmount);
    }

    function withdrawContractProfit() external onlyOwner {
        require(!raffleOpen || participants.length == 0, "Raffle must be idle");

        uint256 contractBalance = address(this).balance;
        uint256 profit = contractBalance - totalRefundable;
        require(profit > 0, "No profit to withdraw");

        payable(owner).transfer(profit);
        emit BalanceWithdrawn(owner, profit);
    }

    function getParticipants() external view returns (address[] memory) {
        return participants;
    }

    function getRaffleResult(uint256 raffleIndex) external view returns (address, uint256, string memory) {
        require(raffleIndex < raffleResults.length, "Raffle does not exist");
        RaffleResult storage result = raffleResults[raffleIndex];
        return (result.winner, result.tokenId, result.tokenURI);
    }
}
