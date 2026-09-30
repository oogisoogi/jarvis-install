#!/bin/bash
# 0.3.37(TICKET=installer-0337-delete-path) — 삭제 길 사람 손 0 · 자료는 보관 폴더로 · 재설치 = 통째 보관 후 되옮기기(부서 보존) · 반례 처방.
#   설계 = docs/install-master/DESIGN-0337.md (master#bc5fb4f6 승인).
#
# 🔴운영 맥 안전(remover-tests-only-in-guest-home-swap-is-not-isolation): 제거기 **전체는 돌리지 않는다.**
#   맥 = 함수와 purge 본문을 떼어 임시 홈 · 가짜 앱 자리(CYS_APP = 임시 폴더)에서만 부른다. 떼어 낸 묶음에
#   launchctl·pkill·kill·/Applications·security·osascript·sudo 가 **0** 임을 첫 칸에서 잰다(변이 = tests/delete-path-mutate.py 가 그 단언을 깨 본다).
#   윈 = 실물 reset-clean.ps1 을 pwsh 로 C:\Users\emu 흉내(tests/delete-path-win-host.ps1 · Stop-Process·레지스트리 값·바로가기 가짜 · 가짜 uninstall.exe 는 불리면 표지를 남긴다) — login-keep 과 같은 방식.
#   ⛔이 파일에 「제거기 전체 실행」 갈래를 넣으면 입구 거절 가드(아래 refuse_full_run)가 먼저 막는다.
# 쓰는 법: bash tests/delete-path-run.sh [--dir <install-master 자리>] [--only mac|win] · rc 0 = 통과
set -u
HERE="$(cd "$(dirname "$0")" && pwd)"
DIR="$HERE/../install-master"; ONLY=""
while [ $# -gt 0 ]; do case "$1" in --dir) DIR="$2"; shift 2 ;; --only) ONLY="$2"; shift 2 ;; *) shift ;; esac; done
DIR="$(cd "$DIR" && pwd)"
RS="$DIR/reset-clean.sh"; RP="$DIR/reset-clean.ps1"
BASE="$(mktemp -d /tmp/delpathXXXXXX)" || exit 2
trap 'chmod -R u+w "$BASE" 2>/dev/null; rm -rf "${BASE:?}"' EXIT
pass=0; fail=0
t() { if [ "$1" -eq 0 ]; then pass=$((pass+1)); printf '  ok   %s\n' "$2"; else fail=$((fail+1)); printf '  FAIL %s  ← %s\n' "$2" "$3"; fi; }
# 입구 거절 가드(master#bc5fb4f6 ⑨) — 제거기 **전체**를 부르는 갈래는 「/Applications/cys(r).app 있음 + CI 없음」이면 거절한다.
refuse_full_run() {
  if { [ -d /Applications/cysr.app ] || [ -d /Applications/cys.app ]; } && [ -z "${CI:-}" ]; then
    echo "거절: 이 기계에 cys 가 깔려 있고 CI 가 아닙니다 — 제거기 전체 실행은 게스트·러너에서만(운영 맥 보호)."; return 1
  fi
  return 0
}
digest() { ( cd "$1" 2>/dev/null && find . -type f -print0 | LC_ALL=C sort -z | xargs -0 shasum -a 256 2>/dev/null ) | shasum -a 256 | cut -c1-16; }
MARK='jarvis-installer-owned v1'

run_mac() {
echo "== [맥] 함수·purge 본문 떼어 내기(제거기 전체는 안 돌린다) =="
LIB="$BASE/mac-lib.sh"
{
  # 윗머리 값(여러 줄 값 포함) — 사람·기계 자리 값(CYS_APP·CYS_CLI·JARVIS_HOME·AGORA_*·PRESERVE_PATHS·KEYCHAIN·MODE 등)은 시험이 준다
  awk '
    /^(JARVIS_OWNER_MARK|JARVIS_HOME_BASENAME|JARVIS_BACKUP_PREFIX|JARVIS_BACKUP_KEEP|JARVIS_BACKUP_INSTALLER_NAMES|BACKUP_NOTE|RESTORE_MARK|CRED_MARK|PRESCAN_BAD|PRUNE_FAIL|PRUNE_WHY|REMOVED|FOUND|HIST_KEEPS|PRESERVE_CANON|PRESERVE_CANON_FAIL|PRESERVE_CANON_BAD)=/ { print; next }
    /^ARCHIVE_DEST=/ { print; next }
    /^(HISTORY_KEEP_NAMES|STATE_FORMATION_NAMES)="/ { m=1 }
    m { print; if ($0 ~ /"$/ && $0 !~ /^[A-Z_]+="$/) m=0 }
  ' "$RS"
  # 함수 — 기계 자리를 건드리는 것(프로세스 끄기·열쇠고리·osascript)은 빼고, 부르는 쪽은 아래 가짜로 받는다
  awk '
    /^[a-z_]+\(\) *\{/ { n=$1; sub(/\(\).*/, "", n)
      skip = (n ~ /^(kill_verified|stop_cys_processes|alive_after|write_alive_procs|procs_under|proc_token|proc_descendants|table_pids|add_descendants|login_keychain_state|login_keychain_count|login_where|login_present|login_state|login_status|dir_key_json|strip_json_key|purge_login_first|notice_close_cys|diagnose|show_rerun_how|rerun_cmd|strip_hooks|pick_python)$/)
      f=1 }
    f && !skip { print }
    f && /^}/ { f=0 }
  ' "$RS" | sed -e 's/^  launchctl bootout .*$/  : # (시험) 등록 떼기 줄 무력화/'
  cat <<'STUBS'
stop_cys_processes() { :; }
write_alive_procs() { :; }
purge_login_first() { :; }
login_state() { printf absent; }
strip_hooks() { :; }
strip_json_key() { :; }
show_rerun_how() { :; }
STUBS
} > "$LIB"
bash -n "$LIB"; t $? "[맥] 떼어 낸 묶음 문법 통과" "$(bash -n "$LIB" 2>&1 | head -2)"
grep -q '^purge() {' "$LIB" && grep -q '^cys_home_reinstall() {' "$LIB" && grep -q '^prescan_links() {' "$LIB" && grep -q '^resume_unfinished_restore() {' "$LIB"
t $? "[맥] purge · 재설치 되옮기기 · 사전 훑기 · 이어 끝내기가 제거기에 있다" "$(grep -c '() {' "$LIB") 개"
! grep -vE '^\s*#' "$LIB" | grep -qE 'launchctl|pkill|[^_]kill |/Applications|security |osascript|sudo '
t $? "[맥] 떼어 낸 묶음에 기계 등록·프로세스 끄기·/Applications·열쇠고리·osascript 가 없다(운영 맥 안전)" "$(grep -vE '^\s*#' "$LIB" | grep -nE 'launchctl|pkill|[^_]kill |/Applications|security |osascript|sudo ' | head -3 | tr '\n' '|')"

# 제거기 본문의 「purge → 스스로 다시 해 보기」 고리를 그대로 떼어 둔다(LOOPRUN=1 칸이 purge 한 번 대신 이것을 돈다 · 회차 사이 초기화 줄 포함)
MLOOP="$(awk '/^purge$/{p=1} p{print} /^\[ "\$rc" -ne 0 \] && show_rerun_how$/{exit}' "$RS")"
[ -n "$MLOOP" ]; t $? "[맥] 다시 해 보기 고리를 떼어 냈다" "없음"
# 설치가 끝난 맥 흉내 — 작업 폴더 · ~/.cys(본부 · 부서) · 상태 · 클로드 · 가짜 앱
seed_mac() { # seed_mac <홈>
  local H="$1" J="$1/install-jarvis"
  mkdir -p "$J/dl" "$J/notes" "$H/.cys/pack/memory" "$H/.cys/pack/bin" "$H/.cys/claude/projects/-u-install-jarvis" "$H/.cys/claude/skills/z" \
    "$H/.cys/claude/file-history/f" "$H/.cys/claude-default-dept-1/projects/p" "$H/.cys/pack-dept-dept-1/round" "$H/.cys/dept-missions" \
    "$H/.cys/dept-requests/r1" "$H/.cys/state/formation" "$H/.local/state/cys/phoenix" "$H/.local/state/cys/boot-intents" "$H/.local/state/cys-dept-dept-1" \
    "$H/.local/state/cys-trash/dept-9-1" "$H/.local/share/claude/versions" "$H/.local/bin" "$H/Apps/cysr.app/Contents/MacOS" "$H/.claude"
  printf '%s\n' "$MARK" > "$J/.jarvis-owned"; printf 'log\n' > "$J/bootstrap.log"; printf '내 메모\n' > "$J/notes/a.txt"; printf 'x' > "$J/dl/claude-1.bin"
  printf 'mem' > "$H/.cys/pack/memory/MEMORY.md"; printf 'bin' > "$H/.cys/pack/bin/cys-dept"
  printf '{"t":1}\n' > "$H/.cys/claude/projects/-u-install-jarvis/s 1.jsonl"; printf 'h\n' > "$H/.cys/claude/history.jsonl"
  printf 'f' > "$H/.cys/claude/file-history/f/1"; printf '{"claudeAiOauth":{"accessToken":"fake"}}' > "$H/.cys/claude/.credentials.json"
  printf 'router' > "$H/.cys/claude/CLAUDE.md"; printf '{}' > "$H/.cys/claude/settings.json"; printf 'k' > "$H/.cys/claude/skills/z/SKILL.md"
  printf '{"hasCompletedOnboarding":true}' > "$H/.cys/claude-default-dept-1/.claude.json"; printf 'd' > "$H/.cys/claude-default-dept-1/projects/p/x.jsonl"
  printf '{"claudeAiOauth":{"accessToken":"fake-dept"}}' > "$H/.cys/claude-default-dept-1/.credentials.json"
  printf '{"depts":{"dept-1":{"account_dir":"%s"}}}' "$H/.cys/claude-default-dept-1" > "$H/.cys/depts.json"
  printf '{}' > "$H/.cys/dept-catalog.json"; printf 'm' > "$H/.cys/dept-missions/c1.md"; printf '{}' > "$H/.cys/dept-requests/r1/request.json"
  printf -- '- [ ] 부서 할 일\n' > "$H/.cys/pack-dept-dept-1/round/WORKER_TODO.md"; printf 'f' > "$H/.cys/state/formation/k.json"
  printf 'log' > "$H/.cys/dept-launch-path.log"
  printf '{}' > "$H/.local/state/cys/topology.json"; printf 'db' > "$H/.local/state/cys/transcripts.db"; printf '{}' > "$H/.local/state/cys/dept_tombstones.json"
  printf 'r' > "$H/.local/state/cys/phoenix/dept_roster.json"; printf 'i' > "$H/.local/state/cys/boot-intents/1"; printf '{}' > "$H/.local/state/cys/topology.json.corrupt-1"
  printf '{}' > "$H/.local/state/cys-dept-dept-1/topology.json"; printf 'db' > "$H/.local/state/cys-dept-dept-1/transcripts.db"; printf 't' > "$H/.local/state/cys-trash/dept-9-1/x"
  printf 'bin' > "$H/.local/share/claude/versions/2.1"; ln -s "$H/.local/share/claude/versions/2.1" "$H/.local/bin/claude"
  printf 'app' > "$H/Apps/cysr.app/Contents/MacOS/cys"; printf '#!/bin/bash\n' > "$H/install-jarvis.sh"
  # 앱 화면(웹뷰) 자료 — 가짜 HOME 안 Library 만(기계 자리 0)
  mkdir -p "$H/Library/WebKit/com.cysjavis.terminal/WebsiteData" "$H/Library/Caches/com.cysjavis.terminal" "$H/Library/Preferences"
  printf 'w' > "$H/Library/WebKit/com.cysjavis.terminal/WebsiteData/x"; printf 'c' > "$H/Library/Caches/com.cysjavis.terminal/y"; printf 'p' > "$H/Library/Preferences/com.cysjavis.terminal.plist"
}
# mac_purge <이름> <KEEP_HISTORY> <KEEP_APP> [준비 셸] [purge 앞에 끼울 셸] → 홈 · 출력 = <이름>/out.txt · 마지막 줄 RC=<n>
mac_purge() {
  local W="$BASE/mac-$1" H="$BASE/mac-$1/home"
  mkdir -p "$H"; [ "${NOSEED:-0}" = "1" ] || seed_mac "$H"
  [ -n "${4:-}" ] && ( cd "$H" && eval "$4" )
  ( cd "$W" && HOME="$H" JARVIS_HOME="$H/install-jarvis" KEEP_HISTORY="$2" KEEP_APP="$3" CYS_APP="$H/Apps/cysr.app" CYS_APP_OLD="" CYS_CLI="" \
    PURGE_LOGIN=0 ASSUME_YES=1 AGORA_HOME="${AGH:-$H/.config/agora}" AGORA_SKILL="$H/.claude/skills/agora-delegate" AGORA_SKILL_IN_CYS="$H/.cys/claude/skills/agora-delegate" \
    PROFILE_MARKER="# added by jarvis installer (claude PATH)" KEYCHAIN_SERVICE="x" CRED_FILE="$H/.claude/.credentials.json" TRUST_SEED_ROWS="" \
    PRE="${5:-}" LOOPRUN="${LOOPRUN:-0}" MLOOP="$MLOOP" JARVIS_RETRY_WAIT=0 bash -c 'set -u; PRESERVE_PATHS="$AGORA_HOME
$AGORA_SKILL"; . "$1"; KEPT_FAIL=0; PRESERVED=0; ARCHIVE_FAIL=0; ARCHIVED=0; ARCHIVE_HOME=""; ARCHIVE_LAST=""; TRUST_CLEANUP_FAIL=0
      read_trust_seed_record() { TRUST_SEED_ROWS=""; }
      [ -n "$PRE" ] && eval "$PRE"
      if ! prescan_links; then echo "PRESCAN_BAD=$PRESCAN_BAD"; echo "RC=7"; exit 0; fi
      if [ "$LOOPRUN" = "1" ]; then eval "$MLOOP"; echo "RC=$rc"; else purge; echo "RC=$?"; fi' _ "$LIB" ) > "$W/out.txt" 2>&1
  printf '%s' "$H"
}
bk_of() { find "$1" -mindepth 1 -maxdepth 1 -name 'install-jarvis-backup-*' | LC_ALL=C sort | head -1; }
nbk() { find "$1" -mindepth 1 -maxdepth 1 -name 'install-jarvis-backup-*' | wc -l | tr -d ' '; }
rc_of() { sed -n 's/^RC=//p' "$BASE/mac-$1/out.txt" | tail -1; }
why() { tail -${2:-4} "$BASE/mac-$1/out.txt" | tr '\n' '|' | cut -c1-400; }

# ── ⓐ 완전 삭제 = 자료는 보관 폴더 한 곳 · 프로그램만 지움 · 로그인 파일은 보관하지 않음 ──
REF="$BASE/mac-ref/home"; mkdir -p "$REF"; seed_mac "$REF"
H="$(mac_purge a 0 0)"; B="$(bk_of "$H")"
[ "$(rc_of a)" = "0" ] && [ "$(nbk "$H")" = "1" ] && [ -f "$B/notes/a.txt" ] && [ ! -e "$H/install-jarvis" ]
t $? "[맥] ⓐ 완전 삭제 rc 0 · 보관 폴더 1개 · 작업 폴더 자료가 그 안에" "rc=$(rc_of a) 보관본 $(nbk "$H") · $(why a)"
[ "$(digest "$B/cys-home/claude/projects")" = "$(digest "$REF/.cys/claude/projects")" ] && [ -f "$B/cys-home/pack/memory/MEMORY.md" ] \
  && [ -f "$B/cys-home/pack-dept-dept-1/round/WORKER_TODO.md" ] && [ -f "$B/cys-home/depts.json" ] && [ -f "$B/cys-home/claude-default-dept-1/projects/p/x.jsonl" ] && [ ! -e "$H/.cys" ]
t $? "[맥] ⓐ 옛 ~/.cys 통째로 보관(cys-home · 대화 지문 같음 · 팩 기억 · 부서 할 일 · 부서 좌석 대화) · 원자리 비움" "$(ls -A "$B" 2>/dev/null | tr '\n' ' ')"
[ ! -e "$B/cys-home/claude/.credentials.json" ] && [ ! -e "$B/cys-home/claude-default-dept-1/.credentials.json" ] && grep -q '보관본 속 자비스 창 로그인 파일' "$BASE/mac-a/out.txt"
t $? "[맥] ⓐ 보관본에서 로그인 파일(본부·부서)만 빼고 지운다(📌3)" "$(find "$B" -name .credentials.json | head -2 | tr '\n' ' ')"
[ -f "$B/cys-state/transcripts.db" ] && [ -f "$B/cys-dept-state/cys-dept-dept-1/transcripts.db" ] && [ -f "$B/cys-trash/dept-9-1/x" ] \
  && [ ! -e "$H/.local/state/cys" ] && [ ! -e "$H/.local/state/cys-dept-dept-1" ] && [ ! -e "$H/.local/state/cys-trash" ]
t $? "[맥] ⓐ 실행 상태 · 부서 실행 상태 · 닫은 부서 휴지통도 보관(자국 표 밖이던 자리 · §2-3 ②)" "$(ls -A "$H/.local/state" 2>/dev/null | tr '\n' ' ')"
[ ! -e "$H/Apps/cysr.app" ] && [ ! -e "$H/.local/share/claude" ] && [ ! -e "$H/.local/bin/claude" ] && [ ! -L "$H/.local/bin/claude" ] && [ ! -e "$H/install-jarvis.sh" ]
t $? "[맥] ⓐ 프로그램 파일(앱 · 클로드 실물·실행 파일 · 설치 스크립트 사본)은 지운다" "$(why a)"
[ -f "$B/webview-webkit/WebsiteData/x" ] && [ -f "$B/webview-caches/y" ] && [ -f "$B/webview-prefs/com.cysjavis.terminal.plist" ] \
  && [ ! -e "$H/Library/WebKit/com.cysjavis.terminal" ] && [ ! -e "$H/Library/Caches/com.cysjavis.terminal" ] && [ ! -e "$H/Library/Preferences/com.cysjavis.terminal.plist" ]
t $? "[맥] ⓐ 앱 화면(웹뷰) 자료 세 자리 = 보관(윈 W-WEBVIEW 짝 · M-WEBVIEW)" "$(ls -A "$B" 2>/dev/null | tr '\n' ' ')"
grep -q "폴더에 모두 보관해 두었습니다 (" "$BASE/mac-a/out.txt" && grep -q '필요 없으시면' "$BASE/mac-a/out.txt"
t $? "[맥] ⓐ 끝 요약에 보관 폴더 자리·크기 1줄(쉬운 말 · master ②)" "$(why a 3)"

# ── ⓑ 재설치 = 통째 보관 → 남길 것만 되옮김(부서 보존) ──
H="$(mac_purge b 1 1)"; B="$(bk_of "$H")"
[ "$(rc_of b)" = "0" ] && [ "$(digest "$H/.cys/claude/projects")" = "$(digest "$REF/.cys/claude/projects")" ] && [ -f "$H/.cys/claude/.credentials.json" ] \
  && [ -f "$H/.cys/claude/history.jsonl" ] && [ -f "$H/.cys/claude/file-history/f/1" ] && [ ! -e "$H/.cys/claude/CLAUDE.md" ] && [ ! -e "$H/.cys/claude/settings.json" ]
t $? "[맥] ⓑ 재설치 = 본부 로그인·대화 5 제자리(바이트 같음) · CLAUDE.md·settings.json 은 새로(보관본으로)" "rc=$(rc_of b) · $(why b)"
[ "$(digest "$H/.cys/claude-default-dept-1")" = "$(digest "$REF/.cys/claude-default-dept-1")" ] && [ -f "$H/.cys/depts.json" ] && [ -f "$H/.cys/dept-catalog.json" ] \
  && [ -f "$H/.cys/dept-missions/c1.md" ] && [ -f "$H/.cys/dept-requests/r1/request.json" ] && [ -f "$H/.cys/pack-dept-dept-1/round/WORKER_TODO.md" ]
t $? "[맥] ⓑ 부서 등록부·카탈로그·임무·요청·부서 팩(할 일)·부서 좌석 프로필(통째) 제자리" "$(ls -A "$H/.cys" | tr '\n' ' ')"
[ ! -e "$H/.cys/pack" ] && [ ! -e "$H/.cys/state" ] && [ ! -e "$H/.cys/dept-launch-path.log" ] && [ -f "$B/cys-home/pack/memory/MEMORY.md" ] && [ -f "$B/cys-home/claude/CLAUDE.md" ] \
  && [ ! -e "$B/$(printf '.jarvis-restore-pending')" ]
t $? "[맥] ⓑ 새 ~/.cys 에 팩 없음(병합 대기 0) · 나머지는 보관본에(팩 기억 포함 · §2-3 ④) · 되옮기기 표지 치움" "$(ls -A "$B/cys-home" 2>/dev/null | tr '\n' ' ')"
[ -f "$B/cys-state/topology.json" ] && [ -f "$B/cys-state/dept_tombstones.json" ] && [ -e "$B/cys-state/phoenix" ] && [ -e "$B/cys-state/boot-intents" ] && [ -f "$B/cys-state/topology.json.corrupt-1" ] \
  && [ -f "$H/.local/state/cys/transcripts.db" ] && [ -f "$H/.local/state/cys-dept-dept-1/topology.json" ] && [ -f "$H/.local/state/cys-trash/dept-9-1/x" ]
t $? "[맥] ⓑ 재설치 = 본부 편성 기록만 보관 · 검색 기록·부서 상태·휴지통 제자리(📌4 ⓑ · 윈과 같은 모양)" "$(ls -A "$H/.local/state/cys" | tr '\n' ' ')"
[ -d "$H/Apps/cysr.app" ] && [ ! -e "$H/.local/share/claude" ] && [ -f "$H/Library/WebKit/com.cysjavis.terminal/WebsiteData/x" ] && [ -f "$H/Library/Preferences/com.cysjavis.terminal.plist" ]
t $? "[맥] ⓑ 재설치 = 앱·앱 화면 자료 남김 · 클로드 실물은 지움(다시 받음 · 종전)" "$(why b)"

# ── F8 --keep-app 단독(KEEP_HISTORY=0 · KEEP_APP=1) = 윈 -KeepApp 단독과 같은 뜻 — 상태는 편성 기록만 보관 · 검색 기록·부서 상태·휴지통·앱 화면 자료 제자리 ──
#   (~/.cys 는 --keep-history 몫이라 이 길에선 통째 보관 = 종전 · 윈과 같음)
H="$(mac_purge ka 0 1)"; B="$(bk_of "$H")"
[ "$(rc_of ka)" = "0" ] && [ -f "$B/cys-state/topology.json" ] && [ -f "$B/cys-state/dept_tombstones.json" ] && [ -e "$B/cys-state/phoenix" ] && [ -e "$B/cys-state/boot-intents" ] \
  && [ -f "$B/cys-state/topology.json.corrupt-1" ] && [ ! -e "$B/cys-state/transcripts.db" ] && [ -f "$H/.local/state/cys/transcripts.db" ] \
  && [ -f "$H/.local/state/cys-dept-dept-1/topology.json" ] && [ -f "$H/.local/state/cys-trash/dept-9-1/x" ] && [ ! -e "$B/cys-dept-state" ] && [ ! -e "$B/cys-trash" ]
t $? "[맥] F8 앱 남김 단독 = 편성 기록만 보관 · 검색 기록·부서 상태·휴지통 제자리(윈 -KeepApp 단독 짝)" "rc=$(rc_of ka) · 상태=$(ls -A "$H/.local/state/cys" 2>/dev/null | tr '\n' ' ') · 보관=$(ls -A "$B" 2>/dev/null | tr '\n' ' ')"
[ -d "$H/Apps/cysr.app" ] && [ -f "$H/Library/WebKit/com.cysjavis.terminal/WebsiteData/x" ] && [ -f "$H/Library/Preferences/com.cysjavis.terminal.plist" ] && [ -f "$B/cys-home/depts.json" ] && [ ! -e "$H/.cys" ]
t $? "[맥] F8 앱 남김 단독 = 앱·앱 화면 자료 그대로 · ~/.cys 는 통째 보관(--keep-history 몫 · 종전)" "$(why ka)"

# ── ⓒ 옮기기 실패(홈에 쓰기 막힘) → 아무것도 안 지움 · 뒤 단계(앱·클로드) 멈춤 · rc 7 ──
H="$(mac_purge c 0 0 'chmod 555 .')"
chmod 755 "$H"
[ "$(rc_of c)" = "7" ] && [ -f "$H/.cys/claude/projects/-u-install-jarvis/s 1.jsonl" ] && [ -d "$H/Apps/cysr.app" ] && [ -d "$H/.local/share/claude" ] && grep -q '보관을 끝까지 마치지 못해' "$BASE/mac-c/out.txt"
t $? "[맥] ⓒ 보관 폴더로 못 옮기면 자료 그대로 · 프로그램도 안 지움 · rc 7(master ⑴⑵)" "rc=$(rc_of c) · $(why c)"

# ── ⓓ 옮긴 뒤 수·크기가 다르면 → 뒤 단계 멈춤 ──
H="$(mac_purge d 0 0 '' 'tree_stat() { if [ -f "$HOME/.ts" ]; then echo "9 9"; else : > "$HOME/.ts"; perl -MFile::Find -e '"'"'my($n,$b)=(0,0); find({no_chdir=>1,wanted=>sub{my @s=lstat($_); return if -d _; $n++; $b+=$s[7]}}, $ARGV[0]); print "$n $b\n"'"'"' "$1"; fi; }')"
[ "$(rc_of d)" = "7" ] && [ -d "$H/Apps/cysr.app" ] && grep -q '보관 확인 실패' "$BASE/mac-d/out.txt"
t $? "[맥] ⓓ 옮긴 뒤 수·크기가 다르면 「보관 확인 실패」 · 앱 안 지움 · rc 7" "rc=$(rc_of d) · $(why d)"

# ── ⓔ 다른 디스크 → 복사하지 않고 멈춤 ──
H="$(mac_purge e 0 0 '' 'volume_of() { case "$1" in *install-jarvis-backup-*) echo 1 ;; *) echo 2 ;; esac; }')"
[ "$(rc_of e)" = "7" ] && [ -d "$H/.cys" ] && [ -d "$H/Apps/cysr.app" ] && grep -q '다른 디스크' "$BASE/mac-e/out.txt"
t $? "[맥] ⓔ 보관 폴더와 다른 디스크면 옮기지 않고(복사 0) 멈춤(master ⑶)" "rc=$(rc_of e) · $(why e)"

# ── ⓕ 되옮기기 도중 끊김 → 다음 실행이 이어서 끝낸다(master ⑴) ──
FAKE="$BASE/fakeperl"; mkdir -p "$FAKE"
cat > "$FAKE/perl" <<'FP'
#!/bin/bash
# 이름 바꾸기 세기 — DIE_AT 번째 이름 바꾸기에서 부른 셸째 죽는다(창이 닫힌 흉내)
if [ "${1:-}" = "-e" ] && printf '%s' "${2:-}" | grep -q '^rename'; then
  n=$(( $(cat "$COUNT_FILE" 2>/dev/null || echo 0) + 1 )); echo "$n" > "$COUNT_FILE"
  [ "$n" -eq "${DIE_AT:-0}" ] && kill -9 "$PPID"
fi
exec /usr/bin/perl "$@"
FP
chmod +x "$FAKE/perl"
H="$(mac_purge f 1 1 '' "export PATH=\"$FAKE:\$PATH\" COUNT_FILE=\"$BASE/mac-f/count\" DIE_AT=4")"
B="$(bk_of "$H")"
[ -f "$B/.jarvis-restore-pending" ] && [ ! -e "$H/.cys/depts.json" -o ! -e "$H/.cys/claude/projects" ]
t $? "[맥] ⓕ-1 되옮기기 도중 끊기면 표지가 남고 일부는 보관본에만 있다(재현 확인)" "표지=$([ -f "$B/.jarvis-restore-pending" ] && echo 있음 || echo 없음) · $(ls -A "$H/.cys" 2>/dev/null | tr '\n' ' ')"
[ -f "$B/cys-home/claude/projects/-u-install-jarvis/s 1.jsonl" ] || [ -f "$H/.cys/claude/projects/-u-install-jarvis/s 1.jsonl" ]
t $? "[맥] ⓕ-2 끊긴 동안에도 대화는 한 곳(원자리 또는 보관본)에 온전" "없음"
( cd "$BASE/mac-f" && HOME="$H" JARVIS_HOME="$H/install-jarvis" KEEP_HISTORY=1 KEEP_APP=1 bash -c 'set -u; . "$1"; KEPT_FAIL=0; ARCHIVE_FAIL=0; resume_unfinished_restore; echo "KF=$KEPT_FAIL"' _ "$LIB" ) > "$BASE/mac-f/out2.txt" 2>&1
[ ! -f "$B/.jarvis-restore-pending" ] && [ "$(digest "$H/.cys/claude/projects")" = "$(digest "$REF/.cys/claude/projects")" ] && [ -f "$H/.cys/depts.json" ] \
  && [ -f "$H/.cys/pack-dept-dept-1/round/WORKER_TODO.md" ] && grep -q '^KF=0$' "$BASE/mac-f/out2.txt" && grep -q '이어서 합니다' "$BASE/mac-f/out2.txt"
t $? "[맥] ⓕ-3 다음 실행이 표지부터 이어서 끝낸다 · 표지 치움 · 대화 지문 같음" "$(tail -4 "$BASE/mac-f/out2.txt" | tr '\n' '|')"

# ── ⓖ 되옮기기 한 칸 실패 → 표지에 남은 것만 · rc 7 · 다음 실행이 끝낸다 ──
cat > "$FAKE/perl2" <<'FP'
#!/bin/bash
if [ "${1:-}" = "-e" ] && printf '%s' "${2:-}" | grep -q '^rename' && printf '%s' "${4:-}" | grep -q '/.cys/depts.json$'; then exit 1; fi
exec /usr/bin/perl "$@"
FP
mkdir -p "$BASE/fp2"; mv "$FAKE/perl2" "$BASE/fp2/perl"; chmod +x "$BASE/fp2/perl"
H="$(mac_purge g 1 1 '' "export PATH=\"$BASE/fp2:\$PATH\"")"; B="$(bk_of "$H")"
[ "$(rc_of g)" = "7" ] && [ -f "$B/.jarvis-restore-pending" ] && [ -f "$B/cys-home/depts.json" ] && [ -f "$H/.cys/claude/history.jsonl" ] && [ -d "$H/Apps/cysr.app" ]
t $? "[맥] ⓖ 되옮기기 한 칸 실패 → 그 칸은 보관본에 · 표지 남김 · 재설치 멈춤(rc 7)" "rc=$(rc_of g) · $(why g)"
( cd "$BASE/mac-g" && HOME="$H" JARVIS_HOME="$H/install-jarvis" bash -c 'set -u; . "$1"; KEPT_FAIL=0; ARCHIVE_FAIL=0; resume_unfinished_restore; echo "KF=$KEPT_FAIL"' _ "$LIB" ) > "$BASE/mac-g/out2.txt" 2>&1
[ -f "$H/.cys/depts.json" ] && [ ! -f "$B/.jarvis-restore-pending" ] && grep -q '^KF=0$' "$BASE/mac-g/out2.txt"
t $? "[맥] ⓖ-2 다음 실행이 남은 한 칸을 끝낸다" "$(tail -3 "$BASE/mac-g/out2.txt" | tr '\n' '|')"

# ── ⓓ 반례 ② 사전 훑기: 남길 자리 안 바로가기가 지울 프로그램 자리를 가리킴 → 아무것도 안 바꿈 ──
H="$(mac_purge p2 1 1 'printf keep > .local/share/claude/talk.jsonl && ln -s "$PWD/.local/share/claude/talk.jsonl" .cys/claude/projects/lnk')"
[ "$(rc_of p2)" = "7" ] && [ -f "$H/.local/share/claude/talk.jsonl" ] && [ -f "$H/.cys/claude/CLAUDE.md" ] && [ -d "$H/install-jarvis" ] && [ "$(nbk "$H")" = "0" ] && grep -q '지울 프로그램 자리를 가리킵니다' "$BASE/mac-p2/out.txt"
t $? "[맥] 반례② 바로가기가 지울 자리(클로드 실물)를 가리키면 첫 변경 전에 멈춤 · 변경 0" "rc=$(rc_of p2) · $(why p2)"
# ── 반례 ③ 홈 경로에 줄바꿈 ──
NH="$BASE/mac-p3/ho
me"; mkdir -p "$NH"; seed_mac "$NH"
( cd "$BASE/mac-p3" && HOME="$NH" JARVIS_HOME="$NH/install-jarvis" KEEP_HISTORY=1 KEEP_APP=1 CYS_APP="$NH/Apps/cysr.app" CYS_APP_OLD="" PRESERVE_PATHS="" bash -c 'set -u; . "$1"; prescan_links; echo "RC=$?"; echo "BAD=$PRESCAN_BAD"' _ "$LIB" ) > "$BASE/mac-p3/out.txt" 2>&1
grep -q '^RC=1$' "$BASE/mac-p3/out.txt" && grep -q '줄바꿈' "$BASE/mac-p3/out.txt"
t $? "[맥] 반례③ 홈 경로에 줄바꿈 → 사전 훑기가 못 풂(첫 변경 전)" "$(tr '\n' '|' < "$BASE/mac-p3/out.txt")"
# ── 반례 ④ 목록(find)만 실패 → 못 풂 ──
mkdir -p "$BASE/ff"; printf '#!/bin/bash\nfor a in "$@"; do [ "$a" = "-type" ] && exit 1; done\nexec /usr/bin/find "$@"\n' > "$BASE/ff/find"; chmod +x "$BASE/ff/find"
H="$(mac_purge p4 1 1 '' "export PATH=\"$BASE/ff:\$PATH\"")"
[ "$(rc_of p4)" = "7" ] && [ -f "$H/.cys/claude/CLAUDE.md" ] && [ "$(nbk "$H")" = "0" ] && grep -q '목록을 끝까지 읽지 못했습니다' "$BASE/mac-p4/out.txt"
t $? "[맥] 반례④ 목록 읽기(find)가 실패하면 「남길 것 없음」이 아니라 못 풂 · 변경 0" "rc=$(rc_of p4) · $(why p4)"
# ── 반례 ① 남길 자리 안 바로가기가 ~/.cys 의 남길 것 밖(pack)을 가리킴 → 멈추지 않음 · 가리키던 자료는 보관본 · 안내 ──
H="$(mac_purge p1 1 1 'mkdir -p .cys/pack/talk && printf talk > .cys/pack/talk/s.jsonl && ln -s "$PWD/.cys/pack/talk" .cys/claude/projects/lnk')"; B="$(bk_of "$H")"
[ "$(rc_of p1)" = "0" ] && [ "$(cat "$B/cys-home/pack/talk/s.jsonl" 2>/dev/null)" = "talk" ] && grep -q '^  \[안내\] 아래 바로가기가 가리키던 자료는 보관 폴더' "$BASE/mac-p1/out.txt"
t $? "[맥] 반례① 가리키던 자료는 보관본에 온전 · 안내 1줄(삭제 0)" "rc=$(rc_of p1) · $(why p1 6)"
# ── 반례 ⑤ pack 이 projects 안을 가리키는 바로가기 → 새 ~/.cys 에 pack 없음 · projects 그대로 ──
H="$(mac_purge p5 1 1 'rm -rf .cys/pack && mkdir -p .cys/claude/projects/p && printf k > .cys/claude/projects/p/k.jsonl && ln -s "$PWD/.cys/claude/projects/p" .cys/pack')"
[ "$(rc_of p5)" = "0" ] && [ ! -e "$H/.cys/pack" ] && [ ! -L "$H/.cys/pack" ] && [ -f "$H/.cys/claude/projects/p/k.jsonl" ]
t $? "[맥] 반례⑤ pack 바로가기는 보관본으로 · 새 자리에 pack 이름표 없음 · 대화 그대로" "rc=$(rc_of p5) · $(why p5)"

# ── 반례 ③-2 바로가기 **이름**에 줄바꿈 → 못 풂 ──
H="$(mac_purge p3b 1 1 'ln -s "$PWD/.cys/claude/history.jsonl" "$PWD/.cys/claude/projects/a
b"')"
[ "$(rc_of p3b)" = "7" ] && [ -f "$H/.cys/claude/CLAUDE.md" ] && [ "$(nbk "$H")" = "0" ] && grep -q '줄바꿈' "$BASE/mac-p3b/out.txt"
t $? "[맥] 반례③-2 바로가기 이름에 줄바꿈 → 못 풂 · 변경 0" "rc=$(rc_of p3b) · $(why p3b)"
# ── ⓓ-2 작업 폴더가 아닌 자리(~/.cys)의 대조가 어긋남 → 뒤 단계 멈춤 ──
H="$(mac_purge d2 0 0 '' 'eval "orig_tree_stat() $(declare -f tree_stat | tail -n +2)"; tree_stat() { case "$1" in */cys-home) echo "0 0" ;; *) orig_tree_stat "$1" ;; esac; }')"
[ "$(rc_of d2)" = "7" ] && [ -d "$H/Apps/cysr.app" ] && [ -d "$H/.local/share/claude" ] && grep -q '보관 확인 실패' "$BASE/mac-d2/out.txt"
t $? "[맥] ⓓ-2 ~/.cys 를 옮긴 뒤 수·크기가 다르면 「보관 확인 실패」 · 앱·클로드 안 지움 · rc 7" "rc=$(rc_of d2) · $(why d2)"
# ── ⓕ-4 되옮기기가 끊긴 뒤 **재설치를 다시 돌리면**(purge) 먼저 이어서 끝낸다 ──
H="$(mac_purge f4 1 1 '' "export PATH=\"$FAKE:\$PATH\" COUNT_FILE=\"$BASE/mac-f4/count\" DIE_AT=4")"
H2="$(NOSEED=1 mac_purge f4 1 1)"; B="$(bk_of "$H")"
[ "$(rc_of f4)" = "0" ] && [ ! -f "$B/.jarvis-restore-pending" ] && [ "$(digest "$H/.cys/claude/projects")" = "$(digest "$REF/.cys/claude/projects")" ] \
  && [ -f "$H/.cys/depts.json" ] && [ -f "$H/.cys/pack-dept-dept-1/round/WORKER_TODO.md" ] && grep -q '이어서 합니다' "$BASE/mac-f4/out.txt"
t $? "[맥] ⓕ-4 끊긴 뒤 재설치를 다시 돌리면 purge 가 먼저 이어서 끝낸다 · 대화·부서 제자리 · 표지 치움" "rc=$(rc_of f4) · $(why f4 6)"
# ── ⓠ ~/.cys/claude 자체가 바로가기 → 재설치 못 풂(0.3.36 규칙 유지) ──
H="$(mac_purge q 1 1 'mv .cys/claude ./prof-real && ln -s "$PWD/prof-real" .cys/claude')"
[ "$(rc_of q)" = "7" ] && [ -L "$H/.cys/claude" ] && [ -f "$H/prof-real/CLAUDE.md" ] && [ -f "$H/.cys/pack/memory/MEMORY.md" ]
t $? "[맥] ⓠ ~/.cys/claude 가 바로가기면 재설치 = ~/.cys 변경 0 · rc 7(0.3.36 ⓠ 유지)" "rc=$(rc_of q) · $(why q)"

# ── 예외 갈래(참가 자리가 ~/.cys 안 · §4-4 · 재설치 = 0.3.36 장치 + 부서 남길 것 + 반례 처방) ──
AGF='mkdir -p .cys/forum && printf key > .cys/forum/key'
AGH="$BASE/mac-x1/home/.cys/forum" H="$(AGH="$BASE/mac-x1/home/.cys/forum" mac_purge x1 1 1 "$AGF")"
[ "$(rc_of x1)" = "0" ] && [ "$(cat "$H/.cys/forum/key" 2>/dev/null)" = "key" ] && [ -f "$H/.cys/claude/projects/-u-install-jarvis/s 1.jsonl" ] && [ -f "$H/.cys/depts.json" ] \
  && [ -f "$H/.cys/pack-dept-dept-1/round/WORKER_TODO.md" ] && [ -f "$H/.cys/claude-default-dept-1/projects/p/x.jsonl" ] && [ ! -e "$H/.cys/pack" ] && [ ! -e "$H/.cys/claude/CLAUDE.md" ]
t $? "[맥] 예외 F1 참가 자리 안(~/.cys/forum) → 열쇠·본부 대화·부서 기록 남김 · 팩·CLAUDE.md 지움 · rc 0" "rc=$(rc_of x1) · $(ls -A "$H/.cys" 2>/dev/null | tr '\n' ' ') · $(why x1)"
H="$(AGH="$BASE/mac-x2/home/.cys/forum" mac_purge x2 1 1 "$AGF"' && mkdir -p .cys/pack/talk && printf talk > .cys/pack/talk/s.jsonl && ln -s "$PWD/.cys/pack/talk" .cys/claude/projects/lnk')"
[ "$(rc_of x2)" = "7" ] && [ "$(cat "$H/.cys/pack/talk/s.jsonl" 2>/dev/null)" = "talk" ] && grep -q '남길 자리 밖을 가리킵니다' "$BASE/mac-x2/out.txt"
t $? "[맥] 예외 F① 남길 자리 안 바로가기가 남길 것 밖(pack)을 가리키면 못 풂 · 변경 0(반례① 처방)" "rc=$(rc_of x2) · $(why x2)"
H="$(AGH="$BASE/mac-x5/home/.cys/forum" mac_purge x5 1 1 "$AGF"' && rm -rf .cys/pack && mkdir -p .cys/claude/projects/p && printf k > .cys/claude/projects/p/k.jsonl && ln -s "$PWD/.cys/claude/projects/p" .cys/pack')"
[ "$(rc_of x5)" = "0" ] && [ ! -e "$H/.cys/pack" ] && [ ! -L "$H/.cys/pack" ] && [ -f "$H/.cys/claude/projects/p/k.jsonl" ]
t $? "[맥] 예외 F⑤ pack 이 projects 안을 가리키는 바로가기 → pack 이름표 지움 · 대화 그대로(반례⑤ 처방)" "rc=$(rc_of x5) · $(why x5)"
# ⓓM 참가 자리 안 바로가기(참가자가 만든 것)는 표지 없는 길에서도 남긴다 — MINOR 처방 기각 · 더 남기는 쪽 고정
MH="$BASE/mac-xm/home"; mkdir -p "$MH/root/forum" "$MH/outside"; printf o > "$MH/outside/o"; ln -s "$MH/outside" "$MH/root/forum/lnk"; printf z > "$MH/root/junk"
( HOME="$MH" bash -c 'set -u; . "$1"; PRESERVE_PATHS="$HOME/root/forum"; KEPT_FAIL=0; REMOVED=0; PRESERVED=0; resolve_preserve_paths; drop_dir "$HOME/root"; echo "KF=$KEPT_FAIL"' _ "$LIB" ) > "$BASE/mac-xm.txt" 2>&1
[ -L "$MH/root/forum/lnk" ] && [ -f "$MH/outside/o" ] && [ ! -e "$MH/root/junk" ] && grep -q '^KF=0$' "$BASE/mac-xm.txt"
t $? "[맥] ⓓM 표지 없는 길 · 참가 자리 안 바로가기는 남는다(자리 비교 · 0.3.36 동작 고정)" "$(tr '\n' '|' < "$BASE/mac-xm.txt" | cut -c1-300)"

# ── 새 결함 ⓑ(0337 후임 · 결정 3) 보관본 속 로그인 파일 지우기가 1회차에 실패 → 다시 해 보기가 그 파일을 다시 지운다(비밀값을 남긴 채 rc 0 금지) ──
H="$(LOOPRUN=1 mac_purge rb 0 0 '' 'eval "orig_dac() $(declare -f drop_archived_credentials | tail -n +2)"; _dacn=0; drop_archived_credentials() { _dacn=$((_dacn+1)); if [ "$_dacn" -eq 1 ]; then KEPT_FAIL=$((KEPT_FAIL+1)); say "  (시험) 보관본 속 로그인 파일 지우기 실패 흉내"; return 0; fi; orig_dac "$@"; }')"
[ "$(rc_of rb)" = "0" ] && [ -z "$(find "$H" -path '*install-jarvis-backup-*' -name .credentials.json 2>/dev/null)" ] && grep -q '(시험) 보관본 속 로그인 파일 지우기 실패 흉내' "$BASE/mac-rb/out.txt" \
  && [ "$(grep -c '스스로 한 번 더 해 봅니다' "$BASE/mac-rb/out.txt")" = "1" ]
t $? "[맥] 새ⓑ 1회차에 보관본 로그인 파일을 못 지우면 다시 해 보기가 그 자리를 다시 지운다 · 비밀값 0 · rc 0" "rc=$(rc_of rb) · 남은 것 $(find "$H" -path '*install-jarvis-backup-*' -name .credentials.json 2>/dev/null | head -2 | tr '\n' ' ') · $(why rb)"
# ── 새 결함 ⓒ 신뢰 칸 실패 깃발 — 1회차만 실패하면 2회차가 매 회차 실측으로 다시 세운다(작업 폴더 보관 · rc 0) ──
H="$(LOOPRUN=1 mac_purge rc 0 0 '' '_trn=0; read_trust_seed_record() { _trn=$((_trn+1)); TRUST_SEED_ROWS=""; if [ "$_trn" -eq 1 ]; then TRUST_CLEANUP_FAIL=$((TRUST_CLEANUP_FAIL+1)); say "  (시험) 신뢰 기록 읽기 실패 흉내"; fi; }')"
[ "$(rc_of rc)" = "0" ] && [ ! -e "$H/install-jarvis" ] && [ -n "$(find "$H" -path '*install-jarvis-backup-*/notes/a.txt' 2>/dev/null)" ] && grep -q '(시험) 신뢰 기록 읽기 실패 흉내' "$BASE/mac-rc/out.txt"
t $? "[맥] 새ⓒ 신뢰 칸 실패가 1회차에서 풀리면 2회차가 작업 폴더를 보관하고 rc 0(깃발은 회차마다 다시 잰다)" "rc=$(rc_of rc) · $(why rc)"
H="$(LOOPRUN=1 mac_purge rc2 0 0 '' 'read_trust_seed_record() { TRUST_SEED_ROWS=""; TRUST_CLEANUP_FAIL=$((TRUST_CLEANUP_FAIL+1)); }')"
[ "$(rc_of rc2)" = "7" ] && [ -f "$H/install-jarvis/notes/a.txt" ]
t $? "[맥] 새ⓒ-2 매 회차 실패면 끝까지 작업 폴더를 남기고 rc 7(무조건 풀기 금지)" "rc=$(rc_of rc2) · $(why rc2)"
# ── 결정 ⑵ 같은 실행의 다시 해 보기에서 되옮기기가 거듭 실패 → 두 번째 회차가 표지를 덮지 않는다(남은 한 칸이 표지에 그대로 · rc 7) ──
H="$(LOOPRUN=1 mac_purge rg 1 1 '' "export PATH=\"$BASE/fp2:\$PATH\"")"
MK="$(find "$H" -mindepth 2 -maxdepth 2 -path '*install-jarvis-backup-*' -name .jarvis-restore-pending | head -1)"
HN="$( [ -n "$MK" ] && tr '\0' '\n' < "$MK" | head -1)"
[ "$(rc_of rg)" = "7" ] && [ -n "$MK" ] && tr '\0' '\n' < "$MK" | grep -qx 'depts.json' && [ -f "$(dirname "$MK")/$HN/depts.json" ] && [ ! -e "$(dirname "$MK")/cys-home-2" ] \
  && grep -q '다시 실행하시면 이어서 제자리로 옮깁니다' "$BASE/mac-rg/out.txt"
t $? "[맥] 결정⑵ 되옮기기가 거듭 실패해도 표지를 덮지 않는다 · 남은 칸이 표지와 보관본에 · rc 7 · 쉬운 말 안내" "rc=$(rc_of rg) · 표지=$MK 첫칸=$HN · $(why rg 6)"
# ── 결정⑵ 가드 단독(이어 하기를 끈 상태) — 같은 실행 둘째 회차가 끝나지 않은 표지가 있는 보관 폴더에 ~/.cys 를 또 옮기지 않는다
#    (r1 F2 의 이어 가지 않음이 같은 상황을 먼저 막아 이 가드가 시험에서 안 닿게 됐다 — 가드 자체를 따로 잰다) ──
H="$(LOOPRUN=1 mac_purge rg2 1 1 '' "export PATH=\"$BASE/fp2:\$PATH\"; resume_unfinished_restore() { RESUME_LEFT=0; }")"
MK="$(find "$H" -mindepth 2 -maxdepth 2 -path '*install-jarvis-backup-*' -name .jarvis-restore-pending | head -1)"
[ "$(rc_of rg2)" = "7" ] && [ -n "$MK" ] && [ ! -e "$(dirname "$MK")/cys-home-2" ] && grep -q '지난번 옮기기가 아직 끝나지 않아' "$BASE/mac-rg2/out.txt"
t $? "[맥] 결정⑵ 가드 단독 — 이어 하기를 꺼도 둘째 회차가 끝나지 않은 표지 위에 ~/.cys 를 또 옮기지 않는다" "rc=$(rc_of rg2) · $(why rg2 4)"
# ── r1 F2(master#0337b3fa · 겹침 = 되옮기기 실패) 끊긴 재설치 뒤 같은 이름의 새 자료가 생김 → 재설치를 다시 돌려도(새 프로세스 purge 전체)
#    덮지 않고 · 옛 자료는 보관본에 · 표지 유지 · rc 7 · 쉬운 말 · 그 이름에 「되옮겼습니다」 0 · 이어 가지 않는다(~/.cys 를 또 옮기지 않음) ──
H="$(mac_purge ov 1 1 '' "export PATH=\"$FAKE:\$PATH\" COUNT_FILE=\"$BASE/mac-ov/count\" DIE_AT=4")"; B="$(bk_of "$H")"
HN="$(tr '\0' '\n' < "$B/.jarvis-restore-pending" 2>/dev/null | head -1)"; OV=""
while IFS= read -r r; do [ -n "$r" ] && [ -n "$HN" ] && { [ -e "$B/$HN/$r" ] || [ -L "$B/$HN/$r" ]; } && { OV="$r"; break; }; done <<OVL
$(tr '\0' '\n' < "$B/.jarvis-restore-pending" 2>/dev/null | tail -n +2)
OVL
if [ -n "$OV" ]; then
  OLDD="$(digest "$B/$HN/$OV")"; [ -d "$B/$HN/$OV" ] || OLDD="$(shasum -a 256 < "$B/$HN/$OV")"
  if [ -d "$B/$HN/$OV" ]; then mkdir -p "$H/.cys/$OV"; printf new > "$H/.cys/$OV/new-after-cut"; else mkdir -p "$(dirname "$H/.cys/$OV")"; printf new > "$H/.cys/$OV"; fi
fi
NOSEED=1 mac_purge ov 1 1 >/dev/null
NCH="$(find "$H" -mindepth 2 -maxdepth 2 -path '*install-jarvis-backup-*' -name 'cys-home*' | wc -l | tr -d ' ')"
if [ -d "$B/$HN/$OV" ]; then NOLD="$(digest "$B/$HN/$OV")"; else NOLD="$(shasum -a 256 < "$B/$HN/$OV" 2>/dev/null)"; fi
[ -n "$OV" ] && [ "$(rc_of ov)" = "7" ] && [ -f "$B/.jarvis-restore-pending" ] && tr '\0' '\n' < "$B/.jarvis-restore-pending" | grep -qxF "$OV" \
  && [ "$NOLD" = "$OLDD" ] && { [ -f "$H/.cys/$OV/new-after-cut" ] || [ "$(cat "$H/.cys/$OV" 2>/dev/null)" = "new" ]; } && [ "$NCH" = "1" ] \
  && grep -q '같은 이름의 자료가 이미 있어 덮지 않았습니다' "$BASE/mac-ov/out.txt" && grep -q '예전 자료는 보관 폴더에 그대로 있습니다' "$BASE/mac-ov/out.txt" \
  && ! grep -q '되옮겼습니다' "$BASE/mac-ov/out.txt" && ! grep -qF "되옮김: ~/.cys/$OV" "$BASE/mac-ov/out.txt" \
  && grep -qF "그대로 있습니다: ~/$(basename "$B")/$HN/$OV" "$BASE/mac-ov/out.txt" && grep -q '다른 이름으로 바꿔 두신 뒤 다시 실행하시면' "$BASE/mac-ov/out.txt" && grep -q '바꿔 둔 새 쪽은 그때 보관 폴더로 함께 옮겨집니다' "$BASE/mac-ov/out.txt"
t $? "[맥] F2 끊긴 재설치 뒤 같은 이름의 새 자료 → 다시 돌려도 덮지 않음 · 옛 자료 보관본 그대로 · 표지 유지 · rc 7 · 쉬운 말 · 되옮겼다는 말 0 · ~/.cys 다시 옮기지 않음" \
  "겹친 이름=$OV · rc=$(rc_of ov) · 표지=$([ -f "$B/.jarvis-restore-pending" ] && echo 있음 || echo 없음) · 옛 cys-home 수=$NCH · $(why ov 6)"
# ── r1 F5 맥 진단이 끝나지 않은 되옮기기 표지를 「찾은 자국」 으로 센다(윈 짝) — 다른 자국이 없어도 「지울 것이 없습니다」 로 끝나지 않고 이어 하기가 돈다 ──
DG="$BASE/mac-diag.sh"; awk '/^diagnose\(\) *\{/{f=1} f{print} f && /^}/{exit}' "$RS" > "$DG"
W="$BASE/mac-f5"; H="$W/home"; BK="$H/install-jarvis-backup-20260101-000000"; mkdir -p "$BK/cys-home"
printf '%s\n' "$MARK" > "$BK/.jarvis-owned"; printf 'cys-home\0depts.json\0' > "$BK/.jarvis-restore-pending"; printf '{}' > "$BK/cys-home/depts.json"
( cd "$W" && HOME="$H" JARVIS_HOME="$H/install-jarvis" KEEP_HISTORY=1 KEEP_APP=1 CYS_APP="$H/Apps/cysr.app" CYS_APP_OLD="" CYS_CLI="" MODE="" PURGE_LOGIN=0 ASSUME_YES=1 CYS_CRED_FILE="$H/.cys/claude/.credentials.json" \
    AGORA_HOME="$H/.config/agora" AGORA_SKILL="$H/.claude/skills/agora-delegate" AGORA_SKILL_IN_CYS="$H/.cys/claude/skills/agora-delegate" \
    PROFILE_MARKER="# added by jarvis installer (claude PATH)" KEYCHAIN_SERVICE="x" CRED_FILE="$H/.claude/.credentials.json" \
    bash -c 'set -u; . "$1"; . "$2"; login_status() { printf "없음"; }; FOUND=0; diagnose; echo "FOUND=$FOUND"' _ "$LIB" "$DG" ) > "$W/out.txt" 2>&1
[ -s "$DG" ] && [ "$(grep -c '끝나지 않은 되옮기기' "$W/out.txt")" = "1" ] && [ "$(sed -n 's/^FOUND=//p' "$W/out.txt")" = "1" ]
t $? "[맥] F5 진단이 끝나지 않은 되옮기기 표지를 찾은 자국으로 센다(다른 자국 0이어도 · 기본 배치에서 한 번만 = FOUND 1 · 윈 짝 · r2 N2)" "$(tail -3 "$W/out.txt" | tr '\n' '|' | cut -c1-300)"
# ── F8 맥 진단 = --keep-app 단독도 purge 와 같은 말(편성 기록만 보관 · 부서 상태·휴지통 제자리) — 윈 진단 짝 ──
W="$BASE/mac-kadg"; H="$W/home"; mkdir -p "$H"; seed_mac "$H"
( cd "$W" && HOME="$H" JARVIS_HOME="$H/install-jarvis" KEEP_HISTORY=0 KEEP_APP=1 CYS_APP="$H/Apps/cysr.app" CYS_APP_OLD="" CYS_CLI="" MODE="" PURGE_LOGIN=0 ASSUME_YES=1 CYS_CRED_FILE="$H/.cys/claude/.credentials.json" \
    AGORA_HOME="$H/.config/agora" AGORA_SKILL="$H/.claude/skills/agora-delegate" AGORA_SKILL_IN_CYS="$H/.cys/claude/skills/agora-delegate" \
    PROFILE_MARKER="# added by jarvis installer (claude PATH)" KEYCHAIN_SERVICE="x" CRED_FILE="$H/.claude/.credentials.json" \
    bash -c 'set -u; . "$1"; . "$2"; login_status() { printf "없음"; }; FOUND=0; diagnose; echo "FOUND=$FOUND"' _ "$LIB" "$DG" ) > "$W/out.txt" 2>&1
grep -q 'cys 실행 상태(지난 편성 기록만 보관합니다)' "$W/out.txt" && grep -q '부서 실행 상태 · .*(제자리에 둡니다' "$W/out.txt" && grep -q '닫은 부서 휴지통 · .*(제자리에 둡니다)' "$W/out.txt" \
  && ! grep -qE '(실행 상태|휴지통)\(보관 폴더로 옮깁니다\)' "$W/out.txt"
t $? "[맥] F8 진단 = 앱 남김 단독도 편성 기록만 보관 · 부서 상태·휴지통 제자리라고 말한다(purge 와 같은 말 · 윈 짝)" "$(grep -E '실행 상태|휴지통' "$W/out.txt" | tr '\n' '|' | cut -c1-400)"
# ── r1 Fable F5 맥 되옮기기가 표지의 ~/.cys 밖 칸(.. · 절대경로)을 되옮기지 않는다(윈 Restore-From 짝) — 손으로 고쳐진 표지 ──
W="$BASE/mac-esc"; H="$W/home"; BK="$H/install-jarvis-backup-20260101-000000"; mkdir -p "$BK/cys-home" "$H/.cys"
printf '%s\n' "$MARK" > "$BK/.jarvis-owned"; printf 'e' > "$BK/escape"; printf 'a' > "$BK/cys-home/ok.json"
printf 'cys-home\0../escape\0%s\0ok.json\0' "$BK/escape" > "$BK/.jarvis-restore-pending"
( cd "$W" && HOME="$H" JARVIS_HOME="$H/install-jarvis" bash -c 'set -u; . "$1"; KEPT_FAIL=0; ARCHIVE_FAIL=0; resume_unfinished_restore; echo "KF=$KEPT_FAIL"' _ "$LIB" ) > "$W/out.txt" 2>&1
[ ! -e "$H/escape" ] && [ -f "$BK/escape" ] && [ -f "$H/.cys/ok.json" ] && [ -f "$BK/.jarvis-restore-pending" ] && ! grep -q '^KF=0$' "$W/out.txt" && grep -q '알아보지 못했습니다' "$W/out.txt"
t $? "[맥] Fable F5 표지의 ~/.cys 밖 칸(.. · 절대경로)은 되옮기지 않는다 · 표지에 남김 · 못 지움 · 나머지 칸은 되옮김" "$(ls -A "$H" | tr '\n' ' ') · $(tail -3 "$W/out.txt" | tr '\n' '|' | cut -c1-300)"
# ── r1 F4(codex F4 · Fable F1 · agy F4 가족) 완전 삭제 보관본 속 로그인 파일 지우기가 그 실행에서 끝내 실패 → **새 실행**이 이어서 지운다
#    (진단이 그것을 찾은 자국으로 센다 · 지우면 표지 치움 · rc 0) — 앞 판은 회차 사이만 이어서, 새 실행은 「지울 것 없음」 · 비밀값이 보관본에 남았다 ──
H="$(LOOPRUN=1 mac_purge cr 0 0 '' 'rm() { case "$*" in *.credentials.json*) return 1 ;; *) command rm "$@" ;; esac; }')"; B="$(bk_of "$H")"
R1="$(rc_of cr)"; NC1="$(find "$B" -name .credentials.json 2>/dev/null | wc -l | tr -d ' ')"
( cd "$BASE/mac-cr" && HOME="$H" JARVIS_HOME="$H/install-jarvis" KEEP_HISTORY=0 KEEP_APP=0 CYS_APP="$H/Apps/cysr.app" CYS_APP_OLD="" CYS_CLI="" MODE="" PURGE_LOGIN=0 ASSUME_YES=1 \
    CYS_CRED_FILE="$H/.cys/claude/.credentials.json" AGORA_HOME="$H/.config/agora" AGORA_SKILL="$H/.claude/skills/agora-delegate" AGORA_SKILL_IN_CYS="$H/.cys/claude/skills/agora-delegate" \
    PROFILE_MARKER="# added by jarvis installer (claude PATH)" KEYCHAIN_SERVICE="x" CRED_FILE="$H/.claude/.credentials.json" \
    bash -c 'set -u; . "$1"; . "$2"; login_status() { printf "없음"; }; FOUND=0; diagnose; echo "FOUND=$FOUND"' _ "$LIB" "$DG" ) > "$BASE/mac-cr/diag.txt" 2>&1
F2N="$(sed -n 's/^FOUND=//p' "$BASE/mac-cr/diag.txt")"
NOSEED=1 mac_purge cr 0 0 >/dev/null
[ "$R1" = "7" ] && [ "$NC1" -ge 1 ] && [ "${F2N:-0}" -ge 1 ] 2>/dev/null && [ "$(rc_of cr)" = "0" ] && [ "$(find "$B" -name .credentials.json | wc -l | tr -d ' ')" = "0" ] \
  && [ -z "$(find "$B" -name '.jarvis-cred-pending')" ] && [ -f "$B/cys-home/claude/projects/-u-install-jarvis/s 1.jsonl" ]
t $? "[맥] F4 보관본 속 로그인 파일 지우기가 끝내 실패한 뒤 새 실행이 이어서 지운다(진단이 셈 · 표지 치움 · 대화 그대로 · rc 0)" \
  "1회 rc=$R1 남은 로그인=$NC1 · 진단 FOUND=$F2N · 2회 rc=$(rc_of cr) 남은 로그인=$(find "$B" -name .credentials.json | wc -l | tr -d ' ') · $(why cr 4)"
# ── r1 agy F4 보관본 속 로그인 파일을 권한으로 못 읽으면 「없음」 으로 넘기지 않는다(못 지움 · 표지 남김 · rc 7) ──
H="$(mac_purge cu 0 0 '' 'eval "orig_dac() $(declare -f drop_archived_credentials | tail -n +2)"; drop_archived_credentials() { chmod 000 "$1"/claude; orig_dac "$@"; }')"; B="$(bk_of "$H")"
chmod 755 "$B/cys-home/claude" 2>/dev/null
[ "$(rc_of cu)" = "7" ] && [ -f "$B/cys-home/.jarvis-cred-pending" ] && [ -f "$B/cys-home/claude/.credentials.json" ] && grep -q '읽지 못했습니다' "$BASE/mac-cu/out.txt"
t $? "[맥] agy F4 보관본 속 로그인 파일을 못 읽으면 못 지움으로 센다(표지 남김 · rc 7)" "rc=$(rc_of cu) · 표지=$([ -f "$B/cys-home/.jarvis-cred-pending" ] && echo 있음 || echo 없음) · $(why cu 4)"
# ── r1 F6(윈 짝) 완전 삭제에서 끄지 못한 cys 가 남으면 이번 회차에는 아무것도 옮기지 않는다(작업 폴더 · ~/.cys · 상태 그대로 · rc 7) · 재설치는 알림만 ──
H="$(mac_purge al 0 0 '' 'stop_cys_processes() { printf "4242 cysd\n"; }')"
[ "$(rc_of al)" = "7" ] && [ "$(nbk "$H")" = "0" ] && [ "$(digest "$H/.cys/claude")" = "$(digest "$REF/.cys/claude")" ] && [ -f "$H/.cys/depts.json" ] && [ -f "$H/install-jarvis/notes/a.txt" ] \
  && [ -f "$H/.local/state/cys/topology.json" ] && [ -d "$H/Apps/cysr.app" ] && grep -q '아직 실행 중이라' "$BASE/mac-al/out.txt" \
  && ! grep -q '잠시 뒤 스스로 한 번 더 해 봅니다' "$BASE/mac-al/out.txt" && grep -q '닫힌 뒤 다시 해 보면 이어서 옮깁니다' "$BASE/mac-al/out.txt"
t $? "[맥] F6 완전 삭제에서 끄지 못한 cys 가 남으면 아무것도 옮기지 않는다(보관본 0 · ~/.cys 그대로 · 앱 그대로 · rc 7 · 윈 짝)" "rc=$(rc_of al) · 보관본 $(nbk "$H") · $(why al 5)"
H="$(mac_purge al2 1 1 '' 'stop_cys_processes() { printf "4242 cysd\n"; }')"
[ "$(rc_of al2)" = "0" ] && [ -f "$H/.cys/depts.json" ] && grep -q '돌고 있는 것이 있습니다' "$BASE/mac-al2/out.txt"
t $? "[맥] F6 재설치(앱 남김)는 끄지 못한 cys 가 있어도 알림만 하고 이어 간다(윈 -KeepApp 짝)" "rc=$(rc_of al2) · $(why al2 4)"
# ── r2 Fable N3 보관된 옛 ~/.cys 자체를 못 들어가면 「없음」 이 아니다 · N4 다 지웠는데 정리 표지를 못 치우면 센다 ──
W="$BASE/mac-n34"; mkdir -p "$W/a/claude" "$W/b/claude"; printf s > "$W/a/claude/.credentials.json"; chmod 000 "$W/a"
printf s > "$W/b/claude/.credentials.json"; : > "$W/b/.jarvis-cred-pending"; chmod 500 "$W/b"
mkdir -p "$W/c/claude-dept-1"; printf s > "$W/c/claude-dept-1/.credentials.json"; : > "$W/c/.jarvis-cred-pending"; chmod 300 "$W/c"   # 들어가기만 되고 목록을 못 읽음(r3 M1)
mkdir -p "$W/d/claude"; printf s > "$W/d/claude/.credentials.json"; chmod 500 "$W/d/claude" "$W/d"   # 표지를 애초에 못 쓰고 지우기도 실패(r3 M3)
( cd "$W" && HOME="$W" JARVIS_HOME="$W/install-jarvis" bash -c 'set -u; . "$1"; KEPT_FAIL=0; drop_archived_credentials "$2"; echo "KA=$KEPT_FAIL"; KEPT_FAIL=0; drop_archived_credentials "$3"; echo "KB=$KEPT_FAIL"; KEPT_FAIL=0; drop_archived_credentials "$4"; echo "KC=$KEPT_FAIL"; echo ===D; drop_archived_credentials "$5"' _ "$LIB" "$W/a" "$W/b" "$W/c" "$W/d" ) > "$W/out.txt" 2>&1
chmod 755 "$W/a" "$W/b" "$W/c" "$W/d" "$W/d/claude"
grep -q '^KA=[1-9]' "$W/out.txt" && grep -q '^KB=[1-9]' "$W/out.txt" && grep -q '^KC=[1-9]' "$W/out.txt" && [ -f "$W/c/.jarvis-cred-pending" ] && [ ! -f "$W/b/claude/.credentials.json" ] && ! grep -q 'Permission denied' "$W/out.txt" \
  && sed -n '/^===D$/,$p' "$W/out.txt" | grep -q '쓰기 권한을 확인해 주십시오' && ! sed -n '/^===D$/,$p' "$W/out.txt" | grep -q '이어서 지웁니다'
t $? "[맥] r2 N3·N4 보관본 자체를 못 들어감 = 못 지움 · 정리 표지를 못 치움 = 못 지움(조용한 rc 0 · 영구 표지 금지) · 권한 오류가 화면에 새지 않음" "$(tr '\n' '|' < "$W/out.txt" | cut -c1-300)"
# ── r2 Fable N6 되옮길 자리의 윗자리(~/.cys/claude)가 바로가기면 따라가지 않는다(밖으로 옮김 금지 · 표지 유지 · 못 지움) ──
W="$BASE/mac-n6"; H="$W/home"; BK="$H/install-jarvis-backup-20260101-000000"; mkdir -p "$BK/cys-home/claude/projects/p" "$H/.cys" "$H/elsewhere"
printf '%s\n' "$MARK" > "$BK/.jarvis-owned"; printf 'x' > "$BK/cys-home/claude/projects/p/s.jsonl"; ln -s "$H/elsewhere" "$H/.cys/claude"
printf 'cys-home\0claude/projects\0' > "$BK/.jarvis-restore-pending"
( cd "$W" && HOME="$H" JARVIS_HOME="$H/install-jarvis" bash -c 'set -u; . "$1"; KEPT_FAIL=0; ARCHIVE_FAIL=0; resume_unfinished_restore; echo "KF=$KEPT_FAIL"' _ "$LIB" ) > "$W/out.txt" 2>&1
[ ! -e "$H/elsewhere/projects" ] && [ -f "$BK/cys-home/claude/projects/p/s.jsonl" ] && [ -f "$BK/.jarvis-restore-pending" ] && ! grep -q '^KF=0$' "$W/out.txt" && grep -q '바로가기라' "$W/out.txt"
t $? "[맥] r2 N6 ~/.cys/claude 가 바로가기면 되옮기기가 따라가지 않는다(밖으로 옮김 0 · 표지 유지 · 못 지움)" "$(ls -A "$H/elsewhere" | tr '\n' ' ') · $(tail -3 "$W/out.txt" | tr '\n' '|' | cut -c1-300)"
# ── r1 F3 남은 목록 표지를 고쳐 쓰다 끊김(반쪽) → 옛 표지가 그대로 남아 다음 실행이 남은 칸을 끝낸다(반쪽 표지로 「할 것 없음」 → 표지 지움 금지) ──
H="$(mac_purge hf 1 1 '' "export PATH=\"$BASE/fp2:\$PATH\""'; cat() { case "${1:-}" in */jarvis-left*) head -c 9 "$1"; return 1 ;; *) command cat "$@" ;; esac; }')"; B="$(bk_of "$H")"
( cd "$BASE/mac-hf" && HOME="$H" JARVIS_HOME="$H/install-jarvis" bash -c 'set -u; . "$1"; KEPT_FAIL=0; ARCHIVE_FAIL=0; resume_unfinished_restore; echo "KF=$KEPT_FAIL"' _ "$LIB" ) > "$BASE/mac-hf/out2.txt" 2>&1
[ "$(rc_of hf)" = "7" ] && [ -f "$H/.cys/depts.json" ] && [ ! -f "$B/.jarvis-restore-pending" ] && grep -q '^KF=0$' "$BASE/mac-hf/out2.txt"
t $? "[맥] F3 표지 고쳐 쓰기가 반쪽에서 끊겨도 옛 표지가 남아 다음 실행이 남은 칸(depts.json)을 끝낸다" "rc=$(rc_of hf) · depts=$([ -f "$H/.cys/depts.json" ] && echo 제자리 || echo 없음) · $(tail -3 "$BASE/mac-hf/out2.txt" | tr '\n' '|')"

# ── ⓗ 손 0(정적) — 사람 입력을 읽는 줄 0 · 묻는 문구 0 · 스스로 다시 해 보기 상한 2 ──
n_tty="$(grep -vE '^\s*#' "$RS" | grep -cE '/dev/tty|read -r (answer|again|_ignored)')"
[ "$n_tty" = "0" ]; t $? "[맥] ⓗ 사람 입력을 읽는 줄 0(Enter·「지웁니다」·다시 해 보기 질문 삭제)" "남은 줄 $n_tty"
! grep -vE '^\s*#' "$RS" | grep -q '라고 입력해 주십시오'; t $? "[맥] ⓗ 「지웁니다」 입력 문구 0" "남음"
grep -qE '^while \[ "\$rc" -ne 0 \] && \[ "\$tries" -lt 2 \]; do$' "$RS"; t $? "[맥] ⓗ 스스로 다시 해 보기 = 최대 2회(사람 조건 없음)" "고리 줄 다름"
grep -q 'sleep "${JARVIS_NOTICE_WAIT:-5}"' "$RS"; t $? "[맥] ⓗ 「끕니다」 알림 뒤 5초(master ⑤)" "없음"
# 다시 해 보기 고리 동작 — 가짜 purge 가 두 번 실패 뒤 성공 / 늘 실패
LOOP="$(awk '/^purge$/{p=1} p{print} /^\[ "\$rc" -ne 0 \] && show_rerun_how$/{exit}' "$RS")"
for want in "2:0:3" "9:7:3"; do
  failn="${want%%:*}"; rest="${want#*:}"; wrc="${rest%%:*}"; wcalls="${rest#*:}"
  out="$(FAILN="$failn" LOOP="$LOOP" bash -c 'n=0; purge() { n=$((n+1)); [ "$n" -gt "$FAILN" ] && return 0; return 7; }; prescan_links() { return 0; }; say() { :; }; show_rerun_how() { :; }; sleep() { :; }; eval "$LOOP"; echo "$rc:$n"' 2>&1)"
  [ "$out" = "$wrc:$wcalls" ]; t $? "[맥] ⓗ 고리 동작(실패 ${failn}번) → rc $wrc · purge ${wcalls}번" "받음 $out"
done
}

run_win() {
echo "== [윈] 실물 reset-clean.ps1 을 pwsh 로 C:\\Users\\emu 흉내(tests/delete-path-win-host.ps1 · 레지스트리 값·바로가기·Stop-Process 가짜) =="
PW="$(command -v pwsh 2>/dev/null)"
if [ -z "$PW" ]; then t 1 "[윈] pwsh 가 있어야 윈 칸을 잰다(건너뜀 ≠ 통과)" "pwsh 없음"; return; fi
WB="$(cd "$BASE" && pwd -P)"   # 윈 흉내는 조상에 바로가기가 없어야 한다(/tmp → /private/tmp · 작업 폴더 안전 관문이 조상 바로가기를 거부)
WHOST="$HERE/delete-path-win-host.ps1"
REG='reg/Software/Microsoft/Windows/CurrentVersion'
SMP='AppData/Roaming/Microsoft/Windows/Start Menu/Programs'
WLOC='C:\Users\emu\AppData\Local\cys'
# 설치가 끝난 윈 기계 흉내 — 프로그램 파일 · 실행 기록 · 부서 상태 · ~\.cys(본부·부서) · 작업 폴더 · 등록(우리 것 + 남의 같은 이름) · 바로가기
win_seed() { # win_seed <샌드박스> [E2: nop|p = 설치 목록 항목을 UninstallString 하나로만(InstallLocation 없음 · /P 없음·있음)]
  local SB="$1" U="$1/C:/Users/emu" L="$1/C:/Users/emu/AppData/Local/cys"
  mkdir -p "$L/runtime/python" "$L/phoenix" "$L/boot-intents" "$L/cys-dept-dept-1" "$U/AppData/Local/Temp" "$U/AppData/Roaming/com.cysjavis.terminal/EBWebView" \
    "$U/AppData/Local/com.cysjavis.terminal" "$U/.cys/pack/memory" "$U/.cys/pack/bin" "$U/.cys/claude/projects/-u-install-jarvis" "$U/.cys/claude/skills/z" \
    "$U/.cys/claude/file-history/f" "$U/.cys/claude/agent-memory" "$U/.cys/claude-default-dept-1/projects/p" "$U/.cys/pack-dept-dept-1/round" "$U/.cys/dept-missions" \
    "$U/.cys/dept-requests/r1" "$U/.cys/dept-snapshots" "$U/.cys/state/formation" "$U/install-jarvis/notes" "$U/.local/bin" "$U/.local/state/cys-trash/dept-9-1" \
    "$U/$SMP/cysr" "$U/Desktop" "$SB/$REG/Explorer/User Shell Folders" "$SB/$REG/Uninstall/cysr" "$SB/$REG/Uninstall/cys" "$SB/$REG/Run" "$SB/reg/Software/cysjavis/cysr" "$SB/reg/Software/cysjavis/cys"
  ln -s "$SB/C:" "$SB/cdrv"
  # 프로그램 파일(P) — 가짜 실행 파일은 불리면 표지를 남긴다(제거 프로그램 실행 0 · 데몬 떼기 기록)
  printf '#!/bin/sh\necho ran >> "%s/uninstall-ran"\nexit 0\n' "$SB" > "$L/uninstall.exe"
  printf '#!/bin/sh\necho "$*" >> "%s/cys-calls.log"\nexit 0\n' "$SB" > "$L/cys.exe"; chmod +x "$L/uninstall.exe" "$L/cys.exe"
  for f in cysd.exe cys-app.exe cysr.exe WebView2Loader.dll cys.exe.prev4711 pack.tar.gz pack-manifest.json runtime-manifest.json cys-installed-version.txt jarvis-cys-pin.json; do printf 'p' > "$L/$f"; done
  printf 'rt' > "$L/runtime/python/x.dll"
  # 실행 기록 · 부서 상태 · 모르는 이름(D)
  printf '{}' > "$L/topology.json"; printf 'c' > "$L/topology.json.corrupt-1"; printf 'r' > "$L/phoenix/dept_roster.json"; printf 'i' > "$L/boot-intents/1"
  printf '[]' > "$L/dept_tombstones.json"; printf 'db' > "$L/transcripts.db"; printf 'f' > "$L/feed.jsonl"; printf 'u' > "$L/unknown-thing.dat"
  printf '{}' > "$L/cys-dept-dept-1/topology.json"; printf 'db' > "$L/cys-dept-dept-1/transcripts.db"
  # ~\.cys
  printf 'mem' > "$U/.cys/pack/memory/MEMORY.md"; printf 'bin' > "$U/.cys/pack/bin/cys-dept"
  printf '{"t":1}\n' > "$U/.cys/claude/projects/-u-install-jarvis/s 1.jsonl"; printf 'h\n' > "$U/.cys/claude/history.jsonl"; printf 'f' > "$U/.cys/claude/file-history/f/1"
  printf 'm' > "$U/.cys/claude/agent-memory/m.md"; printf '{"claudeAiOauth":{"accessToken":"fake"}}' > "$U/.cys/claude/.credentials.json"
  printf 'router' > "$U/.cys/claude/CLAUDE.md"; printf '{}' > "$U/.cys/claude/settings.json"; printf 'k' > "$U/.cys/claude/skills/z/SKILL.md"
  printf '{"hasCompletedOnboarding":true}' > "$U/.cys/claude-default-dept-1/.claude.json"; printf 'd' > "$U/.cys/claude-default-dept-1/projects/p/x.jsonl"
  printf '{"claudeAiOauth":{"accessToken":"fake-dept"}}' > "$U/.cys/claude-default-dept-1/.credentials.json"
  printf '{"depts":{}}' > "$U/.cys/depts.json"; printf '{}' > "$U/.cys/dept-catalog.json"; printf 'm' > "$U/.cys/dept-missions/c1.md"
  printf '{}' > "$U/.cys/dept-requests/r1/request.json"; printf 's' > "$U/.cys/dept-snapshots/s.tar.gz"; printf -- '- [ ] 부서 할 일\n' > "$U/.cys/pack-dept-dept-1/round/WORKER_TODO.md"
  printf 'f' > "$U/.cys/state/formation/k.json"; printf 'log' > "$U/.cys/dept-launch-path.log"
  # 작업 폴더 · 클로드 실행 파일 · 받아 둔 설치 스크립트 · 휴지통 · 앱 화면 자료
  printf '%s\n' "$MARK" > "$U/install-jarvis/.jarvis-owned"; printf '내 메모\n' > "$U/install-jarvis/notes/a.txt"; printf 'log\n' > "$U/install-jarvis/bootstrap.log"
  printf 'exe' > "$U/.local/bin/claude.exe"; printf '# old copy' > "$U/install-jarvis.ps1"; printf 't' > "$U/.local/state/cys-trash/dept-9-1/x"
  printf 'w' > "$U/AppData/Roaming/com.cysjavis.terminal/EBWebView/x"; printf 'y' > "$U/AppData/Local/com.cysjavis.terminal/y"
  # 바로가기 — 우리 것(대상 = 우리 설치 자리) · 남의 것 · 대상을 못 읽는 것
  printf '%s\\cys-app.exe' "$WLOC" > "$U/$SMP/cysr.lnk"; printf '%s\\cys-app.exe' "$WLOC" > "$U/$SMP/cysr/cysr.lnk"; printf 'C:\\Other\\cys\\cys.exe' > "$U/$SMP/cys.lnk"
  printf '%s\\cys-app.exe' "$WLOC" > "$U/Desktop/cysr.lnk"; printf 'UNREADABLE' > "$U/Desktop/cys.lnk"
  printf '%%USERPROFILE%%\\Desktop' > "$SB/$REG/Explorer/User Shell Folders/Desktop.regval"   # 셸 폴더 기록(바탕화면 자리)
  # 등록 — 우리 cysr 항목 · 남의 같은 이름 cys 항목(다른 자리) · 설치 위치 기록 · 자동 실행 값
  case "${2:-}" in
    nop) printf '"%s\\uninstall.exe"' "$WLOC" > "$SB/$REG/Uninstall/cysr/UninstallString.regval" ;;
    p)   printf '"%s\\uninstall.exe" /P' "$WLOC" > "$SB/$REG/Uninstall/cysr/UninstallString.regval" ;;
    *)   printf '"%s"' "$WLOC" > "$SB/$REG/Uninstall/cysr/InstallLocation.regval"; printf '"%s\\uninstall.exe" /P' "$WLOC" > "$SB/$REG/Uninstall/cysr/UninstallString.regval" ;;
  esac
  printf 'cysr' > "$SB/$REG/Uninstall/cysr/DisplayName.regval"
  printf '"D:\\Apps\\cys"' > "$SB/$REG/Uninstall/cys/InstallLocation.regval"; printf '"D:\\Apps\\cys\\uninstall.exe"' > "$SB/$REG/Uninstall/cys/UninstallString.regval"
  printf '%s' "$WLOC" > "$SB/reg/Software/cysjavis/cysr/(default).regval"; printf 'D:\\Apps\\cys' > "$SB/reg/Software/cysjavis/cys/(default).regval"
  printf '"%s\\cys-app.exe" --autostart' "$WLOC" > "$SB/$REG/Run/cysr.regval"; printf 'C:\\Other\\cys.exe' > "$SB/$REG/Run/cys.regval"
}
# win_run <이름> <스위치(쉼표)> [준비 셸(U 에서)] [스크립트 덧붙임 파일(본문 앞에 끼움)] [E2 씨앗] → 샌드박스 경로 · 출력 out.txt · rc.txt
win_prep() { # win_prep <이름> [준비 셸] [덧붙임 파일] [E2] → 샌드박스(씨앗 · 지우개 사본까지)
  local SB="$WB/win-$1"
  mkdir -p "$SB"; win_seed "$SB" "${4:-}"
  [ -n "${2:-}" ] && ( cd "$SB/C:/Users/emu" && eval "$2" )
  if [ -n "${3:-}" ]; then awk -v f="$3" '/^# ── 본문 ──/{while((getline l < f) > 0) print l} {print}' "$RP" > "$SB/reset-clean.ps1"
  else cp "$RP" "$SB/reset-clean.ps1"; fi
  printf '%s' "$SB"
}
win_go() { # win_go <샌드박스> <스위치> [출력 이름] [AGORA_HOME]
  local SB="$1" o="${3:-out}"
  ( cd "$SB" && env USERPROFILE='C:\Users\emu' LOCALAPPDATA='C:\Users\emu\AppData\Local' APPDATA='C:\Users\emu\AppData\Roaming' TEMP='C:\Users\emu\AppData\Local\Temp' \
      HOME="$SB/childhome" JARVIS_BASE_URL='http://127.0.0.1:9/emu' JARVIS_NOTICE_WAIT=0 JARVIS_RETRY_WAIT=0 JARVIS_NO_PROGRESS=1 ${4:+AGORA_HOME="$4"} \
      perl -e 'alarm shift; exec @ARGV' 1500 "$PW" -NoProfile -NonInteractive -File "$WHOST" -Target "$SB/reset-clean.ps1" -Log "$SB/readhost.log" -Switches "$2" -Sb "$SB" \
      </dev/null > "$SB/$o.txt" 2>&1; echo $? > "$SB/$o.rc" )
}
wrc() { cat "$WB/win-$1/${2:-out}.rc" 2>/dev/null; }
wwhy() { tail -${2:-5} "$WB/win-$1/out.txt" 2>/dev/null | tr '\n' '|' | cut -c1-500; }
wbk() { find "$WB/win-$1/C:/Users/emu" -mindepth 1 -maxdepth 1 -name 'install-jarvis-backup-*' 2>/dev/null | LC_ALL=C sort | head -1; }
wnbk() { find "$WB/win-$1/C:/Users/emu" -mindepth 1 -maxdepth 1 -name 'install-jarvis-backup-*' 2>/dev/null | wc -l | tr -d ' '; }
WPATCH="$WB/patch"; mkdir -p "$WPATCH"
# 덧붙임(시험 전용 · 사본에만 · 실물 무접촉) — 맥 칸이 함수를 덮어 쓰는 것과 같은 자리
cat > "$WPATCH/stat.ps1" <<'P'
${function:Get-TreeStatOrig} = ${function:Get-TreeStat}
$script:TsN = 0
function Get-TreeStat($p) { $script:TsN++; if ($script:TsN -ge 2) { return '9 9' }; return (Get-TreeStatOrig $p) }
P
cat > "$WPATCH/stat2.ps1" <<'P'
${function:Get-TreeStatOrig} = ${function:Get-TreeStat}
function Get-TreeStat($p) { if ([string]$p -like '*cys-home*') { return '0 0' }; return (Get-TreeStatOrig $p) }
P
cat > "$WPATCH/vol.ps1" <<'P'
function Get-VolumeRoot($p) { if ([string]$p -like '*install-jarvis-backup-*') { return 'X:\' }; return 'C:\' }
P
cat > "$WPATCH/die.ps1" <<'P'
${function:Move-OneEntryOrig} = ${function:Move-OneEntry}
$script:MvN = 0
function Move-OneEntry($src, $dst) { $script:MvN++; if ($script:MvN -ge 4) { [Environment]::Exit(9) }; Move-OneEntryOrig $src $dst }
P
cat > "$WPATCH/onefail.ps1" <<'P'
${function:Move-OneEntryOrig} = ${function:Move-OneEntry}
function Move-OneEntry($src, $dst) { if ([string]$dst -like '*depts.json') { throw 'emu: locked' }; Move-OneEntryOrig $src $dst }
P
cat > "$WPATCH/cred1.ps1" <<'P'
${function:Remove-ArchivedCredentialsOrig} = ${function:Remove-ArchivedCredentials}
$script:RcN = 0
function Remove-ArchivedCredentials($h) { $script:RcN++; if ($script:RcN -eq 1) { $script:KeptFail++; Write-Host '  (시험) 보관본 속 로그인 파일 지우기 실패 흉내'; return }; Remove-ArchivedCredentialsOrig $h }
P
cat > "$WPATCH/pcf.ps1" <<'P'
${function:Initialize-PreserveCanonOrig} = ${function:Initialize-PreserveCanon}
function Initialize-PreserveCanon { Initialize-PreserveCanonOrig; $script:PreserveCanonFail += @{ path = 'C:\Users\emu\.config\agora'; why = '(시험) 흉내' } }
P
cat > "$WPATCH/trust1.ps1" <<'P'
${function:Read-TrustSeedRecordOrig} = ${function:Read-TrustSeedRecord}
$script:TrN = 0
function Read-TrustSeedRecord { $script:TrN++; if ($script:TrN -eq 1) { $script:TrustCleanupFail++; Write-Host '  (시험) 신뢰 기록 읽기 실패 흉내'; return @() }; return (Read-TrustSeedRecordOrig) }
P
cat > "$WPATCH/trust9.ps1" <<'P'
function Read-TrustSeedRecord { $script:TrustCleanupFail++; return @() }
P
cat > "$WPATCH/credro.ps1" <<'P'
${function:Remove-ArchivedCredentialsOrig} = ${function:Remove-ArchivedCredentials}
function Remove-ArchivedCredentials($h) {
    foreach ($d in @(Get-ChildItem -LiteralPath $h -Force -Directory -ErrorAction SilentlyContinue | Where-Object { $_.Name -like 'claude*' })) { & chmod 555 $d.FullName }
    Remove-ArchivedCredentialsOrig $h
}
P
cat > "$WPATCH/credun.ps1" <<'P'
${function:Remove-ArchivedCredentialsOrig} = ${function:Remove-ArchivedCredentials}
function Remove-ArchivedCredentials($h) {
    foreach ($d in @(Get-ChildItem -LiteralPath $h -Force -Directory -ErrorAction SilentlyContinue | Where-Object { $_.Name -eq 'claude' })) { & chmod 000 $d.FullName }
    Remove-ArchivedCredentialsOrig $h
}
P
cat > "$WPATCH/alive.ps1" <<'P'
function Stop-CysProcesses { return @([pscustomobject]@{ ProcessName = 'cysd'; Id = 4242; Path = 'C:\Users\emu\AppData\Local\cys\cysd.exe' }) }
P
cat > "$WPATCH/onefail-nores.ps1" <<'P'
${function:Move-OneEntryOrig} = ${function:Move-OneEntry}
function Move-OneEntry($src, $dst) { if ([string]$dst -like '*depts.json') { throw 'emu: locked' }; Move-OneEntryOrig $src $dst }
function Resume-UnfinishedRestore { $script:ResumeLeft = $false }
P
cat > "$WPATCH/halfmark.ps1" <<'P'
${function:Move-OneEntryOrig} = ${function:Move-OneEntry}
function Move-OneEntry($src, $dst) { if ([string]$dst -like '*depts.json') { throw 'emu: locked' }; Move-OneEntryOrig $src $dst }
${function:Write-RestoreMarkOrig} = ${function:Write-RestoreMark}
$script:WmN = 0
function Write-RestoreMark($mark, $recs) { $script:WmN++; if ($script:WmN -eq 1) { Write-RestoreMarkOrig $mark $recs; return }
    [System.IO.File]::WriteAllText($mark, ([string]@($recs)[0] + [char]0), (New-Object System.Text.UTF8Encoding($false))); throw 'emu: disk full' }
P
REF="$WB/win-ref"; mkdir -p "$REF"; win_seed "$REF"; RU="$REF/C:/Users/emu"

# 모든 칸을 먼저 띄운다(서로 다른 샌드박스 · 병렬 4) — 흉내 한 번이 수십 초라 차례로 돌리면 너무 길다
SBa="$(win_prep a)"; SBb="$(win_prep b)"; SBc="$(win_prep c 'chmod 555 .')"; SBd="$(win_prep d '' "$WPATCH/stat.ps1")"
SBd2="$(win_prep d2 '' "$WPATCH/stat2.ps1")"; SBe="$(win_prep e '' "$WPATCH/vol.ps1")"; SBf="$(win_prep f '' "$WPATCH/die.ps1")"; SBg="$(win_prep g '' "$WPATCH/onefail.ps1")"
SBp1="$(win_prep p1 'mkdir -p .cys/pack/talk && printf talk > .cys/pack/talk/s.jsonl && ln -s "$PWD/.cys/pack/talk" .cys/claude/projects/lnk')"
SBp2="$(win_prep p2 'printf keep > AppData/Local/cys/runtime/x && ln -s "$PWD/AppData/Local/cys/runtime/x" .cys/claude/projects/lnk')"
SBp3="$(win_prep p3 'ln -s "$PWD/.cys/claude/history.jsonl" "$PWD/.cys/claude/projects/a
b"')"
SBp4="$(win_prep p4 'mkdir -p .cys/pack/locked && printf s > .cys/pack/locked/x && chmod 000 .cys/pack/locked')"
SBp5="$(win_prep p5 'rm -rf .cys/pack && mkdir -p .cys/claude/projects/p && printf k > .cys/claude/projects/p/k.jsonl && ln -s "$PWD/.cys/claude/projects/p" .cys/pack')"
SBq="$(win_prep q 'mv .cys/claude ./prof-real && ln -s "$PWD/prof-real" .cys/claude')"
AGF='mkdir -p .cys/forum && printf key > .cys/forum/key'
SBx1="$(win_prep x1 "$AGF")"
SBx2="$(win_prep x2 "$AGF"' && mkdir -p .cys/pack/talk && printf talk > .cys/pack/talk/s.jsonl && ln -s "$PWD/.cys/pack/talk" .cys/claude/projects/lnk')"
SBx5="$(win_prep x5 "$AGF"' && rm -rf .cys/pack && mkdir -p .cys/claude/projects/p && printf k > .cys/claude/projects/p/k.jsonl && ln -s "$PWD/.cys/claude/projects/p" .cys/pack')"
SBn="$(win_prep e2n '' '' nop)"; SBy="$(win_prep e2p '' '' p)"
SBcr="$(win_prep cr '' "$WPATCH/credro.ps1")"; SBg2="$(win_prep g2 '' "$WPATCH/onefail-nores.ps1")"; SBal="$(win_prep al '' "$WPATCH/alive.ps1")"; SBal2="$(win_prep al2 '' "$WPATCH/alive.ps1")"; SBx1f="$(win_prep x1f 'L=AppData/Local/cys; printf mine > $L/my-tool.exe; printf d > $L/helper.dll; printf r > $L/other.exe.prev3; printf n > $L/cys-app.new.exe; printf t > $L/cysd.prev123456.exe; printf s > $L/cys.exe.prev77; printf w > $L/WebView2Loader.dll.prev5')"; SBc0="$WB/win-c0"; mkdir -p "$SBc0/C:/Users/emu/install-jarvis-backup-20260101-000000/cys-home/claude" "$SBc0/C:/Users/emu/AppData/Local/Temp" "$SBc0/reg"   # 보관본 하나뿐인 기계(다른 자국 0)
ln -s "$SBc0/C:" "$SBc0/cdrv"; cp "$RP" "$SBc0/reset-clean.ps1"
( B0="$SBc0/C:/Users/emu/install-jarvis-backup-20260101-000000"; printf '%s\n' "$MARK" > "$B0/.jarvis-owned"; : > "$B0/cys-home/.jarvis-cred-pending"
  printf '{"claudeAiOauth":{"accessToken":"fake"}}' > "$B0/cys-home/claude/.credentials.json"; printf 'h\n' > "$B0/cys-home/claude/history.jsonl" )
SBcu="$(win_prep cu '' "$WPATCH/credun.ps1")"; SBov="$(win_prep ov '' "$WPATCH/die.ps1")"; SBhf="$(win_prep hf '' "$WPATCH/halfmark.ps1")"
SBka="$(win_prep ka)"   # F8 -KeepApp 단독
SBrb="$(win_prep rb '' "$WPATCH/cred1.ps1")"; SBra="$(win_prep ra '' "$WPATCH/pcf.ps1")"; SBrc="$(win_prep rc '' "$WPATCH/trust1.ps1")"; SBrc2="$(win_prep rc2 '' "$WPATCH/trust9.ps1")"
AGX='C:\Users\emu\.cys\forum'
win_chain() { # win_chain <샌드박스> — 첫 실행(덧붙임 사본) → 중간 상태 기록 → 실물 사본으로 다시 실행(재설치 한 줄을 다시 붙여 넣은 흉내)
  local SB="$1" b
  win_go "$SB" 'KeepApp,KeepHistory,Yes'
  b="$(find "$SB/C:/Users/emu" -mindepth 1 -maxdepth 1 -name 'install-jarvis-backup-*' | LC_ALL=C sort | head -1)"
  { [ -f "$b/.jarvis-restore-pending" ] && echo MARK; ls -A "$SB/C:/Users/emu/.cys" 2>/dev/null; } > "$SB/mid.txt"
  cp "$RP" "$SB/reset-clean.ps1"
  win_go "$SB" 'KeepApp,KeepHistory,Yes' out2
}
win_chain_ov() { # win_chain_ov <샌드박스> — 끊긴 재설치 → 보관본에만 있는 한 이름으로 새 자료가 생김(앱이 만든 흉내) → 실물 사본으로 다시 실행
  local SB="$1" U="$1/C:/Users/emu" b hn ov="" r
  win_go "$SB" 'KeepApp,KeepHistory,Yes'
  b="$(find "$U" -mindepth 1 -maxdepth 1 -name 'install-jarvis-backup-*' | LC_ALL=C sort | head -1)"
  hn="$(tr '\0' '\n' < "$b/.jarvis-restore-pending" 2>/dev/null | head -1)"
  while IFS= read -r r; do r="${r//\\//}"; [ -n "$r" ] && [ -n "$hn" ] && { [ -e "$b/$hn/$r" ] || [ -L "$b/$hn/$r" ]; } && { ov="$r"; break; }; done <<OVL
$(tr '\0' '\n' < "$b/.jarvis-restore-pending" 2>/dev/null | tail -n +2)
OVL
  printf '%s' "$ov" > "$SB/ov.txt"; printf '%s' "$hn" > "$SB/hn.txt"
  if [ -n "$ov" ]; then
    if [ -d "$b/$hn/$ov" ]; then digest "$b/$hn/$ov" > "$SB/ovold.txt"; mkdir -p "$U/.cys/$ov"; printf new > "$U/.cys/$ov/new-after-cut"
    else shasum -a 256 < "$b/$hn/$ov" > "$SB/ovold.txt"; mkdir -p "$(dirname "$U/.cys/$ov")"; printf new > "$U/.cys/$ov"; fi
  fi
  cp "$RP" "$SB/reset-clean.ps1"
  win_go "$SB" 'KeepApp,KeepHistory,Yes' out2
}
win_chain_cr() { # win_chain_cr <샌드박스> — 완전 삭제(보관본 속 로그인 파일 지우기가 그 실행에서 끝내 실패) → 권한 되돌림 → 실물 사본으로 새 실행
  local SB="$1"
  win_go "$SB" 'Yes'
  find "$SB/C:/Users/emu" -mindepth 2 -maxdepth 3 -path '*install-jarvis-backup-*' -type d -exec chmod u+w {} + 2>/dev/null
  find "$SB/C:/Users/emu" -path '*install-jarvis-backup-*' -name .credentials.json > "$SB/cred-mid.txt" 2>/dev/null
  cp "$RP" "$SB/reset-clean.ps1"
  win_go "$SB" 'Yes' out2
}
jobs_run() { # 네 개씩
  local n=0 spec
  for spec in "$@"; do
    ( eval "$spec" ) &
    n=$((n+1)); [ $((n % 4)) -eq 0 ] && wait
  done
  wait
}
jobs_run "win_go '$SBa' ''" "win_go '$SBb' 'KeepApp,KeepHistory,Yes'" "win_go '$SBc' 'Yes'" "win_go '$SBd' 'Yes'" \
  "win_go '$SBd2' 'Yes'" "win_go '$SBe' 'Yes'" "win_chain '$SBf'" "win_chain '$SBg'" \
  "win_go '$SBp1' 'KeepApp,KeepHistory,Yes'" "win_go '$SBp2' 'Yes'" "win_go '$SBp3' 'KeepApp,KeepHistory,Yes'" "win_go '$SBp4' 'KeepApp,KeepHistory,Yes'" \
  "win_go '$SBp5' 'KeepApp,KeepHistory,Yes'" "win_go '$SBq' 'KeepApp,KeepHistory,Yes'" "win_go '$SBx1' 'KeepApp,KeepHistory,Yes' out '$AGX'" "win_go '$SBx2' 'KeepApp,KeepHistory,Yes' out '$AGX'" \
  "win_go '$SBx5' 'KeepApp,KeepHistory,Yes' out '$AGX'" "win_go '$SBn' 'Yes'" "win_go '$SBy' 'Yes'" \
  "win_go '$SBrb' 'Yes'" "win_go '$SBra' 'Yes'" "win_go '$SBrc' 'Yes'" "win_go '$SBrc2' 'Yes'" \
  "win_chain_ov '$SBov'" "win_chain '$SBhf'" "win_chain_cr '$SBcr'" "win_go '$SBg2' 'KeepApp,KeepHistory,Yes'" "win_go '$SBal' 'Yes'" "win_go '$SBal2' 'KeepApp,KeepHistory,Yes'" "win_go '$SBx1f' 'Yes'" "win_go '$SBc0' 'Yes'" "win_go '$SBcu' 'Yes'" "win_go '$SBka' 'KeepApp,Yes'"
chmod 755 "$SBc/C:/Users/emu" 2>/dev/null; chmod 755 "$SBp4/C:/Users/emu/.cys/pack/locked" 2>/dev/null

# ── ⓐ 완전 삭제(스위치 없음 · 입력 닫힘) = 손 0 · 자료는 보관 폴더 한 곳 · 프로그램 파일만 지움 ──
U="$SBa/C:/Users/emu"; B="$(wbk a)"
[ "$(wrc a)" = "0" ] && [ "$(wnbk a)" = "1" ] && [ -f "$B/notes/a.txt" ] && [ ! -e "$U/install-jarvis" ] && [ ! -e "$SBa/readhost.log" ]
t $? "[윈] ⓐ 완전 삭제 rc 0 · 묻는 줄 0(입력 닫힘) · 보관 폴더 1개 · 작업 폴더 자료가 그 안에" "rc=$(wrc a) 보관본 $(wnbk a) 물음=$(cat "$SBa/readhost.log" 2>/dev/null | head -2 | tr '\n' '|') · $(wwhy a)"
[ "$(digest "$B/cys-home/claude/projects")" = "$(digest "$RU/.cys/claude/projects")" ] && [ -f "$B/cys-home/pack/memory/MEMORY.md" ] && [ -f "$B/cys-home/pack-dept-dept-1/round/WORKER_TODO.md" ] \
  && [ -f "$B/cys-home/depts.json" ] && [ -f "$B/cys-home/claude-default-dept-1/projects/p/x.jsonl" ] && [ ! -e "$U/.cys" ]
t $? "[윈] ⓐ 옛 ~\\.cys 통째로 보관(cys-home · 대화 지문 같음 · 팩 기억 · 부서 할 일 · 부서 좌석 대화) · 원자리 비움" "$(ls -A "$B" 2>/dev/null | tr '\n' ' ')"
[ ! -e "$B/cys-home/claude/.credentials.json" ] && [ ! -e "$B/cys-home/claude-default-dept-1/.credentials.json" ] && grep -q '보관본 속 자비스 창 로그인 파일' "$SBa/out.txt"
t $? "[윈] ⓐ 보관본에서 로그인 파일(본부·부서)만 빼고 지운다(결정 3)" "$(find "$B" -name .credentials.json 2>/dev/null | head -2 | tr '\n' ' ')"
S="$B/cys-app-state"
[ -f "$S/topology.json" ] && [ -f "$S/topology.json.corrupt-1" ] && [ -f "$S/phoenix/dept_roster.json" ] && [ -f "$S/boot-intents/1" ] && [ -f "$S/transcripts.db" ] \
  && [ -f "$S/unknown-thing.dat" ] && [ -f "$B/cys-trash/dept-9-1/x" ] && [ ! -e "$U/.local/state/cys-trash" ]
t $? "[윈] ⓐ 프로그램 폴더 안 실행 기록·모르는 이름 = cys-app-state · 휴지통 = cys-trash(보관)" "$(ls -A "$S" 2>/dev/null | tr '\n' ' ')"
[ -f "$B/cys-dept-state/cys-dept-dept-1/transcripts.db" ] && [ -f "$B/cys-dept-state/cys-dept-dept-1/topology.json" ] && [ ! -e "$S/cys-dept-dept-1" ]
t $? "[윈] ⓐ 부서 실행 상태 = cys-dept-state\\cys-dept-<n>(맥과 같은 보관 모양 · 결정⑴)" "$(ls -A "$B" 2>/dev/null | tr '\n' ' ')"
[ -f "$B/webview-appdata/EBWebView/x" ] && [ -f "$B/webview-localappdata/y" ] && [ ! -e "$U/AppData/Roaming/com.cysjavis.terminal" ] && [ ! -e "$U/AppData/Local/com.cysjavis.terminal" ]
t $? "[윈] ⓐ 앱 화면 자료(웹뷰 두 자리) = 보관(결정 7)" "$(ls -A "$B" 2>/dev/null | tr '\n' ' ')"
[ ! -e "$U/AppData/Local/cys" ] && [ ! -e "$U/.local/bin/claude.exe" ] && [ ! -e "$U/install-jarvis.ps1" ]
t $? "[윈] ⓐ 프로그램 파일(설치 폴더 · 클로드 실행 파일 · 설치 스크립트 사본)은 지우고 빈 설치 폴더도 치운다" "$(ls -A "$U/AppData/Local/cys" 2>/dev/null | tr '\n' ' ') · $(wwhy a)"
grep -q '폴더에 모두 보관해 두었습니다 (' "$SBa/out.txt" && grep -q '필요 없으시면' "$SBa/out.txt"
t $? "[윈] ⓐ 끝 요약에 보관 폴더 자리·크기 1줄(쉬운 말)" "$(wwhy a 3)"
# 윈만: 프로그램 걷기 — 우리 것만(남의 같은 이름 무접촉) · 제거 프로그램 실행 0
[ ! -e "$SBa/$REG/Uninstall/cysr" ] && [ -f "$SBa/$REG/Uninstall/cys/InstallLocation.regval" ] && [ ! -e "$SBa/reg/Software/cysjavis/cysr" ] && [ -d "$SBa/reg/Software/cysjavis/cys" ] \
  && [ ! -e "$SBa/$REG/Run/cysr.regval" ] && [ -f "$SBa/$REG/Run/cys.regval" ]
t $? "[윈] ⓐ 설치 목록 Uninstall\\cysr · 설치 위치 기록 · 자동 실행 값 = 우리 것만 지움 · 남의 같은 이름(Uninstall\\cys → D:\\) 무접촉" "$(find "$SBa/reg" -mindepth 1 | sed "s|$SBa/||" | tr '\n' ' ' | cut -c1-400)"
[ ! -e "$U/$SMP/cysr.lnk" ] && [ ! -e "$U/$SMP/cysr" ] && [ -f "$U/$SMP/cys.lnk" ] && [ ! -e "$U/Desktop/cysr.lnk" ] && [ -f "$U/Desktop/cys.lnk" ] \
  && grep -q '가리키는 곳을 확인하지 못해 그대로 두었습니다(모르면 남깁니다)' "$SBa/out.txt"
t $? "[윈] ⓐ 바로가기 = 우리 설치 자리를 가리키는 cysr.lnk(시작 메뉴·폴더·바탕화면)만 지움 · 남의 cys.lnk 남김 · 대상을 못 읽으면 남김" "$(ls -A "$U/$SMP" "$U/Desktop" 2>/dev/null | tr '\n' ' ')"
[ ! -e "$SBa/uninstall-ran" ] && [ -f "$SBa/cys-calls.log" ]
t $? "[윈] ⓐ 제거 프로그램(uninstall.exe)은 한 번도 실행되지 않는다(가짜가 남기는 실행 표지 0 · 같은 자리 cys.exe 는 불림 = 가짜가 살아 있음)" "표지=$(cat "$SBa/uninstall-ran" 2>/dev/null) · cys 불림=$(cat "$SBa/cys-calls.log" 2>/dev/null | head -1)"

# ── ⓑ 재설치 = 통째 보관 → 남길 것만 되옮김(부서 보존) ──
U="$SBb/C:/Users/emu"; B="$(wbk b)"
[ "$(wrc b)" = "0" ] && [ "$(digest "$U/.cys/claude/projects")" = "$(digest "$RU/.cys/claude/projects")" ] && [ -f "$U/.cys/claude/.credentials.json" ] && [ -f "$U/.cys/claude/history.jsonl" ] \
  && [ -f "$U/.cys/claude/file-history/f/1" ] && [ -f "$U/.cys/claude/agent-memory/m.md" ] && [ ! -e "$U/.cys/claude/CLAUDE.md" ] && [ ! -e "$U/.cys/claude/settings.json" ]
t $? "[윈] ⓑ 재설치 = 본부 로그인·대화 5 제자리(바이트 같음) · CLAUDE.md·settings.json 은 새로(보관본으로)" "rc=$(wrc b) · $(wwhy b)"
[ "$(digest "$U/.cys/claude-default-dept-1")" = "$(digest "$RU/.cys/claude-default-dept-1")" ] && [ -f "$U/.cys/depts.json" ] && [ -f "$U/.cys/dept-catalog.json" ] && [ -f "$U/.cys/dept-missions/c1.md" ] \
  && [ -f "$U/.cys/dept-requests/r1/request.json" ] && [ -f "$U/.cys/dept-snapshots/s.tar.gz" ] && [ -f "$U/.cys/pack-dept-dept-1/round/WORKER_TODO.md" ]
t $? "[윈] ⓑ 부서 등록부·카탈로그·임무·요청·스냅샷·부서 팩(할 일)·부서 좌석 프로필(통째 · 로그인 포함) 제자리" "$(ls -A "$U/.cys" 2>/dev/null | tr '\n' ' ')"
[ ! -e "$U/.cys/pack" ] && [ ! -e "$U/.cys/state" ] && [ ! -e "$U/.cys/dept-launch-path.log" ] && [ -f "$B/cys-home/pack/memory/MEMORY.md" ] && [ -f "$B/cys-home/claude/CLAUDE.md" ] && [ ! -e "$B/.jarvis-restore-pending" ]
t $? "[윈] ⓑ 새 ~\\.cys 에 팩 없음(병합 대기 0) · 나머지는 보관본에(팩 기억 포함) · 되옮기기 표지 치움" "$(ls -A "$B/cys-home" 2>/dev/null | tr '\n' ' ')"
L="$U/AppData/Local/cys"
[ -f "$B/cys-state/topology.json" ] && [ -f "$B/cys-state/dept_tombstones.json" ] && [ -e "$B/cys-state/phoenix" ] && [ -e "$B/cys-state/boot-intents" ] && [ -f "$B/cys-state/topology.json.corrupt-1" ] \
  && [ -f "$L/transcripts.db" ] && [ -f "$L/cys-dept-dept-1/topology.json" ] && [ -f "$U/.local/state/cys-trash/dept-9-1/x" ] && [ ! -e "$L/topology.json" ]
t $? "[윈] ⓑ 재설치 = 지난 편성 기록 4종만 보관(지우지 않음) · 검색 기록·부서 상태(cys-dept-<n>)·휴지통 제자리" "$(ls -A "$L" 2>/dev/null | tr '\n' ' ')"
[ -f "$L/cys-app.exe" ] && [ -f "$L/runtime/python/x.dll" ] && [ -d "$SBb/$REG/Uninstall/cysr" ] && [ -f "$U/$SMP/cysr.lnk" ] && [ -d "$U/AppData/Roaming/com.cysjavis.terminal" ] && [ ! -e "$U/.local/bin/claude.exe" ]
t $? "[윈] ⓑ 재설치 = 프로그램·설치 목록·바로가기·앱 화면 자료 남김 · 클로드 실행 파일은 지움(다시 받음 · 종전)" "$(wwhy b)"

# ── F8 -KeepApp 단독(-KeepHistory 없음) = 편성 기록만 보관 · 나머지·부서 상태·휴지통·앱 화면 자료 제자리 — 진단도 같은 말(휴지통 줄이 purge 와 어긋났다) ──
U="$SBka/C:/Users/emu"; B="$(wbk ka)"; L="$U/AppData/Local/cys"
[ "$(wrc ka)" = "0" ] && [ -f "$B/cys-state/topology.json" ] && [ -f "$B/cys-state/dept_tombstones.json" ] && [ -e "$B/cys-state/phoenix" ] && [ -e "$B/cys-state/boot-intents" ] \
  && [ -f "$B/cys-state/topology.json.corrupt-1" ] && [ ! -e "$L/topology.json" ] && [ -f "$L/transcripts.db" ] && [ -f "$L/cys-dept-dept-1/topology.json" ] \
  && [ -f "$U/.local/state/cys-trash/dept-9-1/x" ] && [ -f "$L/cys-app.exe" ] && [ -d "$U/AppData/Roaming/com.cysjavis.terminal" ] && [ ! -e "$B/cys-trash" ]
t $? "[윈] F8 -KeepApp 단독 = 편성 기록만 보관 · 검색 기록·부서 상태·휴지통·프로그램·앱 화면 자료 제자리(맥 짝)" "rc=$(wrc ka) · $(ls -A "$L" 2>/dev/null | tr '\n' ' ') · $(wwhy ka)"
grep -q '닫은 부서 휴지통 · .*(제자리에 둡니다)' "$SBka/out.txt" && ! grep -q '닫은 부서 휴지통(보관 폴더로 옮깁니다)' "$SBka/out.txt" \
  && grep -q '부서 실행 상태 · .*(제자리에 둡니다' "$SBka/out.txt" && grep -q 'cys 지난 편성 기록' "$SBka/out.txt"
t $? "[윈] F8 진단 = -KeepApp 단독도 휴지통 · 부서 상태 제자리 · 편성 기록만 보관이라고 말한다(purge 와 같은 말)" "$(grep -E '휴지통|부서 실행 상태|편성 기록' "$SBka/out.txt" | tr '\n' '|' | cut -c1-400)"

# ── ⓒ 옮기기 실패(사용자 폴더 쓰기 막힘) → 자료 그대로 · 프로그램·등록 안 지움 · rc 7 ──
U="$SBc/C:/Users/emu"
[ "$(wrc c)" = "7" ] && [ -f "$U/.cys/claude/projects/-u-install-jarvis/s 1.jsonl" ] && [ -f "$U/AppData/Local/cys/cys-app.exe" ] && [ -f "$U/AppData/Local/cys/transcripts.db" ] \
  && [ -d "$SBc/$REG/Uninstall/cysr" ] && [ -f "$U/$SMP/cysr.lnk" ] && [ -f "$U/.local/bin/claude.exe" ] && grep -q '보관을 끝까지 마치지 못해' "$SBc/out.txt"
t $? "[윈] ⓒ 보관 폴더로 못 옮기면 자료 그대로 · 프로그램·설치 목록·바로가기도 안 지움 · rc 7" "rc=$(wrc c) · $(wwhy c)"
[ "$(grep -c '스스로 한 번 더 해 봅니다' "$SBc/out.txt")" = "2" ] && [ ! -e "$SBc/readhost.log" ]
t $? "[윈] ⓒ 실패 뒤 묻지 않고 스스로 2번 더 해 본다(상한 2)" "다시 해 보기 $(grep -c '스스로 한 번 더 해 봅니다' "$SBc/out.txt")번"

# ── ⓓ 옮긴 뒤 수·크기가 다르면 → 뒤 단계 멈춤 ──
U="$SBd/C:/Users/emu"
[ "$(wrc d)" = "7" ] && [ -f "$U/AppData/Local/cys/cys-app.exe" ] && [ -d "$SBd/$REG/Uninstall/cysr" ] && grep -q '보관 확인 실패' "$SBd/out.txt"
t $? "[윈] ⓓ 옮긴 뒤 수·크기가 다르면 「보관 확인 실패」 · 프로그램·등록 안 지움 · rc 7" "rc=$(wrc d) · $(wwhy d)"
U="$SBd2/C:/Users/emu"
[ "$(wrc d2)" = "7" ] && [ -f "$U/AppData/Local/cys/cys-app.exe" ] && [ -f "$U/.local/bin/claude.exe" ] && grep -q '보관 확인 실패' "$SBd2/out.txt"
t $? "[윈] ⓓ-2 ~\\.cys 를 옮긴 뒤 수·크기가 다르면 프로그램·클로드 안 지움 · rc 7" "rc=$(wrc d2) · $(wwhy d2)"

# ── ⓔ 다른 드라이브 → 복사하지 않고 멈춤 ──
U="$SBe/C:/Users/emu"
[ "$(wrc e)" = "7" ] && [ -d "$U/.cys" ] && [ -f "$U/AppData/Local/cys/cys-app.exe" ] && grep -q '다른 드라이브' "$SBe/out.txt"
t $? "[윈] ⓔ 보관 폴더와 다른 드라이브면 옮기지 않고(복사 0) 멈춤" "rc=$(wrc e) · $(wwhy e)"

# ── ⓕ 되옮기기 도중 끊김(창이 닫힘) → 다음 실행이 이어서 끝낸다 ──
U="$SBf/C:/Users/emu"; B="$(wbk f)"
[ "$(wrc f)" = "9" ] && grep -q '^MARK$' "$SBf/mid.txt" && ! { grep -qx 'depts.json' "$SBf/mid.txt" && grep -qx 'claude' "$SBf/mid.txt" && grep -qx 'pack-dept-dept-1' "$SBf/mid.txt" && grep -qx 'claude-default-dept-1' "$SBf/mid.txt"; }
t $? "[윈] ⓕ-1 되옮기기 도중 끊김 재현(넷째 이름 바꾸기에서 창이 닫힘 · 표지 남음 · 일부는 보관본에만)" "rc=$(wrc f) · 중간 $(tr '\n' ' ' < "$SBf/mid.txt" 2>/dev/null) · $(wwhy f)"
[ "$(wrc f out2)" = "0" ] && [ ! -f "$B/.jarvis-restore-pending" ] && [ "$(digest "$U/.cys/claude/projects")" = "$(digest "$RU/.cys/claude/projects")" ] \
  && [ -f "$U/.cys/depts.json" ] && [ -f "$U/.cys/pack-dept-dept-1/round/WORKER_TODO.md" ] && [ -f "$U/.cys/claude/.credentials.json" ] && grep -q '이어서 합니다' "$SBf/out2.txt"
t $? "[윈] ⓕ-2 다음 실행이 표지부터 이어서 끝낸다 · 대화·로그인·부서 제자리 · 표지 치움" "rc=$(wrc f out2) · $(tail -5 "$SBf/out2.txt" 2>/dev/null | tr '\n' '|' | cut -c1-400)"

# ── ⓖ 되옮기기 한 칸 실패 → 표지에 남은 것만 · rc 7 · 다음 실행이 끝낸다 ──
U="$SBg/C:/Users/emu"; B="$(wbk g)"
[ "$(wrc g)" = "7" ] && grep -q '^MARK$' "$SBg/mid.txt" && ! grep -qx 'depts.json' "$SBg/mid.txt" && [ -f "$U/.cys/claude/history.jsonl" ] && grep -q '되옮기지 못함' "$SBg/out.txt"
t $? "[윈] ⓖ 되옮기기 한 칸 실패 → 그 칸은 보관본에 · 나머지는 제자리 · 재설치 멈춤(rc 7)" "rc=$(wrc g) · $(wwhy g)"
grep -q '다시 실행하시면 이어서 제자리로 옮깁니다' "$SBg/out.txt" && [ ! -e "$B/cys-home-2" ]
t $? "[윈] ⓖ 다시 해 보기 회차는 끝나지 않은 표지를 덮지 않는다 · 「자료 그대로 · 다시 실행하면 이어서」 쉬운 말(결정⑵ 짝)" "$(grep -n '지난번 옮기기' "$SBg/out.txt" | head -2 | tr '\n' '|')"
[ "$(wrc g out2)" = "0" ] && [ -f "$U/.cys/depts.json" ] && [ ! -f "$B/.jarvis-restore-pending" ] && grep -q '이어서 합니다' "$SBg/out2.txt"
t $? "[윈] ⓖ-2 다음 실행이 남은 한 칸을 끝낸다 · 표지 치움" "rc=$(wrc g out2) · $(tail -4 "$SBg/out2.txt" 2>/dev/null | tr '\n' '|' | cut -c1-300)"
# ── r1 F2(master#0337b3fa) 끊긴 재설치 뒤 같은 이름의 새 자료 → 다시 실행해도 덮지 않음 · 옛 자료 보관본 그대로 · 표지 유지 · rc 7 · 쉬운 말 · 되옮겼다는 말 0 · ~\.cys 다시 안 옮김 ──
U="$SBov/C:/Users/emu"; B="$(wbk ov)"; OV="$(cat "$SBov/ov.txt" 2>/dev/null)"; HN="$(cat "$SBov/hn.txt" 2>/dev/null)"
if [ -d "$B/$HN/$OV" ]; then NOLD="$(digest "$B/$HN/$OV")"; else NOLD="$(shasum -a 256 < "$B/$HN/$OV" 2>/dev/null)"; fi
NCH="$(find "$U" -mindepth 2 -maxdepth 2 -path '*install-jarvis-backup-*' -name 'cys-home*' | wc -l | tr -d ' ')"
[ -n "$OV" ] && [ "$(wrc ov out2)" = "7" ] && [ -f "$B/.jarvis-restore-pending" ] && tr '\0' '\n' < "$B/.jarvis-restore-pending" | tr '\\' '/' | grep -qxF "$OV" \
  && [ "$NOLD" = "$(cat "$SBov/ovold.txt")" ] && { [ -f "$U/.cys/$OV/new-after-cut" ] || [ "$(cat "$U/.cys/$OV" 2>/dev/null)" = "new" ]; } && [ "$NCH" = "1" ] \
  && grep -q '같은 이름의 자료가 이미 있어 덮지 않았습니다' "$SBov/out2.txt" && grep -q '예전 자료는 보관 폴더에 그대로 있습니다: ' "$SBov/out2.txt" && ! grep -q '되옮겼습니다' "$SBov/out2.txt" \
  && grep -q '다른 이름으로 바꿔 두신 뒤 다시 실행하시면' "$SBov/out2.txt" && grep -q '바꿔 둔 새 쪽은 그때 보관 폴더로 함께 옮겨집니다' "$SBov/out2.txt"
t $? "[윈] F2 끊긴 재설치 뒤 같은 이름의 새 자료 → 다시 실행해도 덮지 않음 · 옛 자료 보관본 그대로 · 표지 유지 · rc 7 · 쉬운 말 · 되옮겼다는 말 0 · ~\.cys 다시 안 옮김" \
  "겹친 이름=$OV · rc=$(wrc ov out2) · 표지=$([ -f "$B/.jarvis-restore-pending" ] && echo 있음 || echo 없음) · 옛 cys-home 수=$NCH · $(tail -6 "$SBov/out2.txt" 2>/dev/null | tr '\n' '|' | cut -c1-400)"
# ── r1 F4 완전 삭제 보관본 속 로그인 파일 지우기가 그 실행에서 끝내 실패 → 새 실행이 이어서 지운다(진단이 셈 · 표지 치움 · rc 0) ──
U="$SBcr/C:/Users/emu"; B="$(wbk cr)"
[ "$(wrc cr)" = "7" ] && [ -s "$SBcr/cred-mid.txt" ] && [ "$(wrc cr out2)" = "0" ] && [ -z "$(find "$B" -name .credentials.json 2>/dev/null)" ] \
  && [ -z "$(find "$B" -name '.jarvis-cred-pending' 2>/dev/null)" ] && [ -f "$B/cys-home/claude/history.jsonl" ] && grep -q '이어서 지웁니다' "$SBcr/out2.txt"
t $? "[윈] F4 보관본 속 로그인 파일 지우기가 끝내 실패한 뒤 새 실행이 이어서 지운다(진단이 셈 · 표지 치움 · 대화 그대로 · rc 0)" \
  "rc=$(wrc cr)/$(wrc cr out2) · 중간 로그인 $(wc -l < "$SBcr/cred-mid.txt" 2>/dev/null | tr -d ' ') · 남은 로그인 $(find "$B" -name .credentials.json 2>/dev/null | wc -l | tr -d ' ') · $(tail -4 "$SBcr/out2.txt" 2>/dev/null | tr '\n' '|' | cut -c1-300)"
B="$SBc0/C:/Users/emu/install-jarvis-backup-20260101-000000"
[ "$(wrc c0)" = "0" ] && [ ! -e "$B/cys-home/claude/.credentials.json" ] && [ ! -e "$B/cys-home/.jarvis-cred-pending" ] && [ -f "$B/cys-home/claude/history.jsonl" ] && grep -q '보관본 속 로그인 파일 지우기가 남음' "$SBc0/out.txt"
t $? "[윈] F4 다른 자국이 하나도 없어도 진단이 「보관본 속 로그인 파일 지우기 남음」 을 세어 이어서 지운다(「지울 것이 없습니다」 금지)" "rc=$(wrc c0) · $(wwhy c0 4)"
# ── r1 F1(codex BLOCK · Fable F9) 설치 폴더 바로 아래 exe·dll 은 설치기가 실제로 까는 이름만 프로그램으로 지운다 — 사람이 둔 exe·dll·잔해 꼴은 보관(모르면 보관) ──
L="$SBx1f/C:/Users/emu/AppData/Local/cys"; B="$(wbk x1f)"
[ "$(wrc x1f)" = "0" ] && [ -n "$B" ] && [ -n "$(find "$B" -name my-tool.exe)" ] && [ -n "$(find "$B" -name helper.dll)" ] && [ -n "$(find "$B" -name other.exe.prev3)" ] \
  && [ ! -e "$L/my-tool.exe" ] && [ ! -e "$L/cys-app.new.exe" ] && [ ! -e "$L/cysd.prev123456.exe" ] && [ ! -e "$L/cys.exe.prev77" ] && [ ! -e "$L/WebView2Loader.dll.prev5" ] \
  && [ ! -e "$L/cysd.exe" ] && [ ! -e "$L/WebView2Loader.dll" ] && [ -z "$(find "$B" -name 'cys-app.new.exe' -o -name 'cysd.prev123456.exe' -o -name 'cysd.exe')" ]
t $? "[윈] F1 사람이 둔 exe·dll·잔해 꼴(my-tool.exe · helper.dll · other.exe.prev3)은 보관 · 우리 실행 파일·교체 슬롯·잠금 잔해만 지운다" \
  "rc=$(wrc x1f) · 보관본 속 $(find "$B" \( -name '*.exe' -o -name '*.dll' -o -name '*.prev*' \) 2>/dev/null | sed 's|.*/||' | tr '\n' ' ') · 남은 $(ls "$L" 2>/dev/null | tr '\n' ' ')"
# ── 결정⑵ 가드 단독(이어 하기를 끈 상태 · 윈) ──
B="$(wbk g2)"
[ "$(wrc g2)" = "7" ] && [ -f "$B/.jarvis-restore-pending" ] && [ ! -e "$B/cys-home-2" ] && grep -q '지난번 옮기기가 아직 끝나지 않아' "$SBg2/out.txt"
t $? "[윈] 결정⑵ 가드 단독 — 이어 하기를 꺼도 둘째 회차가 끝나지 않은 표지 위에 ~\\.cys 를 또 옮기지 않는다" "rc=$(wrc g2) · $(wwhy g2 4)"
# ── r2 Fable N7 윈 F6 짝 — 완전 삭제에서 끄지 못한 cys 가 남으면 아무것도 안 옮김(rc 7 · 보관본 0 · 프로그램 그대로) · 재설치는 알림만 ──
U="$SBal/C:/Users/emu"
[ "$(wrc al)" = "7" ] && [ "$(wnbk al)" = "0" ] && [ -f "$U/.cys/depts.json" ] && [ -f "$U/AppData/Local/cys/cysd.exe" ] && grep -q '아직 실행 중이라' "$SBal/out.txt" \
  && ! grep -q '잠시 뒤 스스로 한 번 더 해 봅니다' "$SBal/out.txt"
t $? "[윈] r2 N7 완전 삭제에서 끄지 못한 cys 가 남으면 아무것도 안 옮긴다(rc 7 · 보관본 0 · 프로그램 그대로 · 거짓 약속 문구 0)" "rc=$(wrc al) · 보관본 $(wnbk al) · $(wwhy al 4)"
[ "$(wrc al2)" = "0" ] && [ -f "$SBal2/C:/Users/emu/.cys/depts.json" ] && grep -q '돌고 있습니다' "$SBal2/out.txt"
t $? "[윈] r2 N7 재설치(-KeepApp)는 끄지 못한 cys 가 있어도 알림만 하고 이어 간다" "rc=$(wrc al2) · $(wwhy al2 4)"
# ── r1 agy F4 보관본 속 로그인 파일을 권한으로 못 읽으면 「없음」 으로 넘기지 않는다 ──
U="$SBcu/C:/Users/emu"; B="$(wbk cu)"; find "$B" -type d -exec chmod u+rwx {} + 2>/dev/null
[ "$(wrc cu)" = "7" ] && [ -f "$B/cys-home/.jarvis-cred-pending" ] && [ -f "$B/cys-home/claude/.credentials.json" ] && grep -q '읽지 못했습니다' "$SBcu/out.txt"
t $? "[윈] agy F4 보관본 속 로그인 파일을 못 읽으면 못 지움으로 센다(표지 남김 · rc 7)" "rc=$(wrc cu) · $(wwhy cu 4)"
# ── r1 F3 남은 목록 표지를 고쳐 쓰다 반쪽에서 끊김 → 옛 표지 유지 → 다음 실행이 남은 칸(depts.json)을 끝낸다 ──
U="$SBhf/C:/Users/emu"; B="$(wbk hf)"
[ "$(wrc hf)" = "7" ] && [ "$(wrc hf out2)" = "0" ] && [ -f "$U/.cys/depts.json" ] && [ ! -f "$B/.jarvis-restore-pending" ] && grep -q '이어서 합니다' "$SBhf/out2.txt"
t $? "[윈] F3 표지 고쳐 쓰기가 반쪽에서 끊겨도 옛 표지가 남아 다음 실행이 남은 칸(depts.json)을 끝낸다" "rc=$(wrc hf)/$(wrc hf out2) · depts=$([ -f "$U/.cys/depts.json" ] && echo 제자리 || echo 없음) · $(tail -4 "$SBhf/out2.txt" 2>/dev/null | tr '\n' '|' | cut -c1-300)"

# ── 반례 ①~⑤ ──
U="$SBp1/C:/Users/emu"; B="$(wbk p1)"
[ "$(wrc p1)" = "0" ] && [ "$(cat "$B/cys-home/pack/talk/s.jsonl" 2>/dev/null)" = "talk" ] && grep -q '\[안내\] 아래 바로가기가 가리키던 자료는 보관 폴더' "$SBp1/out.txt"
t $? "[윈] 반례① 가리키던 자료는 보관본에 온전 · 안내 1줄(삭제 0)" "rc=$(wrc p1) · $(wwhy p1 6)"
U="$SBp2/C:/Users/emu"
[ "$(wrc p2)" = "7" ] && [ "$(cat "$U/AppData/Local/cys/runtime/x" 2>/dev/null)" = "keep" ] && [ -f "$U/AppData/Local/cys/cys-app.exe" ] && [ -f "$U/.cys/claude/CLAUDE.md" ] \
  && [ -d "$U/install-jarvis" ] && [ "$(wnbk p2)" = "0" ] && [ -d "$SBp2/$REG/Uninstall/cysr" ] && grep -q '지울 프로그램 자리를 가리킵니다' "$SBp2/out.txt"
t $? "[윈] 반례② 바로가기가 지울 자리(설치 폴더 runtime)를 가리키면 첫 변경 전에 멈춤 · 변경 0" "rc=$(wrc p2) · $(wwhy p2)"
U="$SBp3/C:/Users/emu"
[ "$(wrc p3)" = "7" ] && [ -f "$U/.cys/claude/CLAUDE.md" ] && [ "$(wnbk p3)" = "0" ] && grep -q '줄바꿈' "$SBp3/out.txt"
t $? "[윈] 반례③ 바로가기 이름에 줄바꿈 → 못 풂 · 변경 0" "rc=$(wrc p3) · $(wwhy p3)"
U="$SBp4/C:/Users/emu"
[ "$(wrc p4)" = "7" ] && [ -f "$U/.cys/claude/CLAUDE.md" ] && [ "$(wnbk p4)" = "0" ] && grep -q '목록을 끝까지 읽지 못했습니다' "$SBp4/out.txt"
t $? "[윈] 반례④ 목록을 못 읽는 자리가 있으면 「남길 것 없음」이 아니라 못 풂 · 변경 0" "rc=$(wrc p4) · $(wwhy p4)"
U="$SBp5/C:/Users/emu"
[ "$(wrc p5)" = "0" ] && [ ! -e "$U/.cys/pack" ] && [ ! -L "$U/.cys/pack" ] && [ -f "$U/.cys/claude/projects/p/k.jsonl" ]
t $? "[윈] 반례⑤ pack 바로가기는 보관본으로 · 새 자리에 pack 이름표 없음 · 대화 그대로" "rc=$(wrc p5) · $(wwhy p5)"
# ── ⓠ ~\.cys\claude 자체가 바로가기 → 재설치 못 풂(0.3.36 규칙 유지) ──
U="$SBq/C:/Users/emu"
[ "$(wrc q)" = "7" ] && [ -L "$U/.cys/claude" ] && [ -f "$U/prof-real/CLAUDE.md" ] && [ -f "$U/.cys/pack/memory/MEMORY.md" ] && [ -f "$U/.cys/depts.json" ]
t $? "[윈] ⓠ ~\\.cys\\claude 가 바로가기면 재설치 = ~\\.cys 변경 0 · rc 7(0.3.36 ⓠ 유지)" "rc=$(wrc q) · $(wwhy q)"
# ── 예외 갈래(참가 자리가 ~\.cys 안) = 0.3.36 장치 + 부서 남길 것 + 반례 처방 ──
U="$SBx1/C:/Users/emu"
[ "$(wrc x1)" = "0" ] && [ "$(cat "$U/.cys/forum/key" 2>/dev/null)" = "key" ] && [ -f "$U/.cys/claude/projects/-u-install-jarvis/s 1.jsonl" ] && [ -f "$U/.cys/depts.json" ] \
  && [ -f "$U/.cys/pack-dept-dept-1/round/WORKER_TODO.md" ] && [ -f "$U/.cys/claude-default-dept-1/projects/p/x.jsonl" ] && [ ! -e "$U/.cys/pack" ] && [ ! -e "$U/.cys/claude/CLAUDE.md" ]
t $? "[윈] 예외 F1 참가 자리 안(~\\.cys\\forum) → 열쇠·본부 대화·부서 기록 남김 · 팩·CLAUDE.md 지움 · rc 0" "rc=$(wrc x1) · $(ls -A "$U/.cys" 2>/dev/null | tr '\n' ' ') · $(wwhy x1)"
U="$SBx2/C:/Users/emu"
[ "$(wrc x2)" = "7" ] && [ "$(cat "$U/.cys/pack/talk/s.jsonl" 2>/dev/null)" = "talk" ] && grep -q '남길 자리 밖을 가리킵니다' "$SBx2/out.txt"
t $? "[윈] 예외 F① 남길 자리 안 바로가기가 남길 것 밖(pack)을 가리키면 못 풂 · 변경 0" "rc=$(wrc x2) · $(wwhy x2)"
U="$SBx5/C:/Users/emu"
[ "$(wrc x5)" = "0" ] && [ ! -e "$U/.cys/pack" ] && [ ! -L "$U/.cys/pack" ] && [ -f "$U/.cys/claude/projects/p/k.jsonl" ]
t $? "[윈] 예외 F⑤ pack 이 projects 안을 가리키는 바로가기 → pack 이름표 지움 · 대화 그대로" "rc=$(wrc x5) · $(wwhy x5)"

# ── 새 결함 ⓑ(결정 3) 보관본 속 로그인 파일 지우기가 1회차에 실패 → 다시 해 보기가 다시 지운다 ──
U="$SBrb/C:/Users/emu"
[ "$(wrc rb)" = "0" ] && [ -z "$(find "$U" -path '*install-jarvis-backup-*' -name .credentials.json 2>/dev/null)" ] && grep -q '(시험) 보관본 속 로그인 파일 지우기 실패 흉내' "$SBrb/out.txt" \
  && [ "$(grep -c '스스로 한 번 더 해 봅니다' "$SBrb/out.txt")" = "1" ]
t $? "[윈] 새ⓑ 1회차에 보관본 로그인 파일을 못 지우면 다시 해 보기가 그 자리를 다시 지운다 · 비밀값 0 · rc 0" "rc=$(wrc rb) · 남은 것 $(find "$U" -path '*install-jarvis-backup-*' -name .credentials.json 2>/dev/null | head -2 | tr '\n' ' ') · $(wwhy rb)"
# ── 새 결함 ⓐ 남길 자리 실경로 확인 실패 → 프로그램 파일·바로가기와 함께 설치 목록·설치 위치 기록·자동 실행 값도 남긴다 ──
U="$SBra/C:/Users/emu"
[ "$(wrc ra)" = "7" ] && [ -f "$U/AppData/Local/cys/cys-app.exe" ] && [ -d "$SBra/$REG/Uninstall/cysr" ] && [ -d "$SBra/reg/Software/cysjavis/cysr" ] && [ -f "$SBra/$REG/Run/cysr.regval" ] && [ -f "$U/$SMP/cysr.lnk" ]
t $? "[윈] 새ⓐ 남길 자리를 확인 못 하면 프로그램·바로가기·설치 목록·설치 위치 기록·자동 실행 값 전부 남김(고아 프로그램 0)" "rc=$(wrc ra) · $(find "$SBra/reg" -mindepth 1 | sed "s|$SBra/||" | tr '\n' ' ' | cut -c1-300)"
# ── 새 결함 ⓒ 신뢰 칸 실패 깃발 — 매 회차 실측 ──
U="$SBrc/C:/Users/emu"
[ "$(wrc rc)" = "0" ] && [ ! -e "$U/install-jarvis" ] && [ -n "$(find "$U" -path '*install-jarvis-backup-*/notes/a.txt' 2>/dev/null)" ] && grep -q '(시험) 신뢰 기록 읽기 실패 흉내' "$SBrc/out.txt"
t $? "[윈] 새ⓒ 신뢰 칸 실패가 1회차에서 풀리면 2회차가 작업 폴더를 보관하고 rc 0(깃발은 회차마다 다시 잰다)" "rc=$(wrc rc) · $(wwhy rc)"
U="$SBrc2/C:/Users/emu"
[ "$(wrc rc2)" = "7" ] && [ -f "$U/install-jarvis/notes/a.txt" ]
t $? "[윈] 새ⓒ-2 매 회차 실패면 끝까지 작업 폴더를 남기고 rc 7(무조건 풀기 금지)" "rc=$(wrc rc2) · $(wwhy rc2)"

# ── 154 E2 앞뒤: 설치 목록 UninstallString 에 /P 가 없든 있든 끝 상태가 같다 ──
lsb() { ( cd "$(wbk "$1")" 2>/dev/null && find . -mindepth 1 | LC_ALL=C sort ); }
[ "$(wrc e2n)" = "0" ] && [ "$(wrc e2p)" = "0" ] && [ ! -e "$SBn/$REG/Uninstall/cysr" ] && [ ! -e "$SBy/$REG/Uninstall/cysr" ] && [ -n "$(lsb e2n)" ] && [ "$(lsb e2n)" = "$(lsb e2p)" ] \
  && [ ! -e "$SBn/C:/Users/emu/AppData/Local/cys" ] && [ ! -e "$SBy/C:/Users/emu/AppData/Local/cys" ]
t $? "[윈] 154 E2 앞뒤 — UninstallString(/P 없음·있음) 어느 쪽이든 우리 항목 지움 · 보관본 구성 같음" "rc=$(wrc e2n)/$(wrc e2p) · $(diff <(lsb e2n) <(lsb e2p) | head -3 | tr '\n' '|')"

# ── ⓗ 손 0(정적) — 사람 입력을 읽는 줄 0 · 묻는 문구 0 · 스스로 다시 해 보기 상한 2 · 알림 뒤 5초 ──
n_rh="$(grep -vE '^\s*#' "$RP" | grep -c 'Read-Host')"
[ "$n_rh" = "0" ]; t $? "[윈] ⓗ 사람 입력을 읽는 줄(Read-Host) 0" "남은 줄 $n_rh"
! grep -vE '^\s*#' "$RP" | grep -q '라고 입력해 주십시오'; t $? "[윈] ⓗ 「지웁니다」 입력 문구 0" "남음"
grep -qE '^while \(\(\$rc -ne 0\) -and \(\$tries -lt 2\)\) \{' "$RP"; t $? "[윈] ⓗ 스스로 다시 해 보기 = 최대 2회(사람 조건 없음)" "고리 줄 다름"
grep -qE '^\s+\$noticeWait = 5$' "$RP" && grep -q 'Start-Sleep -Seconds \$noticeWait' "$RP"; t $? "[윈] ⓗ 「끕니다」 알림 뒤 5초" "없음"
! grep -vE '^\s*#' "$RP" | grep -q '설정 > 앱'; t $? "[윈] ⓗ 설정 앱 제거를 사람에게 시키는 문구 0" "남음"
awk '/Start-Process -FilePath \$UninstExe/{s=NR} /if \(\(Test-Path \$UninstExe\) -and \$UseUninstaller\)/{u=NR} END{exit !(s && u && u < s && s - u < 5)}' "$RP"
t $? "[윈] ⓗ 제거 프로그램 실행은 -UseUninstaller 갈래 안에만" "갈래 밖"
# 다시 해 보기 고리 동작 — 가짜 Invoke-Purge 가 두 번 실패 뒤 성공 / 늘 실패
awk '/^\$rc = Invoke-Purge$/{p=1} p && /^if \(\$rc -ne 0\) \{ Show-RerunHow \}$/{print; exit} p{print}' "$RP" > "$WB/loop.ps1"
for want in "2:0:3" "9:7:3"; do
  failn="${want%%:*}"; rest="${want#*:}"
  out="$(FAILN="$failn" LOOPF="$WB/loop.ps1" "$PW" -NoProfile -NonInteractive -Command '$script:n = 0; function Invoke-Purge { $script:n++; if ($script:n -gt [int]$env:FAILN) { return 0 }; return 7 }; function Invoke-Prescan { return $true }; function Show-RerunHow { }; function Reset-PurgeCounters { }; function Start-Sleep { }; function Write-Host { }; . ([scriptblock]::Create([IO.File]::ReadAllText($env:LOOPF))); "{0}:{1}" -f $rc, $script:n' 2>&1 | tail -1)"
  [ "$out" = "$rest" ]; t $? "[윈] ⓗ 고리 동작(실패 ${failn}번) → rc ${rest%%:*} · Invoke-Purge ${rest#*:}번" "받음 $out"
done
}

[ "$ONLY" = "win" ] || run_mac
[ "$ONLY" = "mac" ] || run_win
printf '== delete-path: ok %s · FAIL %s ==\n' "$pass" "$fail"
[ "$fail" -eq 0 ]
