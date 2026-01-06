# Bot Keeper Automático para AutoCompound Hook
# Este script monitora a pool e executa o compound automaticamente quando possível
# Execute: .\keeper-bot-automatico.ps1

param(
    [int]$IntervalMinutes = 60,  # Intervalo de verificação em minutos (padrão: 1 hora)
    [switch]$RunOnce = $false,    # Executar apenas uma vez (não loop infinito)
    [switch]$Verbose = $false,
    [string]$Network = "auto"     # Rede: "sepolia", "mainnet", ou "auto" (detecta automaticamente)
)

Write-Host "=== Keeper Bot Automático - AutoCompound Hook ===" -ForegroundColor Cyan
Write-Host ""

# Verificar se .env existe
if (-not (Test-Path ".env")) {
    Write-Host "[ERRO] Arquivo .env nao encontrado!" -ForegroundColor Red
    Write-Host "Execute primeiro: .\configurar-env.ps1" -ForegroundColor Yellow
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

# Detectar rede automaticamente ou usar a especificada
$rpcUrl = $null
$networkName = ""

if ($Network -eq "auto" -or $Network -eq "") {
    # Tentar detectar: verificar qual RPC está configurado
    if ($envVars["MAINNET_RPC_URL"]) {
        $rpcUrl = $envVars["MAINNET_RPC_URL"]
        $networkName = "mainnet"
    } elseif ($envVars["SEPOLIA_RPC_URL"]) {
        $rpcUrl = $envVars["SEPOLIA_RPC_URL"]
        $networkName = "sepolia"
    }
} else {
    # Usar rede especificada
    if ($Network -eq "mainnet") {
        $rpcUrl = $envVars["MAINNET_RPC_URL"]
        $networkName = "mainnet"
    } elseif ($Network -eq "sepolia") {
        $rpcUrl = $envVars["SEPOLIA_RPC_URL"]
        $networkName = "sepolia"
    }
}

if (-not $rpcUrl) {
    Write-Host "[ERRO] RPC URL nao encontrado no .env!" -ForegroundColor Red
    Write-Host "Configure MAINNET_RPC_URL ou SEPOLIA_RPC_URL no arquivo .env" -ForegroundColor Yellow
    exit 1
}

# Aviso de segurança para mainnet
if ($networkName -eq "mainnet") {
    Write-Host "=== AVISO: MAINNET DETECTADO ===" -ForegroundColor Red
    Write-Host "Voce esta executando o keeper no MAINNET!" -ForegroundColor Yellow
    Write-Host "Certifique-se de:" -ForegroundColor Yellow
    Write-Host "  1. Private key esta segura e nao compartilhada" -ForegroundColor White
    Write-Host "  2. Carteira tem ETH suficiente para gas" -ForegroundColor White
    Write-Host "  3. Contratos foram auditados e testados" -ForegroundColor White
    Write-Host "  4. Configuracoes estao corretas" -ForegroundColor White
    Write-Host ""
    $confirm = Read-Host "Continuar com mainnet? (digite 'SIM' para confirmar)"
    if ($confirm -ne "SIM") {
        Write-Host "Operacao cancelada." -ForegroundColor Yellow
        exit 0
    }
    Write-Host ""
}

Write-Host "Configuracao:" -ForegroundColor Yellow
Write-Host "  Rede: $networkName" -ForegroundColor $(if ($networkName -eq "mainnet") { "Red" } else { "White" })
Write-Host "  Intervalo de verificacao: $IntervalMinutes minutos" -ForegroundColor White
Write-Host "  Modo: $(if ($RunOnce) { 'Executar uma vez' } else { 'Loop continuo' })" -ForegroundColor White
Write-Host "  RPC: $($rpcUrl.Substring(0, [Math]::Min(50, $rpcUrl.Length)))..." -ForegroundColor Gray
Write-Host ""

$executionCount = 0
$successCount = 0
$skipCount = 0

function Execute-Keeper {
    param([bool]$VerboseOutput = $false)
    
    $executionCount++
    $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    
    Write-Host "[$timestamp] Verificacao #$executionCount" -ForegroundColor Cyan
    
    try {
        # Executar o keeper script
        # Usar --rpc-url com o nome da rede se disponível no foundry.toml, senão usar URL direta
        if ($networkName -eq "mainnet" -or $networkName -eq "sepolia") {
            $output = & "C:\foundry\bin\forge.exe" script script/AutoCompoundKeeper.s.sol:AutoCompoundKeeper --rpc-url $networkName --broadcast --slow 2>&1
        } else {
            $output = & "C:\foundry\bin\forge.exe" script script/AutoCompoundKeeper.s.sol:AutoCompoundKeeper --rpc-url $rpcUrl --broadcast --slow 2>&1
        }
        
        # Verificar se o compound foi executado
        $compoundExecuted = $output -match "Compound Executed Successfully|SUCCESS: Fees foram reinvestidas"
        $cannotPrepare = $output -match "Compound nao pode ser preparado|Cannot prepare compound"
        
        if ($compoundExecuted) {
            $script:successCount++
            Write-Host "  [OK] Compound executado com sucesso!" -ForegroundColor Green
            return $true
        } elseif ($cannotPrepare) {
            $script:skipCount++
            Write-Host "  [SKIP] Compound nao pode ser executado (condicoes nao atendidas)" -ForegroundColor Yellow
            return $false
        } else {
            Write-Host "  [AVISO] Resultado desconhecido" -ForegroundColor Yellow
            if ($VerboseOutput) {
                Write-Host $output -ForegroundColor Gray
            }
            return $false
        }
    } catch {
        Write-Host "  [ERRO] Erro ao executar keeper: $_" -ForegroundColor Red
        return $false
    }
}

# Executar pela primeira vez
Write-Host "=== Iniciando Monitoramento ===" -ForegroundColor Green
Write-Host ""

Execute-Keeper -VerboseOutput $Verbose

if ($RunOnce) {
    Write-Host ""
    Write-Host "=== Execucao Unica Concluida ===" -ForegroundColor Cyan
    Write-Host "  Execucoes: $executionCount" -ForegroundColor White
    Write-Host "  Sucessos: $successCount" -ForegroundColor Green
    Write-Host "  Pulados: $skipCount" -ForegroundColor Yellow
    exit 0
}

# Loop contínuo
Write-Host ""
Write-Host "=== Modo Loop Continuo Ativado ===" -ForegroundColor Green
Write-Host "Pressione Ctrl+C para parar" -ForegroundColor Yellow
Write-Host ""

try {
    while ($true) {
        # Aguardar intervalo
        $nextCheck = (Get-Date).AddMinutes($IntervalMinutes)
        Write-Host "Proxima verificacao em: $($nextCheck.ToString('HH:mm:ss'))" -ForegroundColor Gray
        Write-Host "Aguardando $IntervalMinutes minutos..." -ForegroundColor Gray
        Write-Host ""
        
        Start-Sleep -Seconds ($IntervalMinutes * 60)
        
        # Executar verificação
        Execute-Keeper -VerboseOutput $Verbose
        
        Write-Host ""
    }
} catch {
    Write-Host ""
    Write-Host "=== Bot Interrompido ===" -ForegroundColor Yellow
    Write-Host "  Execucoes totais: $executionCount" -ForegroundColor White
    Write-Host "  Sucessos: $successCount" -ForegroundColor Green
    Write-Host "  Pulados: $skipCount" -ForegroundColor Yellow
    Write-Host ""
}

