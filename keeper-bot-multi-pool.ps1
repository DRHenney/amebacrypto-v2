# Bot Keeper Multi-Pool - Monitora múltiplas pools automaticamente
# Este script pode monitorar múltiplas pools configuradas no .env
# Execute: .\keeper-bot-multi-pool.ps1

param(
    [int]$IntervalMinutes = 60,
    [switch]$RunOnce = $false,
    [switch]$Verbose = $false,
    [string]$Network = "auto"
)

Write-Host "=== Keeper Bot Multi-Pool - AutoCompound Hook ===" -ForegroundColor Cyan
Write-Host ""

# Verificar se .env existe
if (-not (Test-Path ".env")) {
    Write-Host "[ERRO] Arquivo .env nao encontrado!" -ForegroundColor Red
    exit 1
}

# Carregar variáveis do .env
$envVars = @{}
Get-Content .env | ForEach-Object {
    if ($_ -match '^\s*([^#][^=]*)\s*=\s*(.*)$') {
        $name = $matches[1].Trim()
        $value = $matches[2].Trim()
        $envVars[$name] = $value
    }
}

# Detectar rede
$rpcUrl = $null
$networkName = ""

if ($Network -eq "auto" -or $Network -eq "") {
    if ($envVars["MAINNET_RPC_URL"]) {
        $rpcUrl = $envVars["MAINNET_RPC_URL"]
        $networkName = "mainnet"
    } elseif ($envVars["SEPOLIA_RPC_URL"]) {
        $rpcUrl = $envVars["SEPOLIA_RPC_URL"]
        $networkName = "sepolia"
    }
} else {
    if ($Network -eq "mainnet") {
        $rpcUrl = $envVars["MAINNET_RPC_URL"]
        $networkName = "mainnet"
    } elseif ($Network -eq "sepolia") {
        $rpcUrl = $envVars["SEPOLIA_RPC_URL"]
        $networkName = "sepolia"
    }
}

if (-not $rpcUrl) {
    Write-Host "[ERRO] RPC URL nao encontrado!" -ForegroundColor Red
    exit 1
}

# Aviso para mainnet
if ($networkName -eq "mainnet") {
    Write-Host "=== AVISO: MAINNET DETECTADO ===" -ForegroundColor Red
    $confirm = Read-Host "Continuar? (digite 'SIM')"
    if ($confirm -ne "SIM") { exit 0 }
    Write-Host ""
}

# Detectar pools configuradas
# Formato no .env:
# POOL_1_POOL_MANAGER=0x...
# POOL_1_HOOK_ADDRESS=0x...
# POOL_1_TOKEN0=0x...
# POOL_1_TOKEN1=0x...
# POOL_2_POOL_MANAGER=0x...
# etc.

$pools = @()
$poolIndex = 1

while ($true) {
    $poolManager = $envVars["POOL_${poolIndex}_POOL_MANAGER"]
    $hookAddress = $envVars["POOL_${poolIndex}_HOOK_ADDRESS"]
    $token0 = $envVars["POOL_${poolIndex}_TOKEN0"]
    $token1 = $envVars["POOL_${poolIndex}_TOKEN1"]
    
    if (-not $poolManager -or -not $hookAddress) {
        break
    }
    
    $pools += @{
        Index = $poolIndex
        PoolManager = $poolManager
        HookAddress = $hookAddress
        Token0 = $token0
        Token1 = $token1
    }
    
    $poolIndex++
}

# Se não encontrou pools no formato POOL_X, usar formato padrão
if ($pools.Count -eq 0) {
    if ($envVars["POOL_MANAGER"] -and $envVars["HOOK_ADDRESS"]) {
        $pools += @{
            Index = 1
            PoolManager = $envVars["POOL_MANAGER"]
            HookAddress = $envVars["HOOK_ADDRESS"]
            Token0 = $envVars["TOKEN0_ADDRESS"]
            Token1 = $envVars["TOKEN1_ADDRESS"]
        }
    }
}

if ($pools.Count -eq 0) {
    Write-Host "[ERRO] Nenhuma pool configurada no .env!" -ForegroundColor Red
    Write-Host "Configure POOL_MANAGER e HOOK_ADDRESS ou POOL_X_POOL_MANAGER, POOL_X_HOOK_ADDRESS" -ForegroundColor Yellow
    exit 1
}

Write-Host "Configuracao:" -ForegroundColor Yellow
Write-Host "  Rede: $networkName" -ForegroundColor White
Write-Host "  Pools encontradas: $($pools.Count)" -ForegroundColor White
Write-Host "  Intervalo: $IntervalMinutes minutos" -ForegroundColor White
Write-Host "  Modo: $(if ($RunOnce) { 'Executar uma vez' } else { 'Loop continuo' })" -ForegroundColor White
Write-Host ""

foreach ($pool in $pools) {
    Write-Host "  Pool #$($pool.Index):" -ForegroundColor Cyan
    Write-Host "    Hook: $($pool.HookAddress.Substring(0, [Math]::Min(20, $pool.HookAddress.Length)))..." -ForegroundColor Gray
}

Write-Host ""

$executionCount = 0
$successCount = 0
$skipCount = 0

function Execute-Keeper-For-Pool {
    param(
        [hashtable]$Pool,
        [bool]$VerboseOutput = $false
    )
    
    $script:executionCount++
    $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    
    Write-Host "[$timestamp] Pool #$($Pool.Index) - Verificacao #$executionCount" -ForegroundColor Cyan
    
    # Criar arquivo .env temporário para esta pool
    $tempEnv = @()
    $tempEnv += "PRIVATE_KEY=$($envVars['PRIVATE_KEY'])"
    $tempEnv += "POOL_MANAGER=$($Pool.PoolManager)"
    $tempEnv += "HOOK_ADDRESS=$($Pool.HookAddress)"
    $tempEnv += "TOKEN0_ADDRESS=$($Pool.Token0)"
    $tempEnv += "TOKEN1_ADDRESS=$($Pool.Token1)"
    if ($networkName -eq "mainnet") {
        $tempEnv += "MAINNET_RPC_URL=$rpcUrl"
    } else {
        $tempEnv += "SEPOLIA_RPC_URL=$rpcUrl"
    }
    
    $tempEnvFile = ".env.temp.pool$($Pool.Index)"
    $tempEnv | Set-Content $tempEnvFile
    
    try {
        # Executar keeper com .env temporário
        $env:PRIVATE_KEY = $envVars['PRIVATE_KEY']
        $env:POOL_MANAGER = $Pool.PoolManager
        $env:HOOK_ADDRESS = $Pool.HookAddress
        $env:TOKEN0_ADDRESS = $Pool.Token0
        $env:TOKEN1_ADDRESS = $Pool.Token1
        if ($networkName -eq "mainnet") {
            $env:MAINNET_RPC_URL = $rpcUrl
        } else {
            $env:SEPOLIA_RPC_URL = $rpcUrl
        }
        
        if ($networkName -eq "mainnet" -or $networkName -eq "sepolia") {
            $output = & "C:\foundry\bin\forge.exe" script script/AutoCompoundKeeper.s.sol:AutoCompoundKeeper --rpc-url $networkName --broadcast --slow 2>&1
        } else {
            $output = & "C:\foundry\bin\forge.exe" script script/AutoCompoundKeeper.s.sol:AutoCompoundKeeper --rpc-url $rpcUrl --broadcast --slow 2>&1
        }
        
        $compoundExecuted = $output -match "Compound Executed Successfully|SUCCESS: Fees foram reinvestidas"
        $cannotPrepare = $output -match "Compound nao pode ser preparado|Cannot prepare compound"
        
        if ($compoundExecuted) {
            $script:successCount++
            Write-Host "  [OK] Compound executado com sucesso!" -ForegroundColor Green
            Remove-Item $tempEnvFile -ErrorAction SilentlyContinue
            return $true
        } elseif ($cannotPrepare) {
            $script:skipCount++
            Write-Host "  [SKIP] Compound nao pode ser executado" -ForegroundColor Yellow
            Remove-Item $tempEnvFile -ErrorAction SilentlyContinue
            return $false
        } else {
            Write-Host "  [AVISO] Resultado desconhecido" -ForegroundColor Yellow
            Remove-Item $tempEnvFile -ErrorAction SilentlyContinue
            return $false
        }
    } catch {
        Write-Host "  [ERRO] Erro: $_" -ForegroundColor Red
        Remove-Item $tempEnvFile -ErrorAction SilentlyContinue
        return $false
    }
}

# Executar para todas as pools
Write-Host "=== Iniciando Monitoramento ===" -ForegroundColor Green
Write-Host ""

foreach ($pool in $pools) {
    Execute-Keeper-For-Pool -Pool $pool -VerboseOutput $Verbose
    Write-Host ""
}

if ($RunOnce) {
    Write-Host "=== Execucao Unica Concluida ===" -ForegroundColor Cyan
    Write-Host "  Execucoes: $executionCount" -ForegroundColor White
    Write-Host "  Sucessos: $successCount" -ForegroundColor Green
    Write-Host "  Pulados: $skipCount" -ForegroundColor Yellow
    exit 0
}

# Loop contínuo
Write-Host "=== Modo Loop Continuo Ativado ===" -ForegroundColor Green
Write-Host "Pressione Ctrl+C para parar" -ForegroundColor Yellow
Write-Host ""

try {
    while ($true) {
        $nextCheck = (Get-Date).AddMinutes($IntervalMinutes)
        Write-Host "Proxima verificacao em: $($nextCheck.ToString('HH:mm:ss'))" -ForegroundColor Gray
        Write-Host "Aguardando $IntervalMinutes minutos..." -ForegroundColor Gray
        Write-Host ""
        
        Start-Sleep -Seconds ($IntervalMinutes * 60)
        
        foreach ($pool in $pools) {
            Execute-Keeper-For-Pool -Pool $pool -VerboseOutput $Verbose
            Write-Host ""
        }
    }
} catch {
    Write-Host ""
    Write-Host "=== Bot Interrompido ===" -ForegroundColor Yellow
    Write-Host "  Execucoes totais: $executionCount" -ForegroundColor White
    Write-Host "  Sucessos: $successCount" -ForegroundColor Green
    Write-Host "  Pulados: $skipCount" -ForegroundColor Yellow
}

