#!/usr/bin/env bash
# OSS Scanner 이미지 안에서 도는 시험 묶음 — 네트워크 없이(`docker run --network none`) 돈다.
#   쓰는 곳 둘: ① .oss-scanner/Dockerfile 마지막 단계(실패해도 빌드는 계속 · 결과는 로그로 남긴다)
#              ② .github/workflows/oss-scanner-image.yml(실패하면 붉어진다)
#   목록을 한 곳에만 둔다 — 두 사용처가 같은 시험을 잰다.
# 쓰는 법: bash .oss-scanner/run-tests.sh            (전부 · 하나라도 붉으면 rc 1)
#          bash .oss-scanner/run-tests.sh <단계…>     (syntax · ps-parse · ps-balance · checks 중 골라서)
# ⚠이 저장소의 설치기는 맥(bash)·윈도우(PowerShell)용이다. 리눅스 이미지는 「정적 축 + 흉내 시험」만 돈다 —
#   실제 설치(앱 내려받기·로그인)는 하지 않는다. 진행 이벤트·도움 보고는 닿지 않는 로컬 주소로 돌린다.
set -uo pipefail
cd "$(dirname "$0")/.." || exit 2

export JARVIS_NO_PROGRESS=1
export JARVIS_PROGRESS_URL=http://127.0.0.1:9/oss-scanner
export JARVIS_HELP_API_URL=http://127.0.0.1:9/oss-scanner
export PYTHONUTF8=1

STEPS=("$@")
[ "${#STEPS[@]}" -eq 0 ] && STEPS=(syntax ps-parse ps-balance checks)

PS_FILES=(install-master/bootstrap.ps1 install-master/reset-clean.ps1 install-master/reinstall.ps1)
declare -a RESULT=()
fail=0

record() { # record <단계> <rc> <비고>
  local mark=ok
  [ "$2" -ne 0 ] && { mark=FAIL; fail=1; }
  RESULT+=("$(printf '%-10s %-4s rc=%-3s %s' "$1" "$mark" "$2" "$3")")
}

for s in "${STEPS[@]}"; do
  echo "== [oss-scanner] $s =="
  case "$s" in
    syntax)
      n=0; bad=""
      while IFS= read -r f; do
        n=$((n + 1))
        bash -n "$f" || bad="$bad $f"
      done < <(git ls-files '*.sh')
      rc=0; [ -n "$bad" ] && rc=1
      record "$s" "$rc" "bash -n ${n}개${bad:+ · 실패:$bad}" ;;
    ps-parse)
      if ! command -v pwsh >/dev/null 2>&1; then record "$s" 1 "pwsh 없음"; continue; fi
      n=0; bad=""
      while IFS= read -r f; do
        n=$((n + 1))
        PS_FILE="$f" pwsh -NoProfile -NonInteractive -Command '
          $p = $env:PS_FILE; $errs = $null
          [void][System.Management.Automation.Language.Parser]::ParseFile((Resolve-Path $p).Path, [ref]$null, [ref]$errs)
          if ($errs.Count) { foreach ($e in $errs) { Write-Output ("{0}:{1}: {2}" -f $p, $e.Extent.StartLineNumber, $e.Message) }; exit 1 }
        ' || bad="$bad $f"
      done < <(git ls-files '*.ps1')
      rc=0; [ -n "$bad" ] && rc=1
      record "$s" "$rc" "PowerShell 구문 분석 ${n}개${bad:+ · 실패:$bad}" ;;
    ps-balance)
      python3 tests/ps-balance.py "${PS_FILES[@]}"
      record "$s" $? "tests/ps-balance.py (윈 CI 와 같은 3파일)" ;;
    checks)
      # 맥에서는 checks.sh 의 판정을 그대로 쓴다. 맥이 아니면(스캐너 이미지 = 리눅스) 「이 환경에서 잴 수 없는」 검사의 실패만
      #   .oss-scanner/linux-env-skip.tsv 의 사유를 붙여 「건너뜀」으로 옮긴다 — checks.sh 자체는 손대지 않는다(맥 판정 불변).
      #   표에 없는 실패 · checks.sh 가 집계 줄 없이 죽은 경우는 그대로 붉다.
      if [ "$(uname -s 2>/dev/null)" = "Darwin" ] || [ ! -f .oss-scanner/linux-env-skip.tsv ]; then
        bash install-master/checks.sh
        record "$s" $? "install-master/checks.sh (검사 축 전수 · pwsh 있으면 흉내 시험 포함)"
      else
        clog="$(mktemp "${TMPDIR:-/tmp}/oss-checks.XXXXXX")"
        bash install-master/checks.sh > "$clog" 2>&1; crc=$?
        python3 - "$clog" .oss-scanner/linux-env-skip.tsv "$crc" <<'PY'
import re, sys
log, table, crc = sys.argv[1], sys.argv[2], int(sys.argv[3])
rows = []
for line in open(table, encoding="utf-8"):
    line = line.rstrip("\n")
    if line and not line.startswith("#") and "\t" in line:
        rows.append(tuple(line.split("\t", 1)))
moved, left, tally = 0, 0, None
for line in open(log, encoding="utf-8", errors="replace"):
    line = line.rstrip("\n")
    if line.startswith("  FAIL "):
        name = line[7:].split("  ← ")[0]
        why = next((reason for head, reason in rows if name.startswith(head)), None)
        if why is None:
            left += 1
        else:
            moved += 1
            line = "  skip %s  (리눅스 환경 — %s)" % (name, why)
    m = re.match(r"^통과 (\d+) · 실패 (\d+) · 건너뜀 (\d+)$", line)
    if m:
        tally = tuple(int(x) for x in m.groups())
    print(line)
print()
if tally is None:
    print("[oss-scanner] checks.sh 가 집계 줄 없이 끝났다(rc=%d) — 환경 판별을 하지 않고 실패로 둔다" % crc)
    sys.exit(1)
ok, bad, skipped = tally
if bad != moved + left:
    print("[oss-scanner] 집계(실패 %d)와 실패 줄 수(%d)가 다르다 — 실패로 둔다" % (bad, moved + left))
    sys.exit(1)
print("[oss-scanner] 리눅스 환경 판별: 실패 %d 중 %d = 이 환경에서 잴 수 없는 검사(건너뜀으로 옮김) → 통과 %d · 실패 %d · 건너뜀 %d"
      % (bad, moved, ok, left, skipped + moved))
sys.exit(0 if left == 0 and crc in (0, 1) else 1)
PY
        record "$s" $? "install-master/checks.sh + 리눅스 환경 판별(.oss-scanner/linux-env-skip.tsv · 표에 없는 실패는 그대로 붉다)"
        rm -f "$clog"
      fi ;;
    *)
      echo "모르는 단계: $s (syntax · ps-parse · ps-balance · checks)" >&2
      record "$s" 2 "모르는 단계" ;;
  esac
done

echo
echo "== [oss-scanner] 요약 =="
printf '  %s\n' "${RESULT[@]}"
exit "$fail"
