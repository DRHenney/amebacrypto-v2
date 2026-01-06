// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Script, console2} from "forge-std/Script.sol";
import {AutoCompoundHook} from "../src/hooks/AutoCompoundHook.sol";
import {PoolKey} from "@uniswap/v4-core/src/types/PoolKey.sol";
import {Currency, CurrencyLibrary} from "@uniswap/v4-core/src/types/Currency.sol";
import {IHooks} from "@uniswap/v4-core/src/interfaces/IHooks.sol";
import {PoolId, PoolIdLibrary} from "@uniswap/v4-core/src/types/PoolId.sol";

/// @notice Script para verificar se evento PoolAutoEnabled foi emitido
contract CheckPoolAutoEnabledEvent is Script {
    using PoolIdLibrary for PoolKey;
    using CurrencyLibrary for Currency;
    
    function run() external view {
        address hookAddress = vm.envAddress("HOOK_ADDRESS");
        address token0Address = vm.envAddress("TOKEN0_ADDRESS");
        address token1Address = vm.envAddress("TOKEN1_ADDRESS");
        
        AutoCompoundHook hook = AutoCompoundHook(hookAddress);
        
        // Criar PoolKey
        Currency currency0 = Currency.wrap(token0Address < token1Address ? token0Address : token1Address);
        Currency currency1 = Currency.wrap(token0Address < token1Address ? token1Address : token0Address);
        
        PoolKey memory poolKey = PoolKey({
            currency0: currency0,
            currency1: currency1,
            fee: 5000, // 0.5% (pool recriada)
            tickSpacing: 60,
            hooks: IHooks(hookAddress)
        });
        
        PoolId poolId = poolKey.toId();
        
        console2.log("=== Verificacao do Evento PoolAutoEnabled ===");
        console2.log("Pool ID:", vm.toString(uint256(PoolId.unwrap(poolId))));
        console2.log("Hook:", hookAddress);
        console2.log("");
        
        // Verificar se pool está habilitada
        (AutoCompoundHook.PoolConfig memory config,,,,) = hook.getPoolInfo(poolKey);
        
        console2.log("=== Status da Pool ===");
        console2.log("Pool Habilitada:", config.enabled);
        console2.log("");
        
        if (config.enabled) {
            console2.log("[OK] Pool esta habilitada no hook");
            console2.log("[OK] Evento PoolAutoEnabled deve ter sido emitido durante a inicializacao");
            console2.log("");
            console2.log("=== Keeper Auto-Start ===");
            console2.log("O keeper-bot-auto-start.ps1 deve detectar esta pool automaticamente");
            console2.log("quando monitorar eventos PoolAutoEnabled do hook.");
            console2.log("");
            console2.log("Para verificar:");
            console2.log("1. Execute: keeper-bot-auto-start.ps1");
            console2.log("2. O keeper deve detectar a pool via evento");
            console2.log("3. A pool sera adicionada automaticamente ao monitoramento");
        } else {
            console2.log("[AVISO] Pool nao esta habilitada");
            console2.log("Execute setPoolConfig para habilitar");
        }
    }
}

