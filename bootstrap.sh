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
# 🔴🔴**꼬리 빗금을 여기서 한 번에 걷어낸다**(교차 검토 1차 NEW-1 · 2026-09-11).
#   `rm -rf "이음줄/"` 은 **이음줄이 아니라 가리키던 자리 안엣것**을 지운다(뒤에 빗금이 붙으면
#   그 자리를 「폴더」로 풀어서 보기 때문이다). 이름 관문은 `%/` 로 하나만 떼고 봤으므로
#   `…/install-jarvis//` 같은 값이 지우는 자리까지 그대로 흘러갈 수 있었다.
#   ⇒ 들어온 자리를 **한 번만 정리해** 이후 모든 자리가 같은 글자를 보게 한다.
while [ "${JARVIS_HOME%/}" != "$JARVIS_HOME" ] && [ ${#JARVIS_HOME} -gt 1 ]; do
  JARVIS_HOME="${JARVIS_HOME%/}"
done
LOG_FILE="$JARVIS_HOME/bootstrap.log"
REPORT_FILE="$JARVIS_HOME/env-report.md"
DIRECTIVE_FILE="$JARVIS_HOME/install-directive.md"
DL_DIR="$JARVIS_HOME/dl"
# 🔴우리가 **홈 폴더에 새로 넣은** 신뢰 키의 기록(설정파일<탭>키). 제거기는 이 파일에 적힌 것만
#   되돌린다 — 적히지 않은 키는 참가자의 것이므로 손대지 않는다(1차 검토 REVISE ④).
#   ⚠TSV 다: 두 OS 가 같은 파일을 읽고 쓰는데 깨끗한 맥에는 JSON 도구(jq)가 없다.
TRUST_SEED_FILE="$JARVIS_HOME/trust-seed.tsv"
# 🔴**우리가 만든 폴더라는 표식**(2차 검토 N3). 제거기는 이 표식이 있을 때만 작업 폴더를 재귀로 지운다 —
#   `JARVIS_HOME` 은 환경변수라 무엇이든 들어올 수 있고, 검사 없이 지우면 남의 폴더가 사라진다.
JARVIS_OWNER_FILE="$JARVIS_HOME/.jarvis-owned"
JARVIS_OWNER_MARK="jarvis-installer-owned v1"
BLOCKED_STEP=""

# cys 설치 파일 — 판본이 파일 이름에 박혀 배포되므로 여기에 핀한다.
# 🔴★2026-09-11 핫픽스(v0.3.11) — **받을 자리**와 **판본**을 함께 고친다.
#   ⑴ 받을 자리를 **벤더 GitHub 릴리스**로 옮긴다. 앞 판이 쓰던 배포 폴더는 **최신 판본 하나만** 둔다 —
#      벤더가 0.14.33 을 올린 날 우리가 핀해 둔 0.14.30 이 **404 로 사라졌고**, 그때부터 깨끗한 맥에서
#      설치가 **100% 실패**했다(2026-09-11 09:47 실측: 옛 핀 두 파일 다 404 · 그 폴더에 남은 dmg 는
#      0.14.33 둘뿐). 릴리스 자산은 **판본별로 남는다**(같은 시각 실측: v0.14.30 자산 270596222B 건재).
#      ⇒ 판본이 박힌 자리를 쓰면 **벤더가 다음 판을 내도 우리 핀이 사라지지 않는다.**
#      ★핀을 「늘 최신을 가리키는 자리」에 걸면, 그 자리가 움직이는 날 라이브가 조용히 죽는다.
#   ⑵ 판본 0.14.30 → **0.14.33**(벤더 마지막 판본).
#   크기·지문은 **받을 자리에서 두 번 받아** 쟀다(2026-09-11 09:5x · 두 번 동일 · 옛 배포 폴더에서 받은
#   두 벌과도 같았다 = 네 벌 전수 일치):
#     aarch64 272977882 · 3919ce1c… / x64 269923933 · 7ec9e557…
#   서명·공증도 벤더 기준선(로컬 0.14.27 dmg)과 같다 —
#     Developer ID Application: yoonsik choi (Q43YA2NMF9) · Notarized Developer ID · stapled.
#     ⚠대라고 한 기준선은 0.14.30 이었는데 **그 파일을 이제 못 받는다**(위 404) ⇒ 0.14.27 로 잡았고
#       그 사실을 여기 적는다. 못 잰 것을 잰 것처럼 적지 않는다.
#   ⚠윈도우(bootstrap.ps1)는 2026-09-09부터 **우리 릴리스**를 받는다(우리 빌드가 서명돼 있다).
#     맥은 우리 빌드가 무서명이라 아직 벤더 dmg 그대로다 — 두 OS 가 갈리는 것이 지금은 의도다.
CYS_VERSION="0.14.33"
CYS_DOWNLOAD_DIR="https://github.com/idoforgod/cys-terminal/releases/download/v${CYS_VERSION}/"
case "$(uname -m)" in
  arm64) CYS_MAC_FILE="cys_${CYS_VERSION}_aarch64.dmg"; CYS_MAC_BYTES=272977882
         CYS_MAC_SHA256="3919ce1cad7ac834584951190420f92d6ba86b3a2343451829e784aadf3153df" ;;
  *)     CYS_MAC_FILE="cys_${CYS_VERSION}_x64.dmg";     CYS_MAC_BYTES=269923933
         CYS_MAC_SHA256="7ec9e557f9185d03416f949341f5b7b4dc3367aaf72206e754c736d4e7395153" ;;
esac
CYS_DOWNLOAD_URL="${CYS_DOWNLOAD_DIR}${CYS_MAC_FILE}"

LOGIN_POLL_INTERVAL=3      # 초
LOGIN_POLL_TIMEOUT=600     # 초 (10분)
# 🔴★승인 대기 구간 — 여기에는 **상한이 없었다**(2026-09-11 Tart 실기).
#   벤더의 `claude auth login` 이 「Paste code here if prompted >」를 띄운 뒤
#   **2시간 32분 41초 동안 화면에 0바이트**를 찍고 서 있었다. 위 10분 상한은 **그 다음 구간(폴링)**
#   에만 있어 여기엔 닿지 않는다 — 벤더 프롬프트가 먼저 막기 때문이다.
#   ⇒ 사람이 승인 창을 열어 놓고 잠깐 자리를 비우면 **아무 말도 없는 창**을 마주한다.
#     (신청자 방 안내가 나간 날 가장 밟기 쉬운 자리다.)
#   두 가지를 넣는다: **60초마다 한 줄** · **20분이면 이 기다림을 끝낸다**.
LOGIN_SAY_INTERVAL=60      # 초 — 기다리는 동안 화면에 한 줄씩 말하는 간격
# 왜 20분인가: 브라우저에서 승인하고 코드를 붙여넣는 데 실기 기준 **1~2분**이면 된다.
#   20분은 그 열 배이고, 자리를 비운 사람을 한 시간씩 세워 두지 않는 값이다.
#   ★이 상한 뒤에는 기존 폴링 10분이 이어지므로 **최악이 30분**으로 닫힌다(그 전에는 무한이었다).
LOGIN_WAIT_TIMEOUT=1200    # 초 (20분) — 승인 대기 자체의 상한

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
# 🔴화면 문구에서 「강제」를 뺀다(1차 검토 확정 2026-09-10 · 윈도우판과 같다). 이 칸의 뜻은 「누가
#   시키는가」이지 「우리가 사람을 강제한다」가 아니다. 앞 판은 자리마다 문구를 순화해 놓고
#   **이 공통 래퍼가 여전히 「강제: 자비스」를 인쇄**해 화면에는 순화가 하나도 안 나타났다.
#   ★자리마다 고치고 공통 자리를 안 고치면 아무것도 안 고친 것이다.
HUMAN_HANDS=0
human() {
  HUMAN_HANDS=$((HUMAN_HANDS + 1))
  say "[사람 손 #${HUMAN_HANDS} · 시킨 쪽: $1] $2"
}
say() { printf '%s\n' "$*"; log "$*"; }
# 화면에만 말한다 — 기록에는 안 남긴다.
#   ★왜 가르는가: 60초마다 같은 줄이 `bootstrap.log` 를 가득 채우면, 나중에 그 파일을 읽는 사람이
#   **진짜 사건을 못 찾는다.** 기다림은 「지금 보는 사람」을 위한 말이고, 기록은 「나중 사람」을 위한 것이다.
tell() { printf '%s\n' "$*" >&2; }

# ── 승인 대기 감시자 ──────────────────────────────────────────
# ⛔**승인 프로세스는 앞(foreground)에 그대로 둔다.** 사람이 코드를 붙여넣어야 하므로 stdin 을
#   뺏으면 안 된다 — 그래서 **감시자를 배경에 두는** 모양이 됐다(반대로 하면 붙여넣기가 죽는다).
# ★상한에 닿으면 **그 프로세스 하나에만** INT 를 보낸다 = **사람이 Ctrl-C 를 누른 것과 같은 결과**.
#   그 뒤는 이미 있는 길(폴링 → J-LOGIN-01 → 「다시 하시는 법」)로 그대로 흘러간다.
# ⛔벤더 화면을 자동으로 넘기거나 코드를 대신 넣지 않는다(그건 우리가 할 일이 아니다).

# 상한에서 **그 프로세스 하나만** 끝낸다.
# 🔴앞 판은 `pgrep -P` 로 「지금의 자식들」을 **다시 찾아** INT 를 보냈다(검토 지적 채택 2026-09-11).
#   그 사이 승인이 끝나고 본문이 `claude auth status` 를 띄웠으면 **무관한 자식이 맞는다** —
#   그러면 우리가 20분을 기다린 끝에 **로그인 확인 단계를 우리 손으로 깨뜨리는** 셈이다.
#   ⇒ 표적을 **띄울 때 한 번** 적어 두고, 그 **번호와 시작 시각이 둘 다 맞을 때만** 보낸다.
#     ★번호는 재사용된다 — 번호만 맞추면 남의 프로세스를 맞힐 수 있다. 시작 시각이 그것을 가른다.
login_end_wait() {
  local pidfile="$1" pid born now
  [ -f "$pidfile" ] || return 0          # 이미 끝났고 표적도 치웠다
  pid="$(sed -n 1p "$pidfile" 2>/dev/null)"
  born="$(sed -n 2p "$pidfile" 2>/dev/null)"
  case "$pid" in ''|*[!0-9]*) return 0 ;; esac
  now="$(ps -o lstart= -p "$pid" 2>/dev/null)"
  [ -n "$now" ] || return 0              # 그 번호는 이제 없다
  [ "$now" = "$born" ] || return 0       # 번호가 재사용됐다 — 남의 프로세스다
  tell "     $(( LOGIN_WAIT_TIMEOUT / 60 ))분 동안 승인이 오지 않아 이 기다림을 끝냅니다."
  kill -INT "$pid" 2>/dev/null
  sleep 3
  now="$(ps -o lstart= -p "$pid" 2>/dev/null)"
  if [ -n "$now" ] && [ "$now" = "$born" ]; then
    kill -TERM "$pid" 2>/dev/null
    tell "     (승인 창이 바로 닫히지 않아 한 번 더 끝냈습니다)"
  fi
}

login_waiter() {
  # $1 = 표식 파일(있는 동안만 돈다) · $2 = 승인 프로세스의 번호·시작시각을 적어 둔 파일
  local mark="$1" pidfile="$2" waited=0 sleep_pid=""
  # 🔴내가 끝날 때 **내 자식(sleep)도 데려간다**(검토 지적 채택 2026-09-11).
  #   앞 판은 본문이 `kill $LOGIN_WATCHER` 로 나만 죽였고, 그때 돌던 `sleep 60` 이 **고아로 남았다** —
  #   성공할 때마다 하나씩. ★자기가 만든 것을 자기가 치우지 않으면 아무도 안 치운다.
  trap 'kill "$sleep_pid" 2>/dev/null; exit 0' TERM INT
  while [ -e "$mark" ]; do
    # 기다림을 **배경 자식**으로 둬야 위 trap 이 그것을 붙잡을 수 있다(앞에서 자면 못 데려간다).
    sleep "$LOGIN_SAY_INTERVAL" & sleep_pid=$!
    wait "$sleep_pid" 2>/dev/null
    sleep_pid=""
    [ -e "$mark" ] || return 0
    waited=$(( waited + LOGIN_SAY_INTERVAL ))
    if [ "$waited" -ge "$LOGIN_WAIT_TIMEOUT" ]; then
      login_end_wait "$pidfile"
      return 0
    fi
    tell "     브라우저의 승인 화면에서 「코드」를 복사해 이 창에 붙여넣고 Enter 를 눌러 주십시오."
    tell "     (기다린 지 $(( waited / 60 ))분 · 창을 닫거나 Ctrl-C 를 누르시면 다시 하는 법을 안내합니다)"
  done
}

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

# ── 반복 막힘 단계별 안내 (2026-09-12 · v0.3.15) ─────────────────
# 같은 컴퓨터에서 같은 진단 코드로 끝난 횟수를 센다 — 2회째 = 다른 방법 · 3회째부터 = 담당자와 직접.
#   문구 정본 = tests/help-escalation.tsv(글자 그대로 · checks.sh 가 잰다).
# ⚠상태 파일은 고정 모양 JSON — 두 설치기가 같은 모양으로 쓰고 줄 단위 정규식으로 읽는다(깨끗한 맥에 jq·python 이 없다).
# ⚠끝맺음 트랩이 자리 만들기보다 먼저 매달리므로, 이른 끝(J-HOME-01 등)에서도 여기 값·함수가 정의돼 있어야 한다.
HELP_CONTACT_PHONE="010-7745-5885"   # 담당자 번호 — 글자로는 이 한 곳뿐(나머지는 이 변수)
HELP_ATTEMPTS_FILE="$JARVIS_HOME/help-attempts.json"
HELP_RE_CODE='^"(J-[A-Z]+-[0-9]{2})":\{"count":([0-9]{1,4}),"first":"([^"]*)","last":"([^"]*)","step":"([0-9]{1,2})"\},?$'
HELP_RE_REPORT='^"last_report":\{"id":"([A-Z2-9]{8})","at":"([^"]*)","code":"(J-[A-Z]+-[0-9]{2})"\}$'
HELP_STAGE=1          # 이 코드로 끝난 횟수(세지 않은 실행 = 1)
HELP_FIRST=""         # 첫 기록 시각(세지 않은 실행 = 빈칸 · 보고서 「같은 진단 코드」 줄의 조건)
HELP_PREV_REPORT=""   # 「ID (시각 · 같은 코드)」·「ID (시각 · 다른 코드 코드명)」 또는 빈칸
HELP_STAGE3_SHOWN=0
HELP_SENT_OK=0
HA_CODES=""           # 읽은 코드 줄들(끝 쉼표 뗌)
HA_REPORT=""          # 읽은 보고 줄(없으면 빈칸)

help_way_lines() {   # help_way_lines <코드> — 두 번째 방법 줄들(정본 way · 없는 코드 = 아무것도 안 찍는다)
  case "$1" in
    # 윈도우에서만 나는 코드(tests/help-rules.tsv 7번째 칸 = win)는 두지 않는다 — 맥에서는 찍힐 일이 없다.
    # 백신: 끄라고 하지 않고 우리가 예외를 등록하지도 않는다 — 사람이 직접 예외에 넣고 되돌리는 법까지 말한다.
    J-AV-02)    printf '%s\n' '백신의 보호 기록(격리함)에 cys 설치 파일이 있으면 [복원]을 골라 주십시오.' \
                  '안 되면 install-jarvis 폴더를 백신의 「예외(허용)」에 추가하신 뒤' \
                  '다시 실행해 주십시오. 설치 뒤 예외에서 지우시면 원래대로입니다.' ;;
    J-NET-01)   printf '%s\n' '휴대폰 핫스팟 같은 다른 인터넷에 연결하신 뒤 다시 실행해 주십시오.' ;;
    J-NET-02)   printf '%s\n' '10분쯤 뒤에 다시 실행해 주십시오.' '휴대폰 핫스팟 같은 다른 인터넷으로 바꿔 보셔도 됩니다.' ;;
    J-NET-03)   printf '%s\n' '회사·학교 망은 바깥 서버를 막아 둔 경우가 있습니다.' '휴대폰 핫스팟 같은 다른 인터넷으로 연결하신 뒤 다시 실행해 주십시오.' ;;
    J-PATH-01)  printf '%s\n' '컴퓨터를 한 번 다시 시작하신 뒤 새 창에서 다시 실행해 주십시오.' ;;
    J-LOGIN-01) printf '%s\n' '브라우저가 뜨지 않았거나 다른 브라우저에 로그인돼 있으면,' \
                  '설치 창에 보이는 https:// 로 시작하는 로그인 주소를 복사해' '로그인된 브라우저 주소창에 붙여넣어 주십시오.' ;;
    J-HOME-01)  printf '%s\n' '창을 닫고 새 창을 여신 뒤(남은 설정이 따라오지 않습니다)' '다시 실행해 주십시오.' ;;
    J-PERM-01)  printf '%s\n' '컴퓨터를 한 번 다시 시작하신 뒤 다시 실행해 주십시오.' '저장 공간이 3GB 이상 남았는지도 함께 봐 주십시오.' ;;
    J-DISK-01)  printf '%s\n' '휴지통을 비우시고, 설정의 저장 공간 화면에서 큰 파일을' '정리하신 뒤 다시 실행해 주십시오.' ;;
    J-VER-01)   printf '%s\n' '컴퓨터를 한 번 다시 시작하신 뒤 새 창에서 다시 실행해 주십시오.' ;;
    J-UNK-00)   printf '%s\n' '컴퓨터를 한 번 다시 시작하신 뒤 다시 실행해 주십시오.' ;;
    J-DL-03)    printf '%s\n' '컴퓨터를 한 번 다시 시작하신 뒤 새 창에서 다시 실행해 주십시오.' ;;
    J-DL-04)    printf '%s\n' '휴대폰 핫스팟 같은 다른 인터넷으로 연결하신 뒤 다시 실행해 주십시오.' ;;
  esac
}
help_is_direct() {   # 다른 방법이 없는 코드 — 2회째부터 곧바로 담당자 안내(정본 direct)
  case "$1" in J-DL-05) return 0 ;; esac
  return 1
}

help_attempts_read() {   # → HA_CODES · HA_REPORT · 없으면 빈 상태 · 못 읽거나 첫 줄이 틀리면 빈 상태 + 기록 한 줄
  local head="" line
  HA_CODES=""; HA_REPORT=""
  [ -e "$HELP_ATTEMPTS_FILE" ] || return 0
  { IFS= read -r head; } 2>/dev/null < "$HELP_ATTEMPTS_FILE"
  if [ "${head%$'\r'}" != '{"v":1,' ]; then
    log "help attempts: unreadable - reset"
    return 0
  fi
  while IFS= read -r line || [ -n "$line" ]; do
    line="${line%$'\r'}"
    if [[ "$line" =~ $HELP_RE_CODE ]]; then
      HA_CODES="$HA_CODES${line%,}
"
    elif [[ "$line" =~ $HELP_RE_REPORT ]]; then
      HA_REPORT="$line"
    fi
  done 2>/dev/null < "$HELP_ATTEMPTS_FILE"
}

help_attempts_write() {   # HA_CODES · HA_REPORT → 고정 모양(코드 이름순) · 임시 파일에 쓴 뒤 이름 바꾸기 · 실패 = 기록 한 줄
  local tmp="$HELP_ATTEMPTS_FILE.tmp" sorted
  sorted="$(printf '%s' "$HA_CODES" | LC_ALL=C sort | sed '/^$/d; $!s/$/,/')"
  if [ ! -d "$HELP_ATTEMPTS_FILE" ] && {
       printf '%s\n' '{"v":1,' '"codes":{'
       if [ -n "$sorted" ]; then printf '%s\n' "$sorted"; fi
       if [ -n "$HA_REPORT" ]; then printf '%s\n' '},' "$HA_REPORT"; else printf '%s\n' '}'; fi
       printf '%s\n' '}'
     } 2>/dev/null > "$tmp" && mv -f "$tmp" "$HELP_ATTEMPTS_FILE" 2>/dev/null; then
    return 0
  fi
  rm -f "$tmp" 2>/dev/null
  log "help attempts: write failed"
  return 1
}

# 끝맺음이 한 번 부른다 → HELP_STAGE · HELP_FIRST · HELP_PREV_REPORT
help_attempts_update() {
  local n now line code cnt=0 first="" keep=""
  HELP_STAGE=1; HELP_FIRST=""; HELP_PREV_REPORT=""
  [ "$MODE" = "full" ] || return 0     # 미리보기·감지만 = 세지 않는다(읽지도 쓰지도 않는다)
  # 작업 폴더가 없거나 우리 표식이 없는 자리(J-HOME-01 로 거절한 남의 폴더)에는 쓰지 않는다 —
  #   거절한 자리에 파일을 보태면 그 폴더가 「우리 구판 지문」에서 벗어나 다음 이관 제안도 막힌다.
  owner_mark_ok || return 0
  if [ -z "$J_CODE" ]; then
    # 성공 끝(깨우기 도달) = 코드 줄 전부 지운다 · 이전 보고는 남긴다
    { [ "${REACHED_WAKE:-0}" = "1" ] && [ -f "$HELP_ATTEMPTS_FILE" ]; } || return 0
    help_attempts_read
    HA_CODES=""
    help_attempts_write && log "help attempts: cleared"
    return 0
  fi
  help_attempts_read
  # 현재 단계 = 이 실행이 기록 파일에 마지막으로 찍은 [n/10] 의 n(remote_help_report 와 같은 방법 · 없으면 0)
  n="$(grep -oE '\[[0-9]{1,2}/[0-9]{1,2}\]' "$LOG_FILE" 2>/dev/null | tail -1 | tr -d '[]')"
  n="${n%%/*}"
  [ -n "$n" ] || n=0
  n=$((10#$n))
  while IFS= read -r line; do
    [[ "$line" =~ $HELP_RE_CODE ]] || continue
    code="${BASH_REMATCH[1]}"
    if [ "$code" = "$J_CODE" ]; then
      cnt=$((10#${BASH_REMATCH[2]})); first="${BASH_REMATCH[3]}"
    elif [ $((10#${BASH_REMATCH[5]})) -ge "$n" ]; then
      keep="$keep$line
"
    fi   # 그 밖 = 기록된 단계를 이번 실행이 지나갔다 → 지운다(D4)
  done <<EOF_HELP_CODES
$HA_CODES
EOF_HELP_CODES
  now="$(date '+%Y-%m-%dT%H:%M:%S%z')"
  [ "$cnt" -lt 9999 ] && cnt=$((cnt + 1))
  [ -n "$first" ] || first="$now"
  line="\"$J_CODE\":{\"count\":$cnt,\"first\":\"$first\",\"last\":\"$now\",\"step\":\"$n\"}"
  [[ "$line" =~ $HELP_RE_CODE ]] || return 0     # 읽을 수 없는 모양은 쓰지 않는다(코드 모양이 다르면 세지 않는다)
  if [[ "$HA_REPORT" =~ $HELP_RE_REPORT ]]; then
    if [ "${BASH_REMATCH[3]}" = "$J_CODE" ]; then
      HELP_PREV_REPORT="${BASH_REMATCH[1]} (${BASH_REMATCH[2]} · 같은 코드)"
    else
      HELP_PREV_REPORT="${BASH_REMATCH[1]} (${BASH_REMATCH[2]} · 다른 코드 ${BASH_REMATCH[3]})"
    fi
  fi
  HA_CODES="$keep$line
"
  help_attempts_write
  HELP_STAGE=$cnt
  HELP_FIRST="$first"
  log "help attempts: $J_CODE count=$cnt step=$n"
}

# 끝맺음 「진단 코드:」 줄 바로 다음 — 1회째 = 아무것도 안 찍는다
help_escalation_print() {
  local way line i=0
  [ -n "$J_CODE" ] || return 0
  if [ "$HELP_STAGE" -ge 3 ] || { [ "$HELP_STAGE" -ge 2 ] && help_is_direct "$J_CODE"; }; then
    printf '%s\n' "" \
      "  계속 같은 자리에서 막히셔서 많이 불편하셨지요." \
      "  개발자와 직접 이야기해 보시면 어떨까요?" \
      "  담당자 전화 $HELP_CONTACT_PHONE (문자나 전화 · 편하신 시간에)" \
      "  진단 코드 $J_CODE 만 말씀해 주시면 됩니다."
    HELP_STAGE3_SHOWN=1
    return 0
  fi
  [ "$HELP_STAGE" -eq 2 ] || return 0
  way="$(help_way_lines "$J_CODE")"
  [ -n "$way" ] || return 0     # 두 번째 방법이 없는 코드는 1회째처럼 둔다
  printf '%s\n' "" "  같은 자리에서 다시 막히셨네요. 난감하시겠어요. 이렇게 한 번 해 보세요."
  while IFS= read -r line; do
    if [ "$i" -eq 0 ]; then printf '%s\n' "   - $line"; else printf '%s\n' "     $line"; fi
    i=$((i + 1))
  done <<EOF_HELP_WAY
$way
EOF_HELP_WAY
  printf '%s\n' "  그래도 같으면 다음에는 담당자 연락처를 안내해 드리겠습니다."
}

# 보고 전송 성공 직후 — 같은 실행에서 여러 번 보내도 매번 갱신한다
help_last_report_save() {   # help_last_report_save <보고 번호>
  local line
  [ "$MODE" = "full" ] || return 0
  owner_mark_ok || return 0
  line="\"last_report\":{\"id\":\"$1\",\"at\":\"$(date '+%Y-%m-%dT%H:%M:%S%z')\",\"code\":\"$J_CODE\"}"
  if ! [[ "$line" =~ $HELP_RE_REPORT ]]; then
    log "help attempts: report not saved"
    return 0
  fi
  help_attempts_read
  HA_REPORT="$line"
  help_attempts_write
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
  # 반복 막힘 셈 — 끝맺음 이 한 자리에서 한 번만
  help_attempts_update
  if [ -n "$J_CODE" ]; then
    printf '%s\n' "  진단 코드: $J_CODE  (${HELP_CODE_URL}${J_CODE})"
    help_escalation_print
    # 🔴화면과 보고서가 갈리지 않게 한다(검토 지적 채택 2026-09-09) — 단계가 코드를 남기고 그 자리에서
    #   끝나면 보고서는 그 전에 쓰인 것이라 **옛 코드나 빈칸**이 남는다. 그 둘이 다르면 사람이 읽어 주는 코드와
    #   우리가 받는 파일이 어긋나 소통이 꼬인다. ⇒ 끝나기 직전에 보고서의 그 줄만 지금 값으로 맞춘다.
    #   반복 막힘 두 줄(같은 진단 코드 · 이전 보고)도 같은 방법으로 맞춘다(원격 해결 전송보다 앞).
    if [ -f "$REPORT_FILE" ]; then
      grep -v -e '^- 진단 코드: ' -e '^- 같은 진단 코드: ' -e '^- 이전 보고: ' "$REPORT_FILE" > "$REPORT_FILE.tmp" 2>/dev/null &&
        {
          printf '%s\n' "- 진단 코드: **$J_CODE** (${HELP_CODE_URL}${J_CODE})"
          if [ -n "$HELP_FIRST" ]; then printf '%s\n' "- 같은 진단 코드: ${HELP_STAGE}회째 (이 컴퓨터 · 첫 기록 $HELP_FIRST)"; fi
          if [ -n "$HELP_PREV_REPORT" ]; then printf '%s\n' "- 이전 보고: $HELP_PREV_REPORT"; fi
        } >> "$REPORT_FILE.tmp" &&
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
  # 원격 해결 — 막혀 멈춘 끝이면 여기서 진단을 보내고 창을 연 채 운영팀을 기다린다([1/10] 고지를 보여 드린 실행만).
  [ "${NOTICE_SHOWN:-0}" = "1" ] && remote_help
  # 3회째 안내의 마지막 줄 — 「전달됐다」는 전송이 성공한 순간에만 찍었다(D3). 그 밖(미동의·실패·안 돎)은 이 줄.
  if [ "$HELP_STAGE3_SHOWN" = "1" ] && [ "$HELP_SENT_OK" != "1" ]; then
    printf '%s\n' "  전화하실 때 이 화면을 사진으로 보내 주시면 더 빠릅니다."
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
# ── 🔴🔴작업 폴더는 **이름을 못 박고, 우리가 만든 자리에만 표식을 놓는다** (3차 검토 N3 · 관리자 결정) ──
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
  echo "     진단 코드: J-HOME-01 — 이 도구가 만들고 지우는 폴더의 이름은 「${JARVIS_HOME_BASENAME}」 하나입니다" >&2
  J_CODE="J-HOME-01"
  NEXT_STEP="JARVIS_HOME 을 지정하지 않으신 채로 다시 실행하시면 기본 자리($HOME/$JARVIS_HOME_BASENAME)를 씁니다. 그 자리를 꼭 쓰시려면 그 폴더를 지우거나 옮기신 뒤 다시 실행해 주십시오 — 설치 도우미는 자기가 새로 만든 폴더만 씁니다."
  SHOW_RERUN=1
  exit 3
}
# ⑴이름 관문 — **만들기 전에** 본다.
if [ "$(basename "${JARVIS_HOME%/}")" != "$JARVIS_HOME_BASENAME" ]; then
  refuse_jarvis_home "폴더 이름이 「${JARVIS_HOME_BASENAME}」 이 아닙니다"
fi
# ⑵채택 관문 — 이미 있는 자리는 **우리 표식이 있을 때만** 쓴다.
# 🔴🔴**「비어 있으면 채택」을 걷어냈다**(4차 검토 BLOCK N3 확정 2026-09-10). 두 가지가 틀렸다:
#   ⑴결정은 「설치기가 **자기가 만든** 폴더에만 표식을 놓는다」였는데, 코드는 **남이 만들어 둔 빈 폴더**도
#     채택해 표식을 써 줬다 ⇒ 그 자리는 그때부터 「우리 것」이 되어 다음 지우기가 통째로 지운다.
#   ⑵더 나쁜 것은 **비었는지 세는 방법**이었다: `ls -A` 가 **권한 오류**를 내도 빈 목록으로 읽었다.
#     「목록은 못 읽지만 파일은 만들 수 있는」 폴더 — 남의 파일이 가득한 그 자리에 표식을 써 준다.
#   ★「비었다」와 「못 세었다」를 한 칸에 담은 자리가 또 있었다. 이 작업에서만 세 번째다.
#   ⇒ **세지 않는다.** 셀 필요가 없으면 틀릴 자리도 없다 — 표식이 없는 기존 폴더는 내용과 무관하게 거부한다.
#   ⚠참가자 영향: 앞선 실행이 표식을 못 쓰고 죽어 **빈 폴더만 남은** 드문 경우에 한 번 막힌다.
#     그때 화면이 「그 폴더를 지우고 다시 실행」이라고 정확히 말한다 — 손 한 번이 남의 폴더를 지키는 값이다.
# ── 🔴구판 폴더 이관 (v0.3.10 · 실제 노트북에서 겪은 일 2026-09-10) ───────────
#   실제 노트북에서 구판(v0.3.7)이 만든 `~/install-jarvis` 에는 **표식이 없었다**(표식은 그 뒤에 생겼다).
#   새 판은 규칙대로 거부했고, 그래서 **사람이 손으로 폴더를 지워야** 설치가 이어졌다.
#   ⇒ **우리 구판 지문**(설치기가 만드는 이름만 있고 그 밖의 것이 0)일 때에 한해, 무엇이 들었는지
#     보여 드리고 **사람이 「지웁니다」라고 한 번 쳐야** 지운다. ⛔자동 삭제는 하지 않는다.
#   ★두 가지를 함께 지킨다: ⑴**빈 폴더는 지문이 아니다**(5차 검토 결정 유지 — 남이 만들어 둔 빈 자리를
#     채택하지 않는다) ⑵**못 세면 거부한다** — 열거 실패를 「우리 것뿐」으로 읽지 않는다(이 저장소가
#     세 번 밟은 함정이다: 「비었다」와 「못 세었다」를 한 칸에 담지 마라).
JARVIS_OLD_NAMES="bootstrap.log env-report.md install-directive.md trust-seed.tsv wake.sh wake.ps1 dl backup .jarvis-owned"
JARVIS_OLD_SIGN="install-directive.md env-report.md bootstrap.log"   # 이 중 하나는 있어야 「우리 구판」이다
list_home_entries() {  # 폴더 안 이름을 한 줄씩. **못 세면 rc 1** — 빈 목록과 구분한다.
  local d="$1" out
  [ -d "$d" ] && [ -r "$d" ] && [ -x "$d" ] || return 1
  out="$(find "$d" -mindepth 1 -maxdepth 1 2>/dev/null)" || return 1
  printf '%s\n' "$out"
  return 0
}
old_layout_matches() {  # rc 0 = 우리 구판 지문이다
  local entries p b known=1 sign=0
  entries="$(list_home_entries "$JARVIS_HOME")" || return 1
  while IFS= read -r p; do
    [ -n "$p" ] || continue
    b="$(basename "$p")"
    # 🔴🔴**이음줄이 섞여 있으면 우리 구판이 아니다**(자기 교차 검토 2026-09-11).
    #   우리가 만드는 것 중 이음줄은 하나도 없다. 그런데 이름만 맞는 이음줄(`dl` 이 남의 폴더를
    #   가리키는 것)이 섞이면, 지우는 순간 **가리키던 자리 안엣것**까지 함께 사라질 수 있다
    #   (윈도우 5.1 의 `Remove-Item -Recurse` 가 실제로 그렇게 판 적이 있다 — 지우개가 그 때문에 고쳐졌다).
    #   ⇒ 이름이 맞아도 이음줄이면 **지문 아님**으로 본다. 잃는 것은 없다(우리는 그런 것을 안 만든다).
    [ -L "$p" ] && known=0
    case " $JARVIS_OLD_NAMES " in *" $b "*) ;; *) known=0 ;; esac
    case " $JARVIS_OLD_SIGN " in *" $b "*) sign=1 ;; esac
  done <<ENTRIES
$entries
ENTRIES
  [ "$known" = "1" ] && [ "$sign" = "1" ]
}
offer_old_home_cleanup() {  # rc 0 = 사람이 허락해 지웠다 · 그 밖 = 지우지 않았다
  local answer p _full
  [ "$MODE" = "full" ] || return 1     # 보기만 하는 판(detect·dry)에서는 바깥을 바꾸지 않는다
  # ⚠사람이 있는지는 **열어 봐서** 안다 — `[ -r /dev/tty ]` 는 사람이 없어도 참이 될 수 있다
  #   (실측 2026-09-11: 러너·파이프에서 -r 은 참인데 읽으면 「Device not configured」).
  #   물어보지도 못할 자리에서 물음만 찍고 물러나면, 화면은 사람에게 고르라고 해 놓고 답을 안 받는다.
  { : < /dev/tty; } 2>/dev/null || return 1
  old_layout_matches || return 1
  # ★사람에게는 **실제 자리**를 보여 준다 — `JARVIS_HOME` 이 상대 경로로 들어오면 화면의 글자만
  #   보고는 어디를 지우는지 알 수 없다(지우겠다고 답할 사람이 무엇을 지우는지 몰라선 안 된다).
  _full="$(cd "$JARVIS_HOME" 2>/dev/null && pwd -P)" || _full=""
  [ -n "$_full" ] || _full="$JARVIS_HOME"
  echo ""
  echo "그 자리에 예전 판이 만든 작업 폴더가 있습니다: $(redact "$_full")"
  echo "     안에 있는 것(이 도구가 만드는 이름뿐입니다):"
  list_home_entries "$JARVIS_HOME" | while IFS= read -r p; do
    [ -n "$p" ] && echo "       · $(basename "$p")"
  done
  echo "     이 폴더를 지우고 새로 만들면 그대로 이어서 설치합니다. 되돌릴 수 없습니다."
  printf '계속하려면 「지웁니다」라고 쳐 주십시오(그만두시려면 그냥 Enter): '
  read -r answer < /dev/tty || answer=""
  if [ "$answer" != "지웁니다" ]; then
    echo "     그만둡니다 — 아무것도 지우지 않았습니다."
    return 1
  fi
  rm -rf "$JARVIS_HOME" 2>/dev/null
  if [ -e "$JARVIS_HOME" ]; then
    echo "     그 폴더를 지우지 못했습니다."
    return 1
  fi
  echo "     예전 작업 폴더를 지웠습니다."
  return 0
}
fail_make_home() {
  echo "자리를 만들지 못했습니다: $JARVIS_HOME" >&2
  echo "     진단 코드: J-PERM-01 — 파일이나 폴더를 쓸 권한이 없습니다(공간 부족·백신 차단도 같은 모양입니다)" >&2
  J_CODE="J-PERM-01"
  NEXT_STEP="회사·학교에서 관리하는 컴퓨터면 담당자에게 문의해 주십시오. 개인 컴퓨터면 저장 공간과 백신 알림을 확인해 주십시오."
  exit 3
}
make_home_now() {  # 마지막 마디만 원자적으로 만든다(부모는 미리 만들어 둔다)
  local parent
  parent="$(dirname "${JARVIS_HOME%/}")"
  if [ ! -d "$parent" ] && ! mkdir -p "$parent" 2>/dev/null; then
    fail_make_home
  fi
  mkdir "$JARVIS_HOME" 2>/dev/null
}
adopt_existing_home() {  # 이미 있는 자리를 받아들일지 판정한다 — 두 갈래가 같은 잣대를 쓰게 한다
  # 🔴🔴**그 자리 자신이 이음줄이면 여기서 멈춘다**(교차 검토 1차 NEW-1 · 2026-09-11).
  #   `[ -d ]` 는 이음줄을 **따라가서** 참이 된다 ⇒ 남의 폴더를 가리키는 이음줄에 우리 이름을 붙여 두면
  #   그 안엣것이 우리 지문처럼 보이고, 지우는 순간 **가리키던 자리**가 비워진다.
  #   ★우리는 작업 폴더를 이음줄로 만들지 않는다 — 그러니 이음줄은 언제나 「우리 것이 아니다」.
  #   ⚠**정직하게 적는다**: 맥에서는 이 줄이 없어도 지금은 안 뚫렸다(실측 2026-09-11) — `find` 가
  #     **인자로 받은 이음줄을 따라가지 않아** 열거가 비고, 「빈 폴더는 지문이 아니다」에 걸려 거부된다.
  #     그러나 그것은 **우연히 안전한 것**이다(열거 도구의 기본값 하나에 기대고 있다).
  #     ⇒ 말로 못박는다. 윈도우는 다르다 — 열거가 junction 을 따라가므로 그쪽은 실제 구멍이었다.
  if [ -L "$JARVIS_HOME" ]; then
    refuse_jarvis_home "그 자리는 다른 곳을 가리키는 이음줄입니다(우리가 만드는 작업 폴더는 이음줄이 아닙니다)"
  fi
  if [ ! -d "$JARVIS_HOME" ]; then
    refuse_jarvis_home "그 자리에 폴더가 아닌 것이 이미 있습니다"
  fi
  owner_mark_ok && return 0
  if offer_old_home_cleanup; then
    make_home_now || fail_make_home
    JARVIS_HOME_CREATED=1
    return 0
  fi
  refuse_jarvis_home "그 폴더는 이미 있는데 우리 표식이 없습니다(우리가 만든 자리가 아닙니다 — 지울 때 통째로 지우는 자리이므로 채택하지 않습니다)"
}
JARVIS_HOME_CREATED=0
if [ -e "$JARVIS_HOME" ]; then
  adopt_existing_home
else
  # 🔴🔴**보고 나서 만드는 사이에 남이 그 자리를 만들 수 있다**(2026-09-11 수리).
  #   앞 판은 「없다」를 본 뒤 `mkdir -p` 로 만들고 곧바로 「우리가 만들었다」고 적었다. 그런데
  #   `mkdir -p` 는 **이미 있는 폴더에도 성공한다** ⇒ 그 사이에 생긴 남의 폴더에 우리가 표식을
  #   써 주고, 제거기는 그 표식을 소유 증거로 읽어 **통째로 지운다.**
  #   ⇒ 마지막 마디는 `-p` 없이 만든다. **`mkdir` 은 이미 있으면 실패한다** — 그 실패가 곧
  #     「우리가 만든 자리가 아니다」라는 신호다(만들기와 알리기가 한 동작이라 사이가 없다).
  #   ★검사와 만들기를 따로 두면 그 사이는 반드시 남는다. **만드는 행위 자체에게 물어야** 사라진다.
  if make_home_now; then
    JARVIS_HOME_CREATED=1
  elif [ -e "$JARVIS_HOME" ] || [ -L "$JARVIS_HOME" ]; then
    # 경합 — 우리가 만든 자리가 아니므로 기존 폴더와 같은 잣대로 잰다.
    # ⚠`-L` 도 함께 묻는다: **끊어진 이음줄**은 `-e` 가 거짓인데 `mkdir` 은 「이미 있다」로 실패한다.
    #   그 자리를 「권한이 없다」로 말하면 사람이 엉뚱한 것을 고치러 간다.
    adopt_existing_home
  else
    fail_make_home
  fi
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

  #   🔴교차 검토 지적 채택(2026-09-06) — 앞 판은 `~/.zprofile` **하나만** 보고 판단했다.
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
  #   왜 이 줄이 생겼나(2026-09-08 운영자 윈 노트북): 「지우고 다시 깔기」에서 지우개는 로그인을
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
    say "[3/10] (dry-run) 폴링하지 않았습니다. 간격 ${LOGIN_POLL_INTERVAL}초 · 상한 ${LOGIN_POLL_TIMEOUT}초 · 승인 대기 상한 ${LOGIN_WAIT_TIMEOUT}초(${LOGIN_SAY_INTERVAL}초마다 안내)."
    return 0
  fi
  if ! claude_has_auth_cmd; then
    say "[3/10] 이 판본의 클로드는 로그인 확인 명령을 모릅니다. 판올림이 먼저 필요합니다."
    say "     아래 「다시 하시는 법」대로 다시 실행하시면 판올림부터 이어서 갑니다."; SHOW_RERUN=1
    return 6
  fi
  human "벤더" "로그인 승인 클릭 — 클로드 회사 화면에서만 할 수 있다(우리가 대신 못 누른다)"
  say "[3/10] 지금 로그인 화면을 엽니다. 브라우저가 뜨면 승인을 눌러 주십시오."
  say "     승인 화면이 뜨면 「코드」를 복사해 이 창에 붙여넣고 Enter 를 눌러 주십시오."
  say "     기다리는 동안 $((LOGIN_SAY_INTERVAL))초마다 한 줄씩 알려 드리고, $((LOGIN_WAIT_TIMEOUT / 60))분이 지나면 이 기다림을 끝냅니다."
  LOGIN_WAIT_MARK="$JARVIS_HOME/.login-wait"
  LOGIN_PID_FILE="$JARVIS_HOME/.login-pid"
  rm -f "$LOGIN_PID_FILE"
  : > "$LOGIN_WAIT_MARK"
  login_waiter "$LOGIN_WAIT_MARK" "$LOGIN_PID_FILE" &
  LOGIN_WATCHER=$!
  # ★승인은 **앞에 그대로** 두되, 자기 번호와 시작 시각을 적고 나서 벤더 명령으로 **바뀐다**(exec).
  #   그래야 상한이 `pgrep` 로 다시 찾지 않고 **그 프로세스 하나만** 겨눌 수 있다.
  #   (이 셸은 3.2 라 `BASHPID` 가 없다 — 자식이 스스로 적는 것이 유일한 길이다.)
  /bin/sh -c 'echo $$ > "$0"; ps -o lstart= -p $$ >> "$0"; exec claude auth login' "$LOGIN_PID_FILE" || true
  # 끝났으면 **표적을 먼저** 치운다 — 표식보다 먼저 지워야 감시자가 겨눌 것이 없다.
  rm -f "$LOGIN_PID_FILE"
  rm -f "$LOGIN_WAIT_MARK"
  kill "$LOGIN_WATCHER" 2>/dev/null
  wait "$LOGIN_WATCHER" 2>/dev/null || true
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
# 🔴🔴**실패를 「사람 손 한 번」으로 바꿔 적고 성공을 돌려주지 않는다**(3차 검토 N4 확정 2026-09-10).
#   앞 판은 `seed_claude_prefs` 가 rc 1 로 돌아와도 `human` 한 줄만 찍고 **항상 0** 을 돌려줬다.
#   ⇒ 신뢰 기록이 실패한 판에서도 [4/10] 은 「갖춰 두었습니다」로 넘어갔다.
#   ★`human` 은 **사람에게 할 일이 생겼다는 표시**지 실패의 처리 방법이 아니다. 둘을 섞으면
#     단계는 늘 성공하고, 실패는 화면 한 줄로만 흘러간다.
# ⚠**실패의 종류를 가른다.** 사전 설정을 못 건 것(도구 부재 등)은 예전처럼 「사람 손 한 번」이면
#   끝나는 일이라 계속 간다. 그러나 **기록 실패는 다르다** — 그때는 설정을 도로 뺐고, 그 사실을
#   단계가 삼키면 화면은 「갖춰 두었습니다」라고 말한다. 그 한 줄만 단계 실패로 올린다.
TRUST_JOURNAL_FAILED=0
# 🔴🔴**「키가 없다」와 「확인하지 못했다」를 한 칸에 담지 않는다**(2026-09-11 수리).
#   앞 판은 되돌린 뒤 `plutil -extract` 가 실패하면 **까닭을 묻지 않고** 「도로 뺐습니다」라고 말했다.
#   그런데 그 실패는 둘이다 — ⑴그 칸이 정말 없다 ⑵설정 파일을 못 읽거나 못 알아본다.
#   디스크가 꽉 찬 판에서는 기록도, 되쓰기도, 되읽기도 **함께** 실패한다 ⇒ 키는 남았는데 화면은
#   되돌렸다고 말하고, 다음 실행은 그 키를 **참가자의 것**으로 읽어 영영 건너뛴다.
#   ⇒ 파일이 통째로 성한지를 따로 묻는다(`plutil -lint`). 성한데 칸이 없으면 「없다」,
#     파일 자체를 못 알아보면 「확인 못 했다」다. ★확인 못 한 것을 했다고 말하지 않는다.
TRUST_ROLLBACK_STATE=""   # verified(도로 뺐다) · kept(키가 남았다) · unknown(확인 못 했다)
trust_set_rollback_state() {  # 설정 파일이 여럿이다 — **나쁜 쪽이 남는다**(뒤 파일이 앞 실패를 덮지 않게)
  case "$TRUST_ROLLBACK_STATE" in
    kept|unknown) [ "$1" = "verified" ] && return 0 ;;
  esac
  TRUST_ROLLBACK_STATE="$1"
}
trust_key_state() {  # trust_key_state <설정파일> <키경로> → present|absent|unknown
  local cfg="$1" keypath="$2"
  if plutil -extract "$keypath" raw -o - "$cfg" >/dev/null 2>&1; then
    printf 'present\n'; return 0
  fi
  # ⚠파일이 성한지를 묻는 계기를 **틀리지 마라**: `plutil -lint` 는 JSON 을 안 받는다
  #   (실측 2026-09-11: 성한 `.claude.json` 에도 `Unexpected character {` 를 내고 rc 1).
  #   ★그것으로 갈랐다면 「없는 키」가 전부 「확인 못 함」이 되어, 고치려던 자리에서 또 한 번
  #     한 칸에 두 사건을 담았을 것이다. 읽어서 다시 쓰는 변환을 **버리는 자리로** 시켜 성함만 묻는다
  #     (`-o /dev/null` — 원본은 건드리지 않는다. 실측: 내용·해시 그대로).
  if plutil -convert json -o /dev/null "$cfg" >/dev/null 2>&1; then
    printf 'absent\n'
  else
    printf 'unknown\n'
  fi
  return 0
}
trust_rollback_words() {  # 단계 한 줄이 안에서 일어난 일을 그대로 말하게 한다
  case "$TRUST_ROLLBACK_STATE" in
    verified) printf '그 설정은 도로 뺐고,' ;;
    kept)     printf '그 설정을 도로 빼지 못해 기록을 남겨 두었고(지울 때 되돌립니다),' ;;
    unknown)  printf '그 설정이 도로 빠졌는지 확인하지 못해 기록을 남겨 두었고(지울 때 되돌립니다),' ;;
    *)        printf '그 설정이 어떻게 됐는지 확인하지 못했고,' ;;
  esac
}
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
  # 🔴2026-09-10 수리(4차 검토) — 앞 판은 **자비스 작업 폴더에만** 신뢰를 심었다. 그런데 동료 좌석은
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
  # ⑵사용자 홈 — **참가자의 자리다.** 규칙이 다르다(1차 검토 REVISE ④ 확정 2026-09-10 · 윈도우판과 같다).
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
         _made_entry=0; _verify=""
         plutil -extract "projects.$HOME" json -o - "$cfg" >/dev/null 2>&1 || _made_entry=1
         if plutil -insert "projects.$HOME" -json '{"hasTrustDialogAccepted":true}' "$cfg" >/dev/null 2>&1 \
            || plutil -insert "projects.$HOME.hasTrustDialogAccepted" -bool true "$cfg" >/dev/null 2>&1; then
           # 🔴🔴**기록에 실패하면 설정 변경을 되돌린다**(3차 검토 N4 확정 2026-09-10).
           #   앞 판은 기록 실패를 「말하고 rc 1」로 끝냈다 — 그런데 **키는 이미 들어가 있었다.**
           #   ⇒ 제거기는 그 키를 「참가자의 것」으로 읽어 **영영 남긴다.** 우리가 남의 컴퓨터에
           #     되돌릴 길 없는 자국을 남기는 것이다.
           #   ★기록과 설정은 **함께 서거나 함께 물러난다** — 반쪽만 남으면 그것이 곧 자국이다.
           if ! printf '%s\t%s\n' "$cfg" "$HOME" >> "$TRUST_SEED_FILE" 2>/dev/null; then
             TRUST_JOURNAL_FAILED=1
             # 🔴🔴**되돌렸다고 말하기 전에 되돌아갔는지 본다**(4차 검토 BLOCK N4 확정 2026-09-10).
             #   앞 판은 `plutil -remove` 의 종료값을 **버리고** 곧바로 「도로 뺐습니다」라고 말했다.
             #   디스크가 꽉 차면 기록 쓰기와 설정 되쓰기가 **함께** 실패한다 ⇒ 키는 남고 기록은 없는데
             #   화면은 되돌렸다고 말한다. 다음 실행은 그 키를 **참가자의 것**으로 읽어 영영 건너뛴다.
             #   ★「했다」는 **다시 봐서 없을 때만** 참이다 — 이 파일이 로그인 쪽에서 이미 배운 규칙이다.
             if [ "$_made_entry" = "1" ]; then
               plutil -remove "projects.$HOME" "$cfg" >/dev/null 2>&1 || true
             else
               plutil -remove "projects.$HOME.hasTrustDialogAccepted" "$cfg" >/dev/null 2>&1 || true
             fi
             _verify="$(trust_key_state "$cfg" "projects.$HOME.hasTrustDialogAccepted")"
             if [ "$_verify" = "absent" ]; then
               trust_set_rollback_state verified
               say "     (홈 폴더 신뢰 기록을 남기지 못해 그 설정을 도로 뺐습니다 — 좌석이 폴더 신뢰를 한 번 물을 수 있습니다.)"
               log "trust seed record FAILED -> rollback verified: $(redact "$cfg") + $(redact "$HOME")"
               return 1
             fi
             # 여기부터는 **되돌렸다고 말하지 않는다**: present = 키가 남았다 · unknown = 확인하지 못했다.
             #   둘 다 「키는 남고 기록은 없는」 상태일 수 있으므로, 기록을 한 번 더 시도해 둘을 맞춘다
             #   (기록이 서면 지울 때 되돌아간다 — 없는 키를 되돌리는 것은 아무 일도 하지 않는 것이다).
             if [ "$_verify" = "present" ]; then trust_set_rollback_state kept; else trust_set_rollback_state unknown; fi
             if printf '%s\t%s\n' "$cfg" "$HOME" >> "$TRUST_SEED_FILE" 2>/dev/null; then
               if [ "$_verify" = "present" ]; then
                 say "     (설정을 도로 빼지 못해 기록을 남겨 두었습니다 — 지울 때 이 칸도 함께 되돌립니다.)"
               else
                 say "     (그 설정이 도로 빠졌는지 확인하지 못해 기록을 남겨 두었습니다 — 지울 때 이 칸도 함께 되돌립니다.)"
               fi
               log "trust seed rollback $_verify -> journal re-recorded: $(redact "$cfg") + $(redact "$HOME")"
               return 1
             fi
             # 둘 다 실패했다. 조용히 지나가지 않는다 — 사람이 손으로 되돌릴 수 있게 **어디의 무엇**인지 적는다.
             if [ "$_verify" = "present" ]; then
               say "     홈 폴더 신뢰 설정을 넣었는데 그 기록도, 되돌리기도 하지 못했습니다."
             else
               say "     홈 폴더 신뢰 설정을 넣었는데 그 기록도 남기지 못했고, 도로 빠졌는지도 확인하지 못했습니다."
             fi
             say "        지울 때 이 칸은 자동으로 되돌아가지 않습니다. 손으로 빼시려면:"
             say "        파일 $(redact "$cfg") 의 projects → $(redact "$HOME") → hasTrustDialogAccepted 줄"
             log "trust seed rollback $_verify and journal FAILED: $(redact "$cfg") + $(redact "$HOME")"
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
    # ★단계가 말하는 것과 안에서 일어난 것이 달라서는 안 된다(5차 검토 STILL OPEN N4).
    #   앞 판은 어느 경우든 「도로 뺐고」라고 단정했다 — 되돌리지 못했거나 확인하지 못한 판에서도 그랬다.
    say "[4/10] 홈 폴더 신뢰 기록을 남기지 못했습니다 — $(trust_rollback_words) 여기서 멈춥니다."
    say "     기록 없이 그 칸만 넣으면 지울 때 되돌릴 길이 없습니다(남의 컴퓨터에 자국이 남습니다)."
    J_CODE="J-PERM-01"
    NEXT_STEP="저장 공간과 백신 알림을 확인하신 뒤 다시 실행해 주십시오."
    SHOW_RERUN=1
    return 4
  fi
  say "[4/10] 자비스가 쓸 것을 갖춰 두었습니다."
  return 0
}


# 받을 자리가 **뭐라고 답하는지** 한 번 물어 본다(HTTP 코드 세 자리 · 못 물으면 `000`).
#   ★왜 있는가: 「그 파일이 자리에 없다」와 「연결이 끊겼다」는 **다른 일**인데 앞 판은 둘을 한 칸에
#   두었다 — 그래서 벤더가 옛 판본 dmg 를 내린 날부터 사람은 **없는 파일을 30분씩 두 번 기다린 뒤에야**
#   실패를 봤다(2026-09-11 라이브 실사고). 기다려서 생기는 파일이 아니다.
cys_http_code() {
  local c
  c="$(curl -sSI -L -o /dev/null -w '%{http_code}' --max-time 60 "$1" 2>/dev/null)"
  [ -n "$c" ] || c="000"
  printf '%s' "$c"
}

# 받은 파일의 지문. 맥에는 `shasum` 이 기본으로 있고, 없으면 `openssl` 로 잰다. 둘 다 없으면 빈 문자열 —
#   ★**못 쟀다는 것을 「맞다」로 바꾸지 않는다.** 부르는 쪽이 빈 문자열을 실패로 받는다.
cys_file_sha256() {
  local f="$1" out=""
  if command -v shasum >/dev/null 2>&1; then
    out="$(shasum -a 256 "$f" 2>/dev/null | awk '{print $1}')"
  fi
  if [ -z "$out" ] && command -v openssl >/dev/null 2>&1; then
    out="$(openssl dgst -sha256 "$f" 2>/dev/null | awk '{print $NF}')"
  fi
  printf '%s' "$out" | tr 'A-F' 'a-f'
}

# ── 하는 일 5 — cys 설치 파일 받기 ────────────────────────────────
# 완료 판정 = 파일이 있고 **크기와 지문이 둘 다** 맞는가. 크기가 다르면 받다 끊긴 것이고,
#   크기는 같은데 지문이 다르면 **다른 파일**이다(크기만 보던 앞 판은 그것을 그냥 지나갔다).
step_download_cys() {
  mkdir -p "$DL_DIR"
  local dst got try code have fresh
  dst="$DL_DIR/$CYS_MAC_FILE"
  if [ -f "$dst" ] && [ "$(wc -c < "$dst" | tr -d ' ')" = "$CYS_MAC_BYTES" ]; then
    # 크기만 보고 건너뛰면 **같은 크기의 다른 파일**이 재실행 경로로 들어온다 — 지문까지 본다
    # (윈도우판은 2026-09-09부터 이미 그렇게 한다. 맥만 크기로 지나가고 있었다.)
    have="$(cys_file_sha256 "$dst")"
    if [ -n "$have" ] && [ "$have" = "$CYS_MAC_SHA256" ]; then
      say "[5/10] 설치 파일이 이미 있습니다 (지문 확인) — 건너뜁니다."
      return 0
    fi
    if [ -z "$have" ]; then
      say "[5/10] 남아 있던 설치 파일의 지문을 재지 못했습니다 — 확인 없이 쓰지 않고 다시 받습니다."
    else
      say "[5/10] 남아 있던 설치 파일의 지문이 다릅니다 — 버리고 다시 받습니다."
    fi
    # dry-run 은 아무것도 지우지 않는다 — 지울 것이 있다는 사실만 말한다(윈도우판과 같다).
    if [ "$MODE" = "dry" ]; then
      say "[5/10] (dry-run) 위 파일을 지우고 다시 받을 것입니다. 받을 곳 = $CYS_DOWNLOAD_URL"
      return 0
    fi
    rm -f "$dst"
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
      # 🔴먼저 **까닭을 가른다**. 받을 자리가 「그런 파일 없다」고 답했으면 기다릴 일이 아니다.
      #   ⚠**404·410 만** 이 갈래다. 5xx(자리는 살아 있는데 잠시 탈이 난 것)도, 물어보지도 못한
      #     `000`(망 쪽)도 **여전히 기다리는 쪽**이다 — 새 갈래가 그 길까지 삼키면 안 된다.
      code="$(cys_http_code "$CYS_DOWNLOAD_URL")"
      case "$code" in
        404|410)
          rm -f "$dst"
          say "[5/10] 받을 자리에 그 판본이 없습니다 (응답 $code)."
          say "     받으려던 곳 = $CYS_DOWNLOAD_URL"
          jcode "J-DL-05" "받을 자리에 그 판본이 없습니다"
          NEXT_STEP="이 진단 코드와 함께 알려 주십시오 — 받는 길을 고쳐 드리겠습니다. 기다려도 생기는 파일이 아니라 다시 실행하셔도 같습니다."
          return 5
          ;;
      esac
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
      # 크기가 맞아도 지문을 본다 — 크기는 같은데 내용이 다른 파일이 「받았습니다」로 지나가면
      # 그 뒤의 모든 단계가 남의 파일 위에서 돈다(윈도우판과 같은 갈래).
      fresh="$(cys_file_sha256 "$dst")"
      if [ -z "$fresh" ]; then
        say "[5/10] 받은 파일의 지문을 잴 수 없습니다 — 확인 없이 설치하지 않습니다."
        jcode "J-DL-03" "설치 파일 지문을 잴 수 없음"
        rm -f "$dst"
        return 5
      fi
      if [ "$fresh" = "$CYS_MAC_SHA256" ]; then
        say "[5/10] 받았습니다 (크기·지문 확인 완료)."
        return 0
      fi
      say "[5/10] 지문이 맞지 않습니다 (받은 것 $(printf '%s' "$fresh" | cut -c1-12)… · 기대 $(printf '%s' "$CYS_MAC_SHA256" | cut -c1-12)…). 이 파일은 쓰지 않습니다."
      jcode "J-DL-04" "설치 파일 지문 불일치"
      rm -f "$dst"
      return 5
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
    1) # 🔴교차 검토가 무너뜨린 자리다(2026-09-06). 앞 판은 여기서 「그 창은 사람이 직접 눌러야 하는
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
    say "[8/10] 홈 폴더 신뢰 기록을 남기지 못했습니다 — $(trust_rollback_words) 여기서 멈춥니다."
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
# 🔴🔴**이전 설치의 좌석을 이번 선언으로 세지 않는다**(2차 검토 N2 확정 2026-09-10).
#   앞 판은 전역 목록에서 **역할 이름만** 셌다. 그러면 지난 설치의 master·cso·worker 가 아직 살아
#   있는 기계에서는 사람이 **아무 선언도 하지 않았는데** 첫 폴링에 세 역할이 다 차서
#   「함대가 섰습니다」로 끝난다 — 새로 연 자비스는 깨어 있지도 않다.
#   ⇒ 자리를 열기 **전에** 목록을 찍어 두고(기준선), 그 뒤 **새로 생긴 자리만** 센다.
# 🔴🔴**기준선을 못 찍었으면 세는 것 자체를 하지 않는다**(3차 검토 N2 확정 2026-09-10 · 관리자 결정).
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
# 🔴🔴**「선언됐다」의 근거를 바꾼다**(1차 검토 BLOCK ③ 확정 2026-09-10).
#   앞 판은 「목록에 master 자리가 있으면 사람이 선언한 것」으로 봤다. **그 축은 처음부터 거짓이었다** —
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
  # 🔴2026-09-10 실기에서 고친 것(5차 검토 · 윈도우에서 드러났고 이쪽도 같은 문구다) — 옛 문구는 「강제」였는데
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
    # 🔴2026-09-10 수리(5차 검토) — 앞 판은 **판정 없이** 「아직 치지 않으셨다면」을 되풀이했다.
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
  # ★여기서도 「아직 안 쳤다」를 단정하지 않는다 — master 자리가 서 있으면 그 말은 거짓이다(5차 검토).
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
    # ★자리를 열기 **전에** 기준선을 찍는다(2차 검토 N2). 이 줄이 자리 여는 줄보다 뒤에 오면
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
        # 깨우기가 **성공한 뒤에만** 세운다(검토 지적 · D1 기각) — 깨우기가 실패한 끝은 원격 해결이 돈다.
        #   이 창에서 띄우는 갈래(exec)는 성공하면 이 프로세스가 자비스로 바뀌어 끝맺음이 오지 않고, 실패하면 이 깃발 없이 끝맺음이 온다.
        REACHED_WAKE=1
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

# ── 원격 해결 (help-s2) — 막히면 진단이 서버로 가고, 운영팀 명령을 이 창이 실행한다 ────────
# 계약 정본 = ai-jarvis `web-install/docs/HELP-API.md` 4절·5절·7절·9-4절 · 실행 가능한 명세 = `web-install/test-s2/s2-double.ts`.
# ★사람이 누르는 것은 없다 — [1/10] 에서 고지 1줄을 보여 드리고, 막혀 멈추면 묻지 않고 보낸다(서열 1 쉬운 설치).
# ★서버 응답을 믿지 않는다 — 명령은 **이 파일에 넣어 둔 표**로 다시 재고(글자·칸·이름·모양·자리),
#   작업 폴더 밖을 가리키는 경로를 막고, 실행한 번호를 **실행 전에** 파일에 남기고, 셸 없이 실행한다.
#   ⇒ 응답이 위조돼도 닿는 것은 표 v1 의 읽기 명령뿐이다.
# ★이 창이 닫히면 멈춘다 — 폴링은 이 프로세스 안에서만 돈다(뒤로 떼어 놓지 않는다).
# ★언제 도는가 = 자비스를 깨우기 **전에** 진단 코드를 남기고 멈춘 끝. 자비스를 깨운 뒤에는 돌지 않는다
#   (자비스가 이 창을 넘겨받으므로 두 쪽이 한 화면에 섞이지 않게).
# ⚠JSON·재검사·스크럽은 macOS 기본 `osascript`(JavaScript)가 한다 — 깨끗한 맥에는 jq·python 이 없다.
INSTALLER_VERSION="0.3.15"      # 보고의 installer_version · BOOTSTRAP_VERSION 은 화면 머리글 용도 그대로(보내지 않는다)
HELP_API_URL="https://jarvis-install.godmeyou.kr"
REMOTE_HELP_NOTICE_URL="jarvis-install.godmeyou.kr/help/notice"
# [1/10] 고지 1줄 = /help/notice 정본(page.ts)이 인용하는 문장 그대로 + 끝에 자세한 안내 자리(계약 7-1절). ⛔문안 변경 금지.
REMOTE_HELP_NOTICE="막히면 진단이 서버로 가고 운영 자비스가 원격으로 해결합니다 · 창을 닫으면 멈춥니다 · 자세히: $REMOTE_HELP_NOTICE_URL"
# 「막혔을 때」 절 = page.ts REMOTE_LINES 3줄에서 태그만 뗀 것. ⛔문안 변경 금지(시험이 글자를 잰다).
REMOTE_HELP_LINES=(
  "무엇을 보내는가 — 설치가 막히면 설치 창이 진단(진단 코드·멈춘 단계·운영체제 판본·환경 보고·기록 끝부분)을 이 서버로 보냅니다. 집 폴더 경로·이메일·토큰, 그리고 환경 보고와 기록에 표시된 로그인 이름(같은 보고의 다른 곳에 나와도)은 보내기 전에 지우고, 서버가 한 번 더 지웁니다. 표시 없이 글 속에 홀로 적힌 이름은 알아보지 못해 남을 수 있습니다."
  "누가 명령하는가 — 운영팀만 명령을 보낼 수 있습니다. 명령은 설치 창에 글자 그대로 표시된 뒤 실행되고, 이 화면에도 같은 글자로 남습니다. 서버는 명령을 실행하지 않습니다."
  "어떻게 멈추는가 — 설치 창을 닫으면 곧바로 멈춥니다. 보고 화면의 「원격 해결 멈추기」로도 멈출 수 있고, 명령이 30분 동안 없거나 시작한 지 2시간이 지나면 저절로 닫힙니다."
)
REMOTE_HELP_POLL_SEC=20
REMOTE_HELP_MAX_SEC=7200          # 2시간 — 서버의 절대 상한과 같다(서버가 못 닿아도 이 창이 따로 멈춘다)
REMOTE_HELP_CMD_TIMEOUT=60        # 명령 하나의 시간 상한(초)
REMOTE_HELP_NOTE_EVERY_SEC=300    # 기다리는 동안 몇 초마다 한 줄 말하는가(침묵은 「멈췄다」로 읽힌다)
REMOTE_HELP_SEQ_FILE="$JARVIS_HOME/remote-help-executed.json"   # 실행한 명령 번호 · 재부팅 내성 · 깨지면 실행 0
REMOTE_HELP_TOKEN_FILE="$JARVIS_HOME/remote-help-client-token"   # 보고 응답의 client_token(600) · ack·close 출처 헤더
NOTICE_SHOWN=0
REACHED_WAKE=0
RH_TMP=""
RH_ID=""
RH_HTTP=""
RH_REAL=""
RH_RC=""
RH_TIMEDOUT=0
RH_REFUSED=""
RH_RECORD=""
RH_LOCK_HELD=0
RH_LAST_ANSWER=""

# 허용 명령 표 — ai-jarvis `web-install/docs/command-table.json` 과 **바이트 동일**(시험이 sha256 을 잰다).
#   판본 글자는 이 표의 "version" 하나뿐이다(코드에 따로 적지 않는다).
IFS= read -r -d '' REMOTE_HELP_TABLE <<'EOF_REMOTE_HELP_TABLE' || true
{
  "version": "v1-2026-09-11",
  "token_pattern": "^[A-Za-z0-9_.:/\\\\-]+$",
  "max_command_bytes": 512,
  "max_tokens": 12,
  "max_token_chars": 200,
  "max_path_segments": 8,
  "proc_names": [
    "cys",
    "cysd",
    "claude",
    "node"
  ],
  "entries": [
    {
      "id": "dir.root",
      "shell": "ps1",
      "usage": "Get-ChildItem",
      "exec": "cmdlet",
      "risk": 0,
      "title": "작업 폴더 맨 위의 목록을 본다"
    },
    {
      "id": "dir.list",
      "shell": "ps1",
      "usage": "Get-ChildItem -LiteralPath <path>",
      "exec": "cmdlet",
      "risk": 0,
      "title": "작업 폴더 안 한 폴더의 목록을 본다"
    },
    {
      "id": "file.tail",
      "shell": "ps1",
      "usage": "Get-Content -LiteralPath <path> -Tail <n:1-200>",
      "exec": "cmdlet",
      "risk": 0,
      "title": "작업 폴더 안 파일의 끝 N줄을 본다"
    },
    {
      "id": "file.hash",
      "shell": "ps1",
      "usage": "Get-FileHash -LiteralPath <path> -Algorithm SHA256",
      "exec": "cmdlet",
      "risk": 0,
      "title": "작업 폴더 안 파일의 SHA256 을 본다"
    },
    {
      "id": "file.exists",
      "shell": "ps1",
      "usage": "Test-Path -LiteralPath <path>",
      "exec": "cmdlet",
      "risk": 0,
      "title": "작업 폴더 안에 그 파일(예: 표식 .jarvis-owned)이 있는지 본다"
    },
    {
      "id": "disk.free",
      "shell": "ps1",
      "usage": "Get-PSDrive -Name C",
      "exec": "cmdlet",
      "risk": 0,
      "title": "C 드라이브의 남은 공간을 본다"
    },
    {
      "id": "net.check",
      "shell": "ps1",
      "usage": "Test-NetConnection -ComputerName jarvis-install.godmeyou.kr -Port 443 -InformationLevel Quiet",
      "exec": "cmdlet",
      "risk": 0,
      "title": "우리 서버(443)에 닿는지 본다"
    },
    {
      "id": "shell.version",
      "shell": "ps1",
      "usage": "Get-Host",
      "exec": "cmdlet",
      "risk": 0,
      "title": "PowerShell 판본을 본다"
    },
    {
      "id": "av.status",
      "shell": "ps1",
      "usage": "Get-MpComputerStatus",
      "exec": "cmdlet",
      "risk": 0,
      "title": "백신 상태를 본다(끄지 않는다)"
    },
    {
      "id": "proc.find",
      "shell": "ps1",
      "usage": "Get-Process -Name <proc>",
      "exec": "cmdlet",
      "risk": 0,
      "title": "우리 프로그램(cys·cysd·claude·node)이 떠 있는지 본다"
    },
    {
      "id": "cys.status",
      "shell": "ps1",
      "usage": "cys status",
      "exec": "cys",
      "risk": 0,
      "title": "cys 노드 상태를 본다"
    },
    {
      "id": "cys.doctor",
      "shell": "ps1",
      "usage": "cys doctor",
      "exec": "cys",
      "risk": 0,
      "title": "cys 자기진단을 본다(고치지 않는다)"
    },
    {
      "id": "cys.daemon",
      "shell": "ps1",
      "usage": "cys daemon status",
      "exec": "cys",
      "risk": 0,
      "title": "cys 상시 가동 등록 상태를 본다"
    },
    {
      "id": "dir.root",
      "shell": "sh",
      "usage": "ls -lan",
      "exec": "/bin/ls",
      "risk": 0,
      "title": "작업 폴더 맨 위의 목록을 본다(소유자는 번호로)"
    },
    {
      "id": "dir.list",
      "shell": "sh",
      "usage": "ls -lan <path>",
      "exec": "/bin/ls",
      "risk": 0,
      "title": "작업 폴더 안 한 폴더의 목록을 본다(소유자는 번호로)"
    },
    {
      "id": "file.tail",
      "shell": "sh",
      "usage": "tail -n <n:1-200> <path>",
      "exec": "/usr/bin/tail",
      "risk": 0,
      "title": "작업 폴더 안 파일의 끝 N줄을 본다"
    },
    {
      "id": "file.hash",
      "shell": "sh",
      "usage": "shasum -a 256 <path>",
      "exec": "/usr/bin/shasum",
      "risk": 0,
      "title": "작업 폴더 안 파일의 SHA256 을 본다"
    },
    {
      "id": "file.exists",
      "shell": "sh",
      "usage": "test -e <path>",
      "exec": "/bin/test",
      "risk": 0,
      "title": "작업 폴더 안에 그 파일(예: 표식 .jarvis-owned)이 있는지 본다(종료 코드)"
    },
    {
      "id": "disk.free",
      "shell": "sh",
      "usage": "df -h .",
      "exec": "/bin/df",
      "risk": 0,
      "title": "작업 폴더가 있는 디스크의 남은 공간을 본다"
    },
    {
      "id": "net.check",
      "shell": "sh",
      "usage": "nc -z -G 5 jarvis-install.godmeyou.kr 443",
      "exec": "/usr/bin/nc",
      "risk": 0,
      "title": "우리 서버(443)에 닿는지 본다"
    },
    {
      "id": "shell.version",
      "shell": "sh",
      "usage": "sw_vers",
      "exec": "/usr/bin/sw_vers",
      "risk": 0,
      "title": "macOS 판본을 본다"
    },
    {
      "id": "av.status",
      "shell": "sh",
      "usage": "spctl --status",
      "exec": "/usr/sbin/spctl",
      "risk": 0,
      "title": "Gatekeeper 상태를 본다(끄지 않는다)"
    },
    {
      "id": "proc.find",
      "shell": "sh",
      "usage": "pgrep -l <proc>",
      "exec": "/usr/bin/pgrep",
      "risk": 0,
      "title": "우리 프로그램(cys·cysd·claude·node)이 떠 있는지 본다"
    },
    {
      "id": "cys.status",
      "shell": "sh",
      "usage": "cys status",
      "exec": "cys",
      "risk": 0,
      "title": "cys 노드 상태를 본다"
    },
    {
      "id": "cys.doctor",
      "shell": "sh",
      "usage": "cys doctor",
      "exec": "cys",
      "risk": 0,
      "title": "cys 자기진단을 본다(고치지 않는다)"
    },
    {
      "id": "cys.daemon",
      "shell": "sh",
      "usage": "cys daemon status",
      "exec": "cys",
      "risk": 0,
      "title": "cys 상시 가동 등록 상태를 본다"
    }
  ]
}
EOF_REMOTE_HELP_TABLE

# 판정 쪽(JavaScript) — 입력은 환경(RH_*)과 인자로 받고, 결과는 파일이나 한 줄씩 돌려준다.
#   ⚠`Ref()` 오류 포인터를 쓰지 않는다 — 이 기계(macOS 26.6.2)에서 osascript 가 그 자리에서 죽었다(rc 139 실측).
IFS= read -r -d '' REMOTE_HELP_JS <<'EOF_REMOTE_HELP_JS' || true
ObjC.import("Foundation");

var ENV_REPORT_MAX_BYTES = 96000;
var LOG_TAIL_MAX_BYTES = 128000;
var LOG_TAIL_LINES = 200;
var OUTPUT_MAX_BYTES = 4096;
var REPORT_MAX_BYTES = 240000;   // 서버 본문 상한 262,144 바이트 안쪽 — 잘라 낸 글이 아니라 **직렬화한 JSON** 을 잰다(백슬래시·제어 글자는 두 배 이상 커진다)
var MAX_NAMES = 64;

function env(name) {
  var value = $.NSProcessInfo.processInfo.environment.objectForKey(name);
  return value.isNil() ? "" : ObjC.unwrap(value);
}

function readText(path) {
  if (!path) return null;
  var text = $.NSString.stringWithContentsOfFileEncodingError(path, $.NSUTF8StringEncoding, null);
  return text.isNil() ? null : ObjC.unwrap(text);
}

function readJson(path) {
  var text = readText(path);
  if (text === null) throw new Error("unreadable");
  return JSON.parse(text);
}

function writeText(path, text) {
  if (!path || !$(text).writeToFileAtomicallyEncodingError(path, true, $.NSUTF8StringEncoding, null)) throw new Error("write");
}

function utf8Bytes(text) {
  var bytes = 0;
  for (var i = 0; i < text.length; i += 1) {
    var c = text.charCodeAt(i);
    if (c < 0x80) bytes += 1;
    else if (c < 0x800) bytes += 2;
    else if (c >= 0xd800 && c <= 0xdbff && i + 1 < text.length) { bytes += 4; i += 1; }
    else bytes += 3;
  }
  return bytes;
}

function tailBytes(text, max) {
  var chars = Array.from(text);
  var bytes = utf8Bytes(text);
  var start = 0;
  while (bytes > max && start < chars.length) { bytes -= utf8Bytes(chars[start]); start += 1; }
  return chars.slice(start).join("");
}

function headBytes(text, max) {
  var chars = Array.from(text);
  var bytes = utf8Bytes(text);
  var end = chars.length;
  while (bytes > max && end > 0) { end -= 1; bytes -= utf8Bytes(chars[end]); }
  return chars.slice(0, end).join("");
}

// ── 1차 스크럽 — 서버 src/scrub.ts 와 같은 규칙(계약 5절) · 서버가 한 번 더 지운다 ──
var SCRUB_PATTERNS = [
  [/[A-Za-z0-9._%+-]{1,64}@[A-Za-z0-9-]{1,63}(?:\.[A-Za-z0-9-]{1,63})*\.[A-Za-z]{2,63}/g, "<이메일 지움>"],
  [/\bBearer\s+[A-Za-z0-9._~+/=-]+/gi, "Bearer <토큰 지움>"],
  [/\bsk-[A-Za-z0-9_-]{8,}/g, "<키 지움>"],
  [/\b[A-Za-z]:(?:\\{1,2}|\/)Users(?:\\{1,2}|\/)[^\\/\r\n"'<>|:*?]+/gi, "~"],
  [/\/Users\/[^/\s"'<>]+/g, "~"]
];
var NAME_LINES = /\b(?:USERNAME|USERPROFILE|LOGNAME|USER|HOME)\b[ \t]*[=:][ \t]*([^\r\n]+)|\bwhoami\b[ \t]*[:=>][ \t]*([^\r\n]+)|(?:^|\n)[ \t]*([A-Za-z][A-Za-z0-9.-]{1,63}\\[A-Za-z0-9._-]{2,63})[ \t]*(?:\r?\n|$)/gi;

// known = 이 컴퓨터가 스스로 아는 로그인 이름(표시 없이 나와도 지운다 — 서버는 표시된 이름만 안다).
function harvestNames(input, known) {
  var names = [];
  function add(raw) {
    if (names.length >= MAX_NAMES) return;
    var value = String(raw).trim().replace(/["']/g, "");
    if (value.length >= 2 && names.indexOf(value) < 0) names.push(value);
    var segment = (value.split(/[\\/]/).pop() || "").trim();
    if (segment.length >= 2 && names.length < MAX_NAMES && names.indexOf(segment) < 0) names.push(segment);
  }
  known.forEach(add);
  var matches = Array.from(input.matchAll(NAME_LINES));
  for (var i = 0; i < matches.length && names.length < MAX_NAMES; i += 1) add(matches[i][1] || matches[i][2] || matches[i][3] || "");
  return names.sort(function (a, b) { return b.length - a.length; });
}

function scrubWith(input, names) {
  var text = input;
  if (names.length > 0) {
    var alternation = new RegExp(names.map(function (name) { return name.replace(/[.*+?^${}()|[\]\\]/g, "\\$&"); }).join("|"), "g");
    text = text.replace(alternation, "~user");
  }
  return SCRUB_PATTERNS.reduce(function (acc, pattern) { return acc.replace(pattern[0], pattern[1]); }, text);
}

// ── 재검사 — 번들 표·같은 문법(계약 9-1절 · 서버 코드를 가져오지 않은 독립 구현) ──
var SEGMENT = /^\.?[A-Za-z0-9_][A-Za-z0-9_.-]{0,62}$/;
var DEVICE = /^(con|prn|aux|nul|com[0-9]|lpt[0-9])(\.|$)/i;

function pathOk(table, shell, value) {
  if (/^[\\/]/.test(value) || value.indexOf(":") >= 0) return false;
  if (shell === "sh" && value.indexOf("\\") >= 0) return false;
  var segments = value.split(/[\\/]/);
  if (segments.length > table.max_path_segments) return false;
  return segments.every(function (segment) { return SEGMENT.test(segment) && segment.charAt(segment.length - 1) !== "." && !DEVICE.test(segment); });
}

function slotOk(table, shell, slot, value) {
  if (slot === "<path>") return pathOk(table, shell, value);
  if (slot === "<proc>") return table.proc_names.indexOf(value) >= 0;
  var range = /^<n:([0-9]+)-([0-9]+)>$/.exec(slot);
  if (range !== null) return /^(0|[1-9][0-9]{0,3})$/.test(value) && Number(value) >= Number(range[1]) && Number(value) <= Number(range[2]);
  return slot === value;
}

function recheckArgv(table, shell, argv) {
  if (!Array.isArray(argv) || argv.length === 0) return { ok: false, rule: "empty" };
  if (argv.length > table.max_tokens) return { ok: false, rule: "too_many_tokens" };
  var token = new RegExp(table.token_pattern);
  for (var i = 0; i < argv.length; i += 1) {
    if (typeof argv[i] !== "string" || argv[i].length === 0) return { ok: false, rule: "empty" };
    if (argv[i].length > table.max_token_chars || !token.test(argv[i])) return { ok: false, rule: "char" };
  }
  if (utf8Bytes(argv.join(" ")) > table.max_command_bytes) return { ok: false, rule: "too_long" };
  var named = table.entries.filter(function (entry) { return entry.shell === shell && entry.usage.split(" ")[0] === argv[0]; });
  if (named.length === 0) return { ok: false, rule: "unknown_command" };
  for (var j = 0; j < named.length; j += 1) {
    var slots = named[j].usage.split(" ");
    if (slots.length === argv.length && slots.every(function (slot, k) { return k === 0 || slotOk(table, shell, slot, argv[k]); })) {
      return { ok: true, entry: named[j], argv: argv.slice() };
    }
  }
  return { ok: false, rule: "usage_mismatch" };
}

// 실행한 번호. 파일이 없으면 빈 목록 · 있는데 못 읽거나 깨졌으면 null(아무것도 실행하지 않는다).
function loadExecuted(path) {
  if (!$.NSFileManager.defaultManager.fileExistsAtPath(path)) return [];
  var raw = readText(path);
  if (raw === null) return null;
  var parsed;
  try { parsed = JSON.parse(raw); } catch (error) { return null; }
  if (Array.isArray(parsed) && parsed.every(function (seq) { return Number.isSafeInteger(seq) && seq > 0; })) return parsed;
  return null;
}

function positiveSeq(text) {
  var seq = Number(text);
  if (!Number.isSafeInteger(seq) || seq <= 0 || String(seq) !== text) throw new Error("seq");
  return seq;
}

// 본문 한 칸을 줄여 직렬화한 본문이 상한 안에 들게 한다 — keep(글, 바이트) 가 남기는 쪽(끝 · 앞)을 정한다 · 이분 탐색
function fitReport(body, field, keep) {
  if (utf8Bytes(JSON.stringify(body)) <= REPORT_MAX_BYTES) return;
  var full = body[field];
  var lo = 0;
  var hi = utf8Bytes(full);
  while (lo < hi) {
    var mid = Math.ceil((lo + hi) / 2);
    body[field] = keep(full, mid);
    if (utf8Bytes(JSON.stringify(body)) <= REPORT_MAX_BYTES) lo = mid; else hi = mid - 1;
  }
  body[field] = keep(full, lo);
}

function modeReport() {
  var code = env("RH_CODE");
  var step = env("RH_STEP");
  var version = env("RH_VERSION");
  if (!/^J-[A-Z]{2,6}-[0-9]{2}$/.test(code)) throw new Error("code");
  if (!/^[0-9]{1,2}\/[0-9]{1,2}$/.test(step)) throw new Error("step");
  if (!/^[0-9A-Za-z][0-9A-Za-z.+_-]{0,31}$/.test(version)) throw new Error("installer_version");
  var envReport = readText(env("RH_ENV_FILE")) || "";
  var lines = (readText(env("RH_LOG_FILE")) || "").split("\n");
  if (lines.length > 0 && lines[lines.length - 1] === "") lines.pop();
  var log = lines.slice(-LOG_TAIL_LINES).join("\n");
  var names = harvestNames(envReport + "\n" + log, env("RH_EXTRA_NAMES").split("\n"));
  var body = {
    code: code,
    step: step,
    os: "mac",
    installer_version: version,
    env_report: headBytes(scrubWith(envReport, names), ENV_REPORT_MAX_BYTES),
    log_tail: tailBytes(scrubWith(log, names), LOG_TAIL_MAX_BYTES),
    notice_shown: true
  };
  // 직렬화한 본문이 상한을 넘으면 기록 끝(log_tail) → 환경 보고(env_report) 순으로, 남길 수 있는 가장 긴 길이를 찾아 줄인다
  fitReport(body, "log_tail", tailBytes);
  fitReport(body, "env_report", headBytes);
  writeText(env("RH_REPORT_OUT"), JSON.stringify(body));
  writeText(env("RH_NAMES_OUT"), names.join("\n"));
  return "OK";
}

function modeId() {
  var body = readJson(env("RH_BODY_FILE"));
  var id = body !== null && typeof body === "object" ? body.id : null;
  if (typeof id !== "string" || !/^[ABCDEFGHJKLMNPQRSTUVWXYZ23456789]{8}$/.test(id)) return "";
  // 출처 증명 — 64자 16진만 받는다. 없거나 모양이 틀리면 빈 칸(옛 서버 = 헤더 없이 보낸다).
  var token = body.client_token;
  return id + " " + (typeof token === "string" && /^[0-9a-f]{64}$/.test(token) ? token : "");
}

// 한 번의 폴링 응답 → 줄마다 하나의 판정. 계약 7-4절·9-4절 ①② 까지(경로·실행은 bash 쪽).
//   SESSION open|closed · HALT seqfile · DECLINE <seq> <rule> · RUN <seq> <exec> <칸 종류> <argv…>
function modePoll() {
  var poll = readJson(env("RH_BODY_FILE"));
  var table = JSON.parse(env("RH_TABLE"));
  var shell = env("RH_SHELL");
  var session = poll !== null && typeof poll === "object" ? poll.session : null;
  if (session === null || typeof session !== "object" || session.open !== true) return "SESSION closed";
  var out = ["SESSION open"];
  var executed = loadExecuted(env("RH_SEQ_FILE"));
  if (executed === null) { out.push("HALT seqfile"); return out.join("\n"); }
  var messages = Array.isArray(session.messages) ? session.messages : [];
  for (var i = 0; i < messages.length; i += 1) {
    var message = messages[i];
    if (message === null || typeof message !== "object") continue;
    var seq = message.seq;
    if (message.kind !== "command") continue;
    if (typeof seq !== "number" || !Number.isSafeInteger(seq) || seq <= 0) continue;
    if (message.ack === null || typeof message.ack !== "object" || message.ack.status !== "pending") continue;
    if (typeof message.sig !== "string" || !/^[0-9a-f]{64}$/.test(message.sig)) continue;
    if (executed.indexOf(seq) >= 0) continue;
    if (message.shell !== shell) { out.push("DECLINE " + seq + " shell"); continue; }
    if (message.table_version !== table.version) { out.push("DECLINE " + seq + " table_version"); continue; }
    // `text` 는 읽지 않는다 — 실행에 닿는 입력은 argv 하나뿐이다.
    var verdict = recheckArgv(table, shell, message.argv);
    if (!verdict.ok) { out.push("DECLINE " + seq + " " + verdict.rule); continue; }
    var kinds = verdict.entry.usage.split(" ").slice(1).map(function (slot) { return slot === "<path>" ? "p" : "v"; }).join("");
    out.push(["RUN", seq, verdict.entry.exec, kinds || "-"].concat(verdict.argv).join(" "));
  }
  return out.join("\n");
}

// 처방 표시. 운영팀 글이라도 화면 제어 글자(색·커서·방향 바꿈)는 지우고 보여 준다.
function modeAnswer() {
  var poll = readJson(env("RH_BODY_FILE"));
  var answer = poll !== null && typeof poll === "object" ? poll.answer : null;
  if (answer === null || typeof answer !== "object" || typeof answer.text !== "string") return "";
  var number = Number.isInteger(answer.action_no) ? "(조치 " + answer.action_no + ")" : "";
  var control = new RegExp("[" + [[0x00, 0x09], [0x0b, 0x1f], [0x7f, 0x9f], [0x200e, 0x200f], [0x202a, 0x202e], [0x2066, 0x2069]].map(function (r) { return String.fromCharCode(r[0]) + "-" + String.fromCharCode(r[1]); }).join("") + "]", "g");
  var text = answer.text.replace(control, "").split("\n").join("\n       ");
  return "     처방" + number + ": " + text;
}

function modeRecord(argv) {
  var seq = positiveSeq(argv[1]);
  var path = env("RH_SEQ_FILE");
  var executed = loadExecuted(path);
  if (executed === null) throw new Error("seq file");
  if (executed.indexOf(seq) >= 0) return "ALREADY";
  executed.push(seq);
  writeText(path, JSON.stringify(executed));
  var back = loadExecuted(path);
  if (back === null || back.indexOf(seq) < 0) throw new Error("seq file verify");
  return "OK";
}

// ack <seq> declined <rule> · ack <seq> ran <rc|null> <시간 초과 0|1> <상한 초>
function modeAck(argv) {
  var seq = positiveSeq(argv[1]);
  var body;
  if (argv[2] === "declined") {
    if (!/^[a-z_]{1,40}$/.test(argv[3] || "")) throw new Error("rule");
    body = { seq: seq, status: "declined", rc: null, output_tail: "policy:" + argv[3] };
  } else if (argv[2] === "ran") {
    var timedOut = argv[4] === "1";
    var rc = timedOut || argv[3] === "null" ? null : Number(argv[3]);
    if (rc !== null && !Number.isSafeInteger(rc)) throw new Error("rc");
    var output = readText(env("RH_OUTPUT_FILE")) || "";
    if (timedOut) output += "\ntimeout:" + argv[5] + "s";
    var names = (readText(env("RH_NAMES_FILE")) || "").split("\n").filter(function (name) { return name.length >= 2; });
    body = { seq: seq, status: "ran", rc: rc, output_tail: tailBytes(scrubWith(output, names), OUTPUT_MAX_BYTES) };
  } else {
    throw new Error("status");
  }
  writeText(env("RH_ACK_OUT"), JSON.stringify(body));
  return "OK";
}

function run(argv) {
  switch (argv[0]) {
    case "report": return modeReport();
    case "id": return modeId();
    case "poll": return modePoll();
    case "answer": return modeAnswer();
    case "record": return modeRecord(argv);
    case "ack": return modeAck(argv);
  }
  throw new Error("mode");
}
EOF_REMOTE_HELP_JS

remote_help_js() {   # remote_help_js <mode> [인자…] — 입력은 환경(RH_*)으로 넘긴다
  /usr/bin/osascript -l JavaScript -e "$REMOTE_HELP_JS" "$@" </dev/null
}

remote_help_http() {   # remote_help_http <METHOD> <경로> [본문 파일] → RH_HTTP(응답 코드 · 000 = 닿지 못함) · 응답 본문 = $RH_TMP/resp
  local -a extra=()
  rm -f "$RH_TMP/resp"
  [ -n "${3:-}" ] && extra+=(-H 'content-type: application/json' --data-binary "@$3")
  # 출처 헤더는 파일로 넘긴다(명령줄에 값이 보이지 않게) · ack·close 에만
  case "$2" in
    */ack|*/close) [ -s "$RH_TMP/client-header" ] && extra+=(-H "@$RH_TMP/client-header") ;;
  esac
  RH_HTTP="$(curl -sS -m "${RH_HTTP_MAX:-20}" -X "$1" ${extra[@]+"${extra[@]}"} -o "$RH_TMP/resp" -w '%{http_code}' \
    "$HELP_API_URL$2" </dev/null 2>/dev/null)"
  case "$RH_HTTP" in [1-5][0-9][0-9]) ;; *) RH_HTTP="000" ;; esac
}

# 끝맺음(closing_note)이 부른다 — [1/10] 고지를 보여 드린 실행에서만.
remote_help() {
  local line
  [ -n "$J_CODE" ] || return 0
  [ "$REACHED_WAKE" = "1" ] && return 0
  if [ "$MODE" != "full" ]; then
    [ "$MODE" = "dry" ] && say "  (dry-run) 원격 해결 진단을 보내지 않았습니다."
    return 0
  fi
  say ""
  say "  == 막혔을 때 — 원격 해결 =="
  for line in "${REMOTE_HELP_LINES[@]}"; do say "   $line"; done
  say "   자세히: $REMOTE_HELP_NOTICE_URL"
  if [ ! -x /usr/bin/osascript ] || ! command -v curl >/dev/null 2>&1; then
    say "     이 컴퓨터에서 진단을 보낼 도구를 찾지 못해 원격 해결을 시작하지 못했습니다."
    return 0
  fi
  RH_TMP="$(mktemp -d -t jarvis-help 2>/dev/null)" || RH_TMP=""
  if [ -z "$RH_TMP" ]; then
    say "     임시 자리를 만들지 못해 원격 해결을 시작하지 못했습니다."
    return 0
  fi
  trap 'remote_help_on_signal' HUP INT TERM
  if remote_help_report; then
    # 3회째 안내를 보인 실행만 — 보고가 실제로 전달된 순간에 그렇다고 말한다(D3)
    if [ "$HELP_STAGE3_SHOWN" = "1" ]; then
      printf '%s\n' "  막힌 자리 정보는 방금 자동으로 전달됐습니다."
      HELP_SENT_OK=1
    fi
    remote_help_loop
  fi
  trap - HUP INT TERM
  rm -rf "$RH_TMP"
  RH_TMP=""
  return 0
}

remote_help_report() {   # rc 0 = 보고 번호를 받았다
  local names step ids="" token="" tries=0
  : > "$RH_TMP/env"
  : > "$RH_TMP/log"
  [ -f "$REPORT_FILE" ] && iconv -f UTF-8 -t UTF-8 -c < "$REPORT_FILE" > "$RH_TMP/env" 2>/dev/null
  [ -f "$LOG_FILE" ] && tail -n 200 "$LOG_FILE" 2>/dev/null | iconv -f UTF-8 -t UTF-8 -c > "$RH_TMP/log" 2>/dev/null
  # 멈춘 단계 = 이 실행이 기록 파일에 마지막으로 찍은 [n/10](이 실행은 [1/10] 을 찍었으므로 앞 실행의 것이 아니다)
  step="$(grep -oE '\[[0-9]{1,2}/[0-9]{1,2}\]' "$LOG_FILE" 2>/dev/null | tail -1 | tr -d '[]')"
  [ -n "$step" ] || step="0/10"
  names="$(id -un 2>/dev/null)
$(id -F 2>/dev/null)
$(basename "$HOME")"
  if ! RH_ENV_FILE="$RH_TMP/env" RH_LOG_FILE="$RH_TMP/log" RH_EXTRA_NAMES="$names" RH_CODE="$J_CODE" \
       RH_STEP="$step" RH_VERSION="$INSTALLER_VERSION" RH_REPORT_OUT="$RH_TMP/report.json" RH_NAMES_OUT="$RH_TMP/names" \
       remote_help_js report >/dev/null 2>&1; then
    say "     진단을 꾸리지 못해 보내지 않았습니다."
    return 1
  fi
  while :; do
    remote_help_http POST "/api/help" "$RH_TMP/report.json"
    case "$RH_HTTP" in
      201) break ;;
      000|429|5??)
        tries=$((tries + 1))
        [ "$tries" -lt 3 ] || break
        sleep "$REMOTE_HELP_POLL_SEC" ;;
      *) break ;;
    esac
  done
  if [ "$RH_HTTP" = "201" ]; then
    ids="$(RH_BODY_FILE="$RH_TMP/resp" remote_help_js id 2>/dev/null)"
    RH_ID="${ids%% *}"
    token="${ids#* }"
    [ "$token" = "$ids" ] && token=""
  fi
  if [ -z "$RH_ID" ]; then
    say "     진단을 보내지 못했습니다(서버 답 $RH_HTTP). 위 진단 코드로 안내를 찾아보실 수 있습니다."
    return 1
  fi
  log "remote help: report $RH_ID"
  help_last_report_save "$RH_ID"
  # 출처 증명 — 서버가 준 client_token 을 이 기계에만 두고(600) ack·close 에 헤더로 붙인다
  #   처음부터 본인만 읽는 권한으로 만든다(umask 077). 못 쓰거나 권한을 못 맞추면 파일을 지우고 토큰도 버린다(닫힌 쪽 · 검토 지적).
  rm -f "$REMOTE_HELP_TOKEN_FILE"
  if [ -n "$token" ]; then
    if ! { ( umask 077; printf '%s\n' "$token" > "$REMOTE_HELP_TOKEN_FILE" ) 2>/dev/null && chmod 600 "$REMOTE_HELP_TOKEN_FILE" 2>/dev/null &&
           ( umask 077; printf 'x-help-client: %s\n' "$token" > "$RH_TMP/client-header" ) 2>/dev/null; }; then
      rm -f "$REMOTE_HELP_TOKEN_FILE" "$RH_TMP/client-header" 2>/dev/null
      token=""
      log "remote help: 출처 헤더 없음(출처 토큰을 본인만 읽는 파일로 두지 못해 버렸다)"
    fi
  else
    log "remote help: 출처 헤더 없음(보고 응답에 client_token 이 없다)"
  fi
  say "     보고 번호 $RH_ID — 운영팀이 곧 봅니다."
  say "     폰에서 보기: $HELP_API_URL/help/$RH_ID"
  say "     이 창을 열어 두시면 처방과 운영팀 명령이 여기에 나타납니다. 창을 닫으면 멈춥니다."
  return 0
}

remote_help_loop() {
  local started=$SECONDS last_note=$SECONDS rc
  while :; do
    if [ $((SECONDS - started)) -ge "$REMOTE_HELP_MAX_SEC" ]; then
      say "     원격 해결 시간($((REMOTE_HELP_MAX_SEC / 60))분)이 끝나 멈춥니다."
      remote_help_http POST "/api/help/$RH_ID/close"
      return 0
    fi
    remote_help_http GET "/api/help/$RH_ID"
    case "$RH_HTTP" in
      200)
        remote_help_tick
        rc=$?
        case "$rc" in
          0) ;;
          2) remote_help_http POST "/api/help/$RH_ID/close"; return 0 ;;
          *) remote_help_ended; return 0 ;;
        esac ;;
      404) say "     보고가 지워져 원격 해결을 멈춥니다."; return 0 ;;
      410) remote_help_ended; return 0 ;;
    esac
    if [ $((SECONDS - last_note)) -ge "$REMOTE_HELP_NOTE_EVERY_SEC" ]; then
      last_note=$SECONDS
      say "     원격 해결을 기다리는 중입니다 ($(( (SECONDS - started) / 60 ))분 지남 · 최대 $((REMOTE_HELP_MAX_SEC / 60))분 · 창을 닫으면 멈춥니다)."
    fi
    sleep "$REMOTE_HELP_POLL_SEC"
  done
}

# 계약 7-8절 과 같은 뜻. ⚠이 파일은 사람에게 「줄」을 말하지 않는다 — 다시 하는 방법은 끝맺음이 명령 전체로 인쇄한다.
remote_help_ended() {
  say "     원격 해결이 끝났습니다 · 아래 「다시 하시는 법」대로 다시 실행하시면 새 보고로 이어집니다."
  SHOW_RERUN=1
}

remote_help_tick() {   # rc 0 = 계속 · 1 = 대화 닫힘 · 2 = 실행 기록을 못 믿어 멈춤 · 3 = 서버가 닫았다(410)
  local plan answer line rc
  local -a f
  plan="$(RH_BODY_FILE="$RH_TMP/resp" RH_TABLE="$REMOTE_HELP_TABLE" RH_SEQ_FILE="$REMOTE_HELP_SEQ_FILE" RH_SHELL=sh \
    remote_help_js poll 2>/dev/null)" || return 0
  answer="$(RH_BODY_FILE="$RH_TMP/resp" remote_help_js answer 2>/dev/null)"
  if [ -n "$answer" ] && [ "$answer" != "$RH_LAST_ANSWER" ]; then
    RH_LAST_ANSWER="$answer"
    say "$answer"
  fi
  while IFS= read -r line; do
    [ -n "$line" ] || continue
    read -r -a f <<< "$line"
    case "${f[0]}" in
      SESSION) [ "${f[1]}" = "open" ] || return 1 ;;
      HALT)    say "     실행 기록 파일을 읽을 수 없어 명령을 실행하지 않고 멈춥니다."; return 2 ;;
      DECLINE) remote_help_ack "${f[1]}" declined "${f[2]}" || return 3 ;;
      RUN)     remote_help_run_one "${f[@]:1}"; rc=$?; [ "$rc" -eq 0 ] || return "$rc" ;;
    esac
  done <<< "$plan"
  return 0
}

# 계약 9-4절 ③~⑦ — 판정 쪽이 ①②를 통과시킨 명령 하나. rc 는 remote_help_tick 과 같다.
remote_help_run_one() {   # <seq> <exec> <칸 종류> <이름> [인자…]
  local seq="$1" exec="$2" kinds="$3" prog shown i rel="" first="" dir leaf="" pidx=-1
  shift 3
  local -a toks=("$@") args=()
  # ③ <path> 칸 = 링크를 푼 실제 경로가 작업 폴더 안인지 본다 · 표 v1 은 줄마다 <path> 가 많아야 하나다
  #   없는 성분 뒤에 성분이 더 남으면(없는 폴더 안의 이름) 열 실제 부모가 없다 — 표시·번호 기록 **전에** path_missing
  i=1
  while [ "$i" -lt "${#toks[@]}" ]; do
    if [ "${kinds:$((i - 1)):1}" = "p" ]; then
      if [ -n "$rel" ]; then
        remote_help_ack "$seq" declined path_count
        return $?
      fi
      remote_help_confine "${toks[$i]}"
      case $? in
        0) ;;
        2) remote_help_ack "$seq" declined path_missing; return $? ;;
        *) remote_help_ack "$seq" declined path_outside; return $? ;;
      esac
      rel="${toks[$i]}"
      first="$RH_REAL"
      pidx=${#args[@]}
    fi
    args+=("${toks[$i]}")
    i=$((i + 1))
  done
  # 실행 파일은 번들 표의 것만 — cys 는 절대 경로 후보에서만 찾는다(PATH 조회 없음)
  case "$exec" in
    cys) prog="$(remote_help_cys_path)" || { remote_help_ack "$seq" declined cys_not_found; return $?; } ;;
    /*)  prog="$exec" ;;
    *)   remote_help_ack "$seq" declined exec; return $? ;;
  esac
  # ④ 명령 글 = argv 를 공백 한 칸으로 이은 것 · 확인 대기 없이 창에 찍는다
  shown="${toks[0]}"
  i=1
  while [ "$i" -lt "${#toks[@]}" ]; do shown="$shown ${toks[$i]}"; i=$((i + 1)); done
  say "     운영팀 명령: $shown"
  # ⑤ 번호를 실행 **전에** 파일에 남긴다 — 이미 있으면 다시 돌리지 않는다 · 못 남기면 실행 0
  #   다른 창이 같은 기록을 쓰는 중이라 잠금을 못 잡으면 실행하지 않고 거절한다(policy:seq_lock)
  remote_help_record "$seq"
  case "$RH_RECORD" in
    OK) ;;
    ALREADY) return 0 ;;
    LOCKED) remote_help_ack "$seq" declined seq_lock; return $? ;;
    *) say "     실행 기록을 남기지 못해 이 명령을 실행하지 않고 멈춥니다."; return 2 ;;
  esac
  # ⑥-a 경로를 **실행 직전에 한 번 더** 푼다 — 처음과 다르면(그 사이 링크가 생겼다) 실행하지 않는다
  dir="$(cd -P -- "$JARVIS_HOME" 2>/dev/null && pwd -P)" || dir=""
  if [ -n "$rel" ]; then
    if ! remote_help_confine "$rel" || [ "$RH_REAL" != "$first" ]; then
      remote_help_ack "$seq" declined path_changed
      return $?
    fi
    dir="$(dirname -- "$RH_REAL")"
    leaf="$(basename -- "$RH_REAL")"
  fi
  if [ -z "$dir" ]; then
    remote_help_ack "$seq" declined path_outside
    return $?
  fi
  # ⑥-b 셸 없이 · 60초 상한 · 실제 부모 폴더에서 마지막 성분을 **열고 · 연 것의 정체를 대조하고 · 연 것을** 명령에 준다
  remote_help_launch "$dir" "$leaf" "$pidx" "$prog" ${args[@]+"${args[@]}"}
  if [ -n "$RH_REFUSED" ]; then
    remote_help_ack "$seq" declined "$RH_REFUSED"
    return $?
  fi
  # ⑦
  remote_help_ack "$seq" ran "$RH_RC" "$RH_TIMEDOUT"
}

remote_help_confine() {   # <작업 폴더 기준 상대 경로> → RH_REAL · rc 1 = 밖(끊어진 링크 포함) · rc 2 = 없는 폴더 안의 이름(path_missing)
  local root cur rest seg next real t l i
  RH_REAL=""
  root="$(cd -P -- "$JARVIS_HOME" 2>/dev/null && pwd -P)" || return 1
  [ -n "$root" ] || return 1
  cur="$root"
  rest="$1"
  while [ -n "$rest" ]; do
    case "$rest" in
      */*) seg="${rest%%/*}"; rest="${rest#*/}" ;;
      *)   seg="$rest"; rest="" ;;
    esac
    next="$cur/$seg"
    if [ ! -e "$next" ] && [ ! -L "$next" ]; then
      # 아직 없는 성분은 링크일 수 없다 — 단 마지막 성분일 때만 붙인다(그 뒤에 성분이 더 남으면 열 실제 부모가 없다)
      [ -z "$rest" ] || return 2
      RH_REAL="$next"
      return 0
    fi
    [ -e "$next" ] || return 1          # 끊어진 링크(또는 고리) = 밖
    if [ -d "$next" ]; then
      real="$(cd -P -- "$next" 2>/dev/null && pwd -P)" || return 1
    else
      t="$next"
      i=0
      while [ -L "$t" ]; do
        i=$((i + 1))
        [ "$i" -le 40 ] || return 1
        l="$(readlink -- "$t")" || return 1
        case "$l" in /*) t="$l" ;; *) t="$(dirname -- "$t")/$l" ;; esac
      done
      real="$(cd -P -- "$(dirname -- "$t")" 2>/dev/null && pwd -P)" || return 1
      real="$real/$(basename -- "$t")"
    fi
    # 경로 성분 경계 — `install-jarvis-evil` 은 `install-jarvis` 안이 아니다
    case "$real" in "$root"|"$root"/*) ;; *) return 1 ;; esac
    cur="$real"
  done
  RH_REAL="$cur"
  return 0
}

remote_help_cys_path() {   # 표 9-2절 「실행 대상」 — 절대 경로 후보만 본다
  local c
  for c in "$HOME/.local/bin/cys" "/usr/local/bin/cys" "/Applications/cys.app/Contents/MacOS/cys"; do
    [ -x "$c" ] && { printf '%s\n' "$c"; return 0; }
  done
  return 1
}

# ⑤ 실행 번호 기록 — 두 창(또는 두 번 뜬 설치기)이 같은 번호를 동시에 남기지 못하게 잠근다(검토 지적: 잠금 없이 둘이 함께 부르면 둘 다 OK).
#   잠금 = `mkdir`(원자) · 못 잡으면 0.1초씩 최대 2초 · 그래도 못 잡으면 LOCKED(실행하지 않는다).
#   끝나지 못한 잠금(프로세스가 강제로 죽은 자리)은 30초가 지나면 치운다 — 한 번의 기록은 1초 안에 끝난다(치우지 않으면 그 뒤 모든 명령이 거절된다).
#   ⚠전원 단절 내구성(정직): 기록은 임시 파일에 쓴 뒤 이름을 바꾼다(반쯤 쓴 파일은 없다). `sync` 는 디스크 전체를 비우는 명령이라 쓰지 않는다 —
#     쓴 직후 전원이 끊기면 기록이 사라져 재부팅 뒤 같은 번호가 한 번 더 돌 수 있다(표 v1 은 읽기뿐이다).
remote_help_record() {   # <seq> → RH_RECORD = OK · ALREADY · LOCKED · FAIL
  local lock="$REMOTE_HELP_SEQ_FILE.lock" tries=0
  RH_RECORD=FAIL
  until mkdir "$lock" 2>/dev/null; do
    [ -n "$(find "$lock" -maxdepth 0 -mtime +30s 2>/dev/null)" ] && rmdir "$lock" 2>/dev/null
    tries=$((tries + 1))
    [ "$tries" -le 20 ] || { RH_RECORD=LOCKED; return 0; }
    sleep 0.1
  done
  RH_LOCK_HELD=1
  RH_RECORD="$(RH_SEQ_FILE="$REMOTE_HELP_SEQ_FILE" remote_help_js record "$1" 2>/dev/null)"
  [ -n "$RH_RECORD" ] || RH_RECORD=FAIL
  rmdir "$lock" 2>/dev/null
  RH_LOCK_HELD=0
  return 0
}

# ⑥ 경로 칸은 **이름을 검사하고 그 이름을 넘기지 않는다 — 열고, 연 것의 정체를 대조하고, 연 것을 넘긴다**(검토 지적 BLOCKER).
#   이름을 넘기면 프로그램이 그 이름을 다시 열고, 검사와 여는 순간 사이에 바꿔 끼운 링크를 따라간다.
#   ①실제 부모 폴더로 들어가 그곳이 맞는지 `pwd -P` 로 본다 ②마지막 성분이 링크면 거부 ③fd 3 으로 연다
#   ④fd 3 이 가리키는 파일과 그 이름이 **지금** 가리키는 파일의 장치:아이노드가 같고, 그 이름이 여전히 링크가 아닐 때만
#   ⑤프로그램에는 이름이 아니라 `/dev/fd/3` 을 준다(`tail`·`shasum`·`ls` 가 fd 를 읽는다 · `test -e` 는 fd 가 열렸는가가 답).
#     폴더는 `/dev/fd/3` 으로 목록을 못 낸다(이 기계 실측 「Not a directory」) — 그 안으로 들어가 들어간 곳이 연 것과 같은지 대조한 뒤 `.` 를 준다.
#   ⚠연 것의 정체는 `stat <&3`(fstat)로 잰다 — `stat /dev/fd/3` 은 장치 번호가 fd 파일시스템의 것으로 나와 늘 어긋난다(이 기계 실측).
#   못 열면(없는 이름·읽기 권한 없음) 이름을 다시 열지 않는다 — 프로그램이 닫힌 fd 3 을 받아 스스로 실패를 말한다(`test -e` 는 rc 1).
# 잔여(정직): 같은 계정이 작업 폴더 안에 **밖 파일의 하드 링크**를 만들면 정체가 같아 통과한다 — 그 권한이면 명령 없이도 그 파일을 읽는다.
remote_help_open_leaf() {   # <마지막 성분> — 지금 폴더에서 fd 3 으로 연다(시험이 이 자리를 바꿔 끼워 「여는 순간의 교체」를 재현한다)
  { exec 3< "./$1"; } 2>/dev/null
}

remote_help_launch() {   # <실제 폴더> <마지막 성분 또는 빈 글> <경로 칸 번호(없으면 -1)> <프로그램 절대 경로> [인자…] → RH_RC · RH_TIMEDOUT · RH_REFUSED · 출력 = $RH_TMP/out
  local dir="$1" leaf="$2" pidx="$3" prog="$4" pid watch rc
  shift 4
  local -a args=("$@")
  rm -f "$RH_TMP/timedout" "$RH_TMP/refused"
  RH_REFUSED=""
  (
    refuse() { printf '%s' "$1" > "$RH_TMP/refused"; exit 126; }
    # 표의 읽기 명령이 cys 데몬을 깨우지 않게 한다(설치기가 자기 조회에 거는 것과 같은 안전장치 · 검토 지적)
    export CYS_NO_AUTOSTART=1
    exec 3<&-
    cd -P -- "$dir" 2>/dev/null || refuse path_missing
    [ "$(pwd -P)" = "$dir" ] || refuse path_changed
    if [ -n "$leaf" ]; then
      [ -L "$leaf" ] && refuse path_changed
      if remote_help_open_leaf "$leaf"; then
        opened="$(/usr/bin/stat -f '%d:%i' <&3 2>/dev/null)"
        # 연 뒤의 불일치·실패 = path_outside(계약 9-4 ④ — 연 것이 작업 폴더 안의 그 이름이라고 말할 수 없다)
        [ -n "$opened" ] && [ "$opened" = "$(/usr/bin/stat -L -f '%d:%i' "./$leaf" 2>/dev/null)" ] || refuse path_outside
        [ -L "$leaf" ] && refuse path_outside
        if [ "$(/usr/bin/stat -f '%HT' <&3 2>/dev/null)" = "Directory" ]; then
          { cd -P -- "./$leaf" 2>/dev/null && [ "$(/usr/bin/stat -f '%d:%i' . 2>/dev/null)" = "$opened" ]; } || refuse path_outside
          args[$pidx]="."
        else
          args[$pidx]="/dev/fd/3"
        fi
      else
        args[$pidx]="/dev/fd/3"
      fi
    fi
    exec "$prog" ${args[@]+"${args[@]}"}
  ) </dev/null >"$RH_TMP/out.raw" 2>&1 &
  pid=$!
  # ⚠`&&` 로 잇는다 — 끝난 뒤 sleep 을 죽이면 `;` 는 다음 줄로 넘어가 멀쩡히 끝난 명령을 「시간 초과」로 적는다(첫 시험에서 7건 실측)
  ( sleep "$REMOTE_HELP_CMD_TIMEOUT" && { : > "$RH_TMP/timedout"; kill -9 "$pid" 2>/dev/null; } ) </dev/null >/dev/null 2>&1 &
  watch=$!
  wait "$pid"
  rc=$?
  pkill -P "$watch" 2>/dev/null
  kill "$watch" 2>/dev/null
  wait "$watch" 2>/dev/null
  [ -f "$RH_TMP/refused" ] && RH_REFUSED="$(cat "$RH_TMP/refused")"
  iconv -f UTF-8 -t UTF-8 -c < "$RH_TMP/out.raw" > "$RH_TMP/out" 2>/dev/null || : > "$RH_TMP/out"
  if [ -f "$RH_TMP/timedout" ]; then RH_TIMEDOUT=1; RH_RC=null; else RH_TIMEDOUT=0; RH_RC="$rc"; fi
}

remote_help_ack() {   # <seq> declined <rule> · <seq> ran <rc|null> <시간 초과 0|1> → rc 3 = 서버가 닫았다(410)
  if [ "$2" = "declined" ]; then
    RH_ACK_OUT="$RH_TMP/ack.json" remote_help_js ack "$1" declined "$3" >/dev/null 2>&1 || return 0
  else
    RH_OUTPUT_FILE="$RH_TMP/out" RH_NAMES_FILE="$RH_TMP/names" RH_ACK_OUT="$RH_TMP/ack.json" \
      remote_help_js ack "$1" ran "$3" "$4" "$REMOTE_HELP_CMD_TIMEOUT" >/dev/null 2>&1 || return 0
  fi
  remote_help_http POST "/api/help/$RH_ID/ack" "$RH_TMP/ack.json"
  [ "$RH_HTTP" = "410" ] && return 3
  return 0
}

# 창이 닫히거나(HUP) 중단되면(INT·TERM) 닫기를 **시도**하고 끝낸다 — 실패해도 이 프로세스가 끝나므로 명령은 더 돌지 않는다.
remote_help_on_signal() {
  trap - HUP INT TERM
  # 기록 잠금을 쥔 채 멈추면 다음 실행의 명령이 모두 거절된다 — 쥔 것은 풀고 나간다
  [ "$RH_LOCK_HELD" = "1" ] && rmdir "$REMOTE_HELP_SEQ_FILE.lock" 2>/dev/null
  log "remote help: stopped by signal - close"
  if [ -n "$RH_ID" ] && [ -n "$RH_TMP" ]; then RH_HTTP_MAX=5 remote_help_http POST "/api/help/$RH_ID/close"; fi
  [ -n "$RH_TMP" ] && rm -rf "$RH_TMP"
  rm -f "$ROWS_FILE"
  exit 129
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
say "     $REMOTE_HELP_NOTICE"
NOTICE_SHOWN=1
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
