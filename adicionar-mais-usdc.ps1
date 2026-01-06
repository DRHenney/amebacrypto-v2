# Script para adicionar mais USDC à pool USDC/WETH
# Execute: .\adicionar-mais-usdc.ps1

param(
    [string]$USDC_AMOUNT = ""
)

Write-Host "=== Adicionar Mais USDC à Pool ===" -ForegroundColor Cyan
Write-Host ""

# Se não foi fornecido via parâmetro, perguntar ao usuário
if ([string]::IsNullOrEmpty($USDC_AMOUNT)) {
    Write-Host "Quanto USDC você quer adicionar?" -ForegroundColor Yellow
    Write-Host "  Exemplo: 50 para 50 USDC, 100 para 100 USDC" -ForegroundColor Gray
    Write-Host ""
    $USDC_AMOUNT = Read-Host "Quantidade de USDC"
}

# Converter para número
try {
    $usdcValue = [decimal]$USDC_AMOUNT
} catch {
    Write-Host "[ERRO] Valor inválido! Use um número (ex: 50, 100, 200)" -ForegroundColor Red
    exit 1
}

# Validar valor
if ($usdcValue -le 0) {
    Write-Host "[ERRO] A quantidade deve ser maior que zero!" -ForegroundColor Red
    exit 1
}

# USDC tem 6 decimais
$usdcSmallest = [math]::Floor($usdcValue * 1000000)
$usdcInt = [string]$usdcSmallest

# Calcular WETH correspondente (assumindo 1 WETH = 3000 USDC)
# Ajuste este valor se o preço for diferente
$WETH_PRICE = 3000
$wethValue = $usdcValue / $WETH_PRICE
$wethSmallest = [math]::Floor($wethValue * 1000000000000000000) # 18 decimais
$wethInt = [string]$wethSmallest

Write-Host ""
Write-Host "Valores calculados:" -ForegroundColor Yellow
Write-Host "  USDC: $usdcInt ($usdcValue USDC)" -ForegroundColor White
Write-Host "  WETH: $wethInt ($wethValue WETH)" -ForegroundColor White
Write-Host "  Proporção: 1 WETH = $WETH_PRICE USDC" -ForegroundColor Gray
Write-Host ""

# Verificar se .env existe
if (-not (Test-Path ".env")) {
    Write-Host "[ERRO] Arquivo .env não encontrado!" -ForegroundColor Red
    Write-Host "Execute primeiro: .\configurar-env.ps1" -ForegroundColor Yellow
    exit 1
}

# Ler conteúdo do .env
$envContent = Get-Content .env -Raw

# Atualizar ou adicionar LIQUIDITY_TOKEN0_AMOUNT (USDC)
if ($envContent -match "LIQUIDITY_TOKEN0_AMOUNT=") {
    $envContent = $envContent -replace "LIQUIDITY_TOKEN0_AMOUNT=.*", "LIQUIDITY_TOKEN0_AMOUNT=$usdcInt"
    Write-Host "[OK] LIQUIDITY_TOKEN0_AMOUNT atualizado para $usdcInt ($usdcValue USDC)" -ForegroundColor Green
} else {
    $envContent += "`nLIQUIDITY_TOKEN0_AMOUNT=$usdcInt`n"
    Write-Host "[OK] LIQUIDITY_TOKEN0_AMOUNT adicionado: $usdcInt ($usdcValue USDC)" -ForegroundColor Green
}

# Atualizar ou adicionar LIQUIDITY_TOKEN1_AMOUNT (WETH)
if ($envContent -match "LIQUIDITY_TOKEN1_AMOUNT=") {
    $envContent = $envContent -replace "LIQUIDITY_TOKEN1_AMOUNT=.*", "LIQUIDITY_TOKEN1_AMOUNT=$wethInt"
    Write-Host "[OK] LIQUIDITY_TOKEN1_AMOUNT atualizado para $wethInt ($wethValue WETH)" -ForegroundColor Green
} else {
    $envContent += "LIQUIDITY_TOKEN1_AMOUNT=$wethInt`n"
    Write-Host "[OK] LIQUIDITY_TOKEN1_AMOUNT adicionado: $wethInt ($wethValue WETH)" -ForegroundColor Green
}

# Salvar .env
Set-Content .env -Value $envContent

Write-Host ""
Write-Host "=== Verificando Saldo Antes de Adicionar ===" -ForegroundColor Cyan
Write-Host ""

# Verificar saldo primeiro
& "C:\foundry\bin\forge.exe" script script/CheckBalance.s.sol:CheckBalance --rpc-url sepolia -vv 2>&1 | Out-Null

$balanceOutput = & "C:\foundry\bin\forge.exe" script script/CheckBalance.s.sol:CheckBalance --rpc-url sepolia -vv 2>&1
$usdcBalanceWeiLine = $balanceOutput | Select-String "Balance \(USDC wei\):"

if ($usdcBalanceWeiLine) {
    $usdcBalanceWei = [decimal]($usdcBalanceWeiLine -replace ".*Balance \(USDC wei\): (\d+).*", '$1')
    $usdcBalance = $usdcBalanceWei / 1000000.0  # Converter de wei para USDC (6 decimais)
    Write-Host "Saldo atual de USDC: $usdcBalance USDC ($usdcBalanceWei wei)" -ForegroundColor Yellow
    
    if ($usdcBalance -lt $usdcValue) {
        Write-Host ""
        Write-Host "[ERRO] Saldo insuficiente!" -ForegroundColor Red
        Write-Host "  Você tem: $usdcBalance USDC" -ForegroundColor White
        Write-Host "  Você precisa: $usdcValue USDC" -ForegroundColor White
        Write-Host ""
        Write-Host "Opções:" -ForegroundColor Yellow
        Write-Host "  1. Obtenha mais USDC na testnet Sepolia" -ForegroundColor White
        Write-Host "  2. Use uma quantidade menor (ex: $([math]::Floor($usdcBalance * 0.9)) USDC)" -ForegroundColor White
        Write-Host ""
        Write-Host "Para obter USDC na Sepolia:" -ForegroundColor Cyan
        Write-Host "  - Faucet: https://sepoliafaucet.com/" -ForegroundColor White
        Write-Host "  - Ou faça swap de WETH para USDC na pool" -ForegroundColor White
        exit 1
    }
}

Write-Host ""
Write-Host "=== Executando Script de Adicionar Liquidez ===" -ForegroundColor Cyan
Write-Host ""

# Executar o script de adicionar liquidez
& "C:\foundry\bin\forge.exe" script script/AddLiquidity.s.sol:AddLiquidity --rpc-url sepolia --broadcast --slow -vvvv

if ($LASTEXITCODE -eq 0) {
    Write-Host ""
    Write-Host "=== Liquidez Adicionada com Sucesso! ===" -ForegroundColor Green
    Write-Host "  USDC adicionado: $usdcValue USDC" -ForegroundColor White
    Write-Host "  WETH adicionado: $wethValue WETH" -ForegroundColor White
} else {
    Write-Host ""
    Write-Host "=== Erro ao adicionar liquidez ===" -ForegroundColor Red
    Write-Host "Verifique:" -ForegroundColor Yellow
    Write-Host "  1. Se você tem tokens suficientes na carteira" -ForegroundColor White
    Write-Host "  2. Se os tokens foram aprovados" -ForegroundColor White
    Write-Host "  3. Se a pool existe e está configurada" -ForegroundColor White
    Write-Host "  4. Se você tem ETH suficiente para gas fees" -ForegroundColor White
}

