# Script para instalar Foundry no Windows
# Execute como Administrador: .\instalar-foundry.ps1

Write-Host "=== Instalacao do Foundry ===" -ForegroundColor Cyan
Write-Host ""

$installPath = "C:\foundry\bin"
$sourcePath = "foundry_extracted"

# Verificar se os arquivos foram extraidos
if (-not (Test-Path $sourcePath)) {
    Write-Host "Erro: Diretorio $sourcePath nao encontrado" -ForegroundColor Red
    Write-Host "Execute primeiro: .\baixar-foundry.ps1" -ForegroundColor Yellow
    exit 1
}

# Criar diretorio de instalacao
Write-Host "Criando diretorio de instalacao: $installPath" -ForegroundColor Yellow
New-Item -ItemType Directory -Path $installPath -Force | Out-Null

# Copiar executaveis
Write-Host "Copiando executaveis..." -ForegroundColor Yellow
$exeFiles = Get-ChildItem $sourcePath -Recurse -Filter "*.exe"
foreach ($file in $exeFiles) {
    Copy-Item $file.FullName -Destination $installPath -Force
    Write-Host "  Copiado: $($file.Name)" -ForegroundColor Gray
}

Write-Host ""
Write-Host "Executaveis instalados em: $installPath" -ForegroundColor Green
Write-Host ""

# Adicionar ao PATH
Write-Host "Adicionando ao PATH do sistema..." -ForegroundColor Yellow

$currentPath = [Environment]::GetEnvironmentVariable("Path", "User")
if ($currentPath -notlike "*$installPath*") {
    [Environment]::SetEnvironmentVariable("Path", "$currentPath;$installPath", "User")
    Write-Host "  PATH atualizado para o usuario atual" -ForegroundColor Green
} else {
    Write-Host "  PATH ja contem $installPath" -ForegroundColor Yellow
}

# Verificar instalacao
Write-Host ""
Write-Host "Verificando instalacao..." -ForegroundColor Yellow

$forgePath = Join-Path $installPath "forge.exe"
if (Test-Path $forgePath) {
    Write-Host "  Forge encontrado: $forgePath" -ForegroundColor Green
} else {
    Write-Host "  Erro: Forge nao encontrado" -ForegroundColor Red
}

Write-Host ""
Write-Host "=== Instalacao Concluida ===" -ForegroundColor Green
Write-Host ""
Write-Host "IMPORTANTE:" -ForegroundColor Yellow
Write-Host "1. Feche e reabra o terminal" -ForegroundColor White
Write-Host "2. Teste: forge --version" -ForegroundColor White
Write-Host "3. Se nao funcionar, adicione manualmente ao PATH:" -ForegroundColor White
Write-Host "   $installPath" -ForegroundColor Gray
Write-Host ""
