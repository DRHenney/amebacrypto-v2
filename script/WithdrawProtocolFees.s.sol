// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Script, console2} from "forge-std/Script.sol";
import {AutoCompoundHook} from "../src/hooks/AutoCompoundHook.sol";
import {PoolKey} from "@uniswap/v4-core/src/types/PoolKey.sol";
import {Currency} from "@uniswap/v4-core/src/types/Currency.sol";
import {IHooks} from "@uniswap/v4-core/src/interfaces/IHooks.sol";
import {PoolId, PoolIdLibrary} from "@uniswap/v4-core/src/types/PoolId.sol";

/// @notice Script para retirar protocol fees acumuladas manualmente
contract WithdrawProtocolFees is Script {
    using PoolIdLibrary for PoolKey;
    
    function run() external {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
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
        
        console2.log("=== Withdraw Protocol Fees ===");
        console2.log("Hook Address:", hookAddress);
        console2.log("Fee Recipient:", hook.feeRecipient());
        console2.log("");
        
        // Verificar protocol fees acumuladas
        uint128 protocolFee0 = hook.protocolFeeToken0();
        uint128 protocolFee1 = hook.protocolFeeToken1();
        
        console2.log("Protocol Fees Acumuladas:");
        console2.log("  Token0:", protocolFee0);
        console2.log("  Token1:", protocolFee1);
        console2.log("");
        
        if (protocolFee0 == 0 && protocolFee1 == 0) {
            console2.log("[AVISO] Nao ha protocol fees acumuladas para retirar");
            return;
        }
        
        vm.startBroadcast(deployerPrivateKey);
        
        // Chamar withdrawProtocolFees (função do owner)
        hook.withdrawProtocolFees(poolKey);
        
        console2.log("[OK] Protocol fees retiradas e enviadas para feeRecipient");
        
        vm.stopBroadcast();
    }
}
