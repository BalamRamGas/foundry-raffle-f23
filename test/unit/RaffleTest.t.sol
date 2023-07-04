//SPDX-License-Identifier: MIT

// 1.- Pragma
pragma solidity ^0.8.18;

// 2.- Import Statements
import {console, Test} from "forge-std/Test.sol";
import {Raffle} from "../../src/Raffle.sol";
import {DeployRaffle} from "../../script/DeployRaffle.s.sol";
import {HelperConfig} from "../../script/HelperConfig.s.sol";
import {Vm} from "forge-std/Vm.sol";
import {VRFCoordinatorV2Mock} from "@chainlink/contracts/src/v0.8/mocks/VRFCoordinatorV2Mock.sol";

// 3.- Error - Codes
// 4.- Interfaces
// 5.- Libraries
// 6.- Contract
contract RaffleTest is Test {
    // 1.- Type Declarations
    Raffle raffle;
    HelperConfig helperConfig;

    // 2.- State Variables
    address public PLAYER = makeAddr("player");
    uint256 public constant STARTING_BALANCE = 10 ether;

    uint256 public entranceFee;
    uint256 public interval;
    address public vrfCoordinatorV2;
    //bytes32 public gasLane;
    uint64 public subscriptionId;
    //uint32 public callbackGasLimit;
    address public linkToken;
    uint256 public deployerKey;

    // 2.5.- Contract Variables
    // 3.- Events
    event RaffleEnter(address indexed player);
    event PickedWinner(address indexed winner);
    event RequestedRaffleWinner(uint256 indexed requestId);

    // 4.- Modifiers
    modifier raffleEnterAndTimePassed() {
        vm.prank(PLAYER);
        raffle.enterRaffle{value: entranceFee}();
        vm.warp(block.timestamp + interval + 1);
        vm.roll(block.number + 1);
        _;
    }

    // 5.- Functions
    function setUp() external {
        DeployRaffle deployRaffle = new DeployRaffle();
        (raffle, helperConfig) = deployRaffle.run();
        (
            entranceFee,
            interval,
            vrfCoordinatorV2,
            ,
            /*gasLane*/ subscriptionId,
            ,
            /*callbackGasLimit*/ linkToken,
            deployerKey
        ) = helperConfig.activeNetworkConfig();

        vm.deal(PLAYER, STARTING_BALANCE);
    }

    function testRaffleInitializedInOpenState() public view {
        assert(raffle.getRaffleState() == Raffle.RaffleState.OPEN);
    }

    //////////////////////////////////////////////
    //////      enterRaffle                 //////
    //////////////////////////////////////////////

    function testRaffleRevertsWhenYouDontSentEnoughEth() public {
        // Arrange
        vm.prank(PLAYER);

        // Act / Assert
        vm.expectRevert(Raffle.Raffle__NotEnoughEthSent.selector);
        raffle.enterRaffle();
    }

    function testRaffleRecordsPlayerWhenTheyEnter() public {
        // Arrange
        vm.prank(PLAYER);

        // Act
        raffle.enterRaffle{value: entranceFee}();

        // Assert
        assertEq(PLAYER, raffle.getPlayer(0));
    }

    function testEmitEventOnEntrance() public {
        // Arrange
        vm.prank(PLAYER);
        vm.expectEmit(true, false, false, false, address(raffle));
        emit RaffleEnter(PLAYER);

        // Act / Assert
        raffle.enterRaffle{value: entranceFee}();
    }

    function testRaffleRevertsWhenCalculating()
        public
        raffleEnterAndTimePassed
    {
        // Arrange
        raffle.performUpkeep("");
        vm.expectRevert(Raffle.Raffle__NotOpen.selector);
        vm.prank(PLAYER);

        // Act / Assert
        raffle.enterRaffle{value: entranceFee}();
    }

    //////////////////////////////////////////////
    //////      checkUpkeep                 //////
    //////////////////////////////////////////////

    function testCheckUpkeepReturnsFalseIfNotEnoughTimeHasPassed() public {
        // Arrange
        vm.prank(PLAYER);
        raffle.enterRaffle{value: entranceFee}();
        vm.warp(block.timestamp + interval - 1);
        vm.roll(block.number + 1);

        // Act
        (bool upkeepNeeded, ) = raffle.checkUpkeep("");

        // Assert
        assert(!upkeepNeeded);
    }

    function testCheckUpkeepReturnsFalseIfNotEnoughBalance() public {
        // Arrange
        vm.warp(block.timestamp + interval + 1);
        vm.roll(block.number + 1);

        // Act
        (bool upkeepNeeded, ) = raffle.checkUpkeep("");

        // Assert
        assert(!upkeepNeeded);
    }

    function testCheckUpkeepReturnsFalseIfRaffleNotOpen()
        public
        raffleEnterAndTimePassed
    {
        // Arrange
        raffle.performUpkeep("");

        // Act
        (bool upkeepNeeded, ) = raffle.checkUpkeep("");

        // Assert
        assert(!upkeepNeeded);
    }

    function testCheckUpkeepReturnsTrueWhenParametersAreGood()
        public
        raffleEnterAndTimePassed
    {
        // Arrange / Act
        (bool upkeepNeeded, ) = raffle.checkUpkeep("");

        // Assert
        assert(upkeepNeeded);
    }

    //////////////////////////////////////////////
    //////      performUpkeep               //////
    //////////////////////////////////////////////

    function testPerformUpkeepCanOnlyRunIfCheckUpkeepIsTrue()
        public
        raffleEnterAndTimePassed
    {
        // Arrange / Act / Assert
        raffle.performUpkeep("");
    }

    function testPerformUpkeepRevertsIfCheckUpkeepNotNeeded() public {
        // Arrange
        uint256 currtenBalance = 0;
        uint256 numPlayers = 0;
        uint256 raffleState = 0;
        vm.expectRevert(
            abi.encodeWithSelector(
                Raffle.Raffle__UpkeepNotNeeded.selector,
                currtenBalance,
                numPlayers,
                raffleState
            )
        );

        // Act / Assert
        raffle.performUpkeep("");
    }

    function testPerformUpkeepUpdatesRaffleStateAndEmitsRequestId()
        public
        raffleEnterAndTimePassed
    {
        // Arrange
        // Act
        vm.recordLogs();
        raffle.performUpkeep(""); // emit the requestId
        Vm.Log[] memory entries = vm.getRecordedLogs();
        bytes32 requestId = entries[1].topics[1];

        Raffle.RaffleState rState = raffle.getRaffleState();

        // Assert
        assert(uint256(requestId) > 0);
        assert(uint256(rState) == 1);
    }

    //////////////////////////////////////////////
    //////      fulfillRandomWords          //////
    //////////////////////////////////////////////

    modifier skipFork() {
        if (block.chainid != 31337) {
            return;
        }
        _;
    }

    function testFulfillRandomWordsCanOnlyBeCalledAfterPerformUpkeep(
        uint256 randomRequestId
    ) public raffleEnterAndTimePassed skipFork {
        // Arrange
        vm.expectRevert("nonexistent request");

        // Act / Assert
        VRFCoordinatorV2Mock(vrfCoordinatorV2).fulfillRandomWords(
            randomRequestId,
            address(raffle)
        );
    }

    function testFulfillRandomWordsGetsTheRaffleStateBackToOpen()
        public
        raffleEnterAndTimePassed
        skipFork
    {
        // Arrange
        uint256 additionalEntrants = 5;
        uint256 startingIndex = 1;
        for (
            uint256 i = startingIndex;
            i < startingIndex + additionalEntrants;
            i++
        ) {
            address player = address(uint160(i)); // address
            hoax(player, STARTING_BALANCE);
            raffle.enterRaffle{value: entranceFee}();
        }

        vm.recordLogs();
        raffle.performUpkeep(""); // emit the requestId
        Vm.Log[] memory entries = vm.getRecordedLogs();
        bytes32 requestId = entries[1].topics[1];

        // Act
        // pretend to be chainlink vrf to get random number & pick a winner
        VRFCoordinatorV2Mock(vrfCoordinatorV2).fulfillRandomWords(
            uint256(requestId),
            address(raffle)
        );

        // Assert
        assert(uint256(raffle.getRaffleState()) == 0);
    }

    function testFulfillRandomWordsGetsARecentWinner()
        public
        raffleEnterAndTimePassed
        skipFork
    {
        // Arrange
        uint256 additionalEntrants = 5;
        uint256 startingIndex = 1;
        for (
            uint256 i = startingIndex;
            i < startingIndex + additionalEntrants;
            i++
        ) {
            address player = address(uint160(i)); // address
            hoax(player, STARTING_BALANCE);
            raffle.enterRaffle{value: entranceFee}();
        }

        vm.recordLogs();
        raffle.performUpkeep(""); // emit the requestId
        Vm.Log[] memory entries = vm.getRecordedLogs();
        bytes32 requestId = entries[1].topics[1];

        // Act
        // pretend to be chainlink vrf to get random number & pick a winner
        VRFCoordinatorV2Mock(vrfCoordinatorV2).fulfillRandomWords(
            uint256(requestId),
            address(raffle)
        );

        // Assert
        assert(raffle.getRecentWinner() != address(0));
    }

    function testFulfillRandomWordsResetsThePlayersArray()
        public
        raffleEnterAndTimePassed
        skipFork
    {
        // Arrange
        uint256 additionalEntrants = 5;
        uint256 startingIndex = 1;
        for (
            uint256 i = startingIndex;
            i < startingIndex + additionalEntrants;
            i++
        ) {
            address player = address(uint160(i)); // address
            hoax(player, STARTING_BALANCE);
            raffle.enterRaffle{value: entranceFee}();
        }

        vm.recordLogs();
        raffle.performUpkeep(""); // emit the requestId
        Vm.Log[] memory entries = vm.getRecordedLogs();
        bytes32 requestId = entries[1].topics[1];

        // Act
        // pretend to be chainlink vrf to get random number & pick a winner
        VRFCoordinatorV2Mock(vrfCoordinatorV2).fulfillRandomWords(
            uint256(requestId),
            address(raffle)
        );

        // Assert
        assert(raffle.getNumberOfPlayers() == 0);
    }

    function testFulfillRandomWordsTimeIntervalHasBeenReset()
        public
        raffleEnterAndTimePassed
        skipFork
    {
        // Arrange
        uint256 additionalEntrants = 5;
        uint256 startingIndex = 1;
        for (
            uint256 i = startingIndex;
            i < startingIndex + additionalEntrants;
            i++
        ) {
            address player = address(uint160(i)); // address
            hoax(player, STARTING_BALANCE);
            raffle.enterRaffle{value: entranceFee}();
        }

        vm.recordLogs();
        raffle.performUpkeep(""); // emit the requestId
        Vm.Log[] memory entries = vm.getRecordedLogs();
        bytes32 requestId = entries[1].topics[1];

        uint256 previousTimeStamp = raffle.getLastTimeStamp();

        // Act
        // pretend to be chainlink vrf to get random number & pick a winner
        VRFCoordinatorV2Mock(vrfCoordinatorV2).fulfillRandomWords(
            uint256(requestId),
            address(raffle)
        );

        // Assert
        assert(previousTimeStamp < raffle.getLastTimeStamp());
    }

    function testFulfillRandomWordsSendsMoneyToTheWinner()
        public
        raffleEnterAndTimePassed
        skipFork
    {
        // Arrange
        uint256 additionalEntrants = 5;
        uint256 startingIndex = 1;
        for (
            uint256 i = startingIndex;
            i < startingIndex + additionalEntrants;
            i++
        ) {
            address player = address(uint160(i)); // address
            hoax(player, STARTING_BALANCE);
            raffle.enterRaffle{value: entranceFee}();
        }

        uint256 prize = entranceFee * (additionalEntrants + 1);

        vm.recordLogs();
        raffle.performUpkeep(""); // emit the requestId
        Vm.Log[] memory entries = vm.getRecordedLogs();
        bytes32 requestId = entries[1].topics[1];

        // Act
        // pretend to be chainlink vrf to get random number & pick a winner
        VRFCoordinatorV2Mock(vrfCoordinatorV2).fulfillRandomWords(
            uint256(requestId),
            address(raffle)
        );

        // Assert
        assert(
            raffle.getRecentWinner().balance ==
                (STARTING_BALANCE + prize - entranceFee)
        );
    }

    //////////////////////////////////////////////
    //////              receive             //////
    //////////////////////////////////////////////

    function testReceive() public {
        // Arrange
        vm.prank(PLAYER);

        // Act
        address(raffle).call{value: entranceFee}("");

        // Assert
        assert(address(raffle).balance == entranceFee);
    }

    //////////////////////////////////////////////
    //////             fallback             //////
    //////////////////////////////////////////////

    function testFallback() public {
        // Arrange
        vm.prank(PLAYER);

        // Act
        address(raffle).call{value: entranceFee}(
            abi.encodeWithSignature("own()")
        );
        uint256 contractBalance = address(raffle).balance;

        // Assert
        assert(contractBalance == entranceFee);
    }
}
