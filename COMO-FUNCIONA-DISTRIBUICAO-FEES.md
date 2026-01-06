# 📊 Como Funciona a Distribuição de Fees no Compound

## 🔄 Processo de Compound

Quando o `executeCompound` é chamado, o hook faz o seguinte:

### 1. Separação de Fees (10% Protocol + 90% Compound)

```solidity
// Calcular 10% para protocol fees
uint256 protocolFee0 = (fees0 * protocolFeePercent) / 10000;
uint256 protocolFee1 = (fees1 * protocolFeePercent) / 10000;

// Calcular 90% para compound
uint256 compoundFees0 = fees0 - protocolFee0;
uint256 compoundFees1 = fees1 - protocolFee1;
```

### 2. Processamento dos 10% (Protocol Fees)

1. **Retirada do PoolManager**:
   ```solidity
   poolManager.take(key.currency0, address(this), protocolFee0);
   poolManager.take(key.currency1, address(this), protocolFee1);
   ```

2. **Conversão para USDC** (se necessário):
   - Se `token0` não é USDC → faz swap para USDC
   - Se `token1` não é USDC → faz swap para USDC
   - Usa `_swapToUSDC()` para fazer os swaps

3. **Transferência Automática**:
   ```solidity
   uint256 usdcBalance = IERC20(USDC()).balanceOf(address(this));
   IERC20(USDC()).transfer(feeRecipient, usdcBalance);
   ```

4. **Evento Emitido**:
   ```solidity
   emit ProtocolFeesTransferred(feeRecipient, protocolFee0, protocolFee1);
   ```

### 3. Processamento dos 90% (Compound)

1. **Uso dos Ticks Iniciais**:
   ```solidity
   if (hasInitialTicks[poolId]) {
       // Usar ticks iniciais para manter a mesma distribuição da criação da pool
       tickLower = initialTickLower[poolId];
       tickUpper = initialTickUpper[poolId];
   } else {
       // Fallback para ticks configurados manualmente
       tickLower = poolTickLower[poolId];
       tickUpper = poolTickUpper[poolId];
   }
   ```

2. **Cálculo de Liquidez**:
   ```solidity
   int128 liquidityDelta = _calculateLiquidityFromAmounts(
       key,
       tickLower,
       tickUpper,
       compoundFees0,  // Apenas 90% das fees
       compoundFees1  // Apenas 90% das fees
   );
   ```

3. **Adição de Liquidez**:
   - A liquidez é adicionada usando `modifyLiquidity` do PoolManager
   - Usa os ticks iniciais para manter a mesma distribuição

4. **Eventos Emitidos**:
   ```solidity
   emit FeesCompounded(poolId, compoundFees0, compoundFees1);
   emit CompoundExecuted(
       poolId,
       compoundFees0,
       compoundFees1,
       liquidityDelta,
       estimatedGasUsed,
       feesValueUSD,
       block.timestamp
   );
   ```

## ✅ Respeito às Características Iniciais

### Ticks Iniciais

O hook **respeita automaticamente** os ticks iniciais da pool:

1. **Captura Automática**:
   - Quando a primeira liquidez é adicionada, o hook captura `tickLower` e `tickUpper`
   - Armazena em `initialTickLower[poolId]` e `initialTickUpper[poolId]`
   - Marca `hasInitialTicks[poolId] = true`

2. **Uso nos Compounds**:
   - Todos os compounds subsequentes usam os ticks iniciais
   - Isso garante que a distribuição de liquidez seja mantida
   - A liquidez sempre é adicionada no mesmo range inicial

### Exemplo

**Criação da Pool**:
- Tick Lower: `719340`
- Tick Upper: `720540`
- Range: ~1,200 ticks

**Primeiro Compound**:
- Captura: `initialTickLower = 719340`, `initialTickUpper = 720540`
- `hasInitialTicks = true`

**Compounds Subsequentes**:
- Sempre usa `tickLower = 719340`, `tickUpper = 720540`
- Mantém a mesma distribuição inicial

## 📝 Resumo

### Distribuição de Fees

| Item | Percentual | Destino | Processamento |
|------|-----------|---------|---------------|
| Protocol Fees | 10% | `feeRecipient` | Convertido para USDC e enviado automaticamente |
| Compound | 90% | Pool (liquidez) | Adicionado como liquidez usando ticks iniciais |

### Características Respeitadas

✅ **Ticks Iniciais**: Sempre usados nos compounds  
✅ **Distribuição**: Mantém o mesmo range da criação  
✅ **Protocol Fees**: Enviados automaticamente em USDC  
✅ **Eventos**: Emitidos para monitoramento  

## 🔍 Verificação

Para verificar se um compound foi executado:

1. **Eventos**:
   - `ProtocolFeesTransferred`: Confirma que 10% foram enviados
   - `CompoundExecuted`: Confirma que 90% foram reinvestidos

2. **Status da Pool**:
   - `accumulatedFees0[poolId]` e `accumulatedFees1[poolId]` devem ser resetados para 0
   - `lastCompoundTimestamp[poolId]` deve ser atualizado

3. **Liquidez**:
   - A liquidez total da pool deve aumentar
   - A liquidez deve estar no range dos ticks iniciais

