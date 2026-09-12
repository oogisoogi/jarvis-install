#!/bin/bash
# 로그인 보존 축 — 맥 쪽 실행 입구 (씨앗 → 지우기 → 대조)
#
# ★이 파일이 유일한 입구다. reset-clean.sh 를 시험 목적으로 직접 부르지 마라.
#
# 🔴왜 입구를 하나로 좁혔는가 (2026-09-08 사고 · 개발 에이전트 자신이 낸 것 · 관리자 채택)
#   개발 에이전트가 `HOME` 만 임시 폴더로 바꿔 놓고 **개발기에서** 제거기를 돌렸다.
#   그런데 제거기가 지우는 자리 가운데 **HOME 을 안 보는 것들**이 있다:
#     · `/Applications/cys.app`  (절대경로)
#     · `launchctl bootout com.cysjavis.cysd` · `cys daemon uninstall`  (기계 등록)
#     · `pkill -f cysd`  (돌고 있는 프로세스)
#   그 한 번에 **살아 있는 앱이 지워졌다.** 「HOME 을 바꿨으니 격리다」가 틀렸던 것이다.
#   ⇒ ★조심하라고 적지 않는다. 입구에서 **거절**한다.
#     거절 판정 자체는 `login-seed.py` 안에 있고, 이 입구는 **씨앗을 가장 먼저** 부른다 —
#     씨앗 없이는 잴 것이 없으므로, 모든 길이 그 거절을 먼저 지난다(판정을 두 곳에 적지 않는다).
#
# 쓰는 법
#   bash tests/login-preserve-run.sh --dir install-master --sandbox <자리> [--expect-fail] [--seeder <경로>]
#   --expect-fail 은 뮤턴트 시험용이다 — 「적색이 나와야 정상」인 실행.
#   --expect-fail-at <자리> 를 함께 주면 **그 자리에 났는지**까지 본다(지우개가 죽어서 난 적색을 가른다).
set -u

DIR=""; SB=""; EXPECT_FAIL=""; SEEDER=""; EXPECT_AT=""; SAYS=""
HERE="$(cd "$(dirname "$0")" && pwd)"
while [ $# -gt 0 ]; do
  case "$1" in
    --dir)         DIR="$2"; shift 2 ;;
    --sandbox)     SB="$2"; shift 2 ;;
    --seeder)      SEEDER="$2"; shift 2 ;;
    --expect-fail) EXPECT_FAIL="--expect-fail"; shift ;;
    --expect-fail-at) EXPECT_AT="$2"; shift 2 ;;
    --expect-cleaner-says) SAYS="$2"; shift 2 ;;
    *) echo "모르는 인자: $1" >&2; exit 2 ;;
  esac
done
[ -n "$DIR" ] && [ -n "$SB" ] || { echo "쓰는 법: --dir <install-master> --sandbox <자리>" >&2; exit 2; }
[ -n "$SEEDER" ] || SEEDER="$HERE/login-seed.py"

# ⚠씨앗 자리 이름에 마침표를 두지 않는다 — 맥판이 plutil 키 경로를 쓰기 때문이다(씨앗 쪽에서도 막는다).
case "$SB" in *.*) echo "씨앗 자리 경로에 마침표를 두지 마십시오: $SB" >&2; exit 2 ;; esac
rm -rf "$SB"; mkdir -p "$SB" || exit 2

echo "── 씨앗 ─────────────────────────────────────────"
python3 "$SEEDER" --home "$SB" --os mac --jarvis-home "$SB/install-jarvis" --out "$SB/expect.json" || exit $?

echo "── 지운다 (HOME=$SB) ────────────────────────────"
HOME="$SB" bash "$DIR/reset-clean.sh" --yes | tee "$SB/reset-clean.out"
echo "지우개 종료 코드 = ${PIPESTATUS[0]}"

# 지우개가 해야 할 말이 지정됐으면 그 말을 했는지 본다 — 「방어가 발화했다」와 「그냥 안 돌았다」가 갈린다.
if [ -n "$SAYS" ]; then
  if grep -qF -- "$SAYS" "$SB/reset-clean.out"; then
    echo "지우개가 해야 할 말을 했습니다: $SAYS"
  else
    echo "::error::지우개가 이 말을 하지 않았습니다: $SAYS"
    exit 1
  fi
fi

echo "── 대조 ─────────────────────────────────────────"
if [ -n "$EXPECT_AT" ]; then
  python3 "$HERE/login-verify.py" --home "$SB" --expect "$SB/expect.json" $EXPECT_FAIL --expect-fail-at "$EXPECT_AT"
else
  python3 "$HERE/login-verify.py" --home "$SB" --expect "$SB/expect.json" $EXPECT_FAIL
fi
exit $?
