// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Script, console2} from "forge-std/Script.sol";
import {IPoolManager} from "@uniswap/v4-core/src/interfaces/IPoolManager.sol";
import {PoolKey} from "@uniswap/v4-core/src/types/PoolKey.sol";
import {Currency, CurrencyLibrary} from "@uniswap/v4-core/src/types/Currency.sol";
import {IHooks} from "@uniswap/v4-core/src/interfaces/IHooks.sol";
import {StateLibrary} from "@uniswap/v4-core/src/libraries/StateLibrary.sol";
import {PoolId, PoolIdLibrary} from "@uniswap/v4-core/src/types/PoolId.sol";

/// @notice Script para verificar se a pool USDC/WETH foi criada
contract VerifyPoolExists is Script {
    using PoolIdLibrary for PoolKey;
    using CurrencyLibrary for Currency;
    using StateLibrary for IPoolManager;
    
    // Endereços dos tokens em Sepolia
    address constant USDC_SEPOLIA = 0x1c7D4B196Cb0C7B01d743Fbc6116a902379C7238;
    address constant WETH_SEPOLIA = 0xfFf9976782d46CC05630D1f6eBAb18b2324d6B14;
    
    function run() external view {
        address poolManagerAddress = vm.envAddress("POOL_MANAGER");
        address hookAddress = vm.envAddress("HOOK_ADDRESS");
        
        IPoolManager poolManager = IPoolManager(poolManagerAddress);
        
        // Criar PoolKey (tokens em ordem crescente)
        Currency currency0 = Currency.wrap(USDC_SEPOLIA < WETH_SEPOLIA ? USDC_SEPOLIA : WETH_SEPOLIA);
        Currency currency1 = Currency.wrap(USDC_SEPOLIA < WETH_SEPOLIA ? WETH_SEPOLIA : USDC_SEPOLIA);
        
        PoolKey memory poolKey = PoolKey({
            currency0: currency0,
            currency1: currency1,
            fee: 3000, // 0.3%
            tickSpacing: 60,
            hooks: IHooks(hookAddress)
        });
        
        PoolId poolId = poolKey.toId();
        
        console2.log("=== Verificando Pool USDC/WETH ===");
        console2.log("PoolManager:", address(poolManager));
        console2.log("Hook:", hookAddress);
        console2.log("Pool ID:", vm.toString(uint256(PoolId.unwrap(poolId))));
        console2.log("");
        
        // Verificar se pool existe (slot0.sqrtPriceX96 != 0)
        (uint160 sqrtPriceX96, int24 tick, uint24 protocolFee, uint24 lpFee) = StateLibrary.getSlot0(poolManager, poolId);
        
        console2.log("=== Resultado da Verificacao ===");
        
        if (sqrtPriceX96 == 0) {
            console2.log("Status: POOL NAO EXISTE");
            console2.log("sqrtPriceX96: 0");
            console2.log("");
            console2.log("A pool ainda nao foi inicializada.");
            console2.log("Execute: forge script script/CreatePoolUSDCWETH.s.sol:CreatePoolUSDCWETH --rpc-url sepolia --broadcast");
        } else {
            console2.log("Status: POOL EXISTE!");
            console2.log("sqrtPriceX96:", sqrtPriceX96);
            console2.log("Tick:", tick);
            console2.log("Protocol Fee:", protocolFee);
            console2.log("LP Fee:", lpFee);
            console2.log("");
            console2.log("A pool foi criada com sucesso!");
        }
    }
}

