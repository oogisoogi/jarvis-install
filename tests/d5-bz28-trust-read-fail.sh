#!/bin/bash
# 0.3.36 B-Z28 — 제거기의 폴더 신뢰 칸 정리가 설정 파일을 「못 읽은」 것을 실패로 센다(기록이 든 폴더를 지우지 않는다).
#
# 재는 것(기록 1행 · 우리가 넣은 true 가 든 설정)
#   ⓐ 마침표 든 홈 + 잠시 깨진 .claude.json → TRUST_CLEANUP_FAIL ≥ 1(게이트가 작업 폴더를 남긴다) · 🔴 줄
#   ⓑ 마침표 없는 홈(plutil 갈래) + 깨진 .claude.json → 같은 뜻
#   대조군(거짓 실패 0): ⓒⓓ 성한 설정 + 우리 true → 지움 · FAIL 0 ⓔⓕ 성한 설정 + 그 칸 없음 → FAIL 0(할 일 없음)
#   ⓖ 반례(이종 검토): 글자 칸 안 16자리 이상 숫자가 든 성한 설정 → 지움 · FAIL 0(큰 수 가드 오탐 0)
# 재현 원본 = master 의 bz28.sh(같은 함수 떼어 읽기 방식) · 쓰는 법: bash tests/d5-bz28-trust-read-fail.sh [--dir <install-master 자리>]
# ⛔바깥에 닿지 않는다 — 임시 폴더 안의 가짜 홈만 쓴다 · 프로세스를 띄워 두지 않는다.
set -u
HERE="$(cd "$(dirname "$0")" && pwd)"
DIR="$HERE/../install-master"
[ "${1:-}" = "--dir" ] && DIR="$2"
RS="$(cd "$DIR" && pwd)/reset-clean.sh"
# ⚠시험 자리에 마침표가 없어야 「마침표 없는 홈」 사례가 plutil 갈래를 탄다(mktemp -t 는 …/T/bz28.XXXX 라 늘 JXA 갈래 — 거짓 초록 실측).
BASE="$(mktemp -d /tmp/bz28XXXXXX)" || exit 2
case "$BASE" in *.*) echo "잴 수 없음: 시험 자리에 마침표가 있다($BASE)" >&2; exit 2 ;; esac
trap 'rm -rf "$BASE"' EXIT
pass=0; fail=0
t() { if [ "$1" -eq 0 ]; then pass=$((pass+1)); printf '  ok   %s\n' "$2"; else fail=$((fail+1)); printf '  FAIL %s  ← %s\n' "$2" "$3"; fi; }
awk '/^IFS= read -r -d .. DIR_KEY_JS <</{c=1} /^(real_path|dir_key_json|read_trust_seed_record|strip_trust_seed|strip_json_key)\(\) \{/{f=1} /^TRUST_(SEED_ROWS|CLEANUP_FAIL)=/{print} c{print; if($0 ~ /^EOF_DIR_KEY_JS$/) c=0; next} f{print; if($0 ~ /^}/) f=0}' "$RS" > "$BASE/lib.sh"
grep -q '^strip_trust_seed() {' "$BASE/lib.sh" || { echo "잴 수 없음: strip_trust_seed 를 못 떼어 냈다" >&2; exit 2; }

case_run() { # case_run <이름> <홈 끝 이름> <설정 글(%H = 홈 자리)> → 「FAIL|KEPT|REMOVED|true줄수」
  local H="$BASE/$1/$2"; mkdir -p "$H/install-jarvis"
  printf '%s' "$3" | sed "s#%H#$H#g" > "$H/.claude.json"
  printf '%s\t%s\n' "$H/.claude.json" "$H" > "$H/install-jarvis/trust-seed.tsv"
  env -i PATH=/usr/bin:/bin:/usr/sbin:/sbin HOME="$H" JARVIS_HOME="$H/install-jarvis" LIB="$BASE/lib.sh" bash -c '
    say(){ printf "%s\n" "$*" >> "$JARVIS_HOME/../say.txt"; }; short(){ printf "%s" "$1"; }; REMOVED=0; KEPT_FAIL=0
    . "$LIB"; read_trust_seed_record
    while IFS="$(printf "\t")" read -r c k; do [ -n "$c" ] && strip_trust_seed "$c" "$k"; done <<< "$TRUST_SEED_ROWS"
    printf "%s|%s|%s" "$TRUST_CLEANUP_FAIL" "$KEPT_FAIL" "$REMOVED"' 2>/dev/null
  printf '|%s' "$(grep -c '"hasTrustDialogAccepted" *: *true' "$H/.claude.json")"
}
BROKEN='{"projects":{"%H":{"hasTrustDialogAccepted":true}}'          # 끝 } 하나 빠진 깨진 JSON(저장 도중 등)
OURS='{"projects":{"%H":{"hasTrustDialogAccepted":true}},"x":1}'
NOKEY='{"projects":{"/elsewhere":{"hasTrustDialogAccepted":true}},"x":1}'

r="$(case_run a first.last "$BROKEN")"; case "$r" in [1-9]*\|[1-9]*\|0\|1) true ;; *) false ;; esac
t $? "[ⓐ] 마침표 든 홈 + 깨진 설정 → 정리 실패로 센다(FAIL≥1 · 못 지움≥1 · 우리 true 그대로)" "$r(FAIL|KEPT|REMOVED|true)"
grep -q '🔴' "$BASE/a/first.last/say.txt" 2>/dev/null; t $? "[ⓐ] 화면에 🔴(못 살핌/못 지움) 줄이 있다 — 「완료」 로 읽히지 않게" "$(cat "$BASE/a/first.last/say.txt" 2>/dev/null | head -2)"
r="$(case_run b firstlast "$BROKEN")"; case "$r" in [1-9]*\|[1-9]*\|0\|1) true ;; *) false ;; esac
t $? "[ⓑ] 마침표 없는 홈(plutil 갈래) + 깨진 설정 → 같은 뜻(FAIL≥1)" "$r"
r="$(case_run c first.last "$OURS")"; [ "$r" = "0|0|1|0" ]; t $? "[ⓒ 대조군] 마침표 든 홈 + 성한 설정 · 우리 true → 지움 · FAIL 0" "$r"
r="$(case_run d firstlast "$OURS")";  [ "$r" = "0|0|1|0" ]; t $? "[ⓓ 대조군] 마침표 없는 홈 + 성한 설정 · 우리 true → 지움 · FAIL 0" "$r"
r="$(case_run e first.last "$NOKEY")"; [ "$r" = "0|0|0|1" ]; t $? "[ⓔ 대조군] 마침표 든 홈 + 그 칸 없음 → 할 일 없음 · FAIL 0" "$r"
r="$(case_run f firstlast "$NOKEY")";  [ "$r" = "0|0|0|1" ]; t $? "[ⓕ 대조군] 마침표 없는 홈 + 그 칸 없음 → 할 일 없음 · FAIL 0(없음 ≠ 못 읽음)" "$r"
# 이종 검토 반례(MAJOR 퇴행): 큰 수 가드가 **글자 칸 안** 16자리 이상 숫자에도 걸려 성한 설정을 「못 읽음」 으로 셌다
#   → 폴더 남김 → 제거기 rc 7 → 재설치 거부 영구. 글자 칸 안 숫자는 JSON.parse 가 뭉개지 않는다 ⇒ 정리해야 한다.
STRBIG='{"userID":"ab1234567890123456cd","projects":{"%H":{"hasTrustDialogAccepted":true}},"x":1}'
r="$(case_run g first.last "$STRBIG")"; [ "$r" = "0|0|1|0" ]; t $? "[ⓖ 반례] 마침표 든 홈 + 글자 칸 안 16자리 수(userID) · 우리 true → 지움 · FAIL 0" "$r"

# ── 이종 검토 MINOR: 거짓 실패(성한 설정인데 영구 FAIL → 재설치 거부) 부류 ──
EMPTY=''
SURR='{"s":"x\ud83d","projects":{"%H":{"hasTrustDialogAccepted":true}},"x":1}'   # 짝 없는 서로게이트 = 성한 JSON · plutil 만 못 읽는다
EXPN='{"n":1e400,"projects":{"/elsewhere":{"hasTrustDialogAccepted":true}},"x":1}'  # plutil 만 못 읽는다 · 우리 칸 없음
EXPO='{"n":1e400,"projects":{"%H":{"hasTrustDialogAccepted":true}},"x":1}'          # 우리 칸 있음 · 고쳐 쓰면 1e400 이 null 로 뭉개진다
r="$(case_run h first.last "$EMPTY")"; [ "$r" = "0|0|0|0" ]; t $? "[ⓗ] 마침표 든 홈 + 빈 설정 파일 → 칸 없음(할 일 없음) · FAIL 0" "$r"
r="$(case_run i firstlast "$EMPTY")";  [ "$r" = "0|0|0|0" ]; t $? "[ⓘ] 마침표 없는 홈 + 빈 설정 파일 → 칸 없음 · FAIL 0" "$r"
r="$(case_run j firstlast "$SURR")";   [ "$r" = "0|0|1|0" ]; t $? "[ⓙ] 마침표 없는 홈 + plutil 만 못 읽는 성한 설정(서로게이트) · 우리 true → 지움 · FAIL 0" "$r"
grep -q 'x\\ud83d' "$BASE/j/firstlast/.claude.json"; t $? "[ⓙ] 남의 글자 칸(서로게이트 이스케이프) 그대로" "$(head -c 160 "$BASE/j/firstlast/.claude.json")"
r="$(case_run k firstlast "$EXPN")";   [ "$r" = "0|0|0|1" ]; t $? "[ⓚ] 마침표 없는 홈 + 1e400 · 우리 칸 없음 → 할 일 없음 · FAIL 0" "$r"
r="$(case_run l firstlast "$EXPO")";   case "$r" in [1-9]*\|[1-9]*\|0\|1) true ;; *) false ;; esac
t $? "[ⓛ] 1e400 + 우리 true → 고쳐 쓰지 않는다(뭉개짐 방지) · 정리 실패로 센다" "$r"
grep -q '"n":1e400' "$BASE/l/firstlast/.claude.json"; t $? "[ⓛ] 1e400 그대로(null 로 뭉개지지 않았다)" "$(head -c 160 "$BASE/l/firstlast/.claude.json")"
# 심볼릭 링크 설정(dotfile 관리 도구) — 링크는 그대로 두고 실제 파일에서 우리 칸만 뺀다
H="$BASE/m/first.last"; mkdir -p "$H/install-jarvis" "$BASE/m/dots"
printf '%s' "$OURS" | sed "s#%H#$H#g" > "$BASE/m/dots/claude.json"; ln -s "$BASE/m/dots/claude.json" "$H/.claude.json"
printf '%s\t%s\n' "$H/.claude.json" "$H" > "$H/install-jarvis/trust-seed.tsv"
r="$(env -i PATH=/usr/bin:/bin:/usr/sbin:/sbin HOME="$H" JARVIS_HOME="$H/install-jarvis" LIB="$BASE/lib.sh" bash -c '
  say(){ printf "%s\n" "$*" >> "$JARVIS_HOME/../say.txt"; }; short(){ printf "%s" "$1"; }; REMOVED=0; KEPT_FAIL=0
  . "$LIB"; read_trust_seed_record
  while IFS="$(printf "\t")" read -r c k; do [ -n "$c" ] && strip_trust_seed "$c" "$k"; done <<< "$TRUST_SEED_ROWS"
  printf "%s|%s|%s" "$TRUST_CLEANUP_FAIL" "$KEPT_FAIL" "$REMOVED"' 2>/dev/null)"
[ "$r" = "0|0|1" ] && [ -L "$H/.claude.json" ] && ! grep -q hasTrustDialogAccepted "$BASE/m/dots/claude.json"
t $? "[ⓜ] 마침표 든 홈 + 링크 설정 · 우리 true → 실제 파일에서 지움 · 링크 그대로 · FAIL 0" "$r · 링크=$([ -L "$H/.claude.json" ] && echo 예 || echo 아니오)"
# 작업 폴더 칸(strip_json_key)도 못 읽으면 못 지운 것으로 센다(같은 병 · 「못 지운 것은 없습니다」 거짓 방지)
for hn in first.last firstlast; do
  H="$BASE/n/$hn"; mkdir -p "$H/install-jarvis"; printf '%s' "$BROKEN" | sed "s#%H#$H/install-jarvis#g" > "$H/.claude.json"
  r="$(env -i PATH=/usr/bin:/bin:/usr/sbin:/sbin HOME="$H" JARVIS_HOME="$H/install-jarvis" LIB="$BASE/lib.sh" bash -c '
    say(){ :; }; short(){ printf "%s" "$1"; }; REMOVED=0; KEPT_FAIL=0; . "$LIB"; strip_json_key "$HOME/.claude.json" "projects.$JARVIS_HOME"; printf "%s" "$KEPT_FAIL"' 2>/dev/null)"
  [ "$r" = "1" ]; t $? "[ⓝ $hn] 작업 폴더 칸 — 깨진 설정이면 못 지운 것 1" "KEPT_FAIL=$r"
  : > "$H/.claude.json"
  r="$(env -i PATH=/usr/bin:/bin:/usr/sbin:/sbin HOME="$H" JARVIS_HOME="$H/install-jarvis" LIB="$BASE/lib.sh" bash -c '
    say(){ :; }; short(){ printf "%s" "$1"; }; REMOVED=0; KEPT_FAIL=0; . "$LIB"; strip_json_key "$HOME/.claude.json" "projects.$JARVIS_HOME"; printf "%s" "$KEPT_FAIL"' 2>/dev/null)"
  [ "$r" = "0" ]; t $? "[ⓝ $hn 대조군] 작업 폴더 칸 — 빈 설정이면 할 일 없음" "KEPT_FAIL=$r"
done
H="$BASE/o/firstlast"; mkdir -p "$H/install-jarvis"
printf '%s' '{"s":"x\ud83d","hasCompletedOnboarding":true,"keep":1}' > "$H/.claude.json"
r="$(env -i PATH=/usr/bin:/bin:/usr/sbin:/sbin HOME="$H" JARVIS_HOME="$H/install-jarvis" LIB="$BASE/lib.sh" bash -c '
  say(){ :; }; short(){ printf "%s" "$1"; }; REMOVED=0; KEPT_FAIL=0; . "$LIB"; strip_json_key "$HOME/.claude.json" hasCompletedOnboarding; printf "%s|%s" "$KEPT_FAIL" "$REMOVED"' 2>/dev/null)"
[ "$r" = "0|1" ] && ! grep -q hasCompletedOnboarding "$H/.claude.json" && grep -q '"keep"' "$H/.claude.json"
t $? "[ⓞ] plutil 만 못 읽는 성한 설정(서로게이트)의 최상위 우리 칸 → 지움 · 남의 칸 그대로" "$r · $(head -c 120 "$H/.claude.json")"
# 정밀 디버깅 반례: 큰 수·1e400 이 든 성한 설정에 **뺄 칸이 없으면** 할 일 없음이다(가드는 고쳐 쓸 때만 · 거짓 「못 살핌」 → rc 7 → 재설치 거부 방지)
for c in "p first.last {\"big\":12345678901234567890,\"projects\":{\"/o\":{\"x\":1}}} projects.@J@" \
         "q firstlast {\"n\":1e400,\"projects\":{\"/o\":{\"x\":1}}} hasCompletedOnboarding" \
         "r firstlast {\"n\":1e400,\"projects\":{\"/o\":{\"x\":1}}} projects.@J@" \
         "s first.last {\"n\":1e400,\"projects\":{\"/o\":{\"x\":1}}} fullscreenUpsellSeenCount"; do
  set -- $c; H="$BASE/$1/$2"; mkdir -p "$H/install-jarvis"; printf '%s' "$3" > "$H/.claude.json"; k="${4/@J@/$H/install-jarvis}"
  r="$(env -i PATH=/usr/bin:/bin:/usr/sbin:/sbin HOME="$H" JARVIS_HOME="$H/install-jarvis" LIB="$BASE/lib.sh" K="$k" bash -c '
    say(){ :; }; short(){ printf "%s" "$1"; }; REMOVED=0; KEPT_FAIL=0; . "$LIB"; strip_json_key "$HOME/.claude.json" "$K"; printf "%s|%s" "$KEPT_FAIL" "$REMOVED"' 2>/dev/null)"
  [ "$r" = "0|0" ] && [ "$(cat "$H/.claude.json")" = "$3" ]; t $? "[ⓟ $1 $2] 큰 수·1e400 설정 + 뺄 칸 없음($4) → 할 일 없음 · 못 지움 0 · 파일 그대로" "$r"
done
# 이종 검토 3회차 반례(F1·F2·F4): 가드는 「자릿수」가 아니라 「다시 써도 값이 같은가」로 잰다 · 깊은 링크도 조용히 넘기지 않는다
LOSSY='{"s":"x\ud800","n":9.007199254740993e15,"hasCompletedOnboarding":true}'       # plutil 못 읽음 → JS 갈래 · 다시 쓰면 …992 로 바뀐다
H="$BASE/f1/firstlast"; mkdir -p "$H/install-jarvis"; printf '%s' "$LOSSY" > "$H/.claude.json"
r="$(env -i PATH=/usr/bin:/bin:/usr/sbin:/sbin HOME="$H" JARVIS_HOME="$H/install-jarvis" LIB="$BASE/lib.sh" bash -c '
  say(){ :; }; short(){ printf "%s" "$1"; }; REMOVED=0; KEPT_FAIL=0; . "$LIB"; strip_json_key "$HOME/.claude.json" hasCompletedOnboarding; printf "%s|%s" "$KEPT_FAIL" "$REMOVED"' 2>/dev/null)"
[ "$r" = "1|0" ] && grep -q '9.007199254740993e15' "$H/.claude.json"; t $? "[F1] 다시 쓰면 값이 바뀌는 수(9.007199254740993e15) → 고쳐 쓰지 않는다 · 못 지움 1 · 남의 수 그대로" "$r · $(head -c 120 "$H/.claude.json")"
DEC='{"f":0.1234567890123456789,"projects":{"%H":{"hasTrustDialogAccepted":true}},"x":1}'
r="$(case_run f1b first.last "$DEC")"; case "$r" in [1-9]*\|[1-9]*\|0\|1) true ;; *) false ;; esac
t $? "[F1] 긴 소수(0.1234567890123456789) + 우리 true → 고쳐 쓰지 않는다 · 정리 실패로 센다" "$r"
grep -q '0.1234567890123456789' "$BASE/f1b/first.last/.claude.json"; t $? "[F1] 긴 소수 그대로" "$(head -c 120 "$BASE/f1b/first.last/.claude.json")"
r="$(case_run f2 first.last '{"n":1e000,"projects":{"%H":{"hasTrustDialogAccepted":true}},"x":1}')"; [ "$r" = "0|0|1|0" ]
t $? "[F2] 1e000(= 1 · 다시 써도 같은 값) + 우리 true → 지움 · FAIL 0" "$r"
r="$(case_run f2b first.last '{"n":1234567890123456,"projects":{"%H":{"hasTrustDialogAccepted":true}},"x":1}')"; [ "$r" = "0|0|1|0" ]
t $? "[F2 대조군] 16자리지만 정확히 표현되는 정수 + 우리 true → 지움 · FAIL 0" "$r"
grep -q '1234567890123456' "$BASE/f2b/first.last/.claude.json"; t $? "[F2 대조군] 그 수 그대로" "$(head -c 120 "$BASE/f2b/first.last/.claude.json")"
# F4: 상대 링크 40단(운영체제는 32단까지만 따라간다) · 끊긴 링크 · 고리
H="$BASE/f4/first.last"; mkdir -p "$H/install-jarvis" "$BASE/f4/l"; printf '%s' "$OURS" | sed "s#%H#$H#g" > "$BASE/f4/l/real.json"
prev="real.json"; for i in $(seq 1 39); do ln -s "$prev" "$BASE/f4/l/h$i"; prev="h$i"; done; ln -s "$BASE/f4/l/$prev" "$H/.claude.json"
printf '%s\t%s\n' "$H/.claude.json" "$H" > "$H/install-jarvis/trust-seed.tsv"
r="$(env -i PATH=/usr/bin:/bin:/usr/sbin:/sbin HOME="$H" JARVIS_HOME="$H/install-jarvis" LIB="$BASE/lib.sh" bash -c '
  say(){ :; }; short(){ printf "%s" "$1"; }; REMOVED=0; KEPT_FAIL=0; . "$LIB"; read_trust_seed_record
  while IFS="$(printf "\t")" read -r c k; do [ -n "$c" ] && strip_trust_seed "$c" "$k"; done <<< "$TRUST_SEED_ROWS"
  printf "%s|%s|%s" "$TRUST_CLEANUP_FAIL" "$KEPT_FAIL" "$REMOVED"' 2>/dev/null)"
[ "$r" = "0|0|1" ] && ! grep -q hasTrustDialogAccepted "$BASE/f4/l/real.json" && [ -L "$H/.claude.json" ]
t $? "[F4] 40단 상대 링크(운영체제 한도 32 초과) + 우리 true → 실제 파일에서 지움 · 링크 그대로 · FAIL 0" "$r · 남음=$(grep -c hasTrustDialogAccepted "$BASE/f4/l/real.json")"
for kind in dangling loop; do
  H="$BASE/f4$kind/first.last"; mkdir -p "$H/install-jarvis"
  if [ $kind = dangling ]; then ln -s "$BASE/f4$kind/nowhere.json" "$H/.claude.json"; else ln -s "$H/.claude.json" "$H/.claude.json" 2>/dev/null || ln -s .claude.json "$H/.claude.json"; fi
  printf '%s\t%s\n' "$H/.claude.json" "$H" > "$H/install-jarvis/trust-seed.tsv"
  r="$(env -i PATH=/usr/bin:/bin:/usr/sbin:/sbin HOME="$H" JARVIS_HOME="$H/install-jarvis" LIB="$BASE/lib.sh" bash -c '
    say(){ :; }; short(){ printf "%s" "$1"; }; REMOVED=0; KEPT_FAIL=0; . "$LIB"; read_trust_seed_record
    while IFS="$(printf "\t")" read -r c k; do [ -n "$c" ] && strip_trust_seed "$c" "$k"; done <<< "$TRUST_SEED_ROWS"
    printf "%s|%s|%s" "$TRUST_CLEANUP_FAIL" "$KEPT_FAIL" "$REMOVED"' 2>/dev/null)"
  if [ $kind = dangling ]; then [ "$r" = "0|0|0" ]; t $? "[F4 대조군] 끊긴 링크(가리키는 파일 없음) → 칸 없음 · FAIL 0" "$r"
  else case "$r" in [1-9]*) true ;; *) false ;; esac; t $? "[F4] 고리 링크 → 조용히 넘기지 않고 정리 실패로 센다" "$r"; fi
done
# 이종 검토 3회차(Opus) 반례: 잘린 설정 — 그 키 이름이 글자로도 없으면 칸 없음(다시 해도 같은 영구 rc 7 방지) · 있으면 못 뺌으로 센다
TRUNC='{"theme":"dark","model":"x"'
for c in "tr1 hasCompletedOnboarding 0" "tr2 theme 1"; do
  set -- $c; H="$BASE/$1/firstlast"; mkdir -p "$H/install-jarvis"; printf '%s' "$TRUNC" > "$H/.claude.json"
  r="$(env -i PATH=/usr/bin:/bin:/usr/sbin:/sbin HOME="$H" JARVIS_HOME="$H/install-jarvis" LIB="$BASE/lib.sh" K="$2" bash -c '
    say(){ printf "%s\n" "$*" >> "$HOME/say.txt"; }; short(){ printf "%s" "$1"; }; REMOVED=0; KEPT_FAIL=0; . "$LIB"; strip_json_key "$HOME/.claude.json" "$K"; printf "%s" "$KEPT_FAIL"' 2>/dev/null)"
  [ "$r" = "$3" ]; t $? "[잘린 설정 · $2] 키 글자 $([ "$3" = 1 ] && echo 있음 → 못 뺌 1 || echo 없음 → 칸 없음 0)" "KEPT_FAIL=$r · $(cat "$H/say.txt" 2>/dev/null | head -1)"
done
grep -q '깨져' "$BASE/tr2/firstlast/say.txt" 2>/dev/null; t $? "[잘린 설정 · theme] 까닭을 「파일이 깨져 있다」 로 말한다" "$(cat "$BASE/tr2/firstlast/say.txt" 2>/dev/null | head -1)"
H="$BASE/tr3/firstlast"; mkdir -p "$H/install-jarvis"; printf '{"s":"x\\ud800","n":9.007199254740993e15,"hasCompletedOnboarding":true}' > "$H/.claude.json"
env -i PATH=/usr/bin:/bin:/usr/sbin:/sbin HOME="$H" JARVIS_HOME="$H/install-jarvis" LIB="$BASE/lib.sh" bash -c '
  say(){ printf "%s\n" "$*" >> "$HOME/say.txt"; }; short(){ printf "%s" "$1"; }; REMOVED=0; KEPT_FAIL=0; . "$LIB"; strip_json_key "$HOME/.claude.json" hasCompletedOnboarding' >/dev/null 2>&1
grep -q '수가 바뀌' "$H/say.txt" 2>/dev/null && ! grep -q '읽지 못했습니다' "$H/say.txt"; t $? "[F1 문구] 물러난 까닭을 「고쳐 쓰면 다른 수가 바뀐다」 로 말한다(「읽지 못했습니다」 아님)" "$(head -1 "$H/say.txt" 2>/dev/null)"

# ── 폴더 게이트(이종 검토 MINOR d): 정리 실패면 기록 폴더를 남기고 종료 코드 7 · 성공이면 지운다 ──
#   purge 안의 게이트 블록과 끝 요약 블록만 떼어 낸다(제거기 통째 실행 = 호스트 앱·데몬 접촉 · 금지).
awk '/^  if \[ "\$\{TRUST_CLEANUP_FAIL:-0\}" -gt 0 \]; then$/{g=1} g{print} g&&/^  fi$/{g=0}' "$RS" > "$BASE/gate.sh"
awk '/^  if \[ "\$KEPT_FAIL" -eq 0 \]; then$/{g=1} g{print} g&&/^  return 7$/{g=0}' "$RS" > "$BASE/tail.sh"
# 0.3.36: 성공 갈래는 지우기(drop_dir) 대신 보관 이동(keep_jarvis_dir) — 원래 자리를 비운다는 뜻은 같다
grep -q 'keep_jarvis_dir' "$BASE/gate.sh" && grep -q 'return 7' "$BASE/tail.sh" || { echo "잴 수 없음: 게이트·요약 블록을 못 떼어 냈다" >&2; exit 2; }
gate_run() { # gate_run <TRUST_CLEANUP_FAIL> → 「rc|폴더 있음(1/0)」
  local J="$BASE/gate/$1/install-jarvis"; mkdir -p "$J"; : > "$J/trust-seed.tsv"
  env -i PATH=/usr/bin:/bin JARVIS_HOME="$J" TF="$1" G="$BASE/gate.sh" TL="$BASE/tail.sh" bash -c '
    say(){ :; }; short(){ printf "%s" "$1"; }; safe_jarvis_dir(){ return 0; }; drop_dir(){ rm -rf "$1"; }; keep_jarvis_dir(){ mv "$1" "$1-backup-test"; }
    REMOVED=0; KEPT_FAIL=0; PRESERVED=0; TRUST_CLEANUP_FAIL=$TF
    eval "p(){ $(cat "$G")
$(cat "$TL")
return 0; }"; p' >/dev/null 2>&1
  printf '%s|%s' "$?" "$([ -d "$J" ] && echo 1 || echo 0)"
}
r="$(gate_run 1)"; [ "$r" = "7|1" ]; t $? "[게이트] 정리 실패 1 → 기록 폴더 남김 · 종료 코드 7(재설치 진입점이 멈춘다)" "$r(rc|폴더)"
r="$(gate_run 0)"; [ "$r" = "0|0" ]; t $? "[게이트 대조군] 정리 실패 0 → 원래 자리 비움(0.3.36 보관 이동) · 종료 코드 0" "$r"

echo "== 합계: ok $pass · FAIL $fail =="
[ "$fail" -eq 0 ]
