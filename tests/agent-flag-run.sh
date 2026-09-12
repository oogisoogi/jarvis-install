#!/bin/bash
# 자리 복원 플래그 축 — 「실제로 무엇을 넘겼는가」를 재는 입구 (맥)
#
# ★글자 세기로는 잴 수 없는 것을 잰다.
#   설치기 파일에는 갈래가 둘 다 적혀 있다(붙임 1 · 안 붙임 1). 그래서 `grep` 은
#   「조건을 실제로 물어보고 골랐는가」를 말해 주지 못한다 — 부르는 수밖에 없다.
#
# ⛔이 입구는 진짜 cys 를 부르지 않는다. 가짜를 놓고 **넘어간 인자만** 받아 적는다.
#   ⇒ 자리(좌석)를 만들지 않는다 · /Applications 를 건드리지 않는다 · 데몬을 깨우지 않는다.
#
# 쓰는 법
#   bash tests/agent-flag-run.sh --dir install-master --sandbox <자리> \
#        --cys has-agent|no-agent [--mutant none|always-false|always-true] --expect-agent <횟수>
#
#   --cys       가짜 cys 가 「그 칸이 있다/없다」 중 무엇으로 답하는가(참가자 기기 = no-agent)
#   --mutant    설치기 사본을 일부러 망가뜨린다. 뮤턴트가 기대한 횟수를 못 내면 이 축은 아무것도 안 재는 것이다.
#   --expect-agent  좌석 여는 명령에 `--agent claude` 가 몇 번 실려야 하는가(0 또는 1)
set -u

DIR=""; SB=""; CYS="has-agent"; MUT="none"; EXPECT=""
while [ $# -gt 0 ]; do
  case "$1" in
    --dir)          DIR="$2"; shift 2 ;;
    --sandbox)      SB="$2"; shift 2 ;;
    --cys)          CYS="$2"; shift 2 ;;
    --mutant)       MUT="$2"; shift 2 ;;
    --expect-agent) EXPECT="$2"; shift 2 ;;
    *) echo "모르는 인자: $1" >&2; exit 2 ;;
  esac
done
[ -n "$DIR" ] && [ -n "$SB" ] && [ -n "$EXPECT" ] || { echo "쓰는 법: --dir <install-master> --sandbox <자리> --cys has-agent|no-agent --expect-agent <횟수>" >&2; exit 2; }
[ -f "$DIR/bootstrap.sh" ] || { echo "설치기를 못 찾았습니다: $DIR/bootstrap.sh" >&2; exit 2; }

rm -rf "$SB"; mkdir -p "$SB/bin" || exit 2
LOG="$SB/cys-args.log"; : > "$LOG"

# ── 가짜 cys — 받은 인자를 그대로 받아 적고, 물으면 도움말을 답한다 ──
HELP="$SB/cys-help.txt"
{
  echo 'Create a new surface (PTY session). Prints its surface ref'
  echo ''
  echo 'Options:'
  echo '      --cwd <CWD>'
  echo '      --cmd <CMD>'
  echo '      --title <TITLE>'
  echo '      --role <ROLE>'
  [ "$CYS" = "has-agent" ] && echo '      --agent <AGENT>    이 좌석에서 무엇을 띄우는지'
  echo '  -h, --help'
} > "$HELP"

cat > "$SB/bin/cys" <<EOF
#!/bin/bash
printf '%s\n' "\$*" >> "$LOG"
if [ "\$1" = "new-surface" ] && [ "\$2" = "--help" ]; then cat "$HELP"; exit 0; fi
if [ "\$1" = "--version" ]; then echo "cys 0.0.0-fake"; exit 0; fi
echo "surface:999"
EOF
chmod +x "$SB/bin/cys"

# ── 설치기 사본 (뮤턴트는 이 사본에만 낸다 — 실물은 건드리지 않는다) ──
SRC="$SB/bootstrap.sh"
cp "$DIR/bootstrap.sh" "$SRC" || exit 2
case "$MUT" in
  none) : ;;
  always-false|always-true)
    want="no"; [ "$MUT" = "always-true" ] && want="yes"
    anchor='  case "$out" in'
    grep -qF -- "$anchor" "$SRC" || { echo "::error::뮤턴트 앵커를 못 찾았습니다 — 설치기가 바뀌었습니다"; exit 3; }
    # 판정 자리만 상수로 바꾼다(부르는 자리는 그대로 둔다 — 재려는 것이 「부르는 자리가 판정을 쓰는가」이므로).
    python3 - "$SRC" "$want" <<'PY'
import sys
p, want = sys.argv[1], sys.argv[2]
s = open(p, encoding="utf-8").read()
old = '''  case "$out" in
    *--agent*) ans="yes" ;;
    *)         ans="no" ;;
  esac'''
if s.count(old) != 1:
    sys.stderr.write("::error::뮤턴트 앵커가 1개가 아닙니다 — 설치기가 바뀌었습니다\n"); sys.exit(3)
open(p, "w", encoding="utf-8").write(s.replace(old, '  ans="%s"' % want, 1))
PY
    [ $? -eq 0 ] || exit 3
    ;;
  *) echo "모르는 뮤턴트: $MUT" >&2; exit 2 ;;
esac
bash -n "$SRC" || { echo "::error::사본이 문법에서 깨졌습니다"; exit 3; }

# ── 부른다 (본문은 안 돈다 · 가짜 cys 만 부른다) ──
# ⚠읽어 들이는 파일의 자리를 위치 인자로 넘기면 안 된다 — 설치기는 자기 인자를 스스로 검사하고
#   모르는 인자를 보면 그 자리에서 끝낸다(첫 실행에서 실제로 그렇게 끝났다). 그래서 환경으로 넘긴다.
HOME="$SB" JARVIS_LIB_ONLY=1 CYS_CLI="$SB/bin/cys" AF_SRC="$SRC" AF_SB="$SB" bash -c '
  . "$AF_SRC" || exit 5
  cys_open_master_seat "bash /x/wake.sh" > "$AF_SB/seat.out" 2>&1
' || { echo "::error::부르다 실패했습니다"; exit 5; }

echo "── 가짜 cys 가 받은 인자 ─────────────────────────"
cat "$LOG"
echo "──────────────────────────────────────────────────"

seat=$(grep -c -- '--role master' "$LOG" || true)
agent=$(grep -c -- '--agent claude' "$LOG" || true)
echo "좌석 여는 호출 = ${seat}회 · --agent claude = ${agent}회 (기대 ${EXPECT}회) · 가짜 cys = $CYS · 뮤턴트 = $MUT"

rc=0
[ "${seat:-0}" -eq 1 ] || { echo "::error::좌석 여는 호출이 1회가 아닙니다(${seat}회) — 아무것도 안 잰 것입니다"; rc=1; }
[ "${agent:-0}" -eq "$EXPECT" ] || { echo "::error::--agent 전달이 ${agent}회입니다 — ${EXPECT}회여야 합니다"; rc=1; }
[ "$rc" -eq 0 ] && echo "확인: 기대대로입니다."
exit $rc
