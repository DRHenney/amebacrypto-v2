# Script para verificar se a pool foi criada na blockchain
# Execute: .\verificar-pool-blockchain.ps1

Write-Host "=== Verificando Pool na Blockchain ===" -ForegroundColor Cyan
Write-Host ""

$poolManager = "0x76E9E1AFFDe82bb4544cE95EA58fFc2f9D45061f"
$hook = "0x6A087B9340925E1c66273FAE8F7527c8754F1540"
$poolId = "96581450869586643332131644812111398789711740483350970162926025488554309685359"
$usdc = "0x1c7D4B196Cb0C7B01d743Fbc6116a902379C7238"
$weth = "0xfFf9976782d46CC05630D1f6eBAb18b2324d6B14"

# Carregar .env
if (Test-Path ".env") {
    Get-Content .env | ForEach-Object {
        if ($_ -match '^\s*([^#][^=]*)\s*=\s*(.*)$') {
            $name = $matches[1].Trim()
            $value = $matches[2].Trim()
            Set-Variable -Name $name -Value $value -Scope Script
        }
    }
}

$rpcUrl = if ($SEPOLIA_RPC_URL) { $SEPOLIA_RPC_URL } else { "https://sepolia.infura.io/v3/YOUR_KEY" }

Write-Host "Pool ID: $poolId" -ForegroundColor Yellow
Write-Host ""

# Verificar se PoolManager tem código
Write-Host "1. Verificando PoolManager..." -ForegroundColor Cyan
try {
    $code = & "C:\foundry\bin\cast.exe" code $poolManager --rpc-url sepolia 2>&1
    if ($code -match "0x") {
        $codeLength = ($code -replace "0x", "").Length
        if ($codeLength -gt 2) {
            Write-Host "   [OK] PoolManager tem codigo ($codeLength caracteres)" -ForegroundColor Green
        } else {
            Write-Host "   [ERRO] PoolManager nao tem codigo" -ForegroundColor Red
        }
    }
} catch {
    Write-Host "   [AVISO] Nao foi possivel verificar codigo" -ForegroundColor Yellow
}

Write-Host ""

# Verificar se Hook tem código
Write-Host "2. Verificando Hook..." -ForegroundColor Cyan
try {
    $code = & "C:\foundry\bin\cast.exe" code $hook --rpc-url sepolia 2>&1
    if ($code -match "0x") {
        $codeLength = ($code -replace "0x", "").Length
        if ($codeLength -gt 2) {
            Write-Host "   [OK] Hook tem codigo ($codeLength caracteres)" -ForegroundColor Green
        } else {
            Write-Host "   [ERRO] Hook nao tem codigo" -ForegroundColor Red
        }
    }
} catch {
    Write-Host "   [AVISO] Nao foi possivel verificar codigo" -ForegroundColor Yellow
}

Write-Host ""

# Tentar verificar slot0 da pool (se sqrtPriceX96 != 0, pool existe)
Write-Host "3. Verificando se pool foi inicializada..." -ForegroundColor Cyan
Write-Host "   (Verificando slot0 do PoolManager para este poolId)" -ForegroundColor Gray

# O slot0 está em uma posição específica do storage do PoolManager
# Para Uniswap v4, precisamos calcular o slot baseado no poolId
# Slot = keccak256(abi.encode(poolId, slot_number))
# Slot 0 do pool = keccak256(abi.encode(poolId, 0))

try {
    # Tentar chamar uma função view do PoolManager se disponível
    # Como não temos uma função direta, vamos verificar eventos/transações
    
    Write-Host "   Verificando ultimas transacoes do PoolManager..." -ForegroundColor Gray
    
    # Usar cast para verificar logs de Initialize
    $logs = & "C:\foundry\bin\cast.exe" logs --from-block latest --to-block latest --address $poolManager --rpc-url sepolia 2>&1 | Select-Object -First 20
    
    if ($logs -match "Initialize") {
        Write-Host "   [OK] Encontrados eventos Initialize recentes" -ForegroundColor Green
        Write-Host "   Verifique os detalhes no Etherscan" -ForegroundColor Gray
    } else {
        Write-Host "   [AVISO] Nenhum evento Initialize encontrado recentemente" -ForegroundColor Yellow
    }
} catch {
    Write-Host "   [AVISO] Nao foi possivel verificar via cast logs" -ForegroundColor Yellow
}

Write-Host ""

# Verificar eventos do Hook
Write-Host "4. Verificando configuracao do Hook..." -ForegroundColor Cyan
try {
    $logs = & "C:\foundry\bin\cast.exe" logs --from-block latest --to-block latest --address $hook --rpc-url sepolia 2>&1 | Select-Object -First 20
    
    if ($logs -match "PoolConfigUpdated|TokenPricesUpdated|PoolTickRangeUpdated") {
        Write-Host "   [OK] Encontrados eventos de configuracao recentes" -ForegroundColor Green
    } else {
        Write-Host "   [AVISO] Nenhum evento de configuracao encontrado recentemente" -ForegroundColor Yellow
    }
} catch {
    Write-Host "   [AVISO] Nao foi possivel verificar eventos do hook" -ForegroundColor Yellow
}

Write-Host ""
Write-Host "=== Links Etherscan (Verificacao Manual) ===" -ForegroundColor Cyan
Write-Host ""
Write-Host "PoolManager (ver transacoes de initialize):" -ForegroundColor Yellow
Write-Host "  https://sepolia.etherscan.io/address/$poolManager#events" -ForegroundColor Cyan
Write-Host ""
Write-Host "Hook (ver eventos de configuracao):" -ForegroundColor Yellow
Write-Host "  https://sepolia.etherscan.io/address/$hook#events" -ForegroundColor Cyan
Write-Host ""
Write-Host "=== Como Verificar ===" -ForegroundColor Cyan
Write-Host ""
Write-Host "1. Acesse o PoolManager no Etherscan" -ForegroundColor White
Write-Host "2. Vá para a aba 'Events'" -ForegroundColor White
Write-Host "3. Procure por eventos 'Initialize' recentes" -ForegroundColor White
Write-Host "4. Verifique se algum evento tem:" -ForegroundColor White
Write-Host "   - currency0: $usdc" -ForegroundColor Gray
Write-Host "   - currency1: $weth" -ForegroundColor Gray
Write-Host "   - hooks: $hook" -ForegroundColor Gray
Write-Host ""
Write-Host "Se encontrar, a pool foi criada!" -ForegroundColor Green
Write-Host ""

