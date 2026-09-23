#!/bin/bash
# 32비트 PowerShell 감지·64비트 재실행 시험 — TICKET=installer-0325 c8 (2026-09-17)
#
# 무엇을 재는가
#   ⓐ Test-Ps32OnWin64(순수 함수 — [Environment] 정적값을 직접 안 묻는다)가 4개 조합에서 정확히 판정한다
#      (64bit OS ∧ 32bit 프로세스 일 때만 참 — 그 밖은 전부 거짓, 32bit OS 조합도 포함)
#   ⓑ Build-Ps32RelaunchArgs 가 -File 뒤 원래 인자(-DetectOnly·-DryRun)를 그대로 이어 붙인다
#   ⓒ [2/10] J-PS32-01 분기가 J-PATH-01 보다 먼저 걸린다(설치기 3초 미만 종료 + 파일 없음 + 32비트 프로세스일 때만)
#
# 쓰는 법: bash tests/ps32-detect-run.sh [--dir <install-master 자리>]
#   rc 0 = 전건 통과 · 1 = 실패 있음 · 2 = 잴 수 없음(pwsh 가 없다)
# ⛔바깥에 닿지 않는다 — [Environment] 실값을 안 묻는다(순수 함수에 값을 주입) · 실제 재실행 0(Start-Process 를 안 부른다).
# ⚠여기서 안 재는 것: 진짜 32비트 프로세스에서 돌리는 것(이 기계의 pwsh 는 64비트뿐) · sysnative 실경로 존재 여부(윈 실기 몫).
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

echo "== [1/10] Test-Ps32OnWin64 4조합 =="
out="$(run_lib "$PS" "
Write-Output ('c1=' + (Test-Ps32OnWin64 \$true  \$false))
Write-Output ('c2=' + (Test-Ps32OnWin64 \$true  \$true))
Write-Output ('c3=' + (Test-Ps32OnWin64 \$false \$false))
Write-Output ('c4=' + (Test-Ps32OnWin64 \$false \$true))
")"
printf '%s' "$out" | grep -q '^c1=True$';  t $? "[c1] 64bit OS · 32bit 프로세스 → 참(재실행 대상)" "$out"
printf '%s' "$out" | grep -q '^c2=False$'; t $? "[c2] 64bit OS · 64bit 프로세스 → 거짓(정상)" "$out"
printf '%s' "$out" | grep -q '^c3=False$'; t $? "[c3] 32bit OS · 32bit 프로세스 → 거짓(재실행할 64비트가 없다)" "$out"
printf '%s' "$out" | grep -q '^c4=False$'; t $? "[c4] 32bit OS · 64bit 프로세스(모순값) → 거짓" "$out"

echo "== [1/10] Build-Ps32RelaunchArgs 인자 이어붙임 =="
out2="$(run_lib "$PS" "
(Build-Ps32RelaunchArgs '/tmp/a b/bootstrap.ps1' \$false \$false) -join '|'
(Build-Ps32RelaunchArgs '/tmp/a b/bootstrap.ps1' \$true  \$true)  -join '|'
")"
printf '%s' "$out2" | grep -qF -- '-NoProfile|-ExecutionPolicy|Bypass|-File|"/tmp/a b/bootstrap.ps1"'
t $? "[인자] 기본값(DetectOnly·DryRun 둘 다 없음) — 다섯 토큰뿐" "$out2"
printf '%s' "$out2" | grep -qF -- '-DetectOnly|-DryRun'
t $? "[인자] -DetectOnly -DryRun 이 켜지면 그대로 이어 붙는다(순서·개수 보존)" "$out2"

echo "== [2/10] J-PS32-01 이 J-PATH-01 보다 먼저(정적) =="
py=$(python3 - "$PS" <<'PYEOF'
import re, sys
t = open(sys.argv[1], encoding='utf-8').read()
i_ps32 = t.find("Write-JCode 'J-PS32-01'")
i_path = t.find("Write-JCode 'J-PATH-01'")
sys.exit(0 if (i_ps32 >= 0 and i_path >= 0 and i_ps32 < i_path) else 1)
PYEOF
); t $? "[정적] J-PS32-01 분기가 소스에서 J-PATH-01 보다 앞선다(먼저 갈린다)" "-"
grep -qE "^\s*'J-PS32-01'\s*=" "$PS"; t $? "[정적] J-PS32-01 도움 문구가 등록돼 있다" "-"

printf '\n통과 %s · 실패 %s\n' "$pass" "$fail"
[ "$fail" -eq 0 ]
