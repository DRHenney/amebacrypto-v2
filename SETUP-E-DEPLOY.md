# 🚀 Setup e Deploy - Passo a Passo

## Passo 1: Instalar Foundry

### Windows (PowerShell)

```powershell
# Opção 1: Usando o instalador oficial (Recomendado)
# Baixe e execute: https://github.com/foundry-rs/foundry/releases

# Opção 2: Usando curl (se tiver)
curl -L https://foundry.paradigm.xyz | bash
foundryup

# Opção 3: Manual
# 1. Baixe: https://github.com/foundry-rs/foundry/releases/latest/download/foundry_nightly_windows_amd64.tar.gz
# 2. Extraia
# 3. Adicione ao PATH ou use caminho completo
```

### Verificar Instalação

```bash
forge --version
cast --version
```

## Passo 2: Configurar Ambiente

### 2.1 Criar arquivo .env

```bash
# No diretório do projeto
cp env.example.txt .env
```

### 2.2 Editar .env

Abra o arquivo `.env` e configure:

```bash
# OBRIGATÓRIO
PRIVATE_KEY=sua_chave_privada_sem_0x
POOL_MANAGER=0x...  # Endereço do PoolManager na rede escolhida

# OPCIONAL (valores padrão serão usados se não especificar)
THRESHOLD_MULTIPLIER=20
MIN_TIME_INTERVAL=14400
PROTOCOL_FEE_PERCENT=1000
FEE_RECIPIENT=0xd9D3e3C7dc4F5d058ff24C0b71cF68846316F65c

# RPC
SEPOLIA_RPC_URL=https://rpc.sepolia.org
```

### 2.3 Obter PoolManager

**Para Sepolia (Testnet):**
- Verifique a documentação do Uniswap v4 para o endereço do PoolManager em Sepolia
- Ou faça deploy do PoolManager primeiro se necessário

**Para Mainnet:**
- Use o endereço oficial do PoolManager do Uniswap v4

## Passo 3: Instalar Dependências

```bash
# Instalar submodules do git
forge install

# Se houver problemas, instale manualmente:
forge install foundry-rs/forge-std
forge install Uniswap/v4-core
forge install Uniswap/v4-periphery
```

## Passo 4: Compilar

```bash
forge build --via-ir
```

Se houver erros:
- Verifique se todas as dependências estão instaladas
- Verifique a versão do Solidity (deve ser 0.8.24 ou compatível)

## Passo 5: Deploy

### 5.1 Simular Deploy (Recomendado primeiro)

```bash
forge script script/DeployAutoCompoundHookV2.s.sol:DeployAutoCompoundHookV2 \
    --rpc-url sepolia \
    -vvvv
```

Isso simula o deploy sem enviar transação. Verifique:
- ✅ Endereço do hook calculado
- ✅ Gas estimado
- ✅ Configurações aplicadas

### 5.2 Deploy Real em Sepolia

```bash
forge script script/DeployAutoCompoundHookV2.s.sol:DeployAutoCompoundHookV2 \
    --rpc-url sepolia \
    --broadcast \
    --verify \
    -vvvv
```

**O que acontece:**
1. Calcula endereço do hook
2. Faz deploy usando CREATE2
3. Configura valores padrão
4. Verifica contrato no Etherscan (se `--verify`)

### 5.3 Deploy em Mainnet

⚠️ **ATENÇÃO**: Só faça isso após testar em Sepolia!

```bash
forge script script/DeployAutoCompoundHookV2.s.sol:DeployAutoCompoundHookV2 \
    --rpc-url mainnet \
    --broadcast \
    --verify \
    -vvvv
```

## Passo 6: Verificar Deploy

### 6.1 Verificar no Explorer

- Sepolia: https://sepolia.etherscan.io/address/<HOOK_ADDRESS>
- Mainnet: https://etherscan.io/address/<HOOK_ADDRESS>

### 6.2 Verificar via Cast

```bash
# Verificar owner
cast call <HOOK_ADDRESS> "owner()(address)" --rpc-url sepolia

# Verificar configurações
cast call <HOOK_ADDRESS> "thresholdMultiplier()(uint256)" --rpc-url sepolia
cast call <HOOK_ADDRESS> "minTimeBetweenCompounds()(uint256)" --rpc-url sepolia
cast call <HOOK_ADDRESS> "protocolFeePercent()(uint256)" --rpc-url sepolia
cast call <HOOK_ADDRESS> "feeRecipient()(address)" --rpc-url sepolia
```

## Passo 7: Configurar Pool

Após o deploy, configure sua primeira pool:

```solidity
// 1. Habilitar pool
hook.setPoolConfig(poolKey, true);

// 2. Configurar preços (USD)
hook.setTokenPricesUSD(poolKey, 3000e18, 1e18); // Ex: ETH=$3000, USDC=$1

// 3. Configurar tick range
hook.setPoolTickRange(poolKey, -887272, 887272); // Full range
```

## Troubleshooting

### Erro: "forge: command not found"
- Foundry não está instalado ou não está no PATH
- Instale Foundry (Passo 1)

### Erro: "Insufficient funds"
- Adicione ETH/ETH Sepolia à carteira
- Sepolia Faucet: https://sepoliafaucet.com/

### Erro: "Hook address mismatch"
- Verifique CREATE2_DEPLOYER
- Verifique se o salt foi minerado corretamente

### Erro: "PoolManager not found"
- Verifique endereço do POOL_MANAGER no .env
- Confirme que está na rede correta

### Erro: "Module not found"
- Execute `forge install` novamente
- Verifique se lib/ está presente

## Próximos Passos

1. ✅ Deploy do hook
2. ⏳ Criar pool com o hook
3. ⏳ Adicionar liquidez
4. ⏳ Configurar keeper
5. ⏳ Monitorar e ajustar

## Links Úteis

- [Foundry Installation](https://book.getfoundry.sh/getting-started/installation)
- [Sepolia Faucet](https://sepoliafaucet.com/)
- [Uniswap v4 Docs](https://docs.uniswap.org/contracts/v4/overview)
- [Etherscan Sepolia](https://sepolia.etherscan.io/)

