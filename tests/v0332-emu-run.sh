#!/bin/bash
# 0.3.32 흉내 실행 시험 — 새 갈래를 **실제로 부른다**(글자 대조가 아니라 실행 · TICKET=installer-0332).
#
# 재는 것
#   ⓐ C1 [8/10] 데몬 선확인 문구 — 이미 돎+등록 yes 면 「그대로 둡니다」 한 줄뿐(「등록됨」 줄 0) ·
#      이미 돎+등록 없음이면 「그대로 둡니다」 0 · 등록 상태 한 줄(두 OS)
#   ⓑ C2 [9/10] 자리 선점 거절 — 설치 창에 영문 원문(claim_denied·error:) 0줄 · 원문은 기록(bootstrap.log)에 남는다 ·
#      대조군 = 선점이 아닌 거절이면 원문을 종전대로 창에 보인다(두 OS)
#   ⓒ B9 선점 갈래 끝 — 화면에 [10/10] 끝맺음 줄 · 진행 전송 순서 9/10 end → 10/10 start → 10/10 end ·
#      그 뒤 설치 끝 증거(post-install)가 단계 10/10 으로 나간다(앞 판은 9/10 으로 붙어 서버 마지막 행이 9/10 이었다)
#   ⓓ B2 로그인 승계(A1 · master 판정 70ab51cf) — 판정 함수 두 OS 글자 동형 · 네 갈래 × 두 OS
#      (자비스 없음 / 자비스 옛것 / 자비스 새것 / 둘 다 만료시각 없음 → 수정 시각) · 앞 사본 1세대 · 기록에 값 0
#
# 쓰는 법: bash tests/v0332-emu-run.sh [--dir <install-master 자리>]   rc 0 = 전건 통과 · 1 = 실패 · 2 = 잴 수 없음(pwsh 없음)
# ⛔바깥에 닿지 않는다 — 네트워크 0 · 앱 실행 0 · 실물 cys·키체인·자격증명 무접촉(가짜 cys · 가짜 security · 가짜 HOME · 가짜 토큰 글).
# ⚠여기서 안 재는 것: 실물 서버가 10/10 증거 행을 보드에 어떻게 그리는가(스테이징 몫) · 실물 키체인의 mdat 형식(맥 실기 몫) ·
#   실물 클로드 자격증명 파일의 칸 이름(claudeAiOauth.expiresAt — 【추정】 실물 형식 대조는 실기 몫) · 갱신 토큰 1회용 회전 여부(미실측).
set -u
HERE="$(cd "$(dirname "$0")" && pwd)"
DIR="$HERE/../install-master"
while [ $# -gt 0 ]; do case "$1" in --dir) DIR="$2"; shift 2 ;; *) echo "모르는 인자: $1" >&2; exit 2 ;; esac; done
PS="$(cd "$DIR" && pwd)/bootstrap.ps1"
SH="$(cd "$DIR" && pwd)/bootstrap.sh"
PW="$(command -v pwsh 2>/dev/null)"
[ -n "$PW" ] || { echo "잴 수 없음: pwsh 가 없다" >&2; exit 2; }
BASE="$(mktemp -d -t v0332emu)" || exit 2
trap 'rm -rf "$BASE"' EXIT
pass=0; fail=0
t() { if [ "$1" -eq 0 ]; then pass=$((pass+1)); printf '  ok   %s\n' "$2"; else fail=$((fail+1)); printf '  FAIL %s  ← %s\n' "$2" "$3"; fi; }
cnt() { local n; n="$(grep -c -- "$1" "$2" 2>/dev/null)"; echo "${n:-0}"; }
DENIED="error: claim_denied: surface.create denied: privileged role 'master' is held by a live surface"
OTHER="error: bad_request: surface.create failed: cwd missing"

# ── 가짜 cys(상태 = 폴더 $FAKE_CYS_STATE) ──
cat > "$BASE/cys" <<'EOF'
#!/bin/bash
S="${FAKE_CYS_STATE:?}"
echo "$*" >> "$S/calls"
case "$1" in
  ping) [ -f "$S/alive" ] && { echo pong; exit 0; }; echo "error: no daemon" >&2; exit 1 ;;
  identify) [ -f "$S/alive" ] && { printf '{\n  "daemon_pid": %s\n}\n' "$(cat "$S/pid")"; exit 0; }; exit 1 ;;
  daemon) echo "작업 스케줄러 등록 완료"; exit 0 ;;
  init-pack) exit 0 ;;
  doctor) echo "  [OK  ] pack-version"; echo "요약: 1 OK · 0 WARN · 0 FAIL · 0 SKIP"; exit 0 ;;
  new-surface) cat "$S/answer" >&2; exit 1 ;;
esac
exit 0
EOF
chmod +x "$BASE/cys"
mkst() { local d="$BASE/st-$1"; mkdir -p "$d"; touch "$d/alive"; echo 14888 > "$d/pid"; [ -n "${2:-}" ] && printf '%s\n' "$2" > "$d/answer"; }

run_ps() { # run_ps <이름> <앞 준비 ps 글> <부를 ps 글>
  FAKE_CYS_STATE="$BASE/st-$1" JARVIS_LIB_ONLY=1 JARVIS_HOME="$BASE/wh-$1" USERPROFILE="$BASE/up-$1" \
  perl -e 'alarm shift; exec @ARGV or exit 126' 120 "$PW" -NoProfile -Command ". '$PS' *> \$null;
function Write-Log([string]\$m) { Add-Content -LiteralPath '$BASE/wlog-$1' -Value \$m -Encoding UTF8 }
function Say(\$m) { Add-Content -LiteralPath '$BASE/wsay-$1' -Value \$m -Encoding UTF8; if (\$m -match '^\[\d+/\d+\]') { [void]\$script:StepLog.Add(\$m) } }
\$Mode = 'real'; \$script:CysCli = '$BASE/cys'; \$DaemonPingCapSec = 2
$2
$3" 2>&1
}
mkdir -p "$BASE/home"
run_sh() { # run_sh <기록 파일> <부를 sh 글>
  HOME="$BASE/home" TMPDIR="$BASE" JARVIS_HOME="$BASE/home/install-jarvis" JARVIS_LIB_ONLY=1 \
  perl -e 'alarm shift; exec @ARGV or exit 126' 120 bash -c ". '$SH' >/dev/null 2>&1; LOG_FILE='$1'; MODE=full; $2; exec >/dev/null 2>&1" 2>/dev/null; }

echo "== C1 [8/10] 데몬 선확인 문구 =="
for c in A D; do
  mkst "$c"; task=yes; [ "$c" = D ] && task=no
  run_ps "$c" "function Get-CysAutoStartState { param([string]\$CysCli = '') return '$task' }
function Set-AllProfiles { }
function Copy-LoginToIsolated { }" 'Write-Output (Step-PrepareAccount)' >/dev/null
done
[ "$(cnt '그대로 둡니다' "$BASE/wsay-A")" = 1 ] && [ "$(cnt '자동 시작 등록됨' "$BASE/wsay-A")" = 0 ]
t $? "[윈 C1 A] 이미 돎+등록 yes → 「그대로 둡니다」 1줄 · 「자동 시작 등록됨」 0줄" "$(tr '\n' '|' < "$BASE/wsay-A" 2>/dev/null)"
grep -q '자동 시작도 등록돼 있어(작업 이름 cysd) 그대로 둡니다' "$BASE/wsay-A"; t $? "[윈 C1 A] 한 줄이 등록 사실을 함께 말한다" "-"
[ "$(cnt '그대로 둡니다' "$BASE/wsay-D")" = 0 ] && [ "$(cnt '등록되지 않았습니다' "$BASE/wsay-D")" = 1 ]
t $? "[윈 C1 D] 이미 돎+등록 없음 → 「그대로 둡니다」 0 · 상태 한 줄" "$(tr '\n' '|' < "$BASE/wsay-D" 2>/dev/null)"
for c in A D; do
  as=yes; [ "$c" = D ] && as=no
  FAKE_CYS_STATE="$BASE/st-$c" run_sh "$BASE/mlog-$c" "CYS_CLI='$BASE/cys'; DAEMON_PING_CAP_SEC=2
copy_login_to_isolated() { :; }; cys_autostart_state() { echo $as; }; seed_all_profiles() { return 0; }
say() { printf '%s\n' \"\$*\" >> '$BASE/msay-$c'; }
step_prepare_account" >/dev/null
done
[ "$(cnt '그대로 둡니다' "$BASE/msay-A")" = 1 ] && [ "$(cnt '자동 시작 등록됨' "$BASE/msay-A")" = 0 ]
t $? "[맥 C1 A] 이미 돎+등록 yes → 「그대로 둡니다」 1줄 · 「자동 시작 등록됨」 0줄" "$(tr '\n' '|' < "$BASE/msay-A" 2>/dev/null)"
[ "$(cnt '그대로 둡니다' "$BASE/msay-D")" = 0 ] && [ "$(cnt '등록되지 않았습니다' "$BASE/msay-D")" = 1 ]
t $? "[맥 C1 D] 이미 돎+등록 없음 → 「그대로 둡니다」 0 · 상태 한 줄" "$(tr '\n' '|' < "$BASE/msay-D" 2>/dev/null)"

echo "== C2·B9 [9/10] 자리 선점 거절 =="
WAKE_STUBS="function Clear-MasterMark { }
function Move-OldRound { }
function Set-FleetBaseline { }
function Test-CysAgentFlag { return \$true }
function Start-CysAppWindow { return 'raised' }
function Get-MasterSeatRef { return '' }
function Invoke-StepFleet { return 0 }
function Send-Progress(\$step, \$ev) { Add-Content -LiteralPath (Join-Path \$env:FAKE_CYS_STATE 'progress') -Value (\$step + ' ' + \$ev) -Encoding UTF8 }
function Send-EvidenceEvent([string]\$Reason, [string]\$Text) { Add-Content -LiteralPath (Join-Path \$env:FAKE_CYS_STATE 'evidence') -Value (\$Reason + ' ' + (Get-CurrentStep)) -Encoding UTF8; return \$null }
function Send-EvidenceImages { }
function claude { \$global:LASTEXITCODE = 0 }
\$script:RotatePlan = 'skip:fresh'"
for c in W O; do
  a="$DENIED"; [ "$c" = O ] && a="$OTHER"
  mkst "$c" "$a"; mkdir -p "$BASE/wh-$c"
  run_ps "$c" "$WAKE_STUBS" 'Step-Wake' >/dev/null
done
! grep -qE 'claim_denied|error:' "$BASE/wsay-W"; t $? "[윈 C2] 선점 거절 → 설치 창에 영문 원문 0줄" "$(grep -E 'claim_denied|error:' "$BASE/wsay-W" | head -2 | tr '\n' '|')"
grep -q '^new-surface failed: .*claim_denied' "$BASE/wlog-W" && grep -q '^seat claim denied: .*claim_denied' "$BASE/wlog-W"
t $? "[윈 C2] 원문은 기록에 남는다(new-surface failed · seat claim denied)" "$(grep -c claim_denied "$BASE/wlog-W" 2>/dev/null)"
grep -q '자비스는 이미 열려 있는 cysr 앱 안에 있습니다' "$BASE/wsay-W"; t $? "[윈 C2] 사람 말 한 줄은 그대로" "-"
grep -q 'bad_request' "$BASE/wsay-O" && grep -q '프로그램이 답한 내용은 이렇습니다' "$BASE/wsay-O"
t $? "[윈 C2 대조군] 선점이 아닌 거절은 원문을 창에 보인다(종전)" "$(tr '\n' '|' < "$BASE/wsay-O" 2>/dev/null | cut -c1-300)"
grep -q '^\[10/10\] 설치는 여기까지 끝났습니다' "$BASE/wsay-W"; t $? "[윈 B9] 선점 갈래 끝맺음 줄이 [10/10] 이다" "-"
[ "$(tr '\n' '|' < "$BASE/st-W/progress" 2>/dev/null)" = "9/10 end|10/10 start|10/10 end|" ]
t $? "[윈 B9] 진행 전송 = 9/10 end → 10/10 start → 10/10 end" "$(tr '\n' '|' < "$BASE/st-W/progress" 2>/dev/null)"
[ "$(cat "$BASE/st-W/evidence" 2>/dev/null)" = "post-install 10/10" ]
t $? "[윈 B9] 설치 끝 증거가 단계 10/10 으로 나간다" "[$(cat "$BASE/st-W/evidence" 2>/dev/null)]"

M_WAKE_STUBS="open_cys_app() { :; }; clear_master_mark() { :; }; archive_old_round() { :; }; set_fleet_baseline() { :; }
start_cys_app_window() { echo raised; }; master_seat_ref() { :; }; invoke_step_fleet() { return 0; }
cys_open_master_seat() { cat \"\$FAKE_CYS_STATE/answer\"; }
progress_send() { echo \"\$1 \$2\" >> \"\$FAKE_CYS_STATE/progress\"; }
evidence_event_send() { echo \"\$1 \$(current_step)\" >> \"\$FAKE_CYS_STATE/evidence\"; return 1; }
ROTATE_PLAN=skip:fresh; CYS_CLI='$BASE/cys'"
for c in W O; do
  a="$DENIED"; [ "$c" = O ] && a="$OTHER"
  mkst "m$c" "$a"
  # 대조군은 이 창에서 띄우는 갈래로 내려가 exec 한다 — 가짜 claude 가 곧바로 끝나게 둔다
  mkdir -p "$BASE/home/.local/bin"; printf '#!/bin/bash\nexit 0\n' > "$BASE/home/.local/bin/claude"; chmod +x "$BASE/home/.local/bin/claude"
  FAKE_CYS_STATE="$BASE/st-m$c" run_sh "$BASE/mlog-w$c" "$M_WAKE_STUBS
mkdir -p \"\$JARVIS_HOME\"; say() { printf '%s\n' \"\$*\" >> '$BASE/msay-w$c'; printf '%s\n' \"\$*\" >> \"\$LOG_FILE\"; }
step_wake" >/dev/null
done
! grep -qE 'claim_denied|error:' "$BASE/msay-wW"; t $? "[맥 C2] 선점 거절 → 설치 창에 영문 원문 0줄" "$(grep -E 'claim_denied|error:' "$BASE/msay-wW" | head -2 | tr '\n' '|')"
grep -q 'seat claim denied: .*claim_denied' "$BASE/mlog-wW"; t $? "[맥 C2] 원문은 기록에 남는다" "-"
grep -q 'bad_request' "$BASE/msay-wO"; t $? "[맥 C2 대조군] 선점이 아닌 거절은 원문을 창에 보인다(종전)" "$(tr '\n' '|' < "$BASE/msay-wO" 2>/dev/null | cut -c1-300)"
grep -q '^\[10/10\] 설치는 여기까지 끝났습니다' "$BASE/msay-wW"; t $? "[맥 B9] 선점 갈래 끝맺음 줄이 [10/10] 이다" "-"
[ "$(tr '\n' '|' < "$BASE/st-mW/progress" 2>/dev/null)" = "9/10 end|10/10 start|10/10 end|" ]
t $? "[맥 B9] 진행 전송 = 9/10 end → 10/10 start → 10/10 end" "$(tr '\n' '|' < "$BASE/st-mW/progress" 2>/dev/null)"
[ "$(cat "$BASE/st-mW/evidence" 2>/dev/null)" = "post-install 10/10" ]
t $? "[맥 B9] 설치 끝 증거가 단계 10/10 으로 나간다" "[$(cat "$BASE/st-mW/evidence" 2>/dev/null)]"

echo "== B2 판정 함수 두 OS 동형 =="
# (자비스 있음, 개인 만료, 자비스 만료, 개인 수정, 자비스 수정)
PW_OUT="$(JARVIS_LIB_ONLY=1 JARVIS_HOME="$BASE/wp" "$PW" -NoProfile -Command ". '$PS' *> \$null;
foreach (\$a in @(@(\$false,\$null,\$null,5,0), @(\$true,200,100,1,9), @(\$true,100,200,9,1), @(\$true,100,100,9,1), @(\$true,\$null,\$null,9,1), @(\$true,\$null,\$null,1,9), @(\$true,200,\$null,1,9), @(\$true,\$null,\$null,9,\$null))) { Write-Output (Get-LoginCopyPlan \$a[0] \$a[1] \$a[2] \$a[3] \$a[4]) }" 2>/dev/null | tr '\n' ' ')"
SH_OUT="$(run_sh "$BASE/mlog0" 'login_copy_plan 0 "" "" 5 0; login_copy_plan 1 200 100 1 9; login_copy_plan 1 100 200 9 1; login_copy_plan 1 100 100 9 1; login_copy_plan 1 "" "" 9 1; login_copy_plan 1 "" "" 1 9; login_copy_plan 1 200 "" 1 9; login_copy_plan 1 "" "" 9 ""' | tr '\n' ' ')"
[ "$PW_OUT" = "copy:absent copy:older keep:newer keep:same copy:older keep:newer keep:newer keep:unknown " ]; t $? "[윈] Get-LoginCopyPlan 여덟 입력(수정 시각 못 읽음 = keep:unknown)" "[$PW_OUT]"
[ "$PW_OUT" = "$SH_OUT" ]; t $? "[동형] 맥 login_copy_plan 이 글자까지 같다" "윈[$PW_OUT] 맥[$SH_OUT]"

echo "== B2 윈 로그인 승계 네 갈래 =="
cred() { printf '{"claudeAiOauth":{"accessToken":"FAKE-AT-%s","refreshToken":"FAKE-RT-%s"%s}}' "$1" "$1" "${2:+,\"expiresAt\":$2}"; }
mkup() { # mkup <이름> <개인 글> [<자비스 글>] [<자비스 쪽이 더 새것: newer>]
  local u="$BASE/up-$1"; mkdir -p "$u/.claude" "$u/.cys/claude"
  printf '%s' "$2" > "$u/.claude/.credentials.json"
  if [ -n "${3:-}" ]; then printf '%s' "$3" > "$u/.cys/claude/.credentials.json"
    if [ "${4:-}" = newer ]; then touch -t 202609010000 "$u/.claude/.credentials.json"; touch -t 202609020000 "$u/.cys/claude/.credentials.json"
    else touch -t 202609020000 "$u/.claude/.credentials.json"; touch -t 202609010000 "$u/.cys/claude/.credentials.json"; fi
  fi
}
mkup L1 "$(cred S 2000)"
mkup L2 "$(cred S 2000)" "$(cred D 1000)"
mkup L3 "$(cred S 1000)" "$(cred D 2000)"
mkup L4 "$(cred S)" "$(cred D)" newer
mkup L5 "$(cred S)" "$(cred D)"
for c in L1 L2 L3 L4 L5; do run_ps "$c" '' 'Write-Output (Copy-LoginToIsolated)' >/dev/null; done
dst() { cat "$BASE/up-$1/.cys/claude/.credentials.json" 2>/dev/null; }
bak() { ls -A "$BASE/up-$1/.cys/claude/" 2>/dev/null | grep -c 'bak-jarvis'; }
[ "$(dst L1)" = "$(cred S 2000)" ] && [ "$(bak L1)" = 0 ] && grep -q '^login copy plan: copy:absent ' "$BASE/wlog-L1"
t $? "[윈 L1] 자비스 없음 → 옮김 · 앞 사본 없음" "$(grep 'login copy' "$BASE/wlog-L1" 2>/dev/null | tr '\n' '|')"
[ "$(dst L2)" = "$(cred S 2000)" ] && [ "$(cat "$BASE/up-L2/.cys/claude/.credentials.json.bak-jarvis" 2>/dev/null)" = "$(cred D 1000)" ] && grep -q '^login copy plan: copy:older (basis=expiresAt) — 자비스 쪽이 더 옛것 → 옮김$' "$BASE/wlog-L2"
t $? "[윈 L2] 자비스 옛것(만료 시각) → 옮김 · 앞 사본 = 옛 자비스 글" "$(grep 'login copy' "$BASE/wlog-L2" 2>/dev/null | tr '\n' '|')"
[ "$(dst L3)" = "$(cred D 2000)" ] && [ "$(bak L3)" = 0 ] && grep -q '^login copy plan: keep:newer (basis=expiresAt) — 자비스 쪽이 더 새것 → 그대로$' "$BASE/wlog-L3"
t $? "[윈 L3] 자비스 새것 → 그대로(앞 판은 여기서 옛 개인 글로 덮었다)" "$(grep 'login copy' "$BASE/wlog-L3" 2>/dev/null | tr '\n' '|')"
[ "$(dst L4)" = "$(cred D)" ] && grep -q '^login copy plan: keep:newer (basis=mtime)' "$BASE/wlog-L4" && [ "$(dst L5)" = "$(cred S)" ] && grep -q '^login copy plan: copy:older (basis=mtime)' "$BASE/wlog-L5"
t $? "[윈 L4·L5] 둘 다 만료 시각 없음 → 수정 시각으로 가른다(새것 유지 · 옛것 교체)" "$(grep 'login copy plan' "$BASE/wlog-L4" "$BASE/wlog-L5" 2>/dev/null | tr '\n' '|')"
# 앞 사본 1세대 — 한 번 더 옛것이 되어 옮기면 사본은 여전히 하나이고 방금 전 자비스 글이다
printf '%s' "$(cred S 3000)" > "$BASE/up-L2/.claude/.credentials.json"
run_ps L2 '' 'Write-Output (Copy-LoginToIsolated)' >/dev/null
[ "$(bak L2)" = 1 ] && [ "$(cat "$BASE/up-L2/.cys/claude/.credentials.json.bak-jarvis")" = "$(cred S 2000)" ]
t $? "[윈 L2'] 앞 사본은 1세대만(누적 없음 · 직전 자비스 글)" "bak=$(bak L2)"
! cat "$BASE"/wlog-L* 2>/dev/null | grep -qE 'FAKE-|expiresAt":|[^0-9](1000|2000|3000)([^0-9]|$)'; t $? "[윈] 기록에 토큰·만료 시각 값 0" "$(cat "$BASE"/wlog-L* | grep -E 'FAKE-|1000|2000' | head -2 | tr '\n' '|')"

echo "== B2 맥 로그인 승계 네 갈래(가짜 키체인) =="
mkdir -p "$BASE/fbin"
cat > "$BASE/fbin/security" <<'EOF'
#!/bin/bash
K="${FAKE_KC:?}"
if [ "$1" = -i ]; then
  while IFS= read -r l; do
    s="$(printf '%s' "$l" | sed -n 's/.* -s "\([^"]*\)" -X .*/\1/p')"; x="${l##* -X }"
    [ -n "$s" ] || continue
    printf '%s' "$x" | xxd -r -p > "$K/$s.pw"; echo "$FAKE_NOW" > "$K/$s.mdat"
  done; exit 0
fi
[ "$1" = find-generic-password ] || exit 1
shift; s=""; w=0
while [ $# -gt 0 ]; do case "$1" in -s) s="$2"; shift 2 ;; -a) shift 2 ;; -w) w=1; shift ;; *) shift ;; esac; done
[ -f "$K/$s.pw" ] || { echo "security: The specified item could not be found in the keychain." >&2; exit 44; }
if [ "$w" = 1 ]; then cat "$K/$s.pw"; echo; else printf 'keychain: "x"\nattributes:\n    "mdat"<timedate>=0x00  "%sZ\\000"\n' "$(cat "$K/$s.mdat")"; fi
EOF
chmod +x "$BASE/fbin/security"
ISO_SVC="Claude Code-credentials-$(printf '%s' "$BASE/home/.cys/claude" | shasum -a 256 | cut -c1-8)"
mkkc() { # mkkc <이름> <개인 글> <개인 mdat> [<자비스 글> <자비스 mdat>]
  local k="$BASE/kc-$1"; mkdir -p "$k"
  printf '%s' "$2" > "$k/Claude Code-credentials.pw"; echo "$3" > "$k/Claude Code-credentials.mdat"
  [ -n "${4:-}" ] && { printf '%s' "$4" > "$k/$ISO_SVC.pw"; echo "$5" > "$k/$ISO_SVC.mdat"; }
}
mkkc M1 "$(cred S 2000)" 20260902000000
mkkc M2 "$(cred S 2000)" 20260902000000 "$(cred D 1000)" 20260901000000
mkkc M3 "$(cred S 1000)" 20260902000000 "$(cred D 2000)" 20260901000000
mkkc M4 "$(cred S)" 20260901000000 "$(cred D)" 20260902000000
mkkc M5 "$(cred S)" 20260902000000 "$(cred D)" 20260901000000
for c in M1 M2 M3 M4 M5; do
  FAKE_KC="$BASE/kc-$c" FAKE_NOW=20260921000000 PATH="$BASE/fbin:$PATH" run_sh "$BASE/mlog-$c" \
    "claude_has_auth_cmd() { return 0; }; claude_profile_logged_in() { return 0; }; say() { printf '%s\n' \"\$*\" >> '$BASE/msay-$c'; }; copy_login_to_isolated" >/dev/null
done
kdst() { cat "$BASE/kc-$1/$ISO_SVC.pw" 2>/dev/null; }
kbak() { ls "$BASE/kc-$1/" 2>/dev/null | grep -c 'bak-jarvis\.pw'; }
[ "$(kdst M1)" = "$(cred S 2000)" ] && [ "$(kbak M1)" = 0 ] && grep -q ' login copy plan: copy:absent ' "$BASE/mlog-M1"
t $? "[맥 L1] 자비스 없음 → 옮김 · 앞 사본 없음" "$(grep 'login copy' "$BASE/mlog-M1" 2>/dev/null | tr '\n' '|')"
[ "$(kdst M2)" = "$(cred S 2000)" ] && [ "$(cat "$BASE/kc-M2/$ISO_SVC.bak-jarvis.pw" 2>/dev/null)" = "$(cred D 1000)" ] && grep -q ' login copy plan: copy:older (basis=expiresAt) — 자비스 쪽이 더 옛것 → 옮김$' "$BASE/mlog-M2"
t $? "[맥 L2] 자비스 옛것(만료 시각) → 옮김 · 앞 사본 = 옛 자비스 글" "$(grep 'login copy' "$BASE/mlog-M2" 2>/dev/null | tr '\n' '|')"
[ "$(kdst M3)" = "$(cred D 2000)" ] && [ "$(kbak M3)" = 0 ] && grep -q ' login copy plan: keep:newer (basis=expiresAt) — 자비스 쪽이 더 새것 → 그대로$' "$BASE/mlog-M3"
t $? "[맥 L3] 자비스 새것 → 그대로" "$(grep 'login copy' "$BASE/mlog-M3" 2>/dev/null | tr '\n' '|')"
[ "$(kdst M4)" = "$(cred D)" ] && grep -q ' login copy plan: keep:newer (basis=mtime)' "$BASE/mlog-M4" && [ "$(kdst M5)" = "$(cred S)" ] && grep -q ' login copy plan: copy:older (basis=mtime)' "$BASE/mlog-M5"
t $? "[맥 L4·L5] 둘 다 만료 시각 없음 → 수정 시각으로 가른다" "$(grep 'login copy plan' "$BASE/mlog-M4" "$BASE/mlog-M5" 2>/dev/null | tr '\n' '|')"
printf '%s' "$(cred S 3000)" > "$BASE/kc-M2/Claude Code-credentials.pw"
FAKE_KC="$BASE/kc-M2" FAKE_NOW=20260921000001 PATH="$BASE/fbin:$PATH" run_sh "$BASE/mlog-M2" \
  "claude_has_auth_cmd() { return 0; }; claude_profile_logged_in() { return 0; }; say() { :; }; copy_login_to_isolated" >/dev/null
[ "$(kbak M2)" = 1 ] && [ "$(cat "$BASE/kc-M2/$ISO_SVC.bak-jarvis.pw")" = "$(cred S 2000)" ]
t $? "[맥 L2'] 앞 사본은 1세대만(누적 없음 · 직전 자비스 글)" "bak=$(kbak M2)"
! cat "$BASE"/mlog-M* 2>/dev/null | grep -qE 'FAKE-|expiresAt":'; t $? "[맥] 기록에 토큰 값 0" "$(cat "$BASE"/mlog-M* | grep -E 'FAKE-' | head -2 | tr '\n' '|')"
# 두 OS 사람 말 동형(판정 → 한 줄)
[ "$(grep -h 'login copy plan' "$BASE/wlog-L3" | sed 's/^.*login copy plan: //')" = "$(grep -h 'login copy plan' "$BASE/mlog-M3" | sed 's/^.*login copy plan: //')" ]
t $? "[동형] 두 OS 판정 기록 줄이 글자까지 같다(L3)" "-"

echo "== [2/10] 망 실패 기계의 파일 없음 → 다른 인터넷 안내(도움 KW67JGJG) · 자식 오류 글 기록 =="
# 실물 claude 가 PATH 에 잡히지 않게 좁힌다(pwsh 링크만 둔 가짜 bin + /usr/bin:/bin) · 앞 절이 가짜 홈에 둔 가짜 claude 도 치운다.
rm -f "$BASE/home/.local/bin/claude"
mkdir -p "$BASE/pbin"; ln -sf "$PW" "$BASE/pbin/pwsh"
# 윈 가짜 공식 설치기 = 시험 안에서만 뜨는 로컬 서버(127.0.0.1 · 이 스크립트가 끝나면 프로세스 그룹째 내린다 · 바깥 0).
#   ⓘ 설치기가 오류 글을 남기고 0 으로 끝난다(파일은 안 만든다) — 종료 코드를 못 읽은 KW67JGJG 와 같은 판정 길로 들어간다.
mkdir -p "$BASE/srv"; printf "Write-Host 'Failed to fetch version from downloads.claude.ai'\nexit 0\n" > "$BASE/srv/install.ps1"
SRV_PORT="$(python3 - "$BASE/srv" "$BASE/srv.pgid" <<'PYS'
import os, socket, subprocess, sys
s = socket.socket(); s.bind(("127.0.0.1", 0)); port = s.getsockname()[1]; s.close()
p = subprocess.Popen([sys.executable, "-m", "http.server", str(port), "--bind", "127.0.0.1", "--directory", sys.argv[1]],
                     stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL, start_new_session=True)
open(sys.argv[2], "w").write(str(p.pid)); print(port)
PYS
)"
trap 'kill -- -"$(cat "$BASE/srv.pgid" 2>/dev/null)" 2>/dev/null; rm -rf "$BASE"' EXIT
for i in 1 2 3 4 5 6 7 8 9 10; do curl -s -o /dev/null "http://127.0.0.1:$SRV_PORT/install.ps1" && break; sleep 0.3; done
for c in N P; do
  nf='$true'; [ "$c" = P ] && nf='$false'
  mkdir -p "$BASE/wh-i$c" "$BASE/up-i$c"
  PATH="$BASE/pbin:/usr/bin:/bin" JARVIS_NO_PROGRESS=1 run_ps "i$c" "\$ClaudeInstallUrl = 'http://127.0.0.1:$SRV_PORT/install.ps1'; \$ClaudeInstallFastExitSec = 0; \$script:NetFailed = $nf
function Seed-LocalBinPath { }
function Send-EvidenceOnce { }" 'Write-Output (Step-InstallClaude)' >/dev/null
done
# ③ 윈 — 설치기가 예외로 죽는 경우(닫힌 포트 · 종료 코드 1 갈래): 오류 글이 기록을 닫기 전에 적히고 꼬리로 옮겨진다
mkdir -p "$BASE/wh-iE" "$BASE/up-iE"
PATH="$BASE/pbin:/usr/bin:/bin" JARVIS_NO_PROGRESS=1 run_ps "iE" "\$ClaudeInstallUrl = 'http://127.0.0.1:9/install.ps1'
function Seed-LocalBinPath { }
function Send-EvidenceOnce { }" 'Write-Output (Step-InstallClaude)' >/dev/null
grep -q 'J-DL-07' "$BASE/wsay-iN" && grep -q '처음 점검에서 인터넷 연결이 한 곳 이상 실패했습니다' "$BASE/wsay-iN" && ! grep -q 'J-PATH-01' "$BASE/wsay-iN"
t $? "[윈 망실패] 파일 없음+1-7 실패 → J-DL-07(다른 인터넷) · J-PATH-01 아님(걸린 시간 무관)" "$(grep -E '\[2/10\]|J-' "$BASE/wsay-iN" 2>/dev/null | tr '\n' '|' | cut -c1-300)"
grep -q '^J-DL-07 by: net-failed' "$BASE/wlog-iN"; t $? "[윈 망실패] 기록에 판정 근거 한 줄(net-failed)" "$(grep 'J-DL-07 by' "$BASE/wlog-iN" 2>/dev/null)"
grep -q 'J-PATH-01' "$BASE/wsay-iP" && ! grep -q 'J-DL-07' "$BASE/wsay-iP"
t $? "[윈 대조군] 1-7 이 성하고 빨리 안 끝났으면 종전대로 J-PATH-01" "$(grep -E 'J-' "$BASE/wsay-iP" 2>/dev/null | tr '\n' '|')"
grep -q 'Failed to fetch version' "$BASE/wsay-iN"; t $? "[윈 ③] 설치기가 한 말(0 으로 끝난 갈래)이 화면 꼬리·bootstrap.log 에 남는다" "-"
grep -q '^\[claude-install error\] ' "$BASE/wh-iE/claude-install.log" 2>/dev/null
t $? "[윈 ③] 설치기가 예외로 죽으면 오류 글이 기록(claude-install.log)에 남는다(기록을 닫기 전에 적는다)" "$(tail -c 300 "$BASE/wh-iE/claude-install.log" 2>/dev/null | tr '\n' '|')"
grep -q '실패 (종료 코드' "$BASE/wsay-iE" && grep -q '\[claude-install error\] ' "$BASE/wsay-iE"
t $? "[윈 ③] 종료 코드 실패 갈래도 그 오류 글을 화면 꼬리·bootstrap.log 로 옮긴다" "$(tr '\n' '|' < "$BASE/wsay-iE" 2>/dev/null | cut -c1-300)"

printf '#!/bin/bash\necho "Failed to fetch version from downloads.claude.ai" >&2\nexit 0\n' > "$BASE/fake-install.sh"
for c in N P; do
  nf=1; [ "$c" = P ] && nf=0
  PATH="/usr/bin:/bin" run_sh "$BASE/mlog-i$c" "CLAUDE_INSTALL_URL='file://$BASE/fake-install.sh'; CLAUDE_INSTALL_FAST_EXIT_SEC=0; NET_FAILED=$nf; REPORT_FILE='$BASE/mrep-i$c'
mkdir -p \"\$JARVIS_HOME\"; seed_local_bin_path() { :; }; evidence_once() { :; }; progress_send() { :; }
say() { printf '%s\n' \"\$*\" >> '$BASE/msay-i$c'; printf '%s\n' \"\$*\" >> \"\$LOG_FILE\"; }
step_install_claude" >/dev/null
done
grep -q 'J-DL-07' "$BASE/msay-iN" && grep -q '처음 점검에서 인터넷 연결이 한 곳 이상 실패했습니다' "$BASE/msay-iN" && ! grep -q 'J-PATH-01' "$BASE/msay-iN"
t $? "[맥 망실패] 파일 없음+1-7 실패 → J-DL-07 · J-PATH-01 아님" "$(grep -E '\[2/10\]|J-' "$BASE/msay-iN" 2>/dev/null | tr '\n' '|' | cut -c1-300)"
grep -q 'J-DL-07 by: net-failed' "$BASE/mlog-iN"; t $? "[맥 망실패] 기록에 판정 근거 한 줄(net-failed)" "-"
grep -q 'J-PATH-01' "$BASE/msay-iP" && ! grep -q 'J-DL-07' "$BASE/msay-iP"
t $? "[맥 대조군] 1-7 이 성하고 빨리 안 끝났으면 종전대로 J-PATH-01" "$(grep -E 'J-' "$BASE/msay-iP" 2>/dev/null | tr '\n' '|')"
grep -q 'Failed to fetch version' "$BASE/msay-iN"; t $? "[맥 ③] 자식 설치기의 오류 글(stderr)이 화면 꼬리·기록에 남는다" "-"

echo "== [2/10] 종료 코드 실패 갈래도 같은 축(master 판정 abb77ec4) =="
mkdir -p "$BASE/wh-iR" "$BASE/up-iR"
PATH="$BASE/pbin:/usr/bin:/bin" JARVIS_NO_PROGRESS=1 run_ps "iR" "\$ClaudeInstallUrl = 'http://127.0.0.1:9/install.ps1'; \$script:NetFailed = \$true
function Seed-LocalBinPath { }
function Send-EvidenceOnce { }" 'Write-Output (Step-InstallClaude)' >/dev/null
grep -q 'J-DL-07' "$BASE/wsay-iR" && grep -q '종료 코드 1) 파일이 생기지 않았습니다' "$BASE/wsay-iR" && ! grep -q '^\[2/10\] 실패 (종료 코드' "$BASE/wsay-iR" && grep -q '^J-DL-07 by: net-failed rc=1' "$BASE/wlog-iR"
t $? "[윈 종료코드] 파일 없음+1-7 실패 → J-DL-07(일반 「실패」 아님) · 기록 근거" "$(grep -E '\[2/10\]|J-' "$BASE/wsay-iR" 2>/dev/null | tr '\n' '|' | cut -c1-300)"
grep -q '^\[2/10\] 실패 (종료 코드 1)' "$BASE/wsay-iE" && ! grep -q 'J-DL-07' "$BASE/wsay-iE"
t $? "[윈 종료코드 대조군] 1-7 이 성하면 종전대로 일반 「실패」" "-"
printf '#!/bin/bash\necho "curl: (6) Could not resolve host: downloads.claude.ai" >&2\nexit 1\n' > "$BASE/fake-install-fail.sh"
for c in N P; do
  nf=1; [ "$c" = P ] && nf=0
  PATH="/usr/bin:/bin" run_sh "$BASE/mlog-r$c" "CLAUDE_INSTALL_URL='file://$BASE/fake-install-fail.sh'; NET_FAILED=$nf; REPORT_FILE='$BASE/mrep-r$c'
NET_WAIT_TIMEOUT=1; NET_WAIT_INTERVAL=1
mkdir -p \"\$JARVIS_HOME\"; seed_local_bin_path() { :; }; evidence_once() { :; }; progress_send() { :; }; net_cause() { echo offline; }
say() { printf '%s\n' \"\$*\" >> '$BASE/msay-r$c'; printf '%s\n' \"\$*\" >> \"\$LOG_FILE\"; }
step_install_claude; printf 'NEXT=%s\n' \"\$NEXT_STEP\" >> '$BASE/msay-r$c'" >/dev/null
done
grep -q '^NEXT=휴대폰 핫스팟 같은 다른 인터넷으로' "$BASE/msay-rN" && grep -q 'J-DL-07 by: net-failed rc=' "$BASE/mlog-rN" && grep -q 'Could not resolve host' "$BASE/msay-rN"
t $? "[맥 종료코드] 기다림 끝에도 안 붙고 파일 없음+1-7 실패 → 다른 인터넷 안내 · 기록 근거 · 설치기 글 꼬리" "$(tr '\n' '|' < "$BASE/msay-rN" 2>/dev/null | cut -c1-400)"
grep -q '^NEXT=연결이 된 뒤' "$BASE/msay-rP"; t $? "[맥 종료코드 대조군] 1-7 이 성하면 종전대로 「연결이 된 뒤」" "$(grep NEXT "$BASE/msay-rP" 2>/dev/null)"

echo "== rotate 부서 순회 생략(master 판정 0c0f5705) =="
cat > "$BASE/cysr" <<'EOF'
#!/bin/bash
S="${FAKE_CYS_STATE:?}"
case "$1" in
  --version) cat "$S/ver"; exit 0 ;;
  ping) echo pong; exit 0 ;;
  identify) printf '{\n  "daemon_pid": 100\n}\n'; exit 0 ;;
  list) exit 0 ;;
  rotate) echo "$* SKIP=${CYS_ROTATE_SKIP_DEPTS:-}" >> "$S/rotcalls"; echo "재시작 완료 — 알림 (rc=0)"; exit 0 ;;
esac
exit 0
EOF
chmod +x "$BASE/cysr"
for v in 112 113; do
  for os in w m; do d="$BASE/st-r$os$v"; mkdir -p "$d"; printf 'cys %s (build test)\n' "1.1.${v#11}" > "$d/ver"; done
  FAKE_CYS_STATE="$BASE/st-rw$v" JARVIS_LIB_ONLY=1 JARVIS_HOME="$BASE/wh-r$v" perl -e 'alarm shift; exec @ARGV or exit 126' 120 "$PW" -NoProfile -Command ". '$PS' *> \$null;
function Write-Log([string]\$m) { Add-Content -LiteralPath '$BASE/wlog-r$v' -Value \$m -Encoding UTF8 }
\$RotatePollMs = 200
Write-Output (Get-CysRotateState '$BASE/cysr')" >/dev/null 2>&1
  FAKE_CYS_STATE="$BASE/st-rm$v" run_sh "$BASE/mlog-r$v" "ROTATE_POLL_SEC=0.2; cys_rotate_state '$BASE/cysr'" >/dev/null
done
[ "$(cat "$BASE/st-rw113/rotcalls" 2>/dev/null)" = "rotate --timeout 120 --skip-depts SKIP=1" ] && [ "$(cat "$BASE/st-rw112/rotcalls" 2>/dev/null)" = "rotate --timeout 120 SKIP=1" ]
t $? "[윈 rotate] 1.1.3 = 인자+env · 1.1.2 = env 만(옛 cys 가 모르는 인자로 실패하지 않게)" "113[$(cat "$BASE/st-rw113/rotcalls" 2>/dev/null)] 112[$(cat "$BASE/st-rw112/rotcalls" 2>/dev/null)]"
[ "$(cat "$BASE/st-rm113/rotcalls" 2>/dev/null)" = "rotate --timeout 120 --skip-depts SKIP=1" ] && [ "$(cat "$BASE/st-rm112/rotcalls" 2>/dev/null)" = "rotate --timeout 120 SKIP=1" ]
t $? "[맥 rotate] 같음" "113[$(cat "$BASE/st-rm113/rotcalls" 2>/dev/null)] 112[$(cat "$BASE/st-rm112/rotcalls" 2>/dev/null)]"
grep -q 'skip-depts=env+arg' "$BASE/wlog-r113" && grep -q 'skip-depts=env cap=' "$BASE/wlog-r112" && grep -q 'skip-depts=env+arg' "$BASE/mlog-r113"
t $? "[두 OS rotate] 기록에 넘긴 방식 한 줄" "-"
PWF="$(JARVIS_LIB_ONLY=1 JARVIS_HOME="$BASE/wp" "$PW" -NoProfile -Command ". '$PS' *> \$null;
foreach (\$l in @('cys 1.1.2', 'cys 1.1.3 (x)', 'cysr v1.2.0', 'cys 2.0.0', 'cys 1.1.10', 'cys 0.14.36', '', 'error: no')) { Write-Output ('[' + (Get-RotateSkipDeptsFlag \$l) + ']') }" 2>/dev/null | tr '\n' ' ')"
SHF="$(run_sh "$BASE/mlog0" "for l in 'cys 1.1.2' 'cys 1.1.3 (x)' 'cysr v1.2.0' 'cys 2.0.0' 'cys 1.1.10' 'cys 0.14.36' '' 'error: no'; do printf '[%s]\n' \"\$(rotate_skip_depts_flag \"\$l\")\"; done" | tr '\n' ' ')"
[ "$PWF" = "[] [--skip-depts] [--skip-depts] [--skip-depts] [--skip-depts] [] [] [] " ] && [ "$PWF" = "$SHF" ]
t $? "[동형] 판번 판정 여덟 입력 두 OS 글자까지 같다(1.1.10 = 이상 · 판번 없음 = 인자 없음)" "윈[$PWF] 맥[$SHF]"

echo "== B2 개인 쪽 로그아웃(토큰 없음) → 옮기지 않음(master 판정 1b01748b · 899 L5) =="
# 개인 쪽 = 토큰이 빠진 글(수정 시각은 더 새것) · 자비스 쪽 = 살아 있는 로그인 — 앞 판은 수정 시각으로 copy:older 가 나와 덮었다
mkup L6 '{"claudeAiOauth":{}}' "$(cred D 1000)"
run_ps L6 '' 'Write-Output (Copy-LoginToIsolated)' >/dev/null
[ "$(dst L6)" = "$(cred D 1000)" ] && [ "$(bak L6)" = 0 ] && grep -q '^login copy plan: keep:src-logged-out (basis=token) — 개인 쪽에 로그인이 없음 → 옮기지 않음$' "$BASE/wlog-L6"
t $? "[윈 L6] 개인 쪽 로그아웃 → 자비스 쪽 그대로 · 앞 사본 없음 · 기록 근거" "$(grep 'login copy' "$BASE/wlog-L6" 2>/dev/null | tr '\n' '|')"
mkkc M6 '{"claudeAiOauth":{}}' 20260902000000 "$(cred D 1000)" 20260901000000
FAKE_KC="$BASE/kc-M6" FAKE_NOW=20260921000000 PATH="$BASE/fbin:$PATH" run_sh "$BASE/mlog-M6" \
  "claude_has_auth_cmd() { return 0; }; claude_profile_logged_in() { return 0; }; say() { :; }; copy_login_to_isolated" >/dev/null
[ "$(kdst M6)" = "$(cred D 1000)" ] && [ "$(kbak M6)" = 0 ] && grep -q ' login copy plan: keep:src-logged-out (basis=token) — 개인 쪽에 로그인이 없음 → 옮기지 않음$' "$BASE/mlog-M6"
t $? "[맥 L6] 같음(판정·기록 줄 동형)" "$(grep 'login copy' "$BASE/mlog-M6" 2>/dev/null | tr '\n' '|')"

printf '\n통과 %s · 실패 %s\n' "$pass" "$fail"
[ "$fail" -eq 0 ]
