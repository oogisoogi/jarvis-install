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
#   ⑤ 마스터 각성 판정(TICKET=installer-0322-awaken) — 첫 지시가 **의뢰형**이고 선언 첫 줄은 그대로 · 판정이 master 자리를 실제로 잰다
#      (표지∧답=각성 확인 · 답만=받았으나 시작 안 함 → 재시도 1회 → 사람 카드 · 둘 다 없음=판정 못 함)
#      ⚠거부 갈래의 **전제** = 훅이 정상 실행돼 마스터 자리에 SessionStart 주입(팩 1.0.1 · 45,644자)이 실린 상태다
#        (1.0.0 은 윈도우에 bash 가 없어 훅이 전부 실패 = 주입 0 이었고, 그때는 거부가 한 번도 안 났다 — 박사님 실측 2026-09-16).
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
for s in success claim-denied fallback-success no-surface child-awake paste-late child-stall screen-lies stale-session fallback-dir no-answer grace master-refuse master-retry-late master-unknown master-stale-mark master-prior-mark master-mark-only; do
  [ -n "$PW" ] || break
  SB="$BASE/$s"; mkdir -p "$SB"
  run_ps "$EMU/fleet.ps1" -Src "$PS" -Scenario "$s" -Sb "$SB" >"$SB/out.txt" 2>"$SB/err.txt"
  JH="$(cat "$SB/jarvis-home" 2>/dev/null)"
  L="$JH/bootstrap.log"; W="$JH/wake.ps1"; O="$SB/out.txt"
  [ -n "$JH" ] && [ -f "$L" ] || { bad "[$s] 기록 파일" "흉내가 기록을 남기지 못했다(err: $(head -c 200 "$SB/err.txt"))"; continue; }
  has "$L" 'TEST finally'; t $? "[$s] 흉내가 끝까지 돌았다" "마지막 줄이 없다 — 멈췄거나 죽었다(err: $(head -c 160 "$SB/err.txt"))"
  # 자비스 창에는 글도 키도 넣지 않는다 · 예외는 둘뿐이다: 자식 자리(surface:10·11)의 Return(installer-awaken-verify)
  #   과 마스터가 「받았으나 시작 안 함」일 때의 **보충 한 줄 1회**(installer-0322-awaken · 선언은 다시 보내지 않는다).
  ! grep -qvE '^send-key --surface surface:1[01] Return$|^send --surface surface:9 앞서 보낸 요청은 |^send-key --surface surface:9 Return$' "$SB/sent" 2>/dev/null
  t $? "[$s] 창에 밀어 넣는 것은 자식 Return 과 마스터 보충 한 줄뿐" "$(grep -vE '^send-key --surface surface:1[01] Return$|^send --surface surface:9 앞서 보낸 요청은 |^send-key --surface surface:9 Return$' "$SB/sent" 2>/dev/null | head -2 | tr '\n' '|')"
  msend9() { [ -f "$SB/sent" ] || { echo 0; return; }; grep -cE '^send --surface surface:9 ' "$SB/sent" || true; }
  case "$s" in master-refuse|master-retry-late|master-stale-mark|master-prior-mark) want9=1 ;; *) want9=0 ;; esac
  [ "$(msend9)" = "$want9" ] && ! grep -q '^send --surface surface:9 .*너는 마스터다' "$SB/sent" 2>/dev/null
  t $? "[$s] 마스터 자리 보충 한 줄은 「받았으나 시작 안 함」일 때만 1회 · 선언을 다시 싣지 않는다" "보낸 횟수 $(msend9) · 기대 $want9"
  P="$SB/progress.jsonl"
  nsent() { [ -f "$SB/sent" ] || { echo 0; return; }; grep -cxE "send-key --surface surface:$1 Return" "$SB/sent" || true; }   # 파일 없음 = 0회(msent 와 동형 · no-answer 에서 빈 문자열이 나와 거짓 실패)
  prog() { python3 - "$P" "$@" <<'PYEOF'
import sys, json
rows = [json.loads(l) for l in open(sys.argv[1], encoding="utf-8-sig").read().split("\n") if l.strip()] if __import__("os").path.exists(sys.argv[1]) else []
det = [r.get("detail") for r in rows if r.get("event") == "info"]
ev = [r for r in rows if r.get("event") == "evidence"]
mode = sys.argv[2]
if mode == "details":
    print("|".join(str(d) for d in det if str(d).startswith("awaken:child")))
elif mode == "evidence":
    # 🔴v0.3.20 — 증거는 이제 셋이 난다(앞 판은 stall 하나였다): 재시도 표지(retry) · 멈춘 자식(stall) · 끝난 뒤(post-install).
    #   ★검사를 「1건」에서 「여러 건 허용」으로 **푸는 것이 아니라**, 이유마다 **정확히 1건**을 따로 못 박는다
    #     (푸는 쪽으로 고치면 이유 × 단계 한 번이라는 성질이 그 순간 안 재진다 — 뮤턴트 retry-dedupe-drop 이 그것을 잰다).
    by = {}
    for r in ev:
        by.setdefault(r.get("reason"), []).append(r)
    ok = sorted(by) == ["post-install", "retry", "stall"] and all(len(v) == 1 for v in by.values())
    ok = ok and all(r.get("masked") is True and r.get("step") == "10/10" for r in ev)
    t = by["stall"][0].get("text", "") if "stall" in by else ""
    ok = ok and t.startswith("seat=worker") and "<USER>" in t and "<EMAIL>" in t and "hong" not in t and "[Pasted text" in t
    rt = by["retry"][0].get("text", "") if "retry" in by else ""
    ok = ok and rt.startswith("[retry] awaken:child-retry role=worker")
    pt = by["post-install"][0].get("text", "") if "post-install" in by else ""
    ok = ok and pt.startswith("seat=master\nhook_errors=")
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
        "너는 마스터다\ninstall-jarvis 폴더의 install-directive.md(" + sys.argv[2] + "/install-directive.md) 를 읽고, 거기 적힌 준비 작업을 해 주세요."]
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
      # installer-awaken-jsonl — 세션 기록이 없는(미제출) worker 자리에 Return 한 번 → 세션 기록으로 깸 확인 · 이미 깬 cso 는 무동작
      has "$L" 'awaken child: role=worker seat=surface:11 marker=awaken:child-verified retries=1 evidence=jsonl u=1 a=1$' && [ "$(nsent 11)" = "1" ] \
        && has "$L" 'awaken child: role=cso seat=surface:10 marker=awaken:child-verified retries=0 evidence=jsonl u=1 a=1$' && [ "$(nsent 10)" = "0" ] \
        && grep -q '     worker 자리 지시 제출 확인' "$O" && grep -q '     cso 자리 지시 제출 확인' "$O" && ! grep -q '답이 없습니다' "$O"
      t $? "[성공] 제출 전 자리(세션 기록 없음)에 Return 1회 → 세션 기록으로 깸 확인 · 이미 깬 자리는 무동작" "$(grep 'awaken child' "$L" | tr '\n' '|' | cut -c1-240) · Return 11=$(nsent 11) 10=$(nsent 10)"
      [ "$(prog details)" = "awaken:child-verified|awaken:child-retry 1|awaken:child-verified" ]
      t $? "[성공] 표지 = cso child-verified · worker child-retry 1 → child-verified" "$(prog details)"
      has "$L" 'TEST default child cap=90s gaps=5 10 20 grace=10s retry=3$'
      t $? "[성공] 자식 자리 확인 상한 = 자리당 90초 · Return 뒤 5·10·20초 · 유예 10초 · 최대 3회" "$(grep 'default child cap' "$L")"
      # ── 마스터 각성 판정(installer-0322-awaken) ──
      has "$L" 'awaken master: marker=awaken:master-verified mark=True a=1 retry=0$' && grep -q '     자비스(master) 각성 확인' "$O" \
        && ! grep -q '준비 작업을 시작하지 않았습니다' "$O" && ! grep -q '판정하지 못했습니다' "$O"
      t $? "[성공] 표지∧답 레코드가 다 있으면 각성 확인(문구도 그것 하나만)" "$(grep 'awaken master' "$L" | tr '\n' '|' | cut -c1-200)"
      has "$L" 'TEST default master cap=120s poll=3s retrycap=60s retry=1$'
      t $? "[성공] 마스터 판정 상한 = 120초 · 재시도 1회 · 재시도 뒤 60초" "$(grep 'default master' "$L")"
      # 표지를 만든 것이 **설치기가 아니라는 것**을 내용으로 잰다 — 가짜 마스터만 pid=4242 를 적는다.
      grep -q '^pid=4242$' "$JH/awake-master.ok" 2>/dev/null
      t $? "[성공] 표지는 마스터가 만든 것이다(설치기가 스스로 만들지 않는다)" "$(head -2 "$JH/awake-master.ok" 2>/dev/null | tr '\n' '|')"
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
      has "$L" 'awaken child: role=cso seat=surface:10 marker=awaken:child-verified retries=0 evidence=jsonl u=1 a=1$' && has "$L" 'awaken child: role=worker seat=surface:11 marker=awaken:child-verified retries=0 evidence=jsonl u=1 a=1$'
      t $? "[폴백 뒤 섬] 카드 뒤에 선 자식 자리도 깸을 확인한다" "$(grep 'awaken child' "$L" | tr '\n' '|' | cut -c1-200)"
      ;;
    child-awake)
      has "$L" 'awaken child: role=cso seat=surface:10 marker=awaken:child-verified retries=0 evidence=jsonl u=1 a=1$' && has "$L" 'awaken child: role=worker seat=surface:11 marker=awaken:child-verified retries=0 evidence=jsonl u=1 a=1$' \
        && [ ! -e "$SB/sent" ] && [ "$(prog details)" = "awaken:child-verified|awaken:child-verified" ]
      t $? "[이미 깸] 두 자식이 이미 답했으면 Return 0회 · 깸 확인 표지 2건만" "$(grep 'awaken child' "$L" | tr '\n' '|' | cut -c1-200) · sent=$(cat "$SB/sent" 2>/dev/null | tr '\n' '|') · $(prog details)"
      ;;
    paste-late)
      has "$L" 'awaken child: role=worker seat=surface:11 marker=awaken:child-verified retries=2 evidence=jsonl u=1 a=1$' && [ "$(nsent 11)" = "2" ] && [ "$(nsent 10)" = "0" ] \
        && grep -q '     worker 자리 지시 제출 확인' "$O"
      t $? "[늦게 제출] Return 두 번째에 세션 기록이 생기면 깸 확인" "$(grep 'awaken child' "$L" | tr '\n' '|' | cut -c1-200) · Return 11=$(nsent 11) 10=$(nsent 10)"
      ;;
    screen-lies)
      has "$L" 'awaken child: role=worker seat=surface:11 marker=awaken:child-fail retries=3 why=no-submit u=0 a=0$' && [ "$(nsent 11)" = "3" ] \
        && grep -q '     worker 자리는 열렸으나 아직 답이 없습니다' "$O" && ! grep -q 'worker 자리 지시 제출 확인' "$O"
      t $? "[화면 거짓] 화면이 답한 모양이어도 세션 기록이 없으면 깸 확인이라 말하지 않는다" "$(grep 'awaken child' "$L" | tr '\n' '|' | cut -c1-240) · Return=$(nsent 11)"
      ;;
    stale-session)
      has "$L" 'awaken child: role=worker seat=surface:11 marker=awaken:child-verified retries=1 evidence=jsonl u=1 a=1$' && [ "$(nsent 11)" = "1" ]
      t $? "[지난 기록] 기준선 전에 생긴 같은 폴더 세션 기록은 세지 않는다(Return 1회 뒤 새 기록으로 확인)" "$(grep 'awaken child' "$L" | tr '\n' '|' | cut -c1-240) · Return=$(nsent 11)"
      ;;
    fallback-dir)
      has "$L" 'awaken child: role=worker seat=surface:11 marker=awaken:child-verified retries=1 evidence=jsonl u=1 a=1$' && [ "$(nsent 11)" = "1" ]
      t $? "[다른 폴더] 폴더 이름 규칙이 안 맞으면 파일 안 cwd 로 찾는다" "$(grep 'awaken child' "$L" | tr '\n' '|' | cut -c1-240) · Return=$(nsent 11)"
      ;;
    no-answer)
      has "$L" 'awaken child: role=worker seat=surface:11 marker=awaken:child-verified retries=0 evidence=jsonl u=1 a=0$' && [ "$(nsent 11)" = "0" ] \
        && grep -q '     worker 자리 지시 제출 확인' "$O" && ! grep -q '답이 없습니다' "$O"
      t $? "[제출만] 사용자 레코드만 있고 답 레코드가 아직 없어도 제출 확인 · Return 0회" "$(grep 'awaken child' "$L" | tr '\n' '|' | cut -c1-240) · Return=$(nsent 11)"
      ;;
    grace)
      has "$L" 'awaken child: role=worker seat=surface:11 marker=awaken:child-verified retries=3 evidence=jsonl u=1 a=0$' && [ "$(nsent 11)" = "3" ] \
        && grep -q '     worker 자리 지시 제출 확인' "$O" && ! grep -q '답이 없습니다' "$O" \
        && [ "$(prog details)" = "awaken:child-verified|awaken:child-retry 1|awaken:child-retry 2|awaken:child-retry 3|awaken:child-verified" ]
      t $? "[유예] 마지막 Return 뒤 기록이 늦게 생겨도 유예 뒤 다시 재서 제출 확인 · Return 은 3회에서 멈춘다" "$(grep 'awaken child' "$L" | tr '\n' '|' | cut -c1-240) · Return=$(nsent 11) · $(prog details)"
      ;;
    child-stall)
      has "$L" 'awaken child: role=worker seat=surface:11 marker=awaken:child-fail retries=3 why=no-submit u=0 a=0$' && [ "$(nsent 11)" = "3" ] \
        && grep -q '     worker 자리는 열렸으나 아직 답이 없습니다 — 자비스가 이어서 깨웁니다(사람 손 0)' "$O" && ! grep -q 'worker 자리 지시 제출 확인' "$O"
      t $? "[3회 실패] Return 3회 뒤에도 세션 기록이 없으면 정직 문구 · 깸 확인이라 말하지 않는다" "$(grep 'awaken child' "$L" | tr '\n' '|' | cut -c1-200) · Return=$(nsent 11)"
      [ "$(prog details)" = "awaken:child-verified|awaken:child-retry 1|awaken:child-retry 2|awaken:child-retry 3|awaken:child-fail" ]
      t $? "[3회 실패] 표지 = child-retry 1·2·3 → child-fail (cso 는 child-verified)" "$(prog details)"
      prog evidence
      t $? "[3회 실패] 증거 = 이유마다 정확히 1건(retry·stall·post-install) · 자식 화면 끝부분 · 마스킹(이름·이메일)" "$(grep -c '"evidence"' "$P" 2>/dev/null)건"
      ;;
    master-refuse)
      has "$L" 'awaken master: marker=awaken:master-no-start mark=False a=1 retry=1$' \
        && grep -q '     자비스(master)는 지시를 받았으나 준비 작업을 시작하지 않았습니다' "$O" \
        && grep -q '거절했거나, 표지 파일을 쓰지 못했을 수 있습니다' "$O" \
        && ! grep -q '자비스가 깨어났습니다' "$O"
      t $? "[마스터 거부] 답은 있고 표지가 없으면 재시도 1회 뒤 「받았으나 시작 안 함」 · 「깨어났습니다」 없음" "$(grep 'awaken master' "$L" | tr '\n' '|' | cut -c1-220)"
      grep -q '동료 자리는 섰지만, 자비스(master)가 준비 작업을 시작한 것은 확인하지 못했습니다' "$O" \
        && has "$L" 'fleet awaken: auto - seats=master,cso,worker$'
      t $? "[마스터 거부] 동료가 서도 그것을 마스터 각성으로 세지 않는다(거짓 초록 봉합)" "$(grep -E 'fleet awaken|확인하지 못' "$L" "$O" | tail -2 | tr '\n' '|' | cut -c1-220)"
      grep -q 'install-jarvis 폴더의 install-directive.md 를 읽고,' "$O" && ! grep -q '│        너는 마스터다' "$O"
      t $? "[마스터 거부] 사람 카드에 적히는 것은 **실제로 받아들여진 문장**이다(선언 재입력이 아니다)" "$(grep -n '쳐 주십시오' "$O" | head -2 | tr '\n' '|' | cut -c1-200)"
      grep -q '다음에 할 일: cys 창(제목 jarvis)의 자비스에게 위 한 줄을 전해 주십시오' "$O" && ! grep -q '설치가 끝났습니다' "$O"
      t $? "[마스터 거부] 끝맺음이 「끝났습니다」라고 말하지 않는다 · 남은 일을 그대로 적는다" "$(grep '다음에 할 일' "$O" | head -1)"
      ;;
    master-retry-late)
      has "$L" 'awaken master: marker=awaken:master-verified mark=True a=1 retry=1$' \
        && grep -q '     자비스(master) 각성 확인' "$O" && grep -q '자비스가 깨어났습니다' "$O"
      t $? "[마스터 늦게 시작] 보충 한 줄을 받고 시작하면 각성 확인(재시도가 헛일이 아니다)" "$(grep 'awaken master' "$L" | tr '\n' '|' | cut -c1-220)"
      ;;
    master-stale-mark)
      has "$L" 'awaken master: marker=awaken:master-no-start mark=False a=1 retry=1$' \
        && grep -q '     자비스(master)는 지시를 받았으나 준비 작업을 시작하지 않았습니다' "$O" && ! grep -q '자비스가 깨어났습니다' "$O"
      t $? "[지난 표지·시각] 표지가 있어도 이번 설치 기준선보다 앞서 쓰였으면 세지 않는다" "$(grep 'awaken master' "$L" | tr '\n' '|' | cut -c1-220)"
      ;;
    master-prior-mark)
      has "$L" 'master mark: cleared stale ' \
        && has "$L" 'awaken master: marker=awaken:master-no-start mark=False a=1 retry=1$' && ! grep -q '자비스가 깨어났습니다' "$O"
      t $? "[지난 표지·지우기] 깨우기 전부터 놓여 있던 표지를 지워 이번 각성으로 세지 않는다" "$(grep -E 'master mark|awaken master' "$L" | tr '\n' '|' | cut -c1-240)"
      ;;
    master-mark-only)
      has "$L" 'awaken master: marker=awaken:master-verified mark=True a=0 retry=0$' \
        && grep -q '     자비스(master) 각성 확인' "$O" && grep -q '자비스가 깨어났습니다' "$O"
      t $? "[표지만] 표지가 있으면 답 기록이 아직 없어도 각성 확인(느린 기계의 거짓 실패 방지)" "$(grep 'awaken master' "$L" | tr '\n' '|' | cut -c1-220)"
      ;;
    master-unknown)
      has "$L" 'awaken master: marker=awaken:master-unknown mark=False a=0 retry=0$' \
        && grep -q '     자비스(master)가 깼는지 판정하지 못했습니다' "$O" \
        && ! grep -q '준비 작업을 시작하지 않았습니다' "$O" && ! grep -q '자비스가 깨어났습니다' "$O"
      t $? "[판정 못 함] 답도 표지도 없으면 「판정 못 함」 — 「거절했다」라고 말하지 않는다" "$(grep 'awaken master' "$L" | tr '\n' '|' | cut -c1-220)"
      [ "$(msend9)" = "0" ]
      t $? "[판정 못 함] 판정이 안 되는 자리에 보충 한 줄을 밀어 넣지 않는다(재시도는 답이 있을 때만)" "보낸 횟수 $(msend9)"
      ;;
    no-surface)
      has "$L" 'new-surface failed' && grep -q 'EMU-CLAUDE-INLINE' "$O" && ! grep -q '자비스가 깨어났습니다' "$O"
      t $? "[창 못 엶] 종전 폴백(이 창에서 띄움) 그대로 · 「깨어났습니다」 없음" "$(grep -E 'new-surface|TEST' "$L" | tail -2 | tr '\n' '|' | cut -c1-200)"
      # 이 창에서 띄울 때도 선언이 그 자체 첫 줄이다(2026-09-15 윈 2차 재설치 실기 — 폴백 프롬프트에 「너는 마스터다」가 없었다)
      python3 - "$SB/claude-args" "$JH" <<'PYEOF'
import sys, base64
rows = [base64.b64decode(l).decode("utf-8") for l in open(sys.argv[1]).read().split("\n") if l]
want = ["--dangerously-skip-permissions",
        "너는 마스터다\ninstall-jarvis 폴더의 install-directive.md(" + sys.argv[2] + "/install-directive.md) 를 읽고, 거기 적힌 준비 작업을 해 주세요."]
sys.exit(0 if rows == want else 1)
PYEOF
      t $? "[창 못 엶] 이 창에서 띄울 때도 선언은 첫 프롬프트의 그 자체 첫 줄 · claude 가 두 줄 그대로 받는다" "받은 인자 $(wc -l < "$SB/claude-args" 2>/dev/null | tr -d ' ')개"
      ;;
  esac
done

echo "== [10/10] 자식 자리 각성 검증 — 맥판(bootstrap.sh · bash · installer-awaken-jsonl) =="
SHF="$(cd "$DIR" && pwd)/bootstrap.sh"
for s in success child-awake paste-late child-stall screen-lies stale-session fallback-dir no-answer grace; do
  SB="$BASE/mac-$s"; mkdir -p "$SB/bin" "$SB/home"   # 자비스 폴더는 만들지 않는다 — 이미 있으면 lib 가 작업 폴더로 거절한다
  cp "$EMU/fake-cys.sh" "$SB/bin/cys"; chmod +x "$SB/bin/cys"
  printf '%s' "$s" > "$SB/scenario"; touch "$SB/opened"; echo 5 > "$SB/listcalls"
  cat > "$SB/run.sh" <<EOF
. "$SHF" || exit 9
printf 'TEST default child cap=%ss gaps=%s grace=%ss retry=%s\n' "\$CHILD_AWAKE_CAP_SEC" "\$CHILD_AWAKE_GAPS" "\$CHILD_AWAKE_GRACE_SEC" "\$CHILD_AWAKE_MAX_RETRY"
FLEET_BASELINE=" surface:3 "
CHILD_AWAKE_GAPS='0 0 0'
CHILD_AWAKE_GRACE_SEC=2
CHILD_AWAKE_CAP_SEC=8
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
      grep -q 'awaken child: role=worker seat=surface:11 marker=awaken:child-verified retries=1 evidence=jsonl u=1 a=1$' "$L" && [ "$(msent 11)" = "1" ] \
        && grep -q 'awaken child: role=cso seat=surface:10 marker=awaken:child-verified retries=0 evidence=jsonl u=1 a=1$' "$L" && [ "$(msent 10)" = "0" ] \
        && grep -q '^     worker 자리 지시 제출 확인$' "$O" && grep -q '^     cso 자리 지시 제출 확인$' "$O" && ! grep -q '답이 없습니다' "$O"
      t $? "[맥 success] 제출 전 자리에 Return 1회 → 세션 기록으로 깸 확인 · 이미 깬 자리는 무동작" "$(grep 'awaken child' "$L" | tr '\n' '|' | cut -c1-240) · Return 11=$(msent 11)"
      grep -q '^TEST default child cap=90s gaps=5 10 20 grace=10s retry=3$' "$O"
      t $? "[맥 success] 자식 자리 확인 상한 = 자리당 90초 · Return 뒤 5·10·20초 · 유예 10초 · 최대 3회" "$(grep 'default child' "$O")" ;;
    child-awake)
      grep -q 'role=cso seat=surface:10 marker=awaken:child-verified retries=0 evidence=jsonl u=1 a=1$' "$L" && grep -q 'role=worker seat=surface:11 marker=awaken:child-verified retries=0 evidence=jsonl u=1 a=1$' "$L" && [ ! -e "$SB/sent" ]
      t $? "[맥 child-awake] 두 자식이 이미 깼으면 Return 0회" "$(grep 'awaken child' "$L" | tr '\n' '|' | cut -c1-200)" ;;
    paste-late)
      grep -q 'role=worker seat=surface:11 marker=awaken:child-verified retries=2 evidence=jsonl u=1 a=1$' "$L" && [ "$(msent 11)" = "2" ]
      t $? "[맥 paste-late] Return 두 번째에 세션 기록이 생기면 깸 확인" "$(grep 'awaken child' "$L" | tr '\n' '|' | cut -c1-200) · Return=$(msent 11)" ;;
    child-stall)
      grep -q 'role=worker seat=surface:11 marker=awaken:child-fail retries=3 why=no-submit u=0 a=0$' "$L" && [ "$(msent 11)" = "3" ] \
        && grep -q '^     worker 자리는 열렸으나 아직 답이 없습니다 — 자비스가 이어서 깨웁니다(사람 손 0)$' "$O" && ! grep -q 'worker 자리 지시 제출 확인' "$O" \
        && grep -q 'awaken child stall tail (worker): .*Pasted text' "$L"
      t $? "[맥 child-stall] Return 3회 뒤에도 세션 기록이 없으면 정직 문구 · 화면 끝부분을 기록에 남긴다" "$(grep 'awaken child' "$L" | tr '\n' '|' | cut -c1-240) · Return=$(msent 11)" ;;
    screen-lies)
      grep -q 'role=worker seat=surface:11 marker=awaken:child-fail retries=3 why=no-submit u=0 a=0$' "$L" && [ "$(msent 11)" = "3" ] \
        && ! grep -q 'worker 자리 지시 제출 확인' "$O" && grep -q '^     cso 자리 지시 제출 확인$' "$O"
      t $? "[맥 screen-lies] 화면이 답한 모양이어도 세션 기록이 없으면 깸 확인이라 말하지 않는다" "$(grep 'awaken child' "$L" | tr '\n' '|' | cut -c1-240) · Return=$(msent 11)" ;;
    stale-session)
      grep -q 'role=worker seat=surface:11 marker=awaken:child-verified retries=1 evidence=jsonl u=1 a=1$' "$L" && [ "$(msent 11)" = "1" ]
      t $? "[맥 stale-session] 기준선 전에 생긴 같은 폴더 세션 기록은 세지 않는다" "$(grep 'awaken child' "$L" | tr '\n' '|' | cut -c1-240) · Return=$(msent 11)" ;;
    fallback-dir)
      grep -q 'role=worker seat=surface:11 marker=awaken:child-verified retries=1 evidence=jsonl u=1 a=1$' "$L" && [ "$(msent 11)" = "1" ]
      t $? "[맥 fallback-dir] 폴더 이름 규칙이 안 맞으면 파일 안 cwd 로 찾는다" "$(grep 'awaken child' "$L" | tr '\n' '|' | cut -c1-240) · Return=$(msent 11)" ;;
    no-answer)
      grep -q 'role=worker seat=surface:11 marker=awaken:child-verified retries=0 evidence=jsonl u=1 a=0$' "$L" && [ "$(msent 11)" = "0" ] \
        && grep -q '^     worker 자리 지시 제출 확인$' "$O" && ! grep -q '답이 없습니다' "$O"
      t $? "[맥 no-answer] 사용자 레코드만 있고 답 레코드가 아직 없어도 제출 확인 · Return 0회" "$(grep 'awaken child' "$L" | tr '\n' '|' | cut -c1-240) · Return=$(msent 11)" ;;
    grace)
      grep -q 'role=worker seat=surface:11 marker=awaken:child-verified retries=3 evidence=jsonl u=1 a=0$' "$L" && [ "$(msent 11)" = "3" ] \
        && grep -q '^     worker 자리 지시 제출 확인$' "$O" && ! grep -q '답이 없습니다' "$O"
      t $? "[맥 grace] 마지막 Return 뒤 기록이 늦게 생겨도 유예 뒤 다시 재서 제출 확인 · Return 은 3회에서 멈춘다" "$(grep 'awaken child' "$L" | tr '\n' '|' | cut -c1-240) · Return=$(msent 11)" ;;
  esac
done
echo "== [9/10]~[10/10] 마스터 각성 판정 — 맥판(bootstrap.sh · bash · mac-parity-0323 · ps1 master-* 동형 + master-late-fleet) =="
# ★윈도우판 fleet.ps1 구역의 master-* 판정을 맥 bash 로 그대로 옮겨 잰다 — 기록 줄·화면 문구는 **ps1 과 글자 동일**이 계약이다
#   (브리프 mac-parity-t3-gates §5-3 · ps1 과 글자 대조 가능하게). 상한 변수 이름 = ps1 이름의 대문자 뱀 표기(MasterAwakeCapSec → MASTER_AWAKE_CAP_SEC).
#   ⚠이 구역은 T1 이식(선언·판정) **전에** 쓰였다 — 이식 전 판에서는 전건 붉은 것이 정상이다(검사기가 대상을 때린다는 증명 · 보고서 기준선 참조).
# ⛔입구는 실물 step_wake 하나(fleet.ps1 이 Step-Wake 를 부르는 것과 동형) · 끝맺음은 실물 closing_note(EXIT 트랩) · 바깥 호출 0.
# 마스터 보충 한 줄의 기대 글 = **정본(bootstrap.sh send_master_retry 의 msg='…' 한 줄)을 읽어 쓴다**(master#63749eda).
#   ⛔이 파일에 글자를 따로 박지 않는다 — 정본·사본 이중화는 문구를 고칠 때마다 거짓 적색을 낸다.
#   ⚠정본에서 읽으면 「글자가 맞는가」 축은 자기 자신과 대조가 되므로, 정본이 지켜야 할 성질(한 곳 · ASCII(H-M2) · 선언 재전송 없음 · 빈 글 아님)을 따로 잰다.
MAC_RETRY_MSG="$(D="$(mktemp -d)"; mkdir -p "$D/home"; HOME="$D/home" JARVIS_HOME="$D/home/install-jarvis" JARVIS_LIB_ONLY=1 \
  bash -c 'f="$1"; set --; . "$f" >/dev/null 2>&1; trap - EXIT; printf "%s" "${MASTER_RETRY_MSG:-}"' _ "$SHF" 2>/dev/null; rm -rf "$D")"
# 정본은 상수 한 줄(^MASTER_RETRY_MSG=) · 보내는 함수가 그 상수를 쓴다
[ "$(grep -cE '^MASTER_RETRY_MSG=' "$SHF")" = "1" ] && python3 - "$SHF" <<'PYEOF'
import re, sys
t = open(sys.argv[1], encoding="utf-8").read()
m = re.search(r"(?ms)^send_master_retry\(\) \{.*?^\}", t)
sys.exit(0 if m and re.search(r'(?m)^\s*msg="\$MASTER_RETRY_MSG"\s*$', m.group(0)) else 1)
PYEOF
MAC_RETRY_SRC_OK=$?
python3 - "$MAC_RETRY_MSG" <<'PYEOF'
import sys
m = sys.argv[1]
sys.exit(0 if m and all(0x20 <= ord(c) < 0x7f for c in m) and "너는 마스터다" not in m else 1)
PYEOF
[ $? -eq 0 ] && [ "$MAC_RETRY_SRC_OK" -eq 0 ]
t $? "[맥 master] 보충 한 줄 정본 = bootstrap.sh 상수 MASTER_RETRY_MSG 한 줄 · send_master_retry 가 그것을 보냄 · 빈 글 아님 · ASCII 뿐(H-M2 · 판정 master#63749eda) · 선언 재전송 없음" "읽은 글: $(printf '%s' "$MAC_RETRY_MSG" | cut -c1-120)"
MAC_MASTER_SCEN="${AWAKEN_EMU_MAC_MASTER:-success master-refuse master-retry-late master-unknown master-stale-mark master-prior-mark master-mark-only master-late-fleet master-verified-fleet-late}"
for s in $MAC_MASTER_SCEN; do
  SB="$BASE/macm-$s"; mkdir -p "$SB/bin" "$SB/home"
  cp "$EMU/fake-cys.sh" "$SB/bin/cys"; chmod +x "$SB/bin/cys"
  printf '#!/bin/bash\necho "EMU-CLAUDE-INLINE"\nexit 0\n' > "$SB/bin/claude"; chmod +x "$SB/bin/claude"
  JH="$SB/home/install-jarvis"
  printf '%s' "$s" > "$SB/scenario"; printf '%s' "$JH" > "$SB/jarvis-home"
  cat > "$SB/run.sh" <<EOF
. "$SHF" || exit 9
printf 'TEST default awake cap=%ss\n' "\$(( \${FLEET_AWAKE_TRIES:-0} * \${FLEET_POLL_SEC:-0} ))"
printf 'TEST default master cap=%ss poll=%ss retrycap=%ss retry=%s\n' "\${MASTER_AWAKE_CAP_SEC:-}" "\${MASTER_AWAKE_POLL_SEC:-}" "\${MASTER_RETRY_CAP_SEC:-}" "\${MASTER_RETRY_MAX:-}"
CYS_CLI=cys; MODE=full
FLEET_POLL_SEC=0; FLEET_AWAKE_TRIES=3; FLEET_WAIT_TRIES=2
CHILD_AWAKE_GAPS='0 0 0'; CHILD_AWAKE_GRACE_SEC=2; CHILD_AWAKE_CAP_SEC=8
MASTER_AWAKE_CAP_SEC=2; MASTER_AWAKE_POLL_SEC=0; MASTER_RETRY_CAP_SEC=2
mkdir -p "$JH"
# 깨우기 전부터 놓여 있는 표지(fleet.ps1 과 같은 자리 · 시각이 지금이라 시각 검사로는 못 거른다 — 지우기만 거른다)
[ "$s" = "master-prior-mark" ] && printf 'prior\npid=1111\n' > "$JH/awake-master.ok"
step_wake
echo "TEST wake rc=\$?"
EOF
  PATH="$SB/bin:$PATH" HOME="$SB/home" JARVIS_HOME="$JH" JARVIS_LIB_ONLY=1 \
    perl -e 'alarm shift; exec @ARGV' 90 bash "$SB/run.sh" </dev/null >"$SB/out.txt" 2>"$SB/err.txt"
  O="$SB/out.txt"; L="$JH/bootstrap.log"
  msend9m() { [ -f "$SB/sent" ] || { echo 0; return; }; grep -cE '^send --surface surface:9 ' "$SB/sent" || true; }
  mhas() { grep -qE -- "$1" "$L" 2>/dev/null; }
  grep -q '^TEST wake rc=' "$O" && grep -q '^다음에 할 일: ' "$O"
  t $? "[맥 master $s] 흉내가 끝까지 돌았다(깨우기 → 끝맺음)" "err: $(head -c 200 "$SB/err.txt" | tr '\n' '|')"
  mac_other_sent() { [ -f "$SB/sent" ] || return 1; grep -vxF -e 'send-key --surface surface:10 Return' -e 'send-key --surface surface:11 Return' -e 'send-key --surface surface:9 Return' -e "send --surface surface:9 $MAC_RETRY_MSG" "$SB/sent"; }
  [ -n "$MAC_RETRY_MSG" ] && ! mac_other_sent >/dev/null
  t $? "[맥 master $s] 창에 밀어 넣는 것은 자식 Return 과 마스터 보충 한 줄(정본 글 그대로)뿐(선언을 창에 밀어 넣지 않는다)" "$(mac_other_sent | head -2 | tr '\n' '|' | cut -c1-240)"
  case "$s" in master-refuse|master-retry-late|master-stale-mark|master-prior-mark|master-late-fleet) want9=1 ;; *) want9=0 ;; esac
  [ "$(msend9m)" = "$want9" ] && ! grep -q '^send --surface surface:9 .*너는 마스터다' "$SB/sent" 2>/dev/null
  t $? "[맥 master $s] 마스터 자리 보충 한 줄은 「받았으나 시작 안 함」일 때만 1회 · 선언을 다시 싣지 않는다" "보낸 횟수 $(msend9m) · 기대 $want9"
  case "$s" in
    success)
      mhas 'awaken master: marker=awaken:master-verified mark=True a=1 retry=0$' && grep -q '     자비스(master) 각성 확인' "$O" \
        && grep -q '자비스가 깨어났습니다 — 이제 설치 창을 닫으셔도 됩니다' "$O" \
        && ! grep -q '준비 작업을 시작하지 않았습니다' "$O" && ! grep -q '판정하지 못했습니다' "$O"
      t $? "[맥 master 성공] 표지∧답 레코드 → 각성 확인 · 「깨어났습니다」" "$(grep 'awaken master' "$L" 2>/dev/null | tr '\n' '|' | cut -c1-200)"
      mhas 'fleet awaken: auto - seats=master,cso,worker$' && ! grep -q '사람 손 #' "$O"
      t $? "[맥 master 성공] 동료 자리가 서고 사람 손 0(맥도 선언이 자동 — 카드 없음)" "$(grep -E 'fleet' "$L" 2>/dev/null | tail -2 | tr '\n' '|' | cut -c1-200)"
      python3 - "$JH/wake.sh" <<'PYEOF'
import sys
t = open(sys.argv[1], encoding="utf-8").read()
sys.exit(0 if "너는 마스터다\ninstall-jarvis 폴더의 install-directive.md(" in t else 1)
PYEOF
      t $? "[맥 master 성공] 선언 「너는 마스터다」는 첫 프롬프트의 그 자체 첫 줄(wake.sh 안)" "$(head -c 240 "$JH/wake.sh" 2>/dev/null | tr '\n' '|')"
      grep -q '^TEST default master cap=120s poll=3s retrycap=60s retry=1$' "$O"
      t $? "[맥 master 성공] 마스터 판정 상한 = 120초 · 3초 간격 · 재시도 1회 · 재시도 뒤 60초(ps1 과 같은 값)" "$(grep 'default master' "$O")"
      grep -q '^TEST default awake cap=240s$' "$O"
      t $? "[맥 master 성공] 동료 자동 관측 상한 = 240초(ps1 과 같은 값)" "$(grep 'default awake' "$O")"
      grep -q '다음에 할 일: 없습니다 — 설치가 끝났습니다. 이 창을 닫으셔도 됩니다.' "$O"
      t $? "[맥 master 성공] 끝맺음이 「설치가 끝났습니다」" "$(grep '다음에 할 일' "$O" | head -1)"
      grep -q '^pid=4242$' "$JH/awake-master.ok" 2>/dev/null
      t $? "[맥 master 성공] 표지는 마스터가 만든 것이다(설치기가 스스로 만들지 않는다)" "$(head -2 "$JH/awake-master.ok" 2>/dev/null | tr '\n' '|')" ;;
    master-refuse)
      mhas 'awaken master: marker=awaken:master-no-start mark=False a=1 retry=1$' \
        && grep -q '     자비스(master)는 지시를 받았으나 준비 작업을 시작하지 않았습니다' "$O" \
        && grep -q '거절했거나, 표지 파일을 쓰지 못했을 수 있습니다' "$O" && ! grep -q '자비스가 깨어났습니다' "$O"
      t $? "[맥 마스터 거부] 답은 있고 표지가 없으면 재시도 1회 뒤 「받았으나 시작 안 함」 · 「깨어났습니다」 없음" "$(grep 'awaken master' "$L" 2>/dev/null | tr '\n' '|' | cut -c1-220)"
      grep -q '동료 자리는 섰지만, 자비스(master)가 준비 작업을 시작한 것은 확인하지 못했습니다' "$O" && mhas 'fleet awaken: auto - seats=master,cso,worker$'
      t $? "[맥 마스터 거부] 동료가 서도 그것을 마스터 각성으로 세지 않는다(거짓 초록 봉합)" "$(grep -E '확인하지 못' "$O" | head -1 | cut -c1-200)"
      grep -q 'install-jarvis 폴더의 install-directive.md 를 읽고,' "$O" && ! grep -q '│        너는 마스터다' "$O"
      t $? "[맥 마스터 거부] 사람 카드에 적히는 것은 실제로 받아들여진 문장(선언 재입력 아님)" "$(grep -n '쳐 주십시오' "$O" | head -2 | tr '\n' '|' | cut -c1-200)"
      grep -q '다음에 할 일: cys 창(제목 jarvis)의 자비스에게 위 한 줄을 전해 주십시오' "$O" && ! grep -q '설치가 끝났습니다' "$O"
      t $? "[맥 마스터 거부] 끝맺음이 「끝났습니다」라고 말하지 않는다 · 남은 일을 그대로 적는다" "$(grep '다음에 할 일' "$O" | head -1)" ;;
    master-retry-late)
      mhas 'awaken master: marker=awaken:master-verified mark=True a=1 retry=1$' && grep -q '     자비스(master) 각성 확인' "$O" && grep -q '자비스가 깨어났습니다' "$O"
      t $? "[맥 마스터 늦게 시작] 보충 한 줄을 받고 시작하면 각성 확인(재시도가 헛일이 아니다)" "$(grep 'awaken master' "$L" 2>/dev/null | tr '\n' '|' | cut -c1-220)" ;;
    master-stale-mark)
      mhas 'awaken master: marker=awaken:master-no-start mark=False a=1 retry=1$' \
        && grep -q '     자비스(master)는 지시를 받았으나 준비 작업을 시작하지 않았습니다' "$O" && ! grep -q '자비스가 깨어났습니다' "$O"
      t $? "[맥 지난 표지·시각] 표지가 있어도 이번 설치 기준선보다 앞서 쓰였으면 세지 않는다" "$(grep 'awaken master' "$L" 2>/dev/null | tr '\n' '|' | cut -c1-220)" ;;
    master-prior-mark)
      mhas 'master mark: cleared stale ' && mhas 'awaken master: marker=awaken:master-no-start mark=False a=1 retry=1$' && ! grep -q '자비스가 깨어났습니다' "$O"
      t $? "[맥 지난 표지·지우기] 깨우기 전부터 놓여 있던 표지를 지워 이번 각성으로 세지 않는다" "$(grep -E 'master mark|awaken master' "$L" 2>/dev/null | tr '\n' '|' | cut -c1-240)" ;;
    master-mark-only)
      mhas 'awaken master: marker=awaken:master-verified mark=True a=0 retry=0$' && grep -q '     자비스(master) 각성 확인' "$O" && grep -q '자비스가 깨어났습니다' "$O"
      t $? "[맥 표지만] 표지가 있으면 답 기록이 아직 없어도 각성 확인" "$(grep 'awaken master' "$L" 2>/dev/null | tr '\n' '|' | cut -c1-220)" ;;
    master-unknown)
      mhas 'awaken master: marker=awaken:master-unknown mark=False a=0 retry=0$' && grep -q '     자비스(master)가 깼는지 판정하지 못했습니다' "$O" \
        && ! grep -q '준비 작업을 시작하지 않았습니다' "$O" && ! grep -q '자비스가 깨어났습니다' "$O"
      t $? "[맥 판정 못 함] 답도 표지도 없으면 「판정 못 함」 — 「거절했다」라고 말하지 않는다" "$(grep 'awaken master' "$L" 2>/dev/null | tr '\n' '|' | cut -c1-220)" ;;
    master-late-fleet)
      # H-M1(2026-09-16 실행 확정): 첫 판정은 no-start 였지만 동료가 서는 동안 마스터가 표지를 썼다 — 최종 판정 직전에 다시 재야 한다.
      mhas 'awaken master: marker=awaken:master-no-start mark=False a=1 retry=1$'
      t $? "[맥 늦은 표지] 첫 판정은 no-start 였다(전제 성립)" "$(grep 'awaken master' "$L" 2>/dev/null | tr '\n' '|' | cut -c1-220)"
      grep -q '^pid=4242$' "$JH/awake-master.ok" 2>/dev/null
      t $? "[맥 늦은 표지] 동료가 선 뒤 표지 파일이 실제로 생겼다(전제 성립)" "$(ls "$JH" 2>/dev/null | tr '\n' ' ')"
      grep -q '자비스가 깨어났습니다' "$O" && ! grep -q '동료 자리는 섰지만' "$O" && ! grep -q '쳐 주십시오' "$O" \
        && grep -q '다음에 할 일: 없습니다 — 설치가 끝났습니다' "$O"
      t $? "[맥 늦은 표지] 최종 판정 직전에 다시 재서 「깨어났습니다」 · 거짓 no-start 카드 없음(H-M1)" "$(grep -E '깨어났습니다|동료 자리는 섰지만|다음에 할 일' "$O" | tr '\n' '|' | cut -c1-240)" ;;
    master-verified-fleet-late)
      # N13(t4-fix · codex 새2): 마스터는 깼는데(verified) 동료 자리가 상한 안에 안 섰다 — 이미 깬 자비스에게 선언을 또 치게 하면 거짓 카드다.
      mhas 'awaken master: marker=awaken:master-verified mark=True a=1 retry=0$' && mhas 'fleet awaken: no child seat within'
      t $? "[맥 마스터 깸·동료 늦음] 전제 성립(마스터 verified · 동료 자동 관측 상한 안에 0)" "$(grep -E 'awaken master|fleet awaken' "$L" 2>/dev/null | tr '\n' '|' | cut -c1-220)"
      # v0324 C2(master#4c9d14e3 A): N13 의 뜻 = 「기다리는 동안 이미 깬 마스터에게 선언을 치게 하지 마라」 ⇒ 재는 범위 = 대기 단계 출력(최종 카드 줄 앞).
      #   상한 소진 뒤 최종 카드는 복구 국면이라 재선언 한 줄을 안내한다(아래 축) — 범위를 좁혀도 대기 카드에 선언이 새면 mac-wait-card-redecl-inject 뮤턴트가 붉힌다.
      W="$SB/wait-stage.txt"; awk '/\[10\/10\] 아직 서지 않은 자리가 있습니다/{exit} {print}' "$O" > "$W"
      grep -q '\[10/10\] 아직 서지 않은 자리가 있습니다' "$O" && grep -q '마스터는 깨어났습니다 · 동료 자리는 자비스가 세우는 중입니다' "$W" && ! grep -q '너는 마스터다' "$W" && ! grep -q '쳐 주십시오' "$W" \
        && ! grep -q '저절로 깨어나지 않아' "$O" && ! grep -q '사람 손 #' "$O" && mhas 'fleet: master verified - waiting for child seats without declaration card'
      t $? "[맥 마스터 깸·동료 늦음] 카드 문구에 「너는 마스터다」·「쳐 주십시오」 없음(대기 단계 · 최종 카드 줄 앞) · 「사람이 하실 일은 없습니다」(N13)" "$(grep -nE '너는 마스터다|쳐 주십시오|깨어나지 않아|마스터는 깨어|아직 서지 않은' "$O" | head -4 | tr '\n' '|' | cut -c1-240)"
      grep -qF '     마스터는 깨어 있습니다. 남은 자리를 다시 세우려면 cysr 창의 jarvis 칸에 『너는 마스터다.』 한 줄을 다시 쳐 주십시오(이 설치 창이 아닙니다).' "$O" && ! grep -q '이어서 세웁니다' "$O" && ! grep -q '다시 치실 필요는 없습니다' "$O"
      t $? "[맥 마스터 깸·동료 늦음] 상한 소진 뒤 최종 카드는 cysr 창 jarvis 칸 재선언 한 줄을 안내 · 「이어서 세웁니다」 거짓 약속 없음(v0324 C2)" "$(grep -nE '남은 자리|치실 필요' "$O" | head -3 | tr '\n' '|' | cut -c1-240)"
      grep -q '다음에 할 일: cys 창(제목 jarvis)의 자비스와 이어서 이야기하십시오' "$O" && ! grep -q '다시 하시는 법' "$O"
      t $? "[맥 마스터 깸·동료 늦음] 끝맺음이 「다시 실행」이 아니라 자비스와 이어서 이야기(N13)" "$(grep '다음에 할 일' "$O" | head -1)" ;;
  esac
done
echo "== [9/10] 맥 앱 창 열기(open_cys_app) — 대기 기록 실측 초(N16) · 문장 순서(N3) · t4-fix =="
# ★cys 앱 자리 = 샌드박스 안 빈 폴더(CYS_KIND=fork) · open = 가짜(기록만) · ping = 가짜(slow-ping 이면 2초 · 답 없음) — 실제 앱·데몬 무접촉.
for s in app-slow-ping app-no-surface; do
  SB="$BASE/macw-$s"; mkdir -p "$SB/bin" "$SB/home" "$SB/cys.app"
  cp "$EMU/fake-cys.sh" "$SB/bin/cys"; chmod +x "$SB/bin/cys"
  printf '#!/bin/bash\necho "EMU-CLAUDE-INLINE"\nexit 0\n' > "$SB/bin/claude"; chmod +x "$SB/bin/claude"
  printf '#!/bin/bash\necho "open $*" >> "%s/open-calls"\nexit 0\n' "$SB" > "$SB/bin/open"; chmod +x "$SB/bin/open"
  JH="$SB/home/install-jarvis"
  case "$s" in
    app-slow-ping) printf 'success' > "$SB/scenario"; touch "$SB/slow-ping" ;;
    app-no-surface) printf 'no-surface' > "$SB/scenario" ;;   # 데몬이 자리 열기를 거절(claim_denied) — 자비스는 이 설치 창에서 뜬다
  esac
  printf '%s' "$JH" > "$SB/jarvis-home"
  cat > "$SB/run.sh" <<EOF
. "$SHF" || exit 9
CYS_CLI=cys; MODE=full; CYS_KIND=fork; CYS_FORK_APP="$SB/cys.app"; CYS_APP_OPEN_WAIT_SEC=2
FLEET_POLL_SEC=0; FLEET_AWAKE_TRIES=3; FLEET_WAIT_TRIES=2
CHILD_AWAKE_GAPS='0 0 0'; CHILD_AWAKE_GRACE_SEC=2; CHILD_AWAKE_CAP_SEC=8
MASTER_AWAKE_CAP_SEC=2; MASTER_AWAKE_POLL_SEC=0; MASTER_RETRY_CAP_SEC=2
mkdir -p "$JH"
step_wake
echo "TEST wake rc=\$?"
EOF
  PATH="$SB/bin:$PATH" HOME="$SB/home" JARVIS_HOME="$JH" JARVIS_LIB_ONLY=1 \
    perl -e 'alarm shift; exec @ARGV' 90 bash "$SB/run.sh" </dev/null >"$SB/out.txt" 2>"$SB/err.txt"
  O="$SB/out.txt"; L="$JH/bootstrap.log"
  case "$s" in
    app-slow-ping)
      grep -q "^open -a $SB/cys.app" "$SB/open-calls" 2>/dev/null
      t $? "[맥 앱 창 $s] 전제: 앱 창 열기를 실제로 불렀다(가짜 open)" "$(cat "$SB/open-calls" 2>/dev/null | head -1)"
      w="$(sed -n 's/.*app open: .* waited=\([0-9][0-9]*\)s tries=\([0-9][0-9]*\)$/\1 \2/p' "$L" 2>/dev/null | tail -1)"
      [ -n "$w" ] && [ "${w% *}" -ge 5 ] && [ "${w#* }" = "2" ]
      t $? "[맥 앱 창 $s] 대기 기록 waited 는 실제 흐른 초(ping 2초 × 2바퀴 + 쉼 → 5초 이상 · tries=2 · N16)" "기록: $(grep 'app open:' "$L" 2>/dev/null | tail -1 | sed 's/.*ping_ok/ping_ok/')"
      a="$(grep -n 'app open: ' "$L" 2>/dev/null | head -1 | cut -d: -f1)"; b="$(grep -n '자비스는 그 창(제목 jarvis)에서 깨어납니다' "$L" 2>/dev/null | head -1 | cut -d: -f1)"
      c="$(grep -n 'cys 안에서 자비스를 열었습니다 (surface:9)' "$L" 2>/dev/null | head -1 | cut -d: -f1)"
      [ -n "$a" ] && [ -n "$b" ] && [ -n "$c" ] && [ "$b" -gt "$a" ] && [ "$c" -eq $((b + 1)) ] && [ -s "$SB/newsurface-args" ]
      t $? "[맥 앱 창 $s] 「그 창에서 깨어납니다」는 자리가 열린 뒤에 말한다(앱 대기 기록 뒤 · 「자비스를 열었습니다」 바로 앞 · N3)" "줄 app-open=$a 문장=$b 열었습니다=$c" ;;
    app-no-surface)
      grep -q "^open -a $SB/cys.app" "$SB/open-calls" 2>/dev/null && [ -s "$SB/newsurface-args" ]
      t $? "[맥 앱 창 $s] 전제: 앱 창은 열었고 자리 열기를 불렀다(거절됨)" "open=$(wc -l < "$SB/open-calls" 2>/dev/null | tr -d ' ') newsurface=$([ -s "$SB/newsurface-args" ] && echo 1 || echo 0)"
      ! grep -q '그 창(제목 jarvis)에서 깨어납니다' "$O" && grep -q '자리를 열지 못해 이 설치 창에서 깨웁니다' "$O" && grep -q 'EMU-CLAUDE-INLINE' "$O"
      t $? "[맥 앱 창 $s] 자리를 못 열면 「그 창에서 깨어납니다」가 남지 않고 「이 설치 창에서 깨웁니다」 · 실제로 이 창에서 뜬다(N3)" "$(grep -nE '깨어납니다|깨웁니다|EMU-CLAUDE' "$O" | tr '\n' '|' | cut -c1-240)" ;;
  esac
done
# 윈 정적 축 — 콘솔 빠른 편집(QuickEdit)을 머리글 앞에서 끄고 끝맺음 뒤 되돌린다(installer-awaken-verify-r2 · 윈도우 콘솔은 흉내로 못 돈다)
awk '/^function Disable-ConsoleQuickEdit/{d=1}
     /-band 4294967231\)/{b++}
     /^    Disable-ConsoleQuickEdit   # 창 클릭/{c++; cl=NR}
     /^    Say "=== 자비스 설치 도우미 —/{hl=NR}
     /^    try \{ Write-ClosingNote \} finally \{ Restore-ConsoleQuickEdit \}/{r++}
     END{exit !(d && b==1 && c==1 && r==1 && hl && cl < hl && hl - cl <= 3)}' "$DIR/bootstrap.ps1"
t $? "[윈 정적] 설치 창 빠른 편집을 머리글 앞에서 끄고(0x40 끔) 끝맺음 뒤 되돌린다" "$(grep -nE 'Disable-ConsoleQuickEdit|Restore-ConsoleQuickEdit|4294967231' "$DIR/bootstrap.ps1" | tr '\n' '|' | cut -c1-240)"
# 윈 정적 축 — [3/10] 로그인 대기 구간에서는 빠른 편집이 켜져 있다(installer-speed-pin-0320 ⓔ' · 샌드박스 실기 적색: 꺼져 있으면 로그인 주소를 긁지 못한다)
#   불변식 = 로그인 부르기 바로 앞 줄에서 되돌리고(0x40 켜짐) · 바로 뒷 줄에서 다시 끈다 · 로그인 카드에 긁기 폴백(Alt+Space → E → K) 1줄.
awk '/^    Restore-ConsoleQuickEdit   # \[3\/10\]/{r=NR}
     /^    Step-Login; \$rc = \$script:LoginRc; if \(\$rc -ne 0\) \{ exit \$rc \}/{l=NR}
     /^    Disable-ConsoleQuickEdit   # \[3\/10\]/{d=NR}
     /Alt\+Space → E → K/{k++}
     END{exit !(r && l && d && l - r == 1 && d - l == 1 && k == 1)}' "$DIR/bootstrap.ps1"
t $? "[윈 정적] 로그인 대기 구간에서는 빠른 편집을 켠다(로그인 바로 앞에서 켜고 · 바로 뒤에서 끔 · 긁기 폴백 1줄)" "$(grep -nE 'ConsoleQuickEdit|Step-Login; \$rc|Alt\+Space' "$DIR/bootstrap.ps1" | tr '\n' '|' | cut -c1-240)"
# 부르는 자리 — 맥 [10/10] 성공·「선언은 들어갔으나 덜 섬」 두 곳 · 윈 자동 각성·카드 뒤 성공 두 곳(주석 줄 제외 세기)
[ "$(grep -cE '^[[:space:]]+confirm_child_seats "\$cli"$' "$DIR/bootstrap.sh")" = "2" ] \
  && [ "$(grep -cE '^[[:space:]]+\[void\]\(Confirm-ChildSeats \$cli\)$' "$DIR/bootstrap.ps1")" = "2" ]
t $? "[맥·윈] 자식 자리 확인을 [10/10] 두 자리에서 부른다" "맥 $(grep -cE 'confirm_child_seats "\$cli"' "$DIR/bootstrap.sh") · 윈 $(grep -cE 'Confirm-ChildSeats \$cli' "$DIR/bootstrap.ps1")"

printf '\n통과 %s · 실패 %s\n' "$pass" "$fail"
[ "$fail" -eq 0 ] || exit 1
[ -n "$PW" ] || exit 2
exit 0
