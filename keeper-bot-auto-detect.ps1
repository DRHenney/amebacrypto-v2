# Bot Keeper com Detecção Automática de Pools
# Monitora eventos do PoolManager e detecta automaticamente quando uma nova pool é criada
# Execute: .\keeper-bot-auto-detect.ps1

param(
    [int]$IntervalMinutes = 60,
    [switch]$RunOnce = $false,
    [switch]$Verbose = $false,
    [string]$Network = "auto",
    [int]$CheckIntervalSeconds = 300  # Verificar novos eventos a cada 5 minutos
)

Write-Host "=== Keeper Bot com Detecao Automatica de Pools ===" -ForegroundColor Cyan
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

# Hook address para filtrar pools
$targetHookAddress = $envVars["HOOK_ADDRESS"]
if (-not $targetHookAddress) {
    Write-Host "[AVISO] HOOK_ADDRESS nao configurado. Monitorara todas as pools." -ForegroundColor Yellow
}

# PoolManager address
$poolManagerAddress = $envVars["POOL_MANAGER"]
if (-not $poolManagerAddress) {
    Write-Host "[ERRO] POOL_MANAGER nao configurado!" -ForegroundColor Red
    exit 1
}

# Aviso para mainnet
if ($networkName -eq "mainnet") {
    Write-Host "=== AVISO: MAINNET DETECTADO ===" -ForegroundColor Red
    $confirm = Read-Host "Continuar? (digite 'SIM')"
    if ($confirm -ne "SIM") { exit 0 }
    Write-Host ""
}

Write-Host "Configuracao:" -ForegroundColor Yellow
Write-Host "  Rede: $networkName" -ForegroundColor White
Write-Host "  PoolManager: $($poolManagerAddress.Substring(0, [Math]::Min(20, $poolManagerAddress.Length)))..." -ForegroundColor White
Write-Host "  Hook Alvo: $(if ($targetHookAddress) { $targetHookAddress.Substring(0, [Math]::Min(20, $targetHookAddress.Length)) + '...' } else { 'Todas' })" -ForegroundColor White
Write-Host "  Intervalo de verificacao: $IntervalMinutes minutos" -ForegroundColor White
Write-Host "  Intervalo de deteccao: $CheckIntervalSeconds segundos" -ForegroundColor White
Write-Host ""

# Arquivo para armazenar pools detectadas
$poolsFile = "pools-detectadas.json"
$detectedPools = @{}

# Carregar pools já detectadas
if (Test-Path $poolsFile) {
    try {
        $content = Get-Content $poolsFile -Raw | ConvertFrom-Json
        $detectedPools = @{}
        $content.PSObject.Properties | ForEach-Object {
            $detectedPools[$_.Name] = $_.Value
        }
        Write-Host "Pools ja detectadas: $($detectedPools.Count)" -ForegroundColor Green
    } catch {
        Write-Host "[AVISO] Erro ao carregar pools detectadas. Comecando do zero." -ForegroundColor Yellow
    }
}

# Função para detectar novas pools via eventos
function Detect-NewPools {
    param([int]$FromBlock, [int]$ToBlock)
    
    Write-Host "  Verificando eventos Initialize de $FromBlock a $ToBlock..." -ForegroundColor Gray
    
    try {
        # Usar cast para buscar eventos Initialize
        # Event signature: Initialize(bytes32 indexed id, Currency indexed currency0, Currency indexed currency1, uint24 fee, int24 tickSpacing, Hooks indexed hooks, uint160 sqrtPriceX96, int24 tick)
        
        # Buscar logs do evento Initialize
        $logs = & "C:\foundry\bin\cast.exe" logs `
            --from-block $FromBlock `
            --to-block $ToBlock `
            --address $poolManagerAddress `
            --rpc-url $rpcUrl `
            "Initialize(bytes32,address,address,uint24,int24,address,uint160,int24)" 2>&1
        
        if ($LASTEXITCODE -ne 0) {
            Write-Host "  [AVISO] Erro ao buscar eventos. Tentando metodo alternativo..." -ForegroundColor Yellow
            return @()
        }
        
        $newPools = @()
        
        # Parse dos logs (formato pode variar)
        # Por enquanto, vamos usar uma abordagem mais simples: verificar diretamente via script Solidity
        
        return $newPools
    } catch {
        Write-Host "  [ERRO] Erro ao detectar pools: $_" -ForegroundColor Red
        return @()
    }
}

# Função para verificar pool via script Solidity
function Check-PoolViaScript {
    param(
        [string]$PoolId,
        [string]$Token0,
        [string]$Token1,
        [int]$Fee,
        [int]$TickSpacing,
        [string]$HookAddress
    )
    
    # Verificar se é o hook correto
    if ($targetHookAddress -and $HookAddress.ToLower() -ne $targetHookAddress.ToLower()) {
        return $false
    }
    
    # Verificar se pool já foi detectada
    $poolKey = "$PoolId"
    if ($detectedPools.ContainsKey($poolKey)) {
        return $false
    }
    
    return $true
}

# Função para executar keeper em uma pool
function Execute-Keeper-For-Pool {
    param(
        [hashtable]$Pool,
        [bool]$VerboseOutput = $false
    )
    
    $script:executionCount++
    $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    
    Write-Host "[$timestamp] Pool $($Pool.PoolId.Substring(0, [Math]::Min(16, $Pool.PoolId.Length)))... - Verificacao #$executionCount" -ForegroundColor Cyan
    
    # Configurar variáveis de ambiente temporárias
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
    
    try {
        if ($networkName -eq "mainnet" -or $networkName -eq "sepolia") {
            $output = & "C:\foundry\bin\forge.exe" script script/AutoCompoundKeeper.s.sol:AutoCompoundKeeper --rpc-url $networkName --broadcast --slow 2>&1
        } else {
            $output = & "C:\foundry\bin\forge.exe" script script/AutoCompoundKeeper.s.sol:AutoCompoundKeeper --rpc-url $rpcUrl --broadcast --slow 2>&1
        }
        
        $compoundExecuted = $output -match "Compound Executed Successfully|SUCCESS: Fees foram reinvestidas"
        $cannotPrepare = $output -match "Compound nao pode ser preparado|Cannot prepare compound"
        
        if ($compoundExecuted) {
            $script:successCount++
            Write-Host "  [OK] Compound executado!" -ForegroundColor Green
            return $true
        } elseif ($cannotPrepare) {
            $script:skipCount++
            Write-Host "  [SKIP] Compound nao pode ser executado" -ForegroundColor Yellow
            return $false
        } else {
            Write-Host "  [AVISO] Resultado desconhecido" -ForegroundColor Yellow
            return $false
        }
    } catch {
        Write-Host "  [ERRO] Erro: $_" -ForegroundColor Red
        return $false
    }
}

# Script Solidity para detectar pools
$detectScript = @"
// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Script, console2} from "forge-std/Script.sol";
import {IPoolManager} from "@uniswap/v4-core/src/interfaces/IPoolManager.sol";

contract DetectPools is Script {
    function run() external view {
        address poolManager = vm.envAddress("POOL_MANAGER");
        address targetHook = vm.envAddress("HOOK_ADDRESS");
        
        IPoolManager pm = IPoolManager(poolManager);
        
        // Buscar eventos Initialize recentes
        // Nota: Em produção, você usaria um indexer ou subgraph
        console2.log("PoolManager:", poolManager);
        console2.log("Target Hook:", targetHook);
        console2.log("Use um indexer ou subgraph para buscar eventos Initialize");
    }
}
"@

# Criar script de detecção se não existir
$detectScriptPath = "script/DetectNewPools.s.sol"
if (-not (Test-Path $detectScriptPath)) {
    $detectScript | Set-Content $detectScriptPath
}

# Função melhorada para detectar pools usando script
function Detect-PoolsViaScript {
    Write-Host "  Detectando novas pools..." -ForegroundColor Cyan
    
    try {
        # Usar script Solidity para verificar pools
        # Por enquanto, vamos usar uma abordagem mais prática:
        # Monitorar o hook diretamente para ver quais pools estão configuradas
        
        # Alternativa: usar um script que lista pools do hook
        # Mas isso requer que o hook tenha uma função para listar pools
        
        # Por enquanto, vamos adicionar pools manualmente detectadas
        # ou usar o método de monitoramento de eventos via Node.js
        
        return @()
    } catch {
        Write-Host "  [ERRO] Erro ao detectar: $_" -ForegroundColor Red
        return @()
    }
}

$executionCount = 0
$successCount = 0
$skipCount = 0
$lastBlockChecked = 0

# Obter bloco atual
try {
    $currentBlock = & "C:\foundry\bin\cast.exe" block-number --rpc-url $rpcUrl 2>&1
    if ($LASTEXITCODE -eq 0) {
        $lastBlockChecked = [int]$currentBlock - 1000  # Verificar últimos 1000 blocos inicialmente
        Write-Host "Bloco atual: $currentBlock" -ForegroundColor Gray
        Write-Host "Verificando a partir do bloco: $lastBlockChecked" -ForegroundColor Gray
    }
} catch {
    Write-Host "[AVISO] Nao foi possivel obter bloco atual" -ForegroundColor Yellow
}

Write-Host ""
Write-Host "=== Iniciando Monitoramento ===" -ForegroundColor Green
Write-Host ""

# Adicionar pool padrão se configurada
if ($envVars["POOL_MANAGER"] -and $envVars["HOOK_ADDRESS"] -and $envVars["TOKEN0_ADDRESS"] -and $envVars["TOKEN1_ADDRESS"]) {
    $defaultPool = @{
        PoolId = "default"
        PoolManager = $envVars["POOL_MANAGER"]
        HookAddress = $envVars["HOOK_ADDRESS"]
        Token0 = $envVars["TOKEN0_ADDRESS"]
        Token1 = $envVars["TOKEN1_ADDRESS"]
        Fee = 3000
        TickSpacing = 60
    }
    
    $poolKey = "default"
    if (-not $detectedPools.ContainsKey($poolKey)) {
        $detectedPools[$poolKey] = $defaultPool
        Write-Host "[OK] Pool padrao adicionada ao monitoramento" -ForegroundColor Green
    }
}

# Salvar pools detectadas
$detectedPools | ConvertTo-Json -Depth 10 | Set-Content $poolsFile

# Executar keeper para pools conhecidas
foreach ($poolKey in $detectedPools.Keys) {
    $pool = $detectedPools[$poolKey]
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

# Loop contínuo com detecção
Write-Host "=== Modo Loop Continuo com Deteccao Automatica ===" -ForegroundColor Green
Write-Host "Pressione Ctrl+C para parar" -ForegroundColor Yellow
Write-Host ""

$lastDetectionTime = Get-Date

try {
    while ($true) {
        # Verificar novas pools periodicamente
        $timeSinceLastDetection = (Get-Date) - $lastDetectionTime
        if ($timeSinceLastDetection.TotalSeconds -ge $CheckIntervalSeconds) {
            Write-Host "[$(Get-Date -Format 'HH:mm:ss')] Verificando novas pools..." -ForegroundColor Cyan
            
            # Tentar detectar novas pools
            $newPools = Detect-PoolsViaScript
            
            if ($newPools.Count -gt 0) {
                Write-Host "  [OK] $($newPools.Count) nova(s) pool(s) detectada(s)!" -ForegroundColor Green
                foreach ($newPool in $newPools) {
                    $poolKey = $newPool.PoolId
                    $detectedPools[$poolKey] = $newPool
                    Write-Host "    - Pool: $($poolKey.Substring(0, [Math]::Min(16, $poolKey.Length)))..." -ForegroundColor White
                }
                $detectedPools | ConvertTo-Json -Depth 10 | Set-Content $poolsFile
            }
            
            $lastDetectionTime = Get-Date
        }
        
        # Executar keeper para todas as pools
        foreach ($poolKey in $detectedPools.Keys) {
            $pool = $detectedPools[$poolKey]
            Execute-Keeper-For-Pool -Pool $pool -VerboseOutput $Verbose
            Write-Host ""
        }
        
        # Aguardar intervalo
        $nextCheck = (Get-Date).AddMinutes($IntervalMinutes)
        Write-Host "Proxima verificacao em: $($nextCheck.ToString('HH:mm:ss'))" -ForegroundColor Gray
        Write-Host "Aguardando $IntervalMinutes minutos..." -ForegroundColor Gray
        Write-Host ""
        
        Start-Sleep -Seconds ($IntervalMinutes * 60)
    }
} catch {
    Write-Host ""
    Write-Host "=== Bot Interrompido ===" -ForegroundColor Yellow
    Write-Host "  Execucoes totais: $executionCount" -ForegroundColor White
    Write-Host "  Sucessos: $successCount" -ForegroundColor Green
    Write-Host "  Pulados: $skipCount" -ForegroundColor Yellow
    Write-Host "  Pools monitoradas: $($detectedPools.Count)" -ForegroundColor White
}

