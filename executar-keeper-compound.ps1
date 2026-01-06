# Script PowerShell para executar o keeper de compound automaticamente
# Execute: .\executar-keeper-compound.ps1

$ErrorActionPreference = "Stop"

Write-Host "=== Executando Auto Compound Keeper ===" -ForegroundColor Cyan
Write-Host "Timestamp: $(Get-Date)" -ForegroundColor Gray
Write-Host ""

# Verificar se .env existe
if (-not (Test-Path ".env")) {
    Write-Host "Erro: Arquivo .env nao encontrado!" -ForegroundColor Red
    exit 1
}

# Carregar variáveis do .env
Get-Content ".env" | ForEach-Object {
    if ($_ -match '^\s*([^#][^=]+)=(.*)$') {
        $name = $matches[1].Trim()
        $value = $matches[2].Trim()
        [Environment]::SetEnvironmentVariable($name, $value, "Process")
    }
}

# Verificar variáveis obrigatórias
$requiredVars = @("PRIVATE_KEY", "POOL_MANAGER", "HOOK_ADDRESS", "TOKEN0_ADDRESS", "TOKEN1_ADDRESS", "SEPOLIA_RPC_URL")
foreach ($var in $requiredVars) {
    if (-not [Environment]::GetEnvironmentVariable($var, "Process")) {
        Write-Host "Erro: Variavel $var nao configurada no .env!" -ForegroundColor Red
        exit 1
    }
}

Write-Host "Executando keeper..." -ForegroundColor Yellow
Write-Host ""

# Executar o script do keeper
& "C:\foundry\bin\forge.exe" script script/AutoCompoundKeeper.s.sol:AutoCompoundKeeper `
    --rpc-url sepolia `
    --broadcast `
    -vvv

if ($LASTEXITCODE -eq 0) {
    Write-Host ""
    Write-Host "=== Keeper execution finished ===" -ForegroundColor Green
    Write-Host "Timestamp: $(Get-Date)" -ForegroundColor Gray
} else {
    Write-Host ""
    Write-Host "=== Keeper execution failed ===" -ForegroundColor Red
    Write-Host "Verifique os logs acima para mais detalhes" -ForegroundColor Yellow
    exit 1
}

