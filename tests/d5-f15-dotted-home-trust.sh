#!/bin/bash
# 0.3.36 F15 행동 시험 — 홈 폴더 이름에 마침표가 있어도(예: /Users/first.last) 폴더 신뢰를 미리 넘기고,
#   제거기가 **우리가 넣은 칸만** 도로 빼는가(맥 전용 · 윈판은 PSObject 속성으로 다뤄 해당 없음).
#
# 재는 것
#   ⓐ 설치기 seed_claude_prefs 를 실제로 부른다(JARVIS_LIB_ONLY=1 · 가짜 HOME=<임시>/a.b)
#      A 새 자리    : 「마침표가 있어」 문장 0 · 작업 폴더 칸 true · 홈 칸 true(없었으니 넣음) · 기록 1행 · 남의 칸 그대로
#      B 대조(false) : 홈 칸에 명시한 false 가 이미 있다 → 그대로 false · 곁의 남의 키 그대로 · 기록 0행
#      C 칸만 있음  : 홈 칸에 남의 키만 있다 → 우리 키만 더한다 · 남의 키 그대로 · 기록 1행
#      D 값이 바뀜  : A 처럼 넣은 뒤 사람이 그 값을 false 로 바꿨다(제거 쪽 대조용)
#   ⓑ 제거기 reset-clean.sh 의 신뢰 칸 함수만 **떼어 내어** 같은 파일에 돌린다
#      A 작업 폴더 칸·홈 칸 사라짐(빈 칸이 되어 칸째) · 남의 칸 그대로 · 「마침표」 못 살핌 0
#      B 기록이 없으니 false 그대로 · C 우리 키만 빠지고 칸과 남의 키는 남는다 · D 값이 달라 그대로 둔다
#
# 쓰는 법: bash tests/d5-f15-dotted-home-trust.sh [--dir <install-master 자리>]
#   rc 0 = 전건 통과 · 1 = 실패 있음 · 2 = 잴 수 없음(python3·osascript 가 없다 · 떼어 낸 사본이 안전하지 않다)
#   v0.3.35 사본의 install-master 를 --dir 로 주면 적색이어야 한다(마침표 자리를 건너뛰었다).
# ⛔바깥에 닿지 않는다 — reset-clean.sh 를 통째로 돌리지 않는다(절대경로의 앱·데몬·launchctl 을 건드린다).
#   신뢰 칸 함수만 떼어 사본에 담고, 사본에 실제 앱 경로·launchctl·security·sudo 가 없음을 확인한 뒤에만 부른다.
# ⚠여기서 안 재는 것: 클로드가 그 칸을 보고 실제로 질문을 건너뛰는가(실기 몫).
set -u
HERE="$(cd "$(dirname "$0")" && pwd)"
DIR="$HERE/../install-master"
while [ $# -gt 0 ]; do
  case "$1" in
    --dir) DIR="$2"; shift 2 ;;
    *) echo "모르는 인자: $1" >&2; exit 2 ;;
  esac
done
SH="$(cd "$DIR" && pwd)/bootstrap.sh"
RS="$(cd "$DIR" && pwd)/reset-clean.sh"
[ -f "$SH" ] && [ -f "$RS" ] || { echo "잴 수 없음: $DIR 에 bootstrap.sh·reset-clean.sh 가 없다" >&2; exit 2; }
command -v python3 >/dev/null 2>&1 || { echo "잴 수 없음: python3 가 없다" >&2; exit 2; }
[ -x /usr/bin/osascript ] || { echo "잴 수 없음: osascript 가 없다" >&2; exit 2; }
T="$(mktemp -d -t d5f15)" || exit 2
T="$(cd "$T" && pwd -P)"
trap 'rm -rf "$T"' EXIT
pass=0; fail=0
t() { if [ "$1" -eq 0 ]; then pass=$((pass+1)); printf '  ok   %s\n' "$2"; else fail=$((fail+1)); printf '  FAIL %s  ← %s\n' "$2" "$3"; fi; }
# jtrue <파일> <파이썬 식> — d = 읽은 JSON · H = 그 자리의 홈 · J = 작업 폴더
jtrue() {
  python3 - "$1" "$2" "$3" "$4" <<'PY' >/dev/null 2>&1
import json, sys
d = json.load(open(sys.argv[1], encoding="utf-8"))
H, J = sys.argv[3], sys.argv[4]
P = d.get("projects", {})
sys.exit(0 if eval(sys.argv[2]) else 1)
PY
}
# 자리 만들기 — mk <이름(마침표 포함)> <처음 .claude.json 내용(H 는 홈 경로로 바뀐다)>
mk() {
  local h="$T/$1"
  mkdir -p "$h/install-jarvis"
  printf 'jarvis-installer-owned v1\n' > "$h/install-jarvis/.jarvis-owned"
  python3 - "$h" "$2" <<'PY'
import json, sys
h, tpl = sys.argv[1], sys.argv[2]
d = json.loads(tpl.replace("@H@", h))
open(h + "/.claude.json", "w", encoding="utf-8").write(json.dumps(d, indent=2))
PY
  chmod 600 "$h/.claude.json"
}
OTHER='"/other/proj":{"allowedTools":["Bash(ls)"]}'
mk a.b   '{"userKey":5,"projects":{'"$OTHER"'}}'
mk c.d   '{"userKey":5,"projects":{'"$OTHER"',"@H@":{"hasTrustDialogAccepted":false,"allowedTools":["mine"]}}}'
mk e.f   '{"userKey":5,"projects":{'"$OTHER"',"@H@":{"allowedTools":["mine"]}}}'
mk g.h   '{"userKey":5,"projects":{'"$OTHER"'}}'

seed() { # seed <이름> — 설치기 함수를 실제로 부른다
  local h="$T/$1"
  ( cd "$h" && env -i PATH="/usr/bin:/bin:/usr/sbin:/sbin" HOME="$h" TMPDIR="$T" LANG=ko_KR.UTF-8 \
      JARVIS_HOME="$h/install-jarvis" JARVIS_LIB_ONLY=1 SH="$SH" \
      perl -e 'alarm 120; exec @ARGV or exit 126' bash -c '. "$SH" >/dev/null 2>&1; seed_claude_prefs "$HOME/.claude.json"; echo "SEED-RC=$?"' ) \
    > "$T/seed-$1.out" 2>&1
}
rows() { # rows <이름> — 기록 파일에서 그 홈을 가리키는 행 수
  local h="$T/$1" f="$T/$1/install-jarvis/trust-seed.tsv"
  [ -f "$f" ] || { echo 0; return; }
  awk -F'\t' -v c="$h/.claude.json" -v k="$h" '$1==c && $2==k{n++} END{print n+0}' "$f"
}

echo "== ⓐ 설치기 씨앗(가짜 홈 = 마침표 든 이름) =="
for n in a.b c.d e.f g.h; do seed "$n"; done
for n in a.b c.d e.f g.h; do
  grep -q 'SEED-RC=' "$T/seed-$n.out" || { echo "잴 수 없음: $n 에서 설치기 함수가 끝나지 않았다"; sed 's/^/    /' "$T/seed-$n.out" | tail -5; exit 2; }
done
for n in a.b c.d e.f g.h; do
  ! grep -q '마침표가 있어' "$T/seed-$n.out"; t $? "[$n] 「마침표가 있어 … 넘기지 못했습니다」 문장 0" "마침표 자리를 건너뛰고 말로만 알린다"
  jtrue "$T/$n/.claude.json" 'P.get(J, {}).get("hasTrustDialogAccepted") is True' "$T/$n" "$T/$n/install-jarvis"
  t $? "[$n] 작업 폴더 칸 hasTrustDialogAccepted = true" "작업 폴더 신뢰가 안 들어갔다"
  jtrue "$T/$n/.claude.json" 'd.get("userKey") == 5 and P.get("/other/proj") == {"allowedTools": ["Bash(ls)"]}' "$T/$n" "$T/$n/install-jarvis"
  t $? "[$n] 남의 최상위 키·남의 프로젝트 칸 그대로" "설정 파일의 다른 값을 잃었다"
done
H="$T/a.b"
jtrue "$H/.claude.json" 'P.get(H) == {"hasTrustDialogAccepted": True}' "$H" "$H/install-jarvis"; t $? "[A] 홈 칸이 없었으니 새로 넣었다(true)" "홈 신뢰가 안 들어갔다"
[ "$(rows a.b)" = 1 ]; t $? "[A] 넣은 홈 키가 기록에 1행" "기록이 없다(제거기가 못 뺀다) — 행 수 $(rows a.b)"
grep -q 'SEED-RC=0' "$T/seed-a.b.out"; t $? "[A] 함수 rc 0" "$(grep SEED-RC "$T/seed-a.b.out")"
H="$T/c.d"
jtrue "$H/.claude.json" 'P.get(H) == {"hasTrustDialogAccepted": False, "allowedTools": ["mine"]}' "$H" "$H/install-jarvis"
t $? "[B 대조] 명시한 false 는 그대로 · 곁의 남의 키도 그대로" "있던 값을 덮었다(안전 선택을 뒤집는다)"
[ "$(rows c.d)" = 0 ]; t $? "[B 대조] 넣지 않았으니 기록 0행" "남의 값을 우리 것으로 적었다(제거기가 남의 값을 지운다)"
grep -q '이미 있어 그대로 두었습니다' "$T/seed-c.d.out"; t $? "[B 대조] 있어서 그대로 뒀다고 말한다" "말이 없다"
H="$T/e.f"
jtrue "$H/.claude.json" 'P.get(H) == {"allowedTools": ["mine"], "hasTrustDialogAccepted": True}' "$H" "$H/install-jarvis"
t $? "[C] 칸은 있고 우리 키만 없었다 → 우리 키만 더했다" "칸째 덮었거나 안 넣었다"
[ "$(rows e.f)" = 1 ]; t $? "[C] 넣은 키가 기록에 1행" "행 수 $(rows e.f)"

# D — 넣은 뒤 사람이 값을 false 로 바꿨다(그분의 선택)
python3 - "$T/g.h" <<'PY'
import json, sys
h = sys.argv[1]; p = h + "/.claude.json"
d = json.load(open(p, encoding="utf-8")); d["projects"][h]["hasTrustDialogAccepted"] = False
open(p, "w", encoding="utf-8").write(json.dumps(d, indent=2))
PY

echo "== ⓑ 제거기 신뢰 칸 함수(떼어 낸 사본) =="
LIB="$T/reset-trust-lib.sh"
awk '
  /^IFS= read -r -d .. DIR_KEY_JS <</ {c=1}
  /^(real_path|dir_key_json|strip_json_key|read_trust_seed_record|strip_trust_seed)\(\) \{/ {f=1}
  c {print; if ($0 ~ /^EOF_DIR_KEY_JS$/) c=0; next}
  f {print; if ($0 ~ /^}/) f=0}
' "$RS" > "$LIB"
grep -q '^strip_trust_seed() {' "$LIB" && grep -q '^strip_json_key() {' "$LIB" && grep -q '^read_trust_seed_record() {' "$LIB" \
  || { echo "잴 수 없음: 제거기에서 신뢰 칸 함수를 떼어 내지 못했다"; exit 2; }
if grep -vE '^[[:space:]]*#' "$LIB" | grep -qE '/Applications|launchctl|security |sudo |drop_dir|rm -rf'; then
  echo "잴 수 없음: 떼어 낸 사본에 바깥에 닿는 줄이 있다 — 부르지 않는다"; exit 2
fi
BIN="$T/bin"; mkdir -p "$BIN"
for b in launchctl security sudo; do printf '#!/bin/bash\necho "%s $*" >> "%s/calls"\nexit 1\n' "$b" "$T" > "$BIN/$b"; chmod +x "$BIN/$b"; done
strip() { # strip <이름> — 제거기와 같은 순서: 기록 읽기 → 기록된 홈 칸 → 작업 폴더 칸
  local h="$T/$1"
  ( cd "$h" && env -i PATH="$BIN:/usr/bin:/bin:/usr/sbin:/sbin" HOME="$h" TMPDIR="$T" LANG=ko_KR.UTF-8 \
      JARVIS_HOME="$h/install-jarvis" LIB="$LIB" \
      perl -e 'alarm 120; exec @ARGV or exit 126' bash -c '
        say() { printf "%s\n" "$*"; }; short() { printf "%s" "$1"; }
        REMOVED=0; KEPT_FAIL=0; TRUST_CLEANUP_FAIL=0
        . "$LIB"
        read_trust_seed_record
        if [ -n "$TRUST_SEED_ROWS" ]; then
          while IFS="$(printf "\t")" read -r _cfg _key; do
            [ -n "$_cfg" ] && [ -n "$_key" ] && strip_trust_seed "$_cfg" "$_key"
          done <<EOF_ROWS
$TRUST_SEED_ROWS
EOF_ROWS
        fi
        strip_json_key "$HOME/.claude.json" "projects.$JARVIS_HOME"
        echo "STRIP-DONE removed=$REMOVED kept_fail=$KEPT_FAIL trust_fail=$TRUST_CLEANUP_FAIL"' ) \
    > "$T/strip-$1.out" 2>&1
}
for n in a.b c.d e.f g.h; do strip "$n"; done
for n in a.b c.d e.f g.h; do
  grep -q 'STRIP-DONE' "$T/strip-$n.out" || { echo "잴 수 없음: $n 에서 제거 함수가 끝나지 않았다"; tail -5 "$T/strip-$n.out" | sed 's/^/    /'; exit 2; }
  ! grep -q '마침표' "$T/strip-$n.out"; t $? "[$n] 제거기에 「마침표 … 다루지 못합니다」 0" "마침표 자리를 못 살피고 지나간다(넣은 칸이 자국으로 남는다)"
  jtrue "$T/$n/.claude.json" 'J not in P' "$T/$n" "$T/$n/install-jarvis"; t $? "[$n] 작업 폴더 칸이 칸째 사라졌다" "작업 폴더 칸이 남았다"
  jtrue "$T/$n/.claude.json" 'd.get("userKey") == 5 and P.get("/other/proj") == {"allowedTools": ["Bash(ls)"]}' "$T/$n" "$T/$n/install-jarvis"
  t $? "[$n] 남의 최상위 키·남의 프로젝트 칸 그대로" "남의 값을 지웠다"
  grep -q 'kept_fail=0 trust_fail=0' "$T/strip-$n.out"; t $? "[$n] 못 지운 것 0" "$(grep STRIP-DONE "$T/strip-$n.out")"
done
H="$T/a.b"; jtrue "$H/.claude.json" 'H not in P' "$H" "$H/install-jarvis"; t $? "[A] 우리가 만든 홈 칸이 비어 칸째 사라졌다" "홈 칸(또는 빈 칸)이 남았다"
H="$T/c.d"; jtrue "$H/.claude.json" 'P.get(H) == {"hasTrustDialogAccepted": False, "allowedTools": ["mine"]}' "$H" "$H/install-jarvis"
t $? "[B 대조] 기록이 없으니 false·남의 키 그대로" "남의 값을 지웠다"
H="$T/e.f"; jtrue "$H/.claude.json" 'P.get(H) == {"allowedTools": ["mine"]}' "$H" "$H/install-jarvis"
t $? "[C] 우리 키만 빠지고 칸과 남의 키는 남았다" "칸째 지웠거나 우리 키가 남았다"
H="$T/g.h"; jtrue "$H/.claude.json" 'P.get(H) == {"hasTrustDialogAccepted": False}' "$H" "$H/install-jarvis"
t $? "[D] 기록은 있어도 값이 우리 것(true)과 달라 그대로 뒀다" "사람이 바꾼 값을 지웠다"
grep -q '우리가 넣은 값과 달라 손대지 않습니다' "$T/strip-g.h.out"; t $? "[D] 그대로 둔 까닭을 말한다" "말이 없다"
for n in a.b c.d e.f g.h; do
  [ "$(stat -f %Lp "$T/$n/.claude.json")" = 600 ]; t $? "[$n] 설정 파일 권한 600 그대로(씨앗·제거 뒤)" "권한이 바뀌었다: $(stat -f %Lp "$T/$n/.claude.json")"
done
[ ! -s "$T/calls" ]; t $? "바깥 명령(launchctl·security·sudo) 호출 0" "$(cat "$T/calls" 2>/dev/null | head -3)"
ls "$T"/*/.claude.json.jarvis.* >/dev/null 2>&1; [ $? -ne 0 ]; t $? "곁 임시 파일이 남지 않았다" "$(ls "$T"/*/.claude.json.jarvis.* 2>/dev/null | head -3)"

echo "== 큰 정수가 든 설정 = 고쳐 쓰지 않고 물러난다(이종 검토 지적 · 2^53 넘는 수 보존) =="
h="$T/i.j"; mkdir -p "$h/install-jarvis"; printf 'jarvis-installer-owned v1\n' > "$h/install-jarvis/.jarvis-owned"
printf '{"userKey":5,"big":12345678901234567890,"projects":{}}\n' > "$h/.claude.json"; chmod 600 "$h/.claude.json"
seed i.j
grep -q '"big" *: *12345678901234567890' "$h/.claude.json" && ! grep -q 'hasTrustDialogAccepted' "$h/.claude.json"
t $? "[큰 정수] 큰 수는 그대로 · 신뢰 칸은 안 넣는다(다른 설정 칸은 plutil 갈래가 종전대로 넣는다)" "$(head -c 200 "$h/.claude.json")"
grep -q '마침표가 있어' "$T/seed-i.j.out"; t $? "[큰 정수] 종전 안내(마침표가 있어 … [Yes])로 물러난다" "$(tail -3 "$T/seed-i.j.out" | tr '\n' '|')"
[ "$(rows i.j)" = 0 ]; t $? "[큰 정수] 넣지 않은 것은 기록하지 않는다" "rows=$(rows i.j)"
echo "== 글자 칸 안 큰 수 = 큰 정수가 아니다(이종 검토 반례 · 가드 오탐이면 신뢰 칸을 못 넣는다) =="
h="$T/k.l"; mkdir -p "$h/install-jarvis"; printf 'jarvis-installer-owned v1\n' > "$h/install-jarvis/.jarvis-owned"
printf '%s\n' '{"userKey":5,"userID":"ab1234567890123456cd","note":"q\"12345678901234567890","projects":{}}' > "$h/.claude.json"; chmod 600 "$h/.claude.json"
seed k.l
jtrue "$h/.claude.json" 'd.get("userID") == "ab1234567890123456cd" and d.get("note") == "q\"12345678901234567890" and P.get(H, {}).get("hasTrustDialogAccepted") is True' "$h" "$h/install-jarvis"
t $? "[글자 칸 큰 수] 신뢰 칸을 넣는다 · 글자 칸(따옴표 든 것 포함) 그대로" "$(head -c 240 "$h/.claude.json")"
! grep -q '마침표가 있어' "$T/seed-k.l.out"; t $? "[글자 칸 큰 수] 종전 안내로 물러나지 않는다" "$(tail -3 "$T/seed-k.l.out" | tr '\n' '|')"
[ "$(rows k.l)" = 1 ]; t $? "[글자 칸 큰 수] 넣은 칸을 기록한다(제거기 짝)" "rows=$(rows k.l)"
h="$T/m.n"; mkdir -p "$h/install-jarvis"; printf 'jarvis-installer-owned v1\n' > "$h/install-jarvis/.jarvis-owned"
printf '%s\n' '{"userKey":5,"n":1e400,"projects":{}}' > "$h/.claude.json"; chmod 600 "$h/.claude.json"
seed m.n
grep -q '"n" *: *1e400' "$h/.claude.json" && ! grep -q 'hasTrustDialogAccepted' "$h/.claude.json"
t $? "[지수 큰 수] 1e400(JSON.parse → Infinity → null)은 고쳐 쓰지 않고 물러난다(제거기 가드와 같은 글)" "$(head -c 200 "$h/.claude.json")"
# ⚠9.007199254740993e15 같은 지수 꼴 큰 수는 여기서 못 잰다 — 설치기의 plutil 갈래(hasCompletedOnboarding 등)가 JS 보다 먼저
#   파일 전체를 다시 써 그 수를 이미 …992 로 바꾼다(기존 동작 · 이번 판 무관 · plutil 단독 실측). 그 사례는 제거기 시험(d5-bz28 F1)이 JS 갈래만으로 잰다.
for c in "q.r 0.1234567890123456789 retreat" "s.t 1e000 seed" "u.v 1234567890123456 seed"; do
  set -- $c; h="$T/$1"; mkdir -p "$h/install-jarvis"; printf 'jarvis-installer-owned v1\n' > "$h/install-jarvis/.jarvis-owned"
  printf '{"userKey":5,"n":%s,"projects":{}}\n' "$2" > "$h/.claude.json"; chmod 600 "$h/.claude.json"; seed "$1"
  if [ "$3" = retreat ]; then grep -q "\"n\" *: *$2" "$h/.claude.json" && ! grep -q hasTrustDialogAccepted "$h/.claude.json"
    t $? "[다시 쓰면 바뀌는 수 $2] 고쳐 쓰지 않고 물러난다 · 수 그대로(이종 검토 3회차 F1)" "$(head -c 160 "$h/.claude.json")"
  else jtrue "$h/.claude.json" 'P.get(H, {}).get("hasTrustDialogAccepted") is True' "$h" "$h/install-jarvis"
    t $? "[다시 써도 같은 수 $2] 신뢰 칸을 넣는다(자릿수만으로 물러나지 않는다 · F2)" "$(head -c 160 "$h/.claude.json")"; fi
done
echo "== 합계: 통과 $pass · 실패 $fail =="
[ "$fail" -eq 0 ]
