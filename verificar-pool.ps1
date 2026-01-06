# Script para verificar se a pool foi criada
# Execute: .\verificar-pool.ps1

Write-Host "=== Verificando Pool USDC/WETH ===" -ForegroundColor Cyan
Write-Host ""

$poolManager = "0x76E9E1AFFDe82bb4544cE95EA58fFc2f9D45061f"
$hook = "0x6A087B9340925E1c66273FAE8F7527c8754F1540"
$poolId = "96581450869586643332131644812111398789711740483350970162926025488554309685359"
$usdc = "0x1c7D4B196Cb0C7B01d743Fbc6116a902379C7238"
$weth = "0xfFf9976782d46CC05630D1f6eBAb18b2324d6B14"

Write-Host "Informacoes da Pool:" -ForegroundColor Yellow
Write-Host "  Pool ID: $poolId" -ForegroundColor White
Write-Host "  USDC: $usdc" -ForegroundColor White
Write-Host "  WETH: $weth" -ForegroundColor White
Write-Host "  Fee: 3000 (0.3%)" -ForegroundColor White
Write-Host "  Tick Spacing: 60" -ForegroundColor White
Write-Host ""

Write-Host "=== Links Etherscan ===" -ForegroundColor Cyan
Write-Host ""
Write-Host "1. PoolManager (ver transacoes):" -ForegroundColor Yellow
Write-Host "   https://sepolia.etherscan.io/address/$poolManager" -ForegroundColor Cyan
Write-Host "   Procure por:" -ForegroundColor Gray
Write-Host "   - Transacoes de initialize" -ForegroundColor Gray
Write-Host "   - Eventos Initialize com tokens USDC/WETH" -ForegroundColor Gray
Write-Host ""

Write-Host "2. Hook (ver configuracao):" -ForegroundColor Yellow
Write-Host "   https://sepolia.etherscan.io/address/$hook" -ForegroundColor Cyan
Write-Host "   Procure por:" -ForegroundColor Gray
Write-Host "   - Eventos PoolConfigUpdated" -ForegroundColor Gray
Write-Host "   - Eventos TokenPricesUpdated" -ForegroundColor Gray
Write-Host "   - Eventos PoolTickRangeUpdated" -ForegroundColor Gray
Write-Host ""

Write-Host "3. USDC Token:" -ForegroundColor Yellow
Write-Host "   https://sepolia.etherscan.io/address/$usdc" -ForegroundColor Cyan
Write-Host ""

Write-Host "4. WETH Token:" -ForegroundColor Yellow
Write-Host "   https://sepolia.etherscan.io/address/$weth" -ForegroundColor Cyan
Write-Host ""

Write-Host "=== Verificacao via Cast ===" -ForegroundColor Cyan
Write-Host ""

# Tentar verificar via cast se possível
try {
    Write-Host "Verificando ultimo bloco..." -ForegroundColor Yellow
    $blockNumber = & "C:\foundry\bin\cast.exe" block-number --rpc-url sepolia 2>&1
    if ($LASTEXITCODE -eq 0) {
        Write-Host "  Bloco atual: $blockNumber" -ForegroundColor Green
        Write-Host "  Rede Sepolia esta funcionando" -ForegroundColor Green
    }
} catch {
    Write-Host "  Nao foi possivel verificar via cast" -ForegroundColor Yellow
}

Write-Host ""
Write-Host "=== Como Verificar Manualmente ===" -ForegroundColor Cyan
Write-Host ""
Write-Host "1. Acesse o PoolManager no Etherscan" -ForegroundColor White
Write-Host "2. Clique em 'Transactions' ou 'Events'" -ForegroundColor White
Write-Host "3. Procure por transacoes recentes de 'initialize'" -ForegroundColor White
Write-Host "4. Verifique se ha uma transacao com:" -ForegroundColor White
Write-Host "   - currency0: $usdc (USDC)" -ForegroundColor Gray
Write-Host "   - currency1: $weth (WETH)" -ForegroundColor Gray
Write-Host "   - hooks: $hook" -ForegroundColor Gray
Write-Host ""
Write-Host "Se encontrar, a pool foi criada com sucesso!" -ForegroundColor Green
Write-Host ""

