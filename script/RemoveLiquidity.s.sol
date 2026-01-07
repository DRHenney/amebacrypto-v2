// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Script, console2} from "forge-std/Script.sol";
import {IPoolManager} from "@uniswap/v4-core/src/interfaces/IPoolManager.sol";
import {PoolKey} from "@uniswap/v4-core/src/types/PoolKey.sol";
import {Currency} from "@uniswap/v4-core/src/types/Currency.sol";
import {IHooks} from "@uniswap/v4-core/src/interfaces/IHooks.sol";
import {ModifyLiquidityParams} from "@uniswap/v4-core/src/types/PoolOperation.sol";
import {BalanceDelta} from "@uniswap/v4-core/src/types/BalanceDelta.sol";
import {PoolId, PoolIdLibrary} from "@uniswap/v4-core/src/types/PoolId.sol";
import {StateLibrary} from "@uniswap/v4-core/src/libraries/StateLibrary.sol";
import {LiquidityHelper} from "../src/helpers/LiquidityHelper.sol";

/// @notice Script to remove all liquidity from a pool
contract RemoveLiquidity is Script {
    using PoolIdLibrary for PoolKey;
    using StateLibrary for IPoolManager;
    
    IPoolManager public poolManager;
    PoolKey public poolKey;
    LiquidityHelper public helper;
    
    function run() external {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        address poolManagerAddress = vm.envAddress("POOL_MANAGER");
        address hookAddress = vm.envAddress("HOOK_ADDRESS");
        address token0Address = vm.envAddress("TOKEN0_ADDRESS");
        address token1Address = vm.envAddress("TOKEN1_ADDRESS");
        
        poolManager = IPoolManager(poolManagerAddress);
        
        // Create PoolKey (tokens must be in ascending order)
        Currency currency0 = Currency.wrap(token0Address < token1Address ? token0Address : token1Address);
        Currency currency1 = Currency.wrap(token0Address < token1Address ? token1Address : token0Address);
        
        poolKey = PoolKey({
            currency0: currency0,
            currency1: currency1,
            fee: 3000, // 0.3% (pool existente)
            tickSpacing: 60,
            hooks: IHooks(hookAddress)
        });
        
        PoolId poolId = poolKey.toId();
        
        address deployer = vm.addr(deployerPrivateKey);
        
        console2.log("=== Removendo Liquidez da Pool ===");
        console2.log("Pool ID:", vm.toString(uint256(PoolId.unwrap(poolId))));
        console2.log("Deployer:", deployer);
        console2.log("");
        
        // Get current pool state
        (uint160 sqrtPriceX96, int24 currentTick,,) = StateLibrary.getSlot0(poolManager, poolId);
        uint128 currentLiquidity = poolManager.getLiquidity(poolId);
        
        console2.log("Current Liquidity:", currentLiquidity);
        console2.log("Current Tick:", currentTick);
        console2.log("");
        
        if (currentLiquidity == 0) {
            console2.log("[AVISO] Pool nao tem liquidez para remover!");
            return;
        }
        
        vm.startBroadcast(deployerPrivateKey);
        
        // Deploy helper if needed (or reuse existing)
        // For simplicity, deploy a new one
        helper = new LiquidityHelper(poolManager);
        console2.log("LiquidityHelper deployed at:", address(helper));
        console2.log("");
        
        // Get initial ticks from hook (if available)
        // We'll use a wide range to remove all liquidity
        // First, try to get the initial ticks from the hook
        address hookAddr = hookAddress;
        (bool success, bytes memory data) = hookAddr.staticcall(
            abi.encodeWithSignature("initialTickLower(bytes32)", PoolId.unwrap(poolId))
        );
        
        int24 tickLower;
        int24 tickUpper;
        
        if (success && data.length > 0) {
            tickLower = abi.decode(data, (int24));
            console2.log("Initial Tick Lower:", tickLower);
            
            (success, data) = hookAddr.staticcall(
                abi.encodeWithSignature("initialTickUpper(bytes32)", PoolId.unwrap(poolId))
            );
            if (success && data.length > 0) {
                tickUpper = abi.decode(data, (int24));
                console2.log("Initial Tick Upper:", tickUpper);
            }
        }
        
        // If we don't have initial ticks, use a very wide range around current tick
        if (tickLower == 0 && tickUpper == 0) {
            console2.log("[AVISO] Ticks iniciais nao encontrados, usando range amplo");
            // Use a very wide range to capture all liquidity
            tickLower = currentTick - 1000000; // Very wide range
            tickUpper = currentTick + 1000000;
        }
        
        console2.log("Using Tick Range:");
        console2.log("  Tick Lower:", tickLower);
        console2.log("  Tick Upper:", tickUpper);
        console2.log("");
        
        // Remove all liquidity (negative liquidityDelta)
        // Convert uint128 to int128 negative
        int128 liquidityDelta = -int128(currentLiquidity);
        
        console2.log("Removing Liquidity:");
        console2.log("  Liquidity Delta:", uint128(-liquidityDelta));
        console2.log("");
        
        ModifyLiquidityParams memory params = ModifyLiquidityParams({
            tickLower: tickLower,
            tickUpper: tickUpper,
            liquidityDelta: liquidityDelta,
            salt: bytes32(0)
        });
        
        // Execute remove liquidity via helper
        try helper.removeLiquidity(poolKey, params, "") returns (BalanceDelta delta) {
            console2.log("[SUCCESS] Liquidez removida!");
            console2.log("Delta Amount0:", delta.amount0());
            console2.log("Delta Amount1:", delta.amount1());
            
            // Positive deltas mean we receive tokens
            if (delta.amount0() > 0) {
                console2.log("Tokens0 recebidos:", uint128(int128(delta.amount0())));
            }
            if (delta.amount1() > 0) {
                console2.log("Tokens1 recebidos:", uint128(int128(delta.amount1())));
            }
        } catch Error(string memory reason) {
            console2.log("[ERRO] Falha ao remover liquidez:", reason);
        } catch (bytes memory lowLevelData) {
            console2.log("[ERRO] Falha ao remover liquidez (low level)");
        }
        
        vm.stopBroadcast();
        
        // Verify liquidity was removed
        uint128 remainingLiquidity = poolManager.getLiquidity(poolId);
        console2.log("");
        console2.log("=== Verificacao Final ===");
        console2.log("Liquidez restante:", remainingLiquidity);
        
        if (remainingLiquidity == 0) {
            console2.log("[SUCCESS] Toda liquidez foi removida!");
        } else {
            console2.log("[AVISO] Ainda ha liquidez na pool:", remainingLiquidity);
        }
    }
}
