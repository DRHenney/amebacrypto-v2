# Script para adicionar liquidez à pool USDC/WETH
# Execute: .\adicionar-liquidez.ps1

Write-Host "=== Adicionar Liquidez à Pool ===" -ForegroundColor Cyan
Write-Host ""

# Valores padrão (ajustáveis)
# USDC tem 6 decimais, WETH tem 18 decimais
$USDC_AMOUNT = "100000000"  # 100 USDC (100 * 10^6)
$WETH_AMOUNT = "33000000000000000"  # 0.033 WETH (0.033 * 10^18)

Write-Host "Valores configurados:" -ForegroundColor Yellow
Write-Host "  USDC: $USDC_AMOUNT (100 USDC)" -ForegroundColor White
Write-Host "  WETH: $WETH_AMOUNT (0.033 WETH)" -ForegroundColor White
Write-Host "  Total: ~$100 de liquidez de cada lado" -ForegroundColor Gray
Write-Host ""

# Verificar se .env existe
if (-not (Test-Path ".env")) {
    Write-Host "[ERRO] Arquivo .env nao encontrado!" -ForegroundColor Red
    Write-Host "Execute primeiro: .\configurar-env.ps1" -ForegroundColor Yellow
    exit 1
}

# Adicionar ou atualizar variáveis no .env
Write-Host "Atualizando .env..." -ForegroundColor Yellow

$envContent = Get-Content .env -Raw

# Adicionar ou atualizar LIQUIDITY_TOKEN0_AMOUNT
if ($envContent -match "LIQUIDITY_TOKEN0_AMOUNT=") {
    $envContent = $envContent -replace "LIQUIDITY_TOKEN0_AMOUNT=.*", "LIQUIDITY_TOKEN0_AMOUNT=$USDC_AMOUNT"
    Write-Host "  [OK] LIQUIDITY_TOKEN0_AMOUNT atualizado" -ForegroundColor Green
} else {
    $envContent += "`nLIQUIDITY_TOKEN0_AMOUNT=$USDC_AMOUNT`n"
    Write-Host "  [OK] LIQUIDITY_TOKEN0_AMOUNT adicionado" -ForegroundColor Green
}

# Adicionar ou atualizar LIQUIDITY_TOKEN1_AMOUNT
if ($envContent -match "LIQUIDITY_TOKEN1_AMOUNT=") {
    $envContent = $envContent -replace "LIQUIDITY_TOKEN1_AMOUNT=.*", "LIQUIDITY_TOKEN1_AMOUNT=$WETH_AMOUNT"
    Write-Host "  [OK] LIQUIDITY_TOKEN1_AMOUNT atualizado" -ForegroundColor Green
} else {
    $envContent += "LIQUIDITY_TOKEN1_AMOUNT=$WETH_AMOUNT`n"
    Write-Host "  [OK] LIQUIDITY_TOKEN1_AMOUNT adicionado" -ForegroundColor Green
}

Set-Content .env -Value $envContent

Write-Host ""
Write-Host "Verificando saldo de tokens..." -ForegroundColor Yellow

# Verificar saldo de tokens (se possível)
$privateKey = (Get-Content .env | Select-String "PRIVATE_KEY=(.+)").Matches.Groups[1].Value
if ($privateKey) {
    $privateKey = $privateKey -replace "0x", ""
    Write-Host "  Private key encontrada" -ForegroundColor Gray
} else {
    Write-Host "  [AVISO] Private key nao encontrada no .env" -ForegroundColor Yellow
}

Write-Host ""
Write-Host "=== Executando Script de Adicionar Liquidez ===" -ForegroundColor Cyan
Write-Host ""

# Executar o script
& "C:\foundry\bin\forge.exe" script script/AddLiquidity.s.sol:AddLiquidity --rpc-url sepolia --broadcast --slow -vvvv

if ($LASTEXITCODE -eq 0) {
    Write-Host ""
    Write-Host "=== Liquidez Adicionada com Sucesso! ===" -ForegroundColor Green
} else {
    Write-Host ""
    Write-Host "=== Erro ao adicionar liquidez ===" -ForegroundColor Red
    Write-Host "Verifique:" -ForegroundColor Yellow
    Write-Host "  1. Se voce tem tokens suficientes na carteira" -ForegroundColor White
    Write-Host "  2. Se os tokens foram aprovados" -ForegroundColor White
    Write-Host "  3. Se a pool existe e esta configurada" -ForegroundColor White
}

