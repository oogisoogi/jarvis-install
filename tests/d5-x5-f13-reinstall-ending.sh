#!/bin/bash
# 0.3.36 X-5 · F13 행동 시험 — 재설치 끝(자리 선점 갈래)의 판정과 안내를 **실제로 불러** 잰다.
#
# 재는 것
#   ⓐ X-5(두 OS · cys_rotate_state · Get-CysRotateState): 가짜 cys 의 rotate 가 rc 25 로 끝나고
#      ⓛ 늦던 자리가 rc 25 뒤 3초에 선다   → observed-ok(거짓 경고 0) · 기록에 「rotate held recheck」
#      ⓝ 끝내 안 선다                      → held · 기다림은 창(시험값 8초) 안에서 끝난다
#      ⓤ 기준 데몬 pid 를 못 읽었다         → held · 기다리지 않는다(5초 안)
#   ⓑ F13(두 OS · step_wake · Step-Wake 의 자리 선점 갈래): rotate 판정 8가지 × 앱 창 2가지(띄움 · 못 띄움)
#      · 실패(fail-22·23·24·timeout·absent·fail-1)면 「여기까지 끝났습니다」 0 · 「다음에 할 일」이 「없습니다」가 아니다 ·
#        [재시작] 은 화면 전체에서 한 번(다음에 할 일 안)
#      · 어느 경우든 위 줄들에는 「주세요」가 0 — 사람에게 부탁하는 말은 「다음에 할 일」 한 줄에만 있다
#      · 「다음에 할 일: 없습니다」는 앱을 띄웠고 성공(ok·observed-ok)일 때만
#      · 진행 전송 = 9/10 end → 10/10 start → 10/10 end · 끝 표기에 rotate=<판정>
#      · 단계 표지 [10/10] 줄은 모든 경우에 한 번(B9)
#
# 쓰는 법: bash tests/d5-x5-f13-reinstall-ending.sh [--dir <install-master 자리>]
#   rc 0 = 전건 통과 · 1 = 실패 있음 · 2 = 잴 수 없음(pwsh 가 없다)
#   원본(v0.3.35) 사본의 install-master 를 --dir 로 주면 적색이어야 한다(수리 전 거짓 경고 · 엇갈린 안내).
# ⛔바깥에 닿지 않는다 — 네트워크 0 · 앱 실행 0 · 실물 cys 무접촉(가짜 cys · 가짜 HOME · 진행 전송은 가짜 함수).
# ⚠여기서 안 재는 것: 실물 cys rotate 의 rc 25 가 나오는 조건 · 실제 좌석 기동 시간(실기 몫).
set -u
HERE="$(cd "$(dirname "$0")" && pwd)"
DIR="$HERE/../install-master"
while [ $# -gt 0 ]; do
  case "$1" in
    --dir) DIR="$2"; shift 2 ;;
    *) echo "모르는 인자: $1" >&2; exit 2 ;;
  esac
done
PS="$(cd "$DIR" && pwd)/bootstrap.ps1"
SH="$(cd "$DIR" && pwd)/bootstrap.sh"
PW="$(command -v pwsh 2>/dev/null)"
[ -n "$PW" ] || { echo "잴 수 없음: pwsh 가 없다" >&2; exit 2; }
BASE="$(mktemp -d -t d5x5f13)" || exit 2
trap 'rm -rf "$BASE"' EXIT
pass=0; fail=0
t() { if [ "$1" -eq 0 ]; then pass=$((pass+1)); printf '  ok   %s\n' "$2"; else fail=$((fail+1)); printf '  FAIL %s  ← %s\n' "$2" "$3"; fi; }
cnt() { local n; n="$(grep -c -- "$1" "$2" 2>/dev/null)"; echo "${n:-0}"; }

# ── ⓐ 가짜 cys — 상태 폴더 $FAKE_CYS_STATE(pid · list · late) ──
cat > "$BASE/cys" <<'EOF'
#!/bin/bash
S="${FAKE_CYS_STATE:?}"
case "$1" in
  ping) echo pong; exit 0 ;;
  identify) [ -f "$S/pid" ] || exit 1; printf '{\n  "daemon_pid": %s\n}\n' "$(cat "$S/pid")"; exit 0 ;;
  list) cat "$S/list" 2>/dev/null; exit 0 ;;
  --version) echo "cys 1.1.5"; exit 0 ;;
  rotate)
    echo 2222 > "$S/pid"
    printf 'surface:21\trole=master\tpid=31\texited=false\tclaude\t/x\nsurface:22\trole=worker\tpid=32\texited=false\tclaude\t/x\n' > "$S/list"
    if [ -f "$S/late" ]; then
      ( sleep "$(cat "$S/late")"; printf 'surface:23\trole=cso\tpid=33\texited=false\tclaude\t/x\n' >> "$S/list" ) </dev/null >/dev/null 2>&1 &
    fi
    echo "[rotate] ⑤ 조직 복원" >&2
    echo "재시작 완료 — 조직 복원 실패·보류 — 창을 확인하세요 (rc=25)"
    exit 25 ;;
esac
exit 0
EOF
chmod +x "$BASE/cys"
mkst() { # mkst <이름> <late 초|-> <pid 있음 1|0>
  local d="$BASE/st-$1"; mkdir -p "$d"
  [ "$3" = 1 ] && echo 1111 > "$d/pid"
  printf 'surface:1\trole=master\tpid=21\texited=false\tclaude\t/x\nsurface:2\trole=cso\tpid=22\texited=false\tclaude\t/x\nsurface:3\trole=worker\tpid=23\texited=false\tclaude\t/x\n' > "$d/list"
  [ "$2" != - ] && echo "$2" > "$d/late"
  return 0
}

echo "== ⓐ X-5 rc 25 뒤 다시 보기 =="
for os in w m; do
  for c in L N U; do
    case "$c" in L) mkst "$os$c" 3 1 ;; N) mkst "$os$c" - 1 ;; U) mkst "$os$c" 3 0 ;; esac
  done
done
for c in L N U; do
  FAKE_CYS_STATE="$BASE/st-w$c" JARVIS_LIB_ONLY=1 JARVIS_HOME="$BASE/wh-$c" \
    perl -e 'alarm shift; exec @ARGV or exit 126' 150 "$PW" -NoProfile -Command ". '$PS' *> \$null;
function Write-Log([string]\$m) { Add-Content -LiteralPath '$BASE/wlog-$c' -Value \$m -Encoding UTF8 }
\$RotateObserveMs = 1000; \$RotateHeldObserveMs = 8000
\$sw0 = [System.Diagnostics.Stopwatch]::StartNew(); \$r = Get-CysRotateState '$BASE/cys'
Write-Output ('R=' + \$r); Write-Output ('T=' + [int]\$sw0.Elapsed.TotalSeconds)" > "$BASE/wout-$c" 2>&1
  sed -n 's/^T=//p' "$BASE/wout-$c" > "$BASE/wsec-$c"
done
mkdir -p "$BASE/home"
for c in L N U; do
  FAKE_CYS_STATE="$BASE/st-m$c" HOME="$BASE/home" TMPDIR="$BASE" JARVIS_HOME="$BASE/home/install-jarvis" JARVIS_LIB_ONLY=1 \
    perl -e 'alarm shift; exec @ARGV or exit 126' 150 bash -c ". '$SH' >/dev/null 2>&1; LOG_FILE='$BASE/mlog-$c'; ROTATE_OBSERVE_SEC=1; ROTATE_HELD_OBSERVE_SEC=8
s0=\$SECONDS; r=\"\$(cys_rotate_state '$BASE/cys')\"; printf 'R=%s\nT=%s\n' \"\$r\" \"\$((SECONDS - s0))\"" > "$BASE/mout-$c" 2>/dev/null
  sed -n 's/^T=//p' "$BASE/mout-$c" > "$BASE/msec-$c"
done
st() { sed -n 's/^R=//p' "$BASE/$1" | cut -f1; }
for os in w m; do
  nm=윈; [ "$os" = m ] && nm=맥
  [ "$(st ${os}out-L)" = observed-ok ]; t $? "[$nm ⓛ] rc 25 뒤 3초에 자리가 서면 observed-ok(거짓 경고 0)" "$(tr '\n' '|' < "$BASE/${os}out-L" | cut -c1-240)"
  grep -q 'rotate held recheck: verdict=ok' "$BASE/${os}log-L" 2>/dev/null; t $? "[$nm ⓛ] 기록에 다시 보기 판정 한 줄(verdict=ok)" "$(grep -c 'held recheck' "$BASE/${os}log-L" 2>/dev/null)"
  ! grep -q '조직 복원 실패' "$BASE/${os}out-L"; t $? "[$nm ⓛ] 성공이면 rotate 의 「복원 실패·보류」 알림을 넘기지 않는다" "$(tr '\n' '|' < "$BASE/${os}out-L" | cut -c1-240)"
  [ "$(st ${os}out-N)" = held ]; t $? "[$nm ⓝ] 끝내 안 서면 held(종전 경고 유지)" "$(tr '\n' '|' < "$BASE/${os}out-N" | cut -c1-240)"
  s="$(cat "$BASE/${os}sec-N")"; [ -n "$s" ] && [ "$s" -ge 8 ] && [ "$s" -lt 40 ]; t $? "[$nm ⓝ] 다시 보기는 창(8초) 동안 하고 그 안에서 끝낸다(8~40초)" "${s}초"
  [ "$(st ${os}out-U)" = held ]; t $? "[$nm ⓤ] 기준 pid 를 못 읽었으면 held" "$(tr '\n' '|' < "$BASE/${os}out-U" | cut -c1-240)"
  s="$(cat "$BASE/${os}sec-U")"; [ -n "$s" ] && [ "$s" -lt 8 ]; t $? "[$nm ⓤ] 기준 pid 를 못 읽었으면 기다리지 않는다(8초 안)" "${s}초"
done

# ── ⓑ F13 끝맺음 안내 ──
DENIED="error: claim_denied: surface.create denied: privileged role 'master' is held by a live surface"
STATES="ok observed-ok skipped-restarted held fail-22 fail-23 fail-24 timeout absent fail-1"
# held 의 알림 = 실물 cys 원문 모양(부탁 「창을 확인하세요」가 들어 있다 · 09-22 VM bootstrap.log 200행)
HELD_NOTE="재시작 완료 — 저장 확인 3/3 · 데몬 교체 · 새 팩 반영 · 조직 복원 실패·보류 — 창을 확인하세요 (rc=25)"
ASK='주세요|하세요|하십시오|주십시오'   # 부탁하는 끝말(적대 검토 지적: 「주세요」만 세면 다른 부탁이 빠져나간다)
printf '%s\n' "$DENIED" > "$BASE/answer"
# 자리를 여는 명령만 거절을 답하는 가짜 cys(윈 Step-Wake 가 부른다 · v0332 흉내와 같은 모양)
printf '#!/bin/bash\ncase "$1" in new-surface) cat "%s" >&2; exit 1 ;; esac\nexit 0\n' "$BASE/answer" > "$BASE/cys-wake"; chmod +x "$BASE/cys-wake"
for app in raised none; do
  av="'$app'"; [ "$app" = none ] && av="''"
  mkdir -p "$BASE/wf-$app" "$BASE/wfh-$app"
  FAKE_OUT="$BASE/wf-$app" JARVIS_LIB_ONLY=1 JARVIS_HOME="$BASE/wfh-$app" USERPROFILE="$BASE/up-$app" \
  perl -e 'alarm shift; exec @ARGV or exit 126' 240 "$PW" -NoProfile -Command ". '$PS' *> \$null;
function Write-Log([string]\$m) { }
function Say(\$m) { Add-Content -LiteralPath (Join-Path \$env:FAKE_OUT (\$global:CASE + '.say')) -Value \$m -Encoding UTF8; if (\$m -match '^\[\d+/\d+\]') { [void]\$script:StepLog.Add(\$m) } }
function Clear-MasterMark { }
function Move-OldRound { }
function Set-FleetBaseline { }
function Test-CysAgentFlag { return \$true }
function Start-CysAppWindow { return $av }
function Get-MasterSeatRef { return '' }
function Invoke-StepFleet { return 0 }
function Send-Progress(\$step, \$ev, \$code, \$detail) { Add-Content -LiteralPath (Join-Path \$env:FAKE_OUT (\$global:CASE + '.prog')) -Value (\$step + ' ' + \$ev + ' ' + \$detail) -Encoding UTF8 }
function Send-PostInstallEvidence { }
function Get-CysRotateState([string]\$Cli) { \$n = \$(if (\$global:FS -eq 'held') { '$HELD_NOTE' } else { '재시작 알림' }); return (\$global:FS + \"\`t\" + \$global:FR + \"\`t\" + \$n) }
function claude { \$global:LASTEXITCODE = 0 }
\$Mode = 'real'; \$script:CysCli = '$BASE/cys-wake'; \$script:RotatePlan = 'run:same'
foreach (\$s in ('$STATES' -split ' ')) {
  \$global:CASE = \$s; \$global:FS = \$s; \$global:FR = \$(if (\$s -like 'fail-*') { \$s.Substring(5) } elseif (\$s -eq 'held') { '25' } else { '0' })
  \$script:NextStep = \$null; \$script:ReachedWake = \$false
  Step-Wake *> \$null
  Set-Content -LiteralPath (Join-Path \$env:FAKE_OUT (\$s + '.next')) -Value ([string]\$script:NextStep) -Encoding UTF8
}" > "$BASE/wf-$app.out" 2>&1
  mkdir -p "$BASE/mf-$app" "$BASE/home/.local/bin"
  printf '#!/bin/bash\nexit 0\n' > "$BASE/home/.local/bin/claude"; chmod +x "$BASE/home/.local/bin/claude"
  mav="$app"; [ "$app" = none ] && mav=""
  FAKE_OUT="$BASE/mf-$app" HOME="$BASE/home" TMPDIR="$BASE" JARVIS_HOME="$BASE/home/install-jarvis" JARVIS_LIB_ONLY=1 \
  perl -e 'alarm shift; exec @ARGV or exit 126' 240 bash -c ". '$SH' >/dev/null 2>&1; LOG_FILE='$BASE/mf-$app/log'; MODE=full
open_cys_app() { :; }; clear_master_mark() { :; }; archive_old_round() { :; }; set_fleet_baseline() { :; }
start_cys_app_window() { printf '%s' '$mav'; }; master_seat_ref() { :; }; invoke_step_fleet() { return 0; }
cys_open_master_seat() { cat '$BASE/answer'; }
progress_send() { echo \"\$1 \$2 \$4\" >> \"\$FAKE_OUT/\$CASE.prog\"; }
post_install_evidence() { :; }
cys_rotate_state() { local r=0 n='재시작 알림'; case \"\$CASE\" in fail-*) r=\"\${CASE#fail-}\" ;; held) r=25; n='$HELD_NOTE' ;; esac; printf '%s\t%s\t%s\n' \"\$CASE\" \"\$r\" \"\$n\"; }
ROTATE_PLAN=run:same; CYS_CLI='$BASE/cys'
mkdir -p \"\$JARVIS_HOME\"
for CASE in $STATES; do
  NEXT_STEP=''; REACHED_WAKE=0
  say() { printf '%s\n' \"\$*\" >> \"\$FAKE_OUT/\$CASE.say\"; }
  step_wake >/dev/null 2>&1
  printf '%s\n' \"\$NEXT_STEP\" > \"\$FAKE_OUT/\$CASE.next\"
done" > "$BASE/mf-$app.out" 2>&1
done

for os in w m; do
  nm=윈; [ "$os" = m ] && nm=맥
  for app in raised none; do
    for s in $STATES; do
      d="$BASE/${os}f-$app"; tag="[$nm ${s}·앱 $app]"
      if [ ! -s "$d/$s.say" ]; then t 1 "$tag 화면 줄이 기록됐다" "$(head -c 300 "$BASE/${os}f-$app.out")"; continue; fi
      nx="$(cat "$d/$s.next" 2>/dev/null)"
      { cat "$d/$s.say"; printf '다음에 할 일: %s\n' "$nx"; } > "$d/$s.all"
      # 위 줄들에는 부탁하는 말이 없다 — 부탁은 「다음에 할 일」 한 줄에만
      [ "$(grep -cE "$ASK" "$d/$s.say")" = 0 ]; t $? "$tag 위 줄들에 부탁하는 말 0(주세요·하세요·하십시오 · 부탁은 다음에 할 일에만)" "$(grep -E "$ASK" "$d/$s.say" | head -2 | tr '\n' '|')"
      [ "$(cnt '^\[10/10\]' "$d/$s.say")" = 1 ]; t $? "$tag 단계 표지 [10/10] 줄 한 번(B9)" "$(cnt '^\[10/10\]' "$d/$s.say")"
      pr="$(awk '{print $1" "$2}' "$d/$s.prog" 2>/dev/null | tr '\n' '|')"
      [ "$pr" = "9/10 end|10/10 start|10/10 end|" ] && grep -q "^10/10 end .*rotate=$s\$" "$d/$s.prog"
      t $? "$tag 진행 전송 9/10 end → 10/10 start → 10/10 end · 끝 표기 rotate=$s" "$(tr '\n' '|' < "$d/$s.prog" 2>/dev/null)"
      case "$s:$app" in
        ok:raised|observed-ok:raised|skipped-restarted:raised)
          [ "$(cnt '여기까지 끝났습니다' "$d/$s.say")" = 1 ] && case "$nx" in 없습니다*) true ;; *) false ;; esac
          t $? "$tag 성공 · 앱 띄움 → 「여기까지 끝났습니다」 + 「다음에 할 일: 없습니다」" "[$nx]" ;;
        *)
          case "$nx" in 없습니다*|'') false ;; *) true ;; esac
          t $? "$tag 사람 손이 남은 끝 → 「다음에 할 일」이 그 한 가지를 말한다(없습니다 아님)" "[$nx]" ;;
      esac
      case "$s" in
        ok|observed-ok|skipped-restarted) [ "$(cnt '\[재시작\]' "$d/$s.all")" = 0 ]; t $? "$tag 성공이면 [재시작] 0" "$(cnt '\[재시작\]' "$d/$s.all")" ;;
        held)
          [ "$(cnt '여기까지 끝났습니다' "$d/$s.say")" = 1 ] && [ "$(cnt '\[재시작\]' "$d/$s.all")" = 0 ] && [ "$(cnt '열려 있는지 확인해 주세요' "$d/$s.all")" = 1 ]
          t $? "$tag 복원 보류 → 설치는 끝 · [재시작] 0 · 창 확인 부탁 한 번(다음에 할 일)" "$(tr '\n' '|' < "$d/$s.all" | cut -c1-300)" ;;
        *)
          [ "$(cnt '여기까지 끝났습니다' "$d/$s.all")" = 0 ] && [ "$(cnt '할 일: 없습니다' "$d/$s.all")" = 0 ] && [ "$(cnt '\[재시작\]' "$d/$s.all")" = 1 ]
          t $? "$tag 재시작 실패 → 「끝났습니다·할 일 없음」 0 · [재시작] 안내 한 번" "$(tr '\n' '|' < "$d/$s.all" | cut -c1-300)" ;;
      esac
    done
  done
done

echo "== 합계: ok $pass · FAIL $fail =="
[ "$fail" -eq 0 ]
