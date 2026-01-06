# Script para verificar saldo de USDC na carteira
# Execute: .\verificar-saldo-usdc.ps1

Write-Host "=== Verificando Saldo de USDC ===" -ForegroundColor Cyan
Write-Host ""

# Verificar se .env existe
if (-not (Test-Path ".env")) {
    Write-Host "[ERRO] Arquivo .env não encontrado!" -ForegroundColor Red
    exit 1
}

# Ler variáveis do .env
$envContent = Get-Content .env -Raw

# Extrair endereços
$privateKeyMatch = $envContent | Select-String "PRIVATE_KEY=(.+)"
$token0Match = $envContent | Select-String "TOKEN0_ADDRESS=(.+)"

if (-not $privateKeyMatch -or -not $token0Match) {
    Write-Host "[ERRO] PRIVATE_KEY ou TOKEN0_ADDRESS não encontrados no .env" -ForegroundColor Red
    exit 1
}

$token0Address = $token0Match.Matches.Groups[1].Value.Trim()

# Obter endereço da carteira a partir da chave privada
$privateKey = $privateKeyMatch.Matches.Groups[1].Value.Trim()
if ($privateKey -match "^0x") {
    $privateKey = $privateKey -replace "0x", ""
}

Write-Host "Token0 (USDC): $token0Address" -ForegroundColor Yellow
Write-Host ""

# Obter endereço da carteira primeiro
Write-Host "Obtendo endereço da carteira..." -ForegroundColor Yellow
$walletAddress = & "C:\foundry\bin\cast.exe" wallet address $privateKey 2>&1 | Select-Object -Last 1
$walletAddress = $walletAddress.Trim()

if (-not $walletAddress -or $walletAddress -match "Error") {
    Write-Host "[ERRO] Não foi possível obter endereço da carteira" -ForegroundColor Red
    exit 1
}

Write-Host "Endereço da carteira: $walletAddress" -ForegroundColor White
Write-Host ""

# Usar cast para verificar saldo
Write-Host "Verificando saldo..." -ForegroundColor Yellow

$balanceHex = & "C:\foundry\bin\cast.exe" call $token0Address "balanceOf(address)(uint256)" $walletAddress --rpc-url sepolia 2>&1

if ($LASTEXITCODE -eq 0 -and $balanceHex -match "0x[0-9a-fA-F]+") {
    # Converter de hex para decimal
    $balanceDecimal = [System.Convert]::ToInt64($balanceHex, 16)
    $balanceUSDC = $balanceDecimal / 1000000.0  # USDC tem 6 decimais
    
    Write-Host ""
    Write-Host "Saldo encontrado:" -ForegroundColor Green
    Write-Host "  Saldo em wei: $balanceDecimal" -ForegroundColor White
    Write-Host "  Saldo em USDC: $balanceUSDC USDC" -ForegroundColor White
    Write-Host ""
    
    if ($balanceUSDC -lt 1) {
        Write-Host "[AVISO] Saldo muito baixo! Você precisa de mais USDC para adicionar liquidez." -ForegroundColor Yellow
        Write-Host "  Saldo atual: $balanceUSDC USDC" -ForegroundColor White
        Write-Host "  Recomendado: pelo menos 10-50 USDC" -ForegroundColor White
    } else {
        Write-Host "[OK] Você tem $balanceUSDC USDC disponível" -ForegroundColor Green
        Write-Host "  Você pode adicionar até aproximadamente $([math]::Floor($balanceUSDC * 0.95)) USDC (deixando 5% para gas)" -ForegroundColor Gray
    }
} else {
    Write-Host "[ERRO] Não foi possível verificar o saldo automaticamente" -ForegroundColor Red
    Write-Host ""
    Write-Host "Tente verificar o saldo manualmente em:" -ForegroundColor Yellow
    Write-Host "  https://sepolia.etherscan.io/address/$walletAddress" -ForegroundColor Cyan
    Write-Host "  Token: https://sepolia.etherscan.io/token/$token0Address?a=$walletAddress" -ForegroundColor Cyan
}

