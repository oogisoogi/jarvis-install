# Q6LNC844 B 흉내 몰이 — 로그인 대기 중 설치 창에 Ctrl+C (pwsh 7 · 맥 가상 터미널 · 2026-11-09)
#   실물 Step-Login 을 몬다. 로그인 프로세스·확인 명령·질문만 흉내로 갈아 끼운다(벤더 도구·네트워크 0).
#   ⛔바깥에 닿지 않는다 — 진행 전송 끔 · 쓰기는 $Sb 안에서만 · 띄운 sleep 은 이 프로세스가 번호로 거둔다.
param([string]$Src, [string]$Sb)
$ErrorActionPreference = 'Continue'
$jh = "$Sb/home/install-jarvis"
New-Item -ItemType Directory -Force -Path $jh | Out-Null
$env:USERPROFILE = "$Sb/home"
$env:JARVIS_HOME = $jh
$env:JARVIS_NO_PROGRESS = '1'
$env:JARVIS_LIB_ONLY = '1'
. $Src
$env:JARVIS_LIB_ONLY = ''
function Out-Fact($k, $v) { Add-Content -Path "$Sb/facts" -Value ("$k=$v") -Encoding utf8 }
$script:LoggedIn = $false
$Mode = 'full'
$LoginWaitTimeout = 12; $LoginTickMs = 200; $LoginCheckpointSec = 9999; $LoginStatusEverySec = 9999
function Test-ClaudeAuthCmd { return $true }
function Get-LoginStatusText($exe) { return '' }
function Get-LoginClipText { return $null }
function Invoke-LoginFailQuestion { return @{ Answer = 'stub'; Keys = 'stub' } }
function Confirm-LoginAfterExit($exe, $credBefore) { return @{ By = ''; Auth = ''; Fails = 0; Note = 'stub' } }
function Start-LoginPipeProc {
    param([string]$FilePath, [string[]]$ArgumentList)
    $psi = New-Object System.Diagnostics.ProcessStartInfo
    $psi.FileName = '/bin/sleep'; $psi.Arguments = '60'
    $psi.UseShellExecute = $false; $psi.RedirectStandardInput = $true
    $p = [System.Diagnostics.Process]::Start($psi)
    $script:StubPid = $p.Id
    return $p
}
$returned = $false
try {
    Step-Login
    $returned = $true
} finally {
    Out-Fact 'returned' $returned
    Out-Fact 'loginrc' $script:LoginRc
    try { Out-Fact 'treat_after' ([Console]::TreatControlCAsInput) } catch { Out-Fact 'treat_after' 'unreadable' }
    if ($script:StubPid) { try { (Get-Process -Id $script:StubPid -ErrorAction Stop).Kill() } catch { } }
}
