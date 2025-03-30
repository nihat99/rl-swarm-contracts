// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8;

import {Script, console2} from "forge-std/Script.sol";
import {Vm} from "forge-std/Vm.sol";

import {SwarmCoordinator} from "../src/SwarmCoordinator.sol";

import {UUPSUpgradeable} from "@openzeppelin/contracts/proxy/utils/UUPSUpgradeable.sol";
import {ERC1967Proxy} from "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";

contract DeploySwarmCoordinatorProxy is Script {
    SwarmCoordinator public swarmCoordinator_implementation;
    SwarmCoordinator public swarmCoordinator;

    ERC1967Proxy public proxy;

    Vm.Wallet deployer;

    function setUp() public {
        deployer = vm.createWallet(vm.envUint("ETH_PRIVATE_KEY"), "deployer");
    }

    function run() public {
        vm.startBroadcast(deployer.privateKey);
        swarmCoordinator_implementation = new SwarmCoordinator();
        swarmCoordinator_implementation.initialize(deployer.addr);

        bytes memory initializeCallData = abi.encodeWithSelector(SwarmCoordinator.initialize.selector, deployer.addr);
        proxy = new ERC1967Proxy(address(swarmCoordinator_implementation), initializeCallData);

        swarmCoordinator = SwarmCoordinator(address(proxy));
        swarmCoordinator.setStageCount(3);

        vm.stopBroadcast();

        console2.log("SwarmCoordinator proxy deployed at:", address(swarmCoordinator));
        console2.log("SwarmCoordinator implementation deployed at:", address(swarmCoordinator_implementation));
    }

    function deployNewVersion() public {
        address proxyAddress = vm.envAddress("PROXY_ADDRESS");
        SwarmCoordinator proxy_ = SwarmCoordinator(payable(proxyAddress));

        vm.startBroadcast(deployer.privateKey);

        swarmCoordinator_implementation = new SwarmCoordinator();
        swarmCoordinator_implementation.initialize(deployer.addr);

        proxy_.upgradeToAndCall(address(swarmCoordinator_implementation), "");

        vm.stopBroadcast();

        console2.log("SwarmCoordinator upgraded at:", proxyAddress);
        console2.log("SwarmCoordinator implementation deployed at:", address(swarmCoordinator_implementation));
    }
}
