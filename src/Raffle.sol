//SPDX-License-Identifier: MIT

// 1.- Pragma
pragma solidity ^0.8.18;

// 2.- Import Statements
import {console} from "forge-std/Script.sol";
import {VRFCoordinatorV2Interface} from "@chainlink/contracts/src/v0.8/interfaces/VRFCoordinatorV2Interface.sol";
import {VRFConsumerBaseV2} from "@chainlink/contracts/src/v0.8/VRFConsumerBaseV2.sol";
import {AutomationBase, AutomationCompatibleInterface} from "@chainlink/contracts/src/v0.8/AutomationCompatible.sol";

// 3.- Error - Codes

// 4.- Interfaces

// 5.- Libraries

// 6.- Contract

/**
 * @title A sample Raffle Contract
 * @author Balam Ramírez Gaspar
 * @notice This contract is for creating an untamperable decentralized smart contract
 * @dev This implements Chainlink VRF V2 and Chainlink Automation.
 */
contract Raffle is VRFConsumerBaseV2, AutomationCompatibleInterface {
    // According to the Layout error-codes were supposed to be outside of the contract....
    error Raffle__NotEnoughEthSent();
    error Raffle__TransferFailed();
    error Raffle__NotOpen();
    error Raffle__UpkeepNotNeeded(
        uint256 currentBalance,
        uint256 numPlayers,
        uint256 raffleState
    );

    // 1.- Type Declarations
    enum RaffleState {
        OPEN,
        CALCULATING
    }

    // 2.- State Variables
    uint16 private constant REQUEST_CONFIRMATIONS = 3;
    uint32 private constant NUM_WORDS = 1;
    uint256 private immutable i_entranceFee;
    uint256 private immutable i_interval;
    VRFCoordinatorV2Interface private immutable i_vrfCoordinator;
    bytes32 private immutable i_gasLane;
    uint64 private immutable i_subscriptionId;
    uint32 private immutable i_callbackGasLimit;
    address payable[] private s_players;

    // 2.5.- Raffle Variables
    RaffleState private s_raffleState;
    uint256 private s_lastTimeStamp;
    address private s_recentWinner;

    // 3.- Events
    event RaffleEnter(address indexed player);
    event PickedWinner(address indexed winner);
    event RequestedRaffleWinner(uint256 indexed requestId);

    // 4.- Modifiers

    // 5.- Functions
    //constructor
    constructor(
        uint256 entranceFee,
        uint256 interval,
        address vrfCoordinatorV2,
        bytes32 gasLane,
        uint64 subscriptionId,
        uint32 callbackGasLimit
    ) VRFConsumerBaseV2(vrfCoordinatorV2) {
        i_entranceFee = entranceFee;
        i_interval = interval;
        s_lastTimeStamp = block.timestamp;
        i_vrfCoordinator = VRFCoordinatorV2Interface(vrfCoordinatorV2);
        i_gasLane = gasLane;
        i_subscriptionId = subscriptionId;
        i_callbackGasLimit = callbackGasLimit;
        s_raffleState = RaffleState.OPEN;
    }

    //receive
    receive() external payable {}

    //fallback
    fallback() external payable {}

    //external
    function enterRaffle() external payable {
        if (msg.value < i_entranceFee) {
            revert Raffle__NotEnoughEthSent();
        }
        if (s_raffleState == RaffleState.CALCULATING) {
            revert Raffle__NotOpen();
        }
        s_players.push(payable(msg.sender));
        // 1.- Makes Migration Easier
        // 2.- Makes Front End "indexing" easier
        emit RaffleEnter(msg.sender);
    }

    /**
     * @dev This is the function that the Chainlink Automation Network nodes call
     * to see if it's time to perform an upkeep, the following should be true for this to return true:
     * 1.- Our time interval should have passed.
     * 2.- The raffle state must be open.
     * 3.- The contract has at least 1 player and have some ETH.
     * 4.- Our subscription is funded with LINK.
     */
    function checkUpkeep(
        bytes memory /*checkData*/
    )
        public
        view
        override
        returns (bool upkeepNeeded, bytes memory /*performData*/)
    {
        bool timePassed = ((block.timestamp - s_lastTimeStamp) > i_interval);
        bool isOpen = (RaffleState.OPEN == s_raffleState);
        bool hasPlayers = (s_players.length > 0);
        bool hasBalance = (address(this).balance > 0);
        upkeepNeeded = (timePassed && isOpen && hasPlayers && hasBalance);
        return (upkeepNeeded, "0x0");
    }

    //Once checkUpkeep returns true, the chainlink nodes will automatically call the performUpkeep() function.
    function performUpkeep(bytes calldata /*performData*/) external override {
        (bool upkeepNeeded, ) = checkUpkeep("");
        if (!upkeepNeeded) {
            revert Raffle__UpkeepNotNeeded(
                address(this).balance,
                s_players.length,
                uint256(s_raffleState)
            );
        }
        s_raffleState = RaffleState.CALCULATING;
        uint256 requestId = i_vrfCoordinator.requestRandomWords(
            i_gasLane,
            i_subscriptionId,
            REQUEST_CONFIRMATIONS,
            i_callbackGasLimit,
            NUM_WORDS
        );
        // This is redundant because there is an event with the same functionality inside the VRFCoordinatorMock
        emit RequestedRaffleWinner(requestId);
    }

    function fulfillRandomWords(
        uint256 /*requestId*/,
        uint256[] memory randomWords
    ) internal override {
        // Checks

        // Effects (Our own contract)
        uint256 indexOfWinner = randomWords[0] % s_players.length;
        address payable winner = s_players[indexOfWinner];
        s_recentWinner = winner;
        s_players = new address payable[](0);
        s_raffleState = RaffleState.OPEN;
        s_lastTimeStamp = block.timestamp;
        emit PickedWinner(winner);

        // Interactions
        (bool success, ) = winner.call{value: address(this).balance}("");
        if (!success) {
            revert Raffle__TransferFailed();
        }
    }

    //public
    //internal
    //private
    //view / pure
    function getEntranceFee() public view returns (uint256) {
        return i_entranceFee;
    }

    function getRequestConfirmations() public pure returns (uint16) {
        return REQUEST_CONFIRMATIONS;
    }

    function getNumberOfWords() public pure returns (uint32) {
        return NUM_WORDS;
    }

    function getInterval() public view returns (uint256) {
        return i_interval;
    }

    function getPlayer(uint256 indexOfPlayer) public view returns (address) {
        return s_players[indexOfPlayer];
    }

    function getRecentWinner() public view returns (address) {
        return s_recentWinner;
    }

    function getRaffleState() public view returns (RaffleState) {
        return s_raffleState;
    }

    function getNumberOfPlayers() public view returns (uint256) {
        return s_players.length;
    }

    function getLastTimeStamp() public view returns (uint256) {
        return s_lastTimeStamp;
    }
}
