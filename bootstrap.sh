#!/bin/bash
# 자비스 설치 도우미 — 맥
#
# 하는 일 4가지
#   1) 이 컴퓨터의 상태를 살펴 환경 보고 1장을 쓴다
#   2) 클로드 코드가 없거나 낡았으면 공식 설치기로 설치한다
#   3) 로그인 화면을 열고 승인이 끝날 때까지 기다린다
#   4) 자비스를 깨워 환경 보고를 사람 말로 옮겨 준다
# 다시 실행하면 끝난 단계는 건너뛰고 이어서 간다.
#   ⛔사람에게 「같은 줄을 다시 돌려 주십시오」라고 말하지 않는다 — 2026-09-10 실기에서
#     **사용자 막힘으로 확정**된 문구다. 대신 show_rerun_how 가 창 여는 법과 **명령 전체**를 인쇄한다.
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
# 우리 자리(배포 한 줄이 가리키는 곳). 새 바깥 주소가 아니라 **이미 쓰고 있던 우리 주소**를 상수로 올린 것이다 —
# 연결이 끊겼을 때 「우리 쪽인가 바깥인가」를 가르려면 우리 주소를 물어볼 수 있어야 한다.
JARVIS_SITE_URL="https://jarvis.godmeyou.kr/install/"


# ── 자리 ──────────────────────────────────────────────────────────
# 점 없는 이름을 쓴다(2026-09-04 개정 · 이유 둘):
JARVIS_HOME="${JARVIS_HOME:-$HOME/install-jarvis}"
LOG_FILE="$JARVIS_HOME/bootstrap.log"
REPORT_FILE="$JARVIS_HOME/env-report.md"
DIRECTIVE_FILE="$JARVIS_HOME/install-directive.md"
DL_DIR="$JARVIS_HOME/dl"
# 🔴우리가 **홈 폴더에 새로 넣은** 신뢰 키의 기록(설정파일<탭>키). 제거기는 이 파일에 적힌 것만
#   되돌린다 — 적히지 않은 키는 참가자의 것이므로 손대지 않는다(1R REVISE ④).
#   ⚠TSV 다: 두 OS 가 같은 파일을 읽고 쓰는데 깨끗한 맥에는 JSON 도구(jq)가 없다.
TRUST_SEED_FILE="$JARVIS_HOME/trust-seed.tsv"
# 🔴**우리가 만든 폴더라는 표식**(2R N3). 제거기는 이 표식이 있을 때만 작업 폴더를 재귀로 지운다 —
#   `JARVIS_HOME` 은 환경변수라 무엇이든 들어올 수 있고, 검사 없이 지우면 남의 폴더가 사라진다.
JARVIS_OWNER_FILE="$JARVIS_HOME/.jarvis-owned"
JARVIS_OWNER_MARK="jarvis-installer-owned v1"
BLOCKED_STEP=""

# cys 설치 파일 — 판본이 파일 이름에 박혀 배포되므로 여기에 핀한다.
# ★2026-09-10 판올림 — 벤더 마지막 판본으로 올린다. 바이트는 **받을 자리에 직접 물어** 적었다
#   (`curl -sSI -L` 의 content-length · 2026-09-10 12:0x 실측: aarch64 270596222 · x64 280008429).
#   ⚠윈도우(bootstrap.ps1)는 2026-09-09부터 **우리 릴리스**를 받는다(우리 빌드가 서명돼 있다).
#     맥은 우리 빌드가 무서명이라 아직 벤더 dmg 그대로다 — 두 OS 가 갈리는 것이 지금은 의도다.
CYS_VERSION="0.14.30"
CYS_DOWNLOAD_DIR="https://www.cysinsight.com/downloads/"
case "$(uname -m)" in
  arm64) CYS_MAC_FILE="cys_${CYS_VERSION}_aarch64.dmg"; CYS_MAC_BYTES=270596222 ;;
  *)     CYS_MAC_FILE="cys_${CYS_VERSION}_x64.dmg";     CYS_MAC_BYTES=280008429 ;;
esac
CYS_DOWNLOAD_URL="${CYS_DOWNLOAD_DIR}${CYS_MAC_FILE}"

LOGIN_POLL_INTERVAL=3      # 초
LOGIN_POLL_TIMEOUT=600     # 초 (10분)

# ── 멈추지 않는 설치기 (2026-09-09) ───────────────────────────────
#   못 나가는 단계에서 침묵하거나 즉시 실패하지 않는다. 원인을 갈라 말하고, 기다리고, 이어간다.
#   상한을 넘기면 **정직하게** 멈추고 다음에 할 일을 남긴다(조용한 성공 흉내 금지).
NET_WAIT_TIMEOUT=1800      # 초 (30분) — 이 한 줄이 기다림의 상한이다
NET_WAIT_INTERVAL=30       # 초 — 다시 해 보는 간격이자 화면에 한 줄 적는 간격
HELP_CODE_URL="https://jarvis.godmeyou.kr/help/"   # 코드별 안내 자리(게시는 사이트 쪽)

MODE="full"
for a in "$@"; do
  case "$a" in
    --detect-only) MODE="detect" ;;
    --dry-run)     MODE="dry" ;;
    -h|--help)     [ -f "$0" ] && sed -n '1,18p' "$0" || echo "쓰는 법: bash bootstrap.sh [--detect-only|--dry-run]"; exit 0 ;;
    *) echo "모르는 인자: $a" >&2; exit 2 ;;
  esac
done

log() { printf '%s %s\n' "$(date '+%Y-%m-%dT%H:%M:%S%z')" "$*" >> "$LOG_FILE"; }

#   「내가 중간에 5번 이상 작업을 해야 했다」 · 몇 번이었는지 아무도 정확히 몰랐다).
#   $1 = 누가 이 손을 시키는가(OS·벤더·우리) — 「우리」가 하나라도 남으면 그것이 우리가 고칠 몫이다.
# 🔴화면 문구에서 「강제」를 뺀다(1R 봉인 2026-09-10 · 윈도우판과 같다). 이 칸의 뜻은 「누가
#   시키는가」이지 「우리가 사람을 강제한다」가 아니다. 앞 판은 자리마다 문구를 순화해 놓고
#   **이 공통 래퍼가 여전히 「강제: 자비스」를 인쇄**해 화면에는 순화가 하나도 안 나타났다.
#   ★자리마다 고치고 공통 자리를 안 고치면 아무것도 안 고친 것이다.
HUMAN_HANDS=0
human() {
  HUMAN_HANDS=$((HUMAN_HANDS + 1))
  say "[사람 손 #${HUMAN_HANDS} · 시킨 쪽: $1] $2"
}
say() { printf '%s\n' "$*"; log "$*"; }

# ── 다시 하시는 법 — 「같은 줄」이라고 말하지 않는다 (2026-09-10 실기에서 고친 것) ─────
# 🔴막힌 자리마다 「같은 한 줄을 다시 돌려 주십시오」라고 적어 왔다. 실기에서 그것이 **사용자
#   막힘으로 확정**됐다 — 「줄」이 무엇인지, 「돌린다」가 무슨 뜻인지 모르고, 무엇보다 그 명령이
#   화면 어디에도 없었다. 창이 닫힌 뒤 사이트를 다시 찾는 것 자체가 손 하나다.
#   ⇒ 끝맺음에서 ①창 여는 법 ②복사 ③붙여넣기+Enter 를 적고 **명령 전체를 인쇄한다.**
# ★어느 명령을 인쇄할지는 **들어온 길**이 정한다(재설치가 JARVIS_ENTRY=reinstall 로 알려 준다).
# ⚠아래 두 줄은 사이트가 게시하는 명령과 **글자까지 같아야 한다** — checks.sh 가 그 동일성을 잰다.
JARVIS_RERUN_BOOTSTRAP='curl -fsSL https://jarvis.godmeyou.kr/install/bootstrap.sh -o "$HOME/install-jarvis.sh" && bash "$HOME/install-jarvis.sh"'
JARVIS_RERUN_REINSTALL='curl -fsSL https://jarvis.godmeyou.kr/install/reinstall.sh -o "$HOME/reinstall-jarvis.sh" && bash "$HOME/reinstall-jarvis.sh"'
rerun_cmd() {
  if [ "${JARVIS_ENTRY:-}" = "reinstall" ]; then printf '%s\n' "$JARVIS_RERUN_REINSTALL"
  else printf '%s\n' "$JARVIS_RERUN_BOOTSTRAP"; fi
}
SHOW_RERUN=0
# 「다시 실행하면 풀린다」고 말하는 자리는 **전부 이 함수로** 적는다 — 문구와 깃발이 갈리면
#   화면은 다시 하라는데 그 방법은 안 나오는 끝이 생긴다(그것이 실기에서 난 일이다).
next_rerun() { NEXT_STEP="$1"; SHOW_RERUN=1; }
show_rerun_how() {
  printf '%s\n' ""
  printf '%s\n' "  == 다시 하시는 법 (이대로 따라 하시면 됩니다) =="
  printf '%s\n' "   1) Command(⌘)+스페이스를 누르고 터미널 이라고 치신 뒤 [터미널] 을 여십시오."
  printf '%s\n' "   2) 아래 명령을 처음부터 끝까지 끌어 선택한 뒤 Command(⌘)+C 를 누르십시오."
  printf '%s\n' "   3) 터미널 창을 한 번 누르고 Command(⌘)+V 로 붙여넣은 뒤 Enter(리턴) 를 누르십시오."
  printf '%s\n' ""
  printf '%s\n' "$(rerun_cmd)"
  printf '%s\n' ""
  printf '%s\n' "  끝난 단계는 건너뛰고 막힌 자리부터 이어서 갑니다."
}

redact() { printf '%s' "$1" | sed "s|$HOME|~|g"; }

#   왜 판본 숫자로 재지 않는가: 우리가 실제로 필요한 것은 「이 명령이 있는가」이지 숫자가 아니다.
#     하위명령이 아니라 질문으로 읽고 세션을 띄운다(rc=0). ⇒ 3초 폴링이 모델 호출 200회가 된다.
#     `--help` 는 어느 판본에서도 플래그이고 질문이 되지 않는다.
claude_has_auth_cmd() {
  claude --help 2>/dev/null | grep -qE '^[[:space:]]*auth[[:space:]]'
}

#   cys 쪽 능력도 같은 이유로 `--help` 로 묻는다(판본 숫자를 게이트로 쓰지 않는다).
#   묻는 것 = 좌석을 열 때 「이 자리에서 무엇을 띄우는지」를 적어 두는 칸이 있는가.
#   그 칸이 있어야 컴퓨터를 껐다 켠 뒤 복원이 자비스 자리를 「무엇을 띄울지 모름」으로 건너뛰지 않는다.
#   ⚠판본에 따라 그 칸이 없다 — 없는 판본에 붙이면 좌석이 아예 안 열린다(2026-09-04 실측: 0.14.29 에 없었다).
#     ★그래서 이 주석에 「지금 배포된 판본은 X」라고 적지 않는다 — 핀이 올라가는 날 그 문장만 낡는다.
#   그래서 붙이기 전에 물어본다. 한 번만 묻고 그 답을 기록 파일에 한 줄 남긴다.
#   ⚠답을 기억해 두지 않는다. 이 스크립트가 도는 동안 cys 는 **없다가 생기고 낡았다가 새로워진다** —
#   설치 전에 물어 둔 답을 설치 뒤에 그대로 쓰면, 방금 깐 판본이 아니라 옛 판본에 대고 판정하는 셈이 된다.
#   대신 기록은 한 줄만 남긴다(답이 바뀐 때만 또 남긴다 — 바뀌었다는 것 자체가 알 값이다).
CYS_AGENT_FLAG=""      # 마지막으로 기록한 답 · "" 아직 기록 안 함
cys_supports_agent_flag() {
  local cli out ans
  cli="${CYS_CLI:-cys}"
  out=""
  if command -v "$cli" >/dev/null 2>&1 || [ -x "$cli" ]; then
    out="$(CYS_NO_AUTOSTART=1 "$cli" new-surface --help 2>&1)"
  fi
  case "$out" in
    *--agent*) ans="yes" ;;
    *)         ans="no" ;;
  esac
  if [ "$ans" != "$CYS_AGENT_FLAG" ]; then
    CYS_AGENT_FLAG="$ans"
    log "cys new-surface --agent supported: $ans"
  fi
  [ "$ans" = "yes" ]
}

# 이 컴퓨터의 cys 가 스스로 말하는 판본 한 줄(없으면 빈 문자열).
cys_version_line() {
  local cli="${CYS_CLI:-cys}"
  if command -v "$cli" >/dev/null 2>&1 || [ -x "$cli" ]; then
    CYS_NO_AUTOSTART=1 "$cli" --version 2>/dev/null | head -1
  fi
}

# ── 진단 코드 (J-<축>-<두 자리>) ──────────────────────────────────
# ★같은 문자열이 세 자리에 남아야 한다 — 화면 · 환경 보고 · 기록 파일.
#   사람은 화면에서 코드를 읽어 사이트에서 찾고, 우리는 파일에서 같은 코드를 본다.
#   자리마다 다른 이름을 쓰면 그 셋을 맞춰 보는 일이 사람 몫이 된다.
J_CODE=""       # 마지막으로 남긴 코드(환경 보고가 이 값을 적는다)
jcode() {       # jcode <코드> <한 줄 설명>
  J_CODE="$1"
  say "     진단 코드: $1 — $2"
  say "     이 코드로 찾아보실 수 있습니다: ${HELP_CODE_URL}$1"
  log "jcode $1 $2"
}

# ── 연결 원인 판별 (3프로브) ──────────────────────────────────────
# ⛔「서버 사정」 한 문장으로 뭉뚱그리지 않는다 — 그러면 백신이 파일을 붙든 것(J-AV)과 섞여
#   **거짓 안내**가 된다(2026-09-09 3호 실기의 교훈). 셋을 갈라 묻고, 못 가르면 못 갈랐다고 적는다.
#   none   = 인터넷 자체가 안 나간다        · ours    = 우리 서버만 안 답한다
#   theirs = 바깥(클로드·GitHub)만 안 답한다  · fine    = 셋 다 답한다(연결은 되는데 이 단계만 안 된다)
#   unknown = 물어볼 도구가 없어 못 가름
# ⚠셋 다 답하는데 단계가 안 나가는 경우를 「연결 문제」로 적으면 안 된다 — 그건 다른 병이다
#   (백신이 붙들었거나 그 단계 고유의 사정). 그때는 **연결은 된다**고 사실대로 말한다.
# 🔴순서가 아니라 **종합**으로 판단한다(검토 지적 채택 2026-09-09).
#   앞 판은 1.1.1.1 을 먼저 물어 실패하면 곧바로 「인터넷 없음」이라고 했다. 그런데 회사·학교 망은
#   **그 주소만 막고 프록시로 웹은 되게** 하는 일이 흔하다 ⇒ 인터넷이 멀쩡한 사람에게 30분 동안
#   「인터넷이 없습니다」라고 우기게 된다. 진짜 원인은 가려지고 사람은 설치기를 믿지 않게 된다.
#   ⇒ 목적지 둘(우리·바깥)을 먼저 믿는다. 둘 다 안 되면 그때만 중립 주소로 「망 자체인가」를 묻는다.
net_cause() {
  local probe ours theirs
  command -v curl >/dev/null 2>&1 || { printf 'unknown'; return 0; }
  probe="curl -sS -m 6 -o /dev/null -I"
  ours=1; theirs=1
  $probe "$JARVIS_SITE_URL"   >/dev/null 2>&1 || ours=0
  $probe "$CLAUDE_INSTALL_URL" >/dev/null 2>&1 || theirs=0
  if [ "$ours" = "1" ] && [ "$theirs" = "1" ]; then printf 'fine';   return 0; fi
  if [ "$ours" = "1" ] && [ "$theirs" = "0" ]; then printf 'theirs'; return 0; fi
  if [ "$ours" = "0" ] && [ "$theirs" = "1" ]; then printf 'ours';   return 0; fi
  # 둘 다 안 된다 — 망 자체가 없는가, 아니면 두 곳이 함께 안 되는 드문 경우인가.
  if $probe "https://1.1.1.1" >/dev/null 2>&1 || $probe "https://8.8.8.8" >/dev/null 2>&1; then
    printf 'unknown'; return 0
  fi
  printf 'none'
}

net_cause_words() {   # 원인 → 사람에게 하는 말 조각
  case "$1" in
    none)   printf '인터넷 연결이 없어서' ;;
    ours)   printf '우리 서버가 응답하지 않아서' ;;
    theirs) printf '설치 파일을 받는 바깥 서버가 응답하지 않아서' ;;
    fine)   printf '연결은 되는데 이 단계가 진행되지 않아서' ;;
    *)      printf '연결 상태를 확인하지 못해서' ;;
  esac
}

net_cause_code() {    # 원인 → 진단 코드
  case "$1" in
    none)   printf 'J-NET-01' ;;
    ours)   printf 'J-NET-02' ;;
    theirs) printf 'J-NET-03' ;;
    *)      printf 'J-UNK-00' ;;
  esac
}

# ── 연결 대기 (모든 연결 단계가 이 한 자리를 쓴다) ────────────────
#   $1 = 단계 표시(예: [5/10]) · $2 = 다시 해 볼 명령(문자열로 받아 그대로 실행한다)
#   rc 0 = 성공(이어간다) · rc 1 = 상한 초과(정직 실패 — 부르는 쪽이 코드를 남기고 멈춘다)
# ⚠기다리는 동안 **말을 한다.** 침묵은 사람에게 「멈췄다」로 읽히고, 그때 창을 닫는다.
wait_for_connection() {
  local tag="$1" cmd="$2" waited=0 cause words
  while [ "$waited" -lt "$NET_WAIT_TIMEOUT" ]; do
    cause="$(net_cause)"
    words="$(net_cause_words "$cause")"
    say "$tag 현재 ${words} 진행할 수 없습니다. 다시 연결이 되면 이어서 진행하겠습니다."
    say "     창을 닫지 말고 기다려 주십시오. 다른 작업을 하셔도 괜찮습니다."
    say "     ($(( waited / 60 ))분 지남 · 최대 $(( NET_WAIT_TIMEOUT / 60 ))분 · ${NET_WAIT_INTERVAL}초마다 다시 해 봅니다)"
    sleep "$NET_WAIT_INTERVAL"
    waited=$(( waited + NET_WAIT_INTERVAL ))
    if eval "$cmd"; then return 0; fi
  done
  cause="$(net_cause)"
  say "$tag $(( NET_WAIT_TIMEOUT / 60 ))분을 기다렸지만 연결되지 않았습니다."
  jcode "$(net_cause_code "$cause")" "$(net_cause_words "$cause") 진행하지 못했습니다"
  return 1
}

# ── 끝맺음 (어느 끝에서도 「다음에 할 일」이 있다) ────────────────
# ★이것을 함수 호출로 두지 않고 **트랩**에 매단 까닭: 끝나는 자리가 여럿이고(성공·실패·중단·
#   감지만·미리보기), 사람이 새 종료 자리를 만들 때마다 이 줄을 기억해서 붙여야 한다면
#   언젠가 빠진다. 트랩은 **기억이 아니라 구조**다.
CLOSING_DONE=0
closing_note() {
  [ "$CLOSING_DONE" = "1" ] && return 0
  CLOSING_DONE=1
  printf '%s\n' ""
  # 「다음에 할 일」을 아무도 안 적은 끝 = 우리가 예상 못 한 자리다. 그때가 안내가 가장 필요한 때이므로
  #   기본값을 「다시 실행」으로 두고 **깃발도 함께 세운다**(문구만 두면 방법이 안 나온다).
  if [ -z "$NEXT_STEP" ]; then NEXT_STEP="아래 「다시 하시는 법」대로 다시 실행해 주십시오."; SHOW_RERUN=1; fi
  printf '%s\n' "다음에 할 일: $NEXT_STEP"
  if [ -n "$J_CODE" ]; then
    printf '%s\n' "  진단 코드: $J_CODE  (${HELP_CODE_URL}${J_CODE})"
    # 🔴화면과 보고서가 갈리지 않게 한다(검토 지적 채택 2026-09-09) — 단계가 코드를 남기고 그 자리에서
    #   끝나면 보고서는 그 전에 쓰인 것이라 **옛 코드나 빈칸**이 남는다. 그 둘이 다르면 사람이 읽어 주는 코드와
    #   우리가 받는 파일이 어긋나 소통이 꼬인다. ⇒ 끝나기 직전에 보고서의 그 줄만 지금 값으로 맞춘다.
    if [ -f "$REPORT_FILE" ]; then
      grep -v '^- 진단 코드: ' "$REPORT_FILE" > "$REPORT_FILE.tmp" 2>/dev/null &&
        printf '%s\n' "- 진단 코드: **$J_CODE** (${HELP_CODE_URL}${J_CODE})" >> "$REPORT_FILE.tmp" &&
        mv "$REPORT_FILE.tmp" "$REPORT_FILE"
      rm -f "$REPORT_FILE.tmp"
    fi
  fi
  # ⚠없는 파일을 보내 달라고 하지 않는다 — 자리 자체를 못 만든 끝(J-PERM-01)에서는 그 두 줄이 거짓이다.
  if [ -f "$REPORT_FILE" ] || [ -f "$LOG_FILE" ]; then
    printf '%s\n' "  막히면 이 두 파일을 보내 주십시오: $(redact "$REPORT_FILE") · $(redact "$LOG_FILE")"
    printf '%s\n' "  여는 법: open $(redact "$JARVIS_HOME")"
  else
    printf '%s\n' "  기록 파일은 아직 만들어지지 않았습니다 — 이 화면을 사진으로 남겨 주십시오."
  fi
  # ★안내는 **맨 마지막**에 둔다 — 사람이 마지막으로 보는 화면에 명령이 있어야 복사할 수 있다.
  [ "$SHOW_RERUN" = "1" ] && show_rerun_how
  return 0
}
NEXT_STEP=""    # 단계가 자기 자리에서 더 정확한 한 줄을 넣을 수 있다

# ── 감지 행 적재 ──────────────────────────────────────────────────
# 한 행 = 번호 \t 무엇 \t 값 \t enum \t 비고   (bash 3.2 이므로 연관배열을 안 쓴다)
ROWS_FILE="$(mktemp -t jarvis-rows)"
trap 'closing_note; rm -f "$ROWS_FILE"' EXIT

# 🔴자리 만들기를 **끝맺음 보증 안쪽**으로 옮겼다(검토 지적 채택 2026-09-09).
#   앞 판은 이 실패가 트랩 등록보다 먼저 나서, 가장 도움이 필요한 순간(권한·공간·백신으로 자리를 못 만든
#   순간)에 「다음에 할 일」이 한 줄도 안 나오고 창이 차갑게 닫혔다.
#   ⚠까닭을 「권한」 하나로 단정하지 않는다 — 공간이 꽉 찼거나 백신이 폴더 생성을 막아도 여기서 실패한다.
# ── 🔴🔴작업 폴더는 **이름을 못 박고, 우리가 만든 자리에만 표식을 놓는다** (3R N3 · master 결정) ──
#   앞 판은 `JARVIS_HOME` 값이 무엇이든 `mkdir -p` 로 만들고 **이미 있던 남의 폴더에도 표식을 써 줬다.**
#   ⇒ 제거기의 「우리 폴더인가」 관문이 그 표식을 소유 증거로 받아 **남의 폴더를 통째로 지웠다**
#     (`JARVIS_HOME=~/valuable/project` 로 한 번 설치하면 그 다음 지우기가 그 폴더를 재귀 삭제한다).
#   ★설치기가 표식을 헤프게 놓으면 제거기의 관문은 **관문이 아니다.** 관문의 값은 그것을 세우는
#     쪽이 아끼는 만큼이다 — 검사를 늘리는 것으로는 이 구멍이 안 막힌다.
#   ⇒ 두 관문을 **만들기보다 먼저** 통과해야 한다:
#     ⑴이름이 정확히 `install-jarvis` 인 자리만 쓴다(그 외 값 = 거부·안내·중단).
#     ⑵표식은 **우리가 새로 만든 자리**(또는 비어 있는 자리)에만 놓는다. 이미 있고 **비어 있지 않으면**
#       채택하지 않는다 — 우리가 앞서 만든 자리는 우리 표식을 갖고 있으므로 다시 깔 때 그대로 이어 쓴다.
#   ⚠표식을 못 쓰면 **거기서 멈춘다**(앞 판은 경고만 하고 계속 갔다). 표식 없는 폴더에 기록을 쌓아 두면
#     다음 실행이 그 폴더를 「남의 것」으로 읽어 ⑵에서 막힌다 — 그때는 사람이 손으로 치울 수밖에 없다.
JARVIS_HOME_BASENAME="install-jarvis"
owner_mark_ok() {  # 이 자리에 우리 표식이 있는가
  [ -f "$JARVIS_OWNER_FILE" ] && grep -qF "$JARVIS_OWNER_MARK" "$JARVIS_OWNER_FILE" 2>/dev/null
}
write_owner_mark() {
  owner_mark_ok && return 0
  printf '%s\n' "$JARVIS_OWNER_MARK" > "$JARVIS_OWNER_FILE" 2>/dev/null || return 1
  return 0
}
refuse_jarvis_home() {  # refuse_jarvis_home <까닭 한 줄>
  echo "작업 폴더로 쓸 수 없는 자리입니다: $JARVIS_HOME" >&2
  echo "     까닭: $1" >&2
  echo "     진단 코드: J-HOME-01 — 이 도구가 만들고 지우는 폴더의 이름은 「$JARVIS_HOME_BASENAME」 하나입니다" >&2
  J_CODE="J-HOME-01"
  NEXT_STEP="JARVIS_HOME 을 지정하지 않으신 채로 다시 실행하시면 기본 자리($HOME/$JARVIS_HOME_BASENAME)를 씁니다. 그 자리를 꼭 쓰시려면 그 폴더를 지우거나 옮기신 뒤 다시 실행해 주십시오 — 설치 도우미는 자기가 새로 만든 폴더만 씁니다."
  SHOW_RERUN=1
  exit 3
}
# ⑴이름 관문 — **만들기 전에** 본다.
if [ "$(basename "${JARVIS_HOME%/}")" != "$JARVIS_HOME_BASENAME" ]; then
  refuse_jarvis_home "폴더 이름이 「$JARVIS_HOME_BASENAME」 이 아닙니다"
fi
# ⑵채택 관문 — 이미 있는 자리는 **우리 표식이 있을 때만** 쓴다.
# 🔴🔴**「비어 있으면 채택」을 걷어냈다**(4R BLOCK N3 봉인 2026-09-10). 두 가지가 틀렸다:
#   ⑴결정은 「설치기가 **자기가 만든** 폴더에만 표식을 놓는다」였는데, 코드는 **남이 만들어 둔 빈 폴더**도
#     채택해 표식을 써 줬다 ⇒ 그 자리는 그때부터 「우리 것」이 되어 다음 지우기가 통째로 지운다.
#   ⑵더 나쁜 것은 **비었는지 세는 방법**이었다: `ls -A` 가 **권한 오류**를 내도 빈 목록으로 읽었다.
#     「목록은 못 읽지만 파일은 만들 수 있는」 폴더 — 남의 파일이 가득한 그 자리에 표식을 써 준다.
#   ★「비었다」와 「못 세었다」를 한 칸에 담은 자리가 또 있었다. 이 티켓에서만 세 번째다.
#   ⇒ **세지 않는다.** 셀 필요가 없으면 틀릴 자리도 없다 — 표식이 없는 기존 폴더는 내용과 무관하게 거부한다.
#   ⚠참가자 영향: 앞선 실행이 표식을 못 쓰고 죽어 **빈 폴더만 남은** 드문 경우에 한 번 막힌다.
#     그때 화면이 「그 폴더를 지우고 다시 실행」이라고 정확히 말한다 — 손 한 번이 남의 폴더를 지키는 값이다.
JARVIS_HOME_CREATED=0
if [ -e "$JARVIS_HOME" ]; then
  if [ ! -d "$JARVIS_HOME" ]; then
    refuse_jarvis_home "그 자리에 폴더가 아닌 것이 이미 있습니다"
  fi
  if ! owner_mark_ok; then
    refuse_jarvis_home "그 폴더는 이미 있는데 우리 표식이 없습니다(우리가 만든 자리가 아닙니다 — 지울 때 통째로 지우는 자리이므로 채택하지 않습니다)"
  fi
else
  if ! mkdir -p "$JARVIS_HOME" 2>/dev/null; then
    echo "자리를 만들지 못했습니다: $JARVIS_HOME" >&2
    echo "     진단 코드: J-PERM-01 — 파일이나 폴더를 쓸 권한이 없습니다(공간 부족·백신 차단도 같은 모양입니다)" >&2
    J_CODE="J-PERM-01"
    NEXT_STEP="회사·학교에서 관리하는 컴퓨터면 담당자에게 문의해 주십시오. 개인 컴퓨터면 저장 공간과 백신 알림을 확인해 주십시오."
    exit 3
  fi
  JARVIS_HOME_CREATED=1
fi
# ★표식을 놓는다 — 제거기는 이 표식이 있을 때만 그 폴더를 재귀로 지운다.
if ! write_owner_mark; then
  echo "작업 폴더 표식을 쓰지 못했습니다: $(redact "$JARVIS_OWNER_FILE")" >&2
  echo "     진단 코드: J-PERM-01 — 파일이나 폴더를 쓸 권한이 없습니다(공간 부족·백신 차단도 같은 모양입니다)" >&2
  J_CODE="J-PERM-01"
  NEXT_STEP="저장 공간과 백신 알림을 확인하신 뒤 다시 실행해 주십시오. (표식 없이 계속하면 다음 실행이 이 폴더를 「남의 것」으로 읽습니다.)"
  # 우리가 방금 만든 빈 자리라면 되돌려 둔다 — 반쯤 만든 자리를 남기지 않는다.
  [ "$JARVIS_HOME_CREATED" = "1" ] && rmdir "$JARVIS_HOME" 2>/dev/null
  exit 3
fi

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

  #   컴퓨터를 껐다 켠 뒤 자비스 자리가 스스로 되살아나는가 — 그 답은 판본이 정한다.
  #   이 행은 「무엇을 했는가」가 아니라 「이 컴퓨터에서 무엇이 되는가」를 적는다.
  if cys_supports_agent_flag; then
    row "2-9" "master 좌석 복원 플래그" "전달" "ok" "껐다 켠 뒤 자비스 자리가 자동으로 되살아납니다"
  else
    row "2-9" "master 좌석 복원 플래그" "미지원($(cys_version_line))" "ok" "이 판본에는 그 칸이 없어 붙이지 않았습니다 — 껐다 켜면 자비스 자리는 손으로 다시 엽니다"
  fi
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
    # 화면·기록 파일과 **같은 문자열**을 여기에도 남긴다 — 셋을 맞춰 보는 일이 사람 몫이 되면 안 된다.
    [ -n "$J_CODE" ] && printf '%s\n' "- 진단 코드: **$J_CODE** (${HELP_CODE_URL}${J_CODE})"
    printf '%s\n\n' "  - \`unknown\` 은 「완료됨」으로 세지 않는다."
    printf '\n## 지금 상태 → 다음 행동\n'
    if [ "$MODE" = "dry" ]; then
      #   dry 모드에서는 아래 「앞 단계는 이미 끝났습니다」가 거짓이다 — 아무것도 안 했기 때문이다.
      #   깨끗한 기계 실측(2026-09-06 Tart)에서 그 줄이 실제로 찍혔다: 클로드도 로그인도 없는 기계가
      #   「클로드 설치·로그인이 이미 끝났다」는 보고서를 받았다. 모드가 다르면 문장도 달라야 한다.
      printf -- '- (미리보기) 아무것도 하지 않았습니다 — 이 보고는 **지금 이 컴퓨터의 상태**일 뿐입니다.\n'
      printf -- '- 실제로 설치하시려면 `--dry-run` 없이 아래 명령을 다시 실행하십시오.\n'
      printf -- '\n```\n%s\n```\n' "$(rerun_cmd)"
    elif [ -n "$BLOCKED_STEP" ]; then
      printf -- '- **막힌 단계: %s**\n' "$BLOCKED_STEP"
      printf -- '- 앞 단계(클로드 설치·로그인·자비스 준비)는 **이미 끝났습니다.** 여기부터 다시 이어서 갑니다.\n'
      printf -- '- 그 **다음 단계들은 아직 하지 않았습니다** — 실패한 것이 아니라 순서가 안 온 것입니다.\n'
    printf -- '- 아래 명령을 다시 실행하면 **끝난 단계는 건너뛰고 막힌 자리부터** 갑니다.\n'
      printf -- '\n```\n%s\n```\n' "$(rerun_cmd)"
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

# 🔴2026-09-06 신설 (깨끗한 맥 실기 실측). **공식 클로드 설치기는 셸 프로필에 아무것도 안 쓴다.**
#   깨끗한 맥에서 설치한 직후 `~/.zprofile`·`~/.zshrc`·`~/.zshenv`·`~/.bash_profile`·`~/.bashrc`·
#   `~/.profile` 여섯을 다시 재 보니 **여섯 개 다 여전히 없었다.** 설치기는 대신 화면에 이렇게 적는다 —
#   「Native installation exists but ~/.local/bin is not in your PATH. Run: echo 'export
#   PATH="$HOME/.local/bin:$PATH"' >> ~/.zshrc && source ~/.zshrc」. 즉 **사람에게 시킨다.**
#   ⇒ 우리가 안 넣어 주면, 설치가 끝난 뒤 사용자가 터미널을 새로 열었을 때 `claude` 가 없다(실측:
#     새 로그인 셸의 PATH 에 `~/.local/bin` 이 없다).
#   ⚠**`[9/10]`·`[10/10]` 때문이 아니다.** cys 가 띄우는 창은 cysd 가 `~/.local/bin` 을 앞에 심어 줘서
#     거기서는 잘 잡힌다(실측으로 확인 — 이것은 처음에 우리가 세운 예측이 틀렸던 자리다).
#     이 줄이 필요한 이유는 오직 **사용자가 스스로 새 터미널을 열었을 때**다.
seed_local_bin_path() {
  local marker="# added by jarvis installer (claude PATH)" rc_file f
  [ -d "$HOME/.local/bin" ] || return 0

  #   🔴적대검증 지적 채택(2026-09-06) — 앞 판은 `~/.zprofile` **하나만** 보고 판단했다.
  #   공식 설치기가 사람에게 시키는 자리는 `~/.zshrc` 다 ⇒ 그 말을 이미 따른 사람의 `~/.zshrc` 에는
  #   그 줄이 있는데 우리는 `~/.zprofile` 만 보고 「없다」고 판단해 **또 넣는다.** 중복이 쌓인다.
  #   ⇒ 읽힐 수 있는 프로필을 **전부** 먼저 훑고, 어디든 이미 있으면 아무것도 안 한다.
  for f in "$HOME/.zprofile" "$HOME/.zshrc" "$HOME/.zshenv" "$HOME/.profile" "$HOME/.bash_profile" "$HOME/.bashrc"; do
    [ -f "$f" ] || continue
    grep -qF "$marker" "$f" 2>/dev/null && return 0
    grep -q '\.local/bin' "$f" 2>/dev/null && return 0
  done

  #   같은 지적의 둘째 갈래 — 셸이 zsh 가 아니면 `~/.zprofile` 을 아무도 안 읽는다(그 사람에게는
  #   아무 일도 안 일어난다). 맥 기본은 zsh 지만 바꾼 사람이 있다 ⇒ **그 사람의 셸이 읽는 자리**에 쓴다.
  case "${SHELL##*/}" in
    bash) rc_file="$HOME/.bash_profile" ;;
    zsh|"") rc_file="$HOME/.zprofile" ;;
    *)    rc_file="$HOME/.profile" ;;   # 그 밖의 셸 — 가장 널리 읽히는 자리
  esac

  {
    printf '\n%s\n' "$marker"
    printf '%s\n' 'export PATH="$HOME/.local/bin:$PATH"'
  } >> "$rc_file" 2>/dev/null || return 0
  log "seeded PATH line into $rc_file (SHELL=${SHELL:-미상})"
}

# ── 하는 일 2 — 공식 설치기 호출 (멱등: 이미 있으면 건너뛴다) ─────
step_install_claude() {
  if [ "$S1_CLAUDE_OK" = "1" ]; then
    say "[2/10] 클로드가 이미 있습니다 — 건너뜁니다 (멱등)."
    return 0
  fi
  if [ -n "$(command -v claude 2>/dev/null)" ]; then
    say "[2/10] 이 컴퓨터의 클로드가 낡았습니다($(claude --version 2>/dev/null | head -1)). 최신판을 설치합니다."
  fi
  if [ "$MODE" = "dry" ]; then
    say "[2/10] (dry-run) 설치기를 부르지 않았습니다. 부를 줄 = curl -fsSL $CLAUDE_INSTALL_URL | bash"
    return 0
  fi
  say "[2/10] 클로드 코드를 설치합니다. 글자가 주르륵 올라갑니다 — 정상입니다."
  local rc=0
  ( set -o pipefail; curl -fsSL --max-time 600 "$CLAUDE_INSTALL_URL" | bash ) || rc=$?
  if [ "$rc" -ne 0 ]; then
    # 여기서 곧바로 끝내지 않는다 — 못 나가는 까닭이 잠깐일 수 있다. 원인을 갈라 말하고 기다린다.
    say "[2/10] 설치기를 받지 못했습니다 (종료 코드 $rc)."
    if wait_for_connection "[2/10]" '( set -o pipefail; curl -fsSL --max-time 600 "$CLAUDE_INSTALL_URL" | bash )'; then
      rc=0
    else
      next_rerun "연결이 된 뒤 아래 「다시 하시는 법」대로 다시 실행해 주십시오. 끝난 단계는 건너뛰고 이어서 갑니다."
      return 4
    fi
  fi
  #   깨끗한 기계에서 매번 rc 4 로 끝나 「한 줄」 약속이 「한 줄 · 새 창 · 한 줄」이 된다.
  case ":$PATH:" in
    *":$HOME/.local/bin:"*) : ;;
    *) PATH="$HOME/.local/bin:$PATH"; export PATH ;;
  esac
  hash -r 2>/dev/null || true
  seed_local_bin_path
  # 실행 결과 검사 = 설치기의 종료 코드가 아니라 명령이 답하는가
  if ! claude --version >/dev/null 2>&1; then
    say "[2/10] 설치기는 끝났는데 claude 명령이 아직 안 잡힙니다."
    jcode "J-PATH-01" "깔렸는데 이 창에서 명령을 찾지 못합니다"
    next_rerun "터미널 창을 새로 열고 아래 「다시 하시는 법」대로 다시 실행해 주십시오."
    return 4
  fi
  #   새로 깐 것이 PATH 에서 이겨야 한다. 위에서 `$HOME/.local/bin` 을 앞에 붙였으므로 이기는 것이
  local nowpath
  nowpath="$(command -v claude 2>/dev/null)"
  case "$nowpath" in
    "$HOME"/.local/bin/*) : ;;
    *) say "[2/10] ⚠새로 깐 클로드가 아니라 $(redact "$nowpath") 가 먼저 잡힙니다. 터미널 창을 새로 열고 아래 「다시 하시는 법」대로 다시 실행해 주십시오."; SHOW_RERUN=1
       return 4 ;;
  esac
  if ! claude_has_auth_cmd; then
    say "[2/10] 설치는 끝났는데 아직 낡은 판본이 잡힙니다."
    jcode "J-VER-01" "낡은 판본이 먼저 잡혀 로그인 명령을 모릅니다"
    next_rerun "터미널 창을 새로 열고 아래 「다시 하시는 법」대로 다시 실행해 주십시오. 판올림부터 이어서 갑니다."
    return 4
  fi
  S1_CLAUDE_OK=1
  say "[2/10] 완료: $(claude --version 2>/dev/null | head -1) ($(redact "$nowpath"))"
}

# ── 하는 일 3 — 로그인 유도 + 완료 감지 ───────────────────────────
step_login() {
  # 🔴[1/10] 의 로그인 판정은 **클로드가 없던 시점**의 것이다 — 그 자리에서는 물어볼 상대가 없어
  #   `unknown` 으로 적고 지나간다. 그런데 [2/10] 에서 방금 클로드를 깔았다.
  #   ⇒ 브라우저를 열기 전에 **한 번 다시 본다.**
  #   왜 이 줄이 생겼나(2026-09-08 오너 윈 노트북): 「지우고 다시 깔기」에서 지우개는 로그인을
  #   남겼는데(화면에 「남김: 로그인」), 판정만 옛것이라 [3/10] 이 로그인 화면을 다시 열었다.
  #   ★첫 설치에서는 이 줄이 아무 일도 하지 않는다(정말로 로그인이 없으니까). 어긋나는 것은
  #   **지우고 다시 까는 길** 하나뿐이고, 그 길은 우리가 최근에 만든 길이다.
  #   ⚠능력 확인을 먼저 통과할 때만 묻는다 — 낡은 판본에서 `auth status` 는 질문으로 나간다.
  if [ "$S1_LOGGED_IN" != "1" ] && claude_has_auth_cmd; then
    if claude auth status 2>/dev/null | grep -q '"loggedIn"[[:space:]]*:[[:space:]]*true'; then
      S1_LOGGED_IN=1
    fi
  fi
  if [ "$S1_LOGGED_IN" = "1" ]; then
    say "[3/10] 이미 로그인돼 있습니다 — 건너뜁니다 (멱등)."
    return 0
  fi
  if [ "$MODE" = "dry" ]; then
    say "[3/10] (dry-run) 폴링하지 않았습니다. 간격 ${LOGIN_POLL_INTERVAL}초 · 상한 ${LOGIN_POLL_TIMEOUT}초."
    return 0
  fi
  if ! claude_has_auth_cmd; then
    say "[3/10] 이 판본의 클로드는 로그인 확인 명령을 모릅니다. 판올림이 먼저 필요합니다."
    say "     아래 「다시 하시는 법」대로 다시 실행하시면 판올림부터 이어서 갑니다."; SHOW_RERUN=1
    return 6
  fi
  human "벤더" "로그인 승인 클릭 — 클로드 회사 화면에서만 할 수 있다(우리가 대신 못 누른다)"
  say "[3/10] 지금 로그인 화면을 엽니다. 브라우저가 뜨면 승인을 눌러 주십시오."
  claude auth login || true
  say "     승인이 끝났는지 확인합니다. 최대 $((LOGIN_POLL_TIMEOUT / 60))분까지 기다립니다."
  local waited=0 logged
  while [ "$waited" -lt "$LOGIN_POLL_TIMEOUT" ]; do
    logged="$(claude auth status 2>/dev/null | grep -o '"loggedIn"[[:space:]]*:[[:space:]]*true')"
    if [ -n "$logged" ]; then
      S1_LOGGED_IN=1
      say "[3/10] 로그인 확인했습니다."
      return 0
    fi
    sleep "$LOGIN_POLL_INTERVAL"
    waited=$((waited + LOGIN_POLL_INTERVAL))
  done
  say "[3/10] $((LOGIN_POLL_TIMEOUT / 60))분 동안 로그인이 확인되지 않았습니다."
  jcode "J-LOGIN-01" "로그인 승인이 시간 안에 끝나지 않았습니다"
  next_rerun "브라우저에서 승인을 누르신 뒤 아래 「다시 하시는 법」대로 다시 실행해 주십시오."
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
# 🔴🔴**실패를 「사람 손 한 번」으로 바꿔 적고 성공을 돌려주지 않는다**(3R N4 봉인 2026-09-10).
#   앞 판은 `seed_claude_prefs` 가 rc 1 로 돌아와도 `human` 한 줄만 찍고 **항상 0** 을 돌려줬다.
#   ⇒ 신뢰 기록이 실패한 판에서도 [4/10] 은 「갖춰 두었습니다」로 넘어갔다.
#   ★`human` 은 **사람에게 할 일이 생겼다는 표시**지 실패의 처리 방법이 아니다. 둘을 섞으면
#     단계는 늘 성공하고, 실패는 화면 한 줄로만 흘러간다.
# ⚠**실패의 종류를 가른다.** 사전 설정을 못 건 것(도구 부재 등)은 예전처럼 「사람 손 한 번」이면
#   끝나는 일이라 계속 간다. 그러나 **기록 실패는 다르다** — 그때는 설정을 도로 뺐고, 그 사실을
#   단계가 삼키면 화면은 「갖춰 두었습니다」라고 말한다. 그 한 줄만 단계 실패로 올린다.
TRUST_JOURNAL_FAILED=0
seed_all_profiles() {
  local p
  for p in $(profile_configs); do
    seed_claude_prefs "$p" || human "벤더" "클로드 첫 실행 질문($(redact "$p") 자리에 사전 설정을 못 걸었다)"
  done
  for p in $(profile_settings); do
    seed_claude_settings "$p" || human "벤더" "설정 파일($(redact "$p"))을 못 썼다"
  done
  [ "$TRUST_JOURNAL_FAILED" = "1" ] && return 1
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
  # 🔴2026-09-10 수리(R4) — 앞 판은 **자비스 작업 폴더에만** 신뢰를 심었다. 그런데 동료 좌석은
  #   팩 편성이 정하는 cwd 로 뜨고 그 cwd 가 **홈**이었다 ⇒ 좌석들이 「Quick safety check …
  #   Yes, I trust this folder」에서 서고, ★기본 선택이 「No, exit」라 Enter 만 누르면 클로드가
  #   종료돼 좌석이 셸로 낙하한다. 홈도 심어 그 고리를 끊는다.
  #   ⚠사용자 폴더 이름에 마침표가 있으면 plutil 이 그 칸을 가리킬 수 없다(이 저장소가 아는 함정) —
  #     조용히 지나가지 않고 화면에 말한다. 못 넘긴 질문은 사람이 한 번 누르면 끝난다.
  # ⑴자비스 작업 폴더 — 우리가 만든 자리다. 없으면 만들고, 있으면 우리 칸을 세운다.
  case "$JARVIS_HOME" in
    *.*) say "     (폴더 이름에 마침표가 있어 $(redact "$JARVIS_HOME") 의 폴더 신뢰 질문은 미리 넘기지 못했습니다 — 한 번 [Yes] 를 눌러 주십시오.)" ;;
    *) plutil -insert "projects.$JARVIS_HOME" -json '{"hasTrustDialogAccepted":true}' "$cfg" >/dev/null 2>&1 \
         || plutil -replace "projects.$JARVIS_HOME.hasTrustDialogAccepted" -bool true "$cfg" >/dev/null 2>&1 \
         || plutil -insert "projects.$JARVIS_HOME.hasTrustDialogAccepted" -bool true "$cfg" >/dev/null 2>&1 ;;
  esac
  # ⑵사용자 홈 — **참가자의 자리다.** 규칙이 다르다(1R REVISE ④ 봉인 2026-09-10 · 윈도우판과 같다).
  # 🔴🔴**이미 값이 있으면 손대지 않는다.** 앞 판은 있든 없든 true 로 세웠다. 그러면
  #   ①원래 true 였던 분의 값을 「우리 것」과 구별할 수 없게 되고(제거기가 남의 값을 지운다)
  #   ②원래 **false**(신뢰하지 않겠다고 명시적으로 고르신 것)를 조용히 true 로 뒤집는다.
  #   ★②는 안전 설정을 우리가 몰래 되돌리는 것이다 — 편의를 위해 할 일이 아니다.
  #   ⇒ **없을 때만 넣고, 넣은 것만 적어 둔다.** 제거기는 적힌 것만 되돌린다.
  #   ⚠값이 false 라 좌석이 신뢰 질문을 만나면 사람이 한 번 [Yes] 를 누르시면 된다 —
  #     남의 선택을 뒤집는 것보다 손 한 번이 싸다.
  case "$HOME" in
    *.*) say "     (폴더 이름에 마침표가 있어 $(redact "$HOME") 의 폴더 신뢰 질문은 미리 넘기지 못했습니다 — 한 번 [Yes] 를 눌러 주십시오.)" ;;
    *) if plutil -extract "projects.$HOME.hasTrustDialogAccepted" raw -o - "$cfg" >/dev/null 2>&1; then
         say "     (이 컴퓨터에는 홈 폴더 신뢰 설정이 이미 있어 그대로 두었습니다 — 우리가 바꾸지 않습니다.)"
       else
         # 되돌릴 때 **그만큼만** 되돌리려면, 무엇을 새로 만드는지 넣기 전에 갈라 둬야 한다.
         _made_entry=0
         plutil -extract "projects.$HOME" json -o - "$cfg" >/dev/null 2>&1 || _made_entry=1
         if plutil -insert "projects.$HOME" -json '{"hasTrustDialogAccepted":true}' "$cfg" >/dev/null 2>&1 \
            || plutil -insert "projects.$HOME.hasTrustDialogAccepted" -bool true "$cfg" >/dev/null 2>&1; then
           # 🔴🔴**기록에 실패하면 설정 변경을 되돌린다**(3R N4 봉인 2026-09-10).
           #   앞 판은 기록 실패를 「말하고 rc 1」로 끝냈다 — 그런데 **키는 이미 들어가 있었다.**
           #   ⇒ 제거기는 그 키를 「참가자의 것」으로 읽어 **영영 남긴다.** 우리가 남의 컴퓨터에
           #     되돌릴 길 없는 자국을 남기는 것이다.
           #   ★기록과 설정은 **함께 서거나 함께 물러난다** — 반쪽만 남으면 그것이 곧 자국이다.
           if ! printf '%s\t%s\n' "$cfg" "$HOME" >> "$TRUST_SEED_FILE" 2>/dev/null; then
             TRUST_JOURNAL_FAILED=1
             # 🔴🔴**되돌렸다고 말하기 전에 되돌아갔는지 본다**(4R BLOCK N4 봉인 2026-09-10).
             #   앞 판은 `plutil -remove` 의 종료값을 **버리고** 곧바로 「도로 뺐습니다」라고 말했다.
             #   디스크가 꽉 차면 기록 쓰기와 설정 되쓰기가 **함께** 실패한다 ⇒ 키는 남고 기록은 없는데
             #   화면은 되돌렸다고 말한다. 다음 실행은 그 키를 **참가자의 것**으로 읽어 영영 건너뛴다.
             #   ★「했다」는 **다시 봐서 없을 때만** 참이다 — 이 파일이 로그인 쪽에서 이미 배운 규칙이다.
             if [ "$_made_entry" = "1" ]; then
               plutil -remove "projects.$HOME" "$cfg" >/dev/null 2>&1 || true
             else
               plutil -remove "projects.$HOME.hasTrustDialogAccepted" "$cfg" >/dev/null 2>&1 || true
             fi
             if ! plutil -extract "projects.$HOME.hasTrustDialogAccepted" raw -o - "$cfg" >/dev/null 2>&1; then
               say "     (홈 폴더 신뢰 기록을 남기지 못해 그 설정을 도로 뺐습니다 — 좌석이 폴더 신뢰를 한 번 물을 수 있습니다.)"
               log "trust seed record FAILED -> rollback verified: $(redact "$cfg") + $(redact "$HOME")"
               return 1
             fi
             # 되돌리기도 실패했다. **키는 남고 기록은 없는** 상태만은 만들지 않는다 —
             #   기록을 한 번 더 시도해 둘을 맞춘다(그러면 지울 때 되돌릴 수 있다).
             if printf '%s\t%s\n' "$cfg" "$HOME" >> "$TRUST_SEED_FILE" 2>/dev/null; then
               say "     (설정을 도로 빼지 못해 기록을 남겨 두었습니다 — 지울 때 이 칸도 함께 되돌립니다.)"
               log "trust seed rollback FAILED -> journal re-recorded: $(redact "$cfg") + $(redact "$HOME")"
               return 1
             fi
             # 둘 다 실패했다. 조용히 지나가지 않는다 — 사람이 손으로 되돌릴 수 있게 **어디의 무엇**인지 적는다.
             say "     홈 폴더 신뢰 설정을 넣었는데 그 기록도, 되돌리기도 하지 못했습니다."
             say "        지울 때 이 칸은 자동으로 되돌아가지 않습니다. 손으로 빼시려면:"
             say "        파일 $(redact "$cfg") 의 projects → $(redact "$HOME") → hasTrustDialogAccepted 줄"
             log "trust seed rollback FAILED and journal FAILED: $(redact "$cfg") + $(redact "$HOME")"
             return 1
           fi
           log "trust seed record: $(redact "$cfg") + $(redact "$HOME")"
         fi
       fi ;;
  esac
  # 큰 화면 권유 질문은 「본 횟수」가 적을 때만 뜬다(실측: 그 값이 3인 기계에서는 안 떴다).
  plutil -replace fullscreenUpsellSeenCount -integer 99 "$cfg" >/dev/null 2>&1 \
    || plutil -insert fullscreenUpsellSeenCount -integer 99 "$cfg" >/dev/null 2>&1
  say "     첫 실행 질문(테마·폴더 신뢰·큰 화면 권유)을 미리 넘겨 두었습니다."
  log "seed: hasCompletedOnboarding=true · 작업 폴더 신뢰($(redact "$JARVIS_HOME")) · 홈 신뢰는 없을 때만($(redact "$HOME")) (되돌리기 = 우리가 넣은 키만 · 기록 = $(redact "$TRUST_SEED_FILE"))"
  return 0
}

step_prepare() {
  write_directive
  if [ "$MODE" = "dry" ]; then
    say "[4/10] (dry-run) 사전 설정을 쓰지 않았습니다(바깥 변경 0)."
    return 0
  fi
  if ! seed_all_profiles; then
    say "[4/10] 홈 폴더 신뢰 기록을 남기지 못했습니다 — 그 설정은 도로 뺐고, 여기서 멈춥니다."
    say "     기록 없이 그 칸만 넣으면 지울 때 되돌릴 길이 없습니다(남의 컴퓨터에 자국이 남습니다)."
    J_CODE="J-PERM-01"
    NEXT_STEP="저장 공간과 백신 알림을 확인하신 뒤 다시 실행해 주십시오."
    SHOW_RERUN=1
    return 4
  fi
  say "[4/10] 자비스가 쓸 것을 갖춰 두었습니다."
  return 0
}


# ── 하는 일 5 — cys 설치 파일 받기 ────────────────────────────────
# 완료 판정 = 파일이 있고 크기가 정확히 맞는가. 크기가 다르면 받다 끊긴 것이다.
step_download_cys() {
  mkdir -p "$DL_DIR"
  local dst got try
  dst="$DL_DIR/$CYS_MAC_FILE"
  if [ -f "$dst" ] && [ "$(wc -c < "$dst" | tr -d ' ')" = "$CYS_MAC_BYTES" ]; then
    say "[5/10] 설치 파일이 이미 있습니다 — 건너뜁니다."
    return 0
  fi
  if [ "$MODE" = "dry" ]; then
    say "[5/10] (dry-run) 받지 않았습니다. 받을 곳 = $CYS_DOWNLOAD_URL"
    return 0
  fi
  # 260MB 를 받기 전에 자리가 있는지 본다. 받다 중간에 꽉 차면 「받다 끊긴 파일」로만 보여
  # 사람은 망 문제로 오해한다 — 미리 갈라 말한다.
  local freemb
  freemb="$(df -m "$DL_DIR" 2>/dev/null | awk 'NR==2 {print $4}')"
  if [ -n "$freemb" ] && [ "$freemb" -lt 3072 ] 2>/dev/null; then
    say "[5/10] 저장 공간이 부족합니다 (남은 자리 약 ${freemb}MB · 3GB 이상을 권합니다)."
    jcode "J-DISK-01" "저장 공간이 부족합니다"
    next_rerun "공간을 3GB 이상 비우신 뒤 아래 「다시 하시는 법」대로 다시 실행해 주십시오."
    return 5
  fi
  for try in 1 2; do
    rm -f "$dst"
    say "[5/10] cys 설치 파일을 받습니다 (약 260MB · 잠시 걸립니다)."
    if ! curl -fsSL --max-time 900 "$CYS_DOWNLOAD_URL" -o "$dst"; then
      say "[5/10] 받지 못했습니다."
      # 두 번 해 보고 포기하지 않는다. 연결이 돌아오면 이어간다(같은 자리·같은 문장).
      # ⚠다시 해 보는 명령에도 상한이 있어야 한다 — 없으면 curl 이 응답 없는 연결에 매달려
      #   30분 상한이 있는 바깥 고리로 **돌아오지 못한다**(검토 지적 채택 2026-09-09).
      if ! wait_for_connection "[5/10]" 'curl -fsSL --max-time 900 "$CYS_DOWNLOAD_URL" -o "$dst"'; then
        next_rerun "연결이 된 뒤 아래 「다시 하시는 법」대로 다시 실행해 주십시오. 받은 데까지는 건너뛰고 이어서 갑니다."
        rm -f "$dst"
        return 5
      fi
    fi
    if [ ! -f "$dst" ]; then
      # 다 받았는데 파일이 없다 = 백신이 그 자리에서 격리했을 때 나는 모양이다(윈도우판과 같은 갈래).
      say "[5/10] 받은 파일이 사라졌습니다 — 백신이 격리했을 수 있습니다."
      jcode "J-AV-02" "받은 설치 파일이 사라졌습니다"
      say "     백신 알림이 떴다면 그 화면의 이름, 대상 파일, 조치(차단·격리·삭제) 세 가지를 알려 주십시오."
      continue
    fi
    got="$(wc -c < "$dst" | tr -d ' ')"
    if [ "$got" = "$CYS_MAC_BYTES" ]; then
      say "[5/10] 받았습니다 (크기 확인 완료)."
      return 0
    fi
    say "[5/10] 크기가 맞지 않습니다 (받은 것 $got · 기대 $CYS_MAC_BYTES). 다시 받습니다."
  done
  # 두 번 다 실패했으면 반쯤 받은 파일을 남기지 않는다 — 다음 실행이 그것을 온전한 것으로 볼 수 있다.
  rm -f "$dst"
  say "[5/10] 설치 파일을 온전히 받지 못했습니다."
  say "     공식 페이지에서 직접 받으실 수 있습니다: $CYS_SITE_URL"
  say "     받을 파일 이름 = $CYS_MAC_FILE"
  return 5
}

# ── 하는 일 6 — cys 설치 ──────────────────────────────────────────
# 완료 판정은 설치기의 종료 코드가 아니라 프로그램 실체가 생겼는가로 한다.
#
# 🔴2026-09-06 재작성 (깨끗한 맥 첫 실기 · Tart 가상 맥 실측). 앞 판은 **어떤 맥에서도 성공할 수
#   없었다.** 이 기계에서 한 번도 안 돌려 봤기 때문에 두 가지를 동시에 틀렸다.
#   ⑴ `hdiutil attach -nobrowse -quiet` 는 **마운트는 하지만 표준출력에 아무것도 안 찍는다.**
#      그래서 마운트 지점을 뽑던 awk 가 언제나 빈 문자열을 돌려주고, 그 다음 검사에서 곧바로
#      「설치 파일을 열지 못했습니다」로 끝났다. 게다가 그 실패 분기는 detach 앞에서 return 해서
#      **마운트한 디스크를 그대로 두고 나갔다** — 다시 돌릴 때마다 볼륨이 쌓인다.
#   ⑵ 더 근본적으로, 이 dmg 에는 **`cys.app` 이 최상위에 없다.** 안에 든 것은 `Install cys.app`
#      (설치 도우미)과 숨김 `.support/cys.app`(실물)이다. 그래서 `[ -d "$mnt/cys.app" ]` 이 거짓이라
#      **복사를 조용히 건너뛰고** 아무 에러 없이 다음 검사에서 실패했다.
#   ⇒ ★그리고 우리가 하려던 `cp -R` 자체가 **벤더가 일부러 막아 둔 방식**이었다. 설치 도우미의
#      원문 주석이 이유를 적어 놨다 — 최종 경로로 직접 복사하면 복사 도중 「반쪽 번들」이 노출되고,
#      그 순간 앱을 열면 Gatekeeper 가 미완본을 보고 **「손상되었기 때문에 열 수 없습니다」**로
#      막는다. 설치 도우미는 그 경합을 **원자 교체**(숨김 스테이징 → 단일 rename)로 없앤다.
#      우리 옛 코드는 그 경합을 그대로 재현하는 코드였다.
#   ⇒ 그래서 이제 **벤더가 dmg 안에 넣어 둔 CLI 진입점**을 그대로 부른다. 종료 코드 계약도 그
#      스크립트 주석에 명시돼 있다(0=완료 1=권한 실패 2=소스 아님 3=도구 결손 4=진위 실패).
#      GUI 경로(`open "Install cys.app"`)는 쓰지 않는다 — 대화상자가 둘 떠서 **사람 손이 2 늘어난다.**
CYS_DMG_MNT=""
cys_dmg_detach() {
  # 어느 경로로 나가든 마운트를 남기지 않는다. 실패 분기가 볼륨을 남기던 것이 앞 판의 결함이었다.
  [ -n "$CYS_DMG_MNT" ] || return 0
  hdiutil detach "$CYS_DMG_MNT" -quiet >/dev/null 2>&1 || hdiutil detach "$CYS_DMG_MNT" -force -quiet >/dev/null 2>&1 || true
  CYS_DMG_MNT=""
}
cys_dmg_remount() {
  # 권한 갈래에서만 쓴다 — 이미 붙어 있으면 그대로 쓰고, 떨어졌으면 다시 붙인다.
  [ -n "$CYS_DMG_MNT" ] && [ -d "$CYS_DMG_MNT" ] && return 0
  CYS_DMG_MNT="$(hdiutil attach -nobrowse "$DL_DIR/$CYS_MAC_FILE" 2>>"$LOG_FILE" | awk '/\/Volumes\//{ $1=""; $2=""; sub(/^[ \t]+/,""); print; exit }')"
  [ -n "$CYS_DMG_MNT" ] && [ -d "$CYS_DMG_MNT" ]
}

step_install_cys() {
  if [ -d /Applications/cys.app ]; then
    say "[6/10] cys 가 이미 설치돼 있습니다 — 건너뜁니다."
    return 0
  fi
  local dst core src rc
  if [ "$MODE" = "dry" ]; then
    say "[6/10] (dry-run) 설치 파일을 열지 않았습니다."
    return 0
  fi
  dst="$DL_DIR/$CYS_MAC_FILE"
  [ -f "$dst" ] || { say "[6/10] 설치 파일이 없습니다."; return 6; }
  say "[6/10] cys 를 설치합니다."

  # ⚠`-quiet` 를 주면 안 된다(위 ⑴). 사람에게 보일 필요는 없으니 화면 대신 기록 파일로만 흘린다.
  CYS_DMG_MNT="$(hdiutil attach -nobrowse "$dst" 2>>"$LOG_FILE" | awk '/\/Volumes\//{ $1=""; $2=""; sub(/^[ \t]+/,""); print; exit }')"
  if [ -z "$CYS_DMG_MNT" ] || [ ! -d "$CYS_DMG_MNT" ]; then
    say "[6/10] 설치 파일을 열지 못했습니다."
    cys_dmg_detach
    return 6
  fi

  core="$CYS_DMG_MNT/Install cys.app/Contents/Resources/install-core.sh"
  src="$CYS_DMG_MNT/.support/cys.app"
  if [ ! -f "$core" ] || [ ! -d "$src/Contents" ]; then
    # 배포물의 속 모양이 바뀐 경우다. 우리가 짐작으로 복사하지 않는다 — 짐작 복사가 앞 판의 결함이었다.
    say "[6/10] 설치 파일의 속 모양이 예상과 다릅니다. 공식 페이지에서 직접 받아 열어 주십시오: $CYS_SITE_URL"
    cys_dmg_detach
    return 6
  fi

  # 벤더 정본 원자 설치기. 관리자 권한을 쓰지 않고 먼저 시도하는 것도 그 스크립트가 한다.
  /bin/bash "$core" "$src" /Applications/cys.app >>"$LOG_FILE" 2>&1
  rc=$?
  #   rc=1(권한 실패)은 아래에서 설치 도우미를 열어야 하므로 그 갈래에서 다시 마운트한다.
  [ "$rc" = "1" ] || cys_dmg_detach

  case "$rc" in
    0) : ;;
    1) # 🔴적대검증이 무너뜨린 자리다(2026-09-06). 앞 판은 여기서 「그 창은 사람이 직접 눌러야 하는
       #   자리입니다」라고 안내하고 끝냈다. **그런데 그 창은 뜨지 않는다** — 비밀번호 창을 띄우는
       #   책임은 벤더의 `Install cys.app`(AppleScript) 에 있고, 우리는 그 안의 셸 코어만 직접 불러서
       #   **GUI 승격 갈래를 통째로 우회**했기 때문이다. 셸은 스스로 그 창을 못 띄운다.
       #   ⇒ 사용자는 **영원히 안 뜰 창**을 기다리게 된다. 안내문이 거짓말이 되는 자리였다.
       #   ⇒ 무승격으로 안 되는 것이 확인된 **이때만** 벤더 설치 도우미를 연다. 그 도우미가
       #   자기 대화상자로 비밀번호를 묻는다(누르는 것은 사람이다 — 우리가 대신 넣지 않는다).
       #   ⚠평소 경로에는 손이 늘지 않는다. 여는 것은 「안 그러면 설치가 불가능한」 경우뿐이다.
       cys_dmg_remount || { say "[6/10] 설치 파일을 다시 열지 못했습니다."; return 6; }
       say "[6/10] 이 계정에는 프로그램 폴더에 넣을 권한이 없습니다 — 설치 도우미를 엽니다."
       say "     창이 뜨면 「설치」를 누르시고, 이 컴퓨터의 관리자 비밀번호를 넣어 주십시오."
       say "     (자비스는 비밀번호를 대신 넣지 않습니다. 넣으신 뒤 끝나면 「닫기」를 누르십시오.)"
       open "$CYS_DMG_MNT/Install cys.app" >>"$LOG_FILE" 2>&1 || {
         say "     설치 도우미를 열지 못했습니다. 공식 페이지에서 직접 받아 열어 주십시오: $CYS_SITE_URL"
         cys_dmg_detach; return 6; }
       #   사람이 창을 다 누를 때까지 기다린다. 끝났는지는 **프로그램 실체가 생겼는가**로 본다.
       local waited=0
       while [ "$waited" -lt 300 ]; do
         [ -d /Applications/cys.app ] && break
         sleep 3; waited=$((waited + 3))
       done
       cys_dmg_detach
       if [ -d /Applications/cys.app ]; then
         say "[6/10] 설치를 마쳤습니다."
         return 0
       fi
       say "[6/10] 5분 동안 설치가 확인되지 않았습니다. 아래 「다시 하시는 법」대로 다시 실행하시면 여기서부터 이어서 갑니다."; SHOW_RERUN=1
       return 6 ;;
    2|3) say "[6/10] 설치 파일이 온전하지 않습니다. 아래 「다시 하시는 법」대로 다시 실행하시면 다시 받습니다."; SHOW_RERUN=1
         rm -f "$dst"
         return 6 ;;
    4) say "[6/10] 받은 설치 파일이 공식 서명 검사를 통과하지 못했습니다 — 설치를 멈춥니다."
       say "     받다가 바뀐 파일이거나, 이 컴퓨터가 애플의 확인 서비스에 닿지 못한 경우입니다."
       say "     공식 페이지에서 직접 받아 열어 주십시오: $CYS_SITE_URL"
       #   ⛔받은 파일을 지우지 않는다. 검사 실패의 원인이 파일이 아니라 **확인 경로**일 수 있고
       #   (2026-09-06 실측: 가상 맥에서는 공증된 앱이 전부 거절됐는데 같은 파일이 실물 맥에서는
       #   통과했다), 그때 지워 버리면 멀쩡한 260MB 를 다시 받게 만든다. 걸렸을 때 그 파일이 단서다.
       return 6 ;;
    *) say "[6/10] 설치가 끝나지 않았습니다 (종료 코드 $rc). 자세한 내용은 기록 파일에 있습니다: $(redact "$LOG_FILE")"
       return 6 ;;
  esac

  if [ -d /Applications/cys.app ]; then
    say "[6/10] 설치를 마쳤습니다."
    return 0
  fi
  say "[6/10] 설치가 확인되지 않았습니다."
  return 6
}

# ── 하는 일 7 — cys 가 실제로 쓸 수 있는가 ────────────────────────
# 프로그램 실체와 버전 응답 두 가지를 본다.
step_verify_cys() {
  local c ver
  #   dry 분기가 이 단에만 없었다. 깨끗한 기계에는 /Applications/cys.app 이 없으므로 미리보기가
  #   여기서 rc 7 로 끊겨 **[8/10] 이 호출조차 안 됐다**(화면이 7 다음에 9 로 건너뛴다). 다른 아홉 단은
  #   전부 dry 분기를 갖고 있었고, 이 단만 없어서 미리보기가 기계 상태에 따라 다른 길을 갔다.
  #   ⇒ cys 가 이미 깔린 기계(개발기)에서는 안 드러나고 깨끗한 기계에서만 드러나는 형태였다.
  if [ "$MODE" = "dry" ]; then
    say "[7/10] (dry-run) cys 를 확인하지 않았습니다."
    return 0
  fi
  if [ ! -d /Applications/cys.app ]; then
    say "[7/10] cys 프로그램을 찾지 못했습니다."
    return 7
  fi
  say "[7/10] cys 프로그램을 찾았습니다: /Applications/cys.app"
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
    say "[7/10] cys 가 답합니다: $ver"
    say "     부르는 길: $(redact "$CYS_CLI")"
    return 0
  fi
  say "[7/10] 프로그램은 있는데 아직 명령으로 부를 수 없습니다. 터미널 창을 새로 열고 아래 「다시 하시는 법」대로 다시 실행해 주십시오."; SHOW_RERUN=1
  return 7
}

# ── 하는 일 8 — 이 계정에 자리 잡기 ───────────────────────────────
# 관리자 권한을 쓰지 않는다. 마지막 판정은 자가진단이 전부 통과하는가로 한다.
step_prepare_account() {
  local cli i pong doc bad
  cli="${CYS_CLI:-cys}"
  if [ "$MODE" = "dry" ]; then
    say "[8/10] (dry-run) 계정 준비를 하지 않았습니다."
    return 0
  fi
  say "[8/10] 이 계정에 자리를 잡습니다."
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
    say "[8/10] 준비는 됐는데 아직 응답이 없습니다. 잠시 뒤 아래 「다시 하시는 법」대로 다시 실행해 주십시오."; SHOW_RERUN=1
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
    say "[8/10] 자가진단: ${summary#*요약: }"
  else
    bad="$(printf '%s\n' "$doc" | grep -c '\[FAIL *\]' | tr -d ' ')"
    n_skip="$(printf '%s\n' "$doc" | grep -c '\[SKIP *\]' | tr -d ' ')"
    say "[8/10] 자가진단 요약 줄을 찾지 못해 항목을 세었습니다: 실패 ${bad:-0}"
  fi
  # 통과 기준은 실패 0 이다. 주의는 성한 컴퓨터에도 나온다.
  if [ "${bad:-0}" -gt 0 ]; then
    say "[8/10] 자가진단에서 ${bad}가지가 통과하지 못했습니다."
    say "     아래 자비스가 무엇이 걸렸는지 사람 말로 알려 드립니다."
    return 8
  fi
  # 판정 못 한 항목은 「됐다」로 세지 않는다 — 몇 개인지 그대로 알린다.
  if [ "${n_skip:-0}" -gt 0 ]; then
    say "     (${n_skip}가지는 이 컴퓨터에서 판정할 수 없는 항목입니다 — 고장이 아닙니다.)"
  fi
  # 자리를 잡으면서 자비스 전용 설정 자리가 새로 생긴다 — 동료들이 그 자리로 뜨므로 한 번 더 심는다.
  if ! seed_all_profiles; then
    say "[8/10] 홈 폴더 신뢰 기록을 남기지 못했습니다 — 그 설정은 도로 뺐고, 여기서 멈춥니다."
    J_CODE="J-PERM-01"
    NEXT_STEP="저장 공간과 백신 알림을 확인하신 뒤 다시 실행해 주십시오."
    SHOW_RERUN=1
    return 8
  fi
  say "[8/10] 자리를 잡았습니다 (실패 0)."
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
# 🔴🔴**이전 설치의 좌석을 이번 선언으로 세지 않는다**(2R N2 봉인 2026-09-10).
#   앞 판은 전역 목록에서 **역할 이름만** 셌다. 그러면 지난 설치의 master·cso·worker 가 아직 살아
#   있는 기계에서는 사람이 **아무 선언도 하지 않았는데** 첫 폴링에 세 역할이 다 차서
#   「함대가 섰습니다」로 끝난다 — 새로 연 자비스는 깨어 있지도 않다.
#   ⇒ 자리를 열기 **전에** 목록을 찍어 두고(기준선), 그 뒤 **새로 생긴 자리만** 센다.
# 🔴🔴**기준선을 못 찍었으면 세는 것 자체를 하지 않는다**(3R N2 봉인 2026-09-10 · master 결정).
#   기준선은 「이번 설치의 자리」와 「지난 설치의 자리」를 가르는 **유일한 근거**다. 그 조회가 실패해
#   빈 집합이 되면, 다음 조회에 보이는 **옛 좌석 전부가 새 좌석으로** 읽힌다 ⇒ 사람이 아무 말도
#   하지 않았는데 첫 폴링에 「함대가 섰습니다」로 끝난다.
#   ★빈 집합은 「아무것도 없었다」가 아니라 **「못 물어봤다」**일 수 있다. 그 둘을 한 칸에 담으면
#     실패가 곧 거짓 성공이 된다(우리가 세 라운드 내내 되풀이한 형태다).
#   ⇒ 실패면 **계산하지 않고 모른다고 말한다**(unknown 게이트).
FLEET_BASELINE=""
FLEET_BASELINE_OK=0
set_fleet_baseline() {
  local out
  if ! out="$(CYS_NO_AUTOSTART=1 "$1" list 2>&1)"; then
    FLEET_BASELINE=""; FLEET_BASELINE_OK=0
    log "fleet baseline FAILED: cys list 가 답하지 않았다 -> 좌석 판정 안 함"
    return 1
  fi
  FLEET_BASELINE=" $(printf '%s\n' "$out" | grep -oE 'surface:[0-9]+' | sort -u | tr '\n' ' ')"
  FLEET_BASELINE_OK=1
  log "fleet baseline surfaces:$FLEET_BASELINE"
  return 0
}
live_roles() {
  local out r live="" line sid
  out="$(CYS_NO_AUTOSTART=1 "$1" list 2>&1)"
  while IFS= read -r line; do
    [ -n "$line" ] || continue
    sid="$(printf '%s' "$line" | grep -oE 'surface:[0-9]+' | head -1)"
    # 기준선에 있던 자리는 **이번 설치의 것이 아니다** — 세지 않는다.
    if [ -n "$sid" ]; then
      case "$FLEET_BASELINE" in *" $sid "*) continue ;; esac
    fi
    for r in $FLEET_ROLES; do
      case " $live " in *" $r "*) continue ;; esac
      printf '%s' "$line" | grep -qE "role=${r}(\s|-|\b)" && live="$live $r"
    done
  done <<EOF_LIVE
$out
EOF_LIVE
  printf '%s' "${live# }"
}
# 🔴🔴**「선언됐다」의 근거를 바꾼다**(1R BLOCK ③ 봉인 2026-09-10).
#   앞 판은 「목록에 master 가 있으면 사람이 선언한 것」으로 봤다. **그 축은 처음부터 거짓이었다** —
#   ★master 좌석을 만든 것은 사람이 아니라 **우리 자신**이다(우리가 role=master 자리를 연다).
#   그래서 사람이 아무것도 치지 않아도 「부르는 중 · 사람이 하실 일 없습니다」라고 말하고
#   끝에는 「그 한마디는 들어갔습니다」라고 단정했다 ⇒ 선언이 영영 안 일어나고 6분을 버린다.
#   ⇒ 근거 = **자식 좌석의 출현**. cso·worker 는 자비스가 선언을 듣고서야 부른다(우리가 안 만든다).
#   ⚠자식이 없으면 **선언 여부를 우리는 모른다** — 모를 때는 단정하지 않고 조건문으로 말한다.
declaration_seen() { # declaration_seen "<live 목록>"
  local r
  for r in $1; do
    [ "$r" = "master" ] || return 0
  done
  return 1
}
step_fleet() {
  local ref="$1" cli i live missing r
  cli="${CYS_CLI:-cys}"
  if [ "$MODE" = "dry" ]; then say "[10/10] (dry-run) 함대를 부르지 않았습니다."; return 0; fi
  if [ -z "$ref" ]; then
    say "[10/10] 자비스 창을 못 열어 동료들을 부르지 못했습니다."
    say "     cys 창에서 자비스에게 이렇게 말해 주십시오: $FLEET_TRIGGER"
    return 10
  fi
  # 🔴2026-09-10 실기에서 고친 것(R5 · 윈도우에서 드러났고 이쪽도 같은 문구다) — 옛 문구는 「강제」였는데
  #   같은 시간에 자비스는 「사람이 할 일 없음」이라 적고 있었다 ⇒ 두 화면이 정면으로 모순이었다.
  #   ★안전장치 설명은 남기고 「강제」의 어감만 뺀다.
  # ★기준선을 못 찍었으면 **여기서 멈춘다** — 세어 봐야 그 수가 무엇을 뜻하는지 모른다.
  if [ "$FLEET_BASELINE_OK" != "1" ]; then
    say "[10/10] 지금 열려 있는 자리 목록을 읽지 못해, 동료들이 섰는지 판정하지 않습니다."
    say "     cys 창에서 자비스에게 이렇게 말해 주십시오: $FLEET_TRIGGER"
    say "     그 뒤 자비스에게 「동료들 다 섰어?」라고 물어보시면 자비스가 직접 확인해 알려 드립니다."
    return 10
  fi
  human "자비스" "이 한마디만 사람이 칩니다 — cys 창에서 직접 쳐 주십시오(안전장치)"
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
    # 🔴2026-09-10 수리(R5) — 앞 판은 **판정 없이** 「아직 치지 않으셨다면」을 되풀이했다.
    #   ★판정 축은 이미 손에 있다 — master 자리가 목록에 서 있으면 그 한마디는 **이미 들어간 것**이다.
    #   ⚠새 프로브를 만들지 않는다(5초마다 부르는 `cys list` 의 답을 그대로 읽는다).
    if [ "$i" -gt 0 ] && [ $((i % 12)) -eq 0 ]; then
      if declaration_seen "$live"; then
        say "   자비스가 동료들을 부르는 중입니다. 그대로 기다려 주십시오 ($((i * 5 / 60))분 지남 · 최대 $((FLEET_WAIT_TRIES * 5 / 60))분)."
        say "     선 자리 = ${live:-없음}  (사람이 하실 일은 없습니다)"
      else
        say "   기다리는 중입니다 ($((i * 5 / 60))분 지남 · 최대 $((FLEET_WAIT_TRIES * 5 / 60))분). 아직 치지 않으셨다면 지금 쳐 주십시오."
      fi
    fi
  done
  missing=""
  for r in $FLEET_ROLES; do
    printf '%s' " $live " | grep -q " $r " || missing="$missing $r"
  done
  if [ -z "$missing" ]; then
    say "[10/10] 함대가 섰습니다: $live"
    return 0
  fi
  # 성공보다 이 문구가 중요하다 — 무엇이 없어서 못 섰는지를 그대로 말한다.
  say "[10/10] 아직 서지 않은 자리가 있습니다:${missing}"
  say "     선 자리 = ${live:-없음}"
  # ★여기서도 「아직 안 쳤다」를 단정하지 않는다 — master 가 서 있으면 그 말은 거짓이다(R5).
  if declaration_seen "$live"; then
    say "     자비스는 이미 깨어 있습니다(master 자리가 섰습니다) — 그 한마디는 들어갔습니다."
    say "     남은 자리는 자비스가 이어서 세웁니다. cys 창의 자비스에게 무엇이 걸렸는지 물어보십시오."
  else
    say "     아직 그 한마디를 치지 않으셨다면, cys 창에서 지금 쳐 주시면 됩니다."
    say "     치셨는데도 서지 않았다면 cys 창의 자비스에게 물어보십시오 — 무엇이 걸렸는지 사람 말로 알려 줍니다."
  fi
  log "fleet missing:${missing}"
  return 10
}

# 자비스 자리를 연다. 「무엇을 띄우는지」 칸은 그 칸이 있는 판본에서만 붙인다 —
# 없는 판본에 붙이면 모르는 인자라며 거절당해 자리 자체가 안 열린다(그것이 조건을 둔 유일한 까닭이다).
cys_open_master_seat() {   # $1 = 여는 명령 · 화면으로 나가는 것 = cys 가 답한 내용
  local cli="${CYS_CLI:-cys}"
  if cys_supports_agent_flag; then
    "$cli" new-surface --role master --cwd "$JARVIS_HOME" --title "jarvis" --agent claude --cmd "$1" 2>&1
  else
    "$cli" new-surface --role master --cwd "$JARVIS_HOME" --title "jarvis" --cmd "$1" 2>&1
  fi
}

# ── 하는 일 9 — 자비스 깨우기 ─────────────────────────────────────
# cys 안에서 세션을 여는 것이 기본이고, 그것이 안 되면 이 창에서 바로 띄운다.
step_wake() {
  local first_prompt cli ref fleet_rc
  # 바깥 프로그램에 넘기는 글자는 ASCII 로만 쓴다(윈도우에서 우리말 인자가 깨져 거절당했다).
  # 우리말 문장은 인자가 아니라 지침 파일에 담아 보낸다 — 자비스가 그 파일을 직접 읽는다.
  first_prompt="Read the file ${DIRECTIVE_FILE} and do exactly what it says. Your first line must be the fixed line specified there."
  if [ "$MODE" = "dry" ]; then
    say "[9/10] (dry-run) 자비스를 띄우지 않았습니다."
    say "     (지금까지 사람 손이 필요했던 횟수: ${HUMAN_HANDS}번)"
    step_fleet ""
    return 0
  fi
  say "[9/10] 자비스를 깨웁니다."
  say "     (지금까지 사람 손이 필요했던 횟수: ${HUMAN_HANDS}번)"
  cli="${CYS_CLI:-cys}"
  if command -v "$cli" >/dev/null 2>&1 || [ -x "$cli" ]; then
    # 창 이름도 같은 이유로 ASCII 다.
    # 여는 명령에 문장을 실으면 안 된다(윈도우에서 두 번 실측: 우리말이 깨졌고, 따옴표가 벗겨졌다).
    # 문장은 파일에 넣고 여는 명령은 그 파일 하나만 가리킨다 — 맥도 같은 모양으로 맞춘다.
    wake_file="$JARVIS_HOME/wake.sh"
    #   보험이다. 결함을 메우는 것이 아니다 — cys 가 띄우는 창은 cysd 가 `~/.local/bin` 을 PATH 앞에 심어 줘서
    #   `claude` 만 써도 잡힌다(2026-09-06 깨끗한 맥 실측). 다만 그 주입은 **cys 쪽 구현이지 우리 계약이
    #   아니다.** 우리 창이 아닌 곳에서 도는 파일이므로, 남의 구현에 기대지 않고 우리가 아는 자리를 먼저 본다.
    printf '#!/bin/bash\nCLAUDE="$HOME/.local/bin/claude"\n[ -x "$CLAUDE" ] || CLAUDE=claude\nexec "$CLAUDE" --dangerously-skip-permissions %s\n' "'$first_prompt'" > "$wake_file" 2>/dev/null
    chmod +x "$wake_file" 2>/dev/null
    # ★자리를 열기 **전에** 기준선을 찍는다(2R N2). 이 줄이 자리 여는 줄보다 뒤에 오면
    #   우리가 만든 master 자리까지 기준선에 들어가 영영 안 세어진다.
    set_fleet_baseline "$cli"
    cmd_line="bash $wake_file"
    if [ ! -f "$wake_file" ] || case "$wake_file" in *" "*) true ;; *) false ;; esac; then
      say "     여는 파일의 경로를 쓸 수 없어 cys 안에서는 열지 못합니다. 이 창에서 띄웁니다."
      log "wake path unusable: $wake_file"
      ref=""
    else
      ref="$(cys_open_master_seat "$cmd_line" | tr -d '\n')"
    fi
    case "$ref" in
      *surface:*)
        say "     cys 안에서 자비스를 열었습니다 ($ref). cys 창에서 이어서 이야기하십시오."
        # 창이 열렸으면 곧바로 동료들을 부른다(아래 폴백으로 내려가면 자비스 화면에 갇혀 다음 줄을 못 간다).
        step_fleet "$(printf '%s' "$ref" | sed -n 's/.*\(surface:[0-9][0-9]*\).*/\1/p')"
        fleet_rc=$?
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
  # 같은 보험을 이 창에도 건다 — 우리가 방금 깐 자리를 먼저 보고, 없을 때만 PATH 에 맡긴다.
  local claude_bin="$HOME/.local/bin/claude"
  if [ ! -x "$claude_bin" ]; then
    claude_bin="$(command -v claude 2>/dev/null)"
  fi
  if [ -z "$claude_bin" ]; then
    say "[9/10] 자비스를 띄우지 못했습니다 — 클로드 명령을 찾지 못했습니다."
    say "     터미널 창을 새로 열고 아래 「다시 하시는 법」대로 다시 실행해 주십시오."; SHOW_RERUN=1
    return 9
  fi
  if [ ! -t 0 ] && [ -r /dev/tty ]; then
    exec < /dev/tty
  fi
  exec "$claude_bin" --dangerously-skip-permissions "$first_prompt"
}

# 시험이 이 파일을 「함수 묶음」으로만 읽는 문. 여기서 멈추므로 본문은 한 줄도 돌지 않는다.
#   왜 필요한가: 좌석 여는 자리가 실제로 무엇을 넘기는지는 **글자로 세면 알 수 없다** —
#   조건 갈래 양쪽이 파일에 다 적혀 있기 때문이다. 재려면 그 함수를 실제로 불러야 하고,
#   부르려면 설치 단계를 지나지 않고 이 파일을 읽어 들일 길이 있어야 한다.
#   ⚠사람이 쓰는 길이 아니다(설치기는 이 변수 없이 돈다 — 없으면 이 줄은 아무 일도 하지 않는다).
[ "${JARVIS_LIB_ONLY:-}" = "1" ] && { return 0 2>/dev/null || exit 0; }

# ── 본문 ──────────────────────────────────────────────────────────
say "=== 자비스 설치 도우미 $BOOTSTRAP_VERSION (모드: $MODE) ==="
say "[1/10] 이 컴퓨터를 살펴봅니다."
detect_stage1
detect_stage2
write_report

if [ "$MODE" = "detect" ]; then
  say "감지만 하고 끝냅니다."
  # 끝맺음 한 줄은 그 끝에 맞아야 한다 — 「살펴보기만 한 끝」에 「이어서 갑니다」는 맞지 않는다.
  next_rerun "실제로 설치하시려면 --detect-only 없이 아래 「다시 하시는 법」대로 다시 실행해 주십시오."
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
