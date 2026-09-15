# [8/10] v0.3.18 계정 준비 흉내 (pwsh 7 · 맥) — 실물 bootstrap.ps1 을 「함수 묶음」으로 읽고, 가짜 자가진단 출력으로 Step-PrepareAccount 의 판정을 부른다
#   막는 기준 = 자비스 창(cys 좌석)을 여는 데 필요한 항목뿐 · 나머지 실패는 주의 · 항목 줄을 못 읽으면 앞 판대로 실패 수 전체
param([string]$Src, [string]$Scenario, [string]$Sb)
$ErrorActionPreference = 'Continue'
New-Item -ItemType Directory -Force -Path "$Sb/home/install-jarvis", "$Sb/bin" | Out-Null
# 가짜 cys — ping 에 pong 으로 답한다(데몬 생존 축은 이 흉내가 재지 않는다) · init-pack · daemon install 은 0
Set-Content -Path "$Sb/bin/cys" -Value "#!/bin/sh`ncase `"`$1`" in ping) echo pong ;; esac`nexit 0`n" -NoNewline
& chmod +x "$Sb/bin/cys"
$env:USERPROFILE = "$Sb/home"
$env:JARVIS_HOME = "$Sb/home/install-jarvis"
$env:JARVIS_LIB_ONLY = '1'
$env:JARVIS_NO_PROGRESS = '1'
. $Src
$env:JARVIS_LIB_ONLY = ''

function L($st, $name, $detail) { '  [{0,-4}] {1,-16} {2}' -f $st, $name, $detail }
$okNames = @('pack-version', 'pack-state', 'install-manifest', 'hook', 'dept-hook-residue', 'dept-awakening-seed', 'config-dir-target', 'socket', 'startup-lock', 'staging-residue', 'channels-db', 'legacy-config')
$lines = New-Object System.Collections.ArrayList
switch ($Scenario) {
    'all-ok' {
        foreach ($n in $okNames) { [void]$lines.Add((L 'OK' $n 'emu')) }
        [void]$lines.Add('요약: 12 OK · 0 WARN · 0 FAIL · 0 SKIP(판정 불가)')
    }
    'minor-fail' {
        # 3차 실기 모양 — 좌석과 무관한 항목 하나가 실패(런타임 git 폴더 목록 대조)
        foreach ($n in $okNames) { [void]$lines.Add((L 'OK' $n 'emu')) }
        [void]$lines.Add((L 'FAIL' 'runtime-sanity' 'runtime\git\etc 목록 대조 불일치 (mtab)'))
        [void]$lines.Add('요약: 12 OK · 0 WARN · 1 FAIL · 0 SKIP(판정 불가)')
    }
    'fatal-fail' {
        foreach ($n in $okNames) { if ($n -eq 'hook') { [void]$lines.Add((L 'FAIL' $n 'emu hook missing')) } else { [void]$lines.Add((L 'OK' $n 'emu')) } }
        [void]$lines.Add('요약: 11 OK · 0 WARN · 1 FAIL · 0 SKIP(판정 불가)')
    }
    'unreadable' {
        # 항목 줄 문안이 바뀌어 하나도 못 읽는다 — 요약만 실패 1
        foreach ($n in $okNames) { [void]$lines.Add(('  ' + $n + ': emu')) }
        [void]$lines.Add('요약: 11 OK · 0 WARN · 1 FAIL · 0 SKIP(판정 불가)')
    }
    'unread-fail' {
        # 항목 줄은 읽히는데 실패 줄 하나가 모양이 달라 안 읽힌다 — 요약은 실패 1
        foreach ($n in $okNames) { [void]$lines.Add((L 'OK' $n 'emu')) }
        [void]$lines.Add('  FAILED new-item emu')
        [void]$lines.Add('요약: 12 OK · 0 WARN · 1 FAIL · 0 SKIP(판정 불가)')
    }
}
$script:EmuDoctor = @($lines)

# ── 바꿔 끼우는 것 (판정 앞뒤의 바깥 일만) ──
function Set-AllProfiles { return 0 }
function Copy-LoginToIsolated { return 0 }
function Get-CysAutoStartState { param([string]$CysCli = '') return 'yes' }
function Invoke-CysProbe {
    param([string]$Cli, [string[]]$CysArgs)
    if ($CysArgs -and $CysArgs[0] -eq 'doctor') { return $script:EmuDoctor }
    return @()
}
$script:CysCli = "$Sb/bin/cys"
$script:TrustJournalFailed = $false

try { $rc = @(Step-PrepareAccount)[-1]; Write-Log ('TEST rc=' + $rc) }
finally { Write-Log 'TEST finally' }
