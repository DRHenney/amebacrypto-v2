# 📊 Cálculo de Swaps Necessários para Ativar Compound

## 🎯 Requisitos do Compound

### Threshold
- **Threshold Multiplier**: `20x gas cost`
- O valor das fees acumuladas deve ser >= 20x o custo de gas estimado

### Gas Cost Estimado
- **Gas Limit**: ~200,000 gas (estimativa para compound)
- **Gas Price (Sepolia)**: ~30 gwei
- **Gas Cost (Wei)**: `200,000 * 30e9 = 6,000,000,000,000 wei`
- **Gas Cost (USD)**: `(6e12 * 3000) / 1e18 = ~$0.012`

### Required Fees
- **Required Fees (USD)**: `$0.012 * 20 = $0.24`

## 💰 Fees Atuais

- **USDC**: `3000` (0.003 USD)
- **WETH**: `3000000000000 wei` (~0.000003 WETH = ~0.009 USD)
- **Total**: ~`$0.012`

## 📈 Fees por Swap

### Pool Fee
- **Fee da Pool**: `0.3%` (3000)

### Exemplos de Swaps

1. **Swap de 1 USDC**:
   - Fees geradas: `1,000,000 * 0.003 = 3,000 wei USDC`
   - Valor em USD: `~$0.003`

2. **Swap de 0.001 WETH**:
   - Fees geradas: `1,000,000,000,000,000 * 0.003 = 3,000,000,000,000 wei WETH`
   - Valor em USD: `~$0.009`

## 🧮 Cálculo de Swaps Necessários

### Fórmula
```
Swaps Necessários = (Required Fees - Current Fees) / Fees per Swap
```

### Cálculo
- **Required Fees**: `$0.24`
- **Current Fees**: `$0.012`
- **Fees per Swap**: `$0.003` (swap de 1 USDC)
- **Swaps Necessários**: `($0.24 - $0.012) / $0.003 = ~76 swaps`

### Com Swaps Maiores
Se usar swaps maiores (ex: 10 USDC por swap):
- **Fees per Swap**: `$0.03`
- **Swaps Necessários**: `($0.24 - $0.012) / $0.03 = ~8 swaps`

## ⚠️ Observações

1. **Estimativa**: Este cálculo é uma estimativa baseada em valores típicos
2. **Gas Price Variável**: O gas price pode variar, afetando o required fees
3. **Tamanho do Swap**: Swaps maiores geram mais fees proporcionalmente
4. **Preços dos Tokens**: O valor em USD depende dos preços configurados (USDC=$1, WETH=$3000)

## 🚀 Recomendações

### Para Testes Rápidos
- Fazer **8-10 swaps de 10 USDC cada**
- Isso deve gerar fees suficientes para ativar o compound

### Para Produção
- O keeper monitora automaticamente
- Quando houver fees suficientes, o compound será executado
- Não é necessário fazer swaps manualmente

## 📝 Resumo

| Item | Valor |
|------|-------|
| Required Fees (USD) | $0.24 |
| Current Fees (USD) | $0.012 |
| Fees per Swap (1 USDC) | $0.003 |
| **Swaps Necessários** | **~76 swaps** |
| Swaps Necessários (10 USDC) | ~8 swaps |

---

**Conclusão**: Para ativar o compound rapidamente, faça **8-10 swaps de 10 USDC cada**, ou **~76 swaps de 1 USDC cada**.

