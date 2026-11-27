#!/bin/bash
# [9/10] 자동 복원 경합 시험 — 맥판 bootstrap.sh 의 wait_auto_restore_settled (0.3.50).
#
# 무엇을 재는가 (맥 VM rc3 실기 11-25 · 링 기록 seq 8964·8968·8985)
#   [8/10] 이 데몬을 새로 띄우면 데몬은 지난 자리를 명부 순서대로 되살린다(worker → master → cso).
#   앞 판은 그 도중(worker 만 선 때)에 master 자리를 새로 열어 옛 master 대화(--resume)를 밀어냈다.
#   ① restore-race  — 복원 중이면 기다리고, 지난 master 자리가 되살아나면 새 자리를 열지 않고 이어 받기 갈래로 간다
#   ② 대조군         — 같은 시나리오를 고침 전 판(48e812c 원본 · 또는 기다림 한 줄을 뺀 변이)으로 돌리면 새 master 를 연다(= rc3 결함 재현)
#   ③ restore-stuck — 상한에 닿으면 종전대로 연다(설치가 멈추지 않는다 · fail-open)
#   ④ 칸 없음(옛 cys · 빈 답) — 기다리지 않는다 · 화면 줄 0 · 종전 그대로
#   ⑤ 판독 — 다듬은 JSON · 한 줄 JSON · 칸 없음
#   ⑥ 순서 — step_wake 안에서 open_cys_app → wait_auto_restore_settled → set_fleet_baseline → cys_open_master_seat
#
#   ⑦~⑩ 윈판(bootstrap.ps1 Wait-AutoRestoreSettled) — 같은 갈래를 pwsh 7 로(tests/awaken-emu/fleet.ps1 흉내 · 실물 Step-Wake)
#
# 쓰는 법: bash tests/wake-restore-race-run.sh [--dir <install-master 자리>] [--base <대조군 bootstrap.sh>] [--base-ps <대조군 bootstrap.ps1>]
#   rc 0 = 전건 통과 · 1 = 실패 있음 · 2 = 맥 구역 통과인데 윈 구역을 잴 수 없음(pwsh 없음)
# ⛔바깥에 닿지 않는다 — 실제 cys·claude·open·osascript 호출 0 · 쓰기는 mktemp -d 안에서만.
export JARVIS_NO_PROGRESS=1
set -u
HERE="$(cd "$(dirname "$0")" && pwd)"
DIR="$HERE/../install-master"
BASEF=""
BASEPS=""
while [ $# -gt 0 ]; do
  case "$1" in
    --dir) DIR="$2"; shift 2 ;;
    --base) BASEF="$2"; shift 2 ;;
    --base-ps) BASEPS="$2"; shift 2 ;;
    *) echo "모르는 인자: $1" >&2; exit 2 ;;
  esac
done
SHF="$(cd "$DIR" && pwd)/bootstrap.sh"
EMU="$HERE/awaken-emu"
BASE="$(mktemp -d -t wake-restore-race)" || exit 2
BASE="$(cd "$BASE" && pwd -P)" || exit 2
cleanup() { rm -rf "$BASE"; }
trap cleanup EXIT
pass=0; fail=0
ok()  { pass=$((pass+1)); printf '  ok   %s\n' "$1"; }
bad() { fail=$((fail+1)); printf '  FAIL %s  ← %s\n' "$1" "$2"; }
t() { if [ "$1" -eq 0 ]; then ok "$2"; else bad "$2" "$3"; fi; }

# run_case <이름> <시나리오> <bootstrap.sh> [덧붙일 설정 줄]
run_case() {
  local name="$1" scen="$2" shf="$3" extra="${4:-}"
  SB="$BASE/$name"; mkdir -p "$SB/bin" "$SB/home" "$SB/cys.app"
  cp "$EMU/fake-cys.sh" "$SB/bin/cys"; chmod +x "$SB/bin/cys"
  printf '#!/bin/bash\necho "EMU-CLAUDE-INLINE"\nexit 0\n' > "$SB/bin/claude"; chmod +x "$SB/bin/claude"
  printf '#!/bin/bash\nprintf "%%s\\n" "$*" >> "%s/osascript-calls"\nexit 0\n' "$SB" > "$SB/bin/osascript"; chmod +x "$SB/bin/osascript"
  printf '#!/bin/bash\necho "open $*" >> "%s/open-calls"\nexit 0\n' "$SB" > "$SB/bin/open"; chmod +x "$SB/bin/open"
  JH="$SB/home/install-jarvis"
  printf '%s' "$scen" > "$SB/scenario"; printf '%s' "$JH" > "$SB/jarvis-home"
  cat > "$SB/run.sh" <<EOF
. "$shf" || exit 9
CYS_CLI=cys; MODE=full; CYS_KIND=fork; CYS_FORK_APP="$SB/cys.app"; CYS_APP_OPEN_WAIT_SEC=2
FLEET_POLL_SEC=0; FLEET_AWAKE_TRIES=3; FLEET_WAIT_TRIES=2
CHILD_AWAKE_GAPS='0 0 0'; CHILD_AWAKE_GRACE_SEC=2; CHILD_AWAKE_CAP_SEC=8
MASTER_AWAKE_CAP_SEC=2; MASTER_AWAKE_POLL_SEC=0; MASTER_RETRY_CAP_SEC=2
RESTORE_SETTLE_POLL_SEC=0
# rc3 와 같이 [8/10] 이 데몬을 새로 띄운 뒤다(앞뒤 pid 다름 → 재설치 rotate 생략)
ROTATE_PLAN="skip:pid"; DAEMON_PID_BEFORE=44224; DAEMON_PID_AFTER=67174
$extra
mkdir -p "$JH"
step_wake
echo "TEST wake rc=\$?"
EOF
  PATH="$SB/bin:$PATH" HOME="$SB/home" JARVIS_HOME="$JH" JARVIS_LIB_ONLY=1 \
    perl -e 'alarm shift; exec @ARGV' 90 bash "$SB/run.sh" </dev/null >"$SB/out.txt" 2>"$SB/err.txt"
  O="$SB/out.txt"; L="$JH/bootstrap.log"
}
opened_new_master() { [ -f "$SB/opened" ] && grep -q 'cysr 안에서 자비스를 열었습니다 (surface:9)' "$O"; }
resumed_branch() { [ ! -f "$SB/opened" ] && grep -q '자비스는 이미 열려 있는 cysr 앱 안에 있습니다' "$O" && ! grep -q 'EMU-CLAUDE-INLINE' "$O"; }

echo "== ① restore-race — 복원 중 기다림 → 되살아난 master 를 이어 받음 =="
run_case fix-race restore-race "$SHF"
grep -q '^TEST wake rc=0' "$O" && grep -q '^다음에 할 일: ' "$O"
t $? "[①] 흉내가 끝까지 돌았다(깨우기 → 끝맺음 · rc 0)" "$(grep '^TEST' "$O") err: $(head -c 200 "$SB/err.txt" | tr '\n' '|')"
resumed_branch
t $? "[①] 새 master 자리를 열지 않았다 · 이어 받기 갈래(「이미 열려 있는 cysr 앱 안」) · 이 창에서도 안 띄움" "opened=$([ -f "$SB/opened" ] && echo 1 || echo 0) · $(grep -nE '열었습니다|이미 열려|EMU-CLAUDE' "$O" | tr '\n' '|' | cut -c1-200)"
grep -qE 'auto-restore wait: master restored \(surface:5\) phase=running polls=2 ' "$L"
t $? "[①] 기다림은 지난 master(surface:5)가 보인 순간 끝남(단계는 아직 running · status 3번째)" "$(grep 'auto-restore wait' "$L" | tr '\n' '|')"
grep -qE 'fleet baseline surfaces: surface:3 surface:4 surface:5 $' "$L"
t $? "[①] 기준선은 기다림 뒤에 찍힘 — 되살아난 worker·master 자리가 기준선 안(이번 설치의 자리로 안 셈)" "$(grep 'fleet baseline' "$L")"
[ "$(grep -c '지난 자비스 창들을 되살리는 중입니다' "$O")" = 1 ]
t $? "[①] 화면 줄 「되살리는 중 · 기다립니다」 는 한 번만" "$(grep -c '되살리는 중' "$O")"
grep -q 'seat claim denied: ' "$L" && grep -q '자비스가 새 판으로 이미 다시 깨어났습니다' "$O"
t $? "[①] 자리 열기는 데몬이 거절(claim_denied) → rc2 와 같은 끝맺음(「새 판으로 이미 다시 깨어났습니다」 · rotate 생략)" "$(grep -E 'seat claim|reinstall rotate' "$L" | tr '\n' '|' | cut -c1-200)"

echo "== ② 대조군 — 같은 시나리오 · 고침 전 판 =="
MUT="$BASE/bootstrap-mutant.sh"
# 변이 = 기다림 부르는 줄 하나만 뺀 판(정의는 남긴다) — 이 줄이 결함을 막는 그 줄인지 잰다
grep -vE '^    wait_auto_restore_settled "\$cli"$' "$SHF" > "$MUT"
[ "$(grep -cE '^    wait_auto_restore_settled "\$cli"$' "$SHF")" = 1 ] && [ "$(wc -l < "$SHF")" -eq $(( $(wc -l < "$MUT") + 1 )) ]
t $? "[②] 전제: 부르는 줄이 정확히 한 곳 · 변이는 그 한 줄만 다름" "$(grep -nE 'wait_auto_restore_settled "\$cli"' "$SHF" | tr '\n' '|')"
run_case mut-race restore-race "$MUT"
opened_new_master && ! grep -q 'auto-restore wait' "$L"
t $? "[②] 변이(기다림 없음) = 새 master surface:9 를 엶(rc3 결함 재현 · 이 시험이 그 결함을 잡는다)" "opened=$([ -f "$SB/opened" ] && echo 1 || echo 0) · $(grep -n '열었습니다' "$O" | head -1)"
if [ -n "$BASEF" ]; then
  run_case base-race restore-race "$BASEF"
  opened_new_master
  t $? "[②] 고침 전 원본($(basename "$BASEF")) = 새 master surface:9 를 엶(rc3 결함 재현)" "opened=$([ -f "$SB/opened" ] && echo 1 || echo 0)"
fi

echo "== ③ restore-stuck — 상한에 닿으면 종전대로 연다 =="
run_case fix-stuck restore-stuck "$SHF" "RESTORE_SETTLE_CAP_SEC=1; RESTORE_SETTLE_POLL_SEC=1"
grep -qE 'auto-restore wait: cap 1s phase=running polls=[0-9]+ -> open seat anyway$' "$L" && opened_new_master
t $? "[③] 상한 기록 1줄 → 자리를 연다(surface:9 · 설치가 멈추지 않음)" "$(grep 'auto-restore wait' "$L" | tr '\n' '|') opened=$([ -f "$SB/opened" ] && echo 1 || echo 0)"
# 이 흉내는 동료가 끝내 안 서는 모양이라 끝 코드는 종전 함대 상한 갈래의 값이다(rc 0 을 요구하지 않는다) — 재는 것은 「멈추지 않고 끝맺음까지 감」
grep -q '^TEST wake rc=' "$O" && grep -q '^다음에 할 일: ' "$O"
t $? "[③] 멈추지 않고 끝맺음까지 감" "$(grep '^TEST' "$O") err: $(head -c 200 "$SB/err.txt" | tr '\n' '|')"

echo "== ④ 칸 없음(옛 cys · 빈 답) — 기다리지 않는다 =="
run_case fix-success success "$SHF"
grep -qE 'auto-restore wait: settled phase=unknown polls=0 waited=[0-9]+s$' "$L" && ! grep -q '되살리는 중' "$O" && opened_new_master
t $? "[④] 기록 1줄(phase=unknown polls=0) · 화면 줄 0 · 종전대로 surface:9 를 엶" "$(grep 'auto-restore wait' "$L" | tr '\n' '|')"
grep -q '자비스가 깨어났습니다 — 이제 설치 창을 닫으셔도 됩니다' "$O"
t $? "[④] 첫 설치 성공 끝맺음 그대로(동료 섬 · 「깨어났습니다」)" "$(grep -n '깨어났' "$O" | head -2 | tr '\n' '|')"

echo "== ④-2 조회 실패(독립 검증 N3) — 한 번으로 끝내지 않음 · 연속 3번이면 끝 =="
run_case fix-flaky restore-flaky "$SHF"
grep -qE 'auto-restore wait: master restored \(surface:5\) phase=running polls=2 ' "$L" && ! grep -q 'phase=unreadable' "$L" && resumed_branch
t $? "[④-2] 실패 2번(실패한 출력의 done 은 읽지 않음) 뒤 running → 지난 master 이어 받음 · 새 master 안 엶" "$(grep 'auto-restore wait' "$L" | tr '\n' '|') opened=$([ -f "$SB/opened" ] && echo 1 || echo 0)"
run_case fix-unreadable restore-unreadable "$SHF"
grep -qE 'auto-restore wait: settled phase=unreadable fails=3 polls=2 waited=[0-9]+s$' "$L" && [ "$(cat "$SB/statuscalls")" = 3 ] && opened_new_master
t $? "[④-2] 늘 실패 → 3번째 실패에서 끝(기록 1줄 · status 3번) · 종전대로 surface:9" "$(grep 'auto-restore wait' "$L" | tr '\n' '|') calls=$(cat "$SB/statuscalls" 2>/dev/null)"

echo "== ⑤ 판독 — auto_restore_phase_of =="
P="$BASE/parse"; mkdir -p "$P/bin" "$P/home"
probe() { # probe <cys 가 찍을 글> → 판독값
  printf '#!/bin/bash\n[ "$1" = status ] && cat "%s/body"\nexit 0\n' "$P" > "$P/bin/cys"; chmod +x "$P/bin/cys"
  printf '%s' "$1" > "$P/body"
  # ⚠`set --` = 이 파일의 인자 읽기가 source 의 인자(파일 경로)를 설치 인자로 읽지 않게(awaken-emu-run.sh MAC_RETRY_MSG 와 같은 꼴)
  PATH="$P/bin:$PATH" HOME="$P/home" JARVIS_HOME="$P/home/install-jarvis" JARVIS_LIB_ONLY=1 \
    bash -c 'f="$1"; set --; . "$f" >/dev/null 2>&1; trap - EXIT; auto_restore_phase_of cys' _ "$SHF" 2>/dev/null
}
[ "$(probe $'{\n  "daemon": {\n    "auto_restore": "retry_wait",\n    "build_id": "x"\n  }\n}')" = retry_wait ]
t $? "[⑤] 다듬은 JSON → retry_wait" ""
[ "$(probe '{"daemon":{"auto_restore":"held","x":1}}')" = held ]
t $? "[⑤] 한 줄 JSON → held" ""
[ -z "$(probe '{"daemon":{"version":"1.1.15"}}')" ]
t $? "[⑤] 칸 없음 → 빈 값(기다리지 않음)" ""

echo "== ⑥ 순서 — step_wake 안 =="
awk '/^step_wake\(\) \{/{in_f=1} in_f && /^}/{in_f=0}
     in_f && /^    open_cys_app$/{a=NR} in_f && /^    wait_auto_restore_settled "\$cli"$/{b=NR}
     in_f && /^    set_fleet_baseline "\$cli"$/{c=NR} in_f && /ref="\$\(cys_open_master_seat "\$cmd_line"\)"/{d=NR}
     END{exit !(a && b && c && d && a < b && b < c && c < d)}' "$SHF"
t $? "[⑥] open_cys_app → wait_auto_restore_settled → set_fleet_baseline → cys_open_master_seat" "$(grep -nE '^    open_cys_app$|^    wait_auto_restore_settled|^    set_fleet_baseline "\$cli"|cys_open_master_seat "\$cmd_line"' "$SHF" | tr '\n' '|')"

# ══ 윈판(bootstrap.ps1 · Wait-AutoRestoreSettled) — pwsh 7 로 실물 Step-Wake 를 tests/awaken-emu/fleet.ps1 흉내로 부른다 ══
PW="$(command -v pwsh 2>/dev/null)"
PSF="$(cd "$DIR" && pwd)/bootstrap.ps1"
win_skip=0
if [ -z "$PW" ]; then
  echo "잴 수 없음(윈판 구역): pwsh 가 없다" >&2; win_skip=1
else
  # run_win <이름> <시나리오> <bootstrap.ps1> [상한 초]
  run_win() {
    SB="$BASE/win-$1"; mkdir -p "$SB"
    EMU_ROTATE_PLAN="skip:pid" EMU_RESTORE_CAP="${4:-}" EMU_RESTORE_POLL="${4:+1}" JARVIS_NO_PROGRESS=1 \
      perl -e 'alarm shift; exec @ARGV' 120 "$PW" -NoProfile -File "$EMU/fleet.ps1" -Src "$3" -Scenario "$2" -Sb "$SB" </dev/null >"$SB/out.txt" 2>"$SB/err.txt"
    JH="$(cat "$SB/jarvis-home" 2>/dev/null)"; L="$JH/bootstrap.log"; O="$SB/out.txt"
  }
  w_opened_new() { [ -f "$SB/opened" ] && grep -q 'cysr 안에서 자비스를 열었습니다 (surface:9)' "$L"; }
  w_resumed() { [ ! -f "$SB/opened" ] && grep -q '자비스는 이미 열려 있는 cysr 앱 안에 있습니다' "$L" && ! grep -q 'EMU-CLAUDE-INLINE' "$O"; }

  echo "== ⑦ 윈 restore-race — 복원 중 기다림 → 되살아난 master 를 이어 받음 =="
  run_win fix-race restore-race "$PSF"
  grep -q 'TEST finally' "$L" 2>/dev/null
  t $? "[⑦ 윈] 흉내가 끝까지 돌았다(Step-Wake → 끝맺음)" "err: $(head -c 200 "$SB/err.txt" | tr '\n' '|')"
  w_resumed
  t $? "[⑦ 윈] 새 master 자리를 열지 않았다 · 이어 받기 갈래 · 이 창에서도 안 띄움" "opened=$([ -f "$SB/opened" ] && echo 1 || echo 0) · $(grep -nE '열었습니다|이미 열려' "$L" | tr '\n' '|' | cut -c1-200)"
  grep -qE 'auto-restore wait: master restored \(surface:5\) phase=running polls=2 ' "$L"
  t $? "[⑦ 윈] 기다림은 지난 master(surface:5)가 보인 순간 끝남(단계는 아직 running · status 3번째)" "$(grep 'auto-restore wait' "$L" | tr '\n' '|')"
  grep -qE 'fleet baseline surfaces: surface:3 surface:4 surface:5$' "$L"
  t $? "[⑦ 윈] 기준선은 기다림 뒤 — 되살아난 worker·master 자리가 기준선 안" "$(grep 'fleet baseline' "$L")"
  [ "$(grep -c '지난 자비스 창들을 되살리는 중입니다' "$L")" = 1 ]
  t $? "[⑦ 윈] 화면 줄 「되살리는 중 · 기다립니다」 는 한 번만" "$(grep -c '되살리는 중' "$L")"
  grep -q 'seat claim denied: ' "$L" && grep -q '자비스가 새 판으로 이미 다시 깨어났습니다' "$L"
  t $? "[⑦ 윈] 자리 열기는 claim_denied → 「새 판으로 이미 다시 깨어났습니다」(rotate 생략)" "$(grep -E 'seat claim|rotate' "$L" | tr '\n' '|' | cut -c1-200)"

  echo "== ⑧ 윈 대조군 — 같은 시나리오 · 고침 전 판 =="
  WMUT="$BASE/bootstrap-mutant.ps1"
  grep -vE '^    \[void\]\(Wait-AutoRestoreSettled \$cli\)$' "$PSF" > "$WMUT"
  [ "$(grep -cE '^    \[void\]\(Wait-AutoRestoreSettled \$cli\)$' "$PSF")" = 1 ] && [ "$(wc -l < "$PSF")" -eq $(( $(wc -l < "$WMUT") + 1 )) ]
  t $? "[⑧ 윈] 전제: 부르는 줄이 정확히 한 곳 · 변이는 그 한 줄만 다름" "$(grep -nE 'Wait-AutoRestoreSettled \$cli' "$PSF" | tr '\n' '|')"
  run_win mut-race restore-race "$WMUT"
  w_opened_new && ! grep -q 'auto-restore wait' "$L"
  t $? "[⑧ 윈] 변이(기다림 없음) = 새 master surface:9 를 엶(결함 재현)" "opened=$([ -f "$SB/opened" ] && echo 1 || echo 0) · err: $(head -c 160 "$SB/err.txt" | tr '\n' '|')"
  if [ -n "$BASEPS" ]; then
    run_win base-race restore-race "$BASEPS"
    w_opened_new
    t $? "[⑧ 윈] 고침 전 원본($(basename "$BASEPS")) = 새 master surface:9 를 엶(결함 재현)" "opened=$([ -f "$SB/opened" ] && echo 1 || echo 0)"
  fi

  echo "== ⑨ 윈 restore-stuck · 칸 없음 =="
  run_win fix-stuck restore-stuck "$PSF" 1
  grep -qE 'auto-restore wait: cap 1s phase=running polls=[0-9]+ -> open seat anyway$' "$L" && w_opened_new && grep -q 'TEST finally' "$L"
  t $? "[⑨ 윈] 상한 기록 1줄 → 자리를 엶(surface:9) · 끝맺음까지 감" "$(grep 'auto-restore wait' "$L" | tr '\n' '|') opened=$([ -f "$SB/opened" ] && echo 1 || echo 0)"
  run_win fix-success success "$PSF"
  grep -qE 'auto-restore wait: settled phase=unknown polls=0 waited=[0-9]+s$' "$L" && ! grep -q '되살리는 중' "$L" && w_opened_new
  t $? "[⑨ 윈] 칸 없음 → 기록 1줄(phase=unknown polls=0) · 화면 줄 0 · 종전대로 surface:9" "$(grep 'auto-restore wait' "$L" | tr '\n' '|')"

  echo "== ⑨-2 윈 조회 실패(독립 검증 N3) =="
  run_win fix-flaky restore-flaky "$PSF"
  grep -qE 'auto-restore wait: master restored \(surface:5\) phase=running polls=2 ' "$L" && ! grep -q 'phase=unreadable' "$L" && w_resumed
  t $? "[⑨-2 윈] 실패 2번 뒤 running → 지난 master 이어 받음 · 새 master 안 엶" "$(grep 'auto-restore wait' "$L" | tr '\n' '|') opened=$([ -f "$SB/opened" ] && echo 1 || echo 0)"
  run_win fix-unreadable restore-unreadable "$PSF"
  grep -qE 'auto-restore wait: settled phase=unreadable fails=3 polls=2 waited=[0-9]+s$' "$L" && w_opened_new
  t $? "[⑨-2 윈] 늘 실패 → 3번째 실패에서 끝 · 종전대로 surface:9" "$(grep 'auto-restore wait' "$L" | tr '\n' '|')"

  echo "== ⑩ 윈 순서 — Step-Wake 안 =="
  awk '/^function Step-Wake \{/{in_f=1} in_f && /^}/{in_f=0}
       in_f && /^    Move-OldRound$/{a=NR} in_f && /^    \[void\]\(Wait-AutoRestoreSettled \$cli\)$/{b=NR} in_f && /^    Set-FleetBaseline \$cli$/{c=NR}
       END{exit !(a && b && c && a < b && b < c)}' "$PSF"
  t $? "[⑩ 윈] Move-OldRound → Wait-AutoRestoreSettled → Set-FleetBaseline" "$(grep -nE '^    Move-OldRound$|Wait-AutoRestoreSettled \$cli|^    Set-FleetBaseline \$cli$' "$PSF" | tr '\n' '|')"
fi

echo
echo "합계: 통과 $pass · 실패 $fail"
[ "$fail" -eq 0 ] || exit 1
[ "$win_skip" = 0 ] || exit 2
