#!/bin/bash
# 0.3.36 — 재설치·삭제 때 자비스 작업 폴더를 지우지 않고 「install-jarvis-backup-<날짜-시각>」 으로 보관한다(두 OS).
#
# 재는 것(임시 홈에서만 · 제거기에서 보관 함수와 그 도우미만 떼어 부른다 — 진짜 제거기는 돌리지 않는다)
#   ⓐ 보관본이 생기고 · 옮긴 자료(다시 받는 dl·backup 제외)의 내용 지문이 옮기기 전과 같다 · 원래 자리는 비고 · 지운 수 0 · 못 지움 0 · 마지막 안내 1줄
#   ⓑ 같은 초에 두 번 → 뒤에 번호(-2) · 먼저 있던 보관본은 그대로(덮어쓰기 0)
#   ⓒ 옮기기 실패(부모 폴더 쓰기 막힘) → 아무것도 안 지움 · 원래 자리 그대로 · 못 지움으로 세지 않음(재설치가 그 위에 이어서 간다) · 안내 1줄
#   ⓓ 옮긴 뒤 수·크기가 다르면 → 「확인하지 못했습니다」 · 다시 받는 것도 안 지움 · 오래된 보관본 정리도 안 함
#   ⓔ 최근 3개만 — 이름 꼴 ∧ 우리 표식 둘 다 맞는 것만 정리 · 표식 없는 같은 이름 · 이름 다른 우리 폴더 · 바로가기는 무접촉
#   ⓕ 다음 지우기의 안전 확인이 보관본을 절대 통과시키지 않는다(이름 관문) · 새 설치도 보관본 자리를 작업 폴더로 안 받는다(J-HOME-01)
#   ⓖ 안에 따로 두신 자리(보존 경로)가 있으면 옮기지 않는다
#   ⓗ 부르는 자리: 안전 확인 통과 갈래가 보관 함수를 부른다(두 OS) · 끝 요약에 안내 1줄(두 갈래)
# 쓰는 법: bash tests/keep-backup-run.sh [--dir <install-master 자리>]   · rc 0 = 통과
set -u
HERE="$(cd "$(dirname "$0")" && pwd)"
DIR="$HERE/../install-master"
[ "${1:-}" = "--dir" ] && DIR="$2"
RS="$(cd "$DIR" && pwd)/reset-clean.sh"
RP="$(cd "$DIR" && pwd)/reset-clean.ps1"
BS="$(cd "$DIR" && pwd)/bootstrap.sh"
BASE="$(mktemp -d /tmp/keepbkXXXXXX)" || exit 2
trap 'chmod -R u+w "$BASE" 2>/dev/null; rm -rf "$BASE"' EXIT
pass=0; fail=0
t() { if [ "$1" -eq 0 ]; then pass=$((pass+1)); printf '  ok   %s\n' "$2"; else fail=$((fail+1)); printf '  FAIL %s  ← %s\n' "$2" "$3"; fi; }
MARK='jarvis-installer-owned v1'

# ── 맥: 함수 떼어 내기 ──
awk '/^(JARVIS_OWNER_MARK|JARVIS_HOME_BASENAME|JARVIS_BACKUP_PREFIX|JARVIS_BACKUP_KEEP|JARVIS_BACKUP_INSTALLER_NAMES)=/{print}
     /^(canon|preserved_under|preserve_covers|safe_jarvis_dir|tree_stat|is_jarvis_backup|installer_only_backup|prune_jarvis_backups|keep_jarvis_dir)\(\) \{/{f=1}
     f{print; if($0 ~ /^}/) f=0}' "$RS" > "$BASE/lib.sh"
grep -q '^keep_jarvis_dir() {' "$BASE/lib.sh"; t $? "[맥] 보관 함수(keep_jarvis_dir)가 제거기에 있다" "떼어 낸 것: $(grep -c '() {' "$BASE/lib.sh") 개"

mk_home() { # mk_home <홈> — 작업 폴더에 우리 표식 + 자료 + 다시 받는 것
  local J="$1/install-jarvis"
  mkdir -p "$J/dl" "$J/backup/cys.app.prev" "$J/notes/깊은 폴더"
  printf '%s\n' "$MARK" > "$J/.jarvis-owned"
  printf 'log line\n' > "$J/bootstrap.log"; printf "it's 자료 %s\n" "$1" > "$J/notes/깊은 폴더/메모 1.txt"
  head -c 70000 /dev/urandom > "$J/notes/blob.bin"; printf 'x' > "$J/dl/claude-installer.bin"; printf 'y' > "$J/backup/cys.app.prev/app"
}
digest() { # digest <폴더> — dl·backup 을 뺀 파일 경로·내용 지문(상대 경로 기준)
  ( cd "$1" 2>/dev/null && find . -type f ! -path './dl/*' ! -path './backup/*' -print0 | LC_ALL=C sort -z | xargs -0 shasum -a 256 ) 2>/dev/null | shasum -a 256 | cut -c1-16
}
mac_keep() { # mac_keep <홈> [추가 셸 줄] → 결과 한 줄 「REMOVED|KEPT_FAIL|NOTE」 · 화면 = <홈>.say
  env -i PATH="$BASE/bin:/usr/bin:/bin:/usr/sbin:/sbin" HOME="$1" LIB="$BASE/lib.sh" EXTRA="${2:-}" bash -c '
    say(){ printf "%s\n" "$*" >> "$HOME.say"; }; short(){ printf "%s" "$1"; }
    drop_dir(){ if rm -rf "$1" 2>/dev/null && [ ! -e "$1" ]; then REMOVED=$((REMOVED+1)); return 0; fi; KEPT_FAIL=$((KEPT_FAIL+1)); return 0; }   # 진짜 drop_dir 처럼: 실패를 세지만 rc 는 0(진짜의 흔한 실패 갈래 · 적대 검토 2회차 반례)
    REMOVED=0; KEPT_FAIL=0; PRESERVED=0; PRESERVE_CANON=""; PRESERVE_CANON_FAIL=0
    . "$LIB"; eval "$EXTRA"
    keep_jarvis_dir "$HOME/install-jarvis"
    printf "%s|%s|%s" "$REMOVED" "$KEPT_FAIL" "$BACKUP_NOTE"' 2>/dev/null
}
backups() { find "$1" -mindepth 1 -maxdepth 1 -name 'install-jarvis-backup-*' 2>/dev/null | LC_ALL=C sort; }

# ⓐ
H="$BASE/a"; mk_home "$H"; d0="$(digest "$H/install-jarvis")"
r="$(mac_keep "$H")"; b="$(backups "$H")"
[ "$(printf '%s\n' "$b" | grep -c .)" = "1" ] && basename "$b" | grep -qE '^install-jarvis-backup-[0-9]{8}-[0-9]{6}$' && [ ! -e "$H/install-jarvis" ]
t $? "[ⓐ 맥] 보관본 1개(이름 = install-jarvis-backup-날짜-시각) · 원래 자리는 비었다" "$(basename "${b:-없음}") · 원래 자리 $( [ -e "$H/install-jarvis" ] && echo 있음 || echo 없음)"
[ -n "$b" ] && [ "$(digest "$b")" = "$d0" ] && [ -f "$b/.jarvis-owned" ]; t $? "[ⓐ 맥] 옮긴 자료의 내용 지문 = 옮기기 전(표식 포함)" "전 $d0 · 뒤 $( [ -n "$b" ] && digest "$b")"
[ -n "$b" ] && [ ! -e "$b/dl" ] && [ ! -e "$b/backup" ]; t $? "[ⓐ 맥] 다시 받을 수 있는 dl·backup 은 보관본에서 뺐다" "$(ls -A "$b" 2>/dev/null | tr '\n' ' ')"
case "$r" in "0|0|이전 자비스 자료는 "*" 에 그대로 보관해 두었습니다.") true ;; *) false ;; esac; t $? "[ⓐ 맥] 지운 수 0 · 못 지움 0 · 마지막 안내 1줄(왕초보 말투)" "$r"

# ⓑ 같은 초(시계를 고정한 가짜 date) · 먼저 있던 보관본은 덮지 않는다
mkdir -p "$BASE/bin"; printf '#!/bin/bash\necho 20260925-214500\n' > "$BASE/bin/date"; chmod +x "$BASE/bin/date"
H="$BASE/b"; mk_home "$H"; mkdir -p "$H/install-jarvis-backup-20260925-214500"; printf '%s\n' "$MARK" > "$H/install-jarvis-backup-20260925-214500/.jarvis-owned"; printf '먼저' > "$H/install-jarvis-backup-20260925-214500/first.txt"
r="$(mac_keep "$H")"
[ -d "$H/install-jarvis-backup-20260925-214500-2" ] && [ "$(cat "$H/install-jarvis-backup-20260925-214500/first.txt" 2>/dev/null)" = "먼저" ] && [ ! -e "$H/install-jarvis-backup-20260925-214500/notes" ]
t $? "[ⓑ 맥] 같은 이름이 있으면 -2 로 · 먼저 있던 보관본 무접촉" "$(backups "$H" | xargs -n1 basename 2>/dev/null | tr '\n' ' ')"
rm -f "$BASE/bin/date"

# ⓒ 옮기기 실패 — 부모 폴더 쓰기 막힘(다른 볼륨·잠김과 같은 갈래: 이름 바꾸기 실패)
H="$BASE/c"; mk_home "$H"; d0="$(digest "$H/install-jarvis")"; chmod 555 "$H"
r="$(mac_keep "$H")"; chmod 755 "$H"
[ -d "$H/install-jarvis/dl" ] && [ "$(digest "$H/install-jarvis")" = "$d0" ] && [ -z "$(backups "$H")" ]
t $? "[ⓒ 맥] 옮기기 실패 → 아무것도 안 지움(dl 까지 그대로) · 보관본 0" "$(ls -A "$H/install-jarvis" 2>/dev/null | tr '\n' ' ')"
case "$r" in "0|0|이전 자비스 자료는 옮기지 못해 "*"지운 것은 없습니다.") true ;; *) false ;; esac; t $? "[ⓒ 맥] 못 지움으로 세지 않음(재설치가 이어서 간다) · 안내 1줄" "$r"

# ⓓ 옮긴 뒤 수·크기 불일치(셈 도구가 두 번째에 다른 값을 내게 한다)
H="$BASE/d"; mk_home "$H"
mkdir -p "$H/install-jarvis-backup-20200101-000000"; printf '%s\n' "$MARK" > "$H/install-jarvis-backup-20200101-000000/.jarvis-owned"
for i in 1 2 3; do mkdir -p "$H/install-jarvis-backup-2020010$i-000001"; printf '%s\n' "$MARK" > "$H/install-jarvis-backup-2020010$i-000001/.jarvis-owned"; done
# ⚠셈은 $( ) 서브셸 안에서 불린다 — 횟수는 변수가 아니라 파일로 센다(변수는 서브셸에서 사라진다)
r="$(mac_keep "$H" 'eval "orig_$(declare -f tree_stat)"; tree_stat(){ echo x >> "$HOME.tsn"; if [ "$(grep -c . "$HOME.tsn")" -ge 2 ]; then echo "1 1"; else orig_tree_stat "$@"; fi; }')"
nb="$(backups "$H" | grep -c .)"; nb2="$(backups "$H" | xargs -I{} sh -c 'test -d "{}/dl" && echo "{}"' | grep -c .)"
case "$r" in "0|0|"*"확인하지 못했습니다. 아무것도 지우지 않았습니다.") true ;; *) false ;; esac; t $? "[ⓓ 맥] 옮긴 뒤 수·크기 다름 → 「확인하지 못했습니다 · 아무것도 지우지 않았습니다」" "$r"
[ "$nb" = "5" ] && [ "$nb2" = "1" ]; t $? "[ⓓ 맥] 불일치면 dl 도 안 지우고 오래된 보관본 정리도 안 한다(보관본 5 그대로)" "보관본 $nb · dl 남은 보관본 $nb2"

# ⓔ 최근 3개만 · 두 축
H="$BASE/e"; mk_home "$H"
for s in 20200101-000000 20200102-000000 20200103-000000 20200104-000000; do mkdir -p "$H/install-jarvis-backup-$s"; printf '%s\n' "$MARK" > "$H/install-jarvis-backup-$s/.jarvis-owned"; done
mkdir -p "$H/install-jarvis-backup-20190101-000000"                       # 이름 맞음 · 표식 없음(남의 것)
mkdir -p "$H/install-jarvis-old"; printf '%s\n' "$MARK" > "$H/install-jarvis-old/.jarvis-owned"   # 표식 있음 · 이름 꼴 아님
mkdir -p "$BASE/elsewhere"; printf '%s\n' "$MARK" > "$BASE/elsewhere/.jarvis-owned"; ln -s "$BASE/elsewhere" "$H/install-jarvis-backup-20180101-000000"   # 바로가기
r="$(mac_keep "$H")"
left="$(backups "$H" | xargs -n1 basename | tr '\n' ' ')"
# 방금 것은 작업(notes)이 들어 셈에서 빠진다 ⇒ 설치기 이름만 든 4개 가운데 최근 3개가 남는다
[ -d "$H/install-jarvis-backup-20200102-000000" ] && [ -d "$H/install-jarvis-backup-20200103-000000" ] && [ -d "$H/install-jarvis-backup-20200104-000000" ] && [ ! -e "$H/install-jarvis-backup-20200101-000000" ]
t $? "[ⓔ 맥] 설치기 이름만 든 보관본은 최근 3개만 · 가장 오래된 것부터 정리" "$left"
[ -d "$H/install-jarvis-backup-20190101-000000" ] && [ -d "$H/install-jarvis-old" ] && [ -L "$H/install-jarvis-backup-20180101-000000" ] && [ -f "$BASE/elsewhere/.jarvis-owned" ]
t $? "[ⓔ 맥] 표식 없는 같은 이름 · 이름 다른 우리 폴더 · 바로가기(와 가리키는 자리)는 무접촉" "$left"

# ⓕ 다음 지우기 · 새 설치가 보관본을 작업 폴더로 안 받는다
BK="$(backups "$BASE/a" | head -1)"
env -i PATH=/usr/bin:/bin LIB="$BASE/lib.sh" P="$BK" bash -c '. "$LIB"; safe_jarvis_dir "$P"' >/dev/null 2>&1; [ $? -ne 0 ]
t $? "[ⓕ 맥] 다음 지우기의 안전 확인이 보관본을 거부한다(표식이 있어도 · 이름 관문)" "$BK"
out="$(env -i PATH=/usr/bin:/bin:/usr/sbin:/sbin HOME="$BASE/a" JARVIS_HOME="$BK" JARVIS_NO_PROGRESS=1 perl -e 'alarm 60; exec @ARGV' /bin/bash "$BS" --detect-only </dev/null 2>&1)"
printf '%s' "$out" | grep -q 'J-HOME-01'; t $? "[ⓕ 맥] 새 설치에 보관본 자리를 줘도 작업 폴더로 안 받는다(J-HOME-01)" "$(printf '%s' "$out" | grep -m1 -E 'J-HOME|진단' )"

# ⓖ 보존 경로가 안에 있으면 옮기지 않는다
H="$BASE/g"; mk_home "$H"; mkdir -p "$H/install-jarvis/forum"
r="$(mac_keep "$H" "PRESERVE_CANON=\"\$(cd -P \"\$HOME/install-jarvis/forum\" && pwd -P)
\"")"
[ -d "$H/install-jarvis/forum" ] && [ -d "$H/install-jarvis/dl" ] && [ -z "$(backups "$H")" ]; t $? "[ⓖ 맥] 안에 따로 두신 자리가 있으면 옮기지 않고 그대로(지운 것 없음)" "$r"

pristine() { mkdir -p "$1"; printf '%s\n' "$MARK" > "$1/.jarvis-owned"; printf 'l\n' > "$1/bootstrap.log"; }   # 설치기 이름만 든 보관본
# ⓘ 작업이 든 보관본은 정리하지 않는다(연속 재설치 반례) · 설치기 이름만 든 것만 최근 3개
H="$BASE/i"; mk_home "$H"
mkdir -p "$H/install-jarvis-backup-20200101-000000"; printf '%s\n' "$MARK" > "$H/install-jarvis-backup-20200101-000000/.jarvis-owned"; printf '몇 주 치 작업' > "$H/install-jarvis-backup-20200101-000000/보고서.md"; mkdir -p "$H/install-jarvis-backup-20200101-000000/_round"
for s2 in 20200102-000000 20200103-000000 20200104-000000 20200105-000000 20200106-000000; do pristine "$H/install-jarvis-backup-$s2"; done
r="$(mac_keep "$H")"
[ "$(cat "$H/install-jarvis-backup-20200101-000000/보고서.md" 2>/dev/null)" = "몇 주 치 작업" ] && [ ! -e "$H/install-jarvis-backup-20200102-000000" ] && [ ! -e "$H/install-jarvis-backup-20200103-000000" ] && [ -d "$H/install-jarvis-backup-20200104-000000" ] && [ -d "$H/install-jarvis-backup-20200106-000000" ]
t $? "[ⓘ 맥] 작업이 든 가장 오래된 보관본은 남고 · 설치기 이름만 든 보관본만 최근 3개로 정리" "$(backups "$H" | xargs -n1 basename | tr '\n' ' ')"
# ⓙ dl·backup 안 사용자 파일은 남는다 · 설치기 산출물만 뺀다
H="$BASE/j"; mk_home "$H"; printf 'pdf' > "$H/install-jarvis/dl/강의자료.pdf"; printf 'm' > "$H/install-jarvis/backup/claude-메모.md"; mkdir -p "$H/install-jarvis/backup/보고서-백업"; printf 'v3' > "$H/install-jarvis/backup/보고서-백업/보고서-v3.md"
r="$(mac_keep "$H")"; b="$(backups "$H")"
[ "$(cat "$b/dl/강의자료.pdf" 2>/dev/null)" = "pdf" ] && [ -f "$b/backup/claude-메모.md" ] && [ "$(cat "$b/backup/보고서-백업/보고서-v3.md" 2>/dev/null)" = "v3" ] && [ ! -e "$b/dl/claude-installer.bin" ] && [ ! -e "$b/backup/cys.app.prev" ]
t $? "[ⓙ 맥] dl·backup 안 사용자 파일은 그대로 · 설치기 산출물(claude-*·cys*)만 뺐다" "$(cd "$b" 2>/dev/null && find dl backup 2>/dev/null | tr '\n' ' ')"
# ⓚ 오래된 보관본 정리가 실패해도 못 지움으로 세지 않는다(재설치 rc 7 반례) · 안내 1줄
H="$BASE/k"; mk_home "$H"
for s2 in 20200101-000000 20200102-000000 20200103-000000 20200104-000000; do pristine "$H/install-jarvis-backup-$s2"; done
chmod 555 "$H/install-jarvis-backup-20200101-000000"
r="$(mac_keep "$H")"; chmod 755 "$H/install-jarvis-backup-20200101-000000"
case "$r" in "0|0|"*"보관해 두었습니다.") true ;; *) false ;; esac && grep -q '오래된 보관본을 정리하지 못했습니다' "$H.say"
t $? "[ⓚ 맥] 정리 실패 = 못 지움 0 · 안내 1줄(재설치가 멈추지 않는다)" "$r · $(grep -c '정리하지 못했습니다' "$H.say" 2>/dev/null)"
# ⓛ 읽지 못하는 하위가 있으면 셈이 실패 → 옮기지 않고 아무것도 안 지운다(셈 상수 변이 반례)
H="$BASE/l"; mk_home "$H"; mkdir -p "$H/install-jarvis/notes/잠금"; printf 's' > "$H/install-jarvis/notes/잠금/비밀.txt"; chmod 000 "$H/install-jarvis/notes/잠금"
r="$(mac_keep "$H")"; chmod 755 "$H/install-jarvis/notes/잠금"
[ -d "$H/install-jarvis/dl" ] && [ -z "$(backups "$H")" ]; t $? "[ⓛ 맥] 읽지 못하는 하위가 있으면 옮기지 않고 그대로(지운 것 없음)" "$r"
# ⓜ 시계가 뒤로 가도 방금 만든 보관본은 남긴다
printf '#!/bin/bash\necho 20000101-000000\n' > "$BASE/bin/date"; chmod +x "$BASE/bin/date"
H="$BASE/m"; mkdir -p "$H/install-jarvis/dl"; printf '%s\n' "$MARK" > "$H/install-jarvis/.jarvis-owned"; printf 'l' > "$H/install-jarvis/bootstrap.log"; printf 'x' > "$H/install-jarvis/dl/claude-x"
for s2 in 20200101-000000 20200102-000000 20200103-000000; do pristine "$H/install-jarvis-backup-$s2"; done
r="$(mac_keep "$H")"; rm -f "$BASE/bin/date"
[ -d "$H/install-jarvis-backup-20000101-000000" ] && [ ! -e "$H/install-jarvis-backup-20200101-000000" ]
t $? "[ⓜ 맥] 시계가 뒤로 가도 방금 만든 보관본은 남기고 그다음 오래된 것을 정리" "$(backups "$H" | xargs -n1 basename | tr '\n' ' ')"
# ⓝ 보존 경로가 작업 폴더 자신이면 옮기지 않는다
H="$BASE/n"; mk_home "$H"
r="$(mac_keep "$H" "PRESERVE_CANON=\"\$(cd -P \"\$HOME/install-jarvis\" && pwd -P)
\"")"
[ -d "$H/install-jarvis/dl" ] && [ -z "$(backups "$H")" ]; t $? "[ⓝ 맥] 보존 경로가 작업 폴더 자신이면 옮기지 않는다" "$r"

# ⓞ dl·backup 이 링크면 따라 들어가지 않는다(가리키는 곳의 claude-*·cys* 무접촉)
H="$BASE/o"; mk_home "$H"; rm -rf "$H/install-jarvis/dl" "$H/install-jarvis/backup"; mkdir -p "$BASE/o-dl" "$BASE/o-bk"
printf 'z' > "$BASE/o-dl/claude-conversations-export.zip"; printf 'p' > "$BASE/o-dl/cys-분기보고서.pdf"; printf 'b' > "$BASE/o-bk/cys-app-copy"
ln -s "$BASE/o-dl" "$H/install-jarvis/dl"; ln -s "$BASE/o-bk" "$H/install-jarvis/backup"
r="$(mac_keep "$H")"
[ -f "$BASE/o-dl/claude-conversations-export.zip" ] && [ -f "$BASE/o-dl/cys-분기보고서.pdf" ] && [ -f "$BASE/o-bk/cys-app-copy" ]
t $? "[ⓞ 맥] dl·backup 이 링크면 가리키는 곳의 파일은 무접촉" "$(ls "$BASE/o-dl" "$BASE/o-bk" 2>/dev/null | tr '\n' ' ') · $r"

# ⓗ 부르는 자리(주석 걷고)
r="$(python3 - "$RS" "$RP" <<'PY'
import re, sys
sh = open(sys.argv[1], encoding="utf-8").read(); ps = open(sys.argv[2], encoding="utf-8-sig").read()
nc = lambda t: "\n".join(l.split("#", 1)[0] for l in t.splitlines())
s, p = nc(sh), nc(ps)
o = []
o.append("sh-call=" + ("1" if re.search(r'elif safe_jarvis_dir "\$JARVIS_HOME"; then\s*\n\s*keep_jarvis_dir "\$JARVIS_HOME"\s*\n', s) and 'drop_dir "$JARVIS_HOME"' not in s else "0"))
o.append("ps-call=" + ("1" if re.search(r'elseif \(Test-SafeJarvisDir \$JarvisDir\) \{\s*\n\s*Keep-JarvisDir \$JarvisDir\s*\n', p) and "Drop '자비스 작업 폴더' $JarvisDir" not in p else "0"))
o.append("sh-note=" + str(len(re.findall(r'\[ -n "\$BACKUP_NOTE" \] && say "    \$BACKUP_NOTE"', s))))
o.append("ps-note=" + str(len(re.findall(r"if \(\$script:BackupNote\) \{ Write-Host \('    ' \+ \$script:BackupNote\) \}", p))))
o.append("sh-rename=" + ("1" if "rename($ARGV[0], $ARGV[1])" in sh and not re.search(r'^\s*mv\b[^\n]*JARVIS', s, re.M) else "0"))
print(" ".join(o))
PY
)"
case "$r" in *sh-call=1*ps-call=1*sh-note=2*ps-note=2*sh-rename=1*) true ;; *) false ;; esac
t $? "[ⓗ 두 OS] 안전 확인 통과 갈래가 보관 함수를 부른다(작업 폴더 지우기 0) · 끝 요약 두 갈래에 안내 1줄 · 맥은 이름 바꾸기만(mv 0)" "$r"

# ── 윈(pwsh 7): 제거기에서 함수만 떼어 불러 같은 축을 잰다 ──
PW="$(command -v pwsh 2>/dev/null)"
if [ -z "$PW" ]; then
  t 1 "[윈] pwsh 가 있어야 윈 보관 동작을 잰다(건너뜀 ≠ 통과)" "pwsh 없음"
else
  cat > "$BASE/win.ps1" <<'PS1'
param($Src, $Home2, $Mode)
$ast = [System.Management.Automation.Language.Parser]::ParseFile($Src, [ref]$null, [ref]$null)
$want = 'Read-TextUtf8','Resolve-RealPath','Get-PreservedUnder','Path-IsUnder','Path-IsSame','Norm-Path','Test-PreserveCovers','Test-SafeJarvisDir','Get-ReparseAncestor','Get-TreeStat','Test-JarvisBackup','Test-InstallerOnlyBackup','Remove-OldJarvisBackups','Keep-JarvisDir'
foreach ($f in $ast.FindAll({ param($n) $n -is [System.Management.Automation.Language.FunctionDefinitionAst] }, $true)) { if ($want -contains $f.Name) { . ([scriptblock]::Create($f.Extent.Text)) } }
# 최상위 상수 대입 줄(줄 머리에서 시작)만 글자로 뽑아 실행한다
foreach ($ln in [System.IO.File]::ReadAllLines($Src)) {
  if ($ln -match '^\$(JarvisOwnerMark|JarvisHomeBaseName|JarvisBackupPrefix|JarvisBackupKeep|JarvisBackupInstallerNames)\s*=') { . ([scriptblock]::Create($ln)) }
}
if (-not $JarvisBackupPrefix) { throw 'no prefix' }
function Short($p) { return [string]$p }
function Drop($l, $p) { try { Remove-Item -LiteralPath $p -Recurse -Force -ErrorAction Stop; $script:Removed++ } catch { $script:KeptFail++ } }   # 진짜 Drop 처럼 실패를 센다
$script:Removed = 0; $script:KeptFail = 0; $script:PreserveCanon = @(); $script:PreserveCanonFail = @(); $script:BackupNote = ''
if ($Mode -eq 'clockback') { function Get-Date { [datetime]'2000-01-01' } }
if ($Mode -eq 'self') { $script:PreserveCanon = @((Resolve-RealPath (Join-Path $Home2 'install-jarvis'))) }
if ($Mode -eq 'safe') { if (Test-SafeJarvisDir $Home2) { 'SAFE' } else { 'REFUSED' }; return }
if ($Mode -eq 'mismatch') { $script:tsn = 0; ${function:orig} = ${function:Get-TreeStat}; function Get-TreeStat($p) { $script:tsn++; if ($script:tsn -ge 2) { '1 1' } else { orig $p } } }
Keep-JarvisDir (Join-Path $Home2 'install-jarvis')
'{0}|{1}|{2}' -f $script:Removed, $script:KeptFail, $script:BackupNote
PS1
  win_keep() { perl -e 'alarm 90; exec @ARGV' "$PW" -NoProfile -File "$BASE/win.ps1" -Src "$RP" -Home2 "$1" -Mode "${2:-}" 2>/dev/null | tail -1; }
  H="$BASE/wa"; mk_home "$H"; d0="$(digest "$H/install-jarvis")"; r="$(win_keep "$H")"; b="$(backups "$H")"
  [ "$(printf '%s\n' "$b" | grep -c .)" = "1" ] && [ ! -e "$H/install-jarvis" ] && [ "$(digest "$b")" = "$d0" ] && [ ! -e "$b/dl" ] && [ ! -e "$b/backup" ]
  t $? "[ⓐ 윈] 보관본 1개 · 내용 지문 같음 · 원래 자리 비고 · dl·backup 뺌" "$(basename "${b:-없음}") · $r"
  case "$r" in "0|0|이전 자비스 자료는 "*" 에 그대로 보관해 두었습니다.") true ;; *) false ;; esac; t $? "[ⓐ 윈] 지운 수 0 · 못 지움 0 · 마지막 안내 1줄" "$r"
  H="$BASE/wc"; mk_home "$H"; d0="$(digest "$H/install-jarvis")"; chmod 555 "$H"; r="$(win_keep "$H")"; chmod 755 "$H"
  [ -d "$H/install-jarvis/dl" ] && [ "$(digest "$H/install-jarvis")" = "$d0" ] && [ -z "$(backups "$H")" ]
  t $? "[ⓒ 윈] 옮기기 실패 → 아무것도 안 지움 · 보관본 0" "$r"
  case "$r" in "0|0|이전 자비스 자료는 옮기지 못해 "*) true ;; *) false ;; esac; t $? "[ⓒ 윈] 못 지움으로 세지 않음 · 안내 1줄" "$r"
  H="$BASE/wd"; mk_home "$H"; for i in 1 2 3 4; do mkdir -p "$H/install-jarvis-backup-2020010$i-000000"; printf '%s\n' "$MARK" > "$H/install-jarvis-backup-2020010$i-000000/.jarvis-owned"; done
  r="$(win_keep "$H" mismatch)"; nb="$(backups "$H" | grep -c .)"
  case "$r" in "0|0|"*"확인하지 못했습니다. 아무것도 지우지 않았습니다.") true ;; *) false ;; esac && [ "$nb" = "5" ]
  t $? "[ⓓ 윈] 옮긴 뒤 수·크기 다름 → 확인 실패 안내 · 정리 0(보관본 5 그대로)" "$r · 보관본 $nb"
  H="$BASE/we"; mk_home "$H"
  for s in 20200101-000000 20200102-000000 20200103-000000 20200104-000000; do mkdir -p "$H/install-jarvis-backup-$s"; printf '%s\n' "$MARK" > "$H/install-jarvis-backup-$s/.jarvis-owned"; done
  mkdir -p "$H/install-jarvis-backup-20190101-000000" "$H/install-jarvis-old"; printf '%s\n' "$MARK" > "$H/install-jarvis-old/.jarvis-owned"
  r="$(win_keep "$H")"
  [ -d "$H/install-jarvis-backup-20200102-000000" ] && [ -d "$H/install-jarvis-backup-20200103-000000" ] && [ -d "$H/install-jarvis-backup-20200104-000000" ] && [ ! -e "$H/install-jarvis-backup-20200101-000000" ] && [ -d "$H/install-jarvis-backup-20190101-000000" ] && [ -d "$H/install-jarvis-old" ]
  t $? "[ⓔ 윈] 최근 3개만 · 표식 없는 같은 이름 · 이름 다른 우리 폴더 무접촉" "$(backups "$H" | xargs -n1 basename | tr '\n' ' ')"
  H="$BASE/wi"; mk_home "$H"; mkdir -p "$H/install-jarvis-backup-20200101-000000/_round"; printf '%s\n' "$MARK" > "$H/install-jarvis-backup-20200101-000000/.jarvis-owned"; printf '작업' > "$H/install-jarvis-backup-20200101-000000/보고서.md"
  for s2 in 20200102-000000 20200103-000000 20200104-000000 20200105-000000 20200106-000000; do pristine "$H/install-jarvis-backup-$s2"; done
  r="$(win_keep "$H")"
  [ -f "$H/install-jarvis-backup-20200101-000000/보고서.md" ] && [ ! -e "$H/install-jarvis-backup-20200102-000000" ] && [ ! -e "$H/install-jarvis-backup-20200103-000000" ] && [ -d "$H/install-jarvis-backup-20200104-000000" ]
  t $? "[ⓘ 윈] 작업이 든 보관본은 남고 · 설치기 이름만 든 것만 최근 3개" "$(backups "$H" | xargs -n1 basename | tr '\n' ' ')"
  H="$BASE/wj"; mk_home "$H"; printf 'pdf' > "$H/install-jarvis/dl/강의자료.pdf"; printf 'm' > "$H/install-jarvis/backup/claude-메모.md"; mkdir -p "$H/install-jarvis/backup/보고서-백업"; printf 'v3' > "$H/install-jarvis/backup/보고서-백업/v3.md"
  r="$(win_keep "$H")"; b="$(backups "$H")"
  [ -f "$b/dl/강의자료.pdf" ] && [ -f "$b/backup/claude-메모.md" ] && [ -f "$b/backup/보고서-백업/v3.md" ] && [ ! -e "$b/dl/claude-installer.bin" ] && [ ! -e "$b/backup/cys.app.prev" ]
  t $? "[ⓙ 윈] dl·backup 안 사용자 파일은 그대로 · 설치기 산출물만 뺐다" "$(cd "$b" 2>/dev/null && find dl backup 2>/dev/null | tr '\n' ' ')"
  H="$BASE/wk"; mk_home "$H"; for s2 in 20200101-000000 20200102-000000 20200103-000000 20200104-000000; do pristine "$H/install-jarvis-backup-$s2"; done
  chmod 555 "$H/install-jarvis-backup-20200101-000000"; r="$(win_keep "$H")"; chmod 755 "$H/install-jarvis-backup-20200101-000000"
  case "$r" in "0|0|"*"보관해 두었습니다.") true ;; *) false ;; esac; t $? "[ⓚ 윈] 정리 실패 = 못 지움 0" "$r"
  H="$BASE/wl"; mk_home "$H"; mkdir -p "$H/install-jarvis/notes/잠금"; printf 's' > "$H/install-jarvis/notes/잠금/x"; chmod 000 "$H/install-jarvis/notes/잠금"
  r="$(win_keep "$H")"; chmod 755 "$H/install-jarvis/notes/잠금"
  [ -d "$H/install-jarvis/dl" ] && [ -z "$(backups "$H")" ]; t $? "[ⓛ 윈] 읽지 못하는 하위가 있으면 옮기지 않는다" "$r"
  H="$BASE/wm"; mkdir -p "$H/install-jarvis/dl"; printf '%s\n' "$MARK" > "$H/install-jarvis/.jarvis-owned"; printf 'l' > "$H/install-jarvis/bootstrap.log"; printf 'x' > "$H/install-jarvis/dl/claude-x"
  for s2 in 20200101-000000 20200102-000000 20200103-000000; do pristine "$H/install-jarvis-backup-$s2"; done
  r="$(win_keep "$H" clockback)"
  [ -d "$H/install-jarvis-backup-20000101-000000" ] && [ ! -e "$H/install-jarvis-backup-20200101-000000" ]
  t $? "[ⓜ 윈] 시계가 뒤로 가도 방금 만든 보관본은 남긴다" "$(backups "$H" | xargs -n1 basename | tr '\n' ' ')"
  H="$BASE/wo"; mk_home "$H"; rm -rf "$H/install-jarvis/dl"; mkdir -p "$BASE/wo-dl"; printf 'z' > "$BASE/wo-dl/claude-export.zip"; ln -s "$BASE/wo-dl" "$H/install-jarvis/dl"
  r="$(win_keep "$H")"; [ -f "$BASE/wo-dl/claude-export.zip" ]; t $? "[ⓞ 윈] dl 이 링크면 가리키는 곳의 파일은 무접촉" "$r"
  H="$BASE/wn"; mk_home "$H"; r="$(win_keep "$H" self)"
  [ -d "$H/install-jarvis/dl" ] && [ -z "$(backups "$H")" ]; t $? "[ⓝ 윈] 보존 경로가 작업 폴더 자신이면 옮기지 않는다" "$r"
  BK="$(backups "$BASE/wa" | head -1)"; r="$(perl -e 'alarm 60; exec @ARGV' "$PW" -NoProfile -File "$BASE/win.ps1" -Src "$RP" -Home2 "$BK" -Mode safe 2>/dev/null | tail -1)"
  [ "$r" = "REFUSED" ]; t $? "[ⓕ 윈] 다음 지우기의 안전 확인이 보관본을 거부한다(이름 관문)" "$r"
fi

echo "== 합계: ok $pass · FAIL $fail =="
[ "$fail" -eq 0 ]
