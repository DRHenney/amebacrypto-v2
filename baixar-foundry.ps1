# Script para baixar Foundry manualmente
# Execute: .\baixar-foundry.ps1

Write-Host "=== Download do Foundry ===" -ForegroundColor Cyan
Write-Host ""

# URL do GitHub Releases
$releasesUrl = "https://github.com/foundry-rs/foundry/releases"
$latestUrl = "https://api.github.com/repos/foundry-rs/foundry/releases/latest"

Write-Host "Verificando ultima versao..." -ForegroundColor Yellow

try {
    $response = Invoke-RestMethod -Uri $latestUrl
    $version = $response.tag_name
    Write-Host "Ultima versao encontrada: $version" -ForegroundColor Green
    Write-Host ""
    
    # Procurar asset para Windows
    $windowsAsset = $response.assets | Where-Object { $_.name -like "*windows*" -or $_.name -like "*amd64*" }
    
    if ($windowsAsset) {
        $downloadUrl = $windowsAsset.browser_download_url
        $fileName = $windowsAsset.name
        
        Write-Host "Arquivo encontrado: $fileName" -ForegroundColor Green
        Write-Host "URL: $downloadUrl" -ForegroundColor Gray
        Write-Host ""
        
        $download = Read-Host "Deseja baixar agora? (s/n)"
        
        if ($download -eq "s") {
            Write-Host "Baixando..." -ForegroundColor Yellow
            Invoke-WebRequest -Uri $downloadUrl -OutFile $fileName
            Write-Host "Download concluido: $fileName" -ForegroundColor Green
            Write-Host ""
            Write-Host "Proximos passos:" -ForegroundColor Yellow
            Write-Host "1. Extraia o arquivo $fileName" -ForegroundColor White
            Write-Host "2. Copie os executaveis (forge.exe, cast.exe, etc.) para uma pasta" -ForegroundColor White
            Write-Host "3. Adicione essa pasta ao PATH do Windows" -ForegroundColor White
            Write-Host "4. Reinicie o terminal e teste: forge --version" -ForegroundColor White
        } else {
            Write-Host "Download cancelado." -ForegroundColor Yellow
            Write-Host ""
            Write-Host "Voce pode baixar manualmente de:" -ForegroundColor Yellow
            Write-Host $releasesUrl -ForegroundColor Cyan
        }
    } else {
        Write-Host "Nao foi possivel encontrar arquivo para Windows automaticamente" -ForegroundColor Yellow
        Write-Host ""
        Write-Host "Acesse manualmente:" -ForegroundColor Yellow
        Write-Host $releasesUrl -ForegroundColor Cyan
        Write-Host ""
        Write-Host "Procure por: foundry_nightly_windows_amd64.tar.gz" -ForegroundColor White
    }
} catch {
    Write-Host "Erro ao verificar releases: $_" -ForegroundColor Red
    Write-Host ""
    Write-Host "Acesse manualmente:" -ForegroundColor Yellow
    Write-Host $releasesUrl -ForegroundColor Cyan
    Write-Host ""
    Write-Host "Ou use o metodo Git Bash:" -ForegroundColor Yellow
    Write-Host "curl -L https://foundry.paradigm.xyz | bash" -ForegroundColor White
}

Write-Host ""
Write-Host "Para mais opcoes, veja: INSTALAR-FOUNDRY.md" -ForegroundColor Cyan
