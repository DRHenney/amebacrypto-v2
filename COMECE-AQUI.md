# 🚀 COMECE AQUI - Deploy AmebaCrypto v2

## ✅ Status Atual

- ✅ Código implementado e testado
- ✅ Script de deploy criado
- ✅ Documentação completa
- ⏳ **Próximo passo: Instalar Foundry e fazer deploy**

## 📋 Checklist Rápido

### 1. Instalar Foundry
```powershell
# Opção mais fácil: Baixe de https://github.com/foundry-rs/foundry/releases
# Ou use: curl -L https://foundry.paradigm.xyz | bash
```

### 2. Configurar .env
```bash
# Copie o template
cp env.example.txt .env

# Edite .env com:
PRIVATE_KEY=sua_chave_privada
POOL_MANAGER=0x...  # Endereço do PoolManager
```

### 3. Instalar Dependências
```bash
forge install
```

### 4. Compilar
```bash
forge build --via-ir
```

### 5. Deploy (Sepolia primeiro!)
```bash
# Simular (sem enviar)
forge script script/DeployAutoCompoundHookV2.s.sol:DeployAutoCompoundHookV2 --rpc-url sepolia -vvvv

# Deploy real
forge script script/DeployAutoCompoundHookV2.s.sol:DeployAutoCompoundHookV2 --rpc-url sepolia --broadcast --verify -vvvv
```

## 📚 Documentação Completa

1. **SETUP-E-DEPLOY.md** - Guia passo a passo completo
2. **GUIA-DEPLOY-V2.md** - Detalhes técnicos do deploy
3. **DEPLOY-RESUMO.md** - Resumo rápido
4. **TESTES-CONFIGURACOES.md** - Documentação dos testes

## 🆘 Precisa de Ajuda?

- Verifique **SETUP-E-DEPLOY.md** para troubleshooting
- Todos os scripts estão prontos
- Basta seguir os passos acima

## 🎯 Próximos Passos Após Deploy

1. Verificar deploy no Etherscan
2. Configurar primeira pool
3. Adicionar liquidez
4. Configurar keeper

---

**Tudo está pronto! Só falta instalar o Foundry e executar o deploy.** 🚀

