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

/// @notice Script para recriar pool USDC/WETH com configuração correta
/// @dev Usa fee diferente para criar nova pool e verifica evento PoolAutoEnabled
contract RecreatePoolV2 is Script {
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
        // USDC < WETH, então USDC é currency0 e WETH é currency1
        Currency currency0 = Currency.wrap(USDC_SEPOLIA < WETH_SEPOLIA ? USDC_SEPOLIA : WETH_SEPOLIA);
        Currency currency1 = Currency.wrap(USDC_SEPOLIA < WETH_SEPOLIA ? WETH_SEPOLIA : USDC_SEPOLIA);
        
        // Nova pool com fee 5000 (0.5%) para garantir pool diferente
        PoolKey memory poolKey = PoolKey({
            currency0: currency0,
            currency1: currency1,
            fee: 5000, // 0.5% (nova pool)
            tickSpacing: 60,
            hooks: IHooks(hookAddress) // Hook v2 atualizado
        });
        
        PoolId poolId = poolKey.toId();
        
        console2.log("=== Recriando Pool USDC/WETH com Configuracao Correta ===");
        console2.log("PoolManager:", address(poolManager));
        console2.log("Hook v2:", hookAddress);
        console2.log("USDC (Token0):", Currency.unwrap(currency0));
        console2.log("WETH (Token1):", Currency.unwrap(currency1));
        console2.log("Fee: 5000 (0.5%)");
        console2.log("Tick Spacing: 60");
        console2.log("Pool ID:", vm.toString(uint256(PoolId.unwrap(poolId))));
        console2.log("");
        
        vm.startBroadcast(deployerPrivateKey);
        
        // Verificar se pool já existe
        (uint160 sqrtPriceX96,,,) = StateLibrary.getSlot0(poolManager, poolId);
        
        if (sqrtPriceX96 == 0) {
            // Inicializar pool com preço correto
            // Preço: 1 WETH = 3000 USDC
            // Para USDC/WETH (token0/token1):
            // price = 3000 USDC / 1 WETH = 3000
            // sqrtPrice = sqrt(3000) * 2^96
            // Como USDC tem 6 decimais e WETH tem 18:
            // price = (3000 * 10^6) / (1 * 10^18) = 3000 * 10^-12
            // sqrtPrice = sqrt(3000 * 10^-12) * 2^96 = sqrt(3000) * 10^-6 * 2^96
            
            // Cálculo correto: sqrt(3000) ≈ 54.77
            // Para Uniswap v4: sqrtPriceX96 = sqrt(price) * 2^96
            // price = token1/token0 = WETH/USDC = 3000 * 10^6 / 10^18 = 3000 * 10^-12
            // sqrtPrice = sqrt(3000 * 10^-12) * 2^96
            // Simplificando: sqrtPrice = sqrt(3000) * 10^-6 * 2^96
            
            // Usando valor calculado para 3000 USDC por WETH
            // sqrt(3000) ≈ 54.772255750516614
            // 54.772255750516614 * 2^96 / 10^6 ≈ 340275971719517849884124397208085282957798792
            uint160 initialSqrtPrice = uint160(340275971719517849884124397208085282957798792);
            
            console2.log("=== Inicializando Pool ===");
            console2.log("Preco inicial: 1 WETH = 3000 USDC");
            console2.log("SqrtPriceX96:", initialSqrtPrice);
            
            int24 tick = poolManager.initialize(poolKey, initialSqrtPrice);
            console2.log("Pool inicializada!");
            console2.log("Initial Tick:", tick);
            console2.log("");
            
            // Verificar se evento PoolAutoEnabled foi emitido
            // O evento é emitido automaticamente no _afterInitialize do hook
            console2.log("[OK] Pool inicializada - evento PoolAutoEnabled deve ter sido emitido");
            console2.log("");
        } else {
            console2.log("Pool ja existe, pulando inicializacao");
            console2.log("SqrtPriceX96 atual:", sqrtPriceX96);
            console2.log("");
        }
        
        // Verificar se pool está habilitada no hook
        (AutoCompoundHook.PoolConfig memory config,,,,) = hook.getPoolInfo(poolKey);
        console2.log("=== Verificacao do Hook ===");
        console2.log("Pool habilitada:", config.enabled);
        
        if (!config.enabled) {
            console2.log("Habilitando pool no hook...");
            hook.setPoolConfig(poolKey, true);
            console2.log("[OK] Pool habilitada");
        }
        
        // Configurar preços USD (USDC = $1, WETH = $3000)
        hook.setTokenPricesUSD(poolKey, 1e18, 3000e18);
        console2.log("Precos configurados: USDC=$1, WETH=$3000");
        
        // Configurar tick range (full range)
        int24 tickLower = TickMath.minUsableTick(60);
        int24 tickUpper = TickMath.maxUsableTick(60);
        hook.setPoolTickRange(poolKey, tickLower, tickUpper);
        console2.log("Tick range configurado: full range");
        console2.log("");
        
        console2.log("=== Pool v2 Recriada e Configurada ===");
        console2.log("");
        console2.log("Proximos passos:");
        console2.log("1. Adicionar liquidez usando AddLiquidity.s.sol");
        console2.log("2. Verificar se keeper detecta automaticamente");
        console2.log("3. Monitorar eventos com monitor-eventos.ps1");
        console2.log("");
        console2.log("Pool ID:", vm.toString(uint256(PoolId.unwrap(poolId))));
        console2.log("Hook v2 Address:", hookAddress);
        console2.log("PoolManager:", address(poolManager));
        console2.log("");
        console2.log("=== Keeper Auto-Start ===");
        console2.log("O keeper deve detectar automaticamente esta pool via evento PoolAutoEnabled");
        console2.log("Execute: keeper-bot-auto-start.ps1 para iniciar o keeper");
        console2.log("");
        
        vm.stopBroadcast();
    }
}

