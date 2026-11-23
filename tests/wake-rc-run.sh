#!/bin/bash
# 0.3.47 — 설치기가 띄우는 본부 자비스(master)가 설치·갱신 직후부터 RC 를 켜고 뜨는가(두 OS).
#
# 까닭(운영자 결정 11-23 · RC 는 기본으로 켜져 있어야 한다 — 단, 본부 자비스(master)만):
#   설치기 [9/10] 은 master 좌석을 `cys new-surface --cmd "bash wake.sh"` 로 연다 — cys 가 자기가 claude 를 띄우는 기동(복원 포함)에만 붙이는
#   좌석 설정(--settings · RC 켬)이 닿지 않아, 설치 직후 master RC 가 꺼져 있고 다음 복원부터 켜졌다(맥 VM 실측).
#   ⇒ 설치기가 ~/.cys/seat-settings/master-wake.json 을 쓰고 wake 파일·창 폴백의 claude 에 --settings 로 넘긴다.
# 재는 것 — 글자 세기가 아니라 **실제로 돌려** 가짜 claude 가 받은 인자를 대조한다.
#   ⓐ 설정 파일 쓰기: 폴더가 없어도 만든다 · 내용 = {"remoteControlAtStartup": true} 정확히 · 임시 파일 잔재 0 · 재설치(다른 내용) = 덮음 · 못 쓰면 rc 1
#   ⓑ wake 파일: 설정 파일이 있으면 [--dangerously-skip-permissions, --settings, <파일>, 첫 프롬프트] · 없으면 종전 [--dangerously-skip-permissions, 첫 프롬프트]
#      (홈 경로에 작은따옴표·공백 · 첫 프롬프트 글자 그대로)
#   ⓒ 맥 창 폴백(실제 step_wake · cys 없음): 파일을 쓰고 --settings 를 넘긴다 · 사용자 settings.json 두 곳 바이트 무변 · 쓰기 실패 = 인자 없이 종전대로 뜬다 · dry 는 파일을 안 쓴다
#   ⓓ 윈 창 폴백·부르는 자리(주석 걷고): Step-Wake 가 [9/10] 갈래 앞에서 Write-MasterWakeSettings 를 부르고 & $fallbackExe 에 @rcArgs 를 싣는다
#   ⓔ 범위(부정 축): 설정 파일 이름을 쓰는 자리는 wake 함수들뿐 — cso·worker·다른 단계는 이 파일을 모른다 · 두 OS 내용 글자 같음
# 쓰는 법: bash tests/wake-rc-run.sh [--dir <install-master 자리>]   · rc 0 = 통과 · 1 = 실패
# ⛔바깥에 닿지 않는다 — 진짜 claude·cys 호출 0 · 쓰기는 mktemp -d 안에서만.
# ⚠여기서 안 재는 것: 진짜 claude 가 --settings 를 사용자 설정보다 위로 읽는가(= 맥 VM 실측 · [9/10] 직후 footer /rc active) · 윈도우 PowerShell 5.1(pwsh 7 로 돈다).
set -u
HERE="$(cd "$(dirname "$0")" && pwd)"
DIR="$HERE/../install-master"
[ "${1:-}" = "--dir" ] && DIR="$2"
SH="$(cd "$DIR" && pwd)/bootstrap.sh"
PS="$(cd "$DIR" && pwd)/bootstrap.ps1"
BASE="$(mktemp -d /tmp/wakercXXXXXX)" || exit 2
trap 'chmod -R u+w "$BASE" 2>/dev/null; rm -rf "$BASE"' EXIT
pass=0; fail=0
t() { if [ "$1" -eq 0 ]; then pass=$((pass+1)); printf '  ok   %s\n' "$2"; else fail=$((fail+1)); printf '  FAIL %s  ← %s\n' "$2" "$3"; fi; }

PROMPT="너는 마스터다
it's '따옴표' \$HOME \`echo x\` 둘째 줄"
export PROMPT
WANT_JSON='{"remoteControlAtStartup": true}'
REL='.cys/seat-settings/master-wake.json'

fake_claude() { # fake_claude <자리> — 받은 인자(NUL 구분)를 적는다
  mkdir -p "$(dirname "$1")"
  cat > "$1" <<'EOF'
#!/bin/bash
printf '%s\0' "$@" > "$WE_OUT.args"
EOF
  chmod +x "$1"
}
args_is() { # args_is <출력 앞머리> <기대 인자…> → rc 0 = 받은 인자가 정확히 그것
  local f="$1.args"; shift
  python3 - "$f" "$@" <<'PY'
import sys
try: a = open(sys.argv[1], "rb").read().split(b"\0")[:-1]
except OSError: sys.exit(1)
sys.exit(0 if a == [x.encode() for x in sys.argv[2:]] else 1)
PY
}
json_ok() { # json_ok <파일> → rc 0 = 내용이 정확히 WANT_JSON + 줄바꿈 · JSON 으로 읽혀 remoteControlAtStartup 가 true 하나뿐 · BOM 없음
  python3 - "$1" "$WANT_JSON" <<'PY'
import json, sys
b = open(sys.argv[1], "rb").read()
ok = b in (sys.argv[2].encode() + b"\n",) and json.loads(b.decode()) == {"remoteControlAtStartup": True}
sys.exit(0 if ok else 1)
PY
}
show() { tr '\0' '|' < "$1.args" 2>/dev/null | head -c 240; }

# ── 맥 ⓐ 설정 파일 쓰기 ──
mac_write() { # mac_write <홈> → write_master_wake_settings 의 rc
  env -i PATH="/usr/bin:/bin" HOME="$1" JARVIS_LIB_ONLY=1 SH="$SH" bash -c '. "$SH" >/dev/null 2>&1; write_master_wake_settings' >/dev/null 2>&1
}
A="$BASE/a home"; mkdir -p "$A"
mac_write "$A"; r=$?
[ "$r" -eq 0 ] && [ -f "$A/$REL" ]; t $? "[ⓐ 맥] 폴더가 없어도 ~/$REL 을 만든다(rc 0)" "rc=$r $(ls -la "$A/.cys/seat-settings" 2>&1 | tail -n +2 | tr '\n' ' ')"
json_ok "$A/$REL"; t $? "[ⓐ 맥] 내용 = {\"remoteControlAtStartup\": true} 정확히(BOM·다른 키 0)" "$(od -c "$A/$REL" 2>/dev/null | head -3 | tr '\n' ' ')"
n="$(find "$A/.cys/seat-settings" -name '.master-wake.*' 2>/dev/null | wc -l | tr -d ' ')"; [ "$n" = 0 ]; t $? "[ⓐ 맥] 임시 파일 잔재 0" "남은 임시 파일 $n"
[ "$(stat -f '%Lp' "$A/$REL" 2>/dev/null)" = 644 ]; t $? "[ⓐ 맥] 파일 권한 644(claude 가 읽는다)" "$(stat -f '%Lp' "$A/$REL" 2>&1)"
printf '{"remoteControlAtStartup": false, "x": 1}\n' > "$A/$REL"
mac_write "$A"; r=$?
[ "$r" -eq 0 ] && json_ok "$A/$REL"; t $? "[ⓐ 맥] 재설치 — 다른 내용이 있으면 같은 내용으로 덮는다" "rc=$r $(cat "$A/$REL" 2>&1)"
R="$BASE/ro home"; mkdir -p "$R/.cys/seat-settings"; chmod 555 "$R/.cys/seat-settings"
mac_write "$R"; r=$?
[ "$r" -ne 0 ] && [ ! -e "$R/$REL" ]; t $? "[ⓐ 맥] 못 쓰는 폴더 = rc 1 · 반쪽 파일 0" "rc=$r $(ls -la "$R/.cys/seat-settings" 2>&1 | tr '\n' ' ')"
chmod 755 "$R/.cys/seat-settings"
K="$BASE/dir home"; mkdir -p "$K/$REL"   # 그 자리가 폴더(이종 검토 반례: mv 가 그 안으로 옮기고 성공했다)
mac_write "$K"; r=$?
n="$(find "$K/.cys/seat-settings" -name '.master-wake.*' 2>/dev/null | wc -l | tr -d ' ')"
[ "$r" -ne 0 ] && [ "$n" = 0 ]; t $? "[ⓐ 맥] 그 자리가 폴더면 rc 1 · 폴더 안·옆 임시 파일 0" "rc=$r 남은 임시 파일 $n"

# ── 맥 ⓑ wake.sh ──
H="$BASE/it's home"; mkdir -p "$H"
fake_claude "$H/.local/bin/claude"
WF="$H/w dir/wake.sh"; mkdir -p "$(dirname "$WF")"
env -i PATH="/usr/bin:/bin" HOME="$H" JARVIS_LIB_ONLY=1 SH="$SH" WF="$WF" PROMPT="$PROMPT" \
  bash -c '. "$SH" >/dev/null 2>&1; write_wake_file "$WF" "$PROMPT"' >/dev/null 2>&1
mac_run() { # mac_run <이름> — wake.sh 를 실제로 돌린다
  rm -f "$BASE/$1.args"
  env -i PATH="/usr/bin:/bin" HOME="$H" WE_OUT="$BASE/$1" perl -e 'alarm 30; exec @ARGV or exit 126' /bin/bash "$WF" >/dev/null 2>&1
}
mac_run m-none
args_is "$BASE/m-none" --dangerously-skip-permissions "$PROMPT"; t $? "[ⓑ 맥] 설정 파일이 없으면 종전 인자 그대로([--dangerously-skip-permissions, 첫 프롬프트])" "$(show "$BASE/m-none")"
mac_write "$H"
mac_run m-rc
args_is "$BASE/m-rc" --dangerously-skip-permissions --settings "$H/$REL" "$PROMPT"; t $? "[ⓑ 맥] 설정 파일이 있으면 --settings <그 파일> · 홈에 작은따옴표·공백 · 첫 프롬프트 글자 그대로" "$(show "$BASE/m-rc")"
printf '{"remoteControlAtStartup": tr' > "$H/$REL"   # 깨진 옛 파일(이번 쓰기가 실패해 남은 것)
mac_run m-bad
args_is "$BASE/m-bad" --dangerously-skip-permissions "$PROMPT"; t $? "[ⓑ 맥] 내용이 우리 글자가 아니면(깨진 옛 파일) --settings 를 넘기지 않는다" "$(show "$BASE/m-bad")"
printf '%s\n' "$WANT_JSON" > "$H/$REL"; chmod 000 "$H/$REL"
mac_run m-unread
args_is "$BASE/m-unread" --dangerously-skip-permissions "$PROMPT"; t $? "[ⓑ 맥] 못 읽는 파일이면 --settings 를 넘기지 않는다" "$(show "$BASE/m-unread")"
chmod 644 "$H/$REL"
printf '{"remoteControlAtStartup": true}\0\n' > "$H/$REL"   # NUL 이 섞인 깨진 옛 파일(이종 검토 2차 반례: 글자 비교는 같다고 봤다)
mac_run m-nul
args_is "$BASE/m-nul" --dangerously-skip-permissions "$PROMPT"; t $? "[ⓑ 맥] NUL 이 섞인 파일이면 --settings 를 넘기지 않는다(바이트 대조)" "$(show "$BASE/m-nul")"
rm -f "$H/$REL"; mkfifo "$H/$REL"   # FIFO(이종 검토 2차 반례: 열면 쓰는 쪽이 없어 멈춘다)
mac_run m-fifo
args_is "$BASE/m-fifo" --dangerously-skip-permissions "$PROMPT"; t $? "[ⓑ 맥] 그 자리가 FIFO 면 멈추지 않고 --settings 없이 뜬다" "$(show "$BASE/m-fifo")"
rm -f "$H/$REL"

# ── 맥 ⓒ 창 폴백(실제 step_wake) ──
fb_run() { # fb_run <이름> <홈> [MODE] — cys 가 없어 이 창에서 띄우는 갈래를 실제로 돌린다
  rm -f "$BASE/$1.args"
  env -i PATH="/usr/bin:/bin" HOME="$2" JARVIS_HOME="$2/install-jarvis" JARVIS_LIB_ONLY=1 JARVIS_NO_PROGRESS=1 CYS_CLI="$BASE/no-such-cys" \
      WE_OUT="$BASE/$1" SH="$SH" M="${3:-full}" perl -e 'alarm 60; exec @ARGV or exit 126' /bin/bash -c '. "$SH" >/dev/null 2>&1; MODE="$M"; step_wake' </dev/null >/dev/null 2>&1
}
F="$BASE/fb home"; mkdir -p "$F/.claude" "$F/.cys/claude"; fake_claude "$F/.local/bin/claude"
printf '{"remoteControlAtStartup": false, "theme": "dark"}\n' > "$F/.claude/settings.json"
printf '{"remoteControlAtStartup": false, "skipDangerousModePermissionPrompt": true}\n' > "$F/.cys/claude/settings.json"
before="$(cat "$F/.claude/settings.json" "$F/.cys/claude/settings.json" | shasum -a 256)"
fb_run fb "$F"
json_ok "$F/$REL"; t $? "[ⓒ 맥] 창 폴백 — step_wake 가 설정 파일을 쓴다" "$(cat "$F/$REL" 2>&1)"
python3 - "$BASE/fb.args" "$F/$REL" <<'PY'
import sys
try: a = open(sys.argv[1], "rb").read().split(b"\0")[:-1]
except OSError: sys.exit(1)
sys.exit(0 if len(a) == 4 and a[:3] == [b"--dangerously-skip-permissions", b"--settings", sys.argv[2].encode()] and a[3].startswith("너는".encode()) else 1)
PY
t $? "[ⓒ 맥] 창 폴백 claude 에 --settings <그 파일> · 첫 프롬프트는 마지막 인자 하나" "$(show "$BASE/fb")"
after="$(cat "$F/.claude/settings.json" "$F/.cys/claude/settings.json" | shasum -a 256)"
[ "$before" = "$after" ]; t $? "[ⓒ 맥] 사용자 settings.json 두 곳(~/.claude · ~/.cys/claude) 바이트 무변" "before=$before after=$after"
X="$BASE/x home"; mkdir -p "$X"; fake_claude "$X/.local/bin/claude"; : > "$X/.cys"   # ~/.cys 가 파일 = 폴더를 못 만든다
fb_run fbx "$X"
python3 - "$BASE/fbx.args" <<'PY'
import sys
try: a = open(sys.argv[1], "rb").read().split(b"\0")[:-1]
except OSError: sys.exit(1)
sys.exit(0 if len(a) == 2 and a[0] == b"--dangerously-skip-permissions" and a[1].startswith("너는".encode()) else 1)
PY
t $? "[ⓒ 맥] 설정 파일을 못 쓰면 --settings 없이 종전대로 뜬다(설치가 멈추지 않는다)" "$(show "$BASE/fbx")"
D="$BASE/dry home"; mkdir -p "$D"; fake_claude "$D/.local/bin/claude"
fb_run dry "$D" dry
[ ! -e "$D/$REL" ]; t $? "[ⓒ 맥] dry-run 은 설정 파일을 쓰지 않는다" "$(ls -la "$D/.cys/seat-settings" 2>&1 | tr '\n' ' ')"
Y="$BASE/stale home"; mkdir -p "$Y/.cys/seat-settings"; fake_claude "$Y/.local/bin/claude"
printf '{"remoteControlAtStartup": tr' > "$Y/$REL"; chmod 555 "$Y/.cys/seat-settings"   # 깨진 옛 파일 + 이번 쓰기 실패(폴더 쓰기 금지)
fb_run fby "$Y"
chmod 755 "$Y/.cys/seat-settings"
python3 - "$BASE/fby.args" <<'PY'
import sys
try: a = open(sys.argv[1], "rb").read().split(b"\0")[:-1]
except OSError: sys.exit(1)
sys.exit(0 if len(a) == 2 and a[0] == b"--dangerously-skip-permissions" and a[1].startswith("너는".encode()) else 1)
PY
t $? "[ⓒ 맥] 쓰기 실패 + 깨진 옛 파일 = 창 폴백이 그 파일을 넘기지 않는다(이종 검토 반례)" "$(show "$BASE/fby")"
N="$BASE/nul home"; mkdir -p "$N/.cys/seat-settings"; fake_claude "$N/.local/bin/claude"
printf '{"remoteControlAtStartup": true}\0\n' > "$N/$REL"; chmod 555 "$N/.cys/seat-settings"   # NUL 섞인 옛 파일 + 이번 쓰기 실패
fb_run fbn "$N"
chmod 755 "$N/.cys/seat-settings"
python3 - "$BASE/fbn.args" <<'PY'
import sys
try: a = open(sys.argv[1], "rb").read().split(b"\0")[:-1]
except OSError: sys.exit(1)
sys.exit(0 if len(a) == 2 and a[0] == b"--dangerously-skip-permissions" and a[1].startswith("너는".encode()) else 1)
PY
t $? "[ⓒ 맥] 쓰기 실패 + NUL 섞인 옛 파일 = 창 폴백이 그 파일을 넘기지 않는다(이종 검토 2차 반례)" "$(show "$BASE/fbn")"

# ── 정적 ⓓ·ⓔ(주석 걷고) ──
r="$(python3 - "$SH" "$PS" <<'PY'
import re, sys
sh = open(sys.argv[1], encoding="utf-8").read()
ps = open(sys.argv[2], encoding="utf-8-sig").read()
nc = lambda t: [l.split("#", 1)[0] for l in t.splitlines()]
def cut(src, start):
    t = src[src.index(start):]; return t[:t.index("\n}\n")]
out = []
# ⓓ 윈 Step-Wake: 부르는 자리가 cli 고르기(갈래 앞) 앞 · 창 폴백 줄 앞에 rcArgs 두 줄
b = nc(cut(ps, "\nfunction Step-Wake {"))
ci = next((i for i, l in enumerate(b) if re.search(r'^\s*if \(Write-MasterWakeSettings\)', l)), None)
li = next((i for i, l in enumerate(b) if re.search(r'^\s*\$cli = if \(\$script:CysCli\)', l)), None)
calls = sum(1 for l in b if "Write-MasterWakeSettings" in l)
out.append("ps-call=" + ("1" if ci is not None and li is not None and ci < li and calls == 1 else "0:%s,%s,%d" % (ci, li, calls)))
fi = next((i for i, l in enumerate(b) if re.search(r'^\s*& \$fallbackExe --dangerously-skip-permissions @rcArgs \$fallbackPrompt\s*$', l)), None)
got = [l.strip() for l in b[:fi] if l.strip()][-2:] if fi is not None else None
want = ["$rcSettings = Join-Path $env:USERPROFILE $MasterWakeSettingsRel",
        "$rcArgs = @(); if (Test-MasterWakeSettings $rcSettings) { $rcArgs = @('--settings', $rcSettings) }"]
out.append("ps-fb=" + ("1" if got == want else "0:%s" % got))
# 맥 step_wake: 부르는 자리가 cli 고르기 앞 · 1곳
b = nc(cut(sh, "\nstep_wake() {"))
ci = next((i for i, l in enumerate(b) if re.search(r'^\s*if write_master_wake_settings; then', l)), None)
li = next((i for i, l in enumerate(b) if re.search(r'^\s*cli="\$\{CYS_CLI:-cys\}"', l)), None)
calls = sum(1 for l in b if "write_master_wake_settings" in l)
out.append("sh-call=" + ("1" if ci is not None and li is not None and ci < li and calls == 1 else "0:%s,%s,%d" % (ci, li, calls)))
# ⓔ 범위: 설정 파일 이름·변수를 쓰는 함수 = 정해진 것뿐(cso·worker·다른 단계 0)
def funcs_using(src, pat, fdef):
    names = set(); cur = None
    for l in src.splitlines():
        m = re.match(fdef, l)
        if m: cur = m.group(1)
        code = l.split("#", 1)[0]
        if re.search(pat, code): names.add(cur)
    return names
sh_use = funcs_using(sh, r'MASTER_WAKE_SETTINGS|master-wake\.json', r'^([A-Za-z_][A-Za-z0-9_]*)\(\) *\{')
ps_use = funcs_using(ps, r'MasterWakeSettings|master-wake\.json', r'^function ([A-Za-z0-9_-]+)')
ok_sh = sh_use <= {"write_wake_file", "master_wake_settings_ok", "write_master_wake_settings", "step_wake", "start_cys_app_window"}
ok_ps = ps_use <= {"Get-WakeBody", "Test-MasterWakeSettings", "Write-MasterWakeSettings", "Step-Wake", "Start-CysAppWindow"}
out.append("scope=" + ("1" if ok_sh and ok_ps else "0:sh=%s ps=%s" % (sorted(map(str, sh_use)), sorted(map(str, ps_use)))))
# 두 OS 내용 글자 같음 · 파일 이름 같음
mj = re.search(r"^MASTER_WAKE_SETTINGS_JSON='([^']*)'", sh, re.M); pj = re.search(r"^\$MasterWakeSettingsJson = '([^']*)'", ps, re.M)
mr = re.search(r"^MASTER_WAKE_SETTINGS_REL='([^']*)'", sh, re.M); pr = re.search(r"^\$MasterWakeSettingsRel = '([^']*)'", ps, re.M)
same = mj and pj and mj.group(1) == pj.group(1) == '{"remoteControlAtStartup": true}' and mr and pr and mr.group(1).replace("/", "\\") == pr.group(1)
out.append("same=" + ("1" if same else "0"))
print(" ".join(out))
PY
)" || r="python-fail"
case "$r" in *sh-call=1*) true ;; *) false ;; esac; t $? "[ⓓ 맥] step_wake 가 갈래(cys 안 · 창 폴백) 앞에서 write_master_wake_settings 를 한 번 부른다" "$r"
case "$r" in *ps-call=1*) true ;; *) false ;; esac; t $? "[ⓓ 윈] Step-Wake 가 갈래 앞에서 Write-MasterWakeSettings 를 한 번 부른다" "$r"
case "$r" in *ps-fb=1*) true ;; *) false ;; esac; t $? "[ⓓ 윈] 창 폴백 & \$fallbackExe 에 @rcArgs(파일 있을 때만 --settings)" "$r"
case "$r" in *scope=1*) true ;; *) false ;; esac; t $? "[ⓔ 두 OS] 설정 파일을 아는 자리는 wake 함수들뿐(cso·worker·다른 단계 0)" "$r"
case "$r" in *same=1*) true ;; *) false ;; esac; t $? "[ⓔ 두 OS] 파일 이름·내용 글자 같음({\"remoteControlAtStartup\": true})" "$r"

# ── 윈(pwsh 7) ──
PW="$(command -v pwsh 2>/dev/null)"
if [ -z "$PW" ]; then
  t 1 "[윈] pwsh 가 있어야 윈 쪽을 실제로 돌려 잰다" "pwsh 없음 — 설치(brew install powershell) 뒤 다시"
else
  WU="$BASE/it's win user"; mkdir -p "$WU"
  pw_write() { # pw_write <USERPROFILE> → 함수가 돌려준 값(True/False)
    env JARVIS_LIB_ONLY=1 JARVIS_HOME="$BASE/jh" USERPROFILE="$1" PS_SRC="$PS" perl -e 'alarm 90; exec @ARGV or exit 126' "$PW" -NoProfile -Command '. $env:PS_SRC *> $null
$env:JARVIS_LIB_ONLY = ""
Write-Output (Write-MasterWakeSettings)' 2>/dev/null | tail -1 | tr -d '\r'
  }
  WREL='.cys\seat-settings\master-wake.json'
  # 맥 pwsh 에서 Join-Path 는 \ 를 글자로 남긴다 — 그래서 파일은 이름이 「.cys\seat-settings\master-wake.json」 하나이거나 폴더 셋이다(둘 다 받는다)
  wfile() { if [ -f "$1/.cys/seat-settings/master-wake.json" ]; then printf '%s' "$1/.cys/seat-settings/master-wake.json"; else printf '%s' "$1/$WREL"; fi; }
  v="$(pw_write "$WU")"
  [ "$v" = True ] && json_ok "$(wfile "$WU")"; t $? "[ⓐ 윈] Write-MasterWakeSettings 가 파일을 쓴다 · 내용 정확히 · BOM 없음" "ret=$v $(od -c "$(wfile "$WU")" 2>/dev/null | head -2 | tr '\n' ' ')"
  n="$(find "$WU" -name '*master-wake.*.tmp' 2>/dev/null | wc -l | tr -d ' ')"; [ "$n" = 0 ]; t $? "[ⓐ 윈] 임시 파일 잔재 0" "남은 임시 파일 $n"
  printf '{"x": 1}\n' > "$(wfile "$WU")"
  v="$(pw_write "$WU")"
  [ "$v" = True ] && json_ok "$(wfile "$WU")"; t $? "[ⓐ 윈] 재설치 — 다른 내용이 있으면 같은 내용으로 덮는다" "ret=$v $(cat "$(wfile "$WU")" 2>&1)"
  # ⓑ 윈 wake.ps1 — 설정 파일 유무 두 갈래
  WH="$BASE/it's win"; mkdir -p "$WH/bin"; fake_claude "$WH/bin/claude"
  WP="$WH/wake.ps1"
  env JARVIS_LIB_ONLY=1 JARVIS_HOME="$WH/jh" PS_SRC="$PS" WP="$WP" \
    perl -e 'alarm 90; exec @ARGV or exit 126' "$PW" -NoProfile -Command '. $env:PS_SRC *> $null
$q = $env:PROMPT -replace "'"'"'", "'"''"'"
[System.IO.File]::WriteAllText($env:WP, (Get-WakeBody $q), (New-Object System.Text.UTF8Encoding($true)))' >/dev/null 2>&1
  win_run() { # win_run <이름> <USERPROFILE>
    rm -f "$BASE/$1.args"
    env PATH="$WH/bin:$PATH" USERPROFILE="$2" WE_OUT="$BASE/$1" perl -e 'alarm 60; exec @ARGV or exit 126' "$PW" -NoProfile -File "$WP" </dev/null >/dev/null 2>&1
  }
  WN="$BASE/win none"; mkdir -p "$WN"
  win_run w-none "$WN"
  args_is "$BASE/w-none" --dangerously-skip-permissions "$PROMPT"; t $? "[ⓑ 윈] 설정 파일이 없으면 종전 인자 그대로" "$(show "$BASE/w-none")"
  KD="$BASE/win dir"; mkdir -p "$KD/.cys/seat-settings/master-wake.json"
  v="$(pw_write "$KD")"
  n="$(find "$KD" -name '*master-wake.*.tmp' 2>/dev/null | wc -l | tr -d ' ')"
  [ "$v" = False ] && [ "$n" = 0 ]; t $? "[ⓐ 윈] 그 자리가 폴더면 False · 임시 파일 0" "ret=$v 남은 임시 파일 $n"
  WB="$BASE/win bad"; mkdir -p "$WB/.cys/seat-settings"; printf '{"remoteControlAtStartup": tr' > "$WB/.cys/seat-settings/master-wake.json"
  win_run w-bad "$WB"
  args_is "$BASE/w-bad" --dangerously-skip-permissions "$PROMPT"; t $? "[ⓑ 윈] 내용이 우리 글자가 아니면(깨진 옛 파일) --settings 를 넘기지 않는다" "$(show "$BASE/w-bad")"
  WZ="$BASE/win nul"; mkdir -p "$WZ/.cys/seat-settings"; printf '{"remoteControlAtStartup": true}\0\n' > "$WZ/.cys/seat-settings/master-wake.json"
  win_run w-nul "$WZ"
  args_is "$BASE/w-nul" --dangerously-skip-permissions "$PROMPT"; t $? "[ⓑ 윈] NUL 이 섞인 파일이면 --settings 를 넘기지 않는다(바이트 대조)" "$(show "$BASE/w-nul")"
  WC="$BASE/win crlf"; mkdir -p "$WC/.cys/seat-settings"; printf '{"remoteControlAtStartup": true}\r\n' > "$WC/.cys/seat-settings/master-wake.json"
  win_run w-crlf "$WC"
  args_is "$BASE/w-crlf" --dangerously-skip-permissions "$PROMPT"; t $? "[ⓑ 윈] 바이트가 우리 것과 다르면(CRLF) --settings 를 넘기지 않는다 — 다음 설치가 같은 바이트로 덮는다" "$(show "$BASE/w-crlf")"
  win_run w-rc "$WU"
  args_is "$BASE/w-rc" --dangerously-skip-permissions --settings "$(wfile "$WU")" "$PROMPT"; t $? "[ⓑ 윈] 설정 파일이 있으면 --settings <그 파일>(공백·작은따옴표 경로도 인자 하나) · 첫 프롬프트 글자 그대로" "$(show "$BASE/w-rc")"
fi

echo "== 합계: ok $pass · FAIL $fail =="
[ "$fail" -eq 0 ]
