#!/bin/bash
# 0.3.30 흉내 실행 시험 — 새 갈래를 **실제로 부른다**(글자 대조가 아니라 실행 · TICKET=installer-0330).
#
# 재는 것
#   ⓐ 윈 [8/10] Step-PrepareAccount 를 가짜 cys 로 네 갈래 실행(데몬 답 있음/없음 × 재기동 있음/없음):
#      A 답함·작업 등록 yes → daemon install 을 부르지 않는다 · 판정 run:same(rotate 부름)
#      B 답함·작업 등록 no · 등록이 재기동을 일으킴(pid 바뀜) → 등록만 부르고 판정 skip:pid(rotate 생략)
#      C 답 없음 → 등록 · 새 데몬이 뜸 → skip:fresh(rotate 생략)
#      D 답함·작업 등록 no · 등록이 재기동을 안 일으킴 → run:same
#   ⓑ 판정 함수(윈 Get-RotatePlan · 맥 rotate_plan)가 다섯 입력에서 글자까지 같다(pid 못 읽음 = run:unknown)
#   ⓒ rotate 경과 기록 — 가짜 rotate 가 drain·restore 자식을 부르면 기록에 「rotate stage 1-drain」·「5-restore」·
#      경과초 붙은 줄·rc 가 남는다 · 상한에 닿으면 「rotate stopped at: 1-drain」 한 줄 + timeout 판정(두 OS)
#
# 쓰는 법: bash tests/v0330-emu-run.sh [--dir <install-master 자리>]   rc 0 = 전건 통과 · 1 = 실패 · 2 = 잴 수 없음(pwsh 없음)
# ⛔바깥에 닿지 않는다 — 네트워크 0 · 앱 실행 0 · 실물 cys 무접촉(가짜 cys · 가짜 HOME).
# ⚠여기서 안 재는 것: 실물 윈 schtasks 덮어쓰기가 실행 중 데몬을 끊는가(실기 몫) · Get-CimInstance 자식 명령 읽기(윈 전용 — 맥 pwsh 는 ps 갈래를 탄다)
set -u
HERE="$(cd "$(dirname "$0")" && pwd)"
DIR="$HERE/../install-master"
while [ $# -gt 0 ]; do case "$1" in --dir) DIR="$2"; shift 2 ;; *) echo "모르는 인자: $1" >&2; exit 2 ;; esac; done
PS="$(cd "$DIR" && pwd)/bootstrap.ps1"
SH="$(cd "$DIR" && pwd)/bootstrap.sh"
PW="$(command -v pwsh 2>/dev/null)"
[ -n "$PW" ] || { echo "잴 수 없음: pwsh 가 없다" >&2; exit 2; }
BASE="$(mktemp -d -t v0330emu)" || exit 2
trap 'pkill -f "$BASE/" 2>/dev/null; rm -rf "$BASE"' EXIT
pass=0; fail=0
t() { if [ "$1" -eq 0 ]; then pass=$((pass+1)); printf '  ok   %s\n' "$2"; else fail=$((fail+1)); printf '  FAIL %s  ← %s\n' "$2" "$3"; fi; }

# ── 가짜 cys(데몬 상태 = 폴더 $S) — alive 파일이 있으면 ping 에 pong · pid 파일 = daemon_pid ──
#   daemon install 은 호출을 calls 에 적고, restart-on-install 이 있으면 pid 를 바꾸고, up-on-install 이 있으면 데몬을 띄운다.
cat > "$BASE/cys" <<'EOF'
#!/bin/bash
S="${FAKE_CYS_STATE:?}"
echo "$*" >> "$S/calls"
case "$1" in
  ping) [ -f "$S/alive" ] && { echo pong; exit 0; }; echo "error: no daemon" >&2; exit 1 ;;
  identify) [ -f "$S/alive" ] && { printf '{\n  "daemon_pid": %s\n}\n' "$(cat "$S/pid")"; exit 0; }; exit 1 ;;
  daemon) [ -f "$S/restart-on-install" ] && echo 22660 > "$S/pid"
          [ -f "$S/up-on-install" ] && { touch "$S/alive"; echo 30001 > "$S/pid"; }
          echo "작업 스케줄러 등록 완료"; exit 0 ;;
  init-pack) exit 0 ;;
  doctor) echo "  [OK  ] pack-version"; echo "요약: 1 OK · 0 WARN · 0 FAIL · 0 SKIP"; exit 0 ;;
  rotate)
    "$0" drain --verify --timeout 120 &  wait $!
    echo "[rotate] ① 저장 확인 1/1" >&2
    [ -f "$S/rotate-hang" ] && { "$0" hang-drain; exit 0; }
    "$0" restore --include-master & wait $!
    echo "재시작 완료 — 알림 (rc=0)"; exit 0 ;;
  drain) sleep 2; exit 0 ;;
  restore) sleep 2; exit 0 ;;
  hang-drain) exec -a "cys drain --verify" sleep 12 ;;
esac
exit 0
EOF
chmod +x "$BASE/cys"
mkcase() { # mkcase <이름> <alive 0|1> <pid> <표식...>
  local d="$BASE/st-$1"; mkdir -p "$d"; [ "$2" = 1 ] && touch "$d/alive"; echo "$3" > "$d/pid"; shift 3
  for f in "$@"; do touch "$d/$f"; done
}
mkcase A 1 14888
mkcase B 1 14888 restart-on-install
mkcase C 0 0 up-on-install
mkcase D 1 14888

echo "== 윈(ps1) [8/10] 네 갈래 =="
for c in A B C D; do
  task=yes; [ "$c" = B ] || [ "$c" = D ] && task=no
  [ "$c" = C ] && task=yes
  o="$(FAKE_CYS_STATE="$BASE/st-$c" JARVIS_LIB_ONLY=1 JARVIS_HOME="$BASE/wh-$c" perl -e 'alarm shift; exec @ARGV or exit 126' 120 "$PW" -NoProfile -Command ". '$PS' *> \$null;
function Write-Log([string]\$m) { Add-Content -LiteralPath '$BASE/wlog-$c' -Value \$m -Encoding UTF8 }
function Say(\$m) { Add-Content -LiteralPath '$BASE/wsay-$c' -Value \$m -Encoding UTF8 }
function Get-CysAutoStartState { param([string]\$CysCli = '') return '$task' }
function Set-AllProfiles { }
function Copy-LoginToIsolated { }
\$Mode = 'real'; \$script:CysCli = '$BASE/cys'; \$DaemonPingCapSec = 2
\$r = Step-PrepareAccount
Write-Output ('rc=' + \$r + ' plan=' + \$script:RotatePlan)
" 2>&1)"
  eval "W_$c=\"\$o\""
done
calls() { grep -c '^daemon install' "$BASE/st-$1/calls" 2>/dev/null; }
printf '%s' "$W_A" | grep -q 'rc=0 plan=run:same'; t $? "[윈 A] 답함·등록 yes → 계획 run:same(재기동 없음 → rotate)" "$W_A"
[ "$(calls A)" = 0 ]; t $? "[윈 A] daemon install 을 부르지 않는다(옛 데몬 정지 0)" "calls=$(calls A)"
grep -q '이미 돌고 있고 자동 시작도 등록돼 있어(작업 이름 cysd) 그대로 둡니다' "$BASE/wsay-A" 2>/dev/null; t $? "[윈 A] 정보 줄 1줄(0.3.32 C1 문구로 재조준 — 등록 사실을 한 줄에 함께)" "$(cat "$BASE/wsay-A" 2>/dev/null | tr '\n' '|')"
printf '%s' "$W_B" | grep -q 'rc=0 plan=skip:pid'; t $? "[윈 B] 답함·등록 no·등록이 재기동 → skip:pid" "$W_B"
[ "$(calls B)" = 1 ]; t $? "[윈 B] 등록만 1회 부른다" "calls=$(calls B)"
printf '%s' "$W_C" | grep -q 'rc=0 plan=skip:fresh'; t $? "[윈 C] 답 없음 → 등록 · 새 데몬 → skip:fresh" "$W_C"
[ "$(calls C)" = 1 ]; t $? "[윈 C] 등록 1회" "calls=$(calls C)"
printf '%s' "$W_D" | grep -q 'rc=0 plan=run:same'; t $? "[윈 D] 답함·등록 no·재기동 없음 → run:same" "$W_D"
grep -q '^daemon pid before=14888 after=22660 rotate plan=skip:pid$' "$BASE/wlog-B" 2>/dev/null; t $? "[윈 B] 기록에 앞뒤 pid 와 판정이 남는다" "$(grep 'daemon pid' "$BASE/wlog-B" 2>/dev/null)"
# 판정 요청(ping·identify)이 데몬을 띄우지 않게 묻는다 — 선확인은 CYS_NO_AUTOSTART 로(Invoke-CysCapped)
grep -q "Test-CysPong\|Invoke-CysCapped \$Cli 'ping'" "$PS"; t $? "[윈] 선확인 ping 은 상한·무기동(Invoke-CysCapped)" "-"

echo "== 판정 함수 두 OS 동형 =="
PW_OUT="$(JARVIS_LIB_ONLY=1 JARVIS_HOME="$BASE/wp" "$PW" -NoProfile -Command ". '$PS' *> \$null;
foreach (\$a in @(@(\$false,\$null,\$null), @(\$true,100,100), @(\$true,100,200), @(\$true,\$null,200), @(\$true,100,\$null))) { Write-Output (Get-RotatePlan \$a[0] \$a[1] \$a[2]) }" 2>/dev/null | tr '\n' ' ')"
mkdir -p "$BASE/home"
run_sh() { HOME="$BASE/home" TMPDIR="$BASE" JARVIS_HOME="$BASE/home/install-jarvis" JARVIS_LIB_ONLY=1 \
  perl -e 'alarm shift; exec @ARGV or exit 126' 120 bash -c ". '$SH' >/dev/null 2>&1; LOG_FILE='$1'; $2; exec >/dev/null 2>&1" 2>/dev/null; }   # 끝 exec = 설치기 EXIT 트랩의 끝맺음 글이 캡처에 섞이지 않게
SH_OUT="$(run_sh "$BASE/mlog0" 'rotate_plan 0 "" ""; rotate_plan 1 100 100; rotate_plan 1 100 200; rotate_plan 1 "" 200; rotate_plan 1 100 ""' | tr '\n' ' ')"
[ "$PW_OUT" = "skip:fresh run:same skip:pid run:unknown run:unknown " ]; t $? "[윈] Get-RotatePlan 다섯 입력" "[$PW_OUT]"
[ "$PW_OUT" = "$SH_OUT" ]; t $? "[동형] 맥 rotate_plan 이 글자까지 같다" "윈[$PW_OUT] 맥[$SH_OUT]"
SH_PID="$(FAKE_CYS_STATE="$BASE/st-B" run_sh "$BASE/mlog0" "daemon_pid_of '$BASE/cys'")"
[ "$SH_PID" = 22660 ]; t $? "[맥] daemon_pid_of 가 identify 의 daemon_pid 를 읽는다" "[$SH_PID]"

echo "== rotate 경과 기록 =="
mkcase R 1 1; mkcase H 1 1 rotate-hang
WR="$(FAKE_CYS_STATE="$BASE/st-R" JARVIS_LIB_ONLY=1 JARVIS_HOME="$BASE/wr" perl -e 'alarm shift; exec @ARGV or exit 126' 120 "$PW" -NoProfile -Command ". '$PS' *> \$null;
function Write-Log([string]\$m) { Add-Content -LiteralPath '$BASE/wlog-R' -Value \$m -Encoding UTF8 }
\$RotatePollMs = 200
Write-Output ('r=' + (Get-CysRotateState '$BASE/cys'))
\$RotateWallCapMs = 4000; \$RotateDrainHardMs = 6000; \$env:FAKE_CYS_STATE = '$BASE/st-H'
function Write-Log([string]\$m) { Add-Content -LiteralPath '$BASE/wlog-H' -Value \$m -Encoding UTF8 }
Write-Output ('h=' + (Get-CysRotateState '$BASE/cys'))
" 2>&1)"
printf '%s' "$WR" | grep -q '^r=ok'; t $? "[윈 R] 정상 rotate → ok" "$WR"
grep -q '^rotate stage 1-drain \[t=' "$BASE/wlog-R" && grep -q '^rotate stage 5-restore \[t=' "$BASE/wlog-R"; t $? "[윈 R] 단계 1-drain·5-restore 가 경과초와 함께 남는다" "$(tr '\n' '|' < "$BASE/wlog-R" 2>/dev/null)"
grep -q '^rotate \[t=[0-9]*s\] \[rotate\] ① 저장 확인 1/1$' "$BASE/wlog-R"; t $? "[윈 R] rotate 가 쓴 줄을 경과초와 함께 옮긴다" "$(tr '\n' '|' < "$BASE/wlog-R")"
grep -q '^rotate rc=0 \[t=[0-9]*s\] last stage=5-restore$' "$BASE/wlog-R"; t $? "[윈 R] 끝 줄 = rc·경과·마지막 단계" "$(tr '\n' '|' < "$BASE/wlog-R")"
printf '%s' "$WR" | grep -q '^h=timeout'; t $? "[윈 H] 상한 → timeout" "$WR"
grep -q '^rotate stopped at: 1-drain (since t=' "$BASE/wlog-H"; t $? "[윈 H] 멈춘 단계 한 줄(1-drain)" "$(tr '\n' '|' < "$BASE/wlog-H" 2>/dev/null)"

MR="$(FAKE_CYS_STATE="$BASE/st-R" run_sh "$BASE/mlog-R" "ROTATE_POLL_SEC=0.2; cys_rotate_state '$BASE/cys'")"
MH="$(FAKE_CYS_STATE="$BASE/st-H" run_sh "$BASE/mlog-H" "ROTATE_POLL_SEC=0.2; ROTATE_WALL_CAP_SEC=4; ROTATE_DRAIN_HARD_SEC=6; cys_rotate_state '$BASE/cys'")"
printf '%s' "$MR" | grep -q '^ok'; t $? "[맥 R] 정상 rotate → ok" "$MR"
grep -q ' rotate stage 1-drain \[t=' "$BASE/mlog-R" && grep -q ' rotate stage 5-restore \[t=' "$BASE/mlog-R"; t $? "[맥 R] 단계 1-drain·5-restore 가 경과초와 함께 남는다" "$(tr '\n' '|' < "$BASE/mlog-R" 2>/dev/null)"
grep -q ' rotate \[t=[0-9]*s\] \[rotate\] ① 저장 확인 1/1$' "$BASE/mlog-R"; t $? "[맥 R] rotate 가 쓴 줄을 경과초와 함께 옮긴다" "$(tr '\n' '|' < "$BASE/mlog-R")"
grep -q ' rotate rc=0 \[t=[0-9]*s\] last stage=5-restore$' "$BASE/mlog-R"; t $? "[맥 R] 끝 줄 = rc·경과·마지막 단계" "$(tr '\n' '|' < "$BASE/mlog-R")"
printf '%s' "$MH" | grep -q '^timeout'; t $? "[맥 H] 상한 → timeout" "$MH"
grep -q ' rotate stopped at: 1-drain (since t=' "$BASE/mlog-H"; t $? "[맥 H] 멈춘 단계 한 줄(1-drain)" "$(tr '\n' '|' < "$BASE/mlog-H" 2>/dev/null)"

printf '\n통과 %s · 실패 %s\n' "$pass" "$fail"
[ "$fail" -eq 0 ]
