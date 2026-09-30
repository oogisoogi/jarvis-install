#!/bin/bash
# 0.3.37(TICKET=installer-0337-delete-path) — [7/10] 화면 문구 「프로그램이 준비되었습니다 (버전 X)」 두 OS.
#   재는 것: ⓐ 숫자 뽑기(맥 version_number · 윈 Get-VersionNumber)가 옛 판 「cys 1.1.6」·새 판 「cysr 1.1.7」·
#     원작자 판 「cys 0.14.33」·파일 판본 「1.1.7」 을 같은 숫자로 · 숫자 없으면 빈 값 ⓑ 화면 줄(정적) — 새 문장 있음 · 옛 「답합니다」 0
#   (설치기는 돌리지 않는다 — 함수만 떼어 부른다)
# 쓰는 법: bash tests/version-line-run.sh [--dir <install-master 자리>] · rc 0 = 통과
set -u
HERE="$(cd "$(dirname "$0")" && pwd)"
DIR="$HERE/../install-master"
[ "${1:-}" = "--dir" ] && DIR="$2"
BS="$DIR/bootstrap.sh"; BP="$DIR/bootstrap.ps1"
pass=0; fail=0
t() { if [ "$1" -eq 0 ]; then pass=$((pass+1)); printf '  ok   %s\n' "$2"; else fail=$((fail+1)); printf '  FAIL %s  ← %s\n' "$2" "$3"; fi; }
LIB="$(awk '/^version_number\(\) \{/{print}' "$BS")"
[ -n "$LIB" ]; t $? "[맥] version_number 가 설치기에 있다" "없음"
eval "$LIB" 2>/dev/null
for pair in 'cys 1.1.6|1.1.6' 'cysr 1.1.7|1.1.7' 'cys 0.14.33|0.14.33' '1.1.7|1.1.7' 'cysr 1.1.7 (abc 2.3.4)|1.1.7' 'cys|' '|'; do
  in="${pair%%|*}"; want="${pair#*|}"
  got="$(version_number "$in" 2>/dev/null)"
  [ "$got" = "$want" ]; t $? "[맥] 숫자 뽑기 「${in}」 → 「${want}」" "받음 「${got}」"
done
if command -v pwsh >/dev/null 2>&1; then
  got="$(VL_SRC="$BP" pwsh -NoProfile -Command '
    $src = $env:VL_SRC
    $ast = [System.Management.Automation.Language.Parser]::ParseFile($src, [ref]$null, [ref]$null)
    $f = $ast.FindAll({ $args[0] -is [System.Management.Automation.Language.FunctionDefinitionAst] -and $args[0].Name -eq "Get-VersionNumber" }, $true) | Select-Object -First 1
    if (-not $f) { "NOFUNC"; exit }
    Invoke-Expression $f.Extent.Text
    foreach ($v in @("cys 1.1.6","cysr 1.1.7","cys 0.14.33","1.1.7","cysr 1.1.7 (abc 2.3.4)","cys","")) { "[" + (Get-VersionNumber $v) + "]" }' 2>&1 | tr -d '\r' | tr '\n' ' ')"
  [ "$got" = "[1.1.6] [1.1.7] [0.14.33] [1.1.7] [1.1.7] [] [] " ]; t $? "[윈] Get-VersionNumber 같은 표" "받음 $got"
else
  printf '  skip [윈] pwsh 없음\n'
fi
grep -vE '^\s*#' "$BS" | grep -qF 'say "[7/10] 프로그램이 준비되었습니다${vn:+ (버전 $vn)}"'; t $? "[맥] 성공 줄 = 새 문장" "없음"
grep -vE '^\s*#' "$BP" | grep -qF 'Say "[7/10] 프로그램이 준비되었습니다 (버전 $vn)"'; t $? "[윈] 성공 줄 = 새 문장" "없음"
n_old=$(( $(grep -vE '^\s*#' "$BS" | grep -c 'cys 가 답합니다') + $(grep -vE '^\s*#' "$BP" | grep -c 'cys 가 답합니다') ))
[ "$n_old" -eq 0 ]; t $? "[두 OS] 옛 「cys 가 답합니다」 줄 0" "남음 $n_old"
! grep -vE '^\s*#' "$BS" | grep -q 'cys 가 답하는데'; t $? "[맥] 어긋남 줄도 이름 없이" "옛 줄 남음"
grep -vE '^\s*#' "$BS" | grep -qF '이번 버전(${CYS_FORK_VERSION})이 아닙니다${vn:+ (지금 버전 $vn)}'; t $? "[맥] 어긋남 줄 = 새 문장" "없음"
printf '== version-line: ok %s · FAIL %s ==\n' "$pass" "$fail"
[ "$fail" -eq 0 ]
