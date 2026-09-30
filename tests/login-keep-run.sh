#!/bin/bash
# 0.3.36 — 재설치 길에서 자비스 창의 로그인·이전 대화를 지우지 않는다(두 OS · TICKET=installer-login-keep)
#   설계 = docs/install-master/DESIGN-login-keep-0336.md · 09-25 윈 실기: 재설치 한 줄 뒤 본부 세 자리 모두 「Login expired」.
#
# 재는 것
#   [윈] 실물 reset-clean.ps1 전체를 pwsh 로 — 윈도우 모양 경로(C:\Users\emu)를 샌드박스의 「C:」 폴더로 흉내(tests/reinstall-keepapp-emu/reset-host.ps1 재사용)
#     ⓐ 재설치 길(-KeepApp -KeepHistory -Yes) → 남길 다섯(.credentials.json · projects · history.jsonl · file-history · agent-memory) 바이트 그대로 ·
#        나머지(CLAUDE.md · settings.json · .claude.json · skills · sessions · .bak-jarvis · pack · 부서 프로필)는 없음 · rc 0
#     ⓑ 옛 재설치(-KeepApp -Yes · 새 표지 없음) → ~\.cys 통째로 지움(종전과 같다)
#     ⓒ 완전 삭제 길(-Yes) → ~\.cys 통째로 지움(불변)
#     ⓓ 살펴보기 화면 — 재설치 길 = 「다시 하셔야 합니다」 0 · 「그대로 둡니다」 1 · 「이전 대화」 1 / 표지 없음 = 종전 줄
#     ⓔ 남길 자리가 바깥을 가리키는 바로가기 → 바로가기 남음 · 바깥 폴더 그대로
#     ⓕ 남길 자리가 끊어진 바로가기(실경로 못 풂) → ~\.cys 하나도 안 지움 · rc 7 · 「확인하지 못해」
#     ⓖ 이어서 설치 도우미 [8/10] Copy-LoginToIsolated(떼어 부름) → 남은 동료 로그인(더 늦은 만료)을 옛 기본 파일이 안 덮음(keep:newer)
#   [맥] reset-clean.sh 에서 함수와 purge 의 ~/.cys 한 토막만 떼어 임시 홈에서 — 제거기 전체는 돌리지 않는다
#     ⓗ 재설치 길(KEEP_HISTORY=1) = ⓐ 짝 · ⓘ 표지 없음 = 통째로(옛 재설치·완전 삭제 불변) · ⓙ 바로가기 · ⓚ 못 여는 자리 → 하나도 안 지움
#   [정적] ⓛ 재설치 두 입구가 표지를 늘 넘긴다(맥 = 칩 조건 밖) · ⓜ 맥 화면 줄 갈래 · ⓝ 맥 열쇠고리 지우기 = 기본 이름 한 곳 · --purge-login 한정
# 🔴운영 맥 안전: 맥 제거기 전체 실행 0([[remover-tests-only-in-guest-home-swap-is-not-isolation]]) — 떼어 낸 묶음에 launchctl·pkill·/Applications·security 가 없음을 첫 칸에서 잰다.
#   윈 흉내는 Stop-Process 를 기록 함수로 덮고(reset-host.ps1) PATH 를 /usr/bin:/bin 으로 좁힌다 · 쓰기 = mktemp 안에서만 · 토큰 = 가짜 모양만.
# 쓰는 법: bash tests/login-keep-run.sh [--dir <install-master 자리>]   · rc 0 = 통과 · 2 = 잴 수 없음(pwsh 없음)
set -u
export JARVIS_NO_PROGRESS=1
HERE="$(cd "$(dirname "$0")" && pwd)"
DIR="$HERE/../install-master"
[ "${1:-}" = "--dir" ] && DIR="$2"
SRC="$(cd "$DIR" && pwd)"
RP="$SRC/reset-clean.ps1"; RS="$SRC/reset-clean.sh"; BP="$SRC/bootstrap.ps1"
EMU="$HERE/reinstall-keepapp-emu"
PW="$(command -v pwsh 2>/dev/null)"
[ -n "$PW" ] || { echo "잴 수 없음: pwsh 가 없다" >&2; exit 2; }
BASE="$(mktemp -d -t login-keep)" || exit 2
BASE="$(cd "$BASE" && pwd -P)" || exit 2
trap 'chmod -R u+rwx "$BASE" 2>/dev/null; rm -rf "$BASE"' EXIT
pass=0; fail=0
t() { if [ "$1" -eq 0 ]; then pass=$((pass+1)); printf '  ok   %s\n' "$2"; else fail=$((fail+1)); printf '  FAIL %s  ← %s\n' "$2" "$3"; fi; }
KEEP5=".credentials.json projects history.jsonl file-history agent-memory"
GONE=".credentials.json.bak-jarvis CLAUDE.md settings.json .claude.json skills sessions"

seed_profile() { # seed_profile <~/.cys/claude 실경로> — 가짜 모양만(진짜 로그인 아님)
  local C="$1"
  mkdir -p "$C/projects/-Users-emu-install-jarvis" "$C/file-history/s1" "$C/agent-memory" "$C/skills/z" "$C/sessions"
  printf '{"claudeAiOauth":{"accessToken":"fake-seat-access","refreshToken":"fake-seat-refresh","expiresAt":1790300000000}}' > "$C/.credentials.json"
  printf '{"claudeAiOauth":{"accessToken":"fake-old","expiresAt":1790000000000}}' > "$C/.credentials.json.bak-jarvis"
  printf '{"type":"user","message":"이전 대화 %s"}\n' "it's" > "$C/projects/-Users-emu-install-jarvis/s 1.jsonl"
  printf '{"display":"hello"}\n' > "$C/history.jsonl"
  printf 'snapshot\n' > "$C/file-history/s1/a@v1"
  printf 'memo\n' > "$C/agent-memory/m.md"
  printf 'router\n' > "$C/CLAUDE.md"; printf '{}' > "$C/settings.json"; printf '{}' > "$C/.claude.json"
  printf 'skill\n' > "$C/skills/z/SKILL.md"; printf '{}' > "$C/sessions/1.json"
}
digest() { # digest <폴더> <이름들…> — 남길 자리들의 경로·내용 지문
  local d="$1"; shift
  ( cd "$d" 2>/dev/null || exit 0; for n in "$@"; do [ -e "$n" ] && find "$n" -type f -print0 | LC_ALL=C sort -z | xargs -0 shasum -a 256; done ) 2>/dev/null
}
gone_all() { local d="$1" n left=""; for n in $GONE; do { [ -e "$d/$n" ] || [ -L "$d/$n" ]; } && left="$left $n"; done; printf '%s' "$left"; }

# ═════════ [윈] ═════════
win_sb() { # win_sb <이름> → 샌드박스 경로(찍음) · 설치가 끝난 기계의 자국 + 자비스 창 프로필
  local SB="$BASE/win-$1" U
  U="$SB/C:/Users/emu"
  mkdir -p "$U/AppData/Local/cys" "$U/AppData/Local/Temp" "$U/AppData/Roaming" "$U/.cys/pack" "$U/.cys/claude-default-dept-1/projects" "$U/install-jarvis" "$SB/reg/Software/Microsoft/Windows/CurrentVersion/Uninstall/cys" "$SB/childhome"
  ln -s "$SB/C:" "$SB/cdrv"
  printf 'emu uninstaller' > "$U/AppData/Local/cys/uninstall.exe"
  printf '#!/bin/sh\nexit 0\n' > "$U/AppData/Local/cys/cys.exe"; chmod +x "$U/AppData/Local/cys/cys.exe"
  printf 'pack' > "$U/.cys/pack/f.txt"; printf 'dept' > "$U/.cys/claude-default-dept-1/projects/x.jsonl"
  printf 'emu' > "$U/install-jarvis/emu.txt"; printf 'jarvis-installer-owned v1' > "$U/install-jarvis/.jarvis-owned"
  seed_profile "$U/.cys/claude"
  printf '%s' "$SB"
}
win_run() { # win_run <샌드박스> <스위치(쉼표)> → 출력 = <샌드박스>/out.txt · rc = <샌드박스>/rc.txt
  local SB="$1"
  ( cd "$SB" && USERPROFILE='C:\Users\emu' LOCALAPPDATA='C:\Users\emu\AppData\Local' APPDATA='C:\Users\emu\AppData\Roaming' \
      TEMP='C:\Users\emu\AppData\Local\Temp' JARVIS_HOME='C:\Users\emu\install-jarvis' HOME="$SB/childhome" JARVIS_BASE_URL='http://127.0.0.1:9/emu' \
      perl -e 'alarm shift; exec @ARGV' 900 "$PW" -NoProfile -NonInteractive -File "$EMU/reset-host.ps1" -Target "$RP" -Log "$SB/readhost.log" -Switches "$2" -Sb "$SB" \
      </dev/null >"$SB/out.txt" 2>&1; echo $? > "$SB/rc.txt" )
}

echo "== [윈] ⓐ 재설치 길 (-KeepApp -KeepHistory -Yes) =="
SB="$(win_sb a)"; C="$SB/C:/Users/emu/.cys/claude"
before="$(digest "$C" $KEEP5)"
win_run "$SB" 'KeepApp,KeepHistory,Yes'
after="$(digest "$C" $KEEP5)"
[ -n "$before" ] && [ "$before" = "$after" ] && [ "$(printf '%s\n' "$before" | wc -l | tr -d ' ')" -ge 5 ]
t $? "[윈] 남길 다섯 자리가 바이트 그대로 남는다" "앞 $(printf '%s\n' "$before" | wc -l | tr -d ' ')줄 · 뒤 $(printf '%s\n' "$after" | grep -c . )줄"
# 0.3.37(뜻 변경 · TICKET=installer-0337-delete-path): 나머지는 지우지 않고 보관 폴더(cys-home)로 · 부서 좌석 프로필(claude-*)은 제자리로 되옮긴다(부서 보존)
BK="$(find "$SB/C:/Users/emu" -mindepth 1 -maxdepth 1 -name 'install-jarvis-backup-*' | LC_ALL=C sort | head -1)"
left="$(gone_all "$C")"; [ -z "$left" ] && [ ! -e "$SB/C:/Users/emu/.cys/pack" ] && [ -f "$BK/cys-home/pack/f.txt" ] && [ -f "$SB/C:/Users/emu/.cys/claude-default-dept-1/projects/x.jsonl" ]
t $? "[윈] 나머지(설정·라우터·팩·옛 사본)는 보관 폴더로 옮기고 새 자리에 없다 · 부서 좌석 프로필은 제자리(0.3.37)" "남은 것:$left $( [ -e "$SB/C:/Users/emu/.cys/pack" ] && echo pack) · 보관 팩=$( [ -f "$BK/cys-home/pack/f.txt" ] && echo 있음 || echo 없음) · 부서=$( [ -e "$SB/C:/Users/emu/.cys/claude-default-dept-1" ] && echo 제자리 || echo 없음)"
[ "$(cat "$SB/rc.txt")" = "0" ] && grep -q '로그인·이전 대화는 그대로' "$SB/out.txt"
t $? "[윈] rc 0 · 「로그인·이전 대화는 그대로」 한 줄" "rc=$(cat "$SB/rc.txt") · $(grep -E '\[남음\]|\[일부' "$SB/out.txt" | head -2 | tr '\n' '|' | cut -c1-200)"
! grep -q '다시 하셔야 합니다' "$SB/out.txt" && grep -q '다시 까는 길이라 이 로그인은 지우지 않고 그대로 둡니다' "$SB/out.txt" && grep -q '\[있음\] 자비스 창 이전 대화' "$SB/out.txt"
t $? "[윈] ⓓ 재설치 길 화면 = 「다시 하셔야」 0 · 「그대로 둡니다」 · 「이전 대화」" "$(grep -E '다시 하셔야|그대로 둡니다|이전 대화' "$SB/out.txt" | head -3 | tr '\n' '|' | cut -c1-200)"

echo "== [윈] ⓖ 이어서 설치 도우미 [8/10] 로그인 이어 두기 =="
# init-pack 이 전용 자리를 만든다(흉내 = mkdir) · 기본 자리 = 첫 설치 때의 옛 로그인(더 이른 만료)
U="$SB/C:/Users/emu"; mkdir -p "$U/.claude" "$C"
printf '{"claudeAiOauth":{"accessToken":"fake-old-default","refreshToken":"fake-old-refresh","expiresAt":1790000000000}}' > "$U/.claude/.credentials.json"
{ for f in Get-CredExpiresAt Test-CredHasLogin Get-LoginCopyPlan Copy-LoginToIsolated Get-LoginCopyWords; do
    awk -v f="$f" '$0 ~ "^function "f"[ ({]" {p=1} p{print} p && /^}/{exit}' "$BP"
  done
  printf 'function Write-Log($m) { Add-Content -LiteralPath $env:LK_LOG -Value $m }\nfunction Say($m) { }\nfunction Redact($s) { return $s }\n'
  printf '[void](Copy-LoginToIsolated)\n'
} > "$BASE/copy-login.ps1"
grep -q '^function Copy-LoginToIsolated' "$BASE/copy-login.ps1"
t $? "[윈] 설치 도우미에서 Copy-LoginToIsolated 를 떼어 냈다" "없다"
seat="$(shasum -a 256 < "$C/.credentials.json" 2>/dev/null)"
USERPROFILE="$U" LK_LOG="$BASE/copy-login.log" "$PW" -NoProfile -NonInteractive -File "$BASE/copy-login.ps1" >/dev/null 2>&1
[ -n "$seat" ] && [ "$(shasum -a 256 < "$C/.credentials.json")" = "$seat" ] && grep -q 'login copy plan: keep:newer' "$BASE/copy-login.log"
t $? "[윈] 남은 동료 로그인(더 새것)을 옛 기본 파일이 안 덮는다(keep:newer)" "기록: $(head -2 "$BASE/copy-login.log" 2>/dev/null | tr '\n' '|' | cut -c1-160)"

echo "== [윈] ⓑ 옛 재설치(-KeepApp -Yes · 새 표지 없음) · ⓒ 완전 삭제(-Yes) =="
for c in 'b:KeepApp,Yes' 'c:Yes'; do
  n="${c%%:*}"; SB="$(win_sb "$n")"; win_run "$SB" "${c#*:}"
  [ ! -e "$SB/C:/Users/emu/.cys" ]
  t $? "[윈] ⓑⓒ ${c#*:} → ~\\.cys 원자리를 비운다(0.3.37 = 통째로 보관 폴더로)" "남음 · rc=$(cat "$SB/rc.txt") · $(grep -E '\[남음\]' "$SB/out.txt" | head -2 | tr '\n' '|' | cut -c1-160)"
done
# 0.3.37(뜻 변경): 표지 없는 길은 로그인 파일을 보관하지 않고 지운다 — 「다시 하셔야 할 수 있습니다」(보관 폴더에 비밀값 0)
SB="$BASE/win-b"; grep -q '다시 하셔야 할 수 있습니다' "$SB/out.txt" && grep -q '보관 폴더에 넣지 않고 지웁니다' "$SB/out.txt" && ! grep -q '다시 까는 길이라' "$SB/out.txt"
t $? "[윈] ⓓ 표지 없는 길 화면 = 「보관 폴더에 넣지 않고 지웁니다」 · 「다시 하셔야 할 수 있습니다」(0.3.37)" "$(grep -E '다시 하셔야|다시 까는|넣지 않고' "$SB/out.txt" | head -3 | tr '\n' '|')"

echo "== [윈] ⓔ 남길 자리가 바깥을 가리키는 바로가기 =="
SB="$(win_sb e)"; C="$SB/C:/Users/emu/.cys/claude"; O="$SB/C:/Users/emu/outside-proj"
mkdir -p "$O"; printf 'outside' > "$O/keep.jsonl"; rm -rf "$C/projects"; ln -s "$O" "$C/projects"
win_run "$SB" 'KeepApp,KeepHistory,Yes'
[ -L "$C/projects" ] && [ "$(cat "$O/keep.jsonl" 2>/dev/null)" = "outside" ] && [ -f "$C/history.jsonl" ] && [ ! -e "$C/CLAUDE.md" ] && [ ! -e "$SB/C:/Users/emu/.cys/pack" ] && [ "$(cat "$SB/rc.txt")" = "0" ]
t $? "[윈] 바로가기 자체가 남고 바깥 폴더는 그대로 · 나머지는 지운다" "링크=$( [ -L "$C/projects" ] && echo 있음 || echo 없음) · 바깥=$(cat "$O/keep.jsonl" 2>/dev/null) · rc=$(cat "$SB/rc.txt")"

echo "== [윈] ⓕ 남길 자리가 끊어진 바로가기 =="
SB="$(win_sb f)"; C="$SB/C:/Users/emu/.cys/claude"
rm -f "$C/history.jsonl"; ln -s "$SB/nowhere/history.jsonl" "$C/history.jsonl"
win_run "$SB" 'KeepApp,KeepHistory,Yes'
# 0.3.37(뜻 변경): 통째로 보관 → 되옮기기라 끊어진 바로가기도 이름표째 제자리로 돌아온다(지우는 것 0 · 가리키던 곳은 원래 없음) — rc 0
BK="$(find "$SB/C:/Users/emu" -mindepth 1 -maxdepth 1 -name 'install-jarvis-backup-*' | LC_ALL=C sort | head -1)"
[ -L "$C/history.jsonl" ] && [ -f "$BK/cys-home/pack/f.txt" ] && [ -f "$BK/cys-home/claude/CLAUDE.md" ] && [ ! -e "$C/CLAUDE.md" ] && [ "$(cat "$SB/rc.txt")" = "0" ]
t $? "[윈] 남길 자리가 끊어진 바로가기 → 이름표째 제자리 · 팩·라우터는 보관 폴더에(지운 것 0) · rc 0(0.3.37)" "링크=$( [ -L "$C/history.jsonl" ] && echo 있음 || echo 없음) · 보관 팩=$( [ -f "$BK/cys-home/pack/f.txt" ] && echo 있음 || echo 없음) · rc=$(cat "$SB/rc.txt")"

echo "== [윈] ⓕ-2 남길 자리가 ~\\.cys 안 다른 자리를 가리키는 바로가기(적대 1R 반례) =="
SB="$(win_sb f2)"; C="$SB/C:/Users/emu/.cys/claude"
rm -rf "$C/projects"; ln -s "$SB/C:/Users/emu/.cys/pack" "$C/projects"
win_run "$SB" 'KeepApp,KeepHistory,Yes'
# 0.3.37(뜻 변경 · 맥과 같은 모양): 가리키던 pack 은 보관 폴더에 온전 · 바로가기는 이름표째 제자리 · [안내] 1줄 · rc 0(삭제 0)
BK="$(find "$SB/C:/Users/emu" -mindepth 1 -maxdepth 1 -name 'install-jarvis-backup-*' | LC_ALL=C sort | head -1)"
[ -f "$BK/cys-home/pack/f.txt" ] && [ -L "$C/projects" ] && [ "$(cat "$SB/rc.txt")" = "0" ] && grep -q '\[안내\] 아래 바로가기가 가리키던 자료는 보관 폴더' "$SB/out.txt" && ! grep -q '지움: .*\.cys (로그인' "$SB/out.txt"
t $? "[윈] pack 을 가리키는 바로가기 → pack 은 보관 폴더에 온전 · 이름표 제자리 · [안내] 1줄 · rc 0(0.3.37)" "rc=$(cat "$SB/rc.txt") · 보관 팩=$( [ -f "$BK/cys-home/pack/f.txt" ] && echo 있음 || echo 없음) · $(grep -E '안내|지움: .*cys' "$SB/out.txt" | head -2 | tr '\n' '|')"

echo "== [윈] ⓔ-2 남길 폴더 안의 바로가기 · ⓕ-3 프로필 자체가 바로가기 (이종 1R) =="
SB="$(win_sb e2)"; C="$SB/C:/Users/emu/.cys/claude"; O="$SB/C:/Users/emu/outside-saved"
mkdir -p "$O"; printf 'saved' > "$O/s.jsonl"; ln -s "$O" "$C/projects/saved"
win_run "$SB" 'KeepApp,KeepHistory,Yes'
[ -L "$C/projects/saved" ] && [ "$(cat "$O/s.jsonl" 2>/dev/null)" = "saved" ] && [ ! -e "$SB/C:/Users/emu/.cys/pack" ] && [ "$(cat "$SB/rc.txt")" = "0" ]
t $? "[윈] 남길 폴더 안 바로가기도 남는다(바깥 그대로 · 나머지 지움)" "링크=$( [ -L "$C/projects/saved" ] && echo 있음 || echo 없음) · rc=$(cat "$SB/rc.txt")"
SB="$(win_sb f3)"; U="$SB/C:/Users/emu"; mv "$U/.cys/claude" "$U/prof-real"; ln -s "$U/prof-real" "$U/.cys/claude"
win_run "$SB" 'KeepApp,KeepHistory,Yes'
[ -f "$U/.cys/pack/f.txt" ] && [ -f "$U/prof-real/CLAUDE.md" ] && [ "$(cat "$SB/rc.txt")" = "7" ]
t $? "[윈] ~\\.cys\\claude 자체가 바로가기 → 못 풂(삭제 0 · rc 7)" "rc=$(cat "$SB/rc.txt")"

# ═════════ [맥] ═════════
echo "== [맥] 함수 떼어 내기(제거기 전체는 안 돌린다) =="
# 0.3.37(TICKET=installer-0337-delete-path): ~/.cys 토막이 보관 이동·되옮기기(R2)를 부르게 되어 떼는 함수를 넓혔다 —
#   기계 자리를 건드리는 함수(프로세스 끄기·열쇠고리·osascript)는 여전히 빼고, 아래 첫 칸이 그 부재를 잰다.
{ awk '/^(PRESERVE_CANON|PRESERVE_CANON_FAIL|PRESERVE_CANON_BAD|HIST_KEEPS|PRUNE_FAIL|PRUNE_WHY|JARVIS_OWNER_MARK|JARVIS_BACKUP_PREFIX|JARVIS_BACKUP_KEEP|JARVIS_BACKUP_INSTALLER_NAMES|RESTORE_MARK|ARCHIVE_DEST|PRESCAN_BAD|DEPT_KEEPS)=/{print}
       /^(HISTORY_KEEP_NAMES|STATE_FORMATION_NAMES)="/{h=1} h{print; if($0 ~ /"$/ && $0 !~ /^[A-Z_]+="$/) h=0}
       /^[a-z_]+\(\) *\{/{n=$1; sub(/\(\).*/,"",n); skip=(n ~ /^(kill_verified|stop_cys_processes|alive_after|write_alive_procs|procs_under|proc_token|proc_descendants|table_pids|add_descendants|login_[a-z_]+|dir_key_json|strip_json_key|purge_login_first|notice_close_cys|diagnose|purge|show_rerun_how|rerun_cmd|strip_hooks|pick_python|say|short)$/); f=1}
       f && !skip {print} f && /^}/ {f=0}' "$RS"
  printf 'say() { printf "%%s\\n" "$*"; }\nshort() { printf "%%s" "${1/#$HOME/~}"; }\n'
  printf 'cys_home_block() {\n'
  awk '/# footprint: M-CYSHOME +\(M-CYSPROFILE/{p=1} /# footprint: M-CYSSTATE/{p=0} p' "$RS"
  printf '}\n'
} > "$BASE/mac-lib.sh"
grep -q '^history_keeps() {' "$BASE/mac-lib.sh" && grep -q "^root_clash() {" "$BASE/mac-lib.sh" && grep -q 'cys_home_reinstall' "$BASE/mac-lib.sh" && bash -n "$BASE/mac-lib.sh"
t $? "[맥] 떼어 낸 묶음에 history_keeps · ~/.cys 토막이 있다(문법 통과)" "$(grep -c '() {' "$BASE/mac-lib.sh") 개"
! grep -vE '^\s*#' "$BASE/mac-lib.sh" | grep -qE 'launchctl|pkill|/Applications|security |osascript'
t $? "[맥] 떼어 낸 묶음에 절대경로·기계 등록·프로세스 끄기·열쇠고리가 없다(운영 맥 안전)" "$(grep -nE 'launchctl|pkill|/Applications|security ' "$BASE/mac-lib.sh" | head -3 | tr '\n' '|')"
mac_run() { # mac_run <이름> <KEEP_HISTORY 0|1> [준비 명령] → 홈 경로 찍음 · 출력 = <홈>/../out.txt
  local H="$BASE/mac-$1/home"
  mkdir -p "$H/.cys/pack" "$H/.cys/claude-default-dept-1/projects"; printf 'pack' > "$H/.cys/pack/f.txt"; printf 'd' > "$H/.cys/claude-default-dept-1/projects/x.jsonl"
  seed_profile "$H/.cys/claude"
  [ -n "${3:-}" ] && ( cd "$H" && eval "$3" )
  ( HOME="$H" JARVIS_HOME="$H/install-jarvis" KEEP_HISTORY="$2" AGORA_MIGRATE_OK=1 KEPT_FAIL=0 REMOVED=0 PRESERVED=0 bash -c 'set -u; . "$1"; ARCHIVE_FAIL=0; ARCHIVED=0; ARCHIVE_HOME=""; ARCHIVE_LAST=""; resolve_preserve_paths() { :; }; cys_home_block; echo "KEPT_FAIL=$KEPT_FAIL"' _ "$BASE/mac-lib.sh" ) > "$BASE/mac-$1/out.txt" 2>&1
  printf '%s' "$H"
}
H="$(mac_run h 1)"; C="$H/.cys/claude"
mkdir -p "$BASE/mac-ref"; seed_profile "$BASE/mac-ref/claude"
[ "$(digest "$C" $KEEP5)" = "$(digest "$BASE/mac-ref/claude" $KEEP5)" ] && [ -n "$(digest "$C" $KEEP5)" ]
t $? "[맥] ⓗ 재설치 길 = 남길 다섯 자리가 바이트 그대로 남는다" "$(sed -n '1,6p' "$BASE/mac-h/out.txt" | tr '\n' '|' | cut -c1-240)"
# 0.3.37 뜻 변경: 나머지는 지우지 않고 보관 폴더로(R2) · 부서 좌석 프로필은 이제 제자리(📌1 「안 남김」 → 박사님 범위 ⓑ)
left="$(gone_all "$C")"; [ -z "$left" ] && [ ! -e "$H/.cys/pack" ] && [ -f "$H/.cys/claude-default-dept-1/projects/x.jsonl" ] && grep -q '^KEPT_FAIL=0$' "$BASE/mac-h/out.txt" && grep -q '제자리로 되옮겼습니다' "$BASE/mac-h/out.txt" \
  && [ -f "$(ls -d "$H"/install-jarvis-backup-*/cys-home 2>/dev/null | head -1)/pack/f.txt" ]
t $? "[맥] ⓗ 나머지는 보관 폴더로(pack 보관본에) · 부서 프로필 제자리 · 못 지움 0 · 「제자리로 되옮겼습니다」" "남은 것:$left · $(tail -2 "$BASE/mac-h/out.txt" | tr '\n' '|')"
H="$(mac_run i 0)"
[ ! -e "$H/.cys" ]
t $? "[맥] ⓘ 표지 없음(옛 재설치·완전 삭제) → ~/.cys 통째로 원자리에서 사라진다(0.3.37 = 보관 폴더로)" "남음: $(ls -A "$H/.cys" 2>/dev/null | tr '\n' ' ')"
H="$(mac_run i2 0 'mv .cys/claude ./prof-real && ln -s "$PWD/prof-real" .cys/claude')"
[ ! -e "$H/.cys" ] && [ -f "$H/prof-real/CLAUDE.md" ]
t $? "[맥] ⓘ-2 표지 없음 + 프로필이 바로가기 → 종전대로 ~/.cys 통째로(바로가기 이름표만 · 대상 그대로)" "남음: $(ls -A "$H/.cys" 2>/dev/null | tr '\n' ' ') · $(tail -2 "$BASE/mac-i2/out.txt" | tr '\n' '|')"
H="$(mac_run j 1 'mkdir -p ../outside && printf outside > ../outside/keep.jsonl && rm -rf .cys/claude/projects && ln -s "$PWD/../outside" .cys/claude/projects')"
[ -L "$H/.cys/claude/projects" ] && [ "$(cat "$BASE/mac-j/outside/keep.jsonl" 2>/dev/null)" = "outside" ] && [ ! -e "$H/.cys/claude/CLAUDE.md" ]
t $? "[맥] ⓙ 바로가기 자체가 남고 바깥 폴더는 그대로" "$(tail -3 "$BASE/mac-j/out.txt" | tr '\n' '|')"
H="$(mac_run k 1 'chmod 000 .cys/claude/projects')"
chmod 755 "$H/.cys/claude/projects" 2>/dev/null
[ -f "$H/.cys/pack/f.txt" ] && [ -f "$H/.cys/claude/CLAUDE.md" ] && grep -q '^KEPT_FAIL=1$' "$BASE/mac-k/out.txt" && grep -qE '아무것도 지우지 않았습니다|지운 것 없음' "$BASE/mac-k/out.txt"
t $? "[맥] ⓚ 남길 자리를 못 열면 ~/.cys 를 하나도 안 지우고 못 지움 1" "$(tail -3 "$BASE/mac-k/out.txt" | tr '\n' '|')"

H="$(mac_run l 1 'rm -rf .cys/claude/projects && ln -s "$PWD/.cys" .cys/claude/projects')"
# 0.3.37 뜻 변경: R2 는 지우지 않는다 — pack 은 보관본으로 가고 「지움: ~/.cys」 줄은 없다(사전 훑기가 [안내] 로 알린다 · delete-path 반례①)
[ -f "$(ls -d "$H"/install-jarvis-backup-*/cys-home 2>/dev/null | head -1)/pack/f.txt" ] && ! grep -q '^  지움: ~/.cys' "$BASE/mac-l/out.txt"
t $? "[맥] ⓛ-2 ~/.cys 자신을 가리키는 바로가기 → 「지움」이라 말하지 않고 삭제 0(pack 은 보관본에)" "$(tail -3 "$BASE/mac-l/out.txt" | tr '\n' '|')"
H="$(mac_run m 1 'printf hist > .cys/pack/hist.jsonl && rm -f .cys/claude/history.jsonl && ln -s "$PWD/.cys/pack/hist.jsonl" .cys/claude/history.jsonl')"
[ "$(cat "$(ls -d "$H"/install-jarvis-backup-*/cys-home 2>/dev/null | head -1)/pack/hist.jsonl" 2>/dev/null)" = "hist" ]   # 0.3.37: 가리키던 곳은 보관본에 온전(삭제 0)
t $? "[맥] ⓜ-2 pack 안 파일을 가리키는 파일 바로가기 → 가리키는 곳을 안 지움(삭제 0)" "$(tail -2 "$BASE/mac-m/out.txt" | tr '\n' '|')"
H="$(mac_run n 1 'mv .cys/claude/projects .cys/claude/Projects')"
[ -f "$H/.cys/claude/Projects/-Users-emu-install-jarvis/s 1.jsonl" ] && [ ! -e "$H/.cys/pack" ]
t $? "[맥] ⓝ-2 대소문자가 다른 이름(Projects)도 남긴다" "$(tail -3 "$BASE/mac-n/out.txt" | tr '\n' '|')"
H="$(mac_run "o sp'q" 1)"
[ "$(digest "$H/.cys/claude" $KEEP5)" = "$(digest "$BASE/mac-ref/claude" $KEEP5)" ] && [ ! -e "$H/.cys/pack" ]
t $? "[맥] ⓞ 홈 경로에 빈칸·작은따옴표 → 남길 다섯 그대로 · 나머지 지움" "$(tail -2 "$BASE/mac-o sp'q/out.txt" | tr '\n' '|')"

H="$(mac_run p 1 'mkdir -p ../outside-saved && printf saved > ../outside-saved/s.jsonl && ln -s "$PWD/../outside-saved" .cys/claude/projects/saved')"
[ -L "$H/.cys/claude/projects/saved" ] && [ ! -e "$H/.cys/pack" ] && grep -q '^KEPT_FAIL=0$' "$BASE/mac-p/out.txt"
t $? "[맥] ⓟ 남길 폴더 안의 바로가기도 남는다(나머지 지움 · 못 지움 0)" "$(tail -3 "$BASE/mac-p/out.txt" | tr '\n' '|')"
H="$(mac_run q 1 'mv .cys/claude ./prof-real && ln -s "$PWD/prof-real" .cys/claude')"
[ -f "$H/.cys/pack/f.txt" ] && grep -q '^KEPT_FAIL=1$' "$BASE/mac-q/out.txt"
t $? "[맥] ⓠ ~/.cys/claude 자체가 바로가기 → 못 풂(삭제 0 · 못 지움 1)" "$(tail -3 "$BASE/mac-q/out.txt" | tr '\n' '|')"

# ═════════ [정적] ═════════
echo "== [정적] =="
code() { grep -vE '^\s*#' "$1"; }
code "$SRC/reinstall.sh" | grep -qE '^bash "\$RESET_FILE" --yes --keep-history \$KEEP_APP_ARG$' && code "$SRC/reinstall.sh" | grep -qE '^  bash "\$RESET_FILE" --list --keep-history \$KEEP_APP_ARG$' \
  && ! code "$SRC/reinstall.sh" | grep -E 'uname -m' | grep -q 'keep-history'
t $? "[정적] ⓛ 맥 재설치가 --keep-history 를 칩과 무관하게 늘 넘긴다(목록·지우기 두 곳)" "$(grep -n 'keep-history' "$SRC/reinstall.sh" | head -3 | tr '\n' '|')"
code "$SRC/reinstall.ps1" | grep -qE '^powershell -ExecutionPolicy Bypass -File \$ResetFile -KeepApp -KeepHistory -Yes$' && code "$SRC/reinstall.ps1" | grep -qE -- '-List -KeepApp -KeepHistory$'
t $? "[정적] ⓛ 윈 재설치가 -KeepHistory 를 넘긴다(목록·지우기 두 곳)" "$(grep -n 'KeepHistory' "$SRC/reinstall.ps1" | head -3 | tr '\n' '|')"
code "$RS" | grep -qE '^    --keep-history\)[[:space:]]+KEEP_HISTORY=1 ;;$' && code "$RP" | grep -qE '^param\(.*\[switch\]\$KeepHistory\)'
t $? "[정적] ⓛ 지우개가 표지를 받는다(맥 인자 갈래 · 윈 param)" "$(grep -n 'keep-history)\|KeepHistory)' "$RS" "$RP" | head -2 | tr '\n' '|')"
awk '/if \[ -f "\$CYS_CRED_FILE" \]; then/{p=1} p{print} p && /^  fi$/{exit}' "$RS" > "$BASE/mac-diag.txt"
awk '/KEEP_HISTORY" = "1" \]; then/{a=NR} /다시 하셔야 (합니다|할 수 있습니다)/{b=NR} /^    else$/{e=NR} END{exit !(a && e && b && a < e && e < b)}' "$BASE/mac-diag.txt"   # 0.3.37: 문장 끝 「할 수 있습니다」(로그인 파일은 보관하지 않고 지움)
t $? "[정적] ⓜ 맥 화면 = 「다시 하셔야 합니다」는 표지 없는 갈래에만" "$(grep -n '하셔야\|그대로 둡니다' "$BASE/mac-diag.txt" | tr '\n' '|')"
n="$(code "$RS" | grep -c 'delete-generic-password')"
[ "$n" = "1" ] && awk '/^purge_login_first\(\) \{/{p=1} p && /delete-generic-password/{f=1} p && /^}/{exit} END{exit !f}' "$RS" && grep -q '^KEYCHAIN_SERVICE="Claude Code-credentials"$' "$RS"
t $? "[정적] ⓝ 맥 열쇠고리 지우기 = 기본 이름 한 곳(purge_login_first 안 · --purge-login 한정) — 동료 항목은 재설치에서 남는다" "코드 줄 수 $n"

printf '\n통과 %s · 실패 %s\n' "$pass" "$fail"
[ "$fail" -eq 0 ]
