#!/bin/bash
# [9/10]~[10/10] 자동 각성 흉내 실행 시험 — PowerShell 7 로 실물 bootstrap.ps1 을 「함수 묶음」으로 읽고, 가짜 cys·claude 로 깨우기와 함대 부르기를 끝까지 부른다.
#
# 무엇을 재는가 (2026-09-15 · 첫 각성 = 사람 타이핑 게이트 폐지)
#   ① 성공 — 선언은 자비스를 띄울 때 넘기는 첫 프롬프트의 그 자체 첫 줄 · wake.ps1 을 실제로 돌려 claude 가 받은 인자를 글자 그대로 대조
#            (자비스 폴더 경로에 작은따옴표가 있어도) · 여는 명령 인자에는 우리말 0 · 창에 글을 밀어 넣지 않는다
#            · 동료 자리가 선 것을 보고서야 「깨어났습니다」 · 사람 손 0 · 떠나기 전 설치 창 입력 버퍼를 비운다
#   ② 동료 안 섬(claim_denied 등) — 상한까지 안 서면 그때만 사람 카드 · 「깨어났습니다」·「함대가 섰습니다」 없음
#            · 지난 설치가 남긴 자리 · 자리 번호 없는 경고 줄의 역할 글자를 이번 동료로 세지 않는다 · 카드에 안전장치 설명 없음
#   ③ 폴백 뒤 섬 — 카드가 뜬 뒤 동료가 서면 성공 줄을 기록하고 끝맺음이 「설치가 끝났습니다」(「다시 실행」 없음) · 성공 끝맺음은 ①도 같다
#   ④ 창 못 엶(도달 실패) — 종전 폴백(이 창에서 띄움) 그대로 · 「깨어났습니다」 없음
#
# 쓰는 법: bash tests/awaken-emu-run.sh [--dir <install-master 자리>]
#   rc 0 = 전건 통과 · 1 = 실패 있음 · 2 = 잴 수 없음(pwsh 가 없다)
# ⛔바깥에 닿지 않는다 — 실제 cys·claude 호출 0 · 쓰기는 mktemp -d 안에서만.
# ⚠여기서 **안 재는 것**(윈도우 실기에서만 있는 것): wake.ps1 을 PS 5.1 이 아니라 pwsh 7 로 돌린다(인자 조립 규칙이 다를 수 있다) ·
#   claude.exe/.cmd 고르기 · 첫 프롬프트에도 자비스의 선언 훅이 실제로 도는가 · 콘솔 입력 버퍼(맥 흉내엔 콘솔 입력이 없어 비우기는 -1 로 적힌다) ·
#   동료가 자동 관측 상한(4분) 안에 서는가.
export JARVIS_NO_PROGRESS=1   # 🔴흉내·검사는 라이브 서버로 진행 이벤트를 보내지 않는다(2026-09-15 15:49 master 게이트 실행이 라이브 progress에 가짜 4건을 남긴 사고 · Send-Progress의 레버)
set -u
HERE="$(cd "$(dirname "$0")" && pwd)"
DIR="$HERE/../install-master"
while [ $# -gt 0 ]; do
  case "$1" in
    --dir) DIR="$2"; shift 2 ;;
    *) echo "모르는 인자: $1" >&2; exit 2 ;;
  esac
done
PW="$(command -v pwsh 2>/dev/null)"
# pwsh 가 없으면 윈도우판 구역만 건너뛰고 맥 구역은 돈다 — 끝에서 rc 2(잴 수 없음)로 알린다(전건 통과라 말하지 않는다).
[ -n "$PW" ] || echo "잴 수 없음(윈도우판 구역): pwsh 가 없다" >&2
PS="$(cd "$DIR" && pwd)/bootstrap.ps1"
EMU="$HERE/awaken-emu"
BASE="$(mktemp -d -t awaken-emu)" || exit 2
BASE="$(cd "$BASE" && pwd -P)" || exit 2
cleanup() { rm -rf "$BASE"; }
trap cleanup EXIT
pass=0; fail=0
ok()  { pass=$((pass+1)); printf '  ok   %s\n' "$1"; }
bad() { fail=$((fail+1)); printf '  FAIL %s  ← %s\n' "$1" "$2"; }
t() { if [ "$1" -eq 0 ]; then ok "$2"; else bad "$2" "$3"; fi; }
run_ps() { perl -e 'alarm shift; exec @ARGV' 60 "$PW" -NoProfile -File "$@" </dev/null; }
has() { grep -qE -- "$2" "$1"; }

echo "== [9/10]~[10/10] 자동 각성 =="
for s in success claim-denied fallback-success no-surface child-awake paste-late child-stall; do
  [ -n "$PW" ] || break
  SB="$BASE/$s"; mkdir -p "$SB"
  run_ps "$EMU/fleet.ps1" -Src "$PS" -Scenario "$s" -Sb "$SB" >"$SB/out.txt" 2>"$SB/err.txt"
  JH="$(cat "$SB/jarvis-home" 2>/dev/null)"
  L="$JH/bootstrap.log"; W="$JH/wake.ps1"; O="$SB/out.txt"
  [ -n "$JH" ] && [ -f "$L" ] || { bad "[$s] 기록 파일" "흉내가 기록을 남기지 못했다(err: $(head -c 200 "$SB/err.txt"))"; continue; }
  has "$L" 'TEST finally'; t $? "[$s] 흉내가 끝까지 돌았다" "마지막 줄이 없다 — 멈췄거나 죽었다(err: $(head -c 160 "$SB/err.txt"))"
  # 자비스 창에는 글도 키도 넣지 않는다 · 넣어도 되는 것은 자식 자리(surface:10·11)의 Return 하나뿐(installer-awaken-verify)
  ! grep -qvE '^send-key --surface surface:1[01] Return$' "$SB/sent" 2>/dev/null
  t $? "[$s] 창에 글을 밀어 넣지 않는다(cys send 0회 · send-key 는 자식 자리 Return 만)" "$(grep -vE '^send-key --surface surface:1[01] Return$' "$SB/sent" 2>/dev/null | head -2 | tr '\n' '|')"
  P="$SB/progress.jsonl"
  nsent() { grep -cxE "send-key --surface surface:$1 Return" "$SB/sent" 2>/dev/null || true; }
  prog() { python3 - "$P" "$@" <<'PYEOF'
import sys, json
rows = [json.loads(l) for l in open(sys.argv[1], encoding="utf-8-sig").read().split("\n") if l.strip()] if __import__("os").path.exists(sys.argv[1]) else []
det = [r.get("detail") for r in rows if r.get("event") == "info"]
ev = [r for r in rows if r.get("event") == "evidence"]
mode = sys.argv[2]
if mode == "details":
    print("|".join(str(d) for d in det if str(d).startswith("awaken:child")))
elif mode == "evidence":
    ok = len(ev) == 1 and ev[0].get("reason") == "stall" and ev[0].get("masked") is True and ev[0].get("step") == "10/10"
    t = ev[0].get("text", "") if ev else ""
    ok = ok and t.startswith("seat=worker") and "<USER>" in t and "<EMAIL>" in t and "hong" not in t and "[Pasted text" in t
    sys.exit(0 if ok else 1)
PYEOF
  }
  case "$s" in
    success)
      grep -q '자비스가 깨어났습니다 — 이제 설치 창을 닫으셔도 됩니다' "$O" && has "$L" 'fleet awaken: auto - seats=master,cso,worker$' \
        && has "$L" 'TEST reached=True hands=0$' && ! grep -q '사람 손 #' "$O"
      t $? "[성공] 동료 자리가 서면 「깨어났습니다」 · 사람 손 0" "$(grep -E 'fleet|TEST' "$L" | tail -3 | tr '\n' '|' | cut -c1-200)"
      [ "$(cat "$SB/listcalls" 2>/dev/null || echo 0)" -ge 3 ]
      t $? "[성공] 자리 목록을 다시 본 뒤에 판정한다(기준선 1 + 조회 2회 이상)" "목록 조회 $(cat "$SB/listcalls" 2>/dev/null || echo 0)회"
      # wake.ps1 을 실제로 돌려 claude 가 받은 인자를 글자 그대로 대조한다(경로에 작은따옴표 · 두 줄 · 우리말)
      rm -f "$SB/claude-args"
      PATH="$SB/bin:$PATH" perl -e 'alarm shift; exec @ARGV' 60 "$PW" -NoProfile -File "$W" </dev/null >"$SB/wake-out.txt" 2>&1
      [ "$(head -c 3 "$W" 2>/dev/null | od -An -tx1 | tr -d ' \n')" = "efbbbf" ] \
        && python3 - "$SB/claude-args" "$JH" <<'PYEOF'
import sys, base64
rows = [base64.b64decode(l).decode("utf-8") for l in open(sys.argv[1]).read().split("\n") if l]
want = ["--dangerously-skip-permissions",
        "너는 마스터다\nRead the file " + sys.argv[2] + "/install-directive.md and do exactly what it says. Your first line must be the fixed line specified there."]
sys.exit(0 if rows == want else 1)
PYEOF
      t $? "[성공] 선언은 첫 프롬프트의 그 자체 첫 줄 · wake.ps1 을 돌리면 claude 가 두 줄 그대로 받는다(경로에 작은따옴표 포함 · BOM 파일)" "받은 인자 $(wc -l < "$SB/claude-args" 2>/dev/null | tr -d ' ')개 · wake 출력: $(head -c 160 "$SB/wake-out.txt" | tr '\n' '|')"
      [ -s "$SB/newsurface-args" ] && grep -qx -- '--cmd' "$SB/newsurface-args" && ! grep -q '마스터' "$SB/newsurface-args" \
        && ! grep -v "o'k" "$SB/newsurface-args" | LC_ALL=C grep -q '[^ -~]'
      t $? "[성공] 자리 여는 명령의 인자에는 우리말이 한 글자도 없다" "$(tr '\n' ' ' < "$SB/newsurface-args" 2>/dev/null | cut -c1-200)"
      has "$L" 'fleet stray keys in installer window cleared='
      t $? "[성공] [10/10] 을 떠나기 전에 설치 창 입력 버퍼를 비운다" "비우기 기록이 없다"
      has "$L" 'TEST default awake cap=240s$'
      t $? "[성공] 자동 관측 상한은 240초(자비스 첫 턴보다 길게 · 윈 실기)" "$(grep 'default awake cap' "$L")"
      grep -q '다음에 할 일: 없습니다 — 설치가 끝났습니다. 이 창을 닫으셔도 됩니다.' "$O" && ! has "$L" 'unexpected end'
      t $? "[성공] 끝맺음이 「설치가 끝났습니다」 · 「다시 실행」 안내를 인쇄하지 않는다" "$(grep '다음에 할 일' "$O" | head -1)"
      # installer-awaken-verify — 붙여넣기가 실린 채 멈춘 worker 자리에 Return 한 번 → 답 시작 확인 · 이미 답한 cso 는 무동작
      has "$L" 'awaken child: role=worker seat=surface:11 marker=awaken:child-verified retries=1$' && [ "$(nsent 11)" = "1" ] \
        && has "$L" 'awaken child: role=cso seat=surface:10 marker=awaken:child-verified retries=0$' && [ "$(nsent 10)" = "0" ] \
        && grep -q '     worker 자리 깨움 확인' "$O" && grep -q '     cso 자리 깨움 확인' "$O" && ! grep -q '답이 없습니다' "$O"
      t $? "[성공] 붙여넣기가 남은 자리에 Return 1회 → 답 시작 확인 · 이미 답한 자리는 무동작" "$(grep 'awaken child' "$L" | tr '\n' '|' | cut -c1-200) · Return 11=$(nsent 11) 10=$(nsent 10)"
      [ "$(prog details)" = "awaken:child-verified|awaken:child-retry 1|awaken:child-verified" ]
      t $? "[성공] 표지 = cso child-verified · worker child-retry 1 → child-verified" "$(prog details)"
      has "$L" 'TEST default child cap=60s gap=2s retry=3$'
      t $? "[성공] 자식 자리 확인 상한 = 자리당 60초 · 2초 간격 · 최대 3회" "$(grep 'default child cap' "$L")"
      ;;
    claim-denied)
      has "$L" 'fleet awaken: no child seat within' && grep -q '사람 손 #1 · 시킨 쪽: 자비스' "$O" && grep -q '너는 마스터다' "$O" \
        && has "$L" 'TEST reached=True hands=1$'
      t $? "[동료 안 섬] 상한까지 안 서면 그때만 사람 카드(손 1)" "$(grep -E 'fleet|TEST' "$L" | tail -3 | tr '\n' '|' | cut -c1-200)"
      ! grep -q '자비스가 깨어났습니다' "$O" && ! grep -q '함대가 섰습니다' "$O"
      t $? "[동료 안 섬] 「깨어났습니다」·「함대가 섰습니다」를 말하지 않는다(거짓 성공 0)" "성공 문구가 나왔다"
      has "$L" 'fleet missing: cso,worker$'
      t $? "[동료 안 섬] 지난 설치가 남긴 자리(cso)·자리 번호 없는 경고 줄(worker)을 이번 동료로 세지 않는다" "$(grep 'fleet' "$L" | tail -2 | tr '\n' '|')"
      ! grep -q '안전장치' "$O"
      t $? "[동료 안 섬] 카드에 안전장치 설명이 없다(2026-09-15 결정)" "$(grep '안전장치' "$O" | head -1)"
      has "$L" 'fleet stray keys in installer window cleared='
      t $? "[동료 안 섬] 떠나기 전에 설치 창 입력 버퍼를 비운다" "비우기 기록이 없다"
      ;;
    fallback-success)
      has "$L" 'fleet awaken: no child seat within' && has "$L" 'fleet awaken: success after fallback card - seats=master,cso,worker$' \
        && grep -q '함대가 섰습니다: master · cso · worker' "$O"
      t $? "[폴백 뒤 섬] 카드 뒤에 선 함대도 성공 줄을 기록한다" "$(grep -E 'fleet' "$L" | tail -3 | tr '\n' '|' | cut -c1-200)"
      grep -q '다음에 할 일: 없습니다 — 설치가 끝났습니다. 이 창을 닫으셔도 됩니다.' "$O" && ! has "$L" 'unexpected end'
      t $? "[폴백 뒤 섬] 끝맺음이 「설치가 끝났습니다」 · 「다시 실행」 안내를 인쇄하지 않는다" "$(grep '다음에 할 일' "$O" | head -1)"
      has "$L" 'awaken child: role=cso seat=surface:10 marker=awaken:child-verified retries=0$' && has "$L" 'awaken child: role=worker seat=surface:11 marker=awaken:child-verified retries=0$'
      t $? "[폴백 뒤 섬] 카드 뒤에 선 자식 자리도 깸을 확인한다" "$(grep 'awaken child' "$L" | tr '\n' '|' | cut -c1-200)"
      ;;
    child-awake)
      has "$L" 'awaken child: role=cso seat=surface:10 marker=awaken:child-verified retries=0$' && has "$L" 'awaken child: role=worker seat=surface:11 marker=awaken:child-verified retries=0$' \
        && [ ! -e "$SB/sent" ] && [ "$(prog details)" = "awaken:child-verified|awaken:child-verified" ]
      t $? "[이미 깸] 두 자식이 이미 답했으면 Return 0회 · 깸 확인 표지 2건만" "$(grep 'awaken child' "$L" | tr '\n' '|' | cut -c1-200) · sent=$(cat "$SB/sent" 2>/dev/null | tr '\n' '|') · $(prog details)"
      ;;
    paste-late)
      has "$L" 'awaken child: role=worker seat=surface:11 marker=awaken:child-verified retries=2$' && [ "$(nsent 11)" = "2" ] && [ "$(nsent 10)" = "0" ] \
        && grep -q '     worker 자리 깨움 확인' "$O"
      t $? "[붙여넣기 늦게 풀림] 옛 모양 입력줄에서 Return 두 번째에 비워지면 깸 확인(위쪽 기록에 남은 붙여넣기는 세지 않는다)" "$(grep 'awaken child' "$L" | tr '\n' '|' | cut -c1-200) · Return 11=$(nsent 11) 10=$(nsent 10)"
      ;;
    child-stall)
      has "$L" 'awaken child: role=worker seat=surface:11 marker=awaken:child-fail retries=3$' && [ "$(nsent 11)" = "3" ] \
        && grep -q '     worker 자리는 열렸으나 아직 답이 없습니다 — 자비스가 이어서 깨웁니다(사람 손 0)' "$O" && ! grep -q 'worker 자리 깨움 확인' "$O"
      t $? "[3회 실패] Return 3회 뒤에도 붙여넣기가 남으면 정직 문구 · 깸 확인이라 말하지 않는다" "$(grep 'awaken child' "$L" | tr '\n' '|' | cut -c1-200) · Return=$(nsent 11)"
      [ "$(prog details)" = "awaken:child-verified|awaken:child-retry 1|awaken:child-retry 2|awaken:child-retry 3|awaken:child-fail" ]
      t $? "[3회 실패] 표지 = child-retry 1·2·3 → child-fail (cso 는 child-verified)" "$(prog details)"
      prog evidence
      t $? "[3회 실패] 증거 1건 = reason=stall · 자식 화면 끝부분 · 마스킹(이름·이메일)" "$(grep -c '"evidence"' "$P" 2>/dev/null)건"
      ;;
    no-surface)
      has "$L" 'new-surface failed' && grep -q 'EMU-CLAUDE-INLINE' "$O" && ! grep -q '자비스가 깨어났습니다' "$O"
      t $? "[창 못 엶] 종전 폴백(이 창에서 띄움) 그대로 · 「깨어났습니다」 없음" "$(grep -E 'new-surface|TEST' "$L" | tail -2 | tr '\n' '|' | cut -c1-200)"
      # 이 창에서 띄울 때도 선언이 그 자체 첫 줄이다(2026-09-15 윈 2차 재설치 실기 — 폴백 프롬프트에 「너는 마스터다」가 없었다)
      python3 - "$SB/claude-args" "$JH" <<'PYEOF'
import sys, base64
rows = [base64.b64decode(l).decode("utf-8") for l in open(sys.argv[1]).read().split("\n") if l]
want = ["--dangerously-skip-permissions",
        "너는 마스터다\nRead the file " + sys.argv[2] + "/install-directive.md and do exactly what it says. Your first line must be the fixed line specified there."]
sys.exit(0 if rows == want else 1)
PYEOF
      t $? "[창 못 엶] 이 창에서 띄울 때도 선언은 첫 프롬프트의 그 자체 첫 줄 · claude 가 두 줄 그대로 받는다" "받은 인자 $(wc -l < "$SB/claude-args" 2>/dev/null | tr -d ' ')개"
      ;;
  esac
done

echo "== [10/10] 자식 자리 각성 검증 — 맥판(bootstrap.sh · bash · installer-awaken-verify) =="
SHF="$(cd "$DIR" && pwd)/bootstrap.sh"
for s in success child-awake paste-late child-stall; do
  SB="$BASE/mac-$s"; mkdir -p "$SB/bin" "$SB/home"   # 자비스 폴더는 만들지 않는다 — 이미 있으면 lib 가 작업 폴더로 거절한다
  cp "$EMU/fake-cys.sh" "$SB/bin/cys"; chmod +x "$SB/bin/cys"
  printf '%s' "$s" > "$SB/scenario"; touch "$SB/opened"; echo 5 > "$SB/listcalls"
  cat > "$SB/run.sh" <<EOF
. "$SHF" || exit 9
printf 'TEST default child cap=%ss gap=%ss retry=%s\n' "\$CHILD_AWAKE_CAP_SEC" "\$CHILD_AWAKE_GAP_SEC" "\$CHILD_AWAKE_MAX_RETRY"
FLEET_BASELINE=" surface:3 "
CHILD_AWAKE_GAP_SEC=0
CHILD_AWAKE_CAP_SEC=5
confirm_child_seats cys
echo "TEST done rc=\$?"
EOF
  PATH="$SB/bin:$PATH" HOME="$SB/home" JARVIS_HOME="$SB/home/install-jarvis" JARVIS_LIB_ONLY=1 \
    perl -e 'alarm shift; exec @ARGV' 60 bash "$SB/run.sh" </dev/null >"$SB/out.txt" 2>"$SB/err.txt"
  O="$SB/out.txt"; L="$SB/home/install-jarvis/bootstrap.log"
  msent() { [ -f "$SB/sent" ] || { echo 0; return; }; grep -cxE "send-key --surface surface:$1 Return" "$SB/sent" || true; }
  grep -q '^TEST done rc=0$' "$O"; t $? "[맥 $s] 흉내가 끝까지 돌았다" "err: $(head -c 200 "$SB/err.txt")"
  ! grep -qvE '^send-key --surface surface:1[01] Return$' "$SB/sent" 2>/dev/null
  t $? "[맥 $s] 넣는 것은 자식 자리 Return 뿐" "$(head -2 "$SB/sent" 2>/dev/null | tr '\n' '|')"
  case "$s" in
    success)
      grep -q 'awaken child: role=worker seat=surface:11 marker=awaken:child-verified retries=1$' "$L" && [ "$(msent 11)" = "1" ] \
        && grep -q 'awaken child: role=cso seat=surface:10 marker=awaken:child-verified retries=0$' "$L" && [ "$(msent 10)" = "0" ] \
        && grep -q '^     worker 자리 깨움 확인$' "$O" && grep -q '^     cso 자리 깨움 확인$' "$O" && ! grep -q '답이 없습니다' "$O"
      t $? "[맥 success] 붙여넣기가 남은 자리에 Return 1회 → 답 시작 확인 · 이미 답한 자리는 무동작" "$(grep 'awaken child' "$L" | tr '\n' '|' | cut -c1-200) · Return 11=$(msent 11)"
      grep -q '^TEST default child cap=60s gap=2s retry=3$' "$O"
      t $? "[맥 success] 자식 자리 확인 상한 = 자리당 60초 · 2초 간격 · 최대 3회" "$(grep 'default child' "$O")" ;;
    child-awake)
      grep -q 'role=cso seat=surface:10 marker=awaken:child-verified retries=0$' "$L" && grep -q 'role=worker seat=surface:11 marker=awaken:child-verified retries=0$' "$L" && [ ! -e "$SB/sent" ]
      t $? "[맥 child-awake] 두 자식이 이미 답했으면 Return 0회" "$(grep 'awaken child' "$L" | tr '\n' '|' | cut -c1-200)" ;;
    paste-late)
      grep -q 'role=worker seat=surface:11 marker=awaken:child-verified retries=2$' "$L" && [ "$(msent 11)" = "2" ]
      t $? "[맥 paste-late] 옛 모양 입력줄에서 Return 두 번째에 비워지면 깸 확인" "$(grep 'awaken child' "$L" | tr '\n' '|' | cut -c1-200) · Return=$(msent 11)" ;;
    child-stall)
      grep -q 'role=worker seat=surface:11 marker=awaken:child-fail retries=3$' "$L" && [ "$(msent 11)" = "3" ] \
        && grep -q '^     worker 자리는 열렸으나 아직 답이 없습니다 — 자비스가 이어서 깨웁니다(사람 손 0)$' "$O" && ! grep -q 'worker 자리 깨움 확인' "$O" \
        && grep -q 'awaken child stall tail (worker): .*Pasted text' "$L"
      t $? "[맥 child-stall] Return 3회 뒤에도 붙여넣기가 남으면 정직 문구 · 화면 끝부분을 기록에 남긴다" "$(grep 'awaken child' "$L" | tr '\n' '|' | cut -c1-240) · Return=$(msent 11)" ;;
  esac
done
# 부르는 자리 — 맥 [10/10] 성공·「선언은 들어갔으나 덜 섬」 두 곳 · 윈 자동 각성·카드 뒤 성공 두 곳(주석 줄 제외 세기)
[ "$(grep -cE '^[[:space:]]+confirm_child_seats "\$cli"$' "$DIR/bootstrap.sh")" = "2" ] \
  && [ "$(grep -cE '^[[:space:]]+\[void\]\(Confirm-ChildSeats \$cli\)$' "$DIR/bootstrap.ps1")" = "2" ]
t $? "[맥·윈] 자식 자리 확인을 [10/10] 두 자리에서 부른다" "맥 $(grep -cE 'confirm_child_seats "\$cli"' "$DIR/bootstrap.sh") · 윈 $(grep -cE 'Confirm-ChildSeats \$cli' "$DIR/bootstrap.ps1")"

printf '\n통과 %s · 실패 %s\n' "$pass" "$fail"
[ "$fail" -eq 0 ] || exit 1
[ -n "$PW" ] || exit 2
exit 0
