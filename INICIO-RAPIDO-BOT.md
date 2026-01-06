# 🚀 Início Rápido - Bot Local Keeper

## ✅ Tudo Pronto!

O bot `keeper-bot-automatico.ps1` está configurado e pronto para usar.

## 🎯 Como Começar Agora

### 1. Verificar Configuração

Certifique-se de que seu `.env` está configurado:

```env
# Sepolia (para testes)
SEPOLIA_RPC_URL=https://eth-sepolia.g.alchemy.com/v2/YOUR_KEY
PRIVATE_KEY=0x...
POOL_MANAGER=0x76E9E1AFFDe82bb4544cE95EA58fFc2f9D45061f
HOOK_ADDRESS=0x6A087B9340925E1c66273FAE8F7527c8754F1540
TOKEN0_ADDRESS=0x1c7D4B196Cb0C7B01d743Fbc6116a902379C7238
TOKEN1_ADDRESS=0xfFf9976782d46CC05630D1f6eBAb18b2324d6B14
```

### 2. Executar Bot (Modo Teste)

```powershell
# Executar uma vez para testar
.\keeper-bot-automatico.ps1 -RunOnce
```

Isso vai:
- ✅ Verificar se pode executar compound
- ✅ Executar se as condições forem atendidas
- ✅ Mostrar resultado e parar

### 3. Executar Bot (Modo Contínuo)

```powershell
# Executar em loop contínuo (verifica a cada hora)
.\keeper-bot-automatico.ps1

# Ou configurar intervalo personalizado (ex: 30 minutos)
.\keeper-bot-automatico.ps1 -IntervalMinutes 30
```

## 📊 O Que o Bot Faz

1. **Verifica condições** de compound
2. **Executa compound** se possível
3. **Aguarda intervalo** configurado
4. **Repete** automaticamente

## 🎛️ Opções Disponíveis

```powershell
# Executar uma vez (teste)
.\keeper-bot-automatico.ps1 -RunOnce

# Loop contínuo com intervalo padrão (1 hora)
.\keeper-bot-automatico.ps1

# Loop contínuo com intervalo personalizado
.\keeper-bot-automatico.ps1 -IntervalMinutes 30

# Modo verbose (mostra mais detalhes)
.\keeper-bot-automatico.ps1 -Verbose

# Especificar rede
.\keeper-bot-automatico.ps1 -Network sepolia
.\keeper-bot-automatico.ps1 -Network mainnet

# Combinar opções
.\keeper-bot-automatico.ps1 -Network sepolia -IntervalMinutes 60 -Verbose
```

## 📈 Exemplo de Saída

```
=== Keeper Bot Automático - AutoCompound Hook ===

Configuracao:
  Rede: sepolia
  Intervalo de verificacao: 60 minutos
  Modo: Loop continuo
  RPC: https://eth-sepolia.g.alchemy.com/v2/...

=== Iniciando Monitoramento ===

[2024-01-15 10:00:00] Verificacao #1
  [SKIP] Compound nao pode ser executado (condicoes nao atendidas)

Proxima verificacao em: 11:00:00
Aguardando 60 minutos...
```

## 🔄 Executar em Background (Windows)

### Opção 1: Task Scheduler (Recomendado)

```powershell
# Criar tarefa agendada
$action = New-ScheduledTaskAction -Execute "PowerShell.exe" `
    -Argument "-NoProfile -ExecutionPolicy Bypass -File `"$PWD\keeper-bot-automatico.ps1`" -IntervalMinutes 60"

$trigger = New-ScheduledTaskTrigger -Once -At (Get-Date) `
    -RepetitionInterval (New-TimeSpan -Minutes 60) `
    -RepetitionDuration (New-TimeSpan -Days 365)

Register-ScheduledTask -TaskName "AutoCompoundKeeper" `
    -Action $action -Trigger $trigger -Description "AutoCompound Keeper Bot"
```

### Opção 2: Start-Process em Background

```powershell
# Executar em nova janela
Start-Process powershell.exe -ArgumentList "-File `"$PWD\keeper-bot-automatico.ps1`" -IntervalMinutes 60"
```

### Opção 3: Redirecionar para Arquivo

```powershell
# Executar e salvar logs em arquivo
.\keeper-bot-automatico.ps1 -IntervalMinutes 60 *> keeper.log
```

## 🛑 Parar o Bot

- **Modo interativo**: Pressione `Ctrl+C`
- **Task Scheduler**: Desabilitar a tarefa
- **Processo**: Fechar a janela do PowerShell

## 📝 Logs e Monitoramento

### Ver Logs em Tempo Real

```powershell
# Se redirecionou para arquivo
Get-Content keeper.log -Wait -Tail 50
```

### Verificar Última Execução

```powershell
# Verificar se pode executar (sem broadcast)
forge script script/AutoCompoundKeeper.s.sol:AutoCompoundKeeper --rpc-url sepolia
```

## ⚙️ Configurações Recomendadas

### Para Desenvolvimento/Testes
- **Intervalo**: 30-60 minutos
- **Rede**: Sepolia
- **Modo**: `-RunOnce` para testes

### Para Produção
- **Intervalo**: 60-120 minutos (o hook tem intervalo mínimo de 4 horas)
- **Rede**: Mainnet
- **Modo**: Loop contínuo
- **Backup**: Considere Gelato como backup

## 🔍 Troubleshooting

### Bot não executa
- Verifique se `.env` está configurado
- Verifique se RPC URL está funcionando
- Execute com `-Verbose` para mais detalhes

### Compound não executa
- Verifique se há fees acumuladas
- Verifique se passou o intervalo mínimo (4 horas)
- Verifique se pool está habilitada

### Erro de gas
- Verifique se carteira tem ETH suficiente
- Tente com `--slow` (já está configurado)

## ✅ Checklist Antes de Usar

- [ ] `.env` configurado corretamente
- [ ] RPC URL funcionando
- [ ] Carteira tem ETH suficiente
- [ ] Pool criada e configurada
- [ ] Testou com `-RunOnce` primeiro

## 🚀 Próximos Passos

1. **Teste agora**: `.\keeper-bot-automatico.ps1 -RunOnce`
2. **Se funcionar**: Execute em loop: `.\keeper-bot-automatico.ps1`
3. **Para produção**: Configure Task Scheduler ou execute em servidor

---

**Pronto para usar!** Execute `.\keeper-bot-automatico.ps1 -RunOnce` para começar! 🎉

