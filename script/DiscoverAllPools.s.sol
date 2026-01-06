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

/// @notice Script para descobrir TODAS as pools que usam o hook
/// @dev Busca eventos PoolAutoEnabled e verifica pools no PoolManager
contract DiscoverAllPools is Script {
    using PoolIdLibrary for PoolKey;
    using CurrencyLibrary for Currency;
    using StateLibrary for IPoolManager;
    
    function run() external view {
        address poolManagerAddress = vm.envAddress("POOL_MANAGER");
        address hookAddress = vm.envAddress("HOOK_ADDRESS");
        
        IPoolManager poolManager = IPoolManager(poolManagerAddress);
        AutoCompoundHook hook = AutoCompoundHook(hookAddress);
        
        console2.log("=== Descobrindo TODAS as Pools do Hook ===");
        console2.log("Hook:", hookAddress);
        console2.log("PoolManager:", poolManagerAddress);
        console2.log("");
        console2.log("NOTA: Este script verifica pools conhecidas.");
        console2.log("Para encontrar TODAS as pools, use eventos PoolAutoEnabled.");
        console2.log("O keeper-bot-auto-start.ps1 busca esses eventos automaticamente.");
        console2.log("");
        
        // Lista de tokens comuns para verificar (pode ser expandida)
        address[] memory commonTokens = new address[](5);
        commonTokens[0] = 0x1c7D4B196Cb0C7B01d743Fbc6116a902379C7238; // USDC Sepolia
        commonTokens[1] = 0xfFf9976782d46CC05630D1f6eBAb18b2324d6B14; // WETH Sepolia
        commonTokens[2] = 0x1f9840a85d5aF5bf1D1762F925BDADdC4201F984; // UNI (exemplo)
        commonTokens[3] = 0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48; // USDC Mainnet
        commonTokens[4] = 0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2; // WETH Mainnet
        
        uint24[] memory fees = new uint24[](5);
        fees[0] = 100;   // 0.01%
        fees[1] = 500;   // 0.05%
        fees[2] = 3000;  // 0.3%
        fees[3] = 5000;  // 0.5%
        fees[4] = 10000; // 1.0%
        
        uint256 poolCount = 0;
        
        // Verificar combinações de tokens e fees
        for (uint256 i = 0; i < commonTokens.length; i++) {
            for (uint256 j = i + 1; j < commonTokens.length; j++) {
                address token0 = commonTokens[i] < commonTokens[j] ? commonTokens[i] : commonTokens[j];
                address token1 = commonTokens[i] < commonTokens[j] ? commonTokens[j] : commonTokens[i];
                
                Currency currency0 = Currency.wrap(token0);
                Currency currency1 = Currency.wrap(token1);
                
                for (uint256 k = 0; k < fees.length; k++) {
                    PoolKey memory poolKey = PoolKey({
                        currency0: currency0,
                        currency1: currency1,
                        fee: fees[k],
                        tickSpacing: 60,
                        hooks: IHooks(hookAddress)
                    });
                    
                    PoolId poolId = poolKey.toId();
                    
                    // Verificar se pool existe e está inicializada
                    (uint160 sqrtPriceX96,,,) = StateLibrary.getSlot0(poolManager, poolId);
                    
                    if (sqrtPriceX96 > 0) {
                        // Pool existe, verificar se está habilitada no hook
                        (AutoCompoundHook.PoolConfig memory config,,,,) = hook.getPoolInfo(poolKey);
                        
                        if (config.enabled) {
                            poolCount++;
                            console2.log("=== Pool Encontrada ===");
                            console2.log("Pool ID:", vm.toString(uint256(PoolId.unwrap(poolId))));
                            console2.log("Token0:", token0);
                            console2.log("Token1:", token1);
                            console2.log("Fee:", fees[k]);
                            console2.log("Habilitada: true");
                            console2.log("");
                        }
                    }
                }
            }
        }
        
        console2.log("=== Resumo ===");
        console2.log("Total de pools encontradas:", poolCount);
        console2.log("");
        console2.log("NOTA: Este script verifica apenas tokens comuns.");
        console2.log("Para encontrar TODAS as pools, o keeper usa eventos PoolAutoEnabled");
        console2.log("que são emitidos automaticamente quando qualquer pool é criada.");
    }
}

