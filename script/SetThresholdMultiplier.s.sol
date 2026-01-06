// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Script, console2} from "forge-std/Script.sol";
import {AutoCompoundHook} from "../src/hooks/AutoCompoundHook.sol";

/// @notice Script to set thresholdMultiplier for testing
contract SetThresholdMultiplier is Script {
    function run() external {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        address hookAddress = vm.envAddress("HOOK_ADDRESS");
        
        // New multiplier (default: 1 for testing, 20 for production)
        uint256 newMultiplier = vm.envOr("NEW_THRESHOLD_MULTIPLIER", uint256(1));
        
        AutoCompoundHook hook = AutoCompoundHook(hookAddress);
        
        console2.log("=== Setting Threshold Multiplier ===");
        console2.log("Hook Address:", hookAddress);
        console2.log("Current multiplier:", hook.thresholdMultiplier());
        console2.log("New multiplier:", newMultiplier);
        console2.log("");
        
        vm.startBroadcast(deployerPrivateKey);
        
        hook.setThresholdMultiplier(newMultiplier);
        
        vm.stopBroadcast();
        
        console2.log("=== Threshold Multiplier Updated! ===");
        console2.log("New value:", hook.thresholdMultiplier());
        
        if (newMultiplier < 5) {
            console2.log("");
            console2.log("WARNING: Low multiplier is for TESTING only!");
            console2.log("For production, use at least 10x");
        }
    }
}

