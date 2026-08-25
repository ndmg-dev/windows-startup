<#
    startup.ps1

    Abre, em sequencia, os apps de trabalho ao ligar o PC:
    1. Docker Desktop (primeiro, porque demora a subir)
    2. VSCode
    3. App desktop do Claude
    4. Chrome, uma ou mais janelas, cada uma em um perfil, cada uma com
       uma ou mais URLs abertas como abas
    5. Code Watcher (https://github.com/ndmg-dev/CodeWatcher), se instalado

    CONFIGURACAO:
    Edite as variaveis abaixo antes de usar. Os valores marcados com
    <PREENCHER> sao especificos de cada maquina/usuario e PRECISAM ser
    trocados antes do script funcionar.
#>

# --- CONFIGURACAO -----------------------------------------------------

# Caminho do executavel do Docker Desktop. O instalador mais recente
# instala por usuario, em %LOCALAPPDATA%\Programs\DockerDesktop (nao mais
# em Program Files) — confira onde esta o seu antes de rodar o script.
$dockerPath = "$env:LOCALAPPDATA\Programs\DockerDesktop\Docker Desktop.exe"

# Caminho do executavel do VSCode (padrao de instalacao por usuario):
$vscodePath = "$env:LOCALAPPDATA\Programs\Microsoft VS Code\Code.exe"

# O Claude desktop foi instalado via WindowsApps (MSIX), cujo caminho
# muda a cada atualizacao do app (contem um hash de versao). Por isso,
# em vez de um caminho fixo, ele e aberto via protocolo do Explorer,
# que sempre resolve a versao instalada no momento.
# Descubra o valor certo abrindo o PowerShell e rodando:
#   Get-StartApps | Where-Object {$_.Name -like "*Claude*"}
$claudeAppId = "<PREENCHER: AppUserModelId do Claude desktop>"

# Caminho do executavel do Chrome:
$chromePath = "C:\Program Files\Google\Chrome\Application\chrome.exe"

# Janelas do Chrome a abrir no boot. Cada item vira uma janela separada,
# no perfil indicado, com todas as URLs listadas abertas como abas dessa
# mesma janela (o Chrome aceita multiplas URLs na mesma chamada).
#
# Nome da pasta de perfil (Profile): descubra abrindo chrome://version no
# perfil desejado, campo "Caminho do perfil" — o nome da ultima pasta
# (ex.: "Profile 3", "Default"). Tambem da para conferir em
# %LOCALAPPDATA%\Google\Chrome\User Data\Local State (JSON), campo
# profile.info_cache, que mapeia cada "Profile N" para o email da conta.
$chromeWindows = @(
    @{
        Profile = "<PREENCHER: nome da pasta de perfil do Chrome, ex. Profile 3>"
        Urls    = @(
            "<PREENCHER: URL a abrir no boot, ex. o CRM interno da sua empresa>"
        )
    }
    # Exemplo de uma segunda janela, em outro perfil, com varias abas:
    # @{
    #     Profile = "<PREENCHER: nome da pasta de perfil do Chrome, ex. Profile 2>"
    #     Urls    = @(
    #         "<PREENCHER: URL 1>"
    #         "<PREENCHER: URL 2>"
    #     )
    # }
)

# Segundos de espera apos abrir o Docker, antes de seguir com o resto
# (Docker demora para inicializar o daemon):
$dockerWaitSeconds = 25

# Segundos de espera antes de abrir o Code Watcher, DEPOIS que Docker, VSCode,
# Claude e Chrome ja foram disparados. Docker + VSCode + Chrome + Claude +
# a janela WebView2 do watcher, todos competindo por GPU no mesmo instante do
# boot, ja causaram um travamento real (AppHang do pythonw.exe, coincidindo
# com resets do driver de video). Esperar aqui evita empilhar a criacao da
# janela do watcher em cima da carga de abertura dos outros apps.
$watcherWaitSeconds = 15

# Code Watcher: app de bandeja que roda o watcher em background e mostra o
# painel de revisoes (https://github.com/ndmg-dev/CodeWatcher).
#
# Roda via pythonw (nao o .exe empacotado): Smart App Control do Windows
# tende a bloquear um .exe recem-compilado ate a checagem de reputacao da
# Microsoft na nuvem aprovar (pode nao acontecer rapido, ou nunca sozinho).
# pythonw.exe e assinado pela Python Software Foundation, entao nunca
# esbarra nisso. Se preferir usar o .exe empacotado (build_exe.ps1 no
# repositorio do CodeWatcher), troque as duas linhas comentadas abaixo.
$pythonwPath   = "<PREENCHER: caminho do pythonw.exe>"
$watcherScript = "<PREENCHER: caminho do watcher_gui.py>"
# $watcherExe = "<PREENCHER: caminho do CodeWatcher.exe empacotado>"

# --- EXECUCAO -----------------------------------------------------------

# Retorna $true se o app ja estiver rodando. -ProcessName casa pelo nome do
# executavel; -CommandLineMatch e para casos como o pythonw, onde varios
# processos compartilham o mesmo nome e so a linha de comando os distingue.
function Test-AppRunning {
    param(
        [string]$ProcessName,
        [string]$CommandLineMatch = ""
    )
    if ($CommandLineMatch -ne "") {
        $found = Get-CimInstance Win32_Process -Filter "Name='$ProcessName'" -ErrorAction SilentlyContinue |
                 Where-Object { $_.CommandLine -like "*$CommandLineMatch*" }
        return [bool]$found
    }
    return [bool](Get-Process -Name $ProcessName -ErrorAction SilentlyContinue)
}

function Start-AppIfExists {
    param(
        [string]$Path,
        [string]$Arguments = "",
        [string]$Label,
        [string]$ProcessName = "",       # se ja estiver rodando, nao abre de novo
        [string]$CommandLineMatch = ""
    )
    if ($ProcessName -ne "" -and (Test-AppRunning -ProcessName $ProcessName -CommandLineMatch $CommandLineMatch)) {
        Write-Host "$Label ja esta rodando, pulando."
        return $false
    }
    if (Test-Path $Path) {
        Write-Host "Abrindo $Label..."
        if ($Arguments -ne "") {
            Start-Process -FilePath $Path -ArgumentList $Arguments
        } else {
            Start-Process -FilePath $Path
        }
        return $true
    }
    Write-Warning "$Label nao encontrado em: $Path (verifique o caminho no script)"
    return $false
}

Write-Host "=== Iniciando rotina de abertura de apps de trabalho ==="

# 1. Docker Desktop primeiro (mais demorado)
# O instalador do Docker tambem se registra sozinho no Run do registro, entao
# ele pode ja ter subido antes deste script rodar. So esperamos os 25s se
# fomos nos que o abrimos agora.
$dockerIniciado = Start-AppIfExists -Path $dockerPath -Label "Docker Desktop" -ProcessName "Docker Desktop"
if ($dockerIniciado) {
    Write-Host "Aguardando $dockerWaitSeconds segundos para o Docker inicializar..."
    Start-Sleep -Seconds $dockerWaitSeconds
}

# 2. VSCode
Start-AppIfExists -Path $vscodePath -Label "VSCode" -ProcessName "Code" | Out-Null

# 3. Claude desktop app (via AppsFolder, por ser instalacao MSIX)
Write-Host "Abrindo Claude (app desktop)..."
try {
    Start-Process "shell:AppsFolder\$claudeAppId"
} catch {
    Write-Warning "Nao foi possivel abrir o Claude via AppsFolder. Verifique `$claudeAppId no script."
}

# 4. Chrome, uma janela por perfil configurado em $chromeWindows, cada uma
# com suas URLs abertas como abas.
# De proposito SEM checagem de "ja rodando": se o Chrome ja estiver aberto,
# isso apenas abre as abas na janela existente do perfil (ou uma nova janela
# do perfil, se ainda nao tinha uma aberta) — nao abre um segundo processo
# do Chrome indevidamente.
foreach ($window in $chromeWindows) {
    $urlArgs = ($window.Urls | ForEach-Object { "`"$_`"" }) -join " "
    $chromeArgs = "--profile-directory=`"$($window.Profile)`" $urlArgs"
    Start-AppIfExists -Path $chromePath -Arguments $chromeArgs -Label "Chrome (perfil: $($window.Profile))" | Out-Null
}

# 5. Code Watcher — sobe na bandeja E abre o painel junto com os outros apps.
# A flag --show e o que faz a janela aparecer no boot; sem ela o app fica so
# na bandeja, e o painel abre pelo menu do icone (botao direito > Abrir painel).
# A checagem de "ja rodando" aqui e a mais importante do script: duas
# instancias do watcher revisariam o mesmo arquivo duas vezes, dobrando as
# chamadas ao Claude Code CLI.
if (Test-AppRunning -ProcessName "pythonw.exe" -CommandLineMatch "watcher_gui.py") {
    Write-Host "Code Watcher (bandeja + painel) ja esta rodando, pulando."
} else {
    Write-Host "Aguardando $watcherWaitSeconds segundos antes de abrir o Code Watcher..."
    Start-Sleep -Seconds $watcherWaitSeconds
    Start-AppIfExists -Path $pythonwPath -Arguments "`"$watcherScript`" --show" `
                      -Label "Code Watcher (bandeja + painel)" `
                      -ProcessName "pythonw.exe" -CommandLineMatch "watcher_gui.py" | Out-Null
}

Write-Host "=== Rotina concluida ==="
