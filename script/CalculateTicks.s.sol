// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Script, console2} from "forge-std/Script.sol";
import {TickMath} from "@uniswap/v4-core/src/libraries/TickMath.sol";

/// @notice Script para calcular ticks exatos para range de preço
/// @dev Calcula ticks para range 1500-4500 USD/WETH
/// @dev Para USDC/WETH: price = amount1/amount0 = WETH/USDC
contract CalculateTicks is Script {
    function run() external {
        // Para USDC/WETH (currency0=USDC, currency1=WETH):
        // price = WETH/USDC = amount1/amount0
        // Lower: 1500 USDC por WETH = 1/1500 WETH por USDC
        // Upper: 4500 USDC por WETH = 1/4500 WETH por USDC
        // 
        // Mas na Uniswap, o preço é calculado como: price = amount1/amount0
        // Se 1 WETH = 1500 USDC, então price = 1500/1 = 1500 (em unidades de USDC)
        // sqrtPriceX96 = sqrt(price) * 2^96
        
        // Preços em unidades base (assumindo 18 decimais para ambos)
        // price = 1500 significa 1500e18 / 1e18 = 1500
        uint256 priceLower = 1500; // 1500 USDC por WETH
        uint256 priceUpper = 4500; // 4500 USDC por WETH
        
        // Calcular sqrtPriceX96
        // sqrtPriceX96 = sqrt(price) * 2^96
        // Usar aproximação: sqrt(price * 2^192) = sqrt(price) * 2^96
        uint256 priceLowerScaled = priceLower * 2**192;
        uint256 priceUpperScaled = priceUpper * 2**192;
        
        uint160 sqrtPriceLowerX96 = uint160(sqrt(priceLowerScaled));
        uint160 sqrtPriceUpperX96 = uint160(sqrt(priceUpperScaled));
        
        // Calcular ticks usando TickMath
        int24 tickLower = TickMath.getTickAtSqrtPrice(sqrtPriceLowerX96);
        int24 tickUpper = TickMath.getTickAtSqrtPrice(sqrtPriceUpperX96);
        
        console2.log("=== Ticks Calculados para Range 1500-4500 USD ===");
        console2.log("Pool: USDC/WETH (currency0=USDC, currency1=WETH)");
        console2.log("Price Lower: 1500 USDC/WETH");
        console2.log("Price Upper: 4500 USDC/WETH");
        console2.log("");
        console2.log("Tick Lower:", tickLower);
        console2.log("Tick Upper:", tickUpper);
        console2.log("");
        console2.log("SqrtPrice Lower (X96):", sqrtPriceLowerX96);
        console2.log("SqrtPrice Upper (X96):", sqrtPriceUpperX96);
        console2.log("");
        console2.log("=== Valores para usar no contrato ===");
        console2.log("initialTickLower:", tickLower);
        console2.log("initialTickUpper:", tickUpper);
    }
    
    function sqrt(uint256 x) internal pure returns (uint256) {
        if (x == 0) return 0;
        uint256 z = (x + 1) / 2;
        uint256 y = x;
        while (z < y) {
            y = z;
            z = (x / z + z) / 2;
        }
        return y;
    }
}

