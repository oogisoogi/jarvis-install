#!/bin/bash
# v0.3.18 맥 로그인 코드 자동 넣기 흉내 — 실물 bootstrap.sh 를 함수 묶음으로 읽고, 가짜 claude·pbpaste 로 login_run_fed 를 실제로 부른다.
#   재는 것: ⑴복사된 새 코드가 가짜 터미널(script) 안 로그인 프로세스의 입력으로 한 줄 들어간다(그 프로세스의 stdin 은 터미널)
#            ⑵로그인을 열기 전에 이미 복사돼 있던 코드는 넣지 않는다 ⑶로그인 프로세스가 끝나면 넣는 쪽도 끝난다(멈추지 않는다)
#            ⑷코드 글자는 기록에 남지 않는다
#   ⚠안 재는 것: 실제 claude 의 입력 칸 · 사람이 이 창에 붙여넣는 폴백(시험에는 터미널이 없다) · 실제 클립보드
# 쓰는 법: bash tests/v0318-mac-login-run.sh [--dir <install-master>]   rc 0 = 전건 통과
set -u
HERE="$(cd "$(dirname "$0")" && pwd)"
DIR="$HERE/../install-master"
[ "${1:-}" = "--dir" ] && DIR="$2"
SH="$(cd "$DIR" && pwd)/bootstrap.sh"
command -v script >/dev/null 2>&1 || { echo "잴 수 없음: script 가 없다" >&2; exit 2; }
BASE="$(mktemp -d -t v0318-maclogin)" || exit 2
trap 'rm -rf "$BASE"' EXIT
pass=0; fail=0
t() { if [ "$1" -eq 0 ]; then pass=$((pass+1)); printf '  ok   %s\n' "$2"; else fail=$((fail+1)); printf '  FAIL %s  ← %s\n' "$2" "$3"; fi; }
OLD='oldOLDold0123456789abcdefXYZ#oldstate0123456789'
NEW='newNEWnew0123456789abcdefXYZ#newstate0123456789'

run_case() { # run_case <이름> <pbpaste 가 돌려줄 것: 「old」 한 가지 또는 「old-then-new」>
  local name="$1" mode="$2" SB="$BASE/$1"
  mkdir -p "$SB/bin" "$SB/home"   # ⚠작업 폴더(install-jarvis)는 미리 만들지 않는다 — 설치기가 「자기가 만들지 않은 폴더」로 보고 J-HOME-01 로 멈춘다
  # 가짜 claude: 입력이 터미널인지 적고 · 한 줄을 (최대 8초) 기다려 받은 것을 적는다
  cat > "$SB/bin/claude" <<EOF
#!/bin/bash
[ -t 0 ] && echo tty > "$SB/stdin.txt" || echo notty > "$SB/stdin.txt"
printf 'Paste code here if prompted > '
if IFS= read -r -t 8 code; then printf '%s' "\$code" > "$SB/got.txt"; fi
echo; exit 0
EOF
  # 가짜 pbpaste: 처음 두 번은 OLD(로그인 열기 전부터 있던 코드) · old-then-new 이면 그 뒤 NEW
  cat > "$SB/bin/pbpaste" <<EOF
#!/bin/bash
n=\$(cat "$SB/clipn" 2>/dev/null || echo 0); n=\$((n+1)); echo \$n > "$SB/clipn"
if [ "$mode" = "old-then-new" ] && [ "\$n" -ge 3 ]; then printf '%s' '$NEW'; else printf '%s' '$OLD'; fi
EOF
  chmod +x "$SB/bin/claude" "$SB/bin/pbpaste"
  cat > "$SB/run.sh" <<EOF
. "$SH" || exit 9
LOGIN_TICK=1
LOGIN_WAIT_MARK="$SB/mark"; : > "\$LOGIN_WAIT_MARK"
login_run_fed "$SB/pid" </dev/null >/dev/null 2>&1
echo done > "$SB/done.txt"
EOF
  local t0=$SECONDS
  PATH="$SB/bin:$PATH" HOME="$SB/home" JARVIS_LIB_ONLY=1 \
    perl -e 'alarm shift; exec @ARGV' 40 bash "$SB/run.sh" </dev/null >/dev/null 2>&1
  ELAPSED=$((SECONDS - t0))
}

echo "== v0.3.18 맥 로그인 코드 자동 넣기 =="
run_case new old-then-new
SB="$BASE/new"; L="$(ls "$SB"/home/install-jarvis/*.log 2>/dev/null | head -1)"
[ "$(cat "$SB/got.txt" 2>/dev/null)" = "$NEW" ] && [ "$(cat "$SB/stdin.txt" 2>/dev/null)" = "tty" ]
t $? "[맥 로그인 · 새 코드] 복사된 새 코드가 가짜 터미널 안 로그인 프로세스에 한 줄로 들어간다" "받은 것=$(cat "$SB/got.txt" 2>/dev/null) · 입력=$(cat "$SB/stdin.txt" 2>/dev/null)"
[ -f "$SB/done.txt" ] && [ "$ELAPSED" -lt 30 ]
t $? "[맥 로그인 · 끝남] 로그인 프로세스가 끝나면 넣는 쪽도 끝나 설치가 이어진다" "끝나지 않았다(${ELAPSED}초)"
[ -n "$L" ] && grep -q 'login code sent from clipboard 1' "$L" && ! grep -qF "$NEW" "$L" && ! grep -qF "$OLD" "$L"
t $? "[맥 로그인 · 기록] 넣은 사실은 적고 코드 글자는 기록에 남기지 않는다" "기록=$L"
run_case old old
SB="$BASE/old"
[ ! -s "$SB/got.txt" ] && [ -f "$SB/done.txt" ]
t $? "[맥 로그인 · 복사 전 코드] 로그인을 열기 전에 이미 복사돼 있던 코드는 넣지 않는다" "받은 것=$(cat "$SB/got.txt" 2>/dev/null)"
grep -vE '^[[:space:]]*#' "$SH" | grep -qF 'login_run_fed "$LOGIN_PID_FILE" || true'
t $? "[맥 로그인 · 부르는 자리] step_login 이 로그인을 설치기가 입력을 쥔 길로 부른다" "부르는 자리가 없다"

printf '\n통과 %s · 실패 %s\n' "$pass" "$fail"
[ "$fail" -eq 0 ]
