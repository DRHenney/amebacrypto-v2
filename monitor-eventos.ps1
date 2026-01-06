# Monitor de Eventos do Hook
# Monitora eventos emitidos pelo hook para facilitar debugging e monitoramento
# Execute: .\monitor-eventos.ps1

param(
    [int]$FromBlock = -1000,  # Blocos atrás (negativo) ou número absoluto
    [switch]$Watch = $false   # Monitorar em tempo real
)

Write-Host "=== Monitor de Eventos - AutoCompound Hook ===" -ForegroundColor Cyan
Write-Host ""

# Carregar .env
if (-not (Test-Path ".env")) {
    Write-Host "[ERRO] .env nao encontrado!" -ForegroundColor Red
    exit 1
}

$envVars = @{}
Get-Content .env | ForEach-Object {
    if ($_ -match '^\s*([^#][^=]*)\s*=\s*(.*)$') {
        $name = $matches[1].Trim()
        $value = $matches[2].Trim()
        $envVars[$name] = $value
    }
}

$hookAddress = $envVars["HOOK_ADDRESS"]
$rpcUrl = $envVars["SEPOLIA_RPC_URL"]
if (-not $rpcUrl) {
    $rpcUrl = $envVars["MAINNET_RPC_URL"]
}

if (-not $hookAddress -or -not $rpcUrl) {
    Write-Host "[ERRO] HOOK_ADDRESS ou RPC_URL nao configurado!" -ForegroundColor Red
    exit 1
}

Write-Host "Configuracao:" -ForegroundColor Yellow
Write-Host "  Hook: $hookAddress" -ForegroundColor White
Write-Host "  RPC: $($rpcUrl.Substring(0, [Math]::Min(50, $rpcUrl.Length)))..." -ForegroundColor Gray
Write-Host ""

# Obter bloco atual
try {
    $currentBlock = & "C:\foundry\bin\cast.exe" block-number --rpc-url $rpcUrl 2>&1
    if ($LASTEXITCODE -eq 0) {
        $currentBlock = [int]$currentBlock
        $fromBlock = if ($FromBlock -lt 0) { $currentBlock + $FromBlock } else { $FromBlock }
        Write-Host "Bloco atual: $currentBlock" -ForegroundColor Gray
        Write-Host "Verificando blocos: $fromBlock a $currentBlock" -ForegroundColor Gray
        Write-Host ""
    }
} catch {
    Write-Host "[AVISO] Nao foi possivel obter bloco atual" -ForegroundColor Yellow
}

Write-Host "=== Eventos Disponiveis ===" -ForegroundColor Cyan
Write-Host ""
Write-Host "1. CompoundExecuted - Compound executado com sucesso" -ForegroundColor Green
Write-Host "2. FeesAccumulated - Fees acumuladas apos swap" -ForegroundColor Green
Write-Host "3. FeesCompounded - Compound executado (compatibilidade)" -ForegroundColor Gray
Write-Host "4. PoolConfigUpdated - Configuracao da pool atualizada" -ForegroundColor Gray
Write-Host "5. TokenPricesUpdated - Precos atualizados" -ForegroundColor Gray
Write-Host ""

Write-Host "=== Buscando Eventos ===" -ForegroundColor Cyan
Write-Host ""

# Buscar eventos CompoundExecuted
Write-Host "Buscando eventos CompoundExecuted..." -ForegroundColor Yellow
try {
    $logs = & "C:\foundry\bin\cast.exe" logs `
        --from-block $fromBlock `
        --to-block latest `
        --address $hookAddress `
        --rpc-url $rpcUrl `
        "CompoundExecuted(bytes32,uint256,uint256,int128,uint256,uint256,uint256)" 2>&1
    
    if ($LASTEXITCODE -eq 0 -and $logs) {
        Write-Host "[OK] Eventos CompoundExecuted encontrados:" -ForegroundColor Green
        $logs | ForEach-Object { Write-Host "  $_" -ForegroundColor White }
    } else {
        Write-Host "[INFO] Nenhum evento CompoundExecuted encontrado" -ForegroundColor Gray
    }
} catch {
    Write-Host "[AVISO] Erro ao buscar eventos: $_" -ForegroundColor Yellow
}

Write-Host ""

# Buscar eventos FeesAccumulated
Write-Host "Buscando eventos FeesAccumulated..." -ForegroundColor Yellow
try {
    $logs = & "C:\foundry\bin\cast.exe" logs `
        --from-block $fromBlock `
        --to-block latest `
        --address $hookAddress `
        --rpc-url $rpcUrl `
        "FeesAccumulated(bytes32,uint256,uint256,uint256,uint256,uint256)" 2>&1
    
    if ($LASTEXITCODE -eq 0 -and $logs) {
        Write-Host "[OK] Eventos FeesAccumulated encontrados:" -ForegroundColor Green
        $logs | ForEach-Object { Write-Host "  $_" -ForegroundColor White }
    } else {
        Write-Host "[INFO] Nenhum evento FeesAccumulated encontrado" -ForegroundColor Gray
    }
} catch {
    Write-Host "[AVISO] Erro ao buscar eventos: $_" -ForegroundColor Yellow
}

Write-Host ""
Write-Host "=== Dica ===" -ForegroundColor Cyan
Write-Host "Para monitorar em tempo real, use um indexer como The Graph" -ForegroundColor White
Write-Host "ou crie um script Node.js usando ethers.js" -ForegroundColor White
Write-Host ""
Write-Host "Documentacao: EVENTOS-OTIMIZADOS.md" -ForegroundColor Gray

