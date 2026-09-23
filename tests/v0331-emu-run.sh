#!/bin/bash
# 0.3.31 흉내 실행 시험 — rotate 결과를 rc 가 아니라 관측으로 가르는 갈래를 **실제로 부른다**(TICKET=installer-0331).
#
# 재는 것(두 OS · 가짜 cys · 가짜 데몬 상태 폴더)
#   A rc0            rotate 가 스스로 rc 0 → ok(종전대로)
#   B 멈춤+관측성공  드레인 뒤 새 데몬·새 자리 3이 섰는데 rotate 가 2-daemon-up 에서 안 끝남(09-21 18:57 윈 실기 모양)
#                    → 상한 전에 observed-ok · rotate 를 끊는다 · 근거 3줄(① ping ② pid ③ 자리) 기록
#   C 멈춤+관측실패  같은 멈춤인데 데몬·자리가 그대로 → 상한 → 마지막 관측 1회(3줄) → timeout(폴백)
#   D 드레인 보호    드레인이 시작되자마자 관측상 「성공」처럼 보여도 드레인 중엔 관측도 끊기도 하지 않는다 → rotate 가 스스로 rc 0
#   E 상한+관측성공  주기 관측이 상한 전에 안 돌아도 상한 뒤 마지막 관측이 성공을 건진다
#   F·G 판정 C     상한이 드레인 도중에 오면 연장 · 끝나면 관측 1회 → 성공 observed-ok / 실패 폴백(rotate 는 끊지 않는다)
#   ⓔ 판정 함수(윈 Get-RotateObserveVerdict · 맥 rotate_observe_verdict)가 여섯 입력에서 글자까지 같다
#
# 쓰는 법: bash tests/v0331-emu-run.sh [--dir <install-master 자리>]   rc 0 = 전건 통과 · 1 = 실패 · 2 = 잴 수 없음(pwsh 없음)
# ⛔바깥에 닿지 않는다 — 네트워크 0 · 앱 실행 0 · 실물 cys 무접촉(가짜 cys · 가짜 HOME).
# ⚠여기서 안 재는 것: 실물 cys 1.1.2 윈 rotate 의 stage 2 결함 자체(실기 몫) · Get-CimInstance 자식 명령 읽기(윈 전용 — 맥 pwsh 는 ps 갈래)
set -u
HERE="$(cd "$(dirname "$0")" && pwd)"
DIR="$HERE/../install-master"
while [ $# -gt 0 ]; do case "$1" in --dir) DIR="$2"; shift 2 ;; *) echo "모르는 인자: $1" >&2; exit 2 ;; esac; done
PS="$(cd "$DIR" && pwd)/bootstrap.ps1"
SH="$(cd "$DIR" && pwd)/bootstrap.sh"
PW="$(command -v pwsh 2>/dev/null)"
[ -n "$PW" ] || { echo "잴 수 없음: pwsh 가 없다" >&2; exit 2; }
BASE="$(mktemp -d -t v0331emu)" || exit 2
# ⚠정리는 이 실행의 폴더($BASE)가 든 프로세스만 — 가짜 이름에 상태 폴더($S · $BASE 아래)를 싣는다(dbg-D5 F8 · 전역 이름은 다른 worktree 의 동시 실행을 끈다).
trap 'pkill -f "$BASE/" 2>/dev/null; rm -rf "$BASE"' EXIT
pass=0; fail=0
t() { if [ "$1" -eq 0 ]; then pass=$((pass+1)); printf '  ok   %s\n' "$2"; else fail=$((fail+1)); printf '  FAIL %s  ← %s\n' "$2" "$3"; fi; }

# ── 가짜 cys(데몬 상태 = 폴더 $S) — pid 파일 = daemon_pid · list 파일 = cys list 글 · mode 파일 = rotate 모양 ──
cat > "$BASE/cys" <<'FAKE'
#!/bin/bash
S="${FAKE_CYS_STATE:?}"
echo "$*" >> "$S/calls"
newstate() { echo 27688 > "$S/pid"; printf 'surface:56\trole=master\tpid=1\texited=false\tm\nsurface:57\trole=cso\tpid=2\texited=false\tc\nsurface:58\trole=worker\tpid=3\texited=false\tw\n' > "$S/list"; }
case "$1" in
  ping) echo pong; exit 0 ;;
  identify) printf '{\n  "daemon_pid": %s\n}\n' "$(cat "$S/pid")"; exit 0 ;;
  list) cat "$S/list"; exit 0 ;;
  rotate)
    m="$(cat "$S/mode")"
    "$0" drain --verify --timeout 120 & wait $!
    echo "[rotate] 저장 확인 3/3" >&2
    case "$m" in
      rc0)   "$0" restore --include-master & wait $!; echo "재시작 완료 — 알림 (rc=0)"; exit 0 ;;
      stuck-ok)   newstate; "$0" hang-identify & wait $!; exit 0 ;;
      stuck-fail) "$0" hang-identify & wait $!; exit 0 ;;
      drain-guard) echo "드레인 뒤 끝 (rc=0)"; exit 0 ;;
      drain-long-ok)   newstate; "$0" hang-identify & wait $!; exit 0 ;;
      drain-long-fail) "$0" hang-identify & wait $!; exit 0 ;;
    esac ;;
  drain) case "$(cat "$S/mode")" in drain-long-*) exec -a "$S/v0331-fake-cys drain --verify" sleep 5 ;; esac
         if [ "$(cat "$S/mode")" = drain-guard ]; then newstate; exec -a "$S/v0331-fake-cys drain --verify" sleep 4; fi; sleep 1; exit 0 ;;
  restore) sleep 1; exit 0 ;;
  hang-identify) exec -a "$S/v0331-fake-cys identify --wait" sleep 40 ;;
esac
exit 0
FAKE
chmod +x "$BASE/cys"
mkcase() { # mkcase <폴더> <mode>
  local d="$BASE/$1"; rm -rf "$d"; mkdir -p "$d"; echo "$2" > "$d/mode"; echo 22660 > "$d/pid"
  printf 'surface:53\trole=master\tpid=1\texited=false\tm\nsurface:54\trole=cso\tpid=2\texited=false\tc\nsurface:55\trole=worker\tpid=3\texited=false\tw\n' > "$d/list"
}

mkdir -p "$BASE/home"
run_sh() { HOME="$BASE/home" TMPDIR="$BASE" JARVIS_HOME="$BASE/home/install-jarvis" JARVIS_LIB_ONLY=1 \
  perl -e 'alarm shift; exec @ARGV or exit 126' 120 bash -c ". '$SH' >/dev/null 2>&1; LOG_FILE='$1'; $2; exec >/dev/null 2>&1" 2>/dev/null; }

echo "== 맥(sh) 네 갈래 =="
for c in A:rc0 B:stuck-ok C:stuck-fail D:drain-guard; do
  k="${c%%:*}"; m="${c#*:}"; mkcase "m$k" "$m"
  s0=$SECONDS
  o="$(FAKE_CYS_STATE="$BASE/m$k" run_sh "$BASE/mlog-$k" "ROTATE_POLL_SEC=0.2; ROTATE_OBSERVE_SEC=1; ROTATE_WALL_CAP_SEC=12; cys_rotate_state '$BASE/cys'")"
  eval "M_$k=\"\$o\"; MT_$k=$((SECONDS - s0))"
done
printf '%s' "$M_A" | grep -q '^ok	0	재시작 완료'; t $? "[맥 A] rc 0 → ok(종전대로)" "$M_A"
printf '%s' "$M_B" | grep -q '^observed-ok	.*	자비스가 새 판으로 다시 깨어났습니다\.$'; t $? "[맥 B] 멈춤+관측성공 → observed-ok" "$M_B"
[ "$MT_B" -lt 12 ]; t $? "[맥 B] 상한(12s) 전에 끝난다" "${MT_B}s"
grep -q ' rotate observed-ok at stage 2-daemon-up ' "$BASE/mlog-B"; t $? "[맥 B] 드레인 뒤 단계에서 끊는다" "$(tr '\n' '|' < "$BASE/mlog-B")"
grep -q ' ① ping: pong=yes$' "$BASE/mlog-B" && grep -q ' ② daemon pid: 22660 -> 27688$' "$BASE/mlog-B" && grep -q ' ③ seats: old alive 0/3 · role alive 3 (surface:56 surface:57 surface:58)$' "$BASE/mlog-B"; t $? "[맥 B] 근거 3줄(① ping ② pid ③ 자리)" "$(grep observe "$BASE/mlog-B" | tr '\n' '|')"
printf '%s' "$M_C" | grep -q '^timeout'; t $? "[맥 C] 멈춤+관측실패 → timeout(폴백)" "$M_C"
grep -q ' rotate stopped at: 2-daemon-up ' "$BASE/mlog-C" && grep -q ' verdict=no:pid$' "$BASE/mlog-C" && grep -q ' ③ seats: old alive 3/3 ' "$BASE/mlog-C"; t $? "[맥 C] 상한 뒤 마지막 관측 3축이 기록된다" "$(tr '\n' '|' < "$BASE/mlog-C")"
printf '%s' "$M_D" | grep -q '^ok	0	'; t $? "[맥 D] 드레인 중엔 끊지 않는다 → rotate 가 스스로 rc 0" "$M_D"
! grep -q 'rotate observe' "$BASE/mlog-D"; t $? "[맥 D] 드레인 중 관측 0회" "$(grep observe "$BASE/mlog-D" | tr '\n' '|')"

echo "== 윈(ps1) 네 갈래 =="
for c in A:rc0 B:stuck-ok C:stuck-fail D:drain-guard; do
  k="${c%%:*}"; m="${c#*:}"; mkcase "w$k" "$m"
  s0=$SECONDS
  o="$(FAKE_CYS_STATE="$BASE/w$k" JARVIS_LIB_ONLY=1 JARVIS_HOME="$BASE/wh-$k" perl -e 'alarm shift; exec @ARGV or exit 126' 120 "$PW" -NoProfile -Command ". '$PS' *> \$null;
function Write-Log([string]\$m) { Add-Content -LiteralPath '$BASE/wlog-$k' -Value \$m -Encoding UTF8 }
\$RotatePollMs = 200; \$RotateObserveMs = 1000; \$RotateWallCapMs = 12000
Write-Output ('r=' + (Get-CysRotateState '$BASE/cys'))
" 2>&1)"
  eval "W_$k=\"\$o\"; WT_$k=$((SECONDS - s0))"
done
printf '%s' "$W_A" | grep -q '^r=ok	0	재시작 완료'; t $? "[윈 A] rc 0 → ok(종전대로)" "$W_A"
printf '%s' "$W_B" | grep -q '^r=observed-ok		자비스가 새 판으로 다시 깨어났습니다\.$'; t $? "[윈 B] 멈춤+관측성공 → observed-ok" "$W_B"
[ "$WT_B" -lt 16 ]; t $? "[윈 B] 상한(12s) 전에 끝난다(pwsh 기동 여유 4s)" "${WT_B}s"
grep -q '^rotate observed-ok at stage 2-daemon-up ' "$BASE/wlog-B"; t $? "[윈 B] 드레인 뒤 단계에서 끊는다" "$(tr '\n' '|' < "$BASE/wlog-B")"
grep -q ' ① ping: pong=yes$' "$BASE/wlog-B" && grep -q ' ② daemon pid: 22660 -> 27688$' "$BASE/wlog-B" && grep -q ' ③ seats: old alive 0/3 · role alive 3 (surface:56 surface:57 surface:58)$' "$BASE/wlog-B"; t $? "[윈 B] 근거 3줄(① ping ② pid ③ 자리)" "$(grep observe "$BASE/wlog-B" | tr '\n' '|')"
printf '%s' "$W_C" | grep -q '^r=timeout'; t $? "[윈 C] 멈춤+관측실패 → timeout(폴백)" "$W_C"
grep -q '^rotate stopped at: 2-daemon-up ' "$BASE/wlog-C" && grep -q ' verdict=no:pid$' "$BASE/wlog-C" && grep -q ' ③ seats: old alive 3/3 ' "$BASE/wlog-C"; t $? "[윈 C] 상한 뒤 마지막 관측 3축이 기록된다" "$(tr '\n' '|' < "$BASE/wlog-C")"
printf '%s' "$W_D" | grep -q '^r=ok	0	'; t $? "[윈 D] 드레인 중엔 끊지 않는다 → rotate 가 스스로 rc 0" "$W_D"
! grep -q 'rotate observe' "$BASE/wlog-D"; t $? "[윈 D] 드레인 중 관측 0회" "$(grep observe "$BASE/wlog-D" | tr '\n' '|')"

echo "== 상한 뒤 마지막 관측이 성공을 건진다(주기 관측이 상한 전에 한 번도 안 돈 경우) =="
mkcase mE stuck-ok; mkcase wE stuck-ok
ME="$(FAKE_CYS_STATE="$BASE/mE" run_sh "$BASE/mlog-E" "ROTATE_POLL_SEC=0.2; ROTATE_OBSERVE_SEC=100; ROTATE_WALL_CAP_SEC=5; cys_rotate_state '$BASE/cys'")"
printf '%s' "$ME" | grep -q '^observed-ok	'; t $? "[맥 E] 상한 → 마지막 관측 성공 → observed-ok(폴백 안내 없음)" "$ME"
WE="$(FAKE_CYS_STATE="$BASE/wE" JARVIS_LIB_ONLY=1 JARVIS_HOME="$BASE/wh-E" perl -e 'alarm shift; exec @ARGV or exit 126' 120 "$PW" -NoProfile -Command ". '$PS' *> \$null;
function Write-Log([string]\$m) { Add-Content -LiteralPath '$BASE/wlog-E' -Value \$m -Encoding UTF8 }
\$RotatePollMs = 200; \$RotateObserveMs = 100000; \$RotateWallCapMs = 5000
Write-Output ('r=' + (Get-CysRotateState '$BASE/cys'))
" 2>&1)"
printf '%s' "$WE" | grep -q '^r=observed-ok	'; t $? "[윈 E] 상한 → 마지막 관측 성공 → observed-ok(폴백 안내 없음)" "$WE"

echo "== 판정 C — 상한이 드레인 도중에 오면 드레인이 끝날 때까지 연장 · 끝나면 관측 1회 =="
for c in F:drain-long-ok G:drain-long-fail; do
  k="${c%%:*}"; m="${c#*:}"; mkcase "m$k" "$m"; mkcase "w$k" "$m"
  o="$(FAKE_CYS_STATE="$BASE/m$k" run_sh "$BASE/mlog-$k" "ROTATE_POLL_SEC=0.2; ROTATE_OBSERVE_SEC=100; ROTATE_WALL_CAP_SEC=2; ROTATE_DRAIN_HARD_SEC=30; cys_rotate_state '$BASE/cys'")"
  eval "M_$k=\"\$o\""
  # rotate 프로세스 자체가 살아 있나(자식 sleep 이 아니라) — 재고 나서 치운다
  pgrep -f "$BASE/cys rotate" >/dev/null && echo alive > "$BASE/alive-m$k"; pkill -f "$BASE/cys rotate" 2>/dev/null; pkill -f "$BASE/.*v0331-fake-cys identify" 2>/dev/null
  o="$(FAKE_CYS_STATE="$BASE/w$k" JARVIS_LIB_ONLY=1 JARVIS_HOME="$BASE/wh-$k" perl -e 'alarm shift; exec @ARGV or exit 126' 120 "$PW" -NoProfile -Command ". '$PS' *> \$null;
function Write-Log([string]\$m) { Add-Content -LiteralPath '$BASE/wlog-$k' -Value \$m -Encoding UTF8 }
\$RotatePollMs = 200; \$RotateObserveMs = 100000; \$RotateWallCapMs = 2000; \$RotateDrainHardMs = 30000
Write-Output ('r=' + (Get-CysRotateState '$BASE/cys'))
" 2>&1)"
  eval "W_$k=\"\$o\""
  pgrep -f "$BASE/cys rotate" >/dev/null && echo alive > "$BASE/alive-w$k"; pkill -f "$BASE/cys rotate" 2>/dev/null; pkill -f "$BASE/.*v0331-fake-cys identify" 2>/dev/null
done
printf '%s' "$M_F" | grep -q '^observed-ok	'; t $? "[맥 F] 드레인이 상한을 넘겨도 끊지 않고 · 끝난 뒤 관측 성공 → observed-ok" "$M_F"
grep -q ' rotate cap 2s reached during 1-drain ' "$BASE/mlog-F" && grep -q ' rotate stage 2-daemon-up ' "$BASE/mlog-F" && ! grep -q ' rotate stopped at: 1-drain' "$BASE/mlog-F"; t $? "[맥 F] 연장 기록 · 드레인을 끝까지 지나갔다" "$(tr '\n' '|' < "$BASE/mlog-F")"
printf '%s' "$M_G" | grep -q '^timeout'; t $? "[맥 G] 연장 뒤 관측 실패 → 폴백" "$M_G"
grep -q ' rotate left running at stage 2-daemon-up ' "$BASE/mlog-G" && [ -f "$BASE/alive-mG" ]; t $? "[맥 G] 데몬 교체 단계의 rotate 를 끊지 않는다(rotate 프로세스가 살아 있다)" "$(tr '\n' '|' < "$BASE/mlog-G")"
[ ! -f "$BASE/alive-mF" ]; t $? "[맥 F] 대조군 — 관측 성공이면 rotate 가 끊겼다(생존 판정이 살아 있다)" "alive-mF 가 있다"
printf '%s' "$W_F" | grep -q '^r=observed-ok	'; t $? "[윈 F] 드레인이 상한을 넘겨도 끊지 않고 · 끝난 뒤 관측 성공 → observed-ok" "$W_F"
grep -q '^rotate cap 2s reached during 1-drain ' "$BASE/wlog-F" && grep -q '^rotate stage 2-daemon-up ' "$BASE/wlog-F" && ! grep -q '^rotate stopped at: 1-drain' "$BASE/wlog-F"; t $? "[윈 F] 연장 기록 · 드레인을 끝까지 지나갔다" "$(tr '\n' '|' < "$BASE/wlog-F")"
printf '%s' "$W_G" | grep -q '^r=timeout'; t $? "[윈 G] 연장 뒤 관측 실패 → 폴백" "$W_G"
grep -q '^rotate left running at stage 2-daemon-up ' "$BASE/wlog-G" && [ -f "$BASE/alive-wG" ]; t $? "[윈 G] 데몬 교체 단계의 rotate 를 끊지 않는다(rotate 프로세스가 살아 있다)" "$(tr '\n' '|' < "$BASE/wlog-G")"
[ ! -f "$BASE/alive-wF" ]; t $? "[윈 F] 대조군 — 관측 성공이면 rotate 가 끊겼다" "alive-wF 가 있다"

echo "== 판정 함수 두 OS 동형 =="
OLD=$'surface:53\trole=master\tpid=1\texited=false\tm\nsurface:54\trole=cso\tpid=2\texited=false\tc\nsurface:55\trole=worker\tpid=3\texited=false\tw'
NEW=$'surface:56\trole=master\tpid=1\texited=false\tm\nsurface:57\trole=cso\tpid=2\texited=false\tc\nsurface:58\trole=worker\tpid=3\texited=false\tw'
TWO=$'surface:56\trole=master\tpid=1\texited=false\tm\nsurface:57\trole=cso\tpid=2\texited=true\tc\nsurface:58\trole=-\tpid=3\texited=false\tw'
MIX="$NEW"$'\nsurface:54\trole=cso\tpid=2\texited=false\tc'
DEADOLD="$NEW"$'\nsurface:54\trole=cso\tpid=2\texited=true\tc'
printf '%s' "$OLD" > "$BASE/l-old"; printf '%s' "$NEW" > "$BASE/l-new"; printf '%s' "$TWO" > "$BASE/l-two"; printf '%s' "$MIX" > "$BASE/l-mix"; printf '%s' "$DEADOLD" > "$BASE/l-deadold"
CASES='22660|27688|l-new 22660|22660|l-new 22660||l-new |27688|l-new 22660|27688|l-old 22660|27688|l-two 22660|27688|l-mix 22660|27688|l-deadold'
SH_OUT=""; PW_ARGS=""
for c in $CASES; do
  IFS='|' read -r a b f <<<"$c"
  SH_OUT="$SH_OUT$(run_sh "$BASE/mlog-v" "rotate_observe_verdict '$a' '$b' 'surface:53 surface:54 surface:55' \"\$(cat '$BASE/$f')\"") "
  PW_ARGS="$PW_ARGS Write-Output (Get-RotateObserveVerdict '$a' '$b' 'surface:53 surface:54 surface:55' (Get-Content -Raw '$BASE/$f'));"
done
PW_OUT="$(JARVIS_LIB_ONLY=1 JARVIS_HOME="$BASE/wv" "$PW" -NoProfile -Command ". '$PS' *> \$null; $PW_ARGS" 2>/dev/null | tr '\n' ' ')"
EXP="ok no:pid no:pid no:pid no:old-seats no:role-seats no:old-seats ok "
[ "$SH_OUT" = "$EXP" ]; t $? "[맥] rotate_observe_verdict 여덟 입력" "[$SH_OUT]"
[ "$PW_OUT" = "$SH_OUT" ]; t $? "[동형] 윈 Get-RotateObserveVerdict 가 글자까지 같다" "윈[$PW_OUT] 맥[$SH_OUT]"

printf '\n통과 %s · 실패 %s\n' "$pass" "$fail"
[ "$fail" -eq 0 ]
