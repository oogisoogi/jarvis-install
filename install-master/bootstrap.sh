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
# v0.3.18 — 참가자 클로드는 stable 채널로 깔고 그 채널에 묶는다(윈판 $ClaudeChannel 과 같은 값 · 공식 문서 code.claude.com/docs/en/setup 2026-09-15 확인:
#   설치기 `bash -s stable` · 설정 열쇠 settings.json "autoUpdatesChannel": "stable" — 자동 판올림으로 수업 중 화면이 바뀌지 않게).
CLAUDE_CHANNEL="stable"
CLAUDE_DIRECT_BASE_URL="https://downloads.claude.ai/claude-code-releases"   # 공식 설치기(install.sh)가 받는 자리 그대로(DOWNLOAD_BASE_URL · 2026-09-16 실물) — 상한에 닿았을 때만 쓴다
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
# 지난 실행이 끝을 알리지 않고 사라졌으면 그때 남은 것은 기록 파일의 마지막 줄뿐이다 — 이번 실행이 한 줄이라도 적기 전에 떠 둔다(ps1 165~186).
#   PREV_RUN_STATE = 마지막 머리글(=== 자비스 설치 도우미) 뒤에서 어디까지 갔나 · 뒤에 적힌 줄이 앞의 것을 이긴다
#   '' 모름 · closed 끝맺음까지 · wait 원격 해결 대기 중 · answer 처방을 받은 뒤 · ended 원격 해결이 스스로 끝남
PREV_TAIL=""; PREV_RUN_STATE=""; PREV_RUN_CODE=""
if [ -f "$LOG_FILE" ]; then
  PREV_TAIL="$(grep -v '^$' "$LOG_FILE" 2>/dev/null | tail -1)"
  PREV_RUN_STATE="$(perl -CSD -Mutf8 -ne '
    push @l, $_;
    END {
      my $from = 0; for (my $i = $#l; $i >= 0; $i--) { if ($l[$i] =~ /=== 자비스 설치 도우미 /) { $from = $i; last } }
      my $s = "";
      for my $i ($from .. $#l) { my $ln = $l[$i];
        if    ($ln =~ /^\S+\s+다음에 할 일: /) { $s = "closed" }
        elsif ($ln =~ /^\S+\s+remote help: report [A-Z2-9]{8}/) { $s = "wait" }
        elsif ($ln =~ /^\S+\s+처방(\(조치 [0-9]+\))?: /) { $s = "answer" }
        elsif ($ln =~ /^\S+\s+(원격 해결 시간\([0-9]+분\)이 끝나 멈춥니다|원격 해결이 끝났습니다)/) { $s = "ended" }
      }
      print $s;
    }' "$LOG_FILE" 2>/dev/null)"
fi
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
#
# 🔴★2026-09-15 전환 — 애플 실리콘 맥도 **우리 릴리스**(oogisoogi/cys-ro)를 받는다.
#   까닭: 윈도우만 우리 빌드이고 맥은 원작자 판(0.14.33)이라, 같은 날 같은 방에서 두 OS 참가자가
#   **서로 다른 cys** 를 쓰고 있었다(맥 참가자가 판본을 헷갈린 사례가 있었다).
#   우리 맥 빌드는 유료 공증 없이 **자체 서명(cys-local)** 이다. 그래서 원작자 dmg 의 설치 도우미를 쓰지 않고
#   **zip 받기 → 풀기 → 격리 속성 지우기 → 서명 무결성 확인 → 한 번에 바꿔 넣기** 로 깐다.
#   (curl 로 받은 파일에는 격리 속성이 붙지 않지만, 붙어 있어도 지운다 — 사람이 「열기」를 누를 일이 없게.)
#   크기·지문·CDHash 는 우리 설치본을 `ditto -c -k --keepParent` 로 묶은 그 자산에서 쟀다(2026-09-15).
#   ⚠원작자 판으로 가는 길은 **둘뿐**이다: ⑴인텔 맥(우리 빌드는 arm64 전용) ⑵우리 자산이 404 일 때.
# ★★릴리스 핀 자리(v0.3.18) — 다음 판(cysr 1.0.0 · 앱+팩 단일 판번)으로 올릴 때 고치는 곳은 **이 CYS_FORK_* 블록뿐**이다:
#   CYS_DISPLAY_NAME · CYS_FORK_VERSION · CYS_FORK_FILE(자산 이름이 바뀌면) · CYS_FORK_BYTES · CYS_FORK_SHA256 · CYS_FORK_CDHASH.
#   ⚠맥은 판번 대조에 CDHash(설치된 프로그램의 내용 지문)를 이미 함께 쓴다 — 판번이 같아도 CDHash 가 다르면 바꿔 넣는다(step_install_cys).
#   화면 머리글 = 「<이름> <판> · 설치 도우미 <설치기 판>」(설치기 판 = INSTALLER_VERSION · 별도 semver).
CYS_DISPLAY_NAME="cysr"
CYS_FORK_VERSION="1.0.2"
CYS_FORK_DIR="https://github.com/oogisoogi/cys-ro/releases/download/v${CYS_FORK_VERSION}/"
# 1.0.1 부터 zip 최상위 = cysr.app(안의 실행 파일 = Contents/MacOS/cys · cys-app · cysd · CFBundleName cysr · 로컬 빌드 실측 2026-09-16).
CYS_FORK_FILE="cysr-macos-arm64-v${CYS_FORK_VERSION}.zip"
# ✅아래 크기·지문·CDHash = v1.0.2 발행(2026-09-18 11:23 · Latest) 뒤 **실측으로 채웠다**(installer-0325-r3 · 앞 판 값(v1.0.1)을 대신한다).
#   출처 = 릴리스 SHA256SUMS.txt(그 파일 자신의 sha256 = 17ad2595213ae3868fb56820cd6c7aabca2d66f9c7130d618e4cc57d38f4897e) · 크기는 릴리스 자산 목록과 내려받은 파일 양쪽에서 쟀다.
#   CDHash 는 **발행된 그 zip** 을 풀어(ditto -x -k) `codesign -dvvv` 로 쟀다(서명 = cys-local · zip 최상위 = cysr.app 하나).
CYS_FORK_BYTES="471899457"
CYS_FORK_SHA256="86ba5a68f9d07f4598094841209ee5471d3fa5396c2f5a93f49a787620ba389a"
# 설치된 프로그램이 「바로 이 판」인가를 가르는 값. 판본 숫자는 원작자 판도 같은 숫자를 쓸 수 있어서
#   숫자만 보면 **원작자 판을 우리 판으로 읽고 건너뛴다**(어제 원작자 판을 깐 맥이 그대로 남는다).
CYS_FORK_CDHASH="17d240abc9d7a9261d410e58616ff1aeb1848c2e"
# 저희 판이 놓이는 자리 = /Applications/cysr.app · 옛 이름 자리 = /Applications/cys.app(0.14.x·1.0.0 이 깔린 자리 · 원작자 판도 이 이름).
CYS_FORK_APP="/Applications/cysr.app"
CYS_OLD_APP="/Applications/cys.app"
cys_app_dir() { if [ "${CYS_KIND:-}" = "fork" ]; then printf '%s\n' "$CYS_FORK_APP"; else printf '%s\n' "$CYS_OLD_APP"; fi; }
CYS_FORK_PAGE="https://github.com/oogisoogi/cys-ro/releases/tag/v${CYS_FORK_VERSION}"
# 원작자 판(위 두 경우에만 쓴다)
CYS_VERSION="0.14.33"
CYS_DOWNLOAD_DIR="https://github.com/idoforgod/cys-terminal/releases/download/v${CYS_VERSION}/"
cys_use_vendor_pin() {
  CYS_KIND="vendor"; CYS_PIN_VERSION="$CYS_VERSION"; CYS_MANUAL_URL="$CYS_SITE_URL"
  case "$(uname -m)" in
    arm64) CYS_MAC_FILE="cys_${CYS_VERSION}_aarch64.dmg"; CYS_MAC_BYTES=272977882
           CYS_MAC_SHA256="3919ce1cad7ac834584951190420f92d6ba86b3a2343451829e784aadf3153df" ;;
    *)     CYS_MAC_FILE="cys_${CYS_VERSION}_x64.dmg";     CYS_MAC_BYTES=269923933
           CYS_MAC_SHA256="7ec9e557f9185d03416f949341f5b7b4dc3367aaf72206e754c736d4e7395153" ;;
  esac
  CYS_DOWNLOAD_URL="${CYS_DOWNLOAD_DIR}${CYS_MAC_FILE}"
}
cys_use_fork_pin() {
  CYS_KIND="fork"; CYS_PIN_VERSION="$CYS_FORK_VERSION"; CYS_MANUAL_URL="$CYS_FORK_PAGE"
  CYS_MAC_FILE="$CYS_FORK_FILE"; CYS_MAC_BYTES="$CYS_FORK_BYTES"; CYS_MAC_SHA256="$CYS_FORK_SHA256"
  CYS_DOWNLOAD_URL="${CYS_FORK_DIR}${CYS_MAC_FILE}"
}
# 원작자 판으로 간 까닭(intel · missing) — 사람에게 한 번 말하고 기록에 남긴다.
CYS_VENDOR_WHY=""
if [ "$(uname -m)" = "arm64" ]; then
  cys_use_fork_pin
else
  cys_use_vendor_pin; CYS_VENDOR_WHY="intel"
fi

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
LOGIN_STATUS_WAIT_SEC=20   # 초 — 확인 명령(auth status) 한 번의 상한(ps1 $LoginStatusWaitMs 20000 · 벤더 도구가 멈춰도 폴링 상한이 살아 있게)
LOGIN_ASK_WAIT_SEC=60      # 초 — 상한에 닿았을 때 숫자 하나를 기다리는 상한(ps1 $LoginAskWaitSec)

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
say() { printf '%s\n' "$*"; log "$*"; say_error_text_hook "$*"; }   # 오류 글 촉발(error-text) = 윈판 Say 안 ⓕ③ 동형
# 화면에만 말한다 — 기록에는 안 남긴다.
#   ★왜 가르는가: 60초마다 같은 줄이 `bootstrap.log` 를 가득 채우면, 나중에 그 파일을 읽는 사람이
#   **진짜 사건을 못 찾는다.** 기다림은 「지금 보는 사람」을 위한 말이고, 기록은 「나중 사람」을 위한 것이다.
tell() { printf '%s\n' "$*" >&2; }

# ══ 진행 자동 전송·진단 자료(증거) — 맥 (TICKET=mac-parity-t2-telemetry · 2026-09-16) ═══════════════════════════════
# 정본 = 윈도우판 bootstrap.ps1(5a1cd67) 4888~5471줄 — Get-InstallId · Send-Progress · Protect-EvidenceText · Get-EvidenceText ·
#   Send-EvidenceOnce · Update-StepBaselines · Test-StepSlow · Send-EvidenceEvent · Send-EvidenceImage(s) · Receive-CaptureRequest ·
#   Invoke-CaptureRequested · Send-CaptureEvidence · Send-PostInstallEvidence 를 **함수 단위로** 옮겼다(이름은 셸 관례로 바꿨다).
#   왜: 09-16 실기에서 맥판은 진행 전송이 0 이었다(윈판 호출 23곳) — 맥에서 막히면 운영팀은 사람이 말해 줄 때까지 아무것도 몰랐다.
# 원칙(계약 1절) = fail-open: 전송 실패·서버 장애·시간 초과는 설치를 절대 막지 않는다 · 경고는 기록에 실행당 한 줄.
#   ⚠이 구역의 함수는 표준 출력에 아무것도 흘리지 않는다 — 부르는 쪽이 $(…) 안에서 불러도 값이 섞이지 않게(윈판 같은 함정).
# 🔴갈리는 자리(OS 차이) — 전부 「왜」 를 함께 적는다:
#   ⑴JSON·마스킹은 macOS 기본 osascript(JavaScript)가 한다 — 깨끗한 맥에는 jq·python 이 없다(원격 해결 구역과 같은 까닭).
#     마스킹 식은 대조표 tests/mask-vectors.json 의 **js_regex** 를 글자 그대로 옮겼다(윈판은 ps1_regex · 서버 정본은 src/mask.ts).
#   ⑵설치 창 글자 = 기록 파일(bootstrap.log) — 맥에는 Start-Transcript 가 없다(윈판도 트랜스크립트가 없으면 같은 파일을 쓴다).
#   ⑶창 그림 = screencapture -l <창 번호>. 창 번호는 CoreGraphics 창 목록(osascript 안 ObjC 다리 · AppleEvent 아님)으로 찾는다.
#     ⛔앱 이름으로 AppleEvent 를 보내지 않는다(2026-09-16 실측: cys 앱에 보낸 AppleEvent 가 -1712 로 약 2분 멈췄다).
#   ⑷로그인 창·첫 자리는 맥에서 그림이 없다 — 맥의 로그인은 설치 창 안에서 진행되고, 첫 자리는 앱 창 안의 한 칸이다.
#   ⑸🔴창 그림은 **기본 꺼짐**이다(TICKET=mac-parity-t4-fix N1 · master 판정 「화면 기록 권한 미요청」).
#     screencapture 는 화면 기록 권한이 없는 맥에서 macOS 「화면 기록 허용」 창을 띄울 수 있다 — 처음 설치하는 사람 앞에 창이 하나 더 뜬다.
#     권한을 묻지 않고 확인하는 API 를 쓰지 않는다(깨끗한 맥에 pyobjc·swift 가 없고 결과가 기계마다 갈린다) ⇒ 켜는 길 = JARVIS_EVIDENCE_IMAGES=1 하나.
#     꺼져 있으면 촬영기를 부르지 않고 기록 1줄만 남긴다 · 서버로는 글자 증거만 간다(그림 자리를 받아도 올릴 그림이 없다).
PROGRESS_TIMEOUT_SEC=3                    # 요청 하나의 상한(윈판 $ProgressTimeoutSec · 계약 1절)
EVIDENCE_MAX_NAMES=64                     # 서버 scrub.ts MAX_NAMES 와 같은 값
EVIDENCE_SOURCE_BYTES=60000               # 기록 파일 끝에서 읽는 양(윈판 $EvidenceSourceBytes)
EVIDENCE_TEXT_BYTES=32000                 # 마스킹 뒤 보내는 양(윈판 $EvidenceTextBytes)
EVIDENCE_IMAGE_MAX_BYTES=1572864          # 한 장 1.5MB(계약 3절 · 넘으면 413)
EVIDENCE_IMAGE_CAP=12                     # 설치당 하루 12장(계약 3절 · 넘으면 429 image_cap)
EVIDENCE_IMAGE_KINDS=" installer_window login_window app_window first_pane "
EVIDENCE_HOOK_ERROR_PATTERN='Stop hook error|hook error'
EVIDENCE_IMAGES_OFF_LOGGED=0              # 「창 그림 = 꺼짐」 기록은 설치당 한 줄(⑸)
SCREENCAPTURE_BIN="${JARVIS_TEST_SCREENCAPTURE:-/usr/sbin/screencapture}"   # 시험이 가짜 촬영기로 바꿔 「불렸는가」를 잰다(운영 맥에서 진짜를 부르지 않게)
INSTALL_ID=""
PROGRESS_WARNED=0                         # 전송 실패 경고는 실행당 한 번만 기록한다
EVIDENCE_SENT=" "                         # 이유|단계 → 이미 보냈다(Send-EvidenceOnce)
CAPTURE_SENT=" "                          # 이유|단계 → 이미 보냈다(Send-CaptureEvidence · post-install)
EVIDENCE_IMAGE_SENT=0
EVIDENCE_IMAGE_DONE=0                     # 오늘 몫을 다 썼다(429 image_cap) — 더 시도하지 않는다
EVIDENCE_IMAGE_WARNED=0
EV_SEQ=""                                 # 마지막 증거 이벤트가 받은 그림 자리(번호·토큰) — 비었으면 그림을 안 보낸다
EV_TOKEN=""
CAPTURE_IN_SAY=0                          # say 안에서 다시 say 로 들어가는 것을 막는다
CAPTURE_READY=0                           # 이 구역이 다 읽힌 뒤에만 say 가 오류 글(error-text)을 본다
CAPTURE_REQUESTED=""                      # 운영팀이 청한 촬영(계약 5절) — 받은 그 자리에서 쓰고 버린다
STEP_BASELINES=""                         # 「단계<탭>초」 줄 — ⛔코드에 고정표를 두지 않는다(계약 4절)
STEP_BASELINE_NOTE="not-fetched"          # not-fetched | ok:<칸수> | http:<코드> | empty | error | skip:*

progress_url() { printf '%s' "${JARVIS_PROGRESS_URL:-$HELP_API_URL/api/progress}"; }   # 흉내가 바꿔치면 그림·기준선도 같은 곳으로 간다

progress_tmp() { # → PG_TMP(본인만 읽는 임시 폴더) · rc 1 = 못 만들었다
  PG_TMP=""
  if [ -d "$JARVIS_HOME" ]; then PG_TMP="$(umask 077; mktemp -d "$JARVIS_HOME/.progress.XXXXXX" 2>/dev/null)"; fi
  [ -n "$PG_TMP" ] || PG_TMP="$(umask 077; mktemp -d "${TMPDIR:-/tmp}/jarvis-progress.XXXXXX" 2>/dev/null)"
  [ -n "$PG_TMP" ] && [ -d "$PG_TMP" ]
}

progress_js() { /usr/bin/osascript -l JavaScript -e "$PROGRESS_JS" "$@" </dev/null; }

install_id_ensure() { # → INSTALL_ID — 첫 실행에 무작위 번호를 만들어 두고 이후 재사용한다(영숫자·_·- 8~36자 · 서버 허용 범위)
  [ -n "$INSTALL_ID" ] && return 0
  local f="$JARVIS_HOME/install-id" id=""
  [ -f "$f" ] && IFS= read -r id < "$f" 2>/dev/null
  id="$(printf '%s' "$id" | tr -d ' \t\r')"
  # 모양 검사를 로케일에 맡기지 않는다 — 한국어 로케일에서 [A-Za-z] 범위가 무엇을 품는지 흔들린다(LC_ALL=C 로 지운 뒤 남는 것이 없어야 한다).
  if [ ${#id} -lt 8 ] || [ ${#id} -gt 36 ] || [ -n "$(printf '%s' "$id" | LC_ALL=C tr -d '0-9A-Za-z_-')" ]; then
    id="$(head -c 32 /dev/urandom 2>/dev/null | base64 2>/dev/null | LC_ALL=C tr -dc '0-9A-Za-z' | cut -c1-24)"
    [ ${#id} -ge 8 ] || id="m$(date +%s)$$"   # 난수를 못 읽는 기계 — 그래도 번호 없이 보내지는 않는다
    ( umask 077; printf '%s\n' "$id" > "$f" ) 2>/dev/null   # 윈판은 CRLF · 맥은 LF(읽을 때 둘 다 걷는다)
  fi
  INSTALL_ID="$id"
}

progress_post() { # progress_post <url> <본문 파일> <응답 파일> [curl 인자…] → PG_HTTP(000 = 닿지 못함) · PG_ERR
  local url="$1" body="$2" out="$3"
  shift 3
  PG_HTTP="$(curl -sS -m "$PROGRESS_TIMEOUT_SEC" -X POST "$@" --data-binary "@$body" -o "$out" -w '%{http_code}' "$url" </dev/null 2>"$out.err")"
  case "$PG_HTTP" in [1-5][0-9][0-9]) ;; *) PG_HTTP="000" ;; esac
  PG_ERR="$(head -1 "$out.err" 2>/dev/null)"
}

progress_warn_once() { # <무엇> — 윈판 문구 그대로(progress send failed (fail-open) - …)
  [ "$PROGRESS_WARNED" = "1" ] && return 0
  PROGRESS_WARNED=1
  log "progress send failed (fail-open) - $1"
}

progress_env_fields() { # 살핌(info) 이벤트의 env 칸 — 계약 2절. 못 읽는 값은 넣지 않는다(fail-open).
  # ⚠서버가 받는 열쇠는 claude_ver·cys_ver·win_build·ps_ver·av·browser·mac_ver·admin 이다(web-install telemetry.ts ENV_TEXT_KEYS).
  #   맥의 운영체제 판본은 mac_ver 칸에 싣는다(서버 계약 칸 · web-install c14d66d) — win_build 에 맥 값을 넣지 않는다(이름이 거짓말이 된다).
  local cv="" vv="" mv="" cli=""
  if command -v claude >/dev/null 2>&1; then cv="$(claude --version 2>/dev/null | head -1)"; fi
  for cli in "${CYS_CLI:-}" "$(cys_app_dir 2>/dev/null)/Contents/MacOS/cys"; do
    [ -n "$cli" ] && [ -x "$cli" ] && { vv="$(cys_version_line "$cli" 2>/dev/null)"; break; }
  done
  mv="$(/usr/bin/sw_vers -productVersion 2>/dev/null | head -1)"
  PG_ENV_CLAUDE_VER="$cv"
  PG_ENV_CYS_VER="$vv"
  PG_ENV_MAC_VER="$mv"
  if id -Gn 2>/dev/null | tr ' ' '\n' | grep -qx admin; then PG_ENV_ADMIN=true; else PG_ENV_ADMIN=false; fi
}

progress_send() { # progress_send <단계> <event> [elapsed 초] [detail] [env] — 윈판 Send-Progress($step,$ev,$elapsed,$detail,$envInfo) 동형
  # 다섯째 인자가 「env」 이면 환경 칸을 싣는다(윈판은 표를 넘긴다 — 셸은 표를 못 넘겨 표지 한 낱말로 받는다).
  # ⚠윈판의 여섯째 인자($extra)는 이 판에서 부르는 자리가 0 이라 옮기지 않았다(증거는 evidence_event_send 가 따로 보낸다).
  [ "$MODE" = "full" ] || return 0
  [ "${JARVIS_NO_PROGRESS:-}" = "1" ] && return 0   # 흉내 시험이 실제 서버로 나가지 않게 하는 레버(사람이 쓰는 길이 아니다)
  {
    local step="${1:-}" ev="${2:-}" el="${3:-}" detail="${4:-}" withenv="${5:-}"
    install_id_ensure
    progress_tmp || { progress_warn_once "임시 폴더를 못 만들었다"; return 0; }
    PG_ENV_CLAUDE_VER=""; PG_ENV_CYS_VER=""; PG_ENV_MAC_VER=""; PG_ENV_ADMIN=""
    [ "$withenv" = "env" ] && progress_env_fields
    if PG_INSTALL_ID="$INSTALL_ID" PG_VERSION="$INSTALLER_VERSION" PG_STEP="$step" PG_EVENT="$ev" PG_ELAPSED="$el" \
         PG_DETAIL="$detail" PG_WITH_ENV="$withenv" PG_ENV_CLAUDE_VER="$PG_ENV_CLAUDE_VER" PG_ENV_CYS_VER="$PG_ENV_CYS_VER" PG_ENV_MAC_VER="$PG_ENV_MAC_VER" \
         PG_ENV_ADMIN="$PG_ENV_ADMIN" PG_OUT="$PG_TMP/body.json" progress_js body; then
      progress_post "$(progress_url)" "$PG_TMP/body.json" "$PG_TMP/resp" -H 'content-type: application/json; charset=utf-8'
      case "$PG_HTTP" in
        2??) capture_receive "$PG_TMP/resp" ;;   # 운영팀이 청한 촬영은 이 답에 실려 온다(계약 5절 ① · 하트비트가 곧 수신함)
        *)   progress_warn_once "http $PG_HTTP ${PG_ERR}" ;;
      esac
    else
      progress_warn_once "본문을 꾸리지 못했다"
    fi
    rm -rf "$PG_TMP"
  } >/dev/null 2>&1
  return 0
}

evidence_mask_line() { # evidence_mask_line <글> → 표준 출력 = 마스킹한 글(한 줄 기록용) · 못 가리면 집 경로만이라도 가린다
  local t
  progress_tmp || { redact "$1"; return 0; }
  printf '%s' "$1" > "$PG_TMP/in"
  if PG_IN="$PG_TMP/in" PG_OUT="$PG_TMP/out" progress_js mask >/dev/null 2>&1 && [ -f "$PG_TMP/out" ]; then
    t="$(cat "$PG_TMP/out")"; printf '%s' "$t"
  else
    redact "$1"
  fi
  rm -rf "$PG_TMP"
}

evidence_text_file() { # evidence_text_file <만들 파일> [이유] [사유 글] — 윈판 Get-EvidenceText(+Send-CaptureEvidence 머리) · rc 0 = 파일에 글이 있다
  local out="$1" reason="${2:-}" detail="${3:-}" size cut=0
  : > "$out"
  [ -f "$LOG_FILE" ] || return 1
  size="$(/usr/bin/stat -f %z "$LOG_FILE" 2>/dev/null)"
  [ -n "$size" ] && [ "$size" -gt "$EVIDENCE_SOURCE_BYTES" ] && cut=1
  tail -c "$EVIDENCE_SOURCE_BYTES" "$LOG_FILE" 2>/dev/null | iconv -f UTF-8 -t UTF-8 -c > "$out.src" 2>/dev/null
  PG_SRC="$out.src" PG_CUT="$cut" PG_REASON="$reason" PG_DETAIL="$detail" PG_OUT="$out" progress_js evtext >/dev/null 2>&1
  rm -f "$out.src"
  [ -s "$out" ]
}

evidence_event_send() { # evidence_event_send <이유> [글 파일] — 윈판 Send-EvidenceEvent · → EV_SEQ·EV_TOKEN(그림 자리) · rc 0 = 자리를 받았다
  EV_SEQ=""; EV_TOKEN=""
  [ "$MODE" = "full" ] || return 1
  [ "${JARVIS_NO_PROGRESS:-}" = "1" ] && return 1
  local reason="$1" tf="${2:-}" dir line
  install_id_ensure
  progress_tmp || return 1
  dir="$PG_TMP"
  # ⚠글은 선택이다 — 빈 글을 보내면 400 이라 아예 칸을 빼고 보낸다.
  [ -n "$tf" ] && [ ! -s "$tf" ] && tf=""
  if ! PG_INSTALL_ID="$INSTALL_ID" PG_VERSION="$INSTALLER_VERSION" PG_STEP="$(current_step)" PG_EVENT=evidence \
         PG_REASON="$reason" PG_TEXT_FILE="$tf" PG_OUT="$dir/body.json" progress_js body >/dev/null 2>&1; then
    progress_warn_once "증거 본문을 꾸리지 못했다"; rm -rf "$dir"; return 1
  fi
  progress_post "$(progress_url)" "$dir/body.json" "$dir/resp" -H 'content-type: application/json; charset=utf-8'
  case "$PG_HTTP" in
    2??) ;;
    *) progress_warn_once "http $PG_HTTP ${PG_ERR}"; rm -rf "$dir"; return 1 ;;
  esac
  capture_receive "$dir/resp"
  while IFS="$(printf '\t')" read -r k v; do
    case "$k" in seq) EV_SEQ="$v" ;; token) EV_TOKEN="$v" ;; esac
  done <<EOF_EV_RESP
$(PG_RESP="$dir/resp" progress_js slot 2>/dev/null)
EOF_EV_RESP
  rm -rf "$dir"
  [ -n "$EV_SEQ" ] && [ -n "$EV_TOKEN" ]
}

evidence_window_id() { # evidence_window_id <종류> → 표준 출력 = 창 번호(없으면 빈 글 · 까닭은 기록에)
  local kind="$1" pids="" p n=0 app out why
  case "$kind" in
    installer_window)
      [ -n "${JARVIS_CAPTURE_WINDOW_ID:-}" ] && { printf '%s' "$JARVIS_CAPTURE_WINDOW_ID"; return 0; }
      # 설치 창 = 이 셸을 띄운 프로그램의 창. 조상 프로세스 번호를 모아 넘긴다.
      p=$$
      while [ -n "$p" ] && [ "$p" -gt 1 ] 2>/dev/null && [ "$n" -lt 30 ]; do
        pids="$pids $p"; p="$(ps -o ppid= -p "$p" 2>/dev/null | tr -d ' ')"; n=$((n + 1))
      done ;;
    app_window)
      [ -n "${JARVIS_CAPTURE_APP_WINDOW_ID:-}" ] && { printf '%s' "$JARVIS_CAPTURE_APP_WINDOW_ID"; return 0; }
      app="$(cys_app_dir 2>/dev/null)"
      [ -n "$app" ] || { log "app window skip (우리가 깐 자리를 모른다)"; return 0; } ;;
    *) return 0 ;;
  esac
  out="$(PG_KIND="$kind" PG_PIDS="$pids" PG_APP_DIR="${app:-}" perl -e 'alarm shift; exec @ARGV' 10 \
         /usr/bin/osascript -l JavaScript -e "$PROGRESS_JS" windows </dev/null 2>/dev/null)"
  why="$(printf '%s\n' "$out" | sed -n 's/^why	//p' | head -1)"
  out="$(printf '%s\n' "$out" | sed -n 's/^window	//p' | head -1)"
  [ -n "$out" ] || log "$kind skip ($why)"
  printf '%s' "$out"
}

evidence_kind_jpeg() { # evidence_kind_jpeg <종류> <만들 파일> — 윈판 Get-EvidenceKindJpeg · rc 0 = 상한 안의 그림 파일이 생겼다
  local kind="$1" out="$2" wid raw w q
  # ⛔모르는 이름에는 아무것도 주지 않는다(전체 화면으로 대신하는 길을 만들지 않는다 — 서버는 그것을 가려낼 수 없다).
  case "$kind" in
    installer_window|app_window) ;;
    login_window) log "login_window skip (맥의 로그인은 설치 창 안에서 진행된다 — 따로 찍을 창이 없다)"; return 1 ;;
    first_pane)   log "first_pane skip (맥에서도 첫 자리는 앱 창 안의 한 칸이라 따로 찍을 창이 없다)"; return 1 ;;
    *)            log "evidence image skip (모르는 종류): $kind"; return 1 ;;
  esac
  # 🔴⑸ 기본 꺼짐 — 켜라는 말(=1)이 없으면 촬영기도 창 번호 찾기도 부르지 않는다.
  if [ "${JARVIS_EVIDENCE_IMAGES:-}" != "1" ]; then
    [ "$EVIDENCE_IMAGES_OFF_LOGGED" = "1" ] || { log "창 그림 = 꺼짐(기본) · 글자 증거만 (켜기: JARVIS_EVIDENCE_IMAGES=1)"; EVIDENCE_IMAGES_OFF_LOGGED=1; }
    return 1
  fi
  [ -x "$SCREENCAPTURE_BIN" ] || { log "capture skip (screencapture 없음): $kind"; return 1; }
  wid="$(evidence_window_id "$kind")"
  [ -n "$wid" ] || return 1
  raw="$out.raw.jpg"
  # 상한을 걸고 부른다 — 맥에는 timeout(1) 이 없다. 화면 기록 권한이 없으면 파일이 안 생긴다(2026-09-16 실측: rc 1 · could not create image from window).
  perl -e 'alarm shift; exec @ARGV' 10 "$SCREENCAPTURE_BIN" -x -o -t jpg -l "$wid" "$raw" >/dev/null 2>&1
  if [ ! -s "$raw" ]; then
    rm -f "$raw"
    log "window capture skip (그림이 안 만들어졌다 · 화면 기록 권한이 없으면 이렇게 된다): $kind"
    return 1
  fi
  # 🔴한 장 1.5MB 를 넘으면 서버가 413 으로 돌려보낸다 ⇒ 가로 1280 · 품질 60 부터 낮춰 가며 다시 만든다(윈판 같은 네 걸음).
  w="$(sips -g pixelWidth "$raw" 2>/dev/null | awk '/pixelWidth/ {print $2}')"
  for q in "1280 60" "1280 40" "960 40" "800 30"; do
    set -- $q
    if [ -n "$w" ] && [ "$w" -gt "$1" ] 2>/dev/null; then
      sips -s format jpeg -s formatOptions "$2" --resampleWidth "$1" "$raw" --out "$out" >/dev/null 2>&1
    else
      sips -s format jpeg -s formatOptions "$2" "$raw" --out "$out" >/dev/null 2>&1
    fi
    if [ -s "$out" ] && [ "$(/usr/bin/stat -f %z "$out" 2>/dev/null)" -le "$EVIDENCE_IMAGE_MAX_BYTES" ]; then
      rm -f "$raw"; return 0
    fi
  done
  rm -f "$raw" "$out"
  log "window capture skip (가장 낮은 품질로도 한 장 상한을 못 맞췄다)"
  return 1
}

evidence_image_send() { # evidence_image_send <종류> <그림 파일> — 윈판 Send-EvidenceImage · rc 0 = 보냈다 · fail-open
  local kind="$1" f="$2" size dir u
  [ -n "$EV_SEQ" ] && [ -n "$EV_TOKEN" ] || return 1
  [ "$EVIDENCE_IMAGE_DONE" = "1" ] && return 1
  case "$EVIDENCE_IMAGE_KINDS" in *" $kind "*) ;; *) log "evidence image skip (계약에 없는 종류): $kind"; return 1 ;; esac
  [ -s "$f" ] || { log "evidence image skip (그림이 없다): $kind"; return 1; }
  size="$(/usr/bin/stat -f %z "$f" 2>/dev/null)"
  [ "${size:-0}" -le "$EVIDENCE_IMAGE_MAX_BYTES" ] || { log "evidence image skip (${size}B > 한 장 상한): $kind"; return 1; }
  [ "$EVIDENCE_IMAGE_SENT" -lt "$EVIDENCE_IMAGE_CAP" ] || { log "evidence image skip (설치당 ${EVIDENCE_IMAGE_CAP}장 상한): $kind"; return 1; }
  progress_tmp || return 1
  dir="$PG_TMP"
  # 토큰은 명령줄에 싣지 않는다(ps 에 보인다) — 본인만 읽는 머리글 파일로 넘긴다(원격 해결 구역과 같은 방식).
  ( umask 077; printf 'x-progress-upload: %s\n' "$EV_TOKEN" > "$dir/upload-header" ) 2>/dev/null || { rm -rf "$dir"; return 1; }
  u="$(progress_url)/evidence/$EV_SEQ/image?kind=$kind&filename=$kind.jpg"
  # ⛔길이 머리글을 손으로 넣지 않는다 — curl 이 본문 길이로 넣는다(윈판 2026-09-16 실측 사고와 같은 자리).
  progress_post "$u" "$f" "$dir/resp" -H "@$dir/upload-header" -H 'content-type: image/jpeg'
  case "$PG_HTTP" in
    2??)
      EVIDENCE_IMAGE_SENT=$((EVIDENCE_IMAGE_SENT + 1))
      log "evidence image sent: $kind ${size}B (${EVIDENCE_IMAGE_SENT}/${EVIDENCE_IMAGE_CAP})"
      rm -rf "$dir"; return 0 ;;
    429)
      # 🔴429 는 두 종류다 — 오늘 몫을 다 쓴 것(image_cap)이면 더 시도하지 않는다(재시도해도 같은 답이다).
      if grep -q 'image_cap' "$dir/resp" 2>/dev/null; then
        EVIDENCE_IMAGE_DONE=1
        log "evidence image: 오늘 몫을 다 썼다(image_cap) — 이 실행에서는 더 올리지 않는다"
        rm -rf "$dir"; return 1
      fi ;;
  esac
  if [ "$EVIDENCE_IMAGE_WARNED" != "1" ]; then
    EVIDENCE_IMAGE_WARNED=1
    log "evidence image failed (fail-open) $PG_HTTP - ${PG_ERR}"
  fi
  rm -rf "$dir"
  return 1
}

evidence_images_send() { # evidence_images_send <종류…> — 윈판 Send-EvidenceImages
  local k f
  [ -n "$EV_SEQ" ] && [ -n "$EV_TOKEN" ] || return 0
  for k in "$@"; do
    f="$JARVIS_HOME/capture-$(current_step | tr '/' '-')-$k-$((EVIDENCE_IMAGE_SENT + 1)).jpg"
    if evidence_kind_jpeg "$k" "$f"; then
      # 보내지 못한 그림은 이 기계에 남긴다(나중에 사람이 보낼 수 있게) · 보낸 그림은 지운다(가려지지 않은 그림을 쌓지 않는다).
      evidence_image_send "$k" "$f" && rm -f "$f"
    fi
  done
  return 0
}

current_step() { # 지금까지 기록에 찍힌 마지막 [n/10] — 실패 전송이 「어느 단계에서 막혔나」를 싣게 한다(윈판 Get-CurrentStep)
  local n
  n="$(grep -oE '\[[0-9]{1,2}/[0-9]{1,2}\]' "$LOG_FILE" 2>/dev/null | tail -1 | tr -d '[]')"
  printf '%s\n' "${n:-0/10}"
}

evidence_once() { # evidence_once <이유> — 윈판 Send-EvidenceOnce · (이유 × 단계) 한 번 · fail-open
  {
    local reason="$1" key tf bytes=0
    key="${reason}|$(current_step)"
    case "$EVIDENCE_SENT" in *" $key "*) return 0 ;; esac
    EVIDENCE_SENT="$EVIDENCE_SENT$key "
    progress_tmp || return 0
    tf="$PG_TMP/evidence.txt"
    evidence_text_file "$tf" && bytes="$(/usr/bin/stat -f %z "$tf" 2>/dev/null)"
    if evidence_event_send "$reason" "$tf"; then
      evidence_images_send installer_window   # 맥의 기본 = 설치 창(로그인 창이 따로 없다 · 윈판 Get-DefaultEvidenceKinds)
    fi
    rm -rf "$(dirname "$tf")"
    log "evidence sent: $key ${bytes:-0}B"
  } >/dev/null 2>&1
  return 0
}

capture_receive() { # capture_receive <응답 파일> — 윈판 Receive-CaptureRequest · 받으면 그 자리에서 쓰고 버린다
  # ⛔받았다는 확인을 서버에 돌려주지 않고 재시도·영속화도 만들지 않는다. sig 는 우리가 검사하지 않는다(키가 없다).
  local kinds
  grep -q '"capture"[[:space:]]*:[[:space:]]*{' "$1" 2>/dev/null || return 0
  kinds="$(PG_RESP="$1" progress_js capture 2>/dev/null)"
  if [ -z "$kinds" ]; then log "capture request: 찍을 수 있는 종류가 없다"; return 0; fi
  CAPTURE_REQUESTED="$kinds"
  log "capture request 받음: $(printf '%s' "$kinds" | tr ' ' ',')"
}

capture_requested_run() { # 윈판 Invoke-CaptureRequested — 받아 둔 촬영 요청이 있으면 그 자리에서 찍어 보낸다(reason=requested · 1회성)
  [ -n "$CAPTURE_REQUESTED" ] || return 0
  {
    local kinds="$CAPTURE_REQUESTED"
    CAPTURE_REQUESTED=""
    if evidence_event_send requested ""; then
      # shellcheck disable=SC2086
      evidence_images_send $kinds
    fi
    log "capture requested 처리: $(printf '%s' "$kinds" | tr ' ' ',')"
  } >/dev/null 2>&1
  return 0
}

step_baselines_update() { # 윈판 Update-StepBaselines — [1/10] 에서 한 번. 못 받으면 표는 비고 「평소의 두 배」 판정은 통째로 잠든다.
  if [ "$MODE" != "full" ]; then STEP_BASELINE_NOTE="skip:mode"; return 0; fi
  if [ "${JARVIS_NO_PROGRESS:-}" = "1" ]; then STEP_BASELINE_NOTE="skip:no-progress"; return 0; fi
  {
    local code n
    if progress_tmp; then
      code="$(curl -sS -m "$PROGRESS_TIMEOUT_SEC" -o "$PG_TMP/resp" -w '%{http_code}' "$(progress_url)/baseline?os=mac" </dev/null 2>/dev/null)"
      case "$code" in
        200)
          STEP_BASELINES="$(PG_RESP="$PG_TMP/resp" progress_js baseline 2>/dev/null)"
          if [ "$?" -ne 0 ]; then STEP_BASELINES=""; STEP_BASELINE_NOTE="error"
          else
            n="$(printf '%s' "$STEP_BASELINES" | grep -c .)"
            if [ "${n:-0}" -gt 0 ]; then STEP_BASELINE_NOTE="ok:$n"; else STEP_BASELINE_NOTE="empty"; fi
          fi ;;
        [1-5][0-9][0-9]) STEP_BASELINE_NOTE="http:$code" ;;
        *) STEP_BASELINE_NOTE="error" ;;
      esac
      rm -rf "$PG_TMP"
    else
      STEP_BASELINE_NOTE="error"
    fi
  } >/dev/null 2>&1
  log "step baseline: $STEP_BASELINE_NOTE (빈 칸 = 그 단계 느림 촉발 꺼짐)"
  return 0
}

step_baseline_sec() { # step_baseline_sec <단계> → 표준 출력 = 기준선 초(정수) · 칸이 없으면 빈 글
  printf '%s\n' "$STEP_BASELINES" | awk -F '\t' -v s="$1" '$1 == s { printf "%d", $2; exit }'
}

step_is_slow() { # step_is_slow <단계> <초> → rc 0 = 기준선의 2배를 넘었다. ★칸이 없으면 거짓 — 「모른다」를 「느리다」로 읽지 않는다.
  printf '%s\n' "$STEP_BASELINES" | awk -F '\t' -v s="$1" -v t="$2" '$1 == s && $2 > 0 { f = (t + 0 > $2 * 2) ? 0 : 1; found = 1; exit } END { exit (found ? f : 1) }'
}

capture_evidence() { # capture_evidence <이유> [사유 글] — 윈판 Send-CaptureEvidence · (이유 × 단계)마다 한 번 · 설치를 막지 않는다
  {
    local reason="$1" detail="${2:-}" key tf
    key="${reason}|$(current_step)"
    case "$CAPTURE_SENT" in *" $key "*) return 0 ;; esac
    CAPTURE_SENT="$CAPTURE_SENT$key "
    progress_tmp || return 0
    tf="$PG_TMP/evidence.txt"
    # 🔴사유 글도 반드시 마스킹한다 — 오류 글 촉발은 화면 줄을 통째로 넘기고 그 줄에는 경로·메일이 들어 있다(evtext 가 머리에 붙인다).
    evidence_text_file "$tf" "$reason" "$detail"
    if evidence_event_send "$reason" "$tf"; then
      evidence_images_send installer_window
    fi
    rm -rf "$(dirname "$tf")"
    # 🔴여기도 마스킹한다 — 이 기록 파일은 사람이 통째로 보낼 수 있다.
    log "capture evidence: $key $(evidence_mask_line "$detail")"
  } >/dev/null 2>&1
  return 0
}

post_install_evidence() { # post_install_evidence <명령> <자리> — 윈판 Send-PostInstallEvidence · [10/10] 각성 판정 직후 한 번
  {
    local cli="$1" ref="$2" scr="" hooks=0 tf
    case "$CAPTURE_SENT" in *" post-install|10/10 "*) return 0 ;; esac
    CAPTURE_SENT="$CAPTURE_SENT""post-install|10/10 "
    progress_tmp || return 0
    tf="$PG_TMP/post.txt"
    : > "$tf"
    if [ -n "$ref" ]; then
      scr="$(cys_capped "$CHILD_READ_CAP_SEC" "$cli" read-screen --surface "$ref")"
      if [ -n "$scr" ]; then
        hooks="$(printf '%s\n' "$scr" | grep -cE "$EVIDENCE_HOOK_ERROR_PATTERN" || true)"
        log "post-install evidence: seat=master hook_errors=${hooks:-0}"
        printf 'seat=master\nhook_errors=%s\n%s' "${hooks:-0}" "$(printf '%s\n' "$scr" | tail -n 40)" > "$tf.raw"
        PG_IN="$tf.raw" PG_OUT="$tf" PG_TAIL_BYTES="$EVIDENCE_TEXT_BYTES" progress_js mask >/dev/null 2>&1
        rm -f "$tf.raw"
        # 끝 40줄은 이 기계의 기록에도 남긴다(서버로 못 가도 사람이 볼 수 있게) — 마스킹한 글로.
        while IFS= read -r l; do log "post-install tail: $l"; done < "$tf"
      else
        log "post-install evidence: 화면을 읽지 못했다(자리=$ref)"
      fi
    else
      log "post-install evidence: 자리를 모른다"
    fi
    if evidence_event_send post-install "$tf"; then
      evidence_images_send app_window
    fi
    log "evidence sent: post-install|10/10 text=$(/usr/bin/stat -f %z "$tf" 2>/dev/null || echo 0)B"
    rm -rf "$(dirname "$tf")"
  } >/dev/null 2>&1
  return 0
}

say_error_text_hook() { # say 가 부른다 — 창에 오류 글이 뜨면 그 자리에서 찍는다(윈판 Say 안 ⓕ③ · 이유 × 단계마다 한 번 · fail-open)
  [ "$CAPTURE_READY" = "1" ] || return 0
  [ "$CAPTURE_IN_SAY" = "1" ] && return 0
  # 윈판 -imatch 'error|exception|failed|denied|not recognized' 와 같은 낱말 — 대소문자 무관을 글자 묶음으로 쓴다(grep 을 줄마다 띄우지 않는다).
  case "$1" in
    *[Ee][Rr][Rr][Oo][Rr]*|*[Ee][Xx][Cc][Ee][Pp][Tt][Ii][Oo][Nn]*|*[Ff][Aa][Ii][Ll][Ee][Dd]*|*[Dd][Ee][Nn][Ii][Ee][Dd]*|*[Nn][Oo][Tt]' '[Rr][Ee][Cc][Oo][Gg][Nn][Ii][Zz][Ee][Dd]*) ;;
    *) return 0 ;;
  esac
  CAPTURE_IN_SAY=1
  capture_evidence error-text "$1"
  CAPTURE_IN_SAY=0
  return 0
}

child_stall_evidence() { # child_stall_evidence <역할> <화면 글> — 윈판 Send-ChildStallEvidence · 자리마다 한 번 · reason=stall · fail-open
  {
    local role="$1" key="stall-child-${1}|10/10" tf
    case "$EVIDENCE_SENT" in *" $key "*) return 0 ;; esac
    EVIDENCE_SENT="$EVIDENCE_SENT$key "
    progress_tmp || return 0
    tf="$PG_TMP/child.txt"
    printf 'seat=%s\n%s' "$role" "$(printf '%s\n' "${2:-}" | tail -n 40)" > "$tf.raw"
    PG_IN="$tf.raw" PG_OUT="$tf" PG_TAIL_BYTES="$EVIDENCE_TEXT_BYTES" progress_js mask >/dev/null 2>&1
    evidence_event_send stall "$tf"   # 윈판도 이 자리에서는 그림을 보내지 않는다
    log "evidence sent: $key $(/usr/bin/stat -f %z "$tf" 2>/dev/null || echo 0)B"
    rm -rf "$(dirname "$tf")"
  } >/dev/null 2>&1
  return 0
}

# ── 첨부 (보고가 열린 뒤에만 · 각각 실패해도 다음으로 · 계약 3절 순서) — 윈판 Get-FileBytesCapped·Get-ProcTreeBytes·Send-Attachment·Send-FailAttachments ──
ATTACH_MAX_BYTES=$((900 * 1024))          # 항목 하나의 상한(계약 2절 · 윈판 $AttachMaxBytes)

file_tail_capped() { # file_tail_capped <원본> <상한 바이트> <만들 파일> — 기록·화면 글자는 끝이 중요하다 · rc 0 = 만들었다
  [ -f "$1" ] || return 1
  tail -c "$2" "$1" > "$3" 2>/dev/null && [ -s "$3" ]
}

proc_tree_file() { # proc_tree_file <만들 파일> — 이 설치기 밑에서 도는 프로그램(윈판 Get-ProcTree 동형 · 뿌리 = 이 셸)
  { printf '# 실행 중인 프로그램(뿌리 %s)\n' "$$"
    ps -axo pid=,ppid=,comm= 2>/dev/null | awk -v root="$$" '
      { pid=$1; ppid=$2; $1=""; $2=""; sub(/^[ \t]+/, ""); name[pid]=$0; kids[ppid]=kids[ppid] " " pid }
      function walk(p, d,   n, i, list, pad) {
        pad=""; for (i = 0; i < d; i++) pad = pad "  "
        printf "%s%s %s\n", pad, p, name[p]
        n = split(kids[p], list, " ")
        for (i = 1; i <= n; i++) if (list[i] != "" && d < 20) walk(list[i], d + 1)
      }
      END { if (root in name) walk(root, 0) }'
  } > "$1" 2>/dev/null
  [ -s "$1" ]
}

help_attach() { # help_attach <kind> <파일 이름> <파일> — 윈판 Send-Attachment · rc 0 = 보냈다 · 보고가 없으면 아무것도 안 한다
  local kind="$1" name="$2" f="$3" size
  [ -n "$RH_ID" ] && [ -n "$RH_TMP" ] || return 1
  [ -s "$f" ] || { log "attach skip (empty): $kind"; return 1; }
  size="$(/usr/bin/stat -f %z "$f" 2>/dev/null)"
  [ "${size:-0}" -le "$ATTACH_MAX_BYTES" ] || { log "attach skip (${size}B > cap): $kind"; return 1; }
  # kind·이름은 이 파일이 정한 영문 글자뿐이다 — 이스케이프가 필요 없는 값만 넣는다. 내용은 base64(따옴표·줄바꿈이 없다).
  { printf '{"kind":"%s","filename":"%s","content_b64":"' "$kind" "$name"
    base64 -i "$f" | tr -d '\n'
    printf '"}'
  } > "$RH_TMP/attach.json" 2>/dev/null || { log "attach error (fail-open): $kind - 본문을 꾸리지 못했다"; return 1; }
  remote_help_http POST "/api/help/$RH_ID/attach" "$RH_TMP/attach.json"
  rm -f "$RH_TMP/attach.json"
  if [ "$RH_HTTP" = "201" ]; then log "attach ok: $kind ${size}B"; return 0; fi
  log "attach failed ($RH_HTTP): $kind"
  return 1
}

help_fail_attachments() { # 윈판 Send-FailAttachments — 보고가 열린 직후 부른다 · 계약 3절 순서 · 각각 fail-open
  [ -n "$RH_ID" ] && [ -n "$RH_TMP" ] || return 0
  {
    local d="$RH_TMP/attach"
    mkdir -p "$d" 2>/dev/null
    file_tail_capped "$LOG_FILE" "$ATTACH_MAX_BYTES" "$d/bootstrap.log" && help_attach log_full bootstrap.log "$d/bootstrap.log"
    # 맥에는 트랜스크립트가 없다 — 설치 창 글자는 곧 기록 파일이라(say 가 화면과 기록에 같은 줄을 쓴다) log_full 과 같은 내용이 된다.
    log "attach skip (맥에는 트랜스크립트가 없다 · 설치 창 글자 = log_full): console_text"
    # 🔴전체 화면이 아니라 설치 창 하나다(윈판 v0.3.20 과 같은 규율) · 칸 이름 screen_png 는 서버 계약 그대로 · 파일 이름만 사실대로.
    if evidence_kind_jpeg installer_window "$d/installer-window.jpg"; then
      help_attach screen_png installer-window.jpg "$d/installer-window.jpg"
    fi
    log "attach: login window capture 없음(맥의 로그인은 설치 창 안에서 진행된다 — 따로 찍을 창이 없다)"
    proc_tree_file "$d/proc-tree.txt" && help_attach proc_tree proc-tree.txt "$d/proc-tree.txt"
    file_tail_capped "$REPORT_FILE" "$ATTACH_MAX_BYTES" "$d/env-report.md" && help_attach env_full env-report.md "$d/env-report.md"
    rm -rf "$d"
  } >/dev/null 2>&1
  return 0
}

# 판정 쪽(JavaScript) — 입력은 환경(PG_*)으로 받고, 글은 파일로 돌려준다(표준 출력은 짧은 영문 줄만).
IFS= read -r -d '' PROGRESS_JS <<'EOF_PROGRESS_JS' || true
ObjC.import("Foundation");

function env(name) {
  var value = $.NSProcessInfo.processInfo.environment.objectForKey(name);
  return value.isNil() ? "" : ObjC.unwrap(value);
}
function readText(path) {
  if (!path) return null;
  var text = $.NSString.stringWithContentsOfFileEncodingError(path, $.NSUTF8StringEncoding, null);
  return text.isNil() ? null : ObjC.unwrap(text);
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

// ── 증거 마스킹 — 대조표 tests/mask-vectors.json 의 js_regex 를 글자 그대로(서버 정본 web-install src/mask.ts 8571653) ──
var MASK_RULES = [
  [/[A-Za-z0-9._%+-]{1,64}@[A-Za-z0-9-]{1,63}(?:\.[A-Za-z0-9-]{1,63})*\.[A-Za-z]{2,63}/g, "<EMAIL>"],
  [/\bBearer\s+[A-Za-z0-9._~+/=-]+/gi, "<TOKEN>"],
  [/\bsk-[A-Za-z0-9_-]{8,}/g, "<TOKEN>"],
  [/\b[A-Za-z0-9_-]{20,}#[A-Za-z0-9_-]{8,}\b/g, "<LOGIN_CODE>"],
  [/(Paste code here if prompted\s*>\s*)(\S+)/gi, "$1<LOGIN_CODE>"],
  [/\b([A-Za-z]:(?:\\{1,2}|\/)Users(?:\\{1,2}|\/))([^\\/\r\n"'<>|:*?]+)/gi, "$1<USER>"],
  [/(\/Users\/)([^/\s"'<>]+)/g, "$1<USER>"]
];
var MASK_NAME_LINES = /\b(?:USERNAME|USERPROFILE|LOGNAME|USER|HOME)\b[ \t]*[=:][ \t]*([^\r\n]+)|\bwhoami\b[ \t]*[:=>][ \t]*([^\r\n]+)|(?:^|\n)[ \t]*([A-Za-z][A-Za-z0-9.-]{1,63}\\[A-Za-z0-9._-]{2,63})[ \t]*(?:\r?\n|$)/gi;
var MASK_MAX_NAMES = 64;

function maskEvidenceText(raw) {
  if (!raw) return raw;
  // 순서 = 서버 maskEvidenceText 의 4단계: ①이름은 원문에서 ②구조 규칙 자리에 자리표 ③이름 치환 ④자리표를 표식으로.
  var names = [];
  function add(v) {
    if (names.length >= MASK_MAX_NAMES) return;
    var value = String(v).trim().replace(/["']/g, "");
    if (value.length >= 2 && names.indexOf(value) < 0) names.push(value);
    var segment = (value.split(/[\\/]/).pop() || "").trim();
    if (segment.length >= 2 && names.length < MASK_MAX_NAMES && names.indexOf(segment) < 0) names.push(segment);
  }
  var matches = Array.from(raw.matchAll(MASK_NAME_LINES));
  for (var i = 0; i < matches.length; i += 1) {
    add(matches[i][1] || matches[i][2] || matches[i][3] || "");
    if (names.length >= MASK_MAX_NAMES) break;
  }
  names.sort(function (a, b) { return b.length - a.length; });
  var sentinels = [];
  var text = raw;
  MASK_RULES.forEach(function (rule) {
    text = text.replace(rule[0], function () {
      var groups = Array.prototype.slice.call(arguments, 1, -2);
      var resolved = rule[1].replace(/\$(\d)/g, function (_all, n) { var g = groups[Number(n) - 1]; return g === undefined ? "" : g; });
      sentinels.push(resolved);
      return "\u0000M" + (sentinels.length - 1) + "\u0000";
    });
  });
  if (names.length > 0) {
    var alt = new RegExp(names.map(function (n) { return n.replace(/[.*+?^${}()|[\]\\]/g, "\\$&"); }).join("|"), "g");
    text = text.replace(alt, "<USER>");
  }
  return text.replace(/\u0000M(\d+)\u0000/g, function (_all, n) { return sentinels[Number(n)]; });
}

function isoLocal() {
  var d = new Date();
  function p(n, w) { n = String(n); while (n.length < (w || 2)) n = "0" + n; return n; }
  var off = -d.getTimezoneOffset();
  var sign = off >= 0 ? "+" : "-";
  off = Math.abs(off);
  return d.getFullYear() + "-" + p(d.getMonth() + 1) + "-" + p(d.getDate()) + "T" + p(d.getHours()) + ":" + p(d.getMinutes()) + ":" +
    p(d.getSeconds()) + "." + p(d.getMilliseconds(), 3) + sign + p(Math.floor(off / 60)) + ":" + p(off % 60);
}

var KINDS = ["installer_window", "login_window", "app_window", "first_pane"];

function run(argv) {
  var mode = argv[0];
  if (mode === "body") {
    // 칸 순서 = 윈판 [ordered] 와 같다 — install_id · installer_version · os · step · event · at · (elapsed_s · detail · env) · (reason · text · masked)
    var f = {};
    f.install_id = env("PG_INSTALL_ID");
    f.installer_version = env("PG_VERSION");
    f.os = "mac";
    f.step = env("PG_STEP");
    f.event = env("PG_EVENT");
    f.at = isoLocal();
    var el = env("PG_ELAPSED");
    if (/^[0-9]+$/.test(el)) f.elapsed_s = parseInt(el, 10);
    var detail = env("PG_DETAIL");
    if (detail) f.detail = detail;
    if (env("PG_WITH_ENV") === "env") {
      var e = {};
      if (env("PG_ENV_CLAUDE_VER")) e.claude_ver = env("PG_ENV_CLAUDE_VER");
      if (env("PG_ENV_CYS_VER")) e.cys_ver = env("PG_ENV_CYS_VER");
      if (env("PG_ENV_MAC_VER")) e.mac_ver = env("PG_ENV_MAC_VER");
      if (env("PG_ENV_ADMIN") === "true") e.admin = true;
      else if (env("PG_ENV_ADMIN") === "false") e.admin = false;
      f.env = e;
    }
    if (f.event === "evidence") {
      f.reason = env("PG_REASON");
      var tf = env("PG_TEXT_FILE");
      var t = tf ? readText(tf) : null;
      if (t) { f.text = t; f.masked = true; }
    }
    writeText(env("PG_OUT"), JSON.stringify(f));
    return "";
  }
  if (mode === "mask") {
    var raw = readText(env("PG_IN"));
    if (raw === null) throw new Error("unreadable");
    var masked = maskEvidenceText(raw);
    var cap = parseInt(env("PG_TAIL_BYTES"), 10);
    if (cap > 0) masked = tailBytes(masked, cap);
    writeText(env("PG_OUT"), masked);
    return "";
  }
  if (mode === "evtext") {
    // 윈판 Get-EvidenceText: 끝에서 잘라 읽었으면 첫 줄은 반쪽이다 — 반쪽 토큰이 규칙에 안 걸린 채 나가지 않게 버린다.
    var src = readText(env("PG_SRC"));
    if (src === null) src = "";
    if (src.length > 0 && src.charCodeAt(0) === 0xfeff) src = src.substring(1);
    if (env("PG_CUT") === "1") { var nl = src.indexOf("\n"); src = nl >= 0 ? src.substring(nl + 1) : ""; }
    var body = tailBytes(maskEvidenceText(src), 32000);
    if (env("PG_DETAIL")) {
      // 윈판 Send-CaptureEvidence: 머리 = 마스킹한 「[이유] 사유」 끝 400바이트 + 줄바꿈 + 본문.
      var head = tailBytes(maskEvidenceText("[" + env("PG_REASON") + "] " + env("PG_DETAIL")), 400);
      body = head + "\n" + body;
    }
    if (body.length === 0) return "";
    writeText(env("PG_OUT"), body);
    return "";
  }
  if (mode === "slot" || mode === "capture" || mode === "baseline") {
    var j = JSON.parse(readText(env("PG_RESP")) || "null");
    if (j === null || typeof j !== "object") return "";
    if (mode === "slot") {
      // 번호는 정수 · 토큰은 머리글에 실리므로 모양을 좁힌다(줄바꿈·콜론이 섞인 값이 머리글을 늘리지 못하게).
      var out = [];
      if (typeof j.seq === "number" && isFinite(j.seq) && j.seq >= 0 && Math.floor(j.seq) === j.seq) out.push("seq\t" + j.seq);
      else if (typeof j.seq === "string" && /^[0-9]{1,18}$/.test(j.seq)) out.push("seq\t" + j.seq);
      if (typeof j.upload_token === "string" && /^[A-Za-z0-9_-]{16,256}$/.test(j.upload_token)) out.push("token\t" + j.upload_token);
      return out.join("\n");
    }
    if (mode === "capture") {
      // 모르는 이름은 그것만 건너뛴다(윈판 Receive-CaptureRequest).
      var c = j.capture;
      if (!c || !Array.isArray(c.kinds)) return "";
      var seen = [];
      c.kinds.forEach(function (k) { if (KINDS.indexOf(String(k)) >= 0 && seen.indexOf(String(k)) < 0) seen.push(String(k)); });
      return seen.join(" ");
    }
    // baseline — ⛔median_elapsed_s 가 null 이면 아직 모른다는 뜻이다(내장 기본값으로 대신하지 않는다 · 계약 4절).
    var rows = [];
    (Array.isArray(j.steps) ? j.steps : []).forEach(function (r) {
      if (!r || typeof r.step !== "string" || !/^[0-9]{1,2}\/[0-9]{1,2}$/.test(r.step)) return;
      if (r.median_elapsed_s === null || r.median_elapsed_s === undefined) return;
      var v = Number(r.median_elapsed_s);
      if (!isFinite(v) || v <= 0) return;
      rows.push(r.step + "\t" + v);
    });
    return rows.join("\n");
  }
  if (mode === "windows") {
    // 창 번호 찾기 — CoreGraphics 창 목록(AppleEvent 가 아니다 · 권한 없이도 소유 프로그램 번호·창 번호는 나온다).
    //   ⛔고르지 못하면 찍지 않는다 — 「다른 창은 찍지 않습니다」 약속을 지키는 코드가 여기다(윈판 Get-AppWindowJpeg 와 같은 규율).
    ObjC.import("CoreGraphics");
    ObjC.import("AppKit");
    var kind = env("PG_KIND");
    var list = ObjC.castRefToObject($.CGWindowListCopyWindowInfo(1 | 16, 0));   // 화면에 보이는 창 · 바탕 화면 요소 제외
    var wins = [];
    for (var i = 0; i < list.count; i += 1) {
      var d = list.objectAtIndex(i);
      if (ObjC.unwrap(d.objectForKey("kCGWindowLayer")) !== 0) continue;
      var b = d.objectForKey("kCGWindowBounds");
      if (ObjC.unwrap(b.objectForKey("Width")) < 50 || ObjC.unwrap(b.objectForKey("Height")) < 50) continue;
      wins.push({ pid: ObjC.unwrap(d.objectForKey("kCGWindowOwnerPID")), num: ObjC.unwrap(d.objectForKey("kCGWindowNumber")) });
    }
    if (kind === "installer_window") {
      var pids = env("PG_PIDS").trim().split(/\s+/).map(Number);
      var mine = wins.filter(function (w) { return pids.indexOf(w.pid) >= 0; });
      if (mine.length === 1) return "window\t" + mine[0].num;
      return "why\t" + (mine.length === 0 ? "이 설치를 띄운 프로그램의 창을 못 찾았다" : "그 프로그램의 창이 " + mine.length + "개라 어느 것인지 모른다");
    }
    if (kind === "app_window") {
      var dir = env("PG_APP_DIR").replace(/\/+$/, "");
      for (var k = 0; k < wins.length; k += 1) {
        var app = $.NSRunningApplication.runningApplicationWithProcessIdentifier(wins[k].pid);
        if (!app || app.isNil()) continue;
        var url = app.bundleURL;
        if (!url || url.isNil()) continue;
        if (ObjC.unwrap(url.path) === dir) return "window\t" + wins[k].num;
      }
      return "why\t우리가 깐 자리에서 도는 창을 못 찾았다";
    }
    return "";
  }
  throw new Error("mode");
}
EOF_PROGRESS_JS
CAPTURE_READY=1

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
  [ -n "${LOGIN_CAPPED_MARK:-}" ] && : > "$LOGIN_CAPPED_MARK"   # 본문이 「상한에서 끝났다」를 가르는 표지(이 감시자는 배경 자식이라 변수로는 못 건넨다)
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
    tell "     승인 화면의 「코드」를 복사만 하시면 이 창이 알아서 넣습니다 — 안 되면 이 창을 누르고 ⌘+V 로 붙여넣고 Enter 를 눌러 주십시오."
    tell "     (기다린 지 $(( waited / 60 ))분 · 창을 닫거나 Ctrl-C 를 누르시면 다시 하는 법을 안내합니다)"
    # ps1 2289~2292 — 60초마다 대기 진행을 알린다(서버 쪽이 정체를 알아본다) · 3분 이상 = 정체 증거(한 번)
    #   ★사람에게 하는 말 **뒤에** 보낸다 — 전송은 최대 3초 걸리므로 앞에 두면 안내가 그만큼 늦는다(login-wait-double ③ 이 잡음).
    #   ⚠이 감시자는 배경 자식이다 — 여기서 받은 촬영 요청·증거 중복 표지는 이 자식 안에서만 산다(대기가 끝나면 사라진다).
    progress_send '3/10' 'wait' "$waited" '' ''
    [ "$waited" -ge 180 ] && evidence_once stall
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
  printf '%s\n' "   1) Command(⌘)+스페이스를 누르고 터미널 이라고 치신 뒤 [터미널] 을 여십시오 (맥 터미널 앱 · 검은 창 — cys 창이 아닙니다)."
  printf '%s\n' "   2) 아래 명령을 처음부터 끝까지 끌어 선택한 뒤 Command(⌘)+C 를 누르십시오."
  printf '%s\n' "   3) 터미널 창을 한 번 누르고 Command(⌘)+V 로 붙여넣은 뒤 Enter(리턴) 를 누르십시오."
  printf '%s\n' ""
  printf '%s\n' "$(rerun_cmd)"
  printf '%s\n' ""
  printf '%s\n' "  끝난 단계는 건너뛰고 막힌 자리부터 이어서 갑니다."
  # 09-16 실기: 카톡으로 옮겨 붙인 명령의 -- 가 긴 줄(—)로 바뀌어 실패했다 — 이 화면에서 바로 복사하게 한다.
  printf '%s\n' "  ⚠카톡·메신저·메모 앱을 거쳐 붙이면 기호(-- · 따옴표)가 다른 글자로 바뀌어 실패합니다. 이 화면에서 바로 복사해 주십시오."
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
  progress_send "$(current_step)" fail "" "$1"   # 막힌 자리를 자동으로 알린다(fail-open · 윈판 Write-JCode)
  evidence_once fail                               # 실패 증거(설치 창 끝부분 · 마스킹 뒤)
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
                  '화면에 보이는 https:// 로 시작하는 로그인 주소를 복사해' '로그인된 브라우저 주소창에 붙여넣어 주십시오.' ;;
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
  log "다음에 할 일: $NEXT_STEP"   # 다음 실행의 show_prev_run_note 가 「끝맺음까지 갔다」를 가르는 줄(ps1 Say 는 화면·기록 둘 다 쓴다)
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
      grep -v -e '^- 진단 코드: ' -e '^- 같은 진단 코드: ' -e '^- 이전 보고: ' -e '^- 지난 실행 진단 코드' "$REPORT_FILE" > "$REPORT_FILE.tmp" 2>/dev/null &&
        {
          printf '%s\n' "- 진단 코드: **$J_CODE** (${HELP_CODE_URL}${J_CODE})"
          if [ -n "$PREV_RUN_CODE" ]; then printf '%s\n' "- 지난 실행 진단 코드(참고 · 이번 끝의 코드가 아님): $PREV_RUN_CODE"; fi
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
  printf '계속하려면 「지웁니다」라고 입력해 주십시오(그만두시려면 그냥 Enter): '
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
  cysapp="없음"; { [ -d /Applications/cysr.app ] || [ -d /Applications/cys.app ]; } && cysapp="있음"
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
  [ -d /Applications/cysr.app ] && app_cysd="/Applications/cysr.app/Contents/MacOS/cysd"
  local link_state link_enum link_note
  if [ -e /usr/local/bin/cysd ] && [ -e /usr/local/bin/cys ]; then
    link_state="유효"; link_enum="ok"; link_note="-"
  elif [ -x "$app_cysd" ]; then
    link_state="cysd 링크 끊어짐 · 앱 내부 실행 파일은 있음"
    link_enum="blocked"
    link_note="★고칠 필요 없다 — 앱 안 실경로($app_cysd)를 직접 부르면 된다(관리자 권한 불요). 링크 자체를 고치는 것은 관리자 일이라 우리가 하지 않는다"
  elif [ -e /usr/local/bin/cys ] || [ -d /Applications/cys.app ] || [ -d /Applications/cysr.app ]; then
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

  # (installer-speed-pin-0320) [8/10] 이 방금 돌린 자가진단이 있으면 그 출력을 쓴다 — 같은 명령을 한 실행에 두 번 부르지 않는다.
  if [ -n "$DOCTOR_TEXT" ]; then v="$(printf '%s\n' "$DOCTOR_TEXT" | grep '^요약' | head -1)"
  else v="$(cys doctor 2>/dev/null | grep '^요약' | head -1)"; fi
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
    if [ "${DAEMON_TEMPORARY:-0}" = "1" ]; then   # ps1 1411~1417 — 앱을 직접 열어 켠 실행
      printf -- '- ⓘ **cys 를 직접 열어 켰습니다.** %s\n' "$(cys_autostart_words "$AUTOSTART_STATE")"
      printf -- '  다음에 컴퓨터를 켜시면 **cys 를 한 번 열어 주시면** 됩니다 — 그러면 그때부터 다시 돕니다. 따로 하실 일은 없습니다.\n'
    fi
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
      # 「어느 창에서」를 적는다(09-16 실기 — 사람이 cys 창에 설치 명령을 쳤다 · TICKET=mac-parity-t1-core)
      printf -- '- 명령은 **맥 터미널 앱(검은 창)** 에서 실행하십시오 — cys 창이 아닙니다.\n'
      printf -- '\n```\n%s\n```\n' "$(rerun_cmd)"
    else
      printf -- '- 막힌 단계 없음.\n'
      printf -- '- 이제 **cys 창(제목 jarvis)** 에서 자비스와 이어서 이야기하시면 됩니다. 설치 창(검은 터미널)은 닫으셔도 됩니다.\n'
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
# ── [2/10] 공식 설치기가 상한에 닿았을 때 — ps1 Get-ProcTree 1540 · Add-ReportLines · Write-ClaudeInstallDiag 1603 · Stop-ProcTree 1633 ·
#    Wait-ProcBounded 1642 · Install-ClaudeDirect 1655 의 맥 짝 ─────────────────────────────────────────────
#   🔴앞 판은 `curl | bash` 를 **상한 없이** 앞에 두고 기다렸다(curl 의 600초는 스크립트 받기만 묶는다 — 그 안의 본체 받기·설치는 안 묶인다).
#   ⇒ 윈판과 같이 ⑴설치기를 배경에 두고 30초마다 한 줄 + 진행 「대기」 ⑵상한(10분)이면 무엇이 살아 있었는지 적고 ⑶우리가 띄운 설치기와 그 자식만 끄고
#     ⑷같은 공식 자리(install.sh 가 받는 곳)에서 판본·해시·본체를 직접 받아 해시를 대조한 뒤 설치를 이어 간다.
#   ⚠배경으로 두면 Ctrl-C(SIGINT)가 설치기에 안 닿는다(비대화 셸의 배경 자식은 SIGINT 를 무시) ⇒ 이 단계 동안만 trap 으로 받아 설치기 나무를 끄고 끝낸다.
#   ⚠맥에는 윈판의 「백신 창 제목」·「파일 잠김」 판정이 없다(그 창·잠금 개념이 없다) — 그 두 줄은 옮기지 않는다.
CLAUDE_INSTALL_WAIT_SEC=600          # 클로드 설치 상한(ps1 $ClaudeInstallWaitMs 600000)
CLAUDE_DIRECT_INSTALL_WAIT_SEC=180   # 받은 파일로 공식 설치를 한 번 더 해 볼 때의 상한(ps1 $ClaudeDirectInstallWaitMs)
CLAUDE_VERSION_WAIT_SEC=90           # 제자리에 둔 파일이 판본을 답하기까지의 상한(ps1 $ClaudeVersionWaitMs)
INSTALL_NOTE_EVERY_SEC=30            # 기다리는 동안 몇 초마다 한 줄을 적는가(ps1 $InstallNoteEverySec)
DIAG_TREE=""
get_proc_tree() { # get_proc_tree <pid> → 줄마다 「번호<TAB>부모<TAB>깊이<TAB>시작<TAB>이름」(자식·손자 · 깊이 6까지) · 못 읽으면 빈 글
  ps -axo pid=,ppid=,start=,comm= 2>/dev/null | awk -v root="$1" '
    { pid[NR] = $1; pp[NR] = $2; st[NR] = $3; nm = $0; sub(/^[ \t]*[0-9]+[ \t]+[0-9]+[ \t]+[^ \t]+[ \t]+/, "", nm); name[NR] = nm }
    END {
      front[root] = 1
      for (d = 1; d <= 6; d++) {
        n = 0; split("", nxt)
        for (i = 1; i <= NR; i++) if ((pp[i] in front) && pid[i] != pp[i] && !(pid[i] in seen)) {
          printf "%s\t%s\t%d\t%s\t%s\n", pid[i], pp[i], d, st[i], name[i]; nxt[pid[i]] = 1; seen[pid[i]] = 1; n++
        }
        if (n == 0) break
        split("", front); for (k in nxt) front[k] = 1
      }
    }'
}
write_claude_install_diag() { # write_claude_install_diag <pid> <어디서> → DIAG_TREE(끄는 데 쓴다) · 기록·환경 보고에 같은 네 줄 아닌 세 줄
  local pid="$1" where="$2" words="없음(또는 읽지 못함)" exe="$HOME/.local/bin/claude" exe_words="없음" dls="" l
  DIAG_TREE="$(get_proc_tree "$pid")"
  [ -n "$DIAG_TREE" ] && words="$(printf '%s\n' "$DIAG_TREE" | awk -F'\t' '{ printf "%s%s(번호 %s · 부모 %s · 시작 %s)", (NR > 1 ? " · " : ""), $5, $1, $2, $4 }')"
  [ -e "$exe" ] && exe_words="있음 · $(/usr/bin/stat -f %z "$exe" 2>/dev/null || echo '?')바이트"
  dls="$(ls -l "$HOME/.claude/downloads" 2>/dev/null | awk '$NF ~ /^claude-/ { printf "%s%s %s바이트", (n++ ? " · " : ""), $NF, $5 }')"
  set -- "설치기 프로세스 번호 $pid · 자식: $words" "~/.local/bin/claude: $exe_words" "공식 설치기가 받던 파일(~/.claude/downloads): ${dls:-없음}"
  for l in "$@"; do log "install hold diag ($where): $(redact "$l")"; done
  add_report_lines "" "## [2/10] 설치가 상한에 닿았을 때 본 것 ($where)" "$(for l in "$@"; do printf -- '- %s\n' "$(redact "$l")"; done)"
}
stop_proc_tree() { # stop_proc_tree <pid> <나무> — 깊은 자식부터 끄고 마지막에 본인(우리가 띄운 설치기와 그 자식만)
  local pid="$1" tree="$2" p n=0 i=0 exited=False
  # 셸이 끈 작업마다 「Killed: 9 …(명령 전문)」을 화면에 찍는다 — 사람에게는 고장으로 읽힌다 ⇒ 끄는 동안만 셸의 오류 출력을 닫는다
  exec 3>&2 2>/dev/null
  for p in $(printf '%s\n' "$tree" | awk -F'\t' 'NF >= 3 { print $3 "\t" $1 }' | sort -t "$(printf '\t')" -k1,1nr | cut -f2); do
    kill -KILL "$p" 2>/dev/null; n=$((n + 1))
  done
  kill -KILL "$pid" 2>/dev/null
  while [ "$i" -lt 5 ] && kill -0 "$pid" 2>/dev/null; do sleep 1; i=$((i + 1)); done
  kill -0 "$pid" 2>/dev/null || exited=True
  wait "$pid" 2>/dev/null
  sleep 0 ; exec 2>&3 3>&-
  log "install hold: stopped installer $pid and $n child process(es) - exited=$exited"
}
wait_proc_bounded() { # wait_proc_bounded <pid> <상한 초> <안내> → rc 0 = 상한 안에 끝났다 · rc 1 = 상한에 닿았다
  local pid="$1" cap="$2" label="$3" w=0 since=0
  while kill -0 "$pid" 2>/dev/null; do
    sleep 1; w=$((w + 1)); since=$((since + 1))
    [ "$w" -ge "$cap" ] && return 1
    if [ "$since" -ge "$INSTALL_NOTE_EVERY_SEC" ]; then
      since=0
      say "     $label ($((w / 60))분 $((w % 60))초 지남 · 최대 $((cap / 60))분)"
    fi
  done
  return 0
}
install_claude_direct() { # rc 0 = 클로드가 ~/.local/bin 에서 판본을 답했다 · rc 1 = 못 했다(까닭은 화면·기록에)
  local arch platform ver man sum size=0 dl got exe="$HOME/.local/bin/claude" step5="not-run" ip rc t0 try placed=0 vtext
  case "$(uname -m)" in
    arm64) arch=arm64 ;;
    x86_64) arch=x64; [ "$(sysctl -n sysctl.proc_translated 2>/dev/null)" = "1" ] && arch=arm64 ;;   # 로제타 아래 셸이면 본디 arm64 를 받는다(install.sh 같음)
    *) say "     이 컴퓨터의 칩 종류($(uname -m))에 맞는 파일이 공식 자리에 없습니다."; log "install direct: unsupported arch $(uname -m)"; return 1 ;;
  esac
  platform="darwin-$arch"
  # ① 판본
  ver="$(curl -fsSL --max-time 60 "$CLAUDE_DIRECT_BASE_URL/$CLAUDE_CHANNEL" 2>/dev/null | tr -d '[:space:]')"
  if ! [[ "$ver" =~ ^[0-9]+\.[0-9]+\.[0-9]+(-[0-9A-Za-z.]+)?$ ]]; then
    say "     공식 자리에서 판본 번호를 읽지 못했습니다."
    log "install direct: step1 latest unreadable (${#ver} chars)"
    return 1
  fi
  # ② 해시 — 못 읽으면 쓰지 않는다
  man="$(curl -fsSL --max-time 60 "$CLAUDE_DIRECT_BASE_URL/$ver/manifest.json" 2>/dev/null | tr -d '\n')"
  sum=""
  if [[ "$man" =~ \"$platform\"[[:space:]]*:[[:space:]]*[{][^{}]*\"checksum\"[[:space:]]*:[[:space:]]*\"([a-f0-9]{64})\" ]]; then sum="${BASH_REMATCH[1]}"; fi
  if [[ "$man" =~ \"$platform\"[[:space:]]*:[[:space:]]*[{][^{}]*\"size\"[[:space:]]*:[[:space:]]*([0-9]+) ]]; then size="${BASH_REMATCH[1]}"; fi
  if [ -z "$sum" ]; then
    say "     공식 자리에서 파일 확인값(해시)을 읽지 못했습니다 — 확인 없이 설치하지 않습니다."
    log "install direct: step2 manifest checksum unreadable for $ver $platform"
    return 1
  fi
  # ③ 받기
  mkdir -p "$JARVIS_HOME/dl" 2>/dev/null
  dl="$JARVIS_HOME/dl/claude-$ver-$platform"
  rm -f "$dl"
  say "     공식 자리에서 클로드 $ver 파일을 받습니다 (약 $((size / 1048576))MB · 보통 1~3분)."
  t0="$(date +%s)"
  curl -fsSL --max-time 900 -o "$dl" "$CLAUDE_DIRECT_BASE_URL/$ver/$platform/claude" 2>/dev/null; rc=$?
  if [ "$rc" -ne 0 ]; then
    rm -f "$dl"
    say "     파일을 받지 못했습니다: 받기 종료 코드 $rc"
    log "install direct: step3 download failed - curl rc=$rc"
    return 1
  fi
  log "install direct: step3 download ok $ver in $(( $(date +%s) - t0 ))s"
  # ④ 해시 대조 — 못 재면 쓰지 않는다
  got="$(shasum -a 256 "$dl" 2>/dev/null | cut -d' ' -f1)"
  if [ -z "$got" ]; then
    rm -f "$dl"; say "     받은 파일의 확인값(해시)을 잴 수 없어 그 파일은 쓰지 않았습니다."; log "install direct: step4 checksum unmeasurable"; return 1
  fi
  if [ "$got" != "$sum" ]; then
    rm -f "$dl"; say "     받은 파일의 확인값(해시)이 공식 값과 다릅니다 — 그 파일은 쓰지 않았습니다."; log "install direct: step4 checksum mismatch got=$got want=$sum"; return 1
  fi
  log "install direct: step4 checksum ok"
  chmod +x "$dl" 2>/dev/null
  # ⑤ 받은 파일로 공식 설치를 짧은 상한으로 한 번 — 되면 셸 연동·자동 판올림 준비까지 공식 그대로 깔린다
  "$dl" install "$CLAUDE_CHANNEL" </dev/null & ip=$!
  if wait_proc_bounded "$ip" "$CLAUDE_DIRECT_INSTALL_WAIT_SEC" "받은 파일로 설치하는 중입니다"; then
    wait "$ip"; step5="rc=$?"
  else
    step5="timeout $((CLAUDE_DIRECT_INSTALL_WAIT_SEC / 60))min"
    write_claude_install_diag "$ip" "⑤ 받은 파일로 설치"
    stop_proc_tree "$ip" "$DIAG_TREE"
  fi
  log "install direct: step5 install $CLAUDE_CHANNEL $step5"
  # ⑤가 끝나고 파일이 제자리에 있으면 그대로 쓴다 · 아니면 받은 파일을 제자리에 둔다(옮기는 동안만 .jarvis-new)
  if ! { [ "$step5" = "rc=0" ] && [ -e "$exe" ]; }; then
    mkdir -p "$(dirname "$exe")" 2>/dev/null
    for try in 1 2; do
      if cp "$dl" "$exe.jarvis-new" 2>/dev/null && chmod +x "$exe.jarvis-new" && mv -f "$exe.jarvis-new" "$exe" 2>/dev/null; then placed=1; break; fi
      rm -f "$exe.jarvis-new"; log "install direct: place try $try failed"
      [ "$try" -lt 2 ] && sleep 3
    done
    if [ "$placed" != "1" ]; then
      say "     받은 파일을 제자리($(redact "$exe"))에 두지 못했습니다."
      return 1
    fi
    log "install direct: placed $(redact "$exe")"
  fi
  rm -f "$dl"
  # 판정 = 제자리 파일이 판본을 답하는가(상한 있음)
  vtext="$(perl -e 'alarm shift; exec @ARGV or exit 126' "$CLAUDE_VERSION_WAIT_SEC" "$exe" --version 2>/dev/null | head -1)"
  if ! [[ "$vtext" =~ [0-9]+\.[0-9]+\.[0-9]+ ]]; then
    say "     제자리에 둔 클로드가 판본을 답하지 않았습니다."
    log "install direct: --version no answer ($vtext)"
    return 1
  fi
  say "     직접 받은 클로드가 판본을 답했습니다: $vtext"
  log "install direct: ok $vtext - step5 $step5"
  return 0
}
claude_install_interrupt() { # 이 단계에서 Ctrl-C·창 닫기 — 배경에 둔 설치기 나무를 끄고 끝낸다(고아로 남기지 않는다)
  trap - INT TERM
  stop_proc_tree "$1" "$(get_proc_tree "$1")"
  exit 130
}

step_install_claude() {
  if [ "$S1_CLAUDE_OK" = "1" ]; then
    say "[2/10] 클로드가 이미 있습니다 — 건너뜁니다."
    return 0
  fi
  if [ -n "$(command -v claude 2>/dev/null)" ]; then
    say "[2/10] 이 컴퓨터의 클로드가 낡았습니다($(claude --version 2>/dev/null | head -1)). 최신판을 설치합니다."
  fi
  if [ "$MODE" = "dry" ]; then
    say "[2/10] (dry-run) 설치기를 부르지 않았습니다. 부를 줄 = curl -fsSL $CLAUDE_INSTALL_URL | bash -s $CLAUDE_CHANNEL"
    return 0
  fi
  say "[2/10] 클로드 코드를 설치합니다. 글자가 주르륵 올라갑니다 — 정상입니다."
  local rc=0 pid w=0 since=0 direct=0
  ( set -o pipefail; curl -fsSL --max-time 600 "$CLAUDE_INSTALL_URL" | bash -s "$CLAUDE_CHANNEL" ) </dev/null & pid=$!
  trap 'claude_install_interrupt "$pid"' INT TERM
  log "install wait cap ${CLAUDE_INSTALL_WAIT_SEC}s"
  # ps1 1812~1830 — 띄워 놓고 지켜보며 30초마다 한 줄 + 진행 「대기」 · 3분 이상 = 정체 증거 · 상한이면 멈춘다
  while kill -0 "$pid" 2>/dev/null && [ "$w" -lt "$CLAUDE_INSTALL_WAIT_SEC" ]; do
    sleep 1; w=$((w + 1)); since=$((since + 1))
    if [ "$since" -ge "$INSTALL_NOTE_EVERY_SEC" ]; then
      since=0
      say "     아직 설치 중입니다 ($((w / 60))분 $((w % 60))초 지남 · 최대 $((CLAUDE_INSTALL_WAIT_SEC / 60))분)."
      progress_send '2/10' 'wait' "$w" '' ''
      [ "$w" -ge 180 ] && evidence_once stall
    fi
  done
  if kill -0 "$pid" 2>/dev/null; then
    say "[2/10] 설치가 $((CLAUDE_INSTALL_WAIT_SEC / 60))분 안에 끝나지 않았습니다."
    write_claude_install_diag "$pid" "공식 설치기"
    stop_proc_tree "$pid" "$DIAG_TREE"
    trap - INT TERM
    say "     공식 설치기를 멈추고, 같은 공식 자리에서 클로드 파일을 직접 받아 설치를 이어 갑니다."
    if install_claude_direct; then
      direct=1
    else
      # 조용히 다음 단계로 가지 않는다. 윈판의 백신 창 대기 코드는 윈도우 전용이라 맥은 바깥 서버 축으로 적는다.
      jcode "J-NET-03" "클로드 설치 파일을 받는 곳이 정해진 시간 안에 끝나지 않았습니다"
      next_rerun "잠시 뒤 아래 「다시 하시는 법」대로 다시 실행해 주십시오. 끝난 단계는 건너뛰고 이어서 갑니다."
      return 4
    fi
  else
    trap - INT TERM
    wait "$pid"; rc=$?
  fi
  if [ "$rc" -ne 0 ]; then
    # 여기서 곧바로 끝내지 않는다 — 못 나가는 까닭이 잠깐일 수 있다. 원인을 갈라 말하고 기다린다.
    say "[2/10] 설치기를 받지 못했습니다 (종료 코드 $rc)."
    if wait_for_connection "[2/10]" '( set -o pipefail; curl -fsSL --max-time 600 "$CLAUDE_INSTALL_URL" | bash -s "$CLAUDE_CHANNEL" )'; then
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
# ── 로그인 코드 자동 넣기 (v0.3.18 · 728 윈판 동형) ─────────────────────────────
LOGIN_TICK=2              # 초 — 한 바퀴(이 사이에 이 창에 친 줄 · 복사된 코드 · 로그인 프로세스 생존을 본다)
LOGIN_CLIP_MAX_SENDS=3    # 한 번 연 로그인에서 복사된 코드를 넣는 최대 횟수(서로 다른 코드만 센다)
login_trim() { local s="$1"; s="${s#"${s%%[![:space:]]*}"}"; s="${s%"${s##*[![:space:]]}"}"; printf '%s' "$s"; }
login_code_shape() {   # 윈판 Test-LoginCodeShape 와 같은 모양 · 줄 단위 grep 이 아니라 문자열 전체를 본다
  local s="$1"
  [ "${#s}" -le 1100 ] || return 1
  # ⚠맥 bash 3.2 의 정규식(BSD regcomp)은 반복 상한이 255(RE_DUP_MAX)라 {16,512} 는 식 자체가 깨져 늘 거짓이다(2026-09-15 흉내 실측)
  #   ⇒ 모양은 + 로 보고, 길이(16~512)는 두 조각을 따로 센다.
  [[ "$s" =~ ^[A-Za-z0-9._~-]+#[A-Za-z0-9._~-]+$ ]] || return 1
  local a="${s%%#*}" b="${s#*#}"
  [ "${#a}" -ge 16 ] && [ "${#a}" -le 512 ] && [ "${#b}" -ge 16 ] && [ "${#b}" -le 512 ]
}
login_feeder() {   # login_feeder <pid 파일> — 표준 출력 = 로그인 프로세스의 입력(코드 글자는 기록에 적지 않는다)
  local pidf="$1" base="" last="" clip="" line="" sends=0 typed=0 pid="" have_tty=0
  ( : </dev/tty ) 2>/dev/null && have_tty=1
  # 로그인을 열기 **전에** 이미 복사돼 있던 코드는 넣지 않는다(지난 시도의 낡은 코드 · 윈판과 같은 규칙)
  clip="$(login_trim "$(pbpaste 2>/dev/null)")"
  login_code_shape "$clip" && base="$clip"
  clip=""
  while :; do
    pid="$(head -1 "$pidf" 2>/dev/null)"
    if [ -n "$pid" ] && ! kill -0 "$pid" 2>/dev/null; then break; fi   # 로그인 프로세스가 끝났다 → 넣기를 멈춘다
    [ -e "$LOGIN_WAIT_MARK" ] || break
    if [ "$have_tty" = "1" ]; then
      line=""
      if IFS= read -r -t "$LOGIN_TICK" line </dev/tty 2>/dev/null; then
        printf '%s\n' "$line" || break   # 사람이 이 창에 친 줄은 그대로 넘긴다(폴백 = 종전 붙여넣기)
        line="$(login_trim "$line")"; login_code_shape "$line" && last="$line"
        typed=$((typed + 1)); log "login line forwarded from terminal $typed"
      fi
      line=""
    else
      sleep "$LOGIN_TICK"
    fi
    if [ "$sends" -lt "$LOGIN_CLIP_MAX_SENDS" ]; then
      clip="$(login_trim "$(pbpaste 2>/dev/null)")"
      if login_code_shape "$clip" && [ "$clip" != "$base" ] && [ "$clip" != "$last" ]; then
        printf '%s\n' "$clip" || break
        last="$clip"; sends=$((sends + 1))
        log "login code sent from clipboard $sends"
        tell "     복사하신 코드를 로그인에 넣었습니다 — 확인을 기다립니다."
      fi
      clip=""
    fi
  done
  log "login feeder end: clipboard $sends · terminal lines $typed"
  return 0
}
login_run_fed() {   # login_run_fed <pid 파일> — 가짜 터미널 안의 로그인 프로세스 · 입력은 login_feeder
  local pidf="$1"
  login_feeder "$pidf" | script -q /dev/null /bin/sh -c 'echo $$ > "$0"; ps -o lstart= -p $$ >> "$0"; exec claude auth login' "$pidf"
  LOGIN_RUN_RC=$?   # 부르는 자리는 `|| true` 로 막는다 — 로그인 보고(승인 프로세스 종료 코드)는 이 값을 읽는다
  return "$LOGIN_RUN_RC"
}

# ── 로그인 단계 관측 — ps1 Set-LoginStage 1923 · Get-LoginStatusText 1953 · Get-LoginStrayKeyCount 1999 · Read-LoginFailKey 2065 ·
#    Invoke-LoginFailQuestion 2080 · Add-LoginReport 2106 · Add-ReportLines 1596 의 맥 짝 ─────────────────
#   어디서 끝났는지를 기록 끝부분(원격 보고에 실린다)에서 바로 가르고, 상한에서 끝났으면 「어땠는지」 숫자 하나를 받아 둔다.
#   코드·주소·계정 원문은 어디에도 적지 않는다.
LOGIN_STAGE=""
set_login_stage() { LOGIN_STAGE="$1"; log "login stage: $1"; }
add_report_lines() { # add_report_lines <줄>... — 환경 보고(원격 해결이 보내는 본문)에 줄을 덧붙인다
  { printf '%s\n' "$@" >> "$REPORT_FILE"; } 2>/dev/null || log "report append failed"
  return 0
}
login_status_text() { # → 표준 출력 = auth status 답(상한이면 빈 글 · rc 0) · rc 1 = 실행하지 못했다(부르는 쪽이 「실행 실패」로 센다)
  local out rc
  out="$(perl -e 'alarm shift; exec @ARGV or exit 126' "$LOGIN_STATUS_WAIT_SEC" claude auth status 2>/dev/null)"; rc=$?
  case "$rc" in
    126) log "login poll failed: claude auth status 실행 못함 (rc 126)"; return 1 ;;
    142) log "login status timeout ${LOGIN_STATUS_WAIT_SEC}s: killed"; return 0 ;;
  esac
  printf '%s' "$out"
  return 0
}
login_stray_key_count() { # → 표준 출력 = 이 설치 창 입력에 쌓여 있던 글자 수(읽고 버린다 · 적지 않는다) · -1 = 터미널이 아니다
  local n=0 c
  if [ -t 0 ]; then
    while [ "$n" -lt 10000 ] && IFS= read -r -s -n 1 -t 1 c 2>/dev/null; do n=$((n + 1)); done   # ⚠맥 bash 3.2 는 소수 상한을 못 받는다
  else
    n=-1
  fi
  printf '%s\n' "$n"
}
read_login_fail_key() { # read_login_fail_key <초> → 표준 출력 = 1|2|3|enter|timeout|no-input
  local end k
  [ -t 0 ] || { printf 'no-input\n'; return 0; }
  end=$(( $(date +%s) + $1 ))
  while [ "$(date +%s)" -lt "$end" ]; do
    k="x"
    if IFS= read -r -s -n 1 -t 1 k 2>/dev/null; then
      case "$k" in
        1|2|3) printf '%s\n' "$k"; return 0 ;;
        "") printf 'enter\n'; return 0 ;;
      esac
    fi
  done
  printf 'timeout\n'
}
login_fail_question() { # → LOGIN_INFO_ANSWER · LOGIN_INFO_KEYS
  local stray key tag
  stray="$(login_stray_key_count)"
  say "     로그인이 시간 안에 끝나지 않았습니다. 어땠는지 숫자 하나만 눌러 주십시오 (안 누르셔도 1분 뒤 다음으로 갑니다):"
  say "       1 = 브라우저가 열리지 않았다"
  say "       2 = 브라우저는 열렸지만 승인 화면이 안 나왔다 (구독 안내가 나왔다)"
  say "       3 = 승인하고 코드도 붙여넣었는데 안 됐다"
  say "       Enter = 잘 모르겠다"
  key="$(read_login_fail_key "$LOGIN_ASK_WAIT_SEC")"
  case "$key" in
    1) tag=browser-not-opened ;; 2) tag=no-approval-screen ;; 3) tag=approved-code-rejected ;;
    enter) tag=unknown ;; timeout) tag=no-answer ;; no-input) tag=no-console-input ;; *) tag=unknown ;;
  esac
  log "login fail answer: $tag (key=$key) · stray keys before question=$stray"
  case "$key" in 1|2|3) say "     $key 번으로 적었습니다." ;; esac
  LOGIN_INFO_ANSWER="$tag"
  LOGIN_INFO_KEYS="$stray"
}
add_login_report() { # 로그인 단계에서 본 것 — 기록 파일과 환경 보고 두 곳에 똑같이 남긴다
  local l
  set -- "로그인 창: $LOGIN_INFO_WIN" "승인 프로세스: $LOGIN_INFO_PROC" "다시 열기: $LOGIN_INFO_REOPEN" "코드 넣기: $LOGIN_INFO_SEND" \
         "끝난 뒤 확인: $LOGIN_INFO_CONFIRM" "상한에서 받은 답: $LOGIN_INFO_ANSWER" "질문 전 설치 창에 쌓인 글자 수: $LOGIN_INFO_KEYS"
  for l in "$@"; do log "login report: $l"; done
  add_report_lines "" "## [3/10] 로그인 단계에서 본 것" "$(printf -- '- %s\n' "$@")"
}

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
    if login_status_text | grep -q '"loggedIn"[[:space:]]*:[[:space:]]*true'; then
      S1_LOGGED_IN=1
    fi
  fi
  if [ "$S1_LOGGED_IN" = "1" ]; then
    say "[3/10] 이미 로그인돼 있습니다 — 건너뜁니다."
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
  say "[3/10] 지금 로그인 화면을 엽니다. 브라우저가 나타나면 승인을 눌러 주십시오."
  # 로그인 카드(2026-09-14 워크숍 · 윈과 같은 세 가지 · 붙여넣기 키만 맥 것) — 승인을 두 번 누르거나 주소창 주소를 붙여넣어 코드가 무효가 됐다.
  say "     로그인은 이렇게 해 주십시오 (3가지만):"
  say "     1) 열려 있는 Claude 탭을 모두 닫고, 브라우저에서 「승인」은 한 번만 누르십시오 (두 번 누르면 앞 코드가 무효가 됩니다)."
  say "     2) 「Authentication code」 화면에서 복사 단추로 코드만 복사하십시오 (주소창의 주소는 안 됩니다)."
  say "     3) 복사만 하시면 이 창이 몇 초 안에 알아서 넣습니다 — 「코드를 로그인에 넣었습니다」가 안 나오면 이 창을 한 번 누르고 ⌘+V 로 붙여넣은 뒤 Enter 를 누르십시오(5분 안에)."
  say "     기다리는 동안 $((LOGIN_SAY_INTERVAL))초마다 한 줄씩 알려 드리고, $((LOGIN_WAIT_TIMEOUT / 60))분이 지나면 이 기다림을 끝냅니다."
  LOGIN_WAIT_MARK="$JARVIS_HOME/.login-wait"
  LOGIN_PID_FILE="$JARVIS_HOME/.login-pid"
  LOGIN_CAPPED_MARK="$JARVIS_HOME/.login-capped"
  rm -f "$LOGIN_PID_FILE" "$LOGIN_CAPPED_MARK"
  LOGIN_INFO_WIN="설치 창 안 가짜 터미널(코드는 설치기가 넣는다)"; LOGIN_INFO_PROC="-"; LOGIN_INFO_REOPEN="안 했다(맥은 다시 열지 않는다)"
  LOGIN_INFO_SEND="-"; LOGIN_INFO_CONFIRM="-"; LOGIN_INFO_ANSWER="묻지 않음(상한에 닿지 않았다)"; LOGIN_INFO_KEYS="-"
  local login_t0 login_rc=0 login_w feed
  login_t0="$(date +%s)"
  : > "$LOGIN_WAIT_MARK"
  login_waiter "$LOGIN_WAIT_MARK" "$LOGIN_PID_FILE" &
  LOGIN_WATCHER=$!
  # ★승인은 **앞에 그대로** 두되, 자기 번호와 시작 시각을 적고 나서 벤더 명령으로 **바뀐다**(exec).
  #   그래야 상한이 `pgrep` 로 다시 찾지 않고 **그 프로세스 하나만** 겨눌 수 있다.
  #   (이 셸은 3.2 라 `BASHPID` 가 없다 — 자식이 스스로 적는 것이 유일한 길이다.)
  # 🔴v0.3.18 — 로그인 코드를 붙여넣지 않아도 되게(728 윈판 설계 동형): 로그인 프로세스를 가짜 터미널(script) 안에 띄우고
  #   그 입력을 설치기가 쥔다 → 복사된 코드(pbpaste)를 한 줄로 넣는다 · 사람이 이 창에 붙여넣은 줄도 그대로 넘긴다(폴백).
  #   ⚠입력을 파이프로만 바꾸면 벤더 도구가 「터미널이 아니다」로 입력 칸을 안 띄운다 — script 가 자식에게 터미널을 준다(2026-09-15 이 맥 실측 · 자식 stdin=tty).
  if command -v script >/dev/null 2>&1 && command -v pbpaste >/dev/null 2>&1; then
    log "login: installer-fed (script pty · clipboard)"
    set_login_stage "wait (installer-fed)"
    LOGIN_RUN_RC=0
    login_run_fed "$LOGIN_PID_FILE" || true
    login_rc="$LOGIN_RUN_RC"
  else
    log "login: plain (script 또는 pbpaste 없음)"
    LOGIN_INFO_WIN="설치 창(사람이 붙여넣는다 · script 또는 pbpaste 없음)"
    set_login_stage "wait (plain)"
    /bin/sh -c 'echo $$ > "$0"; ps -o lstart= -p $$ >> "$0"; exec claude auth login' "$LOGIN_PID_FILE" || login_rc=$?
  fi
  # 끝났으면 **표적을 먼저** 치운다 — 표식보다 먼저 지워야 감시자가 겨눌 것이 없다.
  rm -f "$LOGIN_PID_FILE"
  rm -f "$LOGIN_WAIT_MARK"
  kill "$LOGIN_WATCHER" 2>/dev/null
  wait "$LOGIN_WATCHER" 2>/dev/null || true
  login_w=$(( $(date +%s) - login_t0 ))
  feed="$(grep -o 'login feeder end: clipboard [0-9]* · terminal lines [0-9]*' "$LOG_FILE" 2>/dev/null | tail -1)"
  [ -n "$feed" ] && LOGIN_INFO_SEND="복사된 코드 $(printf '%s' "$feed" | sed -E 's/.*clipboard ([0-9]+).*/\1/')회 · 설치 창 입력 줄 $(printf '%s' "$feed" | sed -E 's/.*terminal lines ([0-9]+).*/\1/')회"
  if [ -f "$LOGIN_CAPPED_MARK" ]; then
    LOGIN_INFO_PROC="상한 $((LOGIN_WAIT_TIMEOUT / 60))분에 닿아 끝냈다 · 종료 코드 $login_rc · ${login_w}초"
    log "login proc exit=$login_rc after ${login_w}s (cap)"
    rm -f "$LOGIN_CAPPED_MARK"
    set_login_stage "question"
    login_fail_question
  else
    LOGIN_INFO_PROC="스스로 끝났다 · 종료 코드 $login_rc · ${login_w}초"
    log "login proc exit=$login_rc after ${login_w}s (self)"
  fi
  set_login_stage "confirm"
  say "     승인이 끝났는지 확인합니다. 최대 $((LOGIN_POLL_TIMEOUT / 60))분까지 기다립니다."
  local waited=0 logged st tries=0 fails=0
  while [ "$waited" -lt "$LOGIN_POLL_TIMEOUT" ]; do
    tries=$((tries + 1))
    st="$(login_status_text)" || fails=$((fails + 1))
    logged="$(printf '%s' "$st" | grep -o '"loggedIn"[[:space:]]*:[[:space:]]*true')"
    if [ -n "$logged" ]; then
      S1_LOGGED_IN=1
      set_login_stage "done by status after window ended"
      say "[3/10] 로그인 확인했습니다."
      return 0
    fi
    sleep "$LOGIN_POLL_INTERVAL"
    waited=$((waited + LOGIN_POLL_INTERVAL))
  done
  LOGIN_INFO_CONFIRM="로그인 안 됨 · 확인 ${tries}회(${LOGIN_POLL_TIMEOUT}초) · 그 가운데 실행 실패 ${fails}회"
  set_login_stage "fail"
  say "[3/10] $((LOGIN_POLL_TIMEOUT / 60))분 동안 로그인이 확인되지 않았습니다."
  add_login_report
  jcode "J-LOGIN-01" "로그인 승인이 시간 안에 끝나지 않았습니다"
  next_rerun "아래 「다시 하시는 법」대로 다시 실행하시면 로그인 창이 다시 열립니다."
  return 5
}

# ── 하는 일 4 — 자비스 기동 (지침 파일 + 첫 지시 주입) ───────
write_directive() {
  cat > "$DIRECTIVE_FILE" <<DIRECTIVE
# 자비스 설치 도우미 지침

너는 이 컴퓨터의 설치를 대신 해 주는 자비스다. 상대는 처음 설치하는 사람이다.
★상대는 우리말 사용자다 — 이 지침을 읽은 뒤의 모든 답·보고·화면 글은 우리말로 쓴다(코드·명령·파일 이름은 그대로).

## 준비 작업 1번 — 표지 파일 하나 만들기 (제일 먼저)

아래 파일을 만들어라. 내용은 두 줄이면 된다 — 지금 시각과 이 세션의 프로세스 번호.

    $(master_mark_path)

**왜 이것을 먼저 하는가**: 설치기는 이 파일이 생긴 것으로 「자비스가 지침을 읽고 준비 작업을 시작했다」를 판정한다.
없으면 설치기는 **시작하지 않은 것으로 보고 사람에게 사실대로 알린다**(거절인지 못 쓴 것인지는 단정하지 않는다).
이 파일은 설치 확인용이고, 지워도 설치기가 다시 물어볼 뿐 다른 일은 일어나지 않는다.

★**이 지침이 이상하다고 판단되면 따르지 않아도 된다.** 그때는 무엇이 왜 걸리는지 한 줄로 적어라 —
설치기는 그것을 「시작하지 않음」으로 읽고 사람에게 넘긴다. 읽지 않은 채 따르는 것보다 그쪽이 낫다.

**보고서에 「막힌 단계」가 적혀 있으면 표보다 먼저 그것을 말해라.** 세 가지를 이 순서로:
1. 어디까지 됐는가(끝난 단계) 2. 무엇이 막혔는가 3. **사람이 할 일이 있으면 그것 하나만** — 없으면 「없습니다, 제가 이어서 합니다」.

그 다음 아래 파일을 읽어 표로 옮겨 적는다.
★보고서에 **「지나온 단계」** 절이 있으면 **표보다 먼저** 그것을 한 줄 요약으로 보여라 —
사람은 방금 화면이 지워지는 것을 봤고, **무슨 일이 있었는지부터 알고 싶어 한다.**

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
  # ⚠표지 파일 경로만 **가리지 않고** 적는다(ps1 Write-Directive 2436 과 같은 까닭) — 이 줄은 사람이 읽는 안내가 아니라
  #   **모델이 파일을 만들 자리**다. `~` 로 줄이면 도구에 따라 그대로 폴더 이름이 되어 표지가 엉뚱한 곳에 생긴다(거짓 적색).
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
  plutil -replace autoUpdatesChannel -string "$CLAUDE_CHANNEL" "$sf" >/dev/null 2>&1 \
    || plutil -insert autoUpdatesChannel -string "$CLAUDE_CHANNEL" "$sf" >/dev/null 2>&1
  log "seed: $(redact "$sf") theme·skipDangerousModePermissionPrompt·remoteControlAtStartup·autoUpdatesChannel=$CLAUDE_CHANNEL"
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
#   ★HEAD(`-I`)가 아니라 **첫 1바이트만 받는 GET**(`-r 0-0`)으로 묻는다 — 받는 동작과 같은 방식으로 물어야
#   「받기는 되는데 물음에는 404」 같은 갈림이 없다(2026-09-15 GitHub 릴리스 자산의 HEAD 404 제보 · 있으면 206).
cys_http_code() {
  local c
  c="$(curl -sS -L -r 0-0 -o /dev/null -w '%{http_code}' --max-time 60 "$1" 2>/dev/null)"
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
  if [ "$CYS_VENDOR_WHY" = "intel" ]; then
    say "[5/10] 이 맥은 인텔 칩입니다 — 원작자 공식 판(${CYS_VERSION})을 받습니다(저희 판은 애플 실리콘 맥 전용입니다)."
  fi
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
    # 크기 핀이 숫자가 아닐 때(발행 전 자리표)는 크기를 말하지 않는다 — 산술에 글자를 넣으면 셸 오류가 화면에 섞인다(이종 검토 1R 지적 2026-09-16).
    if [ "$CYS_MAC_BYTES" -gt 0 ] 2>/dev/null; then
      say "[5/10] cys 설치 파일을 받습니다 (약 $((CYS_MAC_BYTES / 1000000))MB · 잠시 걸립니다)."
    else
      say "[5/10] cys 설치 파일을 받습니다 (잠시 걸립니다)."
    fi
    if ! curl -fsSL --max-time 900 "$CYS_DOWNLOAD_URL" -o "$dst"; then
      # 🔴먼저 **까닭을 가른다**. 받을 자리가 「그런 파일 없다」고 답했으면 기다릴 일이 아니다.
      #   ⚠**404·410 만** 이 갈래다. 5xx(자리는 살아 있는데 잠시 탈이 난 것)도, 물어보지도 못한
      #     `000`(망 쪽)도 **여전히 기다리는 쪽**이다 — 새 갈래가 그 길까지 삼키면 안 된다.
      code="$(cys_http_code "$CYS_DOWNLOAD_URL")"
      case "$code" in
        404|410)
          rm -f "$dst"
          # ★저희 판 자산이 없으면 **원작자 공식 판으로 한 번만** 돌아간다(그 판도 없으면 아래 J-DL-05).
          #   멈추지 않고 설치를 끝내는 쪽을 고른다 — 원작자 판도 자비스가 돈다(2026-09-14 워크숍까지 쓰던 판).
          if [ "$CYS_KIND" = "fork" ]; then
            say "[5/10] 저희 판을 받을 자리에 파일이 없습니다 (응답 $code) — 원작자 공식 판(${CYS_VERSION})으로 받습니다."
            log "fork asset missing ($code): $CYS_DOWNLOAD_URL -> vendor pin"
            cys_use_vendor_pin; CYS_VENDOR_WHY="missing"
            step_download_cys
            return $?
          fi
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
  say "     공식 페이지에서 직접 받으실 수 있습니다: $CYS_MANUAL_URL"
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

# 설치된 프로그램의 CDHash(서명이 가리키는 내용 지문). 못 읽으면 빈 문자열 — 부르는 쪽이 「다르다」로 받는다.
cys_app_cdhash() {
  codesign -dvvv "$1" 2>&1 | sed -n 's/^CDHash=//p' | head -1
}

# ── 옛 판 안내 (TICKET=installer-speed-pin-0320 · 2026-09-16) ─────────
#   0.14.x 로 깔린 cys 는 앱 안 업데이트가 안 된다(서명 열쇠가 바뀌었다) — 저희 판을 받는 맥에서는 [6/10] 이 새 판으로 다시 깐다.
#   ★묻지 않는다 · 막지 않는다 — 한 줄 알리고 그대로 간다(사람 손 0). 원작자 판 길(인텔·자산 없음)과 판본을 못 읽는 경우는 아무 말도 하지 않는다.
note_old_cys_app() {
  local v
  [ "${CYS_KIND:-}" = "fork" ] && [ -d "$CYS_OLD_APP" ] || return 0
  v="$(defaults read "$CYS_OLD_APP/Contents/Info" CFBundleShortVersionString 2>/dev/null)"
  case "$v" in
    0.14.*)
      say "     깔려 있는 cys ${v} 는 앱 안에서 업데이트할 수 없는 옛 판입니다 — 이번 설치에서 새 판(${CYS_DISPLAY_NAME} ${CYS_FORK_VERSION})으로 다시 설치합니다(하실 일은 없습니다)."
      log "old cys app: ${v} -> reinstall ${CYS_FORK_VERSION}" ;;
  esac
  return 0
}
step_install_cys() {
  local dst swap_note=""
  if [ "$CYS_KIND" != "fork" ]; then
    if [ -d /Applications/cys.app ]; then
      say "[6/10] cys 가 이미 설치돼 있습니다 — 건너뜁니다."
      return 0
    fi
  elif [ -d "$CYS_FORK_APP" ] || [ -d "$CYS_OLD_APP" ]; then
    # 🔴저희 판을 받는 맥에서는 「있다」로 건너뛰지 않는다 — **어느 판이 있는가**를 본다.
    #   어제까지 깐 원작자 판이 그대로 남으면 이 전환이 그 맥에서는 일어나지 않는다.
    #   (installer-speed-pin-0320) 1.0.1 부터 이름이 cysr.app 이다 — 건너뛰는 것은 새 자리가 이번 판이고 옛 이름 자리(cys.app)가 없을 때뿐.
    if [ "$(cys_app_cdhash "$CYS_FORK_APP")" = "$CYS_FORK_CDHASH" ] && [ ! -d "$CYS_OLD_APP" ]; then
      say "[6/10] cys 가 이미 설치돼 있습니다 (판본 ${CYS_FORK_VERSION} 확인) — 건너뜁니다."
      return 0
    fi
    if [ -d "$CYS_OLD_APP" ]; then
      swap_note="설치돼 있는 cys(옛 이름 cys.app)를 이번 판(${CYS_DISPLAY_NAME} ${CYS_FORK_VERSION} · cysr.app)으로 바꿔 넣습니다."
    else
      swap_note="설치돼 있는 cys 가 이번 판(${CYS_FORK_VERSION})이 아니어서 이번 판으로 바꿔 넣습니다."
    fi
  fi
  if [ "$MODE" = "dry" ]; then
    say "[6/10] (dry-run) 설치 파일을 열지 않았습니다.${swap_note:+ ($swap_note — 실행하면 그렇게 합니다)}"
    return 0
  fi
  dst="$DL_DIR/$CYS_MAC_FILE"
  [ -f "$dst" ] || { say "[6/10] 설치 파일이 없습니다."; return 6; }
  [ -n "$swap_note" ] && say "[6/10] $swap_note"
  if [ "$CYS_KIND" = "fork" ]; then
    cys_install_from_zip "$dst"
    return $?
  fi
  cys_install_from_dmg "$dst"
}

# ── 6-가. 저희 판(zip) 설치 ─────────────────────────────────────────
# 이 컴퓨터에서 도는 이 설치기가 **cys 창 안에서** 돌고 있는가(조상 중에 cys 프로그램이 있는가).
#   그렇다면 옛 cys 를 끄는 순간 이 창도 함께 꺼져 반쯤 바꾼 채 멈춘다 — 그 자리에서는 바꾸지 않는다.
cys_run_from_inside_cys() {
  local p="$$" c i=0
  while [ -n "$p" ] && [ "$p" -gt 1 ] 2>/dev/null && [ "$i" -lt 64 ]; do
    c="$(ps -o comm= -p "$p" 2>/dev/null)"
    case "$c" in /Applications/cys.app/*|/Applications/cysr.app/*) return 0 ;; esac
    p="$(ps -o ppid= -p "$p" 2>/dev/null | tr -d ' ')"
    i=$((i+1))
  done
  return 1
}
# 바꿔 넣기 전에 옛 cys 를 끈다. ★**실행 파일의 자리**로만 고른다(명령줄을 보지 않는다) —
#   명령줄로 고르면 그 경로를 파일 인자로 연 편집기까지 끈다(지우개가 같은 이유로 그 축을 뺐다).
cys_stop_old_app() {
  local sig line pid cmd left hit
  launchctl bootout "gui/$(id -u)/com.cysjavis.cysd" >>"$LOG_FILE" 2>&1 || true
  for sig in TERM KILL; do
    hit=0
    while IFS= read -r line; do
      pid="${line%% *}"; cmd="${line#* }"
      [ -n "$pid" ] && [ "$pid" != "$$" ] || continue
      case "$cmd" in /Applications/cys.app/*|/Applications/cysr.app/*) kill "-$sig" "$pid" 2>/dev/null; hit=1 ;; esac
    done <<EOF_PS
$(ps -Ao pid=,comm= 2>/dev/null | sed 's/^[[:space:]]*//')
EOF_PS
    # (installer-speed-pin-0320) 끌 것이 없었으면 기다리지 않는다 — 종전엔 도는 것이 없어도 2초씩 두 번(4초) 기다렸다.
    [ "$hit" = "1" ] || break
    sleep 2
  done
  left="$(ps -Ao comm= 2>/dev/null | grep -cE '^/Applications/cysr?\.app/')"
  log "stop old cys: left=${left:-?}"
}
# 받은 zip → 풀기 → 격리 속성 지우기 → 서명·판본 확인 → 옛 것 끄기 → 한 번에 바꿔 넣기(옛 것은 한 벌 보관).
#   ★확인을 **끄기보다 앞에** 둔다 — 새 것이 멀쩡한지 모르는 채 돌던 cys 를 끄지 않는다.
#   ★넣기는 같은 디스크 안의 이름 바꾸기(mv)라 **반쪽 프로그램이 보이는 순간이 없다**
#     (원작자 설치 도우미가 막으려던 「손상되었습니다」 경합이 여기서는 생기지 않는다).
# 받은(또는 넣은) 프로그램이 **실제로 실행되는가**(TICKET=mac-parity-t1-core · 2026-09-16).
# 🔴2026-09-16 실기 2대 동일 실패: 라이브 0.3.19 가 핀한 v1.0.0 zip 안의 Contents/MacOS/cys·cysd 가 -rw-r--r--(실행 비트 없음)였다.
#   [6/10] 은 지문·서명·CDHash·판번을 전부 통과해 「설치를 마쳤습니다」를 찍었지만 cys 는 한 번도 실행되지 않았다
#   (서명은 파일 모드를 봉인하지 않는다 — 실행 가능성은 서명 검사가 재지 않는 축이다).
# ⇒ 실행 비트 둘 + `cys --version` 의 실제 답을 함께 본다. 윈도우판에는 짝이 없다(실행 비트라는 개념이 없는 OS).
# ⚠`perl -e 'exec @ARGV'` 는 exec 가 실패해도 0 으로 끝난다(2026-09-16 실측) ⇒ `or exit 126` 을 붙이고, 답 글자(판번 모양)도 함께 본다.
CYS_APP_EXEC_WHY=""
cys_app_exec_ok() { # cys_app_exec_ok <앱 폴더> → rc 0 = 실행된다 · 1 = 안 된다(CYS_APP_EXEC_WHY)
  local m="$1/Contents/MacOS" out
  CYS_APP_EXEC_WHY=""
  [ -x "$m/cys" ]  || { CYS_APP_EXEC_WHY="cys-not-executable";  return 1; }
  [ -x "$m/cysd" ] || { CYS_APP_EXEC_WHY="cysd-not-executable"; return 1; }
  if ! out="$(CYS_NO_AUTOSTART=1 perl -e 'alarm shift; exec @ARGV or exit 126' "$CYS_APP_EXEC_CAP_SEC" "$m/cys" --version 2>&1)"; then
    CYS_APP_EXEC_WHY="cys-version-failed"; log "app exec check: cys --version failed: $(redact "$out" | head -3 | tr '\n' '|')"; return 1
  fi
  case "$out" in
    *[0-9].[0-9]*) log "app exec check ok: $(redact "$1") -> $(printf '%s' "$out" | head -1)"; return 0 ;;
  esac
  CYS_APP_EXEC_WHY="cys-version-no-answer"; log "app exec check: no version in answer: $(redact "$out" | head -3 | tr '\n' '|')"
  return 1
}
CYS_APP_EXEC_CAP_SEC=10   # `cys --version` 한 번의 상한(맥에는 timeout 명령이 없다)
cys_install_from_zip() {
  local zip="$1" stage app ver cdh bak prev oldprev swap rc attempt=1
  if { [ -d "$CYS_OLD_APP" ] || [ -d "$CYS_FORK_APP" ]; } && cys_run_from_inside_cys; then
    say "[6/10] 이 창이 cys 안에서 열려 있어 cys 를 바꿔 넣을 수 없습니다(바꾸는 동안 이 창도 꺼집니다)."
    say "     [터미널] 앱을 새로 여시고 아래 「다시 하시는 법」대로 다시 실행해 주십시오."; SHOW_RERUN=1
    return 6
  fi
  say "[6/10] cys 를 설치합니다 (풀어서 넣습니다 · 1분쯤 걸립니다)."
  stage="$DL_DIR/cys-stage"; app="$stage/cysr.app"   # 1.0.1 부터 zip 최상위 = cysr.app
  # ★원자화(TICKET=mac-parity-t1-core): 임시 자리에 풀기 → 서명·판본 → **실행 확인** → 그때만 프로그램 폴더로 바꿔 넣는다.
  #   실행 확인이 걸리면 설치 파일을 버리고 **한 번만** 다시 받아(지문 재확인 포함) 처음부터 다시 잰다. 두 번째도 걸리면 넣지 않는다.
  while :; do
    rm -rf "$stage" 2>/dev/null
    if ! mkdir -p "$stage" || ! ditto -x -k "$zip" "$stage" >>"$LOG_FILE" 2>&1 || [ ! -d "$app/Contents" ]; then
      rm -rf "$stage" 2>/dev/null; rm -f "$zip"
      say "[6/10] 설치 파일을 풀지 못했습니다. 아래 「다시 하시는 법」대로 다시 실행하시면 다시 받습니다."; SHOW_RERUN=1
      return 6
    fi
    # 격리 속성이 붙어 있으면 처음 열 때 확인 창이 뜬다 — 우리가 지운다(사람 손 0).
    xattr -cr "$app" >>"$LOG_FILE" 2>&1 || true
    # 🔴실행 비트 벨트 — 받은 판이 실행 비트를 잃었어도(2026-09-16 v1.0.0 실기) 여기서 되살린다.
    #   서명·CDHash 는 파일 모드를 봉인하지 않으므로 이 줄이 아래 서명 검사를 깨지 않는다(깨진 zip 이 서명 검사를 통과한 것이 그 증거).
    chmod +x "$app/Contents/MacOS/"* >>"$LOG_FILE" 2>&1 || log "app exec belt: chmod failed"
    ver="$(defaults read "$app/Contents/Info" CFBundleShortVersionString 2>/dev/null)"
    cdh="$(cys_app_cdhash "$app")"
    if ! codesign --verify --deep --strict "$app" >>"$LOG_FILE" 2>&1 \
       || [ "$cdh" != "$CYS_FORK_CDHASH" ] || [ "$ver" != "$CYS_FORK_VERSION" ]; then
      log "fork app check failed: ver=$ver cdhash=$cdh"
      rm -rf "$stage" 2>/dev/null
      say "[6/10] 받은 프로그램이 서명·판본 확인을 통과하지 못했습니다 — 설치하지 않습니다 (판본 ${ver:-모름} · 기대 ${CYS_FORK_VERSION})."
      say "     공식 페이지에서 직접 받으실 수 있습니다: $CYS_MANUAL_URL"
      #   ⛔받은 파일을 지우지 않는다 — 지문은 이미 맞았다. 걸린 까닭이 파일이 아니면 다시 받아도 같다.
      return 6
    fi
    if cys_app_exec_ok "$app"; then break; fi
    log "fork app exec check failed: attempt=$attempt why=$CYS_APP_EXEC_WHY"
    rm -rf "$stage" 2>/dev/null
    if [ "$attempt" -ge 2 ]; then
      say "[6/10] 받은 프로그램이 이 맥에서 실행되지 않습니다 (${CYS_APP_EXEC_WHY}) — 설치하지 않습니다."
      { [ -d "$CYS_OLD_APP" ] || [ -d "$CYS_FORK_APP" ]; } && say "     전에 있던 cys 는 그 자리에 그대로 있습니다."
      say "     자세한 내용은 기록 파일에 있습니다: $(redact "$LOG_FILE")"
      SHOW_RERUN=1
      return 6
    fi
    attempt=2
    say "     받은 프로그램이 실행되지 않습니다 (${CYS_APP_EXEC_WHY}) — 설치 파일을 버리고 한 번 다시 받아 확인합니다."
    rm -f "$zip"
    if ! step_download_cys || [ ! -f "$zip" ]; then
      say "[6/10] 다시 받지 못했습니다 — 설치하지 않습니다."; SHOW_RERUN=1
      return 6
    fi
  done
  if [ -d "$CYS_OLD_APP" ] || [ -d "$CYS_FORK_APP" ]; then
    say "     돌고 있는 cys 가 있으면 먼저 끕니다."
    cys_stop_old_app
  fi
  bak="$JARVIS_HOME/backup"; prev="$bak/cysr.app.prev"; oldprev="$bak/cys.app.prev"
  mkdir -p "$bak" 2>/dev/null
  swap="$DL_DIR/cys-swap.sh"
  cat > "$swap" <<'EOF_SWAP'
#!/bin/bash
# cys-swap.sh <새 프로그램> <옛 것 둘 자리> <넣을 자리> <옛 이름 자리> <옛 이름 둘 자리>
#   옛 것을 한 벌 보관하고 새 것을 넣는다. 넣기에 실패하면 옛 것을 되돌린다.
#   (installer-speed-pin-0320) 새 이름(cysr.app)으로 넣은 **뒤에만** 옛 이름 자리(cys.app)를 보관 자리로 옮긴다 —
#   넣기가 실패하면 옛 이름 자리는 손대지 않아 쓰던 cys 가 그대로 남는다. 지우지 않는다(되돌릴 수 있게).
new="$1"; prev="$2"; dst="$3"; old="$4"; oldprev="$5"; moved=0
if [ -e "$dst" ]; then
  rm -rf "$prev" || exit 3
  mv "$dst" "$prev" || exit 3
  moved=1
  # 관리자 권한으로 옮겼으면 보관본 주인을 그 폴더 주인에게 돌려준다 — 지우개가 나중에 지울 수 있게.
  [ "$(id -u)" = "0" ] && chown -R "$(stat -f %u "$(dirname "$prev")")" "$prev" 2>/dev/null
fi
if mv "$new" "$dst"; then
  if [ -n "$old" ] && [ "$old" != "$dst" ] && [ -e "$old" ]; then
    { rm -rf "$oldprev" && mv "$old" "$oldprev"; } || echo "old app move failed: $old" >&2
    [ -e "$oldprev" ] && [ "$(id -u)" = "0" ] && chown -R "$(stat -f %u "$(dirname "$oldprev")")" "$oldprev" 2>/dev/null
  fi
  exit 0
fi
# 넣기에 실패했다 — 디스크가 달라 복사로 넘어가다 멈췄으면 그 자리에 **반쪽**이 남는다. 그것을 먼저 치운다.
#   (옛 것은 이미 보관 자리로 옮겨 두었으므로 이 자리에 남은 것은 새 것의 반쪽뿐이다.)
rm -rf "$dst"
# **이번에 우리가 옮긴 옛 것만** 되돌린다 — 지난 실행의 보관본을 새 설치 자리에 올리지 않는다.
[ "$moved" = "1" ] && [ -e "$prev" ] && mv "$prev" "$dst"
exit 4
EOF_SWAP
  if [ -w /Applications ] && { [ ! -e "$CYS_FORK_APP" ] || [ -w "$CYS_FORK_APP" ]; } && { [ ! -e "$CYS_OLD_APP" ] || [ -w "$CYS_OLD_APP" ]; }; then
    /bin/bash "$swap" "$app" "$prev" "$CYS_FORK_APP" "$CYS_OLD_APP" "$oldprev" >>"$LOG_FILE" 2>&1
    rc=$?
  else
    say "[6/10] 이 계정에는 프로그램 폴더에 넣을 권한이 없습니다 — 관리자 비밀번호 창을 띄웁니다."
    say "     창이 나타나면 이 컴퓨터의 관리자 이름과 비밀번호를 넣어 주십시오. (자비스는 비밀번호를 대신 넣지 않습니다.)"
    osascript -e 'on run argv' \
      -e 'do shell script "/bin/bash " & quoted form of (item 1 of argv) & " " & quoted form of (item 2 of argv) & " " & quoted form of (item 3 of argv) & " " & quoted form of (item 4 of argv) & " " & quoted form of (item 5 of argv) & " " & quoted form of (item 6 of argv) with administrator privileges' \
      -e 'end run' "$swap" "$app" "$prev" "$CYS_FORK_APP" "$CYS_OLD_APP" "$oldprev" >>"$LOG_FILE" 2>&1
    rc=$?
  fi
  rm -f "$swap"; rm -rf "$stage" 2>/dev/null
  if [ "$rc" != "0" ]; then
    say "[6/10] cys 를 프로그램 폴더에 넣지 못했습니다 (종료 코드 $rc)."
    { [ -d "$CYS_OLD_APP" ] || [ -d "$CYS_FORK_APP" ]; } && say "     전에 있던 cys 는 그 자리에 그대로 있습니다."
    say "     자세한 내용은 기록 파일에 있습니다: $(redact "$LOG_FILE")"
    SHOW_RERUN=1
    return 6
  fi
  if [ "$(cys_app_cdhash "$CYS_FORK_APP")" != "$CYS_FORK_CDHASH" ]; then
    say "[6/10] 넣은 뒤 다시 확인했더니 이번 판이 아닙니다 — 설치가 확인되지 않았습니다."
    return 6
  fi
  [ -d "$prev" ] && say "     전에 있던 cys 는 한 벌 남겨 두었습니다: $(redact "$prev")"
  [ -d "$oldprev" ] && [ ! -d "$CYS_OLD_APP" ] && say "     옛 이름의 cys(cys.app)는 한 벌 남겨 두었습니다: $(redact "$oldprev")"
  if [ -d "$CYS_OLD_APP" ]; then
    log "old app still present after swap: $CYS_OLD_APP"
    say "     옛 이름의 cys($CYS_OLD_APP)를 옮기지 못해 그 자리에 남았습니다 — 새 판은 $CYS_FORK_APP 입니다(쓰시는 데 지장은 없습니다)."
  fi
  # 넣은 자리에서도 한 번 더 실행해 본다 — 옮기는 동안 모드가 바뀌는 길(관리자 권한 복사 등)을 여기서 잡는다.
  if ! cys_app_exec_ok "$CYS_FORK_APP"; then
    say "[6/10] 넣은 뒤 실행해 보았더니 cys 가 실행되지 않습니다 (${CYS_APP_EXEC_WHY}) — 설치가 확인되지 않았습니다."
    say "     자세한 내용은 기록 파일에 있습니다: $(redact "$LOG_FILE")"
    SHOW_RERUN=1
    return 6
  fi
  say "[6/10] 설치를 마쳤습니다 (판본 ${CYS_FORK_VERSION} · 서명 확인 · 실행 확인)."
  return 0
}

# ── 6-나. 원작자 판(dmg) 설치 — 인텔 맥 · 저희 자산이 없을 때 ──────────
cys_install_from_dmg() {
  local dst="$1" core src rc
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
    say "[6/10] 설치 파일의 속 모양이 예상과 다릅니다. 공식 페이지에서 직접 받아 열어 주십시오: $CYS_MANUAL_URL"
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
       say "     창이 나타나면 「설치」를 누르시고, 이 컴퓨터의 관리자 비밀번호를 넣어 주십시오."
       say "     (자비스는 비밀번호를 대신 넣지 않습니다. 넣으신 뒤 끝나면 「닫기」를 누르십시오.)"
       open "$CYS_DMG_MNT/Install cys.app" >>"$LOG_FILE" 2>&1 || {
         say "     설치 도우미를 열지 못했습니다. 공식 페이지에서 직접 받아 열어 주십시오: $CYS_SITE_URL"
         cys_dmg_detach; return 6; }
       #   사람이 창을 다 누를 때까지 기다린다. 끝났는지는 **프로그램 실체가 생겼는가**로 본다.
       local waited=0
       while [ "$waited" -lt 300 ]; do
         [ -d /Applications/cys.app ] && break
         sleep 3; waited=$((waited + 3))
         # ps1 2979~2981 — 설치 창을 기다리는 동안 60초마다 「대기」 표지 · 3분 이상 = 정체 증거(한 번)
         if [ $((waited % 60)) -eq 0 ]; then
           progress_send '6/10' 'wait' "$waited" '' ''
           [ "$waited" -ge 180 ] && evidence_once stall
         fi
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
# ── 지난 실행 급종료 안내 — ps1 Show-PrevRunNote 386 의 맥 짝 ──────────────────────────
#   ⛔진단만 한다. J_CODE 에 넣지 않는다 — 이번 실행이 다른 까닭으로 끝나도 끝맺음에 이 코드가 실리면 엉뚱한 안내가 나간다(ps1 2026-09-14).
show_prev_run_note() {
  local tail
  [ -n "$PREV_TAIL" ] || return 0
  printf '%s' "$PREV_TAIL" | grep -qE '\[9/9\]|끝냅니다' && return 0   # 옛 판(9단)의 끝 줄 · 감지만 한 끝(ps1 388 과 같은 식)
  case "$PREV_RUN_STATE" in
    closed|ended) log "prevrun $PREV_RUN_STATE - no J-AV-03"; return 0 ;;
    answer|wait)
      if [ "$PREV_RUN_STATE" = "answer" ]; then say "지난번 실행 기록: (운영팀 처방을 받은 뒤 창이 닫혔습니다)"
      else say "지난번 실행 기록: (원격 해결을 기다리던 중에 창이 닫혔습니다)"; fi
      log "prevrun $PREV_RUN_STATE - no J-AV-03"
      say "     이어서 진행합니다 — 이미 끝난 단계는 다시 하지 않습니다."
      return 0 ;;
  esac
  say "지난번 실행이 끝을 알리지 않고 멈춘 자리가 있습니다. 그때 마지막으로 적힌 줄입니다:"
  PREV_RUN_CODE="J-AV-03"
  say "     지난 실행의 진단 코드: J-AV-03 — 지난 실행이 끝을 알리지 않고 멈췄습니다(창이 갑자기 닫혔을 수 있습니다)"
  say "     이 코드로 찾아보실 수 있습니다: ${HELP_CODE_URL}J-AV-03"
  log "prevrun J-AV-03"
  # 마지막 줄이 길면 새 실행의 첫 화면이 덮인다 — 120자에서 자른다(글자 단위)
  tail="$(printf '%s' "$PREV_TAIL" | perl -CSD -Mutf8 -ne 'chomp; print length($_) > 120 ? substr($_, 0, 120) . "…" : $_')"
  say "       $tail"
  #   ps1 의 다음 줄(「백신이 PowerShell 을 종료한 것일 수 있습니다」)은 윈도우 백신 전용 추정이라 옮기지 않는다 — 맥에서는 창을 닫았거나 Ctrl-C 로 끊은 경우가 대부분이다.
  say "     창을 닫으셨거나 Ctrl-C 로 멈추셨다면 그 때문일 수 있습니다."
  say "     이어서 진행합니다 — 이미 끝난 단계는 다시 하지 않습니다."
}

# ── 바깥 명령 출력을 화면과 기록 양쪽에 — ps1 Invoke-Logged 227 의 맥 짝 ─────────────────
#   화면은 덮이고 지워지지만 파일은 남는다. 실패한 명령의 출력일수록 남겨야 한다.
invoke_logged() { # invoke_logged <무엇> <명령> <인자...> → rc = 그 명령의 rc
  local what="$1" out rc ln; shift
  out="$("$@" 2>&1)"; rc=$?
  if [ -n "$out" ]; then
    while IFS= read -r ln; do say "       $ln"; done <<EOF_INVOKE_LOGGED
$out
EOF_INVOKE_LOGGED
  fi
  log "[$what] rc=$rc"
  return "$rc"
}

# ── 자동 시작 등록을 「말」이 아니라 「자리」로 잰다 — ps1 Get-CysAutoStartState 243 · Get-AutoStartWords 348 의 맥 짝 ──
#   맥의 자리 = LaunchAgent com.cysjavis.cysd(cys 소스 src/launchd.rs · RunAtLoad·KeepAlive · ~/Library/LaunchAgents/<이름>.plist).
#   돌려주는 값은 다섯: yes · off · other · no · unknown. 'yes' 는 셋이 모두 참일 때만 —
#     ①실행 파일이 우리가 깐 자리의 cysd 다(경로 비교) ②로그인 때 뜬다(RunAtLoad true) ③꺼져 있지 않다(plist Disabled · launchctl print-disabled)
#   ⚠못 읽으면 unknown — 모르는 것을 「없다」로 말하지 않는다. 「등록됨」과 「다음 로그인에 실제로 뜬다」는 다른 명제다(뒤는 실기 몫).
CYS_LAUNCHD_LABEL="com.cysjavis.cysd"
cys_autostart_state() { # cys_autostart_state [cli]
  local cli="${1:-}" plist prog run pdis dis uid want mine=0
  plist="$HOME/Library/LaunchAgents/${CYS_LAUNCHD_LABEL}.plist"
  [ -f "$plist" ] || { printf 'no\n'; return 0; }
  prog="$(plutil -extract ProgramArguments.0 raw -o - "$plist" 2>/dev/null)" || prog="$(plutil -extract Program raw -o - "$plist" 2>/dev/null)" || prog=""
  if [ -z "$prog" ]; then plutil -p "$plist" >/dev/null 2>&1 && { printf 'other\n'; return 0; }; printf 'unknown\n'; return 0; fi   # 읽히는데 실행 칸이 없다 = 우리 것 아님 · 못 읽는다 = 모름
  for want in "$(cys_app_dir)/Contents/MacOS/cysd" ${cli:+"$(dirname "$cli")/cysd"}; do
    [ "$prog" = "$want" ] && mine=1
  done
  [ "$mine" = "1" ] || { printf 'other\n'; return 0; }
  pdis="$(plutil -extract Disabled raw -o - "$plist" 2>/dev/null)"
  [ "$pdis" = "true" ] && { printf 'off\n'; return 0; }
  run="$(plutil -extract RunAtLoad raw -o - "$plist" 2>/dev/null)"
  [ "$run" = "true" ] || { printf 'off\n'; return 0; }
  uid="$(id -u 2>/dev/null)" || { printf 'unknown\n'; return 0; }
  dis="$(launchctl print-disabled "gui/$uid" 2>/dev/null)" || { printf 'unknown\n'; return 0; }
  if printf '%s\n' "$dis" | grep -qF -e "\"${CYS_LAUNCHD_LABEL}\" => disabled" -e "\"${CYS_LAUNCHD_LABEL}\" => true"; then printf 'off\n'; return 0; fi
  printf 'yes\n'
}
# 사람에게 할 말은 한 자리에서만 만든다 — 상태가 다섯인데 문장이 자리마다 갈리면 또 모순이 난다.
cys_autostart_words() {
  case "$1" in
    yes)   printf '%s\n' "자동 시작 등록됨 (LaunchAgent ${CYS_LAUNCHD_LABEL} · 다음 로그인부터 저절로 켜집니다)." ;;
    off)   printf '%s\n' "자동 시작 등록은 있는데 꺼져 있습니다 — 컴퓨터를 켜실 때 cys 를 한 번 열어 주십시오." ;;
    other) printf '%s\n' "${CYS_LAUNCHD_LABEL} 라는 이름의 등록이 있지만 우리 것이 아닙니다 — 자동 시작은 등록되지 않았습니다." ;;
    no)    printf '%s\n' "자동으로 켜지도록 등록되지 않았습니다(까닭은 이 화면만으로는 갈리지 않습니다)." ;;
    *)     printf '%s\n' "자동 시작 등록 여부를 확인하지 못했습니다(이 컴퓨터의 정책이 조회를 막았을 수 있습니다)." ;;
  esac
}
AUTOSTART_STATE=""
DAEMON_TEMPORARY=0

# ── cys 자리를 새 터미널의 PATH 에 — ps1 Seed-CysPath 1502 의 맥 짝 ─────────────────────
#   맥 앱은 PATH 연결을 만들지 않는다 — 설치 도우미 안에서는 전체 경로로 불러 드러나지 않고, 새 터미널에서 「cys」를 못 찾는다.
#   ⇒ seed_local_bin_path 와 같은 규칙(읽힐 수 있는 프로필 전부를 먼저 훑고 · 이미 있으면 안 쓴다 · 셸이 읽는 자리에 한 줄)으로 앱 안 자리를 넣는다(관리자 권한 0).
#   ⚠부르는 자리 = [7/10] 이 고른 길이 앱 안 경로일 때만(이미 PATH 에서 답하는 연결이 있으면 그것을 가리지 않는다).
seed_cys_path() { # seed_cys_path <폴더> → rc 0 = 있거나 넣었다 · rc 1 = 못 넣었다
  local dir="${1%/}" marker="# added by jarvis installer (cys PATH)" rc_file f found=""
  [ -n "$dir" ] || return 1
  for f in "$HOME/.zprofile" "$HOME/.zshrc" "$HOME/.zshenv" "$HOME/.profile" "$HOME/.bash_profile" "$HOME/.bashrc"; do
    [ -f "$f" ] || continue
    if grep -qF "$marker" "$f" 2>/dev/null || grep -qF "$dir" "$f" 2>/dev/null; then found="$f"; break; fi
  done
  if [ -n "$found" ]; then
    log "seed-cys-path: already in $(redact "$found")"
  else
    case "${SHELL##*/}" in
      bash) rc_file="$HOME/.bash_profile" ;;
      zsh|"") rc_file="$HOME/.zprofile" ;;
      *)    rc_file="$HOME/.profile" ;;
    esac
    if { printf '\n%s\n' "$marker"; printf 'export PATH="%s:$PATH"\n' "$dir"; } >> "$rc_file" 2>/dev/null; then
      log "seed-cys-path: added $(redact "$dir") to $(redact "$rc_file")"
    else
      log "seed-cys-path: failed - $(redact "$rc_file")"
      return 1
    fi
  fi
  case ":$PATH:" in *":$dir:"*) : ;; *) PATH="$PATH:$dir"; export PATH ;; esac
  return 0
}

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
  if [ ! -d "$(cys_app_dir)" ]; then
    say "[7/10] cys 프로그램을 찾지 못했습니다."
    return 7
  fi
  say "[7/10] cys 프로그램을 찾았습니다: $(cys_app_dir)"
  # 부르는 길이 판본에 따라 다르다. 새 판은 사용자 폴더 안에 두고, 옛 판은 시스템 폴더에 두었다.
  # 옛 자리의 링크가 끊어져 있는 경우가 실제로 있으므로, 찾은 순서대로 쓰되 답하는 것만 쓴다.
  # 프로그램 안쪽 경로는 마지막 수단이고, 우리가 링크를 새로 만들지는 않는다.
  CYS_CLI=""
  local v
  for c in "$HOME/.local/bin/cys" "/usr/local/bin/cys" "$(cys_app_dir)/Contents/MacOS/cys"; do
    [ -x "$c" ] || continue
    v="$(CYS_NO_AUTOSTART=1 "$c" --version 2>/dev/null | head -1)"
    [ -n "$v" ] || continue
    [ -z "$CYS_CLI" ] && { CYS_CLI="$c"; ver="$v"; }
    # 저희 판을 깐 맥에서는 **이번 판으로 답하는 길**을 고른다 — 옛 판에서 남은 연결이 먼저 답할 수 있다.
    [ "$CYS_KIND" = "fork" ] || break
    case "$v" in *"$CYS_FORK_VERSION"*) CYS_CLI="$c"; ver="$v"; break ;; esac
  done
  if [ -z "$CYS_CLI" ]; then
    ver="$(CYS_NO_AUTOSTART=1 cys --version 2>/dev/null | head -1)"
    [ -n "$ver" ] && CYS_CLI="cys"
  fi
  if [ -n "$ver" ] && [ -n "$CYS_CLI" ] && [ "$CYS_KIND" = "fork" ]; then
    case "$ver" in *"$CYS_FORK_VERSION"*) : ;; *)
      say "[7/10] cys 가 답하는데 이번 판(${CYS_FORK_VERSION})이 아닙니다: $ver"
      say "     부르는 길: $(redact "$CYS_CLI") — 옛 판의 연결이 남아 있습니다. 아래 「다시 하시는 법」대로 다시 실행해 주십시오."; SHOW_RERUN=1
      return 7 ;;
    esac
  fi
  if [ -n "$ver" ] && [ -n "$CYS_CLI" ]; then
    say "[7/10] cys 가 답합니다: $ver"
    say "     부르는 길: $(redact "$CYS_CLI")"
    # ps1 3075 — 새 창에서 이름만으로 cys 를 부를 수 있게(seed_cys_path 머리 주석) · 앱 안 경로로만 답했을 때
    case "$CYS_CLI" in "$(cys_app_dir)/Contents/MacOS/cys") seed_cys_path "$(dirname "$CYS_CLI")" || true ;; esac
    return 0
  fi
  say "[7/10] 프로그램은 있는데 아직 명령으로 부를 수 없습니다. 터미널 창을 새로 열고 아래 「다시 하시는 법」대로 다시 실행해 주십시오."; SHOW_RERUN=1
  return 7
}

# ── 하는 일 8 — 이 계정에 자리 잡기 ───────────────────────────────
# 관리자 권한을 쓰지 않는다. 마지막 판정은 자가진단이 전부 통과하는가로 한다.
DAEMON_PING_CAP_SEC=20   # 데몬 응답을 기다리는 상한(초) — 종전 2초×10회와 같다
DAEMON_PING_GAP=0.5      # 다시 묻기 전 간격(초) — 뜬 것을 보면 곧바로 넘어간다(installer-speed-pin-0320)
DOCTOR_TEXT=""           # [8/10] 자가진단 출력 — 뒤의 보고 갱신(2단)이 같은 명령을 다시 부르지 않고 이것을 쓴다
# ── 로그인 이어 두기(윈도우판 Copy-LoginToIsolated 2590 의 맥 짝 · TICKET=mac-parity-t1-core) ──
# 🔴09-16 실기: 설치기는 기본 프로필에 로그인했는데 자비스 자리는 `~/.cys/claude` 프로필로 떠 **로그인을 다시 요구**했다(사람 손 +1).
# 맥은 로그인 정보를 파일(.credentials.json)이 아니라 **키체인**에 둔다 — 윈도우판처럼 파일을 복사하면 아무 일도 안 일어난다.
#   실측(2026-09-16 · claude 2.1.273): 기본 프로필 = 서비스 「Claude Code-credentials」 · CLAUDE_CONFIG_DIR=<경로> 프로필 =
#   「Claude Code-credentials-<경로 sha256 앞 8자>」(~/.cys/claude → a5d624bb 일치) · 계정 칸 = 로그인 이름.
#   빈 프로필에 그 항목 하나를 복사하자 `auth status` 가 loggedIn false → true 로 바뀌었다(스크래치 프로필 · 복사 뒤 지움).
# ⚠비밀값은 명령 인자에 싣지 않는다 — `security -i` 가 표준 입력으로 받고 값은 16진(-X)으로 넘긴다(따옴표·줄바꿈 무관 · 왕복 일치 실측).
# ⚠이미 로그인된 자리면 건드리지 않는다 — 재설치에서 더 새 토큰을 옛 것으로 덮지 않게.
# ⚠여기서 안 재는 것: 두 프로필이 같은 갱신 토큰을 나눠 가진 뒤 한쪽이 토큰을 갱신하면 다른 쪽이 나중에 로그인을 다시 물을 수 있다
#   (윈도우판 파일 복사와 같은 성질 · 자비스 자리 쪽이 늘 쓰는 쪽이라 먼저 갱신하는 것도 그쪽이다 — 실기 관찰 대상).
ISO_CLAUDE_DIR_REL=".cys/claude"
claude_profile_logged_in() { # <설정 폴더> → rc 0 = 로그인돼 있다
  CLAUDE_CONFIG_DIR="$1" perl -e 'alarm shift; exec @ARGV or exit 126' 20 claude auth status 2>/dev/null | grep -q '"loggedIn"[[:space:]]*:[[:space:]]*true'
}
copy_login_to_isolated() {
  local iso="$HOME/$ISO_CLAUDE_DIR_REL" svc acct hex
  if [ "$MODE" = "dry" ]; then log "login copy: dry-run"; return 0; fi
  command -v security >/dev/null 2>&1 && command -v xxd >/dev/null 2>&1 || { log "login copy: security·xxd 명령 없음"; return 1; }
  claude_has_auth_cmd || { log "login copy: claude auth 명령 없음 — 판정 못 해 건드리지 않음"; return 1; }
  if claude_profile_logged_in "$iso"; then
    log "login copy: isolated profile already logged in — 건드리지 않음"
    return 0
  fi
  acct="$(id -un)"
  svc="Claude Code-credentials-$(printf '%s' "$iso" | shasum -a 256 | cut -c1-8)"
  hex="$(perl -e 'alarm shift; exec @ARGV or exit 126' 10 security find-generic-password -a "$acct" -s "Claude Code-credentials" -w 2>/dev/null | tr -d '\n' | xxd -p | tr -d '\n')"
  if [ -z "$hex" ]; then
    log "login copy: source keychain item not found or locked (nothing to carry over)"
    say '     (로그인 정보를 이어 두지 못했습니다. 동료들이 로그인을 물을 수 있습니다.)'
    return 1
  fi
  printf 'add-generic-password -U -a "%s" -s "%s" -X %s\n' "$acct" "$svc" "$hex" | perl -e 'alarm shift; exec @ARGV or exit 126' 10 security -i >/dev/null 2>&1
  hex=""
  if claude_profile_logged_in "$iso"; then
    say '     동료들이 쓸 로그인 정보를 이어 두었습니다.'
    log "login copy: keychain \"Claude Code-credentials\" -> \"$svc\" (되돌리기 = security delete-generic-password -s \"$svc\")"
    return 0
  fi
  say '     (로그인 정보를 이어 두지 못했습니다. 동료들이 로그인을 물을 수 있습니다.)'
  log "login copy failed: after copy the isolated profile still reports not logged in ($svc)"
  return 1
}
step_prepare_account() {
  local cli i pong doc bad
  cli="${CYS_CLI:-cys}"
  if [ "$MODE" = "dry" ]; then
    say "[8/10] (dry-run) 계정 준비를 하지 않았습니다."
    return 0
  fi
  say "[8/10] 이 계정에 자리를 잡습니다."
  # (installer-speed-pin-0320) 이 단계 안에서 무엇이 오래 걸리는지 기록에 초 단위로 남긴다(실기 비교용 · 화면에는 안 나간다).
  local t0="$SECONDS"
  invoke_logged 'init-pack' "$cli" init-pack || true   # ps1 3094 — 출력을 화면·기록 양쪽에
  log "timing 8/10 init-pack t=$((SECONDS - t0))s"
  # 윈도우판과 같은 자리(init-pack 뒤 · 데몬 등록 앞) — 자비스 자리가 뜨기 전에 로그인을 이어 둔다(로그인 1회).
  copy_login_to_isolated || true
  # 프로그램 안의 실제 파일을 직접 부른다 — 중간 연결 고리가 끊겨 있어도 이 길은 열려 있다.
  local daemon_rc=0
  invoke_logged 'daemon install' "$cli" daemon install || daemon_rc=$?
  # ★등록됐는지는 **자리를 직접 보고** 정한다(cys_autostart_state 머리 주석) — 이 값 하나로 아래 문구가 갈린다(ps1 3105).
  AUTOSTART_STATE="$(cys_autostart_state "$cli")"
  log "daemon install rc=$daemon_rc · launchd ${CYS_LAUNCHD_LABEL} = $AUTOSTART_STATE"
  log "timing 8/10 daemon-install t=$((SECONDS - t0))s"
  # 한 번 응답을 받았으면 그것으로 판정한다. 다시 물으면 그 순간의 흔들림으로 성공이 실패가 된다.
  #   (installer-speed-pin-0320) 0.5초 간격 · 상한은 시계로 20초 그대로(종전 2초×10회) — 뜬 것을 보면 곧바로 넘어간다.
  local alive=0 pstart="$SECONDS"
  while :; do
    pong="$("$cli" ping 2>&1 | tr -d '\n')"
    case "$pong" in *pong*) alive=1; break ;; esac
    [ $((SECONDS - pstart)) -ge "$DAEMON_PING_CAP_SEC" ] && break
    sleep "$DAEMON_PING_GAP"
  done
  log "timing 8/10 ping alive=$alive t=$((SECONDS - t0))s"
  if [ "$alive" -ne 1 ]; then
    # ps1 3115~3152 — 권한을 올리지 않는다. 대신 앱을 이번 한 번 직접 열어 쓸 수 있게 한다(앱이 데몬을 함께 띄운다).
    local app side
    app="$(cys_app_dir)"
    if [ -d "$app" ]; then
      # ⚠「등록이 안 됐다」와 「등록은 됐는데 지금 안 답한다」는 다른 일이다. 갈라 말한다.
      if [ "$AUTOSTART_STATE" = "yes" ]; then
        say "[8/10] 자동 시작은 등록됐는데(LaunchAgent ${CYS_LAUNCHD_LABEL}) 아직 답이 없습니다. 이번에는 프로그램을 직접 열어 보겠습니다."
      else
        say "[8/10] 이번에는 프로그램을 직접 열어 보겠습니다."
        say "     $(cys_autostart_words "$AUTOSTART_STATE")"
      fi
      open -a "$app" >>"$LOG_FILE" 2>&1 || say "       직접 열지 못했습니다: open -a $(redact "$app") 실패"
      pstart="$SECONDS"
      while :; do
        pong="$("$cli" ping 2>&1 | tr -d '\n')"
        case "$pong" in *pong*) alive=1; break ;; esac
        [ $((SECONDS - pstart)) -ge "$DAEMON_PING_CAP_SEC" ] && break
        sleep "$DAEMON_PING_GAP"
      done
      if [ "$alive" -eq 1 ]; then
        DAEMON_TEMPORARY=1
        say "[8/10] 켜졌습니다."
        # ⛔까닭을 단정하지 않는다 — 우리는 그것을 잰 적이 없다.
        say "     $(cys_autostart_words "$AUTOSTART_STATE")"
        [ "$AUTOSTART_STATE" = "yes" ] || say "     다음에 컴퓨터를 켜시면 cys 를 한 번 열어 주시면 됩니다. 그러면 그때부터 다시 돕니다."
        log "daemon started by launching the app (launchd ${CYS_LAUNCHD_LABEL} = $AUTOSTART_STATE)"
      fi
    fi
  fi
  # ★답이 왔든 안 왔든 **등록 여부는 따로 말한다** — 이 둘을 한 줄에 뭉치면 다시 모순이 생긴다.
  [ "$alive" -eq 1 ] && [ "$DAEMON_TEMPORARY" != "1" ] && say "     $(cys_autostart_words "$AUTOSTART_STATE")"
  if [ "$alive" -ne 1 ]; then
    say "[8/10] 준비는 됐는데 아직 응답이 없습니다."
    # 어느 층에서 멈췄는지 알려 주는 값이 따로 있다 — 추측하지 말고 그것을 그대로 보인다.
    invoke_logged 'daemon status' "$cli" daemon status || true
    side="$(cys_app_dir)/Contents/MacOS/cysd"
    say "       짝 파일 있음 = $([ -x "$side" ] && echo True || echo False) ($(redact "$side"))"
    say "     잠시 뒤 아래 「다시 하시는 법」대로 다시 실행해 주십시오. 그래도 같으면 위 세 줄을 알려 주십시오."; SHOW_RERUN=1
    return 8
  fi
  doc="$(CYS_NO_AUTOSTART=1 "$cli" doctor 2>&1)"
  DOCTOR_TEXT="$doc"
  log "timing 8/10 doctor t=$((SECONDS - t0))s"
  # 자가진단은 마지막에 요약 한 줄을 낸다: 「요약: 11 OK · 1 WARN · 0 FAIL · 1 SKIP(판정 불가)」
  # 그 줄이 정본이다. 항목 표시는 폭을 맞추느라 [OK  ] 처럼 빈칸이 들어가서 표시만 세면 새어 나간다.
  local summary n_skip doctor_known=1
  summary="$(printf '%s\n' "$doc" | grep '요약:' | tail -1)"
  if [ -n "$summary" ]; then
    bad="$(printf '%s\n' "$summary" | sed -n 's/.*[^0-9]\([0-9][0-9]*\)[[:space:]]*FAIL.*/\1/p')"
    n_skip="$(printf '%s\n' "$summary" | sed -n 's/.*[^0-9]\([0-9][0-9]*\)[[:space:]]*SKIP.*/\1/p')"
    say "[8/10] 자가진단: ${summary#*요약: }"
  else
    bad="$(printf '%s\n' "$doc" | grep -c '\[FAIL *\]' | tr -d ' ')"
    n_skip="$(printf '%s\n' "$doc" | grep -c '\[SKIP *\]' | tr -d ' ')"
    # 🔴N12(t4-fix) — 요약 줄이 없으면 「실패 0」이 아니라 **모른다**다(doctor 가 중간에 죽어도 [FAIL 줄은 0개다).
    #   항목에 실패가 보이면 그대로 막고, 아무것도 못 읽었으면 「미확인」이라고 말한다(「실패 0」이라 말하지 않는다).
    if [ "${bad:-0}" -gt 0 ]; then
      say "[8/10] 자가진단 요약 줄을 찾지 못해 항목을 세었습니다: 실패 ${bad}"
    else
      doctor_known=0
      say "[8/10] 자가진단 결과를 읽지 못했습니다(실패 수 미확인)."
    fi
    log "doctor summary: missing (항목 FAIL 줄 ${bad:-0})"
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
  if [ "$doctor_known" = 1 ]; then
    say "[8/10] 자리를 잡았습니다 (실패 0)."
  else
    say "[8/10] 자리를 잡았습니다 (자가진단 실패 수 미확인)."
  fi
  return 0
}

# ── 하는 일 10 — 첫 함대 부르기 ───────────────────────────────────
# 자비스는 「너는 마스터다」라는 말을 들어야 깨어나 동료를 부른다.
# 🔴2026-09-16 맥판 동등화(TICKET=mac-parity-t1-core · 윈도우판 2026-09-15 결정과 같다) — 그 말을 사람이 치지 않는다.
#   [9/10] 이 자비스를 띄울 때 **첫 프롬프트의 첫 줄**로 함께 넘긴다(wake.sh 안 · cys 명령줄에는 우리말 0).
#   ⛔창에 글을 밀어 넣는 길(cys send)은 쓰지 않는다 — 자비스가 기계 배달로 보고 동료를 부르지 않는다(2026-09-05 실측).
#     첫 프롬프트는 배달 기록에 없어 선언으로 읽힌다(팩 v0.14.36 판정기 2026-09-15 실측 · 메모리 installer-auto-declaration-first-prompt-not-cys-send).
#   앞 판 맥 주석(「사람이 직접 친 선언만 … 우리가 대신 넣지 않는다」)은 cys send 경로에 대한 말이었다 — 첫 프롬프트 경로는 그 장치에 걸리지 않는다.
# 우리가 하는 일 = ⑴마스터가 실제로 일을 시작했는지 잰다 ⑵동료 자리가 서는지 본다(최대 7분) ⑶안 서면 그때만 사람에게 부탁한다.
FLEET_TRIGGER='너는 마스터다'
FLEET_POLL_SEC=2      # 자리 목록을 몇 초마다 보는가 · 종전 5초(installer-speed-pin-0320 — 먼저 보고 나서 기다린다)
FLEET_AWAKE_TRIES=210 # 2초 × 210 = 420초(7분). 옛 240초(4분)에 팩 자원 게이트 재측정 상한(1.0.2 A2 · load 트립 시 30s×6=180s)을 더해 늘림(TICKET=installer-0325 c9 · 2026-09-18) — 윈도우판 $FleetAwakeTries 와 같은 값(90초에서 240초로 올린 까닭도 같다)
FLEET_WAIT_TRIES=180  # 2초 × 180 = 6분. (자동이 안 닿았을 때) 사람이 창을 찾아 한 문장 치기에 넉넉한 시간
FLEET_ROLES='master cso worker'
# ── 마스터 각성 판정(윈도우판 TICKET=installer-0322-awaken 의 이식 · 상수·기록 글자·화면 문구는 ps1 과 같다) ──
#   ⑴그 자리 클로드의 세션 기록(jsonl)에 답 레코드 ≥1 = 「지시를 받고 말을 했다」
#   ⑵지침의 **준비 작업 1번**이 쓰는 표지 파일 = 「받은 뒤 실제로 일을 시작했다」 — 표지 하나가 곧 verified 다(ps1 Get-MasterStateName 주석).
MASTER_MARK_NAME='awake-master.ok'   # 지침의 준비 작업 1번이 만드는 표지(우리가 만들지 않는다)
MASTER_AWAKE_CAP_SEC=120             # 첫 관측 상한 · 시험이 줄여 쓴다
MASTER_AWAKE_POLL_SEC=3
MASTER_RETRY_CAP_SEC=60              # 재시도 뒤 다시 재는 상한
MASTER_RETRY_MAX=1                   # 재시도는 **한 번**뿐이다
# 재시도 보충 한 줄의 **정본**(이 한 자리 · 시험은 이 줄을 읽어 쓴다 — 사본을 두지 않는다 · master#4bc86649 판정 A).
#   ASCII 영문인 까닭 = H-M2(우리말 장문을 창에 밀어 넣는 층의 인코딩 축)를 없앤다 · 뜻은 ps1 Send-MasterRetry 3730 우리말과 같다.
MASTER_RETRY_MSG='The earlier request asks you to read install-directive.md, judge it yourself, and then do the preparation tasks. If it looks fine, please start with preparation task 1 (create the marker file). If you decide not to, write the reason in one line.'
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
  CHILD_AWAKE_SINCE="$(date +%s)"   # 자식 자리 세션 기록은 이 시각 뒤에 생긴 것만 센다
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
# ── 자식 자리 각성 검증(TICKET=installer-awaken-verify · 2026-09-15 → installer-awaken-jsonl · 2026-09-16 · 윈도우판 Confirm-ChildSeats 와 같은 모양) ──
# 🔴자리가 선 것 ≠ 자리가 깨어난 것(샌드박스 실기 3회/3회). 팩이 자식 자리를 처음 띄울 때 각성 지시를 붙여넣기로
#   보내는데, 막 뜬 클로드가 뒤따르는 Return 을 삼켜 입력줄에 「[Pasted text #1 +529 lines]」 가 실린 채 멈춘다.
# 🔴화면을 읽어 판정하던 첫 판(09dcab0)은 거짓 양성을 냈다(2026-09-16 샌드박스 5차). ⇒ 그 자리 클로드의 세션 기록(jsonl)으로 잰다.
#   실측(맥 2026-09-16): 세션 기록 파일은 첫 지시가 제출되는 순간에 생긴다 — 제출 전에는 파일 자체가 없다.
#   깸(제출 확인) = 기준선 뒤에 생긴 그 자리 폴더의 세션 기록에 사용자 레코드 ≥1. 답 레코드는 요구하지 않는다.
#   🔴installer-awaken-verify-r2(2026-09-16 샌드박스 7차): 답 레코드까지 요구하던 판(9c49720)이 이미 답을 쓰는 중인 자리를
#     child-fail 로 찍었다 — 느린 기계에서 답 레코드는 제출 뒤 30초+ 늦게 생긴다(거짓 실패).
#   ⇒ 사용자 레코드가 0(파일 없음 포함)이면 Return 을 넣고 5·10·20초 뒤 다시 잰다(최대 3회) · 마지막 뒤에도 0 이면 10초 유예 뒤 한 번 더(자리당 90초).
#   ⛔사용자 레코드가 이미 있으면 Return 을 넣지 않는다 — 그 자리에서 확인으로 끝난다(비워진 입력줄의 Return 은 제안 글을 제출하는 경로다).
#   ★재시작(phoenix) 경로는 이미 깬다 — 이 확인은 첫 설치 [10/10] 에서만 돈다.
# ⚠맥판에는 진행 전송이 없다 — 표지(awaken:child-*)는 설치 기록에만 남는다.
# ⚠여기서 안 재는 것: ⑴기준선 뒤 같은 폴더에서 다른 클로드 세션이 제출된 경우(그 기록도 깸으로 센다)
#   ⑵세션 기록이 ~/.cys/claude/projects 밖에 있거나 폴더 이름·파일 안 cwd 가 둘 다 안 맞는 경우(끝까지 0 → 정직 문구 · 거짓 양성 쪽이 아니다)
CHILD_AWAKE_ROLES='cso worker'
CHILD_AWAKE_CAP_SEC=90
CHILD_AWAKE_GAPS='5 10 20'   # Return 뒤 다시 재기 전 기다림
CHILD_AWAKE_GRACE_SEC=10     # 마지막 Return 뒤에도 기록이 없을 때 한 번 더 재기 전 유예
CHILD_AWAKE_MAX_RETRY=3
CHILD_READ_CAP_SEC=10   # cys 한 번 부르기의 상한(맥에는 timeout 명령이 없어 perl alarm 으로 묶는다)
CHILD_AWAKE_SINCE="$(date +%s)"   # 이 시각(초) 뒤에 생긴 세션 기록만 센다 · 기준선을 찍을 때 다시 잡는다
cys_capped() { # cys_capped <초> <명령> <인자...>
  local cap="$1"; shift
  #   `or exit 126` — perl 의 exec 는 실행 파일을 못 찾아도 rc 0 으로 끝난다(2026-09-16 실측) · 실패를 성공으로 돌려주지 않게.
  CYS_NO_AUTOSTART=1 perl -e 'alarm shift; exec @ARGV or exit 126' "$cap" "$@" 2>/dev/null
}
# 클로드가 세션 기록 폴더 이름을 짓는 규칙 = 경로의 영숫자 아닌 글자를 하나씩 - 로(맥 실측 · 한글도 한 글자에 - 하나)
claude_project_slug() { perl -CSA -e '$_ = shift; s/[^A-Za-z0-9]/-/g; print' "$1"; }
born_since() { # born_since <파일> → 기준선 뒤에 생긴 파일이면 생긴 시각(초)을 찍고 rc 0
  local b
  b="$(/usr/bin/stat -f %B "$1" 2>/dev/null)" || return 1
  [ -n "$b" ] && [ "$b" -ge "$CHILD_AWAKE_SINCE" ] || return 1
  printf '%s\n' "$b"
}
seat_session_file() { # seat_session_file <자리 폴더> → 그 자리의 세션 기록 경로(가장 새것) · 없으면 빈 출력
  local cwd="$1" root="$HOME/.cys/claude/projects" f b best="" bestb=-1 needle
  [ -d "$root" ] || return 0
  for f in "$root/$(claude_project_slug "$cwd")"/*.jsonl; do
    [ -f "$f" ] || continue
    b="$(born_since "$f")" || continue
    [ "$b" -gt "$bestb" ] && { best="$f"; bestb="$b"; }
  done
  if [ -z "$best" ]; then
    # 폴더 이름 규칙이 안 맞으면 projects 아래 전체에서 파일 안 "cwd" 글자로 찾는다(규칙 추정에 기대지 않는다)
    needle="\"cwd\":\"$(printf '%s' "$cwd" | sed 's/\\/\\\\/g; s/"/\\"/g')\""
    for f in "$root"/*/*.jsonl; do
      [ -f "$f" ] || continue
      b="$(born_since "$f")" || continue
      [ "$b" -gt "$bestb" ] || continue
      LC_ALL=C grep -qF -- "$needle" "$f" && { best="$f"; bestb="$b"; }
    done
  fi
  [ -z "$best" ] || printf '%s\n' "$best"
  return 0
}
seat_session_counts() { # seat_session_counts <파일> → "사용자레코드수 답레코드수"(파일이 없으면 0 0)
  local u=0 a=0
  if [ -n "$1" ] && [ -f "$1" ]; then
    u="$(LC_ALL=C grep -cF '"type":"user"' "$1" 2>/dev/null)"
    a="$(LC_ALL=C grep -cF '"type":"assistant"' "$1" 2>/dev/null)"
  fi
  printf '%s %s\n' "${u:-0}" "${a:-0}"
}
CHILD_RETRY=0
CHILD_U=0
CHILD_A=0
CHILD_WHY=""
confirm_child_seat() { # <명령> <역할> <자리> <자리 폴더> → rc 0 깸 확인 · 1 답 없음 (CHILD_RETRY · CHILD_U · CHILD_A · CHILD_WHY)
  local cli="$1" role="$2" ref="$3" cwd="$4" start counts gap graced=0
  CHILD_RETRY=0; CHILD_U=0; CHILD_A=0; CHILD_WHY=""
  if [ -z "$cwd" ]; then CHILD_WHY=no-cwd; return 1; fi   # 폴더를 모르면 잴 수 없다 — Return 도 넣지 않는다
  start="$(date +%s)"
  while [ $(( $(date +%s) - start )) -lt "$CHILD_AWAKE_CAP_SEC" ]; do
    counts="$(seat_session_counts "$(seat_session_file "$cwd")")"
    CHILD_U="${counts% *}"; CHILD_A="${counts#* }"
    if [ "$CHILD_U" -ge 1 ]; then CHILD_WHY=jsonl; return 0; fi   # 제출 확인 — 답 레코드는 늦게 생긴다
    if [ "$CHILD_RETRY" -lt "$CHILD_AWAKE_MAX_RETRY" ]; then
      CHILD_RETRY=$((CHILD_RETRY + 1))
      cys_capped "$CHILD_READ_CAP_SEC" "$cli" send-key --surface "$ref" Return >/dev/null
      log "awaken child: role=${role} seat=${ref} marker=awaken:child-retry ${CHILD_RETRY}"
      progress_send '10/10' 'info' '' "awaken:child-retry ${CHILD_RETRY}" ''   # ps1 3635
      capture_evidence retry "awaken:child-retry role=${role} seat=${ref} n=${CHILD_RETRY}"   # ⓕ② v0.3.20
      gap="$(printf '%s\n' $CHILD_AWAKE_GAPS | awk -v n="$CHILD_RETRY" 'NR <= n { g = $0 } END { print g + 0 }')"
      sleep "$gap"
    elif [ "$graced" = 0 ]; then
      graced=1   # 마지막 Return 뒤 기록이 늦게 생기는 기계 — 유예 한 번 뒤 다시 잰다(Return 은 더 넣지 않는다)
      sleep "$CHILD_AWAKE_GRACE_SEC"
    else
      break
    fi
  done
  CHILD_WHY=no-submit
  return 1
}
# 캡처 증거 함수(capture_evidence·post_install_evidence·current_step)는 파일 위쪽 「진행 자동 전송·진단 자료(증거)」 구역으로 옮겼다(mac-parity-t2 · 2026-09-16).
confirm_child_seats() { # <명령> — 새로 선 cso·worker 자리마다 깸을 확인한다(설치는 막지 않는다)
  local cli="$1" out line sid r seen=" " seats="" role ref cwd tail tab
  tab="$(printf '\t')"
  out="$(CYS_NO_AUTOSTART=1 "$cli" list 2>&1)"
  while IFS= read -r line; do
    sid="$(printf '%s' "$line" | grep -oE 'surface:[0-9]+' | head -1)"
    [ -n "$sid" ] || continue
    case "$FLEET_BASELINE" in *" $sid "*) continue ;; esac
    for r in $CHILD_AWAKE_ROLES; do
      case "$seen" in *" ${r} "*) continue ;; esac
      if printf '%s' "$line" | grep -qE "(^|[[:space:]])role=${r}([[:space:]]|-|$)"; then
        cwd="$(printf '%s\n' "$line" | awk -F'\t' 'NF >= 6 { print $NF }')"
        seen="$seen$r "
        seats="$seats$r$tab$sid$tab$cwd
"
      fi
    done
  done <<EOF_CHILD
$out
EOF_CHILD
  while IFS="$tab" read -r role ref cwd <&3; do
    [ -n "$role" ] || continue
    if confirm_child_seat "$cli" "$role" "$ref" "$cwd"; then
      # ★이 판정이 재는 것은 **제출**이다(사용자 레코드 >=1) — 「받아들였다」가 아니다(TICKET=installer-0322-awaken).
      say "     ${role} 자리 지시 제출 확인"
      log "awaken child: role=${role} seat=${ref} marker=awaken:child-verified retries=${CHILD_RETRY} evidence=jsonl u=${CHILD_U} a=${CHILD_A}"
      progress_send '10/10' 'info' '' 'awaken:child-verified' ''   # ps1 3675
    else
      say "     ${role} 자리는 열렸으나 아직 답이 없습니다 — 자비스가 이어서 깨웁니다(사람 손 0)"
      log "awaken child: role=${role} seat=${ref} marker=awaken:child-fail retries=${CHILD_RETRY} why=${CHILD_WHY} u=${CHILD_U} a=${CHILD_A}"
      progress_send '10/10' 'info' '' 'awaken:child-fail' ''   # ps1 3680
      tail="$(cys_capped "$CHILD_READ_CAP_SEC" "$cli" read-screen --surface "$ref")"
      log "awaken child stall tail (${role}): $(printf '%s\n' "$tail" | tail -n 15 | tr '\n' '|' | cut -c1-600)"
      child_stall_evidence "$role" "$tail"   # ps1 3682 Send-ChildStallEvidence — 자리마다 한 번 · fail-open
    fi
  done 3<<EOF_SEATS
$seats
EOF_SEATS
  return 0
}
# ── 마스터 각성 판정 함수들(윈도우판 Get-MasterMarkPath 3687 ~ Set-FleetNeedsMaster 3808 의 이식) ──
master_mark_path() { printf '%s\n' "$JARVIS_HOME/$MASTER_MARK_NAME"; }
clear_master_mark() { # 지운다 — 단 **우리 자비스 폴더 안의 그 이름 하나**만(지난 설치 표지가 이번 각성으로 읽히지 않게)
  local f err
  f="$(master_mark_path)"
  if [ -e "$f" ]; then
    if err="$(rm -f "$f" 2>&1)" && [ ! -e "$f" ]; then
      log "master mark: cleared stale $f"
    else
      log "master mark: clear failed (이어 간다) $err"
    fi
  fi
  return 0
}
test_master_mark() { # rc 0 = 표지가 있고 **이번 설치의 기준선 뒤에** 쓰였다
  local f t
  f="$(master_mark_path)"
  [ -e "$f" ] || return 1
  t="$(/usr/bin/stat -f %m "$f" 2>/dev/null)" || return 1
  # 5초 여유 = 파일 시각 알갱이·기준선을 찍는 순간의 어긋남만 흡수한다(ps1 과 같은 값)
  [ -n "$t" ] && [ "$t" -ge $((CHILD_AWAKE_SINCE - 5)) ]
}
master_assistant_count() { # 마스터 자리 세션 기록의 답 레코드 수(자식 판정과 같은 읽기 코드 · 자리 폴더 = 자비스 폴더)
  local counts
  counts="$(seat_session_counts "$(seat_session_file "$JARVIS_HOME")" 2>/dev/null)"
  printf '%s\n' "${counts#* }" | grep -E '^[0-9]+$' || printf '0\n'
}
wait_master_signs() { # wait_master_signs <상한초> → MS_MARK(True|False) · MS_A
  local cap="$1" start
  start="$(date +%s)"
  MS_MARK=False; MS_A=0
  while :; do
    [ "$MS_MARK" = True ] || { test_master_mark && MS_MARK=True; }
    [ "$MS_A" -ge 1 ] || MS_A="$(master_assistant_count)"
    [ "$MS_MARK" = True ] && break   # 표지가 곧 판정이다 — 답 기록을 더 기다리지 않는다
    [ $(( $(date +%s) - start )) -ge "$cap" ] && break
    sleep "$MASTER_AWAKE_POLL_SEC"
  done
  return 0
}
send_master_retry() { # send_master_retry <명령> <자리> → rc 0 = 보냈다
  local cli="$1" ref="$2" msg
  [ -n "$ref" ] || return 1
  # ⚠맥판 문구는 **ASCII 영문**이다(브리프 H-M2 회피 — 창에 밀어 넣는 글이 지나는 층의 인코딩 축을 없앤다).
  #   뜻은 ps1 Send-MasterRetry 3730 의 우리말 문구와 같다. ⛔선언(「너는 마스터다」)을 다시 보내지 않는다.
  msg="$MASTER_RETRY_MSG"
  # 🔴보내기가 실패하면 Return 을 넣지 않는다(762 보고서 D2 — 입력줄에 남은 제안 글이 제출되는 경로).
  if ! cys_capped "$CHILD_READ_CAP_SEC" "$cli" send --surface "$ref" "$msg" >/dev/null; then
    log "awaken master: retry send FAILED seat=$ref"
    return 1
  fi
  sleep 2
  cys_capped "$CHILD_READ_CAP_SEC" "$cli" send-key --surface "$ref" Return >/dev/null
  log "awaken master: marker=awaken:master-retry seat=$ref"
  progress_send '10/10' 'info' '' 'awaken:master-retry' ''
  capture_evidence retry "awaken:master-retry seat=$ref"
  return 0
}
master_state_name() { # <표지 True|False> <답 수> → verified | no-start | unknown (셋으로 가르는 자리는 이 하나다)
  if [ "$1" = True ]; then printf 'verified\n'
  elif [ "${2:-0}" -ge 1 ]; then printf 'no-start\n'
  else printf 'unknown\n'
  fi
}
confirm_master_awake() { # <명령> <자리> → MASTER_STATE · MASTER_MARK · MASTER_A · MASTER_RETRY
  local cli="$1" ref="$2"
  wait_master_signs "$MASTER_AWAKE_CAP_SEC"
  MASTER_RETRY=0
  if [ "$MS_MARK" != True ] && [ "$MS_A" -ge 1 ] && [ "$MASTER_RETRY_MAX" -ge 1 ]; then
    if send_master_retry "$cli" "$ref"; then
      MASTER_RETRY=1
      wait_master_signs "$MASTER_RETRY_CAP_SEC"
    fi
  fi
  MASTER_STATE="$(master_state_name "$MS_MARK" "$MS_A")"; MASTER_MARK="$MS_MARK"; MASTER_A="$MS_A"
  log "awaken master: marker=awaken:master-${MASTER_STATE} mark=${MASTER_MARK} a=${MASTER_A} retry=${MASTER_RETRY}"
  progress_send '10/10' 'info' '' "awaken:master-${MASTER_STATE}" ''
  return 0
}
master_state_now() { # 기다리지 않고 **지금 한 번**만 본다(재시도 없음)
  wait_master_signs 0
  MASTER_STATE="$(master_state_name "$MS_MARK" "$MS_A")"; MASTER_MARK="$MS_MARK"; MASTER_A="$MS_A"; MASTER_RETRY=0
  log "awaken master: marker=awaken:master-${MASTER_STATE} mark=${MASTER_MARK} a=${MASTER_A} retry=0 (recheck)"
  progress_send '10/10' 'info' '' "awaken:master-${MASTER_STATE}" ''
  return 0
}
say_master_state() { # 셋을 **서로 다른 문구**로 찍는다(ps1 Write-MasterSay 와 같은 글자)
  case "$MASTER_STATE" in
    verified) say '     자비스(master) 각성 확인 — 지시를 받고 준비 작업을 시작했습니다.' ;;
    no-start) say '     자비스(master)는 지시를 받았으나 준비 작업을 시작하지 않았습니다.'
              say '     (요청을 판단해 보고 거절했거나, 표지 파일을 쓰지 못했을 수 있습니다 — 무엇인지 여기서는 단정하지 않습니다.)' ;;
    *)        say '     자비스(master)가 깼는지 판정하지 못했습니다 — 세션 기록도 표지 파일도 찾지 못했습니다.' ;;
  esac
}
master_request_card() { # 받았는데 시작 안 한 끝에서만 · ⛔「너는 마스터다」를 적지 않는다(이미 들어갔다)
  human '자비스' '자비스가 아직 준비 작업을 시작하지 않아 한 줄만 부탁드립니다 — cys 창에서 입력해 주십시오'
  say ''
  say '   ┌───────────────────────────────────────────────────────────────┐'
  say '   │   cys 창(제목 jarvis)에 이렇게 입력해 주십시오:               │'
  say '   │                                                               │'
  say '   │     install-jarvis 폴더의 install-directive.md 를 읽고,       │'
  say '   │     거기 적힌 준비 작업을 해 주세요.                          │'
  say '   │                                                               │'
  say '   └───────────────────────────────────────────────────────────────┘'
  say ''
  say '   자비스가 그 파일을 읽고 판단한 뒤 준비 작업을 시작합니다. 거절하면 그 까닭을 사람 말로 알려 줍니다.'
}
master_unknown_card() { # 「판정 못 함」은 「거절했다」가 아니다 — 문구가 다르다
  say ''
  say '   cys 창(제목 jarvis)을 열어 자비스가 무엇을 하고 있는지 보아 주십시오.'
  say '   아무 말도 하지 않고 있으면 이렇게 입력해 주시면 됩니다: install-jarvis 폴더의 install-directive.md 를 읽고, 거기 적힌 준비 작업을 해 주세요.'
}
# 기다리는 동안 설치 창에 친 글자를 비운다(ps1 Clear-FleetStrayKeys 3508 의 짝) — 비우지 않으면 설치가 끝난 뒤 셸이 그 줄을 **명령으로** 읽는다
#   (예: 카드를 보고 이 창에 「너는 마스터다」+Enter → zsh: command not found). 개수만 기록한다(글자는 적지 않는다).
#   ⚠터미널이 아닐 때(흉내·파이프)는 아무것도 하지 않는다 · 한 번에 최대 4096자.
drain_tty_keys() {
  local n=0 c
  if [ -t 0 ]; then
    while [ "$n" -lt 4096 ] && IFS= read -r -s -n 1 -t 1 c 2>/dev/null; do n=$((n + 1)); done
  else
    n=-1
  fi
  log "fleet stray keys in installer window cleared=$n"
  return 0
}
set_fleet_finished() { # 끝났다고 적는다 — 안 적으면 끝맺음이 「예상 못 한 끝」으로 읽고 다시 실행 안내를 찍는다
  NEXT_STEP='없습니다 — 설치가 끝났습니다. 이 창을 닫으셔도 됩니다.'
  SHOW_RERUN=0
}
set_fleet_needs_master() {
  NEXT_STEP='cys 창(제목 jarvis)의 자비스에게 위 한 줄을 전해 주십시오. 그것으로 설치가 끝납니다.'
  SHOW_RERUN=0
}
# 설치 창을 멈춰도(Ctrl-C) 자비스 창은 그대로 둔다(TICKET=mac-parity-t1-core · 09-16 실기 「jarvis 칸 exited · 설치기 ^C 동반 종료 추정」).
#   자비스 자리는 cys 데몬의 자식이지 이 창의 자식이 아니다 — 이 창이 끝나도 자리가 죽을 까닭이 없게 만드는 것이 목표다.
#   ⑴여기서는 기다림만 끝내고 「자비스 창은 그대로 둡니다」를 말한다(자리를 끄는 명령을 보내지 않는다).
#   ⑵데몬이 이 창과 같은 프로세스 묶음에 있으면(= Ctrl-C 가 데몬까지 간다) 그 사실을 기록에 남긴다 — 실기에서 원인을 가를 증거.
fleet_on_interrupt() {
  trap - INT
  printf '\n%s\n' '   설치 창의 기다림을 멈췄습니다 — 자비스 창(cys)은 그대로 둡니다. 거기서 이어서 이야기하시면 됩니다.'
  log "fleet: interrupted by owner (Ctrl-C) — seats left running"
  NEXT_STEP='자비스 창(cys 창 · 제목 jarvis)에서 이어서 이야기하십시오. 이 설치 창은 닫으셔도 됩니다.'
  SHOW_RERUN=0
  exit 130
}
note_daemon_group() { # 데몬이 이 창과 같은 프로세스 묶음(Ctrl-C 가 닿는 묶음)에 있는가 — 기록만 한다
  local my d dg
  my="$(ps -o pgid= -p $$ 2>/dev/null | tr -d ' ')"
  for d in $(pgrep -x cysd 2>/dev/null); do
    dg="$(ps -o pgid= -p "$d" 2>/dev/null | tr -d ' ')"
    if [ -n "$my" ] && [ "$dg" = "$my" ]; then
      log "daemon group: cysd pid=$d shares installer pgid=$my — Ctrl-C here would reach the daemon"
    else
      log "daemon group: cysd pid=$d pgid=${dg:-?} (installer pgid=${my:-?}) — separate"
    fi
  done
}
step_fleet() {
  local ref="$1" cli i r live missing waited=0 fleet_start prev_state
  cli="${CYS_CLI:-cys}"
  if [ "$MODE" = "dry" ]; then say "[10/10] (dry-run) 함대를 부르지 않았습니다."; return 0; fi
  if [ -z "$ref" ]; then
    say "[10/10] 자비스 창을 못 열어 동료들을 부르지 못했습니다."
    say "     cys 창에서 자비스에게 이렇게 말해 주십시오: $FLEET_TRIGGER"
    return 10
  fi
  # ★기준선을 못 찍었으면 **여기서 멈춘다** — 세어 봐야 그 수가 무엇을 뜻하는지 모른다.
  if [ "$FLEET_BASELINE_OK" != "1" ]; then
    say "[10/10] 지금 열려 있는 자리 목록을 읽지 못해, 동료들이 섰는지 판정하지 않습니다."
    say "     cys 창에서 자비스에게 이렇게 말해 주십시오: $FLEET_TRIGGER"
    say "     그 뒤 자비스에게 「동료들 다 섰어?」라고 물어보시면 자비스가 직접 확인해 알려 드립니다."
    return 10
  fi
  note_daemon_group
  trap 'fleet_on_interrupt' INT
  # ── ① 마스터가 **실제로** 깼는지 먼저 잰다(ps1 Step-Fleet 3842 와 같은 순서 — 동료 자리는 편성 자동 복구로도 선다) ──
  say '[10/10] 자비스(master)가 지시를 받고 준비 작업을 시작하는지 봅니다 (최대 2분 · 사람이 하실 일은 없습니다).'
  confirm_master_awake "$cli" "$ref"
  say_master_state
  # ── ② 자동 각성 확인(사람 손 0) — 선언은 [9/10] 이 첫 프롬프트로 이미 넘겼다 ──
  say '[10/10] 자비스가 깨어나 동료들을 부르는지 지켜봅니다 (최대 7분 · 사람이 하실 일은 없습니다).'
  log "fleet: auto awaken - watching child seats in $ref (cap $((FLEET_AWAKE_TRIES * FLEET_POLL_SEC))s)"
  fleet_start="$(date +%s)"
  i=0
  while [ "$i" -lt "$FLEET_AWAKE_TRIES" ]; do
    live="$(live_roles "$cli")"
    [ "$(printf '%s' "$live" | wc -w | tr -d ' ')" -ge 3 ] && break
    sleep "$FLEET_POLL_SEC"   # 먼저 보고 나서 기다린다 — 이미 섰으면 한 번도 기다리지 않는다
    i=$((i + 1))
  done
  # ★성공의 근거 = 자식 좌석. 우리가 연 master 자리는 근거가 못 된다(declaration_seen 머리 주석).
  if declaration_seen "$live"; then
    log "fleet awaken: auto - seats=$(printf '%s' "$live" | tr ' ' ',')"
    progress_send '10/10' 'end' "$(( $(date +%s) - fleet_start ))" 'awaken:auto' ''
    missing=""
    for r in $FLEET_ROLES; do printf '%s' " $live " | grep -q " $r " || missing="$missing $r"; done
    if [ -z "$missing" ]; then
      say "[10/10] 함대가 섰습니다: $(printf '%s' "$live" | sed 's/ / · /g')"
    else
      say "[10/10] 선 자리 = $(printf '%s' "$live" | sed 's/ / · /g') · 남은 자리($(printf '%s' "${missing# }" | sed 's/ / · /g'))는 아래에서 계속 지켜봅니다."
      log "fleet missing at awaken: $(printf '%s' "${missing# }" | tr ' ' ',')"
    fi
    # ★자리가 선 것만으로 끝내지 않는다 — 선 자식 자리가 실제로 깼는지 확인하고, 멈췄으면 깨운다.
    confirm_child_seats "$cli"
    post_install_evidence "$cli" "$ref"
    say ''
    # 🔴H-M1 수리(762 보고서 D1 처방) — 첫 판정은 **몇 분 전** 값이다. 그 사이 표지가 생겼을 수 있다(동료가 선 뒤에 표지 = master-late-fleet).
    #   ⇒ 최종 판정 직전에 verified 가 아니면 **한 번만** 다시 잰다. 문구는 상태가 바뀐 때만 다시 찍는다(두 번 찍히지 않게).
    if [ "$MASTER_STATE" != verified ]; then
      prev_state="$MASTER_STATE"
      master_state_now
      [ "$MASTER_STATE" = "$prev_state" ] || say_master_state
    fi
    # 🔴「깨어났습니다」는 **마스터 판정이 verified 일 때만** 말한다.
    if [ "$MASTER_STATE" = verified ]; then
      raise_cys_app_window   # c7 — 다 선 지금이 참가자가 창을 찾는 순간이다(재기동 없이 앞으로만)
      say '   자비스가 깨어났습니다 — 이제 설치 창을 닫으셔도 됩니다.'
      say '   (설치 창을 닫아도 자비스 창은 그대로 둡니다 — 이어서 cys 창의 자비스와 이야기하시면 됩니다.)'
      say '   cysr 창이 앞에 보이지 않으면 Dock 의 cysr 아이콘을 한 번 눌러 주세요(다시 실행하지 않습니다).'
      set_fleet_finished
      drain_tty_keys
      trap - INT
      return 0
    fi
    say '   동료 자리는 섰지만, 자비스(master)가 준비 작업을 시작한 것은 확인하지 못했습니다.'
    if [ "$MASTER_STATE" = no-start ]; then master_request_card; else master_unknown_card; fi
    set_fleet_needs_master
    drain_tty_keys
    trap - INT
    return 10
  fi
  # 상한 안에 동료 자리가 하나도 안 섰다 = 자동 각성이 닿지 않았다 ⇒ **그때만** 사람에게 부탁한다(원인은 단정하지 않는다).
  log "fleet awaken: no child seat within $((FLEET_AWAKE_TRIES * FLEET_POLL_SEC))s -> manual fallback card"
  progress_send '10/10' 'info' "$(( $(date +%s) - fleet_start ))" 'awaken:manual-fallback' ''
  # 🔴N13(t4-fix) — 마스터가 이미 깼으면(verified) 선언을 다시 치게 하지 않는다. 동료가 늦는 것뿐이다(사람 손 0).
  #   선언 카드는 마스터가 깼는지 모르거나(unknown) 시작하지 않았을 때(no-start)에만 낸다.
  if [ "$MASTER_STATE" = verified ]; then
    say "[10/10] 마스터는 깨어났습니다 · 동료 자리는 자비스가 세우는 중입니다($((FLEET_WAIT_TRIES * FLEET_POLL_SEC / 60))분 더 기다립니다) · 사람이 하실 일은 없습니다."
    log "fleet: master verified - waiting for child seats without declaration card in $ref"
  else
    human "자비스" "자비스가 저절로 깨어나지 않아 한마디만 부탁드립니다 — cys 창에서 입력해 주십시오"
    say ""
    say "   ┌──────────────────────────────────────────────────┐"
    say "   │   cys 창(제목 jarvis)에 이렇게 입력해 주십시오:  │"
    say "   │                                                  │"
    say "   │        ${FLEET_TRIGGER}                             │"
    say "   │                                                  │"
    say "   └──────────────────────────────────────────────────┘"
    say ""
    say "   cys 창 = 방금 열린 cys 앱 창입니다(이 검은 터미널 창이 아닙니다). 안 보이면 Dock 의 cys 아이콘을 누르십시오."
    say "   그 한마디를 들으면 자비스가 동료들을 부릅니다. 여기서 기다리다가 다 서면 알려 드립니다."
    log "fleet: waiting for owner declaration in $ref"
  fi
  live=""
  i=0
  while [ "$i" -lt "$FLEET_WAIT_TRIES" ]; do
    live="$(live_roles "$cli")"
    [ "$(printf '%s' "$live" | wc -w | tr -d ' ')" -ge 3 ] && break
    sleep "$FLEET_POLL_SEC"   # 먼저 보고 나서 기다린다(installer-speed-pin-0320)
    waited=$((waited + FLEET_POLL_SEC))
    i=$((i + 1))
    if [ "$i" -gt 0 ] && [ $((i % 30)) -eq 0 ]; then
      if declaration_seen "$live"; then
        say "   자비스가 동료들을 부르는 중입니다. 그대로 기다려 주십시오 ($((waited / 60))분 지남 · 최대 $((FLEET_WAIT_TRIES * FLEET_POLL_SEC / 60))분)."
        say "     선 자리 = $(printf '%s' "$live" | sed 's/ / · /g')  (사람이 하실 일은 없습니다)"
      elif [ "$MASTER_STATE" = verified ]; then
        say "   동료 자리를 기다리는 중입니다 ($((waited / 60))분 지남 · 최대 $((FLEET_WAIT_TRIES * FLEET_POLL_SEC / 60))분 · 사람이 하실 일은 없습니다)."
      else
        say "   기다리는 중입니다 ($((waited / 60))분 지남 · 최대 $((FLEET_WAIT_TRIES * FLEET_POLL_SEC / 60))분). 아직 입력하지 않으셨다면 지금 입력해 주십시오."
      fi
    fi
  done
  missing=""
  for r in $FLEET_ROLES; do printf '%s' " $live " | grep -q " $r " || missing="$missing $r"; done
  if [ -z "$missing" ]; then
    say "[10/10] 함대가 섰습니다: $(printf '%s' "$live" | sed 's/ / · /g')"
    log "fleet awaken: success after fallback card - seats=$(printf '%s' "$live" | tr ' ' ',')"
    confirm_child_seats "$cli"
    post_install_evidence "$cli" "$ref"
    # 카드 뒤 6분 사이에 마스터가 시작했을 수 있다 ⇒ **한 번만 다시 본다**(재시도는 하지 않는다 · 이미 1회 썼다).
    master_state_now
    say_master_state
    trap - INT
    if [ "$MASTER_STATE" != verified ]; then
      say '   동료 자리는 섰지만, 자비스(master)가 준비 작업을 시작한 것은 확인하지 못했습니다.'
      if [ "$MASTER_STATE" = no-start ]; then master_request_card; else master_unknown_card; fi
      set_fleet_needs_master
      drain_tty_keys
      return 10
    fi
    set_fleet_finished
    drain_tty_keys
    return 0
  fi
  # 성공보다 이 문구가 중요하다 — 무엇이 없어서 못 섰는지를 그대로 말한다.
  say "[10/10] 아직 서지 않은 자리가 있습니다: $(printf '%s' "${missing# }" | sed 's/ / · /g')"
  say "     선 자리 = $( [ -n "$live" ] && printf '%s' "$live" | sed 's/ / · /g' || printf '없음')"
  if declaration_seen "$live"; then
    say "     자비스는 이미 깨어 있습니다(master 자리가 섰습니다) — 그 한마디는 들어갔습니다."
    say "     남은 자리를 다시 세우려면 cysr 창의 jarvis 칸에 『너는 마스터다.』 한 줄을 다시 쳐 주십시오(이 설치 창이 아닙니다)."
  elif [ "$MASTER_STATE" = verified ]; then
    say "     마스터는 깨어 있습니다. 남은 자리를 다시 세우려면 cysr 창의 jarvis 칸에 『너는 마스터다.』 한 줄을 다시 쳐 주십시오(이 설치 창이 아닙니다)."
    say "     오래 서지 않으면 cys 창의 자비스에게 무엇이 걸렸는지 물어보십시오."
    NEXT_STEP='cys 창(제목 jarvis)의 자비스와 이어서 이야기하십시오 — 남은 자리가 왜 안 섰는지 물어보시면 됩니다.'
    SHOW_RERUN=0
  else
    say "     아직 그 한마디를 입력하지 않으셨다면, cys 창에서 지금 입력해 주시면 됩니다."
    say "     치셨는데도 서지 않았다면 cys 창의 자비스에게 물어보십시오 — 무엇이 걸렸는지 사람 말로 알려 줍니다."
  fi
  log "fleet missing: $(printf '%s' "${missing# }" | tr ' ' ',')"
  drain_tty_keys
  trap - INT
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
  # 🔴**cys 에 넘기는 인자**는 ASCII 로만 쓴다(자리 여는 명령 · 창 이름) — 윈도우에서 우리말 인자가 깨져 거절당했다.
  #   첫 지시는 cys 를 지나지 않는다: wake.sh 안에 적혀 claude 에게 바로 가고, 이 창 폴백에서도 claude 의 인자로 바로 간다.
  # 🔴2026-09-16 개정(TICKET=installer-0322-awaken · 윈도우판과 같은 문구로 맞춘다).
  #   앞 문구(... do exactly what it says. Your first line must be the fixed line specified there.)가
  #   같은 날 윈도우 샌드박스에서 **거부**를 불렀다 — 모델이 거절한 것은 지령의 내용이 아니라
  #   (1)읽어 보기 전에 그대로 실행하라 (2)첫마디를 이 대본으로 하라는 **요구의 형태**였다.
  #   문구만 의뢰형으로 바꾼 같은 자리에서 같은 모델이 같은 파일을 읽고 수행했다(2026-09-16 13:25 A/B 실측).
  # 🔴2026-09-16 맥판 동등화(TICKET=mac-parity-t1-core · 목표 「사람 손이 클로드 로그인 외에 필요 없게」) —
  #   앞 판 주석(「맥은 선언을 첫 지시에 싣지 않는다 · 표지 판정도 없다」)은 폐기한다. 윈도우판 Step-Wake 3244~ 와 같이
  #   ⑴선언을 첫 프롬프트의 **첫 줄**로 싣고 ⑵[10/10] 이 표지 파일(awake-master.ok)로 마스터를 실제로 잰다.
  #   ⛔첫 줄 「너는 마스터다」는 인사말이 아니라 **팩 훅의 선언 트리거**다(javis_detect.py · 의뢰 문구 단독 = 선언 없음 실측).
  first_prompt="install-jarvis 폴더의 install-directive.md(${DIRECTIVE_FILE}) 를 읽고, 거기 적힌 준비 작업을 해 주세요."
  local wake_prompt wake_quoted
  wake_prompt="${FLEET_TRIGGER}
${first_prompt}"
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
    # 경로에 작은따옴표가 있으면(사용자 이름 등) 문자열이 거기서 닫혀 wake.sh 가 안 돈다 ⇒ '\'' 로 글자로 남긴다(ps1 3313 과 같은 방어).
    wake_quoted="$(printf '%s' "$wake_prompt" | sed "s/'/'\\\\''/g")"
    printf '#!/bin/bash\nCLAUDE="$HOME/.local/bin/claude"\n[ -x "$CLAUDE" ] || CLAUDE=claude\nexec "$CLAUDE" --dangerously-skip-permissions %s\n' "'$wake_quoted'" > "$wake_file" 2>/dev/null
    chmod +x "$wake_file" 2>/dev/null
    # ★cys 앱 창을 **자리를 열기 전에** 연다(09-16 실기 「앱 창 미가시 · 사람이 open 을 쳤고 오타」 · 윈도우는 앱이 창과 함께 뜬다).
    #   앞에 두는 까닭 = 앱이 뜨며 편성 복구로 지난 자리를 세울 수 있다 — 기준선보다 앞이어야 그 자리가 「이번 설치의 것」으로 안 세어진다.
    open_cys_app
    # ★지난 설치가 남긴 표지를 먼저 치운다 — 남아 있으면 이번 마스터가 아무 일도 안 해도 「시작했다」로 읽힌다(ps1 Clear-MasterMark).
    clear_master_mark
    # ★자리를 열기 **전에** 기준선을 찍는다(2차 검토 N2). 이 줄이 자리 여는 줄보다 뒤에 오면
    #   우리가 만든 master 자리까지 기준선에 들어가 영영 안 세어진다.
    set_fleet_baseline "$cli"
    # 🔴2026-09-17(TICKET=installer-0325 c1 · 09-16 756 발견 · 미수정 이월): 위 4070 은 wake.sh **안**의 문장만 지켰다 —
    #   여는 명령(cmd_line)에 실리는 것은 **경로**(wake_file)인데, 사용자 이름(홈 경로)에 작은따옴표가 있으면
    #   그 글자가 그대로 실려 나가 이 명령을 다시 셈 파싱하는 쪽(cys → 터미널)에서 따옴표가 거기서 끊긴다.
    #   ⇒ 경로에도 같은 방어(작은따옴표 이스케이프 후 통째로 홑따옴표로 감싼다)를 건다.
    wake_file_esc="$(printf '%s' "$wake_file" | sed "s/'/'\\\\''/g")"
    cmd_line="bash '$wake_file_esc'"
    if [ ! -f "$wake_file" ] || case "$wake_file" in *" "*) true ;; *) false ;; esac; then
      say "     여는 파일의 경로를 쓸 수 없어 cys 안에서는 열지 못합니다. 이 창에서 띄웁니다."
      log "wake path unusable: $wake_file"
      ref=""
    else
      ref="$(cys_open_master_seat "$cmd_line" | tr -d '\n')"
    fi
    case "$ref" in
      *surface:*)
        [ "$CYS_APP_OPENED" = "1" ] && say "     cys 앱 창을 열었습니다 — 자비스는 그 창(제목 jarvis)에서 깨어납니다."
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
    say "     cys 창 안에서 이어서 하고 싶으시면, cys 를 열고 그 안에서 아래 한 줄을 입력해 주십시오:"
    say "       $cmd_line"
    say ""
    say "     자리를 열지 못해 이 설치 창에서 깨웁니다."
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
  # 이 창에서 띄울 때도 선언을 첫 줄로 함께 넘긴다(ps1 3421 — cys 안에서 여는 wake.sh 와 같은 두 줄).
  exec "$claude_bin" --dangerously-skip-permissions "$wake_prompt"
}

# cys 앱 창을 연다(TICKET=mac-parity-t1-core) — 첫 설치의 확인 창(격리 속성)은 [6/10] 이 이미 지웠다.
#   ★여는 것은 창이고, 데몬은 [8/10] 이 launchd 에 올렸다. 앱이 뜨며 데몬에 닿는 동안 자리를 열지 않도록 답을 한 번 기다린다(최대 20초).
#   ⚠앱이 데몬을 다시 띄우는지 여기서 단정하지 않는다 — 앞뒤 cysd 번호를 기록에 남겨 실기에서 가른다.
CYS_APP_OPEN_WAIT_SEC=20
CYS_APP_OPENED=0   # open_cys_app 이 앱 창을 실제로 열었나(N3 — 문장은 자리가 열린 뒤에만)
open_cys_app() {
  local app before after i ok=0 t0 cli="${CYS_CLI:-cys}"
  app="$(cys_app_dir)"
  if [ ! -d "$app" ]; then log "app open: skipped (no app at $app)"; return 0; fi
  before="$(pgrep -x cysd 2>/dev/null | tr '\n' ' ')"
  if ! open -a "$app" >>"$LOG_FILE" 2>&1; then
    log "app open failed: $app"
    say "     cys 앱 창을 자동으로 열지 못했습니다 — 응용 프로그램 폴더에서 $(basename "$app") 을 열어 주십시오(자비스는 그대로 깨웁니다)."
    return 0
  fi
  # 🔴N3(t4-fix) — 「그 창에서 깨어납니다」는 여기서 말하지 않는다. 자리(여는 명령)가 성공해야 참이 되는 문장이다
  #   (데몬이 claim_denied 로 거절하면 자비스는 이 설치 창에서 뜬다) ⇒ 연 사실만 적어 두고 step_wake 가 성공 뒤에 말한다.
  CYS_APP_OPENED=1
  i=0; t0="$SECONDS"
  while [ "$i" -lt "$CYS_APP_OPEN_WAIT_SEC" ]; do
    case "$(cys_capped 5 "$cli" ping 2>/dev/null)" in *pong*) ok=1; break ;; esac
    sleep 1; i=$((i + 1))
  done
  after="$(pgrep -x cysd 2>/dev/null | tr '\n' ' ')"
  # 🔴N16(t4-fix) — 기록은 **실제로 흐른 초**다. 한 바퀴 = ping 상한 5초 + 1초라 바퀴 수(상수 20)를 초로 적으면 최악 약 120초가 「20s」로 남는다.
  log "app open: $app cysd before=[${before% }] after=[${after% }] ping_ok=$ok waited=$((SECONDS - t0))s tries=${i}"
  return 0
}

# cys 앱 창을 **앞으로** 가져온다(TICKET=installer-0325 c7 · 09-17 연수 실증 2/2 맥).
#   open_cys_app() 은 [9/10] 초입에 단 한 번 부른다 — 그 뒤 [10/10] 동료 자동 각성을 최대 7분
#   기다리는 동안 참가자가 다른 창을 보고 있으면 cysr 창이 뒤에 남는다. 실기 2건에서 참가자가
#   「자동 실행되지 않았다」고 보고 앱을 **손으로 다시 열어** 살아 있던 자리를 exited 로 만들었다.
#   ⛔재기동 금지(자리 보존) — `open -a` 는 「없으면 켜고 있으면 그저 최근 실행」이라 앞으로 오는지
#   보장이 약하다. `osascript … activate` 는 이미 도는 앱의 창을 **띄우기 없이** 앞으로만 올리는
#   표준 방식이라 그 자체로 재기동 위험이 없다 — 실패해도(앱이 아직 안 떴거나 창이 없거나) fail-open.
raise_cys_app_window() {
  local app cli="${CYS_CLI:-cys}"
  app="$(cys_app_dir)"
  if [ ! -d "$app" ]; then log "raise cys window: skipped (no app at $app)"; return 0; fi
  if osascript -e "tell application \"$app\" to activate" >>"$LOG_FILE" 2>&1; then
    log "raise cys window: activate ok ($app)"
  else
    log "raise cys window: activate failed ($app) — Dock 안내로 보완"
  fi
  return 0
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
INSTALLER_VERSION="0.3.26"      # 보고의 installer_version · BOOTSTRAP_VERSION 은 화면 머리글 용도 그대로(보내지 않는다)
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
    */ack|*/close|*/attach) [ -s "$RH_TMP/client-header" ] && extra+=(-H "@$RH_TMP/client-header") ;;   # 첨부도 보고를 연 설치기만(계약 1절 · 윈판 Invoke-RemoteHelpHttp)
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
  evidence_once ask         # 도움 요청 증거(보고가 열린 순간의 설치 창 끝부분 · 마스킹 뒤 · 윈판 같은 자리)
  help_fail_attachments     # 보고가 열린 직후 진단 자료를 붙인다(계약 3절 · 각각 fail-open)
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
  capture_receive "$RH_TMP/resp"   # 촬영 요청은 폴링 답에도 실려 온다(계약 5절 ② · 윈판 Invoke-RemoteHelpTick)
  capture_requested_run
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
  for c in "$HOME/.local/bin/cys" "/usr/local/bin/cys" "/Applications/cysr.app/Contents/MacOS/cys" "/Applications/cys.app/Contents/MacOS/cys"; do
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
say "=== 자비스 설치 도우미 — ${CYS_DISPLAY_NAME} ${CYS_PIN_VERSION} · 설치 도우미 ${INSTALLER_VERSION} (모드: $MODE) ==="
show_prev_run_note   # ps1 5640 — 머리글 앞머리(=== 자비스 설치 도우미 )는 지난 실행 읽기의 경계 표지다
say "[1/10] 이 컴퓨터를 살펴봅니다."
say "     $REMOTE_HELP_NOTICE"
NOTICE_SHOWN=1
progress_send '1/10' 'start' '' '' ''   # ps1 5645
step_baselines_update                   # ps1 5646 — 단계 소요 기준선을 한 번 받는다(못 받으면 「평소의 두 배」 축은 잠든다)
detect_stage1
detect_stage2
write_report
note_old_cys_app
progress_send '1/10' 'end' '' '' ''     # ps1 5651
progress_send '1/10' 'info' '' '' env   # ps1 5652 — 환경 칸

if [ "$MODE" = "detect" ]; then
  say "감지만 하고 끝냅니다."
  # 끝맺음 한 줄은 그 끝에 맞아야 한다 — 「살펴보기만 한 끝」에 「이어서 갑니다」는 맞지 않는다.
  next_rerun "실제로 설치하시려면 --detect-only 없이 아래 「다시 하시는 법」대로 다시 실행해 주십시오."
  exit 0
fi

# ps1 5661~5678 — 앞 세 단계는 막히면 멈춘다. 끝 표지에 종료 코드를 싣는다(경과는 윈판도 싣지 않는다).
progress_send '2/10' 'start' '' '' ''
step_install_claude; rc=$?; progress_send '2/10' 'end' '' "rc=$rc" ''; [ "$rc" -eq 0 ] || exit "$rc"
progress_send '3/10' 'start' '' '' ''
step_login;          rc=$?; progress_send '3/10' 'end' '' "rc=$rc" ''; [ "$rc" -eq 0 ] || exit "$rc"

progress_send '4/10' 'start' '' '' ''
step_prepare;        rc=$?; progress_send '4/10' 'end' '' "rc=$rc" ''; [ "$rc" -eq 0 ] || exit "$rc"

# 여기서부터는 한 단이 막혀도 멈추지 않는다.
# 앞 단계(클로드 설치·로그인·자비스 준비)는 이미 성립했고, 막힌 자리를 사람에게 설명해 주는 것이
# 그 다음으로 할 수 있는 가장 쓸모 있는 일이기 때문이다. 막힌 단을 적어 두고 자비스를 깨운다.
# ps1 5683~5701 — 단계마다 시작·끝(경과 초·종료 코드) · 기준선 두 배를 넘으면 느림 증거 · 받아 둔 촬영 요청 처리 · 막히면 그 단에서 멈춘다.
for st_row in '5/10|cys 설치 파일 받기|step_download_cys' '6/10|cys 설치|step_install_cys' \
              '7/10|cys 확인|step_verify_cys' '8/10|계정 준비|step_prepare_account'; do
  IFS='|' read -r st_step st_name st_fn <<EOF_STEP
$st_row
EOF_STEP
  progress_send "$st_step" 'start' '' '' ''
  st_t0="$(date +%s)"
  "$st_fn"; rc=$?
  st_sec=$(( $(date +%s) - st_t0 ))
  progress_send "$st_step" 'end' "$st_sec" "rc=$rc" ''
  if step_is_slow "$st_step" "$st_sec"; then capture_evidence slow "$st_step ${st_sec}s > 2x $(step_baseline_sec "$st_step")s"; fi
  capture_requested_run
  if [ "$rc" -ne 0 ]; then BLOCKED_STEP="$st_name"; break; fi
done

# 기동 직전 값으로 보고를 갱신한다.
: > "$ROWS_FILE"
detect_stage1; detect_stage2; write_report
step_wake
