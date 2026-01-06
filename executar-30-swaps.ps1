# Script para executar 30 swaps individuais
param(
    [int]$NumSwaps = 30
)

Write-Host "=== Executando $NumSwaps Swaps Individuais ===" -ForegroundColor Cyan
Write-Host ""

# Ler configurações do .env
$envFile = ".env"
if (-not (Test-Path $envFile)) {
    Write-Host "[ERRO] Arquivo .env nao encontrado!" -ForegroundColor Red
    exit 1
}

$rpcUrl = (Get-Content $envFile | Select-String "SEPOLIA_RPC_URL").ToString().Split("=")[1].Trim()
$wethAmount = (Get-Content $envFile | Select-String "SWAP_WETH_AMOUNT").ToString().Split("=")[1].Trim()

Write-Host "RPC URL: $rpcUrl" -ForegroundColor Gray
Write-Host "Amount per swap: $wethAmount wei" -ForegroundColor Gray
Write-Host ""

$successfulSwaps = 0
$failedSwaps = 0

for ($i = 1; $i -le $NumSwaps; $i++) {
    Write-Host "--- Swap $i of $NumSwaps ---" -ForegroundColor Yellow
    
    try {
        $output = & "C:\foundry\bin\forge.exe" script script/SwapWETHForUSDC.s.sol:SwapWETHForUSDC --rpc-url $rpcUrl --broadcast -vv 2>&1
        
        if ($LASTEXITCODE -eq 0) {
            $successfulSwaps++
            Write-Host "[OK] Swap $i executado com sucesso" -ForegroundColor Green
            
            # Verificar se há fees acumuladas
            $feesLine = $output | Select-String "Fees accumulated"
            if ($feesLine) {
                Write-Host $feesLine -ForegroundColor Cyan
            }
        } else {
            $failedSwaps++
            Write-Host "[ERRO] Swap $i falhou" -ForegroundColor Red
            $output | Select-String -Pattern "Error|Revert|Failed" | ForEach-Object {
                Write-Host $_ -ForegroundColor Red
            }
            
            # Se falhar 3 vezes seguidas, parar
            if ($failedSwaps -ge 3) {
                Write-Host ""
                Write-Host "[AVISO] Muitas falhas consecutivas. Parando execucao." -ForegroundColor Yellow
                break
            }
        }
    } catch {
        $failedSwaps++
        Write-Host "[ERRO] Swap $i falhou com excecao: $_" -ForegroundColor Red
    }
    
    Write-Host ""
    
    # Pequeno delay entre swaps (1 segundo)
    Start-Sleep -Seconds 1
}

Write-Host "=== Resumo Final ===" -ForegroundColor Cyan
Write-Host "Swaps executados com sucesso: $successfulSwaps de $NumSwaps" -ForegroundColor $(if ($successfulSwaps -eq $NumSwaps) { "Green" } else { "Yellow" })
Write-Host "Swaps falhados: $failedSwaps" -ForegroundColor $(if ($failedSwaps -eq 0) { "Green" } else { "Red" })
Write-Host ""

if ($successfulSwaps -gt 0) {
    Write-Host "[OK] Fees foram geradas! Verifique o status do compound." -ForegroundColor Green
}

