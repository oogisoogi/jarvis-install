#!/bin/bash
# [10/10] 7분 자동 각성 고리의 1분 알림 — 맥·윈 짝 행동 시험 (0.3.50 · 사용자 진행 기록 11-19·11-26: 말없는 7분이 사람의 Ctrl-C·창 닫기를 불렀다)
#
# 재는 것(실물 step_fleet · Step-Fleet 을 함수 묶음으로 읽어 돈다 · 바퀴 간격 0 · 바퀴 수로 1분(= 2초 × 30)을 흉내)
#   ① 동료가 안 섬 · 고리 61바퀴 → 알림 2줄(30·60바퀴) · 마지막 바퀴 다음 줄 없음
#   ② 동료가 안 섬 · 고리 30바퀴 → 알림 0줄(마지막 바퀴 = 곧 다음 안내가 나오는 자리라 안 찍는다)
#   ③ 동료가 5바퀴째 섬(1분 안) → 알림 0줄
#   ④ 동료가 40바퀴째 섬(1분 넘음) → 알림 1줄 · 그 뒤 「함대가 섰습니다」
#   알림 글 = 「동료 자리를 기다리는 중입니다 (N분 지남 · 최대 M분 · 사람이 하실 일은 없습니다).」 — 기록(bootstrap.log)에서 센다(say/Say 는 화면과 기록에 같이 쓴다)
# 쓰는 법: bash tests/fleet-wait-heartbeat-run.sh [--dir <install-master 자리>]   · rc 0 = 통과 · 1 = 실패
# ⛔바깥에 닿지 않는다 — 가짜 HOME · JARVIS_LIB_ONLY · 진행 전송·자리 목록·master 확인·자식 확인·증거 전송을 바꿔 끼움 · 쓰기는 mktemp -d 안에서만.
set -u
HERE="$(cd "$(dirname "$0")" && pwd)"
DIR="$HERE/../install-master"
[ "${1:-}" = "--dir" ] && DIR="$2"
DIR="$(cd "$DIR" && pwd)"
SH="$DIR/bootstrap.sh"; PS="$DIR/bootstrap.ps1"
BASE="$(mktemp -d -t fleethb)" || exit 1
trap 'rm -rf "$BASE"' EXIT
pass=0; fail=0
t() { if [ "$1" -eq 0 ]; then pass=$((pass+1)); printf '  ok   %s\n' "$2"; else fail=$((fail+1)); printf '  FAIL %s  ← %s\n' "$2" "$3"; fi; }
PAT='동료 자리를 기다리는 중입니다 \([0-9]+분 지남 · 최대 [0-9]+분 · 사람이 하실 일은 없습니다\)\.'

# ── 맥 ──
mac_run() { # mac_run <이름> <고리 바퀴> <섬 바퀴(0 = 안 섬)>
  local sb="$BASE/mac-$1"; mkdir -p "$sb/home"
  cat > "$sb/run.sh" <<EOF
. '$SH' || exit 97
mkdir -p "\$JARVIS_HOME"
progress_send() { :; }
confirm_master_awake() { MASTER_STATE=verified; MASTER_MARK=True; MASTER_A=1; MASTER_RETRY=0; }
# 자리 목록은 \$(…) 하위 셸에서 불린다 — 바퀴 수는 변수가 아니라 파일에 센다(변수는 바깥에 안 남는다)
live_roles() { local n; n=\$(( \$(cat "$sb/lr" 2>/dev/null || echo 0) + 1 )); echo "\$n" > "$sb/lr"; if [ "$3" -gt 0 ] && [ "\$n" -ge "$3" ]; then printf 'master cso worker'; else printf 'master'; fi; }
note_daemon_group() { :; }; confirm_child_seats() { :; }; post_install_evidence() { :; }; raise_cys_app_window() { :; }
drain_tty_keys() { :; }; master_state_now() { :; }; set_fleet_finished() { :; }; set_fleet_needs_master() { :; }
MODE=full; FLEET_BASELINE_OK=1; FLEET_POLL_SEC=0; FLEET_AWAKE_TRIES=$2; FLEET_WAIT_TRIES=1
step_fleet 'surface:1'; echo "TEST rc=\$?"
EOF
  HOME="$sb/home" JARVIS_HOME="$sb/home/install-jarvis" JARVIS_LIB_ONLY=1 JARVIS_NO_PROGRESS=1 \
    perl -e 'alarm shift; exec @ARGV' 60 bash "$sb/run.sh" </dev/null >"$sb/out.txt" 2>"$sb/err.txt"
  MAC_N="$(grep -cE "$PAT" "$sb/home/install-jarvis/bootstrap.log" 2>/dev/null)"; MAC_N="${MAC_N:-0}"
  MAC_OUT="$sb/out.txt"
}
echo "== 맥 — step_fleet 7분 고리 1분 알림 =="
mac_run never61 61 0; grep -q '^TEST rc=' "$MAC_OUT"; r=$?
[ $r -eq 0 ] && [ "$MAC_N" = 2 ]; t $? "[맥 ①] 안 섬 · 61바퀴 → 알림 2줄" "알림 ${MAC_N}줄 · $(tail -c 200 "$MAC_OUT" | LC_ALL=C tr '\n' '|')"
mac_run never30 30 0; [ "$MAC_N" = 0 ]; t $? "[맥 ②] 안 섬 · 30바퀴(마지막 바퀴) → 알림 0줄" "알림 ${MAC_N}줄"
mac_run early 61 5; [ "$MAC_N" = 0 ] && grep -q '함대가 섰습니다' "$MAC_OUT"; t $? "[맥 ③] 5바퀴째 섬(1분 안) → 알림 0줄 · 함대가 섰습니다" "알림 ${MAC_N}줄"
mac_run late 61 40; [ "$MAC_N" = 1 ] && grep -q '함대가 섰습니다' "$MAC_OUT"; t $? "[맥 ④] 40바퀴째 섬(1분 넘음) → 알림 1줄 · 함대가 섰습니다" "알림 ${MAC_N}줄"

# ── 윈 짝 ──
if command -v pwsh >/dev/null 2>&1; then
  cat > "$BASE/w.ps1" <<'PSEOF'
param([string]$Src, [string]$Sb, [int]$Tries, [int]$StandAt)
$ErrorActionPreference = 'Continue'
$jh = "$Sb/home/install-jarvis"; New-Item -ItemType Directory -Force -Path $jh | Out-Null
$env:USERPROFILE = "$Sb/home"; $env:JARVIS_HOME = $jh; $env:JARVIS_NO_PROGRESS = '1'; $env:JARVIS_LIB_ONLY = '1'
. $Src
$env:JARVIS_LIB_ONLY = ''
function Send-Progress { param($a, $b, $c, $d, $e) }
function Confirm-MasterAwake { param($c, $r) return @{ state = 'verified'; mark = $true; a = 1; retry = 0 } }
function Write-MasterSay { param($m) }
$script:LrN = 0
function Get-LiveRoles { param($c) $script:LrN++; if (($StandAt -gt 0) -and ($script:LrN -ge $StandAt)) { return @('master', 'cso', 'worker') } else { return @('master') } }
function Confirm-ChildSeats { param($c) return $true }
function Send-PostInstallEvidence { param($c, $r) }
function Clear-FleetStrayKeys { }; function Set-FleetFinished { }; function Set-FleetNeedsMaster { }
$Mode = 'full'; $script:BaselineOk = $true; $FleetPollSec = 0; $FleetAwakeTries = $Tries; $FleetWaitTries = 1
$rc = @(Step-Fleet 'surface:1')[-1]
'TEST rc=' + $rc
PSEOF
  win_run() { # win_run <이름> <고리 바퀴> <섬 바퀴>
    local sb="$BASE/win-$1"; mkdir -p "$sb/home"
    perl -e 'alarm shift; exec @ARGV' 90 pwsh -NoProfile -File "$BASE/w.ps1" -Src "$PS" -Sb "$sb" -Tries "$2" -StandAt "$3" </dev/null >"$sb/out.txt" 2>"$sb/err.txt"
    WIN_N="$(grep -cE "$PAT" "$sb/home/install-jarvis/bootstrap.log" 2>/dev/null)"; WIN_N="${WIN_N:-0}"
    WIN_OUT="$sb/out.txt"
  }
  echo "== 윈 — Step-Fleet 7분 고리 1분 알림 (pwsh) =="
  win_run never61 61 0; grep -q '^TEST rc=' "$WIN_OUT"; r=$?
  [ $r -eq 0 ] && [ "$WIN_N" = 2 ]; t $? "[윈 ①] 안 섬 · 61바퀴 → 알림 2줄" "알림 ${WIN_N}줄 · $(tail -c 200 "$WIN_OUT" | LC_ALL=C tr '\n' '|') · err $(head -c 200 "$BASE/win-never61/err.txt" | LC_ALL=C tr '\n' '|')"
  win_run never30 30 0; [ "$WIN_N" = 0 ]; t $? "[윈 ②] 안 섬 · 30바퀴(마지막 바퀴) → 알림 0줄" "알림 ${WIN_N}줄"
  win_run early 61 5; [ "$WIN_N" = 0 ] && grep -q '함대가 섰습니다' "$BASE/win-early/home/install-jarvis/bootstrap.log"; t $? "[윈 ③] 5바퀴째 섬(1분 안) → 알림 0줄 · 함대가 섰습니다" "알림 ${WIN_N}줄"
  win_run late 61 40; [ "$WIN_N" = 1 ] && grep -q '함대가 섰습니다' "$BASE/win-late/home/install-jarvis/bootstrap.log"; t $? "[윈 ④] 40바퀴째 섬(1분 넘음) → 알림 1줄 · 함대가 섰습니다" "알림 ${WIN_N}줄"
else
  echo "  SKIP 윈 ①~④ — pwsh 없음"
fi
echo ""
echo "통과 $pass · 실패 $fail"
[ "$fail" -eq 0 ]
