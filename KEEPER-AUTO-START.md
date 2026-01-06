# 🤖 Keeper com Início Automático

## 📋 Visão Geral

O keeper agora é **ativado automaticamente** quando uma nova pool é criada com o hook. Não é mais necessário configurar manualmente cada pool - o keeper detecta e começa a monitorar automaticamente.

## ✨ Como Funciona

### 1. Quando uma Pool é Criada

Quando alguém cria uma pool usando o `AutoCompoundHook`:

1. **Pool é inicializada** no PoolManager
2. **Hook recebe callback** `_afterInitialize()`
3. **Hook habilita automaticamente** a pool (`enabled = true`)
4. **Hook emite evento** `PoolAutoEnabled` com todas as informações da pool

### 2. Keeper Detecta Automaticamente

O keeper (`keeper-bot-auto-start.ps1`) está rodando e:

1. **Monitora eventos** `PoolAutoEnabled` do hook
2. **Detecta nova pool** automaticamente
3. **Adiciona à lista** de pools monitoradas
4. **Inicia verificação** imediatamente
5. **Continua monitorando** periodicamente

## 🚀 Como Usar

### Iniciar o Keeper

```powershell
.\keeper-bot-auto-start.ps1
```

### Opções Disponíveis

```powershell
# Executar uma vez e parar
.\keeper-bot-auto-start.ps1 -RunOnce

# Intervalo personalizado (padrão: 60 minutos)
.\keeper-bot-auto-start.ps1 -IntervalMinutes 30

# Modo verbose
.\keeper-bot-auto-start.ps1 -Verbose

# Rede específica
.\keeper-bot-auto-start.ps1 -Network sepolia
```

## 📊 Evento PoolAutoEnabled

O hook emite automaticamente este evento quando uma pool é inicializada:

```solidity
event PoolAutoEnabled(
    PoolId indexed poolId,
    Currency currency0,
    Currency currency1,
    uint24 fee,
    int24 tickSpacing,
    address hookAddress
);
```

**Parâmetros:**
- `poolId`: ID único da pool
- `currency0`: Token0 da pool
- `currency1`: Token1 da pool
- `fee`: Taxa da pool (ex: 10000 = 1.0%)
- `tickSpacing`: Espaçamento dos ticks
- `hookAddress`: Endereço do hook (este contrato)

## 🔄 Fluxo Completo

```
1. Usuário cria pool com hook
   ↓
2. PoolManager.initialize() é chamado
   ↓
3. Hook._afterInitialize() é executado
   ↓
4. Hook habilita pool e emite PoolAutoEnabled
   ↓
5. Keeper detecta evento PoolAutoEnabled
   ↓
6. Keeper adiciona pool à lista de monitoramento
   ↓
7. Keeper inicia verificação imediatamente
   ↓
8. Keeper continua monitorando periodicamente
   ↓
9. Quando há fees suficientes, executa compound
```

## 📝 Arquivos

### `pools-monitoradas.json`

O keeper salva todas as pools detectadas neste arquivo:

```json
{
  "0x1234...": {
    "PoolId": "0x1234...",
    "Token0": "0x...",
    "Token1": "0x...",
    "Fee": 10000,
    "TickSpacing": 60,
    "HookAddress": "0x...",
    "PoolManager": "0x...",
    "DetectedAt": "2025-01-06 16:30:00"
  }
}
```

## ✅ Vantagens

1. **Zero Configuração**: Não precisa adicionar pools manualmente
2. **Detecção Automática**: Detecta novas pools em tempo real
3. **Início Imediato**: Começa a monitorar assim que detecta
4. **Persistência**: Salva pools detectadas para não perder
5. **Escalável**: Monitora quantas pools forem criadas

## 🔍 Monitoramento

O keeper verifica:

- **A cada 5 minutos**: Novas pools via eventos
- **A cada X minutos** (configurável): Status de compound de todas as pools

## ⚙️ Configuração

Certifique-se de ter no `.env`:

```env
PRIVATE_KEY=0x...
POOL_MANAGER=0x...
HOOK_ADDRESS=0x...
SEPOLIA_RPC_URL=https://...
# ou
MAINNET_RPC_URL=https://...
```

## 🎯 Resultado

**Antes**: 
- Pool criada → Ninguém monitora → Fees acumulam → Nunca faz compound

**Agora**:
- Pool criada → Keeper detecta automaticamente → Começa a monitorar → Executa compound quando possível

## 📌 Notas

- O keeper precisa estar **rodando** para detectar novas pools
- Pools criadas antes do keeper iniciar serão detectadas nos primeiros blocos verificados
- O keeper verifica os últimos 1000 blocos ao iniciar
- Pools são salvas em `pools-monitoradas.json` para persistência

