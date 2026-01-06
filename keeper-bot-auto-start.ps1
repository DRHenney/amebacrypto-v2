# Keeper Bot com Início Automático de Monitoramento
# Monitora eventos PoolAutoEnabled do hook e automaticamente começa a monitorar novas pools
# Execute: .\keeper-bot-auto-start.ps1

param(
    [int]$IntervalMinutes = 60,
    [switch]$RunOnce = $false,
    [switch]$Verbose = $false,
    [string]$Network = "auto"
)

Write-Host "=== Keeper Bot com Inicio Automatico ===" -ForegroundColor Cyan
Write-Host "Monitora eventos PoolAutoEnabled e inicia monitoramento automaticamente" -ForegroundColor Gray
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

# Hook address
$hookAddress = $envVars["HOOK_ADDRESS"]
if (-not $hookAddress) {
    Write-Host "[ERRO] HOOK_ADDRESS nao configurado!" -ForegroundColor Red
    exit 1
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
Write-Host "  Hook: $($hookAddress.Substring(0, [Math]::Min(20, $hookAddress.Length)))..." -ForegroundColor White
Write-Host "  Intervalo de verificacao: $IntervalMinutes minutos" -ForegroundColor White
Write-Host ""

# Arquivo para armazenar pools monitoradas
$poolsFile = "pools-monitoradas.json"
$monitoredPools = @{}

# Carregar pools já monitoradas
if (Test-Path $poolsFile) {
    try {
        $content = Get-Content $poolsFile -Raw | ConvertFrom-Json
        $monitoredPools = @{}
        $content.PSObject.Properties | ForEach-Object {
            $monitoredPools[$_.Name] = $_.Value
        }
        Write-Host "Pools ja monitoradas: $($monitoredPools.Count)" -ForegroundColor Green
    } catch {
        Write-Host "[AVISO] Erro ao carregar pools monitoradas. Comecando do zero." -ForegroundColor Yellow
    }
}

# Função para detectar novas pools via evento PoolAutoEnabled
function Detect-NewPoolsFromHook {
    param([int]$FromBlock, [int]$ToBlock)
    
    Write-Host "  Verificando eventos PoolAutoEnabled de $FromBlock a $ToBlock..." -ForegroundColor Gray
    
    try {
        # Event signature: PoolAutoEnabled(bytes32 indexed poolId, address currency0, address currency1, uint24 fee, int24 tickSpacing, address hookAddress)
        $eventSignature = "PoolAutoEnabled(bytes32,address,address,uint24,int24,address)"
        
        $logs = & "C:\foundry\bin\cast.exe" logs `
            --from-block $FromBlock `
            --to-block $ToBlock `
            --address $hookAddress `
            --rpc-url $rpcUrl `
            $eventSignature 2>&1
        
        if ($LASTEXITCODE -ne 0) {
            Write-Host "  [AVISO] Erro ao buscar eventos. Tentando metodo alternativo..." -ForegroundColor Yellow
            return @()
        }
        
        $newPools = @()
        
        # Parse dos logs (formato do cast logs)
        if ($logs -and $logs.Count -gt 0) {
            foreach ($log in $logs) {
                if ($log -match "poolId:\s*(0x[a-fA-F0-9]+)") {
                    $poolId = $matches[1]
                    
                    # Extrair outros parâmetros do log
                    # Formato: poolId: 0x..., currency0: 0x..., currency1: 0x..., fee: ..., tickSpacing: ..., hookAddress: 0x...
                    if ($log -match "currency0:\s*(0x[a-fA-F0-9]+)") {
                        $token0 = $matches[1]
                    }
                    if ($log -match "currency1:\s*(0x[a-fA-F0-9]+)") {
                        $token1 = $matches[1]
                    }
                    if ($log -match "fee:\s*(\d+)") {
                        $fee = [int]$matches[1]
                    }
                    if ($log -match "tickSpacing:\s*(-?\d+)") {
                        $tickSpacing = [int]$matches[1]
                    }
                    
                    if ($poolId -and $token0 -and $token1) {
                        $newPools += @{
                            PoolId = $poolId
                            Token0 = $token0
                            Token1 = $token1
                            Fee = $fee
                            TickSpacing = $tickSpacing
                            HookAddress = $hookAddress
                            PoolManager = $poolManagerAddress
                            DetectedAt = (Get-Date).ToString("yyyy-MM-dd HH:mm:ss")
                        }
                    }
                }
            }
        }
        
        return $newPools
    } catch {
        Write-Host "  [ERRO] Erro ao detectar pools: $_" -ForegroundColor Red
        return @()
    }
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

$executionCount = 0
$successCount = 0
$skipCount = 0
$lastBlockChecked = 0

# Obter bloco atual
try {
    $currentBlock = [int](& "C:\foundry\bin\cast.exe" block-number --rpc-url $rpcUrl 2>&1)
    if ($LASTEXITCODE -eq 0) {
        $lastBlockChecked = $currentBlock - 10000  # Verificar últimos 10k blocos inicialmente
        Write-Host "Bloco atual: $currentBlock" -ForegroundColor Gray
        Write-Host "Verificando a partir do bloco: $lastBlockChecked" -ForegroundColor Gray
    }
} catch {
    Write-Host "[AVISO] Nao foi possivel obter bloco atual" -ForegroundColor Yellow
    $currentBlock = 0
}

Write-Host ""
Write-Host "=== Iniciando Monitoramento ===" -ForegroundColor Green
Write-Host ""

# Função para verificar pools existentes diretamente do hook
function Get-ExistingPoolsFromHook {
    Write-Host "Verificando pools existentes no hook..." -ForegroundColor Cyan
    
    $pools = @()
    
    # Método 1: Buscar TODOS os eventos PoolAutoEnabled do hook (TODAS as pools)
    try {
        Write-Host "  Buscando TODOS os eventos PoolAutoEnabled do hook..." -ForegroundColor Gray
        
        if ($currentBlock -gt 0) {
            # Buscar eventos desde o deploy do hook (ou últimos 50k blocos)
            $fromBlock = [Math]::Max(0, $currentBlock - 50000)
            
            $eventSignature = "PoolAutoEnabled(bytes32,address,address,uint24,int24,address)"
            
            $logs = & "C:\foundry\bin\cast.exe" logs `
                --from-block $fromBlock `
                --to-block $currentBlock `
                --address $hookAddress `
                --rpc-url $rpcUrl `
                $eventSignature 2>&1
            
            if ($LASTEXITCODE -eq 0 -and $logs) {
                Write-Host "  [OK] Eventos encontrados, processando..." -ForegroundColor Green
                
                # Parse dos logs
                foreach ($log in $logs) {
                    # Extrair informações do evento
                    # Formato do cast logs pode variar, vamos tentar extrair
                    if ($log -match "poolId.*?0x([a-fA-F0-9]{64})") {
                        $poolIdHex = $matches[1]
                        $poolId = "0x$poolIdHex"
                        
                        # Tentar extrair outros campos
                        $token0 = $null
                        $token1 = $null
                        $fee = 0
                        $tickSpacing = 60
                        
                        if ($log -match "currency0.*?0x([a-fA-F0-9]{40})") {
                            $token0 = "0x$($matches[1])"
                        }
                        if ($log -match "currency1.*?0x([a-fA-F0-9]{40})") {
                            $token1 = "0x$($matches[1])"
                        }
                        if ($log -match "fee.*?(\d+)") {
                            $fee = [int]$matches[1]
                        }
                        if ($log -match "tickSpacing.*?(-?\d+)") {
                            $tickSpacing = [int]$matches[1]
                        }
                        
                        # Se temos poolId, adicionar (mesmo sem todos os campos)
                        if ($poolId) {
                            $poolKey = $poolId
                            if (-not ($pools | Where-Object { $_.PoolId -eq $poolKey })) {
                                $pool = @{
                                    PoolId = $poolId
                                    Token0 = if ($token0) { $token0 } else { "unknown" }
                                    Token1 = if ($token1) { $token1 } else { "unknown" }
                                    Fee = $fee
                                    TickSpacing = $tickSpacing
                                    HookAddress = $hookAddress
                                    PoolManager = $poolManagerAddress
                                    DetectedAt = (Get-Date).ToString("yyyy-MM-dd HH:mm:ss")
                                    Source = "PoolAutoEnabled Event"
                                }
                                $pools += $pool
                                Write-Host "    [OK] Pool encontrada: $($poolId.Substring(0, [Math]::Min(16, $poolId.Length)))..." -ForegroundColor Green
                            }
                        }
                    }
                }
            } else {
                Write-Host "  [AVISO] Nenhum evento encontrado ou erro ao buscar" -ForegroundColor Yellow
            }
        }
    } catch {
        Write-Host "  [AVISO] Erro ao buscar eventos: $_" -ForegroundColor Yellow
    }
    
    # Método 2: Adicionar pool padrão do .env como fallback (se eventos não funcionarem)
    # Mas priorizar eventos PoolAutoEnabled que encontram TODAS as pools
    if ($pools.Count -eq 0 -and $envVars["TOKEN0_ADDRESS"] -and $envVars["TOKEN1_ADDRESS"]) {
        Write-Host "  [AVISO] Nenhuma pool encontrada via eventos, usando .env como fallback" -ForegroundColor Yellow
        
        # Adicionar pools com diferentes fees (pools podem ter fees diferentes)
        $fees = @(3000, 5000, 10000)  # 0.3%, 0.5%, 1.0%
        
        foreach ($fee in $fees) {
            $poolKey = "pool-$($envVars["TOKEN0_ADDRESS"])-$($envVars["TOKEN1_ADDRESS"])-$fee"
            
            $pool = @{
                PoolId = $poolKey
                Token0 = $envVars["TOKEN0_ADDRESS"]
                Token1 = $envVars["TOKEN1_ADDRESS"]
                Fee = $fee
                TickSpacing = 60
                HookAddress = $hookAddress
                PoolManager = $poolManagerAddress
                DetectedAt = (Get-Date).ToString("yyyy-MM-dd HH:mm:ss")
                Source = ".env fallback"
            }
            $pools += $pool
        }
        Write-Host "  [OK] Pools do .env adicionadas como fallback" -ForegroundColor Yellow
    }
    
    # Método 3: Buscar eventos PoolAutoEnabled dos últimos blocos
    if ($currentBlock -gt 0) {
        try {
            Write-Host "  Buscando eventos PoolAutoEnabled dos ultimos blocos..." -ForegroundColor Gray
            
            $eventSignature = "PoolAutoEnabled(bytes32,address,address,uint24,int24,address)"
            
            $logs = & "C:\foundry\bin\cast.exe" logs `
                --from-block $lastBlockChecked `
                --to-block $currentBlock `
                --address $hookAddress `
                --rpc-url $rpcUrl `
                $eventSignature 2>&1
            
            if ($LASTEXITCODE -eq 0 -and $logs -and $logs.Count -gt 0) {
                Write-Host "  [OK] Eventos encontrados nos logs" -ForegroundColor Green
                # Parse dos logs seria feito aqui (complexo, melhor usar indexer em produção)
            }
        } catch {
            Write-Host "  [AVISO] Erro ao buscar eventos: $_" -ForegroundColor Yellow
        }
    }
    
    return $pools
}

# Verificar pools existentes no hook
Write-Host "Verificando pools existentes..." -ForegroundColor Cyan
$existingPools = Get-ExistingPoolsFromHook

foreach ($pool in $existingPools) {
    $poolKey = $pool.PoolId
    if (-not $monitoredPools.ContainsKey($poolKey)) {
        $monitoredPools[$poolKey] = $pool
        Write-Host "[OK] Pool existente adicionada: $poolKey" -ForegroundColor Green
        Write-Host "    Token0: $($pool.Token0)" -ForegroundColor Gray
        Write-Host "    Token1: $($pool.Token1)" -ForegroundColor Gray
        Write-Host "    Fee: $($pool.Fee)" -ForegroundColor Gray
        Write-Host "    [OK] Monitoramento iniciado automaticamente!" -ForegroundColor Green
    }
}

# Salvar pools monitoradas
$monitoredPools | ConvertTo-Json -Depth 10 | Set-Content $poolsFile

# Executar keeper para pools conhecidas
foreach ($poolKey in $monitoredPools.Keys) {
    $pool = $monitoredPools[$poolKey]
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

# Loop contínuo com detecção automática
Write-Host "=== Modo Loop Continuo com Deteccao Automatica ===" -ForegroundColor Green
Write-Host "Monitorando eventos PoolAutoEnabled do hook..." -ForegroundColor Yellow
Write-Host "Pressione Ctrl+C para parar" -ForegroundColor Yellow
Write-Host ""

$lastDetectionTime = Get-Date
$lastBlockChecked = [int]$currentBlock

try {
    while ($true) {
        # Verificar novas pools periodicamente (a cada 5 minutos)
        $timeSinceLastDetection = (Get-Date) - $lastDetectionTime
        if ($timeSinceLastDetection.TotalSeconds -ge 300) {
            Write-Host "[$(Get-Date -Format 'HH:mm:ss')] Verificando novas pools..." -ForegroundColor Cyan
            
            # Obter bloco atual
            try {
                $currentBlock = [int](& "C:\foundry\bin\cast.exe" block-number --rpc-url $rpcUrl 2>&1)
            } catch {
                Write-Host "  [AVISO] Erro ao obter bloco atual" -ForegroundColor Yellow
                $currentBlock = $lastBlockChecked + 100
            }
            
            # Detectar novas pools via evento PoolAutoEnabled
            $newPools = Detect-NewPoolsFromHook -FromBlock $lastBlockChecked -ToBlock $currentBlock
            
            if ($newPools.Count -gt 0) {
                Write-Host "  [OK] $($newPools.Count) nova(s) pool(s) detectada(s)!" -ForegroundColor Green
                foreach ($newPool in $newPools) {
                    $poolKey = $newPool.PoolId
                    if (-not $monitoredPools.ContainsKey($poolKey)) {
                        $monitoredPools[$poolKey] = $newPool
                        Write-Host "    - Pool: $($poolKey.Substring(0, [Math]::Min(16, $poolKey.Length)))..." -ForegroundColor White
                        Write-Host "      Token0: $($newPool.Token0)" -ForegroundColor Gray
                        Write-Host "      Token1: $($newPool.Token1)" -ForegroundColor Gray
                        Write-Host "      Fee: $($newPool.Fee)" -ForegroundColor Gray
                        Write-Host "      [OK] Monitoramento iniciado automaticamente!" -ForegroundColor Green
                        
                        # Começar a monitorar imediatamente
                        Execute-Keeper-For-Pool -Pool $newPool -VerboseOutput $Verbose
                        Write-Host ""
                    }
                }
                $monitoredPools | ConvertTo-Json -Depth 10 | Set-Content $poolsFile
            }
            
            $lastBlockChecked = $currentBlock
            $lastDetectionTime = Get-Date
        }
        
        # Executar keeper para todas as pools monitoradas
        foreach ($poolKey in $monitoredPools.Keys) {
            $pool = $monitoredPools[$poolKey]
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
    Write-Host "  Pools monitoradas: $($monitoredPools.Count)" -ForegroundColor White
}

