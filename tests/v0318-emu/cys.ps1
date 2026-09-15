# v0.3.18 흉내 (pwsh 7 · 맥) — 실물 bootstrap.ps1 을 「함수 묶음」으로 읽고 ①② 판본 · ④ 기록 글자표 · ⑤ 끝맺음 · ⑥ cys PATH 갈래를 실제로 부른다
#   ①② 가짜 = 설치 여부·판본(Test-CysBody) · 받기(Invoke-WebRequest) · 설치기(Start-Process) · 기다리기(Start-Sleep) — 판정 함수(Get-CysInstalledVersion · Step-*)는 실물
#   ④ 윈도우 PowerShell 5.1 의 「UTF-8 아닌 기본 글자표」를 $PSDefaultParameterValues 로 흉내 낸다(맥 pwsh 7 의 기본은 UTF-8 이라 그대로는 결함이 안 보인다)
#   ⑥ 사용자 PATH 읽기·쓰기 두 함수만 바꿔 끼운다(맥 .NET 에는 사용자 환경변수 자리가 없다)
param([string]$Src, [string]$Scenario, [string]$Sb)
$ErrorActionPreference = 'Continue'
New-Item -ItemType Directory -Force -Path "$Sb/home/install-jarvis" | Out-Null
$env:USERPROFILE = "$Sb/home"
# 윈도우에는 늘 있는 자리 — 맥에서 비면 [6/10] 의 설치기 기록 경로(Join-Path)가 멈춤 오류를 내 try 를 끊는다(2026-09-15 흉내 첫 실행 실측)
$env:LOCALAPPDATA = "$Sb/home/AppData/Local"
$env:JARVIS_HOME = "$Sb/home/install-jarvis"
$env:JARVIS_LIB_ONLY = '1'
$env:JARVIS_NO_PROGRESS = '1'
# ④ 지난 실행 꼬리는 스크립트를 읽는 순간(맨 위) 읽힌다 — 기본 글자표 흉내를 읽기 전에 건다
if ($Scenario -eq 'prev-read') { $PSDefaultParameterValues['Get-Content:Encoding'] = 'latin1' }
. $Src
$env:JARVIS_LIB_ONLY = ''

if ($Scenario -eq 'prev-read') {
    try { Write-Log ('TEST prev=' + $script:PrevRunState) } finally { Write-Log 'TEST finally' }
    return
}

if ($Scenario -eq 'log-utf8') {
    $PSDefaultParameterValues['Add-Content:Encoding'] = 'latin1'
    try { Write-Log 'EMU-UTF8 → 한글' } finally { Write-Log 'TEST finally' }
    return
}

if ($Scenario -like 'closing-*') {
    # ⑤ v0.3.17 글자 필터가 놓친 네 형태 — 전부 「조용히 넘긴 확인」이다(오류 5건: 여러 줄 명령은 경로 둘이라 2건)
    $Error.Clear()
    [void](Get-Command emu-nope-v0318a -EA 0)
    [void](Get-Command emu-nope-v0318b -ErrorAction:SilentlyContinue)
    $x = Get-ChildItem '/emu-nope-v0318c',
        '/emu-nope-v0318d' -ErrorAction SilentlyContinue |
        Select-Object -First 1
    try { $v = (& emu-nope-v0318e --version 2>$null | Select-Object -First 1) } catch { }
    # 바깥 명령에서 막은 경우(교차 검토 1R F4) — 오류 자리는 안쪽 Get-Item 이고 막는 것은 바깥 & { } 2>$null 이다
    & { Get-Item -LiteralPath '/emu-nope-v0318f' } 2>$null
    # 한 줄에 조용한 확인과 조용하지 않은 오류가 함께 있는 경우(교차 검토 1R F3) — 뒤 오류는 참고로 적혀야 한다
    if ($Scenario -eq 'closing-forms-loud') { [void](Get-Command emu-nope-v0318h -ErrorAction SilentlyContinue); Get-Item -LiteralPath "$Sb/emu-nope-v0318-loud" }
    $script:LoginStage = 'confirm'
    $script:NoticeShown = $false
    try { Write-ClosingNote } finally { Write-Log 'TEST finally' }
    return
}

if ($Scenario -like 'path-*') {
    $script:EmuUserPath = if ($Scenario -eq 'path-dup') { 'C:\Windows;C:\Users\emu\AppData\Local\CYS\' } else { 'C:\Windows' }
    function Get-UserPathValue { return $script:EmuUserPath }
    function Set-UserPathValue($value) { $script:EmuUserPath = $value; Add-Content -LiteralPath "$Sb/pathset.log" -Value $value }
    try {
        [void](Seed-CysPath 'C:\Users\emu\AppData\Local\cys')
        [void](Seed-CysPath 'C:\Users\emu\AppData\Local\cys\')
        Write-Log ('TEST userpath=' + $script:EmuUserPath)
    } finally { Write-Log 'TEST finally' }
    return
}

if ($Scenario -eq 'progress-body') {
    # 실물 Send-Progress 가 evidence 추가 칸(text·reason·masked)을 본문에 싣는가 — 받는 쪽만 가짜(바깥 전송 0)
    try {
        $Mode = 'full'
        $env:JARVIS_NO_PROGRESS = ''
        $env:JARVIS_PROGRESS_URL = 'http://emu.invalid/api/progress'
        function Invoke-WebRequest {
            [CmdletBinding()] param([string]$Uri, [string]$Method, $Body, [string]$ContentType, [switch]$UseBasicParsing, [int]$TimeoutSec)
            Set-Content -LiteralPath "$Sb/body.json" -Value ([System.Text.Encoding]::UTF8.GetString([byte[]]$Body)) -NoNewline
        }
        Send-Progress '6/10' 'evidence' $null $null $null ([ordered]@{ text = 'emu <EMAIL> tail'; reason = 'stall'; masked = $true })
        $b = Get-Content -LiteralPath "$Sb/body.json" -Raw | ConvertFrom-Json
        Write-Log ('TEST body event=' + $b.event + ' reason=' + $b.reason + ' masked=' + $b.masked + ' text=' + $b.text + ' step=' + $b.step)
    } finally { $env:JARVIS_NO_PROGRESS = '1'; Write-Log 'TEST finally' }
    return
}

if ($Scenario -eq 'mask-vectors') {
    try {
        $vj = Get-Content -LiteralPath $env:V0318_MASK_VECTORS -Raw -Encoding UTF8 | ConvertFrom-Json
        $i = 0
        foreach ($v in $vj.vectors) {
            $i++
            $got = Protect-EvidenceText ([string]$v.input)
            if ($got -ceq [string]$v.expected) { Write-Log ('TEST vec ' + $i + ' ok ' + $v.category) } else { Write-Log ('TEST vec ' + $i + ' BAD ' + $v.category + ' got=' + $got) }
        }
        # 식이 대조표와 글자까지 같은가(대조표 차례 = 코드 차례 · 이름 수집 식은 따로)
        $rules = @($vj.categories | Where-Object { $_.name -ne 'harvested_name' })
        $same = ($rules.Count -eq $EvidenceMaskRules.Count)
        for ($k = 0; $same -and $k -lt $rules.Count; $k++) {
            if (([string]$rules[$k].ps1_regex -cne $EvidenceMaskRules[$k][0]) -or ([string]$rules[$k].placeholder -cne $EvidenceMaskRules[$k][1])) { $same = $false; Write-Log ('TEST drift at ' + $k) }
        }
        $hn = @($vj.categories | Where-Object { $_.name -eq 'harvested_name' })
        if ($hn.Count -ne 1 -or ([string]$hn[0].ps1_regex -cne $EvidenceNameLines)) { $same = $false; Write-Log 'TEST drift at harvested_name' }
        Write-Log ('TEST vectors=' + $i + ' drift=' + $(if ($same) { 'none' } else { 'yes' }))
    } finally { Write-Log 'TEST finally' }
    return
}

if ($Scenario -eq 'settings') {
    try {
        $sf = "$Sb/home/.claude/settings.json"
        [void](Set-ClaudeSettings $sf)
        $o = Get-Content -LiteralPath $sf -Raw | ConvertFrom-Json
        Write-Log ('TEST channel=' + $o.autoUpdatesChannel + ' skip=' + $o.skipDangerousModePermissionPrompt)
    } finally { Write-Log 'TEST finally' }
    return
}

# ── ①② 판본 갈래 (+ v0.3.18 final: 판번+지문 이중 대조 · 지문 뒤 웹 표식 해제 · [6/10] 대기 표지) ──
$script:EmuInstallerBytes = [System.Text.Encoding]::ASCII.GetBytes('emu cys installer v0318')
$tmpf = "$Sb/emu-installer.bin"
[System.IO.File]::WriteAllBytes($tmpf, $script:EmuInstallerBytes)
$CysWinBytes = $script:EmuInstallerBytes.Length
$CysWinSha256 = (Get-FileHash -Algorithm SHA256 -LiteralPath $tmpf).Hash.ToLower()
# 받기 가짜가 쓰는 바이트 — motw-badsha 는 크기는 같고 내용이 다른 파일을 받는다(지문 불일치)
$script:EmuDownloadBytes = if ($Scenario -eq 'motw-badsha') { [System.Text.Encoding]::ASCII.GetBytes('EMU CYS INSTALLER V0318') } else { $script:EmuInstallerBytes }
New-Item -ItemType Directory -Force -Path "$Sb/cysdir" | Out-Null
$exeOld = [System.Text.Encoding]::ASCII.GetBytes('emu cys exe A')
$exeNew = [System.Text.Encoding]::ASCII.GetBytes('emu cys exe B (pinned build)')
function Write-EmuStamp($setupSha, $exeBytes) {
    $f = "$Sb/emu-exe-for-stamp.bin"; [System.IO.File]::WriteAllBytes($f, $exeBytes)
    $es = (Get-FileHash -Algorithm SHA256 -LiteralPath $f).Hash.ToLower()
    Set-Content -LiteralPath "$Sb/cysdir/jarvis-cys-pin.json" -Value ('{"version":"' + $CysVersion + '","setup_sha256":"' + $setupSha + '","exe_sha256":"' + $es + '"}') -NoNewline
}
switch ($Scenario) {
    'ver-same'     { Set-Content -LiteralPath "$Sb/cys-state.txt" -Value $CysVersion -NoNewline; [System.IO.File]::WriteAllBytes("$Sb/cysdir/cys.exe", $exeNew); Write-EmuStamp $CysWinSha256 $exeNew }
    # 같은 판번 · 표지의 핀 지문이 지금 핀과 다르다 = 같은 판번으로 다시 발행한 빌드
    'ver-same-pin' { Set-Content -LiteralPath "$Sb/cys-state.txt" -Value $CysVersion -NoNewline; [System.IO.File]::WriteAllBytes("$Sb/cysdir/cys.exe", $exeOld); Write-EmuStamp ('a' * 64) $exeOld }
    # 같은 판번 · 핀은 같은데 깔린 cys.exe 가 표지와 다르다(다른 경로로 같은 판번의 다른 파일이 깔렸다)
    'ver-same-exe' { Set-Content -LiteralPath "$Sb/cys-state.txt" -Value $CysVersion -NoNewline; [System.IO.File]::WriteAllBytes("$Sb/cysdir/cys.exe", $exeOld); Write-EmuStamp $CysWinSha256 $exeNew }
    'ver-same-refresh-fail' { Set-Content -LiteralPath "$Sb/cys-state.txt" -Value $CysVersion -NoNewline; [System.IO.File]::WriteAllBytes("$Sb/cysdir/cys.exe", $exeOld) }
    'ver-old'      { Set-Content -LiteralPath "$Sb/cys-state.txt" -Value '0.14.30' -NoNewline; [System.IO.File]::WriteAllBytes("$Sb/cysdir/cys.exe", $exeOld) }
    'ver-old-fail' { Set-Content -LiteralPath "$Sb/cys-state.txt" -Value '0.14.30' -NoNewline; [System.IO.File]::WriteAllBytes("$Sb/cysdir/cys.exe", $exeOld) }
    'ver-unknown'  { Set-Content -LiteralPath "$Sb/cys-state.txt" -Value 'unknown' -NoNewline; [System.IO.File]::WriteAllBytes("$Sb/cysdir/cys.exe", $exeOld) }
    'ver-fresh'    { }
    'motw-badsha'  { }
    'wait-hb'      { }
    'evidence-stall' { }
}
function Test-CysBody {
    $f = "$Sb/cys-state.txt"
    if (-not (Test-Path -LiteralPath $f)) { return [pscustomobject]@{ Reg = $null; Body = $false; Path = ''; Cli = '' } }
    $v = (Get-Content -LiteralPath $f -Raw).Trim()
    $reg = if ($v -and $v -ne 'unknown') { [pscustomobject]@{ DisplayName = 'cys'; DisplayVersion = $v } } else { $null }
    return [pscustomobject]@{ Reg = $reg; Body = $true; Path = "$Sb/cysdir"; Cli = "$Sb/cysdir/cys.exe" }
}
function Invoke-WebRequest {
    [CmdletBinding()] param([string]$Uri, [string]$OutFile, [switch]$UseBasicParsing, [int]$TimeoutSec, [string]$Method)
    Add-Content -LiteralPath "$Sb/iwr.log" -Value ("IWR $Uri")
    if ($OutFile) { [System.IO.File]::WriteAllBytes($OutFile, $script:EmuDownloadBytes) }
}
# 웹 표식 가짜 — 받은 파일에 표식이 있다고 답하고, 지우기(Unblock-File)는 부른 사실만 적는다
function Test-WebMark($path) { Add-Content -LiteralPath "$Sb/motw.log" -Value ('ASK ' + (Split-Path -Leaf $path)); return $true }
function Unblock-File { [CmdletBinding()] param([string]$LiteralPath) Add-Content -LiteralPath "$Sb/motw.log" -Value ('UNBLOCK ' + (Split-Path -Leaf $LiteralPath)) }
# 진행 표지 가짜 — 보낸 표지를 적는다(실제 전송은 흉내에서 늘 꺼져 있다)
function Send-Progress($step, $ev, $elapsed, $detail, $envInfo, $extra) {
    Add-Content -LiteralPath "$Sb/progress.log" -Value ('PROG ' + $step + ' ' + $ev + ' ' + $elapsed)
    if ($null -ne $extra) { Add-Content -LiteralPath "$Sb/evidence.log" -Value ('EVID ' + $step + ' ' + (([pscustomobject]$extra) | ConvertTo-Json -Compress)) }
}
$script:EmuWaitCalls = 0
function Start-Process {
    [CmdletBinding()] param([string]$FilePath, [string[]]$ArgumentList, [switch]$PassThru)
    Add-Content -LiteralPath "$Sb/installer.log" -Value ('RUN ' + (Split-Path $FilePath -Leaf) + ' [' + ($ArgumentList -join ',') + ']')
    $fail = ($Scenario -eq 'ver-old-fail') -or ($Scenario -eq 'ver-same-refresh-fail')
    if (-not $fail) {
        Set-Content -LiteralPath "$Sb/cys-state.txt" -Value $CysVersion -NoNewline
        New-Item -ItemType Directory -Force -Path "$Sb/cysdir" | Out-Null
        [System.IO.File]::WriteAllBytes("$Sb/cysdir/cys.exe", $exeNew)
    }
    $o = [pscustomobject]@{ HasExited = $true; ExitCode = $(if ($fail) { 4 } else { 0 }) }
    if ($Scenario -eq 'wait-hb') {
        # 설치기가 두 조각(60초 × 2) 동안 안 끝나다가 세 번째 조각에 끝난다
        $o | Add-Member -MemberType ScriptMethod -Name WaitForExit -Value { param($ms) $script:EmuWaitCalls++; Add-Content -LiteralPath "$Sb/wait.log" -Value ('WAIT ' + $ms); return ($script:EmuWaitCalls -ge 3) }
    } elseif ($Scenario -eq 'evidence-stall') {
        # 네 조각(60·120·180·240초) 동안 안 끝나다가 다섯 번째에 끝난다 — 180초·240초 두 번 3분을 넘겨도 증거는 한 번
        $o | Add-Member -MemberType ScriptMethod -Name WaitForExit -Value { param($ms) $script:EmuWaitCalls++; return ($script:EmuWaitCalls -ge 5) }
    } else {
        $o | Add-Member -MemberType ScriptMethod -Name WaitForExit -Value { param($ms) return $true }
    }
    return $o
}
function Start-Sleep { param([int]$Seconds, [int]$Milliseconds) }
if ($Scenario -eq 'wait-hb') { $InstallWaitMs = 150000 }
if ($Scenario -eq 'evidence-stall') {
    $InstallWaitMs = 600000
    # 설치 창에 찍힌 것처럼 기록에 개인 정보가 섞인 줄을 남긴다(합성 값)
    Write-Log 'EMU screen: 계정 메일 hong.gildong+emu@example.co.kr · 폴더 C:\Users\hong\install-jarvis · Authorization: Bearer emuSECRET123.tok'
    Write-Log 'EMU screen: USERNAME=hongemu'
    Write-Log 'EMU screen: hongemu 계정으로 진행 중 · Paste code here if prompted > emu-not-hash-shaped-token'
}

try {
    $r5 = @(Step-DownloadCys)[-1]
    $r6 = if ($r5 -eq 0) { @(Step-InstallCys)[-1] } else { 'skip' }
    Write-Log ('TEST r5=' + $r5 + ' r6=' + $r6)
} finally { Write-Log 'TEST finally' }
