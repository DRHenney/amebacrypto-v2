# 🔧 Como Instalar Foundry no Windows

## Método 1: Usando Git Bash (Recomendado)

### Passo 1: Instalar Git for Windows
1. Baixe: https://git-scm.com/download/win
2. Instale (inclui Git Bash)

### Passo 2: Instalar Foundry
1. Abra **Git Bash** (não PowerShell)
2. Execute:
```bash
curl -L https://foundry.paradigm.xyz | bash
```

### Passo 3: Atualizar PATH
1. Adicione ao PATH do Windows:
   - `C:\Users\SEU_USUARIO\.foundry\bin`
2. Ou reinicie o terminal

### Passo 4: Verificar
```bash
forge --version
cast --version
```

## Método 2: Download Manual do GitHub

### Passo 1: Baixar
1. Acesse: https://github.com/foundry-rs/foundry/releases
2. Baixe: `foundry_nightly_windows_amd64.tar.gz` (ou versão mais recente)

### Passo 2: Extrair
1. Extraia o arquivo `.tar.gz` usando 7-Zip ou WinRAR
2. Você terá os executáveis: `forge.exe`, `cast.exe`, `anvil.exe`, `chisel.exe`

### Passo 3: Adicionar ao PATH
1. Copie os executáveis para uma pasta (ex: `C:\foundry\bin`)
2. Adicione essa pasta ao PATH do Windows:
   - Painel de Controle → Sistema → Variáveis de Ambiente
   - Edite "Path" → Adicione `C:\foundry\bin`

### Passo 4: Verificar
```powershell
forge --version
cast --version
```

## Método 3: Usando WSL (Windows Subsystem for Linux)

### Passo 1: Instalar WSL
```powershell
wsl --install
```

### Passo 2: Instalar Foundry no WSL
```bash
curl -L https://foundry.paradigm.xyz | bash
foundryup
```

### Passo 3: Usar
```bash
wsl
forge --version
```

## Método 4: Usando Chocolatey (se tiver instalado)

```powershell
choco install foundry
```

## Verificação

Após instalar, verifique:

```bash
forge --version
cast --version
anvil --version
chisel --version
```

Todos devem retornar números de versão.

## Troubleshooting

### "forge: command not found"
- Verifique se o PATH está configurado corretamente
- Reinicie o terminal após adicionar ao PATH
- Verifique se os executáveis estão na pasta correta

### Erro ao baixar
- Verifique sua conexão com a internet
- Tente usar um VPN se houver bloqueios
- Use o método manual (Método 2)

### Erro no Git Bash
- Certifique-se de estar usando Git Bash, não PowerShell
- Verifique se o curl está disponível: `curl --version`

## Links Úteis

- **Foundry Releases**: https://github.com/foundry-rs/foundry/releases
- **Documentação Oficial**: https://book.getfoundry.sh/getting-started/installation
- **Git for Windows**: https://git-scm.com/download/win

## Próximos Passos

Após instalar o Foundry:

1. ✅ Verificar instalação: `forge --version`
2. ⏳ Configurar `.env` (veja `SETUP-E-DEPLOY.md`)
3. ⏳ Instalar dependências: `forge install`
4. ⏳ Compilar: `forge build --via-ir`
5. ⏳ Deploy: `forge script script/DeployAutoCompoundHookV2.s.sol:DeployAutoCompoundHookV2 --rpc-url sepolia --broadcast -vvvv`

---

**Recomendação**: Use o **Método 1** (Git Bash) - é o mais simples e mantém o Foundry atualizado automaticamente.

