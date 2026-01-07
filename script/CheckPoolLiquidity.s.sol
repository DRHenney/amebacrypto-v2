// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Script, console2} from "forge-std/Script.sol";
import {IPoolManager} from "@uniswap/v4-core/src/interfaces/IPoolManager.sol";
import {PoolKey} from "@uniswap/v4-core/src/types/PoolKey.sol";
import {Currency, CurrencyLibrary} from "@uniswap/v4-core/src/types/Currency.sol";
import {IHooks} from "@uniswap/v4-core/src/interfaces/IHooks.sol";
import {PoolId, PoolIdLibrary} from "@uniswap/v4-core/src/types/PoolId.sol";
import {StateLibrary} from "@uniswap/v4-core/src/libraries/StateLibrary.sol";
import {IERC20Minimal} from "@uniswap/v4-core/src/interfaces/external/IERC20Minimal.sol";
import {AutoCompoundHook} from "../src/hooks/AutoCompoundHook.sol";

/// @notice Script para verificar liquidez e status da pool
contract CheckPoolLiquidity is Script {
    using PoolIdLibrary for PoolKey;
    using CurrencyLibrary for Currency;
    using StateLibrary for IPoolManager;
    
    function run() external view {
        address poolManagerAddress = vm.envAddress("POOL_MANAGER");
        address hookAddress = vm.envAddress("HOOK_ADDRESS");
        address token0Address = vm.envAddress("TOKEN0_ADDRESS");
        address token1Address = vm.envAddress("TOKEN1_ADDRESS");
        
        IPoolManager poolManager = IPoolManager(poolManagerAddress);
        AutoCompoundHook hook = AutoCompoundHook(hookAddress);
        
        // Criar PoolKey
        Currency currency0 = Currency.wrap(token0Address < token1Address ? token0Address : token1Address);
        Currency currency1 = Currency.wrap(token0Address < token1Address ? token1Address : token0Address);
        
        PoolKey memory poolKey = PoolKey({
            currency0: currency0,
            currency1: currency1,
            fee: 3000, // 0.3% (nova pool criada)
            tickSpacing: 60,
            hooks: IHooks(hookAddress)
        });
        
        PoolId poolId = poolKey.toId();
        
        console2.log("=== Status da Pool ===");
        console2.log("Pool ID:", vm.toString(uint256(PoolId.unwrap(poolId))));
        console2.log("PoolManager:", address(poolManager));
        console2.log("Hook:", hookAddress);
        console2.log("Token0:", Currency.unwrap(currency0));
        console2.log("Token1:", Currency.unwrap(currency1));
        console2.log("Fee: 3000 (0.3%)");
        console2.log("Tick Spacing: 60");
        console2.log("");
        
        // Verificar se pool está inicializada
        (uint160 sqrtPriceX96, int24 tick, uint24 protocolFee, uint24 protocolFeeSwap) = StateLibrary.getSlot0(poolManager, poolId);
        
        if (sqrtPriceX96 == 0) {
            console2.log("[ERRO] Pool nao esta inicializada!");
            return;
        }
        
        console2.log("=== Informacoes da Pool ===");
        console2.log("SqrtPriceX96:", sqrtPriceX96);
        console2.log("Current Tick:", tick);
        console2.log("Protocol Fee:", protocolFee);
        console2.log("Protocol Fee Swap:", protocolFeeSwap);
        console2.log("");
        
        // Verificar liquidez total da pool
        uint128 liquidity = poolManager.getLiquidity(poolId);
        console2.log("=== Liquidez ===");
        console2.log("Liquidez Total:", liquidity);
        console2.log("");
        
        if (liquidity == 0) {
            console2.log("[AVISO] Pool nao tem liquidez!");
            console2.log("Adicione liquidez antes de fazer swaps.");
            return;
        }
        
        // Verificar saldos dos tokens no PoolManager
        address token0 = Currency.unwrap(currency0);
        address token1 = Currency.unwrap(currency1);
        
        uint256 balance0 = IERC20Minimal(token0).balanceOf(address(poolManager));
        uint256 balance1 = IERC20Minimal(token1).balanceOf(address(poolManager));
        
        console2.log("=== Saldos no PoolManager ===");
        console2.log("Token0 Balance:", balance0);
        console2.log("Token1 Balance:", balance1);
        console2.log("");
        
        // Verificar configuração do hook
        (AutoCompoundHook.PoolConfig memory config, uint256 fees0, uint256 fees1, int24 tickLower, int24 tickUpper) = hook.getPoolInfo(poolKey);
        
        console2.log("=== Configuracao do Hook ===");
        console2.log("Pool Habilitada:", config.enabled);
        console2.log("Fees Acumuladas - Token0:", fees0);
        console2.log("Fees Acumuladas - Token1:", fees1);
        console2.log("Tick Lower:", tickLower);
        console2.log("Tick Upper:", tickUpper);
        console2.log("");
        
        // Verificar ticks iniciais
        int24 initialTickLower = hook.initialTickLower(poolId);
        int24 initialTickUpper = hook.initialTickUpper(poolId);
        bool hasInitialTicks = hook.hasInitialTicks(poolId);
        
        console2.log("=== Ticks Iniciais ===");
        console2.log("Has Initial Ticks:", hasInitialTicks);
        console2.log("Initial Tick Lower:", initialTickLower);
        console2.log("Initial Tick Upper:", initialTickUpper);
        console2.log("");
        
        // Verificar se há liquidez suficiente para swaps
        if (liquidity > 0) {
            console2.log("[OK] Pool tem liquidez");
            console2.log("Swaps devem funcionar.");
        } else {
            console2.log("[ERRO] Pool nao tem liquidez suficiente");
            console2.log("Adicione mais liquidez antes de fazer swaps.");
        }
        
        // Verificar se o preço está dentro do range
        if (tickLower != 0 || tickUpper != 0) {
            if (tick < tickLower || tick > tickUpper) {
                console2.log("[AVISO] Preco atual esta FORA do range de liquidez!");
                console2.log("Current Tick:", tick);
                console2.log("Tick Range Lower:", tickLower);
                console2.log("Tick Range Upper:", tickUpper);
                console2.log("Pool esta FORA do range - precisa adicionar liquidez no tick atual!");
            } else {
                console2.log("[OK] Preco atual esta DENTRO do range");
                console2.log("Current Tick:", tick);
                console2.log("Tick Range Lower:", tickLower);
                console2.log("Tick Range Upper:", tickUpper);
            }
        }
        
        // Verificar se há ticks iniciais
        if (hasInitialTicks) {
            console2.log("");
            console2.log("=== Analise de Range ===");
            if (tick < initialTickLower || tick > initialTickUpper) {
                console2.log("[ERRO] Pool esta FORA dos ticks iniciais!");
                console2.log("Current Tick:", tick);
                console2.log("Initial Tick Lower:", initialTickLower);
                console2.log("Initial Tick Upper:", initialTickUpper);
                console2.log("");
                console2.log("ISSO EXPLICA POR QUE A LIQUIDEZ E 0!");
                console2.log("Os swaps moveram o preco para fora do range inicial.");
                console2.log("");
                console2.log("Solucao:");
                console2.log("  1. Adicionar liquidez no tick atual OU");
                console2.log("  2. Adicionar liquidez em um range mais amplo");
            } else {
                console2.log("[OK] Pool esta dentro dos ticks iniciais");
            }
        }
    }
}

