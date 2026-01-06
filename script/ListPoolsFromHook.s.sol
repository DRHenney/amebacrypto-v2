// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Script, console2} from "forge-std/Script.sol";
import {AutoCompoundHook} from "../src/hooks/AutoCompoundHook.sol";
import {PoolKey} from "@uniswap/v4-core/src/types/PoolKey.sol";
import {Currency, CurrencyLibrary} from "@uniswap/v4-core/src/types/Currency.sol";
import {IHooks} from "@uniswap/v4-core/src/interfaces/IHooks.sol";
import {PoolId, PoolIdLibrary} from "@uniswap/v4-core/src/types/PoolId.sol";

/// @notice Script para listar pools configuradas no hook
/// @dev Útil para o keeper descobrir pools existentes
contract ListPoolsFromHook is Script {
    using PoolIdLibrary for PoolKey;
    using CurrencyLibrary for Currency;
    
    function run() external view {
        address hookAddress = vm.envAddress("HOOK_ADDRESS");
        address token0Address = vm.envAddress("TOKEN0_ADDRESS");
        address token1Address = vm.envAddress("TOKEN1_ADDRESS");
        
        AutoCompoundHook hook = AutoCompoundHook(hookAddress);
        
        console2.log("=== Pools Configuradas no Hook ===");
        console2.log("Hook:", hookAddress);
        console2.log("");
        
        // Verificar pool padrão do .env
        Currency currency0 = Currency.wrap(token0Address < token1Address ? token0Address : token1Address);
        Currency currency1 = Currency.wrap(token0Address < token1Address ? token1Address : token0Address);
        
        // Verificar diferentes fees (pools podem ter fees diferentes)
        uint24[] memory fees = new uint24[](3);
        fees[0] = 3000;  // 0.3%
        fees[1] = 5000;  // 0.5%
        fees[2] = 10000; // 1.0%
        
        for (uint256 i = 0; i < fees.length; i++) {
            PoolKey memory poolKey = PoolKey({
                currency0: currency0,
                currency1: currency1,
                fee: fees[i],
                tickSpacing: 60,
                hooks: IHooks(hookAddress)
            });
            
            PoolId poolId = poolKey.toId();
            
            (AutoCompoundHook.PoolConfig memory config,,,,) = hook.getPoolInfo(poolKey);
            
            if (config.enabled) {
                console2.log("=== Pool Encontrada ===");
                console2.log("Pool ID:", vm.toString(uint256(PoolId.unwrap(poolId))));
                console2.log("Fee:", fees[i]);
                console2.log("Token0:", Currency.unwrap(currency0));
                console2.log("Token1:", Currency.unwrap(currency1));
                console2.log("Habilitada: true");
                console2.log("");
            }
        }
        
        console2.log("=== Instrucoes ===");
        console2.log("O keeper deve verificar estas pools ao iniciar");
        console2.log("e adiciona-las automaticamente ao monitoramento");
    }
}

