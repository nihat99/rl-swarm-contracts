// SPDX-License-Identifier: MIT
pragma solidity ^0.8;

import {Script, console2} from "forge-std/Script.sol";
import {SwarmCoordinator} from "../src/SwarmCoordinator.sol";

contract DeploySwarmCoordinator is Script {
    SwarmCoordinator coordinator;

    uint256 deployerPrivateKey;

    function setUp() public {
        deployerPrivateKey = vm.envUint("ETH_PRIVATE_KEY");
        console2.log("Deployer private key:", deployerPrivateKey);
    }

    function run() public {
        vm.startBroadcast(deployerPrivateKey);
        coordinator = new SwarmCoordinator();
        vm.stopBroadcast();
    }
}
