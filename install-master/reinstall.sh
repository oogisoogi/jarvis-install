#!/bin/bash
# 삭제하고 재설치하기 (맥) — 지우고 나서 처음부터 다시 깐다
#
# 무엇을 하는가
#   1) 이 컴퓨터의 상태를 살펴 목록으로 보여 준다
#   2) 확인을 받고 지운다 (설치 도우미가 놓은 것만)
#   3) 최신 설치 도우미를 새로 받아 처음부터 다시 돌린다
#
# 쓰는 법 — 터미널에 이 한 줄을 붙여넣으십시오
#   curl -fsSL https://jarvis.godmeyou.kr/install/reinstall.sh -o "$HOME/reinstall-jarvis.sh" && bash "$HOME/reinstall-jarvis.sh"
#
#   bash reinstall-jarvis.sh --list   무엇을 지울지 보기만 한다 (아무것도 안 바꾼다)
#
# ★로그인은 남깁니다. 다시 깐 뒤에도 로그인 화면이 안 뜹니다.
#   계정을 바꾸고 싶으실 때만 `claude auth logout` 을 하시고 다시 로그인하시면 됩니다.
#   (그것은 이 도구가 하는 일이 아닙니다 — 재설치와 계정 바꾸기는 다른 일입니다.)
#
# 🔴한 트랜잭션이다: 지우기가 중간에 실패하면 **재설치로 넘어가지 않는다.**
#   반쯤 지운 위에 설치가 얹히면 어느 쪽 상태인지 아무도 모르게 되기 때문이다.
#   그때는 멈추고 무엇이 남았는지 말한다. show_rerun_how 가 인쇄하는 명령 전체를 다시 붙여넣으면
#   거기서부터 이어서 간다.
#   ⛔사람에게 「같은 줄을 다시 돌려 주십시오」라고 말하지 않는다 — 2026-09-10 실기에서
#     **사용자 막힘으로 확정**된 문구다(무엇이 「줄」인지 모르고, 그 명령이 화면에 없었다).
set -u

BASE_URL="${JARVIS_BASE_URL:-https://jarvis.godmeyou.kr/install}"
RESET_URL="$BASE_URL/reset-clean.sh"
BOOTSTRAP_URL="$BASE_URL/bootstrap.sh"
RESET_FILE="$HOME/reset-clean.sh"
BOOTSTRAP_FILE="$HOME/install-jarvis.sh"

LIST_ONLY=0
for a in "$@"; do
  case "$a" in
    --list|--dry-run) LIST_ONLY=1 ;;
    -h|--help)        sed -n '1,23p' "$0"; exit 0 ;;
  esac
done

say() { printf '%s\n' "$*"; }

# ── 다시 하시는 법 (막힌 자리에서 명령 전체를 인쇄한다) ───────────
# ⚠아래 한 줄은 사이트가 게시하는 재설치 명령과 **글자까지 같아야 한다**(머리글의 한 줄도 같다).
JARVIS_RERUN_REINSTALL='curl -fsSL https://jarvis.godmeyou.kr/install/reinstall.sh -o "$HOME/reinstall-jarvis.sh" && bash "$HOME/reinstall-jarvis.sh"'
show_rerun_how() {
  say ""
  say "  == 다시 하시는 법 (이대로 따라 하시면 됩니다) =="
  say "   1) Command(⌘)+스페이스를 누르고 터미널 이라고 치신 뒤 [터미널] 을 여십시오."
  say "   2) 아래 명령을 처음부터 끝까지 끌어 선택한 뒤 Command(⌘)+C 를 누르십시오."
  say "   3) 터미널 창을 한 번 누르고 Command(⌘)+V 로 붙여넣은 뒤 Enter(리턴) 를 누르십시오."
  say ""
  say "$JARVIS_RERUN_REINSTALL"
  say ""
  say "  끝난 단계는 건너뛰고 막힌 자리부터 이어서 갑니다."
}
# ★안에서 부르는 지우개·설치기에게 **어느 길로 들어왔는지** 알려 준다 — 그쪽이 막혔을 때
#   인쇄할 것은 자기 한 줄이 아니라 **이 재설치 한 줄**이다(지우기만 되풀이하게 두지 않는다).
export JARVIS_ENTRY=reinstall

# 받는 자리에서 한 번 더 해 본다 — 인터넷은 그 자리에서 회복되는 일이 많다(창을 닫을 이유가 없다).
download_with_retry() { # download_with_retry <주소> <받을 자리> <무엇>
  local i
  for i in 1 2 3; do
    curl -fsSL "$1" -o "$2" && return 0
    say "  $3 를 받지 못했습니다 ($i/3)."
    [ "$i" -lt 3 ] && { say "  10초 뒤에 다시 해 봅니다. 창을 닫지 말고 기다려 주십시오."; sleep 10; }
  done
  return 1
}

say "=== 삭제하고 재설치하기 ==="
say ""

# ── 1단 · 지우는 도구를 받는다 ────────────────────────────────────
# 사이트에서 새로 받는다 — 이 컴퓨터에 남아 있던 옛 사본을 쓰면 옛 규칙으로 지운다.
if ! download_with_retry "$RESET_URL" "$RESET_FILE" "지우는 도구"; then
  say ""
  say "지우는 도구를 받지 못했습니다. 인터넷 연결을 확인해 주십시오."
  show_rerun_how
  exit 2
fi

if [ "$LIST_ONLY" = "1" ]; then
  bash "$RESET_FILE" --list
  say ""
  say "(보기만 했습니다. 아무것도 지우지 않았고, 설치도 하지 않았습니다.)"
  exit 0
fi

# ── 2단 · 지운다 ──────────────────────────────────────────────────
# 목록을 보여 주고 한 번 묻는 일은 지우는 도구가 한다. 여기서 두 번 묻지 않는다.
bash "$RESET_FILE"
reset_rc=$?

if [ "$reset_rc" = "1" ]; then
  # 사람이 그만두겠다고 답한 경우다. 실패가 아니다.
  say ""
  say "재설치도 하지 않았습니다. 이 컴퓨터는 그대로입니다."
  exit 0
fi

if [ "$reset_rc" != "0" ]; then
  say ""
  say "🔴지우다가 멈췄습니다 — 그래서 다시 설치하지 않았습니다."
  say "   반쯤 지운 위에 설치를 얹으면 무엇이 어떤 상태인지 알 수 없게 됩니다."
  say "   위에 남아 있다고 표시된 자리와 「다시 하시는 법」을 확인해 주십시오."
  exit "$reset_rc"
fi

# ── 3단 · 처음부터 다시 깐다 ──────────────────────────────────────
say ""
say "=== 이제 처음부터 다시 깝니다 ==="
say ""
if ! download_with_retry "$BOOTSTRAP_URL" "$BOOTSTRAP_FILE" "설치 도우미"; then
  say ""
  say "설치 도우미를 받지 못했습니다. 인터넷 연결을 확인해 주십시오."
  say "지우기는 끝났으므로, 이 컴퓨터는 지금 「아무것도 안 깔린 상태」입니다."
  show_rerun_how
  exit 3
fi

# 설치 도우미는 마지막에 자비스를 띄우며 자기 자신을 그 프로그램으로 바꿔치기한다(exec).
# 그래서 이 줄 다음은 실행되지 않는 것이 정상이다.
exec bash "$BOOTSTRAP_FILE"
