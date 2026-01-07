// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Script, console2} from "forge-std/Script.sol";
import {IPoolManager} from "@uniswap/v4-core/src/interfaces/IPoolManager.sol";
import {PoolKey} from "@uniswap/v4-core/src/types/PoolKey.sol";
import {Currency} from "@uniswap/v4-core/src/types/Currency.sol";
import {IHooks} from "@uniswap/v4-core/src/interfaces/IHooks.sol";
import {PoolId, PoolIdLibrary} from "@uniswap/v4-core/src/types/PoolId.sol";
import {StateLibrary} from "@uniswap/v4-core/src/libraries/StateLibrary.sol";
import {AutoCompoundHook} from "../src/hooks/AutoCompoundHook.sol";

/// @notice Script para verificar ticks e range da pool
contract CheckPoolTicks is Script {
    using PoolIdLibrary for PoolKey;
    using StateLibrary for IPoolManager;
    
    function run() external view {
        address poolManagerAddress = vm.envAddress("POOL_MANAGER");
        address hookAddress = vm.envAddress("HOOK_ADDRESS");
        address token0Address = vm.envAddress("TOKEN0_ADDRESS");
        address token1Address = vm.envAddress("TOKEN1_ADDRESS");
        
        IPoolManager poolManager = IPoolManager(poolManagerAddress);
        AutoCompoundHook hook = AutoCompoundHook(hookAddress);
        
        PoolKey memory poolKey = PoolKey({
            currency0: Currency.wrap(token0Address < token1Address ? token0Address : token1Address),
            currency1: Currency.wrap(token0Address < token1Address ? token1Address : token0Address),
            fee: 3000,
            tickSpacing: 60,
            hooks: IHooks(hookAddress)
        });
        
        PoolId poolId = poolKey.toId();
        
        // Tick atual
        (, int24 currentTick,,) = StateLibrary.getSlot0(poolManager, poolId);
        
        // Ticks iniciais
        int24 initialTickLower = hook.initialTickLower(poolId);
        int24 initialTickUpper = hook.initialTickUpper(poolId);
        bool hasInitialTicks = hook.hasInitialTicks(poolId);
        
        // Ticks configurados
        (,,, int24 tickLower, int24 tickUpper) = hook.getPoolInfo(poolKey);
        
        console2.log("=== Analise de Ticks e Range ===");
        console2.log("");
        console2.log("Current Tick:", currentTick);
        console2.log("");
        console2.log("=== Ticks Iniciais (primeira liquidez) ===");
        console2.log("Has Initial Ticks:", hasInitialTicks);
        console2.log("Initial Tick Lower:", initialTickLower);
        console2.log("Initial Tick Upper:", initialTickUpper);
        console2.log("");
        console2.log("=== Ticks Configurados no Hook ===");
        console2.log("Tick Lower:", tickLower);
        console2.log("Tick Upper:", tickUpper);
        console2.log("");
        
        // Verificar se está fora do range
        if (hasInitialTicks) {
            console2.log("=== Verificacao de Range ===");
            if (currentTick < initialTickLower || currentTick > initialTickUpper) {
                console2.log("[ERRO] POOL ESTA FORA DO RANGE INICIAL!");
                console2.log("");
                console2.log("Current Tick:", currentTick);
                console2.log("Initial Range Lower:", initialTickLower);
                console2.log("Initial Range Upper:", initialTickUpper);
                console2.log("");
                console2.log("Isso explica por que a liquidez e 0!");
                console2.log("Os swaps moveram o preco para FORA do range onde a liquidez foi adicionada.");
                console2.log("");
                console2.log("Solucao:");
                console2.log("  1. Adicionar liquidez no tick atual:");
                console2.log("     Current Tick:", currentTick);
                console2.log("  2. OU adicionar liquidez em um range que inclua o tick atual");
                console2.log("  3. OU fazer swaps na direcao oposta para voltar ao range");
            } else {
                console2.log("[OK] Pool esta dentro do range inicial");
            }
        } else {
            console2.log("[AVISO] Nao ha ticks iniciais configurados");
        }
    }
}

