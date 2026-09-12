#!/bin/bash
# 단계 1 산출물 검사 축 — 수정이 실제로 서 있는지 재는 것만 담는다.
# ⛔이 파일은 「좋은 코드인가」를 재지 않는다. **되돌리면 적색이 되는 성질**만 재라.
#   (각 축은 뮤테이션 시험으로 적색을 확인했다 — 수정표 참조)
# 쓰는 법: bash install-master/checks.sh [대상디렉터리]   · rc 0 = 전건 통과
set -u
DIR="${1:-$(cd "$(dirname "$0")" && pwd)}"
SH="$DIR/bootstrap.sh"
PS="$DIR/bootstrap.ps1"
RESET="$DIR/reset-clean.ps1"
RESET_SH="$DIR/reset-clean.sh"
REIN_SH="$DIR/reinstall.sh"
REIN_PS="$DIR/reinstall.ps1"
FOOTPRINT="$DIR/footprint.md"
# ★사람이 사이트에서 받아 **직접 실행**하는 것 넷. 「설치 스크립트 전체」를 재는 축은 이 목록을 쓴다.
#   ⛔축마다 파일 이름을 손으로 다시 적지 마라 — 목록이 둘이 되면 한쪽이 반드시 뒤처진다
#   (교차 검토 1차 [5] 가 잡은 것이 정확히 그 형태다: 역방향 축이 bootstrap 둘만 보고 있었다).
# ⚠**배열이다.** 공백으로 이은 문자열로 두면 경로에 공백이 있을 때 조각나고, 조각은 `-f` 가
#   거짓이라 **조용히 건너뛴다** — 축이 죽은 줄도 모른 채 초록이 된다(교차 검토 4차 지적 채택).
INSTALL_SCRIPTS=("$SH" "$PS" "$REIN_SH" "$REIN_PS")
# grep 의 종료값은 셋이다: 0=찾음 · 1=못 찾음 · **2 이상=읽기 오류**. 오류를 「0건」으로 세면
#   파일을 못 읽은 날이 통과가 된다. ⇒ 이 도우미로 셋을 갈라 받는다.
#   rc 0 = 「없다(통과)」 · rc 1 = 「있다 또는 못 읽었다(실패)」 · 사유는 GREP_WHY 에 담는다.
GREP_WHY=""
absent_or_fail() { # absent_or_fail <파일> <정규식>
  local f="$1" re="$2" out grc
  GREP_WHY=""
  out="$(grep -cE "$re" "$f" 2>/dev/null)"; grc=$?
  if [ "$grc" -ge 2 ]; then GREP_WHY="읽기 오류(grep rc=$grc)"; return 1; fi
  if [ "${out:-0}" -ne 0 ]; then GREP_WHY="${out}건"; return 1; fi
  return 0
}
absent_or_fail_i() { # 같은 것 · 대소문자 무시
  local f="$1" re="$2" out grc
  GREP_WHY=""
  out="$(grep -ciE "$re" "$f" 2>/dev/null)"; grc=$?
  if [ "$grc" -ge 2 ]; then GREP_WHY="읽기 오류(grep rc=$grc)"; return 1; fi
  if [ "${out:-0}" -ne 0 ]; then GREP_WHY="${out}건"; return 1; fi
  return 0
}
pass=0; fail=0; skip=0
# 🔴외부 검토 1차 [4](BLOCK) 수정 — **사람이 실제로 복사하는 것은 문서지 스크립트 주석이 아니다.**
#   앞 판은 배포 한 줄을 `bootstrap.ps1` 의 주석에서만 쟀다 ⇒ 주석만 고치고 문서를 안 고쳐도 통과한다.
#   그러면 **검사는 녹색인데 사용자는 옛 명령을 복사해 실행 정책에 막힌다.** 문서를 검사 축에 넣는다.
DOC=""
for c in "$DIR/../docs/install-master/TEST-s1-windows-2026-09-04.md" "$DIR/TEST-s1-windows-2026-09-04.md"; do
  [ -f "$c" ] && { DOC="$c"; break; }
done
# 깨끗한 기계 재설치 채점표 — 「스크립트가 말할 수 없는 것」이 여기에 적혀 있어야 한다
SCORE=""
for c in "$DIR/../docs/install-master/CLEAN-RETEST-2026-09-05.md" "$DIR/CLEAN-RETEST-2026-09-05.md"; do
  [ -f "$c" ] && { SCORE="$c"; break; }
done
# 아침에 사람 손으로 전달되는 1쪽 — 전달 중 변조를 사람이 눈으로 잡을 수 있어야 한다
SHEET=""
for c in "$DIR/../docs/install-master/MORNING-1page-2026-09-05.md" "$DIR/MORNING-1page-2026-09-05.md"; do
  [ -f "$c" ] && { SHEET="$c"; break; }
done

# 🔴어휘를 세는 축은 **주석·설명문을 함께 센다** — 이 파일에서 세 번 재발했다(자기신고).
#   부정형 축(「~가 남아 있으면 안 된다」)은 반드시 이 헬퍼로 **코드 줄만** 봐야 한다.
codegrep() { # codegrep <파일> <패턴>  — 주석(#)을 뺀 줄에서만 찾는다
  grep -vE '^[[:space:]]*#' "$1" 2>/dev/null | grep -qE "$2"
}
# 🔴🔴**「없다」를 재는 자리는 `! codegrep` 을 쓰지 마라**(2차 검토 지적 채택 2026-09-09).
#   파이프 앞의 `grep` 이 **파일을 못 읽어 rc=2** 로 죽어도 뒤의 `grep -q` 는 no-match(rc 1)를 내고,
#   `!` 가 그것을 **성공으로 뒤집는다** ⇒ 못 읽은 날이 「그 형태가 없다」로 통과한다.
#   ⇒ 앞단을 따로 받아 읽기 오류를 **실패**로 돌린다.
no_code() { # no_code <파일> <정규식> — 「주석 밖에 그 형태가 없다」가 참일 때만 rc 0
  local body rc
  GREP_WHY=""
  body="$(grep -vE '^[[:space:]]*#' "$1" 2>/dev/null)"; rc=$?
  if [ "$rc" -ge 2 ]; then GREP_WHY="읽기 오류(grep rc=$rc)"; return 1; fi
  if printf '%s\n' "$body" | grep -qE "$2"; then GREP_WHY="그 형태가 있다"; return 1; fi
  return 0
}
# 「센다」를 **파이프로** 하는 자리 — 앞단(내용을 뽑는 명령)의 실패도 실패로 받는다.
#   🔴`grep -c` 는 0건에도 rc 1 을 내서 그동안 `|| true` 로 받아 왔는데, 그러면 **rc 2(읽기 오류)까지**
#   함께 삼켜 **못 읽은 날이 「0건」이 된다**(4차 검토 지적 채택 2026-09-09).
#   ⚠내가 r4 보고에서 이 형태를 「전건 교체했다」고 적었는데 **거짓이었다** — 다섯 자리가 남아 있었다.
#     ★고쳤다고 말하기 전에 세어라. 이 파일에서 세 번째 재발이다.
#   ⇒ 건수는 COUNT_N 에 담고, **읽기 오류는 rc 1** 로 가른다.
#   · 정규식은 부르는 자리와 같은 **기본 정규식(BRE)** 으로 센다 — 넘겨받은 패턴을 손대지 않는다
#     (`-E` 로 바꾸면 `|`·`+` 의 뜻이 달라져 멀쩡한 축이 다른 것을 세게 된다).
#   · 앞단 rc 1 = 「고른 줄이 없다」(빈 본문 = 0건)로 받는다. **rc 2 이상만** 오류다 — grep 의 셈과 같다.
count_from_or_fail() { # count_from_or_fail <정규식> -- <내용을 뽑는 명령…> → COUNT_N 에 건수 · rc 1 = 읽기 오류
  local re="$1"; shift
  [ "${1:-}" = "--" ] && shift
  local body prc out grc
  GREP_WHY=""; COUNT_N=0
  body="$( "$@" 2>/dev/null )"; prc=$?
  if [ "$prc" -ge 2 ]; then GREP_WHY="본문을 못 뽑았다(rc=$prc)"; return 1; fi
  out="$(printf '%s\n' "$body" | grep -c "$re")"; grc=$?
  if [ "$grc" -ge 2 ]; then GREP_WHY="읽기 오류(grep rc=$grc)"; return 1; fi
  COUNT_N="${out:-0}"
  return 0
}
# 근거 한 칸에 「못 읽었다」와 「몇 건」을 갈라 적는다.
why_or_count() { if [ -n "$GREP_WHY" ]; then printf '%s' "$GREP_WHY"; else printf '%s개' "$COUNT_N"; fi; }
# 「센다」를 하는 자리도 읽기 오류를 0건으로 삼키지 않는다.
count_or_fail() { # count_or_fail <파일> <정규식> → COUNT_N 에 건수 · rc 1 = 읽기 오류
  local f="$1" re="$2" out rc
  GREP_WHY=""; COUNT_N=0
  out="$(grep -cE "$re" "$f" 2>/dev/null)"; rc=$?
  if [ "$rc" -ge 2 ]; then GREP_WHY="읽기 오류(grep rc=$rc)"; return 1; fi
  COUNT_N="${out:-0}"
  return 0
}

sk() { printf '  skip %s  (%s)\n' "$1" "$2"; skip=$((skip+1)); }   # ★건너뛴 것은 통과로 세지 않는다
ck() { # ck <이름> <조건 rc> <근거>
  if [ "$2" -eq 0 ]; then printf '  ok   %s\n' "$1"; pass=$((pass+1))
  else printf '  FAIL %s  ← %s\n' "$1" "$3"; fail=$((fail+1)); fi
}

echo "== 파일 =="
[ -f "$SH" ]; ck "bootstrap.sh 실재" $? "파일 없음"
[ -f "$PS" ]; ck "bootstrap.ps1 실재" $? "파일 없음"

echo "== 인코딩 (외부 검토 1차 [3]) =="
# ★PowerShell 5.1 은 BOM 없는 .ps1 을 ANSI 로 읽어 한글이 전부 깨진다. 문법 검사로는 안 잡힌다.
[ "$(head -c3 "$PS" | xxd -p)" = "efbbbf" ]; ck "ps1 = UTF-8 with BOM" $? "첫 3바이트가 efbbbf 가 아니다"
! grep -qU $'\r' "$SH" 2>/dev/null; ck "sh 에 CRLF 없음" $? "CRLF 발견"

echo "== 문법 =="
bash -n "$SH" 2>/dev/null; ck "bash -n 통과" $? "문법 오류"
# ⚠ps1 파서 검사는 이 기계에서 불가(PowerShell 부재) — T-W10

echo "== 맥 수정 =="
grep -q 'set -o pipefail' "$SH"; ck "[5] 설치기 호출에 pipefail" $? "curl 실패가 rc 0 으로 통과한다"
grep -q 'PATH="\$HOME/.local/bin:\$PATH"' "$SH"; ck "[1] 설치 직후 PATH 즉시 갱신" $? "깨끗한 기계에서 매번 rc 4 로 끝난다"
grep -q 'elif \[ -n "\$cpath" \]' "$SH"; ck "[6] 1-2 세 갈래(반쪽 설치=failed)" $? "명령 부재와 반쪽 설치를 같은 unknown 으로 찍는다"
grep -q 'exec < /dev/tty' "$SH"; ck "[2] 기동 전 stdin 을 터미널로 되돌림" $? "파이프로 들어오면 대화형 세션이 안 선다"
grep -q '배포 한 줄' "$SH"; ck "[2] 배포 한 줄이 파일에 적혀 있음" $? "어떻게 도착하는지가 코드에 없다"

echo "== 윈도우 수정 =="
grep -q 'psExe' "$PS"; ck "[4] 설치기를 자식 프로세스로" $? "iex in-process 라 설치기의 exit 가 부트스트랩을 죽인다"
no_code "$PS" 'ErrorAction Stop \| Invoke-Expression'; ck "[4] in-process iex 잔여 0" $? "in-process 호출이 남아 있다"
# ⚠앞 판은 `GetEnvironmentVariable('Path'` 하나만 봤다 — 뮤테이션에서 **Machine 쪽만 지워도 통과**했다.
#   두 원천(Machine·User)과 대입까지 셋을 다 본다.
mp=$(grep -c "GetEnvironmentVariable('Path','Machine')" "$PS")
up=$(grep -c "GetEnvironmentVariable('Path','User')" "$PS")
as=$(grep -c '\$env:Path =' "$PS")
[ "$mp" -ge 1 ] && [ "$up" -ge 1 ] && [ "$as" -ge 1 ]; ck "[1] 설치 직후 \$env:Path 재읽기(Machine+User+대입)" $? "PATH 갱신이 온전하지 않다(Machine=$mp User=$up 대입=$as)"
# ⚠주석에 든 어휘를 세면 안 된다 — 이 축은 처음에 자기 경고 주석을 잡아 적색을 냈다(자기신고).
no_code "$PS" 'Write-Output'; ck "[외부 검토 4] Write-Output 잔여 0(코드 줄)" $? "함수 반환 스트림이 오염된다"
grep -q 'if (\$isAdmin)' "$PS"; ck "[외부 검토 1] 1-6 admin 분기" $? "맥판과 판정이 다르다"
grep -q '\$arch -and \$is64' "$PS"; ck "[외부 검토 2] 32비트 failed 분기" $? "비고와 판정이 어긋난다"

echo "== T-M10 실측 수정 =="
# ★능력 프로브는 --help 여야 한다. auth status 로 프로브하면 낡은 판본에서 그 문자열이 질문으로 나간다.
grep -q 'claude --help 2>/dev/null | grep -qE' "$SH"; ck "[F2/F3] sh 능력 프로브가 --help 기반" $? "auth status 로 프로브하면 모델 호출이 된다"
grep -q "match '(?m)^..s\*auth..s'" "$PS" || grep -q 'Test-ClaudeAuthCmd' "$PS"; ck "[F2/F3] ps1 능력 프로브 실재" $? "능력 프로브가 없다"
grep -q '낡음 — 판올림이 필요하다' "$SH"; ck "[F2] sh 1-2 에 「낡음」 판정값" $? "낡은 전역 설치를 ok 로 통과시킨다"
grep -q '낡음 — 판올림이 필요하다' "$PS"; ck "[F2] ps1 1-2 에 「낡음」 판정값" $? "같음"
grep -q 'claude auth login' "$SH"; ck "[F1] sh 가 로그인을 실제로 연다" $? "폴링만 하고 창을 안 연다(문안이 거짓)"
grep -q 'claude auth login' "$PS"; ck "[F1] ps1 이 로그인을 실제로 연다" $? "같음"
grep -q '판올림이 먼저 필요합니다' "$SH"; ck "[F3] sh 능력 없으면 폴링 금지" $? "낡은 판본에서 10분을 헛되이 기다린다"
grep -q '판올림이 먼저 필요합니다' "$PS"; ck "[F3] ps1 능력 없으면 폴링 금지" $? "같음"
c=$(grep -E '^[[:space:]]*say ' "$SH" | grep -c '\*\*'); [ "$c" -eq 0 ]; ck "[화면] sh say 에 마크다운 굵게 0" $? "터미널에 별표가 그대로 찍힌다(${c}행)"
c=$(grep -E '^[[:space:]]*Say ' "$PS" | grep -c '\*\*'); [ "$c" -eq 0 ]; ck "[화면] ps1 Say 에 마크다운 굵게 0" $? "같음(${c}행)"

echo "== 무개입 기본 (운영자 15:0x) =="
grep -q '무개입 기본' "$SH"; ck "[개입] sh 지침이 무개입 기본" $? "지침이 물어도 되는 것으로 남아 있다"
grep -q '무개입 기본' "$PS"; ck "[개입] ps1 지침이 무개입 기본" $? "같음"
grep -q '기본 정책 (갈림길에서 묻지 말고 이대로)' "$SH"; ck "[개입] sh 기본 정책 표 실재" $? "갈림길에서 고르라고 하게 된다"
grep -q '기본 정책 (갈림길에서 묻지 말고 이대로)' "$PS"; ck "[개입] ps1 기본 정책 표 실재" $? "같음"
codegrep "$SH" 'seed_claude_prefs .*\|\| human'; ck "[개입] sh 사전 설정 호출부" $? "함수만 있고 아무도 안 부른다"
[ "$(grep -c 'Set-ClaudePrefs' "$PS")" -ge 2 ]; ck "[개입] ps1 사전 설정 정의+호출" $? "정의만 있고 호출이 없다"
# 🔴이 축은 2026-09-05 [11] 에서 **재조준**했다(완화가 아니라 조준 교정).
#   옛 축 = 「python3 라는 글자가 파일에 있으면 적색」. 그 축은 **절대 경로로 부르는 것까지** 적색으로 만든다.
#   위험의 실체는 글자가 아니라 **이름으로 부르는 것**이다 — 이름으로 부르면 컴퓨터에 원래 있던 것이
#   잡히고 깨끗한 맥에서 도구 설치 창이 뜬다. 절대 경로로 부르면 그 창이 뜨지 않는다.
#   ⇒ 금지 대상 = 줄 맨 앞이나 명령 자리에서 `python`·`python3` 를 **이름으로** 부르는 것.
#   완화 범위 = 「/」로 시작하는 절대 경로 호출 1가지뿐이고, 그 외에는 옛 축과 같다.
#   ⚠앞선 판은 「앞이 공백이면」까지 잡아 **기록 문구 안의 낱말**(bundled python not found)에 걸렸다.
#   명령 자리 = 줄머리 · 파이프·세미콜론·논리연산 뒤 · 명령치환 안 · exec 뒤. 그 자리만 본다.
no_code "$SH" '(^|[;&|]|\$\(|`|exec )[[:space:]]*python3?[[:space:]]'; ck "[개입] sh 가 이름으로 python 을 부르지 않는다" $? "이름으로 부르면 깨끗한 맥에서 도구 설치 창이 뜬다"
no_code "$PS" '(^|[;&|][[:space:]]*)python3?[[:space:]]'; ck "[개입] ps1 이 이름으로 python 을 부르지 않는다" $? "같음"
codegrep "$SH" '^HUMAN_HANDS=0$' && codegrep "$SH" 'HUMAN_HANDS=\$\(\(HUMAN_HANDS \+ 1\)\)'; ck "[개입] sh 사람 손 계수 = 초기화+증가 둘 다" $? "초기화나 증가 한쪽이 없다(set -u 에서 죽는다)"
codegrep "$PS" 'script:HumanHands\+\+'; ck "[개입] ps1 사람 손 계수가 실제로 는다" $? "변수만 있고 세지 않는다"
codegrep "$SH" 'install-jarvis' && no_code "$SH" '\.install-jarvis'; ck "[개입] sh 작업 폴더에 점이 없다(코드 줄)" $? "plutil keypath 가 점에서 쪼개진다"

echo "== 2차 실측 수정 =="
codegrep "$SH" '\*"No such file"\*\)'; ck "[⑴] sh 2-2 미온보딩 갈래(코드)" $? "정상 상태를 데몬 사망으로 읽는다"
codegrep "$PS" "match 'No such file'"; ck "[⑴] ps1 2-2 미온보딩 갈래(코드)" $? "같음"
codegrep "$SH" 'cys_state="앱만"'; ck "[⑵] sh 1-4 「앱만」 갈래(코드)" $? "「없음이 정상」 문구가 「있음」을 설명 못 한다"
codegrep "$PS" "cys 상태.*앱만"; ck "[⑵] ps1 1-4 「앱만」 갈래(코드)" $? "같음"
codegrep "$SH" 'row "1-5".*계정 성격' && codegrep "$SH" 'row "1-6".*계정 성격'; ck "[⑶] sh 1-5·1-6 두 행 모두 「계정 성격」" $? "한쪽만 고쳐져 있다"
grep -q '계정 성격' "$PS"; ck "[⑶] ps1 「계정 성격」 문구" $? "같음"

echo "== 온보딩 실증 수정 (2026-09-04 15:2x) =="
codegrep "$SH" 'row "1-8" "cys 실행 링크"'; ck "[링크] sh 1-8 감지 행(코드)" $? "끊어진 cysd 링크를 아무도 안 본다"
codegrep "$PS" "'1-8' 'cys 실행 링크'"; ck "[링크] ps1 1-8 자리(코드)" $? "윈도우 칸이 비어 있다"
grep -q 'Contents/MacOS/cysd' "$SH"; ck "[링크] sh 우회 경로가 적혀 있다" $? "우회 수단이 코드에 없다"
# 🔴네 번째 재발: `codegrep` 은 주석만 뺀다 — **지침 heredoc 의 설명문**은 코드가 아닌데 코드로 세어졌다.
#   ⇒ 어휘가 아니라 **명령 자리**를 봐야 한다(줄머리 또는 `;`/`|`/`&&` 뒤).
! grep -vE '^[[:space:]]*#' "$SH" | grep -qE '(^[[:space:]]*|[;|&(][[:space:]]*)sudo[[:space:]]'; ck "[권한] sh 에 sudo 실행 0(명령 자리 기준)" $? "권한 상승 0 확정을 어긴다"
grep -q '제안만 하고 실행하지 마라' "$SH"; ck "[권한] sh 지침이 sudo 제안-only" $? "자비스가 링크를 스스로 고치려 든다"

echo "== T-W10 실기 수정 (2026-09-04 · 발견 F-W2~F-W12) =="
# F-W3 배포 한 줄 — 실행 정책
# ⚠이 축은 **주석을 잰다** — 배포 한 줄은 문서(헤더)에만 있기 때문이다. 그래서 어휘가 아니라 **줄의 형태 전체**를 잰다
#   (어휘만 세면 「Bypass 라는 말이 어딘가 있다」로 통과한다 — 뮤테이션에서 실제로 그렇게 뚫렸다).
# 🔴2026-09-05 개정: 정본 한 줄이 cmd 창에서도 돌도록 바뀌었다(맨 앞이 powershell · $ 를 안 쓴다).
#   그래서 옛 지문($env:TEMP)으로는 못 잰다. 재는 성질은 그대로 둘이다 —
#   ⑴실행 정책을 넘기는가 ⑵cmd 창에서도 첫 낱말이 서는가.
grep -q 'powershell -NoProfile -ExecutionPolicy Bypass -Command' "$PS"; ck "[F-W3] ps1 배포 한 줄이 cmd 창에서도 서는 형태" $? "맨 앞이 powershell 이 아니면 cmd 창에서 첫 줄에 죽는다"
# 🔴2026-09-06 재조준: 내려받는 자리를 임시 폴더에서 사용자 폴더로 옮겼다.
#   옛 축은 GetTempPath 라는 낱말이 있는지를 봤다 — 이제 그 낱말이 있으면 오히려 적색이다.
! grep -q 'GetTempPath' "$PS"; ck "[F-W3] ps1 배포 한 줄이 임시 폴더를 쓰지 않는다" $? "임시 폴더는 언제든 비워지고 회사 컴퓨터는 그 자리 실행을 막아 둔다"
grep -q "GetFolderPath('UserProfile')" "$PS"; ck "[F-W3] ps1 배포 한 줄이 사용자 폴더를 가리킨다" $? "자리 식이 없다"
! grep -q '/tmp/install-jarvis.sh' "$SH"; ck "[F-W3] sh 배포 한 줄도 임시 폴더를 쓰지 않는다" $? "두 OS 가 갈린다"
# 자리를 우리말·공백 이름에서 실제로 만들어 본다(지문만 보면 이어 붙이는 방식이 갈려도 모른다)
OPARITY="$DIR/../tests/oneliner-path-parity.py"
if [ -f "$OPARITY" ] && command -v python3 >/dev/null 2>&1; then
  python3 "$OPARITY" >/dev/null 2>&1
  ck "[F-W3] 배포 한 줄이 우리말·공백 폴더에서 성립한다(실제로 만들어 본다)" $? "그 이름에서만 깨지는 결함은 실기 당일에 처음 드러난다"
else
  sk "[F-W3] 배포 한 줄이 우리말·공백 폴더에서 성립한다" "대조 도구가 이 디렉터리에 없다"
fi
[ "$(grep -c 'powershell -ExecutionPolicy Bypass -File' "$PS")" -ge 1 ]; ck "[F-W3] ps1 배포 한 줄 안쪽 실행에도 Bypass" $? "받아 놓은 파일이 정책에 막힌다"
# ★같은 줄을 **참가자가 보는 문서**에서도 잰다 — 이쪽이 진짜 소비처다
if [ -n "$DOC" ]; then
  # 🔴🔴**이력 문서를 「오늘 쓰는 절차서」로 채점하지 않는다**(교차 검토 7차 지적 채택 2026-09-09).
  #   앞 판은 내부 문서를 이름으로 박아 두고 현행 절차서처럼 채점했다.
  #   그 문서는 **그날의 기록**이라 고치지 않는 것이 규율인데, 축은 그 문서에 옛 단계 표기(`[1/11]`)와
  #   아고라 안내가 **있어야** 통과였다 ⇒ ★**이력을 고치면 적색이 되고, 안 고치면 옛 판이 현행으로 채점된다.**
  #   둘 다 틀렸다. 이력은 이력으로 두고, 현행 절차서는 **포인터로 가리킨다**.
  #   포인터 = `docs/install-master/CURRENT-RUNBOOK`(첫 줄에 파일 이름 한 줄). 없으면 **건너뛴다**(통과 아님).
  RUNW=""
  RUNPTR="$DIR/../docs/install-master/CURRENT-RUNBOOK"
  if [ -f "$RUNPTR" ]; then
    rb="$(sed -n '1p' "$RUNPTR" | tr -d '\r' | sed 's/[[:space:]]*$//')"
    case "$rb" in ""|\#*) rb="" ;; esac
    [ -n "$rb" ] && RUNW="$DIR/../docs/install-master/$rb"
  fi
  if [ -n "$RUNW" ] && [ -f "$RUNW" ]; then
    # 현행 절차서라면 **오늘의 단계 수**를 실어야 한다 — 이력과 갈리는 지점이 정확히 여기다.
    absent_or_fail "$RUNW" '\[[0-9]+/11\]'; rc=$?
    ck "[절차서] 현행 절차서에 옛 표기(/11) 0건" "$rc" "현행이라면서 열한 단을 싣고 있다(${GREP_WHY})"
    absent_or_fail_i "$RUNW" 'agora|아고라'; rc=$?
    ck "[절차서] 현행 절차서에 아고라 안내 0건" "$rc" "설치와 토론장은 별개다(${GREP_WHY})"
    grep -q "GetFolderPath('UserProfile')" "$RUNW"; ck "[F-W3] 실기 절차서가 지금 줄을 싣고 있다" $? "절차서에 옛 줄이 실려 사람이 그것을 복사한다"
    ! grep -q 'env:TEMP' "$RUNW"; ck "[F-W3] 실기 절차서에 임시 폴더 줄이 없다" $? "옛 줄이 남아 있다"
    [ "$(grep -c 'powershell -NoProfile -ExecutionPolicy Bypass -Command' "$RUNW")" -ge 2 ]; ck "[F-W3] 실기 절차서에 지우기·설치 두 줄이 다 있다" $? "한 줄이 빠졌다"
    absent_or_fail "$RUNW" '박사님|설치 자비스|슬라이스|미실측|T-M[0-9]|T-W[0-9]|F-W[0-9]|\bagy\b|codex|fable|봉합|§|\[master#'; rc=$?
    ck "[공개] 실기 절차서 내부 용어 0건" "$rc" "노출 ${GREP_WHY}"
    # 🔴리뷰 수정(2026-09-06) — 되돌리면 적색이 되는 성질만 잰다.
    #   ⑴ 두 번 도는 것을 **한 줄을 치기 전에** 알려야 한다(뒤에서 알리면 이미 다 끝난 뒤다)
    awk '/시작 전에 한 가지만 알아 두십시오/{if(!a)a=NR} /install-jarvis\.ps1.\)"$/{if(!b)b=NR} END{exit !(a&&b&&a<b)}' "$RUNW"
    ck "[리뷰] 두 번 도는 것을 설치 한 줄 앞에서 알린다" $? "붙여넣고 다 끝낸 뒤에야 「한 번 더」를 읽는다"
    grep -q '두 번째는 0번(지우기)부터 다시' "$RUNW"; ck "[리뷰] 두 번째가 0번부터인 것을 말한다" $? "지우지 않고 다시 돌려 건너뛴다"
    #   ⑵ 결과 적는 표가 두 벌이어야 두 번째 결과를 덮어쓰지 않는다
    #   ⚠단계 번호를 축에 박지 않는다 — 박으면 단계 수가 바뀌는 날 이 축이 적색이 된다(7차 검토가 잡은 형태).
    [ "$(grep -cE '^\| `\[1/[0-9]+\]` \| \| \| \|$' "$RUNW")" = "1" ]; ck "[리뷰] 5-2 표가 창별 두 칸이다" $? "두 번째 결과를 적을 자리가 없어 덮어쓴다"
    #   ⑶ 지울 것이 없을 때 멈추지 않는다
    grep -q '목록에 `cys` 가 안 보이면 이 단계는 그냥 넘어가십시오' "$RUNW"; ck "[리뷰] 지울 것이 없을 때 넘어가라고 말한다" $? "첫 설치인 사람이 0번에서 멈춘다"
    #   ⑷ 사람이 글자를 친 뒤 무엇을 눌러야 하는지 적혀 있다(두 자리)
    [ "$(grep -c '엔터(Enter) 키를 누르' "$RUNW")" -ge 2 ]; ck "[리뷰] 치는 자리마다 엔터를 말한다" $? "치고 가만히 기다린다"
  else
    sk "[F-W3] 현행 실기 절차서 검사" "CURRENT-RUNBOOK 포인터가 없다(이력 문서는 채점하지 않는다)"
    sk "[절차서] 현행 절차서 단계·아고라 검사" "같은 이유"
  fi
  # ★「Bypass 형태가 하나라도 있다」로는 부족하다 — **없어야 할 형태가 없는지**를 따로 잰다(문서에 줄이 여럿이다)

  # ★재는 것은 「UTF8 인가」가 아니라 **「인코딩을 말했는가」**다 — BOM 시험 줄은 `-Encoding Byte` 가 맞는 값이다.
  #   (앞 판은 UTF8 만 허용해 **옳은 줄을 적색으로 찍었다** — 축이 뭉툭하면 맞는 것을 틀렸다고 한다.)
  ! grep -o 'Get-Content [^|)]*' "$DOC" | grep -qv 'Encoding'; ck "[F-W15] 절차서의 모든 Get-Content 에 인코딩 명시" $? "인코딩을 안 주면 파일이 아니라 콘솔 기본값을 보고한다(표시 착시)"
else
  sk "[F-W3] 절차서 배포 한 줄 형태" "문서가 이 디렉터리에 없다"
  sk "[F-W15] 절차서 Get-Content 인코딩" "문서가 이 디렉터리에 없다"
fi
# F-W7 BOM 없는 쓰기 — 정확히 「.claude.json 을 Set-Content -Encoding UTF8 로 쓰지 않는다」를 잰다
codegrep "$PS" 'UTF8Encoding\(\$false\)'; ck "[F-W7] ps1 BOM 없는 쓰기 헬퍼" $? "Set-Content -Encoding UTF8 은 5.1 에서 BOM 을 붙인다"
# ⚠**인자 순서에 기대지 마라** — PowerShell 은 `-Path` 와 `-Encoding` 의 순서가 자유롭다.
#   앞 판은 `Set-Content -Path $cfg` 라는 **한 가지 형태만** 금지해서, 순서를 바꾼 되돌리기에 **뚫렸다**(뮤테이션 실측).
#   ⇒ 대상 변수로 잡는다(세 산출 파일 + settings.json 을 한 축으로).
no_code "$PS" 'Set-Content.*(\$cfg|\$ReportFile|\$DirectiveFile|\$sf)'; ck "[F-W7] 우리 산출 파일을 Set-Content 로 안 쓴다" $? "BOM 이 붙는 경로가 남아 있다"
# 🔴T-W10 실사고 대응 — 남의 설정 파일을 왕복시키기 전에 사본을 남기고, 쓴 뒤 되읽어 확인한다
codegrep "$PS" 'bak-jarvis'; ck "[사고] .claude.json 재기록 전 자동 백업" $? "참가자 설정을 되돌릴 길 없이 왕복시킨다"
codegrep "$PS" 'Copy-Item "\$cfg\.bak-jarvis"'; ck "[사고] 되읽기 실패 시 사본으로 원복" $? "깨뜨리고 그냥 끝낸다"
codegrep "$PS" '\$back\.hasCompletedOnboarding'; ck "[사고] 쓴 뒤 되읽어 확인한다" $? "원복 장치는 있는데 그것을 켜는 검사가 없다"
codegrep "$PS" "JarvisHome -replace .*,'/'"; ck "[F-W7b] projects 키를 두 형태로 쓴다" $? "클로드는 포워드 슬래시 키만 본다(T-W10 실측)"
# F-W9·F-W10 settings.json — .claude.json 과 다른 파일이다
codegrep "$PS" 'skipDangerousModePermissionPrompt'; ck "[F-W9] ps1 bypass 동의 사전 설정" $? "쓴 적이 없으면 프롬프트가 그대로 뜬다"
codegrep "$PS" 'remoteControlAtStartup'; ck "[F-W10] ps1 원격제어 기본 끔" $? "2절 ⑺ 2(원격 제어 안 함)와 어긋난다"
codegrep "$PS" "Join-Path .* 'settings.json'"; ck "[F-W9] settings.json 을 실제로 연다" $? "키만 있고 파일을 안 건드린다"
codegrep "$PS" 'Set-ClaudeSettings \$t.Settings'; ck "[F-W9] Set-ClaudeSettings 를 호출한다" $? "함수만 있고 안 부른다"
# F-W2 1-4 레지스트리 축 (맥 3축 동등)
codegrep "$PS" 'CurrentVersion.Uninstall'; ck "[F-W2] ps1 1-4 레지스트리 축" $? "cys 가 깔려 있어도 「깨끗한 기계」로 적힌다"
codegrep "$PS" 'CysAppFound'; ck "[F-W2] 앱 축 상태를 보관한다" $? "2단이 그 사실을 못 읽는다"
# F-W5 2-* 가 상태를 읽는다
no_code "$PS" "'2-\*' 'cys 이후 전 행' '-' 'unknown' 'cys 가 아직 없다"; ck "[F-W5] 2-* 비고가 고정 문자열이 아니다" $? "1-4 와 한 장 안에서 모순을 낸다"
# F-W4 1-2 파일 축
codegrep "$PS" 'probeClaude'; ck "[F-W4] ps1 1-2 파일 축(창별 PATH 가시성)" $? "창이 다르면 「없음」으로 거짓 음성을 낸다"
# F-W6 표 순서
awk '/Add-Row .1-7./{s=NR} /Add-Row .1-8./{e=NR} END{exit !(s&&e&&s<e)}' "$PS"; ck "[F-W6] 1-7 이 1-8 보다 먼저 삽입된다" $? "보고서 표가 번호순이 아니다"
# F-W8 관측 개입 빈칸
codegrep "$PS" '실제로 누른 횟수'; ck "[F-W8] 보고서에 관측 개입 빈칸" $? "계수기가 「목표 달성」 쪽으로만 틀린다"
# F-W12 관리자 판정 — 두 OS 동시에
! grep -qE '"1-6" "관리자 그룹" "admin 없음" "blocked"' "$SH"; ck "[F-W12] sh 1-6 = 표준 계정도 ok" $? "정상값을 적색으로 적고 종합 판정을 끌어내린다"
no_code "$PS" "'1-6' '관리자 여부' \"IsInRole\(Administrator\)=False\" 'blocked'"; ck "[F-W12] ps1 1-6 = 표준 계정도 ok" $? "같음"

echo "== 2차 실측 수정 (F-W17 · 레지스트리 ≠ 몸통) =="
codegrep "$PS" 'cysBody'; ck "[F-W17] 실행 파일 존재를 따로 잰다" $? "레지스트리 등록만 보고 「앱 있음」으로 거짓 양성"
codegrep "$PS" 'Get-ChildItem \$r -Filter'; ck "[F-W17] 설치 위치에서 실행 파일을 찾는다" $? "몸통 축이 값을 안 만든다"
codegrep "$PS" '등록만 남음'; ck "[F-W17] 「등록만 남음」 갈래" $? "이전 실패 잔존을 ok 로 삼킨다"
awk '/cysReg -and/{if(!a)a=NR} /cysOnboard -eq .있음. -and/{if(!b)b=NR} END{exit !(a&&b&&a<b)}' "$PS"; ck "[F-W17] 「등록만 남음」을 온보딩 갈래보다 먼저 판정" $? "순서가 뒤면 온보딩 있음이 그것을 ok 로 삼킨다"
codegrep "$PS" 'CysBodyMissing'; ck "[F-W17] 몸통 부재를 상태로 보관(1-8·2-* 가 읽는다)" $? "같은 사실을 세 곳이 따로 추측한다"

# ★「회색」이라는 낱말만 세면 뚫린다(뮤테이션 실측) — **안내 문장이 지침 본문에 살아 있는지**를 잰다
grep -q '회색 글씨가 보이면' "$PS" && grep -q '회색 글씨가 보이면' "$SH" && grep -q '첫 응답 말미에 반드시 붙이는 한 줄' "$PS"; ck "[F-W18] 두 지침 모두 회색 제안글 안내" $? "사람이 「내가 안 쳤는데」로 읽는다(2차 실측)"

codegrep "$PS" 'script:StepLog'; ck "[F-W19] 지나온 단계를 보고서에 남긴다" $? "클로드 TUI 가 화면을 덮으면 무슨 단계를 지났는지 사라진다"
codegrep "$PS" '지나온 단계'; ck "[F-W19] 보고서에 「지나온 단계」 절" $? "모아만 두고 안 적는다"

echo "== 외부 검토 1차 수정 (2026-09-04) =="
codegrep "$PS" 'GetUnresolvedProviderPathFromPSPath'; ck "[외부 검토 1] BOM 없는 쓰기가 상대 경로를 절대로 푼다" $? ".NET 현재 위치는 PowerShell 위치와 다르다 — 엉뚱한 자리에 쓴다"
awk '/^function Invoke-DetectStage1/{f=1} f&&/script:CysAppFound = \$false/{ok=1;exit} f&&/# 1-1/{exit} END{exit !ok}' "$PS"; ck "[외부 검토 3] 재감지 전에 상태 변수를 끈다" $? "로그인 뒤 재감지에서 앞 호출의 true 잔재가 틀린 ok 를 낸다"
codegrep "$PS" 'script:IsAdmin = \$isAdmin'; ck "[외부 검토 2] 관리자 여부를 상태로 보관" $? "판정을 ok 로 바꾸면서 그 사실이 글자로만 남았다"
codegrep "$PS" 'null -eq \$o'; ck "[자기발견] \$o 가 null 이면 빈 파일로 덮지 않는다" $? "0바이트 설정 파일을 만나면 조용히 남의 설정을 빈 파일로 덮는다"

echo "== 지침 본문 훼손 방지 =="
# 지침은 인용 없는 heredoc(sh) / 확장 here-string(ps1) 안에 있다.
# 그 안의 백틱은 sh 에서는 명령치환으로 실행되고 ps1 에서는 이스케이프 문자로 먹힌다.
# 어느 쪽이든 낱말이 조용히 사라지고 문장은 멀쩡해 보인다 — 받는 쪽이 훼손을 모른다.
count_from_or_fail '`' -- awk '/cat > "\$DIRECTIVE_FILE" <<DIRECTIVE/{f=1;next} /^DIRECTIVE$/{f=0} f' "$SH"; rc=$?
[ "$rc" -eq 0 ] && { [ "$COUNT_N" -eq 0 ]; rc=$?; }
ck "[지침] sh 지침 본문에 백틱 0개" "$rc" "$(why_or_count) — 그 자리의 낱말이 사라진 채 배달된다"
count_from_or_fail '`' -- awk '/\$d = @"/{f=1;next} /^"@/{f=0} f' "$PS"; rc=$?
[ "$rc" -eq 0 ] && { [ "$COUNT_N" -eq 0 ]; rc=$?; }
ck "[지침] ps1 지침 본문에 백틱 0개" "$rc" "$(why_or_count) — PowerShell 이 이스케이프 문자로 먹는다"

echo "== 3차 실기 수정 (①~⑦) =="
codegrep "$PS" "BootstrapVersion = 'v1'"; ck "[①] 배너 판본이 올랐다" $? "9단인데 4단 시절 표기를 쓴다"
grep -q 'BOOTSTRAP_VERSION="v1"' "$SH"; ck "[①] sh 도 같음" $? "같음"
codegrep "$PS" 'OutputEncoding = .System.Text.Encoding.::UTF8'; ck "[②⑴] 콘솔 출력 인코딩" $? "막힌 자리의 오류 문구를 읽을 수 없다"
codegrep "$PS" 'function Invoke-Logged'; ck "[②⑵] 외부 명령 출력을 잡아 기록한다" $? "실패한 명령의 출력이 로그에 안 남는다"
no_code "$PS" 'init-pack \| Out-Host'; ck "[②⑵] Out-Host 우회 경로가 없다" $? "그 줄만 로그를 비켜 간다"
codegrep "$PS" 'new-surface failed'; ck "[⑤] 세션 실패 사유를 기록한다" $? "원인 불명이 반복된다"
awk '/cys 창 안에서 이어서/{a=1} END{exit !a}' "$PS"; ck "[⑤] 폴백 2 = 사람이 칠 한 줄 인쇄" $? "cys 안에서 마무리할 길이 화면에 없다"
codegrep "$PS" 'DaemonTemporary'; ck "[④] 이번에만 켠 것을 표시한다" $? "재부팅하면 꺼지는데 그 말을 안 한다"
codegrep "$PS" 'Start-Process -FilePath \$sideCar'; ck "[④] 프로그램 직접 기동 폴백" $? "등록이 막히면 길이 끊긴다"
codegrep "$PS" "cys-app.exe'"; ck "[④] 본체를 먼저 고른다(뒤 부분까지 함께 켠다)" $? "본체 대신 뒤 부분만 켜면 창이 안 선다"
no_code "$PS" 'Start-Process.*-Verb RunAs'; ck "[④] 권한 상승을 시도하지 않는다" $? "우리 원칙을 어긴다"
# ⑥ 깨끗이 지우기 — 되돌릴 수 없으므로 확인과 목록이 반드시 앞에 있어야 한다
if [ -f "$RESET" ]; then
  [ "$(head -c3 "$RESET" | xxd -p)" = "efbbbf" ]; ck "[⑥] reset = UTF-8 with BOM" $? "한글이 깨진다"
  codegrep "$RESET" 'Read-Host'; ck "[⑥] 지우기 전에 사람에게 묻는다" $? "묻지 않고 지운다"
  codegrep "$RESET" '지웁니다'; ck "[⑥] 확인 문구가 정해져 있다" $? "아무 키나 눌러도 지워진다"
  #   ⚠2026-09-08 재작성으로 배너 문구가 바뀌었다(맥과 대칭). **재는 성질은 그대로다** —
  #   「목록이 먼저 나오고 그 다음에 묻는다」. 문구가 아니라 성질을 anchoring 하도록 폭을 넓힌다.
  awk '/=== 이 컴퓨터의 상태 ===|=== 깨끗이 지우기 — 지울 목록 ===/{if(!a)a=NR} /Read-Host/{if(!b)b=NR} END{exit !(a&&b&&a<b)}' "$RESET"; ck "[⑥] 목록을 먼저 보이고 그 다음에 묻는다" $? "무엇을 지울지 모르고 답하게 된다"
  codegrep "$RESET" 'WhatIf'; ck "[⑥] 보기만 하는 길이 있다" $? "확인할 방법이 없다"
  codegrep "$RESET" '되돌릴 수 없습니다'; ck "[⑥] 되돌릴 수 없음을 말한다" $? "사람이 가볍게 누른다"
  codegrep "$RESET" '로그인'; ck "[⑥] 로그인이 지워진다는 것을 말한다" $? "다시 로그인해야 하는 줄 모른다"
  absent_or_fail "$RESET" '박사님|설치 자비스|슬라이스|미실측|T-W[0-9]|F-W[0-9]|봉합|§'
  ck "[⑥] reset 내부 용어 0건" $? "노출 ${GREP_WHY} — 인터넷에 그대로 나간다"
  no_code "$RESET" 'HKLM'; ck "[⑥] 시스템 영역은 건드리지 않는다" $? "HKLM 을 지운다"
else
  sk "[⑥] reset-clean.ps1 검사" "파일이 이 디렉터리에 없다"
fi

echo "== 교차 검토(4차) 수정 =="
awk '/^function Step-InstallCys/{f=1;next} f&&/^}/{f=0} f&&/Mode -eq .dry./{if(!a)a=NR} f&&/설치 파일이 없습니다/{if(!b)b=NR} END{exit !(a&&b&&a<b)}' "$PS"; ck "[R4-1] dry 판정이 파일 검사보다 먼저" $? "dry-run 이 항상 중단된다"
awk '/^step_install_cys\(\)/{f=1;next} f&&/^}/{f=0} f&&/MODE. = .dry./{if(!a)a=NR} f&&/설치 파일이 없습니다/{if(!b)b=NR} END{exit !(a&&b&&a<b)}' "$SH"; ck "[R4-1] sh 도 같음" $? "같음"
awk '/finally \{/{f=1;next} f&&/ProgressPreference = \$pref/{ok=1} f&&/^[[:space:]]*\}/{f=0} END{exit !ok}' "$PS"; ck "[R4-2] 진행 표시 설정을 반드시 되돌린다" $? "실패 한 번에 이 창의 설정이 영구히 바뀐다"
codegrep "$PS" 'Get-Command claude -ErrorAction SilentlyContinue\)\) \{'; ck "[R4-3] 자비스를 못 띄우면 성공으로 보고하지 않는다" $? "안 떴는데 0 을 돌려준다"
codegrep "$SH" 'command -v claude'; ck "[R4-3] sh 도 같음" $? "같음"
awk '/foreach \(\$sw in/{f=1} f&&/catch \{/{c=1} f&&c&&/continue/{ok=1} END{exit !ok}' "$PS"; ck "[R4-4] 한 방법이 실패해도 다음 방법을 시도" $? "설치 창 폴백을 못 밟는다"
codegrep "$PS" 'alive = \$true'; ck "[R4-5] 응답을 한 번 받으면 그것으로 판정" $? "다시 물어 성공이 실패가 된다"
codegrep "$SH" 'alive=1'; ck "[R4-5] sh 도 같음" $? "같음"
codegrep "$PS" 'Test-Path \$bkFile\) \{ Remove-Item \$bkFile'; ck "[R4-6] 옛 백업을 새 백업으로 착각하지 않는다" $? "지난 실행의 백업을 믿고 지운다"

echo "== 만든 사람이 알려 준 것 반영 =="
codegrep "$PS" 'ExitCode -eq 4'; ck "[6] 설치 실패 종류를 읽는다" $? "「안 됐다」만 알리고 어느 종류인지 안 알린다"
codegrep "$PS" 'cys-install-failure.txt'; ck "[6] 설치기가 남긴 기록을 사람에게 보인다" $? "무엇을 왜 못 바꿨는지 사라진다"
codegrep "$PS" '제거하지 않음'; ck "[6] 실패 시 제거 금지 안내" $? "제거하면 쓰던 것까지 잃는다"
codegrep "$PS" 'VersionInfo.ProductVersion'; ck "[7] 명령이 안 답하면 파일의 판본을 읽는다" $? "크기·날짜로 판정하게 된다"
codegrep "$PS" 'CYS_NO_AUTOSTART'; ck "[프로브] 살펴보는 호출이 데몬을 깨우지 않는다" $? "설치 직후 다른 판본 데몬이 겹친다"
codegrep "$SH" 'CYS_NO_AUTOSTART'; ck "[프로브] sh 도 같음" $? "같음"
codegrep "$SH" 'HOME/.local/bin/cys" "/usr/local/bin/cys"'; ck "[7] 맥 부르는 길 탐색 순서" $? "옛 자리의 끊어진 링크에 걸린다"
no_code "$SH" 'ln -s'; ck "[7] 링크를 새로 만들지 않는다" $? "남의 배포물 자리를 우리가 고친다"
# 자가진단은 항목이 늘어난다 — 항목 수를 가정하지 않는다
no_code "$PS" '13항목|항목 수'; ck "[8] 자가진단 항목 수를 가정하지 않는다" $? "판올림으로 항목이 늘면 깨진다"

echo "== 자기 교차 검토 수정 =="
codegrep "$PS" 'Test-Path \$bkFile\) \{'; ck "[6] 백업이 실제로 생겼을 때에만 지운다" $? "백업이 실패해도 남의 레지스트리를 지운다"
codegrep "$PS" 'env:Path = \$env:Path'; ck "[7] 경로 목록을 덮어쓰지 않고 덧붙인다" $? "이 창에만 있던 경로가 사라져 뒤 단계가 깨진다"
codegrep "$PS" '다음 단계들은 아직 하지 않았습니다'; ck "[보고] 건너뛴 단계와 실패한 단계를 구분" $? "뒤 단계가 성공한 것으로 읽힌다"
codegrep "$SH" '다음 단계들은 아직 하지 않았습니다'; ck "[보고] sh 도 같음" $? "같음"
awk '/두 번 다 실패했으면/{a=1} END{exit !a}' "$PS"; ck "[5] 두 번 실패 시 부분 파일을 남기지 않는다" $? "다음 실행이 반쯤 받은 파일을 온전한 것으로 본다"
awk '/두 번 다 실패했으면/{a=1} END{exit !a}' "$SH"; ck "[5] sh 도 같음" $? "같음"

codegrep "$PS" '\$rc = @\(& \$st.Fn\)\[-1\]'; ck "[본문] 함수 반환값을 배열로 받지 않는다" $? "출력이 섞이면 성공한 단계를 막힌 것으로 읽는다"

echo "== 아침 1쪽 (사람 손으로 전달된다) =="
if [ -n "$SHEET" ]; then
  grep -q 'powershell -ExecutionPolicy Bypass -File \$env:TEMP' "$SHEET"; ck "[1쪽] 배포 한 줄 형태" $? "옛 줄을 그대로 복사한다"
  ! grep -q 'powershell -File \$env:TEMP' "$SHEET"; ck "[1쪽] Bypass 없는 형태가 남아 있지 않다" $? "다른 절의 옛 줄을 복사한다"
  n=$(awk '/^```/{f=!f;next} f && (/_/ || /\*/ || /`/) {c++} END{print c+0}' "$SHEET")
  [ "${n:-0}" -eq 0 ]; ck "[1쪽] 명령에 밑줄·별표·백틱 0" $? "${n}줄 — 전달 중 변조돼도 사람이 못 알아챈다"
  grep -q '추가 정보' "$SHEET"; ck "[1쪽] 보안 경고에 무엇을 누를지 적혀 있다" $? "사람이 멈춘다"
  grep -q '핫스팟' "$SHEET"; ck "[1쪽] 망이 막혔을 때의 폴백" $? "기관 망이 막으면 그날 시험이 끝난다"
else
  sk "[1쪽] 검사" "1쪽이 이 디렉터리에 없다"
fi

echo "== 단계 2 — cys 설치 대행 [5]~[9] =="
codegrep "$PS" 'CysWinBytes    = 139840459'; ck "[5] 설치 파일 크기 핀(= 우리 v0.14.36 setup.exe)" $? "받다 끊긴 파일을 정상으로 본다"
codegrep "$PS" "CysVersion     = '0\\.14\\.36'"; ck "[5] 윈 판본 핀 정확값(= 우리 v0.14.36)" $? "이름표만 새 판본이고 실제로 받는 판본은 옛것이다"
codegrep "$PS" "CysWinSha256   = '12c9d398b4e11b175370c6fdc7e4fd299b2e74865c5cc0f8bf891a42eaf70066'"; ck "[5] 윈 설치 파일 sha256 정확값 핀(= 릴리스 SHA256SUMS 줄)" $? "지문이 한 글자만 틀려도 모든 설치가 지문 불일치로 멈춘다"
# ⚠2026-09-10 저장소 개명(cys-terminal → cys-ro · 운영자). 옛 주소는 301 로 이어지지만 **정본은 새 이름**이다.
#   축도 새 이름을 요구한다 — 그러지 않으면 옛 주소가 남아도 아무도 말하지 않는다.
codegrep "$PS" 'github.com/oogisoogi/cys-ro/releases/download/'; ck "[5] 윈 다운로드 자리 = 우리 릴리스" $? "받을 곳이 우리 릴리스가 아니다(벤더 판을 깔면 우리 수리가 안 닿는다)"
absent_or_fail "$PS" 'oogisoogi/cys-terminal'; rc=$?
ck "[5] 윈 설치기에 옛 저장소 이름 0건" "$rc" "개명 전 주소가 남아 있다(${GREP_WHY})"
codegrep "$PS" "CysWinSha256 += '[0-9a-f]{64}'"; ck "[5] 윈 설치 파일 sha256 핀" $? "지문 핀이 없다"
codegrep "$PS" 'Get-FileHash -Algorithm SHA256'; ck "[5] 받은 뒤 지문 대조" $? "지문을 재지 않는다"
codegrep "$PS" 'got -ne \$CysWinBytes'; ck "[5] 받은 뒤 크기를 대조한다" $? "부분 파일을 그대로 설치기에 넘긴다"
codegrep "$PS" 'Test-CysBody..Body'; ck "[6] 완료 판정 = 설치기 종료코드가 아니라 실체" $? "설치기가 0 을 냈다는 이유로 성공으로 친다"
codegrep "$PS" "foreach .\\\$sw in @\('/S', ''\)"; ck "[6] 조용한 설치(/S) → 설치 창 폴백" $? "한 가지만 시도하고 포기한다"
# 지난 설치가 끝까지 못 간 컴퓨터에서 설치기가 「먼저 지우겠다」로 가 멈추는 것을 막는다
codegrep "$PS" 'reg export'; ck "[6] 잔재 항목은 백업 후에만 지운다" $? "되돌릴 길 없이 남의 레지스트리를 지운다"
codegrep "$PS" 'CysBodyMissing\) \{'; ck "[6] 실체가 없을 때에만 잔재를 손댄다" $? "멀쩡한 설치의 항목을 지운다"
no_code "$PS" "HKLM.*Remove-Item"; ck "[6] 시스템 영역은 건드리지 않는다" $? "HKLM 을 손댄다"
codegrep "$PS" 'Start-Process -FilePath \$dst -PassThru'; ck "[6] 사람이 진행하는 폴백 경로" $? "무인 실패 시 길이 끊긴다"
codegrep "$PS" '추가 정보'; ck "[6] 보안 경고에 무엇을 누를지 적는다" $? "사람이 무엇을 눌러야 할지 모른다"
no_code "$PS" 'Step-VerifyCys[^}]*Uninstall'; ck "[7] 판정에 설치 목록을 쓰지 않는다" $? "어제 반증된 축으로 되돌아갔다"
codegrep "$PS" "cys --version"; ck "[7] 버전 응답으로 기능을 확인" $? "파일만 보고 됐다고 한다"
codegrep "$PS" 'init-pack'; ck "[8] 계정 준비 = init-pack" $? "-"
codegrep "$PS" 'daemon install'; ck "[8] 계정 준비 = daemon install" $? "-"
codegrep "$PS" 'Matches\(\$doc'; ck "[8] 자가진단 FAIL 수로 판정" $? "돌렸다는 것만으로 통과로 친다"
codegrep "$PS" 'new-surface --role master'; ck "[9] cys 안에서 세션을 연다" $? "-"
codegrep "$PS" 'ref -match .surface:'; ck "[9] 세션이 실제로 열렸는지 확인" $? "명령을 부른 것으로 열렸다고 친다"
# 판정 앞에 항상 참인 갈래를 끼우면 확인이 무력해진다 — 그런 갈래는 이 스크립트에 있을 이유가 없다.
no_code "$PS" 'if \(\$(true|false)\)'; ck "[판정] 항상 참/거짓인 갈래가 없다" $? "판정을 우회하는 갈래가 들어왔다"
no_code "$SH" 'if (true|false); then'; ck "[판정] sh 도 같음" $? "같음"
codegrep "$PS" 'dangerously-skip-permissions \$firstPrompt'; ck "[9] 열리지 않으면 이 창에서 띄운다" $? "폴백이 없어 길이 끊긴다"
awk '/function Step-DownloadCys/{a=NR} /function Step-Wake/{b=NR} END{exit !(a&&b&&a<b)}' "$PS"; ck "[5~9] 단계 순서가 코드에 있다" $? "-"

echo "== 백신 차단 대응 (2026-09-05 실측 · 우회하지 않고 알아보게 한다) =="
# 한도 없이 기다리면 경고 창 하나에 영원히 선다 — 그 상태는 사람 눈에 「멈춤」과 구분되지 않는다.
no_code "$PS" 'Start-Process -FilePath \$dst[^;]*-Wait'; ck "[6] 설치기를 한도 없이 기다리지 않는다" $? "-Wait 로 되돌아갔다"
codegrep "$PS" 'WaitForExit\(\$limit\)'; ck "[6] 기다리는 한도가 코드에 있다" $? "한도가 없다"
codegrep "$PS" 'HasExited -and \$p.ExitCode'; ck "[6] 아직 도는 설치기의 종료 코드를 읽지 않는다" $? "끝나지 않은 프로세스에서 ExitCode 를 읽는다"
codegrep "$PS" 'if \(\$p -and -not \$p.HasExited\)'; ck "[6] 도는 설치기 위에 또 띄우지 않는다" $? "오류만 하나 더 늘어난다"
# 죽은 스크립트는 말을 못 한다 ⇒ 안내는 설치기를 띄우기 **전에** 나가야 한다.
awk '/백신이 막았다고 하면/{a=NR} /Start-Process -FilePath \$dst/{if(!b)b=NR} END{exit !(a&&b&&a<b)}' "$PS"
ck "[6] 백신 안내가 설치기 실행보다 먼저 나온다" $? "종료당하면 뒤에 적은 말은 나오지 못한다"
codegrep "$PS" '백신이 막았다고 하면 그 화면을 사진으로 남겨 주십시오 — 이름, 대상 파일, 조치'
ck "[6] 사진에 담을 것 세 가지를 말한다" $? "이름만 물으면 조치를 모른다"
codegrep "$PS" '백신이 격리했을 수 있습니다'; ck "[5] 격리 문구가 까닭을 말한다" $? "-"
codegrep "$PS" '조치\(차단·격리·삭제\) 세 가지를 알려 주십시오'; ck "[5] 격리 때도 세 가지를 묻는다" $? "-"
codegrep "$PS" '대신 예외로 등록하지 않습니다'; ck "[6] 우리가 백신 예외를 대신 등록하지 않는다고 말한다" $? "-"
# 우회 3종이 코드에 들어오는 것을 막는다(들어오면 이 축이 적색)
no_code "$PS" 'AmsiUtils|EncodedCommand|Add-MpPreference|ExclusionPath'; ck "[6] 백신 우회 장치가 없다" $? "우회 코드가 들어왔다"
no_code "$RESET" 'AmsiUtils|EncodedCommand|Add-MpPreference|ExclusionPath'; ck "[6] reset 에도 없다" $? "같음"
codegrep "$PS" '받은 파일이 사라졌습니다'; ck "[5] 받은 파일이 사라진 것을 격리로 분류한다" $? "망 문제로 오해된다"
# 종료당한 실행이 남기는 유일한 것 = 기록 파일의 마지막 줄
codegrep "$PS" 'Get-Content \$LogFile -ErrorAction'; ck "[재실행] 지난 실행의 마지막 줄을 떠 둔다" $? "기록 파일을 읽지 않는다"
awk '/Get-Content \$LogFile -ErrorAction/{a=NR} /^function Write-Log/{b=NR} END{exit !(a&&b&&a<b)}' "$PS"
ck "[재실행] 그 블록이 기록 함수보다 앞에 있다" $? "이번 실행이 적은 줄을 지난 꼬리로 읽는다"
# ⚠줄머리 고정(^)을 풀었다 — 본문이 try/finally 로 감싸여 들여쓰기가 생겼기 때문이다.
#   이 축이 재는 것은 **순서**이지 들여쓰기가 아니다(들여쓰기로 붉어지면 축이 딴 것을 재는 것이다).
awk '/\$script:PrevTail = /{if(!a)a=NR} /^[[:space:]]*Say "=== /{b=NR} END{exit !(a&&b&&a<b)}' "$PS"
ck "[재실행] 이번 실행이 적기 전에 떠 둔다" $? "이번 실행의 첫 줄을 지난 꼬리로 읽는다"
awk '/^[[:space:]]*Say "=== /{a=NR} /^[[:space:]]*Show-PrevRunNote/{b=NR} END{exit !(a&&b&&a<b)}' "$PS"
ck "[재실행] 배너 다음에 그 진단을 보여 준다" $? "함수만 있고 부르지 않는다"
codegrep "$PS" '이어서 진행합니다'; ck "[재실행] 다시 돌려도 안전하다고 말한다" $? "사람이 처음부터 다시 하는 줄 안다"
if [ -f "$RESET" ]; then
  #   앞 판은 param 줄을 통째로 문자열 대조했다. 스위치가 늘면 그 자리가 깨진다 —
  #   재는 성질은 「옛 방식이 **스위치로만** 켜진다」이므로 그것만 본다.
  #   🔴교차 검토 지적(2026-09-08): 선언만 보면 본문에서 분기 조건을 지워도 녹색이다.
  #   ⇒ 선언 **그리고** 제거기 실행이 그 스위치 조건 안에 있는지 함께 본다.
  codegrep "$RESET" '\[switch\]\$UseUninstaller' \
    && codegrep "$RESET" 'Test-Path \$UninstExe\) -and \$UseUninstaller'
  ck "[⑥] 옛 방식은 옵션으로만 남는다" $? "선언만 남고 분기가 사라졌다"
  awk '/\$UseUninstaller/{if(!a)a=NR} /Start-Process -FilePath \$UninstExe/{if(!b)b=NR} END{exit !(a&&b&&a<b)}' "$RESET"
  ck "[⑥] 기본은 제거 프로그램을 직접 띄우지 않는다" $? "기본 갈래가 백신에 종료당하는 그 행위를 한다"
  codegrep "$RESET" '설정 > 앱'; ck "[⑥] 정식 제거 경로를 알려 준다" $? "사람이 어디서 지울지 모른다"
  no_code "$RESET" 'Start-Process -FilePath \$UninstExe[^;]*-Wait'; ck "[⑥] 제거도 한도 없이 기다리지 않는다" $? "-Wait 로 되돌아갔다"
  codegrep "$RESET" 'WaitForExit\(180000\)'; ck "[⑥] 그 한도가 코드에 있다" $? "한도가 없다"
  codegrep "$RESET" '백신이 그 파일을 붙들고'; ck "[⑥] 남은 까닭에 백신을 함께 적는다" $? "돌고 있어서라고만 적으면 오진한다"
fi
# 죽은 스크립트가 말할 수 없는 것은 문서에 있어야 한다
if [ -n "$SHEET" ]; then
  grep -q '백신이 PowerShell 자체를 종료' "$SHEET"; ck "[문서] 1쪽이 창이 사라지는 까닭을 적는다" $? "화면에 못 적는 것을 종이에도 안 적었다"
  grep -q '조치(차단·격리·종료)' "$SHEET"; ck "[문서] 1쪽이 사진 세 요소를 적는다" $? "-"
fi
if [ -n "$SCORE" ]; then
  grep -q '환경이 강제한 추가 손' "$SCORE"; ck "[문서] 채점표에 벤더 강제 별칸이 있다" $? "자동화 척도에 벤더 강제가 섞인다"
  grep -q 'Execution/MDP.Powershell.M1201' "$SCORE"; ck "[문서] 진단명을 그대로 적는다" $? "재현 여부를 대조할 기준이 없다"
  grep -q '우회 금지 3종' "$SCORE"; ck "[문서] 하지 않는 것을 적는다" $? "다음 사람이 우회를 시도한다"
  grep -q '설정 > 앱 > 설치된 앱' "$SCORE"; ck "[문서] 채점표의 지우기 절차가 바뀐 갈래를 따른다" $? "문서와 스크립트가 갈라진다"
else
  sk "[문서] 채점표 축" "파일 없음"
fi

echo "== 바깥 프로그램에 넘기는 인자 (2026-09-05 실측 · 우리말이 들어가면 거절당한다) =="
# 받는 쪽은 인자를 바이트로 읽는다 — 우리말이 섞이면 깨진 글자로 보고 「알 수 없는 인자」라며 거절한다.
# 그래서 이 줄들에는 ASCII 밖의 바이트가 하나도 없어야 한다.
nonascii() { # nonascii <파일> <줄 고르는 패턴>  — 고른 줄에 ASCII 밖 바이트가 몇 개인가
  grep "$2" "$1" | LC_ALL=C tr -d '\000-\177' | wc -c | tr -d ' '
}
n=$(nonascii "$PS" 'new-surface'); [ "${n:-1}" -eq 0 ]; ck "[9] ps1 창 여는 명령줄이 ASCII 뿐" $? "우리말 ${n}바이트 — 받는 쪽이 거절한다"
n=$(nonascii "$SH" 'new-surface'); [ "${n:-1}" -eq 0 ]; ck "[9] sh 도 같음" $? "우리말 ${n}바이트"
n=$(nonascii "$PS" 'firstPrompt = '); [ "${n:-1}" -eq 0 ]; ck "[9] ps1 첫 지시문이 ASCII 뿐" $? "우리말 ${n}바이트 — 열려도 지시가 깨진다"
n=$(nonascii "$SH" 'first_prompt='); [ "${n:-1}" -eq 0 ]; ck "[9] sh 첫 지시문이 ASCII 뿐" $? "우리말 ${n}바이트"
codegrep "$PS" "surfaceTitle = 'jarvis'"; ck "[9] ps1 창 이름이 ASCII" $? "이 이름이 거절당한 자리다"
codegrep "$SH" '\-\-title "jarvis"'; ck "[9] sh 창 이름이 ASCII" $? "같음"
# 우리말 문장은 인자가 아니라 지침 파일로 간다 — 그 파일은 자비스가 직접 읽는다.
codegrep "$PS" 'Read the file \$DirectiveFile'; ck "[9] 우리말은 지침 파일로 보낸다" $? "-"
codegrep "$SH" 'Read the file \$\{DIRECTIVE_FILE\}'; ck "[9] sh 도 같음" $? "-"
# 화면에 쓰는 글자와 바깥 출력을 받는 글자는 서로 다른 설정이다 — 한쪽만 맞추면 기록만 깨진다.
codegrep "$PS" '^\$OutputEncoding = '; ck "[기록] 바깥 출력 받는 글자도 UTF-8" $? "화면은 멀쩡한데 기록이 깨진다"
# 맥 동등 — 못 연 까닭과 사람이 칠 한 줄이 윈도우에만 있었다(2026-09-05 적발)
codegrep "$SH" '프로그램이 답한 내용은 이렇습니다'; ck "[9] sh 도 못 연 까닭을 남긴다" $? "다음에도 원인을 모른다"
codegrep "$SH" 'cys 를 열고 그 안에서 아래 한 줄을'; ck "[9] sh 도 사람이 칠 한 줄을 인쇄한다" $? "폴백이 한 갈래뿐이다"

echo "== 여는 명령 (2026-09-05 두 번 실측 · 문장을 인자로 실으면 조각난다) =="
# 1차 = 우리말이 깨져 거절 · 2차 = 명령 안 따옴표가 벗겨져 조각 하나가 위치 인자로 갔다.
# ⇒ 여는 명령은 파일 하나만 가리킨다. 그 줄에 따옴표가 있으면 같은 사고가 다시 난다.
codegrep "$PS" '\$cmd = "powershell -ExecutionPolicy Bypass -File \$wakeArg"'; ck "[9] 여는 명령은 파일 하나만 가리킨다" $? "문장을 다시 인자로 실었다"
count_from_or_fail '\\"' -- grep '\$cmd = "powershell' "$PS"; rc=$?
[ "$rc" -eq 0 ] && { [ "$COUNT_N" -eq 0 ]; rc=$?; }
ck "[9] 그 줄에 따옴표가 없다" "$rc" "$(why_or_count) — 벗겨질 따옴표가 다시 들어왔다"
codegrep "$PS" 'UTF8Encoding\(\$true\)'; ck "[9] 여는 파일은 BOM 을 붙여 쓴다" $? "5.1 이 우리말을 깨뜨린다"
codegrep "$PS" 'ShortPath'; ck "[9] 경로에 빈칸이 있으면 짧은 이름을 쓴다" $? "빈칸에서 명령이 조각난다"
awk '/if \(\(\$wakeArg -match . .\) -or -not \(Test-Path \$wakeFile\)\)/{a=NR} /new-surface --role master/{b=NR} END{exit !(a&&b&&a<b)}' "$PS"
ck "[9] 못 쓸 경로면 보내기 전에 멈춘다" $? "조각난 명령을 보내 원인이 한 겹 늘어난다"
codegrep "$SH" 'wake_file='; ck "[9] sh 도 파일로 연다" $? "맥만 옛 방식이다"
codegrep "$SH" 'cmd_line="bash \$wake_file"'; ck "[9] sh 여는 명령도 파일 하나뿐" $? "-"
# 큰 화면 권유 질문 — 키를 미리 크게 적어 두면 안 묻는다(실측 근거 = 그 값이 3인 기계에서 안 떴다)
codegrep "$PS" 'fullscreenUpsellSeenCount -NotePropertyValue 99'; ck "[4] 큰 화면 권유 질문을 미리 넘긴다" $? "사람 손이 하나 더 든다"
codegrep "$SH" 'plutil -replace fullscreenUpsellSeenCount -integer 99'; ck "[4] sh 도 같음(있으면 고쳐 쓴다)" $? "맥만 질문이 뜬다"
codegrep "$SH" 'plutil -insert fullscreenUpsellSeenCount -integer 99'; ck "[4] sh 키가 없을 때도 넣는다" $? "새 기계에서 안 걸린다"

echo "== 자리 복원 플래그 (2026-09-09 신설 · 껐다 켠 뒤 자비스가 스스로 돌아오는가) =="
# 무엇을 재는가: 자리를 열 때 「여기서 무엇을 띄우는지」를 적어 두는 칸을 **있는 판본에만** 붙이는가.
#   ⚠판본에 따라 그 칸이 없다 — 조건 없이 붙이면 그 기계에서는 자리가 아예 안 열린다(2026-09-04 실측: 0.14.29).
#   ⇒ 이 축이 재는 것은 「붙인다」가 아니라 **「물어보고 붙인다」**이다.
codegrep "$SH" 'new-surface --help'; ck "[9] sh 능력 프로브가 --help 기반" $? "판본 숫자로 재면 다음 판본에서 곧 낡는다"
# ⚠ps1 은 인자를 배열로 넘긴다(데몬을 안 깨우는 감싸개를 지나므로) — 같은 물음, 다른 모양이다.
codegrep "$PS" "'new-surface', '--help'"; ck "[9] ps1 능력 프로브도 --help 기반" $? "판본 숫자로 재면 다음 판본에서 곧 낡는다"
codegrep "$SH" 'log "cys new-surface --agent supported'; ck "[9] sh 판정을 기록에 남긴다" $? "왜 안 붙였는지 나중에 모른다"
codegrep "$PS" 'Write-Log "cys new-surface --agent supported'; ck "[9] ps1 도 같음" $? "같음"
codegrep "$SH" 'if cys_supports_agent_flag; then'; ck "[9] sh 가 판정을 실제로 부른다" $? "판정해 놓고 안 쓴다"
codegrep "$PS" 'if \(Test-CysAgentFlag\)'; ck "[9] ps1 도 같음" $? "같음"
# ★갈래가 둘 다 있어야 한다. 하나뿐이면 「조건 없이 붙인다」거나 「아예 안 붙인다」 둘 중 하나다.
n=$(grep -c 'new-surface --role master' "$SH"); m=$(grep -c 'new-surface --role master.*--agent claude' "$SH")
[ "${n:-0}" -eq 2 ] && [ "${m:-0}" -eq 1 ]; ck "[9] sh 여는 갈래가 둘(붙임 1 · 안 붙임 1)" $? "갈래 ${n}개 · 붙임 ${m}개 — 조건부 전달이 아니다"
n=$(grep -c 'new-surface --role master' "$PS"); m=$(grep -c 'new-surface --role master.*--agent claude' "$PS")
[ "${n:-0}" -eq 2 ] && [ "${m:-0}" -eq 1 ]; ck "[9] ps1 여는 갈래가 둘" $? "갈래 ${n}개 · 붙임 ${m}개 — 조건부 전달이 아니다"
# 사람이 받는 마지막 요약에 그 답이 적히는가 — 「이 컴퓨터에서 무엇이 되는가」는 화면 밖에서 알 길이 없다.
codegrep "$SH" "row \"2-9\" \"master 좌석 복원 플래그\""; ck "[요약] sh 진단에 복원 플래그 행" $? "사람이 되는지 안 되는지 모른다"
codegrep "$PS" "Add-Row '2-9' 'master 좌석 복원 플래그'"; ck "[요약] ps1 도 같음" $? "같음"
codegrep "$SH" '미지원\(\$\(cys_version_line\)\)'; ck "[요약] sh 미지원일 때 판본을 함께 적는다" $? "무엇이 낡았는지 안 적힌다"
codegrep "$PS" '미지원\(\$\(Get-CysVersionLine\)\)'; ck "[요약] ps1 도 같음" $? "같음"
# 시험이 「실제로 무엇을 넘겼는가」를 재려면 이 파일을 함수 묶음으로 읽을 길이 있어야 한다.
# 글자 세기로는 못 잰다 — 조건 갈래 양쪽이 파일에 다 적혀 있기 때문이다.
codegrep "$SH" 'JARVIS_LIB_ONLY'; ck "[시험] sh 를 함수 묶음으로 읽는 문이 있다" $? "뮤턴트가 전달 횟수를 잴 수 없다"

echo "== [2/10] 백신이 붙들었을 때 (2026-09-09 실사용자 3호 실기 수정) =="
# 그 기계에서 무슨 일이 났나: 클로드 설치기가 백신 창(클라우드 자동 분석 요청)에 붙들려 멈췄는데
#   화면에는 아무 말도 없었다. 창은 살아 있었고 사람은 11분을 기다렸다.
#   ⇒ 이 축이 재는 것 셋 = ①기다리는 동안 말을 하는가 ②끝이 있는 기다림인가 ③넘겼을 때 조용히 넘어가지 않는가.
codegrep "$PS" 'ClaudeInstallWaitMs  ='; ck "[2] 클로드 설치에 상한이 있다" $? "한도 없이 기다리면 백신 창 하나에 영원히 선다"
codegrep "$PS" 'InstallNoteEverySec'; ck "[2] 기다리는 동안 주기적으로 말한다" $? "사람은 멈춘 화면만 보고 무엇을 누를지 모른다"
codegrep "$PS" 'Start-Process -FilePath \$psExe'; ck "[2] 설치기를 지켜볼 수 있게 띄운다" $? "부르고 그냥 기다리면 상한도 안내도 걸 자리가 없다"
no_code "$PS" '& \$psExe -NoProfile -Command'; ck "[2] 한도 없는 옛 호출이 남아 있지 않다" $? "옛 호출로 되돌아갔다"
# ★상한을 넘겼는데 0 을 돌려주면 조용히 다음 단계로 간다 — 그 자리가 이 사고의 핵심이다.
# ⚠창을 넓게 잡으면 안 된다 — 바로 아래 「설치기 종료 코드가 0 이 아니다」 갈래에도 return 4 가 있어서,
#   이 자리를 0 으로 바꿔도 그 줄이 대신 잡혀 초록이 된다(이 축을 처음 쓴 날 실제로 그렇게 살아남았다).
#   ⇒ 안내 문장 **바로 다음 줄**만 본다.
# ⚠창을 「바로 다음 줄」로 못박았더니, 안내 뒤에 다음 행동 한 줄을 넣는 정당한 변경에 붉어졌다.
#   ⇒ 창은 3줄로 넓히되 **그 창에 return 0 이 있으면 실격**으로 둔다 — 넓힌 창으로 뮤턴트가 새지 않는다.
awk '/Say-AntivirusHold .클로드 설치 파일/{a=NR}
     a&&NR>a&&NR<=a+3&&/return 0/{bad=1}
     a&&NR>a&&NR<=a+3&&/return [1-9]/{ok=1}
     END{exit !(ok&&!bad)}' "$PS"
ck "[2] 상한 초과는 비영으로 끝난다" $? "0 을 돌려주면 설치가 안 된 채 다음 단계로 조용히 넘어간다"
# 같은 사고인데 문장이 갈리면 사람은 두 가지 다른 일로 배운다 — 한 자리에서만 만든다.
codegrep "$PS" 'function Say-AntivirusHold'; ck "[2] 백신 안내 문장이 한 자리에 있다" $? "문장이 갈린다"
n=$(grep -c 'Say-AntivirusHold ' "$PS"); [ "${n:-0}" -ge 2 ]
ck "[2·5] 그 문장을 두 자리에서 쓴다(설치 대기·받은 파일 사라짐)" $? "호출 ${n}곳 — 격리 자리가 옛 문장 그대로다"
codegrep "$PS" '파일 전송'; ck "[2] 무엇을 눌러야 하는지 적는다" $? "백신 창 이름만 말하면 사람은 무엇을 누를지 모른다"
# ★못 읽은 종료 코드를 0(성공)으로 덮으면 **실패를 우리가 삼킨다** — 러너 실측으로 잡힌 자리다
#   (2026-09-09 · 설치기가 오류로 죽었는데 화면에는 「종료 코드: 0」이 나갔다 · run 34289192025 ↔ 34271220513 대조).
no_code "$PS" 'null -eq \$p.ExitCode\) \{ 0 \}'; ck "[2] 못 읽은 종료 코드를 0 으로 덮지 않는다" $? "실패 코드를 삼켜 성공한 것처럼 적는다"
codegrep "$PS" '종료 코드를 읽지 못했습니다'; ck "[2] 못 읽었으면 못 읽었다고 적는다" $? "빈칸과 0 을 구분하지 못한다"
# ⛔우회는 여전히 금지다(이 작업이 그 규율을 흔들지 않았는지 다시 잰다).
no_code "$PS" 'AmsiUtils|EncodedCommand|Add-MpPreference|ExclusionPath'; ck "[2] 백신 우회·예외 등록 0건" $? "우회 장치가 들어왔다"

echo "== 멈추지 않는 설치기 (2026-09-09 · 연결 대기·정직 실패·끝맺음) =="
# 무엇을 재는가: 못 나가는 단계에서 ①말을 하는가 ②원인을 갈라 말하는가 ③끝이 있는가
#   ④끝에서 다음에 할 일이 남는가. 셋째까지만 있으면 사람은 30분 뒤 빈 화면을 본다.
codegrep "$SH" '^wait_for_connection\(\) \{'; ck "[대기] sh 연결 대기가 한 자리에 있다" $? "단계마다 제각각 기다리면 문장도 상한도 갈라진다"
codegrep "$PS" '^function Wait-ForConnection'; ck "[대기] ps1 도 같음" $? "같음"
n=$(grep -c 'wait_for_connection "' "$SH"); [ "${n:-0}" -ge 2 ]; ck "[대기] sh 가 그 자리를 실제로 쓴다(2곳 이상)" $? "정의만 있고 아무도 안 쓴다(${n}곳)"
n=$(grep -c 'Wait-ForConnection ' "$PS"); [ "${n:-0}" -ge 1 ]; ck "[대기] ps1 도 그 자리를 쓴다" $? "정의만 있고 안 쓴다(${n}곳)"
# ★원인 3종 — 하나로 뭉뚱그리면 백신이 붙든 것과 섞여 거짓 안내가 된다(3호 실기의 교훈)
for f in "$SH" "$PS"; do
  b="$(basename "$f")"
  codegrep "$f" '인터넷 연결이 없어서';               ck "[대기] $b 원인 ①인터넷 없음" $? "원인을 못 가른다"
  codegrep "$f" '우리 서버가 응답하지 않아서';        ck "[대기] $b 원인 ②우리 서버" $? "원인을 못 가른다"
  codegrep "$f" '바깥 서버가 응답하지 않아서';        ck "[대기] $b 원인 ③바깥 서버" $? "원인을 못 가른다"
done
# ⚠부정형 축은 **코드 줄만** 봐야 한다 — 이 축을 처음 쓴 날 「뭉뚱그리지 마라」는 우리 경고 주석 자신을
#   잡아 적색을 냈다(이 파일이 이미 세 번 겪은 자리다). codegrep 이 주석을 뺀다.
# ★「닿았는가」와 「2xx 인가」는 다른 질문이다 — 러너에서 우리 주소가 403 을 주자 앞 판은
#   멀쩡한 서버를 「응답 없음」이라 말했다(run 34292566443 실측). 답이 오면 닿은 것이다.
codegrep "$PS" 'if \(\$_\.Exception\.Response\) \{ return \$true \}'; ck "[대기] ps1 프로브가 상태코드로 닿음을 부정하지 않는다" $? "403·404 를 「응답 없음」으로 읽어 거짓 안내를 한다"
no_code "$SH" 'curl -sS -m 6 -f'; ck "[대기] sh 프로브도 상태코드를 게이트로 안 쓴다" $? "-f 가 붙으면 맥도 같은 거짓 안내를 한다"
no_code "$SH" '서버 사정'; ck "[대기] sh 에 「서버 사정」 뭉뚱그림 0(코드 줄)" $? "한 문장으로 뭉뚱그렸다"
no_code "$PS" '서버 사정'; ck "[대기] ps1 도 같음" $? "같음"
# 운영자 문안이 그대로 있는가 — 이 두 줄이 「기다려도 된다」를 사람에게 알리는 전부다
codegrep "$SH" '창을 닫지 말고 기다려 주십시오'; ck "[대기] sh 기다려도 된다고 말한다" $? "사람이 창을 닫는다"
codegrep "$PS" '창을 닫지 말고 기다려 주십시오'; ck "[대기] ps1 도 같음" $? "같음"
# 상한이 있고, 넘기면 조용히 지나가지 않는다
codegrep "$SH" 'NET_WAIT_TIMEOUT=1800'; ck "[대기] sh 상한 30분이 코드에 있다" $? "끝없이 기다린다"
codegrep "$PS" 'NetWaitTimeoutSec   = 1800'; ck "[대기] ps1 도 같음" $? "같음"
awk '/분을 기다렸지만 연결되지 않았습니다/{a=NR} a&&NR>a&&NR<=a+3&&/return 0/{bad=1} a&&NR>a&&NR<=a+3&&/return 1/{ok=1} END{exit !(ok&&!bad)}' "$SH"
ck "[대기] sh 상한 초과는 비영으로 끝난다" $? "기다리다 만 것을 성공으로 돌려준다"
awk '/분을 기다렸지만 연결되지 않았습니다/{a=NR} a&&NR>a&&NR<=a+3&&/return \$true/{bad=1} a&&NR>a&&NR<=a+3&&/return \$false/{ok=1} END{exit !(ok&&!bad)}' "$PS"
ck "[대기] ps1 상한 초과는 거짓으로 끝난다" $? "기다리다 만 것을 성공으로 돌려준다"

echo "== 끝맺음 — 어느 끝에서도 다음에 할 일이 남는다 =="
# ★기억이 아니라 구조로 강제한다: 맥은 EXIT 트랩 · 윈은 try/finally. 모양은 다르고 보증은 같다.
codegrep "$SH" "trap 'closing_note; rm -f"; ck "[끝] sh 끝맺음이 트랩에 매달려 있다" $? "종료 자리를 새로 만들 때마다 기억해야 한다"
codegrep "$PS" 'Write-ClosingNote'; ck "[끝] ps1 끝맺음 함수가 있다" $? "같음"
awk '/^\} finally \{/{a=NR} a&&NR>a&&NR<=a+3&&/Write-ClosingNote/{ok=1} END{exit !ok}' "$PS"
ck "[끝] ps1 본문이 finally 로 그것을 보증한다" $? "함수만 있고 어떤 끝에서는 안 불린다"
codegrep "$SH" '다음에 할 일: '; ck "[끝] sh 다음에 할 일 한 줄" $? "끝났는데 무엇을 할지 안 적힌다"
codegrep "$PS" '다음에 할 일: '; ck "[끝] ps1 도 같음" $? "같음"
codegrep "$SH" '막히면 이 두 파일을 보내 주십시오'; ck "[끝] sh 회수 경로 한 줄" $? "무엇을 보내야 하는지 모른다"
codegrep "$PS" '막히면 이 두 파일을 보내 주십시오'; ck "[끝] ps1 도 같음" $? "같음"
codegrep "$SH" '여는 법: '; ck "[끝] sh 여는 법까지 적는다" $? "파일 자리만 알려 주면 못 연다"
codegrep "$PS" '여는 법: '; ck "[끝] ps1 도 같음" $? "같음"

echo "== 진단 코드 (J-<축>-<두 자리>) =="
codegrep "$SH" '^jcode\(\) \{'; ck "[코드] sh 코드 남기는 자리가 하나" $? "자리마다 다른 모양으로 적는다"
codegrep "$PS" '^function Write-JCode'; ck "[코드] ps1 도 같음" $? "같음"
codegrep "$SH" '진단 코드: \$J_CODE'; ck "[코드] sh 환경 보고에도 같은 문자열" $? "화면과 보고서가 갈린다"
codegrep "$PS" '진단 코드: \*\*\$\(\$script:JCode\)'; ck "[코드] ps1 도 같음" $? "같음"
codegrep "$SH" 'log "jcode '; ck "[코드] sh 기록 파일에도 남긴다" $? "세 자리 중 하나가 빈다"
codegrep "$PS" "Write-Log \(.jcode"; ck "[코드] ps1 도 같음" $? "같음"
if [ -f "$DIR/../tests/help-rules-check.py" ]; then
  python3 "$DIR/../tests/help-rules-check.py" --dir "$DIR" --docs "$DIR/../docs/help-codes.md" >/dev/null 2>&1
  ck "[코드] 표·설치기·안내 문서가 같은 집합" $? "셋 중 하나가 갈라졌다 (python3 tests/help-rules-check.py 로 자세히)"
fi

echo "== 반복해서 막힐 때 단계별 안내 (2026-09-12 · v0.3.15) =="
# 같은 문구만 되풀이하면 사람은 막힌 채 짜증이 난다 — 2회째는 공감과 다른 방법, 3회째부터는 담당자와 직접 이야기.
#   문구의 정본은 tests/help-escalation.tsv 하나다. 설치 창(두 설치기)·도움말 문서가 그 줄을 글자 그대로 품는지 잰다.
#   ⚠어느 코드에 어느 줄이 붙는지·몇 회째에 무엇이 나오는지는 실행 시험(tests/help-attempts-run.sh · .ps1)이 잰다.
if [ -f "$DIR/../tests/help-escalation-check.py" ] && [ -f "$DIR/../tests/help-escalation.tsv" ]; then
  python3 "$DIR/../tests/help-escalation-check.py" tsv --root "$DIR/.." >/dev/null 2>&1
  ck "[반복] 모든 진단 코드에 두 번째 방법 또는 곧바로 연락이 있다" $? "어떤 코드는 두 번째에도 같은 말만 한다"
  python3 "$DIR/../tests/help-escalation-check.py" sh --root "$DIR/.." >/dev/null 2>&1
  ck "[반복] sh 설치 창 문구가 정본과 같다" $? "화면이 정본과 갈렸다 (python3 tests/help-escalation-check.py sh 로 자세히)"
  python3 "$DIR/../tests/help-escalation-check.py" ps1 --root "$DIR/.." >/dev/null 2>&1
  ck "[반복] ps1 설치 창 문구가 정본과 같다" $? "화면이 정본과 갈렸다 (python3 tests/help-escalation-check.py ps1 로 자세히)"
  python3 "$DIR/../tests/help-escalation-check.py" docs --root "$DIR/.." >/dev/null 2>&1
  ck "[반복] 도움말 문서 「계속 막히시면」 절이 정본과 같다" $? "설치 창과 도움말이 다른 방법을 말한다"
  python3 "$DIR/../tests/help-escalation-check.py" phone --root "$DIR/.." >/dev/null 2>&1
  ck "[반복] 담당자 번호는 설치기마다 상수 한 곳" $? "번호가 여러 곳에 흩어져 바뀔 때 한 곳이 남는다"
  python3 "$DIR/../tests/help-escalation-check.py" width --root "$DIR/.." >/dev/null 2>&1
  ck "[반복] 새 화면 줄이 80칸 이하" $? "좁은 창에서 줄이 잘려 읽기 어렵다"
else
  sk "[반복] 단계별 안내 문구 검사" "정본 또는 검사기가 이 디렉터리에 없다"
fi

echo "== 등록 안 된 잔재 (2026-09-09 · 사람이 할 수 없는 일을 요구하지 않는다) =="
# 그 기계 상태 = cys 폴더 있음 · 설치 목록 항목 없음. 설정 앱은 그 항목을 보므로 cys 가 안 보인다.
#   앞 판은 판별이 「uninstall.exe 가 있는가」 하나뿐이라 설정 앱 제거를 8번 요구했고 사람은 q 로 나왔다.
#   ⇒ 요구하기 전에 그 항목이 실제로 있는지 본다. 없으면 우리가 지운다.
codegrep "$RESET" 'hasRegEntry = Test-Path \$RegKey'; ck "[⑥] 판별 2축 — 등록 항목을 따로 본다" $? "폴더 하나로 판별하면 설정 앱을 못 쓰는 기계에서 교착이 난다"
codegrep "$RESET" 'Test-Path \$UninstExe\) -and \$hasRegEntry'; ck "[⑥] 설정 앱 요구는 항목이 있을 때만" $? "항목이 없는데 설정 앱에서 지우라고 한다(사람이 할 수 없다)"
codegrep "$RESET" 'Test-Path \$CysDir\) -or \(Test-Path \$CysDirOld'; ck "[⑥] 등록 없는 잔재 갈래가 있다" $? "그 상태에서 아무도 폴더를 지우지 않는다"
codegrep "$RESET" '아직 실행 중이라'; ck "[⑥] 지우기 전에 돌고 있는지 본다" $? "돌고 있으면 폴더가 안 지워지는데 지웠다고 적는다"
codegrep "$RESET" 'alive = @\(Stop-CysProcesses\)'; ck "[⑥] 그 확인이 실측이다" $? "멈추라고만 하고 확인하지 않는다"
# 🔴2026-09-10 재조준 — 앞 판은 `alive = @(foreach` 를 쟀다. 그 형태는 **이름 세 개를 다시 세는 것**이라
#   자리 기준으로 고친 순간 적색이 됐다. 재는 성질은 「끈 뒤에 다시 세는가」이므로 새 함수 이름으로 잰다.
#   ⇒ 아래 「자리 기준 종료」 축이 이름 축만으로 되돌리는 뮤턴트를 잡는다.
# ★반복 요구 고리는 설정 앱 갈래에만 있어야 한다 — 새 갈래는 한 번만 묻는다.
n=$(grep -c 'while (Test-Path \$UninstExe)' "$RESET"); [ "${n:-0}" -eq 1 ]
ck "[⑥] 반복 요구 고리가 하나뿐" $? "고리 ${n}개 — 새 갈래에도 반복 요구가 생겼다"
awk '/hasRegEntry = Test-Path/{a=NR} /while \(Test-Path \$UninstExe\)/{b=NR} END{exit !(a&&b&&a<b)}' "$RESET"
ck "[⑥] 항목 확인이 요구보다 먼저 온다" $? "요구한 뒤에 확인하면 이미 사람을 붙잡아 둔 뒤다"
codegrep "$RESET" 'Get-StartMenuLinks'; ck "[⑥] 시작 메뉴 바로가기도 함께 본다" $? "우리가 폴더를 지우는 길에서는 고아가 남는다"
codegrep "$RESET" '\[없음\] cys 시작 메뉴 바로가기'; ck "[⑥] 없으면 없다고 적는다" $? "빈칸과 없음을 구분하지 못한다"
# 맥 대칭 — 맥에는 설정 앱 같은 관문이 없다(레지스트리가 없다). 그래서 맥은 처음부터 제 손으로 지운다.
#   대칭의 뜻 = 「같은 코드」가 아니라 **「사람에게 할 수 없는 일을 요구하지 않는다」가 두 OS 다 성립**하는 것.
# ★프로그램을 남기기로 한 실행에서 목록 항목만 지우면, 우리가 가리킨 그 길을 우리가 없앤다
#   (= 다음 실행에서 폴더만 남은 교착 상태를 우리 손으로 만든다).
codegrep "$RESET" 'if \(\$script:SkipCysDir -and \$hasRegEntry\)'; ck "[⑥] 프로그램을 남기면 목록 항목도 남긴다" $? "설정 앱에서 cys 가 사라져 사람이 끝낼 길이 없어진다"
# ★남긴다는 말은 설정 앱에서 마저 지울 수 있을 때만 참이다 — 항목이 없으면 그 문장을 적지 않는다.
codegrep "$RESET" '남김: cys 설치 목록 항목'; ck "[⑥] 남길 때는 남긴다고 적는다" $? "말없이 남기면 사람은 지워진 줄 안다"
# 시험 입구는 살아 있는 기계에서 시작 자체를 거절해야 한다 — 환경변수로 격리되지 않는 자리가 셋 있다
#   (레지스트리 항목 · 작업 스케줄러 등록 · 사용자 Path). 그중 앞의 둘을 입구에서 거절 판정으로 막는다.
if [ -f "$DIR/../tests/win-stale-cys-run.ps1" ]; then
  STALE="$DIR/../tests/win-stale-cys-run.ps1"
  grep -q 'Get-ScheduledTask' "$STALE"; ck "[시험] 윈 입구가 스케줄러 등록을 보고 거절한다" $? "살아 있는 기계에서 남의 등록이 풀린다"
  n=$(grep -c 'exit 4' "$STALE"); [ "${n:-0}" -ge 3 ]; ck "[시험] 거절 판정이 셋 이상" $? "거절 ${n}개 — 진짜 설치를 못 알아본다"
fi
codegrep "$RESET_SH" 'drop_dir "\$CYS_APP"'; ck "[⑥] 맥은 프로그램을 제 손으로 지운다" $? "맥도 사람에게 떠넘기고 있다"
awk '/pkill -f .cys/{a=NR} /drop_dir "\$CYS_APP"/{b=NR} END{exit !(a&&b&&a<b)}' "$RESET_SH"
ck "[⑥] 맥도 지우기 전에 돌던 것을 멈춘다" $? "돌고 있는 것을 지우려 든다"

echo "== [10] 첫 함대 · 자비스 전용 설정 자리 (2026-09-05 실측 수정) =="
# 동료 노드는 개인 설정이 아니라 자비스 전용 설정으로 뜬다 — 한 자리만 심으면 동료가 질문 앞에 선다.
codegrep "$PS" "Join-Path .*'.cys'.*'claude'"; ck "[4] ps1 이 전용 설정 자리를 함께 본다" $? "동료들이 첫 실행 질문에서 멈춘다"
count_from_or_fail '\[ -d "\$HOME/.cys/claude" \]' -- grep -vE '^[[:space:]]*#' "$SH"; rc=$?
[ "$rc" -eq 0 ] && { [ "$COUNT_N" -ge 2 ]; rc=$?; }
ck "[4] sh 도 같음(구성·설정 두 자리)" "$rc" "$(why_or_count) — 한 자리만 심으면 나머지 질문이 그대로 남는다"
codegrep "$PS" 'if \(Test-Path \$iso\)'; ck "[4] 없는 자리는 만들지 않는다" $? "짐작한 자리에 파일을 만든다"
count_from_or_fail 'Set-AllProfiles | Out-Null' -- grep -vE '^[[:space:]]*#' "$PS"; rc=$?
[ "$rc" -eq 0 ] && { [ "$COUNT_N" -ge 2 ]; rc=$?; }
ck "[8] 자리를 잡은 뒤 한 번 더 심는다" "$rc" "$(why_or_count) — 전용 자리는 [8] 뒤에야 생긴다 · 한 번만 심으면 못 심는다"
codegrep "$SH" 'seed_all_profiles'; ck "[8] sh 도 두 번 심는다" $? "같음"
# 글자 모양 질문의 열쇠는 .claude.json 이 아니라 settings.json 에 있다(맥 실물 대조)
codegrep "$PS" "NotePropertyName theme"; ck "[4] 글자 모양 질문을 미리 넘긴다" $? "동료가 「Choose the text style」에서 선다"
codegrep "$SH" 'plutil -replace theme'; ck "[4] sh 도 같음" $? "같음"
# [10] — 트리거는 인자가 아니라 사람이 치는 길로 넣는다
# 🔴이 두 축은 방향이 뒤집혔다(2026-09-05 09:4x · 운영자 결정 B).
#   기계가 선언을 대신 치면 자비스의 안전장치가 알아보고 거절한다 — 그 장치는 옳고, 우리가 뚫지 않는다.
#   그러므로 재는 것은 「보내는가」가 아니라 **「보내지 않는가」**다.
no_code "$PS" 'send .*(--queued|\$FleetTrigger)'; ck "[10] 선언을 기계가 대신 치지 않는다" $? "안전장치를 우회하는 길이 들어왔다"
no_code "$SH" 'send .*(--queued|\$FLEET_TRIGGER)'; ck "[10] sh 도 같음" $? "같음"
codegrep "$PS" '직접 치셔야 합니다'; ck "[10] 사람이 쳐야 한다고 말한다" $? "왜 기다리는지 모른 채 멈춰 있는 화면이 된다"
codegrep "$SH" '직접 치셔야 합니다'; ck "[10] sh 도 같음" $? "같음"
codegrep "$PS" '\$FleetWaitTries = [0-9]'; ck "[10] 기다리는 상한이 있다" $? "영원히 기다린다"
codegrep "$SH" 'FLEET_WAIT_TRIES'; ck "[10] sh 도 같음" $? "같음"
codegrep "$PS" '기다리는 중입니다'; ck "[10] 기다리는 동안 살아 있다고 말한다" $? "멈춘 것처럼 보인다"
codegrep "$SH" '기다리는 중입니다'; ck "[10] sh 도 같음" $? "같음"
# 동료들이 쓸 로그인 정보 — 없으면 넷 다 로그인 화면에서 선다(2026-09-05 실측)
codegrep "$PS" 'Copy-LoginToIsolated \| Out-Null'; ck "[8] 로그인 정보를 전용 자리로 이어 준다" $? "함수만 있고 안 부른다 — 동료 노드가 전부 로그인 화면에서 선다"
codegrep "$PS" "Join-Path .*'.claude'\) '.credentials.json'"; ck "[8] 옮기는 것은 개인 자리의 로그인 파일" $? "-"
codegrep "$PS" 'source credentials file not found'; ck "[8] 옮길 것이 없으면 그 사실을 기록한다" $? "조용히 넘어가 원인을 못 찾는다"
codegrep "$PS" "FleetRoles   = @\('master', 'cso', 'worker'\)"; ck "[10] 이 기계에서 세울 역할 3" $? "리뷰어 2 는 선택인데 결원으로 센다"
codegrep "$SH" "FLEET_ROLES='master cso worker'"; ck "[10] sh 도 같음" $? "같음"
codegrep "$PS" '아직 서지 않은 자리가 있습니다'; ck "[10] 못 선 자리 이름을 인쇄한다" $? "성공만 말하고 실패는 침묵한다"
codegrep "$SH" '아직 서지 않은 자리가 있습니다'; ck "[10] sh 도 같음" $? "같음"
codegrep "$PS" '\$live = @\(Get-LiveRoles \$cli\)'; ck "[10] 판정은 목록 실측으로 한다" $? "「보냈다」로 판정한다"
codegrep "$SH" 'live_roles'; ck "[10] sh 도 같음" $? "같음"
# 단계 수가 늘어도 지나온 단계 기록이 비지 않아야 한다(숫자 박기 금지)
codegrep "$PS" 'msg -match .\^\\\[\\d\+/\\d\+\\\]'; ck "[기록] 단계 표시를 숫자로 박지 않는다" $? "단계 수가 늘면 기록이 조용히 빈다"

echo "== 공개판 조건 (인터넷에 그대로 노출된다) =="
# 두 스크립트는 배포 사이트에서 받아 실행된다 ⇒ 내부 용어가 한 글자도 없어야 한다.
# 이 축은 **의도적으로 주석까지 센다** — 레포를 연 사람도 그 낱말을 본다.
TERMS='박사님|설치 자비스|슬라이스|미실측|T-M[0-9]|T-W[0-9]|F-W[0-9]|\bagy\b|codex|fable|봉합|§|\[master#'
# 🔴이 축은 **죽어 있었다**(2026-09-09 발견 · 내부 용어 7건을 심어도 초록이었다).
#   까닭 = `ck "… $(basename …)" $?` — `$?` 는 앞의 `[ ]` 가 아니라 **`basename` 의 성공**을 잰다
#   (인자 확장 중에 명령치환이 그 자리에서 `$?` 를 0 으로 덮는다). ⇒ rc 를 변수에 먼저 담는다.
#   ★같은 형태를 새로 쓰지 마라: `ck` 인자 안에 `$( )` 를 두려면 rc 를 그 앞에서 잡아 둔다.
#   ⚠축이 **설치기 둘만** 보고 있었다(2026-09-09 발견). 그런데 사이트가 배포하는 것은 **여섯**이다
#   (아래 「[사이트] 사본이 실물과 같다」 축이 세는 그 여섯). 제거기·재설치기도 사람이 그대로 받아 연다
#   ⇒ 같은 잣대로 잰다. 실측 당시 reset-clean.ps1 에 3 줄이 새고 있었고 아무 축도 그것을 안 봤다.
#   ⚠`|| true` 로 받지 않는다 — 읽기 오류(grep rc≥2)가 「0건」으로 삼켜진다(2차 검토 지적 채택 2026-09-09).
#   ★「못 읽었다」와 「없다」는 다른 답이다. 둘을 한 칸에 넣으면 못 읽은 날이 통과가 된다.
for f in "${INSTALL_SCRIPTS[@]}" "$RESET_SH" "$RESET"; do
  [ -f "$f" ] || { sk "[공개] $(basename "$f") 내부 용어" "그 파일이 없다"; continue; }
  fb="$(basename "$f")"
  absent_or_fail "$f" "$TERMS"; rc=$?
  ck "[공개] $fb 내부 용어 0건" "$rc" "노출 ${GREP_WHY} — 인터넷에 그대로 나간다"
done
# 참가자 화면(터미널)에 문서 관행 기호·마크다운이 나가면 경보·깨진 글자로 읽힌다
#   ⚠막는 기호 목록은 **두 OS 가 다르다** — 윈도우 `Add-Row` 는 보고서(마크다운)로 가는 줄이라
#   `**` 가 정당하다. 목록을 하나로 합치지 마라(합쳤다가 멀쩡한 보고서 문장을 적색으로 만들었다).
screen_marks() { # screen_marks <파일> <화면으로 나가는 줄> <막는 기호>
  local f="$1" pre="$2" marks="$3" out rc
  GREP_WHY=""
  out="$(grep -E "$pre" "$f" 2>/dev/null)"; rc=$?
  if [ "$rc" -ge 2 ]; then GREP_WHY="읽기 오류(grep rc=$rc)"; return 1; fi
  if printf '%s\n' "$out" | grep -qE "$marks"; then GREP_WHY="강조 기호가 있다"; return 1; fi
  return 0
}
screen_marks "$SH" '^[[:space:]]*(say|row) ' '🔴|★|⚠|⛔|\*\*'; ck "[공개] sh 화면 출력에 강조 기호·굵게 0건" $? "터미널에 별표와 빨간 원이 그대로 그려진다(${GREP_WHY})"
screen_marks "$PS" '^[[:space:]]*(Say |Add-Row )' '🔴|★|⚠|⛔'; ck "[공개] ps1 화면 출력에 강조 기호 0건" $? "같음(${GREP_WHY})"
# 고정 첫 줄은 두 OS 가 같아야 한다(기동 성공 판정에 쓴다)
h1=$(grep -o '\[자비스\] 환경 보고 v0' "$SH" | head -1); h2=$(grep -o '\[자비스\] 환경 보고 v0' "$PS" | head -1)
[ -n "$h1" ] && [ "$h1" = "$h2" ]; ck "[공개] 고정 첫 줄이 두 OS 동일" $? "판정 문자열이 갈라지면 한쪽이 기동 실패로 읽힌다"

echo "== 공통 수정 =="
grep -q 'www\.cysinsight\.com' "$SH"; ck "[7] sh 의 cys 핀 = 정본 문자열" $? "정본은 www 를 쓴다"
! grep -q 'cysinsight\.com/downloads' "$PS"; ck "[7] ps1 은 벤더 다운로드 원을 쓰지 않는다" $? "벤더 판이 남아 있다(자체 배포 전환 2026-09-09)"
grep -q 'claude.ai/install.sh' "$SH"; ck "[F] sh 설치 URL 핀" $? "핀이 없다"
grep -q 'claude.ai/install.ps1' "$PS"; ck "[F] ps1 설치 URL 핀" $? "핀이 없다"

echo "== 없는 것을 물었을 때 죽지 않는다 (2026-09-09 러너 실측) =="
# 🔴러너가 잡은 결함: 클로드가 없는 기계에서 윈도우판 미리보기가 **[2/10] 에서 멈췄다.**
#   `& claude --help` 가 「그런 명령이 없다」로 던지고, 본문 try 가 그것을 잡아 스크립트가 끝났다.
#   맥판은 같은 자리에서 안 죽는다(없는 명령 = 종료값 127) ⇒ **두 OS 가 갈리던 자리다.**
#   ★없는 것을 물으면 답은 「모른다」여야지 죽음이면 안 된다.
codegrep "$PS" 'function Test-ClaudeAuthCmd \{'
ck "[갈림] ps1 능력 확인 함수가 있다" $? "함수 자체가 사라졌다"
# ★함수 **안에서** 확인이 `& claude` 보다 먼저 오는가 — 순서가 이 축의 전부다.
awk '/^function Test-ClaudeAuthCmd/,/^}/' "$PS" \
  | awk '/Get-Command claude -ErrorAction SilentlyContinue/{g=NR} /& claude --help/{c=NR} END{exit !(g && c && g < c)}'
ck "[갈림] ps1 능력 확인이 부르기 전에 있는지 본다" $? "없는 기계에서 던지고 스크립트가 끝난다(미리보기가 [2/10] 에서 멈췄다)"
awk '/^function Step-Login/,/^}/' "$PS" | grep -q 'Get-Command claude -ErrorAction SilentlyContinue'
ck "[갈림] ps1 재판정도 부르기 전에 있는지 본다" $? "같은 자리에서 같은 이유로 죽는다"
# 미리보기 차례 축은 이 성질에 기대고 있다 — 러너가 두 OS 를 실제로 돌려 잰다.

# 🔴제거기는 **참가자 기계**에서 돈다 — 거기서 없을 수도 있는 명령에 기대면 그 자리에서 멈춘다.
#   실측(러너 2026-09-09): 사용자 폴더를 갈아 끼운 5.1 환경에서 `Get-FileHash` 를 못 찾았다.
#   이 저장소는 같은 함정을 이미 한 번 겪고 러너 주석에 적어 두었는데, 새 코드가 그것을 또 밟았다.
no_code "$RESET" 'Get-FileHash'
ck "[갈림] 윈 제거기가 Get-FileHash 에 기대지 않는다" $? "그 명령이 없는 환경에서 대조가 통째로 실패한다"
# 🔴안전 가드가 **엉뚱한 것까지 막지 않는가** — 새 방어를 넣을 때마다 물어야 하는 질문이다.
#   실측(러너 2026-09-09): 실경로 fail-closed 가 레지스트리 항목(`HKCU:\…`)까지 「확인 불가」로 막아
#   **멀쩡한 등록 항목이 안 지워졌다.** 방어가 제 범위를 넘으면 그것도 결함이다.
awk '/^function Drop\(/,/^}/' "$RESET" | grep -q 'Test-IsFilePath'
ck "[갈림] 윈 제거기의 실경로 가드가 파일 자리에만 걸린다" $? "레지스트리 항목까지 막아 안 지워진다"
codegrep "$RESET" 'System\.Security\.Cryptography\.SHA256'
ck "[갈림] 윈 제거기가 .NET 으로 직접 센다" $? "지문 세는 길이 없다"

echo "== 아고라 결합 없음 (2026-09-09 정책 — 설치 ≠ 아고라) =="
# 🔴이 구역은 **없는 것을 재는 구역**이다. 앞 판은 여기서 아고라 참가 단계를 **재고 있었다**
#   ([11] 아고라 참가 · 서명 칸 순서 · 열쇠 잠김 가드 …). 운영자 정책으로 그 단이 통째로 빠졌으므로
#   같은 자리에서 **다시 끼우면 적색이 되는 축**으로 바꿔 세운다.
#   ★왜 「지웠다」로 끝내지 않는가: 지운 것은 **다음 사람이 좋은 뜻으로 되돌린다.** 되돌린 순간을
#   말해 주는 것이 없으면, 설치기는 조용히 다시 아고라에 등재하기 시작한다.
# 단계 표기 — 아고라가 빠져 **열 단**이다. 화면이 세는 수와 사이트 문안이 같아야 한다.
#   ⚠옛 표기 축도 **넷 전부**에 건다. 재설치기는 지금 단계를 안 찍지만, 안내 문장에 「[11/11]」을
#   손으로 박아 넣는 길이 열려 있고 그러면 화면과 안내가 갈린다(축 대상은 배포 목록에서 끌어온다).
# 🔴**기대 집합을 독립으로 적는다**(1차 검토 지적 채택). 앞 판은 「서로 다른 것이 10개이고
#   두 OS 가 같다」만 봤다 ⇒ `[12/10]` 로 전부 바꿔도 **10개·동일**이라 통과한다. 세는 것과
#   **무엇인지**는 다른 질문이다. 기대값을 여기 적어 두고 그것과 맞춘다.
EXPECT_STEPS="[1/10] [2/10] [3/10] [4/10] [5/10] [6/10] [7/10] [8/10] [9/10] [10/10]"
# 🔴🔴**분모를 11 만 막지 않는다**(2차 검토 지적 채택 2026-09-09).
#   앞 판은 `/11` 만 금지하고 `/10` 만 수집했다 ⇒ `[3/12]` 로 바꾸면 **어느 축에도 안 걸린다**
#   (금지 목록에도 없고 수집 대상에도 안 들어가 「기대 밖 번호」가 빈 채로 통과한다).
#   ★막을 것을 나열하지 말고 **허용할 것을 나열하라** — 나열한 금지 밖은 언제나 통과한다.
#   ⇒ `[n/m]` 을 **분모와 무관하게 전부** 모아, 하나라도 기대 집합 밖이면 적색.
step_marks_bad() { # step_marks_bad <파일> → 기대 밖 표기를 STEP_BAD 에 모은다 · rc 1 = 읽기 오류
  local f="$1" body rc m
  STEP_BAD=""; GREP_WHY=""
  body="$(cat "$f" 2>/dev/null)"; rc=$?
  [ "$rc" -ne 0 ] && { GREP_WHY="읽기 오류(cat rc=$rc)"; return 1; }
  for m in $(printf '%s\n' "$body" | grep -oE '\[[0-9]+/[0-9]+\]' | sort -u); do
    case " $EXPECT_STEPS " in *" $m "*) : ;; *) STEP_BAD="$STEP_BAD $m" ;; esac
  done
  return 0
}
for f in "${INSTALL_SCRIPTS[@]}"; do
  [ -f "$f" ] || continue
  fb="$(basename "$f")"
  if step_marks_bad "$f"; then
    [ -z "$STEP_BAD" ]; rc=$?
  else
    rc=1; STEP_BAD=" $GREP_WHY"
  fi
  ck "[단계] $fb 의 단계 표기가 전부 기대 집합 안에 있다" "$rc" "기대 밖 표기:$STEP_BAD"
done
steps_of() { grep -oE '\[[0-9]+/10\]' "$1" | awk '!seen[$0]++' | tr '\n' ' '; }   # 등장 순서 그대로 · 중복 제거
sorted_of() { grep -oE '\[[0-9]+/10\]' "$1" | sed 's/[^0-9/]//g;s|/10||' | sort -n -u | sed 's|^|[|;s|$|/10]|' | tr '\n' ' '; }
exp_sorted="$(printf '%s ' $EXPECT_STEPS)"
for f in "$SH" "$PS"; do
  fb="$(basename "$f")"
  got="$(sorted_of "$f")"
  [ "$got" = "$exp_sorted" ]; rc=$?
  ck "[단계] $fb 의 단계 집합이 기대와 정확히 같다" "$rc" "기대=[$exp_sorted] 실제=[$got]"
done
# ★순서는 **실제로 돌려서** 본다. 파일 안 등장 순서로는 못 잰다 — 함수 정의 순서와 부르는
#   순서가 다르기 때문이다(실측: 정의는 5·9·10·2·1… 순인데 화면은 1→10 이다).
#   ⇒ 미리보기(dry-run)를 돌려 **화면에 찍히는 차례**를 기대값과 맞춘다.
#   ⚠맥판만 여기서 잰다(이 기계에 PowerShell 이 없다). 윈도우판은 러너의 같은 이름 축이 잰다.
if command -v bash >/dev/null 2>&1; then
  drytmp="$(mktemp -d 2>/dev/null)" || drytmp=""
  if [ -n "$drytmp" ]; then
    dryseq="$(JARVIS_HOME="$drytmp/install-jarvis" bash "$SH" --dry-run 2>/dev/null \
              | grep -oE '^\[[0-9]+/10\]' | awk '!seen[$0]++' | tr '\n' ' ')"
    [ "$dryseq" = "$exp_sorted" ]; rc=$?
    ck "[단계] 맥 미리보기가 1→10 차례로 찍는다(실제 출력)" "$rc" "찍힌 차례=[$dryseq]"
    rm -rf "$drytmp" 2>/dev/null
  else
    sk "[단계] 맥 미리보기 차례" "임시 자리를 못 만들었다"
  fi
fi
a="$(sorted_of "$SH")"; b="$(sorted_of "$PS")"
[ -n "$a" ] && [ "$a" = "$b" ]; ck "[단계] 두 OS 의 단계 표기 집합이 같다" $? "sh=[$a] ps1=[$b]"
# ★설치 스크립트 **밖의 소비처**도 같은 번호를 써야 한다 — 러너 stub 과 진단 규칙 표가 갈리면
#   러너는 헛것을 재고 규칙 표는 없는 화면을 기다린다(교차 검토 8차: INSTALL_SCRIPTS 밖 드리프트).
for extra in "$DIR/../.github/workflows/reinstall-matrix.yml" "$DIR/../tests/help-fixtures.tsv"; do
  if [ -f "$extra" ]; then
    eb="$(basename "$extra")"
    if step_marks_bad "$extra"; then
      [ -z "$STEP_BAD" ]; rc=$?
    else
      rc=1; STEP_BAD=" $GREP_WHY"
    fi
    ck "[단계] $eb 의 단계 표기가 전부 기대 집합 안에 있다" "$rc" "설치기 밖 소비처가 딴 번호를 쓴다:$STEP_BAD"
  else
    sk "[단계] $(basename "$extra") 번호 대조" "그 파일이 없다"
  fi
done
# ★역방향 축 — **설치 스크립트에 아고라가 한 글자도** 없어야 한다.
#   ⚠`AGORA_` 만 세면 안 된다. 윈도우판은 `$AgoraHome`·`Set-AgoraSkill` 처럼 대소문자를 섞어 쓰므로
#   그 표기를 그대로 되돌리면 `AGORA_` 축은 녹색인 채로 기능이 살아난다. ⇒ **낱말 자체**를 센다.
# 🔴rc 는 **변수에 먼저 담는다.** `ck "... $(basename …)" $?` 로 쓰면 `$?` 가 잰 것은
#   조건이 아니라 **`basename` 의 성공**이다(명령치환이 그 자리에서 `$?` 를 0 으로 덮어쓴다).
#   ⇒ 축이 언제나 녹색이 된다. 실제로 그렇게 썼다가 뮤턴트 2 개가 그대로 살아남았다(2026-09-09 자기신고).
# 🔴🔴**검사 대상은 설치 스크립트 「전체」다 — 둘이 아니라 넷이다**(교차 검토 1차 [5] 지적 채택 2026-09-09).
#   앞 판은 `for f in "$SH" "$PS"` 로 **bootstrap 둘만** 봤다. 그런데 사람이 실제로 붙여넣는 한 줄에는
#   **재설치 경로**가 따로 있고(reinstall.sh·reinstall.ps1) 그 둘도 사이트가 그대로 배포한다.
#   ⇒ 거기에 아고라를 되끼우면 **어떤 축도 말하지 않았다.** 「지운 자리」만 지키고 「지우지 않은 이웃」을
#   안 지키면, 되돌리려는 사람은 **막히지 않는 문**으로 들어온다.
#   ★교훈: 역방향 축의 대상 목록은 **배포 목록에서 끌어와야 한다** — 손으로 두 개만 적으면 그 손이 곧 구멍이다.
# 🔴🔴**이 축이 보증하는 것을 정확히 적는다**(교차 검토 3차 HIGH 결착 · 과대 보증 금지):
#   보증 = 「이 네 파일에 **알려진 지문**(낱말·주소·경로·파일 이름)이 없다」. 그뿐이다.
#   ⛔보증 아님 = 「아고라가 의미상 되살아날 수 없다」. 정규식으로 그것을 보증할 수 없다 —
#   이름을 쪼개 이어 붙이거나(`p=a'go'ra`) 바깥 헬퍼 파일에 동작을 두고 그 파일만 부르면 안 걸린다.
#   ⇒ 그 계열은 **격리 실행 관찰 시험**의 몫이고 이 작업 밖이다(내부 문서 이월). 여기서 「완전 차단」이라 읽지 마라.
for f in "${INSTALL_SCRIPTS[@]}"; do
  [ -f "$f" ] || { sk "[분리] $(basename "$f") 아고라 축" "그 파일이 없다"; continue; }
  fb="$(basename "$f")"
  absent_or_fail_i "$f" 'agora'; rc=$?
  ck "[분리] $fb 에 아고라 문자열 0건" "$rc" "${GREP_WHY} — 설치 스크립트가 다시 아고라와 엮였다"
done
# 등재는 릴레이에 말을 거는 일이다. 주소·서명·명부 어느 자리도 설치 스크립트에 남으면 안 된다.
for f in "${INSTALL_SCRIPTS[@]}"; do
  [ -f "$f" ] || continue
  fb="$(basename "$f")"
  absent_or_fail "$f" 'agora\.godmeyou\.kr|/register|participant\.json|jarvis-agora@'; rc=$?
  ck "[분리] $fb 에 등재 자리 0건(주소·등재 호출·명부 파일)" "$rc" "등재 경로가 남았다(${GREP_WHY})"
done
# 꾸러미·스킬 놓기도 낱말 없이 되살아날 수 있다(파일 이름·자리만으로도 기능이 선다).
for f in "${INSTALL_SCRIPTS[@]}"; do
  [ -f "$f" ] || continue
  fb="$(basename "$f")"
  absent_or_fail "$f" 'agora-client-[0-9]|agora-delegate|\.config/agora|\.config.\\agora|SIGNING_KEY'; rc=$?
  ck "[분리] $fb 에 꾸러미·스킬 놓기 자리 0건" "$rc" "배치 경로가 남았다 — 낱말을 안 써도 기능은 선다(${GREP_WHY})"
done
# 제거기 — 아고라 자국은 **지우지 않는다.** 우리가 만들지 않은 것을 지우면 남의 자산을 지우는 것이다.
if [ -f "$RESET_SH" ]; then
  no_code "$RESET_SH" 'drop_(dir|file) .*AGORA|drop_dir "\$_sk"'
  ck "[분리] 맥 제거기가 아고라를 지우지 않는다" $? "지우는 줄이 남았다 — 남의 자산을 지운다"
  grep -q '토론장 참가 열쇠·이름' "$RESET_SH"
  ck "[분리] 맥 제거기가 「남깁니다」로 말한다" $? "화면에 그 사실이 안 보인다 — 사람은 지워졌다고 여긴다"
fi
if [ -f "$RESET" ]; then
  no_code "$RESET" "Drop .*\\\$Agora"
  ck "[분리] 윈 제거기가 아고라를 지우지 않는다" $? "지우는 줄이 남았다 — 남의 자산을 지운다"
  grep -q '토론장 참가 열쇠·이름' "$RESET"
  ck "[분리] 윈 제거기가 「남깁니다」로 말한다" $? "화면에 그 사실이 안 보인다"
fi

echo "== 맥 첫 실기 수정 (2026-09-06 · 깨끗한 맥 Tart 실측) =="
# 🔴이 다섯 축은 **깨끗한 맥에서만 적색이 되던 결함**을 붙든다. 개발 기계에는 cys·claude 가 이미 있어
#   앞의 어떤 축도 이것들을 못 잡았다 — 그래서 「돌려 봤다」가 아니라 「이 조건에서 돌려 봤다」가 축이다.

# ⑴ [6/10] `-quiet` 는 마운트 지점을 표준출력에 안 찍는다 ⇒ 파싱이 언제나 빈 문자열이 된다.
no_code "$SH" 'hdiutil attach[^|]*-quiet'; ck "[6] hdiutil attach 에 -quiet 없음" $? "-quiet 면 마운트 지점이 안 찍혀 어떤 맥에서도 실패한다"
# ⑵ dmg 최상위에는 cys.app 이 없다(Install cys.app + .support/cys.app). 짐작 복사로 돌아가면 적색.
no_code "$SH" 'cp -R "\$mnt/cys\.app"'; ck "[6] 최상위 cys.app 짐작 복사 안 함" $? "dmg 최상위에 cys.app 이 없다 — 조용히 건너뛴다"
# ⑶ 벤더 원자 설치기를 부른다. 직접 복사는 '반쪽 번들' 경합을 만들어 「손상되었습니다」를 낳는다.
codegrep "$SH" 'install-core\.sh'; ck "[6] 벤더 원자 설치기 호출" $? "직접 복사는 반쪽 번들 경합을 만든다"
# ⑷ 어느 경로로 나가든 마운트를 남기지 않는다(앞 판은 실패 분기에서 볼륨을 남겼다).
#   🔴교차 검토 지적 채택(2026-09-06): 앞 판은 **이름이 파일에 있는가**만 봤다. 그러면 호출을 전부
#   지워도 **함수 선언 한 줄이 남아 녹색**이다 — 내가 돌린 뮤턴트가 이름을 통째로 바꾸는 거친 것이라
#   그 구멍을 못 봤다. ⇒ **선언 1 + 호출 3(실패 2 · 정상 1) = 4자리**를 센다.
#   ⇒ **선언 1 + 호출 5(= 나가는 길 전부) = 6자리.** 한 자리라도 사라지면 적색이 된다.
#   ⚠수를 세는 축이라 정당한 개편에도 적색이 난다 — 그때는 「나가는 길이 몇 개인지」를 다시 세고
#   이 숫자를 고치면 된다. 그 재확인이 곧 이 축이 원하는 것이다.
[ "$(grep -c 'cys_dmg_detach' "$SH")" -ge 6 ]; ck "[6] 모든 경로에서 detach (선언+나가는 길 전부 = 6자리)" $? "호출을 지워도 선언만 남으면 볼륨이 남는다"
# ⑸ [7/10] 만 dry 분기가 없어서, 깨끗한 기계의 미리보기가 여기서 끊겨 [8/10] 이 호출조차 안 됐다.
[ "$(awk '/^step_verify_cys\(\)/,/^}/' "$SH" | grep -c '"\$MODE" = "dry"')" -ge 1 ]; ck "[7] dry 분기 있음" $? "깨끗한 기계 미리보기가 여기서 끊겨 [8/10] 이 안 찍힌다"
# ⑹ 미리보기 보고서가 「앞 단계는 이미 끝났습니다」라고 말하면 거짓이다 — 아무것도 안 했기 때문이다.
[ "$(awk '/## 지금 상태/,/막힌 단계 없음/' "$SH" | grep -c '"\$MODE" = "dry"')" -ge 1 ]; ck "[1] 보고서가 dry 를 가려 말함" $? "미리보기가 「이미 끝났습니다」로 거짓 보고한다"
# ⑺ 공식 클로드 설치기는 셸 프로필에 아무것도 안 쓴다(실측) ⇒ 새 터미널에 claude 가 없다.
#   같은 지적 — 선언만 남고 호출이 사라지면 아무 일도 안 일어난다. 선언 1 + 호출 1 = 2자리.
[ "$(grep -c 'seed_local_bin_path' "$SH")" -ge 2 ]; ck "[2] 새 터미널용 PATH 한 줄 심기 (선언+호출)" $? "호출을 지워도 선언만 남으면 아무것도 안 심긴다"
#   이미 다른 프로필에 그 경로가 있으면 또 넣지 않는다(중복 누적 방지 · 교차 검토 지적).
codegrep "$SH" 'zshrc.*zshenv|zshenv.*zshrc'; ck "[2] 다른 프로필도 보고 나서 심는다" $? "zprofile 만 보면 zshrc 에 이미 있는 사람에게 중복으로 쌓인다"
# ⑻ 우리 창이 아닌 곳에서 도는 파일은 남의 PATH 주입에 기대지 않는다(보험 · cys 는 실제로 심어 준다).
codegrep "$SH" 'CLAUDE="\$HOME/\.local/bin/claude"'; ck "[9] wake.sh 가 절대경로를 먼저 본다" $? "cysd 의 PATH 주입에만 기댄다"
# ⑼⑽ 두 OS 동등 — ⑸⑹ 은 맥에서 잡혔지만 **같은 결함이 윈도우에도 있었다.** 한쪽만 고치면 갈라진다.
[ "$(awk '/^function Step-VerifyCys/,/^}/' "$PS" | grep -c "Mode -eq 'dry'")" -ge 1 ]; ck "[7] ps1 도 dry 분기 있음" $? "윈도우 미리보기도 깨끗한 기계에서 [8/10] 을 건너뛴다"
#   ⚠축을 awk 범위로 잡았더니 범위가 함수 밖까지 번져 뮤턴트가 살아남았다(자기신고 2026-09-06).
#   범위로 좁히려다 못 좁힌 것보다, **그 문장 자체가 있는가**를 보는 편이 뮤턴트에 정직하다.
grep -q '미리보기) 아무것도 하지 않았습니다' "$PS"; ck "[1] ps1 보고서가 dry 를 가려 말함" $? "윈도우 미리보기도 「이미 끝났습니다」로 거짓 보고한다"

# ── F-W18 (2026-09-06 · 실사용자 2건) — 윈도우 공식 설치기는 사용자 PATH 를 안 심는다 ──
#   실사용자 사진: 「Native installation exists but …\.local\bin is not in your PATH. Add it by opening:
#   System Properties → …」 뒤에 우리 문장 「창을 새로 열고 다시」 → 새 창에도 없으니 무한 반복.
#   맥 [2] 축(seed_local_bin_path)의 윈도우 짝. 한쪽만 고치면 갈라진다(위 ⑼⑽ 과 같은 형태).
[ "$(grep -c 'Seed-LocalBinPath' "$PS")" -ge 2 ]; ck "[F-W18] ps1 사용자 PATH 심기 정의+호출" $? "정의만 있고 부르지 않거나 아예 없다"
codegrep "$PS" "SetEnvironmentVariable\('Path',[^)]*'User'\)"; ck "[F-W18] ps1 이 사용자 PATH 에 실제로 쓴다" $? "등록 명령이 없다 — 새 창에서 못 잡는다"
codegrep "$PS" 'ExpandEnvironmentVariables'; ck "[F-W18] ps1 PATH 비교가 %USERPROFILE% 표기를 편다" $? "손으로 넣은 다른 표기와 중복 누적된다"
codegrep "$PS" 'Path.*Machine'; ck "[F-W18] ps1 시스템 PATH 는 읽기만(권한 상승 0)" $? "같음"
no_code "$PS" "SetEnvironmentVariable\('Path',[^)]*'Machine'\)"; ck "[F-W18] ps1 시스템 PATH 에는 쓰지 않는다" $? "관리자 권한 상승 경로가 열린다"
grep -q '파일 있음: ' "$PS"; ck "[F-W18] ps1 [2/10] 실패 문장에 사실 3개(파일·PATH·종료 코드)" $? "「창을 새로 열고 다시」만 말하면 같은 자리를 돈다"
#   [2/10] 안에서 심기가 「PATH 통째 덮어쓰기」 **뒤에** 와야 한다 — 앞에 오면 그 자리에서 지워진다.
[ "$(awk '/^function Step-InstallClaude/,/^}/' "$PS" | grep -n "GetEnvironmentVariable('Path','Machine')" | head -1 | cut -d: -f1)" -lt "$(awk '/^function Step-InstallClaude/,/^}/' "$PS" | grep -n 'Seed-LocalBinPath' | head -1 | cut -d: -f1)" ]; ck "[F-W18] ps1 심기가 PATH 덮어쓰기 뒤에 온다" $? "덮어쓰기가 심은 것을 지운다"

echo "== 자국 대조 — 설치기가 만드는 것 ↔ 제거기가 지우는 것 (2026-09-08 신설) =="
# 🔴이 축이 이 작업의 존재 이유다. 설치기에 자국이 하나 늘고 제거기를 안 고친 날, 그 사실을
#   알려 주는 것이 **아무것도 없었다.** 「지웠다」고 말하는 제거기가 무엇을 안 지웠는지 모르는 채 남는다.
#   ⇒ 정본 표(footprint.md)와 제거기가 **같은 ID 집합**을 갖는지 기계로 잰다.
#   ⚠이름이 있는지만 보지 않는다 — 표에만 있고 코드에 없는 ID, 코드에만 있고 표에 없는 ID를
#     **양방향으로** 센다. 한쪽만 보면 「표에 적고 코드는 안 고친 날」이 녹색으로 지나간다.
if [ -f "$FOOTPRINT" ] && [ -f "$RESET_SH" ]; then
  # 🔴첫 판은 **이름이 파일 어딘가에 있는가**만 봤다. 두 뮤턴트가 그대로 살아남았다(자기신고):
  #   ⑴표에서 행을 지워도 본문 산문에 그 이름이 또 나와서 통과 ⑵제거기에서 지우는 동작을 없애도
  #   진단 쪽에 같은 표식이 남아 통과. ⇒ **어느 자리에 있는가**를 갈라 세지 않으면 축이 안 문다.
  #   ⇒ 표는 **표 줄에서만** 읽고, 코드는 **살펴보기 구역**과 **지우기 구역**을 따로 센다.
  #   ⚠「표 줄」만으로도 부족했다 — 1-1「아직 못 잰 것」도 표라서 같은 이름이 거기서 또 나왔고,
  #   본 표에서 행을 지운 뮤턴트가 그 덕에 살아남았다(자기신고 2). ⇒ **갈래 칸이 있는 줄**만 센다.
  #   갈래 칸은 이 표의 정의 그 자체이므로, 그것을 지우면 그 줄은 애초에 자국 행이 아니다.
  fp_all()  { grep -E '^\| *`M-[A-Z]+`' "$FOOTPRINT" | grep -E '전부 우리 것|남의 파일 속 우리 줄|손대지 않음' | grep -oE '`M-[A-Z]+`' | tr -d '`' | sort -u; }
  # 「전부 우리 것」이면서 다른 자국 안에 들어 있지 않은 것 = 제거기가 제 손으로 지워야 하는 것
  fp_own()  { grep -E '^\| *`M-[A-Z]+`' "$FOOTPRINT" | grep '전부 우리 것' | grep -v '안)' | grep -oE '`M-[A-Z]+`' | tr -d '`' | sort -u; }
  ids_in()  { awk -v a="$2" -v b="$3" 'index($0,a){f=1} f&&index($0,b){f=0} f' "$1" | grep -oE 'footprint: M-[A-Z]+' | awk '{print $2}' | sort -u; }
  DIAG_IDS="$(ids_in "$RESET_SH" 'diagnose() {' '# ── 지우기')"
  PURGE_IDS="$(ids_in "$RESET_SH" '# footprint: M-LOGIN' 'REMOVED $REMOVED')"
  MISS_DIAG="$(comm -23 <(fp_all) <(printf '%s\n' "$DIAG_IDS") | tr '\n' ' ')"
  MISS_PURGE="$(comm -23 <(fp_own) <(printf '%s\n' "$PURGE_IDS") | tr '\n' ' ')"
  EXTRA="$(comm -13 <(fp_all) <(printf '%s\n' "$DIAG_IDS") | tr '\n' ' ')"
  [ -z "$MISS_DIAG" ];  ck "[자국] 표의 자국을 진단기가 전건 살핀다" $? "살펴보지 않는 자국: ${MISS_DIAG:-?}"
  [ -z "$MISS_PURGE" ]; ck "[자국] 「전부 우리 것」을 제거기가 전건 지운다" $? "지우지 않는 자국: ${MISS_PURGE:-?}"
  [ -z "$EXTRA" ];      ck "[자국] 표에 없는 자국 0" $? "표에 없는 자국: ${EXTRA:-?}"
  # 🔴자국 하나 안에 **칸이 여럿**이다. ID 만 대조하면 「그 자국을 건드리기는 했다」까지만 보증한다.
  #   실기에서 두 칸을 빠뜨렸는데 ID 축은 전부 녹색이었다(2026-09-08 게스트 실측) — 다 지운 뒤에도
  #   진단기가 자국을 계속 찾아내 「중간에 멈춘 상태」로 오보했다. ⇒ **칸 이름까지 대조한다.**
  key_of() { grep -E "^\| *\`$1\`" "$FOOTPRINT" | grep -oE '`[a-zA-Z]+[a-zA-Z]*`' | tr -d '`' | grep -vE '^(M|W)-' | sort -u; }
  MISSK=""
  for k in $(key_of M-CLAUDESETTINGS) $(key_of M-CLAUDEJSON); do
    # 신뢰 칸은 **전용 제거기**가 다룬다 — 그 칸이 든 자리에는 참가자가 쌓은 값이 함께 있어서
    #   `strip_json_key` 로 칸째 지우면 남의 값을 함께 날린다(그래서 갈래를 따로 두었다).
    case "$k" in hasTrustDialogAccepted) grep -q 'strip_trust_seed' "$RESET_SH" && continue ;; esac
    grep -q "strip_json_key .*'$k'" "$RESET_SH" || MISSK="$MISSK $k"
  done
  [ -z "$MISSK" ]; ck "[자국] 표에 적힌 칸을 맥 제거기가 전건 뺀다" $? "안 빼는 칸:$MISSK"
  MISSKW=""
  for k in $(key_of W-CLAUDESETTINGS) $(key_of W-CLAUDEJSON); do
    case "$k" in hasTrustDialogAccepted) grep -q 'Remove-TrustSeed' "$RESET" && continue ;; esac
    grep -q "Remove-JsonKey .*'$k'" "$RESET" || MISSKW="$MISSKW $k"
  done
  [ -z "$MISSKW" ]; ck "[자국] 표에 적힌 칸을 윈 제거기가 전건 뺀다" $? "안 빼는 칸:$MISSKW"
  # 표 줄 수가 줄면 적색 — 행을 지우고 산문에만 이름을 남기는 것을 막는다.
  [ "$(fp_all | wc -l | tr -d ' ')" -ge 16 ]; ck "[자국] 맥 표 줄 수(16 이상)" $? "표에서 행이 사라졌다"
else
  sk "[자국] 대조" "footprint.md 또는 reset-clean.sh 가 없다"
fi

# 윈도우 쪽도 같은 잣대로 잰다 — 두 OS 동등(운영자 확정 ⑤). 한쪽만 재면 갈라지는 날을 못 본다.
if [ -f "$FOOTPRINT" ] && [ -f "$RESET" ]; then
  wfp_all()  { grep -E '^\| *`W-[A-Z]+`' "$FOOTPRINT" | grep -E '전부 우리 것|남의 파일 속 우리 줄|손대지 않음' | grep -oE '`W-[A-Z]+`' | tr -d '`' | sort -u; }
  wfp_own()  { grep -E '^\| *`W-[A-Z]+`' "$FOOTPRINT" | grep '전부 우리 것' | grep -v '안)' | grep -oE '`W-[A-Z]+`' | tr -d '`' | sort -u; }
  wids_in()  { awk -v a="$2" -v b="$3" 'index($0,a){f=1} f&&index($0,b){f=0} f' "$1" | grep -oE 'footprint: W-[A-Z]+' | awk '{print $2}' | sort -u; }
  WDIAG="$(wids_in "$RESET" 'function Invoke-Diagnose' '# ── 남의 파일 속 우리 줄')"
  WPURGE="$(wids_in "$RESET" '# footprint: W-LOGIN' 'Write-Host ..=== 끝났습니다')"
  WMISS_D="$(comm -23 <(wfp_all) <(printf '%s\n' "$WDIAG") | tr '\n' ' ')"
  WMISS_P="$(comm -23 <(wfp_own) <(printf '%s\n' "$WPURGE") | tr '\n' ' ')"
  WEXTRA="$(comm -13 <(wfp_all) <(printf '%s\n' "$WDIAG") | tr '\n' ' ')"
  [ -z "$WMISS_D" ]; ck "[자국] 윈 표의 자국을 진단기가 전건 살핀다" $? "살펴보지 않는 자국: ${WMISS_D:-?}"
  [ -z "$WMISS_P" ]; ck "[자국] 윈 「전부 우리 것」을 제거기가 전건 지운다" $? "지우지 않는 자국: ${WMISS_P:-?}"
  [ -z "$WEXTRA" ];  ck "[자국] 윈 표에 없는 자국 0" $? "표에 없는 자국: ${WEXTRA:-?}"
fi

echo "== 사이트 문안 — 삭제 후 재설치 (2026-09-08 신설) =="
GET=""
for c in "$DIR/../../ai-jarvis/site/get/index.html" "$HOME/axdev/ai-jarvis/site/get/index.html"; do
  [ -f "$c" ] && { GET="$c"; break; }
done
if [ -n "$GET" ]; then
  # ★사람이 실제로 복사하는 것은 사이트다 — 스크립트만 고치고 사이트를 안 고치면 옛 줄이 돈다.
  grep -q 'id="reinstall"' "$GET"; ck "[사이트] 재설치 방법이 대문에 있다" $? "사람이 그 방법을 못 찾는다"
  grep -q 'reinstall.sh' "$GET"; ck "[사이트] 맥 한 줄이 있다" $? "-"
  grep -q 'reinstall.ps1' "$GET"; ck "[사이트] 윈 한 줄이 있다" $? "-"
  # 약속 3문장 — 삭제도 자동(목록 확인 · 「지웁니다」 뒤에만) · 로그인 유지 · 개인 파일 무접촉. 하나라도 빠지면 적색.
  # ★2026-09-11 운영자: 「되돌릴 수 없습니다」는 초보를 위축시킨다 → 대문은 「삭제도 자동으로 합니다 + 확인 절차」로(9d0d072).
  #   지우기 직전 관문(reset-clean 「위 목록을 지웁니다. 되돌릴 수 없습니다.」)은 행위 시점의 정직한 고지라 그대로 둔다.
  grep -q '삭제도 자동으로 합니다' "$GET" && grep -q '「지웁니다」라고 치신 뒤에만' "$GET"; ck "[사이트] 삭제도 자동·확인 뒤에만 지운다고 말한다" $? "사람이 모르고 누르거나 · 겁내서 안 누른다"
  grep -q '로그인은 그대로' "$GET"; ck "[사이트] 로그인은 남는다고 말한다" $? "다시 로그인해야 하는 줄 안다"
  grep -q '손대지 않습니다' "$GET"; ck "[사이트] 개인 파일은 안 건드린다고 말한다" $? "사진·문서가 지워질까 겁낸다"
  # 로그인 삭제 옵션을 대문에 내놓지 않는다(운영자 확정 2026-09-08).
  ! grep -qE 'purge-login|PurgeLogin' "$GET"; ck "[사이트] 로그인 삭제 옵션 비노출" $? "사용자 경로에 노출됐다"
  # 계정 바꾸기는 재설치와 다른 일이다 — 그 한 줄을 따로 적는다.
  grep -q 'claude auth logout' "$GET"; ck "[사이트] 계정 바꾸기를 따로 안내한다" $? "계정을 바꾸려고 재설치를 누른다"
  # 사이트 사본이 실물과 같은가 — 갈라지면 사람은 옛 것을 받는다.
  SITE_INSTALL="$(dirname "$GET")/../install"
  # ⚠앞 판은 넷만 셌다. 그런데 사이트 폴더에는 **bootstrap.sh·bootstrap.ps1 도 같이 놓여 있다** —
  #   설치기를 고치고 사이트를 안 고치면 사람은 옛 설치기를 받는데 아무 축도 그것을 말하지 않았다
  #   (2026-09-08 실측: site/install/ 에 6개 파일 · 축은 4개만 대조).
  for f in reset-clean.sh reset-clean.ps1 reinstall.sh reinstall.ps1 bootstrap.sh bootstrap.ps1; do
    if [ -f "$SITE_INSTALL/$f" ]; then
      cmp -s "$DIR/$f" "$SITE_INSTALL/$f"; ck "[사이트] $f 사본이 실물과 같다" $? "사이트가 옛 판을 배포한다"
    else
      ck "[사이트] $f 사본이 있다" 1 "사이트에 그 파일이 없다"
    fi
  done
  # 🔴🔴**대문의 단계 문안도 잰다**(교차 검토 6차 지적 채택 2026-09-09).
  #   사본 여섯을 다 맞춰도 **대문 문장이 옛말이면 거짓 안내는 그대로 남는다** — 실측 당시 대문은
  #   「설치는 열한 단계로 … 마지막 [11/11]은 아고라 참가 등록」이라고 **현재형으로** 적고 있었다.
  #   사람은 `[10/10] 완료` 를 보고 「한 단계가 실패했다」고 읽는다. 그것이 곧 전화 문의다.
  absent_or_fail "$GET" '\[[0-9]+/11\]'; rc=$?
  ck "[사이트] 대문에 옛 단계 표기(/11) 0건" "$rc" "대문이 열한 단이라고 말한다(${GREP_WHY})"
  absent_or_fail "$GET" '열한 단계|열한단계'; rc=$?
  ck "[사이트] 대문에 「열한 단계」 0건" "$rc" "글로도 열한 단이라고 말한다(${GREP_WHY})"
  # ⚠「마지막 [N/N]」 자체를 막지 않는다 — 「마지막 [10/10]은 자비스를 시작합니다」는 **옳은 문장**이다
  #   (2차 검토 지적 채택: 원 문제를 닫으면서 정당한 문안까지 거부하는 새 오탐을 만들었다).
  #   막는 것은 **아고라와 결합한 형태**뿐이다.
  absent_or_fail "$GET" '아고라[^가-힣]{0,4}참가 등록|토론장[^가-힣]{0,6}참가 등록|마지막 \[[0-9]+/[0-9]+\][^<]{0,30}(아고라|토론장)'; rc=$?
  ck "[사이트] 대문이 아고라를 설치 단계로 말하지 않는다" "$rc" "설치와 별개인 것을 설치의 일부로 안내한다(${GREP_WHY})"
  grep -qE '열 단계|\[1/10\]' "$GET"; ck "[사이트] 대문이 열 단계라고 말한다" $? "단계 수를 안 말하거나 옛 수를 말한다"
  # 참가자가 보는 쪽에는 내부 용어를 안 쓴다.
  absent_or_fail "$GET" '박사님|footprint|자국|미실측|T-M[0-9]|F-M[0-9]|뮤턴트|§'; rc=$?
  ck "[공개] 대문에 내부 용어 0건" "$rc" "노출 ${GREP_WHY}"
else
  sk "[사이트] 대문 검사" "get/index.html 을 못 찾았다"
fi

echo "== 남의 파일을 다루는 법 (2026-09-08 교차 검토 수정) =="
# 🔴이 넉 줄이 「칸 하나 빼려다 남의 파일을 깨뜨리는」 길을 막는다.
if [ -f "$RESET" ]; then
  # PowerShell 5.1 의 Set-Content -Encoding UTF8 은 BOM 을 붙인다. JSON 앞의 BOM 은 읽는 쪽을 깨뜨린다.
  no_code "$RESET" "Set-Content -Path \$file -Encoding UTF8"
  ck "[안전] 남의 JSON 을 BOM 붙는 방식으로 안 쓴다" $? "BOM 이 붙어 남의 설정 파일이 안 읽힌다"
  codegrep "$RESET" 'UTF8Encoding\(\$false\)'; ck "[안전] BOM 없는 인코딩을 쓴다" $? "-"
  # 원본에 바로 쓰면 쓰는 도중 멈췄을 때 남의 파일이 반쪽으로 남는다.
  codegrep "$RESET" 'jarvis-tmp'; ck "[안전] 임시 파일에 쓴 뒤 자리를 바꾼다" $? "쓰다 멈추면 남의 파일이 반쪽이 된다"
  # 프로그램이 없어도 상시 가동 등록을 뗄 길이 있어야 한다(맥에는 있었고 윈에는 없었다).
  codegrep "$RESET" 'Unregister-ScheduledTask'; ck "[안전] 프로그램이 없어도 등록을 뗀다" $? "앱만 사라지고 등록이 영원히 남는다"
  # 사람이 설정 앱에서 안 지웠는데 우리가 폴더만 뜯으면 고아가 남는다.
  codegrep "$RESET" 'SkipCysDir'; ck "[안전] 제거가 안 끝났으면 폴더를 억지로 안 뜯는다" $? "바로가기 등이 고아로 남는다"
fi
if [ -f "$RESET_SH" ]; then
  # 표식 다음 줄을 무조건 지우면 사용자가 그 자리에 넣어 둔 자기 줄을 삼킨다.
  codegrep "$RESET_SH" 'if \(\$0 == l\) next|\$0 == l'
  ck "[안전] 표식 다음 줄은 우리 줄일 때만 지운다" $? "사용자가 그 자리에 넣은 줄을 삼킨다"
  no_code "$RESET_SH" 'cat "\$tmp" > "\$f"'
  ck "[안전] 원본을 잘라 쓰지 않는다" $? "쓰다 멈추면 남의 프로필이 반쪽이 된다"
  # 키 경로가 안 먹는 경우를 조용히 지나가지 않는다.
  codegrep "$RESET_SH" '못 살핌'; ck "[안전] 다루지 못한 칸을 사실대로 말한다" $? "조용히 지나가 「다 지웠다」가 거짓이 된다"
fi

echo "== 삭제 후 재설치 — 한 트랜잭션 (2026-09-08 신설) =="
# 🔴이 축이 재는 성질 하나: **지우기가 실패하면 설치로 넘어가지 않는다.**
#   반쯤 지운 위에 설치가 얹히면 어느 쪽 상태인지 아무도 모르게 된다 — 그것이 이 도구의
#   가장 나쁜 실패 모양이라, 되돌리면 적색이 되게 박아 둔다.
if [ -f "$REIN_SH" ]; then
  bash -n "$REIN_SH" 2>/dev/null; ck "[재설치] bash -n 통과" $? "문법 오류"
  codegrep "$REIN_SH" 'reset_rc'; ck "[재설치] 지우기 결과를 받는다" $? "결과를 안 본다"
  codegrep "$REIN_SH" 'exit "\$reset_rc"'; ck "[재설치] 지우기가 실패하면 거기서 끝낸다" $? "반쯤 지운 위에 설치가 얹힌다"
  # ⚠앵커를 `BOOTSTRAP_URL" -o` 로 두면 안 된다 — 받는 자리가 재시도 함수로 감싸이는 순간 사라지고,
  #   변수 정의 줄(`BOOTSTRAP_URL="…"`)에도 걸려 순서 판정이 뒤집힌다. 부르는 자리를 앵커로 쓴다.
  awk '/reset_rc. != .0./{a=NR} /download_with_retry "\$BOOTSTRAP_URL"/{b=NR} END{exit !(a&&b&&a<b)}' "$REIN_SH"
  ck "[재설치] 실패 판정이 설치보다 먼저" $? "판정 전에 설치를 시작한다"
  # 사이트에서 새로 받는다 — 남아 있던 옛 사본으로 지우면 옛 규칙이 돈다.
  codegrep "$REIN_SH" 'download_with_retry "\$RESET_URL"'; ck "[재설치] 지우는 도구를 새로 받는다" $? "옛 사본을 쓴다"
  codegrep "$REIN_SH" 'download_with_retry "\$BOOTSTRAP_URL"'; ck "[재설치] 설치 도우미를 새로 받는다" $? "옛 사본을 쓴다"
  # ★감싼 함수가 **실제로 사이트에서 받는지**도 잰다 — 이름만 바꾸고 옛 사본을 쓰면 위 두 축은 초록이다.
  codegrep "$REIN_SH" 'curl -fsSL "\$1" -o "\$2"'; ck "[재설치] 그 함수가 주소에서 받는다" $? "함수 이름만 그렇고 안에서 옛 사본을 쓴다"
  codegrep "$REIN_SH" 'for i in 1 2 3'; ck "[재설치] 받기는 그 자리에서 다시 해 본다" $? "한 번 끊기면 창을 닫게 만든다"
  # 로그인은 건드리지 않는다(운영자 확정 2026-09-08) — 재설치 입구에 purge 옵션을 노출하지 않는다.
  no_code "$REIN_SH" 'purge-login'; ck "[재설치] 입구에 로그인 삭제를 안 내놓는다" $? "사용자 경로에 노출됐다"
  # 두 번 묻지 않는다 — 묻는 일은 지우는 도구가 한다.
  no_code "$REIN_SH" 'read -r'; ck "[재설치] 두 번 묻지 않는다" $? "같은 것을 두 번 묻는다"
else
  sk "[재설치] 맥 진입점" "reinstall.sh 가 없다"
fi
if [ -f "$REIN_PS" ]; then
  [ "$(head -c3 "$REIN_PS" | xxd -p)" = "efbbbf" ]; ck "[재설치] ps1 = UTF-8 with BOM" $? "한글이 깨진다"
  codegrep "$REIN_PS" '\$resetRc'; ck "[재설치] ps1 지우기 결과를 받는다" $? "결과를 안 본다"
  codegrep "$REIN_PS" 'exit \$resetRc'; ck "[재설치] ps1 지우기가 실패하면 거기서 끝낸다" $? "반쯤 지운 위에 설치가 얹힌다"
  awk '/resetRc -ne 0/{a=NR} /bootstrap\.ps1/{if(!b)b=NR} END{exit !(a&&b&&a<b)}' "$REIN_PS"
  ck "[재설치] ps1 실패 판정이 설치보다 먼저" $? "판정 전에 설치를 시작한다"
  no_code "$REIN_PS" 'PurgeLogin'; ck "[재설치] ps1 입구에 로그인 삭제를 안 내놓는다" $? "사용자 경로에 노출됐다"
  no_code "$REIN_PS" 'Read-Host'; ck "[재설치] ps1 두 번 묻지 않는다" $? "같은 것을 두 번 묻는다"
else
  sk "[재설치] 윈 진입점" "reinstall.ps1 이 없다"
fi

echo "== 제거기(윈) 갈래 수정 (2026-09-08) =="
if [ -f "$RESET" ]; then
  # 🔴앞 판이 실제로 한 일: ~/.claude 폴더와 .claude.json 을 통째로 지웠다.
  #   그 한 줄이 로그인·대화기록·남의 설정 칸을 한꺼번에 날렸다. 되돌아가면 적색이 된다.
  no_code "$RESET" 'Remove-Item \$ClaudeDir|Drop .*\$ClaudeDir|\$ClaudeDir, |, \$ClaudeDir'
  ck "[제거] 클로드 폴더를 통째로 안 지운다" $? "로그인·대화기록·남의 설정이 함께 날아간다"
  no_code "$RESET" 'Drop .*\$ClaudeJson|Remove-Item \$ClaudeJson'
  ck "[제거] 클로드 설정 파일을 통째로 안 지운다" $? "남의 칸까지 지운다"
  codegrep "$RESET" 'Remove-JsonKey \$ClaudeJson'; ck "[제거] 우리 칸만 뺀다" $? "외과적 제거가 없다"
  # 기본값 = 로그인 보존(운영자 확정 2026-09-08). 스위치를 안 붙이면 안 지운다.
  codegrep "$RESET" '\[switch\]\$PurgeLogin'; ck "[제거] 로그인 삭제는 옵션이다" $? "기본으로 지운다"
  codegrep "$RESET" 'auth logout'; ck "[제거] 공식 로그아웃을 먼저 쓴다" $? "자리를 직접 파헤친다"
  # 순서 셋 — 맥과 같은 형태(그 명령이 지울 대상 안에 있다).
  #   ⚠`$` 앵커를 쓰지 마라 — 이 파일은 CRLF 라서 줄 끝에 \r 이 붙어 있어 안 맞는다(자기신고 2026-09-08:
  #   순서가 맞는데도 적색이 떴다). CRLF 는 PowerShell 5.1 때문에 일부러 그렇게 두는 것이다.
  awk '/Invoke-PurgeLoginFirst[\r]*$/{if(!p)p=NR} /Drop .클로드 실행 파일./{c=NR} END{exit !(p&&c&&p<c)}' "$RESET"
  ck "[제거] 로그인 처리가 클로드 삭제보다 먼저" $? "로그아웃 명령이 먼저 사라진다"
  awk '/daemon uninstall/{d=NR} /Drop .cys 프로그램. \$CysDir/{a=NR} END{exit !(d&&a&&d<a)}' "$RESET"
  ck "[제거] daemon uninstall 이 앱 삭제보다 먼저" $? "죽은 등록이 남는다"
  awk '/Remove-OurHooks/{if(!h)h=NR} /Drop .cys 프로그램. \$CysDir/{a=NR} END{exit !(h&&a&&h<a)}' "$RESET"
  ck "[제거] 훅 제거가 앱 삭제보다 먼저" $? "훅을 고칠 수단이 먼저 사라진다"
  # 사용자 Path 만 건드린다 — 시스템 Path 는 관리자 권한이 필요하고 우리 것이 아니다.
  codegrep "$RESET" "SetEnvironmentVariable\('Path', .*'User'\)"; ck "[제거] 사용자 경로만 되돌린다" $? "역연산이 없다"
  no_code "$RESET" "SetEnvironmentVariable\('Path'[^)]*'Machine'\)"; ck "[제거] 시스템 경로는 안 건드린다" $? "시스템 PATH 를 고친다"
  codegrep "$RESET" 'KeptFail'; ck "[제거] 못 지운 것을 센다" $? "실패를 안 센다"
  codegrep "$RESET" 'return 7'; ck "[제거] 못 지운 것이 있으면 실패로 끝낸다" $? "반쯤 지운 위에 설치가 얹힌다"
fi

echo "== 제거기(맥) 수정 =="
if [ -f "$RESET_SH" ]; then
  bash -n "$RESET_SH" 2>/dev/null; ck "[제거] bash -n 통과" $? "문법 오류"
  # ★등록을 떼는 명령이 프로그램 **안에** 있다. 프로그램을 먼저 지우면 뗄 수단이 사라진다.
  awk '/daemon uninstall/{d=NR} /drop_dir "\$CYS_APP"/{a=NR} END{exit !(d && a && d < a)}' "$RESET_SH"
  ck "[제거] daemon uninstall 이 앱 삭제보다 먼저" $? "앱을 먼저 지우면 죽은 등록이 남는다"
  # ★훅을 고칠 파이썬도 그 프로그램 안에 있다(깨끗한 맥엔 다른 파이썬이 없다).
  awk '/strip_hooks "\$HOME\/.claude\/settings.json"/{h=NR} /drop_dir "\$CYS_APP"/{a=NR} END{exit !(h && a && h < a)}' "$RESET_SH"
  ck "[제거] 훅 제거가 앱 삭제보다 먼저" $? "앱을 먼저 지우면 훅을 고칠 도구가 사라진다"
  # ★로그아웃 명령도 클로드 **안에** 있다.
  awk '/purge_login_first$/{p=NR} /drop_file "\$HOME\/.local\/bin\/claude"/{c=NR} END{exit !(p && c && p < c)}' "$RESET_SH"
  ck "[제거] 로그인 처리가 클로드 삭제보다 먼저" $? "클로드를 먼저 지우면 로그아웃 명령이 사라진다"
  # ★기본값 = 로그인 보존. 되돌리면 적색.
  grep -q 'PURGE_LOGIN=0' "$RESET_SH"; ck "[제거] 로그인 보존이 기본값" $? "기본으로 로그인을 지운다"
  grep -q 'claude auth logout\|auth logout' "$RESET_SH"; ck "[제거] 공식 로그아웃을 먼저 쓴다" $? "자리를 직접 파헤친다"
  # ★남의 파일은 지우지 않는다 — 통째 삭제 대상에 들어가면 적색.
  no_code "$RESET_SH" 'drop_dir "\$HOME/\.claude"|drop_file "\$HOME/\.claude\.json"'
  ck "[제거] 클로드 설정·기록을 통째로 안 지운다" $? "손대지 않기로 한 것을 지운다"
  # ★사람에게 한 번 묻는다(--yes 를 안 붙였을 때).
  grep -q '지웁니다' "$RESET_SH"; ck "[제거] 지우기 전에 한 번 묻는다" $? "묻지 않고 지운다"
  # ★못 지운 것이 있으면 사실대로 말하고 0 이 아닌 값으로 끝낸다(재설치가 그 위에 얹히면 안 된다).
  grep -q 'KEPT_FAIL' "$RESET_SH" && grep -q 'return 7' "$RESET_SH"
  ck "[제거] 못 지운 것이 있으면 실패로 끝낸다" $? "반쯤 지운 위에 설치가 얹힌다"
else
  sk "[제거] 맥 제거기 검사" "reset-clean.sh 가 없다"
fi

echo "== [3/10] 로그인 재판정 (2026-09-08 운영자 실기) =="
# 🔴[1/10] 의 로그인 판정은 **클로드가 없던 시점**의 것이다. 지우고 다시 까는 길에서는
#   그 시점에 클로드가 방금 지워져 있어 판정이 「모름」이 되고, [2/10] 이 다시 깐 뒤에도
#   그 옛 판정 그대로 [3/10] 이 브라우저를 연다 — 로그인은 멀쩡히 남아 있는데.
#   ⇒ 브라우저를 열기 전에 한 번 다시 보는 줄이 **있어야** 한다. 되돌리면 여기서 적색.
codegrep "$SH" 'S1_LOGGED_IN" != "1" \] && claude_has_auth_cmd'
ck "[3/10] sh 브라우저 전 재판정" $? "클로드를 새로 깐 뒤에도 옛 판정으로 로그인 화면을 연다"
# ⚠축이 **한 줄 전체를 글자로** 박고 있었다 — 그 줄에 안전 가드를 하나 더 넣자 적색이 났다.
#   재는 성질은 「재판정을 한다」이지 「그 줄이 정확히 이 글자다」가 아니다 ⇒ 두 조각으로 나눠 잰다.
codegrep "$PS" 'not \$script:LoggedIn\) -and'
ck "[3/10] ps1 브라우저 전 재판정" $? "같음(윈도우) — 사고가 난 바로 그 자리다"
codegrep "$PS" '\(Test-ClaudeAuthCmd\)\) \{'
ck "[3/10] ps1 재판정이 능력 확인을 통과할 때만 묻는다" $? "낡은 판본에 대고 물어 그 자리에서 멈춘다"
# ★재판정은 **능력 확인을 통과한 뒤에만** 묻는다 — 낡은 판본에서 auth status 는 질문으로 나간다.
awk '/claude_has_auth_cmd; then/{p=NR} /claude auth login/{l=NR} END{exit !(p && l && p < l)}' "$SH"
ck "[3/10] sh 재판정이 로그인 열기보다 먼저" $? "브라우저를 연 뒤에 묻는다 — 이미 늦었다"
awk '/Test-ClaudeAuthCmd\)\) \{/{p=NR} /claude auth login/{l=NR} END{exit !(p && l && p < l)}' "$PS"
ck "[3/10] ps1 재판정이 로그인 열기보다 먼저" $? "같음"

echo "== 남의 파일을 읽는 인코딩 (러너 34209137309 이 실물에서 잡음) =="
# 🔴`Get-Content -Raw` 는 인코딩을 안 적으면 5.1 에서 ANSI 로 읽는다. 남의 .claude.json 은 UTF-8 이다.
#   ⇒ 한글이 깨진 채로 다시 쓰인다 = **칸 하나 빼려다 남의 설정 파일을 훼손한다.**
#   형제 파일 bootstrap.ps1 은 같은 자리에서 이미 -Encoding UTF8 을 쓰고 있었다(깔 때는 맞고 지울 때는 틀렸다).
no_code "$RESET" 'Get-Content .*-Raw'
ck "[인코딩] ps1 제거기에 인코딩 없는 Get-Content 0건" $? "남의 한글이 깨진 채로 다시 쓰인다"
codegrep "$RESET" 'Read-TextUtf8'; ck "[인코딩] UTF-8 로 읽는 자리가 있다" $? "읽는 자리가 그 기계 기본값을 탄다"
codegrep "$RESET" 'UTF8Encoding\(\$false, \$true\)'
ck "[인코딩] UTF-8 이 아니면 걸러 낸다(throwOnInvalidBytes)" $? "아닌 것을 조용히 뭉갠다"
codegrep "$RESET" 'Write-JsonChecked'; ck "[인코딩] 쓰기에 왕복 자기검증" $? "왕복 손실을 못 보고 덮어쓴다"
codegrep "$RESET_SH" 'open\(p,encoding="utf-8"\)'; ck "[인코딩] sh 제거기의 파이썬도 UTF-8" $? "로케일 따라 남의 파일이 깨진다"
codegrep "$RESET_SH" 'sys.stdout.buffer.write'; ck "[인코딩] sh 제거기가 바이트로 내보낸다" $? "화면 인코딩을 타고 깨진다"

echo "== 지우는 범위 (교차 검토 [3] BLOCK) =="
# 🔴이름이 스친다고 우리 것이 아니다. `*cys*` 로 잡히는 것을 전부 지우면 `macys-backup` 같은
#   남의 작업이 영구 삭제된다. 우리 것의 근거는 이름이 아니라 그 작업이 무엇을 실행하는가다.
no_code "$RESET" "TaskName '\*cys\*'"
ck "[범위] 스케줄러를 느슨한 이름으로 안 지운다" $? "남의 작업까지 지운다"
codegrep "$RESET" 'Get-CysTasks'; ck "[범위] 우리 작업만 골라내는 자리가 있다" $? "고르는 단계가 없다"
codegrep "$RESET" '\$a.Execute'; ck "[범위] 무엇을 실행하는지로 판정한다" $? "이름만 보고 지운다"

echo "== 로그인 자리 판정 (공식 문서 2026-09-08) =="
# ★자리는 고정이 아니다 — CLAUDE_CONFIG_DIR 이 서면 로그인 파일은 그 폴더 아래로 간다.
#   그것을 안 보면 「[있음] 로그인」이 **다른 파일을 보고 하는 말**이 된다.
if [ -f "$RESET_SH" ]; then
  codegrep "$RESET_SH" 'CLAUDE_CONFIG_DIR'
  ck "[로그인자리] sh 가 CLAUDE_CONFIG_DIR 을 본다" $? "클로드가 보는 자리와 다른 자리를 보고 말한다"
  codegrep "$RESET_SH" 'CYS_CRED_FILE'
  ck "[로그인자리] sh 가 자비스 창 로그인을 알린다" $? "~/.cys 를 지우며 그 안의 로그인을 말없이 지운다"
fi
codegrep "$RESET" 'CLAUDE_CONFIG_DIR'
ck "[로그인자리] ps1 이 CLAUDE_CONFIG_DIR 을 본다" $? "클로드가 보는 자리와 다른 자리를 보고 말한다"
codegrep "$RESET" 'CysCredFile'
ck "[로그인자리] ps1 이 자비스 창 로그인을 알린다" $? "~\.cys 를 지우며 그 안의 로그인을 말없이 지운다"

echo "== ps1 괄호 균형 (개발기에서 파싱 사고를 앞당겨 잡는다 · 2026-09-10 신설) =="
# 🔴이 축이 왜 생겼나: 개발기에 pwsh 가 없어 `.ps1` 문법 확인이 **러너에만** 있었다. 그래서 인라인
#   `if` 의 닫는 중괄호 하나를 빠뜨린 판이 push 됐고, 5.1 은 **파일 전체를 파싱하지 못했다**
#   (MissingEndCurlyBrace) — 설치기가 한마디도 못 남기고 죽는 실패다. 러너가 2분 뒤에 잡아 줬지만
#   ★그 2분은 매번 든다. 결정론으로 잴 수 있는 갈래는 개발기로 당긴다.
# 🔴2026-09-11 한 겹 더 — **따옴표가 그 줄 안에서 닫히는지**도 잰다. 치환하다 남은 작은따옴표
#   한 글자(`}\'`)가 그대로 나갔고 괄호는 멀쩡해 이 축이 초록이었다. 러너 Windows 가 파싱에서
#   죽고서야 보였다. ★검사기가 「안 닫힌 채 줄이 끝나는 것」을 조용히 닫힌 것으로 세고 있었다.
# ⚠이 축은 파서가 아니다 — 통과가 「문법이 옳다」를 뜻하지 않는다(러너 검증을 대체하지 않는다).
PSBAL="$DIR/../tests/ps-balance.py"
if [ -f "$PSBAL" ] && command -v python3 >/dev/null 2>&1; then
  python3 "$PSBAL" "$PS" "$RESET" "$REIN_PS" >/dev/null 2>&1; rc=$?
  ck "[문법] ps1 셋의 괄호·따옴표가 맞는다" "$rc" "5.1 이 이 파일을 통째로 파싱하지 못한다 (python3 tests/ps-balance.py install-master/*.ps1 로 자세히)"
else
  sk "[문법] ps1 괄호·따옴표 균형" "대조 도구가 없다"
fi

echo "== v0.3.8 실기 수리 (2026-09-10 · 막힘 R1~R7) =="
# 🔴🔴이 블록을 쓰면서 이 파일이 이미 아는 함정에 그대로 빠졌다(자기신고 · 뮤턴트가 잡았다):
#   `ck "… $(basename …)" $?` 는 **`$?` 가 basename 의 성공을 잰다** — 인자 확장 중의 명령치환이
#   그 자리에서 `$?` 를 0 으로 덮는다. ⇒ 축 여섯이 죽은 채 초록이었다(함수 이름만 바꿔 죽여도 통과).
#   ★규칙: **ck 인자 안에 `$( )` 를 두려면 rc 를 그 앞 줄에서 변수로 잡아라.** 예외 없다.
#   그리고 근거 칸에 쓰는 `$GREP_WHY`·`why_or_count` 도 같은 이유로 **먼저 변수에 담는다**.
# ── ⓐ 「같은 줄」 0건 (역방향) ────────────────────────────────────
# 🔴이 축이 재는 것 = **사람에게 보이는 글에 「같은 줄」이 없다.** 그 문구는 2026-09-10 실사용
#   검증에서 막힘으로 확정됐다(「줄」이 무엇인지 모르고, 그 명령이 화면에 없었다).
# ⚠주석은 세지 않는다 — 「그 문구를 쓰지 마라」를 적은 주석까지 세면 규칙을 적을 수 없어진다
#   (이 파일이 이미 아는 함정: 어휘 축은 주석을 함께 센다 ⇒ 부정형 축은 `no_code` 로만).
for f in "${INSTALL_SCRIPTS[@]}" "$RESET" "$RESET_SH"; do
  [ -f "$f" ] || { sk "[다시] $(basename "$f") 「같은 줄」 0건" "파일 없음"; continue; }
  no_code "$f" '같은 (한 )?줄'; rc=$?; w="$GREP_WHY"
  ck "[다시] $(basename "$f") 「같은 줄」 0건" "$rc" "사람에게 「줄」을 말한다(${w})"
done
# ── ⓐ-2 대신 무엇을 인쇄하는가 ───────────────────────────────────
# ★안 쓰는 것을 재는 것으로 끝내면 **아무 말도 안 하는 판**이 통과한다. 무엇을 대신 하는지도 잰다.
# ⚠「그 이름이 파일 어딘가에 있다」로 재면 **함수 이름만 바꿔 죽여도 초록**이다(뮤턴트 실측
#   2026-09-10: Show-RerunHow → Show-RerunHow-Disabled 로 고쳤는데 축이 안 붉어졌다).
#   ⇒ 재는 성질을 둘로 가른다 — ⑴그 함수가 **정의돼 있는가** ⑵**실제로 불리는가**.
#     정의만 있고 아무도 안 부르면 화면에는 아무 말도 안 나온다. 그것이 이 축이 막는 실패다.
for f in "$PS" "$RESET" "$REIN_PS"; do
  [ -f "$f" ] || continue
  codegrep "$f" 'function Show-RerunHow \{'; rc=$?; b="$(basename "$f")"
  ck "[다시] $b 재실행 안내가 정의돼 있다" "$rc" "문구만 지우고 방법을 안 준다"
  # ⚠부르는 자리를 셀 때 **정의 줄까지 세면** 정의만 남기고 호출을 지운 판이 통과한다.
  #   ⇒ 정의 줄을 뺀 뒤에 센다. 남은 것이 하나라도 있어야 화면에 그 안내가 나온다.
  count_from_or_fail 'Show-RerunHow' -- sh -c "grep -vE '^[[:space:]]*#' \"\$1\" | grep -v 'function Show-RerunHow'" _ "$f"; rc=$?
  n="$COUNT_N"; w="$(why_or_count)"
  [ "$rc" -eq 0 ] && [ "$n" -ge 1 ]
  ck "[다시] $b 그 안내를 실제로 부른다" $? "정의만 있고 아무도 안 부른다($w)"
done
for f in "$SH" "$RESET_SH" "$REIN_SH"; do
  [ -f "$f" ] || continue
  codegrep "$f" '^show_rerun_how\(\) \{'; rc=$?; b="$(basename "$f")"
  ck "[다시] $b 재실행 안내가 정의돼 있다" "$rc" "같음"
  count_from_or_fail 'show_rerun_how' -- sh -c "grep -vE '^[[:space:]]*#' \"\$1\" | grep -v '^show_rerun_how()'" _ "$f"; rc=$?
  n="$COUNT_N"; w="$(why_or_count)"
  [ "$rc" -eq 0 ] && [ "$n" -ge 1 ]
  ck "[다시] $b 그 안내를 실제로 부른다" $? "정의만 있고 아무도 안 부른다($w)"
done
# 창 여는 법·복사·붙여넣기 3단계가 실제로 적혀 있는가(안내라고 이름만 붙인 빈 함수 방지)
for f in "$PS" "$RESET" "$REIN_PS"; do
  [ -f "$f" ] || continue
  codegrep "$f" 'powershell 이라고 치'; rc=$?
  ck "[다시] $(basename "$f") 창 여는 법을 적는다" "$rc" "명령만 주고 어디에 붙일지 안 적는다"
done
for f in "$SH" "$RESET_SH" "$REIN_SH"; do
  [ -f "$f" ] || continue
  codegrep "$f" '터미널 이라고 치'; rc=$?
  ck "[다시] $(basename "$f") 창 여는 법을 적는다" "$rc" "같음"
done
# ★인쇄할 명령이 **들어온 길**로 갈리는가 — 재설치로 들어왔는데 지우기 한 줄을 인쇄하면
#   사람은 지우기만 되풀이하고 재설치에 못 닿는다(그 고리가 이 축이 막는 것이다).
codegrep "$REIN_PS"  'JARVIS_ENTRY'; ck "[다시] 재설치(윈)가 들어온 길을 알려 준다" $? "안쪽이 자기 한 줄을 인쇄한다"
codegrep "$REIN_SH"  'JARVIS_ENTRY'; ck "[다시] 재설치(맥)가 들어온 길을 알려 준다" $? "같음"
codegrep "$RESET"    'JARVIS_ENTRY'; ck "[다시] 제거기(윈)가 그 길을 읽는다" $? "같음"
codegrep "$RESET_SH" 'JARVIS_ENTRY'; ck "[다시] 제거기(맥)가 그 길을 읽는다" $? "같음"
codegrep "$PS"       'JARVIS_ENTRY'; ck "[다시] 설치기(윈)가 그 길을 읽는다" $? "같음"
codegrep "$SH"       'JARVIS_ENTRY'; ck "[다시] 설치기(맥)가 그 길을 읽는다" $? "같음"
# ★인쇄하는 명령이 **머리글의 배포 한 줄과 글자까지 같은가** — 갈리면 화면에서 복사한 것이
#   사이트의 것과 달라진다(이 파일이 이미 아는 형태: 목록이 둘이면 한쪽이 뒤처진다).
for f in "$PS" "$RESET" "$REIN_PS"; do
  [ -f "$f" ] || continue
  b="$(basename "$f")"
  n="$(grep -c "GetFolderPath('UserProfile')" "$f")"
  [ "${n:-0}" -ge 2 ]; rc=$?
  ck "[다시] $b 배포 한 줄이 머리글과 본문 두 곳에 같이 있다" "$rc" "한 곳뿐이라 대조할 짝이 없다(실측 ${n:-0}곳)"
  # 두 곳의 글자가 같은가 — **가리키는 대상별로** 유일해야 한다.
  #   ⚠한 파일에 한 줄만 있다고 가정하면 안 된다: 설치기는 자기 한 줄과 **재설치 한 줄을 함께** 싣는다
  #   (들어온 길에 따라 골라 인쇄하기 때문이다). 그래서 대상별로 가른 뒤에 유일성을 잰다.
  for t in bootstrap reset-clean reinstall; do
    u="$(grep -o "powershell -NoProfile -ExecutionPolicy Bypass -Command .*/install/$t\.ps1 .*" "$f" | sort -u | wc -l | tr -d ' ')"
    [ "${u:-0}" -le 1 ]; rc=$?
    ck "[다시] $b $t 한 줄이 파일 안에서 하나다" "$rc" "머리글과 본문이 갈렸다(유일값 ${u:-0}가지)"
  done
done
for f in "$SH" "$REIN_SH"; do
  [ -f "$f" ] || continue
  b="$(basename "$f")"
  u="$(grep -o 'curl -fsSL https://jarvis.godmeyou.kr/install/[a-z.]*\.sh -o "\$HOME/[a-z-]*\.sh" && bash "\$HOME/[a-z-]*\.sh"' "$f" | sort -u | wc -l | tr -d ' ')"
  [ "${u:-0}" -ge 1 ]; rc=$?
  ck "[다시] $b 배포 한 줄이 본문에 그대로 있다" "$rc" "인쇄할 명령이 없다"
  # 대상별 유일성 — 맥도 같은 성질을 잰다(설치기는 자기 한 줄과 재설치 한 줄을 함께 싣는다).
  for t in bootstrap reset-clean reinstall; do
    # ⚠셸 대입문의 닫는 작은따옴표가 줄 끝에 붙는다 — 그것까지 세면 「같은 줄이 둘」이 된다(실측).
    u="$(grep -o "curl -fsSL https://jarvis.godmeyou.kr/install/$t\.sh .*" "$f" | sed "s/'\$//" | sort -u | wc -l | tr -d ' ')"
    [ "${u:-0}" -le 1 ]; rc=$?
    ck "[다시] $b $t 한 줄이 파일 안에서 하나다" "$rc" "머리글과 본문이 갈렸다(유일값 ${u:-0}가지)"
  done
done

# ── ⓑ R1 자리 기준 종료 (이름으로 끄면 고아 자식이 안 꺼진다) ────
codegrep "$RESET" 'function Get-ProcsUnder'; ck "[R1] 윈 자리 기준으로 프로세스를 찾는다" $? "이름 세 개만 끈다 — 데몬이 띄운 자식이 폴더를 붙든다"
# ⚠축을 `$pr.Path` 로만 두면 안 된다 — **인쇄하는 자리에도 그 글자가 있어서**, 판정을 이름으로
#   바꿔치기해도 초록이었다(뮤턴트 실측 2026-09-10). 재는 것은 「무엇을 비교 대상으로 삼는가」이므로
#   **판정에 쓰는 대입문 그 줄**을 잰다.
codegrep "$RESET" '\$path = \$pr\.Path'; ck "[R1] 그 판정이 실행 파일 자리다" $? "이름으로 되돌아갔다"
codegrep "$RESET" 'StartsWith\(\$pre'; ck "[R1] 그 자리 안인지를 접두로 가른다" $? "자리를 구했는데 비교를 안 한다"
codegrep "$RESET" 'function Stop-CysProcesses'; ck "[R1] 끄고 다시 세는 함수가 있다" $? "보냈다를 꺼졌다로 읽는다"
codegrep "$RESET" 'function Write-AliveProcs'; ck "[R1] 남은 것의 번호·자리를 인쇄한다" $? "무엇을 끝내야 하는지 알 길이 없다"
codegrep "$RESET_SH" 'procs_under()'; ck "[R1] 맥 짝이 있다" $? "두 OS 가 갈린다"
codegrep "$RESET_SH" 'ps -Ao pid=,comm='; ck "[R1] 맥도 실행 파일 자리로 본다" $? "이름만 본다"
# 🔴2026-09-10 **뒤집었다**(1차 검토 BLOCK ② 채택) — 앞 판은 「명령줄 축(`pgrep -f`)도 함께 본다」를
#   **요구**했다. 그 축이 바로 결함이었다: 명령줄만 보고 죽이므로 편집기를 `~/.cys/…` 인자와 함께
#   열어 둔 것만으로 그 편집기가 KILL 을 받고, 경로를 정규식으로 읽어 `~/acys/…` 같은 남의 자리도
#   걸린다. ⇒ **그 축이 없어야 한다**(역방향). 윈도우와 같은 잣대(실행 파일 경로)만 남는다.
no_code "$RESET_SH" 'pgrep -f'; rc=$?; w="$GREP_WHY"
ck "[R1] 맥이 명령줄로 죽이지 않는다" "$rc" "명령줄 축이 돌아왔다 — 남의 프로그램을 죽인다(${w})"
# 🔴우리 자신과 **우리를 부른 쪽**은 죽이지 않는다 — 재설치가 안에서 이 스크립트를 부르므로 부모를
#   죽이면 지우기 도중에 재설치가 사라지고 **반쯤 지운 기계**가 남는다(한 트랜잭션 규율이 깨진다).
codegrep "$RESET_SH" 'pid" = "\${PPID:-0}"'; ck "[R1] 맥이 부른 쪽을 죽이지 않는다" $? "지우기 도중에 재설치가 통째로 사라진다"
codegrep "$RESET"    'pr\.Id -eq \$PID'; ck "[R1] 윈이 자기 자신을 세지 않는다" $? "자기를 끄려 든다"
# ── ⓑ R2 못 지운 까닭을 삼키지 않는다 ───────────────────────────
codegrep "$RESET" 'function Add-TreeFailWhy'; ck "[R2] 윈 실패 사유를 담는다" $? "catch { } 로 전부 삼킨다"
codegrep "$RESET" 'function Write-TreeFailWhy'; ck "[R2] 그것을 인쇄한다" $? "담아 두고 아무도 안 읽는다"
codegrep "$RESET" 'catch \{ Add-TreeFailWhy \$x\.FullName'; ck "[R2] 항목별 예외를 담는다" $? "개수만 세고 무엇인지는 버린다"
codegrep "$RESET" 'TreeFailWhy\.Count -ge 5'; ck "[R2] 인쇄를 최대 5개로 끊는다" $? "화면이 넘쳐 앞 안내가 밀려 사라진다"
codegrep "$RESET_SH" 'RM_WHY='; ck "[R2] 맥도 rm 이 낸 까닭을 받는다" $? "2>/dev/null 로 버린다"
codegrep "$RESET_SH" 'head -5'; ck "[R2] 맥도 최대 5줄로 끊는다" $? "화면이 넘친다"
# ── ⓐ 그 자리에서 다시 해 본다 (창을 닫게 만들지 않는다) ────────
codegrep "$RESET" 'function Reset-PurgeCounters'; ck "[다시] 윈 제거기가 그 자리에서 재시도한다" $? "매번 창을 닫고 명령을 다시 찾게 한다"
codegrep "$RESET" 'tries -lt 3'; ck "[다시] 윈 재시도 상한 3" $? "무한 고리는 막혔다를 영영 말하지 않는다"
codegrep "$RESET_SH" 'tries" -lt 3'; ck "[다시] 맥 재시도 상한 3" $? "같음"

# ── 1차 검토 BLOCK ① 로그인 purge 는 실행당 한 번만 (재시도가 남의 로그인을 반복 삭제했다) ──
# ★열쇠고리에는 같은 이름의 항목이 여럿이고 명령은 한 번에 하나를 지운다 ⇒ 되부르면 하나씩 더 지운다.
#   그 반복을 만든 것은 이 함수가 아니라 **밖의 재시도 루프**였다. 불변식은 함수 자신이 지켜야 한다.
# 🔴🔴2차 검토 N1 로 **범위를 좁혔다**: 한 번만 도는 것은 「열쇠고리 직접 삭제」뿐이다.
#   앞 판은 함수 전체를 막아, 잠긴 로그인 파일을 사람이 풀고 다시 해도 **건너뛰고 전체를 성공**으로
#   끝냈다(거짓 성공). ⇒ 되돌릴 수 없는 것만 막고, 여러 번 해도 결과가 같은 것은 재시도를 허용한다.
codegrep "$RESET_SH" 'LOGIN_KEYCHAIN_DONE=1'; ck "[B1] 맥 열쇠고리 삭제가 한 번만 돈다" $? "부를 때마다 항목이 하나씩 사라진다(비가역)"
codegrep "$RESET_SH" 'LOGIN_KEYCHAIN_DONE" != "1" \]'; ck "[B1] 그 표시를 열쇠고리 갈래에서 본다" $? "표시만 세우고 안 본다"
no_code "$RESET_SH" 'LOGIN_PURGE_DONE'; rc=$?; w="$GREP_WHY"
ck "[B1] 맥에 함수 전체를 막는 옛 표시 0건" "$rc" "재시도가 로그인 처리를 통째로 건너뛴다(${w})"
codegrep "$RESET"    'script:LoginKeychainDone'; ck "[B1] 윈도 같은 이름·같은 자리" $? "한쪽 OS 에만 두면 다음 사람이 「여긴 되불러도 된다」로 읽는다"
# ★끝에서 **다시 봐서** 없을 때만 「지웠다」가 참이다(2차 검토 N1) — 두 OS 모두.
# 🔴🔴3차 검토 N1 로 **재진단의 범위**가 바뀌었다: 파일 하나가 아니라 `login_present` 전체(열쇠고리 포함)다.
#   앞 판 축은 「로그인 파일이 아직 남아 있습니다」 문구만 봤다 ⇒ 열쇠고리에 남는 판이 초록이었다.
# 🔴🔴4차 검토 N1 — 재진단은 이제 **세 상태**다(present/absent/unknown). 「모른다」를 「없다」로 적으면
#   열쇠고리가 잠긴 기계에서 지우기가 **거짓 성공**으로 끝난다.
codegrep "$RESET_SH" '^login_keychain_state\(\) \{'; ck "[B1] 맥이 열쇠고리를 세 상태로 읽는다" $? "조회 실패를 「없음」으로 적어 거짓 성공이 된다"
codegrep "$RESET_SH" '44\) *printf .absent'; ck "[B1] 「없음」의 근거가 errSecItemNotFound(44) 다" $? "어떤 오류든 「없음」이 된다"
codegrep "$RESET_SH" '^login_state\(\) \{'; ck "[B1] 로그인 자국도 세 상태로 답한다" $? "파일 유무만 보고 단정한다"
codegrep "$RESET_SH" '_ls" = "unknown" \]'; ck "[B1] 맥이 끝에서 「모른다」를 실패로 센다" $? "확인 못 한 것을 지웠다고 말한다"
codegrep "$RESET_SH" '_ls" = "present" \]'; ck "[B1] 맥이 끝에서 「남았다」도 실패로 센다" $? "열쇠고리에 남았는데 전체를 성공으로 끝낸다"
codegrep "$RESET_SH" 'dump="\$\(security dump-keychain'; ck "[B1] 셈이 조회 실패를 파이프에 안 삼킨다" $? "dump 가 실패해도 grep -c 가 0 을 찍어 「0개」가 된다"
codegrep "$RESET_SH" '^login_keychain_count\(\) \{'; ck "[B1] 맥이 남은 열쇠고리 항목 수를 셀 수 있다" $? "몇 개 남았는지 못 말한다"
codegrep "$RESET_SH" 'login_keychain_count)"'; ck "[B1] 그 셈을 실제로 부른다" $? "정의만 있고 아무도 안 부른다"
no_code "$RESET_SH" 'PURGE_LOGIN" = "1" \] && \[ -f "\$CRED_FILE" \]'; rc=$?; w="$GREP_WHY"
ck "[B1] 맥에 파일만 보던 옛 재진단 0건" "$rc" "되돌리면 열쇠고리 잔존이 다시 거짓 성공이 된다(${w})"
codegrep "$RESET"    '로그인 파일이 아직 남아 있습니다'; ck "[B1] 윈도 재진단한다" $? "같음"
# ── 1차 검토 BLOCK ② 끄기 전에 무엇을 끄는지 인쇄한다 ──────────────────
codegrep "$RESET_SH" '끄는 중:'; ck "[B2] 맥이 끄는 대상을 인쇄한다" $? "되돌릴 수 없는 강제 종료를 말없이 한다"
codegrep "$RESET"    '돌고 있는 것: '; ck "[B2] 윈도 대상을 인쇄한다" $? "같음"
# ── 1차 검토 REVISE ⑥ 중첩 보존 갈래도 사유를 인쇄한다 ─────────────────
codegrep "$RESET_SH" 'PRUNE_WHY='; ck "[R6b] 맥 중첩 보존이 rm 사유를 모은다" $? "지원한다고 명시한 구성에서 개수만 말한다"
codegrep "$RESET_SH" 'PRUNE_WHY" \| head -5'; ck "[R6b] 그것을 최대 5줄 인쇄한다" $? "모으고 아무도 안 읽는다"
# ── 1차 검토 REVISE ⑦ 두 OS 가 같은 작업 폴더를 본다 ────────────────────
codegrep "$RESET" 'JarvisDir  = if \(\$env:JARVIS_HOME\)'; ck "[R7b] 윈 제거기가 JARVIS_HOME 을 존중한다" $? "사용자 지정 폴더가 남거나 엉뚱한 기본 폴더를 지운다(맥과 갈린다)"

# ── ⓒ R4 폴더 신뢰 씨앗 — 홈까지 심는다 ─────────────────────────
# 🔴2026-09-10 재조준(1차 검토 REVISE ④ 채택) — 씨앗 모양이 바뀌었다. 이제 **자리마다 규칙이 다르다**:
#   작업 폴더 = 우리 자리(만들거나 세운다) · 홈 = 참가자 자리(**없을 때만** 넣고 넣은 것만 적어 둔다).
#   ⇒ 재는 것도 그 둘로 갈린다. 「홈에 심는다」만 재면 **덮어쓰는 판**도 통과한다.
# ⚠적는 자리는 **둘**이다(칸이 아예 없을 때 · 칸은 있는데 우리 키만 없을 때). 하나만 재면
#   다른 하나를 지워도 초록이다 — 그러면 그 갈래로 넣은 키가 기록 없이 남는다(뮤턴트 실측).
count_or_fail "$PS" 'pending \+= ,@\(\$cfg, \$k\)'; rc=$?; n="$COUNT_N"; w="$(why_or_count)"
[ "$rc" -eq 0 ] && [ "$n" -ge 2 ]
ck "[R4] 윈이 홈에 넣은 키를 두 갈래 다 적어 둔다" $? "한 갈래가 기록 없이 넣는다($w)"
# 🔴3차 검토 N4 — 목록에 적는 것은 **쓰고 되읽은 뒤**여야 한다. 앞 판은 쓰기 전에 적어, 되돌린 판에서도
#   목록에 남았다(기록이 사실과 어긋난다). ⇒ 순서를 앵커로 못박는다.
awk '/Write-TextNoBom \$cfg \(\$o \| ConvertTo-Json/{if(!a)a=NR} /foreach \(\$e in \$pending\)/{if(!b)b=NR} END{exit !(a&&b&&a<b)}' "$PS"
ck "[R4] 윈은 쓰고 나서 소유 목록에 적는다" $? "쓰기 전에 적어 두면 되돌린 판에서 기록만 남는다"
codegrep "$PS" "Properties\['hasTrustDialogAccepted'\]"; ck "[R4] 윈이 홈의 기존 값을 보고 비켜 간다" $? "있는 값을 덮는다(원래 false 였던 안전 선택을 뒤집는다)"
codegrep "$SH" 'plutil -extract "projects\.\$HOME\.hasTrustDialogAccepted"'; ck "[R4] 맥도 홈의 기존 값을 보고 비켜 간다" $? "같음"
codegrep "$SH" 'TRUST_SEED_FILE"'; ck "[R4] 맥도 넣은 키를 적어 둔다" $? "기록이 없어 제거기가 추측으로 지운다"
codegrep "$SH" 'case "\$JARVIS_HOME" in'; ck "[R4] 맥이 작업 폴더와 홈을 갈라 다룬다" $? "한 고리로 뭉뚱그리면 홈에도 덮어쓰기가 적용된다"
# ★자가진단 결과와 씨앗은 아무 관계가 없다 — 실패 갈래보다 **앞**에서 심어야 한다
awk '/Set-AllProfiles \| Out-Null/{if(!a)a=NR} /자가진단에서 \$bad 가지가/{b=NR} END{exit !(a&&b&&a<b)}' "$PS"
ck "[R4] 전용 자리 씨앗이 자가진단 실패 갈래보다 먼저" $? "자가진단이 한 가지라도 못 통과하면 씨앗이 영영 안 심긴다"

# ★씨앗도 제거도 **우리 칸 하나만** 다뤄야 한다 — 홈 폴더 칸에는 참가자가 쌓은 값이 함께 있다.
#   ⛔`-Force` 로 객체째 밀어 넣거나 칸째 지우면 그 값이 조용히 사라진다(이 저장소의 규율 위반).
codegrep "$PS" 'hasTrustDialogAccepted -NotePropertyValue \$true -Force'; ck "[R4] 윈 씨앗은 있는 칸에 우리 칸만 세운다" $? "있는 칸을 객체째 덮어 남의 값을 날린다"
# ⚠자리마다 이름이 다르다(작업 폴더는 $JARVIS_HOME · 홈은 $HOME) — 한 변수로 뭉뚱그리던 고리는 뺐다.
codegrep "$SH" 'projects\.\$JARVIS_HOME\.hasTrustDialogAccepted'; ck "[R4] 맥 씨앗도 우리 칸만 세운다" $? "작업 폴더 칸을 객체째 덮는다"
codegrep "$SH" '폴더 이름에 마침표가 있어'; ck "[R4] 맥은 마침표 든 폴더 이름을 사실대로 말한다" $? "못 넘긴 질문을 조용히 지나간다"
# ★제거는 **기록에 적힌 것만** — 경로를 추측해 지우면 그것이 참가자의 값을 지우던 자리다.
codegrep "$RESET"    'function Read-TrustSeedRecord'; ck "[R4] 윈 제거기가 기록을 읽는다" $? "추측으로 지운다"
codegrep "$RESET_SH" 'read_trust_seed_record()';      ck "[R4] 맥 제거기도 기록을 읽는다" $? "같음"
# ★문구가 아니라 **그 문구로 가는 갈림**을 잰다 — 갈림을 죽이면 문구는 남고 동작만 바뀐다(뮤턴트 실측).
codegrep "$RESET" 'TrustSeedRows\.Count -eq 0'; ck "[R4] 윈은 기록이 없으면 안 지운다" $? "기록이 없어도 지우는 길이 열렸다"
codegrep "$RESET"    '우리가 넣은 기록이 없어 손대지 않습니다'; ck "[R4] 윈이 그 사실을 말한다" $? "조용히 지나간다"
codegrep "$RESET_SH" 'z "\$TRUST_SEED_ROWS" \]'; ck "[R4] 맥도 기록이 없으면 안 지운다" $? "기록이 없어도 지우는 길이 열렸다"
codegrep "$RESET_SH" '우리가 넣은 기록이 없어 손대지 않습니다'; ck "[R4] 맥도 그 사실을 말한다" $? "같음"
# ★기록은 자비스 폴더 안에 있다 — **그 폴더를 지우기 전에** 읽어야 한다(순서가 곧 안전장치다).
awk '/Read-TrustSeedRecord/{if(!a)a=NR} /Drop .자비스 작업 폴더./{if(!b)b=NR} END{exit !(a&&b&&a<b)}' "$RESET"
ck "[R4] 윈은 폴더를 지우기 전에 기록을 읽는다" $? "기록이 먼저 사라져 우리 것과 남의 것을 못 가른다"
awk '/read_trust_seed_record/{if(!a)a=NR} /drop_dir "\$JARVIS_HOME"/{if(!b)b=NR} END{exit !(a&&b&&a<b)}' "$RESET_SH"
ck "[R4] 맥도 폴더를 지우기 전에 기록을 읽는다" $? "같음"
codegrep "$RESET"    'function Remove-TrustSeed'; ck "[R4] 윈 제거기가 신뢰 칸을 도로 뺀다" $? "설치기만 심고 제거기는 모른다(자국이 남는다)"
# ★자비스 작업 폴더의 projects 칸은 처음부터 끝까지 우리 자국이다 ⇒ **칸째** 뺀다. 맥판은 원래 그랬고
#   윈도우판은 아무것도 안 뺐다 — 두 OS 가 갈려 있었고 시험 기대까지 갈라 적혀 갈림이 굳어 있었다.
codegrep "$RESET" 'function Remove-ProjectEntry'; ck "[R4] 윈이 자비스 폴더 칸을 칸째 뺀다" $? "설치기가 심은 칸이 남아 다음 진단이 자국으로 센다(맥과 갈린다)"
codegrep "$RESET" 'Remove-ProjectEntry \$ClaudeJson @\(\$JarvisDir'; ck "[R4] 그 대상이 자비스 작업 폴더 2형이다" $? "함수만 있고 안 부른다 · 슬래시 형태를 빠뜨린다"
codegrep "$RESET_SH" "strip_json_key .*'projects\.'"; ck "[R4] 맥도 자비스 폴더 칸을 칸째 뺀다" $? "두 OS 가 갈린다"
codegrep "$RESET_SH" 'strip_trust_seed()';       ck "[R4] 맥 제거기도 같음" $? "같음"
codegrep "$RESET"    "Properties.Remove\('hasTrustDialogAccepted'\)"; ck "[R4] 윈 제거는 칸 하나만 뺀다" $? "칸째 지워 남의 값을 날린다"
codegrep "$RESET_SH" 'plutil -remove "projects\.\$d\.hasTrustDialogAccepted"'; ck "[R4] 맥 제거도 칸 하나만 뺀다" $? "같음"
# ★우리 칸만 있던 자리는 비므로 칸째 지운다 — 빈 칸을 남기면 다음 진단이 자국으로 센다.
codegrep "$RESET"    'PSObject.Properties\).Count -eq 0'; ck "[R4] 윈은 빈 칸을 남기지 않는다" $? "빈 칸이 남아 「설치가 중간에 멈췄다」로 오보한다"
codegrep "$RESET_SH" 'left" = "{}"';                       ck "[R4] 맥도 같음" $? "같음"

# ── 3차 검토 N4 신뢰 기록의 **실패·수명** — 기록과 설정은 함께 서거나 함께 물러난다 ────
# 🔴🔴반쪽만 남으면 그것이 곧 되돌릴 수 없는 자국이다: 키는 들어갔는데 기록이 없으면 제거기가
#   그 키를 「참가자의 것」으로 읽어 **영영 남긴다**(남의 컴퓨터에 우리 자국).
codegrep "$SH" 'TRUST_JOURNAL_FAILED=1'; ck "[N4] 맥이 기록 실패를 따로 든다" $? "실패가 화면 한 줄로 흘러가고 단계는 성공한다"
codegrep "$SH" 'plutil -remove "projects\.\$HOME\.hasTrustDialogAccepted"'; ck "[N4] 맥이 기록 실패 때 넣은 칸을 도로 뺀다" $? "키만 남아 되돌릴 길이 없다"
codegrep "$SH" 'plutil -remove "projects\.\$HOME" "\$cfg"'; ck "[N4] 우리가 만든 칸이면 칸째 되돌린다" $? "빈 칸이 남아 다음 진단이 자국으로 센다"
codegrep "$SH" 'TRUST_JOURNAL_FAILED" = "1" \]'; ck "[N4] 맥이 그 표시를 단계 판정에서 본다" $? "표시만 세우고 안 본다"
no_code "$SH" 'seed_claude_prefs "\$p" \|\| human .* \)\)$'; rc=$?; w="$GREP_WHY"
ck "[N4] 맥 호출자가 실패를 사람 손 한 줄로 바꿔치지 않는다" "$rc" "실패가 늘 성공으로 끝난다(${w})"
codegrep "$PS" 'function Undo-TrustSeed'; ck "[N4] 윈도 되돌리기 손잡이를 가진다" $? "두 OS 가 갈린다"
codegrep "$PS" 'Undo-TrustSeed \$e\[0\] \$e\[1\]'; ck "[N4] 윈이 기록 실패 때 그것을 실제로 부른다" $? "정의만 있고 아무도 안 부른다"
# 🔴🔴4차 검토 BLOCK N4 — **되돌렸다고 말하기 전에 되돌아갔는지 본다.** 앞 판은 두 OS 모두 원복의 종료값을
#   버리고 「도로 뺐습니다」라고 말했다. 디스크가 꽉 차면 기록 쓰기와 되쓰기가 **함께** 실패한다 ⇒
#   **키는 남고 기록은 없는** 상태가 되어 다음 실행이 그 키를 참가자의 것으로 읽는다(영구 추적 누락).
codegrep "$SH" '_verify="\$\(trust_key_state "\$cfg" "projects\.\$HOME\.hasTrustDialogAccepted"\)"'; ck "[N4] 맥이 원복을 되읽어 검증한다" $? "되돌아가지 않았는데 되돌렸다고 말한다"
codegrep "$SH" 'trust seed rollback \$_verify -> journal re-recorded'; ck "[N4] 맥이 원복 실패 때 기록으로 상태를 맞춘다" $? "「키는 남고 기록은 없는」 상태가 남는다"
# 🔴🔴5차 검토 STILL OPEN N4 — **「키가 없다」와 「확인하지 못했다」를 한 칸에 담지 않는다.**
#   `plutil -extract` 의 실패는 두 사건이다(칸이 없다 · 파일을 못 알아본다). 한 칸에 담으면
#   디스크가 꽉 찬 판에서 **키가 남았는데 「도로 뺐습니다」**가 나온다.
codegrep "$SH" '^trust_key_state\(\) \{'; ck "[N4] 맥이 그 판정을 따로 가진다" $? "판정이 호출부에 흩어져 다시 두 상태로 무너진다"
codegrep "$SH" "printf 'unknown"; ck "[N4] 맥 판정에 「확인 불가」 칸이 있다" $? "두 상태뿐이면 확인 못 한 것을 했다고 말한다"
codegrep "$SH" "printf 'absent"; ck "[N4] 맥 판정에 「없음」 칸이 따로 있다" $? "「없음」이 「확인 불가」에 삼켜진다"
# ⚠성함을 묻는 계기를 틀리면 「없는 키」가 전부 「확인 못 함」이 된다 — `plutil -lint` 는 JSON 을 안 받는다(실측).
codegrep "$SH" 'plutil -convert json -o /dev/null "\$cfg"'; ck "[N4] 맥이 파일 성함을 JSON 이 받는 계기로 묻는다" $? "lint 로 물으면 성한 파일도 「확인 불가」가 된다"
no_code "$SH" 'plutil -lint'; rc=$?; w="$GREP_WHY"
ck "[N4] 맥이 JSON 을 안 받는 계기를 쓰지 않는다" "$rc" "성한 설정에도 「확인 불가」가 나온다(${w})"
# ⚠**문구만 재면 그 문구를 부르는 갈래를 꺼도 초록이다**(이 파일에서 일곱 번째) — 단계 한 줄이
#   내부 상태를 **그대로** 말하는지, 즉 호출자가 상태 문구 함수를 부르는지를 못박는다.
count_or_fail "$SH" 'trust_rollback_words'; rc=$?; n="$COUNT_N"; w="$(why_or_count)"
[ "$rc" -eq 0 ] && [ "$n" -ge 3 ]
ck "[N4] 맥 단계 두 자리가 내부 상태를 그대로 말한다" $? "단계가 「도로 뺐고」를 단정한다($w)"
no_code "$SH" '홈 폴더 신뢰 기록을 남기지 못했습니다 — 그 설정은 도로 뺐고'; rc=$?; w="$GREP_WHY"
ck "[N4] 맥에 단정하던 옛 단계 문구 0건" "$rc" "확인하지 못한 것을 했다고 말한다(${w})"
codegrep "$PS" 'Get-TrustRollbackWords'; ck "[N4] 윈 단계도 내부 상태를 그대로 말한다" $? "두 OS 가 갈린다"
codegrep "$PS" "return 'unknown'"; ck "[N4] 윈 되돌리기에 「확인 불가」 칸이 있다" $? "되읽지 못한 것을 「안 빠졌다」로 단정한다"
codegrep "$PS" "return 'kept'"; ck "[N4] 윈 되돌리기에 「아직 있다」 칸이 따로 있다" $? "두 상태로 무너진다"
# ⚠칸이 「있다」는 것만 재면 **되읽기 실패 갈래가 그 칸을 안 쓰도록 바꿔도** 초록이다(칸은 바깥 catch 에도 있다).
#   ⇒ 되읽지 못한 그 자리가 「확인 불가」를 돌려주는지를 **붙어 있는지로** 잰다.
awk '/trust seed rollback UNKNOWN/{a=NR} /return .unknown./{if(a&&NR-a<=2) ok=1} END{exit !ok}' "$PS"
ck "[N4] 윈 되읽기 실패가 바로 「확인 불가」로 간다" $? "되읽지 못한 것을 「아직 있다」로 단정한다"
codegrep "$SH" 'hasTrustDialogAccepted 줄'; ck "[N4] 둘 다 실패하면 손으로 뺄 자리를 적어 준다" $? "조용히 지나가 사람이 되돌릴 길이 없다"
codegrep "$PS" 'trust seed rollback NOT verified'; ck "[N4] 윈도 원복을 되읽어 검증한다" $? "두 OS 가 갈린다"
codegrep "$PS" 'stuck \+= ,\$e'; ck "[N4] 윈이 되돌아가지 않은 것만 목록에 남긴다" $? "무조건 비워 「키는 남고 기록은 없는」 상태가 된다"
# ⚠그 줄이 **있는 것**만 재면 되돌리기 결과와의 연결을 끊어도 초록이다(M28 실측 2026-09-11).
#   ⇒ 「부른 결과($st)를 보고 그때만 남기는지」를 붙어 있는지로 잰다.
awk '/\$st = Undo-TrustSeed \$e\[0\] \$e\[1\]/{a=NR} /if \(\$st -ne .verified.\) \{/{if(a&&NR-a<=2)b=NR} /\$stuck \+= ,\$e/{if(b&&NR-b<=2)ok=1} END{exit !ok}' "$PS"
ck "[N4] 윈이 그 목록을 되돌리기 결과에 매어 둔다" $? "결과를 안 보고 남기거나 비운다"
no_code "$PS" 'foreach \(\$e in \$script:TrustSeeded\) \{ Undo-TrustSeed \$e\[0\] \$e\[1\] \}'; rc=$?; w="$GREP_WHY"
ck "[N4] 결과를 안 보고 부르던 옛 형태 0건" "$rc" "되돌리면 실패가 다시 삼켜진다(${w})"
codegrep "$PS" 'TrustJournalFailed = \$true'; ck "[N4] 윈이 기록 실패를 따로 든다" $? "로그 한 줄만 남기고 성공을 돌려준다"
count_or_fail "$PS" 'if \(\$script:TrustJournalFailed\)'; rc=$?; n="$COUNT_N"; w="$(why_or_count)"
[ "$rc" -eq 0 ] && [ "$n" -ge 2 ]
ck "[N4] 윈이 두 씨앗 자리에서 그 표시를 본다" $? "한 자리만 보면 나머지 판이 성공으로 끝난다($w)"
# ★제거기 쪽 — **우리가 넣은 값과 같을 때만** 뺀다(사람이 손수 false 로 바꾼 것은 그분의 선택이다).
codegrep "$RESET" '\$cur.Value -ne \$true'; ck "[N4] 윈 제거기가 현재값을 설치값과 견준다" $? "사람이 손수 바꾼 값을 되돌린다(맥판과 갈린다)"
codegrep "$RESET_SH" 'true|1|YES|yes\) ;;'; ck "[N4] 맥 제거기도 같은 견줌을 한다" $? "같음"
# ★정리에 실패하면 **기록이 든 폴더를 남긴다** — 지우면 다시 해 볼 근거가 사라진다.
codegrep "$RESET_SH" 'TRUST_CLEANUP_FAIL=\$\(\(TRUST_CLEANUP_FAIL\+1\)\)'; ck "[N4] 맥이 신뢰 칸 정리 실패를 따로 센다" $? "실패해도 작업 폴더를 이어서 지운다"
codegrep "$RESET_SH" 'TRUST_CLEANUP_FAIL:-0\}" -gt 0 \]'; ck "[N4] 맥이 그 셈을 보고 작업 폴더를 남긴다" $? "기록 파일이 사라져 재시도가 영영 건너뛴다"
codegrep "$RESET" 'script:TrustCleanupFail -gt 0'; ck "[N4] 윈도 같은 판정을 한다" $? "두 OS 가 갈린다"
# 🔴🔴셸에서 「센 것을 잃는 자리」는 언제나 파이프다 — 세는 루프는 파이프 밖에 둔다.
codegrep "$RESET_SH" 'EOF_TRUST_ROWS'; ck "[N4] 맥이 신뢰 칸 정리를 파이프 밖에서 돈다" $? "하위 셸에서 센 실패가 부모로 안 돌아온다(작업 폴더가 그대로 지워진다)"
no_code "$RESET_SH" 'TRUST_SEED_ROWS" \| while'; rc=$?; w="$GREP_WHY"
ck "[N4] 파이프로 돌던 옛 형태 0건" "$rc" "되돌리면 실패가 다시 조용히 사라진다(${w})"

# ── 2차 검토 N3 작업 폴더를 재귀로 지우기 전 세 관문 (임의 경로 재귀 삭제 금지) ────────
# 🔴JARVIS_HOME 은 환경변수라 무엇이든 들어온다. 검사 없이 지우면 홈·드라이브 루트가 통째로 사라진다.
#   ⑴절대·실경로 ⑵거부 목록 ⑶**설치기가 놓은 표식** — ⑶이 「좋아 보이지만 남의 폴더」를 막는다.
codegrep "$RESET" 'function Test-SafeJarvisDir'; ck "[N3] 윈이 지우기 전에 자리를 검사한다" $? "임의 경로를 재귀로 지운다(사진·문서가 사라진다)"
# 🔴🔴3차 검토 N3 = **표면 축소**(관리자 결정 2026-09-10). 「나쁜 값 목록」 축을 **이름 관문**으로 바꿨다 —
#   목록은 세 라운드 내내 새 구멍을 냈고(드라이브 루트·UNC·조상 junction·8.3 별칭), 막는 쪽이 늘 뒤늦었다.
#   ⇒ 지워도 되는 자리의 이름을 하나로 못 박으면 그 케이스가 **한꺼번에** 닫힌다.
codegrep "$RESET" 'JarvisHomeBaseName = .install-jarvis.'; ck "[N3] 윈이 지울 폴더 이름을 못박아 둔다" $? "이름 관문이 없다"
codegrep "$RESET" '\$leaf -ne \$JarvisHomeBaseName'; ck "[N3] 윈이 실제 경로의 마지막 칸을 견준다" $? "홈·드라이브 루트·남의 프로젝트가 다시 열린다"
codegrep "$RESET" 'function Get-ReparseAncestor'; ck "[N3] 윈이 조상 링크(junction)를 찾는다" $? "중간 한 칸이 링크면 글자 검사가 전부 빗나간다"
codegrep "$RESET" 'Get-ReparseAncestor \$full'; ck "[N3] 그 링크 검사를 실제로 부른다" $? "정의만 있고 아무도 안 부른다"
codegrep "$RESET" 'function Resolve-RealPath'; ck "[N3] 윈이 8.3 짧은 이름을 다시 푼다" $? "PROGRA~1 같은 별칭에서 이름 관문이 빗나간다"
codegrep "$RESET" 'Get-Item -LiteralPath \$full -Force'; ck "[N3] 그 되풀기가 실물을 본다" $? "GetFullPath 만으로는 8.3 이 안 풀린다"
codegrep "$RESET" 'jarvis-owned'; ck "[N3] 윈이 우리 표식을 확인한다" $? "남의 폴더도 조건만 맞으면 지운다"
codegrep "$RESET_SH" 'safe_jarvis_dir()'; ck "[N3] 맥도 같은 관문" $? "두 OS 가 갈린다"
codegrep "$RESET_SH" 'JARVIS_HOME_BASENAME="install-jarvis"'; ck "[N3] 맥도 이름을 못박아 둔다" $? "두 OS 가 갈린다"
codegrep "$RESET_SH" 'basename "\$c"\)" != "\$JARVIS_HOME_BASENAME"'; ck "[N3] 맥도 실경로의 마지막 칸을 견준다" $? "같음"
codegrep "$RESET_SH" '\.jarvis-owned'; ck "[N3] 맥도 표식을 확인한다" $? "같음"
codegrep "$PS" 'JarvisOwnerFile'; ck "[N3] 윈 설치기가 표식을 놓는다" $? "제거기가 영영 못 지운다(표식이 없으니)"
codegrep "$SH" 'write_owner_mark'; ck "[N3] 맥 설치기도 표식을 놓는다" $? "같음"
# 🔴🔴3차 검토 BLOCK — **설치기가 남의 폴더에도 표식을 써 주면 제거기의 관문은 관문이 아니다.**
#   ⇒ ⑴이름 관문을 **만들기보다 먼저** ⑵비어 있지 않은 남의 폴더는 **채택 금지**(중단·안내).
codegrep "$PS" '작업 폴더로 쓸 수 없는 자리입니다'; ck "[N3] 윈 설치기가 못 쓸 자리를 거부한다" $? "무슨 값이든 만들고 표식까지 써 준다"
# 🔴🔴4차 검토 N3 — **「비어 있으면 채택」을 걷어냈다.** ⑴결정은 「자기가 만든 폴더에만 표식」인데 남이
#   만들어 둔 빈 폴더도 채택했고 ⑵비었는지 세는 방법이 **권한 오류를 빈 목록으로** 읽었다.
#   ⇒ 표식 없는 기존 폴더는 **내용과 무관하게** 거부한다 — 세지 않으면 틀릴 자리도 없다.
codegrep "$PS" '그 폴더는 이미 있는데 우리 표식이 없습니다'; ck "[N3] 윈 설치기가 표식 없는 기존 폴더를 채택하지 않는다" $? "남의 폴더에 소유 표식을 써 줘서 다음 지우기가 통째로 지운다"
# ⚠**문구만 재면 그 문구를 지키는 조건을 꺼도 초록이다**(M31 실측 · r4 의 M15 와 같은 함정 · 이 파일에서 여섯 번째).
#   ⇒ 거부를 **무엇이 지키는가**(표식 판정)를 함께 못박는다.
# ⚠**「그 형태가 어딘가 있다」로는 모자란다** — `$ownerMarkOk` 판정은 표식을 **쓰는 자리**에도 있어서,
#   거부 쪽 조건만 꺼도 축이 그 다른 자리를 보고 초록이었다(M31 2차 실측). ⇒ **붙어 있는지**를 잰다.
# ⚠awk 의 `exit` 는 **END 블록을 거쳐** 나간다 — 본문에서 `exit 0` 을 해도 `END{exit 1}` 이 그것을 덮는다
#   (여기서 한 번 밟았다). ⇒ 깃발을 세우고 END 에서 한 번만 판정한다.
# ⚠**거부가 두 자리에 있다**(기존 폴더 갈래 · 경합 갈래) — 한 자리만 재면 다른 자리를 꺼도 초록이다
#   (M31 3차 실측 2026-09-11: 첫 갈래를 껐는데 축이 경합 갈래를 보고 초록이었다. 이 파일에서 여덟 번째다).
#   ⇒ **짝의 수를 센다.** 어느 쪽을 꺼도 수가 줄어 붉어진다.
awk '/if \(-not \$ownerMarkOk\) \{/{a=NR} /그 폴더는 이미 있는데 우리 표식이 없습니다/{if (a && NR-a<=8) n++} END{exit !(n>=2)}' "$PS"
ck "[N3] 윈의 그 거부를 지키는 것이 표식 판정이다(두 갈래 다)" $? "조건을 꺼도 문구는 남아 축이 못 본다"
# 🔴🔴5차 검토 STILL OPEN N3 — **검사와 만들기 사이는 만드는 행위에게 물어야 사라진다.**
#   `New-Item` 에 `-Force` 를 붙이면 이미 있는 자리에도 성공한다 ⇒ 그 사이에 생긴 남의 폴더에
#   우리 표식을 써 주고, 지우개는 그것을 소유 증거로 읽어 통째로 지운다.
count_or_fail "$PS" 'New-Item -ItemType Directory -Path \$JarvisHome -ErrorAction Stop'; rc=$?; n="$COUNT_N"; w="$(why_or_count)"
[ "$rc" -eq 0 ] && [ "$n" -eq 1 ]
ck "[N3] 윈이 자리 만들기를 한 자리에서만 한다" $? "만드는 자리가 여럿이면 한쪽만 고쳐진다($w)"
no_code "$PS" 'New-Item -ItemType Directory -Path \$JarvisHome -Force'; rc=$?; w="$GREP_WHY"
ck "[N3] 윈 자리 만들기에 -Force 가 없다" "$rc" "이미 있는 남의 자리에도 성공해 표식을 써 준다(${w})"
awk '/if \(New-JarvisHomeNow\) \{/{a=NR} /elseif \(Test-JarvisHomePresent\)/{if (a && NR-a<=6) ok=1} END{exit !ok}' "$PS"
ck "[N3] 윈이 만들기 실패를 경합과 권한으로 가른다" $? "경합을 「권한 없음」으로 말해 사람을 엉뚱한 데로 보낸다"
awk '/Split-Path \$JarvisHome -Leaf\) -ne \$JarvisHomeBaseName/{if(!a)a=NR} /if \(New-JarvisHomeNow\) \{/{if(!b)b=NR} END{exit !(a&&b&&a<b)}' "$PS"
ck "[N3] 윈은 안전 검사를 만들기보다 먼저 한다" $? "만든 뒤에 검사하면 이미 자국을 남긴 뒤다"
codegrep "$SH" '작업 폴더로 쓸 수 없는 자리입니다'; ck "[N3] 맥 설치기도 못 쓸 자리를 거부한다" $? "같음"
# ⚠문구가 있는 것만 재면 **그 문구를 부르는 갈래를 지워도** 초록이다(M15 실측). 세 갈래를 센다.
# ⚠갈래가 늘면 **세는 수도 함께 올려야 한다** — 안 올리면 새 갈래가 옛 수를 채워 주어, 옛 갈래를
#   지워도 축이 초록이다(M15 실측 2026-09-11: 이음줄 갈래가 늘자 이름 관문을 지워도 3이 찼다).
count_or_fail "$SH" 'refuse_jarvis_home "'; rc=$?; n="$COUNT_N"; w="$(why_or_count)"
[ "$rc" -eq 0 ] && [ "$n" -ge 4 ]
ck "[N3] 맥이 네 갈래(이름·이음줄·폴더 아님·표식 없음)에서 다 거부한다" $? "한 갈래가 조용히 통과한다($w)"
codegrep "$SH" '그 폴더는 이미 있는데 우리 표식이 없습니다'; ck "[N3] 맥도 표식 없는 기존 폴더를 채택하지 않는다" $? "같음"
awk '/owner_mark_ok && return 0/{a=NR} /refuse_jarvis_home "그 폴더는 이미 있는데 우리 표식이 없습니다/{if (a && NR-a<=8) ok=1} END{exit !ok}' "$SH"
ck "[N3] 맥의 그 거부를 지키는 것도 표식 판정이다" $? "같음(조건을 꺼도 문구는 남는다)"
no_code "$SH" 'ls -A "\$JARVIS_HOME"'; rc=$?; w="$GREP_WHY"
ck "[N3] 맥도 그 판정에 목록 읽기를 쓰지 않는다" "$rc" "권한 오류가 「비었다」로 읽힌다(${w})"
awk '/basename "\$\{JARVIS_HOME%\/\}"\)" != "\$JARVIS_HOME_BASENAME"/{if(!a)a=NR} /mkdir "\$JARVIS_HOME"/{if(!b)b=NR} END{exit !(a&&b&&a<b)}' "$SH"
ck "[N3] 맥도 안전 검사를 만들기보다 먼저 한다" $? "같음"
# ★맥도 마지막 마디는 `-p` 없이 만든다 — `mkdir -p` 는 이미 있는 폴더에도 성공한다(그 성공이 곧 구멍이다).
codegrep "$SH" 'mkdir "\$JARVIS_HOME" 2>/dev/null'; ck "[N3] 맥이 마지막 마디를 -p 없이 만든다" $? "이미 있는 남의 자리에도 성공해 표식을 써 준다"
# ★부모는 두 OS 가 **미리 만든다**(교차 검토 2차 NEW) — 부모가 없다고 정상 설치가 막히면 안 된다.
codegrep "$SH" 'mkdir -p "\$parent"'; ck "[N3] 맥이 부모 자리를 미리 만든다" $? "부모가 없으면 새 자리 설치가 막힌다"
codegrep "$PS" 'New-Item -ItemType Directory -Path \$parent -Force'; ck "[N3] 윈도 부모 자리를 미리 만든다" $? "같음(두 OS 가 갈린다)"
no_code "$SH" 'mkdir -p "\$JARVIS_HOME"'; rc=$?; w="$GREP_WHY"
ck "[N3] 맥에 -p 로 만들던 옛 형태 0건" "$rc" "검사와 만들기 사이가 그대로 남는다(${w})"
awk '/if make_home_now; then/{a=NR} /elif \[ -e "\$JARVIS_HOME" \] \|\| \[ -L "\$JARVIS_HOME" \]/{if (a && NR-a<=8) ok=1} END{exit !ok}' "$SH"
ck "[N3] 맥도 만들기 실패를 경합과 권한으로 가른다" $? "경합을 「권한 없음」으로 말한다"
codegrep "$SH" '^owner_mark_ok\(\) \{'; ck "[N3] 맥이 「우리 표식인가」를 따로 판정한다" $? "표식 내용을 안 보고 파일 존재만 본다"

echo "== 구판 폴더 이관 — 표식 없는 우리 구판만, 사람이 친 말로만 (2026-09-11 신설) =="
# ★규칙 넷을 함께 잰다: ⑴우리 구판 지문일 때만 ⑵빈 폴더는 지문이 아니다 ⑶못 세면 안 지운다
#   ⑷사람이 「지웁니다」라고 쳐야 지운다(사람이 없으면 묻지도 않는다 = 안 지운다).
codegrep "$SH" '^old_layout_matches\(\) \{'; ck "[구판] 맥이 구판 지문을 따로 판정한다" $? "판정이 흩어져 한쪽만 고쳐진다"
codegrep "$SH" 'entries="\$\(list_home_entries "\$JARVIS_HOME"\)" \|\| return 1'; ck "[구판] 맥은 못 세면 우리 것이라 하지 않는다" $? "열거 실패가 「우리 것뿐」으로 읽힌다"
codegrep "$SH" '\[ "\$sign" = "1" \]'; ck "[구판] 맥은 빈 폴더를 지문으로 세지 않는다" $? "남이 만들어 둔 빈 자리를 지운다"
# 🔴이름이 맞아도 **이음줄이면 지문이 아니다** — 지우는 순간 가리키던 자리 안엣것까지 사라질 수 있다
#   (윈도우 5.1 `Remove-Item -Recurse` 가 실제로 그렇게 판 적이 있고, 그 때문에 지우개가 고쳐졌다).
codegrep "$SH" '\[ -L "\$p" \] && known=0'; ck "[구판] 맥은 이음줄이 섞이면 우리 것이라 하지 않는다" $? "이음줄을 따라 남의 자리 안엣것이 함께 지워질 수 있다"
# 🔴🔴**그 자리 자신이 이음줄인 경우**가 더 위험하다(교차 검토 1차 NEW-1·NEW-2 · 2026-09-11).
#   `[ -d ]`·`Test-Path` 는 이음줄을 **따라가서** 참이 된다 ⇒ 안엣것이 우리 지문처럼 보이고,
#   지우는 순간 **가리키던 자리**가 비워진다(윈 5.1 `Remove-Item -Recurse` 는 junction 을 뚫는다).
#   ⇒ 두 OS 가 채택 갈래의 **첫 물음**으로 이것을 묻는다.
codegrep "$SH" 'if \[ -L "\$JARVIS_HOME" \]; then'; ck "[구판] 맥은 그 자리 자신이 이음줄이면 거부한다" $? "이음줄이 가리키던 남의 자리가 통째로 비워진다"
awk '/^adopt_existing_home\(\) \{/{a=NR} /if \[ -L "\$JARVIS_HOME" \]; then/{if(a&&NR-a<=10)ok=1} END{exit !ok}' "$SH"
ck "[구판] 맥은 그 물음을 채택 갈래 안에서 한다" $? "다른 자리에만 있으면 채택 갈래는 그대로 뚫린다"
codegrep "$PS" 'function Test-JarvisHomeIsLink'; ck "[구판] 윈도 그 자리 자신이 이음줄인지 묻는다" $? "두 OS 가 갈린다"
count_or_fail "$PS" 'if \(Test-JarvisHomeIsLink\) \{'; rc=$?; n="$COUNT_N"; w="$(why_or_count)"
[ "$rc" -eq 0 ] && [ "$n" -ge 2 ]
ck "[구판] 윈은 두 갈래(기존·경합)에서 다 묻는다" $? "한 갈래만 막으면 다른 갈래로 들어온다($w)"
# ★꼬리 빗금은 들어오는 자리에서 한 번에 걷어낸다 — `rm -rf "이음줄/"` 은 이음줄이 아니라 안엣것을 지운다.
codegrep "$SH" 'while \[ "\$\{JARVIS_HOME%/\}" != "\$JARVIS_HOME" \]'; ck "[구판] 맥이 꼬리 빗금을 걷어낸다" $? "빗금 하나로 지우는 대상이 바뀐다"
codegrep "$PS" "EndsWith\('/'\)"; ck "[구판] 윈도 꼬리 빗금을 걷어낸다" $? "같음"
# ★끊어진 이음줄을 「권한 없음」으로 말하지 않는다(두 OS 가 같은 말을 한다).
codegrep "$PS" 'function Test-JarvisHomePresent'; ck "[구판] 윈이 끊어진 이음줄을 있는 것으로 센다" $? "권한 문제로 오분류해 사람을 엉뚱한 데로 보낸다"
# ⚠`ReparsePoint` 라는 글자는 이제 **루트 검사 쪽에도** 있다 ⇒ 「어딘가 있는가」로 재면 항목 검사를
#   꺼도 초록이다(M46 실측). 항목을 도는 그 자리 안에 붙어 있는지를 잰다.
awk '/foreach \(\$it in \$names\) \{/{a=NR} /ReparsePoint\) \{ return \$false \}/{if(a&&NR-a<=2)ok=1} END{exit !ok}' "$PS"
ck "[구판] 윈도 이음줄이 섞이면 우리 것이라 하지 않는다" $? "같음(두 OS 가 갈린다)"
# ★사람이 무엇을 지우는지 화면에서 볼 수 있어야 한다 — 상대 경로로 들어오면 글자만으로는 모른다.
codegrep "$SH" 'cd "\$JARVIS_HOME" 2>/dev/null && pwd -P'; ck "[구판] 맥이 사람에게 실제 자리를 보여 준다" $? "어디를 지우는지 모르고 답하게 된다"
codegrep "$PS" 'Get-Item -LiteralPath \$JarvisHome -Force -ErrorAction Stop\).FullName'; ck "[구판] 윈도 사람에게 실제 자리를 보여 준다" $? "같음"
codegrep "$SH" '{ : < /dev/tty; } 2>/dev/null \|\| return 1'; ck "[구판] 맥은 사람이 없으면 묻지 않는다" $? "묻지도 못하는 자리에서 물음만 찍고 물러난다"
awk '/read -r answer < \/dev\/tty/{a=NR} /\[ "\$answer" != "지웁니다" \]/{if(a&&NR-a<=3)b=NR} /rm -rf "\$JARVIS_HOME"/{if(b&&NR>b)ok=1} END{exit !ok}' "$SH"
ck "[구판] 맥은 사람이 친 말 뒤에만 지운다" $? "확인 없이 지우는 길이 있다"
codegrep "$SH" 'MODE" = "full" \] \|\| return 1'; ck "[구판] 맥은 보기만 하는 판에서 안 지운다" $? "dry-run 이 바깥을 바꾼다"
codegrep "$PS" 'function Test-OldLayout'; ck "[구판] 윈도 구판 지문을 따로 판정한다" $? "두 OS 가 갈린다"
codegrep "$PS" 'if \(\$null -eq \$names\) \{ return \$false \}'; ck "[구판] 윈도 못 세면 우리 것이라 하지 않는다" $? "권한 오류가 「우리 것뿐」으로 읽힌다"
codegrep "$PS" 'return \$sign'; ck "[구판] 윈도 빈 폴더를 지문으로 세지 않는다" $? "빈 자리를 지운다"
codegrep "$PS" 'function Test-HumanPresent'; ck "[구판] 윈도 사람이 있는지 묻는다" $? "입력이 딴 데로 이어진 자리에서 멈춘다"
awk '/\$answer = Read-Host .계속하려면 「지웁니다」/{a=NR} /if \(\$answer -ne .지웁니다.\)/{if(a&&NR-a<=2)b=NR} /Remove-Item -LiteralPath \$JarvisHome -Recurse/{if(b&&NR>b)ok=1} END{exit !ok}' "$PS"
ck "[구판] 윈도 사람이 친 말 뒤에만 지운다" $? "확인 없이 지우는 길이 있다"
codegrep "$PS" 'if \(\$Mode -ne .full.\) \{ return \$false \}'; ck "[구판] 윈도 보기만 하는 판에서 안 지운다" $? "같음"

echo "== cys 를 먼저 닫으라는 안내 — 제거 시작 자리 (2026-09-11 신설) =="
# ★사람이 열어 둔 창을 우리가 끄면 「갑자기 꺼졌다」로 읽힌다. 끄기 전에 말한다(묻는 것이 아니라 알림).
codegrep "$RESET_SH" '^notice_close_cys\(\) \{'; ck "[닫기] 맥 제거기가 그 안내를 가진다" $? "안내가 없다"
count_or_fail "$RESET_SH" 'notice_close_cys'; rc=$?; n="$COUNT_N"; w="$(why_or_count)"
[ "$rc" -eq 0 ] && [ "$n" -ge 2 ]
ck "[닫기] 맥이 그 안내를 실제로 부른다" $? "정의만 있고 아무도 안 부른다($w)"
codegrep "$RESET_SH" 'cys 가 아직 돌고 있습니다'; ck "[닫기] 맥 안내 문구가 있다" $? "무엇을 하라는지 화면이 말하지 않는다"
codegrep "$RESET" 'cys 가 아직 돌고 있습니다'; ck "[닫기] 윈 안내 문구도 있다" $? "두 OS 가 갈린다"
awk '/\$aliveNow = @\(Get-ProcsUnder/{a=NR} /cys 가 아직 돌고 있습니다/{if(a&&NR-a<=4) ok=1} END{exit !ok}' "$RESET"
ck "[닫기] 윈 안내를 지키는 것이 실제 프로세스 판정이다" $? "돌지 않아도 늘 말하거나, 판정을 꺼도 문구가 남는다"

echo "== 셸 확장 함정 — 변수 뒤 한국어 따옴표 (2026-09-11 신설) =="
# 🔴bash 3.2 는 `"$VAR」"` 에서 **따옴표를 이름의 일부로** 먹는다 ⇒ `set -u` 아래서 그 줄이 죽는다
#   (`bash -n` 은 못 잡는다 — 실행 시 오류다). 실측 2026-09-11: J-HOME-01 안내 세 자리가 이 형태였고,
#   거부 갈래가 진단 코드를 찍기 전에 죽고 있었다. ⇒ **중괄호로 가른다.**
for _f in "$SH" "$RESET_SH" "$DIR/reinstall.sh"; do
  [ -f "$_f" ] || continue
  if LC_ALL=C grep -nE '\$[A-Za-z_][A-Za-z0-9_]*[^ -~]' "$_f" >/dev/null 2>&1; then rc=1; else rc=0; fi
  ck "[셸] $(basename "$_f") 변수 뒤 한국어 글자 0건" "$rc" "그 줄이 실행 시 unbound variable 로 죽는다"
done
codegrep "$PS" 'J-HOME-01'; ck "[N3] 윈이 그 거부에 진단 코드를 붙인다" $? "사람이 찾아볼 자리가 없다"
codegrep "$SH" 'J-HOME-01'; ck "[N3] 맥도 같음" $? "같음"
# ★시험 씨앗도 **설치기가 놓는 것을 똑같이** 놓아야 한다 — 안 놓으면 제거기가 옳게 비켜 가는데
#   축은 그것을 손실로 읽는다(2026-09-10 러너 실측 · 두 OS 스텝이 동시에 붉어졌다).
if [ -f "$DIR/../tests/agora-preserve.py" ]; then
  grep -q 'jarvis-owned' "$DIR/../tests/agora-preserve.py"
  ck "[N3] 시험 씨앗이 소유 표식을 놓는다" $? "씨앗이 설치기와 달라 축이 옳은 동작을 손실로 읽는다"
fi
# ★표식을 확인하는 자리와 지우는 자리가 **같은 갈래**여야 한다 — 검사만 하고 그냥 지우면 소용없다.
awk '/Test-SafeJarvisDir \$JarvisDir/{a=NR} /Drop .자비스 작업 폴더./{b=NR} END{exit !(a&&b&&a<b)}' "$RESET"
ck "[N3] 윈은 검사를 통과한 갈래에서만 지운다" $? "검사 결과와 무관하게 지운다"
awk '/safe_jarvis_dir "\$JARVIS_HOME"/{a=NR} /drop_dir "\$JARVIS_HOME"/{b=NR} END{exit !(a&&b&&a<b)}' "$RESET_SH"
ck "[N3] 맥도 같음" $? "같음"

# ── 2차 검토 N2 이전 설치의 좌석을 이번 선언으로 세지 않는다 ────────────
codegrep "$PS" 'BaselineSurfaces'; ck "[N2] 윈이 기준선을 찍는다" $? "지난 설치의 좌석이 이번 선언으로 계산된다"
codegrep "$SH" 'FLEET_BASELINE='; ck "[N2] 맥도 기준선을 찍는다" $? "같음"
# 🔴🔴3차 검토 N2(관리자 결정 = 잔여 위험 수용 · 코드 최소) — **기준선 조회 실패는 게이트다.**
#   빈 집합은 「아무것도 없었다」가 아니라 「못 물어봤다」일 수 있다. 그 둘을 한 칸에 담으면
#   다음 조회의 **옛 좌석 전부가 새 좌석**이 되어 사람이 아무 말도 안 했는데 「함대가 섰습니다」가 된다.
codegrep "$PS" 'BaselineOk = \$false'; ck "[N2] 윈이 기준선 성공 여부를 따로 든다" $? "실패와 빈 목록을 한 칸에 담는다"
codegrep "$PS" 'if \(-not \$script:BaselineOk\)'; ck "[N2] 윈이 실패면 판정하지 않는다" $? "실패가 곧 거짓 성공이 된다"
codegrep "$SH" 'FLEET_BASELINE_OK=0'; ck "[N2] 맥도 그 칸을 든다" $? "같음"
codegrep "$SH" 'FLEET_BASELINE_OK" != "1" \]'; ck "[N2] 맥도 실패면 판정하지 않는다" $? "같음"
# ★기준선은 **자리를 열기 전에** 찍어야 한다 — 뒤에 찍으면 우리 master 자리까지 기준선에 들어간다.
awk '/Set-FleetBaseline \$cli/{if(!a)a=NR} /new-surface --role master/{if(!b)b=NR} END{exit !(a&&b&&a<b)}' "$PS"
ck "[N2] 윈은 자리를 열기 전에 찍는다" $? "우리 자리까지 기준선에 들어가 영영 안 세어진다"
# ⚠맥은 자리 여는 일을 **함수**로 묶어 두었다 — 그 함수 **정의**는 부르는 자리보다 위에 있다.
#   그래서 `new-surface` 를 앵커로 쓰면 순서 판정이 뒤집힌다. **부르는 자리**를 앵커로 쓴다.
awk '/set_fleet_baseline "\$cli"/{if(!a)a=NR} /ref="\$\(cys_open_master_seat/{if(!b)b=NR} END{exit !(a&&b&&a<b)}' "$SH"
ck "[N2] 맥도 자리를 열기 전에 찍는다" $? "우리 자리까지 기준선에 들어가 영영 안 세어진다"

# ── 2차 검토 N5 검증된 부모의 자손만 끈다 · 명령줄 축은 어디에도 없다 ────
# ⚠이름 조각으로 재면 **이름만 바꿔 죽여도 초록**이다(뮤턴트 실측 2026-09-10 · 이 파일에서 두 번째다).
#   ⇒ 정의는 줄머리로 못박고, **실제로 부르는지**를 따로 잰다.
codegrep "$RESET_SH" '^proc_descendants\(\) \{'; ck "[N5] 맥이 자손을 혈연으로 모은다" $? "밖의 해석기가 도는 helper 가 조용히 살아남는다"
codegrep "$RESET_SH" 'proc_descendants \$pids'; ck "[N5] 그 자손 모으기를 실제로 부른다" $? "정의만 있고 아무도 안 부른다"
# 🔴🔴3차 검토 N5 — 표를 찍은 뒤 **새로 생긴 자손**은 목록에 없다. 부모가 먼저 끝나면 고아가 돼 혈연으로
#   다시 찾을 길이 없으므로, 끄기 직전이 마지막 기회다 ⇒ 모으기를 **두 번** 부른다.
count_or_fail "$RESET_SH" 'add_descendants "\$targets"'; rc=$?; n="$COUNT_N"; w="$(why_or_count)"
[ "$rc" -eq 0 ] && [ "$n" -ge 2 ]
ck "[N5] 끄기 직전에 자손을 한 번 더 모은다" $? "표를 찍은 뒤 생긴 자손을 못 끈다($w)"
# ★번호 비교는 구분자까지 맞춘다 — 통짜 부분일치는 「1234」가 다른 번호 안에 있기만 해도 빠뜨린다.
# ⚠이 형태는 **두 자리**(자손 더하기 · 최종 셈)에 있다. 하나만 재면 다른 하나를 되돌려도 초록이다(M3 실측).
count_or_fail "$RESET_SH" 'case "\$pids" in \*" \$pid "\*'; rc=$?; n="$COUNT_N"; w="$(why_or_count)"
[ "$rc" -eq 0 ] && [ "$n" -ge 2 ]
ck "[N5] 번호 비교가 구분자까지 맞는다" $? "다른 번호 글자에 걸려 자손을 목록에서 빠뜨린다($w)"
no_code "$RESET_SH" 'case "\$targets" in \*"\$pid"\*'; rc=$?; w="$GREP_WHY"
ck "[N5] 통짜 부분일치 옛 형태 0건" "$rc" "되돌리면 자손을 다시 빠뜨린다(${w})"
# ★최종 「아직 도는 것」은 자리 축 **+ 모아 둔 자손 가운데 살아남은 것**이다 — 뒤쪽을 빼면
#   밖의 해석기 자손이 TERM 을 무시하고 살아남아도 「없다」로 끝난다.
codegrep "$RESET_SH" '^alive_after\(\) \{'; ck "[N5] 최종 셈이 모아 둔 자손도 본다" $? "밖의 해석기 자손이 살아남아도 없다고 끝낸다"
codegrep "$RESET_SH" 'alive_after "\$targets"'; ck "[N5] 그 최종 셈을 실제로 부른다" $? "정의만 있고 아무도 안 부른다"
# ── 3차 검토 BLOCK ② 사람에게 하는 말과 돌려주는 값의 **채널을 가른다** ──
# 🔴앞 판은 `say`(표준출력)로 「끄는 중」을 찍었고 부르는 쪽이 `$( )` 로 그것을 통째로 삼켰다 ⇒
#   사람은 못 보고, 그 안내문이 「아직 살아 있는 것 표」로 파싱됐다.
codegrep "$RESET_SH" '^tell\(\) \{ printf .* >&2; \}'; ck "[②] 맥에 표준오류 말하기 통로가 있다" $? "값을 돌려주는 함수가 화면에 말할 길이 없다"
codegrep "$RESET_SH" 'tell "  cys 자리에서 도는 것을 멈춥니다:"'; ck "[②] 끄는 대상 인쇄가 그 통로로 간다" $? "안내문이 값에 섞여 사라진다"
no_code "$RESET_SH" 'say "  cys 자리에서 도는 것을 멈춥니다'; rc=$?; w="$GREP_WHY"
ck "[②] 표준출력으로 찍던 옛 형태 0건" "$rc" "되돌리면 안내가 다시 값으로 삼켜진다(${w})"
# ★되돌릴 수 없는 일(강제 종료)의 대상은 **그 순간에** 확인한다 — 표는 과거의 사실이다.
codegrep "$RESET_SH" '^proc_token\(\) \{'; ck "[②] 번호마다 확인표(시작시각·실행 파일)를 뜬다" $? "번호가 재사용되면 남의 프로그램을 끈다"
codegrep "$RESET_SH" '^kill_verified\(\) \{'; ck "[②] 신호는 확인표를 다시 견준 뒤에만 보낸다" $? "같음"
# 🔴🔴4차 검토 BLOCK ② — **빈 확인표가 곧 통과권이었다.** 첫 조회가 실패한 번호를 빈 칸으로 표에 넣었고,
#   신호 직전 검사는 「확인표가 있을 때만」 견줬다 ⇒ fail-open. 그 사이 번호가 남에게 넘어가면
#   우리가 남의 프로그램을 끈다. ⇒ 못 뜬 번호는 **표에 안 넣고**, 빈 칸은 **절대 신호 대상이 아니다**(두 겹).
codegrep "$RESET_SH" 'if tok="\$\(proc_token "\$pid" 2>/dev/null\)" && \[ -n "\$tok" \]'; ck "[②] 확인표를 못 뜬 번호는 표에 안 넣는다" $? "빈 칸이 통과권이 된다"
no_code "$RESET_SH" 'tok="\$\(proc_token "\$pid" 2>/dev/null\)" \|\| tok=""'; rc=$?; w="$GREP_WHY"
ck "[②] 빈 칸으로 넣던 옛 형태 0건" "$rc" "되돌리면 fail-open 이 다시 열린다(${w})"
codegrep "$RESET_SH" '\[ -n "\$tok" \] \|\| \{ tell'; ck "[②] 빈 확인표는 신호 대상이 아니다(두 번째 겹)" $? "위쪽에서 걸러도 이 한 줄이 문을 다시 연다"
no_code "$RESET_SH" 'if \[ -n "\$tok" \] && \[ "\$now" != "\$tok" \]'; rc=$?; w="$GREP_WHY"
ck "[②] 「확인표가 있을 때만 견주던」 옛 형태 0건" "$rc" "되돌리면 빈 칸이 다시 통과한다(${w})"
# 🔴🔴4차 검토 REGRESSED N5 — r4 가 **새로 만든** 공격면: `/tmp/.jarvis-desc.$$` 를 `>` 로 열었다.
#   이름을 미리 알 수 있으므로 그 자리에 남의 파일을 가리키는 링크를 심어 두면 우리가 그 파일을 부순다.
#   ⇒ 임시 파일을 **아예 쓰지 않는다**(here-doc 으로 현재 셸에서 돈다).
no_code "$RESET_SH" '/tmp/\.jarvis-desc'; rc=$?; w="$GREP_WHY"
ck "[N5] 지우개가 예측 가능한 임시 파일을 안 쓴다" "$rc" "남의 파일을 가리키는 링크를 따라가 그 파일을 0바이트로 만든다(${w})"
codegrep "$RESET_SH" 'EOF_PROC_TABLE'; ck "[N5] 자손 훑기가 임시 파일 없이 돈다" $? "하위 셸을 우회하려고 파일을 다시 만들게 된다"
no_code "$RESET_SH" 'rm -f /tmp/'; rc=$?; w="$GREP_WHY"
ck "[N5] /tmp 에 만들고 지우는 자리가 없다" "$rc" "지우개가 /tmp 의 남의 자리를 건드린다(${w})"
# ⚠**부르는 자리만** 센다. 앞 판 패턴(`kill_verified `)은 **정의 줄의 주석**(`# kill_verified <신호> <표>`)
#   까지 세어 3이 나왔다 ⇒ 호출 하나를 지워도 2 라서 초록이었다(뮤턴트 M2 실측 · 이 파일에서 네 번째다).
count_or_fail "$RESET_SH" '^ +kill_verified (TERM|KILL) '; rc=$?; n="$COUNT_N"; w="$(why_or_count)"
[ "$rc" -eq 0 ] && [ "$n" -eq 2 ]
ck "[②] TERM·KILL 둘 다 그 확인을 거친다" $? "한쪽만 확인하면 나머지 한쪽이 남의 것을 끈다($w)"
no_code "$RESET_SH" 'kill -TERM "\$pid"'; rc=$?; w="$GREP_WHY"
ck "[②] 확인 없이 번호로만 끄는 형태 0건" "$rc" "되돌리면 재사용된 번호를 다시 끈다(${w})"
no_code "$RESET_SH" 'pkill -f'; rc=$?; w="$GREP_WHY"
ck "[N5] 맥에 명령줄 종료가 하나도 없다" "$rc" "편집기가 그 경로를 파일 인자로 열기만 해도 죽는다(${w})"
codegrep "$RESET_SH" 'canon "\$cmd"'; ck "[N5] 실행 파일도 실경로로 견준다" $? "링크 별칭에서 빗나간다"

# ── ⓓ R5 「아직 안 쳤다」를 단정하지 않는다 ──────────────────────
# 🔴🔴2026-09-10 **뒤집었다**(1차 검토 BLOCK ③ 채택). 앞 판 축은 「목록에 master 자리가 있으면 선언됐다」를
#   **요구**했다 — 그런데 그 좌석을 만든 것은 사람이 아니라 **설치기 자신**이다. 축이 거짓 명제를
#   지키고 있었다. ⇒ 근거는 **자식 좌석(master 아닌 것)의 출현**이어야 한다.
#   ★역방향 축을 함께 둔다: 옛 형태가 코드에 남아 있으면 적색이다(되돌리면 붉어진다).
codegrep "$PS" 'function Test-DeclarationSeen'; ck "[R5] 윈이 선언 판정을 한 자리에서 만든다" $? "자리마다 다른 잣대를 쓴다"
codegrep "$SH" 'declaration_seen\(\)';        ck "[R5] 맥도 같음" $? "같음"
no_code "$PS" "live -contains 'master'"; rc=$?; w="$GREP_WHY"
ck "[R5] 윈에 옛 판정(master 좌석 존재) 0건" "$rc" "설치기가 만든 좌석을 사람이 친 것으로 읽는다(${w})"
no_code "$SH" 'grep -q " master "'; rc=$?; w="$GREP_WHY"
ck "[R5] 맥에 옛 판정 0건" "$rc" "같음(${w})"
count_or_fail "$PS" 'Test-DeclarationSeen \$live'; rc=$?; n="$COUNT_N"; w="$(why_or_count)"
[ "$rc" -eq 0 ] && [ "$n" -ge 2 ]
ck "[R5] 윈이 두 자리에서 그 판정을 쓴다" $? "한 자리만 고쳤다($w)"
count_or_fail "$SH" 'declaration_seen "\$live"'; rc=$?; n="$COUNT_N"; w="$(why_or_count)"
[ "$rc" -eq 0 ] && [ "$n" -ge 2 ]
ck "[R5] 맥도 두 자리에서 쓴다" $? "한 자리만 고쳤다($w)"
# ★공통 래퍼의 「강제」도 실제로 빠졌는가 — 자리마다 고치고 공통 자리를 안 고치면 화면은 그대로다.
no_code "$PS" '강제: '; rc=$?; w="$GREP_WHY"; ck "[R5] 윈 화면에 「강제:」 0건" "$rc" "순화가 화면에 안 나타난다(${w})"
no_code "$SH" '강제: '; rc=$?; w="$GREP_WHY"; ck "[R5] 맥 화면에 「강제:」 0건" "$rc" "같음(${w})"
codegrep "$PS" '이 한마디만 사람이 칩니다'; ck "[R5] 윈 문구에서 「강제」의 어감을 뺐다" $? "자비스는 「할 일 없음」이라 적는데 이쪽은 「강제」라 적어 모순이다"
codegrep "$SH" '이 한마디만 사람이 칩니다'; ck "[R5] 맥도 같음" $? "같음"

# ── ⓔ R6 자동 시작은 **작업을 직접 보고** 말한다 ────────────────
codegrep "$PS" 'function Get-CysAutoStartState'; ck "[R6] 등록 여부를 자리로 잰다" $? "종료값·팩 출력으로 추정한다(두 줄이 서로 모순됐다)"
codegrep "$PS" 'schtasks /Query /TN cysd /XML'; ck "[R6] 그 자리는 작업 스케줄러다" $? "무엇을 보는지 모른다"
# 🔴🔴**「모른다」를 「없다」로 바꿔 말하지 않는다**(1차 검토 REVISE ⑤ 확정). 상태는 둘이 아니라 다섯이다.
# ⚠「모른다」로 가는 길도 **둘**이다(명령 자체가 실패 · 조회가 0 이 아닌데 없다는 말이 아님).
#   하나만 재면 다른 하나를 'no' 로 바꿔도 초록이다 — 그것이 바로 이 확정이 막으려던 사고다.
# ⚠파일 전체에서 세면 안 된다 — 이 파일에는 **다른 뜻의** `return 'unknown'` 이 따로 있다(연결 원인 판별).
#   그것까지 세면 이 함수 안의 한 길을 죽여도 초록이다(뮤턴트 실측 2026-09-10). **그 함수 안에서만** 센다.
count_from_or_fail "return 'unknown'" -- awk '/^function Get-CysAutoStartState/{f=1} f{print} f&&/^}$/{exit}' "$PS"; rc=$?
n="$COUNT_N"; w="$(why_or_count)"
[ "$rc" -eq 0 ] && [ "$n" -ge 2 ]
ck "[R6] 「모른다」로 가는 길이 둘 다 산다" $? "한 길이 「없다」로 바뀌었다 — 모르는 것을 없다고 말한다($w)"
codegrep "$PS" "return 'other'";   ck "[R6] 이름만 같은 남의 작업을 가른다" $? "남의 cysd 작업을 우리 것으로 읽는다"
codegrep "$PS" "return 'off'";     ck "[R6] 꺼져 있는 작업을 가른다" $? "꺼진 작업에도 「저절로 켜집니다」라고 말한다"
# 🔴🔴2차 검토 STILL OPEN ⑤ — **글자로 보던 것을 구조로 읽는다.** `<Command>` 안에 `cysd` 라는 조각만
#   있으면 'yes' 였다: 달력 trigger 로 `C:\Other\cysd.exe` 를 도는 남의 작업도 「다음 로그온부터
#   저절로 켜집니다」가 됐다. ⇒ 실행 파일 **경로 일치** · **이 사용자의 로그온 trigger** · **켜짐** 셋 다.
codegrep "$PS" '\[xml\]\$body'; ck "[R6] XML 을 구조로 읽는다" $? "글자 조각으로 판정한다"
codegrep "$PS" 'doc\.Task\.Actions\.Exec'; ck "[R6] 실행 파일을 구조에서 꺼낸다" $? "같음"
codegrep "$PS" 'cys\\cysd\.exe'; ck "[R6] 우리 것의 근거는 **그 자리의 cysd.exe** 다" $? "이름 조각만 보고 우리 것이라 한다"
codegrep "$PS" 'doc\.Task\.Triggers\.LogonTrigger'; ck "[R6] 로그온 trigger 를 확인한다" $? "달력 trigger 도 「로그온부터 켜집니다」가 된다"
codegrep "$PS" 't\.UserId'; ck "[R6] 그 trigger 가 이 사용자 것인지 본다" $? "남의 계정 로그온 작업을 내 것으로 읽는다"
# 🔴🔴3차 검토 ⑤ — **사람을 이름으로 견주지 않는다.** 앞 판은 두 방향으로 틀렸다:
#   ⑴`\<이름>` 접미사만 같아도 통과 ⇒ `ACME\alice` 인데 trigger 가 `OTHER\alice` 여도 yes.
#   ⑵작업 스케줄러의 `UserId` 는 **SID 일 수도 있다**(Microsoft 문서) ⇒ 정상적인 내 작업이 off 로 오판.
#   ⇒ 두 형태를 **한 축(SID)** 으로 모아 견준다. 못 알아보면 unknown(「아니다」로 단정 금지).
codegrep "$PS" 'WindowsIdentity\]::GetCurrent\(\)\.User\.Value'; ck "[⑤] 윈이 현재 사용자를 SID 로 견준다" $? "이름으로 견주면 도메인 다른 동명이 통과한다"
codegrep "$PS" 'NTAccount\(\$uid\)\)\.Translate'; ck "[⑤] 이름으로 적힌 UserId 를 SID 로 옮긴다" $? "SID 로 적힌 내 작업을 남의 것으로 오판한다"
codegrep "$PS" 'uid -match .\^S-1-.'; ck "[⑤] UserId 가 SID 형태인지 먼저 가른다" $? "SID 를 계정 이름으로 변환하려 해 늘 실패한다"
no_code "$PS" 'uid -match \(.\\\\\\\\. \+ \[regex\]::Escape'; rc=$?; w="$GREP_WHY"
ck "[⑤] 이름 접미사만 보던 옛 형태 0건" "$rc" "되돌리면 도메인 다른 동명이 다시 통과한다(${w})"
codegrep "$PS" 'if \(\$unresolved\) \{ return .unknown. \}'; ck "[⑤] 못 알아본 계정은 모른다고 한다" $? "「아니다」로 단정해 멀쩡한 등록을 꺼졌다고 말한다"
# ★★`yes` 로 나가는 문은 **하나**여야 하고, 그 문은 **세 확인을 모두 지난 뒤**에 있어야 한다.
#   앞 축들은 「그 확인이 코드에 있다」까지만 봤다 — 확인 **앞에** yes 를 하나 더 두면 전부 초록이었다
#   (뮤턴트 실측). ⇒ 그 함수 안에서 세고, 순서를 잰다.
count_from_or_fail "return 'yes'" -- awk '/^function Get-CysAutoStartState/{f=1} f{print} f&&/^}$/{exit}' "$PS"; rc=$?
n="$COUNT_N"; w="$(why_or_count)"
[ "$rc" -eq 0 ] && [ "$n" -eq 1 ]
ck "[R6] yes 로 나가는 문이 하나뿐이다" $? "확인 앞에 지름길이 생기면 셋을 다 안 보고 yes 가 된다($w)"
awk '/^function Get-CysAutoStartState/{f=1} f&&/LogonTrigger/{a=NR} f&&/return .yes./{b=NR} f&&/^}$/{exit} END{exit !(a&&b&&a<b)}' "$PS"
ck "[R6] 로그온 trigger 확인이 yes 보다 앞이다" $? "trigger 를 보기 전에 yes 로 나간다"
codegrep "$PS" 'AutoStartState = Get-CysAutoStartState'; ck "[R6] 실측값을 담는다" $? "재고 버린다"
codegrep "$PS" 'function Get-AutoStartWords'; ck "[R6] 할 말을 한 자리에서 만든다" $? "상태가 다섯인데 문장이 자리마다 갈리면 또 모순이 난다"
no_code "$PS" '이 계정에서 막혀 있습니다'; rc=$?
ck "[R6] 까닭을 「막혀 있다」로 단정하지 않는다" "$rc" "잰 적 없는 까닭을 단정한다(${GREP_WHY})"

# ── ⓕ 맥 핀 ──────────────────────────────────────────────────────
codegrep "$SH" 'CYS_VERSION="0\.14\.33"'; ck "[핀] 맥 판본 0.14.33" $? "옛 판본을 받는다"
codegrep "$SH" 'CYS_MAC_BYTES=272977882'; ck "[핀] 맥 arm64 크기" $? "크기가 안 맞아 매번 멈춘다"
codegrep "$SH" 'CYS_MAC_BYTES=269923933'; ck "[핀] 맥 x64 크기" $? "같음"
codegrep "$SH" 'CYS_MAC_SHA256="3919ce1cad7ac834584951190420f92d6ba86b3a2343451829e784aadf3153df"'
ck "[핀] 맥 arm64 지문" $? "지문 핀이 없다 — 크기만 같은 다른 파일이 통과한다"
codegrep "$SH" 'CYS_MAC_SHA256="7ec9e557f9185d03416f949341f5b7b4dc3367aaf72206e754c736d4e7395153"'
ck "[핀] 맥 x64 지문" $? "같음"

# 🔴★**받을 자리는 판본이 박힌 자리여야 한다**(2026-09-11 라이브 실사고).
#   앞 판은 「늘 최신 하나만 두는 배포 폴더」를 가리켰다 — 벤더가 0.14.33 을 올린 날 우리가 핀해 둔
#   0.14.30 이 **404** 가 됐고, 그날부터 깨끗한 맥에서 설치가 100% 실패했다. 릴리스 자산은 판본별로
#   남으므로 그 자리를 쓰면 다음 판이 나와도 우리 핀이 안 사라진다.
codegrep "$SH" 'CYS_DOWNLOAD_DIR="https://github\.com/idoforgod/cys-terminal/releases/download/v'
ck "[핀] 맥은 판본이 박힌 자리에서 받는다" $? "최신만 두는 폴더를 가리킨다 — 다음 판이 나오는 날 404 가 된다"
no_code "$SH" 'cysinsight\.com/downloads'; rc=$?
ck "[핀] 최신만 두는 배포 폴더를 안 쓴다" "$rc" "옛 받을 자리가 코드에 남았다(${GREP_WHY})"

# ★판본 문자열을 **코드 전체에서** 센다. 앞 판은 `0.14.29` 하나를 골라 「없는가」를 봤는데,
#   그 축은 **핀이 0.14.30 으로 올라간 뒤로 아무것도 안 재고 있었다** — 고를 문자열을 사람이 손으로
#   갱신해야 하는 축은 갱신을 잊는 날 눈이 먼다. ⇒ 「0.14.* 가 나오는 줄 = 전부 핀 판본 줄」로 잰다.
count_from_or_fail '0\.14\.[0-9]' -- grep -vE '^[[:space:]]*#' "$SH"; rc=$?
nver="$COUNT_N"
count_from_or_fail '0\.14\.33' -- grep -vE '^[[:space:]]*#' "$SH"; rc2=$?
npin="$COUNT_N"
[ "$rc" -eq 0 ] && [ "$rc2" -eq 0 ] && [ "$npin" -gt 0 ] && [ "$nver" -eq "$npin" ]
ck "[핀] 설치기(맥) 코드의 판본 문자열이 전부 핀 판본이다" $? "옛 판본 문자열이 코드에 남았다(0.14.* ${nver}줄 · 핀 ${npin}줄)"

# 🔴★「그 판본이 자리에 없다」와 「연결이 끊겼다」를 **가른다**.
#   앞 판은 둘을 한 칸에 두어, 없는 파일을 **30분씩 두 번**(NET_WAIT_TIMEOUT × for try in 1 2)
#   기다린 뒤에야 실패했다. 그리고 마지막에 대는 파일 이름은 **자리에 없는 파일**이었다.
codegrep "$SH" 'cys_http_code\(\) \{'; ck "[핀] 받을 자리가 뭐라 답하는지 묻는 자리가 있다" $? "답을 안 묻고 모든 실패를 망 문제로 읽는다"
codegrep "$SH" 'code="\$\(cys_http_code'; ck "[핀] 받기 실패 자리에서 그것을 부른다" $? "함수만 있고 아무도 안 부른다(눈먼 수정)"
codegrep "$SH" '404\|410\)'; ck "[핀] 없는 자리 갈래는 404·410 에만 걸린다" $? "갈래가 넓으면 망 단절까지 삼켜 기다리지 않는다"
codegrep "$SH" 'J-DL-05'; ck "[핀] 없는 자리에 진단 코드를 남긴다" $? "사람이 찾아갈 자리가 없다"
# ★**막지 말아야 할 것** — 망 단절은 **여전히 기다려야 한다**. 새 갈래가 그 길을 삼키면 안 된다.
#   (새 방어를 넣을 때마다 「이 방어가 제 범위를 넘지 않는가」를 짝으로 잰다 — r8 이월.)
awk '/^step_download_cys\(\) \{/{f=1} f&&/404\|410\)/{a=NR} f&&/wait_for_connection "\[5\/10\]"/{b=NR} f&&/^\}$/{exit} END{exit !(a&&b&&a<b)}' "$SH"
ck "[핀] 없는 자리 갈래 뒤에도 망 기다림이 남아 있다" $? "새 갈래가 망 단절까지 삼켰다"

# ★맥도 **받은 파일의 지문**을 본다(윈도우는 2026-09-09부터 그렇게 했고 맥만 크기로 지나갔다).
#   두 자리에서 재야 한다 — **남아 있던 파일**(재실행 경로)과 **방금 받은 파일**. 한 자리만 재면
#   다른 길로 안 잰 파일이 들어온다.
codegrep "$SH" 'cys_file_sha256\(\) \{'; ck "[핀] 맥이 지문을 재는 자리가 있다" $? "크기만 보고 지나간다"
count_from_or_fail 'cys_file_sha256' -- awk '/^step_download_cys\(\) \{/{f=1} f{print} f&&/^\}$/{exit}' "$SH"; rc=$?
n="$COUNT_N"; w="$(why_or_count)"
[ "$rc" -eq 0 ] && [ "$n" -eq 2 ]
ck "[핀] 지문을 두 자리에서 본다(남아 있던 것·방금 받은 것)" $? "한 자리만 재면 다른 길로 안 잰 파일이 들어온다($w)"
codegrep "$SH" 'J-DL-03'; ck "[핀] 맥도 「지문을 못 쟀다」에 코드를 남긴다" $? "못 잰 것이 조용히 지나간다"
codegrep "$SH" 'J-DL-04'; ck "[핀] 맥도 「지문이 다르다」에 코드를 남긴다" $? "다른 파일 위에서 다음 단계가 돈다"

# 윈도우도 「그 판본이 자리에 없다」와 「연결이 끊겼다」를 가른다(맥 J-DL-05 와 같은 갈래).
#   앞 판은 404 를 연결 문제로 읽어 없는 파일을 30분 기다린 뒤 「분류 못 함」(J-UNK-00)으로 끝났다.
# (a) 코드가 있다
codegrep "$PS" "Write-JCode 'J-DL-05'"; ck "[핀] 윈도우도 없는 자리에 진단 코드(J-DL-05)를 남긴다" $? "사람이 찾아갈 자리가 없다"
# (b) 404·410 갈래가 J-DL-05 를 남기고, 다른 갈래로 새지 않고 곧바로 멈추며, 그 모두가 연결 대기보다 앞에 있다
awk '/^function Step-DownloadCys \{/{f=1} f&&!a&&/if \(\$http -eq 404 -or \$http -eq 410\) \{/{a=NR} f&&a&&!j&&/Write-JCode .J-DL-05./{j=NR} f&&j&&!r&&/if \(\$http -eq /{bad=1} f&&j&&!r&&/^[[:space:]]+return 5$/{r=NR} f&&/Wait-ForConnection .\[5\/10\]./{b=NR} f&&/^\}$/{exit} END{exit !(!bad&&a&&j&&r&&b&&a<j&&j<r&&r<b)}' "$PS"
ck "[핀] 윈도우도 404·410 은 기다리기 전에 곧바로 멈춘다" $? "없는 파일을 연결 문제로 읽어 30분 기다린다"
# (c-1) 연결 원인 프로브: 407 은 가운데 프록시가 막은 것이라 「닿았다」로 세지 않는다(상태코드면 닿았다는 줄보다 먼저)
awk '/^function Test-UrlReachable\(\$url\) \{/{f=1} f&&!p&&/-eq 407\) \{ return \$false \}/{p=NR} f&&/if \(\$_\.Exception\.Response\) \{ return \$true \}/{t=NR} f&&/^\}$/{exit} END{exit !(p&&t&&p<t)}' "$PS"
ck "[대기] ps1 프로브가 407(프록시 로그인 요구)을 「닿았다」로 세지 않는다" $? "프록시가 막은 것을 목적지가 답한 것으로 읽는다"
# (c-2) 받기 단계: 407 은 따로 멈춘다 — 404·410 조건에 섞이지 않고, J-DL-05 를 적지 않고, 연결 대기보다 앞에서 끝난다
awk '/^function Step-DownloadCys \{/{f=1} f&&/\$http -eq (404|410)/&&/407/{bad=1} f&&!a&&/if \(\$http -eq 407\) \{/{a=NR} f&&a&&!j&&/Write-JCode /{j=NR; if ($0 ~ /J-DL-05/) bad=1} f&&j&&!r&&/^[[:space:]]+return 5$/{r=NR} f&&/Wait-ForConnection .\[5\/10\]./{b=NR} f&&/^\}$/{exit} END{exit !(!bad&&a&&j&&r&&b&&a<j&&j<r&&r<b)}' "$PS"
ck "[핀] 윈도우 받기의 407 은 J-DL-05 도 기다림도 아닌 따로 멈춤이다" $? "프록시 로그인 요구를 「판본 없음」으로 적거나 30분 기다린다"
# (d) 받기 실패 자리에서 상태코드를 먼저 읽고, 상태코드 갈래가 모두 return 으로 닫힌 뒤에만 연결 대기에 들어간다.
#     답이 아예 없는 경우(이름 못 찾음·연결 거부·끊김·시간 초과)는 도우미가 0 을 돌려주어 대기 쪽으로 간다.
awk '/^function Get-WebErrorStatus\(\$err\) \{/{g=1} g&&/^[[:space:]]+return 0$/{z=1} g&&/^\}$/{g=0} /^function Step-DownloadCys \{/{f=1} f&&!c&&/\$http = Get-WebErrorStatus \$_/{c=NR} f&&/if \(\$http -eq /{if (open||!c) bad=1; n++; open=1} f&&open&&/^[[:space:]]+return 5$/{open=0} f&&/Wait-ForConnection .\[5\/10\]./{b=NR; if (open) bad=1} f&&/^\}$/{exit} END{exit !(z&&c&&b&&c<b&&n>=2&&!bad)}' "$PS"
ck "[핀] 윈도우 받기는 상태코드 갈래를 다 지난 뒤에만 연결 대기에 들어간다" $? "HTTP 답을 받고도 연결 문제로 읽어 기다린다"

echo "== 로그인 보존 축 (2026-09-08 운영자 실기 사고) =="
# 🔴왜 이 칸이 생겼는가: 「로그인은 그대로 둡니다」가 **윈도우에서 한 번도 안 재고** 배포됐다.
#   러너에 계정이 없어 [3/10] 앞에서 멈추니 사람 노트북에서만 잴 수 있다고 여겼기 때문이다.
#   실제로는 계정 없이도 잰다 — 재야 할 것은 「지우개가 로그인 자리를 건드렸는가」이기 때문이다.
#   ⇒ 그 축이 **러너에서 사라지면 여기서 적색**이 되게 한다. 축은 지우기 쉽고, 지워도 조용하다.
TDIR=""
for c in "$DIR/../tests" "$DIR/tests"; do [ -d "$c" ] && { TDIR="$c"; break; }; done
WF=""
for c in "$DIR/../.github/workflows/reinstall-matrix.yml"; do [ -f "$c" ] && { WF="$c"; break; }; done
if [ -n "$TDIR" ]; then
  for f in login-seed.py login-verify.py login-mutate.py login-preserve-run.sh login-preserve-run.ps1; do
    [ -f "$TDIR/$f" ]; ck "[로그인] $f 실재" $? "축의 부품이 없다"
  done
  # ★씨앗 셋이 다 들어 있어야 한다. 하나라도 빠지면 「재 봤다」가 좁아진다.
  grep -q 'credentials.json' "$TDIR/login-seed.py"; ck "[로그인] 씨앗 ⓐ 로그인 파일" $? "로그인 자리를 안 심는다"
  grep -q 'oauthAccount' "$TDIR/login-seed.py"; ck "[로그인] 씨앗 ⓑ 계정 칸" $? "로그인과 이어진 칸을 안 심는다"
  grep -q 'session-start' "$TDIR/login-seed.py" && grep -q 'my-own' "$TDIR/login-seed.py"
  ck "[로그인] 씨앗 ⓒ 우리 훅 + 남의 훅" $? "남의 훅이 없으면 과잉 삭제를 못 잡는다"
  # ★글자 비교로 되돌리면 적색 — 뜻으로 비교해야 줄바꿈·칸 순서에 속지 않는다.
  grep -q 'json.loads' "$TDIR/login-verify.py"; ck "[로그인] 검사기가 파싱해서 비교" $? "글자 비교는 진짜 손실을 덮는다"
  grep -q 'sha256' "$TDIR/login-verify.py"; ck "[로그인] 로그인 파일은 바이트로 대조" $? "있다/없다만 보면 안이 비어도 초록이다"
  # ★2026-09-08 사고 수정 — 살아 있는 기계에서 시험이 시작되면 안 된다(HOME 치환은 격리가 아니다).
  grep -q 'refuse_if_live_machine' "$TDIR/login-seed.py"; ck "[로그인] 입구 거절 장치 실재" $? "살아 있는 기계에서 제거기가 돈다"
  grep -q '/Applications/cys.app' "$TDIR/login-seed.py"; ck "[로그인] 거절 판정에 앱 자리" $? "무엇을 보고 거절하는지가 없다"
  grep -q 'guard-removed' "$TDIR/login-mutate.py"; ck "[로그인] 거절 장치 뮤턴트" $? "장치가 정말 막는지 잰 적이 없다"
  # 🔴러너 3차 실행이 이걸로 한 판을 썼다(2026-09-08 · run 34210064678): 인코딩 수정으로
  #   `ConvertTo-Json -Depth 40` 이 한 곳에서 세 곳이 되자 뮤턴트가 「어디를 망가뜨렸는지 말할 수
  #   없다」며 멈췄다. 멈춘 것은 옳다 — 그러나 **그 사실을 러너에서 알아냈다.**
  #   ★정직한 실패는 옳지만, 더 싼 자리에서 실패하는 것이 더 옳다. 여기서 0.2초에 잡는다.
  ( cd "$DIR/.." && python3 tests/login-mutate.py --audit --src install-master >/dev/null 2>&1 )
  ck "[로그인] 뮤턴트 앵커가 표와 맞는다(--audit)" $? "앵커가 흘렀다 — 러너 한 판을 쓰기 전에 여기서 고쳐라"
  # 🔴같은 파일이 기계마다 다른 바이트로 놓인다 — 윈도우 체크아웃은 .py 를 CRLF 로 받는다.
  #   여러 줄 앵커는 그때 **한 곳도 안 걸린다**(러너 5차 실측). ★--audit 은 이걸 못 잡는다:
  #   개발기 파일은 LF 이기 때문이다. 그래서 앵커 대조 자체가 줄바꿈을 골라야 한다.
  grep -q '_norm' "$TDIR/login-mutate.py"
  ck "[로그인] 앵커 대조가 줄바꿈에 안 흔들린다" $? "윈도우에서만 앵커를 못 찾는다"
  GA=""; for c in "$DIR/../.gitattributes"; do [ -f "$c" ] && GA="$c"; done
  if [ -n "$GA" ]; then
    grep -q 'tests/\*.py text eol=lf' "$GA"
    ck "[로그인] tests/*.py 줄바꿈을 LF 로 못박았다" $? "체크아웃 설정에 따라 파일이 달라진다"
  else
    sk "[로그인] .gitattributes 검사" ".gitattributes 가 없다"
  fi
  # ★입구가 씨앗을 **먼저** 부른다 — 거절이 파괴보다 앞이어야 한다(순서가 곧 안전장치다).
  awk '/login-seed.py/{a=NR} /reset-clean.sh/{b=NR} END{exit !(a && b && a < b)}' "$TDIR/login-preserve-run.sh"
  ck "[로그인] 입구가 씨앗을 지우기보다 먼저" $? "거절을 지나기 전에 지우개가 돈다"
  [ "$(head -c3 "$TDIR/login-preserve-run.ps1" | xxd -p)" = "efbbbf" ]
  ck "[로그인] 윈 입구 = UTF-8 with BOM" $? "5.1 이 한글을 못 읽어 파싱 오류가 난다"
  # ★윈도우 파이썬은 stdout 을 그 기계의 코드페이지(cp1252·cp949)로 잡는다 — 우리말을 찍는 순간 죽는다.
  #   러너 첫 실행이 정확히 여기서 넘어졌다(2026-09-08 · 첫 줄 「씨앗 심음:」 에서 UnicodeEncodeError).
  n=0
  for f in login-seed.py login-verify.py login-mutate.py; do
    grep -q 'reconfigure(encoding="utf-8"' "$TDIR/$f" && n=$((n+1))
  done
  [ "$n" -eq 3 ]; ck "[로그인] 시험 스크립트 3종이 stdout 을 UTF-8 로 되돌린다" $? "윈도우에서 첫 줄을 찍다 죽는다(잰 것이 0 이 된다 · 실측 $n/3)"
else
  sk "[로그인] 축 부품 검사" "tests 폴더를 못 찾았다"
fi
if [ -n "$WF" ]; then
  # ★두 OS 가 **둘 다** 돌아야 한다. 한쪽만 걸어 두고 초록을 내던 자리가 이 파일에 이미 있었다.
  grep -q "로그인 보존 — 씨앗·지우기·대조 (맥)" "$WF"; ck "[로그인] 러너 맥 축" $? "맥에서 안 잰다"
  grep -q "로그인 보존 — 씨앗·지우기·대조 (윈)" "$WF"; ck "[로그인] 러너 윈 축" $? "윈도우에서 안 잰다 — 사고가 난 바로 그 자리다"
  grep -q "로그인 보존 — 뮤턴트가 붉어지는가 (맥)" "$WF" && grep -q "로그인 보존 — 뮤턴트가 붉어지는가 (윈)" "$WF"
  ck "[로그인] 뮤턴트 축 두 OS" $? "초록이 수정 덕인지 축이 눈먼 덕인지 못 가른다"
  # ★뮤턴트는 「적색이 났다」로 끝내면 안 된다 — 지우개가 죽어도 씨앗이 그대로 남아 온통 적색이 된다.
  #   그때 증명되는 것은 「망가뜨렸더니 붉어졌다」가 아니라 「아무것도 안 돌았다」이다.
  grep -q -- '--expect-fail-at' "$WF" && grep -q -- '-ExpectFailAt' "$WF"
  ck "[로그인] 뮤턴트가 **기대한 자리**를 붉히는지 본다" $? "지우개가 죽어서 난 적색도 통과한다"
  grep -q 'expect_fail_at' "$TDIR/login-verify.py"
  ck "[로그인] 검사기가 그 자리 대조를 한다" $? "러너만 인자를 넘기고 검사기는 무시한다"
  # ★자리만으로 모자란 뮤턴트가 있다 — 방어가 발화해 「안 고쳤다」와 「그냥 안 돌았다」는
  #   붉어지는 자리가 같다. 지우개가 그때 **무슨 말을 했는가**까지 봐야 갈린다(러너 4차 실측).
  grep -q 'CLEANER_SAYS' "$TDIR/login-mutate.py"
  ck "[로그인] 지우개가 할 말 표가 있다" $? "방어 발화와 무동작이 구별되지 않는다"
  grep -q 'expect-cleaner-says' "$TDIR/login-preserve-run.sh" && grep -q 'ExpectCleanerSays' "$TDIR/login-preserve-run.ps1"
  ck "[로그인] 두 입구가 그 말을 확인한다" $? "한쪽 OS 만 갈라 본다"
  grep -q 'ExpectCleanerSays' "$WF"
  ck "[로그인] 러너가 그 말을 넘긴다" $? "표에만 있고 아무도 안 쓴다"
  grep -q "시험 입구가 살아 있는 기계에서 멈추는가 (맥)" "$WF" && grep -q "시험 입구가 살아 있는 기계에서 멈추는가 (윈)" "$WF"
  ck "[로그인] 입구 거절 축 두 OS" $? "사고 수정이 러너에서 안 재진다"
else
  sk "[로그인] 러너 축 검사" "워크플로 파일을 못 찾았다"
fi

echo "== 승인 대기 — 말하는 대기 (2026-09-11 Tart 실기에서 나온 것) =="
# 🔴왜 이 칸이 생겼나: 승인 대기 구간에 **상한이 없었다.** 벤더 프롬프트가 코드 입력을 기다리며
#   **2시간 32분 41초 동안 화면에 0바이트**를 찍고 섰다(맥 실기 실측). 10분 상한은 **그 다음 구간**
#   에만 있어 여기엔 닿지 않는다 — 벤더 프롬프트가 먼저 막기 때문이다.
codegrep "$SH" '^LOGIN_SAY_INTERVAL=60';   ck "[대기] 맥 안내 간격 60초" $? "간격이 없으면 말이 안 나온다"
codegrep "$SH" '^LOGIN_WAIT_TIMEOUT=1200'; ck "[대기] 맥 승인 대기 상한 20분" $? "상한이 없으면 무한 대기가 그대로다"
codegrep "$SH" '^login_waiter\(\) \{';    ck "[대기] 맥 감시자가 있다" $? "기다리는 동안 아무도 말하지 않는다"
codegrep "$SH" 'login_waiter "\$LOGIN_WAIT_MARK" "\$LOGIN_PID_FILE" &'
ck "[대기] 맥 감시자를 **배경**으로 돌린다" $? "감시자를 앞에 두면 승인 화면이 안 뜬다"
# ★**막지 말아야 할 것** — 승인 프로세스는 **앞에 그대로** 둬야 한다.
#   배경으로 돌리면 화면에 말하기는 쉬워지지만 **사람이 코드를 붙여넣을 수 없다.**
#   이 축이 그 실수를 막는다(시험 ③이 같은 것을 동작으로도 잰다).
# ★승인은 **앞에** 있어야 한다(배경으로 돌리면 붙여넣기가 죽는다). 다만 상한이 겨눌 수 있게
#   자식이 **제 번호와 시작 시각을 적고 나서** 벤더 명령으로 바뀐다(exec).
codegrep "$SH" 'exec claude auth login'
ck "[대기] 맥 승인은 앞에 그대로 둔다(번호를 적고 exec)" $? "승인을 배경으로 돌리면 붙여넣기가 죽는다"
codegrep "$SH" 'ps -o lstart= -p \$\$ >>'
ck "[대기] 맥 승인이 제 번호·시작 시각을 적는다" $? "표적을 못 적으면 상한이 다시 찾게 되고, 다시 찾으면 남을 맞힌다"
no_code "$SH" 'claude auth login[[:space:]]*&[[:space:]]*$'; rc=$?
ck "[대기] 맥 승인을 배경으로 돌린 자리 0건" "$rc" "그 형태가 있다(${GREP_WHY})"
# ★상한은 표적을 **다시 찾지 않는다** — 그 사이 자식이 바뀌면 무관한 프로세스를 맞힌다.
no_code "$SH" 'pgrep -P'; rc=$?
ck "[대기] 상한이 표적을 다시 찾지 않는다" "$rc" "그 형태가 있다 — 무관한 자식을 맞힐 수 있다(${GREP_WHY})"
codegrep "$SH" '\[ "\$now" = "\$born" \]'
ck "[대기] 번호 재사용을 시작 시각으로 가른다" $? "번호만 맞으면 남의 프로세스를 끝낸다"
codegrep "$SH" "trap 'kill \"\\\$sleep_pid\""
ck "[대기] 감시자가 제 자식(sleep)을 데려간다" $? "성공할 때마다 고아가 하나씩 쌓인다"
codegrep "$SH" '^tell\(\) .*>&2'
ck "[대기] 맥 안내는 화면(stderr)에만 간다" $? "표준출력으로 새면 기록이 같은 줄로 뒤덮인다"
codegrep "$SH" 'kill -INT "\$pid"'
ck "[대기] 맥 상한은 **Ctrl-C 와 같은 결과**로 끝낸다" $? "새 길을 내면 이미 완벽한 회복 경로를 안 쓴다"

codegrep "$PS" '^\$LoginSayInterval  = 60';  ck "[대기] 윈 안내 간격 60초" $? "같음"
codegrep "$PS" '^\$LoginWaitTimeout  = 1200'; ck "[대기] 윈 승인 대기 상한 20분" $? "같음"
codegrep "$PS" '\-NoNewWindow \-PassThru'
ck "[대기] 윈도 승인은 이 창을 그대로 쓴다" $? "새 창으로 띄우면 붙여넣을 자리가 갈린다"
# ★윈은 앞에서 `Start-Sleep` 로 돌면 **이 창의 입력을 자식과 함께 쥔다**(붙여넣기가 샌다).
#   `WaitForExit(ms)` 는 커널 대기라 콘솔을 건드리지 않는다.
codegrep "$PS" 'while \(\-not \$loginProc\.WaitForExit\(5000\)\)'
ck "[대기] 윈이 콘솔을 안 건드리며 기다린다" $? "앞에서 자면 입력을 자식과 다툰다"
no_code "$PS" 'Out-Host'; rc=$?
ck "[대기] 윈 승인 갈래에 파이프가 없다" "$rc" "파이프는 「대화 중인가」 판정을 깨 코드 칸이 안 뜬다(${GREP_WHY})"
codegrep "$PS" 'CloseMainWindow\(\)'
ck "[대기] 윈 상한은 부드럽게 먼저 닫는다" $? "바로 죽이면 잠금·임시 파일을 못 치운다"
codegrep "$PS" '\$loginProc\.Kill\(\)'
ck "[대기] 그래도 안 닫히면 끝낸다" $? "말만 하고 안 끝낸다"
codegrep "$PS" '\[Console\]::Error\.WriteLine'
ck "[대기] 윈 안내도 화면(stderr)에만 간다" $? "기록이 같은 줄로 뒤덮인다"
# ★두 OS 가 **같은 값**을 써야 한다 — 한쪽만 고치면 같은 사고가 다른 기계에서 다시 난다.
# ⚠값만 떼어 온다 — 줄 전체에서 숫자를 긁으면 **주석의 숫자까지 붙는다**
#   (작성 중 실측: `# 초 (20분)` 의 20 이 딸려 와 1200 이 120020 이 됐다).
#   ★같은 줄에 사람 말이 있으면 계기가 흔들린다 — 계기는 값만 봐야 한다.
a="$(sed -n 's/^LOGIN_WAIT_TIMEOUT=\([0-9][0-9]*\).*/\1/p' "$SH" | head -1)"
b="$(sed -n 's/^\$LoginWaitTimeout *= *\([0-9][0-9]*\).*/\1/p' "$PS" | head -1)"
[ -n "$a" ] && [ "$a" = "$b" ]
ck "[대기] 두 OS 상한이 같다($a ↔ $b)" $? "한쪽만 고쳤다"

# 더블을 실제로 돌린다 — 정적 축만 두면 「그 줄이 있다」까지만 보고 **동작은 안 본다**.
if [ -f "$DIR/../tests/login-wait-double.sh" ]; then
  bash "$DIR/../tests/login-wait-double.sh" >/dev/null 2>&1
  ck "[대기] 더블이 전건 통과한다(말한다·끝낸다·붙여넣기가 산다)" $? "동작이 깨졌다 — bash tests/login-wait-double.sh 로 자세히"
else
  sk "[대기] 더블" "시험 파일을 못 찾았다"
fi

printf '\n통과 %s · 실패 %s%s\n' "$pass" "$fail" "$([ "$skip" -gt 0 ] && printf ' · 건너뜀 %s' "$skip")"
[ "$fail" -eq 0 ]
