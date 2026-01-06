# ⚙️ Como Configurar o .env

## Arquivo .env Criado

O arquivo `.env` foi criado a partir do template. Agora você precisa preenchê-lo com suas informações.

## 📝 Campos Obrigatórios

### 1. PRIVATE_KEY
Sua chave privada da carteira (sem o prefixo `0x`)

**⚠️ SEGURANÇA**: 
- NUNCA compartilhe sua chave privada
- NUNCA faça commit do .env no Git
- Use uma carteira separada para testes

**Exemplo:**
```
PRIVATE_KEY=abc123def456... (sua chave privada completa)
```

### 2. POOL_MANAGER
Endereço do PoolManager do Uniswap v4 na rede escolhida

**Para Sepolia (Testnet):**
- Verifique a documentação do Uniswap v4 para o endereço oficial
- Ou faça deploy do PoolManager primeiro se necessário

**Para Mainnet:**
- Use o endereço oficial do PoolManager do Uniswap v4

**Exemplo:**
```
POOL_MANAGER=0x1234567890123456789012345678901234567890
```

## 📋 Campos Opcionais (Valores Padrão)

Estes campos já estão configurados com valores padrão. Você pode alterá-los se necessário:

### THRESHOLD_MULTIPLIER
Multiplicador de threshold para compound (padrão: 20)
- Fees devem ser ≥ thresholdMultiplier x custo de gas
- Exemplo: 20 = fees devem ser 20x o custo de gas

### MIN_TIME_INTERVAL
Intervalo mínimo entre compounds em segundos (padrão: 14400 = 4 horas)
- Exemplo: 14400 = 4 horas, 21600 = 6 horas

### PROTOCOL_FEE_PERCENT
Porcentagem de protocol fee em base 10000 (padrão: 1000 = 10%)
- Exemplo: 1000 = 10%, 1500 = 15%, máximo 5000 = 50%

### FEE_RECIPIENT
Endereço que recebe protocol fees (padrão já configurado)
- Você pode alterar para seu próprio endereço

### SEPOLIA_RPC_URL
URL do RPC para Sepolia (padrão: https://rpc.sepolia.org)
- Você pode usar outros providers se preferir

## 🔧 Como Editar

### Opção 1: Editor de Texto
1. Abra o arquivo `.env` em um editor de texto (Notepad++, VS Code, etc.)
2. Preencha os campos obrigatórios
3. Salve o arquivo

### Opção 2: PowerShell
```powershell
# Editar com notepad
notepad .env

# Ou com VS Code (se instalado)
code .env
```

## ✅ Verificação

Após configurar, verifique se está correto:

```powershell
# Verificar se o arquivo existe
Test-Path .env

# Ver conteúdo (sem mostrar PRIVATE_KEY completo)
Get-Content .env | Where-Object { $_ -notlike "*PRIVATE_KEY*" -or $_ -like "*PRIVATE_KEY=*" }
```

## 🚨 Segurança

### ⚠️ IMPORTANTE - NUNCA FAÇA:

1. ❌ Commit do .env no Git
2. ❌ Compartilhar sua chave privada
3. ❌ Usar a mesma carteira de produção para testes
4. ❌ Deixar o .env em repositórios públicos

### ✅ FAÇA:

1. ✅ Adicione `.env` ao `.gitignore`
2. ✅ Use carteira separada para testes
3. ✅ Mantenha backup seguro da chave privada
4. ✅ Use variáveis de ambiente em produção

## 📚 Próximos Passos

Após configurar o .env:

1. ✅ Verificar configuração
2. ⏳ Instalar dependências: `forge install`
3. ⏳ Compilar: `forge build --via-ir`
4. ⏳ Deploy: `forge script script/DeployAutoCompoundHookV2.s.sol:DeployAutoCompoundHookV2 --rpc-url sepolia --broadcast -vvvv`

## 🔗 Links Úteis

- **Sepolia Faucet**: https://sepoliafaucet.com/ (para obter ETH de teste)
- **Uniswap v4 Docs**: https://docs.uniswap.org/contracts/v4/overview
- **Etherscan Sepolia**: https://sepolia.etherscan.io/

---

**Dica**: Comece com Sepolia (testnet) para testar antes de usar mainnet!

