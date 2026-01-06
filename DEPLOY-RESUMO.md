# 📦 Resumo de Deploy - AmebaCrypto v2

## ✅ O que foi preparado

1. **Script de Deploy**: `script/DeployAutoCompoundHookV2.s.sol`
   - Deploy automático do hook
   - Configuração de valores padrão
   - Suporte a configurações customizadas via .env

2. **Documentação**:
   - `GUIA-DEPLOY-V2.md` - Guia completo de deploy
   - `env.example.txt` - Template de configuração

3. **Configurações**:
   - `foundry.toml` atualizado com RPC endpoints

## 🎯 Recomendação: Deploy em Sepolia (Testnet) Primeiro

**Por quê?**
- ✅ Testar sem risco
- ✅ Gas fees baixos
- ✅ Verificar configurações
- ✅ Validar funcionalidades

## 🚀 Passos Rápidos para Deploy

### 1. Configurar Ambiente

```bash
# Copiar template
cp env.example.txt .env

# Editar .env com seus valores
# PRIVATE_KEY=sua_chave_privada
# POOL_MANAGER=endereco_do_poolmanager
```

### 2. Compilar

```bash
forge build --via-ir
```

### 3. Deploy em Sepolia

```bash
forge script script/DeployAutoCompoundHookV2.s.sol:DeployAutoCompoundHookV2 \
    --rpc-url sepolia \
    --broadcast \
    --verify \
    -vvvv
```

### 4. Verificar Deploy

```bash
# Verificar owner
cast call <HOOK_ADDRESS> "owner()(address)"

# Verificar configurações
cast call <HOOK_ADDRESS> "thresholdMultiplier()(uint256)"
cast call <HOOK_ADDRESS> "minTimeBetweenCompounds()(uint256)"
cast call <HOOK_ADDRESS> "protocolFeePercent()(uint256)"
```

## 📊 Comparação: Testnet vs Mainnet

| Aspecto | Sepolia (Testnet) | Mainnet |
|---------|-------------------|---------|
| **Custo** | Gratuito (faucet) | Real (ETH) |
| **Risco** | Nenhum | Alto |
| **Validação** | Testar tudo | Produção |
| **Recomendado para** | Primeiro deploy | Após testes |

## ⚙️ Configurações Padrão vs Customizadas

### Usar Padrões (Recomendado para começar)
```bash
# Apenas configure PRIVATE_KEY e POOL_MANAGER
# Os valores padrão serão usados:
# - thresholdMultiplier = 20
# - minTimeBetweenCompounds = 4 hours
# - protocolFeePercent = 10%
```

### Customizar
```bash
# Adicione no .env:
THRESHOLD_MULTIPLIER=30
MIN_TIME_INTERVAL=21600  # 6 horas
PROTOCOL_FEE_PERCENT=1500  # 15%
FEE_RECIPIENT=0x...
```

## 🔐 Segurança

### Antes do Deploy
- ✅ Teste em testnet primeiro
- ✅ Verifique PRIVATE_KEY está correta
- ✅ Confirme POOL_MANAGER está correto
- ✅ Revise configurações no .env

### Após o Deploy
- ✅ Guarde o endereço do hook
- ✅ Verifique ownership
- ✅ Teste configurações básicas
- ✅ Configure pools gradualmente

## 📝 Checklist de Deploy

### Pré-Deploy
- [ ] Foundry instalado
- [ ] .env configurado
- [ ] PoolManager deployado
- [ ] Carteira com ETH/ETH Sepolia
- [ ] Código compilado (`forge build`)

### Deploy
- [ ] Executar script de deploy
- [ ] Verificar transação no explorer
- [ ] Confirmar endereço do hook

### Pós-Deploy
- [ ] Verificar owner
- [ ] Verificar configurações padrão
- [ ] Configurar primeira pool
- [ ] Testar funcionalidades básicas

## 🆘 Troubleshooting

### "Hook address mismatch"
- Verifique CREATE2_DEPLOYER
- Verifique se o salt foi minerado corretamente

### "Insufficient funds"
- Adicione ETH/ETH Sepolia à carteira
- Use faucet para Sepolia: https://sepoliafaucet.com/

### "PoolManager not found"
- Verifique endereço do POOL_MANAGER
- Confirme que está na rede correta

## 🎯 Próximos Passos Após Deploy

1. **Configurar Pool**
   ```solidity
   hook.setPoolConfig(poolKey, true);
   hook.setTokenPricesUSD(poolKey, price0, price1);
   hook.setPoolTickRange(poolKey, tickLower, tickUpper);
   ```

2. **Criar Pool com Hook**
   - Use o endereço do hook no campo `hooks` da PoolKey

3. **Adicionar Liquidez**
   - Adicione liquidez inicial à pool

4. **Configurar Keeper**
   - Configure keeper para executar compound periodicamente

## 📚 Documentação Adicional

- `GUIA-DEPLOY-V2.md` - Guia detalhado
- `TESTES-CONFIGURACOES.md` - Documentação de testes
- `README.md` - Visão geral do projeto

## 💡 Dica Final

**Comece simples**: Use os valores padrão primeiro, teste em Sepolia, e depois ajuste conforme necessário. As configurações podem ser alteradas a qualquer momento pelo owner!

