# Testes das Configurações Globais (v2)

Este documento descreve como testar as novas funcionalidades de configuração global do AutoCompoundHook.

## Mudanças Implementadas

### Variáveis Configuráveis (substituindo constantes)

1. **`thresholdMultiplier`** (padrão: 20)
   - Substitui `MIN_FEES_MULTIPLIER` constante
   - Define o multiplicador mínimo de fees vs custo de gas

2. **`minTimeBetweenCompounds`** (padrão: 4 hours)
   - Substitui `COMPOUND_INTERVAL` constante
   - Define o intervalo mínimo entre compounds

3. **`protocolFeePercent`** (padrão: 1000 = 10%, base 10000)
   - Novo: porcentagem de protocol fee configurável
   - Substitui cálculo fixo de 10% (divisão por 10)

4. **`feeRecipient`** (configurável)
   - Substitui `FEE_RECIPIENT` constante
   - Endereço que recebe protocol fees

### Funções Setter Adicionadas

- `setThresholdMultiplier(uint256 _new)` - valida `_new > 0`
- `setMinTimeInterval(uint256 _new)` - valida `_new > 0`
- `setProtocolFeePercent(uint256 _new)` - valida `_new <= 5000` (máximo 50%)
- `setFeeRecipient(address _new)` - valida endereço não-zero

### Eventos Adicionados

- `ThresholdMultiplierUpdated(uint256 oldValue, uint256 newValue)`
- `MinTimeIntervalUpdated(uint256 oldValue, uint256 newValue)`
- `ProtocolFeePercentUpdated(uint256 oldValue, uint256 newValue)`
- `FeeRecipientUpdated(address indexed oldRecipient, address indexed newRecipient)`

## Como Executar os Testes

### Pré-requisitos

```bash
# Instalar dependências (se ainda não instalou)
forge install

# Compilar o projeto
forge build --via-ir
```

### Executar Todos os Testes

```bash
forge test --via-ir -vvv
```

### Executar Testes Específicos

#### Testar Valores Padrão
```bash
forge test --match-test test_DefaultGlobalConfigValues -vvv
```

#### Testar setThresholdMultiplier
```bash
forge test --match-test test_SetThresholdMultiplier -vvv
forge test --match-test test_Revert_NotOwner_SetThresholdMultiplier -vvv
forge test --match-test test_Revert_InvalidThresholdMultiplier -vvv
```

#### Testar setMinTimeInterval
```bash
forge test --match-test test_SetMinTimeInterval -vvv
forge test --match-test test_Revert_NotOwner_SetMinTimeInterval -vvv
forge test --match-test test_Revert_InvalidMinTimeInterval -vvv
```

#### Testar setProtocolFeePercent
```bash
forge test --match-test test_SetProtocolFeePercent -vvv
forge test --match-test test_SetProtocolFeePercent_Max50Percent -vvv
forge test --match-test test_Revert_NotOwner_SetProtocolFeePercent -vvv
forge test --match-test test_Revert_InvalidProtocolFeePercent_Above50 -vvv
```

#### Testar setFeeRecipient
```bash
forge test --match-test test_SetFeeRecipient -vvv
forge test --match-test test_Revert_NotOwner_SetFeeRecipient -vvv
forge test --match-test test_Revert_InvalidFeeRecipient_ZeroAddress -vvv
```

#### Testar Uso na Lógica
```bash
forge test --match-test test_ThresholdMultiplier_UsedInCompoundLogic -vvv
forge test --match-test test_MinTimeInterval_UsedInCompoundLogic -vvv
forge test --match-test test_ProtocolFeePercent_UsedInFeeCalculation -vvv
```

#### Testar Eventos
```bash
forge test --match-test test_Events_EmittedOnConfigUpdate -vvv
```

### Executar Todos os Testes de Configuração

```bash
forge test --match-path "test/AutoCompoundHook.t.sol" --match-test "test_DefaultGlobalConfigValues|test_SetThresholdMultiplier|test_SetMinTimeInterval|test_SetProtocolFeePercent|test_SetFeeRecipient|test_ThresholdMultiplier_UsedInCompoundLogic|test_MinTimeInterval_UsedInCompoundLogic|test_ProtocolFeePercent_UsedInFeeCalculation|test_Events_EmittedOnConfigUpdate" -vvv
```

## Testes Implementados

### 1. Valores Padrão
- ✅ Verifica que os valores padrão estão corretos

### 2. setThresholdMultiplier
- ✅ Testa atualização do valor
- ✅ Testa que apenas owner pode atualizar
- ✅ Testa validação (deve ser > 0)

### 3. setMinTimeInterval
- ✅ Testa atualização do valor
- ✅ Testa que apenas owner pode atualizar
- ✅ Testa validação (deve ser > 0)

### 4. setProtocolFeePercent
- ✅ Testa atualização do valor
- ✅ Testa valor máximo (50% = 5000)
- ✅ Testa que apenas owner pode atualizar
- ✅ Testa validação (deve ser <= 5000)

### 5. setFeeRecipient
- ✅ Testa atualização do endereço
- ✅ Testa que apenas owner pode atualizar
- ✅ Testa validação (não pode ser zero address)

### 6. Uso na Lógica
- ✅ Testa que thresholdMultiplier é usado no cálculo de compound
- ✅ Testa que minTimeBetweenCompounds é usado na verificação de intervalo
- ✅ Testa que protocolFeePercent é usado no cálculo de fees

### 7. Eventos
- ✅ Testa que eventos são emitidos corretamente

## Exemplo de Uso

```solidity
// Como owner, atualizar configurações
hook.setThresholdMultiplier(30);        // Mudar para 30x
hook.setMinTimeInterval(6 hours);       // Mudar para 6 horas
hook.setProtocolFeePercent(1500);       // Mudar para 15%
hook.setFeeRecipient(newRecipient);    // Mudar fee recipient
```

## Validações

- `thresholdMultiplier`: deve ser > 0
- `minTimeInterval`: deve ser > 0
- `protocolFeePercent`: deve ser <= 5000 (50%)
- `feeRecipient`: não pode ser address(0)

## Notas

- Todas as funções setter requerem `onlyOwner`
- Eventos são emitidos para todas as mudanças
- As configurações afetam toda a lógica do hook (não são por pool)
- Os valores padrão mantêm compatibilidade com a v1

