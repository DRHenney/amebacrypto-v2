# 🔍 Como o Bot Funciona

## ⚠️ Importante: O Bot NÃO Detecta Automaticamente Novas Pools

O bot **não começa a verificar automaticamente** quando uma pool é criada. Ele verifica a pool que está **configurada no arquivo `.env`**.

## 🔄 Como Funciona Atualmente

1. **Você configura** os endereços no `.env`:
   ```env
   POOL_MANAGER=0x...
   HOOK_ADDRESS=0x...
   TOKEN0_ADDRESS=0x...
   TOKEN1_ADDRESS=0x...
   ```

2. **Você executa** o bot:
   ```powershell
   .\keeper-bot-automatico.ps1
   ```

3. **O bot verifica** a pool configurada no `.env`

4. **O bot executa compound** se as condições forem atendidas

## 📋 Para Verificar uma Nova Pool

Quando você criar uma nova pool, você precisa:

1. **Atualizar o `.env`** com os novos endereços:
   ```env
   POOL_MANAGER=0x...  # Novo endereço
   HOOK_ADDRESS=0x...  # Novo endereço
   TOKEN0_ADDRESS=0x... # Novos tokens
   TOKEN1_ADDRESS=0x...
   ```

2. **Reiniciar o bot** (se estiver rodando):
   - Parar o bot atual (Ctrl+C)
   - Executar novamente: `.\keeper-bot-automatico.ps1`

## 🚀 Solução: Detectar Pools Automaticamente

Se você quiser que o bot detecte automaticamente quando uma pool é criada, existem algumas opções:

### Opção 1: Monitorar Eventos do PoolManager

Criar um script que monitora eventos `Initialize` do PoolManager e inicia o keeper automaticamente.

### Opção 2: Lista de Pools no .env

Manter uma lista de pools no `.env` e o bot verifica todas elas.

### Opção 3: Hook que Registra Pools

O hook pode emitir um evento quando uma pool é configurada, e o bot monitora esse evento.

## 💡 Recomendação

Para produção, a melhor abordagem é:

1. **Criar a pool** com o hook
2. **Configurar o hook** (preços, tick range, etc.)
3. **Atualizar o `.env`** com os novos endereços
4. **Executar o bot** ou reiniciar se já estiver rodando

Isso garante que você tem controle total sobre quais pools são monitoradas.

## 🔧 Quer Automação Completa?

Se você quiser que o bot detecte automaticamente novas pools, posso criar:

1. **Monitor de eventos** - Detecta quando uma pool é criada
2. **Multi-pool support** - Bot verifica múltiplas pools
3. **Auto-registration** - Registra novas pools automaticamente

Diga se quer que eu implemente isso!

