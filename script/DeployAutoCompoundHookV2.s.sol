// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Script, console2} from "forge-std/Script.sol";
import {AutoCompoundHook} from "../src/hooks/AutoCompoundHook.sol";
import {IPoolManager} from "@uniswap/v4-core/src/interfaces/IPoolManager.sol";
import {Hooks} from "@uniswap/v4-core/src/libraries/Hooks.sol";
import {HookMiner} from "v4-periphery/src/utils/HookMiner.sol";

/// @title DeployAutoCompoundHookV2
/// @notice Script de deploy do AutoCompoundHook v2 com configurações globais
contract DeployAutoCompoundHookV2 is Script {
    address constant CREATE2_DEPLOYER = address(0x4e59b44847b379578588920cA78FbF26c0B4956C);

    function run() external {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        address poolManager = vm.envAddress("POOL_MANAGER");
        
        // Configurações opcionais (usar valores padrão se não especificadas)
        uint256 thresholdMultiplier = vm.envOr("THRESHOLD_MULTIPLIER", uint256(20));
        uint256 minTimeInterval = vm.envOr("MIN_TIME_INTERVAL", uint256(4 hours));
        uint256 protocolFeePercent = vm.envOr("PROTOCOL_FEE_PERCENT", uint256(1000)); // 10%
        address feeRecipient = vm.envOr("FEE_RECIPIENT", address(0xd9D3e3C7dc4F5d058ff24C0b71cF68846316F65c));
        
        vm.startBroadcast(deployerPrivateKey);

        console2.log("=== Deploying AutoCompoundHook v2 ===");
        console2.log("PoolManager:", poolManager);
        console2.log("Threshold Multiplier:", thresholdMultiplier);
        console2.log("Min Time Interval:", minTimeInterval, "seconds");
        console2.log("Protocol Fee Percent:", protocolFeePercent, "(base 10000)");
        console2.log("Fee Recipient:", feeRecipient);
        console2.log("");

        // Minerar um endereço válido para o hook
        uint160 flags = uint160(
            Hooks.AFTER_INITIALIZE_FLAG |
            Hooks.AFTER_ADD_LIQUIDITY_FLAG |
            Hooks.AFTER_REMOVE_LIQUIDITY_FLAG |
            Hooks.AFTER_SWAP_FLAG
        );

        address deployerAddress = vm.addr(deployerPrivateKey);
        bytes memory constructorArgs = abi.encode(IPoolManager(address(poolManager)), deployerAddress);

        console2.log("Mining hook address...");
        (address hookAddress, bytes32 salt) = HookMiner.find(
            CREATE2_DEPLOYER,
            flags,
            type(AutoCompoundHook).creationCode,
            constructorArgs
        );

        console2.log("Hook address found:", hookAddress);
        console2.log("Salt:", vm.toString(salt));
        console2.log("");

        // Deploy do hook usando CREATE2 com o salt minerado
        console2.log("Deploying hook...");
        AutoCompoundHook hook = new AutoCompoundHook{salt: salt}(
            IPoolManager(address(poolManager)),
            deployerAddress
        );

        console2.log("Hook deployed successfully!");
        console2.log("");

        // Configurar valores se diferentes dos padrões
        if (thresholdMultiplier != 20) {
            console2.log("Setting threshold multiplier to:", thresholdMultiplier);
            hook.setThresholdMultiplier(thresholdMultiplier);
        }
        
        if (minTimeInterval != 4 hours) {
            console2.log("Setting min time interval to:", minTimeInterval, "seconds");
            hook.setMinTimeInterval(minTimeInterval);
        }
        
        if (protocolFeePercent != 1000) {
            console2.log("Setting protocol fee percent to:", protocolFeePercent);
            hook.setProtocolFeePercent(protocolFeePercent);
        }
        
        if (feeRecipient != address(0xd9D3e3C7dc4F5d058ff24C0b71cF68846316F65c)) {
            console2.log("Setting fee recipient to:", feeRecipient);
            hook.setFeeRecipient(feeRecipient);
        }

        vm.stopBroadcast();

        // Resumo final
        console2.log("\n=== Deploy Summary ===");
        console2.log("Hook Address:", address(hook));
        console2.log("PoolManager:", poolManager);
        console2.log("Owner:", hook.owner());
        console2.log("Threshold Multiplier:", hook.thresholdMultiplier());
        console2.log("Min Time Interval:", hook.minTimeBetweenCompounds(), "seconds");
        console2.log("Protocol Fee Percent:", hook.protocolFeePercent(), "(base 10000)");
        console2.log("Fee Recipient:", hook.feeRecipient());
        console2.log("======================");
        console2.log("");
        console2.log("Next steps:");
        console2.log("1. Configure pool settings using setPoolConfig()");
        console2.log("2. Set token prices using setTokenPricesUSD()");
        console2.log("3. Set tick range using setPoolTickRange()");
        console2.log("4. Create pool with this hook address");
    }
}

