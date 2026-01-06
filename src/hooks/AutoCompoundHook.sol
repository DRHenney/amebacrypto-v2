// SPDX-License-Identifier: GPL-2.0-or-later
pragma solidity ^0.8.24;

import {PoolKey} from "@uniswap/v4-core/src/types/PoolKey.sol";
import {PoolId, PoolIdLibrary} from "@uniswap/v4-core/src/types/PoolId.sol";
import {Currency} from "@uniswap/v4-core/src/types/Currency.sol";
import {IPoolManager} from "@uniswap/v4-core/src/interfaces/IPoolManager.sol";
import {BalanceDelta, BalanceDeltaLibrary, toBalanceDelta} from "@uniswap/v4-core/src/types/BalanceDelta.sol";
import {Hooks} from "@uniswap/v4-core/src/libraries/Hooks.sol";
import {BaseHook} from "lib/v4-periphery/src/utils/BaseHook.sol";
import {BeforeSwapDelta} from "@uniswap/v4-core/src/types/BeforeSwapDelta.sol";
import {ModifyLiquidityParams, SwapParams} from "@uniswap/v4-core/src/types/PoolOperation.sol";
import {IERC20} from "forge-std/interfaces/IERC20.sol";
import {LiquidityAmounts} from "@uniswap/v4-periphery/src/libraries/LiquidityAmounts.sol";
import {TickMath} from "@uniswap/v4-core/src/libraries/TickMath.sol";
import {StateLibrary} from "@uniswap/v4-core/src/libraries/StateLibrary.sol";
import {SafeCast} from "@uniswap/v4-core/src/libraries/SafeCast.sol";

/// @title AutoCompoundHook
/// @notice Hook que automaticamente reinveste taxas acumuladas na pool
/// @dev Implementa o padrão de auto-compound para maximizar retornos
contract AutoCompoundHook is BaseHook {
    using PoolIdLibrary for PoolKey;
    using StateLibrary for IPoolManager;

    // Eventos
    event FeesCompounded(PoolId indexed poolId, uint256 amount0, uint256 amount1);
    
    /// @notice Emitido quando compound é executado com sucesso
    /// @param poolId ID da pool
    /// @param fees0 Quantidade de fees0 reinvestidas
    /// @param fees1 Quantidade de fees1 reinvestidas
    /// @param liquidityDelta Liquidez adicionada na pool
    /// @param gasUsed Gas usado na transação (estimado)
    /// @param feesValueUSD Valor total das fees em USD
    /// @param timestamp Timestamp do compound
    event CompoundExecuted(
        PoolId indexed poolId,
        uint256 fees0,
        uint256 fees1,
        int128 liquidityDelta,
        uint256 gasUsed,
        uint256 feesValueUSD,
        uint256 timestamp
    );
    
    /// @notice Emitido quando fees são acumuladas após um swap
    /// @param poolId ID da pool
    /// @param fees0 Fees acumuladas em token0
    /// @param fees1 Fees acumuladas em token1
    /// @param totalFees0 Total acumulado de fees0 até agora
    /// @param totalFees1 Total acumulado de fees1 até agora
    /// @param feesValueUSD Valor total das fees acumuladas em USD
    event FeesAccumulated(
        PoolId indexed poolId,
        uint256 fees0,
        uint256 fees1,
        uint256 totalFees0,
        uint256 totalFees1,
        uint256 feesValueUSD
    );
    
    /// @notice Emitido quando compound é preparado mas não pode ser executado
    /// @param poolId ID da pool
    /// @param reason Razão pela qual não pode ser executado
    /// @param fees0 Fees disponíveis em token0
    /// @param fees1 Fees disponíveis em token1
    /// @param timeUntilNext Tempo até próximo compound possível (segundos)
    event CompoundPrepared(
        PoolId indexed poolId,
        string reason,
        uint256 fees0,
        uint256 fees1,
        uint256 timeUntilNext
    );
    
    /// @notice Emitido quando tentativa de compound falha
    /// @param poolId ID da pool
    /// @param reason Razão da falha
    /// @param fees0 Fees que deveriam ser reinvestidas
    /// @param fees1 Fees que deveriam ser reinvestidas
    event CompoundFailed(
        PoolId indexed poolId,
        string reason,
        uint256 fees0,
        uint256 fees1
    );
    
    event PoolConfigUpdated(PoolId indexed poolId, bool enabled);
    event TokenPricesUpdated(PoolId indexed poolId, uint256 price0USD, uint256 price1USD);
    event PoolTickRangeUpdated(PoolId indexed poolId, int24 tickLower, int24 tickUpper);
    event OwnerUpdated(address indexed oldOwner, address indexed newOwner);
    event ThresholdMultiplierUpdated(uint256 oldValue, uint256 newValue);
    event MinTimeIntervalUpdated(uint256 oldValue, uint256 newValue);
    event ProtocolFeePercentUpdated(uint256 oldValue, uint256 newValue);
    event FeeRecipientUpdated(address indexed oldRecipient, address indexed newRecipient);
    event ProtocolFeesWithdrawn(address indexed recipient, uint128 amount0, uint128 amount1);
    
    /// @notice Emitido quando protocol fees são transferidas automaticamente durante compound
    /// @param protocolFeeRecipient Endereço que recebe as protocol fees
    /// @param protocolAmount0 Quantidade de protocol fee em token0 (antes da conversão para USDC)
    /// @param protocolAmount1 Quantidade de protocol fee em token1 (antes da conversão para USDC)
    event ProtocolFeesTransferred(
        address indexed protocolFeeRecipient,
        uint256 protocolAmount0,
        uint256 protocolAmount1
    );
    
    /// @notice Emitido quando uma pool é inicializada e habilitada automaticamente
    /// @param poolId ID da pool
    /// @param currency0 Token0 da pool
    /// @param currency1 Token1 da pool
    /// @param fee Taxa da pool
    /// @param tickSpacing Tick spacing da pool
    /// @param hookAddress Endereço do hook (este contrato)
    event PoolAutoEnabled(
        PoolId indexed poolId,
        Currency currency0,
        Currency currency1,
        uint24 fee,
        int24 tickSpacing,
        address hookAddress
    );

    // Configurações por pool
    struct PoolConfig {
        bool enabled; // Se o auto-compound está habilitado para esta pool
    }

    // Mapeamento de pool ID para configurações
    mapping(PoolId => PoolConfig) public poolConfigs;

    // Mapeamento para rastrear taxas acumuladas
    mapping(PoolId => uint256) public accumulatedFees0;
    mapping(PoolId => uint256) public accumulatedFees1;
    
    // Protocol fees acumuladas (10% das fees geradas)
    uint128 public protocolFeeToken0;
    uint128 public protocolFeeToken1;

    // Mapeamento para rastrear posições de liquidez (tick ranges) por pool
    // Isso ajuda a saber onde adicionar a liquidez no compound
    mapping(PoolId => int24) public poolTickLower;
    mapping(PoolId => int24) public poolTickUpper;
    
    // Ticks iniciais da pool (usados para compound manter a mesma distribuição)
    mapping(PoolId => int24) public initialTickLower;
    mapping(PoolId => int24) public initialTickUpper;
    mapping(PoolId => bool) public hasInitialTicks;

    // Mapeamento para último timestamp de compound por pool
    mapping(PoolId => uint256) public lastCompoundTimestamp;

    // Mapeamento para preços dos tokens em USD (para cálculo de threshold)
    mapping(PoolId => uint256) public token0PriceUSD;
    mapping(PoolId => uint256) public token1PriceUSD;

    // Mapeamento para armazenar PoolKey de pools intermediárias (token -> USDC)
    // Exemplo: ETH -> PoolKey(ETH, USDC, fee, tickSpacing, hooks)
    mapping(Currency => PoolKey) public intermediatePools;
    
    // Mapeamento para verificar se uma pool intermediária foi configurada
    mapping(Currency => bool) public hasIntermediatePool;

    // Configurações globais (configuráveis pelo owner)
    uint256 public thresholdMultiplier = 20; // 20x o custo de gas
    uint256 public minTimeBetweenCompounds = 4 hours; // 14400 segundos
    uint256 public protocolFeePercent = 1000; // 10% = 1000 (base 10000)
    
    // Endereço para receber protocol fees
    address public feeRecipient = 0xd9D3e3C7dc4F5d058ff24C0b71cF68846316F65c;
    
    /// @notice Retorna o endereço do USDC baseado na rede atual
    /// @dev Endereços USDC por rede (atualizado 26/12/2025)
    /// @return O endereço do USDC na rede atual
    function USDC() public view returns (address) {
        uint256 chainId = block.chainid;
        
        // Ethereum Mainnet
        if (chainId == 1) return 0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48;
        // Sepolia (testnet)
        if (chainId == 11155111) return 0x1c7D4B196Cb0C7B01d743Fbc6116a902379C7238;
        // Arbitrum One
        if (chainId == 42161) return 0xaf88d065e77c8cC2239327C5EDb3A432268e5831;
        // Optimism
        if (chainId == 10) return 0x0b2C639c533813f4Aa9D7837CAf62653d097Ff85;
        // Base
        if (chainId == 8453) return 0x833589fCD6eDb6E08f4c7C32D4f71b54bdA02913;
        // Polygon
        if (chainId == 137) return 0x3c499c542cEF5E3811e1192ce70d8cC03d5c3359;
        // Unichain Mainnet
        if (chainId == 1301) return 0x078D782b760474a361dDA0AF3839290b0EF57AD6;
        // Unichain Sepolia (testnet)
        if (chainId == 13011301) return 0x31d0220469e10c4E71834a79b1f276d740d3768F;
        // zkSync Era
        if (chainId == 324) return 0x3355df6D4c9C3035724Fd0e3914dE96A5a83aaf4;
        // Scroll
        if (chainId == 534352) return 0x06eFdBFf2a14a7c8E15944D1F4A48F9F95F663A4;
        // Linea
        if (chainId == 59144) return 0x176211869cA2b568f2A7D4EE941E073a821EE1ff;
        // BSC (Binance Smart Chain)
        if (chainId == 56) return 0x8AC76a51cc950d9822D68b83fE1Ad97B32Cd580d;
        // Avalanche
        if (chainId == 43114) return 0xB97EF9Ef8734C71904D8002F8b6Bc66Dd9c48a6E;
        
        // Default (revert se rede não suportada)
        revert("USDC not configured for this chain");
    }

    // Endereço do dono/admin (pode ser atualizado)
    address public owner;

    // Modifiers
    modifier onlyOwner() {
        require(msg.sender == owner, "Not owner");
        _;
    }

    constructor(IPoolManager _poolManager, address _owner) BaseHook(_poolManager) {
        require(_owner != address(0), "Invalid owner");
        owner = _owner;
    }

    /// @notice Retorna os flags de hook necessários
    function getHookPermissions() public pure override returns (Hooks.Permissions memory) {
        return Hooks.Permissions({
            beforeInitialize: false,
            afterInitialize: true,
            beforeAddLiquidity: false,
            afterAddLiquidity: true,
            beforeRemoveLiquidity: false,
            afterRemoveLiquidity: true,
            beforeSwap: false,
            afterSwap: true,
            beforeDonate: false,
            afterDonate: false,
            beforeSwapReturnDelta: false,
            afterSwapReturnDelta: false,
            afterAddLiquidityReturnDelta: false,
            afterRemoveLiquidityReturnDelta: false
        });
    }
    
    /// @notice Função helper para acumular taxas
    /// @dev Esta função apenas acumula taxas, não faz compound
    ///      O compound deve ser feito via checkAndCompound() a cada 4 horas
    /// @param key A chave da pool
    /// @param amount0 Quantidade de token0 para acumular
    /// @param amount1 Quantidade de token1 para acumular
    function accumulateFees(
        PoolKey calldata key,
        uint256 amount0,
        uint256 amount1
    ) external {
        PoolId poolId = key.toId();
        PoolConfig memory config = poolConfigs[poolId];
        
        if (!config.enabled) {
            return;
        }
        
        // Apenas acumular taxas (não fazer compound aqui)
        accumulatedFees0[poolId] += amount0;
        accumulatedFees1[poolId] += amount1;
    }

    /// @notice Verifica se compound pode ser executado (mantida para compatibilidade)
    /// @dev Esta função agora apenas verifica - o compound real deve ser feito via helper
    /// @dev ⚠️ DESCONTINUADA: Use prepareCompound() + CompoundHelper.executeCompound() em vez disso
    /// @return executed Sempre retorna false - compound deve ser feito via helper
    function checkAndCompound(PoolKey calldata /* key */) external pure returns (bool executed) {
        // Esta função não executa compound mais - apenas verifica condições
        // O compound real deve ser feito via CompoundHelper usando prepareCompound + executeCompound
        // Mantida para compatibilidade com código existente
        return false;
    }

    /// @notice Configura uma pool para auto-compound
    /// @param key A chave da pool
    /// @param enabled Se o auto-compound está habilitado
    function setPoolConfig(
        PoolKey calldata key,
        bool enabled
    ) external onlyOwner {
        PoolId poolId = key.toId();
        poolConfigs[poolId] = PoolConfig({
            enabled: enabled
        });
        emit PoolConfigUpdated(poolId, enabled);
    }

    /// @notice Configura preços dos tokens em USD para uma pool
    /// @dev Necessário para calcular se fees acumuladas são >= 20x o custo de gas
    /// @param key A chave da pool
    /// @param price0USD Preço do token0 em USD (ex: 3000 = $3000 para ETH)
    /// @param price1USD Preço do token1 em USD (ex: 1 = $1 para USDC)
    function setTokenPricesUSD(
        PoolKey calldata key,
        uint256 price0USD,
        uint256 price1USD
    ) external onlyOwner {
        require(price0USD > 0, "Token0 price must be > 0");
        require(price1USD > 0, "Token1 price must be > 0");
        
        PoolId poolId = key.toId();
        token0PriceUSD[poolId] = price0USD;
        token1PriceUSD[poolId] = price1USD;
        emit TokenPricesUpdated(poolId, price0USD, price1USD);
    }
    
    /// @notice Configura o tick range para uma pool (necessário para compound)
    /// @param key A chave da pool
    /// @param tickLower Tick inferior do range
    /// @param tickUpper Tick superior do range
    function setPoolTickRange(
        PoolKey calldata key,
        int24 tickLower,
        int24 tickUpper
    ) external onlyOwner {
        require(tickLower < tickUpper, "Invalid tick range");
        PoolId poolId = key.toId();
        poolTickLower[poolId] = tickLower;
        poolTickUpper[poolId] = tickUpper;
        emit PoolTickRangeUpdated(poolId, tickLower, tickUpper);
    }

    /// @notice Configura a pool intermediária para fazer swap de um token para USDC
    /// @dev Necessário quando a pool principal não contém USDC
    /// @dev Exemplo: Para ETH, use setIntermediatePool(ETH, PoolKey(ETH, USDC, 3000, 60, hooks))
    /// @param token O token que precisa ser convertido para USDC (ex: ETH, UNI)
    /// @param intermediatePoolKey A PoolKey da pool token/USDC
    function setIntermediatePool(
        Currency token,
        PoolKey calldata intermediatePoolKey
    ) external onlyOwner {
        Currency usdcCurrency = Currency.wrap(USDC());
        // Verificar se a pool intermediária contém o token e USDC
        require(
            (intermediatePoolKey.currency0 == token && intermediatePoolKey.currency1 == usdcCurrency) ||
            (intermediatePoolKey.currency1 == token && intermediatePoolKey.currency0 == usdcCurrency),
            "Intermediate pool must contain token and USDC"
        );
        intermediatePools[token] = intermediatePoolKey;
        hasIntermediatePool[token] = true;
    }

    /// @notice Callback após inicialização da pool
    /// @dev Habilita automaticamente a pool e emite evento para keeper detectar
    function _afterInitialize(
        address,
        PoolKey calldata key,
        uint160,
        int24
    ) internal override returns (bytes4) {
        // Inicializar configuração padrão (habilitado)
        PoolId poolId = key.toId();
        if (!poolConfigs[poolId].enabled) {
            poolConfigs[poolId] = PoolConfig({
                enabled: true
            });
            
            // Emitir evento para keeper detectar automaticamente
            emit PoolAutoEnabled(
                poolId,
                key.currency0,
                key.currency1,
                key.fee,
                key.tickSpacing,
                address(this)
            );
        }
        return this.afterInitialize.selector;
    }

    /// @notice Implementação interna do callback após swap
    /// @dev Acumula fees do swap para compound posterior
    ///      Calcula as fees baseadas no valor do swap e na taxa da pool
    function _afterSwap(
        address,
        PoolKey calldata key,
        SwapParams calldata params,
        BalanceDelta delta,
        bytes calldata
    ) internal override returns (bytes4, int128) {
        PoolId poolId = key.toId();
        PoolConfig memory config = poolConfigs[poolId];
        
        // Se o auto-compound não está habilitado, retornar sem fazer nada
        if (!config.enabled) {
            return (this.afterSwap.selector, 0);
        }
        
        // Calcular fees baseadas no valor do swap
        // As fees são sempre no token de entrada e calculadas como: amount * fee / 1e6
        // key.fee está em formato 1e6 (ex: 3000 = 0.3% = 3000/1e6)
        
        uint256 fee0 = 0;
        uint256 fee1 = 0;
        
        // Verificar se é exactInput (amountSpecified < 0) ou exactOutput (amountSpecified > 0)
        if (params.amountSpecified < 0) {
            // ExactInput: fees são calculadas sobre o input amount
            uint256 inputAmount = uint256(-params.amountSpecified);
            
            // Calcular fee: inputAmount * fee / 1e6
            // key.fee está em formato 1e6 (ex: 3000 para 0.3%)
            uint256 feeAmount = (inputAmount * key.fee) / 1_000_000;
            
            // As fees são sempre no token de entrada
            if (params.zeroForOne) {
                // Swapping token0 -> token1, fees em token0
                fee0 = feeAmount;
            } else {
                // Swapping token1 -> token0, fees em token1
                fee1 = feeAmount;
            }
        } else {
            // ExactOutput: para simplificar, também calculamos sobre o input estimado
            // Em swaps exactOutput, o input é maior que o output devido às fees
            // Podemos usar uma aproximação baseada no delta
            
            // Extrair os deltas de amount0 e amount1 do BalanceDelta
            int128 amount0Delta = delta.amount0();
            int128 amount1Delta = delta.amount1();
            
            // Para exactOutput, estimar fees baseadas na diferença entre input e output
            // Esta é uma aproximação - o valor real seria mais complexo de calcular
            if (params.zeroForOne) {
                // Swapping token0 -> token1 (output em token1, input em token0)
                // amount0Delta é negativo (token0 saiu), usar como aproximação
                if (amount0Delta < 0) {
                    // Converter int128 negativo para uint256: primeiro para int256, depois uint256
                    int256 amount0DeltaInt256 = int256(amount0Delta);
                    uint256 inputAmount = uint256(-amount0DeltaInt256);
                    fee0 = (inputAmount * key.fee) / 1_000_000;
                }
            } else {
                // Swapping token1 -> token0 (output em token0, input em token1)
                // amount1Delta é negativo (token1 saiu), usar como aproximação
                if (amount1Delta < 0) {
                    // Converter int128 negativo para uint256: primeiro para int256, depois uint256
                    int256 amount1DeltaInt256 = int256(amount1Delta);
                    uint256 inputAmount = uint256(-amount1DeltaInt256);
                    fee1 = (inputAmount * key.fee) / 1_000_000;
                }
            }
        }
        
        // Acumular fees calculadas
        if (fee0 > 0 || fee1 > 0) {
            accumulatedFees0[poolId] += fee0;
            accumulatedFees1[poolId] += fee1;
            
            // Emitir evento de fees acumuladas
            uint256 totalFees0 = accumulatedFees0[poolId];
            uint256 totalFees1 = accumulatedFees1[poolId];
            uint256 feesValueUSD = _calculateFeesValueUSD(poolId, totalFees0, totalFees1);
            
            emit FeesAccumulated(
                poolId,
                fee0,
                fee1,
                totalFees0,
                totalFees1,
                feesValueUSD
            );
        }
        
        // Não fazer compound aqui para evitar gas alto
        // O compound deve ser feito externamente via keeper ou checkAndCompound()
        return (this.afterSwap.selector, 0);
    }

    /// @notice Callback após adicionar liquidez
    /// @dev Captura automaticamente os ticks iniciais da primeira adição de liquidez
    ///      para que o compound use o mesmo range
    function _afterAddLiquidity(
        address,
        PoolKey calldata key,
        ModifyLiquidityParams calldata params,
        BalanceDelta,
        BalanceDelta,
        bytes calldata
    ) internal override returns (bytes4, BalanceDelta) {
        PoolId poolId = key.toId();
        
        // Se ainda não tem ticks iniciais configurados, salvar os ticks da primeira adição de liquidez
        // Isso garante que o compound use o mesmo range da criação inicial da pool
        if (!hasInitialTicks[poolId]) {
            initialTickLower[poolId] = params.tickLower;
            initialTickUpper[poolId] = params.tickUpper;
            hasInitialTicks[poolId] = true;
            
            // Também atualizar poolTickRange para usar os ticks iniciais
            poolTickLower[poolId] = params.tickLower;
            poolTickUpper[poolId] = params.tickUpper;
        }
        
        // Otimização: Não fazer compound aqui para evitar gas alto
        // O compound deve ser feito externamente quando há taxas suficientes

        return (this.afterAddLiquidity.selector, BalanceDeltaLibrary.ZERO_DELTA);
    }

    /// @notice Callback após remover liquidez
    /// @dev Captura 10% das fees geradas e converte para USDC, enviando para FEE_RECIPIENT
    // modifier onlyPoolManager {
    //     require(msg.sender == address(poolManager), "Not PoolManager");
    // }
    function _afterRemoveLiquidity(
        address,
        PoolKey calldata key,
        ModifyLiquidityParams calldata,
        BalanceDelta,
        BalanceDelta feesAccrued,
        bytes calldata
    ) internal override returns (bytes4, BalanceDelta) {
        // Verificação de segurança: apenas PoolManager pode chamar este callback
        // BaseHook já valida isso, mas mantemos explícito para clareza
        require(msg.sender == address(poolManager), "Not PoolManager");
        
        // Extrair as fees acumuladas do BalanceDelta
        int128 fees0 = feesAccrued.amount0();
        int128 fees1 = feesAccrued.amount1();

        // Verificar se há fees positivas
        if (fees0 > 0 || fees1 > 0) {
            // Calcular protocol fee percent das fees (base 10000)
            uint256 protocolFee0 = (uint256(uint128(fees0)) * protocolFeePercent) / 10000;
            uint256 protocolFee1 = (uint256(uint128(fees1)) * protocolFeePercent) / 10000;

            // Pegar os tokens do pool manager
            if (protocolFee0 > 0) {
                poolManager.take(key.currency0, address(this), protocolFee0);
            }
            if (protocolFee1 > 0) {
                poolManager.take(key.currency1, address(this), protocolFee1);
            }

            // Fazer swap para USDC se necessário
            Currency usdcCurrency = Currency.wrap(USDC());
            bool currency0IsUSDC = key.currency0 == usdcCurrency;
            bool currency1IsUSDC = key.currency1 == usdcCurrency;

            // Se token0 não é USDC, fazer swap
            if (protocolFee0 > 0 && !currency0IsUSDC) {
                _swapToUSDC(key, key.currency0, protocolFee0);
            }

            // Se token1 não é USDC, fazer swap
            if (protocolFee1 > 0 && !currency1IsUSDC) {
                _swapToUSDC(key, key.currency1, protocolFee1);
            }

            // Transferir todo USDC acumulado para feeRecipient
            uint256 usdcBalance = IERC20(USDC()).balanceOf(address(this));
            if (usdcBalance > 0) {
                IERC20(USDC()).transfer(feeRecipient, usdcBalance);
            }
        }

        return (this.afterRemoveLiquidity.selector, BalanceDeltaLibrary.ZERO_DELTA);
    }

    /// @notice Função helper para fazer swap de um token para USDC
    /// @param key A chave da pool atual (pode não conter USDC)
    /// @param inputCurrency O token de entrada
    /// @param amount A quantidade a ser trocada
    /// @dev Tenta fazer swap direto se USDC está na pool, senão tenta através de pool intermediária
    function _swapToUSDC(
        PoolKey calldata key,
        Currency inputCurrency,
        uint256 amount
    ) internal {
        Currency usdcCurrency = Currency.wrap(USDC());
        
        // Verificar se USDC está na pool atual
        bool usdcIsCurrency0 = key.currency0 == usdcCurrency;
        bool usdcIsCurrency1 = key.currency1 == usdcCurrency;
        
        if (usdcIsCurrency0 || usdcIsCurrency1) {
            // USDC está na pool atual - fazer swap direto
            bool zeroForOne;
            if (inputCurrency == key.currency0) {
                zeroForOne = true; // Swapping token0 -> token1
            } else {
                zeroForOne = false; // Swapping token1 -> token0
            }

            // Fazer o swap através do poolManager
            try poolManager.swap(
                key,
                SwapParams({
                    zeroForOne: zeroForOne,
                    amountSpecified: -int256(amount),
                    sqrtPriceLimitX96: 0
                }),
                ""
            ) returns (BalanceDelta) {
                // Swap bem-sucedido - o USDC será recebido pelo contrato
                return;
            } catch {
                // Se o swap falhar, tentar pool intermediária
            }
        }

        // Se USDC não está na pool atual, tentar usar pool intermediária
        // Verificar se existe pool intermediária configurada
        if (!hasIntermediatePool[inputCurrency]) {
            // Pool intermediária não configurada - tokens permanecem no contrato
            return;
        }
        
        PoolKey memory intermediatePool = intermediatePools[inputCurrency];

        // Verificar se a pool intermediária contém o token e USDC
        bool validPool = (intermediatePool.currency0 == inputCurrency && intermediatePool.currency1 == usdcCurrency) ||
                         (intermediatePool.currency1 == inputCurrency && intermediatePool.currency0 == usdcCurrency);
        
        if (!validPool) {
            // Pool intermediária inválida
            return;
        }

        // Determinar direção do swap na pool intermediária
        bool zeroForOneIntermediate = intermediatePool.currency0 == inputCurrency;

        // Fazer swap através da pool intermediária
        try poolManager.swap(
            intermediatePool,
            SwapParams({
                zeroForOne: zeroForOneIntermediate,
                amountSpecified: -int256(amount),
                sqrtPriceLimitX96: 0
            }),
            ""
        ) returns (BalanceDelta) {
            // Swap bem-sucedido - o USDC será recebido pelo contrato
        } catch {
            // Se o swap falhar, os tokens permanecem no contrato
            // Podem ser processados depois via função separada
        }
    }

    /// @notice Tenta fazer compound das taxas acumuladas
    /// @dev Esta função pode ser chamada externamente ou internamente
    function tryCompound(PoolKey calldata key) external {
        PoolId poolId = key.toId();
        _tryCompound(key, poolId);
    }

    /// @notice Prepara os dados do compound e retorna os parâmetros
    /// @dev Verifica condições e prepara ModifyLiquidityParams para uso via unlock
    /// @return canCompound Se o compound pode ser executado
    /// @return params Parâmetros para modifyLiquidity (vazio se não pode compound)
    /// @return fees0 Amount de fees0 acumuladas
    /// @return fees1 Amount de fees1 acumuladas
    function prepareCompound(PoolKey calldata key) external view returns (
        bool canCompound,
        ModifyLiquidityParams memory params,
        uint256 fees0,
        uint256 fees1
    ) {
        PoolId poolId = key.toId();
        PoolConfig memory config = poolConfigs[poolId];
        
        if (!config.enabled) {
            return (false, params, 0, 0);
        }

        // Verificar se passou o intervalo mínimo desde o último compound
        uint256 lastCompound = lastCompoundTimestamp[poolId];
        if (lastCompound > 0 && block.timestamp < lastCompound + minTimeBetweenCompounds) {
            return (false, params, 0, 0);
        }

        fees0 = accumulatedFees0[poolId];
        fees1 = accumulatedFees1[poolId];

        // Verificar se há fees acumuladas
        if (fees0 == 0 && fees1 == 0) {
            return (false, params, 0, 0);
        }

        // Calcular custo de gas em USD
        uint256 gasCostUSD = _calculateGasCostUSD(poolId);
        
        // Calcular valor total das fees acumuladas em USD
        uint256 feesValueUSD = _calculateFeesValueUSD(poolId, fees0, fees1);
        
        // Verificar se fees acumuladas são >= thresholdMultiplier x o custo de gas
        // Se feesValueUSD for 0 (preços não configurados), permitir compound
        // Se gasCostUSD for 0, permitir compound
        if (gasCostUSD > 0 && feesValueUSD > 0) {
            // Verificar overflow na multiplicação
            uint256 minRequired;
            unchecked {
                minRequired = gasCostUSD * thresholdMultiplier;
                // Se não houve overflow e feesValueUSD é menor que o mínimo, não pode compound
                if (minRequired / thresholdMultiplier == gasCostUSD && feesValueUSD < minRequired) {
                    return (false, params, fees0, fees1);
                }
            }
        }

        // Usar ticks iniciais se configurados, senão usar ticks da pool
        int24 tickLower;
        int24 tickUpper;
        if (hasInitialTicks[poolId]) {
            // Usar ticks iniciais para manter a mesma distribuição da criação da pool
            tickLower = initialTickLower[poolId];
            tickUpper = initialTickUpper[poolId];
        } else {
            // Fallback para ticks configurados manualmente
            tickLower = poolTickLower[poolId];
            tickUpper = poolTickUpper[poolId];
        }
        
        // Verificar se temos um tick range configurado
        if (tickLower == 0 && tickUpper == 0) {
            return (false, params, fees0, fees1);
        }
        
        // Calcular o delta de liquidez baseado nas taxas
        int128 liquidityDelta = _calculateLiquidityFromAmounts(
            key,
            tickLower,
            tickUpper,
            fees0,
            fees1
        );
        
        if (liquidityDelta <= 0) {
            return (false, params, fees0, fees1);
        }
        
        // Criar parâmetros para modifyLiquidity
        params = ModifyLiquidityParams({
            tickLower: tickLower,
            tickUpper: tickUpper,
            liquidityDelta: liquidityDelta,
            salt: bytes32(0)
        });
        
        return (true, params, fees0, fees1);
    }
    
    
    /// @notice Executa o compound após ser chamado via unlock (deve ser chamado pelo helper)
    /// @dev Esta função deve ser chamada APENAS dentro de um unlock callback
    /// @dev A verificação de msg.sender foi removida porque o CompoundHelper só pode chamar
    ///      esta função dentro do unlockCallback, que só pode ser chamado pelo PoolManager
    /// @dev Separa 10% das fees para protocol fees, converte para USDC e envia automaticamente para feeRecipient
    /// @dev Faz compound apenas com 90% restantes
    /// @param key A chave da pool
    /// @param fees0 Amount de fees0 que serão reinvestidas (antes de separar protocol fee)
    /// @param fees1 Amount de fees1 que serão reinvestidas (antes de separar protocol fee)
    function executeCompound(PoolKey calldata key, uint256 fees0, uint256 fees1) external {
        // No need to check msg.sender because this can only be called from CompoundHelper
        // which only runs during unlockCallback (which only PoolManager can call)
        
        PoolId poolId = key.toId();
        
        // Separar 10% das fees para protocol fees
        uint256 protocolFee0 = (fees0 * protocolFeePercent) / 10000;
        uint256 protocolFee1 = (fees1 * protocolFeePercent) / 10000;
        
        // Se houver protocol fees, processar e enviar automaticamente
        // NOTA: poolManager.take() NÃO pode ser chamado dentro de unlockCallback
        // Os protocol fees precisam ser acumulados e transferidos DEPOIS do compound
        // Isso será feito pelo CompoundHelper após o unlockCallback terminar
        if (protocolFee0 > 0 || protocolFee1 > 0) {
            // Acumular protocol fees nas variáveis de estado
            // O CompoundHelper irá transferir depois do unlockCallback
            protocolFeeToken0 += uint128(protocolFee0);
            protocolFeeToken1 += uint128(protocolFee1);
        }
        
        // Calcular fees que serão reinvestidas (90%)
        uint256 compoundFees0 = fees0 - protocolFee0;
        uint256 compoundFees1 = fees1 - protocolFee1;
        
        // Calcular informações antes de resetar
        uint256 feesValueUSD = _calculateFeesValueUSD(poolId, compoundFees0, compoundFees1);
        
        // Calcular liquidityDelta que será adicionado (apenas com os 90%)
        // Usar ticks iniciais se configurados, senão usar ticks da pool
        int24 tickLower;
        int24 tickUpper;
        if (hasInitialTicks[poolId]) {
            // Usar ticks iniciais para manter a mesma distribuição da criação da pool
            tickLower = initialTickLower[poolId];
            tickUpper = initialTickUpper[poolId];
        } else {
            // Fallback para ticks configurados manualmente
            tickLower = poolTickLower[poolId];
            tickUpper = poolTickUpper[poolId];
        }
        int128 liquidityDelta = _calculateLiquidityFromAmounts(key, tickLower, tickUpper, compoundFees0, compoundFees1);
        
        // Estimativa de gas usado (baseada em execuções típicas)
        // O gas real será calculado pelo keeper/frontend baseado na transação
        uint256 estimatedGasUsed = 200000; // Estimativa típica para compound
        
        // Resetar taxas acumuladas e atualizar timestamp
        accumulatedFees0[poolId] = 0;
        accumulatedFees1[poolId] = 0;
        lastCompoundTimestamp[poolId] = block.timestamp;
        
        // Emitir eventos detalhados (usando fees que foram reinvestidas, não as totais)
        emit FeesCompounded(poolId, compoundFees0, compoundFees1);
        emit CompoundExecuted(
            poolId,
            compoundFees0,
            compoundFees1,
            liquidityDelta,
            estimatedGasUsed,
            feesValueUSD,
            block.timestamp
        );
    }

    /// @notice Função interna para fazer compound (mantida para compatibilidade)
    /// @dev Esta função agora apenas retorna - o compound deve ser feito via helper
    function _tryCompound(PoolKey calldata key, PoolId poolId) internal {
        // Esta função não faz mais nada - o compound deve ser feito via helper
        // Mantida para compatibilidade com código existente
        // O compound real deve ser feito chamando prepareCompound() e depois executeCompound via unlock
    }

    /// @notice Calcula o custo de gas em USD
    /// @dev Estima o custo de gas para executar compound e converte para USD
    /// @return gasCostUSD Custo de gas em USD
    function _calculateGasCostUSD(PoolId /* poolId */) internal view returns (uint256 gasCostUSD) {
        // Estimativa de gas para compound: ~200k gas
        uint256 estimatedGasLimit = 200000;
        
        // Calcular gas price (usar block.basefee * 2 como estimativa)
        uint256 gasPriceWei = block.basefee > 0 ? block.basefee * 2 : 30e9; // Default 30 gwei
        
        // Calcular custo de gas em wei
        uint256 gasCostWei = gasPriceWei * estimatedGasLimit;
        
        // Converter wei para USD (assumindo ETH = $3000 como padrão)
        // Se tiver preço configurado, usar; senão usar padrão
        uint256 ethPriceUSD = 3000; // Preço padrão do ETH em USD
        
        // gasCostUSD = (gasCostWei * ethPriceUSD) / 1e18
        gasCostUSD = (gasCostWei * ethPriceUSD) / 1e18;
        
        return gasCostUSD;
    }

    /// @notice Calcula o valor total das fees acumuladas em USD
    /// @dev Converte fees0 e fees1 para USD usando preços configurados
    /// @param poolId ID da pool
    /// @param fees0 Quantidade de token0 acumulado
    /// @param fees1 Quantidade de token1 acumulado
    /// @return feesValueUSD Valor total das fees em USD
    function _calculateFeesValueUSD(
        PoolId poolId,
        uint256 fees0,
        uint256 fees1
    ) internal view returns (uint256 feesValueUSD) {
        uint256 price0 = token0PriceUSD[poolId];
        uint256 price1 = token1PriceUSD[poolId];
        
        // Se preços não estão configurados, retornar 0 (não pode calcular)
        if (price0 == 0 || price1 == 0) {
            return 0;
        }
        
        // Calcular valor em USD de cada token
        // Assumindo que fees0 e fees1 já estão nas unidades corretas (wei para tokens com 18 decimais)
        // Para tokens com decimais diferentes, seria necessário ajustar
        // Por simplicidade, assumimos que os preços já estão ajustados para a unidade correta
        
        // Proteger contra overflow usando unchecked com verificação
        uint256 value0USD;
        uint256 value1USD;
        unchecked {
            // Verificar se multiplicação não causa overflow antes de calcular
            if (fees0 > 0 && price0 > 0) {
                // Verificar: (fees0 * price0) / price0 == fees0 (sem overflow)
                uint256 temp0 = fees0 * price0;
                if (temp0 / price0 == fees0) {
                    value0USD = temp0 / 1e18;
                }
            }
            
            if (fees1 > 0 && price1 > 0) {
                // Verificar: (fees1 * price1) / price1 == fees1 (sem overflow)
                uint256 temp1 = fees1 * price1;
                if (temp1 / price1 == fees1) {
                    value1USD = temp1 / 1e18;
                }
            }
        }
        
        feesValueUSD = value0USD + value1USD;
        
        return feesValueUSD;
    }
    
    /// @notice Calcula o máximo de liquidez permitido por tick baseado no tickSpacing
    /// @dev Replica o cálculo de tickSpacingToMaxLiquidityPerTick do Pool.sol
    /// @param tickSpacing O spacing dos ticks
    /// @return maxLiquidityPerTick O máximo de liquidez permitido por tick
    function _tickSpacingToMaxLiquidityPerTick(int24 tickSpacing) internal pure returns (uint128 maxLiquidityPerTick) {
        // Replicar o cálculo de Pool.tickSpacingToMaxLiquidityPerTick
        // numTicks = (MAX_TICK - MIN_TICK) / tickSpacing + 1
        // maxLiquidityPerTick = type(uint128).max / numTicks
        int24 MAX_TICK = 887272;
        int24 MIN_TICK = -887272;
        
        unchecked {
            int24 minTick = (MIN_TICK / tickSpacing);
            if (MIN_TICK % tickSpacing != 0 && MIN_TICK < 0) {
                minTick = minTick - 1;
            }
            int24 maxTick = (MAX_TICK / tickSpacing);
            uint24 numTicks = uint24(int24(maxTick - minTick + 1));
            
            maxLiquidityPerTick = uint128(type(uint128).max / uint256(numTicks));
        }
    }
    
    /// @notice Calcula o delta de liquidez baseado nas quantidades de tokens
    /// @dev Usa LiquidityAmounts do Uniswap v4 para calcular corretamente
    /// @param key A chave da pool (para obter preço atual)
    /// @param tickLower Tick inferior do range
    /// @param tickUpper Tick superior do range
    /// @param amount0 Quantidade de token0
    /// @param amount1 Quantidade de token1
    /// @return liquidityDelta O delta de liquidez calculado
    function _calculateLiquidityFromAmounts(
        PoolKey calldata key,
        int24 tickLower,
        int24 tickUpper,
        uint256 amount0,
        uint256 amount1
    ) internal view returns (int128 liquidityDelta) {
        if (amount0 == 0 && amount1 == 0) {
            return 0;
        }
        
        // Obter o preço atual da pool
        PoolId poolId = key.toId();
        (uint160 sqrtPriceX96,,,) = poolManager.getSlot0(poolId);
        
        // Se a pool não está inicializada, retornar 0
        if (sqrtPriceX96 == 0) {
            return 0;
        }
        
        // Converter ticks para sqrtPrice
        uint160 sqrtPriceAX96 = TickMath.getSqrtPriceAtTick(tickLower);
        uint160 sqrtPriceBX96 = TickMath.getSqrtPriceAtTick(tickUpper);
        
        // Calcular liquidez usando a biblioteca do Uniswap v4
        uint128 liquidity = LiquidityAmounts.getLiquidityForAmounts(
            sqrtPriceX96,
            sqrtPriceAX96,
            sqrtPriceBX96,
            amount0,
            amount1
        );
        
        // Obter liquidez atual da pool para calcular o máximo seguro de adição
        uint128 currentPoolLiquidity = poolManager.getLiquidity(poolId);
        
        // CRÍTICO: Verificar a liquidez gross atual dos ticks que serão atualizados
        // Quando adiciona liquidez, a liquidez gross é adicionada aos ticks inferior e superior
        // Isso pode causar overflow no LiquidityMath.addDelta se os ticks já têm muita liquidez
        (uint128 liquidityGrossLower,) = StateLibrary.getTickLiquidity(poolManager, poolId, tickLower);
        (uint128 liquidityGrossUpper,) = StateLibrary.getTickLiquidity(poolManager, poolId, tickUpper);
        
        // Calcular maxLiquidityPerTick para o tickSpacing usando função helper
        uint128 maxLiquidityPerTick = _tickSpacingToMaxLiquidityPerTick(key.tickSpacing);
        
        // Calcular quanto pode ser adicionado sem ultrapassar o limite por tick
        // O Overflow acontece em LiquidityMath.addDelta(liquidityGrossBefore, liquidityDelta)
        // Precisamos garantir: liquidityGrossBefore + liquidityDelta <= maxLiquidityPerTick
        // Ou seja: liquidityDelta <= maxLiquidityPerTick - liquidityGrossBefore
        uint128 maxSafeForLowerTick;
        uint128 maxSafeForUpperTick;
        unchecked {
            // Verificar se há espaço para adicionar liquidez sem overflow
            // Usar verificação adicional para evitar underflow na subtração
            if (liquidityGrossLower > maxLiquidityPerTick) {
                maxSafeForLowerTick = 0;
            } else if (maxLiquidityPerTick - liquidityGrossLower > type(uint128).max / 2) {
                // Se a diferença é muito grande, usar limite conservador
                maxSafeForLowerTick = type(uint128).max / 2;
            } else {
                maxSafeForLowerTick = maxLiquidityPerTick - liquidityGrossLower;
            }
            
            if (liquidityGrossUpper > maxLiquidityPerTick) {
                maxSafeForUpperTick = 0;
            } else if (maxLiquidityPerTick - liquidityGrossUpper > type(uint128).max / 2) {
                maxSafeForUpperTick = type(uint128).max / 2;
            } else {
                maxSafeForUpperTick = maxLiquidityPerTick - liquidityGrossUpper;
            }
        }
        
        // O máximo seguro é o mínimo entre os dois ticks (para não ultrapassar nenhum)
        uint128 maxSafeForTicks = maxSafeForLowerTick < maxSafeForUpperTick 
            ? maxSafeForLowerTick 
            : maxSafeForUpperTick;
        
        // Também verificar o limite da pool total
        uint128 maxSafeForPool;
        unchecked {
            if (currentPoolLiquidity >= type(uint128).max) {
                maxSafeForPool = 0;
            } else {
                maxSafeForPool = type(uint128).max - currentPoolLiquidity;
            }
        }
        
        // O máximo seguro é o mínimo entre todos os limites
        uint128 maxSafe = maxSafeForTicks < maxSafeForPool ? maxSafeForTicks : maxSafeForPool;
        
        // Também limitar ao máximo de int128 (que é menor que uint128.max)
        uint128 maxInt128 = uint128(uint256(int256(type(int128).max)));
        if (maxSafe > maxInt128) {
            maxSafe = maxInt128;
        }
        
        // Limitar a liquidez calculada ao máximo seguro
        if (liquidity > maxSafe) {
            liquidity = maxSafe;
        }
        
        // Converter para int128 usando SafeCast para evitar overflow
        // SafeCast.toInt128 verifica se o valor está dentro do range de int128
        // e reverte com SafeCastOverflow se não estiver
        return SafeCast.toInt128(uint256(liquidity));
    }

    /// @notice Atualiza o owner do contrato
    function setOwner(address newOwner) external onlyOwner {
        require(newOwner != address(0), "Invalid owner");
        address oldOwner = owner;
        owner = newOwner;
        emit OwnerUpdated(oldOwner, newOwner);
    }

    /// @notice Atualiza o multiplicador de threshold para compound
    /// @param _new Novo valor do multiplicador (ex: 20 = 20x o custo de gas)
    function setThresholdMultiplier(uint256 _new) external onlyOwner {
        require(_new > 0, "Threshold multiplier must be > 0");
        uint256 oldValue = thresholdMultiplier;
        thresholdMultiplier = _new;
        emit ThresholdMultiplierUpdated(oldValue, _new);
    }

    /// @notice Atualiza o intervalo mínimo entre compounds
    /// @param _new Novo intervalo em segundos (ex: 14400 = 4 horas)
    function setMinTimeInterval(uint256 _new) external onlyOwner {
        require(_new > 0, "Time interval must be > 0");
        uint256 oldValue = minTimeBetweenCompounds;
        minTimeBetweenCompounds = _new;
        emit MinTimeIntervalUpdated(oldValue, _new);
    }

    /// @notice Atualiza a porcentagem de protocol fee
    /// @param _new Novo valor em base 10000 (ex: 1000 = 10%, máximo 5000 = 50%)
    function setProtocolFeePercent(uint256 _new) external onlyOwner {
        require(_new <= 5000, "Protocol fee percent must be <= 50% (5000)");
        uint256 oldValue = protocolFeePercent;
        protocolFeePercent = _new;
        emit ProtocolFeePercentUpdated(oldValue, _new);
    }

    /// @notice Atualiza o endereço que recebe protocol fees
    /// @param _new Novo endereço do fee recipient
    function setFeeRecipient(address _new) external onlyOwner {
        require(_new != address(0), "Fee recipient cannot be zero address");
        address oldRecipient = feeRecipient;
        feeRecipient = _new;
        emit FeeRecipientUpdated(oldRecipient, _new);
    }

    /// @notice Transfere protocol fees acumuladas para feeRecipient (pode ser chamado pelo CompoundHelper)
    /// @dev Converte todas as protocol fees para USDC e envia para o fee recipient
    /// @param key A chave da pool (necessária para identificar os tokens e fazer swaps)
    function transferProtocolFees(PoolKey calldata key) external {
        // Pode ser chamado pelo CompoundHelper (após unlockCallback) ou pelo owner
        // CompoundHelper chama após unlockCallback terminar, então é seguro
        
        uint128 amount0 = protocolFeeToken0;
        uint128 amount1 = protocolFeeToken1;
        
        // Resetar acumuladores ANTES de processar (para evitar reentrancy)
        protocolFeeToken0 = 0;
        protocolFeeToken1 = 0;
        
        if (amount0 == 0 && amount1 == 0) {
            return; // Nada para transferir
        }
        
        // Os tokens já devem estar no hook (transferidos pelo CompoundHelper via take)
        // Fazer swap para USDC se necessário
        Currency usdcCurrency = Currency.wrap(USDC());
        bool currency0IsUSDC = key.currency0 == usdcCurrency;
        bool currency1IsUSDC = key.currency1 == usdcCurrency;
        
        // Se token0 não é USDC, fazer swap
        if (amount0 > 0 && !currency0IsUSDC) {
            _swapToUSDC(key, key.currency0, amount0);
        }
        
        // Se token1 não é USDC, fazer swap
        if (amount1 > 0 && !currency1IsUSDC) {
            _swapToUSDC(key, key.currency1, amount1);
        }
        
        // Transferir todo USDC acumulado para feeRecipient
        uint256 usdcBalance = IERC20(USDC()).balanceOf(address(this));
        if (usdcBalance > 0) {
            IERC20(USDC()).transfer(feeRecipient, usdcBalance);
            emit ProtocolFeesTransferred(feeRecipient, amount0, amount1);
        }
    }

    /// @notice Retira as protocol fees acumuladas (função manual para owner)
    /// @dev Converte todas as protocol fees para USDC e envia para o fee recipient
    /// @param key A chave da pool (necessária para identificar os tokens e fazer swaps)
    function withdrawProtocolFees(PoolKey calldata key) external onlyOwner {
        uint128 amount0 = protocolFeeToken0;
        uint128 amount1 = protocolFeeToken1;
        
        // Resetar acumuladores
        protocolFeeToken0 = 0;
        protocolFeeToken1 = 0;
        
        // Pegar os tokens do poolManager
        if (amount0 > 0) {
            poolManager.take(key.currency0, address(this), amount0);
        }
        if (amount1 > 0) {
            poolManager.take(key.currency1, address(this), amount1);
        }
        
        // Fazer swap para USDC se necessário
        Currency usdcCurrency = Currency.wrap(USDC());
        bool currency0IsUSDC = key.currency0 == usdcCurrency;
        bool currency1IsUSDC = key.currency1 == usdcCurrency;
        
        // Se token0 não é USDC, fazer swap
        if (amount0 > 0 && !currency0IsUSDC) {
            _swapToUSDC(key, key.currency0, amount0);
        }
        
        // Se token1 não é USDC, fazer swap
        if (amount1 > 0 && !currency1IsUSDC) {
            _swapToUSDC(key, key.currency1, amount1);
        }
        
        // Transferir todo USDC acumulado para feeRecipient
        uint256 usdcBalance = IERC20(USDC()).balanceOf(address(this));
        if (usdcBalance > 0) {
            IERC20(USDC()).transfer(feeRecipient, usdcBalance);
        }
        
        emit ProtocolFeesWithdrawn(feeRecipient, uint128(usdcBalance), 0);
    }

    /// @notice Função de emergência para retirar tokens acumulados
    /// @dev Apenas o owner pode chamar
    /// @dev Transfere os tokens reais do hook para o destinatário
    /// @param key A chave da pool
    /// @param to Endereço para onde enviar os tokens
    function emergencyWithdraw(
        PoolKey calldata key,
        address to
    ) external onlyOwner {
        require(to != address(0), "Invalid address");
        
        PoolId poolId = key.toId();
        uint256 fees0 = accumulatedFees0[poolId];
        uint256 fees1 = accumulatedFees1[poolId];
        
        // Obter saldo real do hook (pode ser menor que fees acumuladas se parte já foi usada)
        // Verificar saldo considerando ETH nativo ou ERC20
        uint256 balance0;
        uint256 balance1;
        
        if (Currency.unwrap(key.currency0) == address(0)) {
            balance0 = address(this).balance;
        } else {
            balance0 = IERC20(Currency.unwrap(key.currency0)).balanceOf(address(this));
        }
        
        if (Currency.unwrap(key.currency1) == address(0)) {
            balance1 = address(this).balance;
        } else {
            balance1 = IERC20(Currency.unwrap(key.currency1)).balanceOf(address(this));
        }
        
        // Transferir apenas o que estiver disponível no hook
        // Pode ser menos que accumulatedFees se tokens já foram usados parcialmente
        uint256 amount0ToTransfer = balance0 < fees0 ? balance0 : fees0;
        uint256 amount1ToTransfer = balance1 < fees1 ? balance1 : fees1;
        
        // Transferir token0 se houver saldo
        if (amount0ToTransfer > 0) {
            key.currency0.transfer(to, amount0ToTransfer);
        }
        
        // Transferir token1 se houver saldo
        if (amount1ToTransfer > 0) {
            key.currency1.transfer(to, amount1ToTransfer);
        }
        
        // Resetar taxas acumuladas
        accumulatedFees0[poolId] = 0;
        accumulatedFees1[poolId] = 0;
        
        emit FeesCompounded(poolId, amount0ToTransfer, amount1ToTransfer);
    }
    
    /// @notice Obtém informações sobre uma pool configurada
    /// @param key A chave da pool
    /// @return config Configuração da pool
    /// @return fees0 Taxas acumuladas em token0
    /// @return fees1 Taxas acumuladas em token1
    /// @return tickLower Tick inferior configurado
    /// @return tickUpper Tick superior configurado
    function getPoolInfo(PoolKey calldata key) external view returns (
        PoolConfig memory config,
        uint256 fees0,
        uint256 fees1,
        int24 tickLower,
        int24 tickUpper
    ) {
        PoolId poolId = key.toId();
        return (
            poolConfigs[poolId],
            accumulatedFees0[poolId],
            accumulatedFees1[poolId],
            poolTickLower[poolId],
            poolTickUpper[poolId]
        );
    }
    
    /// @notice Obtém apenas as taxas acumuladas (útil para keepers)
    /// @param key A chave da pool
    /// @return fees0 Taxas acumuladas em token0
    /// @return fees1 Taxas acumuladas em token1
    function getAccumulatedFees(PoolKey calldata key) external view returns (uint256 fees0, uint256 fees1) {
        PoolId poolId = key.toId();
        return (accumulatedFees0[poolId], accumulatedFees1[poolId]);
    }

    /// @notice Verifica se o compound pode ser executado para uma pool
    /// @dev Útil para keepers verificarem antes de chamar checkAndCompound()
    /// @param key A chave da pool
    /// @return canCompound Retorna true se todas as condições são atendidas
    /// @return reason Mensagem explicando por que não pode fazer compound (se aplicável)
    /// @return timeUntilNextCompound Tempo restante até poder fazer compound (em segundos)
    /// @return feesValueUSD Valor das fees acumuladas em USD
    /// @return gasCostUSD Custo estimado de gas em USD
    function canExecuteCompound(PoolKey calldata key) external view returns (
        bool canCompound,
        string memory reason,
        uint256 timeUntilNextCompound,
        uint256 feesValueUSD,
        uint256 gasCostUSD
    ) {
        PoolId poolId = key.toId();
        PoolConfig memory config = poolConfigs[poolId];
        
        if (!config.enabled) {
            return (false, "Pool not enabled", 0, 0, 0);
        }

        uint256 fees0 = accumulatedFees0[poolId];
        uint256 fees1 = accumulatedFees1[poolId];

        if (fees0 == 0 && fees1 == 0) {
            return (false, "No accumulated fees", 0, 0, 0);
        }

        // Verificar intervalo mínimo
        uint256 lastCompound = lastCompoundTimestamp[poolId];
        if (lastCompound > 0) {
            uint256 timeElapsed = block.timestamp - lastCompound;
            if (timeElapsed < minTimeBetweenCompounds) {
                timeUntilNextCompound = minTimeBetweenCompounds - timeElapsed;
                return (false, "Minimum time interval not elapsed", timeUntilNextCompound, 0, 0);
            }
        }

        // Calcular custo de gas e valor das fees
        gasCostUSD = _calculateGasCostUSD(poolId);
        feesValueUSD = _calculateFeesValueUSD(poolId, fees0, fees1);

        if (feesValueUSD == 0) {
            return (false, "Token prices not configured", 0, 0, gasCostUSD);
        }

        // Verificar se fees >= thresholdMultiplier x custo de gas (calculado automaticamente)
        if (feesValueUSD < gasCostUSD * thresholdMultiplier) {
            return (false, "Fees less than threshold multiplier x gas cost", 0, feesValueUSD, gasCostUSD);
        }

        return (true, "", 0, feesValueUSD, gasCostUSD);
    }
}

