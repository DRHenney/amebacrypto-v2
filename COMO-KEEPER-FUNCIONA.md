# 🤖 Como o Keeper Auto-Start Funciona

## ⚠️ Importante: O Keeper é um Script Externo

O keeper **NÃO é um contrato on-chain** que roda automaticamente. É um **script PowerShell** que precisa ser **executado manualmente**.

## 🔄 Como Funciona

### Quando Você Executa o Keeper

```powershell
.\keeper-bot-auto-start.ps1
```

O keeper faz o seguinte:

### 1. **Ao Iniciar - Descobre Pools Existentes**

O keeper verifica pools que já existem de 3 formas:

#### Método 1: Script Solidity
- Executa `ListPoolsFromHook.s.sol`
- Lista pools configuradas no hook
- Descobre pools com diferentes fees (3000, 5000, 10000)

#### Método 2: Pool do .env
- Verifica `TOKEN0_ADDRESS` e `TOKEN1_ADDRESS` no `.env`
- Adiciona pool baseada na configuração
- Testa diferentes fees automaticamente

#### Método 3: Eventos Históricos
- Busca eventos `PoolAutoEnabled` dos últimos 10k blocos
- Encontra pools criadas anteriormente
- Adiciona ao monitoramento

### 2. **Adiciona Pools ao Monitoramento**

Todas as pools encontradas são:
- ✅ Adicionadas ao arquivo `pools-monitoradas.json`
- ✅ Incluídas no loop de verificação
- ✅ Monitoradas imediatamente

### 3. **Monitora em Tempo Real**

Depois de iniciar, o keeper:
- 🔍 Verifica novas pools a cada 5 minutos
- 📊 Monitora eventos `PoolAutoEnabled` em tempo real
- ➕ Adiciona novas pools automaticamente quando detectadas
- 🔄 Verifica compound de todas as pools periodicamente

## 📋 Fluxo Completo

```
1. Você executa: .\keeper-bot-auto-start.ps1
   ↓
2. Keeper inicia e descobre pools existentes
   - Lista pools do hook
   - Verifica .env
   - Busca eventos históricos
   ↓
3. Adiciona todas as pools encontradas
   - Salva em pools-monitoradas.json
   - Inicia monitoramento imediatamente
   ↓
4. Loop contínuo:
   - Verifica novas pools a cada 5 min
   - Monitora eventos em tempo real
   - Verifica compound de todas as pools
   - Executa compound quando possível
```

## ✅ Resultado

### Pools Criadas ANTES do Keeper Iniciar

Quando você executar o keeper:
- ✅ Ele encontrará a pool recriada automaticamente
- ✅ Adicionará ao monitoramento
- ✅ Começará a verificar compound imediatamente

### Pools Criadas DEPOIS do Keeper Iniciar

Quando alguém criar uma nova pool:
- ✅ Keeper detecta evento `PoolAutoEnabled` em tempo real
- ✅ Adiciona automaticamente ao monitoramento
- ✅ Começa a verificar imediatamente

## 🎯 Exemplo Prático

### Cenário: Pool já foi criada

1. **Pool foi criada** (fee 5000, Pool ID: 2757784...)
2. **Você executa**: `.\keeper-bot-auto-start.ps1`
3. **Keeper inicia**:
   ```
   Verificando pools existentes no hook...
   [OK] Pools do .env adicionadas (fees: 3000, 5000, 10000)
   [OK] Pool existente adicionada: pool-0x1c7D...-0xfFf...-5000
   [OK] Monitoramento iniciado automaticamente!
   ```
4. **Keeper começa a monitorar** a pool imediatamente
5. **Quando houver fees suficientes**, executa compound

## 📝 Notas Importantes

- ⚠️ O keeper precisa estar **rodando** para detectar novas pools
- ✅ Mas ele descobre pools existentes ao iniciar
- ✅ Não precisa configurar manualmente cada pool
- ✅ Funciona automaticamente para pools futuras também

## 🚀 Para Usar

```powershell
# Execute o keeper
.\keeper-bot-auto-start.ps1

# Ele encontrará automaticamente:
# - Pool recriada (fee 5000)
# - Qualquer outra pool configurada no hook
# - Pools criadas no futuro (via eventos)
```

