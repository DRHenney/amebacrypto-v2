// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Script, console2} from "forge-std/Script.sol";
import {AutoCompoundHook} from "../src/hooks/AutoCompoundHook.sol";
import {IERC20} from "forge-std/interfaces/IERC20.sol";

/// @notice Script para verificar protocol fees e feeRecipient
contract CheckProtocolFees is Script {
    function run() external view {
        address hookAddress = vm.envAddress("HOOK_ADDRESS");
        AutoCompoundHook hook = AutoCompoundHook(hookAddress);
        
        console2.log("=== Protocol Fees Configuration ===");
        console2.log("Hook Address:", hookAddress);
        console2.log("");
        
        // Verificar configurações
        address feeRecipient = hook.feeRecipient();
        uint256 protocolFeePercent = hook.protocolFeePercent();
        
        console2.log("Fee Recipient:", feeRecipient);
        console2.log("Protocol Fee Percent:", protocolFeePercent, "(base 10000)");
        console2.log("Protocol Fee Percent (%):", protocolFeePercent / 100, "%");
        console2.log("");
        
        // Verificar saldo de USDC no hook
        address usdcAddress = hook.USDC();
        IERC20 usdc = IERC20(usdcAddress);
        uint256 hookUSDCBalance = usdc.balanceOf(hookAddress);
        
        console2.log("=== Hook Balances ===");
        console2.log("USDC Address:", usdcAddress);
        console2.log("Hook USDC Balance:", hookUSDCBalance);
        console2.log("");
        
        // Verificar saldo de USDC no feeRecipient
        uint256 recipientUSDCBalance = usdc.balanceOf(feeRecipient);
        
        console2.log("=== Fee Recipient Balances ===");
        console2.log("Fee Recipient Address:", feeRecipient);
        console2.log("Fee Recipient USDC Balance:", recipientUSDCBalance);
        console2.log("");
        
        // Verificar se há protocol fees acumuladas
        // (isso seria em variáveis de estado, mas não temos acesso direto)
        console2.log("=== Verificacao ===");
        if (hookUSDCBalance > 0) {
            console2.log("[AVISO] Hook ainda tem USDC balance!");
            console2.log("Protocol fees podem nao ter sido transferidos.");
        } else {
            console2.log("[OK] Hook nao tem USDC balance");
        }
        
        if (recipientUSDCBalance > 0) {
            console2.log("[OK] Fee Recipient recebeu USDC!");
        } else {
            console2.log("[AVISO] Fee Recipient nao tem USDC balance");
            console2.log("Protocol fees podem nao ter sido transferidos.");
        }
    }
}
