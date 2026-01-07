// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Script, console2} from "forge-std/Script.sol";
import {IPoolManager} from "@uniswap/v4-core/src/interfaces/IPoolManager.sol";
import {PoolKey} from "@uniswap/v4-core/src/types/PoolKey.sol";
import {Currency} from "@uniswap/v4-core/src/types/Currency.sol";
import {IHooks} from "@uniswap/v4-core/src/interfaces/IHooks.sol";
import {ModifyLiquidityParams} from "@uniswap/v4-core/src/types/PoolOperation.sol";
import {BalanceDelta} from "@uniswap/v4-core/src/types/BalanceDelta.sol";
import {TickMath} from "@uniswap/v4-core/src/libraries/TickMath.sol";
import {StateLibrary} from "@uniswap/v4-core/src/libraries/StateLibrary.sol";
import {LiquidityAmounts} from "@uniswap/v4-core/test/utils/LiquidityAmounts.sol";
import {IERC20Minimal} from "@uniswap/v4-core/src/interfaces/external/IERC20Minimal.sol";
import {PoolId, PoolIdLibrary} from "@uniswap/v4-core/src/types/PoolId.sol";
import {LiquidityHelper} from "../src/helpers/LiquidityHelper.sol";

/// @notice Script to add liquidity to a pool
contract AddLiquidity is Script {
    using StateLibrary for IPoolManager;
    using PoolIdLibrary for PoolKey;
    
    IPoolManager public poolManager;
    PoolKey public poolKey;
    
    function run() external {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        address poolManagerAddress = vm.envAddress("POOL_MANAGER");
        address hookAddress = vm.envAddress("HOOK_ADDRESS");
        address token0Address = vm.envAddress("TOKEN0_ADDRESS");
        address token1Address = vm.envAddress("TOKEN1_ADDRESS");
        
        // Get liquidity amounts from env (in smallest units)
        uint256 token0Amount = vm.envUint("LIQUIDITY_TOKEN0_AMOUNT"); // e.g., 100e18
        uint256 token1Amount = vm.envUint("LIQUIDITY_TOKEN1_AMOUNT"); // e.g., 100e18
        
        poolManager = IPoolManager(poolManagerAddress);
        
        // Create PoolKey (tokens must be in ascending order)
        Currency currency0 = Currency.wrap(token0Address < token1Address ? token0Address : token1Address);
        Currency currency1 = Currency.wrap(token0Address < token1Address ? token1Address : token0Address);
        
        // Usar fee 3000 (0.3%) - pool existente
        poolKey = PoolKey({
            currency0: currency0,
            currency1: currency1,
            fee: 3000, // 0.3% (pool existente)
            tickSpacing: 60,
            hooks: IHooks(hookAddress)
        });
        
        // Get current pool price
        PoolId poolId = poolKey.toId();
        (uint160 sqrtPriceX96,,,) = StateLibrary.getSlot0(poolManager, poolId);
        int24 currentTick = TickMath.getTickAtSqrtPrice(sqrtPriceX96);
        
        // Set tick range around current price
        // Ticks must be aligned with tickSpacing (60)
        int24 tickSpacing = 60;
        
        // Use a wider range around current price for extreme ticks
        // For extreme ticks (> 500000 or < -500000), use a much wider range
        int24 rangeTicks;
        if (currentTick > 500000 || currentTick < -500000) {
            // For extreme ticks, use 1000 ticks range (much wider)
            rangeTicks = 1000;
        } else {
            // For normal ticks, use 10 ticks range
            rangeTicks = 10;
        }
        
        // Calculate ticks aligned with tickSpacing
        int24 tickLower = ((currentTick / tickSpacing) - rangeTicks) * tickSpacing;
        int24 tickUpper = ((currentTick / tickSpacing) + rangeTicks) * tickSpacing;
        
        // Ensure ticks are within bounds
        int24 minTick = TickMath.minUsableTick(tickSpacing);
        int24 maxTick = TickMath.maxUsableTick(tickSpacing);
        if (tickLower < minTick) tickLower = minTick;
        if (tickUpper > maxTick) tickUpper = maxTick;
        
        console2.log("Current Tick:", currentTick);
        console2.log("Tick Lower:", tickLower);
        console2.log("Tick Upper:", tickUpper);
        
        // Calculate liquidity from amounts
        uint128 liquidity = LiquidityAmounts.getLiquidityForAmounts(
            sqrtPriceX96,
            TickMath.getSqrtPriceAtTick(tickLower),
            TickMath.getSqrtPriceAtTick(tickUpper),
            token0Amount,
            token1Amount
        );
        
        console2.log("Calculated Liquidity:", liquidity);
        
        // If liquidity is still 0, use full range as fallback
        if (liquidity == 0) {
            console2.log("Liquidity is 0, trying full range...");
            tickLower = minTick;
            tickUpper = maxTick;
            liquidity = LiquidityAmounts.getLiquidityForAmounts(
                sqrtPriceX96,
                TickMath.getSqrtPriceAtTick(tickLower),
                TickMath.getSqrtPriceAtTick(tickUpper),
                token0Amount,
                token1Amount
            );
            console2.log("Full range Liquidity:", liquidity);
        }
        
        // If still 0, try calculating with only the token that's closer to current price
        // At high prices (high tick), we need more token1 (WETH)
        if (liquidity == 0 && currentTick > 0) {
            // Use only token1 (WETH) for liquidity at high prices
            liquidity = LiquidityAmounts.getLiquidityForAmount1(
                TickMath.getSqrtPriceAtTick(tickLower),
                TickMath.getSqrtPriceAtTick(tickUpper),
                token1Amount
            );
            console2.log("Token1-only Liquidity:", liquidity);
        }
        
        // If still 0, try with only token0
        if (liquidity == 0) {
            liquidity = LiquidityAmounts.getLiquidityForAmount0(
                TickMath.getSqrtPriceAtTick(tickLower),
                TickMath.getSqrtPriceAtTick(tickUpper),
                token0Amount
            );
            console2.log("Token0-only Liquidity:", liquidity);
        }
        
        // If still 0, require minimum liquidity
        require(liquidity > 0, "Liquidity calculation resulted in 0");
        
        console2.log("=== Adding Liquidity ===");
        console2.log("PoolManager:", address(poolManager));
        console2.log("Token0:", Currency.unwrap(poolKey.currency0));
        console2.log("Token1:", Currency.unwrap(poolKey.currency1));
        console2.log("Token0 Amount:", token0Amount);
        console2.log("Token1 Amount:", token1Amount);
        console2.log("Liquidity:", liquidity);
        console2.log("Tick Lower:", tickLower);
        console2.log("Tick Upper:", tickUpper);
        console2.log("Current Tick:", currentTick);
        
        vm.startBroadcast(deployerPrivateKey);
        
        
        // Deploy helper contract
        LiquidityHelper helper = new LiquidityHelper(poolManager);
        console2.log("Helper deployed at:", address(helper));
        
        // Approve helper to spend tokens
        address token0 = Currency.unwrap(poolKey.currency0);
        address token1 = Currency.unwrap(poolKey.currency1);
        
        if (token0 != address(0)) {
            IERC20Minimal(token0).approve(address(helper), type(uint256).max);
            console2.log("Approved helper for token0");
        }
        if (token1 != address(0)) {
            IERC20Minimal(token1).approve(address(helper), type(uint256).max);
            console2.log("Approved helper for token1");
        }
        
        // Prepare modify liquidity params
        ModifyLiquidityParams memory params = ModifyLiquidityParams({
            tickLower: tickLower,
            tickUpper: tickUpper,
            liquidityDelta: int256(uint256(liquidity)),
            salt: bytes32(0)
        });
        
        bytes memory hookData = "";
        
        // Add liquidity via helper
        BalanceDelta delta = helper.addLiquidity(poolKey, params, hookData);
        
        console2.log("\nLiquidity added successfully!");
        console2.log("Delta Amount0:", delta.amount0());
        console2.log("Delta Amount1:", delta.amount1());
        
        vm.stopBroadcast();
    }
}
