# [2/10] 상한 → 진단 → 직접 받기 흉내 (pwsh 7 · 맥) — 실물 bootstrap.ps1 을 함수 묶음으로 읽고 네트워크·공식 설치기만 가짜로 둔다
param([string]$Src, [string]$Sb, [string]$Scenario)
$ErrorActionPreference = 'Continue'
New-Item -ItemType Directory -Force -Path "$Sb/home/install-jarvis", "$Sb/bin" | Out-Null
Set-Content -Path "$Sb/scenario" -Value $Scenario -NoNewline
# 가짜 공식 설치기 자리(pwsh 이름) — 자식 sleep 을 두고 영원히 안 끝난다
Set-Content -Path "$Sb/bin/pwsh" -Value "#!/bin/bash`n/bin/sleep 3011 &`nwait`n" -NoNewline
& chmod +x "$Sb/bin/pwsh"
# 받을 파일(가짜 claude.exe) — install stable 는 시나리오에 따라 멈추거나 제자리에 둔다
$fake = @'
#!/bin/bash
SB="__SB__"
case "$1 $2" in
  "--version "*) echo "9.9.9 (Claude Code)"; exit 0 ;;
  "--help "*) echo "Commands:"; echo "  auth    Manage authentication"; exit 0 ;;
  "install stable")
     if [ "$(cat "$SB/scenario")" = step5ok ]; then mkdir -p "$SB/home/.local/bin"; cp "$0" "$SB/home/.local/bin/claude.exe"; chmod +x "$SB/home/.local/bin/claude.exe"; exit 0; fi
     /bin/sleep 3022 & wait ;;
  "auth status") echo '{"loggedIn": true}'; exit 0 ;;
esac
exit 0
'@
$fake = $fake.Replace('__SB__', $Sb)
$script:FakeBytes = [System.Text.Encoding]::UTF8.GetBytes($fake)
$sha = [System.Security.Cryptography.SHA256]::Create()
$script:FakeSum = ([System.BitConverter]::ToString($sha.ComputeHash($script:FakeBytes)) -replace '-', '').ToLower()
if ($Scenario -eq 'mismatch') { $script:FakeSum = ('0' * 64) }
if ($Scenario -eq 'mismatch') {
    Set-Content -Path "$Sb/home/install-jarvis/help-attempts.json" -NoNewline -Value ("{`"v`":1,`n`"codes`":{`n`"J-AV-01`":{`"count`":1,`"first`":`"2026-09-14T15:54:27+0900`",`"last`":`"2026-09-14T15:54:27+0900`",`"step`":`"2`"}`n}`n}`n")
}
$env:PATH = "$Sb/bin:" + $env:PATH
$env:USERPROFILE = "$Sb/home"
$env:JARVIS_HOME = "$Sb/home/install-jarvis"
$env:JARVIS_LIB_ONLY = '1'
. $Src
$env:JARVIS_LIB_ONLY = ''
# 시간만 줄인다
$ClaudeInstallWaitMs = 4000; $ClaudeInstallRetryWaitMs = 3000; $InstallNoteEverySec = 2
$ClaudeDirectInstallWaitMs = 3000; $ClaudeVersionWaitMs = 5000
# 네트워크 가짜 — 부른 주소를 적는다
function Invoke-RestMethod {
    [CmdletBinding()] param($Uri, [switch]$UseBasicParsing, $TimeoutSec)
    Add-Content -Path "$Sb/net.log" -Value ("IRM " + $Uri)
    if ($Uri -like '*/stable') { return "9.9.9`n" }
    if ($Uri -like '*/manifest.json') { return [pscustomobject]@{ platforms = [pscustomobject]@{ 'win32-x64' = [pscustomobject]@{ checksum = $script:FakeSum; size = 227051168 } } } }
    throw ("unexpected " + $Uri)
}
function Invoke-WebRequest {
    [CmdletBinding()] param($Uri, $OutFile, [switch]$UseBasicParsing, $TimeoutSec)
    Add-Content -Path "$Sb/net.log" -Value ("IWR " + $Uri + " -> " + $OutFile)
    [System.IO.File]::WriteAllBytes($OutFile, $script:FakeBytes)
    & chmod +x $OutFile
}
# 사용자 PATH 등록은 윈도우 전용 축(맥 .NET 은 User/Machine 대상을 무시) — 흉내에서는 제자리 파일을 claude 이름으로 잇는다
function Seed-LocalBinPath {
    $p = $ExecutionContext.SessionState.Path.GetUnresolvedProviderPathFromPSPath((Join-Path (Join-Path $env:USERPROFILE '.local\bin') 'claude.exe'))
    Set-Alias -Name claude -Value $p -Scope Global
    Write-Log ('EMU seed-path alias claude -> ' + $p)
    return $true
}
if ($Scenario -eq 'av') {
    function Get-AvWindowTitles { return @('AhnLab V3 프로그램 실행 알림 (V3UI)') }
}
try {
    $rc = @(Step-InstallClaude)[-1]
    Write-Log ("TEST install rc=" + $rc + " JCode=" + $script:JCode)
    if ($rc -eq 0) { Step-Login; $rc2 = $script:LoginRc; Write-Log ("TEST login rc=" + $rc2) }
} finally { Write-Log 'TEST finally' }
