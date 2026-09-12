#!/bin/bash
# 토론장 참가 자리 보존 축 — 맥 쪽 실행 입구 (씨앗 → 지우기 → 대조)
#
# ★이 파일이 유일한 입구다. 시험 목적으로 reset-clean.sh 를 직접 부르지 마라.
#   거절 판정은 씨앗(agora-preserve.py) 안에 있고 이 입구는 씨앗을 **가장 먼저** 부른다 —
#   씨앗 없이는 잴 것이 없으므로 모든 길이 그 거절을 먼저 지난다(판정을 두 곳에 적지 않는다).
#   왜 거절하는가는 login-preserve-run.sh 머리말과 같다(2026-09-08 사고 · 절대경로는 HOME 을 안 본다).
#
# 쓰는 법
#   bash tests/agora-preserve-run.sh --dir install-master --sandbox <자리> [--expect-fail] [--shape plain|dotseg|symlink]
#                                    [--stale-out] [--unreadable] [--outside-link]
#                                    [--expect-cys-kept] [--expect-partial]
#   --shape 는 AGORA_HOME 으로 넘길 경로의 **모양**이다. 같은 곳을 가리키되 글자가 다르다 —
#   정규화를 안 하면 dotseg·symlink 에서 중첩 판정이 빠져나가 열쇠가 지워진다(2차 검토 반례).
#
# ★실패를 **실제로 주입하는** 갈래(4차 지적 채택 2026-09-09 — 「적용 확인만」은 축이 아니다)
#   --stale-out        밖에 내용이 다른 반쪽 안내를 미리 놓는다(지난 실행의 치우기 실패 흉내).
#   --unreadable       삭제 루트 안에 이 계정으로 못 여는 자리를 놓는다(열거·삭제가 진짜로 실패한다).
#   --outside-link     삭제 루트 안에 바깥 폴더를 가리키는 링크를 놓는다(뚫고 지우는지 본다).
#   --expect-cys-kept  이 실행은 원본(~/.cys)을 **남겼어야** 한다고 대조한다.
#   --expect-partial   지우개가 비영으로 끝나고 화면에 「일부 남음」이라 적었어야 한다고 본다.
#   --link-in-subdir   바깥 링크를 `.cys/sub` 안에 둔다(그 폴더 열거가 실패했을 때를 재는 자리).
#   --dangling-link    가리키던 곳이 사라진 링크를 둔다(그래도 정상으로 끝나야 한다).
#   --expect-clean     지우개가 **0 으로** 끝났어야 한다고 본다(「[남음]」이 없어야 한다).
#   --chain N          AGORA_HOME 을 N겹 링크 사슬 끝으로 넘긴다(경계 계약 시험).
#   --expect-cleaner-says <문구>
#                      **--expect-cys-kept 와 짝**이다. 그 갈래만 찍는 문구를 화면에서 확인한다 —
#                      종료값만 보면 「아무것도 안 하고 exit 7」 하는 가짜 지우개도 통과한다.
set -u

DIR=""; SB=""; EXPECT_FAIL=""; SHAPE="plain"
SEED_FLAGS=""; VERIFY_FLAGS=""; EXPECT_PARTIAL=""; UNREADABLE=""; EXPECT_CLEAN=""; EXPECT_CYS_KEPT=""; CLEANER_SAYS=""
HERE="$(cd "$(dirname "$0")" && pwd)"
while [ $# -gt 0 ]; do
  case "$1" in
    --dir)         DIR="$2"; shift 2 ;;
    --sandbox)     SB="$2"; shift 2 ;;
    --expect-fail) EXPECT_FAIL="--expect-fail"; shift ;;
    --shape)       SHAPE="$2"; shift 2 ;;
    --stale-out)   SEED_FLAGS="$SEED_FLAGS --stale-out"; shift ;;
    --unreadable)  SEED_FLAGS="$SEED_FLAGS --unreadable"; UNREADABLE=1; shift ;;
    --outside-link) SEED_FLAGS="$SEED_FLAGS --outside-link"; shift ;;
    --link-in-subdir) SEED_FLAGS="$SEED_FLAGS --link-in-subdir"; shift ;;
    --dangling-link) SEED_FLAGS="$SEED_FLAGS --dangling-link"; shift ;;
    --root-link)   SEED_FLAGS="$SEED_FLAGS --root-link"; shift ;;
    --chain)       SEED_FLAGS="$SEED_FLAGS --chain $2"; shift 2 ;;
    --expect-cleaner-says) CLEANER_SAYS="$2"; shift 2 ;;
    --expect-clean) EXPECT_CLEAN=1; shift ;;
    --expect-cys-kept) VERIFY_FLAGS="$VERIFY_FLAGS --expect-cys-kept"; EXPECT_CYS_KEPT=1; shift ;;
    --expect-partial)  EXPECT_PARTIAL=1; shift ;;
    *) echo "모르는 인자: $1" >&2; exit 2 ;;
  esac
done
[ -n "$DIR" ] && [ -n "$SB" ] || { echo "쓰는 법: --dir <install-master> --sandbox <자리>" >&2; exit 2; }
case "$SB" in *.*) echo "씨앗 자리 경로에 마침표를 두지 마십시오: $SB" >&2; exit 2 ;; esac
rm -rf "$SB"; mkdir -p "$SB" || exit 2

echo "── 씨앗 (중첩 설정: AGORA_HOME 을 삭제 루트 안에 둔다) ──"
# shellcheck disable=SC2086  # SEED_FLAGS 는 우리가 만든 낱말 목록이다
python3 "$HERE/agora-preserve.py" seed --home "$SB" --os mac --shape "$SHAPE" $SEED_FLAGS || exit $?

# ★씨앗이 「이 모양으로 넘기라」고 적어 준 값을 그대로 넘긴다 — 같은 곳을 가리키되 글자가 다르다.
HANDED="$(python3 -c 'import json,sys;print(json.load(open(sys.argv[1],encoding="utf-8"))["handed"])' "$SB/agora-expect.json")"
echo "── 지운다 (HOME=$SB · AGORA_HOME=$HANDED) ────────"
HOME="$SB" AGORA_HOME="$HANDED" bash "$DIR/reset-clean.sh" --yes | tee "$SB/reset-clean.out"
CLEANER_RC="${PIPESTATUS[0]}"
echo "지우개 종료 코드 = $CLEANER_RC"

# 심어 둔 「못 여는 자리」의 권한을 돌려놓는다 — 안 그러면 다음 실행이 이 자리를 못 치운다.
if [ -n "$UNREADABLE" ]; then
  LOCKED="$(python3 -c 'import json,sys;print(json.load(open(sys.argv[1],encoding="utf-8"))["unreadable"])' "$SB/agora-expect.json")"
  [ -n "$LOCKED" ] && [ -e "$LOCKED" ] && chmod 755 "$LOCKED" 2>/dev/null
fi

# ★「지웠다」가 아니라 「일부 남음」이라고 말했는가 — 실패를 주입한 실행에서만 본다.
if [ -n "$EXPECT_PARTIAL" ]; then
  # 🔴**정확히 7** 이어야 한다(6차 지적 채택 2026-09-09). 「0 만 아니면 통과」로 두면 **다른 까닭으로
  #   죽은 실행**이 이 축을 통과한다 — 축이 재려던 갈래가 돌았다는 증거가 못 된다.
  if [ "$CLEANER_RC" != "7" ]; then
    echo "::error::「일부 남음」 실행의 종료값은 7 이어야 하는데 $CLEANER_RC 다"
    exit 1
  fi
  if ! grep -q '일부 남음' "$SB/reset-clean.out"; then
    echo "::error::비영으로 끝나긴 했으나 화면에 「일부 남음」이 없다 — 사람이 무엇이 남았는지 모른다"
    exit 1
  fi
  echo "지우개가 실패를 실패라고 말했습니다(종료 코드 $CLEANER_RC · 화면에 「일부 남음」)."
fi

# ★반대쪽도 잰다 — 「깨끗이 끝났어야 하는데 [남음]이 났다」도 결함이다(끊어진 링크 잔재 갈래).
if [ -n "$EXPECT_CLEAN" ]; then
  if [ "$CLEANER_RC" != "0" ]; then
    echo "::error::깨끗이 끝났어야 하는 실행인데 지우개가 $CLEANER_RC 로 끝났다"
    grep -n '남음' "$SB/reset-clean.out" | head -5
    exit 1
  fi
  echo "지우개가 0 으로 끝났습니다(못 지운 것 없음)."
fi

# 🔴**「원본이 그대로다」만으로는 부족하다**(6차 지적 채택): 지우개가 시작하자마자 죽어도 원본은 그대로다.
#   ⇒ 의도한 fail-closed 갈래가 **실제로 돌았다**는 증거 = 종료값 7.
if [ -n "$EXPECT_CYS_KEPT" ]; then
  # 🔴🔴**종료값만으로 「그 갈래가 돌았다」고 말하지 마라**(7차 지적 채택 2026-09-09).
  #   반례: 씨앗을 놓은 뒤 **아무것도 안 하고 `exit 7`** 만 하는 가짜 지우개도 이 축을 통과했다 —
  #   원본이 그대로인 것은 당연하고(아무것도 안 했으니), 종료값도 맞으니까.
  #   ⇒ **그 갈래만 찍는 문구**를 화면에서 함께 확인한다. 문구를 안 주면 축 자체를 거절한다.
  if [ -z "$CLEANER_SAYS" ]; then
    echo "::error::--expect-cys-kept 에는 --expect-cleaner-says <그 갈래만 찍는 문구> 가 함께 있어야 한다"
    exit 2
  fi
  if [ "$CLEANER_RC" != "7" ]; then
    echo "::error::fail-closed 로 멈춘 실행의 종료값은 7 이어야 하는데 $CLEANER_RC 다(그 갈래가 안 돌았을 수 있다)"
    exit 1
  fi
  if ! grep -q "$CLEANER_SAYS" "$SB/reset-clean.out"; then
    echo "::error::지우개가 그 갈래의 말을 안 했다(찾던 문구: $CLEANER_SAYS)"
    exit 1
  fi
  echo "fail-closed 갈래가 실제로 돌았습니다(종료 코드 7 · 화면에 「${CLEANER_SAYS}」)."
fi

echo "── 대조 (열쇠 바이트 · 나머지 삭제 · 안내 이전) ─────────"
# shellcheck disable=SC2086
python3 "$HERE/agora-preserve.py" verify --home "$SB" $EXPECT_FAIL $VERIFY_FLAGS
exit $?
