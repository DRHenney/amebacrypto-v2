# 🤖 Como Configurar Keeper Automático

## Opções Disponíveis

### 1. 🎯 Gelato Network (Recomendado para Produção)

**Melhor para**: Produção, quando você quer automação confiável sem gerenciar infraestrutura.

#### Passos:

1. **Deploy do GelatoKeeper**:
   ```bash
   forge script script/GelatoKeeper.s.sol:GelatoKeeper --rpc-url sepolia --broadcast
   ```

2. **Criar Task no Gelato**:
   - Acesse: https://app.gelato.network/
   - Conecte sua carteira
   - Clique em "Create Task"
   - Configure:
     - **Target Contract**: Endereço do GelatoKeeper deployado
     - **Function**: `checkAndExecuteCompound()`
     - **Interval**: 1 hora (ou conforme necessário)
     - **Gas Limit**: 500000 (ajuste conforme necessário)

3. **Fundar a Task**:
   - Adicione ETH/Token para pagar as execuções
   - Gelato cobra apenas quando executa

#### Vantagens:
- ✅ Descentralizado
- ✅ Não requer servidor próprio
- ✅ Paga apenas quando executa
- ✅ Alta confiabilidade

---

### 2. 🤖 Bot Local (Mais Controle)

**Melhor para**: Desenvolvimento, testes, ou quando você quer controle total.

#### Passos:

1. **Executar Bot Manualmente**:
   ```powershell
   .\keeper-bot-automatico.ps1
   ```

2. **Executar Uma Vez**:
   ```powershell
   .\keeper-bot-automatico.ps1 -RunOnce
   ```

3. **Configurar Intervalo**:
   ```powershell
   .\keeper-bot-automatico.ps1 -IntervalMinutes 30
   ```

4. **Executar em Background (Windows)**:
   ```powershell
   # Criar tarefa agendada
   $action = New-ScheduledTaskAction -Execute "PowerShell.exe" -Argument "-File `"$PWD\keeper-bot-automatico.ps1`""
   $trigger = New-ScheduledTaskTrigger -Once -At (Get-Date) -RepetitionInterval (New-TimeSpan -Minutes 60) -RepetitionDuration (New-TimeSpan -Days 365)
   Register-ScheduledTask -TaskName "AutoCompoundKeeper" -Action $action -Trigger $trigger
   ```

5. **Executar em Background (Linux/Mac)**:
   ```bash
   # Adicionar ao crontab
   crontab -e
   
   # Executar a cada hora
   0 * * * * cd /path/to/amebacrypto-v2 && ./keeper-bot-automatico.sh
   ```

#### Vantagens:
- ✅ Controle total
- ✅ Sem custos adicionais
- ✅ Personalizável
- ⚠️ Requer servidor sempre online

---

### 3. 🛡️ OpenZeppelin Defender

**Melhor para**: Projetos que já usam OpenZeppelin Defender.

#### Passos:

1. **Criar Autotask**:
   - Acesse: https://defender.openzeppelin.com/
   - Crie uma nova Autotask
   - Configure para executar o keeper script

2. **Criar Monitor**:
   - Monitora eventos da pool
   - Dispara autotask quando necessário

#### Vantagens:
- ✅ Interface amigável
- ✅ Integração com OpenZeppelin
- ✅ Monitoramento e alertas

---

## 🚀 Configuração Rápida (Recomendada)

### Para Desenvolvimento/Testes:
```powershell
# Executar bot local em loop
.\keeper-bot-automatico.ps1 -IntervalMinutes 60
```

### Para Produção:
1. Deploy do GelatoKeeper
2. Criar task no Gelato
3. Fundar a task
4. Monitorar execuções

---

## 📋 Checklist

Quando uma pool é criada:

- [ ] Pool criada com hook
- [ ] Hook configurado (preços, tick range, pool habilitada)
- [ ] Keeper configurado (Gelato ou Bot)
- [ ] Testes realizados
- [ ] Monitoramento ativo

---

## 🔍 Monitoramento

### Verificar Status do Keeper:

```bash
# Verificar se pode executar
forge script script/AutoCompoundKeeper.s.sol:AutoCompoundKeeper --rpc-url sepolia

# Verificar fees acumuladas
forge script script/VerifyPoolExists.s.sol:VerifyPoolExists --rpc-url sepolia
```

### Logs:

- **Bot Local**: Saída no console
- **Gelato**: Dashboard do Gelato
- **Defender**: Dashboard do Defender

---

## 💡 Dicas

1. **Intervalo Mínimo**: O hook tem um intervalo mínimo configurável (padrão: 4 horas)
   - Não adianta verificar mais frequentemente que isso
   - Configure o keeper para verificar a cada 1-2 horas

2. **Gas Costs**: 
   - Gelato cobra uma taxa por execução
   - Bot local paga apenas o gas da transação

3. **Backup**:
   - Considere ter um bot local como backup do Gelato
   - Ou vice-versa

4. **Monitoramento**:
   - Configure alertas para falhas
   - Monitore as execuções regularmente

---

## 📚 Arquivos Relacionados

- `keeper-bot-automatico.ps1` - Bot local
- `script/GelatoKeeper.s.sol` - Keeper para Gelato
- `script/AutoCompoundKeeper.s.sol` - Keeper manual
- `KEEPER-AUTOMATICO.md` - Documentação completa

---

**Pronto para usar!** Escolha a opção que melhor se adequa ao seu caso de uso.

