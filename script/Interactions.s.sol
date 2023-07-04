//SPDX-License-Identifier: MIT

// 1.- Pragma
pragma solidity ^0.8.18;

// 2.- Import Statements
import {console, Script} from "forge-std/Script.sol";
import {VRFCoordinatorV2Mock} from "@chainlink/contracts/src/v0.8/mocks/VRFCoordinatorV2Mock.sol";
import {HelperConfig} from "./HelperConfig.s.sol";
import {LinkToken} from "../test/mocks/LinkToken.sol";
import {DevOpsTools} from "../lib/foundry-devops/src/DevOpsTools.sol";

//import {Raffle} from "../../src/Raffle.sol";
//import {DeployRaffle} from "../../script/DeployRaffle.s.sol";

contract SubscriptionIdRaffle is Script {
    function createSubscriptionUsingConfig() public returns (uint64) {
        HelperConfig helperConfig = new HelperConfig();
        (
            ,
            ,
            address vrfCoordinatorV2,
            ,
            ,
            ,
            ,
            uint256 deployerKey
        ) = helperConfig.activeNetworkConfig();
        return createSubscription(vrfCoordinatorV2, deployerKey);
    }

    function createSubscription(
        address _vrfCoordinatorV2,
        uint256 _deployerKey
    ) public returns (uint64) {
        console.log("Creating Subscription on ChainId: ", block.chainid);
        vm.startBroadcast(_deployerKey);
        uint64 subId = VRFCoordinatorV2Mock(_vrfCoordinatorV2)
            .createSubscription();
        vm.stopBroadcast();
        console.log("Your subId is: ", subId);
        console.log("Please update subscriptionId in HelperConfig.s.sol");
        return subId;
    }

    function run() external returns (uint64) {
        return createSubscriptionUsingConfig();
    }
}

//////////////////////////////////////////////////////////////////////////////////////////////////////////
contract FundSubscription is Script {
    uint96 public constant FUND_AMOUNT = 3 ether;

    function fundSubscriptionUsingConfig() public {
        HelperConfig helperConfig = new HelperConfig();
        (
            ,
            ,
            address vrfCoordinatorV2,
            ,
            uint64 subscriptionId,
            ,
            address linkToken,
            uint256 deployerKey
        ) = helperConfig.activeNetworkConfig();
        fundSubscription(
            vrfCoordinatorV2,
            subscriptionId,
            linkToken,
            deployerKey
        );
    }

    function fundSubscription(
        address _vrfCoordinatorV2,
        uint64 _subscriptionId,
        address _linkToken,
        uint256 _deployerKey
    ) public {
        console.log("Funding subcription: ", _subscriptionId);
        console.log("Using vrfCoordinatorV2: ", _vrfCoordinatorV2);
        console.log("On ChainId: ", block.chainid);
        if (block.chainid == 31337) {
            vm.startBroadcast(_deployerKey);
            VRFCoordinatorV2Mock(_vrfCoordinatorV2).fundSubscription(
                _subscriptionId,
                FUND_AMOUNT
            );
            vm.stopBroadcast();
        } else {
            vm.startBroadcast(_deployerKey);
            LinkToken(_linkToken).transferAndCall(
                _vrfCoordinatorV2,
                FUND_AMOUNT,
                abi.encode(_subscriptionId)
            );
            vm.stopBroadcast();
        }
    }

    function run() external {
        fundSubscriptionUsingConfig();
    }
}

/////////////////////////////////////////////////////////////////////////////////////////////////////////
contract AddConsumer is Script {
    function addConsumerUsingConfig(address raffle) public {
        HelperConfig helperConfig = new HelperConfig();
        (
            ,
            ,
            address vrfCoordinatorV2,
            ,
            uint64 subscriptionId,
            ,
            ,
            uint256 deployerKey
        ) = helperConfig.activeNetworkConfig();
        addConsumerToSubscription(
            raffle,
            vrfCoordinatorV2,
            subscriptionId,
            deployerKey
        );
    }

    function addConsumerToSubscription(
        address raffle,
        address vrfCoordinatorV2,
        uint64 subscriptionId,
        uint256 deployerKey
    ) public {
        console.log("Adding Consumer contract: ", raffle);
        console.log("Using vrfCoordinatorV2:", vrfCoordinatorV2);
        console.log("On ChainId: ", block.chainid);
        vm.startBroadcast(deployerKey);
        VRFCoordinatorV2Mock(vrfCoordinatorV2).addConsumer(
            subscriptionId,
            raffle
        );

        vm.stopBroadcast();
    }

    function run() external {
        address raffle = DevOpsTools.get_most_recent_deployment(
            "Raffle",
            block.chainid
        );
        addConsumerUsingConfig(raffle);
    }
}
