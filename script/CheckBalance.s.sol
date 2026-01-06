// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Script, console2} from "forge-std/Script.sol";
import {IERC20Minimal} from "@uniswap/v4-core/src/interfaces/external/IERC20Minimal.sol";

/// @notice Script to check token balances
contract CheckBalance is Script {
    function run() external {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        address token0Address = vm.envAddress("TOKEN0_ADDRESS");
        address token1Address = vm.envAddress("TOKEN1_ADDRESS");
        
        vm.startBroadcast(deployerPrivateKey);
        
        address deployer = vm.addr(deployerPrivateKey);
        
        console2.log("=== Checking Token Balances ===");
        console2.log("Wallet address:", deployer);
        console2.log("");
        
        // Check Token0 (USDC - 6 decimals)
        IERC20Minimal token0 = IERC20Minimal(token0Address);
        uint256 balance0 = token0.balanceOf(deployer);
        console2.log("Token0 (USDC):", token0Address);
        console2.log("Balance (wei):", balance0);
        console2.log("Balance (USDC wei):", balance0);
        console2.log("Balance (USDC):", balance0 / 1e6);
        console2.log("Balance (USDC decimal):", (balance0 * 1000000) / 1e6, "/ 1000000");
        console2.log("");
        
        // Check Token1 (WETH - 18 decimals)
        IERC20Minimal token1 = IERC20Minimal(token1Address);
        uint256 balance1 = token1.balanceOf(deployer);
        console2.log("Token1 (WETH):", token1Address);
        console2.log("Balance (wei):", balance1);
        console2.log("Balance (WETH):", balance1 / 1e18);
        console2.log("");
        
        // Calculate max USDC that can be added (leave 5% for gas)
        uint256 maxUSDC = (balance0 * 95) / 100;
        uint256 maxWETH = (balance1 * 95) / 100;
        
        console2.log("=== Recommended Amounts ===");
        console2.log("Max USDC to add (95% of balance):", maxUSDC / 1e6);
        console2.log("Max WETH to add (95% of balance):", maxWETH / 1e18);
        
        vm.stopBroadcast();
    }
}

