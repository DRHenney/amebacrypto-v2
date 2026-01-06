# 🔍 Detecção Automática de Pools - Guia Completo

## ✅ Implementação Completa

Foram criadas **3 soluções** para detectar automaticamente quando novas pools são criadas:

### 1. 🤖 Bot PowerShell com Detecção (`keeper-bot-auto-detect.ps1`)

Bot que monitora eventos e detecta novas pools automaticamente.

**Como usar:**
```powershell
# Executar bot com detecção automática
.\keeper-bot-auto-detect.ps1

# Com intervalo de detecção personalizado (verifica a cada 5 minutos)
.\keeper-bot-auto-detect.ps1 -CheckIntervalSeconds 300
```

**Funcionalidades:**
- ✅ Monitora eventos do PoolManager
- ✅ Detecta pools criadas com o hook
- ✅ Adiciona automaticamente ao monitoramento
- ✅ Executa keeper para todas as pools detectadas
- ✅ Salva pools detectadas em `pools-detectadas.json`

### 2. 📡 Monitor Node.js (`monitor-pools-node.js`)

Monitor dedicado usando Node.js e ethers.js para detectar eventos em tempo real.

**Pré-requisitos:**
```bash
npm install ethers dotenv
```

**Como usar:**
```bash
# Executar monitor
node monitor-pools-node.js
```

**Funcionalidades:**
- ✅ Monitora eventos em tempo real
- ✅ Detecta novas pools instantaneamente
- ✅ Salva em `pools-detectadas.json`
- ✅ Pode ser integrado com o bot PowerShell

### 3. 🔧 Script Solidity (`script/DetectNewPools.s.sol`)

Script para verificar pools específicas ou buscar informações.

**Como usar:**
```bash
# Verificar uma pool específica
forge script script/DetectNewPools.s.sol:DetectNewPools --rpc-url sepolia
```

## 🚀 Como Funciona

### Fluxo de Detecção

1. **Monitoramento de Eventos**
   - Monitora eventos `Initialize` do PoolManager
   - Filtra pools que usam o hook configurado

2. **Detecção de Nova Pool**
   - Quando uma pool é criada com o hook, o evento é capturado
   - Verifica se é o hook correto (se configurado)
   - Adiciona à lista de pools monitoradas

3. **Execução Automática**
   - Bot executa keeper para todas as pools detectadas
   - Verifica condições de compound
   - Executa quando possível

### Arquivo de Pools Detectadas

As pools são salvas em `pools-detectadas.json`:

```json
{
  "0x...": {
    "poolId": "0x...",
    "poolManager": "0x...",
    "hookAddress": "0x...",
    "token0": "0x...",
    "token1": "0x...",
    "fee": "3000",
    "tickSpacing": "60",
    "detectedAt": "2024-01-15T10:00:00.000Z"
  }
}
```

## 📋 Configuração

### .env

```env
# RPC
SEPOLIA_RPC_URL=https://...
# ou
MAINNET_RPC_URL=https://...

# PoolManager (para monitorar eventos)
POOL_MANAGER=0x...

# Hook (opcional - filtra apenas pools com este hook)
HOOK_ADDRESS=0x...

# Private Key (para executar keeper)
PRIVATE_KEY=0x...
```

### Node.js (para monitor)

```bash
# Instalar dependências
npm install ethers dotenv

# Ou com yarn
yarn add ethers dotenv
```

## 🎯 Uso Recomendado

### Para Desenvolvimento/Testes

1. **Usar bot PowerShell**:
   ```powershell
   .\keeper-bot-auto-detect.ps1 -RunOnce
   ```

2. **Verificar pools detectadas**:
   ```powershell
   Get-Content pools-detectadas.json | ConvertFrom-Json
   ```

### Para Produção

1. **Opção 1: Bot PowerShell** (mais simples)
   ```powershell
   .\keeper-bot-auto-detect.ps1
   ```

2. **Opção 2: Monitor Node.js + Bot** (mais robusto)
   ```bash
   # Terminal 1: Monitor de eventos
   node monitor-pools-node.js
   
   # Terminal 2: Bot keeper
   .\keeper-bot-automatico.ps1
   ```

3. **Opção 3: The Graph Subgraph** (mais escalável)
   - Criar subgraph para indexar eventos
   - Bot consulta subgraph para novas pools

## 🔄 Integração Completa

### Fluxo Automático Completo

1. **Pool é criada** → Evento `Initialize` emitido
2. **Monitor detecta** → Adiciona à lista
3. **Bot verifica** → Executa keeper para todas as pools
4. **Compound executado** → Quando condições atendidas

### Exemplo de Uso

```powershell
# 1. Iniciar bot com detecção automática
.\keeper-bot-auto-detect.ps1

# 2. Criar nova pool (em outro terminal ou via script)
forge script script/CreatePoolUSDCWETH.s.sol:CreatePoolUSDCWETH --rpc-url sepolia --broadcast

# 3. Bot detecta automaticamente e começa a monitorar!
```

## 📊 Monitoramento

### Ver Pools Detectadas

```powershell
# PowerShell
Get-Content pools-detectadas.json | ConvertFrom-Json

# Node.js
node -e "console.log(require('./pools-detectadas.json'))"
```

### Logs

- **Bot PowerShell**: Saída no console
- **Monitor Node.js**: Saída no console
- **Pools detectadas**: Salvas em `pools-detectadas.json`

## ⚙️ Opções Avançadas

### Verificar Apenas Pools Específicas

Edite `pools-detectadas.json` e remova pools que não quer monitorar.

### Intervalo de Detecção

```powershell
# Verificar novas pools a cada 5 minutos
.\keeper-bot-auto-detect.ps1 -CheckIntervalSeconds 300

# Verificar a cada 1 minuto (mais frequente)
.\keeper-bot-auto-detect.ps1 -CheckIntervalSeconds 60
```

### Filtrar por Hook

Configure `HOOK_ADDRESS` no `.env` para monitorar apenas pools com esse hook específico.

## 🐛 Troubleshooting

### Pools não são detectadas

1. Verifique se `POOL_MANAGER` está correto no `.env`
2. Verifique se RPC está funcionando
3. Verifique se eventos estão sendo emitidos
4. Use modo verbose: `.\keeper-bot-auto-detect.ps1 -Verbose`

### Monitor Node.js não funciona

1. Instale dependências: `npm install ethers dotenv`
2. Verifique se `.env` está configurado
3. Verifique se RPC está acessível

### Bot não executa keeper para novas pools

1. Verifique se pool foi adicionada a `pools-detectadas.json`
2. Verifique se endereços estão corretos
3. Execute manualmente para testar: `.\keeper-bot-automatico.ps1 -RunOnce`

## ✅ Checklist

- [ ] `.env` configurado com `POOL_MANAGER` e `HOOK_ADDRESS`
- [ ] RPC URL funcionando
- [ ] Bot executado: `.\keeper-bot-auto-detect.ps1`
- [ ] Pool criada com hook
- [ ] Pool detectada e adicionada
- [ ] Keeper executando para pool detectada

## 🎉 Pronto!

Agora o sistema detecta automaticamente quando novas pools são criadas e começa a monitorá-las automaticamente!

---

**Arquivos criados:**
- `keeper-bot-auto-detect.ps1` - Bot com detecção automática
- `monitor-pools-node.js` - Monitor Node.js
- `script/DetectNewPools.s.sol` - Script de verificação
- `DETECCAO-AUTOMATICA-POOLS.md` - Este guia

