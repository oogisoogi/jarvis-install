#!/bin/bash
# 0.3.36 — 본부 자비스(master)를 띄우는 wake 파일에 cys 좌석과 같은 claude 환경값 두 개가 실리는가(두 OS).
#
# 까닭: cys 는 동료 좌석(cso·worker)의 claude 에 CLAUDE_CODE_EFFORT_LEVEL=high · CLAUDE_CODE_ENABLE_PROMPT_SUGGESTION=false 를
#   넣는데, 본부 자비스는 설치기가 쓴 wake.sh / wake.ps1 이 띄워서 둘 다 없었다(깨끗한 맥 VM 실측 · 회색 제안 글 · 생각 깊이 기본값).
# 재는 것 — 글자 세기가 아니라 **만든 파일을 실제로 돌려** 가짜 claude 가 받은 환경값·인자를 대조한다.
#   ⓐ 키가 없을 때: 두 값이 high · false 로 들어간다
#   ⓑ 키가 있을 때(사용자 값): 손대지 않는다 — max · true 그대로 (맥은 빈 값도 그대로 · cys 주입과 같은 규칙)
#   ⓒ 따옴표 방어 유지: 첫 프롬프트(두 줄 · 작은따옴표 · $ · 백틱 · 우리말)가 인자 하나로 글자 그대로 간다 · 홈 경로에 작은따옴표·공백
#   ⓓ 부르는 자리: step_wake 가 write_wake_file 을 · Step-Wake 가 Get-WakeBody 를 쓴다(주석 걷고 잰다)
# 쓰는 법: bash tests/wake-env-run.sh [--dir <install-master 자리>]   · rc 0 = 통과 · 1 = 실패
# ⛔바깥에 닿지 않는다 — 진짜 claude·cys 호출 0 · 쓰기는 mktemp -d 안에서만.
# ⚠여기서 안 재는 것: 윈도우 PowerShell 5.1(이 시험은 pwsh 7 로 돈다) · claude.exe 고르기(맥에는 .exe 가 없어 이름으로 부르는 갈래만 탄다).
set -u
HERE="$(cd "$(dirname "$0")" && pwd)"
DIR="$HERE/../install-master"
[ "${1:-}" = "--dir" ] && DIR="$2"
SH="$(cd "$DIR" && pwd)/bootstrap.sh"
PS="$(cd "$DIR" && pwd)/bootstrap.ps1"
BASE="$(mktemp -d /tmp/wakeenvXXXXXX)" || exit 2
trap 'rm -rf "$BASE"' EXIT
pass=0; fail=0
t() { if [ "$1" -eq 0 ]; then pass=$((pass+1)); printf '  ok   %s\n' "$2"; else fail=$((fail+1)); printf '  FAIL %s  ← %s\n' "$2" "$3"; fi; }

PROMPT="너는 마스터다
it's '따옴표' \$HOME \`echo x\` 둘째 줄"
export PROMPT

# 가짜 claude — 받은 환경값 두 개와 인자(NUL 구분)를 적는다
fake_claude() { # fake_claude <자리>
  mkdir -p "$(dirname "$1")"
  cat > "$1" <<'EOF'
#!/bin/bash
{ printf 'EFFORT=%s\n' "${CLAUDE_CODE_EFFORT_LEVEL-<unset>}"; printf 'SUGG=%s\n' "${CLAUDE_CODE_ENABLE_PROMPT_SUGGESTION-<unset>}"; } > "$WE_OUT.env"
printf '%s\0' "$@" > "$WE_OUT.args"
EOF
  chmod +x "$1"
}
args_ok() { # args_ok <출력 앞머리> → rc 0 = 인자가 정확히 [--dangerously-skip-permissions, PROMPT]
  python3 - "$1.args" <<'PY'
import os, sys
a = open(sys.argv[1], "rb").read().split(b"\0")[:-1]
want = [b"--dangerously-skip-permissions", os.environ["PROMPT"].encode()]
sys.exit(0 if a == want else 1)
PY
}

# ── 맥 ──
H="$BASE/it's home"; mkdir -p "$H"
fake_claude "$H/.local/bin/claude"
# ⚠install-jarvis 안에 두지 않는다 — 설치기를 읽은 셸이 끝날 때 그 폴더의 옛 파일(wake.sh 포함)을 치운다(실측 · 시험 자리 문제)
WF="$H/w dir/wake.sh"; mkdir -p "$(dirname "$WF")"
env -i PATH="/usr/bin:/bin" HOME="$H" JARVIS_LIB_ONLY=1 SH="$SH" WF="$WF" PROMPT="$PROMPT" \
  bash -c '. "$SH" >/dev/null 2>&1; write_wake_file "$WF" "$PROMPT"' >/dev/null 2>&1
[ -x "$WF" ]; t $? "[맥] write_wake_file 이 실행 가능한 wake.sh 를 쓴다" "$(ls -l "$WF" 2>&1 | head -1)"

mac_run() { # mac_run <이름> [KEY=VAL …] — wake.sh 를 실제로 돌린다
  local n="$1"; shift
  rm -f "$BASE/$n.env" "$BASE/$n.args"
  env -i PATH="/usr/bin:/bin" HOME="$H" WE_OUT="$BASE/$n" "$@" perl -e 'alarm 30; exec @ARGV or exit 126' /bin/bash "$WF" >/dev/null 2>&1
}
mac_run m-absent
[ "$(cat "$BASE/m-absent.env" 2>/dev/null)" = "EFFORT=high
SUGG=false" ]; t $? "[ⓐ 맥] 키가 없으면 EFFORT=high · SUGGESTION=false 가 claude 에 간다" "$(tr '\n' ' ' < "$BASE/m-absent.env" 2>/dev/null)"
mac_run m-user CLAUDE_CODE_EFFORT_LEVEL=max CLAUDE_CODE_ENABLE_PROMPT_SUGGESTION=true
[ "$(cat "$BASE/m-user.env" 2>/dev/null)" = "EFFORT=max
SUGG=true" ]; t $? "[ⓑ 맥] 사용자 값(max · true)은 그대로" "$(tr '\n' ' ' < "$BASE/m-user.env" 2>/dev/null)"
mac_run m-empty CLAUDE_CODE_EFFORT_LEVEL= CLAUDE_CODE_ENABLE_PROMPT_SUGGESTION=
[ "$(cat "$BASE/m-empty.env" 2>/dev/null)" = "EFFORT=
SUGG=" ]; t $? "[ⓑ 맥] 빈 값도 있는 값으로 본다(cys 주입과 같은 규칙)" "$(tr '\n' ' ' < "$BASE/m-empty.env" 2>/dev/null)"
n="$(find "$H" -maxdepth 1 -name '.*' ! -name '.' ! -name '.local' 2>/dev/null | wc -l | tr -d ' ')"; [ "$n" = "0" ]
t $? "[ⓑ 맥] wake.sh 를 돌려도 가짜 홈에 새 점 파일(셸 프로필 등) 0" "$(find "$H" -maxdepth 1 -name '.*' ! -name '.' ! -name '.local' 2>/dev/null | tr '\n' ' ')"
args_ok "$BASE/m-absent"; t $? "[ⓒ 맥] 첫 프롬프트가 인자 하나로 글자 그대로(두 줄 · 작은따옴표 · \$ · 백틱) · 홈에 작은따옴표·공백" "$(tr '\0' '|' < "$BASE/m-absent.args" 2>/dev/null | head -c 200)"

# ⓔ 맥 행동 — cys 가 없어 이 창에서 띄우는 갈래를 실제로 돌린다(step_wake → exec 가짜 claude)
FH="$BASE/fb home"; mkdir -p "$FH"; fake_claude "$FH/.local/bin/claude"   # install-jarvis 는 설치기가 만든다(미리 만들면 J-HOME-01 로 거절)
env -i PATH="/usr/bin:/bin" HOME="$FH" JARVIS_HOME="$FH/install-jarvis" JARVIS_LIB_ONLY=1 JARVIS_NO_PROGRESS=1 CYS_CLI="$BASE/no-such-cys" \
    WE_OUT="$BASE/fb" SH="$SH" perl -e 'alarm 60; exec @ARGV or exit 126' /bin/bash -c '. "$SH" >/dev/null 2>&1; MODE=full; step_wake' </dev/null >/dev/null 2>&1
[ "$(cat "$BASE/fb.env" 2>/dev/null)" = "EFFORT=high
SUGG=false" ]; t $? "[ⓔ 맥] 창 폴백(cys 없음)으로 띄운 claude 도 EFFORT=high · 제안 글 끄기를 받는다(실제 step_wake)" "$(tr '\n' ' ' < "$BASE/fb.env" 2>/dev/null)"

r="$(python3 - "$SH" "$PS" <<'PY'
import re, sys
sh = open(sys.argv[1], encoding="utf-8").read()
ps = open(sys.argv[2], encoding="utf-8-sig").read()
def body(src, start, end):
    i = src.index(start); j = src.index(end, i + 1)
    return [l.split("#", 1)[0] for l in src[i:j].splitlines()]
out = []
# 부르는 자리가 있는 것만으로는 모자란다 — 그 뒤에 파일·본문을 다른 것으로 덮으면 시험은 함수만 재고 통과한다(이종 검토 반례).
b = body(sh, "\nstep_wake() {", "\n}\n")
call = sum(1 for l in b if re.search(r'^\s*write_wake_file "\$wake_file" "\$wake_prompt"\s*$', l))
other = sum(1 for l in b if re.search(r'>>?\s*"?\$wake_file\b', l) or re.search(r'^\s*wake_file=', l) and "wake.sh" not in l)
out.append("sh=" + ("1" if call == 1 and other == 0 else "0:call=%d,other=%d" % (call, other)))
b = body(ps, "\nfunction Step-Wake {", "\n}\n")
assign = [l for l in b if re.search(r'\$wakeBody\s*[+]?=', l)]
write = sum(1 for l in b if re.search(r'WriteAllText\(\$wakeFile, \$wakeBody, \$enc\)', l))
ok = len(assign) == 1 and re.search(r'^\s*\$wakeBody = Get-WakeBody \$wakeQuoted\s*$', assign[0]) and write == 1
out.append("ps=" + ("1" if ok else "0:assign=%d,write=%d" % (len(assign), write)))
# 창 폴백(0.3.36): 이 창에서 claude 를 띄우는 줄 바로 앞(주석·빈 줄 건너뜀)에 같은 두 값 — 맥 eval "$WAKE_CLAUDE_ENV" · 윈 두 if 줄
def before(lines, pat, n):
    k = next((i for i, l in enumerate(lines) if re.search(pat, l)), None)
    if k is None: return None
    got = [l.strip() for l in lines[:k] if l.strip()][-n:]
    return got
bs = [l.split("#", 1)[0] for l in body(sh, "\nstep_wake() {", "\n}\n")]
g = before(bs, r'^\s*exec "\$claude_bin" --dangerously-skip-permissions', 1)
out.append("sh-fb=" + ("1" if g == ['eval "$WAKE_CLAUDE_ENV"'] else "0:%s" % g))
bp = [l.split("#", 1)[0] for l in body(ps, "\nfunction Step-Wake {", "\n}\n")]
g = before(bp, r'^\s*& \$fallbackExe --dangerously-skip-permissions', 2)
want = ["if (-not (Test-Path Env:CLAUDE_CODE_EFFORT_LEVEL)) { $env:CLAUDE_CODE_EFFORT_LEVEL = 'high' }",
        "if (-not (Test-Path Env:CLAUDE_CODE_ENABLE_PROMPT_SUGGESTION)) { $env:CLAUDE_CODE_ENABLE_PROMPT_SUGGESTION = 'false' }"]
out.append("ps-fb=" + ("1" if g == want else "0:%s" % g))
# 영구 기록 금지(부정 축) — 사용자 환경(레지스트리·셸 프로필)에 쓰면 다음부터 「키가 이미 있다」로 읽혀 규칙이 무너진다(적대 검토 반례 · 맥 pwsh 로는 안 보인다)
#   범위 = 쓰는 함수 + 부르는 함수(주석 걷고 · 적대 검토 2회차: 범위 밖·주석 거짓 적색) · 행동 축(가짜 HOME 새 점 파일 0)은 아래 셸에서 따로 잰다.
def cut(src, start):
    t = src[src.index(start):]; return t[:t.index("\n}\n")]
nc = lambda t: "\n".join(l.split("#", 1)[0] for l in t.splitlines())
scope = nc(cut(sh, "\nwrite_wake_file() {")) + nc(cut(sh, "\nstep_wake() {")) + nc(cut(ps, "\nfunction Get-WakeBody")) + nc(cut(ps, "\nfunction Step-Wake {"))
bad = re.compile(r"SetEnvironmentVariable|setx|launchctl\s+setenv|\$PROFILE|\.(zshrc|zshenv|zprofile|bashrc|bash_profile|profile)\b|HKCU:|Registry::", re.I)
m = bad.search(scope)
out.append("persist=" + ("0:" + m.group(0) if m else "1"))
print(" ".join(out))
PY
)" || r="python-fail"
case "$r" in *sh=1*) true ;; *) false ;; esac; t $? "[ⓓ 맥] step_wake 가 write_wake_file 로 wake.sh 를 쓴다" "$r"
case "$r" in *ps=1*) true ;; *) false ;; esac; t $? "[ⓓ 윈] Step-Wake 가 Get-WakeBody 로 wake.ps1 본문을 만든다" "$r"
case "$r" in *sh-fb=1*) true ;; *) false ;; esac; t $? "[ⓔ 맥] 창 폴백(exec claude) 바로 앞에 같은 두 값(eval WAKE_CLAUDE_ENV)" "$r"
case "$r" in *ps-fb=1*) true ;; *) false ;; esac; t $? "[ⓔ 윈] 창 폴백(& \$fallbackExe) 바로 앞에 같은 두 값(키 없을 때만 · 프로세스 범위)" "$r"
case "$r" in *persist=1*) true ;; *) false ;; esac; t $? "[ⓑ 두 OS] 환경값은 이 실행 안에서만 — 사용자 환경·셸 프로필·레지스트리에 영구 기록 0" "$r"

# ── 윈(pwsh 7) ──
PW="$(command -v pwsh 2>/dev/null)"
if [ -z "$PW" ]; then
  # 건너뜀을 통과로 세지 않는다 — 윈 줄을 지운 변이가 pwsh 없는 기계에서 초록이 되던 자리(이종 검토 반례)
  t 1 "[윈] pwsh 가 있어야 윈 wake.ps1 을 실제로 돌려 잰다" "pwsh 없음 — 설치(brew install powershell) 뒤 다시"
else
  WH="$BASE/it's win"; mkdir -p "$WH/bin"
  fake_claude "$WH/bin/claude"
  WP="$WH/wake.ps1"
  env -u CLAUDE_CODE_EFFORT_LEVEL -u CLAUDE_CODE_ENABLE_PROMPT_SUGGESTION JARVIS_LIB_ONLY=1 JARVIS_HOME="$WH/jh" PS_SRC="$PS" WP="$WP" \
    perl -e 'alarm 90; exec @ARGV or exit 126' "$PW" -NoProfile -Command '. $env:PS_SRC *> $null
$q = $env:PROMPT -replace "'"'"'", "'"''"'"
[System.IO.File]::WriteAllText($env:WP, (Get-WakeBody $q), (New-Object System.Text.UTF8Encoding($true)))' >/dev/null 2>&1
  [ -s "$WP" ]; t $? "[윈] Get-WakeBody 로 wake.ps1 을 쓴다(BOM)" "$(head -c 120 "$WP" 2>/dev/null | tr '\r\n' '||')"
  win_run() { # win_run <이름> [KEY=VAL …]
    local n="$1"; shift
    rm -f "$BASE/$n.env" "$BASE/$n.args"
    env -u CLAUDE_CODE_EFFORT_LEVEL -u CLAUDE_CODE_ENABLE_PROMPT_SUGGESTION PATH="$WH/bin:$PATH" WE_OUT="$BASE/$n" "$@" \
      perl -e 'alarm 60; exec @ARGV or exit 126' "$PW" -NoProfile -File "$WP" </dev/null >/dev/null 2>&1
  }
  win_run w-absent
  [ "$(cat "$BASE/w-absent.env" 2>/dev/null)" = "EFFORT=high
SUGG=false" ]; t $? "[ⓐ 윈] 키가 없으면 EFFORT=high · SUGGESTION=false 가 claude 에 간다" "$(tr '\n' ' ' < "$BASE/w-absent.env" 2>/dev/null)"
  win_run w-user CLAUDE_CODE_EFFORT_LEVEL=max CLAUDE_CODE_ENABLE_PROMPT_SUGGESTION=true
  [ "$(cat "$BASE/w-user.env" 2>/dev/null)" = "EFFORT=max
SUGG=true" ]; t $? "[ⓑ 윈] 사용자 값(max · true)은 그대로" "$(tr '\n' ' ' < "$BASE/w-user.env" 2>/dev/null)"
  args_ok "$BASE/w-absent"; t $? "[ⓒ 윈] 첫 프롬프트가 인자 하나로 글자 그대로(작은따옴표 두 번 쓰기 유지)" "$(tr '\0' '|' < "$BASE/w-absent.args" 2>/dev/null | head -c 200)"
fi

echo "== 합계: ok $pass · FAIL $fail =="
[ "$fail" -eq 0 ]
