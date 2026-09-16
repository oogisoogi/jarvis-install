#!/bin/bash
# 맥 [6/10] 실행 비트 게이트 — 「설치를 마쳤습니다」를 찍었는데 cys 가 실제로는 실행되지 않는 상태를 붉게 잡는다.
#
# ★왜 (2026-09-16 실기 2대 동일 실패 · 전제 사실): 라이브 0.3.19 가 핀한 v1.0.0 맥 zip 의 Contents/MacOS/cys·cysd 에
#   실행 비트가 없었다(-rw-r--r--). [6/10] 은 지문·서명·판본만 보고 「설치를 마쳤습니다」를 찍었다 —
#   실행 비트는 서명 대상이 아니라서(모드 비트는 CDHash 에 안 들어간다) 서명·CDHash 검사가 이 결함을 원리적으로 못 본다.
#   ⇒ 「완료」 문구와 「실제로 돈다」를 같은 시험 안에서 대조해야 한다.
#
# 무엇을 하는가: 실물 bootstrap.sh 를 함수 묶음으로 읽고(JARVIS_LIB_ONLY=1) step_install_cys 를 **가짜 zip** 으로 끝까지 부른다.
#   가짜 zip = 발행 자산과 같은 모양(최상위 cysr.app · Contents/MacOS/cys·cys-app·cysd · ditto -c -k --keepParent) ·
#   판본 = 그 bootstrap.sh 의 CYS_FORK_VERSION · CDHash 는 가짜 codesign 이 그 bootstrap.sh 의 CYS_FORK_CDHASH 를 답한다.
#   시나리오 셋:
#     F1 nox   — 실행 비트 없음(오늘 실물의 모양) · 비트만 주면 돈다  → 요구: 「마쳤습니다」 ∧ 넣은 cys·cysd 가 -x ∧ cys --version 이 판본을 답한다
#     F2 dead  — 실행 비트는 있으나 cys 가 돌지 않는다(비트로 못 고침) → 요구: 「마쳤습니다」 를 찍지 않는다
#     F0 good  — 멀쩡한 자산(대조군)                                 → 요구: 「마쳤습니다」 ∧ 돈다 (검사기가 모든 것을 막아 초록인 것을 거른다)
#
# 쓰는 법:
#   bash tests/mac-install-mutate.sh [--src <install-master 자리>] [--defect-src <벨트 없는 install-master 자리>] [--mutants]
#     --src        검사 대상(기본 = 이 저장소의 install-master)
#     --defect-src 벨트가 없는 판(예: 5a1cd67 사본) — **F1 이 붉어야 한다**(검사기가 대상을 때린다는 증명). 있으면 함께 잰다.
#     --mutants    대상 사본에 벨트 제거 뮤턴트를 걸어 F1/F2 가 붉어지는지 잰다(아래 MUTANTS 표)
#   rc 0 = 전건 통과 · 1 = 실패 있음 · 2 = 잴 수 없음(이 계정이 /Applications 에 못 쓴다 등 — 통과라 말하지 않는다)
#
# ⛔바깥에 닿지 않는다: 설치 자리(CYS_FORK_APP·CYS_OLD_APP)는 mktemp -d 안으로 돌린다 · codesign·launchctl·osascript·sudo·open 은
#   가짜(기록만) · 실제 /Applications/cysr.app·cys.app 의 inode·mtime 이 안 변했음을 시험이 스스로 단언한다.
# ⚠여기서 안 재는 것: 관리자 권한 갈래(osascript) · 원작자 판(dmg) 갈래 · 옛 판 바꿔 넣기(끄기 포함) · 진짜 서명 검사.
export JARVIS_NO_PROGRESS=1   # 흉내·검사는 라이브 서버로 진행 이벤트를 보내지 않는다(checks.sh 와 같은 레버)
set -u
HERE="$(cd "$(dirname "$0")" && pwd)"
SRC="$HERE/../install-master"; DEFECT=""; DO_MUT=0
while [ $# -gt 0 ]; do
  case "$1" in
    --src) SRC="$2"; shift 2 ;;
    --defect-src) DEFECT="$2"; shift 2 ;;
    --mutants) DO_MUT=1; shift ;;
    *) echo "모르는 인자: $1" >&2; exit 2 ;;
  esac
done
SRC="$(cd "$SRC" && pwd)" || exit 2
BASE="$(mktemp -d -t mac-install-mutate)" || exit 2
BASE="$(cd "$BASE" && pwd -P)"
trap 'rm -rf "$BASE"' EXIT
pass=0; fail=0; unmeasured=0
ok()  { pass=$((pass+1)); printf '  ok   %s\n' "$1"; }
bad() { fail=$((fail+1)); printf '  FAIL %s  ← %s\n' "$1" "$2"; }
t() { if [ "$1" -eq 0 ]; then ok "$2"; else bad "$2" "$3"; fi; }

# 실 설치 자리의 지문(시험 전후 대조) — 없으면 「none」
real_fp() { local a; for a in /Applications/cysr.app /Applications/cys.app; do
  if [ -e "$a" ]; then stat -f '%i %m' "$a" 2>/dev/null; stat -f '%i %m' "$a/Contents/MacOS" 2>/dev/null; else echo none; fi; done; }
REAL_BEFORE="$(real_fp)"

# run_fixture <bootstrap.sh> <이름표> <nox|dead|good> — SB 경로를 표준출력으로 낸다 · SB/verdict 에 판정 재료를 남긴다
run_fixture() {
  local bs="$1" tag="$2" kind="$3" SB ver cdh app
  SB="$BASE/$tag-$kind"; mkdir -p "$SB/bin" "$SB/home" "$SB/Applications" "$SB/fx"
  # 가짜 도구 — 부르면 기록한다. codesign 은 대상 bootstrap.sh 의 CDHash 를 답하고 검증은 통과시킨다(서명 축은 여기서 안 잰다).
  cat > "$SB/bin/codesign" <<'EOF'
#!/bin/bash
echo "codesign $*" >> "$(dirname "$0")/../calls"
case " $* " in *" -dvvv "*|*" -dv "*) echo "CDHash=$(cat "$(dirname "$0")/../cdhash")" >&2 ;; esac
exit 0
EOF
  for b in launchctl osascript sudo open killall pkill curl; do
    printf '#!/bin/bash\necho "%s $*" >> "$(dirname "$0")/../calls"\nexit 1\n' "$b" > "$SB/bin/$b"
  done
  chmod +x "$SB/bin/"*
  # 1) 대상의 핀을 읽는다(같은 파일로 짓고 같은 파일로 재야 판본·CDHash 축이 통과해 실행 비트 축까지 간다)
  JARVIS_LIB_ONLY=1 HOME="$SB/home" JARVIS_HOME="$SB/home/install-jarvis" PATH="$SB/bin:$PATH" \
    bash -c 'f="$1"; set --; . "$f" >/dev/null 2>&1; cys_use_fork_pin; printf "%s\n%s\n%s\n" "$CYS_FORK_VERSION" "$CYS_FORK_CDHASH" "$CYS_MAC_FILE"' _ "$bs" > "$SB/pins" 2>/dev/null
  ver="$(sed -n 1p "$SB/pins")"; cdh="$(sed -n 2p "$SB/pins")"
  [ -n "$ver" ] && [ -n "$cdh" ] || { echo "$SB"; return 3; }
  printf '%s' "$cdh" > "$SB/cdhash"
  # 2) 가짜 자산 — 발행 자산과 같은 모양
  app="$SB/fx/cysr.app"; mkdir -p "$app/Contents/MacOS"
  cat > "$app/Contents/Info.plist" <<EOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0"><dict>
<key>CFBundleName</key><string>cysr</string>
<key>CFBundleShortVersionString</key><string>$ver</string>
</dict></plist>
EOF
  for x in cys cysd cys-app; do
    if [ "$kind" = "dead" ] && [ "$x" = "cys" ]; then
      printf '#!/bin/bash\necho "EMU-DEAD" >&2\nexit 1\n' > "$app/Contents/MacOS/$x"
    elif [ "$kind" = "mute" ] && [ "$x" = "cys" ]; then
      printf '#!/bin/bash\necho "error: EMU-MUTE"\nexit 0\n' > "$app/Contents/MacOS/$x"   # 종료값 0 인데 판본을 답하지 않는다
    else
      printf '#!/bin/bash\necho "%s %s"\n' "$x" "$ver" > "$app/Contents/MacOS/$x"
    fi
    case "$kind" in nox) chmod 644 "$app/Contents/MacOS/$x" ;; *) chmod 755 "$app/Contents/MacOS/$x" ;; esac
  done
  ( cd "$SB/fx" && ditto -c -k --keepParent cysr.app asset.zip ) || { echo "$SB"; return 3; }
  rm -rf "$app"
  # 3) 부른다 — 설치 자리는 샌드박스 안으로
  cat > "$SB/run.sh" <<EOF
. "$bs" || exit 9
cys_use_fork_pin
CYS_FORK_APP="$SB/Applications/cysr.app"; CYS_OLD_APP="$SB/Applications/cys.app"; MODE=full
mkdir -p "\$DL_DIR" && cp "$SB/fx/asset.zip" "\$DL_DIR/\$CYS_MAC_FILE" || exit 8
# 다시 받기(벨트의 재시도 갈래)는 네트워크로 나가지 않는다 — 같은 가짜 자산을 다시 놓고 부른 횟수만 적는다.
step_download_cys() { echo "redownload" >> "$SB/calls"; cp "$SB/fx/asset.zip" "\$DL_DIR/\$CYS_MAC_FILE"; }
step_install_cys
echo "TEST install rc=\$?"
EOF
  # 환경 격리 — 호출자 셸의 변수(JARVIS_*·CYS_*·프록시 등)가 새지 않게 env -i 로 최소 환경만 준다(master#901eb28e).
  env -i PATH="$SB/bin:/usr/bin:/bin:/usr/sbin:/sbin" HOME="$SB/home" JARVIS_HOME="$SB/home/install-jarvis" JARVIS_LIB_ONLY=1 CYS_NO_AUTOSTART=1 \
    JARVIS_NO_PROGRESS=1 LANG="${LANG:-ko_KR.UTF-8}" TMPDIR="$SB" \
    /usr/bin/perl -e 'alarm shift; exec @ARGV' 120 /bin/bash "$SB/run.sh" </dev/null >"$SB/out.txt" 2>"$SB/err.txt"
  echo "$SB"; return 0
}
# 판정 재료
claimed()  { grep -q '^\[6/10\] 설치를 마쳤습니다' "$1/out.txt"; }
runnable() { # 넣은 자리의 cys·cysd 가 -x 이고 cys --version 이 판본을 답한다
  local a="$1/Applications/cysr.app/Contents/MacOS" ver; ver="$(sed -n 1p "$1/pins")"
  [ -x "$a/cys" ] && [ -x "$a/cysd" ] && CYS_NO_AUTOSTART=1 "$a/cys" --version 2>/dev/null | grep -qF "$ver"
}
used_admin() { grep -q '^osascript ' "$1/calls" 2>/dev/null; }
redownloads() { grep -cx redownload "$1/calls" 2>/dev/null || true; }
# req_ok <SB> <nox|dead|mute|good> — 그 시나리오의 요구 전부(뮤턴트 판정도 이것 하나로 — 사람 출력 축과 판정 축이 갈리지 않게)
req_ok() {
  case "$2" in
    good|nox) claimed "$1" && runnable "$1" ;;
    dead|mute) ! claimed "$1" && grep -qE '^\[6/10\] .*(실행|돌지|열리지|확인되지)' "$1/out.txt" \
                 && [ "$(redownloads "$1")" = "1" ] && [ ! -e "$1/Applications/cysr.app" ] ;;
  esac
}

# check_target <bootstrap.sh> <이름표> — 요구 셋을 잰다(초록이어야 하는 판)
check_target() {
  local bs="$1" tag="$2" SB rc
  for k in good nox dead mute; do
    SB="$(run_fixture "$bs" "$tag" "$k")"; rc=$?
    if [ "$rc" -ne 0 ]; then unmeasured=$((unmeasured+1)); bad "[$tag $k] 흉내 준비" "핀을 읽지 못했다·자산을 못 묶었다"; continue; fi
    grep -q '^TEST install rc=' "$SB/out.txt"; t $? "[$tag $k] 흉내가 끝까지 돌았다" "err: $(head -c 200 "$SB/err.txt")"
    if used_admin "$SB"; then unmeasured=$((unmeasured+1)); bad "[$tag $k] 잴 수 없음" "이 계정이 /Applications 에 못 써 관리자 갈래로 갔다"; continue; fi
    ! grep -qE '^(launchctl|osascript|sudo|open|killall|pkill|curl) ' "$SB/calls" 2>/dev/null
    t $? "[$tag $k] 바깥 도구(launchctl·osascript·sudo·open·killall·pkill·curl — 네트워크 0)를 부르지 않았다" "$(grep -vE '^codesign ' "$SB/calls" | head -2 | tr '\n' '|')"
    case "$k" in
      good) claimed "$SB" && runnable "$SB"
            t $? "[$tag good] 대조군 — 멀쩡한 자산은 「마쳤습니다」 ∧ 돈다(검사기가 전부 막아서 초록인 것이 아니다)" "$(grep '\[6/10\]' "$SB/out.txt" | tail -2 | tr '\n' '|')" ;;
      nox)  claimed "$SB" && runnable "$SB"
            t $? "[$tag nox] 실행 비트 없는 자산(오늘 실물) — 벨트가 비트를 주고 「마쳤습니다」 ∧ cys·cysd -x ∧ cys --version 이 판본을 답한다" "마쳤다=$(claimed "$SB" && echo y || echo n) · 돈다=$(runnable "$SB" && echo y || echo n) · $(grep '\[6/10\]' "$SB/out.txt" | tail -2 | tr '\n' '|')" ;;
      dead) ! claimed "$SB"
            t $? "[$tag dead] 비트가 있어도 cys 가 안 돌면 「마쳤습니다」를 찍지 않는다(--version 실행 검사)" "$(grep '\[6/10\]' "$SB/out.txt" | tail -2 | tr '\n' '|')"
            grep -qE '^\[6/10\] .*(실행|돌지|열리지|확인되지)' "$SB/out.txt"
            t $? "[$tag dead] 대신 [6/10] 실패 문구를 찍는다" "$(grep '\[6/10\]' "$SB/out.txt" | tail -2 | tr '\n' '|')"
            [ "$(redownloads "$SB")" = "1" ]
            t $? "[$tag dead] 실행 확인이 걸리면 설치 파일을 한 번만 다시 받는다(재시도 1회 · 무한 반복 없음)" "다시 받기 $(redownloads "$SB")회"
            [ ! -e "$SB/Applications/cysr.app" ]
            t $? "[$tag dead] 안 도는 판은 프로그램 자리에 넣지 않는다" "$(ls "$SB/Applications" 2>/dev/null | tr '\n' ' ')" ;;
      mute) req_ok "$SB" mute
            t $? "[$tag mute] 종료값 0 인데 판본을 답하지 않는 cys 도 「돈다」로 치지 않는다(답 글자 검사) · 다시 받기 1회 · 넣지 않음" "마쳤다=$(claimed "$SB" && echo y || echo n) · 다시 받기 $(redownloads "$SB")회 · $(grep '\[6/10\]' "$SB/out.txt" | tail -1)" ;;
    esac
  done
}

echo "== [6/10] 실행 비트 게이트 — 대상 $(basename "$(dirname "$SRC")")/$(basename "$SRC") =="
check_target "$SRC/bootstrap.sh" target

if [ -n "$DEFECT" ]; then
  echo "== 벨트 없는 판에서 F1 이 붉은가(검사기가 대상을 때린다는 증명) =="
  SB="$(run_fixture "$(cd "$DEFECT" && pwd)/bootstrap.sh" defect nox)"
  if [ $? -ne 0 ] || used_admin "$SB"; then unmeasured=$((unmeasured+1)); bad "[defect nox] 잴 수 없음" "흉내 준비 실패·관리자 갈래"
  else
    claimed "$SB" && ! runnable "$SB"
    t $? "[defect nox] 벨트 없는 판은 「마쳤습니다」를 찍는데 cys 가 돌지 않는다(= 오늘 실기 재현 · 이 시험의 F1 이 여기서 붉다)" "마쳤다=$(claimed "$SB" && echo y || echo n) · 돈다=$(runnable "$SB" && echo y || echo n)"
  fi
fi

if [ "$DO_MUT" = 1 ]; then
  echo "== 벨트 제거 뮤턴트 =="
  # MUTANTS 표: <id>|<파이썬 정규식(줄 단위)>|<그 줄을 바꿀 글(re.sub 치환 · 빈칸이면 지움)>|<붉어야 할 시나리오 nox|dead>|<기대 일치 줄 수>
  #   ⚠정규식은 대상 bootstrap.sh 의 **실물 줄**에 맞춰 둔다 — 0줄 일치면 NOT-APPLIED 로 실패 처리(측정 실패를 초록으로 세지 않는다).
  MUTANTS="${MAC_INSTALL_MUTANTS:-$HERE/mac-install-mutants.tsv}"
  if [ ! -f "$MUTANTS" ]; then bad "[뮤턴트] 표" "$MUTANTS 가 없다"; else
    while IFS='|' read -r id re sub want nwant; do
      case "$id" in ''|\#*) continue ;; esac
      M="$BASE/mut-$id"; rm -rf "$M"; cp -R "$SRC" "$M"
      n="$(python3 - "$M/bootstrap.sh" "$re" "$sub" <<'PY'
import re, sys
p, pat, sub = sys.argv[1:4]
L = open(p, encoding="utf-8", newline="").read().split("\n")
rx = re.compile(pat); out = []; hit = 0
for l in L:
    if rx.search(l):
        hit += 1
        if sub != "":
            out.append(rx.sub(sub, l))
    else:
        out.append(l)
open(p, "w", encoding="utf-8", newline="").write("\n".join(out))
print(hit)
PY
)"
      [ "${n:-0}" = "${nwant:-1}" ] && ! cmp -s "$SRC/bootstrap.sh" "$M/bootstrap.sh"
      t $? "[$id] 변이 적용(일치 $n 줄 · 기대 ${nwant:-1} · 사본이 원본과 다르다)" "NOT-APPLIED — 정규식이 실물 줄에 기대 수만큼 안 맞는다: $re"
      [ "${n:-0}" = "${nwant:-1}" ] || continue
      bash -n "$M/bootstrap.sh" 2>/dev/null || { bad "[$id] 변이 사본 문법" "bash -n 실패 — 변이가 파일을 깨뜨렸다(킬로 세지 않는다)"; continue; }
      SB="$(run_fixture "$M/bootstrap.sh" "mut-$id" "$want")"
      req_ok "$SB" "$want"
      [ $? -ne 0 ]; t $? "[$id] 뮤턴트에서 [$want] 요구가 붉어진다" "뮤턴트가 살았다 — $(grep '\[6/10\]' "$SB/out.txt" | tail -1)"
    done < "$MUTANTS"
  fi
fi

[ "$(real_fp)" = "$REAL_BEFORE" ]
t $? "실제 /Applications/cysr.app·cys.app 는 시험 전후 그대로다(inode·mtime)" "바뀌었다"
printf '\n통과 %s · 실패 %s\n' "$pass" "$fail"
[ "$unmeasured" -eq 0 ] || exit 2
[ "$fail" -eq 0 ]
