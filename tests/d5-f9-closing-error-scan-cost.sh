#!/bin/bash
# D5-F9 검출 시험 — 윈 「예상 못 한 끝」의 끝맺음이 오류 기록 1건마다 구문 트리 전체를 다시 훑어(FindAll) 분 단위로 멈춘 것처럼 보이면 적색.
#   끝맺음은 $Error 전체를 조용/시끄러움으로 **두 번** 가른다(Write-ClosingNote) — 기록 250건 × 2 × FindAll(이 맥 약 0.28초) ≈ 2분.
#   이 맥의 pwsh 로 실물 bootstrap.ps1 을 **실물 크기 그대로** 사본에 두고, 그 사본 안의 한 자리에서 오류 250건을 만든 뒤
#   끝맺음과 같은 두 번 가르기를 돌려 걸린 시간을 잰다(상한 20초 · 넘으면 적색). 판정 값도 함께 본다(빨라졌는데 틀리면 안 된다).
#   ⚠절대 시간 문턱은 기계에 따라 흔들린다 — 원본은 이 맥에서 상한(60초 알람)을 넘기고, 수리본은 1초대다(두 자릿수 배 차이 · 문턱은 그 사이).
# 쓰는 법: bash tests/d5-f9-closing-error-scan-cost.sh [bootstrap.ps1]   · rc 0 = 통과 · 1 = 결함 · 2 = 측정 무효
set -u
SRC="${1:-$(cd "$(dirname "$0")/.." && pwd)/install-master/bootstrap.ps1}"
PW="$(command -v pwsh 2>/dev/null)"; [ -n "$PW" ] || { echo "FAIL 측정 무효: pwsh 가 없다"; exit 2; }
T="$(mktemp -d "${TMPDIR:-/tmp}/d5f9.XXXXXX")" || exit 2
trap 'rm -rf "$T"' EXIT
CP="$T/bootstrap-copy.ps1"
cp "$SRC" "$CP"
# 사본의 끝맺음 함수 바로 앞에 오류를 내는 함수 둘을 끼운다(파일 끝에 붙이면 JARVIS_LIB_ONLY 가 그 앞에서 돌아와 정의되지 않는다) —
#   하나는 조용히 넘기는 확인(-ErrorAction SilentlyContinue), 하나는 그냥 난 오류. 파일 크기(구문 트리)는 실물과 사실상 같다.
python3 - "$CP" <<'PYEOF' || { echo "FAIL 측정 무효: 끝맺음 함수 자리를 1곳으로 못 찾았다"; exit 2; }
import sys
p = sys.argv[1]; b = open(p, 'rb').read().decode('utf-8')
o = "function Write-ClosingNote {\n"
if b.count(o) != 1: sys.exit(1)
ins = ('function Emu-QuietErr { [void](Get-Item -LiteralPath "/no/such/d5f9-quiet" -ErrorAction SilentlyContinue) }\n'
       'function Emu-LoudErr { Get-Item -LiteralPath "/no/such/d5f9-loud" }\n')
open(p, 'wb').write(b.replace(o, ins + o).encode('utf-8'))
PYEOF
out="$(JARVIS_LIB_ONLY=1 perl -e 'alarm 60; exec @ARGV or exit 126' "$PW" -NoProfile -Command "
. '$CP' *> \$null
\$Error.Clear()
for (\$i = 0; \$i -lt 200; \$i++) { Emu-QuietErr }
for (\$i = 0; \$i -lt 50; \$i++) { Emu-LoudErr 2>\$null }
\$n = \$Error.Count
\$sw = [System.Diagnostics.Stopwatch]::StartNew()
\$quietErr = @(\$Error | Where-Object { Test-QuietErrorRecord \$_ })
\$loudErr  = @(\$Error | Where-Object { -not (Test-QuietErrorRecord \$_) })
Write-Output ('n=' + \$n + ' quiet=' + \$quietErr.Count + ' loud=' + \$loudErr.Count + ' ms=' + [int]\$sw.ElapsedMilliseconds)
" 2>&1)"; rc=$?
line="$(printf '%s\n' "$out" | grep '^n=' | tail -1)"
if [ -z "$line" ]; then
  if [ "$rc" -eq 142 ] || [ "$rc" -ge 128 ]; then echo "FAIL 끝맺음 두 번 가르기가 60초 안에 안 끝났다(rc=$rc · 오류 250건)"; exit 1; fi
  echo "FAIL 측정 무효: 결과 줄이 없다(rc=$rc)"; printf '%s\n' "$out" | tail -3 | sed 's/^/  /'; exit 2
fi
n="$(printf '%s' "$line" | sed -n 's/^n=\([0-9]*\) .*/\1/p')"; q="$(printf '%s' "$line" | sed -n 's/.* quiet=\([0-9]*\) .*/\1/p')"
l="$(printf '%s' "$line" | sed -n 's/.* loud=\([0-9]*\) .*/\1/p')"; ms="$(printf '%s' "$line" | sed -n 's/.* ms=\([0-9]*\)$/\1/p')"
[ "${n:-0}" -ge 200 ] || { echo "FAIL 측정 무효: 오류가 충분히 쌓이지 않았다($line)"; exit 2; }
fail=0
[ "$q" = 200 ] && [ "$l" = 50 ] || { echo "FAIL 판정이 틀렸다(조용 200 · 그냥 50 이어야): $line"; fail=1; }
[ "${ms:-999999}" -lt 20000 ] || { echo "FAIL 끝맺음 가르기가 느리다: ${ms}ms(상한 20000ms · $line)"; fail=1; }
[ "$fail" -eq 0 ] && echo "PASS 오류 ${n}건 두 번 가르기 ${ms}ms · 조용 ${q} · 그냥 ${l}"
exit "$fail"
