// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Script, console2} from "forge-std/Script.sol";
import {IPoolManager} from "@uniswap/v4-core/src/interfaces/IPoolManager.sol";
import {PoolKey} from "@uniswap/v4-core/src/types/PoolKey.sol";
import {Currency, CurrencyLibrary} from "@uniswap/v4-core/src/types/Currency.sol";
import {IHooks} from "@uniswap/v4-core/src/interfaces/IHooks.sol";
import {PoolId, PoolIdLibrary} from "@uniswap/v4-core/src/types/PoolId.sol";
import {AutoCompoundHook} from "../src/hooks/AutoCompoundHook.sol";

/// @notice Script para diagnosticar por que o compound não pode ser executado
contract DiagnoseCompound is Script {
    using PoolIdLibrary for PoolKey;
    using CurrencyLibrary for Currency;
    
    function run() external view {
        address poolManagerAddress = vm.envAddress("POOL_MANAGER");
        address hookAddress = vm.envAddress("HOOK_ADDRESS");
        address token0Address = vm.envAddress("TOKEN0_ADDRESS");
        address token1Address = vm.envAddress("TOKEN1_ADDRESS");
        
        IPoolManager poolManager = IPoolManager(poolManagerAddress);
        AutoCompoundHook hook = AutoCompoundHook(hookAddress);
        
        // Create PoolKey
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
        
        console2.log("=== Diagnostico do Compound ===");
        console2.log("Pool ID:", vm.toString(uint256(PoolId.unwrap(poolId))));
        console2.log("");
        
        // 1. Verificar se pool está habilitada
        (PoolConfig memory config, uint256 fees0, uint256 fees1, int24 tickLower, int24 tickUpper) = hook.getPoolInfo(poolKey);
        bool enabled = config.enabled;
        uint256 lastCompound = hook.lastCompoundTimestamp(poolId);
        uint256 totalCompounds = hook.totalCompounds(poolId);
        console2.log("=== Pool Info ===");
        console2.log("Pool Enabled:", enabled);
        console2.log("Fees0 (USDC):", fees0);
        console2.log("Fees1 (WETH):", fees1);
        console2.log("Tick Lower:", tickLower);
        console2.log("Tick Upper:", tickUpper);
        console2.log("Last Compound Timestamp:", lastCompound);
        console2.log("Total Compounds:", totalCompounds);
        console2.log("Current Block Timestamp:", block.timestamp);
        console2.log("");
        
        // 2. Verificar configurações do hook
        uint256 thresholdMultiplier = hook.thresholdMultiplier();
        uint256 minTimeInterval = hook.minTimeBetweenCompounds();
        console2.log("=== Hook Configuration ===");
        console2.log("Threshold Multiplier:", thresholdMultiplier);
        console2.log("Min Time Interval:", minTimeInterval, "seconds");
        console2.log("Min Time Interval:", minTimeInterval / 3600, "hours");
        console2.log("");
        
        // 3. Verificar se tempo mínimo passou
        if (lastCompound > 0) {
            uint256 timeSinceLastCompound = block.timestamp - lastCompound;
            console2.log("=== Time Check ===");
            console2.log("Time Since Last Compound:", timeSinceLastCompound, "seconds");
            console2.log("Time Since Last Compound:", timeSinceLastCompound / 3600, "hours");
            console2.log("Min Time Required:", minTimeInterval, "seconds");
            console2.log("Time Passed:", timeSinceLastCompound >= minTimeInterval);
            console2.log("");
        } else {
            console2.log("=== Time Check ===");
            console2.log("No previous compound - time check OK");
            console2.log("");
        }
        
        // 4. Verificar tick range
        // Note: Não há função pública para verificar tick range, mas sabemos que foi configurado
        
        // 5. Verificar canExecuteCompound
        (bool canExecute, string memory reason, uint256 timeUntilNext, uint256 feesValueUSD, uint256 gasCostUSD) = 
            hook.canExecuteCompound(poolKey);
        console2.log("=== Can Execute Compound ===");
        console2.log("Can Execute:", canExecute);
        console2.log("Reason:", reason);
        console2.log("Time Until Next:", timeUntilNext, "seconds");
        console2.log("Fees Value (USD):", feesValueUSD);
        console2.log("Gas Cost (USD):", gasCostUSD);
        console2.log("");
        
        // 6. Tentar prepareCompound
        (bool canPrepare, , uint256 prepFees0, uint256 prepFees1) = hook.prepareCompound(poolKey);
        console2.log("=== Prepare Compound ===");
        console2.log("Can Prepare:", canPrepare);
        console2.log("Fees0:", prepFees0);
        console2.log("Fees1:", prepFees1);
        console2.log("");
        
        // 7. Diagnostico
        console2.log("=== Diagnostico ===");
        if (!enabled) {
            console2.log("[ERRO] Pool nao esta habilitada!");
        } else if (fees0 == 0 && fees1 == 0) {
            console2.log("[ERRO] Nao ha fees acumuladas!");
        } else if (lastCompound > 0 && block.timestamp < lastCompound + minTimeInterval) {
            console2.log("[ERRO] Tempo minimo entre compounds nao passou!");
            console2.log("   Aguarde mais", (lastCompound + minTimeInterval) - block.timestamp, "segundos");
        } else if (!canPrepare) {
            console2.log("[ERRO] prepareCompound retornou false");
            console2.log("   Possiveis causas:");
            console2.log("   - Tick range nao configurado corretamente");
            console2.log("   - Liquidity delta calculado <= 0");
            console2.log("   - Fees value < threshold * gas cost");
        } else {
            console2.log("[OK] Todas as condicoes atendidas! Compound pode ser executado.");
        }
    }
}

