# Script para fazer 100 swaps de WETH para USDC em lotes
# Execute: .\fazer-100-swaps-lotes.ps1

param(
    [int]$LOTE_SIZE = 10,
    [int]$NUM_SWAPS = 100,
    [string]$WETH_PER_SWAP = "1000000000000000"  # 0.001 WETH
)

Write-Host "=== Fazer $NUM_SWAPS Swaps WETH -> USDC (em lotes de $LOTE_SIZE) ===" -ForegroundColor Cyan
Write-Host ""

$numLotes = [math]::Ceiling($NUM_SWAPS / $LOTE_SIZE)

Write-Host "Configuração:" -ForegroundColor Yellow
Write-Host "  Total de swaps: $NUM_SWAPS" -ForegroundColor White
Write-Host "  Tamanho do lote: $LOTE_SIZE" -ForegroundColor White
Write-Host "  Número de lotes: $numLotes" -ForegroundColor White
Write-Host "  WETH por swap: $WETH_PER_SWAP wei (0.001 ETH)" -ForegroundColor White
Write-Host ""

# Verificar se .env existe
if (-not (Test-Path ".env")) {
    Write-Host "[ERRO] Arquivo .env não encontrado!" -ForegroundColor Red
    exit 1
}

# Atualizar .env
$envContent = Get-Content .env -Raw

if ($envContent -match "SWAP_WETH_AMOUNT=") {
    $envContent = $envContent -replace "SWAP_WETH_AMOUNT=.*", "SWAP_WETH_AMOUNT=$WETH_PER_SWAP"
} else {
    $envContent += "`nSWAP_WETH_AMOUNT=$WETH_PER_SWAP`n"
}

if ($envContent -match "NUM_SWAPS=") {
    $envContent = $envContent -replace "NUM_SWAPS=.*", "NUM_SWAPS=$LOTE_SIZE"
} else {
    $envContent += "NUM_SWAPS=$LOTE_SIZE`n"
}

Set-Content .env -Value $envContent

Write-Host "=== Executando Swaps em Lotes ===" -ForegroundColor Cyan
Write-Host ""

$swapsCompletos = 0

for ($lote = 1; $lote -le $numLotes; $lote++) {
    $swapsNesteLote = [math]::Min($LOTE_SIZE, $NUM_SWAPS - $swapsCompletos)
    
    Write-Host "--- Lote $lote/$numLotes ($swapsNesteLote swaps) ---" -ForegroundColor Yellow
    Write-Host "Swaps completos até agora: $swapsCompletos/$NUM_SWAPS" -ForegroundColor Gray
    Write-Host ""
    
    # Atualizar NUM_SWAPS para este lote
    $envContent = Get-Content .env -Raw
    $envContent = $envContent -replace "NUM_SWAPS=.*", "NUM_SWAPS=$swapsNesteLote"
    Set-Content .env -Value $envContent
    
    # Executar o script
    $result = & "C:\foundry\bin\forge.exe" script script/SwapWETHForUSDC100.s.sol:SwapWETHForUSDC100 --rpc-url sepolia --broadcast --slow -vvv 2>&1
    
    if ($LASTEXITCODE -eq 0) {
        $swapsCompletos += $swapsNesteLote
        Write-Host "[OK] Lote $lote concluído!" -ForegroundColor Green
        Write-Host "Total de swaps completos: $swapsCompletos/$NUM_SWAPS" -ForegroundColor White
    } else {
        Write-Host "[ERRO] Erro no lote $lote" -ForegroundColor Red
        Write-Host "Tentando continuar..." -ForegroundColor Yellow
        # Continuar mesmo com erro
    }
    
    # Pausa entre lotes (exceto no último)
    if ($lote -lt $numLotes) {
        Write-Host ""
        Write-Host "Aguardando 10 segundos antes do próximo lote..." -ForegroundColor Gray
        Start-Sleep -Seconds 10
        Write-Host ""
    }
}

Write-Host ""
Write-Host "=== Resumo Final ===" -ForegroundColor Cyan
Write-Host "Swaps completos: $swapsCompletos/$NUM_SWAPS" -ForegroundColor White
Write-Host ""

# Verificar saldo final
Write-Host "Verificando saldo final..." -ForegroundColor Yellow
& "C:\foundry\bin\forge.exe" script script/CheckBalance.s.sol:CheckBalance --rpc-url sepolia -vv

if ($swapsCompletos -eq $NUM_SWAPS) {
    Write-Host ""
    Write-Host "=== Todos os Swaps Concluídos! ===" -ForegroundColor Green
} else {
    Write-Host ""
    Write-Host "=== Alguns Swaps Falharam ===" -ForegroundColor Yellow
    Write-Host "Completos: $swapsCompletos de $NUM_SWAPS" -ForegroundColor White
}

