#!/bin/bash
# 윈도우 10 미만 친절 중단 시험 (2026-11-11)
#
# 무엇을 재는가
#   ⓐ Test-WinTooOld(순수 함수 — 레지스트리 실값을 직접 안 묻는다)가 빌드 번호별로 정확히 판정한다
#      (7601·9200·9600 = 참 · 10240·17763·19045·22631 = 거짓 · 0·음수 = 거짓 = 못 읽으면 막지 않는다)
#   ⓑ Get-WinTooOldLines 안내문 — 「윈도우 10 이상」·다음 할 일(다른 컴퓨터)·「오른쪽 단추」·빌드 번호·「아무것도 바꾸지 않았」 ·
#      겁주는 낱말 0(경고·위험·오류·실패·금지·차단)
#   ⓒ [정적] 판 검사 블록이 파일의 다른 실행문(32비트 재실행·$ErrorActionPreference)보다 앞이고, 레지스트리 CurrentBuildNumber 로
#      판정하며(OSVersion.Version 미사용) · 시험용 묶음(JARVIS_LIB_ONLY)에서는 돌지 않고 · 막을 때 exit 1 이다
#   ⓓ [정적] 파일 전체가 pwsh 파서로 오류 0
#
# 쓰는 법: bash tests/winver-gate-run.sh [--dir <install-master 자리>]
#   rc 0 = 전건 통과 · 1 = 실패 있음 · 2 = 잴 수 없음(pwsh 가 없다)
# ⛔바깥에 닿지 않는다 — 레지스트리·[Environment] 실값을 안 묻는다(순수 함수에 값을 주입).
# ⚠여기서 안 재는 것(윈 실기 몫): 진짜 윈도우 8.1(PowerShell 4.0)에서 파일 전체가 해석되어 이 블록까지 오는지 ·
#   그 기계에서 설치 줄의 내려받기(irm · TLS) 자체가 되는지 · 레지스트리 실값 판독.
set -u
HERE="$(cd "$(dirname "$0")" && pwd)"
DIR="$HERE/../install-master"
while [ $# -gt 0 ]; do
  case "$1" in
    --dir) DIR="$2"; shift 2 ;;
    *) echo "모르는 인자: $1" >&2; exit 2 ;;
  esac
done
PW="$(command -v pwsh 2>/dev/null)"
[ -n "$PW" ] || { echo "잴 수 없음: pwsh 가 없다" >&2; exit 2; }
PS="$(cd "$DIR" && pwd)/bootstrap.ps1"
pass=0; fail=0
ok()  { pass=$((pass+1)); printf '  ok   %s\n' "$1"; }
bad() { fail=$((fail+1)); printf '  FAIL %s  ← %s\n' "$1" "$2"; }
t() { if [ "$1" -eq 0 ]; then ok "$2"; else bad "$2" "$3"; fi; }
run_lib() { # run_lib <ps1경로> <pwsh 이어붙일 명령>
  JARVIS_LIB_ONLY=1 perl -e 'alarm shift; exec @ARGV' 30 "$PW" -NoProfile -Command ". '$1' *> \$null; $2" 2>&1
}

echo "== ⓐ Test-WinTooOld 빌드별 판정 =="
out="$(run_lib "$PS" "
foreach (\$b in 7601,9200,9600,10240,17763,19045,22631,0,-1) { Write-Output ('b' + \$b + '=' + (Test-WinTooOld \$b)) }
")"
for b in 7601 9200 9600; do
  printf '%s' "$out" | grep -q "^b$b=True$"; t $? "[ⓐ] 빌드 $b(윈 10 미만) → 멈춘다" "$out"
done
for b in 10240 17763 19045 22631; do
  printf '%s' "$out" | grep -q "^b$b=False$"; t $? "[ⓐ] 빌드 $b(윈 10·11) → 지나간다" "$out"
done
for b in 0 -1; do
  printf '%s' "$out" | grep -q "^b$b=False$"; t $? "[ⓐ] 빌드 $b(못 읽음) → 막지 않는다(fail-open)" "$out"
done

echo "== ⓑ 안내문 =="
msg="$(run_lib "$PS" "(Get-WinTooOldLines 9600) -join [char]10")"
printf '%s' "$msg" | grep -q '윈도우 10 이상'; t $? "[ⓑ] 「윈도우 10 이상」 이 필요하다고 말한다" "$msg"
printf '%s' "$msg" | grep -q '빌드 9600'; t $? "[ⓑ] 이 컴퓨터의 빌드 번호를 보여 준다" "$msg"
printf '%s' "$msg" | grep -q '윈도우 10 또는 11 컴퓨터에서'; t $? "[ⓑ] 다음에 할 일(다른 컴퓨터에서 붙여 넣기)을 말한다" "$msg"
printf '%s' "$msg" | grep -q '오른쪽 단추'; t $? "[ⓑ] 오른쪽 클릭 붙여넣기 1줄" "$msg"
printf '%s' "$msg" | grep -q '설정은 아무것도 바꾸지 않았'; t $? "[ⓑ] 이 컴퓨터의 설정을 바꾸지 않았다고 말한다(받아 둔 파일 1개는 남는다고 밝힘)" "$msg"
printf '%s' "$msg" | grep -qE '경고|위험|오류|실패|금지|차단'; [ $? -ne 0 ]; t $? "[ⓑ] 겁주는 낱말 0" "$msg"

echo "== ⓒ 블록 위치·판정 자료(정적) =="
python3 - "$PS" <<'PYEOF'
import sys
t = open(sys.argv[1], encoding='utf-8-sig').read()
gate = t.find("if ((-not $script:JarvisLibOnly) -and ([Environment]::OSVersion.Platform -eq [PlatformID]::Win32NT)) {")
ps32 = t.find("if (Test-Ps32OnWin64 ([Environment]::Is64BitOperatingSystem)")
eap = t.find("$ErrorActionPreference = 'Continue'")
end = t.find("\n}\n", gate)
blk = t[gate:end] if gate >= 0 and end > gate else ""
checks = [
    ("gate 존재", gate >= 0),
    ("함수 정의 둘이 gate 보다 앞(뒤면 실행 때 명령 없음)", 0 <= t.find("function Test-WinTooOld(") < gate and 0 <= t.find("function Get-WinTooOldLines(") < gate),
    ("gate 가 32비트 재실행보다 앞", 0 <= gate < ps32),
    ("gate 가 $ErrorActionPreference 보다 앞", 0 <= gate < eap),
    ("판정 = 레지스트리 CurrentBuildNumber", "'CurrentBuildNumber'" in blk and "Windows NT\\CurrentVersion" in blk),
    ("판정에 OSVersion.Version 미사용", "OSVersion.Version" not in blk),
    ("막을 때 exit 1", "exit 1" in blk and "Test-WinTooOld $winBuildNo" in blk),
]
bad = [n for n, ok in checks if not ok]
for n, ok in checks:
    print(("ok " if ok else "NG ") + n)
sys.exit(1 if bad else 0)
PYEOF
t $? "[ⓒ] 블록이 맨 앞 · 레지스트리 판정 · lib-only 제외 · exit 1" "위 NG 줄"

echo "== ⓔ 윈 8·8.1 기본 PowerShell(3.0·4.0)이 못 읽는 해석 문법 0 =="
# pwsh 7 파서(ⓓ)는 PS5 전용 문법을 잡지 못한다 — 파일 전체가 해석에 실패하면 판 검사 블록까지 못 온다.
py5=$(python3 - "$PS" <<'PYEOF'
import re, sys
bad = []
for i, line in enumerate(open(sys.argv[1], encoding='utf-8-sig'), 1):
    code = line.split('#', 1)[0]
    if re.match(r'\s*(class|enum)\s+\w+\s*(\{|:|$)', code) or re.match(r'\s*using\s+(namespace|module|assembly)\b', code):
        bad.append(i)
print(bad)
sys.exit(1 if bad else 0)
PYEOF
); t $? "[ⓔ] class·enum·using 0건" "$py5"

echo "== ⓓ 파서 오류 0 =="
perr="$("$PW" -NoProfile -Command "\$e=\$null; [void][System.Management.Automation.Language.Parser]::ParseFile('$PS',[ref]\$null,[ref]\$e); \$e.Count" 2>&1)"
[ "$perr" = "0" ]; t $? "[ⓓ] bootstrap.ps1 파서 오류 0" "$perr"

printf '\n통과 %s · 실패 %s\n' "$pass" "$fail"
[ "$fail" -eq 0 ]
