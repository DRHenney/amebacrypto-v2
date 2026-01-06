# Script de Setup e Deploy - AmebaCrypto v2
# Execute: .\setup-deploy.ps1

Write-Host "=== AmebaCrypto v2 - Setup e Deploy ===" -ForegroundColor Cyan
Write-Host ""

# Verificar Foundry
Write-Host "[1/6] Verificando Foundry..." -ForegroundColor Yellow
if (Get-Command forge -ErrorAction SilentlyContinue) {
    $forgeVersion = forge --version
    Write-Host "✓ Foundry encontrado: $forgeVersion" -ForegroundColor Green
} else {
    Write-Host "✗ Foundry não encontrado" -ForegroundColor Red
    Write-Host ""
    Write-Host "Para instalar Foundry:" -ForegroundColor Yellow
    Write-Host "1. Acesse: https://book.getfoundry.sh/getting-started/installation" -ForegroundColor White
    Write-Host "2. Siga as instruções para Windows" -ForegroundColor White
    Write-Host "3. Ou execute: curl -L https://foundry.paradigm.xyz | bash" -ForegroundColor White
    Write-Host ""
    $continue = Read-Host "Deseja continuar mesmo sem Foundry? (s/n)"
    if ($continue -ne "s") {
        exit
    }
}

# Verificar .env
Write-Host "[2/6] Verificando arquivo .env..." -ForegroundColor Yellow
if (Test-Path ".env") {
    Write-Host "✓ Arquivo .env encontrado" -ForegroundColor Green
} else {
    Write-Host "✗ Arquivo .env não encontrado" -ForegroundColor Red
    if (Test-Path "env.example.txt") {
        Copy-Item "env.example.txt" ".env"
        Write-Host "✓ Arquivo .env criado a partir de env.example.txt" -ForegroundColor Green
        Write-Host "⚠ IMPORTANTE: Edite o arquivo .env com suas credenciais!" -ForegroundColor Yellow
    } else {
        Write-Host "✗ Arquivo env.example.txt não encontrado" -ForegroundColor Red
    }
}

# Verificar dependências
Write-Host "[3/6] Verificando dependências..." -ForegroundColor Yellow
if (Test-Path "lib") {
    Write-Host "✓ Diretório lib/ encontrado" -ForegroundColor Green
} else {
    Write-Host "✗ Diretório lib/ não encontrado" -ForegroundColor Red
    Write-Host "Execute: forge install" -ForegroundColor Yellow
}

# Compilar
Write-Host "[4/6] Compilando projeto..." -ForegroundColor Yellow
if (Get-Command forge -ErrorAction SilentlyContinue) {
    $compileResult = forge build --via-ir 2>&1
    if ($LASTEXITCODE -eq 0) {
        Write-Host "✓ Compilação bem-sucedida" -ForegroundColor Green
    } else {
        Write-Host "✗ Erro na compilação" -ForegroundColor Red
        Write-Host "Execute manualmente: forge build --via-ir" -ForegroundColor Yellow
    }
} else {
    Write-Host "⚠ Pulando compilação (Foundry não encontrado)" -ForegroundColor Yellow
}

# Resumo
Write-Host ""
Write-Host "[5/6] Resumo da configuração:" -ForegroundColor Yellow
Write-Host ""

if (Test-Path ".env") {
    Write-Host "✓ Arquivo .env configurado" -ForegroundColor Green
} else {
    Write-Host "✗ Arquivo .env não configurado" -ForegroundColor Red
}

if (Get-Command forge -ErrorAction SilentlyContinue) {
    Write-Host "✓ Foundry instalado" -ForegroundColor Green
} else {
    Write-Host "✗ Foundry não instalado" -ForegroundColor Red
}

if (Test-Path "lib") {
    Write-Host "✓ Dependências instaladas" -ForegroundColor Green
} else {
    Write-Host "✗ Dependências não instaladas" -ForegroundColor Red
}

# Próximos passos
Write-Host ""
Write-Host "[6/6] Próximos passos:" -ForegroundColor Yellow
Write-Host ""
Write-Host "1. Configure o arquivo .env com:" -ForegroundColor White
Write-Host "   - PRIVATE_KEY (sua chave privada)" -ForegroundColor Gray
Write-Host "   - POOL_MANAGER (endereço do PoolManager)" -ForegroundColor Gray
Write-Host ""
Write-Host "2. Para fazer deploy em Sepolia:" -ForegroundColor White
Write-Host "   forge script script/DeployAutoCompoundHookV2.s.sol:DeployAutoCompoundHookV2 --rpc-url sepolia --broadcast --verify -vvvv" -ForegroundColor Gray
Write-Host ""
Write-Host "3. Para simular deploy (sem enviar):" -ForegroundColor White
Write-Host "   forge script script/DeployAutoCompoundHookV2.s.sol:DeployAutoCompoundHookV2 --rpc-url sepolia -vvvv" -ForegroundColor Gray
Write-Host ""
Write-Host "Documentação completa:" -ForegroundColor Cyan
Write-Host "   - SETUP-E-DEPLOY.md" -ForegroundColor White
Write-Host "   - GUIA-DEPLOY-V2.md" -ForegroundColor White
Write-Host "   - DEPLOY-RESUMO.md" -ForegroundColor White
Write-Host ""

