#!/bin/bash
# 깨끗이 지우기 (맥) — 설치 도우미가 놓은 것을 도로 걷어 낸다
#
# 무엇을 하는가
#   이 컴퓨터의 상태를 먼저 살펴 목록으로 보여 주고, 확인을 받은 뒤 지운다.
#   지우는 것은 `footprint.md` 에 적힌 것뿐이다. 사진·문서 같은 사용자 파일은 손대지 않는다.
#
# 쓰는 법
#   bash reset-clean.sh            지울 목록을 보여 주고 한 번 물은 뒤 지운다
#   bash reset-clean.sh --list     살펴보기만 한다 (아무것도 안 지운다)
#   bash reset-clean.sh --dry-run  지울 목록만 보여 준다 (--list 와 같다)
#   bash reset-clean.sh --yes      묻지 않는다 (재설치 한 줄이 안에서 쓴다)
#   bash reset-clean.sh --purge-login   로그인까지 지운다 (기본은 로그인을 남긴다)
#
# 되돌릴 수 없다.
#
# ★로그인은 기본으로 남긴다. 재설치 뒤 로그인 손 한 번을 아끼기 위해서다.
#   그리고 맥에서는 로그인이 파일이 아니라 **열쇠고리**에 있어서(2026-09-08 실측),
#   `~/.claude` 를 지우는 것만으로는 어차피 안 지워진다. 지우려면 열쇠고리를 건드려야 하고,
#   그것은 `--purge-login` 을 일부러 붙였을 때만 한다.
set -u

MODE="run"; ASSUME_YES=0; PURGE_LOGIN=0
for a in "$@"; do
  case "$a" in
    --list|--dry-run) MODE="list" ;;
    --yes|-y)         ASSUME_YES=1 ;;
    --purge-login)    PURGE_LOGIN=1 ;;
    -h|--help)        sed -n '1,25p' "$0"; exit 0 ;;
  esac
done

JARVIS_HOME="${JARVIS_HOME:-$HOME/install-jarvis}"
# 아고라(토론장) 자리 — 🔴**우리가 만들지 않는다**(v0.3.5부터 설치기에서 뗐다).
#   따로 참가하신 분의 자산이므로 **지우지 않고 「있음 · 남깁니다」로 보이기만 한다.**
#   ⚠여기 있는 것은 지우려고 두는 것이 아니라 **손대지 않는다고 말하려고** 두는 것이다.
AGORA_HOME="${AGORA_HOME:-$HOME/.config/agora}"
AGORA_SKILL="$HOME/.claude/skills/agora-delegate"             # 밖 — 남는다
AGORA_SKILL_IN_CYS="$HOME/.cys/claude/skills/agora-delegate"  # cys 계정 자리 안 — 함께 지워진다
# 🔴🔴**보존 경로 목록 — 지우는 자리 「안에」 들어 있어도 지우지 않는다**(검토 지적 채택 2026-09-09).
#   왜 이 목록이 필요한가: 참가 자리는 사람이 `AGORA_HOME` 으로 옮겨 둘 수 있다. 그것이
#   `~/.cys/forum` 이나 `~/install-jarvis/forum` 처럼 **우리가 지우는 자리 안**이면,
#   화면은 「남깁니다」라고 말한 뒤 **상위를 통째로 지워** 열쇠를 함께 날린다.
#   ⇒ 말이 아니라 **지우는 동작**이 보존을 알아야 한다.
#   ⛔임시로 옮겼다 되돌리는 방식은 쓰지 않는다 — 되돌리는 도중 멈추면 그 자리에서 유실된다.
#   한 줄에 한 경로다(공백 든 경로를 쪼개지 않으려고 줄로 나눈다).
PRESERVE_PATHS="$AGORA_HOME
$AGORA_SKILL"
CYS_APP="/Applications/cys.app"
CYS_CLI=""
for c in "$CYS_APP/Contents/MacOS/cys" "$HOME/.local/bin/cys" "/usr/local/bin/cys"; do
  [ -x "$c" ] && { CYS_CLI="$c"; break; }
done
PROFILE_MARKER="# added by jarvis installer (claude PATH)"
KEYCHAIN_SERVICE="Claude Code-credentials"

say()  { printf '%s\n' "$*"; }
short() { printf '%s' "${1/#$HOME/~}"; }

# ── 살펴보기 ──────────────────────────────────────────────────────
# 있는 것만 세는 것이 아니라 **없는 것도 적는다** — 「어디까지 갔는가」가 그 대조에서 나온다.
FOUND=0
row() { # row <있음판정 rc> <이름> <자리>
  #   ⚠칸 맞추기(%-22s)를 쓰지 않는다 — 우리말 한 글자가 여러 바이트라 자리가 어긋나 보인다
  #   (실측 2026-09-08 · 게스트 출력이 삐뚤어졌다). 가운뎃점으로 가르면 어긋날 자리가 없다.
  if [ "$1" -eq 0 ]; then FOUND=$((FOUND+1)); printf '  [있음] %s · %s\n' "$2" "$(short "$3")"
  else                    printf '  [없음] %s · %s\n' "$2" "$(short "$3")"; fi
}
has_marker() { [ -f "$1" ] && grep -qF "$PROFILE_MARKER" "$1" 2>/dev/null; }
profile_with_marker() {
  local f
  for f in "$HOME/.zprofile" "$HOME/.zshrc" "$HOME/.zshenv" "$HOME/.profile" "$HOME/.bash_profile" "$HOME/.bashrc"; do
    has_marker "$f" && { printf '%s\n' "$f"; }
  done
  return 0
}
json_has() { # json_has <파일> <키>  — plutil 로만 본다(파일을 파싱해 흉내내지 않는다)
  [ -f "$1" ] || return 1
  plutil -extract "$2" raw -o - "$1" >/dev/null 2>&1
}
hook_present() { # 각성 훅이 남의 settings.json 에 병합돼 있는가
  [ -f "$1" ] || return 1
  grep -q 'session-start\.sh\|role-bootstrap\.sh' "$1" 2>/dev/null
}
# 🔴자리가 **둘**이다(공식 문서 2026-09-08 확인 · code.claude.com/docs/en/troubleshoot-install):
#   「On macOS, Claude Code saves credentials to the login Keychain. When the Keychain rejects the
#    write, such as when it's locked in an SSH session …, Claude Code saves your login to the
#    plaintext ~/.claude/.credentials.json file instead.」
#   ⇒ 열쇠고리만 보면 **원격으로 로그인한 기계에서는 못 찾는다.** 둘 다 본다.
#   ⑶그리고 자리는 **고정이 아니다**: 「If you've set the CLAUDE_CONFIG_DIR environment variable,
#     Claude Code keeps the .credentials.json file under that directory instead, including the file
#     the macOS fallback writes, and keys the macOS Keychain entry to that directory too」
#     (같은 문서 · 2026-09-08 확인). ⇒ 그 변수가 선 창에서 이 스크립트를 돌리면 **우리가 보는 자리와
#     클로드가 보는 자리가 갈린다.** 갈린 채로 「있음」이라고 적으면 그 줄이 거짓이 된다.
CLAUDE_CFG_DIR="${CLAUDE_CONFIG_DIR:-$HOME/.claude}"
CRED_FILE="$CLAUDE_CFG_DIR/.credentials.json"
# 자비스 창(cys)이 띄우는 클로드는 CLAUDE_CONFIG_DIR 을 ~/.cys/claude 로 두고 뜬다. 그 폴더는
#   아래에서 「cys 계정 자리」로 **통째로 지워진다** — 거기 든 로그인도 같이 사라진다.
#   지우는 것을 바꾸지는 않는다(그것은 사람이 결정할 일이다). 다만 **말은 해 준다.**
CYS_CRED_FILE="$HOME/.cys/claude/.credentials.json"
login_present() {
  security find-generic-password -s "$KEYCHAIN_SERVICE" >/dev/null 2>&1 && return 0
  [ -f "$CRED_FILE" ]
}
# 결정 2026-09-08: 진단 화면에 「현재 로그인」 한 줄을 보인다(값은 안 찍는다).
#   자리를 뒤지는 것보다 **클로드에게 묻는 것**이 낫다 — 자리가 기계마다 다르기 때문이다.
#   클로드가 없으면 그때만 우리가 아는 자리 둘을 본다.
login_status() {
  local c="$HOME/.local/bin/claude"
  [ -x "$c" ] || c="$(command -v claude 2>/dev/null)"
  if [ -n "$c" ]; then
    case "$("$c" auth status 2>/dev/null | tr -d ' ')" in
      *'"loggedIn":true'*)  printf '있음'; return 0 ;;
      *'"loggedIn":false'*) printf '없음'; return 1 ;;
    esac
  fi
  if login_present; then printf '있음(자리로 판단)'; return 0; fi
  printf '없음(우리가 아는 자리 기준)'; return 1
}
login_where() {
  local w=""
  security find-generic-password -s "$KEYCHAIN_SERVICE" >/dev/null 2>&1 && w="열쇠고리"
  [ -f "$CRED_FILE" ] && w="${w:+$w · }파일($(short "$CRED_FILE"))"
  printf '%s' "${w:-없음}"
}

diagnose() {
  FOUND=0
  say "=== 이 컴퓨터의 상태 ==="
  # footprint: M-APP
  [ -d "$CYS_APP" ]; row $? 'cys 프로그램' "$CYS_APP"
  # footprint: M-DAEMON
  [ -f "$HOME/Library/LaunchAgents/com.cysjavis.cysd.plist" ]; row $? 'cys 상시 가동 등록' "$HOME/Library/LaunchAgents/com.cysjavis.cysd.plist"
  # footprint: M-CYSHOME
  [ -d "$HOME/.cys" ]; row $? 'cys 계정 자리' "$HOME/.cys"
  # footprint: M-CYSSTATE
  [ -d "$HOME/.local/state/cys" ]; row $? 'cys 실행 상태' "$HOME/.local/state/cys"
  # footprint: M-CLAUDEBIN
  [ -e "$HOME/.local/bin/claude" ]; row $? '클로드 실행 파일' "$HOME/.local/bin/claude"
  # footprint: M-CLAUDESHARE
  [ -d "$HOME/.local/share/claude" ]; row $? '클로드 실물' "$HOME/.local/share/claude"
  # footprint: M-JARVISHOME
  [ -d "$JARVIS_HOME" ]; row $? '자비스 작업 폴더' "$JARVIS_HOME"
  # footprint: M-SCRIPTCOPY
  [ -f "$HOME/install-jarvis.sh" ]; row $? '받아 둔 설치 스크립트' "$HOME/install-jarvis.sh"
  # footprint: M-PROFILE
  local pf; pf="$(profile_with_marker | head -1)"
  [ -n "$pf" ]; row $? '실행 경로 한 줄' "${pf:-$HOME/.zprofile}"
  # footprint: M-CLAUDEJSON
  json_has "$HOME/.claude.json" 'hasCompletedOnboarding'; row $? '클로드 설정의 우리 칸' "$HOME/.claude.json"
  # footprint: M-CLAUDESETTINGS
  json_has "$HOME/.claude/settings.json" 'skipDangerousModePermissionPrompt'; row $? '클로드 설정 우리 칸 2' "$HOME/.claude/settings.json"
  # footprint: M-HOOK
  hook_present "$HOME/.claude/settings.json"; row $? '각성 훅 등록' "$HOME/.claude/settings.json"
  # footprint: M-CYSPROFILE
  [ -d "$HOME/.cys/claude" ]; row $? '자비스 전용 클로드 설정' "$HOME/.cys/claude"

  say ""
  if [ "$PURGE_LOGIN" = "1" ]; then say "=== 로그인·개인 자료 ==="; else say "=== 손대지 않는 것 (지우지 않습니다) ==="; fi
  # footprint: M-LOGIN
  say "  현재 로그인: $(login_status)"
  if [ "$PURGE_LOGIN" = "1" ]; then
    say "         ⚠--purge-login 을 붙이셨습니다 — 이번에는 로그인도 지웁니다."
    say "         이때는 로그인만이 아니라 연결해 둔 다른 서비스의 로그인과 확장 기능의 비밀값도 함께 지워집니다."
    say "         (클로드가 그렇게 만들어 두었습니다 — 우리가 고를 수 있는 것이 아닙니다.)"
  else
    say "         기본으로 남깁니다. 재설치 뒤 로그인을 다시 하지 않으셔도 됩니다."
  fi
  if [ -f "$CYS_CRED_FILE" ]; then
    say "  [있음] 자비스 창 전용 로그인 · $(short "$CYS_CRED_FILE")"
    say "         ⚠이것은 위의 「cys 계정 자리」 안에 들어 있어 함께 지워집니다."
    say "         자비스 창에서 하신 로그인은 다시 하셔야 합니다 — 따로 하신 로그인과는 별개입니다."
  fi
  # footprint: M-CLAUDEUSER
  [ -d "$HOME/.claude" ] && say "  [있음] 클로드 대화·기록 · $(short "$HOME/.claude") (남깁니다)" \
                         || say "  [없음] 클로드 대화·기록 · $(short "$HOME/.claude")"
  # footprint: M-AGORA
  #   🔴설치기가 만들지 않는다. 토론장에 따로 참가하신 분이 만든 것이므로 **지우지 않는다.**
  [ -d "$AGORA_HOME" ] && say "  [있음] 토론장 참가 열쇠·이름 · $(short "$AGORA_HOME") (남깁니다)" \
                       || say "  [없음] 토론장 참가 열쇠·이름 · $(short "$AGORA_HOME")"
  # footprint: M-AGORASKILL
  #   🔴자리가 둘이고 **운명이 다르다.** 밖(`~/.claude/`)은 남고, cys 계정 자리 안(`~/.cys/claude/`)은
  #   위의 「cys 계정 자리」를 통째로 지울 때 **함께 지워진다.** 「남깁니다」라고 한 줄로 뭉치면
  #   그 줄이 거짓말이 된다 — 이 표가 막으려는 바로 그 형태다. 그래서 두 자리를 갈라 말한다.
  [ -d "$AGORA_SKILL" ] \
    && say "  [있음] 토론장 안내 가리키기 · $(short "$AGORA_SKILL") (남깁니다)" \
    || say "  [없음] 토론장 안내 가리키기 · $(short "$AGORA_SKILL")"
  if [ -d "$AGORA_SKILL_IN_CYS" ]; then
    say "  [있음] 토론장 안내 가리키기(자비스 창 쪽) · $(short "$AGORA_SKILL_IN_CYS")"
    say "         ⚠이것은 위의 「cys 계정 자리」 안에 들어 있어 함께 지워집니다(cys 설치의 일부입니다)."
    if [ -d "$AGORA_SKILL" ]; then
      say "         같은 안내가 $(short "$AGORA_SKILL") 에도 있어 그쪽은 남습니다."
    else
      say "         지우기 전에 $(short "$AGORA_SKILL") 로 옮겨 둡니다 — 없어지지 않습니다."
    fi
    say "         토론장 참가 열쇠·이름은 어느 경우에도 그대로 남습니다."
  fi
  say "  사진·문서·내려받기 등 개인 파일은 목록에 없습니다 — 손대지 않습니다."

  say ""
  say "=== 판정 ==="
  if [ "$FOUND" -eq 0 ]; then
    say "  아무것도 깔려 있지 않습니다 (미설치)."
  elif [ -d "$CYS_APP" ] && [ -d "$HOME/.cys" ] && [ -e "$HOME/.local/bin/claude" ]; then
    say "  설치가 끝난 상태로 보입니다 (찾은 자국 $FOUND 개)."
  else
    say "  설치가 중간에 멈춘 상태로 보입니다 (찾은 자국 $FOUND 개)."
    say "  고장이 아닙니다 — 지우고 처음부터 다시 하면 됩니다."
  fi
}

# ── 지우기 ────────────────────────────────────────────────────────
REMOVED=0; KEPT_FAIL=0; PRESERVED=0

# 🔴🔴**경로를 실경로로 푼 뒤에 비교한다**(2차 검토 지적 채택 2026-09-09).
#   앞 판은 **끝 슬래시만** 떼고 글자로 비교했다. 그러면 `~/.cys/./forum` · `~/.cys/../.cys/forum` ·
#   심볼릭 링크로 적어 둔 자리가 **중첩 판정을 빠져나가** 열쇠가 지워진다 — 첫 비교는 중첩으로 받는데
#   `find` 가 내는 정규화된 경로와 저장해 둔 날것 경로가 서로 달라 남길 대상을 못 알아본다.
#   ⇒ 양쪽을 **같은 방식으로 푼 뒤** 비교한다. `realpath` 는 맥 기본이 아니라 셸로 푼다.
canon() {  # 실경로를 찍는다. 못 풀면 아무것도 안 찍고 rc 1.
  local p="$1" d b
  [ -n "$p" ] || return 1
  if [ -d "$p" ]; then ( cd -P "$p" 2>/dev/null && pwd -P ) && return 0; return 1; fi
  d="$(dirname "$p")"; b="$(basename "$p")"
  d="$( cd -P "$d" 2>/dev/null && pwd -P )" || return 1
  printf '%s/%s\n' "${d%/}" "$b"
}
# 보존 경로 가운데 이 자리 **안에** 있는 것을 실경로로 한 줄씩 찍는다.
preserved_under() {
  local root="$1" p c
  printf '%s\n' "$PRESERVE_PATHS" | while IFS= read -r p; do
    [ -n "$p" ] || continue; [ -e "$p" ] || continue
    c="$(canon "$p")" || continue
    case "$c" in "$root"/*) printf '%s\n' "$c" ;; esac
  done
}
# 이 자리 **자신이** 보존 대상이거나 보존 경로의 아래인가(그러면 손대지 않는다).
preserve_covers() {
  local t="$1" p c
  printf '%s\n' "$PRESERVE_PATHS" | while IFS= read -r p; do
    [ -n "$p" ] || continue; [ -e "$p" ] || continue
    c="$(canon "$p")" || continue
    case "$t" in "$c"|"$c"/*) printf '%s\n' "$c" ;; esac
  done
}
# 보존 경로만 남기고 그 자리를 비운다. 보존 경로와 **그 위 조상들**은 건드리지 않는다.
#   ★깊은 것부터(-depth) 지운다 — 자식을 먼저 치우지 않으면 부모를 못 지운다.
#   🔴**못 지운 것을 세어 돌려준다**(2차 검토 지적 채택): 앞 판은 개별 실패를 통째로 삼키고도
#   「지움」이라 말했다. 지우는 도구가 「거의 다 지웠다」를 성공으로 보고하면 그것이 곧 거짓 상태 보고다.
#   ⚠`find | while` 은 딴 프로세스라 변수를 못 돌려준다 ⇒ 실패 수를 파일에 적어 넘긴다.
prune_except() {
  local root="$1" keeps="$2" cnt p k skip
  cnt="$(mktemp -t jarvis-prune)" || return 1
  printf '0' > "$cnt"
  find "$root" -depth -mindepth 1 2>/dev/null | while IFS= read -r p; do
    skip=0
    printf '%s\n' "$keeps" | while IFS= read -r k; do
      [ -n "$k" ] || continue
      case "$p" in "$k"|"$k"/*) exit 9 ;; esac   # 보존 경로 자신 또는 그 아래
      case "$k" in "$p"/*) exit 9 ;; esac        # 보존 경로의 조상
    done || skip=1
    [ "$skip" = "1" ] && continue
    rm -rf "$p" 2>/dev/null || printf '%s' "$(( $(cat "$cnt") + 1 ))" > "$cnt"
  done
  PRUNE_FAIL="$(cat "$cnt" 2>/dev/null || printf '0')"
  rm -f "$cnt"
  [ "${PRUNE_FAIL:-0}" -eq 0 ]
}

# 두 자리의 **파일 목록과 내용**이 같은가. 「폴더가 생겼다」로는 옮겼다고 말할 수 없다.
#   ⚠임시 파일은 **바깥**에 만든다 — 대조하는 자리 안에 만들면 그 파일이 목록에 끼어 자기 자신을 어긋나게 한다.
sha_of() { shasum -a 256 "$1" 2>/dev/null | awk '{print $1}'; }
tree_same() {
  local a="$1" b="$2" la lb rel rc=0
  [ -d "$a" ] && [ -d "$b" ] || return 1
  la="$(mktemp -t jarvis-ta)" || return 1
  lb="$(mktemp -t jarvis-tb)" || { rm -f "$la"; return 1; }
  ( cd "$a" 2>/dev/null && find . -type f | LC_ALL=C sort ) > "$la" 2>/dev/null || rc=1
  ( cd "$b" 2>/dev/null && find . -type f | LC_ALL=C sort ) > "$lb" 2>/dev/null || rc=1
  if [ "$rc" -eq 0 ] && cmp -s "$la" "$lb"; then
    while IFS= read -r rel; do
      [ -n "$rel" ] || continue
      [ "$(sha_of "$a/$rel")" = "$(sha_of "$b/$rel")" ] || { rc=1; break; }
    done < "$la"
  else
    rc=1
  fi
  rm -f "$la" "$lb"
  return "$rc"
}

PRUNE_FAIL=0
drop_dir()  {
  [ -e "$1" ] || return 0
  # 🔴지우기 전에 보존 경로와의 중첩을 먼저 본다(검토 지적 채택 2026-09-09).
  local t covers keeps
  # ★실경로를 못 풀면 **지우지 않는다**(fail-closed). 무엇을 지우는지 확신할 수 없는 상태에서
  #   지우는 것이 이 도구가 낼 수 있는 가장 나쁜 실패다.
  t="$(canon "$1")" || {
    KEPT_FAIL=$((KEPT_FAIL+1))
    say "  🔴못 지움: $(short "$1") — 이 자리의 실제 경로를 확인하지 못해 **지우지 않았습니다.**"
    say "         (확인할 수 없는 자리를 지우면 엉뚱한 것을 지울 수 있습니다.)"
    return 1
  }
  covers="$(preserve_covers "$t")"
  if [ -n "$covers" ]; then
    PRESERVED=$((PRESERVED+1))
    say "  보존(중첩): $(short "$1") — 참가 자리와 겹쳐 지우지 않습니다."
    return 0
  fi
  keeps="$(preserved_under "$t")"
  if [ -n "$keeps" ]; then
    PRESERVED=$((PRESERVED+1))
    say "  보존(중첩): $(short "$1") 안에 참가 자리가 있어 **그것만 남기고** 지웁니다."
    printf '%s\n' "$keeps" | while IFS= read -r k; do [ -n "$k" ] && say "           남기는 자리: $(short "$k")"; done
    if prune_except "$t" "$keeps"; then
      REMOVED=$((REMOVED+1)); say "  지움: $(short "$1") (참가 자리는 그대로)"
      return 0
    fi
    KEPT_FAIL=$((KEPT_FAIL+1))
    say "  🔴일부 남음: $(short "$1") — ${PRUNE_FAIL}가지를 지우지 못했습니다(참가 자리는 그대로입니다)."
    return 1
  fi
  if rm -rf "$1" 2>/dev/null; then REMOVED=$((REMOVED+1)); say "  지움: $(short "$1")"; return 0; fi
  KEPT_FAIL=$((KEPT_FAIL+1)); say "  🔴못 지움: $(short "$1")"
  #   가장 흔한 까닭이 권한이다 — 다른 계정이 깐 프로그램은 이 계정으로 못 지운다.
  #   「못 지웠다」로만 끝내면 사람은 무엇을 해야 할지 모른다(적대검증 지적 채택 2026-09-08).
  if [ ! -w "$(dirname "$1")" ]; then
    say "         이 자리는 이 계정으로 지울 수 없습니다(다른 계정이 놓았거나 관리자 자리입니다)."
    say "         그 프로그램을 설치한 계정으로 로그인해서 같은 줄을 돌리시거나, 관리자에게 부탁해 주십시오."
  fi
}
drop_file() { drop_dir "$1"; }

PROFILE_LINE='export PATH="$HOME/.local/bin:$PATH"'
strip_profile_marker() { # 우리 표식 블록 2줄만 뺀다 — 사용자의 다른 줄은 건드리지 않는다
  local f tmp
  for f in $(profile_with_marker); do
    tmp="$(mktemp -t jarvis-prof)" || continue
    #   🔴적대검증 지적 채택(2026-09-08): 앞 판은 표식 **다음 한 줄을 무조건** 지웠다.
    #   사용자가 표식 바로 아래에 자기 줄을 넣어 두었으면 **그 줄을 말없이 삼킨다.**
    #   ⇒ 다음 줄은 **우리가 쓴 그 줄일 때만** 지운다. 아니면 표식만 지우고 그 줄은 남긴다.
    #   그리고 우리 줄을 못 지운 경우에는 **그 사실을 말한다** — 조용히 두면 「다 지웠다」가 거짓이 된다.
    #   ⛔파일 어디서나 같은 줄을 찾아 지우지는 않는다: 공식 설치기가 사람에게 **바로 그 줄**을 직접
    #   넣으라고 시키므로, 같은 줄이 사용자 자신의 것일 수 있다.
    awk -v m="$PROFILE_MARKER" -v l="$PROFILE_LINE" '
      $0 == m { pend = 1; next }
      pend == 1 { pend = 0; if ($0 == l) next; else kept = 1 }
      { print }
      END { if (kept) print "JARVIS_LINE_KEPT" > "/dev/stderr" }
    ' "$f" > "$tmp" 2>"$tmp.err" || { rm -f "$tmp" "$tmp.err"; continue; }
    if grep -q JARVIS_LINE_KEPT "$tmp.err" 2>/dev/null; then
      say "  ⚠$(short "$f") — 표식은 지웠으나, 우리가 쓴 경로 줄이 표식 바로 아래가 아니어서 남겨 두었습니다."
      say "         그 자리에 손수 넣으신 줄이 있어 함께 지우지 않았습니다. 해롭지 않습니다."
    fi
    rm -f "$tmp.err"
    #   🔴원본에 바로 쓰지 않는다 — 쓰는 도중 멈추면 남의 파일이 반쪽으로 남는다(같은 지적).
    #   임시 파일에 다 쓴 뒤 한 번에 자리를 바꾼다. 권한·소유자를 잃지 않게 mv 대신 cp 로 되돌린다.
    if [ -s "$tmp" ] || [ ! -s "$f" ]; then
      if cp "$tmp" "$f" 2>/dev/null; then REMOVED=$((REMOVED+1)); say "  지움: $(short "$f") 의 실행 경로 한 줄 (다른 줄은 그대로)"
      else KEPT_FAIL=$((KEPT_FAIL+1)); say "  🔴못 지움: $(short "$f") 의 실행 경로 한 줄"; fi
    else
      KEPT_FAIL=$((KEPT_FAIL+1)); say "  🔴못 지움: $(short "$f") — 고쳐 쓴 내용이 비어 원본을 그대로 두었습니다"
    fi
    rm -f "$tmp"
  done
}

strip_json_key() { # strip_json_key <파일> <키> — 파일은 남기고 우리 칸만 뺀다
  [ -f "$1" ] || return 0
  #   ⚠`plutil` 은 키 경로에서 마침표를 구분자로 읽는다. 사용자 폴더 이름에 마침표가 있으면
  #   (예: /Users/first.last) 그 칸을 **가리킬 수가 없다**(2026-09-08 실측: extract·remove 둘 다 실패).
  #   설치기도 같은 방식으로 넣으므로 애초에 안 들어갔을 수 있다. 어느 쪽이든 우리가 할 수 있는 것은
  #   **모른다고 말하는 것**뿐이다 — 조용히 지나가면 「다 지웠다」가 거짓이 된다.
  case "$2" in
    projects.*)
      case "${2#projects.}" in
        *.*) say "  ⚠못 살핌: $(short "$1") 의 $2 칸 — 사용자 폴더 이름에 마침표가 있어 이 칸은 다루지 못합니다."
             return 0 ;;
      esac ;;
  esac
  plutil -extract "$2" raw -o - "$1" >/dev/null 2>&1 || return 0
  if plutil -remove "$2" "$1" >/dev/null 2>&1; then REMOVED=$((REMOVED+1)); say "  지움: $(short "$1") 의 $2 칸 (파일은 그대로)"
  else KEPT_FAIL=$((KEPT_FAIL+1)); say "  🔴못 지움: $(short "$1") 의 $2 칸"; fi
}

# 🔴글을 다루는 도구를 고를 때 `python3` 를 그냥 부르면 안 된다.
#   깨끗한 맥에는 개발자 도구가 없어서 `/usr/bin/python3` 는 **설치 대화상자를 띄우고 실패한다**
#   (2026-09-06 실측 · rc=1). 그러면 지우는 중에 창이 하나 뜨고 훅은 안 지워진다.
#   ⇒ cys 프로그램 안에 동봉된 파이썬을 먼저 쓴다. 배포물 자신도 같은 이유로 그렇게 한다.
pick_python() {
  local c
  for c in "$CYS_APP/Contents/Resources/runtime/python/bin/python3" "$HOME/.local/share/claude/runtime/python/bin/python3"; do
    [ -x "$c" ] && { printf '%s' "$c"; return 0; }
  done
  # 개발자 도구가 이미 있는 기계에서만 이것이 답한다. 없으면 빈손으로 돌아간다(대화상자를 안 띄운다).
  if [ -n "$(xcode-select -p 2>/dev/null)" ] && [ -x /usr/bin/python3 ]; then
    printf '%s' /usr/bin/python3; return 0
  fi
  return 1
}

strip_hooks() { # 각성 훅만 뺀다. 사용자의 다른 훅은 건드리지 않는다.
  local sf="$1" tmp py
  hook_present "$sf" || return 0
  if ! py="$(pick_python)"; then
    KEPT_FAIL=$((KEPT_FAIL+1))
    say "  🔴못 지움: $(short "$sf") 의 각성 훅 (설정을 고칠 도구가 이 컴퓨터에 없습니다)"
    say "         그 훅은 이제 없는 자리를 가리킵니다. 그 파일에서 session-start·role-bootstrap 줄을 지워 주십시오."
    return 0
  fi
  tmp="$(mktemp -t jarvis-hook)" || return 0
  if "$py" - "$sf" > "$tmp" 2>/dev/null <<'PY'
import json,sys
p=sys.argv[1]
# ⚠인코딩을 안 적으면 그 기계의 로케일로 읽는다 — 남의 설정 파일은 UTF-8 이다.
#   같은 병이 윈도우판에서 실제로 났다(러너 실측 2026-09-08: 한글이 통째로 깨져 다시 쓰였다).
d=json.load(open(p,encoding="utf-8"))
h=d.get("hooks")
def ours(entry):
    s=json.dumps(entry)
    return "session-start.sh" in s or "role-bootstrap.sh" in s
if isinstance(h,dict):
    for ev in list(h.keys()):
        v=h[ev]
        if isinstance(v,list):
            kept=[e for e in v if not ours(e)]
            if kept: h[ev]=kept
            else: del h[ev]
    if not h: d.pop("hooks",None)
# 화면(stdout)도 로케일을 타므로 바이트로 직접 내보낸다.
sys.stdout.buffer.write(json.dumps(d,ensure_ascii=False,indent=2).encode("utf-8"))
PY
  then
    if cat "$tmp" > "$sf" 2>/dev/null; then REMOVED=$((REMOVED+1)); say "  지움: $(short "$sf") 의 각성 훅 (다른 설정은 그대로)"
    else KEPT_FAIL=$((KEPT_FAIL+1)); say "  🔴못 지움: $(short "$sf") 의 각성 훅"; fi
  else
    KEPT_FAIL=$((KEPT_FAIL+1)); say "  🔴못 지움: $(short "$sf") 의 각성 훅 (설정 파일을 읽지 못했습니다)"
  fi
  rm -f "$tmp"
}

# footprint: M-LOGIN
# ★공식 명령을 먼저 쓴다. 우리가 열쇠고리 항목과 파일을 직접 지우는 것보다 낫다 —
#   공식 문서가 「logout 은 저장된 자격을 전부 지운다(평문 파일 내용 포함)」고 적고 있고,
#   그 명령은 **두 운영체제에서 같은 뜻**이라 대칭이 저절로 맞는다. 손으로 지우는 것은 폴백이다.
purge_login_first() {
  [ "$PURGE_LOGIN" = "1" ] || { say "  남김: 로그인 (다음에 다시 하지 않으셔도 됩니다)"; return 0; }
  local claude_bin="$HOME/.local/bin/claude"
  [ -x "$claude_bin" ] || claude_bin="$(command -v claude 2>/dev/null)"
  if [ -n "$claude_bin" ] && "$claude_bin" auth logout >/dev/null 2>&1; then
    REMOVED=$((REMOVED+1)); say "  지움: 로그인 (공식 로그아웃)"
  else
    # 클로드가 이미 없거나 명령이 안 될 때 — 자리 둘을 직접 치운다
    local did=0
    security delete-generic-password -s "$KEYCHAIN_SERVICE" >/dev/null 2>&1 && did=1
    [ -f "$CRED_FILE" ] && rm -f "$CRED_FILE" 2>/dev/null && did=1
    # 🔴적대검증 [1] **부분** 채택(2026-09-08). 열쇠고리에는 같은 이름의 항목이 **여럿** 있을 수 있다 —
    #   클로드가 설정 폴더마다 따로 걸기 때문이다(공식 문서 · 이 개발기에 실측 8개).
    #   `security delete-generic-password` 는 그 가운데 **하나만** 지운다.
    #   ⛔「없어질 때까지 반복해 지운다」는 안 한다 — 그러면 **이 사람의 다른 클로드 로그인까지**
    #     지운다(우리가 깔지 않은 것도 포함). 지우는 범위를 넓히는 것은 사람이 정할 일이다.
    #   ✅우리가 할 수 있는 것은 **사실대로 말하는 것**이다. 조용히 지나가면 「로그인까지 지웠다」가 거짓이 된다.
    if security find-generic-password -s "$KEYCHAIN_SERVICE" >/dev/null 2>&1; then
      say "  ⚠열쇠고리에 같은 이름의 로그인 항목이 더 남아 있습니다(클로드가 설정 폴더마다 따로 겁니다)."
      say "     우리가 아는 자리 하나만 지웠습니다. 나머지는 그 폴더를 쓰는 클로드에서 로그아웃해 주십시오."
    fi
    if [ "$did" = "1" ]; then REMOVED=$((REMOVED+1)); say "  지움: 로그인 (자리를 직접 치웠습니다)"
    else say "  로그인: 지울 것이 없었습니다."; fi
  fi
}

purge() {
  say ""
  say "=== 지웁니다 ==="

  # ★순서가 중요하다 — 등록을 떼는 명령이 **프로그램 안에** 들어 있다.
  #   프로그램을 먼저 지우면 등록을 뗄 수단이 사라져 죽은 등록이 남는다.
  # footprint: M-DAEMON
  if [ -n "$CYS_CLI" ]; then
    CYS_NO_AUTOSTART=1 "$CYS_CLI" daemon uninstall >/dev/null 2>&1 && say "  지움: cys 상시 가동 등록"
  fi
  launchctl bootout "gui/$(id -u)/com.cysjavis.cysd" >/dev/null 2>&1 || true
  drop_file "$HOME/Library/LaunchAgents/com.cysjavis.cysd.plist"
  pkill -f 'cys\.app/Contents/MacOS/cysd' >/dev/null 2>&1 || true

  # ★로그인도 클로드를 지우기 **전에** 처리한다 — 로그아웃 명령이 클로드 안에 들어 있다.
  purge_login_first

  # ★훅을 프로그램보다 **먼저** 뗀다 — 훅을 고칠 파이썬이 그 프로그램 안에 들어 있다(pick_python).
  #   순서를 뒤집으면 깨끗한 맥에서 훅이 영영 안 지워진다(그 기계엔 다른 파이썬이 없다).
  # footprint: M-HOOK
  strip_hooks "$HOME/.claude/settings.json"

  # footprint: M-APP
  drop_dir "$CYS_APP"
  # 🔴cys 계정 자리를 지우기 **전에** 토론장 안내 파일을 밖으로 옮겨 둔다(검토 지적 채택 2026-09-09).
  #   까닭: `~/.cys/claude/skills/agora-delegate` 는 cys 설치의 일부라 cys 와 함께 사라지는 것이 맞다.
  #   그런데 그대로 두면 다시 깐 뒤 「아고라에 참가해」가 **안 먹는 공백**이 생긴다 — 참가 열쇠는
  #   남아 있는데 그걸 어떻게 쓰는지 적은 종이만 없어진 꼴이다.
  #   ⇒ 밖(`~/.claude/skills/`)에 같은 것이 **없을 때만** 옮겨 둔다(있으면 손대지 않는다 = 멱등).
  #   ⛔밖에 이미 있는 것을 덮어쓰지 않는다 — 사람이 손수 고쳐 둔 것일 수 있다.
  #   🔴🔴**옮겼다고 말하기 전에 바이트를 대조한다**(2차 검토 지적 채택). 앞 판은 `cp` 의 종료값만 봤다 —
  #   폴더만 만들어지고 알맹이가 반만 복사돼도 「옮겼습니다」라고 말한 뒤 원본을 지웠고,
  #   ★**다음 실행은 「대상이 이미 있다」며 이전을 건너뛰어 반쪽이 영구히 고착된다.**
  #   ⇒ 대조에 실패하면 **원본(`~/.cys`)을 지우지 않는다**(fail-closed). 사람 손 한 번이 유실보다 싸다.
  AGORA_MIGRATE_OK=1
  if [ -d "$AGORA_SKILL_IN_CYS" ] && [ ! -d "$AGORA_SKILL" ]; then
    if mkdir -p "$(dirname "$AGORA_SKILL")" 2>/dev/null && cp -R "$AGORA_SKILL_IN_CYS" "$AGORA_SKILL" 2>/dev/null \
       && tree_same "$AGORA_SKILL_IN_CYS" "$AGORA_SKILL"; then
      say "  옮김: 토론장 안내를 $(short "$AGORA_SKILL") 로 옮겨 두었습니다(내용까지 같은지 확인했습니다)."
    else
      AGORA_MIGRATE_OK=0
      KEPT_FAIL=$((KEPT_FAIL+1))
      say "  🔴토론장 안내를 밖으로 옮기지 못했습니다 — 그래서 $(short "$HOME/.cys") 를 **지우지 않았습니다.**"
      say "         지웠다면 그 안내가 영영 사라졌을 것입니다. 참가 열쇠·이름은 그대로 있습니다."
      say "         $(short "$AGORA_SKILL_IN_CYS") 를 손으로 $(short "$AGORA_SKILL") 에 옮기신 뒤 같은 줄을 다시 돌려 주십시오."
      # 반쪽만 생긴 대상은 치운다 — 그대로 두면 다음 실행이 「이미 있다」며 건너뛴다(고착).
      [ -d "$AGORA_SKILL" ] && ! tree_same "$AGORA_SKILL_IN_CYS" "$AGORA_SKILL" && rm -rf "$AGORA_SKILL" 2>/dev/null
    fi
  fi

  # footprint: M-CYSHOME   (M-CYSPROFILE 은 이 안에 들어 있다)
  if [ "$AGORA_MIGRATE_OK" = "1" ]; then
    drop_dir "$HOME/.cys"
  fi
  # footprint: M-CYSSTATE
  drop_dir "$HOME/.local/state/cys"
  # footprint: M-CLAUDEBIN
  drop_file "$HOME/.local/bin/claude"
  # footprint: M-CLAUDESHARE
  drop_dir "$HOME/.local/share/claude"
  # footprint: M-JARVISHOME
  drop_dir "$JARVIS_HOME"
  # footprint: M-SCRIPTCOPY
  drop_file "$HOME/install-jarvis.sh"
  # 남의 파일 속 우리 줄 — 파일을 지우지 않는다
  # footprint: M-PROFILE
  strip_profile_marker
  #   🔴표에 적힌 칸을 **전건** 빼야 한다. 실기에서 두 칸을 빠뜨렸더니(2026-09-08 게스트 실측)
  #   다 지운 뒤에도 진단기가 자국 1 개를 계속 찾아내 **「중간에 멈춘 상태」로 오보**했다.
  #   ⇒ 「거의 다 지웠다」는 이 도구에서 곧 **거짓 상태 보고**가 된다.
  # footprint: M-CLAUDEJSON
  strip_json_key "$HOME/.claude.json" 'hasCompletedOnboarding'
  strip_json_key "$HOME/.claude.json" 'projects.'"$JARVIS_HOME"
  # footprint: M-CLAUDESETTINGS
  strip_json_key "$HOME/.claude/settings.json" 'theme'
  strip_json_key "$HOME/.claude/settings.json" 'skipDangerousModePermissionPrompt'
  strip_json_key "$HOME/.claude/settings.json" 'remoteControlAtStartup'

  # (로그인은 클로드를 지우기 전에 이미 처리했다 — purge_login_first 참조)
  # footprint: M-CLAUDEUSER  — 손대지 않는다
  say "  남김: 클로드 대화·기록"

  say ""
  # 보존한 것이 있으면 반드시 말한다 — 「지웠는데 왜 남아 있지」를 미리 답한다.
  [ "$PRESERVED" -gt 0 ] && say "    (참가 자리와 겹쳐 그대로 둔 자리 $PRESERVED 곳이 있습니다 — 위 「보존(중첩)」 줄)"
  if [ "$KEPT_FAIL" -eq 0 ]; then
    say "=== 끝났습니다 — $REMOVED 가지를 지웠고, 못 지운 것은 없습니다. ==="
    return 0
  fi
  # 🔴사실만 말한다. 「거의 다 됐다」로 얼버무리면 다음 단계가 그 위에 얹힌다.
  say "=== 끝났습니다 — $REMOVED 가지를 지웠고, $KEPT_FAIL 가지를 못 지웠습니다. ==="
  say "    위에 🔴로 표시된 자리가 남아 있습니다. 그대로 두고 다시 설치하면 뒤엉킵니다."
  say "    같은 줄을 한 번 더 돌려 보시고, 그래도 남으면 그 줄을 알려 주십시오."
  return 7
}

# ── 본문 ──────────────────────────────────────────────────────────
diagnose
[ "$MODE" = "list" ] && exit 0

if [ "$FOUND" -eq 0 ]; then
  say ""
  say "지울 것이 없습니다."
  exit 0
fi

if [ "$ASSUME_YES" != "1" ]; then
  say ""
  say "위 목록을 지웁니다. 되돌릴 수 없습니다."
  printf '계속하려면 「지웁니다」라고 쳐 주십시오: '
  read -r answer < /dev/tty || answer=""
  if [ "$answer" != "지웁니다" ]; then
    say "그만둡니다 — 아무것도 지우지 않았습니다."
    exit 1
  fi
fi

purge
