# Script para configurar .env
# Execute: .\configurar-env.ps1

Write-Host "=== Configuracao do .env ===" -ForegroundColor Cyan
Write-Host ""

if (-not (Test-Path ".env")) {
    if (Test-Path "env.example.txt") {
        Copy-Item "env.example.txt" ".env"
        Write-Host "Arquivo .env criado a partir do template" -ForegroundColor Green
    } else {
        Write-Host "Erro: Template env.example.txt nao encontrado" -ForegroundColor Red
        exit 1
    }
}

Write-Host "Arquivo .env encontrado" -ForegroundColor Green
Write-Host ""

# Ler valores atuais
$envContent = Get-Content ".env"
$currentPrivateKey = ($envContent | Where-Object { $_ -like "PRIVATE_KEY=*" }) -replace "PRIVATE_KEY=", ""
$currentPoolManager = ($envContent | Where-Object { $_ -like "POOL_MANAGER=*" }) -replace "POOL_MANAGER=", ""

Write-Host "Valores atuais:" -ForegroundColor Yellow
if ($currentPrivateKey -and $currentPrivateKey -ne "your_private_key_here") {
    Write-Host "  PRIVATE_KEY: [CONFIGURADO]" -ForegroundColor Green
} else {
    Write-Host "  PRIVATE_KEY: [NAO CONFIGURADO]" -ForegroundColor Red
}

if ($currentPoolManager -and $currentPoolManager -ne "0x...") {
    Write-Host "  POOL_MANAGER: $currentPoolManager" -ForegroundColor Green
} else {
    Write-Host "  POOL_MANAGER: [NAO CONFIGURADO]" -ForegroundColor Red
}

Write-Host ""

# Perguntar se deseja configurar
$configure = Read-Host "Deseja configurar agora? (s/n)"

if ($configure -eq "s") {
    Write-Host ""
    Write-Host "=== Configuracao Interativa ===" -ForegroundColor Cyan
    Write-Host ""
    
    # PRIVATE_KEY
    if ($currentPrivateKey -eq "your_private_key_here" -or -not $currentPrivateKey) {
        Write-Host "PRIVATE_KEY:" -ForegroundColor Yellow
        Write-Host "  Digite sua chave privada (sem 0x)" -ForegroundColor White
        Write-Host "  Ou pressione Enter para pular" -ForegroundColor Gray
        $newPrivateKey = Read-Host "  PRIVATE_KEY"
        
        if ($newPrivateKey) {
            $envContent = $envContent | ForEach-Object {
                if ($_ -like "PRIVATE_KEY=*") {
                    "PRIVATE_KEY=$newPrivateKey"
                } else {
                    $_
                }
            }
            Write-Host "  PRIVATE_KEY configurado" -ForegroundColor Green
        }
    } else {
        Write-Host "PRIVATE_KEY ja esta configurado" -ForegroundColor Green
    }
    
    Write-Host ""
    
    # POOL_MANAGER
    if ($currentPoolManager -eq "0x..." -or -not $currentPoolManager) {
        Write-Host "POOL_MANAGER:" -ForegroundColor Yellow
        Write-Host "  Digite o endereco do PoolManager (Uniswap v4)" -ForegroundColor White
        Write-Host "  Exemplo: 0x1234567890123456789012345678901234567890" -ForegroundColor Gray
        Write-Host "  Ou pressione Enter para pular" -ForegroundColor Gray
        $newPoolManager = Read-Host "  POOL_MANAGER"
        
        if ($newPoolManager) {
            $envContent = $envContent | ForEach-Object {
                if ($_ -like "POOL_MANAGER=*") {
                    "POOL_MANAGER=$newPoolManager"
                } else {
                    $_
                }
            }
            Write-Host "  POOL_MANAGER configurado" -ForegroundColor Green
        }
    } else {
        Write-Host "POOL_MANAGER ja esta configurado: $currentPoolManager" -ForegroundColor Green
    }
    
    # Salvar
    $envContent | Set-Content ".env"
    Write-Host ""
    Write-Host "Arquivo .env atualizado!" -ForegroundColor Green
} else {
    Write-Host ""
    Write-Host "Para configurar manualmente:" -ForegroundColor Yellow
    Write-Host "  notepad .env" -ForegroundColor White
    Write-Host "  ou" -ForegroundColor Gray
    Write-Host "  code .env" -ForegroundColor White
}

Write-Host ""
Write-Host "Guia completo: CONFIGURAR-ENV.md" -ForegroundColor Cyan
Write-Host ""

