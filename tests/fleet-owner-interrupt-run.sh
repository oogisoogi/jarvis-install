#!/bin/bash
# [10/10] 동료 대기 중 사람이 멈춘 끝(Ctrl-C)을 「원인 모를 실패(J-UNK-00)」로 보내지 않는가 — 맥·윈 짝 행동 시험
#   (TICKET=user-reports-fix-1119 · 근거 = 사용자 보고 11-19 맥 기기: 10:16:14 awaken:master-verified → 10:21:53 fail J-UNK-00 ·
#    10/10 end 줄 없음 = step_fleet 안에서 끝남 = fleet_on_interrupt 의 exit 130 이 끝맺음의 J-UNK-00 조건을 채웠다)
#
# 재는 것
#   맥 ⓐ 대기 중 Ctrl-C → 진행 이벤트 `10/10 info <초> awaken:owner-interrupt` 정확히 1건 · 초 = 숫자
#      ⓑ 같은 실행에 `fail … J-UNK-00` 0건
#      ⓒ 화면 문구 「설치 창의 기다림을 멈췄습니다」 그대로 · 끝 코드 130 그대로 · 기록 줄 「fleet: interrupted by owner」 그대로
#      ⓓ 대기 중 창 닫기(가상 터미널을 닫음 = HUP) → `10/10 info <초> awaken:owner-window-closed` 1건 · J-UNK-00 0건 · 「창이 닫혀 끝났습니다」 기록 그대로
#         (실측: 실제 창 닫기는 EXIT 트랩이 rc=1 로 돈다 — 신호만 보내는 killpg 재현의 rc 0 과 다르다 · 수리 전 = J-UNK-00)
#      ⓓ2 [10/10] 안(master 확인 대기 · 끊긴 명령 앞 rc 0)에서 창 닫기 → owner-window-closed 1 · J-UNK-00 0(끝 코드에 기대지 않는다)
#      ⓔ 진짜 실패 대조 셋 — 억제가 번지지 않는다: ⓔ1 대기 밖에서 코드 없이 끝남 · ⓔ2 대기 밖([3/10])에서 창 닫기 ·
#         ⓔ3 [10/10] 이 사람 중단 없이 rc=10 으로 끝남(동료 안 섬 · 사람 카드 대기도 넘김) → 셋 다 J-UNK-00 1건 · 사람 중단 표식 0건
#         ⚠ⓔ2 의 고리는 [10/10] 대기 고리와 같은 모양(검사 → sleep)이다 — 실측: 창 닫기 끝의 EXIT 트랩 rc 는 끊긴 sleep 바로 앞 명령의 결과다
#           (`while :; do sleep 1; done` = rc 0 → J-UNK-00 갈래에 닿지도 않아 대조가 무효였다 · 검사가 거짓인 고리 = rc 1 = [10/10] 과 같은 조건)
#   윈 ⓕ 대기 중 Ctrl-C(pwsh 가상 터미널) → `10/10|info|awaken:owner-interrupt` 정확히 1건 · J-UNK-00 0건
#      ⓖ 대조군(정상 끝 = 동료가 섬) → owner-interrupt 0건
# 쓰는 법: bash tests/fleet-owner-interrupt-run.sh [--dir <install-master 자리>]   · rc 0 = 통과 · 1 = 실패 · 2 = 측정 무효
# ⛔바깥에 닿지 않는다 — 가짜 HOME · JARVIS_LIB_ONLY · 진행 전송 함수를 기록 함수로 바꿔 끼움 · 띄운 무리는 번호로만 거둔다(이름 매칭 pkill 금지).
set -u
HERE="$(cd "$(dirname "$0")" && pwd)"
DIR="$HERE/../install-master"
[ "${1:-}" = "--dir" ] && DIR="$2"
DIR="$(cd "$DIR" && pwd)"
SH="$DIR/bootstrap.sh"; PS="$DIR/bootstrap.ps1"
BASE="$(mktemp -d -t fleetint)" || exit 2
trap 'rm -rf "$BASE"' EXIT
pass=0; fail=0; invalid=0
t() { if [ "$1" -eq 0 ]; then pass=$((pass+1)); printf '  ok   %s\n' "$2"; else fail=$((fail+1)); printf '  FAIL %s  ← %s\n' "$2" "$3"; fi; }

# ── 맥 자식: 실물 bootstrap.sh 를 함수 묶음으로 읽고(EXIT 트랩 = 실물 그대로) 실물 invoke_step_fleet 를 돈다 ──
#   흉내는 바깥에 닿는 셋뿐: 진행 전송(기록으로) · master 확인(verified 로 곧장) · 자리 목록(master 만 = 동료가 안 섬)
mk_child() { # mk_child <파일> <모드: wait|unk>
  cat > "$1" <<EOF
. '$SH' || exit 97
mkdir -p "\$JARVIS_HOME"
progress_send() { printf '%s|%s|%s|%s\n' "\${1:-}" "\${2:-}" "\${3:-}" "\${4:-}" >> "\$EV"; }
confirm_master_awake() { MASTER_STATE=verified; MASTER_MARK=True; MASTER_A=1; MASTER_RETRY=0; progress_send '10/10' 'info' '' 'awaken:master-verified' ''; }
live_roles() { printf 'master'; }
note_daemon_group() { :; }
MODE=full; FLEET_BASELINE_OK=1; FLEET_POLL_SEC=1
if [ "$2" = "unk" ]; then log "[3/10] (시험) 코드 없이 끝남"; exit 3; fi
if [ "$2" = "close3" ]; then say "[3/10] (시험) 기다리는 중"; log "fleet: auto awaken - watching (시험 표지 · 대기 밖)"; while :; do [ -e "\$JARVIS_HOME/never" ] && break; sleep 1; done; fi
if [ "$2" = "closem" ]; then confirm_master_awake() { log "fleet: auto awaken - watching (시험 표지 · master 확인 중 · 앞 명령 rc 0)"; while :; do :; sleep 1; done; }; fi
if [ "$2" = "rc10" ]; then FLEET_AWAKE_TRIES=1; FLEET_WAIT_TRIES=1; invoke_step_fleet 'surface:1'; exit \$?; fi
invoke_step_fleet 'surface:1'
EOF
}
cat > "$BASE/drive.py" <<'PY'
import os, pty, sys, time, signal, select
script, home, mode, out = sys.argv[1:5]
env = dict(os.environ, HOME=home, JARVIS_HOME=home + "/install-jarvis", JARVIS_LIB_ONLY="1", EV=home + "/ev")
env.pop("JARVIS_NO_PROGRESS", None)   # 기록 함수로 바꿔 끼웠으니 전송 끔 레버를 풀어야 이벤트가 셈에 든다(바깥 전송 0 — 함수가 파일에만 쓴다)
pid, fd = pty.fork()
if pid == 0:
    os.execve("/bin/bash", ["/bin/bash", script], env)
screen = b""; reaped = False; status = None
def drain(sec, until=None):
    global screen
    t_end = time.time() + sec
    while time.time() < t_end:
        if until and until(): return True
        r, _, _ = select.select([fd], [], [], 0.2)
        if r:
            try: screen += os.read(fd, 65536)
            except OSError: return bool(until and until())
    return bool(until and until())
def exited():
    global reaped, status
    if reaped: return True
    try:
        p, st = os.waitpid(pid, os.WNOHANG)
        if p == pid: reaped = True; status = os.waitstatus_to_exitcode(st)
    except ChildProcessError:
        reaped = True
    return reaped
log = home + "/install-jarvis/bootstrap.log"
reached = True
if mode in ("int", "close"):
    reached = drain(60, lambda: os.path.exists(log) and "fleet: auto awaken - watching" in open(log, encoding="utf-8", errors="replace").read())
    drain(2.5)                                # 대기 고리 안(sleep 중)에 닿게 — 기다린 초가 0 보다 크게
    if mode == "int":
        os.write(fd, b"\x03")                 # 사람이 설치 창에서 Ctrl-C
        drain(30, exited)
        os.close(fd)
    else:
        os.close(fd)                          # 창 닫기 = HUP
        for _ in range(150):
            if exited(): break
            time.sleep(0.2)
else:
    drain(60, exited); os.close(fd)
if not reaped:
    try: os.killpg(pid, signal.SIGKILL)       # 이 시험이 띄운 무리뿐(pty.fork = 새 세션 · 아직 거두기 전)
    except Exception: pass
    try:
        _, st = os.waitpid(pid, 0); status = os.waitstatus_to_exitcode(st)
    except Exception: pass
open(out, "w").write(repr({"reached": reached, "status": status, "screen": screen.decode("utf-8", "replace")}))
PY

ev_count() { grep -c -- "$2" "$1" 2>/dev/null || true; }

echo "== 맥 ⓐⓑⓒ — [10/10] 대기 중 Ctrl-C =="
mkdir -p "$BASE/hi"; mk_child "$BASE/ci.sh" wait
python3 "$BASE/drive.py" "$BASE/ci.sh" "$BASE/hi" int "$BASE/ri" 2>/dev/null
ri="$(cat "$BASE/ri" 2>/dev/null)"
case "$ri" in *"'reached': True"*) ;; *) echo "  측정 무효: 대기 고리에 닿지 못했다 — $(printf '%s' "$ri" | head -c 300)"; invalid=1 ;; esac
EVI="$BASE/hi/ev"
n="$(ev_count "$EVI" '^10/10|info|[0-9][0-9]*|awaken:owner-interrupt$')"
[ "$n" = 1 ]; t $? "[맥 ⓐ] owner-interrupt 진행 이벤트 정확히 1건(초 = 숫자)" "건수 $n · 이벤트: $(tr '\n' ';' < "$EVI" 2>/dev/null)"
n="$(ev_count "$EVI" '|fail|.*J-UNK-00')"
[ "$n" = 0 ]; t $? "[맥 ⓑ] 사람이 멈춘 끝에 J-UNK-00 실패 이벤트 0건" "건수 $n · 이벤트: $(tr '\n' ';' < "$EVI" 2>/dev/null)"
case "$ri" in *"설치 창의 기다림을 멈췄습니다"*) true ;; *) false ;; esac; t $? "[맥 ⓒ] 화면 문구 그대로" "화면에 없음"
case "$ri" in *"'status': 130"*) true ;; *) false ;; esac; t $? "[맥 ⓒ] 끝 코드 130 그대로" "$(printf '%s' "$ri" | grep -o "'status': [^,]*")"
grep -q 'fleet: interrupted by owner (Ctrl-C)' "$BASE/hi/install-jarvis/bootstrap.log" 2>/dev/null; t $? "[맥 ⓒ] 기록 줄 그대로" "bootstrap.log 에 없음"

echo "== 맥 ⓓ 대조 — [10/10] 대기 중 창 닫기(HUP) =="
mkdir -p "$BASE/hc"; mk_child "$BASE/cc.sh" wait
python3 "$BASE/drive.py" "$BASE/cc.sh" "$BASE/hc" close "$BASE/rc" 2>/dev/null
rc_="$(cat "$BASE/rc" 2>/dev/null)"
case "$rc_" in *"'reached': True"*) ;; *) echo "  측정 무효: 대기 고리에 닿지 못했다"; invalid=1 ;; esac
EVC="$BASE/hc/ev"
n1="$(ev_count "$EVC" '^10/10|info|[0-9][0-9]*|awaken:owner-window-closed$')"; n2="$(ev_count "$EVC" 'J-UNK-00')"; n3="$(ev_count "$EVC" 'awaken:owner-interrupt')"
[ "$n1" = 1 ] && [ "$n2" = 0 ] && [ "$n3" = 0 ]; t $? "[맥 ⓓ] 대기 중 창 닫기 = owner-window-closed 1(초 = 숫자) · J-UNK-00 0 · owner-interrupt 0" "owner-window-closed $n1 · J-UNK-00 $n2 · owner-interrupt $n3 · 이벤트: $(tr '\n' ';' < "$EVC" 2>/dev/null)"
grep -q '창이 닫혀 끝났습니다' "$BASE/hc/install-jarvis/bootstrap.log" 2>/dev/null; t $? "[맥 ⓓ] 창 닫기 기록 줄 그대로(다음 실행 = J-AV-03 판독)" "bootstrap.log 에 없음"

real_fail() { # real_fail <이름> <모드> <drive 모드> <설명>
  mkdir -p "$BASE/h$1"; mk_child "$BASE/c$1.sh" "$2"
  python3 "$BASE/drive.py" "$BASE/c$1.sh" "$BASE/h$1" "$3" "$BASE/r$1" 2>/dev/null
  local E="$BASE/h$1/ev" a b
  a="$(ev_count "$E" '|fail|.*J-UNK-00')"; b="$(ev_count "$E" 'awaken:owner-')"
  [ "$a" = 1 ] && [ "$b" = 0 ]; t $? "$4 = J-UNK-00 1 · 사람 중단 표식 0" "J-UNK-00 $a · 사람 중단 표식 $b · 이벤트: $(tr '\n' ';' < "$E" 2>/dev/null)"
}
echo "== 맥 ⓓ2 — [10/10] 안 master 확인 대기 중 창 닫기(끊긴 명령 앞 rc 0) =="
mkdir -p "$BASE/hm"; mk_child "$BASE/cm.sh" closem
python3 "$BASE/drive.py" "$BASE/cm.sh" "$BASE/hm" close "$BASE/rm" 2>/dev/null
case "$(cat "$BASE/rm" 2>/dev/null)" in *"'reached': True"*) ;; *) echo "  측정 무효: master 확인 대기에 닿지 못했다"; invalid=1 ;; esac
n1="$(ev_count "$BASE/hm/ev" '^10/10|info|[0-9][0-9]*|awaken:owner-window-closed$')"; n2="$(ev_count "$BASE/hm/ev" 'J-UNK-00')"
[ "$n1" = 1 ] && [ "$n2" = 0 ]; t $? "[맥 ⓓ2] 끝 코드 0 인 창 닫기도 owner-window-closed 1 · J-UNK-00 0" "owner-window-closed $n1 · J-UNK-00 $n2 · 이벤트: $(tr '\n' ';' < "$BASE/hm/ev" 2>/dev/null)"

echo "== 맥 ⓔ 진짜 실패 대조 =="
real_fail u1 unk keep "[맥 ⓔ1] 대기 밖에서 코드 없이 끝남(rc 3)"
real_fail u2 close3 close "[맥 ⓔ2] 대기 밖([3/10])에서 창 닫기"
real_fail u3 rc10 keep "[맥 ⓔ3] [10/10] 이 사람 중단 없이 rc=10 으로 끝남"
grep -q '^10/10|end|[0-9]*|rc=10$' "$BASE/hu3/ev" 2>/dev/null; t $? "[맥 ⓔ3] 그 실행이 실제로 [10/10] 을 rc=10 으로 끝냈다(측정 유효)" "이벤트: $(tr '\n' ';' < "$BASE/hu3/ev" 2>/dev/null)"

# ── 윈 짝: 실물 bootstrap.ps1 의 Invoke-StepFleet 를 pwsh 가상 터미널에서 돌리고 Ctrl-C ──
if command -v pwsh >/dev/null 2>&1; then
  cat > "$BASE/wdrive.ps1" <<'PSEOF'
param([string]$Src, [string]$Sb, [string]$Kind)
$ErrorActionPreference = 'Continue'
$jh = "$Sb/home/install-jarvis"
New-Item -ItemType Directory -Force -Path $jh | Out-Null
$env:USERPROFILE = "$Sb/home"; $env:JARVIS_HOME = $jh; $env:JARVIS_NO_PROGRESS = '1'; $env:JARVIS_LIB_ONLY = '1'
. $Src
$env:JARVIS_LIB_ONLY = ''
$evf = "$Sb/ev"
function Send-Progress { param($a, $b, $c, $d, $e) Add-Content -Path $evf -Value ('' + $a + '|' + $b + '|' + $c + '|' + $d) -Encoding utf8 }
function Confirm-MasterAwake { param($c, $r) Send-Progress '10/10' 'info' $null 'awaken:master-verified' $null; return @{ state = 'verified'; mark = $true; a = 1; retry = 0 } }
function Write-MasterSay { param($m) }
if ($Kind -eq 'ok') { function Get-LiveRoles { param($c) return @('master', 'cso', 'worker') } } else { function Get-LiveRoles { param($c) return @('master') } }
function Confirm-ChildSeats { param($c) return $true }
function Send-PostInstallEvidence { param($c, $r) }
function Update-HelpAttempts { }; function Invoke-RemoteHelp { }; function Write-HelpEscalation { }; function Show-RerunHow { }
$Mode = 'full'; $script:BaselineOk = $true; $FleetPollSec = 1
$script:JCode = ''; $script:ReachedWake = $true; $script:NextStep = ''
try { $rc = Invoke-StepFleet 'surface:1'; Add-Content -Path "$Sb/facts" -Value ('rc=' + $rc) -Encoding utf8 }
finally {
  Write-ClosingNote
  Add-Content -Path "$Sb/facts" -Value ('closing JCode=' + $script:JCode + ' NextStep=' + $script:NextStep) -Encoding utf8
}
PSEOF
  cat > "$BASE/wdrive.py" <<'PY'
import os, pty, sys, time, select, signal
drive, src, sb, kind = sys.argv[1:5]
log = os.path.join(sb, "home", "install-jarvis", "bootstrap.log")
pid, fd = pty.fork()
if pid == 0:
    os.execvp("pwsh", ["pwsh", "-NoProfile", "-File", drive, "-Src", src, "-Sb", sb, "-Kind", kind])
reaped = False
def pump(sec, until=None):
    t_end = time.time() + sec
    while time.time() < t_end:
        if until and until(): return True
        r, _, _ = select.select([fd], [], [], 0.2)
        if r:
            try: os.read(fd, 65536)
            except OSError: return bool(until and until())
    return bool(until and until())
def exited():
    global reaped
    if reaped: return True
    try:
        if os.waitpid(pid, os.WNOHANG)[0] == pid: reaped = True
    except ChildProcessError: reaped = True
    return reaped
def at_wait():
    try: return "fleet: auto awaken - watching" in open(log, encoding="utf-8", errors="replace").read()
    except FileNotFoundError: return False
ok = pump(90, at_wait)
if kind == "int":
    pump(2.5)
    os.write(fd, b"\x03")
pump(60, exited)
if not reaped:
    try: os.killpg(pid, signal.SIGKILL)
    except Exception: pass
    try: os.waitpid(pid, 0)
    except Exception: pass
print("REACHED" if ok else "NOT_REACHED")
PY
  echo "== 윈 ⓕ — [10/10] 대기 중 Ctrl-C (pwsh 가상 터미널) =="
  mkdir -p "$BASE/wi"
  r="$(python3 "$BASE/wdrive.py" "$BASE/wdrive.ps1" "$PS" "$BASE/wi" int 2>/dev/null)"
  [ "$r" = REACHED ] || { echo "  측정 무효: 윈 대기 고리에 닿지 못했다 ($r)"; invalid=1; }
  n="$(ev_count "$BASE/wi/ev" '^10/10|info|[0-9][0-9]*|awaken:owner-interrupt$')"
  [ "$n" = 1 ]; t $? "[윈 ⓕ] owner-interrupt 진행 이벤트 정확히 1건(초 = 숫자)" "건수 $n · 이벤트: $(tr '\n' ';' < "$BASE/wi/ev" 2>/dev/null)"
  n="$(ev_count "$BASE/wi/ev" 'J-UNK-00')"
  [ "$n" = 0 ]; t $? "[윈 ⓕ] J-UNK-00 0건" "건수 $n"
  echo "  (사실 기록) 윈 끝맺음: $(tr '\n' ' ' < "$BASE/wi/facts" 2>/dev/null)"
  echo "== 윈 ⓖ 대조 — 동료가 서서 정상 끝 =="
  mkdir -p "$BASE/wo"
  r="$(python3 "$BASE/wdrive.py" "$BASE/wdrive.ps1" "$PS" "$BASE/wo" ok 2>/dev/null)"
  n="$(ev_count "$BASE/wo/ev" 'awaken:owner-interrupt')"; m="$(ev_count "$BASE/wo/ev" '^10/10|end|')"
  [ "$n" = 0 ] && [ "$m" -ge 1 ]; t $? "[윈 ⓖ] 정상 끝 = owner-interrupt 0 · 10/10 end 있음" "owner-interrupt $n · end $m · 이벤트: $(tr '\n' ';' < "$BASE/wo/ev" 2>/dev/null)"
else
  echo "  SKIP 윈 ⓕⓖ — pwsh 없음"
fi

echo "통과 $pass · 실패 $fail"
[ "$invalid" = 1 ] && exit 2
[ "$fail" -eq 0 ]
