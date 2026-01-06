# 📊 Status do Deploy - AmebaCrypto v2

## ✅ Concluído

1. ✅ **Foundry instalado** - Versão 1.5.1
2. ✅ **Dependências instaladas** - lib/ copiada e configurada
3. ✅ **Projeto compilado** - Sem erros de compilação
4. ✅ **PRIVATE_KEY configurado** - No arquivo .env
5. ✅ **Scripts de deploy criados**:
   - `DeployPoolManagerSepolia.s.sol`
   - `DeployAutoCompoundHookV2.s.sol`

## ⏳ Pendente

1. ⏳ **RPC URL configurado** - Precisa de API key
2. ⏳ **Deploy do PoolManager** - Aguardando RPC
3. ⏳ **POOL_MANAGER configurado** - Será feito após deploy do PoolManager
4. ⏳ **Deploy do Hook** - Aguardando PoolManager

## 🔧 Próximos Passos

### Passo 1: Obter RPC com API Key

Escolha um dos serviços gratuitos:

**Alchemy (Recomendado)**
1. Acesse: https://www.alchemy.com/
2. Crie conta gratuita
3. Crie um novo app (escolha Sepolia)
4. Copie a API key

**Infura**
1. Acesse: https://www.infura.io/
2. Crie conta gratuita
3. Crie um novo projeto
4. Copie o Project ID

**Ankr**
1. Acesse: https://www.ankr.com/rpc/
2. Crie conta gratuita
3. Gere API key
4. Use o endpoint fornecido

### Passo 2: Configurar .env

Edite o arquivo `.env` e adicione:

```bash
SEPOLIA_RPC_URL=https://eth-sepolia.g.alchemy.com/v2/SUA_API_KEY
# ou
# SEPOLIA_RPC_URL=https://sepolia.infura.io/v3/SEU_PROJECT_ID
```

### Passo 3: Deploy do PoolManager

```bash
forge script script/DeployPoolManagerSepolia.s.sol:DeployPoolManagerSepolia --rpc-url sepolia --broadcast -vvvv
```

**Importante**: Copie o endereço do PoolManager que será exibido no output.

### Passo 4: Configurar POOL_MANAGER

Edite o arquivo `.env` e adicione:

```bash
POOL_MANAGER=0x...  # Endereço retornado no passo anterior
```

### Passo 5: Deploy do Hook

```bash
forge script script/DeployAutoCompoundHookV2.s.sol:DeployAutoCompoundHookV2 --rpc-url sepolia --broadcast -vvvv
```

## 📝 Checklist

- [ ] RPC URL configurado com API key
- [ ] Deploy do PoolManager executado
- [ ] POOL_MANAGER adicionado ao .env
- [ ] Deploy do Hook executado
- [ ] Hook verificado no Etherscan
- [ ] Configurações do hook verificadas

## 🔗 Links Úteis

- **Alchemy**: https://www.alchemy.com/
- **Infura**: https://www.infura.io/
- **Ankr RPC**: https://www.ankr.com/rpc/
- **Sepolia Faucet**: https://sepoliafaucet.com/
- **Etherscan Sepolia**: https://sepolia.etherscan.io/

## 📚 Documentação

- `RPC-ALTERNATIVOS.md` - Guia completo de RPCs
- `SETUP-E-DEPLOY.md` - Guia completo de setup
- `GUIA-DEPLOY-V2.md` - Detalhes técnicos do deploy

---

**Tudo está pronto! Só falta configurar o RPC e executar os deploys.** 🚀

