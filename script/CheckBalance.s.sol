// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Script, console2} from "forge-std/Script.sol";
import {IERC20Minimal} from "@uniswap/v4-core/src/interfaces/external/IERC20Minimal.sol";

/// @notice Script para verificar saldos de tokens na carteira
contract CheckBalance is Script {
    function run() external view {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        address deployer = vm.addr(deployerPrivateKey);
        address token0Address = vm.envAddress("TOKEN0_ADDRESS");
        address token1Address = vm.envAddress("TOKEN1_ADDRESS");
        
        // Get liquidity amounts from env
        uint256 requiredToken0 = vm.envUint("LIQUIDITY_TOKEN0_AMOUNT");
        uint256 requiredToken1 = vm.envUint("LIQUIDITY_TOKEN1_AMOUNT");
        
        console2.log("=== Verificando Saldos ===");
        console2.log("Carteira:", deployer);
        console2.log("");
        
        // Check Token0 (USDC) balance
        IERC20Minimal token0 = IERC20Minimal(token0Address);
        uint256 balance0 = token0.balanceOf(deployer);
        console2.log("Token0 (USDC):", token0Address);
        console2.log("  Saldo:", balance0);
        console2.log("  Requerido:", requiredToken0);
        if (balance0 >= requiredToken0) {
            console2.log("  [OK] Saldo suficiente!");
        } else {
            console2.log("  [ERRO] Saldo insuficiente!");
            console2.log("  Faltam:", requiredToken0 - balance0);
        }
        console2.log("");
        
        // Check Token1 (WETH) balance
        IERC20Minimal token1 = IERC20Minimal(token1Address);
        uint256 balance1 = token1.balanceOf(deployer);
        console2.log("Token1 (WETH):", token1Address);
        console2.log("  Saldo:", balance1);
        console2.log("  Requerido:", requiredToken1);
        if (balance1 >= requiredToken1) {
            console2.log("  [OK] Saldo suficiente!");
        } else {
            console2.log("  [ERRO] Saldo insuficiente!");
            console2.log("  Faltam:", requiredToken1 - balance1);
        }
        console2.log("");
        
        // Summary
        console2.log("=== Resumo ===");
        if (balance0 >= requiredToken0 && balance1 >= requiredToken1) {
            console2.log("[OK] Saldos suficientes para adicionar liquidez!");
        } else {
            console2.log("[ERRO] Saldos insuficientes!");
            console2.log("Precisa obter mais tokens antes de adicionar liquidez.");
        }
    }
}
