// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Script, console2} from "forge-std/Script.sol";
import {AutoCompoundHook} from "../src/hooks/AutoCompoundHook.sol";
import {PoolKey} from "@uniswap/v4-core/src/types/PoolKey.sol";
import {Currency} from "@uniswap/v4-core/src/types/Currency.sol";
import {IHooks} from "@uniswap/v4-core/src/interfaces/IHooks.sol";
import {PoolId, PoolIdLibrary} from "@uniswap/v4-core/src/types/PoolId.sol";

/// @notice Script para verificar eventos de compound e protocol fees
contract CheckCompoundEvents is Script {
    using PoolIdLibrary for PoolKey;
    
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
            fee: 3000, // 0.3%
            tickSpacing: 60,
            hooks: IHooks(hookAddress)
        });
        
        PoolId poolId = poolKey.toId();
        
        console2.log("=== Verificando Ultimo Compound ===");
        console2.log("Pool ID:", vm.toString(uint256(PoolId.unwrap(poolId))));
        console2.log("");
        
        // Verificar lastCompoundTimestamp
        uint256 lastCompound = hook.lastCompoundTimestamp(poolId);
        console2.log("Last Compound Timestamp:", lastCompound);
        if (lastCompound > 0) {
            console2.log("Last Compound (block.timestamp):", block.timestamp);
            console2.log("Tempo desde ultimo compound:", block.timestamp - lastCompound, "segundos");
        }
        console2.log("");
        
        // Verificar fees acumuladas (deve ser 0 se compound foi executado)
        (, uint256 fees0, uint256 fees1,,) = hook.getPoolInfo(poolKey);
        console2.log("=== Fees Atuais ===");
        console2.log("Fees0 (USDC):", fees0);
        console2.log("Fees1 (WETH):", fees1);
        console2.log("");
        
        if (fees0 == 0 && fees1 == 0 && lastCompound > 0) {
            console2.log("[OK] Fees foram resetadas - compound foi executado!");
        } else if (fees0 > 0 || fees1 > 0) {
            console2.log("[AVISO] Ainda ha fees acumuladas - compound pode nao ter sido executado completamente.");
        }
        console2.log("");
        
        // Calcular protocol fees que deveriam ter sido enviados
        uint256 protocolFeePercent = hook.protocolFeePercent();
        console2.log("=== Calculo de Protocol Fees ===");
        console2.log("Protocol Fee Percent:", protocolFeePercent);
        console2.log("Protocol Fee Percent (%):", protocolFeePercent / 100);
        console2.log("");
        console2.log("Se fees antes do compound eram:");
        console2.log("  Fees0: 54,000 wei USDC");
        console2.log("  Fees1: 54,000,000,000,000 wei WETH");
        console2.log("");
        console2.log("Protocol fees deveriam ser:");
        uint256 expectedProtocolFee0 = (54000 * protocolFeePercent) / 10000;
        uint256 expectedProtocolFee1 = (54000000000000 * protocolFeePercent) / 10000;
        console2.log("  Protocol Fee0 (USDC):", expectedProtocolFee0, "wei =", expectedProtocolFee0 / 1e6, "USDC");
        console2.log("  Protocol Fee1 (WETH):", expectedProtocolFee1, "wei =", expectedProtocolFee1 / 1e18, "WETH");
        console2.log("");
        console2.log("[AVISO] Valores muito pequenos podem nao ser transferidos corretamente.");
    }
}

