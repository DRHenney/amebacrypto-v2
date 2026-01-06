// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Script, console2} from "forge-std/Script.sol";
import {IPoolManager} from "@uniswap/v4-core/src/interfaces/IPoolManager.sol";
import {PoolKey} from "@uniswap/v4-core/src/types/PoolKey.sol";
import {Currency, CurrencyLibrary} from "@uniswap/v4-core/src/types/Currency.sol";
import {IHooks} from "@uniswap/v4-core/src/interfaces/IHooks.sol";
import {SwapParams} from "@uniswap/v4-core/src/types/PoolOperation.sol";
import {BalanceDelta} from "@uniswap/v4-core/src/types/BalanceDelta.sol";
import {IERC20Minimal} from "@uniswap/v4-core/src/interfaces/external/IERC20Minimal.sol";
import {AutoCompoundHook} from "../src/hooks/AutoCompoundHook.sol";
import {PoolId, PoolIdLibrary} from "@uniswap/v4-core/src/types/PoolId.sol";
import {SwapHelper} from "../src/helpers/SwapHelper.sol";
import {TickMath} from "@uniswap/v4-core/src/libraries/TickMath.sol";

/// @notice Script to execute 100 swaps WETH->USDC to generate fees
contract OneHundredSwaps is Script {
    using CurrencyLibrary for Currency;
    using PoolIdLibrary for PoolKey;
    
    IPoolManager public poolManager;
    AutoCompoundHook public hook;
    PoolKey public poolKey;
    PoolId public poolId;
    SwapHelper public helper;
    
    function run() external {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        address poolManagerAddress = vm.envAddress("POOL_MANAGER");
        address hookAddress = vm.envAddress("HOOK_ADDRESS");
        address token0Address = vm.envAddress("TOKEN0_ADDRESS");
        address token1Address = vm.envAddress("TOKEN1_ADDRESS");
        
        // Amount per swap (default: 0.001 WETH)
        uint256 wethAmountPerSwap = vm.envOr("SWAP_WETH_AMOUNT", uint256(1000000000000000)); // 0.001 WETH
        
        poolManager = IPoolManager(poolManagerAddress);
        hook = AutoCompoundHook(hookAddress);
        
        // Create PoolKey (tokens must be in ascending order)
        Currency currency0 = Currency.wrap(token0Address < token1Address ? token0Address : token1Address);
        Currency currency1 = Currency.wrap(token0Address < token1Address ? token1Address : token0Address);
        
        poolKey = PoolKey({
            currency0: currency0,
            currency1: currency1,
            fee: 10000, // 1.0% (pool v2)
            tickSpacing: 60,
            hooks: IHooks(hookAddress)
        });
        poolId = poolKey.toId();
        
        address deployer = vm.addr(deployerPrivateKey);
        
        IERC20Minimal weth = IERC20Minimal(Currency.unwrap(poolKey.currency1));
        IERC20Minimal usdc = IERC20Minimal(Currency.unwrap(poolKey.currency0));
        
        // Check initial balances
        uint256 wethBalanceBefore = weth.balanceOf(deployer);
        uint256 usdcBalanceBefore = usdc.balanceOf(deployer);
        
        console2.log("=== 100 Swaps WETH->USDC to Generate Fees ===");
        console2.log("Your address:", deployer);
        console2.log("Number of swaps: 100");
        console2.log("Amount per swap:", wethAmountPerSwap, "wei");
        console2.log("Amount per swap:", wethAmountPerSwap / 1e18, "WETH");
        console2.log("");
        console2.log("Initial balances:");
        console2.log("WETH balance:", wethBalanceBefore);
        console2.log("USDC balance:", usdcBalanceBefore);
        
        // Check total amount needed
        uint256 totalWethNeeded = wethAmountPerSwap * 100;
        if (wethBalanceBefore < totalWethNeeded) {
            console2.log("\nWARNING: Insufficient WETH balance!");
            console2.log("You have:", wethBalanceBefore);
            console2.log("You need:", totalWethNeeded);
            console2.log("Will attempt to do as many swaps as possible...");
        }
        
        // Check initial fees
        (, uint256 fees0Before, uint256 fees1Before,,) = hook.getPoolInfo(poolKey);
        console2.log("\n=== Initial Pool Fees ===");
        console2.log("Fees0 (USDC):", fees0Before);
        console2.log("Fees1 (WETH):", fees1Before);
        
        vm.startBroadcast(deployerPrivateKey);
        
        // Deploy helper contract (only once)
        helper = new SwapHelper(poolManager);
        console2.log("\nSwapHelper deployed at:", address(helper));
        
        // Approve helper to spend WETH
        weth.approve(address(helper), type(uint256).max);
        console2.log("Approved helper for WETH");
        
        bytes memory hookData = "";
        
        uint256 successfulSwaps = 0;
        uint256 failedSwaps = 0;
        
        console2.log("\n=== Executing 100 Swaps ===");
        
        for (uint256 i = 0; i < 100; i++) {
            // Check if we have enough WETH
            uint256 currentWethBalance = weth.balanceOf(deployer);
            if (currentWethBalance < wethAmountPerSwap) {
                console2.log("\nSwap", i + 1, ": Skipping (insufficient WETH balance)");
                console2.log("Remaining WETH:", currentWethBalance);
                break;
            }
            
            if ((i + 1) % 10 == 0) {
                console2.log("\n--- Progress: Swap", i + 1, "of 100 ---");
            }
            
            SwapParams memory swapParams = SwapParams({
                zeroForOne: false, // false = Token1 -> Token0 (WETH -> USDC)
                amountSpecified: -int256(wethAmountPerSwap), // Negative = exactInput
                sqrtPriceLimitX96: TickMath.MAX_SQRT_PRICE - 1 // Max price limit
            });
            
            try helper.swap(poolKey, swapParams, hookData) returns (BalanceDelta delta) {
                successfulSwaps++;
                if ((i + 1) % 10 == 0) {
                    console2.log("Success! Delta0:", delta.amount0());
                    console2.log("Success! Delta1:", delta.amount1());
                }
            } catch Error(string memory errReason) {
                failedSwaps++;
                console2.log("\nSwap", i + 1, "failed:", errReason);
                // Continue with next swap
            } catch {
                failedSwaps++;
                console2.log("\nSwap", i + 1, "failed with unknown error");
                // Continue with next swap
            }
        }
        
        // Final balances
        uint256 wethBalanceAfter = weth.balanceOf(deployer);
        uint256 usdcBalanceAfter = usdc.balanceOf(deployer);
        
        console2.log("\n=== Final Balances ===");
        console2.log("WETH balance:", wethBalanceAfter);
        console2.log("USDC balance:", usdcBalanceAfter);
        console2.log("WETH spent:", wethBalanceBefore - wethBalanceAfter);
        console2.log("USDC received:", usdcBalanceAfter - usdcBalanceBefore);
        
        // Final fees
        (, uint256 fees0After, uint256 fees1After,,) = hook.getPoolInfo(poolKey);
        console2.log("\n=== Final Pool Fees ===");
        console2.log("Fees0 (USDC):", fees0After);
        console2.log("Fees1 (WETH):", fees1After);
        console2.log("Total Fees Accumulated - USDC:", fees0After - fees0Before);
        console2.log("Total Fees Accumulated - WETH:", fees1After - fees1Before);
        
        console2.log("\n=== Swap Summary ===");
        console2.log("Successful swaps:", successfulSwaps);
        console2.log("Failed swaps:", failedSwaps);
        
        // Check compound status
        (bool canCompound, string memory reason, uint256 timeUntilNext, uint256 feesValueUSD, uint256 gasCostUSD) = 
            hook.canExecuteCompound(poolKey);
        console2.log("\n=== Compound Status ===");
        console2.log("Can Execute:", canCompound);
        console2.log("Reason:", reason);
        console2.log("Time Until Next:", timeUntilNext, "seconds");
        console2.log("Fees Value (USD):", feesValueUSD);
        console2.log("Gas Cost (USD):", gasCostUSD);
        
        if (timeUntilNext > 0) {
            console2.log("Time Until Next (hours):", timeUntilNext / 3600);
        }
        
        console2.log("\n=== 100 Swaps Complete! ===");
        console2.log("Fees have been accumulated and are ready for compound");
        
        vm.stopBroadcast();
    }
}

