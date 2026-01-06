// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Script, console2} from "forge-std/Script.sol";
import {IPoolManager} from "@uniswap/v4-core/src/interfaces/IPoolManager.sol";
import {PoolKey} from "@uniswap/v4-core/src/types/PoolKey.sol";
import {Currency, CurrencyLibrary} from "@uniswap/v4-core/src/types/Currency.sol";
import {IHooks} from "@uniswap/v4-core/src/interfaces/IHooks.sol";
import {PoolId, PoolIdLibrary} from "@uniswap/v4-core/src/types/PoolId.sol";
import {StateLibrary} from "@uniswap/v4-core/src/libraries/StateLibrary.sol";
import {AutoCompoundHook} from "../src/hooks/AutoCompoundHook.sol";

/// @notice Script para detectar novas pools criadas com o hook
/// @dev Verifica pools recentes e detecta quais usam o hook configurado
contract DetectNewPools is Script {
    using PoolIdLibrary for PoolKey;
    using CurrencyLibrary for Currency;
    using StateLibrary for IPoolManager;
    
    /// @notice Detecta pools que usam o hook especificado
    /// @dev Verifica pools conhecidas ou busca eventos Initialize
    function run() external view {
        address poolManagerAddress = vm.envAddress("POOL_MANAGER");
        address hookAddress = vm.envAddress("HOOK_ADDRESS");
        
        IPoolManager poolManager = IPoolManager(poolManagerAddress);
        AutoCompoundHook hook = AutoCompoundHook(hookAddress);
        
        console2.log("=== Detecao de Pools ===");
        console2.log("PoolManager:", poolManagerAddress);
        console2.log("Hook:", hookAddress);
        console2.log("");
        console2.log("Nota: Para deteccao automatica completa, use:");
        console2.log("  1. The Graph subgraph para indexar eventos");
        console2.log("  2. Event listener Node.js");
        console2.log("  3. Monitor de eventos via cast/ethers");
        console2.log("");
        console2.log("Para verificar uma pool especifica, use VerifyPoolExists.s.sol");
    }
    
    /// @notice Verifica se uma pool específica usa o hook
    function checkPool(
        address token0,
        address token1,
        uint24 fee,
        int24 tickSpacing
    ) external view returns (bool usesHook, bool isConfigured) {
        address poolManagerAddress = vm.envAddress("POOL_MANAGER");
        address hookAddress = vm.envAddress("HOOK_ADDRESS");
        
        IPoolManager poolManager = IPoolManager(poolManagerAddress);
        AutoCompoundHook hook = AutoCompoundHook(hookAddress);
        
        Currency currency0 = Currency.wrap(token0 < token1 ? token0 : token1);
        Currency currency1 = Currency.wrap(token0 < token1 ? token1 : token0);
        
        PoolKey memory poolKey = PoolKey({
            currency0: currency0,
            currency1: currency1,
            fee: fee,
            tickSpacing: tickSpacing,
            hooks: IHooks(hookAddress)
        });
        
        PoolId poolId = poolKey.toId();
        
        // Verificar se pool existe (sqrtPriceX96 != 0)
        (uint160 sqrtPriceX96,,,) = StateLibrary.getSlot0(poolManager, poolId);
        
        if (sqrtPriceX96 == 0) {
            return (false, false);
        }
        
        // Verificar se hook está configurado para esta pool
        (bool enabled,,,,) = hook.getPoolInfo(poolKey);
        
        return (true, enabled);
    }
}

