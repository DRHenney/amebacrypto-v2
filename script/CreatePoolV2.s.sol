// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Script, console2} from "forge-std/Script.sol";
import {IPoolManager} from "@uniswap/v4-core/src/interfaces/IPoolManager.sol";
import {PoolKey} from "@uniswap/v4-core/src/types/PoolKey.sol";
import {Currency, CurrencyLibrary} from "@uniswap/v4-core/src/types/Currency.sol";
import {IHooks} from "@uniswap/v4-core/src/interfaces/IHooks.sol";
import {TickMath} from "@uniswap/v4-core/src/libraries/TickMath.sol";
import {StateLibrary} from "@uniswap/v4-core/src/libraries/StateLibrary.sol";
import {PoolId, PoolIdLibrary} from "@uniswap/v4-core/src/types/PoolId.sol";
import {AutoCompoundHook} from "../src/hooks/AutoCompoundHook.sol";

/// @notice Script para criar NOVA pool USDC/WETH com hook v2
/// @dev Usa fee 5000 (0.5%) para garantir pool diferente da anterior
contract CreatePoolV2 is Script {
    using PoolIdLibrary for PoolKey;
    using CurrencyLibrary for Currency;
    using StateLibrary for IPoolManager;
    
    // Endereços dos tokens em Sepolia
    address constant USDC_SEPOLIA = 0x1c7D4B196Cb0C7B01d743Fbc6116a902379C7238;
    address constant WETH_SEPOLIA = 0xfFf9976782d46CC05630D1f6eBAb18b2324d6B14;
    
    function run() external {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        address poolManagerAddress = vm.envAddress("POOL_MANAGER");
        address hookAddress = vm.envAddress("HOOK_ADDRESS");
        
        IPoolManager poolManager = IPoolManager(poolManagerAddress);
        AutoCompoundHook hook = AutoCompoundHook(hookAddress);
        
        // Criar PoolKey (tokens em ordem crescente)
        Currency currency0 = Currency.wrap(USDC_SEPOLIA < WETH_SEPOLIA ? USDC_SEPOLIA : WETH_SEPOLIA);
        Currency currency1 = Currency.wrap(USDC_SEPOLIA < WETH_SEPOLIA ? WETH_SEPOLIA : USDC_SEPOLIA);
        
        // NOVA pool com fee 10000 (1.0%) para garantir pool diferente do hook antigo
        PoolKey memory poolKey = PoolKey({
            currency0: currency0,
            currency1: currency1,
            fee: 10000, // 1.0% (diferente da pool anterior com hook antigo)
            tickSpacing: 60,
            hooks: IHooks(hookAddress) // Hook v2 atualizado
        });
        
        PoolId poolId = poolKey.toId();
        
        console2.log("=== Criando NOVA Pool USDC/WETH com Hook v2 ===");
        console2.log("PoolManager:", address(poolManager));
        console2.log("Hook v2:", hookAddress);
        console2.log("USDC:", Currency.unwrap(currency0) == USDC_SEPOLIA ? Currency.unwrap(currency0) : Currency.unwrap(currency1));
        console2.log("WETH:", Currency.unwrap(currency0) == WETH_SEPOLIA ? Currency.unwrap(currency0) : Currency.unwrap(currency1));
        console2.log("Fee: 10000 (1.0%)");
        console2.log("Tick Spacing: 60");
        console2.log("Pool ID:", vm.toString(uint256(PoolId.unwrap(poolId))));
        console2.log("");
        
        vm.startBroadcast(deployerPrivateKey);
        
        // Verificar se pool já existe
        (uint160 sqrtPriceX96,,,) = StateLibrary.getSlot0(poolManager, poolId);
        
        if (sqrtPriceX96 == 0) {
            // Inicializar pool
            // Preço inicial: 1 USDC = 0.0003 WETH (aproximadamente $3000/WETH)
            uint160 initialSqrtPrice = uint160(340275971719517849884124397208085282957798792);
            
            console2.log("=== Inicializando Pool ===");
            int24 tick = poolManager.initialize(poolKey, initialSqrtPrice);
            console2.log("Pool inicializada!");
            console2.log("Initial Tick:", tick);
            console2.log("");
        } else {
            console2.log("Pool ja existe, pulando inicializacao");
            console2.log("");
        }
        
        // Configurar hook v2
        console2.log("=== Configurando Hook v2 ===");
        
        // Habilitar pool
        hook.setPoolConfig(poolKey, true);
        console2.log("Pool habilitada no hook v2");
        
        // Configurar preços USD (USDC = $1, WETH = $3000)
        hook.setTokenPricesUSD(poolKey, 1e18, 3000e18);
        console2.log("Precos configurados: USDC=$1, WETH=$3000");
        
        // Configurar tick range (full range)
        int24 tickLower = TickMath.minUsableTick(60);
        int24 tickUpper = TickMath.maxUsableTick(60);
        hook.setPoolTickRange(poolKey, tickLower, tickUpper);
        console2.log("Tick range configurado: full range");
        console2.log("");
        
        console2.log("=== Pool v2 Criada e Configurada ===");
        console2.log("");
        console2.log("Proximos passos:");
        console2.log("1. Adicionar liquidez usando AddLiquidity.s.sol");
        console2.log("2. Configurar keeper para compound automatico");
        console2.log("3. Monitorar eventos com monitor-eventos.ps1");
        console2.log("");
        console2.log("Pool ID:", vm.toString(uint256(PoolId.unwrap(poolId))));
        console2.log("Hook v2 Address:", hookAddress);
        console2.log("PoolManager:", address(poolManager));
        
        vm.stopBroadcast();
    }
}

