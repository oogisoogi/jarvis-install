#!/bin/bash
# 자비스 설치 도우미 — 맥
#
# 하는 일 4가지
#   1) 이 컴퓨터의 상태를 살펴 환경 보고 1장을 쓴다
#   2) 클로드 코드가 없거나 낡았으면 공식 설치기로 설치한다
#   3) 로그인 화면을 열고 승인이 끝날 때까지 기다린다
#   4) 자비스를 깨워 환경 보고를 사람 말로 옮겨 준다
# 같은 줄을 다시 돌리면 끝난 단계는 건너뛰고 이어서 간다.
#
# 쓰는 법
#   bash bootstrap.sh                 전 단계
#   bash bootstrap.sh --detect-only   살펴보기만 하고 환경 보고 1장을 쓴 뒤 끝낸다
#   bash bootstrap.sh --dry-run       판정은 다 하되 바깥을 바꾸는 행위는 하지 않는다
#
# 배포 한 줄 (사람이 터미널에 붙여넣는 것)
#   curl -fsSL https://jarvis.godmeyou.kr/install/bootstrap.sh -o "$HOME/install-jarvis.sh" && bash "$HOME/install-jarvis.sh"
#   내려받는 자리를 임시 폴더에서 사용자 폴더로 옮겼다(2026-09-06 · 윈도우판과 같은 성질).
#   임시 폴더는 언제든 비워질 수 있고, 무엇이 걸렸는지 나중에 물을 때 그 파일이 남아 있어야 한다.
#   따옴표로 감싼 까닭 = 사용자 폴더 이름에 공백이나 우리말이 들어 있어도 한 덩어리로 넘어가게.
#   `curl ... | bash` 형태를 쓰지 않는다: 그 형태에서는 $0 이 파일이 아니라 -h 가 깨지고,
#   마지막에 클로드를 띄울 때 EOF 파이프를 stdin 으로 물려받아 대화형 세션이 서지 않는다.
#   아래 두 방어는 그래도 파이프로 들어왔을 때를 위한 것이다.
#
# set -e 를 쓰지 않는다: 이 스크립트는 실패를 죽음이 아니라 판정값(enum)으로 적는다.
# 규율: sudo 를 쓰지 않는다 · 시스템 설정을 바꾸지 않는다 · 외부 주소는 공식 2곳만 쓴다

set -u

BOOTSTRAP_VERSION="v1"
REPORT_HEAD="[자비스] 환경 보고 v0"      # 첫 응답의 고정 첫 줄 — 기동 성공 판정에 쓴다

# ── 핀 (외부 URL은 이 두 줄이 전부다) ─────────────────────────────
CLAUDE_INSTALL_URL="https://claude.ai/install.sh"
CYS_SITE_URL="https://www.cysinsight.com/"   # 공식 안내 문서가 쓰는 주소 문자열을 그대로 따른다

# ── 자리 ──────────────────────────────────────────────────────────
# 점 없는 이름을 쓴다(2026-09-04 개정 · 이유 둘):
JARVIS_HOME="${JARVIS_HOME:-$HOME/install-jarvis}"
LOG_FILE="$JARVIS_HOME/bootstrap.log"
REPORT_FILE="$JARVIS_HOME/env-report.md"
DIRECTIVE_FILE="$JARVIS_HOME/install-directive.md"
DL_DIR="$JARVIS_HOME/dl"
BLOCKED_STEP=""

# cys 설치 파일 — 판본이 파일 이름에 박혀 배포되므로 여기에 핀한다.
CYS_VERSION="0.14.29"
CYS_DOWNLOAD_DIR="https://www.cysinsight.com/downloads/"
case "$(uname -m)" in
  arm64) CYS_MAC_FILE="cys_${CYS_VERSION}_aarch64.dmg"; CYS_MAC_BYTES=270338728 ;;
  *)     CYS_MAC_FILE="cys_${CYS_VERSION}_x64.dmg";     CYS_MAC_BYTES=284549706 ;;
esac
CYS_DOWNLOAD_URL="${CYS_DOWNLOAD_DIR}${CYS_MAC_FILE}"

LOGIN_POLL_INTERVAL=3      # 초
LOGIN_POLL_TIMEOUT=600     # 초 (10분)

MODE="full"
for a in "$@"; do
  case "$a" in
    --detect-only) MODE="detect" ;;
    --dry-run)     MODE="dry" ;;
    -h|--help)     [ -f "$0" ] && sed -n '1,18p' "$0" || echo "쓰는 법: bash bootstrap.sh [--detect-only|--dry-run]"; exit 0 ;;
    *) echo "모르는 인자: $a" >&2; exit 2 ;;
  esac
done

mkdir -p "$JARVIS_HOME" || { echo "로그 자리를 만들지 못했습니다: $JARVIS_HOME" >&2; exit 3; }

log() { printf '%s %s\n' "$(date '+%Y-%m-%dT%H:%M:%S%z')" "$*" >> "$LOG_FILE"; }

#   「내가 중간에 5번 이상 작업을 해야 했다」 · 몇 번이었는지 아무도 정확히 몰랐다).
#   $1 = 누가 강제하는가(OS·벤더·우리) — 「우리」가 하나라도 남으면 그것이 우리가 고칠 몫이다.
HUMAN_HANDS=0
human() {
  HUMAN_HANDS=$((HUMAN_HANDS + 1))
  say "[사람 손 #${HUMAN_HANDS} · 강제: $1] $2"
}
say() { printf '%s\n' "$*"; log "$*"; }

redact() { printf '%s' "$1" | sed "s|$HOME|~|g"; }

#   왜 판본 숫자로 재지 않는가: 우리가 실제로 필요한 것은 「이 명령이 있는가」이지 숫자가 아니다.
#     하위명령이 아니라 질문으로 읽고 세션을 띄운다(rc=0). ⇒ 3초 폴링이 모델 호출 200회가 된다.
#     `--help` 는 어느 판본에서도 플래그이고 질문이 되지 않는다.
claude_has_auth_cmd() {
  claude --help 2>/dev/null | grep -qE '^[[:space:]]*auth[[:space:]]'
}

# ── 감지 행 적재 ──────────────────────────────────────────────────
# 한 행 = 번호 \t 무엇 \t 값 \t enum \t 비고   (bash 3.2 이므로 연관배열을 안 쓴다)
ROWS_FILE="$(mktemp -t jarvis-rows)"
trap 'rm -f "$ROWS_FILE"' EXIT

row() { printf '%s\t%s\t%s\t%s\t%s\n' "$1" "$2" "$3" "$4" "$5" >> "$ROWS_FILE"; }

S1_CLAUDE_OK=0; S1_LOGGED_IN=0; S1_CYS_PRESENT=0

detect_stage1() {
  # 1-1 OS·아키텍처
  local os arch
  os="$(uname -s 2>/dev/null)"; arch="$(uname -m 2>/dev/null)"
  if [ -n "$os" ] && [ -n "$arch" ]; then
    row "1-1" "OS·아키텍처" "$os · $arch" "ok" "-"
  else
    row "1-1" "OS·아키텍처" "-" "failed" "uname 이 답하지 않았다"
  fi

  # 1-2 클로드가 깔렸는가·판본  자동 판올림이 도므로 판본을 게이트로 쓰지 않는다
  local cver cpath
  cver="$(claude --version 2>/dev/null | head -1)"
  cpath="$(command -v claude 2>/dev/null)"
  #   「명령은 있는데 판본을 못 읽는다」(반쪽 설치)를 같은 unknown·같은 문안**으로 찍었다.
  #   윈도우판은 이미 세 갈래였다 ⇒ 두 OS 동등 위반이기도 했다.
  if [ -n "$cver" ] && claude_has_auth_cmd; then
    S1_CLAUDE_OK=1
    row "1-2" "클로드 판본" "$cver" "ok" "$(redact "$cpath")"
  elif [ -n "$cver" ]; then
    #   「이미 있음」으로 보고 설치 갈래를 통째로 건너뛰었다. 있다고 쓸 수 있는 것은 아니다.
    S1_CLAUDE_OK=0
    row "1-2" "클로드 판본" "$cver" "blocked" "낡음 — 판올림이 필요하다($(redact "$cpath") · 로그인 명령을 모르는 판본)"
  elif [ -n "$cpath" ]; then
    row "1-2" "클로드 판본" "-" "failed" "명령은 있는데 판본을 못 읽었다 (반쪽 설치 — 정상값 아님)"
  else
    row "1-2" "클로드 판본" "-" "unknown" "claude 명령이 없다 (설치 전 정상값)"
  fi

  # 1-3 로그인·구독 등급  출력의 나머지 칸(email·orgId·orgName·projectsDirectory)은 옮기지 않는다
  if [ -n "$cver" ] && ! claude_has_auth_cmd; then
    # 여기서 `auth status` 를 부르면 그 문자열이 질문으로 나간다(모델 호출 1회). 부르지 않는다.
    row "1-3" "로그인·구독" "-" "unknown" "이 판본은 로그인 확인 명령을 모른다 — 판올림 뒤에 다시 본다"
  elif [ "$S1_CLAUDE_OK" = "1" ]; then
    local auth logged sub
    auth="$(claude auth status 2>/dev/null)"
    logged="$(printf '%s' "$auth" | grep -o '"loggedIn"[[:space:]]*:[[:space:]]*[a-z]*' | grep -o '[a-z]*$')"
    sub="$(printf '%s' "$auth" | grep -o '"subscriptionType"[[:space:]]*:[[:space:]]*"[^"]*"' | sed 's/.*"\([^"]*\)"$/\1/')"
    if [ "$logged" = "true" ]; then
      S1_LOGGED_IN=1
      row "1-3" "로그인·구독" "loggedIn=true · subscriptionType=${sub:-미상}" "ok" "나머지 칸은 옮기지 않는다"
    elif [ "$logged" = "false" ]; then
      row "1-3" "로그인·구독" "loggedIn=false" "blocked" "사람이 승인 클릭을 해야 한다"
    else
      row "1-3" "로그인·구독" "-" "unknown" "auth status 를 읽지 못했다"
    fi
  else
    row "1-3" "로그인·구독" "-" "unknown" "클로드가 아직 없다"
  fi

  # 1-4 cys 가 이미 있는가  깨끗한 기계의 정상값은 「없음」이다
  # 존재의 뜻을 「명령이 잡히는가」 하나로 못박는다. 앱 폴더가 있다는 것만으로 2단을 돌리면,
  local cysapp cyscmd cys_enum cys_note
  cysapp="없음"; [ -d /Applications/cys.app ] && cysapp="있음"
  cyscmd="$(command -v cys 2>/dev/null)"
  [ -n "$cyscmd" ] && S1_CYS_PRESENT=1
  #   다른 계정이 깐 앱이 보이는 상황을 「없음이 정상」이라는 문구로 설명하고 있었다(2차 보고에서 그대로 드러남).
  local cys_onboard cys_state
  cys_onboard="없음"; [ -d "$HOME/.cys" ] && cys_onboard="있음"
  if [ "$cysapp" = "없음" ] && [ -z "$cyscmd" ]; then
    cys_state="없음"; cys_enum="ok"
    cys_note="★깨끗한 기계의 정상값이다 (고장 아님)"
  elif [ "$cys_onboard" = "있음" ]; then
    cys_state="앱+온보딩"; cys_enum="ok"
    cys_note="이 계정에 이미 자리를 잡았다"
  elif [ -n "$cyscmd" ] || [ "$cysapp" = "있음" ]; then
    cys_state="앱만"; cys_enum="blocked"
    cys_note="★프로그램은 이 컴퓨터에 있으나 **이 계정에는 아직 자리를 안 잡았다**(다른 계정이 설치한 경우 정상) — 계정 단위 준비가 남았다"
  else
    cys_state="판정 불가"; cys_enum="unknown"; cys_note="-"
  fi
  row "1-4" "cys 상태" "$cys_state (앱=$cysapp · 명령=${cyscmd:-없음} · 계정 준비=$cys_onboard)" "$cys_enum" "$cys_note"

  # 1-5 놓을 자리에 쓸 수 있는가
  if [ -w /Applications ]; then
    row "1-5" "/Applications 쓰기" "true · $(ls -ld /Applications | awk '{print $1, $3, $4}')" "ok" "-"
  else
    row "1-5" "/Applications 쓰기" "false" "blocked" "고장이 아니라 계정 성격이다(표준 계정) — 프로그램을 컴퓨터 전체 자리에 놓을 때만 이 컴퓨터를 관리하는 분의 도움이 필요하다"
  fi

  # 1-6 관리자 그룹인가
  if id -Gn 2>/dev/null | tr ' ' '\n' | grep -qx admin; then
    row "1-6" "관리자 그룹" "admin 포함" "ok" "권한 상승은 하지 않는다"
  else
    #   윈도우 실기에서 `1-6` 이 blocked 인데 전 과정이 완주했다 — 로그인·기동·첫 응답까지 아무것도 안 막혔다.
    #   `blocked` 의 뜻은 「사람이 무엇을 하면 풀린다」인데 표준 계정은 풀 것이 없다. 정상값을 적색으로 적고
    #   맞게 만드는 것은 건너뛰었다** — 양쪽이 같아지니 대조 검사로는 안 잡혔다. ⇒ 양쪽 다 ok + 비고로 간다.
    #   관리자가 실제로 필요해지는 자리가 생기면 그 행이 그때 blocked 를 낸다.
    row "1-6" "관리자 그룹" "admin 없음" "ok" "고장이 아니라 계정 성격이다(표준 계정) — 지금까지의 단계는 이 권한 없이 끝났다"
  fi

  #         `/usr/local/bin/cysd` → `/Volumes/cys/cys.app/…/cysd` 끊어짐(DMG 마운트 경로를 가리킨다)
  #   ⇒ `cys daemon install` 이 `cysd binary not found next to cys` 로 실패한다.
  #   우회는 sudo 가 필요 없다 — 앱 내부 실경로를 직접 부르면 된다. 링크 고치기(ln -sfn)는 sudo 라 우리 몫이 아니다.
  local app_cysd="/Applications/cys.app/Contents/MacOS/cysd"
  local link_state link_enum link_note
  if [ -e /usr/local/bin/cysd ] && [ -e /usr/local/bin/cys ]; then
    link_state="유효"; link_enum="ok"; link_note="-"
  elif [ -x "$app_cysd" ]; then
    link_state="cysd 링크 끊어짐 · 앱 내부 실행 파일은 있음"
    link_enum="blocked"
    link_note="★고칠 필요 없다 — 앱 안 실경로($app_cysd)를 직접 부르면 된다(관리자 권한 불요). 링크 자체를 고치는 것은 관리자 일이라 우리가 하지 않는다"
  elif [ -e /usr/local/bin/cys ] || [ -d /Applications/cys.app ]; then
    link_state="cysd 를 못 찾음"; link_enum="failed"
    link_note="링크도 끊어졌고 앱 안에도 없다 — 다시 설치해야 한다"
  else
    link_state="해당 없음(cys 미설치)"; link_enum="ok"; link_note="아직 cys 가 없다 — 정상"
  fi
  row "1-8" "cys 실행 링크" "$link_state" "$link_enum" "$link_note"

  # 1-7 네트워크 — 연결 성립 여부만 본다 (응답 내용을 판정에 쓰면 형식 변경에 약해진다)
  local u code net_enum="ok" net_val=""
  for u in "$CLAUDE_INSTALL_URL" "$CYS_SITE_URL"; do
    code="$(curl -sS -o /dev/null -m 8 -w '%{http_code}' -I "$u" 2>/dev/null)"
    net_val="$net_val$u=${code:-실패} "
    case "${code:-000}" in
      2*|3*) : ;;
      *) net_enum="failed" ;;
    esac
  done
  row "1-7" "네트워크(공식 2곳)" "$net_val" "$net_enum" "연결 성립만 본다 · 본문을 판정에 안 쓴다"
}

detect_stage2() {
  # 이 단은 명령이 잡힐 때만 돈다. 안 잡히면 한 행짜리 unknown 으로 접는다 —
  if [ "$S1_CYS_PRESENT" != "1" ]; then
    row "2-*" "cys 이후 전 행" "-" "unknown" "cys 명령이 아직 없습니다 — 다음 단계에서 합니다"
    return
  fi
  local v
  v="$(cys phoenix-identity 2>/dev/null)"
  if [ -n "$v" ]; then row "2-1" "cys 판본·팩 해시" "$v" "ok" "데몬 없어도 답한다"
  else row "2-1" "cys 판본·팩 해시" "-" "failed" "명령이 답하지 않았다"; fi

  #     소켓 파일 자체가 없음  = `No such file or directory (os error 2)`  ⇒ 이 계정에 온보딩이 안 된 것(정상 가능)
  #     소켓은 있는데 무응답    = `Connection refused (os error 61)`        ⇒ 데몬이 안 떠 있다(기동 직후 지연 포함)
  v="$(cys ping 2>&1)"
  case "$v" in
    pong*)
      row "2-2" "데몬 생존" "pong" "ok" "-" ;;
    *"No such file"*)
      row "2-2" "데몬 생존" "소켓 없음" "blocked" "데몬이 죽은 것이 아니다 — 이 계정에 아직 자리를 안 잡았다(소켓은 계정 단위). 계정 준비로 풀린다" ;;
    *"Connection refused"*)
      row "2-2" "데몬 생존" "응답 없음" "failed" "소켓은 있는데 데몬이 안 떠 있습니다 — 방금 켠 직후라면 잠시 뒤 다시 보십시오" ;;
    *)
      row "2-2" "데몬 생존" "${v:-무응답}" "unknown" "처음 보는 응답이다 — 위 두 갈래 어느 쪽인지 모른다" ;;
  esac

  v="$(cys agent-detect 2>/dev/null | head -5)"
  if [ -n "$v" ]; then row "2-4" "어댑터 감지" "$(printf '%s' "$v" | tr '\n' ' ')" "ok" "-"
  else row "2-4" "어댑터 감지" "-" "unknown" "-"; fi

  v="$(cys doctor 2>/dev/null | grep '^요약' | head -1)"
  if [ -n "$v" ]; then row "2-5" "cys 자가점검" "$v" "ok" "요약 줄만 옮겨 적습니다"
  else row "2-5" "cys 자가점검" "-" "unknown" "-"; fi

  row "2-8" "첫 세션 지시 주입" "-" "unknown" "아직 확인하는 방법이 없습니다"
}

write_report() {
  local total ok blocked failed unknown verdict
  total="$(wc -l < "$ROWS_FILE" | tr -d ' ')"
  ok="$(cut -f4 "$ROWS_FILE" | grep -cx ok)"
  blocked="$(cut -f4 "$ROWS_FILE" | grep -cx blocked)"
  failed="$(cut -f4 "$ROWS_FILE" | grep -cx failed)"
  unknown="$(cut -f4 "$ROWS_FILE" | grep -cx unknown)"
  if [ "$failed" -gt 0 ]; then verdict="failed"
  elif [ "$blocked" -gt 0 ]; then verdict="blocked"
  elif [ "$unknown" -gt 0 ]; then verdict="unknown"
  else verdict="ok"; fi

  {
    printf '%s\n\n' "$REPORT_HEAD"
    # 포맷 문자열이 '-' 로 시작하면 bash printf 가 그것을 옵션으로 읽는다. 그래서 '%s\n' 로 감싼다.
    printf '%s\n' "- 언제: $(date '+%Y-%m-%dT%H:%M:%S%z')"
    printf '%s\n' "- 부트스트랩 판본: $BOOTSTRAP_VERSION · 모드: $MODE"
    printf '%s\n' "- 종합 판정: **$verdict** (ok $ok · blocked $blocked · failed $failed · unknown $unknown / 전 ${total}행)"
    printf '%s\n\n' "  - \`unknown\` 은 「완료됨」으로 세지 않는다."
    printf '\n## 지금 상태 → 다음 행동\n'
    if [ -n "$BLOCKED_STEP" ]; then
      printf -- '- **막힌 단계: %s**\n' "$BLOCKED_STEP"
      printf -- '- 앞 단계(클로드 설치·로그인·자비스 준비)는 **이미 끝났습니다.** 여기부터 다시 이어서 갑니다.\n'
      printf -- '- 그 **다음 단계들은 아직 하지 않았습니다** — 실패한 것이 아니라 순서가 안 온 것입니다.\n'
    printf -- '- 같은 한 줄을 다시 돌리면 **끝난 단계는 건너뛰고 막힌 자리부터** 갑니다.\n'
    else
      printf -- '- 막힌 단계 없음.\n'
    fi
    printf '\n| # | 무엇 | 값 | 판정 | 비고 |\n|---|---|---|---|---|\n'
    while IFS="$(printf '\t')" read -r a b c d e; do
      printf '| %s | %s | `%s` | **%s** | %s |\n' "$a" "$b" "$(redact "$c")" "$d" "$e"
    done < "$ROWS_FILE"
    printf '\n이 보고에 담지 않는 것: 이름 · 연락처 · 계정 식별자(email·orgId·orgName) · 시크릿 값 · 파일 내용.\n'
    printf '경로의 사용자 폴더 이름은 `~` 로 줄여 적었습니다.\n'
  } > "$REPORT_FILE"

  say "환경 보고를 썼습니다: $(redact "$REPORT_FILE")  (종합 판정 = $verdict)"
}

# ── 하는 일 2 — 공식 설치기 호출 (멱등: 이미 있으면 건너뛴다) ─────
step_install_claude() {
  if [ "$S1_CLAUDE_OK" = "1" ]; then
    say "[2/11] 클로드가 이미 있습니다 — 건너뜁니다 (멱등)."
    return 0
  fi
  if [ -n "$(command -v claude 2>/dev/null)" ]; then
    say "[2/11] 이 컴퓨터의 클로드가 낡았습니다($(claude --version 2>/dev/null | head -1)). 최신판을 설치합니다."
  fi
  if [ "$MODE" = "dry" ]; then
    say "[2/11] (dry-run) 설치기를 부르지 않았습니다. 부를 줄 = curl -fsSL $CLAUDE_INSTALL_URL | bash"
    return 0
  fi
  say "[2/11] 클로드 코드를 설치합니다. 글자가 주르륵 올라갑니다 — 정상입니다."
  local rc=0
  ( set -o pipefail; curl -fsSL "$CLAUDE_INSTALL_URL" | bash ) || rc=$?
  if [ "$rc" -ne 0 ]; then
    say "[2/11] 실패 (종료 코드 $rc). 인터넷 연결을 확인해 주십시오. 같은 한 줄을 다시 돌리면 여기서부터 이어서 갑니다."
    return "$rc"
  fi
  #   깨끗한 기계에서 매번 rc 4 로 끝나 「한 줄」 약속이 「한 줄 · 새 창 · 한 줄」이 된다.
  case ":$PATH:" in
    *":$HOME/.local/bin:"*) : ;;
    *) PATH="$HOME/.local/bin:$PATH"; export PATH ;;
  esac
  hash -r 2>/dev/null || true
  # 실행 결과 검사 = 설치기의 종료 코드가 아니라 명령이 답하는가
  if ! claude --version >/dev/null 2>&1; then
    say "[2/11] 설치기는 끝났는데 claude 명령이 아직 안 잡힙니다. 창을 새로 열고 다시 돌려 주십시오."
    return 4
  fi
  #   새로 깐 것이 PATH 에서 이겨야 한다. 위에서 `$HOME/.local/bin` 을 앞에 붙였으므로 이기는 것이
  local nowpath
  nowpath="$(command -v claude 2>/dev/null)"
  case "$nowpath" in
    "$HOME"/.local/bin/*) : ;;
    *) say "[2/11] ⚠새로 깐 클로드가 아니라 $(redact "$nowpath") 가 먼저 잡힙니다. 창을 새로 열고 다시 돌려 주십시오."
       return 4 ;;
  esac
  if ! claude_has_auth_cmd; then
    say "[2/11] 설치는 끝났는데 아직 낡은 판본이 잡힙니다. 창을 새로 열고 다시 돌려 주십시오."
    return 4
  fi
  S1_CLAUDE_OK=1
  say "[2/11] 완료: $(claude --version 2>/dev/null | head -1) ($(redact "$nowpath"))"
}

# ── 하는 일 3 — 로그인 유도 + 완료 감지 ───────────────────────────
step_login() {
  if [ "$S1_LOGGED_IN" = "1" ]; then
    say "[3/11] 이미 로그인돼 있습니다 — 건너뜁니다 (멱등)."
    return 0
  fi
  if [ "$MODE" = "dry" ]; then
    say "[3/11] (dry-run) 폴링하지 않았습니다. 간격 ${LOGIN_POLL_INTERVAL}초 · 상한 ${LOGIN_POLL_TIMEOUT}초."
    return 0
  fi
  if ! claude_has_auth_cmd; then
    say "[3/11] 이 판본의 클로드는 로그인 확인 명령을 모릅니다. 판올림이 먼저 필요합니다."
    say "     같은 한 줄을 다시 돌리면 판올림부터 이어서 갑니다."
    return 6
  fi
  human "벤더" "로그인 승인 클릭 — 클로드 회사 화면에서만 할 수 있다(우리가 대신 못 누른다)"
  say "[3/11] 지금 로그인 화면을 엽니다. 브라우저가 뜨면 승인을 눌러 주십시오."
  claude auth login || true
  say "     승인이 끝났는지 확인합니다. 최대 $((LOGIN_POLL_TIMEOUT / 60))분까지 기다립니다."
  local waited=0 logged
  while [ "$waited" -lt "$LOGIN_POLL_TIMEOUT" ]; do
    logged="$(claude auth status 2>/dev/null | grep -o '"loggedIn"[[:space:]]*:[[:space:]]*true')"
    if [ -n "$logged" ]; then
      S1_LOGGED_IN=1
      say "[3/11] 로그인 확인했습니다."
      return 0
    fi
    sleep "$LOGIN_POLL_INTERVAL"
    waited=$((waited + LOGIN_POLL_INTERVAL))
  done
  say "[3/11] $((LOGIN_POLL_TIMEOUT / 60))분 동안 로그인이 확인되지 않았습니다. 같은 한 줄을 다시 돌리면 여기서부터 이어서 갑니다."
  return 5
}

# ── 하는 일 4 — 자비스 기동 (지침 파일 + 첫 지시 주입) ───────
write_directive() {
  cat > "$DIRECTIVE_FILE" <<DIRECTIVE
# 자비스 설치 도우미 지침

너는 이 컴퓨터의 설치를 대신 해 주는 자비스다. 상대는 처음 설치하는 사람이다.

## 첫 응답 규칙 (불변)
첫 응답의 **첫 줄은 반드시 아래 문자열 하나**로 시작한다. 이 줄이 곧 기동 성공의 판정 신호다.

    $REPORT_HEAD

그 다음 줄부터 아래 파일을 읽어 표로 옮겨 적는다.

    $(redact "$REPORT_FILE")
## 하지 않는 것

1. 우리 키·계정을 쓰지 않는다.
2. 원격 제어를 하지 않는다.
3. **sudo·관리자 권한 상승을 스스로 실행하지 않는다.** 권한 대화상자는 사람이 누른다.
4. 사용자 파일을 열지 않는다.
5. 되돌릴 길이 없는 행동을 스스로 하지 않는다.
6. 이 컴퓨터에 우리 조직의 운영 자산을 놓지 않는다.

## 무개입 기본 (이 지침에서 가장 중요한 규칙)

★**사람이 누르는 것은 「운영체제나 회사가 강제해서 우리가 대신 못 누르는 것」뿐이다.** 그 밖의 모든 것은 네가 한다.
지금 그 목록은 **로그인 승인 클릭 하나**다(관리자 비밀번호는 다음 단계에서 나온다).
⛔**그 목록에 없는 이유로 사람을 멈춰 세우지 마라. 묻는 것도 일이다.**

1. **읽기 전용 확인은 묻지 말고 그냥 해라.** 파일 읽기·상태 명령·원인 좁히기는 전부 네 몫이다. 끝난 뒤에 알아낸 것을 말해라.
   ⛔「확인해 볼까요?」·「진행할까요?」를 확인 작업 앞에 붙이지 마라.
2. **갈림길에서 고르라고 하지 마라.** 무엇을 할지는 아래 기본 정책이 정해 두었다. **정책대로 실행하고, 무엇을 왜 했는지 사후에 보고해라.**
3. **바꾸기 전에 묻는 것은 「되돌릴 길이 없는 변경」뿐이다.** 되돌리는 방법이 있는 변경은 묻지 말고 하고, **어떻게 되돌리는지를 함께 적어라.**
4. **「어느 칸부터 볼까요」류 질문 금지.** 순서는 보고 표의 순서 그대로다.

## 기본 정책 (갈림길에서 묻지 말고 이대로)

| 상태 | 기본 행동 |
|---|---|
| 어떤 칸이 「blocked」 인데 **계정 성격 때문**이다(표준 계정) | **고장이 아니라고 설명만** 하고 넘어간다. 사람을 부르지 않는다 |
| 「cys」 상태가 **「앱만」**(프로그램은 있는데 이 계정에 자리를 안 잡음) | ★**계정 준비는 관리자 권한 없이 되는 일이다.** 다음 단계에서는 **묻지 말고 대행하는 것이 기본**이다(지금 범위에서는 그 사실을 보고만 한다) |
| 「cys 실행 링크」 가 **끊어짐**으로 나온다 | ★**고장으로 보고하지 마라.** 앱 안 실경로를 직접 부르면 되고 **관리자 권한이 필요 없다.** 링크 자체를 고치는 것(「sudo ln」)은 **우리 일이 아니다 — 제안만 하고 실행하지 마라** |
| 「unknown」 인 칸 | 「됐다」로 세지 않는다. **왜 모르는지**를 한 줄로 말한다 |
| 사람이 진짜로 필요한 자리 | **그때만** 부른다. 무엇을·왜·어디를·되면·안 되면 다섯 가지를 함께 말한다 |
## 첫 응답 말미에 반드시 붙이는 한 줄

첫 응답 **맨 끝**에 이 뜻의 한 줄을 붙여라:

    입력창에 흐린 회색 글씨가 보이면 그건 제가 미리 적어 둔 **제안**입니다 — 쓰셔도 되고 그냥 무시하고 다른 걸 치셔도 됩니다.

🔴**왜**: 2차 실기에서 입력창에 회색으로 「cys 다시 설치해줘」가 떠 있었고, **사람이 「내가 안 쳤는데?」로 읽었다.**
설치를 처음 하는 사람에게 **「내가 안 한 일이 일어났다」는 인상은 신뢰를 깎는다.** 한 줄이면 사라진다.
## 지금 할 일의 범위

- **cys 설치·계정 준비 대행은 아직 네 일이 아니다**(다음 단계).
- 네가 지금 하는 일은 **환경 보고를 사람 말로 옮겨 주고, 막힌 칸의 원인을 갈라 주는 것**이다.
- ★**「blocked」 가 곧 고장은 아니다.** ⑴표준 계정이라 그런 것인지 ⑵이 계정에 아직 자리를 안 잡아서 그런 것인지를 **먼저 갈라서** 말해라.
DIRECTIVE
  say "지침 파일을 놓았습니다: $(redact "$DIRECTIVE_FILE")"
}

#   `python3` 를 쓰지 마라 — 깨끗한 맥에서 `python3` 는 명령행 도구 설치 프롬프트를 띄운다 ⇒ 개입이 늘어난다.
#     `"hasCompletedOnboarding": true` (최상위) · `"hasTrustDialogAccepted": true` (`projects.<폴더>` 아래)
# 자비스가 부르는 동료 노드는 **개인 설정이 아니라 자비스 전용 설정**으로 뜬다(윈도우 실측 2026-09-05).
# 그래서 사전 설정을 두 자리에 모두 심는다. 자리는 짐작하지 않고 **있는 것만** 쓴다.
profile_configs() {
  printf '%s\n' "$HOME/.claude.json"
  [ -d "$HOME/.cys/claude" ] && printf '%s\n' "$HOME/.cys/claude/.claude.json"
  return 0
}
profile_settings() {
  printf '%s\n' "$HOME/.claude/settings.json"
  [ -d "$HOME/.cys/claude" ] && printf '%s\n' "$HOME/.cys/claude/settings.json"
  return 0
}

# 글자 모양 질문(「Choose the text style」)의 열쇠는 .claude.json 이 아니라 이 파일에 있다.
seed_claude_settings() {
  local sf="$1"
  mkdir -p "$(dirname "$sf")" 2>/dev/null
  [ -f "$sf" ] || printf '{"theme":"dark"}\n' > "$sf" || return 1
  plutil -replace theme -string dark "$sf" >/dev/null 2>&1 \
    || plutil -insert theme -string dark "$sf" >/dev/null 2>&1
  plutil -replace skipDangerousModePermissionPrompt -bool true "$sf" >/dev/null 2>&1 \
    || plutil -insert skipDangerousModePermissionPrompt -bool true "$sf" >/dev/null 2>&1
  plutil -replace remoteControlAtStartup -bool false "$sf" >/dev/null 2>&1 \
    || plutil -insert remoteControlAtStartup -bool false "$sf" >/dev/null 2>&1
  log "seed: $(redact "$sf") theme·skipDangerousModePermissionPrompt·remoteControlAtStartup"
  return 0
}

# 이 함수는 두 번 불린다 — 자비스 전용 자리는 [8] 에서 자리를 잡은 뒤에야 생기기 때문이다.
seed_all_profiles() {
  local p
  for p in $(profile_configs); do
    seed_claude_prefs "$p" || human "벤더" "클로드 첫 실행 질문($(redact "$p") 자리에 사전 설정을 못 걸었다)"
  done
  for p in $(profile_settings); do
    seed_claude_settings "$p" || human "벤더" "설정 파일($(redact "$p"))을 못 썼다"
  done
  return 0
}

seed_claude_prefs() {
  local cfg="${1:-$HOME/.claude.json}"
  if ! command -v plutil >/dev/null 2>&1; then
    say "     (사전 설정 도구가 없어 건너뜁니다. 클로드가 처음 몇 가지를 물을 수 있습니다.)"
    return 1
  fi
  # `plutil -create json` 은 파일을 `{}` 로 만드는데, 키가 하나도 없는 `{}` 는 plutil 이 JSON 으로 못 읽는다
  if [ ! -f "$cfg" ]; then
    printf '{"hasCompletedOnboarding":true}\n' > "$cfg" || return 1
  else
    plutil -replace hasCompletedOnboarding -bool true "$cfg" >/dev/null 2>&1 || true
  fi
  # `projects` 를 무조건 `{}` 로 덮으면 참가자가 이미 쓰던 설정을 지운다. 없을 때만 만든다.
  if ! plutil -extract projects json -o - "$cfg" >/dev/null 2>&1; then
    plutil -replace projects -json '{}' "$cfg" >/dev/null 2>&1
  fi
  plutil -insert "projects.$JARVIS_HOME" -json '{"hasTrustDialogAccepted":true}' "$cfg" >/dev/null 2>&1 \
    || plutil -replace "projects.$JARVIS_HOME" -json '{"hasTrustDialogAccepted":true}' "$cfg" >/dev/null 2>&1
  # 큰 화면 권유 질문은 「본 횟수」가 적을 때만 뜬다(실측: 그 값이 3인 기계에서는 안 떴다).
  plutil -replace fullscreenUpsellSeenCount -integer 99 "$cfg" >/dev/null 2>&1 \
    || plutil -insert fullscreenUpsellSeenCount -integer 99 "$cfg" >/dev/null 2>&1
  say "     첫 실행 질문(테마·폴더 신뢰·큰 화면 권유)을 미리 넘겨 두었습니다."
  log "seed: hasCompletedOnboarding=true · projects.$JARVIS_HOME.hasTrustDialogAccepted=true (되돌리기 = $(redact "$cfg") 삭제)"
  return 0
}

step_prepare() {
  write_directive
  if [ "$MODE" = "dry" ]; then
    say "[4/11] (dry-run) 사전 설정을 쓰지 않았습니다(바깥 변경 0)."
    return 0
  fi
  seed_all_profiles
  say "[4/11] 자비스가 쓸 것을 갖춰 두었습니다."
  return 0
}


# ── 하는 일 5 — cys 설치 파일 받기 ────────────────────────────────
# 완료 판정 = 파일이 있고 크기가 정확히 맞는가. 크기가 다르면 받다 끊긴 것이다.
step_download_cys() {
  mkdir -p "$DL_DIR"
  local dst got try
  dst="$DL_DIR/$CYS_MAC_FILE"
  if [ -f "$dst" ] && [ "$(wc -c < "$dst" | tr -d ' ')" = "$CYS_MAC_BYTES" ]; then
    say "[5/11] 설치 파일이 이미 있습니다 — 건너뜁니다."
    return 0
  fi
  if [ "$MODE" = "dry" ]; then
    say "[5/11] (dry-run) 받지 않았습니다. 받을 곳 = $CYS_DOWNLOAD_URL"
    return 0
  fi
  for try in 1 2; do
    rm -f "$dst"
    say "[5/11] cys 설치 파일을 받습니다 (약 260MB · 잠시 걸립니다)."
    if ! curl -fsSL "$CYS_DOWNLOAD_URL" -o "$dst"; then
      say "[5/11] 받지 못했습니다."
      continue
    fi
    got="$(wc -c < "$dst" | tr -d ' ')"
    if [ "$got" = "$CYS_MAC_BYTES" ]; then
      say "[5/11] 받았습니다 (크기 확인 완료)."
      return 0
    fi
    say "[5/11] 크기가 맞지 않습니다 (받은 것 $got · 기대 $CYS_MAC_BYTES). 다시 받습니다."
  done
  # 두 번 다 실패했으면 반쯤 받은 파일을 남기지 않는다 — 다음 실행이 그것을 온전한 것으로 볼 수 있다.
  rm -f "$dst"
  say "[5/11] 설치 파일을 온전히 받지 못했습니다."
  say "     공식 페이지에서 직접 받으실 수 있습니다: $CYS_SITE_URL"
  say "     받을 파일 이름 = $CYS_MAC_FILE"
  return 5
}

# ── 하는 일 6 — cys 설치 ──────────────────────────────────────────
# 완료 판정은 설치기의 종료 코드가 아니라 프로그램 실체가 생겼는가로 한다.
step_install_cys() {
  if [ -d /Applications/cys.app ]; then
    say "[6/11] cys 가 이미 설치돼 있습니다 — 건너뜁니다."
    return 0
  fi
  local dst mnt
  if [ "$MODE" = "dry" ]; then
    say "[6/11] (dry-run) 설치 파일을 열지 않았습니다."
    return 0
  fi
  dst="$DL_DIR/$CYS_MAC_FILE"
  [ -f "$dst" ] || { say "[6/11] 설치 파일이 없습니다."; return 6; }
  say "[6/11] cys 를 설치합니다."
  mnt="$(hdiutil attach -nobrowse -quiet "$dst" 2>/dev/null | awk '/\/Volumes\//{ $1=""; $2=""; sub(/^[ \t]+/,""); print; exit }')"
  if [ -z "$mnt" ] || [ ! -d "$mnt" ]; then
    say "[6/11] 설치 파일을 열지 못했습니다."
    return 6
  fi
  if [ -d "$mnt/cys.app" ]; then
    cp -R "$mnt/cys.app" /Applications/ 2>/dev/null || {
      say "[6/11] 프로그램 폴더에 복사하지 못했습니다."
      hdiutil detach "$mnt" -quiet 2>/dev/null || true
      return 6
    }
  fi
  hdiutil detach "$mnt" -quiet 2>/dev/null || true
  # 처음 여는 프로그램에는 보안 확인이 뜰 수 있다 — 사람이 눌러야 한다.
  if [ -d /Applications/cys.app ]; then
    say "[6/11] 설치를 마쳤습니다."
    return 0
  fi
  say "[6/11] 설치가 확인되지 않았습니다."
  return 6
}

# ── 하는 일 7 — cys 가 실제로 쓸 수 있는가 ────────────────────────
# 프로그램 실체와 버전 응답 두 가지를 본다.
step_verify_cys() {
  local c ver
  if [ ! -d /Applications/cys.app ]; then
    say "[7/11] cys 프로그램을 찾지 못했습니다."
    return 7
  fi
  say "[7/11] cys 프로그램을 찾았습니다: /Applications/cys.app"
  # 부르는 길이 판본에 따라 다르다. 새 판은 사용자 폴더 안에 두고, 옛 판은 시스템 폴더에 두었다.
  # 옛 자리의 링크가 끊어져 있는 경우가 실제로 있으므로, 찾은 순서대로 쓰되 답하는 것만 쓴다.
  # 프로그램 안쪽 경로는 마지막 수단이고, 우리가 링크를 새로 만들지는 않는다.
  CYS_CLI=""
  for c in "$HOME/.local/bin/cys" "/usr/local/bin/cys" "/Applications/cys.app/Contents/MacOS/cys"; do
    [ -x "$c" ] || continue
    ver="$(CYS_NO_AUTOSTART=1 "$c" --version 2>/dev/null | head -1)"
    if [ -n "$ver" ]; then CYS_CLI="$c"; break; fi
  done
  if [ -z "$CYS_CLI" ]; then
    ver="$(CYS_NO_AUTOSTART=1 cys --version 2>/dev/null | head -1)"
    [ -n "$ver" ] && CYS_CLI="cys"
  fi
  if [ -n "$ver" ] && [ -n "$CYS_CLI" ]; then
    say "[7/11] cys 가 답합니다: $ver"
    say "     부르는 길: $(redact "$CYS_CLI")"
    return 0
  fi
  say "[7/11] 프로그램은 있는데 아직 명령으로 부를 수 없습니다. 창을 새로 열고 같은 줄을 다시 돌려 주십시오."
  return 7
}

# ── 하는 일 8 — 이 계정에 자리 잡기 ───────────────────────────────
# 관리자 권한을 쓰지 않는다. 마지막 판정은 자가진단이 전부 통과하는가로 한다.
step_prepare_account() {
  local cli i pong doc bad
  cli="${CYS_CLI:-cys}"
  if [ "$MODE" = "dry" ]; then
    say "[8/11] (dry-run) 계정 준비를 하지 않았습니다."
    return 0
  fi
  say "[8/11] 이 계정에 자리를 잡습니다."
  "$cli" init-pack || true
  # 프로그램 안의 실제 파일을 직접 부른다 — 중간 연결 고리가 끊겨 있어도 이 길은 열려 있다.
  "$cli" daemon install || true
  # 한 번 응답을 받았으면 그것으로 판정한다. 다시 물으면 그 순간의 흔들림으로 성공이 실패가 된다.
  local alive=0
  i=0
  while [ "$i" -lt 10 ]; do
    pong="$("$cli" ping 2>&1 | tr -d '\n')"
    case "$pong" in *pong*) alive=1; break ;; esac
    sleep 2; i=$((i+1))
  done
  if [ "$alive" -ne 1 ]; then
    say "[8/11] 준비는 됐는데 아직 응답이 없습니다. 잠시 뒤 같은 줄을 다시 돌려 주십시오."
    return 8
  fi
  doc="$(CYS_NO_AUTOSTART=1 "$cli" doctor 2>&1)"
  # 자가진단은 마지막에 요약 한 줄을 낸다: 「요약: 11 OK · 1 WARN · 0 FAIL · 1 SKIP(판정 불가)」
  # 그 줄이 정본이다. 항목 표시는 폭을 맞추느라 [OK  ] 처럼 빈칸이 들어가서 표시만 세면 새어 나간다.
  local summary n_skip
  summary="$(printf '%s\n' "$doc" | grep '요약:' | tail -1)"
  if [ -n "$summary" ]; then
    bad="$(printf '%s\n' "$summary" | sed -n 's/.*[^0-9]\([0-9][0-9]*\)[[:space:]]*FAIL.*/\1/p')"
    n_skip="$(printf '%s\n' "$summary" | sed -n 's/.*[^0-9]\([0-9][0-9]*\)[[:space:]]*SKIP.*/\1/p')"
    say "[8/11] 자가진단: ${summary#*요약: }"
  else
    bad="$(printf '%s\n' "$doc" | grep -c '\[FAIL *\]' | tr -d ' ')"
    n_skip="$(printf '%s\n' "$doc" | grep -c '\[SKIP *\]' | tr -d ' ')"
    say "[8/11] 자가진단 요약 줄을 찾지 못해 항목을 세었습니다: 실패 ${bad:-0}"
  fi
  # 통과 기준은 실패 0 이다. 주의는 성한 컴퓨터에도 나온다.
  if [ "${bad:-0}" -gt 0 ]; then
    say "[8/11] 자가진단에서 ${bad}가지가 통과하지 못했습니다."
    say "     아래 자비스가 무엇이 걸렸는지 사람 말로 알려 드립니다."
    return 8
  fi
  # 판정 못 한 항목은 「됐다」로 세지 않는다 — 몇 개인지 그대로 알린다.
  if [ "${n_skip:-0}" -gt 0 ]; then
    say "     (${n_skip}가지는 이 컴퓨터에서 판정할 수 없는 항목입니다 — 고장이 아닙니다.)"
  fi
  # 자리를 잡으면서 자비스 전용 설정 자리가 새로 생긴다 — 동료들이 그 자리로 뜨므로 한 번 더 심는다.
  seed_all_profiles
  say "[8/11] 자리를 잡았습니다 (실패 0)."
  return 0
}

# ── 하는 일 10 — 첫 함대 부르기 ───────────────────────────────────
# 자비스는 사람이 「너는 마스터다」라고 말해야 깨어나 동료를 부른다. 그 말을 우리가 대신 넣는다.
# ⛔이 문장을 우리가 대신 넣지 않는다. 자비스에는 「사람이 직접 친 선언만 팀을 부른다」는 장치가
#   있고(기계가 넣은 것은 알아보고 거절한다 — 2026-09-05 실측), 그 장치는 옳다.
#   우리가 하는 일 = 어디에 무엇을 칠지 알려 주고, 기다리고, 선 자리를 확인해 주는 것.
FLEET_TRIGGER='너는 마스터다'
FLEET_WAIT_TRIES=72   # 5초 × 72 = 6분
FLEET_ROLES='master cso worker'
live_roles() {
  local out r live=""
  out="$(CYS_NO_AUTOSTART=1 "$1" list 2>&1)"
  for r in $FLEET_ROLES; do
    printf '%s' "$out" | grep -qE "role=${r}(\s|-|\b)" && live="$live $r"
  done
  printf '%s' "${live# }"
}
step_fleet() {
  local ref="$1" cli i live missing r
  cli="${CYS_CLI:-cys}"
  if [ "$MODE" = "dry" ]; then say "[10/11] (dry-run) 함대를 부르지 않았습니다."; return 0; fi
  if [ -z "$ref" ]; then
    say "[10/11] 자비스 창을 못 열어 동료들을 부르지 못했습니다."
    say "     cys 창에서 자비스에게 이렇게 말해 주십시오: $FLEET_TRIGGER"
    return 10
  fi
  human "자비스" "동료들을 부르는 한마디 — cys 창에서 직접 쳐 주셔야 합니다"
  say ""
  say "   ┌─────────────────────────────────────────────┐"
  say "   │   cys 창(제목 jarvis)에 이렇게 쳐 주십시오:  │"
  say "   │                                             │"
  say "   │        ${FLEET_TRIGGER}                        │"
  say "   │                                             │"
  say "   └─────────────────────────────────────────────┘"
  say ""
  say "   그 한마디를 들으면 자비스가 동료들을 부릅니다. 여기서 기다리다가 다 서면 알려 드립니다."
  say "   (직접 치셔야 합니다 — 프로그램이 대신 친 말은 자비스가 알아보고 거절합니다. 안전장치입니다.)"
  log "fleet: waiting for owner declaration in $ref"
  i=0
  while [ "$i" -lt "$FLEET_WAIT_TRIES" ]; do
    sleep 5
    live="$(live_roles "$cli")"
    [ "$(printf '%s' "$live" | wc -w | tr -d ' ')" -ge 3 ] && break
    i=$((i + 1))
    if [ "$i" -gt 0 ] && [ $((i % 12)) -eq 0 ]; then
      say "   기다리는 중입니다 ($((i * 5 / 60))분 지남 · 최대 $((FLEET_WAIT_TRIES * 5 / 60))분). 아직 치지 않으셨다면 지금 쳐 주십시오."
    fi
  done
  missing=""
  for r in $FLEET_ROLES; do
    printf '%s' " $live " | grep -q " $r " || missing="$missing $r"
  done
  if [ -z "$missing" ]; then
    say "[10/11] 함대가 섰습니다: $live"
    return 0
  fi
  # 성공보다 이 문구가 중요하다 — 무엇이 없어서 못 섰는지를 그대로 말한다.
  say "[10/11] 아직 서지 않은 자리가 있습니다:${missing}"
  say "     선 자리 = ${live:-없음}"
  say "     아직 그 한마디를 치지 않으셨다면, cys 창에서 지금 쳐 주시면 됩니다."
  say "     치셨는데도 서지 않았다면 cys 창의 자비스에게 물어보십시오 — 무엇이 걸렸는지 사람 말로 알려 줍니다."
  log "fleet missing:${missing}"
  return 10
}

# ── 하는 일 11 — 아고라 참가 ───────────────────────────────────────
# 아고라는 여러 자비스가 한자리에 모여 토론하는 곳이다. 이 단은 이 컴퓨터를 그 명부에 올린다.
# 파이썬을 쓰지 않는다. 필요한 것(키 만들기·지문·소유 증명 서명·주고받기)이 전부
# 운영체제에 이미 들어 있다. 프로그램을 하나도 더 깔지 않는다는 뜻이다.
AGORA_RELAY_URL="${AGORA_RELAY_URL:-https://agora.godmeyou.kr}"
AGORA_SIGN_NS='jarvis-agora@godmeyou.kr'
AGORA_HOME="${AGORA_HOME:-$HOME/.config/agora}"
AGORA_KEY="$AGORA_HOME/id_ed25519"
AGORA_CONF="$AGORA_HOME/participant.json"
# 클라이언트 파일은 설치 사이트 사본에서 받는다. 주소가 비어 있으면 그 부분만 건너뛴다
# (명부 등재는 클라이언트 파일과 아무 의존이 없다).
AGORA_CLI_URL="${AGORA_CLI_URL:-}"
AGORA_CLI_SHA="${AGORA_CLI_SHA:-}"

# 이름에는 사람에 관한 것을 넣지 않는다.
# 컴퓨터 이름을 쓰지 않는 이유: 이 컴퓨터의 이름은 대개 계정 이름을 담고 있다
# (맥은 처음 설정할 때 계정 이름으로 컴퓨터 이름을 짓는 것이 기본이다). 읽지 않으면 심사할 것도 없다.
agora_new_id() {
  local r
  r="$(LC_ALL=C tr -dc 'a-z0-9' < /dev/urandom 2>/dev/null | head -c 10)"
  # 난수를 못 얻으면 이름이 jarvis- 하나로 줄어 모두가 같은 이름을 쓰게 된다. 그때는 시각으로 채운다.
  [ "${#r}" -eq 10 ] || r="$(date +%s | tail -c 11)0000000000"
  printf 'jarvis-%s' "$(printf '%s' "$r" | head -c 10)"
}

# 서명 도구가 이 컴퓨터에서 소유 증명을 만들 수 있는지 본다(있는 것과 되는 것은 다르다).
# 열쇠가 암호로 잠겨 있으면 서명 도구가 암호를 물으며 그 자리에서 멈춘다.
# 물어보기 전에 파일만 보고 판별한다 - 잠기지 않은 열쇠는 둘째 줄이 늘 이 글자로 시작한다(실측).
agora_key_is_open() {
  [ -f "$AGORA_KEY" ] || return 1
  case "$(sed -n '2p' "$AGORA_KEY" 2>/dev/null)" in
    b3BlbnNzaC1rZXktdjEAAAAABG5vbmU*) return 0 ;;
    *) return 1 ;;
  esac
}

agora_can_sign() {
  command -v ssh-keygen >/dev/null 2>&1 || return 1
  agora_key_is_open || { log "agora: key is locked - not signing"; return 1; }
  # 판본이 낮으면 -Y 자체를 모른다. 실제로 한 번 서명해 보는 것이 유일하게 확실한 판정이다.
  local probe="$AGORA_HOME/.signprobe"
  printf '%s' 'probe' > "$probe" 2>/dev/null || return 1
  # 물어볼 입력을 아예 닫아 둔다. 무언가를 묻게 되면 기다리지 않고 그 자리에서 실패한다.
  if ssh-keygen -Y sign -q -n "$AGORA_SIGN_NS" -f "$AGORA_KEY" "$probe" </dev/null >/dev/null 2>&1; then
    rm -f "$probe" "$probe.sig" 2>/dev/null
    return 0
  fi
  rm -f "$probe" "$probe.sig" 2>/dev/null
  return 1
}

# cys 가 함께 가져온 파이썬을 절대 경로로 찾는다.
# 이름으로 부르면 컴퓨터에 원래 있던 것이 잡히고, 깨끗한 맥에서는 그때 설치 창이 뜬다.
agora_bundled_python() {
  local c
  for c in "/Applications/cys.app/Contents/Resources/runtime/python/bin/python3" \
           "$HOME/Applications/cys.app/Contents/Resources/runtime/python/bin/python3"; do
    [ -x "$c" ] && { printf '%s' "$c"; return 0; }
  done
  return 1
}

# 릴레이에 말을 거는 자리는 여기 하나뿐이다. 주고받는 형태가 바뀌면 이 함수만 고친다.
# 결과: 0 = 올랐다(새로 또는 이미) · 3 = 이름이 이미 다른 키의 것 · 그 밖 = 못 올렸다
agora_register() {
  local pid="$1" pub="$2" fp="$3" msg sig body code
  msg="$AGORA_HOME/.register.json"
  body="$AGORA_HOME/.register.post.json"
  # 서명 대상은 다섯 칸을 이 순서로 이어 붙인 것 하나다. 끝에 줄바꿈이 붙으면 안 되므로 printf 로만 쓴다.
  printf '%s' "{\"display_name\":\"$pid\",\"fingerprint\":\"$fp\",\"participant_id\":\"$pid\",\"public_key\":\"$pub\",\"purpose\":\"agora-register-v1\"}" > "$msg" || return 1
  rm -f "$msg.sig" 2>/dev/null
  ssh-keygen -Y sign -q -n "$AGORA_SIGN_NS" -f "$AGORA_KEY" "$msg" </dev/null >/dev/null 2>&1 || { log "agora: sign failed"; return 1; }
  [ -f "$msg.sig" ] || { log "agora: no signature file"; return 1; }
  sig="$(awk '{printf "%s\\n", $0}' "$msg.sig")"
  printf '%s' "{\"participant_id\":\"$pid\",\"display_name\":\"$pid\",\"public_key\":\"$pub\",\"fingerprint\":\"$fp\",\"signature\":\"$sig\"}" > "$body" || return 1
  code="$(curl -sS -m 30 -o "$AGORA_HOME/.register.resp.json" -w '%{http_code}' \
          -X POST -H 'Content-Type: application/json' \
          --data-binary @"$body" "$AGORA_RELAY_URL/register" 2>>"$LOG_FILE")"
  # 응답 코드를 한 줄로 남긴다. 나중에 무엇이 걸렸는지 물을 때 본문보다 이 값이 먼저 필요하다.
  printf '%s' "$code" > "$AGORA_HOME/.register.http" 2>/dev/null
  log "agora: register http=$code body=$(head -c 300 "$AGORA_HOME/.register.resp.json" 2>/dev/null)"
  rm -f "$msg" "$msg.sig" "$body" 2>/dev/null
  case "$code" in
    201|200) return 0 ;;
    409)     return 3 ;;
    *)       return 4 ;;
  esac
}

# 명부 사본을 내려받는다. 없어도 등재 자체는 이미 끝난 것이므로 실패로 세지 않는다.
agora_sync_roster() {
  local n got=0
  for n in allowed_signers revoked_keys operators; do
    # -f 가 없으면 없는 경로의 오류 본문이 그대로 명부 파일로 저장된다.
    # 그러면 파일은 생겼는데 내용이 명부가 아니고, 아무도 그것을 모른다.
    curl -fsS -m 20 -o "$AGORA_HOME/$n" "$AGORA_RELAY_URL/participants/$n" 2>>"$LOG_FILE" && got=$((got + 1))
  done
  log "agora: roster files=$got"
  [ "$got" -gt 0 ]
}

# 클라이언트 파일을 받아 놓고, cys 가 가져온 파이썬으로 도는 실행 파일을 하나 만든다.
agora_place_client() {
  local py zip
  [ -n "$AGORA_CLI_URL" ] || { log "agora: client url empty - skip"; return 1; }
  py="$(agora_bundled_python)" || { log "agora: bundled python not found"; return 1; }
  zip="$AGORA_HOME/.client.zip"
  curl -fsSL -m 120 -o "$zip" "$AGORA_CLI_URL" 2>>"$LOG_FILE" || { log "agora: client download failed"; return 1; }
  if [ -n "$AGORA_CLI_SHA" ]; then
    local got; got="$(shasum -a 256 "$zip" 2>/dev/null | awk '{print $1}')"
    [ "$got" = "$AGORA_CLI_SHA" ] || { log "agora: client sha mismatch got=$got"; rm -f "$zip"; return 1; }
  fi
  # 우리가 만든 폴더이므로 통째로 비우고 새로 푼다 - 덮어쓰기만 하면 지난 판의 지워진 파일이 남는다.
  rm -rf "$AGORA_HOME/lib" 2>/dev/null
  mkdir -p "$AGORA_HOME/lib" "$AGORA_HOME/bin" 2>/dev/null
  (cd "$AGORA_HOME/lib" && unzip -oq "$zip") 2>>"$LOG_FILE" || { log "agora: client unzip failed"; rm -f "$zip"; return 1; }
  rm -f "$zip" 2>/dev/null
  printf '#!/bin/sh\nexec %s %s/lib/bin/agora "$@"\n' "$py" "$AGORA_HOME" > "$AGORA_HOME/bin/agora"
  chmod +x "$AGORA_HOME/bin/agora" 2>/dev/null
  log "agora: client placed with $py"
  return 0
}

step_agora() {
  local pid pub fp made_key=0 rc
  if [ "$MODE" = "dry" ]; then
    say "[11/11] (dry-run) 아고라에 등재하지 않았습니다. 등재할 곳 = $AGORA_RELAY_URL"
    return 0
  fi
  mkdir -p "$AGORA_HOME" 2>/dev/null && chmod 700 "$AGORA_HOME" 2>/dev/null
  if ! command -v curl >/dev/null 2>&1; then
    say "[11/11] 아고라 참가는 지금 하지 못했습니다 (주고받는 도구를 찾지 못했습니다)."
    say "     나중에 자비스에게 아고라에 참가해 달라고 말하면 됩니다."
    return 0
  fi
  # 이름을 정한다. 이미 있으면 그대로 쓴다(다시 돌려도 사고가 되지 않게).
  if [ -f "$AGORA_CONF" ]; then
    pid="$(sed -n 's/.*"id"[[:space:]]*:[[:space:]]*"\([^"]*\)".*/\1/p' "$AGORA_CONF" | head -1)"
  fi
  [ -n "$pid" ] || pid="$(agora_new_id)"
  # 키를 만든다. 이미 있으면 덮어쓰지 않는다 - 덮어쓰면 그 키로 서명한 지난 글을 아무도 확인할 수 없다.
  if [ ! -f "$AGORA_KEY" ]; then
    if ! ssh-keygen -t ed25519 -N "" -C "agora:$pid" -f "$AGORA_KEY" -q </dev/null >/dev/null 2>&1; then
      say "[11/11] 아고라 참가는 지금 하지 못했습니다 (참가 열쇠를 만들지 못했습니다)."
      say "     나중에 자비스에게 아고라에 참가해 달라고 말하면 됩니다."
      return 0
    fi
    chmod 600 "$AGORA_KEY" 2>/dev/null
    made_key=1
  fi
  # 원인을 하나로 단정하지 않는다. 「열쇠가 잠겼다」와 「도구가 낡았다」는 다른 일이고
  # 사람이 해야 할 일도 다르다 - 앞의 것은 열쇠를 치우면 되고 뒤의 것은 그렇지 않다.
  if ! agora_key_is_open; then
    say "[11/11] 아고라 참가는 지금 하지 못했습니다 (참가 열쇠에 암호가 걸려 있습니다)."
    say "     $(redact "$AGORA_KEY") 를 다른 이름으로 옮겨 두시고 같은 줄을 다시 돌리면 새로 만듭니다."
    log "agora: key is locked"
    return 0
  fi
  if ! agora_can_sign; then
    say "[11/11] 아고라 참가는 지금 하지 못했습니다 (이 컴퓨터의 서명 도구가 낡았습니다)."
    say "     나중에 자비스에게 아고라에 참가해 달라고 말하면 됩니다."
    log "agora: signer too old"
    return 0
  fi
  pub="$(cat "$AGORA_KEY.pub" 2>/dev/null)"
  fp="$(ssh-keygen -l -f "$AGORA_KEY.pub" 2>/dev/null | awk '{for(i=1;i<=NF;i++) if ($i ~ /^SHA256:/) print $i}')"
  if [ -z "$pub" ] || [ -z "$fp" ]; then
    say "[11/11] 아고라 참가는 지금 하지 못했습니다 (참가 열쇠를 읽지 못했습니다)."
    return 0
  fi
  agora_register "$pid" "$pub" "$fp"; rc=$?
  # 이름이 이미 다른 키의 것일 때, 이번에 열쇠를 새로 만들었다면 다른 이름으로 한 번만 다시 해 본다.
  # 열쇠가 원래 있었다면 다시 해도 같은 이유로 막힌다(한 열쇠는 한 이름만 가진다) - 그래서 하지 않는다.
  if [ "$rc" = "3" ] && [ "$made_key" = "1" ]; then
    pid="$(agora_new_id)"
    agora_register "$pid" "$pub" "$fp"; rc=$?
  fi
  if [ "$rc" != "0" ]; then
    say "[11/11] 아고라 참가는 지금 하지 못했습니다."
    say "     나중에 자비스에게 아고라에 참가해 달라고 말하면 됩니다."
    return 0
  fi
  printf '{\n  "id": "%s",\n  "display_name": "%s",\n  "key_fingerprint": "%s",\n  "namespace": "%s",\n  "operator": false,\n  "relay": "%s"\n}\n' \
    "$pid" "$pid" "$fp" "$AGORA_SIGN_NS" "$AGORA_RELAY_URL" > "$AGORA_CONF"
  chmod 600 "$AGORA_CONF" 2>/dev/null
  agora_sync_roster || say "     (참가자 명부 사본은 나중에 받아도 됩니다.)"
  agora_place_client || log "agora: client not placed"
  say "[11/11] 아고라에 참가했습니다. 이 컴퓨터의 참가 이름은 $pid 입니다."
  say "     이 이름과 열쇠는 $(redact "$AGORA_HOME") 에 있습니다."
  return 0
}

# ── 하는 일 9 — 자비스 깨우기 ─────────────────────────────────────
# cys 안에서 세션을 여는 것이 기본이고, 그것이 안 되면 이 창에서 바로 띄운다.
step_wake() {
  local first_prompt cli ref fleet_rc
  # 바깥 프로그램에 넘기는 글자는 ASCII 로만 쓴다(윈도우에서 우리말 인자가 깨져 거절당했다).
  # 우리말 문장은 인자가 아니라 지침 파일에 담아 보낸다 — 자비스가 그 파일을 직접 읽는다.
  first_prompt="Read the file ${DIRECTIVE_FILE} and do exactly what it says. Your first line must be the fixed line specified there."
  if [ "$MODE" = "dry" ]; then
    say "[9/11] (dry-run) 자비스를 띄우지 않았습니다."
    say "     (지금까지 사람 손이 필요했던 횟수: ${HUMAN_HANDS}번)"
    step_fleet ""
    step_agora
    return 0
  fi
  say "[9/11] 자비스를 깨웁니다."
  say "     (지금까지 사람 손이 필요했던 횟수: ${HUMAN_HANDS}번)"
  cli="${CYS_CLI:-cys}"
  if command -v "$cli" >/dev/null 2>&1 || [ -x "$cli" ]; then
    # 창 이름도 같은 이유로 ASCII 다.
    # 여는 명령에 문장을 실으면 안 된다(윈도우에서 두 번 실측: 우리말이 깨졌고, 따옴표가 벗겨졌다).
    # 문장은 파일에 넣고 여는 명령은 그 파일 하나만 가리킨다 — 맥도 같은 모양으로 맞춘다.
    wake_file="$JARVIS_HOME/wake.sh"
    printf '#!/bin/bash\nexec claude --dangerously-skip-permissions %s\n' "'$first_prompt'" > "$wake_file" 2>/dev/null
    chmod +x "$wake_file" 2>/dev/null
    cmd_line="bash $wake_file"
    if [ ! -f "$wake_file" ] || case "$wake_file" in *" "*) true ;; *) false ;; esac; then
      say "     여는 파일의 경로를 쓸 수 없어 cys 안에서는 열지 못합니다. 이 창에서 띄웁니다."
      log "wake path unusable: $wake_file"
      ref=""
    else
      ref="$("$cli" new-surface --role master --cwd "$JARVIS_HOME" --title "jarvis" \
             --cmd "$cmd_line" 2>&1 | tr -d '\n')"
    fi
    case "$ref" in
      *surface:*)
        say "     cys 안에서 자비스를 열었습니다 ($ref). cys 창에서 이어서 이야기하십시오."
        # 창이 열렸으면 곧바로 동료들을 부른다(아래 폴백으로 내려가면 자비스 화면에 갇혀 다음 줄을 못 간다).
        step_fleet "$(printf '%s' "$ref" | sed -n 's/.*\(surface:[0-9][0-9]*\).*/\1/p')"
        fleet_rc=$?
        # 아고라 참가는 함대와 의존이 없다. 함대가 못 선 가장 흔한 이유는 그 한마디를 아직 안 치신 것이고,
        # 그것은 고장이 아니다. 고장이 아닌 이유로 기능을 없애지 않는다.
        step_agora
        return $fleet_rc ;;
    esac
    # 왜 못 열었는지를 화면과 기록 파일 양쪽에 남긴다. 이 값이 없으면 다음에도 원인을 모른다.
    say "     cys 안에서 열지 못했습니다. 프로그램이 답한 내용은 이렇습니다:"
    printf '%s\n' "$ref" | while IFS= read -r ln; do [ -n "$ln" ] && say "       $ln"; done
    say ""
    say "     cys 창 안에서 이어서 하고 싶으시면, cys 를 열고 그 안에서 아래 한 줄을 쳐 주십시오:"
    say "       $cmd_line"
    say ""
    say "     지금은 이 창에서 바로 띄웁니다."
  fi
  cd "$JARVIS_HOME" 2>/dev/null || true
  if ! command -v claude >/dev/null 2>&1; then
    say "[9/11] 자비스를 띄우지 못했습니다 — 클로드 명령을 찾지 못했습니다."
    say "     창을 새로 열고 같은 한 줄을 다시 돌려 주십시오."
    return 9
  fi
  if [ ! -t 0 ] && [ -r /dev/tty ]; then
    exec < /dev/tty
  fi
  exec claude --dangerously-skip-permissions "$first_prompt"
}

# ── 본문 ──────────────────────────────────────────────────────────
say "=== 자비스 설치 도우미 $BOOTSTRAP_VERSION (모드: $MODE) ==="
say "[1/11] 이 컴퓨터를 살펴봅니다."
detect_stage1
detect_stage2
write_report

if [ "$MODE" = "detect" ]; then
  say "감지만 하고 끝냅니다."
  exit 0
fi

step_install_claude || exit $?
step_login          || exit $?

step_prepare || exit $?

# 여기서부터는 한 단이 막혀도 멈추지 않는다.
# 앞 단계(클로드 설치·로그인·자비스 준비)는 이미 성립했고, 막힌 자리를 사람에게 설명해 주는 것이
# 그 다음으로 할 수 있는 가장 쓸모 있는 일이기 때문이다. 막힌 단을 적어 두고 자비스를 깨운다.
if   ! step_download_cys;    then BLOCKED_STEP="cys 설치 파일 받기"
elif ! step_install_cys;     then BLOCKED_STEP="cys 설치"
elif ! step_verify_cys;      then BLOCKED_STEP="cys 확인"
elif ! step_prepare_account; then BLOCKED_STEP="계정 준비"
fi

# 기동 직전 값으로 보고를 갱신한다.
: > "$ROWS_FILE"
detect_stage1; detect_stage2; write_report
step_wake
