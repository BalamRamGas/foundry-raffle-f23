//SPDX-License-Identifier: MIT

// 1.- Pragma
pragma solidity ^0.8.18;

// 2.- Import Statements
import {console, Test} from "forge-std/Test.sol";
import {Raffle} from "../../src/Raffle.sol";
import {DeployRaffle} from "../../script/DeployRaffle.s.sol";
import {SubscriptionIdRaffle, FundSubscription, AddConsumer} from "../../script/Interactions.s.sol";
import {VRFCoordinatorV2Mock} from "@chainlink/contracts/src/v0.8/mocks/VRFCoordinatorV2Mock.sol";
import {HelperConfig} from "../../script/HelperConfig.s.sol";

// 6.- Contract
contract InteractionsTest is Test {
    // 1.- Type Declarations
    Raffle raffle;
    HelperConfig helperConfig;

    // 2.- State Variables
    address public vrfCoordinatorV2;
    uint256 public deployerKey;
    uint64 public subscriptionId;
    address public linkToken;

    // 2.5.- Contract Variables
    // 3.- Events
    // 4.- Modifiers
    // 5.- Functions
    function setUp() external {
        DeployRaffle deployRaffle = new DeployRaffle();
        (raffle, helperConfig) = deployRaffle.run();
        (
            ,
            ,
            vrfCoordinatorV2,
            ,
            subscriptionId,
            ,
            linkToken,
            deployerKey
        ) = helperConfig.activeNetworkConfig();
    }

    function testCreateSubscription() public {
        SubscriptionIdRaffle createSubscription = new SubscriptionIdRaffle();
        subscriptionId = createSubscription.createSubscription(
            vrfCoordinatorV2,
            deployerKey
        );
        assert(subscriptionId != 0);
    }

    function testFundSubscription() public {
        SubscriptionIdRaffle createSubscription = new SubscriptionIdRaffle();
        subscriptionId = createSubscription.createSubscription(
            vrfCoordinatorV2,
            deployerKey
        );
        FundSubscription fundSubscription = new FundSubscription();
        fundSubscription.fundSubscription(
            vrfCoordinatorV2,
            subscriptionId,
            linkToken,
            deployerKey
        );
        (uint256 subscriptionBalance, , , ) = VRFCoordinatorV2Mock(
            vrfCoordinatorV2
        ).getSubscription(subscriptionId);
        assert(subscriptionBalance != 0);
    }

    function testAddConsumer() public {
        SubscriptionIdRaffle createSubscription = new SubscriptionIdRaffle();
        subscriptionId = createSubscription.createSubscription(
            vrfCoordinatorV2,
            deployerKey
        );
        FundSubscription fundSubscription = new FundSubscription();
        fundSubscription.fundSubscription(
            vrfCoordinatorV2,
            subscriptionId,
            linkToken,
            deployerKey
        );
        AddConsumer addConsumer = new AddConsumer();
        addConsumer.addConsumerToSubscription(
            address(raffle),
            vrfCoordinatorV2,
            subscriptionId,
            deployerKey
        );

        bool isAdded = VRFCoordinatorV2Mock(vrfCoordinatorV2).consumerIsAdded(
            subscriptionId,
            address(raffle)
        );

        assert(isAdded == true);
    }
}
