# Script para fazer swaps e testar geração de fees
# Execute: .\fazer-swaps-teste.ps1

Write-Host "=== Fazer Swaps para Testar ===" -ForegroundColor Cyan
Write-Host ""

# Valores padrão para swaps (ajustáveis)
$WETH_AMOUNT = "1000000000000000"  # 0.001 WETH (18 decimais)
$USDC_AMOUNT = "3000000"  # 3 USDC (6 decimais)

Write-Host "Configuracao:" -ForegroundColor Yellow
Write-Host "  Swap 1: WETH -> USDC (0.001 WETH)" -ForegroundColor White
Write-Host "  Swap 2: USDC -> WETH (3 USDC)" -ForegroundColor White
Write-Host "  Swap 3: WETH -> USDC (0.001 WETH)" -ForegroundColor White
Write-Host ""

# Verificar se .env existe
if (-not (Test-Path ".env")) {
    Write-Host "[ERRO] Arquivo .env nao encontrado!" -ForegroundColor Red
    exit 1
}

# Adicionar variáveis de swap ao .env se não existirem
$envContent = Get-Content .env -Raw

if (-not ($envContent -match "SWAP_WETH_AMOUNT=")) {
    $envContent += "`nSWAP_WETH_AMOUNT=$WETH_AMOUNT`n"
    Write-Host "[OK] SWAP_WETH_AMOUNT adicionado" -ForegroundColor Green
}

if (-not ($envContent -match "SWAP_USDC_AMOUNT=")) {
    $envContent += "SWAP_USDC_AMOUNT=$USDC_AMOUNT`n"
    Write-Host "[OK] SWAP_USDC_AMOUNT adicionado" -ForegroundColor Green
}

Set-Content .env -Value $envContent

Write-Host ""
Write-Host "=== Executando Swaps ===" -ForegroundColor Cyan
Write-Host ""

# Swap 1: WETH -> USDC
Write-Host "--- Swap 1: WETH -> USDC ---" -ForegroundColor Yellow
& "C:\foundry\bin\forge.exe" script script/SwapWETHForUSDC.s.sol:SwapWETHForUSDC --rpc-url sepolia --broadcast --slow -vvv

if ($LASTEXITCODE -ne 0) {
    Write-Host "[ERRO] Swap 1 falhou!" -ForegroundColor Red
    exit 1
}

Write-Host ""
Write-Host "Aguardando 5 segundos..." -ForegroundColor Gray
Start-Sleep -Seconds 5

# Verificar se existe script de swap USDC -> WETH
if (Test-Path "script/SwapUSDCForWETH.s.sol") {
    Write-Host ""
    Write-Host "--- Swap 2: USDC -> WETH ---" -ForegroundColor Yellow
    & "C:\foundry\bin\forge.exe" script script/SwapUSDCForWETH.s.sol:SwapUSDCForWETH --rpc-url sepolia --broadcast --slow -vvv
    
    if ($LASTEXITCODE -ne 0) {
        Write-Host "[AVISO] Swap 2 falhou, continuando..." -ForegroundColor Yellow
    }
    
    Write-Host ""
    Write-Host "Aguardando 5 segundos..." -ForegroundColor Gray
    Start-Sleep -Seconds 5
}

# Swap 3: WETH -> USDC novamente
Write-Host ""
Write-Host "--- Swap 3: WETH -> USDC (novamente) ---" -ForegroundColor Yellow
& "C:\foundry\bin\forge.exe" script script/SwapWETHForUSDC.s.sol:SwapWETHForUSDC --rpc-url sepolia --broadcast --slow -vvv

if ($LASTEXITCODE -ne 0) {
    Write-Host "[AVISO] Swap 3 falhou" -ForegroundColor Yellow
}

Write-Host ""
Write-Host "=== Swaps Concluidos ===" -ForegroundColor Green
Write-Host ""
Write-Host "Fees devem ter sido acumuladas na pool!" -ForegroundColor Cyan
Write-Host "Execute o keeper para verificar e fazer compound:" -ForegroundColor Yellow
Write-Host "  forge script script/AutoCompoundKeeper.s.sol:AutoCompoundKeeper --rpc-url sepolia --broadcast" -ForegroundColor White

