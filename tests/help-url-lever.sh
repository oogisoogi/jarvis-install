#!/bin/bash
# 0.3.36 — 도움 보고 주소 손잡이(JARVIS_HELP_API_URL)와 CI 라이브 차단(master#bdb927f2 A안 · 조건 ①②).
#
# 까닭: .github/workflows/reinstall-matrix.yml 이 두 OS 실제 부분 설치를 full 모드로 돌린다(스냅샷 저장소 jarvis-install 에서는
#   push 마다 실제로 돈다 · master 실측 09-24 08:52). 진행 전송은 JARVIS_PROGRESS_URL 로 돌릴 수 있었지만 도움 보고(/api/help ·
#   러너 기록 200줄)는 고정 주소라 CI 가 막히면 라이브 도움 채널로 갔다 → 손잡이를 JARVIS_PROGRESS_URL 과 같은 모양으로 둔다.
# 재는 것
#   ① 손잡이가 없으면(사람이 쓰는 설치) 도움·진행 주소가 **종전과 같다**(회귀 방지 · 두 OS) — 정의 줄만 떼어 내 평가한다
#      (파일을 통째로 읽으면 LIB_ONLY 차단이 끼어 기본값을 못 잰다 · 통째로 돌리면 설치가 시작된다).
#   ② 손잡이를 주면 도움 주소 = 그 값 · 진행 주소 = <그 값>/api/progress(JARVIS_PROGRESS_URL 이 없을 때 · 종전 파생 그대로)
#   ③ LIB_ONLY 로 읽은 셸에서도 손잡이를 주면 그 값(JARVIS_PROGRESS_URL 과 같은 순서) · 안 주면 로컬(lib-only-no-live 가 따로 잰다)
#   ④ 워크플로 job env 에 JARVIS_PROGRESS_URL · JARVIS_HELP_API_URL 둘 다 로컬 주소로 있다(조건 ②)
# 쓰는 법: bash tests/help-url-lever.sh [--dir <install-master 자리>]   · rc 0 = 통과 · 1 = 실패 · 2 = 잴 수 없음
# ⛔바깥에 닿지 않는다 — 주소 글자만 평가한다(전송 0).
set -u
HERE="$(cd "$(dirname "$0")" && pwd)"
DIR="$HERE/../install-master"
[ "${1:-}" = "--dir" ] && DIR="$2"
DIR="$(cd "$DIR" && pwd)"
SH="$DIR/bootstrap.sh"; PS="$DIR/bootstrap.ps1"; WF="$DIR/../.github/workflows/reinstall-matrix.yml"
LIVE="https://jarvis-install.godmeyou.kr"
pass=0; fail=0
t() { if [ "$1" -eq 0 ]; then pass=$((pass+1)); printf '  ok   %s\n' "$2"; else fail=$((fail+1)); printf '  FAIL %s  ← %s\n' "$2" "$3"; fi; }

# 맥: 정의 줄(HELP_API_URL=·LIB_ONLY 덮기·AT_LOAD 고정)과 progress_url 함수만 떼어 낸다
lib="$(mktemp -t helplever)" || exit 2
trap 'rm -f "$lib"' EXIT
{ grep -E '^JARVIS_LIB_ONLY_AT_LOAD=' "$SH"; grep -E '^HELP_API_URL=|^\[ -z "\$\{JARVIS_HELP_API_URL:-\}" \]' "$SH"
  awk '/^progress_url\(\) \{/{f=1} f{print} f&&/^}$/{f=0}' "$SH"; } > "$lib"
[ "$(grep -c . "$lib")" -ge 4 ] && grep -q '^progress_url()' "$lib" || { echo "잴 수 없음: 맥 정의 줄을 못 떼어 냈다" >&2; cat "$lib" >&2; exit 2; }
mac() { # mac <LIB_ONLY 값> [손잡이 값] → 「help|progress」
  env -i PATH=/usr/bin:/bin ${1:+JARVIS_LIB_ONLY="$1"} ${2:+JARVIS_HELP_API_URL="$2"} L="$lib" bash -c 'set -u; . "$L"; printf "%s|%s" "$HELP_API_URL" "$(progress_url)"'
}
r="$(mac "")";    [ "$r" = "$LIVE|$LIVE/api/progress" ]; t $? "[맥 ①] 손잡이 없음 → 도움·진행 주소 종전과 같다" "$r"
r="$(mac "" http://127.0.0.1:9/ci)"; [ "$r" = "http://127.0.0.1:9/ci|http://127.0.0.1:9/ci/api/progress" ]; t $? "[맥 ②] 손잡이 → 도움 = 그 값 · 진행 = 그 값/api/progress" "$r"
r="$(mac 1 http://127.0.0.1:9/ci)"; case "$r" in http://127.0.0.1:9/ci\|http://127.0.0.1:9/lib-only-no-live) true ;; *) false ;; esac
t $? "[맥 ③] LIB_ONLY + 손잡이 → 도움 = 손잡이 · 진행 = 로컬(JARVIS_PROGRESS_URL 없음)" "$r"
r="$(mac 1)"; case "$r" in http://127.0.0.1*\|http://127.0.0.1*) true ;; *) false ;; esac; t $? "[맥 ③ 대조군] LIB_ONLY · 손잡이 없음 → 둘 다 로컬" "$r"

PW="$(command -v pwsh 2>/dev/null)"
if [ -z "$PW" ]; then
  echo "  skip [윈] pwsh 가 없다(통과로 세지 않는다)"
else
  # 윈: 구문 트리에서 $script:JarvisLibOnly·$HelpApiUrl·LIB_ONLY 덮기·$ProgressUrl 대입과 Get-ProgressUrl 만 골라 평가한다
  win() { # win <LIB_ONLY 값> [손잡이 값] → 「help|progress」
    env -u JARVIS_PROGRESS_URL -u JARVIS_HELP_API_URL -u JARVIS_LIB_ONLY ${1:+JARVIS_LIB_ONLY="$1"} ${2:+JARVIS_HELP_API_URL="$2"} \
      perl -e 'alarm 60; exec @ARGV or exit 126' "$PW" -NoProfile -Command "
\$ast = [System.Management.Automation.Language.Parser]::ParseFile('$PS', [ref]\$null, [ref]\$null)
\$top = \$ast.EndBlock.Statements
\$pick = @(\$top | Where-Object { \$x = \$_.Extent.Text; \$x -match '^\\\$script:JarvisLibOnly = ' -or \$x -match '^\\\$HelpApiUrl +=' -or \$x -match '^if \\(\\\$script:JarvisLibOnly -and' -or \$x -match '^\\\$ProgressUrl +=' })
\$fn = @(\$ast.FindAll({ param(\$n) \$n -is [System.Management.Automation.Language.FunctionDefinitionAst] -and \$n.Name -eq 'Get-ProgressUrl' }, \$true))
if (\$pick.Count -ne 4 -or \$fn.Count -ne 1) { 'PICK=' + \$pick.Count + '/' + \$fn.Count; exit 2 }
foreach (\$s in \$pick) { . ([scriptblock]::Create(\$s.Extent.Text)) }
. ([scriptblock]::Create(\$fn[0].Extent.Text))
\$HelpApiUrl + '|' + (Get-ProgressUrl)" 2>&1 | tail -1
  }
  r="$(win "")"; [ "$r" = "$LIVE|$LIVE/api/progress" ]; t $? "[윈 ①] 손잡이 없음 → 도움·진행 주소 종전과 같다" "$r"
  r="$(win "" http://127.0.0.1:9/ci)"; [ "$r" = "http://127.0.0.1:9/ci|http://127.0.0.1:9/ci/api/progress" ]; t $? "[윈 ②] 손잡이 → 도움 = 그 값 · 진행 = 그 값/api/progress" "$r"
  r="$(win 1 http://127.0.0.1:9/ci)"; [ "$r" = "http://127.0.0.1:9/ci|http://127.0.0.1:9/lib-only-no-live" ]
  t $? "[윈 ③] LIB_ONLY + 손잡이 → 도움 = 손잡이 · 진행 = 로컬(맥과 같은 뜻)" "$r"
  r="$(win 1)"; case "$r" in http://127.0.0.1*\|http://127.0.0.1*) true ;; *) false ;; esac; t $? "[윈 ③ 대조군] LIB_ONLY · 손잡이 없음 → 둘 다 로컬" "$r"
fi

# ④ 워크플로 job env(cycle 작업 머리) — 두 값이 로컬 주소로 있다
if [ -f "$WF" ]; then
  envblk="$(awk '/^  cycle:$/{c=1} c&&/^    env:$/{e=1; next} e&&/^      [A-Z_]+:/{print; next} e{exit}' "$WF")"
  printf '%s\n' "$envblk" | grep -qE '^      JARVIS_PROGRESS_URL: *http://127\.0\.0\.1[:/]' \
    && printf '%s\n' "$envblk" | grep -qE '^      JARVIS_HELP_API_URL: *http://127\.0\.0\.1[:/]'
  t $? "[워크플로 ④] reinstall-matrix.yml cycle job env 에 JARVIS_PROGRESS_URL·JARVIS_HELP_API_URL 둘 다 로컬 주소" "$(printf '%s' "$envblk" | tr '\n' ' ')"
else
  echo "  skip [워크플로] $WF 가 없다(스냅샷 사본 등 · 통과로 세지 않는다)"
fi

echo "== 합계: ok $pass · FAIL $fail =="
[ "$fail" -eq 0 ]
