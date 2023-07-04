//SPDX-License-Identifier: MIT

// 1.- Pragma
pragma solidity ^0.8.18;

// 2.- Import Statements
import {console, Script} from "forge-std/Script.sol";
import {VRFCoordinatorV2Mock} from "@chainlink/contracts/src/v0.8/mocks/VRFCoordinatorV2Mock.sol";
import {LinkToken} from "../test/mocks/LinkToken.sol";
import {Vm} from "forge-std/Vm.sol";

// 3.- Error - Codes
// 4.- Interfaces
// 5.- Libraries
// 6.- Contract
contract HelperConfig is Script {
    // 1.- Type Declarations
    struct NetworkConfig {
        uint256 entranceFee;
        uint256 interval;
        address vrfCoordinatorV2;
        bytes32 gasLane;
        uint64 subscriptionId;
        uint32 callbackGasLimit;
        address linkToken;
        uint256 deployerKey;
    }

    // 2.- State Variables
    NetworkConfig public activeNetworkConfig;
    uint96 constant BASE_FEE = 0.25 ether;
    uint96 constant GAS_PRICE_LINK = 1e9;

    //uint256 public DEFAULT_ANVIL_PRIVATE_KEY = 0xac0974bec39a17e36ba4a6b4d238ff944bacb478cbed5efcae784d7bf4f2ff80;

    // 2.5.- Contract Variables
    // 3.- Events
    // 4.- Modifiers
    // 5.- Functions
    //constructor
    constructor() {
        if (block.chainid == 11155111) {
            activeNetworkConfig = getSepoliaEthConfig();
        } else if (block.chainid == 1) {
            activeNetworkConfig = getMainnetEthConfig();
        } else {
            activeNetworkConfig = getOrCreateAnvilEthConfig();
        }
    }

    //receive
    //fallback
    //external
    // Checks
    // Effects (Our own contract)
    // Interactions
    //public
    function getSepoliaEthConfig() public view returns (NetworkConfig memory) {
        NetworkConfig memory sepoliaConfig = NetworkConfig({
            entranceFee: 0.1 ether,
            interval: 30,
            vrfCoordinatorV2: 0x8103B0A8A00be2DDC778e6e7eaa21791Cd364625,
            gasLane: 0x474e34a077df58807dbe9c96d3c009b23b3c6d0cce433e59bbf5b34f823bc56c,
            subscriptionId: 1610,
            callbackGasLimit: 500000,
            linkToken: 0x779877A7B0D9E8603169DdbD7836e478b4624789,
            deployerKey: vm.envUint("PRIVATE_KEY")
        });
        return sepoliaConfig;
    }

    function getMainnetEthConfig() public view returns (NetworkConfig memory) {
        NetworkConfig memory mainnetConfig = NetworkConfig({
            entranceFee: 0.1 ether,
            interval: 30,
            vrfCoordinatorV2: 0x271682DEB8C4E0901D1a1550aD2e64D568E69909,
            gasLane: 0x8af398995b04c28e9951adb9721ef74c74f93e6a478f39e7e0777be13527e7ef,
            subscriptionId: 0,
            callbackGasLimit: 500000,
            linkToken: 0x514910771AF9Ca656af840dff83E8264EcF986CA,
            deployerKey: vm.envUint("PRIVATE_KEY")
        });
        return mainnetConfig;
    }

    function getOrCreateAnvilEthConfig() public returns (NetworkConfig memory) {
        if (activeNetworkConfig.vrfCoordinatorV2 != address(0)) {
            return activeNetworkConfig;
        }
        // 1.- Deploy Mocks
        vm.startBroadcast();
        VRFCoordinatorV2Mock vrfCoordinatorV2Mock = new VRFCoordinatorV2Mock(
            BASE_FEE,
            GAS_PRICE_LINK
        );
        LinkToken linkToken = new LinkToken();
        vm.stopBroadcast();

        NetworkConfig memory anvilConfig = NetworkConfig({
            entranceFee: 0.1 ether,
            interval: 30,
            vrfCoordinatorV2: address(vrfCoordinatorV2Mock),
            gasLane: 0x8af398995b04c28e9951adb9721ef74c74f93e6a478f39e7e0777be13527e7ef,
            subscriptionId: 0, // Our script will add this
            callbackGasLimit: 500000,
            linkToken: address(linkToken),
            deployerKey: vm.envUint("ANVIL_PRIVATE_KEY")
        });
        return anvilConfig;
    }
    //internal
    //private
    //view / pure
}
