// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Script, console2} from "forge-std/Script.sol";
import {AutoCompoundHook} from "../src/hooks/AutoCompoundHook.sol";

/// @notice Script to set minTimeBetweenCompounds for testing
contract SetMinTimeInterval is Script {
    function run() external {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        address hookAddress = vm.envAddress("HOOK_ADDRESS");
        
        // New interval (default: 60 seconds for testing, 14400 for production)
        uint256 newInterval = vm.envOr("NEW_MIN_TIME_INTERVAL", uint256(60));
        
        AutoCompoundHook hook = AutoCompoundHook(hookAddress);
        
        console2.log("=== Setting Min Time Interval ===");
        console2.log("Hook Address:", hookAddress);
        console2.log("Current interval:", hook.minTimeBetweenCompounds(), "seconds");
        console2.log("New interval:", newInterval, "seconds");
        console2.log("");
        
        vm.startBroadcast(deployerPrivateKey);
        
        hook.setMinTimeInterval(newInterval);
        
        vm.stopBroadcast();
        
        console2.log("=== Min Time Interval Updated! ===");
        console2.log("New value:", hook.minTimeBetweenCompounds(), "seconds");
        
        if (newInterval < 3600) {
            console2.log("");
            console2.log("WARNING: Low interval is for TESTING only!");
            console2.log("For production, use at least 3600 seconds (1 hour)");
        }
    }
}

