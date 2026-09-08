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
#   그때는 멈추고 무엇이 남았는지 말한다. 같은 줄을 다시 돌리면 거기서부터 이어서 간다.
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
    -h|--help)        sed -n '1,20p' "$0"; exit 0 ;;
  esac
done

say() { printf '%s\n' "$*"; }

say "=== 삭제하고 재설치하기 ==="
say ""

# ── 1단 · 지우는 도구를 받는다 ────────────────────────────────────
# 사이트에서 새로 받는다 — 이 컴퓨터에 남아 있던 옛 사본을 쓰면 옛 규칙으로 지운다.
if ! curl -fsSL "$RESET_URL" -o "$RESET_FILE"; then
  say "지우는 도구를 받지 못했습니다. 인터넷 연결을 확인하고 같은 줄을 다시 돌려 주십시오."
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
  say "   위에 남아 있다고 표시된 자리를 확인하시고, 같은 줄을 한 번 더 돌려 주십시오."
  exit "$reset_rc"
fi

# ── 3단 · 처음부터 다시 깐다 ──────────────────────────────────────
say ""
say "=== 이제 처음부터 다시 깝니다 ==="
say ""
if ! curl -fsSL "$BOOTSTRAP_URL" -o "$BOOTSTRAP_FILE"; then
  say "설치 도우미를 받지 못했습니다. 인터넷 연결을 확인해 주십시오."
  say "지우기는 끝났으므로, 이 컴퓨터는 지금 「아무것도 안 깔린 상태」입니다."
  say "같은 줄을 다시 돌리시면 설치부터 이어서 갑니다."
  exit 3
fi

# 설치 도우미는 마지막에 자비스를 띄우며 자기 자신을 그 프로그램으로 바꿔치기한다(exec).
# 그래서 이 줄 다음은 실행되지 않는 것이 정상이다.
exec bash "$BOOTSTRAP_FILE"
