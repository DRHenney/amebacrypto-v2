# Script para fazer 100 swaps de WETH para USDC
# Execute: .\fazer-100-swaps-weth-usdc.ps1

param(
    [int]$NUM_SWAPS = 100,
    [string]$WETH_PER_SWAP = ""
)

Write-Host "=== Fazer 100 Swaps WETH -> USDC ===" -ForegroundColor Cyan
Write-Host ""

# Quantidade de WETH por swap (padrão: 0.001 WETH)
if ([string]::IsNullOrEmpty($WETH_PER_SWAP)) {
    $WETH_PER_SWAP = "1000000000000000"  # 0.001 WETH (18 decimais)
    Write-Host "Usando quantidade padrão: 0.001 WETH por swap" -ForegroundColor Yellow
} else {
    Write-Host "Quantidade customizada: $WETH_PER_SWAP wei" -ForegroundColor Yellow
}

$totalWETH = [bigint]$WETH_PER_SWAP * $NUM_SWAPS
$totalWETH_ETH = $totalWETH / 1000000000000000000.0

Write-Host ""
Write-Host "Configuração:" -ForegroundColor Yellow
Write-Host "  Número de swaps: $NUM_SWAPS" -ForegroundColor White
Write-Host "  WETH por swap: $WETH_PER_SWAP wei ($([decimal]$WETH_PER_SWAP / 1000000000000000000) ETH)" -ForegroundColor White
Write-Host "  Total WETH necessário: $totalWETH wei ($totalWETH_ETH ETH)" -ForegroundColor White
Write-Host ""

# Verificar se .env existe
if (-not (Test-Path ".env")) {
    Write-Host "[ERRO] Arquivo .env não encontrado!" -ForegroundColor Red
    exit 1
}

# Atualizar .env com as variáveis
$envContent = Get-Content .env -Raw

# Atualizar ou adicionar SWAP_WETH_AMOUNT
if ($envContent -match "SWAP_WETH_AMOUNT=") {
    $envContent = $envContent -replace "SWAP_WETH_AMOUNT=.*", "SWAP_WETH_AMOUNT=$WETH_PER_SWAP"
} else {
    $envContent += "`nSWAP_WETH_AMOUNT=$WETH_PER_SWAP`n"
}

# Atualizar ou adicionar NUM_SWAPS
if ($envContent -match "NUM_SWAPS=") {
    $envContent = $envContent -replace "NUM_SWAPS=.*", "NUM_SWAPS=$NUM_SWAPS"
} else {
    $envContent += "NUM_SWAPS=$NUM_SWAPS`n"
}

Set-Content .env -Value $envContent

Write-Host "Variáveis atualizadas no .env" -ForegroundColor Green
Write-Host ""

# Verificar saldo de WETH antes
Write-Host "Verificando saldo de WETH..." -ForegroundColor Yellow
& "C:\foundry\bin\forge.exe" script script/CheckBalance.s.sol:CheckBalance --rpc-url sepolia -vv 2>&1 | Out-Null

$balanceOutput = & "C:\foundry\bin\forge.exe" script script/CheckBalance.s.sol:CheckBalance --rpc-url sepolia -vv 2>&1
$wethBalanceLine = $balanceOutput | Select-String "Balance \(WETH\):"

if ($wethBalanceLine) {
    $wethBalance = [decimal]($wethBalanceLine -replace ".*Balance \(WETH\): (\d+).*", '$1')
    Write-Host "Saldo atual de WETH: $wethBalance WETH" -ForegroundColor Yellow
    
    if ($wethBalance -lt $totalWETH_ETH) {
        Write-Host ""
        Write-Host "[AVISO] Você pode não ter WETH suficiente!" -ForegroundColor Yellow
        Write-Host "  Você tem: $wethBalance WETH" -ForegroundColor White
        Write-Host "  Você precisa: $totalWETH_ETH WETH" -ForegroundColor White
        Write-Host ""
        Write-Host "Continuando mesmo assim..." -ForegroundColor Gray
    }
}

Write-Host ""
Write-Host "=== Executando $NUM_SWAPS Swaps ===" -ForegroundColor Cyan
Write-Host "Isso pode levar alguns minutos..." -ForegroundColor Yellow
Write-Host ""

# Executar o script
& "C:\foundry\bin\forge.exe" script script/SwapWETHForUSDC100.s.sol:SwapWETHForUSDC100 --rpc-url sepolia --broadcast --slow -vvv

if ($LASTEXITCODE -eq 0) {
    Write-Host ""
    Write-Host "=== Swaps Concluídos com Sucesso! ===" -ForegroundColor Green
    Write-Host "  Total de swaps: $NUM_SWAPS" -ForegroundColor White
    Write-Host ""
    Write-Host "Verificando saldo final..." -ForegroundColor Yellow
    & "C:\foundry\bin\forge.exe" script script/CheckBalance.s.sol:CheckBalance --rpc-url sepolia -vv
} else {
    Write-Host ""
    Write-Host "=== Erro ao executar swaps ===" -ForegroundColor Red
    Write-Host "Verifique:" -ForegroundColor Yellow
    Write-Host "  1. Se você tem WETH suficiente" -ForegroundColor White
    Write-Host "  2. Se a pool existe e está configurada" -ForegroundColor White
    Write-Host "  3. Se você tem ETH suficiente para gas fees" -ForegroundColor White
}

