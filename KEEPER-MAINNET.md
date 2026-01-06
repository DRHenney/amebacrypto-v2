# 🚨 Keeper no Mainnet - Guia de Segurança

## ⚠️ Considerações Importantes para Mainnet

### Sim, o bot local funcionará no Mainnet!

O bot `keeper-bot-automatico.ps1` foi atualizado para suportar tanto **Sepolia** quanto **Mainnet**.

## 🔧 Como Usar no Mainnet

### 1. Configurar .env para Mainnet

Adicione ao seu `.env`:

```env
# Mainnet RPC
MAINNET_RPC_URL=https://eth-mainnet.g.alchemy.com/v2/YOUR_API_KEY
# ou
MAINNET_RPC_URL=https://mainnet.infura.io/v3/YOUR_PROJECT_ID

# Private Key (mesma para ambas as redes, mas CUIDADO!)
PRIVATE_KEY=0x...

# Endereços do Mainnet
POOL_MANAGER=0x...
HOOK_ADDRESS=0x...
TOKEN0_ADDRESS=0x...
TOKEN1_ADDRESS=0x...
```

### 2. Executar Bot no Mainnet

```powershell
# O bot detecta automaticamente se você tem MAINNET_RPC_URL configurado
.\keeper-bot-automatico.ps1

# Ou especificar explicitamente
.\keeper-bot-automatico.ps1 -Network mainnet

# Executar uma vez (para teste)
.\keeper-bot-automatico.ps1 -Network mainnet -RunOnce
```

### 3. Confirmação de Segurança

Quando você executar no mainnet, o bot pedirá confirmação:

```
=== AVISO: MAINNET DETECTADO ===
Você está executando o keeper no MAINNET!
Certifique-se de:
  1. Private key está segura e não compartilhada
  2. Carteira tem ETH suficiente para gas
  3. Contratos foram auditados e testados
  4. Configurações estão corretas

Continuar com mainnet? (digite 'SIM' para confirmar)
```

## 🛡️ Checklist de Segurança para Mainnet

Antes de executar no mainnet, verifique:

### Segurança da Carteira
- [ ] Private key está em arquivo seguro (não commitado no git)
- [ ] Carteira tem ETH suficiente para múltiplas execuções de gas
- [ ] Carteira não é a principal (use uma carteira dedicada)
- [ ] Backup da private key está seguro

### Contratos
- [ ] Contratos foram auditados
- [ ] Testes extensivos realizados em testnet
- [ ] Endereços dos contratos verificados no Etherscan
- [ ] Configurações do hook estão corretas

### Configuração
- [ ] RPC URL do mainnet está correto e funcional
- [ ] Endereços dos tokens estão corretos (mainnet)
- [ ] Pool Manager está correto
- [ ] Hook address está correto

### Monitoramento
- [ ] Tem sistema de monitoramento/alertas
- [ ] Logs estão sendo salvos
- [ ] Tem backup do bot (Gelato como fallback)

## 💰 Custos no Mainnet

### Gas Costs Estimados

- **Verificação (canExecuteCompound)**: ~50k gas (~$0.50-2.00 dependendo do gas price)
- **Compound Executado**: ~200k-300k gas (~$2-10 dependendo do gas price)

### Recomendações

1. **Gas Price**: Configure `--slow` para usar gas price mais baixo
2. **Saldo Mínimo**: Mantenha pelo menos 0.1-0.5 ETH na carteira
3. **Monitoramento**: Configure alertas para saldo baixo

## 🔄 Diferenças Sepolia vs Mainnet

| Aspecto | Sepolia (Testnet) | Mainnet |
|---------|------------------|---------|
| **Custos** | Gratuito (ETH de faucet) | Real (ETH real) |
| **Gas Price** | Muito baixo | Variável (pode ser alto) |
| **Riscos** | Nenhum (testnet) | Real (ETH real) |
| **RPC** | Sepolia RPC | Mainnet RPC |
| **Tokens** | Testnet tokens | Tokens reais |

## 🚀 Execução Recomendada

### Para Desenvolvimento/Testes:
```powershell
# Sempre teste primeiro em Sepolia
.\keeper-bot-automatico.ps1 -Network sepolia -RunOnce
```

### Para Produção (Mainnet):
```powershell
# 1. Teste uma vez primeiro
.\keeper-bot-automatico.ps1 -Network mainnet -RunOnce

# 2. Se tudo OK, execute em loop
.\keeper-bot-automatico.ps1 -Network mainnet
```

## 📊 Monitoramento no Mainnet

### Verificar Status

```bash
# Verificar se pode executar (sem broadcast)
forge script script/AutoCompoundKeeper.s.sol:AutoCompoundKeeper --rpc-url mainnet

# Verificar fees acumuladas
forge script script/VerifyPoolExists.s.sol:VerifyPoolExists --rpc-url mainnet
```

### Logs e Alertas

- Configure logs para arquivo:
  ```powershell
  .\keeper-bot-automatico.ps1 -Network mainnet *> keeper-mainnet.log
  ```

- Configure alertas para:
  - Falhas de execução
  - Saldo baixo de ETH
  - Compound executado com sucesso

## ⚡ Alternativas Recomendadas para Mainnet

Para produção no mainnet, considere:

1. **Gelato Network** (Recomendado)
   - Mais confiável
   - Não requer servidor sempre online
   - Paga apenas quando executa

2. **Bot Local como Backup**
   - Use o bot local como backup do Gelato
   - Ou vice-versa

3. **OpenZeppelin Defender**
   - Serviço gerenciado
   - Monitoramento integrado

## 🔐 Boas Práticas

1. **Nunca compartilhe sua private key**
2. **Use carteira dedicada** (não sua carteira principal)
3. **Mantenha saldo suficiente** para múltiplas execuções
4. **Monitore regularmente** as execuções
5. **Tenha backup** (Gelato ou outro serviço)
6. **Teste extensivamente** em testnet antes

## 📝 Exemplo de Configuração Completa

```env
# Mainnet
MAINNET_RPC_URL=https://eth-mainnet.g.alchemy.com/v2/YOUR_KEY
PRIVATE_KEY=0x...
POOL_MANAGER=0x...
HOOK_ADDRESS=0x...
TOKEN0_ADDRESS=0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48  # USDC
TOKEN1_ADDRESS=0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2  # WETH

# Sepolia (para testes)
SEPOLIA_RPC_URL=https://eth-sepolia.g.alchemy.com/v2/YOUR_KEY
```

## ✅ Resumo

**Sim, o bot funciona no mainnet!** Mas:

- ⚠️ **Teste primeiro em Sepolia**
- ⚠️ **Verifique todas as configurações**
- ⚠️ **Use carteira dedicada**
- ⚠️ **Mantenha saldo suficiente**
- ⚠️ **Monitore regularmente**
- 💡 **Considere Gelato para produção**

---

**Pronto para usar no mainnet!** 🚀

