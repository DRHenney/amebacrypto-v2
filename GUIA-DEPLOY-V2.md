# 🚀 Guia de Deploy - AmebaCrypto v2

Este guia explica como fazer deploy do AutoCompoundHook v2 com as novas configurações globais.

## 📋 Pré-requisitos

1. **Foundry instalado**: https://book.getfoundry.sh/getting-started/installation
2. **Carteira com ETH** para gas fees
3. **PoolManager deployado** (Uniswap v4)
4. **Variáveis de ambiente configuradas**

## ⚙️ Configuração

### 1. Criar arquivo `.env`

Crie um arquivo `.env` na raiz do projeto:

```bash
# Chave privada da carteira (sem 0x)
PRIVATE_KEY=sua_chave_privada_aqui

# Endereço do PoolManager (Uniswap v4)
POOL_MANAGER=0x...

# Configurações opcionais (valores padrão se não especificadas)
THRESHOLD_MULTIPLIER=20              # Padrão: 20
MIN_TIME_INTERVAL=14400              # Padrão: 14400 (4 horas)
PROTOCOL_FEE_PERCENT=1000             # Padrão: 1000 (10%, base 10000)
FEE_RECIPIENT=0xd9D3e3C7dc4F5d058ff24C0b71cF68846316F65c  # Padrão: endereço configurado

# RPC URL (para testnet Sepolia)
SEPOLIA_RPC_URL=https://rpc.sepolia.org
```

### 2. Configurar foundry.toml (se necessário)

Adicione a configuração da rede no `foundry.toml`:

```toml
[rpc_endpoints]
sepolia = "${SEPOLIA_RPC_URL}"
```

## 🚀 Deploy

### Opção 1: Deploy em Sepolia (Testnet)

```bash
# Compilar
forge build --via-ir

# Deploy
forge script script/DeployAutoCompoundHookV2.s.sol:DeployAutoCompoundHookV2 \
    --rpc-url sepolia \
    --broadcast \
    --verify \
    -vvvv
```

### Opção 2: Deploy em Mainnet

```bash
# ⚠️ ATENÇÃO: Verifique tudo antes de fazer deploy em mainnet!

forge script script/DeployAutoCompoundHookV2.s.sol:DeployAutoCompoundHookV2 \
    --rpc-url mainnet \
    --broadcast \
    --verify \
    -vvvv
```

### Opção 3: Simular deploy (sem broadcast)

```bash
# Apenas simula o deploy sem enviar transação
forge script script/DeployAutoCompoundHookV2.s.sol:DeployAutoCompoundHookV2 \
    --rpc-url sepolia \
    -vvvv
```

## 📝 Configurações Padrão

O hook v2 vem com os seguintes valores padrão:

| Configuração | Valor Padrão | Descrição |
|-------------|--------------|-----------|
| `thresholdMultiplier` | 20 | Fees devem ser ≥ 20x o custo de gas |
| `minTimeBetweenCompounds` | 4 hours (14400s) | Intervalo mínimo entre compounds |
| `protocolFeePercent` | 1000 (10%) | Porcentagem de protocol fee (base 10000) |
| `feeRecipient` | 0xd9D3e3C7dc4F5d058ff24C0b71cF68846316F65c | Endereço que recebe fees |

## 🔧 Configuração Pós-Deploy

Após o deploy, você precisa configurar cada pool:

### 1. Habilitar Pool

```solidity
hook.setPoolConfig(poolKey, true);
```

### 2. Configurar Preços dos Tokens (USD)

```solidity
// Exemplo: ETH = $3000, USDC = $1
hook.setTokenPricesUSD(poolKey, 3000e18, 1e18);
```

### 3. Configurar Tick Range

```solidity
// Exemplo: full range
hook.setPoolTickRange(poolKey, -887272, 887272);
```

### 4. (Opcional) Configurar Pool Intermediária

Se a pool não contém USDC, configure uma pool intermediária:

```solidity
hook.setIntermediatePool(tokenCurrency, intermediatePoolKey);
```

## 🎛️ Ajustar Configurações Globais

Você pode ajustar as configurações globais a qualquer momento (apenas owner):

```solidity
// Mudar threshold para 30x
hook.setThresholdMultiplier(30);

// Mudar intervalo para 6 horas
hook.setMinTimeInterval(6 hours);

// Mudar protocol fee para 15%
hook.setProtocolFeePercent(1500);

// Mudar fee recipient
hook.setFeeRecipient(newRecipient);
```

## ✅ Verificação

Após o deploy, verifique:

```bash
# Verificar endereço do hook
cast call <HOOK_ADDRESS> "owner()(address)"

# Verificar configurações
cast call <HOOK_ADDRESS> "thresholdMultiplier()(uint256)"
cast call <HOOK_ADDRESS> "minTimeBetweenCompounds()(uint256)"
cast call <HOOK_ADDRESS> "protocolFeePercent()(uint256)"
cast call <HOOK_ADDRESS> "feeRecipient()(address)"
```

## 🔍 Troubleshooting

### Erro: "Hook address mismatch"
- Verifique se o CREATE2_DEPLOYER está correto
- Verifique se o salt foi minerado corretamente

### Erro: "Not owner"
- Certifique-se de que o deployer é o owner
- Use `setOwner()` para transferir ownership se necessário

### Erro: "Invalid threshold multiplier"
- Threshold deve ser > 0

### Erro: "Protocol fee percent must be <= 50%"
- Protocol fee deve ser <= 5000 (50% em base 10000)

## 📚 Próximos Passos

1. ✅ Deploy do hook
2. ⏳ Criar pool com o hook
3. ⏳ Adicionar liquidez
4. ⏳ Configurar keeper para compound automático
5. ⏳ Monitorar e ajustar configurações conforme necessário

## 🔗 Links Úteis

- [Uniswap v4 Docs](https://docs.uniswap.org/contracts/v4/overview)
- [Foundry Book](https://book.getfoundry.sh/)
- [Sepolia Faucet](https://sepoliafaucet.com/)

