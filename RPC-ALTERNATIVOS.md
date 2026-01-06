# 🔗 RPCs Alternativos para Sepolia

O RPC padrão (`https://rpc.sepolia.org`) pode estar temporariamente indisponível. Use um dos RPCs alternativos abaixo.

## RPCs Gratuitos para Sepolia

### Opção 1: Alchemy (Recomendado)
```
https://eth-sepolia.g.alchemy.com/v2/YOUR_API_KEY
```
- Crie conta em: https://www.alchemy.com/
- Obtenha API key gratuita
- Substitua `YOUR_API_KEY` pela sua chave

### Opção 2: Infura
```
https://sepolia.infura.io/v3/YOUR_PROJECT_ID
```
- Crie conta em: https://www.infura.io/
- Obtenha Project ID gratuito
- Substitua `YOUR_PROJECT_ID` pelo seu ID

### Opção 3: PublicNode
```
https://ethereum-sepolia-rpc.publicnode.com
```
- Não requer API key
- Pode ter rate limits

### Opção 4: QuickNode
```
https://your-endpoint.sepolia.quiknode.pro/YOUR_API_KEY/
```
- Crie conta em: https://www.quicknode.com/
- Obtenha endpoint gratuito

### Opção 5: Ankr
```
https://rpc.ankr.com/eth_sepolia
```
- Não requer API key
- Público e gratuito

## Como Configurar

### 1. Atualizar .env

Edite o arquivo `.env` e adicione/atualize:

```bash
# Opção com Alchemy (recomendado)
SEPOLIA_RPC_URL=https://eth-sepolia.g.alchemy.com/v2/SUA_API_KEY

# Ou com Infura
# SEPOLIA_RPC_URL=https://sepolia.infura.io/v3/SEU_PROJECT_ID

# Ou público (sem API key)
# SEPOLIA_RPC_URL=https://rpc.ankr.com/eth_sepolia
```

### 2. Atualizar foundry.toml (opcional)

O `foundry.toml` já está configurado para usar `${SEPOLIA_RPC_URL}` do `.env`.

### 3. Testar RPC

```bash
cast block-number --rpc-url sepolia
```

Se retornar um número, o RPC está funcionando.

## Deploy com RPC Alternativo

Após configurar, execute:

```bash
# Deploy do PoolManager
forge script script/DeployPoolManagerSepolia.s.sol:DeployPoolManagerSepolia --rpc-url sepolia --broadcast -vvvv

# Deploy do Hook
forge script script/DeployAutoCompoundHookV2.s.sol:DeployAutoCompoundHookV2 --rpc-url sepolia --broadcast -vvvv
```

## Troubleshooting

### Erro 522 (Cloudflare)
- RPC temporariamente indisponível
- Use um RPC alternativo

### Erro de autenticação
- Verifique se a API key está correta
- Verifique se a conta está ativa

### Rate limit
- Use um RPC com API key (Alchemy, Infura)
- Ou aguarde alguns minutos

## Recomendação

Para produção/testes sérios, use **Alchemy** ou **Infura** com API key:
- Mais confiável
- Melhor performance
- Sem rate limits (ou limites maiores)
- Suporte técnico

Para testes rápidos, use **Ankr** ou **PublicNode** (sem API key).

