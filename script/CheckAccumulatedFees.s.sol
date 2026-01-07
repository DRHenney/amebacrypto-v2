// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Script, console2} from "forge-std/Script.sol";
import {IPoolManager} from "@uniswap/v4-core/src/interfaces/IPoolManager.sol";
import {PoolKey} from "@uniswap/v4-core/src/types/PoolKey.sol";
import {Currency} from "@uniswap/v4-core/src/types/Currency.sol";
import {IHooks} from "@uniswap/v4-core/src/interfaces/IHooks.sol";
import {PoolId, PoolIdLibrary} from "@uniswap/v4-core/src/types/PoolId.sol";
import {AutoCompoundHook} from "../src/hooks/AutoCompoundHook.sol";

/// @notice Script para verificar diretamente as fees acumuladas no hook
contract CheckAccumulatedFees is Script {
    using PoolIdLibrary for PoolKey;
    
    function run() external view {
        address poolManagerAddress = vm.envAddress("POOL_MANAGER");
        address hookAddress = vm.envAddress("HOOK_ADDRESS");
        address token0Address = vm.envAddress("TOKEN0_ADDRESS");
        address token1Address = vm.envAddress("TOKEN1_ADDRESS");
        
        IPoolManager poolManager = IPoolManager(poolManagerAddress);
        AutoCompoundHook hook = AutoCompoundHook(hookAddress);
        
        // Criar PoolKey (tokens devem estar em ordem crescente)
        Currency currency0 = Currency.wrap(token0Address < token1Address ? token0Address : token1Address);
        Currency currency1 = Currency.wrap(token0Address < token1Address ? token1Address : token0Address);
        
        PoolKey memory poolKey = PoolKey({
            currency0: currency0,
            currency1: currency1,
            fee: 3000, // 0.3%
            tickSpacing: 60,
            hooks: IHooks(hookAddress)
        });
        
        PoolId poolId = poolKey.toId();
        
        console2.log("=== Verificacao Direta de Fees Acumuladas ===");
        console2.log("Pool ID:", vm.toString(uint256(PoolId.unwrap(poolId))));
        console2.log("Hook Address:", hookAddress);
        console2.log("");
        console2.log("=== Ordem dos Tokens ===");
        console2.log("Token0 (currency0):", Currency.unwrap(currency0));
        console2.log("Token1 (currency1):", Currency.unwrap(currency1));
        console2.log("");
        console2.log("Token0 < Token1?", Currency.unwrap(currency0) < Currency.unwrap(currency1));
        console2.log("");
        
        // Verificar diretamente as fees acumuladas
        uint256 fees0 = hook.accumulatedFees0(poolId);
        uint256 fees1 = hook.accumulatedFees1(poolId);
        
        console2.log("=== Fees Acumuladas (Direto do Hook) ===");
        console2.log("Fees0 (Token0 - primeiro token na ordem):", fees0);
        console2.log("Fees1 (Token1 - segundo token na ordem):", fees1);
        console2.log("");
        
        // Verificar qual token é qual
        address token0 = Currency.unwrap(currency0);
        address token1 = Currency.unwrap(currency1);
        
        console2.log("=== Identificacao dos Tokens ===");
        if (token0 == token0Address) {
            console2.log("Token0 = USDC");
            console2.log("Fees0 = Fees USDC:", fees0);
        } else {
            console2.log("Token0 = WETH");
            console2.log("Fees0 = Fees WETH:", fees0);
        }
        
        if (token1 == token1Address) {
            console2.log("Token1 = WETH");
            console2.log("Fees1 = Fees WETH:", fees1);
        } else {
            console2.log("Token1 = USDC");
            console2.log("Fees1 = Fees USDC:", fees1);
        }
        console2.log("");
        
        // Verificar via getPoolInfo também
        (AutoCompoundHook.PoolConfig memory config, uint256 fees0FromInfo, uint256 fees1FromInfo,,) = hook.getPoolInfo(poolKey);
        
        console2.log("=== Fees Via getPoolInfo ===");
        console2.log("Fees0:", fees0FromInfo);
        console2.log("Fees1:", fees1FromInfo);
        console2.log("Pool Enabled:", config.enabled);
        console2.log("");
        
        // Comparar
        if (fees0 == fees0FromInfo && fees1 == fees1FromInfo) {
            console2.log("[OK] Fees coincidem entre leitura direta e getPoolInfo");
        } else {
            console2.log("[ERRO] Fees NAO coincidem!");
            console2.log("  Direto - Fees0:", fees0, "Fees1:", fees1);
            console2.log("  getPoolInfo - Fees0:", fees0FromInfo, "Fees1:", fees1FromInfo);
        }
    }
}

