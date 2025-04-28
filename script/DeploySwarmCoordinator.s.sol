// SPDX-License-Identifier: MIT
pragma solidity ^0.8;

import {Script, console2} from "forge-std/Script.sol";
import {SwarmCoordinator} from "../src/SwarmCoordinator.sol";

contract DeploySwarmCoordinator is Script {
    SwarmCoordinator coordinator;

    uint256 deployerPrivateKey;

    function setUp() public {
        deployerPrivateKey = vm.envUint("ETH_PRIVATE_KEY");
    }

    function run() public {
        vm.startBroadcast(deployerPrivateKey);
        coordinator = new SwarmCoordinator();
        vm.stopBroadcast();

        console2.log("SwarmCoordinator deployed at:", address(coordinator));
    }
}
