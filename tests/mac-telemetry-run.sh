#!/bin/bash
# 맥 진행 전송·증거·첨부 실측 러너 (TICKET=mac-parity-t2-telemetry · 2026-09-16)
# ★실물 install-master/bootstrap.sh 를 JARVIS_LIB_ONLY=1 로 통째로 읽고 함수를 부른다 — 떼어 낸 조각이 아니다.
# ★가짜 서버(127.0.0.1)만 쓴다 · 바깥에 닿지 않는다 · 실 서버 주소(HELP_API_URL 기본값)로 한 줄도 안 나가는지도 잰다.
# 쓰는 법: bash tests/mac-telemetry-run.sh [bootstrap.sh 경로]   → 끝 줄 「PASS n / FAIL m」 · FAIL 이 있으면 rc 1
set -u
HERE="$(cd "$(dirname "$0")" && pwd)"
SH="${1:-$HERE/../install-master/bootstrap.sh}"
SH="$(cd "$(dirname "$SH")" && pwd)/$(basename "$SH")"
SB="$(mktemp -d "${TMPDIR:-/tmp}/mac-telemetry.XXXXXX")"
PASS=0; FAIL=0
t() { if [ "$1" -eq 0 ]; then PASS=$((PASS + 1)); echo "  ok   $2"; else FAIL=$((FAIL + 1)); echo "  FAIL $2 — ${3:-}"; fi; }

SRV_PID=""
cleanup() { [ -n "$SRV_PID" ] && kill "$SRV_PID" 2>/dev/null; wait "$SRV_PID" 2>/dev/null; rm -rf "$SB"; }
trap cleanup EXIT

start_server() { # <상태 폴더>
  mkdir -p "$1"
  python3 "$HERE/mac-telemetry-fake-server.py" "$1" >/dev/null 2>&1 &
  SRV_PID=$!
  local i=0
  until [ -s "$1/port" ] || [ "$i" -ge 50 ]; do sleep 0.1; i=$((i + 1)); done
  PORT="$(cat "$1/port")"
}

# 공통 실행기 — 새 bash 에서 실물을 읽고 <스크립트> 를 돈다. HOME·JARVIS_HOME·TMPDIR 는 샌드박스.
run_lib() { # run_lib <이름> <스크립트> [추가 env…]
  local name="$1" body="$2"; shift 2
  mkdir -p "$SB/$name/home/install-jarvis" "$SB/$name/tmp"
  # 이미 있는 작업 폴더는 우리 표식이 있어야 채택된다(설치기 본문 관문) — 시험 자리에도 표식을 둔다.
  printf 'jarvis-installer-owned v1\n' > "$SB/$name/home/install-jarvis/.jarvis-owned"
  env -i PATH="/usr/bin:/bin:/usr/sbin:/sbin" LANG="ko_KR.UTF-8" HOME="$SB/$name/home" TMPDIR="$SB/$name/tmp" \
    JARVIS_HOME="$SB/$name/home/install-jarvis" JARVIS_LIB_ONLY=1 T_SH="$SH" T_SB="$SB/$name" "$@" \
    bash -c ". \"\$T_SH\" || exit 5; $body
echo __BODY_END__" > "$SB/$name/stdout.all" 2> "$SB/$name/stderr"
  local rc=$?
  # 설치기의 EXIT 트랩(끝맺음 안내)이 뒤에 찍는 글은 시험 대상이 아니다 — 본문이 끝난 표지 앞까지만 본다.
  sed '/^__BODY_END__$/,$d' "$SB/$name/stdout.all" > "$SB/$name/stdout"
  grep -q '^__BODY_END__$' "$SB/$name/stdout.all" || return 9
  return "$rc"
}

ST="$SB/srv"; start_server "$ST"
URL="http://127.0.0.1:$PORT"
REQ="$ST/requests.jsonl"
reqcount() { [ -f "$REQ" ] && wc -l < "$REQ" | tr -d ' ' || echo 0; }

echo "== ① 진행 전송 23 지점(윈판 Send-Progress 호출 줄 전수) · 칸·값 글자 대조 =="
# 표 = 단계|event|elapsed|detail|env표지|윈판 줄(5a1cd67) — 호출 모양 그대로(부르는 자리는 T1 이 심는다)
POINTS='0/10|fail||J-NET-01||425
2/10|wait|185|||1822
3/10|wait|190|||2292
6/10|wait|200|||2980
10/10|info||awaken:child-retry 1||3635
10/10|info||awaken:child-verified||3675
10/10|info||awaken:child-fail||3680
10/10|info||awaken:master-retry||3736
10/10|info||awaken:master-verified||3766
10/10|info||awaken:master-fail||3799
10/10|end|42|awaken:auto||3851
10/10|info|43|awaken:manual-fallback||3880
1/10|start||||5645
1/10|end||||5651
1/10|info|||env|5652
2/10|start||||5661
2/10|end||rc=0||5662
3/10|start||||5663
3/10|end||rc=0||5670
4/10|start||||5677
4/10|end||rc=0||5678
5/10|start||||5688
5/10|end|12|rc=0||5694'
printf '%s\n' "$POINTS" > "$SB/points.txt"
before=$(reqcount)
run_lib p1 'MODE=full; HELP_API_URL="$T_URL"; INSTALLER_VERSION=0.3.24
  while IFS="|" read -r s e el d en ln; do
    out="$(progress_send "$s" "$e" "$el" "$d" "$en")"
    [ -z "$out" ] || echo "STDOUT-LEAK $ln" >> "$T_SB/leak"
  done < "$T_POINTS"' T_URL="$URL" T_POINTS="$SB/points.txt"
t $? "실물을 읽고 23 지점을 모두 불렀다(rc 0)" "$(tail -3 "$SB/p1/stderr")"
[ ! -f "$SB/p1/leak" ]; t $? "\$(progress_send …) 가 표준 출력에 아무것도 흘리지 않았다" "$(cat "$SB/p1/leak" 2>/dev/null)"
python3 - "$REQ" "$SB/points.txt" "$before" "$SB/p1/home/install-jarvis/install-id" <<'PY'
import json, re, sys
reqs = [json.loads(l) for l in open(sys.argv[1], encoding="utf-8")][int(sys.argv[3]):]
pts = [l.rstrip("\n").split("|") for l in open(sys.argv[2], encoding="utf-8") if l.strip()]
idf = open(sys.argv[4], encoding="utf-8").read().strip()
CLIENT_AT = re.compile(r"^[0-9]{4}-(?:0[1-9]|1[0-2])-(?:0[1-9]|[12][0-9]|3[01])T(?:[01][0-9]|2[0-3]):[0-5][0-9]:[0-5][0-9](?:\.[0-9]{1,9})?(?:Z|[+-](?:[01][0-9]|2[0-3]):?[0-5][0-9])?$")
bad = []
if len(reqs) != len(pts): bad.append(f"요청 수 {len(reqs)} ≠ 지점 수 {len(pts)}")
ids = set()
for r, p in zip(reqs, pts):
    s, e, el, d, en, ln = p
    if r["path"] != "/api/progress": bad.append(f"{ln}: 경로 {r['path']}")
    if not r["headers"].get("content-type", "").startswith("application/json"): bad.append(f"{ln}: content-type {r['headers'].get('content-type')}")
    b = json.loads(r["body"])
    keys = list(b.keys())
    want = ["install_id", "installer_version", "os", "step", "event", "at"] + (["elapsed_s"] if el else []) + (["detail"] if d else []) + (["env"] if en else [])
    if keys != want: bad.append(f"{ln}: 칸 순서 {keys} ≠ {want}")
    if b.get("os") != "mac": bad.append(f"{ln}: os {b.get('os')}")
    if b.get("installer_version") != "0.3.24": bad.append(f"{ln}: 판번 {b.get('installer_version')}")
    if b.get("step") != s or b.get("event") != e: bad.append(f"{ln}: step/event {b.get('step')}/{b.get('event')}")
    if el and b.get("elapsed_s") != int(el): bad.append(f"{ln}: elapsed_s {b.get('elapsed_s')!r}")
    if d and b.get("detail") != d: bad.append(f"{ln}: detail {b.get('detail')!r}")
    if not CLIENT_AT.match(str(b.get("at"))): bad.append(f"{ln}: at 모양 {b.get('at')}")
    if not re.fullmatch(r"[0-9A-Za-z_-]{8,36}", str(b.get("install_id"))): bad.append(f"{ln}: install_id 모양")
    if r["bytes"] > 8 * 1024: bad.append(f"{ln}: 본문 {r['bytes']}B > 8KB")
    if en:
        env = b.get("env")
        allowed = {"claude_ver", "cys_ver", "win_build", "ps_ver", "av", "browser", "mac_ver", "admin"}   # 서버 ENV_TEXT_KEYS(web-install c14d66d · mac_ver 추가)
        # mac_ver = 맥 운영체제 판본(sw_vers) — 맥 env 에서 빠지면 붉다 · win_build 에 섞이면 붉다
        if not isinstance(env, dict) or not set(env) <= allowed or not isinstance(env.get("admin"), bool) \
           or not re.fullmatch(r"[0-9]+(\.[0-9]+){0,3}", str(env.get("mac_ver"))) or "win_build" in env:
            bad.append(f"{ln}: env {env}")
    ids.add(b.get("install_id"))
if len(ids) != 1: bad.append(f"install_id 가 {len(ids)}개")
if ids and idf not in ids: bad.append(f"install-id 파일({idf}) ≠ 보낸 값 {ids}")
print("\n".join(bad) if bad else "OK")
sys.exit(1 if bad else 0)
PY
t $? "23 지점 전부: 경로·content-type·칸 순서(윈판 [ordered])·os=mac·판번·step·event·elapsed_s·detail·at 모양(서버 CLIENT_AT)·8KB·env 열쇠·install_id 하나"
ID1="$(cat "$SB/p1/home/install-jarvis/install-id" 2>/dev/null)"
[ "$(stat -f %Lp "$SB/p1/home/install-jarvis/install-id" 2>/dev/null)" = "600" ]; t $? "install-id 파일은 본인만 읽는다(600)" "$(stat -f %Lp "$SB/p1/home/install-jarvis/install-id" 2>/dev/null)"

echo "== ② install_id 보존(재실행 = 같은 번호) · 깨진 파일 = 새 번호 =="
mkdir -p "$SB/p2/home/install-jarvis"; cp "$SB/p1/home/install-jarvis/install-id" "$SB/p2/home/install-jarvis/install-id"
run_lib p2 'MODE=full; HELP_API_URL="$T_URL"; INSTALLER_VERSION=0.3.24; install_id_ensure; printf "%s" "$INSTALL_ID" > "$T_SB/id"' T_URL="$URL"
[ "$(cat "$SB/p2/id")" = "$ID1" ]; t $? "새 프로세스가 같은 파일에서 같은 번호를 읽었다($ID1)" "$(cat "$SB/p2/id")"
mkdir -p "$SB/p3/home/install-jarvis"; printf 'bad id with spaces!\r\n' > "$SB/p3/home/install-jarvis/install-id"
run_lib p3 'install_id_ensure; printf "%s" "$INSTALL_ID" > "$T_SB/id"'
{ id3="$(cat "$SB/p3/id")"; [ "$id3" != "bad id with spaces!" ] && [ -n "$id3" ] && [ "$(cat "$SB/p3/home/install-jarvis/install-id")" = "$id3" ]; }
t $? "모양이 틀린 파일은 새 번호로 갈아 쓴다" "$(cat "$SB/p3/id")"
mkdir -p "$SB/p3b/home/install-jarvis"; printf 'Abc_def-1234567\r\n' > "$SB/p3b/home/install-jarvis/install-id"
run_lib p3b 'install_id_ensure; printf "%s" "$INSTALL_ID" > "$T_SB/id"'
[ "$(cat "$SB/p3b/id")" = "Abc_def-1234567" ]; t $? "윈판이 쓴 CRLF 줄 끝도 걷고 같은 번호를 쓴다" "$(cat "$SB/p3b/id")"

echo "== ③ 레버·모드 — JARVIS_NO_PROGRESS=1 · dry · detect 이면 0건 =="
before=$(reqcount)
run_lib p4 'HELP_API_URL="$T_URL"; INSTALLER_VERSION=0.3.24
  MODE=full; JARVIS_NO_PROGRESS=1; progress_send 1/10 start; evidence_event_send fail ""; step_baselines_update; echo "$STEP_BASELINE_NOTE" > "$T_SB/note1"
  unset JARVIS_NO_PROGRESS; MODE=dry; progress_send 1/10 start; evidence_event_send fail ""; step_baselines_update; echo "$STEP_BASELINE_NOTE" > "$T_SB/note2"
  MODE=detect; progress_send 1/10 start' T_URL="$URL"
[ "$(reqcount)" = "$before" ]; t $? "요청 0건(레버·dry·detect)" "$(( $(reqcount) - before ))건"
[ "$(cat "$SB/p4/note1")" = "skip:no-progress" ] && [ "$(cat "$SB/p4/note2")" = "skip:mode" ]; t $? "기준선 표지 = skip:no-progress · skip:mode(윈판 같은 글)" "$(cat "$SB/p4/note1" "$SB/p4/note2" 2>/dev/null | tr '\n' ' ')"

echo "== ④ fail-open — 닿지 않는 주소 · 서버 500 =="
run_lib p5 'MODE=full; INSTALLER_VERSION=0.3.24; JARVIS_PROGRESS_URL="http://127.0.0.1:9/api/progress"
  s=$(date +%s); progress_send 1/10 start; progress_send 1/10 end; rc=$?; e=$(date +%s)
  echo "$rc $((e - s))" > "$T_SB/r"'
read -r rc5 sec5 < "$SB/p5/r"
[ "$rc5" = "0" ]; t $? "닿지 않아도 rc 0(설치를 막지 않는다)" "rc=$rc5"
[ "$sec5" -le 8 ]; t $? "두 번 보내도 상한 안에 끝났다(${sec5}s ≤ 3s×2+여유)" "${sec5}s"
[ "$(grep -c 'progress send failed (fail-open)' "$SB/p5/home/install-jarvis/bootstrap.log" 2>/dev/null)" = "1" ]; t $? "경고는 실행당 한 줄(윈판 문구 그대로)" "$(grep 'progress send' "$SB/p5/home/install-jarvis/bootstrap.log" 2>/dev/null)"
[ ! -s "$SB/p5/stdout" ]; t $? "화면(표준 출력)에 아무것도 안 찍었다" "$(head -2 "$SB/p5/stdout")"
echo 500 > "$ST/progress.status"
run_lib p6 'MODE=full; HELP_API_URL="$T_URL"; INSTALLER_VERSION=0.3.24; progress_send 2/10 start; echo $? > "$T_SB/rc"' T_URL="$URL"
rm -f "$ST/progress.status"
[ "$(cat "$SB/p6/rc")" = "0" ] && grep -q 'progress send failed (fail-open) - http 500' "$SB/p6/home/install-jarvis/bootstrap.log"; t $? "서버 500 도 rc 0 · 기록 한 줄(http 500)" "$(grep 'progress' "$SB/p6/home/install-jarvis/bootstrap.log" 2>/dev/null)"

echo "== ⑤ 마스킹 — 대조표 tests/mask-vectors.json 전건 · 식 글자 대조 =="
python3 - "$HERE/mask-vectors.json" "$SB/vec" <<'PY'
import json, os, sys
d = json.load(open(sys.argv[1], encoding="utf-8"))
os.makedirs(sys.argv[2], exist_ok=True)
for i, v in enumerate(d["vectors"]):
    open(os.path.join(sys.argv[2], f"{i}.in"), "w", encoding="utf-8").write(v["input"])
    open(os.path.join(sys.argv[2], f"{i}.want"), "w", encoding="utf-8").write(v["expected"])
print(len(d["vectors"]))
PY
NV="$(ls "$SB/vec"/*.in | wc -l | tr -d ' ')"
run_lib p7 'for f in "$T_VEC"/*.in; do PG_IN="$f" PG_OUT="${f%.in}.got" progress_js mask >/dev/null 2>&1; done' T_VEC="$SB/vec"
miss=""
for f in "$SB/vec"/*.in; do
  b="${f%.in}"; cmp -s "$b.got" "$b.want" || miss="$miss $(basename "$b")"
done
[ -z "$miss" ]; t $? "대조표 벡터 ${NV}건 전부 기대값과 바이트 동일" "틀린 번호:$miss"
python3 - "$HERE/mask-vectors.json" "$SH" <<'PY'
import json, re, sys
d = json.load(open(sys.argv[1], encoding="utf-8"))
src = open(sys.argv[2], encoding="utf-8").read()
blk = src[src.index("var MASK_RULES = ["):src.index("var MASK_NAME_LINES")]
lits = re.findall(r'^\s*\[(/.*/[gi]*), "', blk, re.M)
nl = re.search(r'^var MASK_NAME_LINES = (/.*/[gi]*);$', src, re.M)
if nl: lits.append(nl.group(1))
cats = [c.get("js_regex") for c in d["categories"] if c.get("js_regex")]
missing = [c for c in cats if c not in lits]
extra = [l for l in lits if l not in cats]
print("대조표 js_regex", len(cats), "· 파일 식", len(lits))
if missing: print("대조표에 있는데 파일에 없음:", missing)
if extra: print("파일에 있는데 대조표에 없음:", extra)
sys.exit(1 if (missing or extra) else 0)
PY
t $? "파일의 마스킹 식 = 대조표 js_regex 글자 그대로(양방향 · 드리프트 0)"

echo "== ⑥ 실패 증거(evidence_once fail) — 기록 끝부분 · 마스킹 · (이유×단계) 한 번 =="
mkdir -p "$SB/p8/home/install-jarvis"
{ printf '%s\n' "2026-09-16T22:00:00+0900 [1/10] 이 컴퓨터를 살펴봅니다."
  printf '%s\n' "2026-09-16T22:00:01+0900 USER=hongildong"
  printf '%s\n' "2026-09-16T22:00:02+0900 경로 /Users/hongildong/install-jarvis/bootstrap.log"
  printf '%s\n' "2026-09-16T22:00:03+0900 메일 hong.gil+x@example.co.kr · Authorization: Bearer abcSECRET123.tok-en"
  printf '%s\n' "2026-09-16T22:00:04+0900 Paste code here if prompted > aBcDeFgHiJkLmNoPqRsTuVwXyZ0123#stateABCDEFGH"
  printf '%s\n' "2026-09-16T22:00:05+0900 [3/10] 지금 로그인 화면을 엽니다." ; } > "$SB/p8/home/install-jarvis/bootstrap.log"
before=$(reqcount)
run_lib p8 'MODE=full; HELP_API_URL="$T_URL"; INSTALLER_VERSION=0.3.24; evidence_once fail; evidence_once fail; evidence_once stall' T_URL="$URL"
python3 - "$REQ" "$before" <<'PY'
import json, sys
reqs = [json.loads(l) for l in open(sys.argv[1], encoding="utf-8")][int(sys.argv[2]):]
ev = [json.loads(r["body"]) for r in reqs if r["what"] == "progress"]
bad = []
if [e.get("reason") for e in ev] != ["fail", "stall"]: bad.append(f"이유 순서 {[e.get('reason') for e in ev]} (같은 이유·단계 두 번째는 안 나가야 한다)")
for e in ev:
    if list(e.keys()) != ["install_id", "installer_version", "os", "step", "event", "at", "reason", "text", "masked"]: bad.append(f"칸 순서 {list(e.keys())}")
    if e.get("event") != "evidence" or e.get("masked") is not True or e.get("step") != "3/10": bad.append(f"event/masked/step {e.get('event')} {e.get('masked')} {e.get('step')}")
    t = e.get("text", "")
    for raw in ["hongildong", "hong.gil", "abcSECRET", "aBcDeFgHiJkLmNoPq", "example.co.kr"]:
        if raw in t: bad.append(f"원문이 샜다: {raw}")
    for mark in ["<EMAIL>", "<TOKEN>", "<LOGIN_CODE>", "/Users/<USER>/install-jarvis"]:
        if mark not in t: bad.append(f"표식 없음: {mark}")
print("\n".join(bad) if bad else "OK"); sys.exit(1 if bad else 0)
PY
t $? "fail·stall 각 1건(두 번째 fail 은 안 나감) · 칸 순서 윈판 동형 · masked=true · 이메일·토큰·로그인 코드·집 이름 전부 가림"
grep -q 'evidence sent: fail|3/10' "$SB/p8/home/install-jarvis/bootstrap.log"; t $? "기록에 「evidence sent: fail|3/10 NB」 한 줄" "$(grep evidence "$SB/p8/home/install-jarvis/bootstrap.log" | head -2)"
# N1(t4-fix) 뒤 기본은 창 그림 꺼짐 — 실패 증거도 창 번호를 찾지 않는다(옛 축 「못 고르면 까닭」은 이 운영 맥의 창 목록에 따라 갈렸다 · 켠 갈래는 ⑪-2 가 가짜 촬영기로 잰다).
grep -q '창 그림 = 꺼짐(기본) · 글자 증거만' "$SB/p8/home/install-jarvis/bootstrap.log" && ! grep -q 'installer_window skip' "$SB/p8/home/install-jarvis/bootstrap.log"
t $? "실패 증거도 기본은 창 그림 꺼짐 · 창 번호를 찾지 않는다(전체 화면 대체 0 · N1)" "$(grep -iE 'skip|창 그림' "$SB/p8/home/install-jarvis/bootstrap.log" | head -3)"
ls "$SB/p8/home/install-jarvis"/.progress.* >/dev/null 2>&1; [ $? -ne 0 ]; t $? "임시 폴더를 남기지 않았다"

echo "== ⑥-2 진단 코드(jcode) — 막힌 자리 fail 전송 + 실패 증거(윈판 Write-JCode 동형) =="
mkdir -p "$SB/p8b/home/install-jarvis"; printf '%s\n' "2026-09-16T22:00:00+0900 [6/10] cys 를 설치합니다." > "$SB/p8b/home/install-jarvis/bootstrap.log"
before=$(reqcount)
run_lib p8b 'MODE=full; HELP_API_URL="$T_URL"; INSTALLER_VERSION=0.3.24; jcode J-CYS-07 "설치 실패"' T_URL="$URL"
python3 - "$REQ" "$before" <<'PY2'
import json, sys
reqs = [json.loads(l) for l in open(sys.argv[1], encoding="utf-8")][int(sys.argv[2]):]
ev = [json.loads(r["body"]) for r in reqs if r["what"] == "progress"]
got = [(e.get("step"), e.get("event"), e.get("detail"), e.get("reason")) for e in ev]
want = [("6/10", "fail", "J-CYS-07", None), ("6/10", "evidence", None, "fail")]
print(got); sys.exit(0 if got == want else 1)
PY2
t $? "jcode 한 번 → [6/10] fail(detail=코드) 1건 + fail 증거 1건(이 순서)"

echo "== ⑦ 오류 글 촉발(say → error-text) · 사유 글 마스킹 · 재귀 없음 =="
before=$(reqcount)
run_lib p9 'MODE=full; HELP_API_URL="$T_URL"; INSTALLER_VERSION=0.3.24; say "[5/10] npm ERR! install failed for hong@example.com at /Users/hongildong/x"; say "[5/10] 두 번째 Failed 줄"; say "평범한 줄"' T_URL="$URL"
python3 - "$REQ" "$before" <<'PY'
import json, sys
reqs = [json.loads(l) for l in open(sys.argv[1], encoding="utf-8")][int(sys.argv[2]):]
ev = [json.loads(r["body"]) for r in reqs if r["what"] == "progress"]
bad = []
if len(ev) != 1: bad.append(f"증거 {len(ev)}건(이유×단계 한 번이어야 한다)")
for e in ev:
    t = e.get("text", "")
    if e.get("reason") != "error-text" or not t.startswith("[error-text] [5/10] npm ERR! install failed for <EMAIL> at /Users/<USER>/x\n"): bad.append("머리 = 마스킹한 「[이유] 사유」 가 아니다: " + t[:120])
    if "hong@example.com" in t or "hongildong" in t: bad.append("원문이 샜다")
print("\n".join(bad) if bad else "OK"); sys.exit(1 if bad else 0)
PY
t $? "오류 낱말이 든 say 한 번 → error-text 증거 1건 · 머리 = 마스킹한 사유 · 원문 0"
grep -q 'capture evidence: error-text|5/10 \[5/10\] npm ERR! install failed for <EMAIL> at /Users/<USER>/x' "$SB/p9/home/install-jarvis/bootstrap.log"; t $? "기록 파일의 사유 글도 가렸다" "$(grep 'capture evidence' "$SB/p9/home/install-jarvis/bootstrap.log")"
[ "$(grep -c '^' "$SB/p9/stdout")" = "3" ]; t $? "화면에는 say 세 줄만(증거 함수가 화면에 흘리지 않는다)" "$(cat "$SB/p9/stdout")"

echo "== ⑧ 운영팀 촬영 요청(capture) — 진행 답에 실려 오면 받아 두고 1회 처리 · 모르는 종류는 그것만 건너뜀 =="
printf '{"id":"c1","install_id":"x","kinds":["installer_window","whole_screen","app_window"],"expires_at":"z"}' > "$ST/capture.json"
before=$(reqcount)
run_lib p10 'MODE=full; HELP_API_URL="$T_URL"; INSTALLER_VERSION=0.3.24; progress_send 5/10 start; echo "$CAPTURE_REQUESTED" > "$T_SB/req"; capture_requested_run; capture_requested_run' T_URL="$URL"
[ "$(cat "$SB/p10/req")" = "installer_window app_window" ]; t $? "받아 둔 종류 = installer_window app_window(whole_screen 은 건너뜀)" "$(cat "$SB/p10/req")"
python3 - "$REQ" "$before" <<'PY'
import json, sys
reqs = [json.loads(l) for l in open(sys.argv[1], encoding="utf-8")][int(sys.argv[2]):]
ev = [json.loads(r["body"]) for r in reqs if r["what"] == "progress"]
reasons = [e.get("reason") for e in ev if e.get("event") == "evidence"]
ok = reasons == ["requested"] and all("text" not in e for e in ev if e.get("event") == "evidence")
print(reasons); sys.exit(0 if ok else 1)
PY
t $? "requested 증거 1건(두 번째 호출은 아무것도 안 함 · 글 칸 없음 = 윈판과 같다)"
grep -q 'capture request 받음: installer_window,app_window' "$SB/p10/home/install-jarvis/bootstrap.log" && grep -q 'capture requested 처리: installer_window,app_window' "$SB/p10/home/install-jarvis/bootstrap.log"
t $? "기록 = 받음·처리 두 줄(윈판 문구)" "$(grep capture "$SB/p10/home/install-jarvis/bootstrap.log")"

echo "== ⑨ 그림 올리기 — 머리글 토큰·경로·content-type·길이 · 429 image_cap 뒤 멈춤 · 한 장 상한 =="
head -c 2048 /dev/urandom > "$SB/fake.jpg"
before=$(reqcount)
run_lib p11 'MODE=full; HELP_API_URL="$T_URL"; INSTALLER_VERSION=0.3.24
  evidence_event_send slow "" && echo "slot $EV_SEQ ${#EV_TOKEN}" > "$T_SB/slot"
  evidence_image_send installer_window "$T_JPG"; echo $? > "$T_SB/rc1"
  evidence_image_send whole_screen "$T_JPG"; echo $? > "$T_SB/rc2"' T_URL="$URL" T_JPG="$SB/fake.jpg"
python3 - "$REQ" "$before" "$SB/fake.jpg" <<'PY'
import hashlib, json, sys
reqs = [json.loads(l) for l in open(sys.argv[1], encoding="utf-8")][int(sys.argv[2]):]
img = [r for r in reqs if r["what"] == "image"]
sha = hashlib.sha256(open(sys.argv[3], "rb").read()).hexdigest()
bad = []
if len(img) != 1: bad.append(f"그림 요청 {len(img)}건")
for r in img:
    if not r["path"].startswith("/api/progress/evidence/901/image?kind=installer_window&filename=installer_window.jpg") and "/image?kind=installer_window&filename=installer_window.jpg" not in r["path"]: bad.append("경로 " + r["path"])
    if r["headers"].get("x-progress-upload") != "f" * 64: bad.append("토큰 머리글")
    if r["headers"].get("content-type") != "image/jpeg": bad.append("content-type " + str(r["headers"].get("content-type")))
    if r["headers"].get("content-length") != "2048" or r["sha256"] != sha: bad.append("길이·지문 불일치")
print("\n".join(bad) if bad else "OK"); sys.exit(1 if bad else 0)
PY
t $? "그림 1건: 경로 evidence/<seq>/image?kind=&filename= · x-progress-upload=토큰 · image/jpeg · 길이·sha256 원본과 같음 · 계약 밖 종류는 안 보냄"
[ "$(cat "$SB/p11/rc1")" = "0" ] && [ "$(cat "$SB/p11/rc2")" = "1" ]; t $? "rc = 보냄 0 · 계약 밖 종류 1"
echo 429 > "$ST/image.status"; echo image_cap > "$ST/image.error"
before=$(reqcount)
run_lib p12 'MODE=full; HELP_API_URL="$T_URL"; INSTALLER_VERSION=0.3.24
  evidence_event_send slow ""; evidence_image_send installer_window "$T_JPG"; evidence_image_send app_window "$T_JPG"; echo "$EVIDENCE_IMAGE_DONE" > "$T_SB/done"' T_URL="$URL" T_JPG="$SB/fake.jpg"
rm -f "$ST/image.status" "$ST/image.error"
[ "$(python3 -c 'import json,sys; print(sum(1 for l in list(open(sys.argv[1]))[int(sys.argv[2]):] if json.loads(l)["what"]=="image"))' "$REQ" "$before")" = "1" ] && [ "$(cat "$SB/p12/done")" = "1" ]
t $? "429 image_cap 뒤에는 더 올리지 않는다(그림 요청 1건 · 멈춤 표지)"
head -c 1572865 /dev/zero > "$SB/big.jpg"
before=$(reqcount)
run_lib p13 'MODE=full; HELP_API_URL="$T_URL"; INSTALLER_VERSION=0.3.24; evidence_event_send slow ""; evidence_image_send installer_window "$T_JPG"; echo $? > "$T_SB/rc"' T_URL="$URL" T_JPG="$SB/big.jpg"
[ "$(cat "$SB/p13/rc")" = "1" ] && grep -q 'evidence image skip (1572865B > 한 장 상한): installer_window' "$SB/p13/home/install-jarvis/bootstrap.log"; t $? "1.5MB 를 넘는 그림은 보내지 않는다(기록 한 줄)"

echo "== ⑩ 단계 기준선 — 받은 칸만 쓰고 모르면 거짓 =="
printf '{"os":"mac","steps":[{"step":"5/10","median_elapsed_s":10,"samples":7},{"step":"6/10","median_elapsed_s":null,"samples":2},{"step":"bad","median_elapsed_s":3}]}' > "$ST/baseline.json"
run_lib p14 'MODE=full; HELP_API_URL="$T_URL"; INSTALLER_VERSION=0.3.24; step_baselines_update
  step_is_slow 5/10 21; a=$?; step_is_slow 5/10 20; b=$?; step_is_slow 6/10 999; c=$?; step_is_slow 7/10 999; d=$?
  echo "$STEP_BASELINE_NOTE $a $b $c $d $(step_baseline_sec 5/10)" > "$T_SB/r"' T_URL="$URL"
rm -f "$ST/baseline.json"
[ "$(cat "$SB/p14/r")" = "ok:1 0 1 1 1 10" ]; t $? "ok:1 · 21s>2×10 느림 · 20s 아님 · null 칸·없는 칸 = 거짓 · 기준 10" "$(cat "$SB/p14/r")"
grep -q '"path": "/api/progress/baseline?os=mac"' "$REQ"; t $? "기준선은 os=mac 으로 묻는다"
run_lib p15 'MODE=full; HELP_API_URL="$T_URL"; INSTALLER_VERSION=0.3.24; step_baselines_update; echo "$STEP_BASELINE_NOTE" > "$T_SB/r"' T_URL="$URL"
[ "$(cat "$SB/p15/r")" = "http:404" ] && grep -q 'step baseline: http:404 (빈 칸 = 그 단계 느림 촉발 꺼짐)' "$SB/p15/home/install-jarvis/bootstrap.log"; t $? "못 받으면 http:404 · 기록 문구 윈판 그대로" "$(cat "$SB/p15/r")"

echo "== ⑪ 설치 뒤 증거(post-install) · 자식 자리 정체 증거 =="
mkdir -p "$SB/bin"
cat > "$SB/bin/fakecys" <<'EOF'
#!/bin/bash
printf '%s\n' "Claude Code v2" "Stop hook error: failed" "user hong@example.com in /Users/hongildong/work" "hook error again" "> "
EOF
chmod +x "$SB/bin/fakecys"
before=$(reqcount)
run_lib p16 'MODE=full; HELP_API_URL="$T_URL"; INSTALLER_VERSION=0.3.24
  post_install_evidence "$T_CLI" surface:9; post_install_evidence "$T_CLI" surface:9
  child_stall_evidence worker "$(printf "line1\nmail hong@example.com\n")"; child_stall_evidence worker "again"' T_URL="$URL" T_CLI="$SB/bin/fakecys"
python3 - "$REQ" "$before" <<'PY'
import json, sys
reqs = [json.loads(l) for l in open(sys.argv[1], encoding="utf-8")][int(sys.argv[2]):]
ev = [json.loads(r["body"]) for r in reqs if r["what"] == "progress"]
bad = []
if [e.get("reason") for e in ev] != ["post-install", "stall"]: bad.append(f"이유 {[e.get('reason') for e in ev]}")
if ev:
    t = ev[0].get("text", "")
    if not t.startswith("seat=master\nhook_errors=2\n"): bad.append("post-install 머리: " + t[:60])
    if "hong@example.com" in t or "hongildong" in t: bad.append("post-install 원문이 샜다")
if len(ev) > 1:
    t = ev[1].get("text", "")
    if not t.startswith("seat=worker\n") or "<EMAIL>" not in t: bad.append("stall 글: " + t[:60])
print("\n".join(bad) if bad else "OK"); sys.exit(1 if bad else 0)
PY
t $? "post-install 1건(seat=master · hook_errors=2 · 가림) · 자식 stall 1건(seat=worker · 가림) · 두 번째 호출은 안 나감"
[ "$(grep -c '창 그림 = 꺼짐(기본) · 글자 증거만' "$SB/p16/home/install-jarvis/bootstrap.log")" = "1" ] && ! grep -q 'app window skip\|app_window skip' "$SB/p16/home/install-jarvis/bootstrap.log"
t $? "기본(켜라는 말 없음) = 앱 창 번호도 찾지 않고 「창 그림 = 꺼짐」 기록 한 줄(N1)" "$(grep -iE '창 그림|app' "$SB/p16/home/install-jarvis/bootstrap.log" | head -2)"

echo "== ⑪-2 창 그림 기본 꺼짐(N1 · master 판정 「화면 기록 권한 미요청」) — 가짜 촬영기로 「불렸는가」를 잰다 =="
# ⛔진짜 /usr/sbin/screencapture 는 어느 갈래에서도 부르지 않는다 — 운영 맥에서 권한 창을 띄우는 것이 바로 이 결함이다.
cat > "$SB/bin/fakeshot" <<'EOF'
#!/bin/bash
echo "called $*" >> "$T_SB/shot-calls"
for a; do last="$a"; done
printf 'not-a-jpeg' > "$last"
EOF
chmod +x "$SB/bin/fakeshot"
SHOT_BODY='MODE=full; HELP_API_URL="$T_URL"; INSTALLER_VERSION=0.3.24
  evidence_kind_jpeg installer_window "$T_SB/a.jpg"; echo $? > "$T_SB/rc1"
  evidence_kind_jpeg app_window "$T_SB/b.jpg"; echo $? > "$T_SB/rc2"
  evidence_event_send post-install "" && evidence_images_send app_window installer_window
  CYS_KIND=fork; CYS_FORK_APP="$T_SB/nope.app"; unset JARVIS_CAPTURE_APP_WINDOW_ID; evidence_kind_jpeg app_window "$T_SB/c.jpg"'
before=$(reqcount)
run_lib p16off "$SHOT_BODY" T_URL="$URL" JARVIS_TEST_SCREENCAPTURE="$SB/bin/fakeshot" JARVIS_CAPTURE_WINDOW_ID=77 JARVIS_CAPTURE_APP_WINDOW_ID=78
imgs_off="$(python3 -c 'import json,sys; print(sum(1 for l in list(open(sys.argv[1],encoding="utf-8"))[int(sys.argv[2]):] if json.loads(l)["what"]=="image"))' "$REQ" "$before")"
[ ! -e "$SB/p16off/shot-calls" ] && [ "$(cat "$SB/p16off/rc1")" = "1" ] && [ "$(cat "$SB/p16off/rc2")" = "1" ] && [ "$imgs_off" = "0" ] \
  && [ "$(grep -c '창 그림 = 꺼짐(기본) · 글자 증거만' "$SB/p16off/home/install-jarvis/bootstrap.log")" = "1" ]
t $? "[N1 꺼짐] 창 번호가 주어져도 촬영기 호출 0 · 그림 요청 0 · 「꺼짐」 기록은 설치당 한 줄" "calls=$(cat "$SB/p16off/shot-calls" 2>/dev/null | wc -l | tr -d ' ') rc=$(cat "$SB/p16off/rc1" 2>/dev/null),$(cat "$SB/p16off/rc2" 2>/dev/null) imgs=$imgs_off"
run_lib p16on "$SHOT_BODY" T_URL="$URL" JARVIS_TEST_SCREENCAPTURE="$SB/bin/fakeshot" JARVIS_CAPTURE_WINDOW_ID=77 JARVIS_CAPTURE_APP_WINDOW_ID=78 JARVIS_EVIDENCE_IMAGES=1
# 이 축이 대상에 닿는지 먼저 단언 — 켜면 같은 몸통이 가짜 촬영기를 실제로 부른다(끄고 0 이 공허한 0 이 아니다)
grep -q -- '-l 77 ' "$SB/p16on/shot-calls" 2>/dev/null && grep -q -- '-l 78 ' "$SB/p16on/shot-calls" && ! grep -q '창 그림 = 꺼짐' "$SB/p16on/home/install-jarvis/bootstrap.log"
t $? "[N1 켬] JARVIS_EVIDENCE_IMAGES=1 이면 같은 몸통이 촬영기를 부른다(설치 창 77 · 앱 창 78 — 꺼짐 축이 대상에 닿는다는 증명)" "$(cat "$SB/p16on/shot-calls" 2>/dev/null | head -3 | tr '\n' '|')"
grep -q 'app window skip\|app_window skip' "$SB/p16on/home/install-jarvis/bootstrap.log"; t $? "[N1 켬] 앱 창을 못 고르면 찍지 않고 까닭을 적는다" "$(grep -i 'app' "$SB/p16on/home/install-jarvis/bootstrap.log" | head -2)"
grep -cE '/usr/sbin/screencapture' "$SH" | grep -qx 1 && grep -qE '^SCREENCAPTURE_BIN="\$\{JARVIS_TEST_SCREENCAPTURE:-/usr/sbin/screencapture\}"' "$SH"
t $? "[N1 정적] 진짜 촬영기 경로는 기본값 한 곳에만 있다(다른 자리가 직접 부르지 않는다)" "$(grep -n '/usr/sbin/screencapture' "$SH" | head -3 | tr '\n' '|')"

echo "== ⑫ 첨부(보고가 열린 뒤) — 출처 머리글 · 계약 3절 순서 · 맥에 없는 것은 까닭 한 줄 =="
before=$(reqcount)
mkdir -p "$SB/p17/home/install-jarvis"; echo "log line" > "$SB/p17/home/install-jarvis/bootstrap.log"; echo "# env" > "$SB/p17/home/install-jarvis/env-report.md"
run_lib p17 'MODE=full; HELP_API_URL="$T_URL"; INSTALLER_VERSION=0.3.24; RH_ID=TEST2345; RH_TMP="$T_SB/rh"; mkdir -p "$RH_TMP"
  printf "x-help-client: %s\n" aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa > "$RH_TMP/client-header"
  help_fail_attachments' T_URL="$URL"
python3 - "$REQ" "$before" <<'PY'
import json, sys
reqs = [json.loads(l) for l in open(sys.argv[1], encoding="utf-8")][int(sys.argv[2]):]
att = [r for r in reqs if r["what"] == "attach"]
kinds = [r["kind"] for r in att]
bad = []
if kinds != ["log_full", "proc_tree", "env_full"]: bad.append(f"순서 {kinds}")
if any(r["headers"].get("x-help-client") != "a" * 64 for r in att): bad.append("출처 머리글 없음")
if any(r["b64_len"] == 0 for r in att): bad.append("빈 내용")
print("\n".join(bad) if bad else "OK"); sys.exit(1 if bad else 0)
PY
t $? "첨부 = log_full·proc_tree·env_full 순서 · x-help-client 머리글 · 내용 있음(설치 창 그림은 창을 못 골라 빠짐)"
grep -q 'attach skip (맥에는 트랜스크립트가 없다' "$SB/p17/home/install-jarvis/bootstrap.log" && grep -q 'attach: login window capture 없음' "$SB/p17/home/install-jarvis/bootstrap.log"; t $? "맥에 없는 두 칸(console_text·login_window_png)은 까닭 한 줄씩"

echo "== ⑬-2 [8/10] 자가진단 요약 줄(N12 · t4-fix) — 실물 step_prepare_account · 가짜 cys(ping·doctor) · 키체인·launchctl·신뢰 기록은 막아 둔다 =="
# ⛔운영 맥 무접촉: 로그인 복사(키체인)·자동 시작 조회(launchctl)·신뢰 기록 쓰기는 함수를 덮어 부르지 않는다 — 재는 것은 doctor 출력 → 문구·rc 뿐이다.
cat > "$SB/bin/doccys" <<'EOF'
#!/bin/bash
case "$1" in
  ping) echo pong ;;
  doctor) cat "$T_SB/doctor.txt" ;;
  *) : ;;
esac
exit 0
EOF
chmod +x "$SB/bin/doccys"
DOC_BODY='MODE=full; CYS_CLI="$T_CLI"; DAEMON_PING_GAP=0
  copy_login_to_isolated() { :; }; cys_autostart_state() { echo yes; }; seed_all_profiles() { return 0; }
  step_prepare_account; echo "rc=$?" > "$T_SB/rc"'
for s in ok missing missing-fail; do
  mkdir -p "$SB/doc-$s"
  case "$s" in
    ok) printf '%s\n' "[OK  ] pack-version" "요약: 12 OK · 0 WARN · 0 FAIL · 1 SKIP(판정 불가)" > "$SB/doc-$s/doctor.txt" ;;
    missing) printf '%s\n' "[OK  ] pack-version" "thread main panicked at doctor.rs" > "$SB/doc-$s/doctor.txt" ;;
    missing-fail) printf '%s\n' "[OK  ] pack-version" "[FAIL] hook" > "$SB/doc-$s/doctor.txt" ;;
  esac
  run_lib "doc-$s" "$DOC_BODY" T_CLI="$SB/bin/doccys"
done
O="$SB/doc-ok/stdout"
[ "$(cat "$SB/doc-ok/rc")" = "rc=0" ] && grep -q '자리를 잡았습니다 (실패 0)' "$O" && ! grep -q '미확인' "$O"
t $? "[N12 요약 있음] 요약 0 FAIL → 「자리를 잡았습니다 (실패 0)」(이 축이 대상 단계를 끝까지 돈다는 증명)" "$(cat "$SB/doc-ok/rc" 2>/dev/null) · $(grep '8/10' "$O" | tail -2 | tr '\n' '|')"
O="$SB/doc-missing/stdout"; LG="$SB/doc-missing/home/install-jarvis/bootstrap.log"
[ "$(cat "$SB/doc-missing/rc")" = "rc=0" ] && grep -q '자가진단 결과를 읽지 못했습니다(실패 수 미확인)' "$O" && ! grep -q '실패 0' "$O" \
  && grep -q '자리를 잡았습니다 (자가진단 실패 수 미확인)' "$O" && grep -q 'doctor summary: missing' "$LG"
t $? "[N12 요약 없음] 「실패 0」이라 말하지 않는다 · 「실패 수 미확인」 · 기록 doctor summary: missing" "$(cat "$SB/doc-missing/rc" 2>/dev/null) · $(grep -E '8/10' "$O" | tail -3 | tr '\n' '|')"
O="$SB/doc-missing-fail/stdout"
[ "$(cat "$SB/doc-missing-fail/rc")" = "rc=8" ] && grep -q '요약 줄을 찾지 못해 항목을 세었습니다: 실패 1' "$O" && ! grep -q '자리를 잡았습니다' "$O"
t $? "[N12 요약 없음·실패 항목 있음] 항목 실패가 보이면 그대로 막는다(rc 8)" "$(cat "$SB/doc-missing-fail/rc" 2>/dev/null) · $(grep '8/10' "$O" | tail -2 | tr '\n' '|')"

echo "PASS $PASS / FAIL $FAIL"
[ "$FAIL" -eq 0 ]
