// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Script, console2} from "forge-std/Script.sol";
import {IPoolManager} from "@uniswap/v4-core/src/interfaces/IPoolManager.sol";
import {PoolKey} from "@uniswap/v4-core/src/types/PoolKey.sol";
import {Currency, CurrencyLibrary} from "@uniswap/v4-core/src/types/Currency.sol";
import {IHooks} from "@uniswap/v4-core/src/interfaces/IHooks.sol";
import {PoolId, PoolIdLibrary} from "@uniswap/v4-core/src/types/PoolId.sol";
import {AutoCompoundHook} from "../src/hooks/AutoCompoundHook.sol";
import {CompoundHelper} from "../src/helpers/CompoundHelper.sol";
import {ModifyLiquidityParams} from "@uniswap/v4-core/src/types/PoolOperation.sol";
import {BalanceDelta} from "@uniswap/v4-core/src/types/BalanceDelta.sol";
import {IERC20Minimal} from "@uniswap/v4-core/src/interfaces/external/IERC20Minimal.sol";

/// @notice Keeper compatível com Gelato Network
/// @dev Esta função pode ser chamada pelo Gelato para executar compound automaticamente
/// @dev O Gelato paga o gas e executa quando as condições são atendidas
contract GelatoKeeper is Script {
    using PoolIdLibrary for PoolKey;
    using CurrencyLibrary for Currency;
    
    /// @notice Função principal chamada pelo Gelato
    /// @dev Gelato chama esta função periodicamente
    /// @return canExec Se o compound pode ser executado
    /// @return execData Dados para execução (se canExec = true)
    function checkAndExecuteCompound() external returns (bool canExec, bytes memory execData) {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
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
        
        // Verificar se pode executar
        (bool canCompound, , , , ) = hook.canExecuteCompound(poolKey);
        
        if (!canCompound) {
            return (false, "");
        }
        
        // Preparar compound
        (bool canPrepare, ModifyLiquidityParams memory params, uint256 fees0, uint256 fees1) = 
            hook.prepareCompound(poolKey);
        
        if (!canPrepare) {
            return (false, "");
        }
        
        // Preparar dados para execução
        // O Gelato executará executeCompoundGelato com estes dados
        execData = abi.encodeWithSelector(
            this.executeCompoundGelato.selector,
            poolKey,
            params,
            fees0,
            fees1
        );
        
        return (true, execData);
    }
    
    /// @notice Executa o compound (chamado pelo Gelato)
    /// @dev Esta função é executada pelo Gelato quando canExec = true
    function executeCompoundGelato(
        PoolKey calldata poolKey,
        ModifyLiquidityParams memory params,
        uint256 fees0,
        uint256 fees1
    ) external {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        address poolManagerAddress = vm.envAddress("POOL_MANAGER");
        address hookAddress = vm.envAddress("HOOK_ADDRESS");
        
        IPoolManager poolManager = IPoolManager(poolManagerAddress);
        AutoCompoundHook hook = AutoCompoundHook(hookAddress);
        
        vm.startBroadcast(deployerPrivateKey);
        
        // Deploy ou usar CompoundHelper existente
        CompoundHelper helper = new CompoundHelper(poolManager, hook);
        
        // Aprovar tokens
        address token0 = Currency.unwrap(poolKey.currency0);
        address token1 = Currency.unwrap(poolKey.currency1);
        IERC20Minimal(token0).approve(address(helper), type(uint256).max);
        IERC20Minimal(token1).approve(address(helper), type(uint256).max);
        
        // Executar compound
        helper.executeCompound(poolKey, params, fees0, fees1);
        
        vm.stopBroadcast();
    }
}

