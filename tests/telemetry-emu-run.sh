#!/bin/bash
# 진행 텔레메트리 흉내 실행 시험 — 가짜 서버가 받은 것과 fail-open 을 잰다(계약 v1 2026-09-15).
#
# 무엇을 재는가
#   ① 설치 번호가 같은 실행에서 재사용된다(영숫자·_·- 8~36자)
#   ② 단계 이벤트(start·end·wait·fail·info)가 서버에 도착한다
#   ③ 진행 전송에는 토큰이 없다(계약 §1 — 보고 전부터 나가므로)
#   ④ 살핌(info) 이벤트에 환경 값이 실린다
#   ⑤ 보고가 열리면 진단 자료를 붙인다(출처 헤더 x-help-client · 계약 §3)
#   ⑥ 900KB 넘는 항목은 보내지 않는다(계약 §2)
#   ⑦ 서버가 죽어도 설치가 이어지고 경고는 한 번만(fail-open · 계약 §1)
#
# 쓰는 법: bash tests/telemetry-emu-run.sh [--dir <install-master 자리>]
#   rc 0 = 전건 통과 · 1 = 실패 · 2 = 잴 수 없음(pwsh 없음). 뮤턴트 러너는 「  FAIL 」 줄의 축 이름으로 판정한다.
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
[ -n "$PW" ] || { echo "잴 수 없음: pwsh 가 없다" >&2; exit 2; }
command -v python3 >/dev/null 2>&1 || { echo "python3 가 필요하다(가짜 서버)" >&2; exit 2; }
PS="$(cd "$DIR" && pwd)/bootstrap.ps1"
SB="$(mktemp -d -t telemetry-emu)" || exit 2
STATE="$SB/state"; mkdir -p "$STATE"
python3 "$HERE/telemetry-fake-server.py" "$STATE" &
SRV=$!
trap 'kill "$SRV" 2>/dev/null; rm -rf "$SB"' EXIT
i=0; while [ ! -s "$STATE/port" ] && [ "$i" -lt 100 ]; do sleep 0.1; i=$((i+1)); done
[ -s "$STATE/port" ] || { echo "가짜 서버가 뜨지 않았다" >&2; exit 2; }
PORT="$(cat "$STATE/port")"

# 🔴이 흉내만 진행 이벤트를 **가짜 서버(127.0.0.1)** 로 보낸다 — checks.sh 가 상속시킨 JARVIS_NO_PROGRESS=1 레버를 여기서만 푼다.
#   푸는 조건 = drive.ps1 이 주소를 루프백으로 고정하고 있음을 실측(아니면 풀지 않는다 → 라이브 발신 사고(2026-09-15 15:49) 재발 차단).
if grep -q '127\.0\.0\.1' "$HERE/telemetry-emu/drive.ps1"; then unset JARVIS_NO_PROGRESS; else echo "drive.ps1 에 루프백 주소가 없다 — 레버를 풀지 않는다(흉내 적색 예상)" >&2; fi
perl -e 'alarm shift; exec @ARGV' 60 "$PW" -NoProfile -File "$HERE/telemetry-emu/drive.ps1" -Src "$PS" -Sb "$SB" -Port "$PORT" >"$SB/out.txt" 2>"$SB/err.txt"
LOG="$SB/home/install-jarvis/bootstrap.log"

pass=0; fail=0
ok()  { pass=$((pass+1)); printf '  ok   %s\n' "$1"; }
bad() { fail=$((fail+1)); printf '  FAIL %s  ← %s\n' "$1" "$2"; }
t()   { if [ "$1" -eq 0 ]; then ok "$2"; else bad "$2" "$3"; fi; }

# 파이썬으로 요청 원장을 읽어 질문에 답한다(gid = 축 이름).
q() { python3 - "$STATE/requests.jsonl" "$1" <<'PY'
import json, sys
rows = []
try:
    for line in open(sys.argv[1], encoding="utf-8"):
        line = line.strip()
        if line:
            rows.append(json.loads(line))
except FileNotFoundError:
    pass
what = sys.argv[2]
prog = [r for r in rows if r["path"] == "/api/progress"]
attach = [r for r in rows if r["path"].endswith("/attach")]
if what == "events":
    print(",".join(sorted(set(r.get("event") or "" for r in prog))))
elif what == "prog_token_leak":
    # 토큰이 실린 진행 전송이 하나라도 있으면 1
    print(1 if any(r.get("client") or r.get("has_token_field") for r in prog) else 0)
elif what == "info_env":
    hit = 0
    for r in prog:
        if r.get("event") == "info":
            try:
                b = json.loads(r["body"])
            except Exception:
                b = {}
            env = b.get("env") or {}
            if isinstance(env, dict) and any(k in env for k in ("win_build", "ps_ver", "av")):
                hit = 1
    print(hit)
elif what == "attach_kinds":
    print(",".join(sorted(set(r.get("kind") or "" for r in attach))))
elif what == "attach_no_token":
    # 출처 헤더 없이 온 첨부가 있으면 1(있으면 안 된다)
    print(1 if any(not r.get("client") for r in attach) else 0)
elif what == "prog_count":
    print(len(prog))
PY
}

EVENTS="$(q events)"
ID1="$(cat "$SB/id1" 2>/dev/null || echo)"
ID2="$(cat "$SB/id2" 2>/dev/null || echo)"

# ① 설치 번호 재사용
{ [ -n "$ID1" ] && [ "$ID1" = "$ID2" ] && printf '%s' "$ID1" | grep -qE '^[0-9A-Za-z_-]{8,36}$'; }
t $? "[설치번호] 같은 실행에서 재사용되고 모양이 맞는다" "id1=$ID1 id2=$ID2"

# ② 단계 이벤트 도착
miss=""
for e in start end wait fail info; do case ",$EVENTS," in *",$e,"*) ;; *) miss="$miss $e" ;; esac; done
[ -z "$miss" ]; t $? "[진행] 단계 이벤트가 서버에 도착한다(start·end·wait·fail·info)" "받은 것=[$EVENTS] · 빠짐:$miss"

# ③ 토큰 없음
[ "$(q prog_token_leak)" = "0" ]; t $? "[진행] 진행 전송에는 토큰이 없다" "토큰이 실린 전송이 있다"

# ④ info 에 환경
[ "$(q info_env)" = "1" ]; t $? "[진행] 살핌 이벤트에 환경 값이 실린다" "info 에 env 가 없다"

# ⑤ 첨부 도착 + 출처 헤더
AK="$(q attach_kinds)"
{ case ",$AK," in *",log_full,"*) case ",$AK," in *",env_full,"*) true ;; *) false ;; esac ;; *) false ;; esac; }
t $? "[첨부] 보고가 열리면 진단 자료를 붙인다" "받은 kind=[$AK]"
[ "$(q attach_no_token)" = "0" ]; t $? "[첨부] 첨부에는 출처 헤더가 붙는다" "헤더 없는 첨부가 있다"

# ⑥ 900KB 초과 안 보냄
[ "$(cat "$SB/bigsent" 2>/dev/null)" = "False" ]; t $? "[첨부] 900KB 넘는 항목은 보내지 않는다" "보냈다(bigsent=$(cat "$SB/bigsent" 2>/dev/null))"

# ⑦ fail-open — 죽어도 이어가고 경고 한 번만
n="$(grep -c 'progress send failed (fail-open)' "$LOG" 2>/dev/null || echo 0)"
{ [ "$(cat "$SB/failopen" 2>/dev/null)" = "SURVIVED" ] && [ "$n" = "1" ]; }
t $? "[fail-open] 서버가 죽어도 설치가 이어지고 경고는 한 번만" "survived=$(cat "$SB/failopen" 2>/dev/null) · 경고 ${n}줄 (err: $(head -c 160 "$SB/err.txt"))"

printf '\n통과 %s · 실패 %s\n' "$pass" "$fail"
[ "$fail" -eq 0 ]
