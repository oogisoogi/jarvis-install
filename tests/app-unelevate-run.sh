#!/bin/bash
# 0.3.50(윈 · TICKET=installer-win-unelevate-1126) — 관리자 창에서 돈 설치기가 앱 창을 일반 권한으로 내려 띄우는가.
#
# 까닭: 11-25 윈 rc3 실기 = 설치기 [9/10] 「cys app start」 가 Start-Process 로 자기 관리자 토큰을 물려줘 cys-app 만 TokenElevation=1
#   (cysd·claude 0) ⇒ 일반 사용자가 관리자 PowerShell 로 설치하면 끌어 놓기 막힘(UIPI). 운영자 노트북은 방침상 관리자(예약 작업 jarvis-cys-app
#   RunLevel=HighestAvailable) ⇒ 그 기기는 종전대로.
# 재는 것 — 실제 Start-CysAppWindow 를 돌리고 Start-Process·Get-Process·schtasks 를 가짜로 바꿔 「무엇을 띄웠는가」를 대조한다.
#   ⓐ 판단 표(순수 Get-AppLaunchPlan) 6칸
#   ⓑ 관리자 · 작업 없음 · 탐색기 있음 → explorer.exe "<앱>" 한 번만(직접 기동 0) · 'started' · 토큰 env 0
#   ⓒ 관리자 · 탐색기가 넘겼는데 10초 안에 앱이 안 보임 → 직접 기동으로 한 번 더(창 0 보다 관리자 창) · 'started'
#   ⓓ 관리자 · 탐색기 부르기가 예외 → 직접 기동(fail-open)
#   ⓔ 관리자 · jarvis-cys-app=HighestAvailable(운영자 노트북) → 종전 직접 기동 · 탐색기 0
#   ⓕ 관리자 · 탐색기 없음 → 종전 직접 기동
#   ⓖ 관리자 아님 → 종전 직접 기동(탐색기 0 · 작업 조회 결과와 무관)
#   ⓗ 이미 떠 있음 → 'raised' · 기동 0
#   ⓘ Get-AppTaskRunLevel: XML 의 RunLevel 글자 · 작업 없음(rc 1) = ''
#   ⓒ2 마지막 대기 중 뜬 앱 = 잡는다 · ⓒ3 다른 세션 · ⓒ4 다른 자리의 같은 이름 앱 = 성공 아님
#   ⓒ5 Path 못 읽음(32비트 셸) = CIM 으로 잡는다 · ⓒ6 CIM 도 실패 = 종전 기동
#   ⓚ 실물 Test-SelfElevated(못 재면 False) · 실물 Test-DesktopShellUp(이 세션 탐색기만)
#   ⓙ 돌연변이 7종(CIM 보완 삭제 · 판단 늘 plain · 탐색기 갈래 삭제 · device-admin 삭제 · 탐색기 판별 늘 False · 세션 거름 삭제 · 마감 재조회 삭제) 이 위 축 중 하나 이상에서 잡힌다
# 쓰는 법: bash tests/app-unelevate-run.sh [--dir <install-master 자리>]   · rc 0 = 통과 · 1 = 실패
# ⛔바깥에 닿지 않는다 — 진짜 Start-Process·schtasks·explorer 호출 0 · 쓰기는 mktemp -d 안에서만.
# ⚠여기서 안 재는 것: 진짜 윈도우에서 explorer.exe 가 일반 토큰으로 띄우는가(= 실기 대본 docs/win-unelevate-0350.md §4) · PowerShell 5.1(pwsh 7 로 돈다).
set -u
HERE="$(cd "$(dirname "$0")" && pwd)"
DIR="$HERE/../install-master"
[ "${1:-}" = "--dir" ] && DIR="$2"
PS="$(cd "$DIR" && pwd)/bootstrap.ps1"
BASE="$(mktemp -d /tmp/appunelevXXXXXX)" || exit 2
trap 'rm -rf "$BASE"' EXIT
pass=0; fail=0
t() { if [ "$1" -eq 0 ]; then pass=$((pass+1)); printf '  ok   %s\n' "$2"; else fail=$((fail+1)); printf '  FAIL %s  ← %s\n' "$2" "$3"; fi; }

PW="$(command -v pwsh 2>/dev/null)"
if [ -z "$PW" ]; then
  t 1 "pwsh 가 있어야 실제로 돌려 잰다" "pwsh 없음 — 설치(brew install powershell) 뒤 다시"
  printf '\n통과 %s · 실패 %s\n' "$pass" "$fail"; exit 1
fi

# 가짜 세계를 깔고 갈래마다 돌린 뒤 결과를 한 줄씩 낸다(pwsh 한 번에 전 갈래 · 읽어 들이기 1회):
#   <갈래> ret=<값>|calls=<FilePath>{<Args>}<+txn>;…|log=<plan 줄>|txnAfter=<되돌린 토큰 env>
cat > "$BASE/drive.ps1" <<'PS1'
param([string]$Src)
. $Src *> $null
$env:JARVIS_LIB_ONLY = ""
$out = New-Object System.Collections.ArrayList
# ⓐ 판단 표
$rows = @(
  @($false, '', $true, 'plain'),
  @($false, 'HighestAvailable', $true, 'plain'),
  @($true, 'HighestAvailable', $true, 'keep:device-admin'),
  @($true, 'HighestAvailable', $false, 'keep:device-admin'),
  @($true, 'LeastPrivilege', $true, 'explorer'),
  @($true, '', $true, 'explorer'),
  @($true, '', $false, 'keep:no-shell')
)
$bad = 0
foreach ($r in $rows) { if ((Get-AppLaunchPlan $r[0] $r[1] $r[2]) -ne $r[3]) { $bad++ } }
# 0.3.50 R1 — 탐색기 주인(4번째 칸): same = 종전 판정 · other = keep:other-user · unknown = keep:owner-unknown · 관리자 아님·기기 방침·탐색기 없음이 먼저
$rows4 = @(
  @($true, '', $true, 'same', 'explorer'),
  @($true, '', $true, 'other', 'keep:other-user'),
  @($true, '', $true, 'unknown', 'keep:owner-unknown'),
  @($false, '', $true, 'other', 'plain'),
  @($true, 'HighestAvailable', $true, 'other', 'keep:device-admin'),
  @($true, '', $false, 'other', 'keep:no-shell')
)
foreach ($r in $rows4) { if ((Get-AppLaunchPlan $r[0] $r[1] $r[2] $r[3]) -ne $r[4]) { $bad++ } }
[void]$out.Add('a bad=' + $bad)
# ⓘ RunLevel 읽기 — schtasks 를 가짜로(함수가 명령보다 먼저 잡힌다)
function schtasks {
  if ($global:SchCase -eq 'none') { $global:LASTEXITCODE = 1; return 'ERROR: The system cannot find the file specified.' }
  $global:LASTEXITCODE = 0
  return @('<?xml version="1.0" encoding="UTF-16"?>', '<Task><Principals><Principal id="Author">', "  <RunLevel>$($global:SchCase)</RunLevel>", '</Principal></Principals></Task>')
}
foreach ($c in @('HighestAvailable', 'none')) { $global:SchCase = $c; [void]$out.Add('i-' + $c + ' rl=[' + (Get-AppTaskRunLevel) + ']') }
# ⓚ 실물 판별 함수 — 실제 Test-SelfElevated(맥 pwsh = 윈 신원 없음 → $false = 종전 동작) 를 가짜로 덮기 **전에** 잰다
[void]$out.Add('k-self elev=' + (Test-SelfElevated))
# 가짜 프로세스 표 — 진짜 Get-Process 처럼 -Name·-Id 로 거르고, 없으면 **아무것도 내지 않는다**($null 을 내면 @(…).Count 가 1 이 된다)
$global:MySid = 1
$global:Procs = New-Object System.Collections.ArrayList
function Get-Process {
  param([string[]]$Name, [int]$Id, $ErrorAction)
  if ($PSBoundParameters.ContainsKey('Id')) {
    if ($Id -eq $PID) { [pscustomobject]@{ Id = $PID; Name = 'pwsh'; SessionId = $global:MySid; Path = 'C:\pwsh.exe' } }
    return
  }
  foreach ($p in $global:Procs) { if (-not $Name -or ($Name -contains $p.Name)) { $p } }
}
function Add-Proc($n, $sid, $path) {
  # 32비트 셸 흉내: NullPath 면 Path 는 비고 CIM 쪽에만 경로가 있다
  $vis = if ($global:NullPath -and $n -ne 'explorer') { $null } else { $path }
  [void]$global:Procs.Add([pscustomobject]@{ Id = 4000 + $global:Procs.Count; Name = $n; SessionId = $sid; Path = $vis; CimPath = $path; Owner = $global:MeSid })
}
# ⓚ 실제 Test-DesktopShellUp — 이 세션 탐색기 / 다른 세션만 / 없음
$global:Procs.Clear(); Add-Proc 'explorer' 1 'C:\Windows\explorer.exe'; [void]$out.Add('k-shell-mine up=' + (Test-DesktopShellUp))
$global:Procs.Clear(); Add-Proc 'explorer' 2 'C:\Windows\explorer.exe'; [void]$out.Add('k-shell-other up=' + (Test-DesktopShellUp))
$global:Procs.Clear(); [void]$out.Add('k-shell-none up=' + (Test-DesktopShellUp))
# ⓑ~ⓗ 실제 Start-CysAppWindow — 바깥 명령은 전부 가짜(관리자 여부·작업 RunLevel 만 덮는다 · 탐색기 판별은 실물)
function Write-Log($m) { [void]$global:Logs.Add([string]$m) }
function Get-CysAppExe { return $global:Exe }
function Test-SelfElevated { return $global:Elev }
function Get-AppTaskRunLevel { return $global:RL }
function Start-Sleep {
  param([int]$Milliseconds, [int]$Seconds)
  $global:Slept += $Milliseconds
  if ($global:BringAt -gt 0 -and -not $global:Brought -and $global:Slept -ge $global:BringAt) { $global:Brought = $true; Add-Proc 'cys-app' $global:MySid $global:Exe }
}
function Start-Process {
  param([string]$FilePath, $ArgumentList, $ErrorAction)
  $txn = if ($env:CYS_UPDATE_TXN) { '+txn' } else { '' }
  [void]$global:Calls.Add($FilePath + '{' + (@($ArgumentList) -join ' ') + '}' + $txn)
  if ($FilePath -like '*explorer.exe') {
    if ($global:ExplorerThrows) { throw 'explorer refused' }
    if ($global:BringSid -gt 0) { Add-Proc 'cys-app' $global:BringSid $global:BringPath }
  }
}
# 주인 SID · 벽시계 — 바꿔 끼움(가짜 프로세스 표의 Owner 칸 · 잔 시간 = 벽시계)
$global:MeSid = 'S-1-5-21-1-1001'
function Get-SelfUserSid { return $global:MeSid }
function Get-ProcOwnerSid([int]$Id) { foreach ($q in $global:Procs) { if ($q.Id -eq $Id) { return [string]$q.Owner } }; return '' }
function Get-ShellWaitElapsedMs($Sw) { return [long]$global:Slept }
function Send-Progress($step, $ev, $elapsed, $detail, $envInfo) { [void]$global:Prog.Add([string]$step + '|' + [string]$ev + '|' + [string]$detail) }
function Get-CimInstance {
  param([string]$ClassName, [string]$Filter, $ErrorAction)
  if ($global:CimThrows) { throw 'cim refused' }
  $id = [int]($Filter -replace '\D', '')
  foreach ($q in $global:Procs) { if ($q.Id -eq $id) { [pscustomobject]@{ ProcessId = $id; ExecutablePath = $q.CimPath } } }
}
$env:WINDIR = 'C:\Windows'
foreach ($case in @('b', 'c', 'c-late', 'c-othersess', 'c-otherpath', 'c-nullpath', 'c-nullpath-cimfail', 'd', 'e', 'e2', 'f', 'g', 'h', 'u-ots', 'u-ownerunk', 'x-mixed')) {
  $global:Calls = New-Object System.Collections.ArrayList
  $global:Logs = New-Object System.Collections.ArrayList
  $global:Prog = New-Object System.Collections.ArrayList
  $global:Slept = 0; $global:BringAt = 0; $global:Brought = $false
  $global:Exe = 'C:\Users\it''s me\AppData\Local\cysr\cys-app.exe'
  $env:CYS_UPDATE_TXN = 'tok-123'
  $global:Elev = $true; $global:RL = ''; $global:ExplorerThrows = $false; $global:NullPath = $false; $global:CimThrows = $false
  $global:BringSid = $global:MySid; $global:BringPath = $global:Exe
  $global:Procs.Clear(); Add-Proc 'explorer' $global:MySid 'C:\Windows\explorer.exe'
  switch ($case) {
    'c' { $global:BringSid = 0 }
    'c-late' { $global:BringSid = 0; $global:BringAt = 10000 }
    'c-othersess' { $global:BringSid = 2 }
    'c-otherpath' { $global:BringPath = 'D:\old\cysr\cys-app.exe' }
    'c-nullpath' { $global:NullPath = $true }
    'c-nullpath-cimfail' { $global:NullPath = $true; $global:CimThrows = $true }
    'd' { $global:ExplorerThrows = $true }
    'e' { $global:RL = 'HighestAvailable' }
    'e2' { $global:RL = 'LeastPrivilege' }
    'f' { $global:Procs.Clear(); Add-Proc 'explorer' 2 'C:\Windows\explorer.exe' }
    'g' { $global:Elev = $false }
    'h' { Add-Proc 'cys-app' $global:MySid $global:Exe }
    'u-ots' { $global:Procs[0].Owner = 'S-1-5-21-1-1002' }
    'u-ownerunk' { $global:Procs[0].Owner = '' }
    'x-mixed' { $global:Procs[0].Owner = 'S-1-5-21-1-1002'; Add-Proc 'explorer' $global:MySid 'C:\Windows\explorer.exe' }
  }
  $r = Start-CysAppWindow
  $plan = ($global:Logs | Where-Object { $_ -like 'cys app launch plan:*' }) -join ','
  [void]$out.Add($case + ' ret=' + $r + '|calls=' + ($global:Calls -join ';') + '|log=' + $plan + '|txnAfter=' + $env:CYS_UPDATE_TXN + '|slept=' + $global:Slept)
  [void]$out.Add('p-' + $case + ' ' + ($global:Prog -join ';'))
}
$out | ForEach-Object { Write-Output $_ }
PS1

run_all() { perl -e 'alarm 120; exec @ARGV or exit 126' "$PW" -NoProfile -File "$BASE/drive.ps1" -Src "$1" 2>/dev/null | tr -d '\r' > "$2"; }
line() { grep "^$2 " "$1" | tail -1 | cut -d' ' -f2-; }

EXE='C:\Users\it'"'"'s me\AppData\Local\cysr\cys-app.exe'

axes() { # axes <ps1> <접두> — 전역 pass/fail 을 센다
  local src="$1" p="$2" o r R="$BASE/out.$$.$RANDOM"
  run_all "$src" "$R"
  o="$(line "$R" a)"; [ "$o" = "bad=0" ]; t $? "$p[ⓐ] 판단 표 7칸(관리자·작업 RunLevel·탐색기) + 탐색기 주인 6칸(0.3.50 R1)" "$o"
  o="$(line "$R" b)"
  case "$o" in "ret=started|calls="*"explorer.exe{\"$EXE\"}|log=cys app launch plan: explorer|txnAfter=tok-123|slept=0") r=0;; *) r=1;; esac
  t $r "$p[ⓑ] 관리자·작업 없음·탐색기 있음 → explorer.exe \"<앱>\" 한 번만 · 직접 기동 0 · 토큰 env 0 · 뒤에 되돌림 · 기다림 0" "$o"
  o="$(line "$R" c)"
  case "$o" in "ret=started|calls="*"explorer.exe{\"$EXE\"};$EXE{}|log=cys app launch plan: explorer|txnAfter=tok-123|slept=10000") r=0;; *) r=1;; esac
  t $r "$p[ⓒ] 탐색기가 10초 안에 못 띄움 → 직접 기동으로 한 번 더(토큰 env 0 · 기다림 10초 상한)" "$o"
  o="$(line "$R" c-late)"
  case "$o" in "ret=started|calls="*"explorer.exe{\"$EXE\"}|log=cys app launch plan: explorer|txnAfter=tok-123|slept=10000") r=0;; *) r=1;; esac
  t $r "$p[ⓒ2] 마지막 대기 중에 뜬 앱 → 마감 시점 재조회로 잡는다 · 직접 기동 0" "$o"
  o="$(line "$R" c-othersess)"
  case "$o" in "ret=started|calls="*"explorer.exe{\"$EXE\"};$EXE{}|"*) r=0;; *) r=1;; esac
  t $r "$p[ⓒ3] 다른 세션의 같은 이름 앱은 성공으로 안 센다 → 직접 기동" "$o"
  o="$(line "$R" c-otherpath)"
  case "$o" in "ret=started|calls="*"explorer.exe{\"$EXE\"};$EXE{}|"*) r=0;; *) r=1;; esac
  t $r "$p[ⓒ4] 다른 자리의 같은 이름 앱은 성공으로 안 센다 → 직접 기동" "$o"
  o="$(line "$R" c-nullpath)"
  case "$o" in "ret=started|calls="*"explorer.exe{\"$EXE\"}|log=cys app launch plan: explorer|txnAfter=tok-123|slept=0") r=0;; *) r=1;; esac
  t $r "$p[ⓒ5] Path 를 못 읽는 셸(32비트) → CIM ExecutablePath 로 잡는다 · 직접 기동 0" "$o"
  o="$(line "$R" c-nullpath-cimfail)"
  case "$o" in "ret=started|calls="*"explorer.exe{\"$EXE\"};$EXE{}|"*) r=0;; *) r=1;; esac
  t $r "$p[ⓒ6] Path·CIM 둘 다 못 읽음 → 세지 않음 → 직접 기동(fail-open)" "$o"
  o="$(line "$R" d)"
  case "$o" in "ret=started|calls="*"explorer.exe{\"$EXE\"};$EXE{}|"*) r=0;; *) r=1;; esac
  t $r "$p[ⓓ] 탐색기 부르기 예외 → 직접 기동(fail-open)" "$o"
  o="$(line "$R" e)"
  [ "$o" = "ret=started|calls=$EXE{}|log=cys app launch plan: keep:device-admin|txnAfter=tok-123|slept=0" ]; t $? "$p[ⓔ] jarvis-cys-app=HighestAvailable(운영자 노트북) → 종전 직접 기동 · 탐색기 0" "$o"
  o="$(line "$R" e2)"
  case "$o" in "ret=started|calls="*"explorer.exe{\"$EXE\"}|"*) r=0;; *) r=1;; esac
  t $r "$p[ⓔ2] jarvis-cys-app=LeastPrivilege → 내려 띄운다" "$o"
  o="$(line "$R" f)"
  [ "$o" = "ret=started|calls=$EXE{}|log=cys app launch plan: keep:no-shell|txnAfter=tok-123|slept=0" ]; t $? "$p[ⓕ] 탐색기 없음 → 종전 직접 기동" "$o"
  o="$(line "$R" g)"
  [ "$o" = "ret=started|calls=$EXE{}|log=cys app launch plan: plain|txnAfter=tok-123|slept=0" ]; t $? "$p[ⓖ] 관리자 아님 → 종전 직접 기동(탐색기 0)" "$o"
  o="$(line "$R" h)"
  [ "$o" = "ret=raised|calls=|log=|txnAfter=tok-123|slept=0" ]; t $? "$p[ⓗ] 이미 떠 있음 → raised · 기동 0" "$o"
  o="$(line "$R" u-ots)"
  [ "$o" = "ret=started|calls=$EXE{}|log=cys app launch plan: keep:other-user|txnAfter=tok-123|slept=0" ]; t $? "$p[ⓤ] 같은 세션 탐색기의 주인이 다른 계정(표준 사용자 바탕화면 + 다른 관리자 자격 창 · 독립 검증 R1) → keep:other-user · 종전 직접 기동 · 탐색기 0" "$o"
  o="$(line "$R" x-mixed)"
  [ "$o" = "ret=started|calls=$EXE{}|log=cys app launch plan: keep:other-user|txnAfter=tok-123|slept=0" ]; t $? "$p[ⓤ3] 같은 세션 탐색기 둘 = 다른 계정 하나 + 설치기 계정 하나(섞임 · 재검 R2-1) → keep:other-user(하나라도 다르면) · 종전 직접 기동" "$o"
  o="$(line "$R" u-ownerunk)"
  [ "$o" = "ret=started|calls=$EXE{}|log=cys app launch plan: keep:owner-unknown|txnAfter=tok-123|slept=0" ]; t $? "$p[ⓤ2] 탐색기 주인을 못 읽음 → keep:owner-unknown · 종전 직접 기동" "$o"
  o="$(line "$R" p-b) # $(line "$R" p-c) # $(line "$R" p-g) # $(line "$R" p-u-ots) # $(line "$R" p-h)"
  [ "$o" = "9/10|info|app-launch plan=explorer elevated=? # 9/10|info|app-launch plan=explorer>direct elevated=? # 9/10|info|app-launch plan=plain elevated=0 # 9/10|info|app-launch plan=keep:other-user elevated=? # " ]
  t $? "$p[ⓟ] 진행 보고 info 1건 = app-launch plan=<판정> elevated=<1|0|?>(맥 흉내 = 토큰 못 읽음 ? · plain = 재지 않고 0 · 재검 N-b) · 폴백 = explorer>direct · 이미 떠 있음(raised) = 0건" "$o"
  o="$(line "$R" k-self)"; [ "$o" = "elev=False" ]; t $? "$p[ⓚ] 실제 Test-SelfElevated — 윈 신원을 못 재면 False(= 종전 동작)" "$o"
  o="$(line "$R" k-shell-mine) $(line "$R" k-shell-other) $(line "$R" k-shell-none)"; [ "$o" = "up=True up=False up=False" ]; t $? "$p[ⓚ] 실제 Test-DesktopShellUp — 이 세션 탐색기만 True(다른 세션만·없음 = False)" "$o"
  o="$(line "$R" i-HighestAvailable)"; [ "$o" = "rl=[HighestAvailable]" ]; t $? "$p[ⓘ] RunLevel 글자를 XML 에서 읽는다" "$o"
  o="$(line "$R" i-none)"; [ "$o" = "rl=[]" ]; t $? "$p[ⓘ] 작업 없음(rc 1) = 빈 값" "$o"
}

echo "── 실물 ──"
axes "$PS" ""
real_fail=$fail

# ⓙ 돌연변이 — 각 돌연변이는 위 축 중 하나 이상에서 FAIL 이어야 한다(시험이 실제로 무는가)
echo "── 돌연변이(FAIL 이 나야 정상) ──"
mut() { # mut <이름> <python 치환식 old> <new>
  local m="$BASE/mut-$1.ps1"
  python3 - "$PS" "$m" "$2" "$3" <<'PY'
import sys
s = open(sys.argv[1], encoding="utf-8-sig").read()
old, new = sys.argv[3], sys.argv[4]
if s.count(old) != 1: sys.exit(3)
open(sys.argv[2], "w", encoding="utf-8-sig").write(s.replace(old, new))
PY
  [ $? -eq 0 ] || { t 1 "[ⓙ $1] 돌연변이 자리 찾기" "치환 대상이 정확히 1곳이 아님"; return; }
  local p0=$pass f0=$fail
  axes "$m" "    (mut $1) " >/dev/null
  local caught=$((fail - f0))
  pass=$p0; fail=$f0
  [ "$caught" -gt 0 ]; t $? "[ⓙ $1] 돌연변이를 잡는다(FAIL $caught 축)" "돌연변이가 모든 축을 통과 — 시험이 안 문다"
}
mut always-plain "    if (-not \$Elevated) { return 'plain' }" "    return 'plain'"
mut no-explorer-branch "    if (\$plan -eq 'explorer') {" "    if (\$false) {"
mut no-device-admin "    if (\$AppTaskRunLevel -eq 'HighestAvailable') { return 'keep:device-admin' }" ""

mut shell-always-false "        return (@(Get-Process -Name 'explorer' -ErrorAction SilentlyContinue | Where-Object { \$_.SessionId -eq \$sid }).Count -gt 0)" "        return \$false"
mut no-session-filter "Where-Object { \$_.SessionId -eq \$SessionId })) {" "Where-Object { \$true })) {"
mut no-final-check "        if ((Get-ShellWaitElapsedMs \$sw) -ge 10000) { return \$false }   # 마감 시점에도 위에서 한 번 더 봤다" "        if ((Get-ShellWaitElapsedMs \$sw) -ge 9500) { return \$false }"
mut no-other-user "    if (\$ShellOwner -eq 'other') { return 'keep:other-user' }" ""
mut owner-always-same "            if (-not [string]::Equals(\$o, \$me, [StringComparison]::OrdinalIgnoreCase)) { \$others++ }" "            if (\$false) { \$others++ }"
mut mixed-first-same "        if (\$others -gt 0) { return 'other' }" "        if ((\$others -gt 0) -and (\$seen -eq \$others)) { return 'other' }"
mut plain-measures "        \$e = if (\$Plan -eq 'plain') { '0' } else { Get-CysAppElevation \$Exe }" "        \$e = Get-CysAppElevation \$Exe"

mut no-cim-fallback "        if (-not \$path) {" "        if (\$false) {"

printf '\n통과 %s · 실패 %s\n' "$pass" "$fail"
[ "$fail" -eq 0 ]
