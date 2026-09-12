#!/bin/bash
# 원격 해결(help-s2) 맥 축 — 설치기를 「함수 묶음」으로 읽어 **실제로 부르고**, 가짜 서버가 받은 것과 창에 찍힌 것을 잰다.
#
# 계약 = ai-jarvis web-install/docs/HELP-API.md 절7·절9-4 · 명세 = test-s2/s2-double.ts · 외부 검토 4차 「S2 must assert」
# ⛔바깥에 닿지 않는다 — 가짜 서버(127.0.0.1)만 부른다. 진짜 cys·자비스를 부르지 않는다(가짜 cys 를 놓는다).
# ⚠python3 는 **시험 쪽**(가짜 서버·판정)에서만 쓴다. 설치기는 쓰지 않는다(깨끗한 맥에는 없다).
#
# 쓰는 법
#   bash tests/remote-help-run.sh [--src <bootstrap.sh 사본>] [--only <묶음>]
#   rc 0 = 전건 통과 · 실패는 「FAIL <이름>」 줄(뮤턴트 입구 tests/remote-help-mutate.py 가 이 줄을 읽는다)
#   묶음 = table diff skip decline text forged path toctou seq display timeout big report stop close gate static
set -u
HERE="$(cd "$(dirname "$0")" && pwd)"
ROOT="$(cd "$HERE/.." && pwd)"
SRC="$ROOT/install-master/bootstrap.sh"
ONLY=""
while [ $# -gt 0 ]; do
  case "$1" in
    --src)  SRC="$2"; shift 2 ;;
    --only) ONLY="$2"; shift 2 ;;
    *) echo "모르는 인자: $1" >&2; exit 2 ;;
  esac
done
[ -f "$SRC" ] || { echo "설치기를 못 찾았습니다: $SRC" >&2; exit 2; }
command -v python3 >/dev/null 2>&1 || { echo "python3 가 필요합니다(시험 쪽 가짜 서버·판정)" >&2; exit 2; }
TABLE="$ROOT/install-master/command-table.json"
CASES="$HERE/remote-help-grammar-cases.tsv"
AI_WEB="${AI_JARVIS_WEB:-$HOME/axdev/ai-jarvis/web-install}"

BASE="$(mktemp -d -t remote-help-run)" || exit 2
STATE="$BASE/state"
mkdir -p "$STATE"
python3 "$HERE/remote-help-fake-server.py" "$STATE" &
SERVER=$!
trap 'kill "$SERVER" 2>/dev/null; rm -rf "$BASE"' EXIT
i=0
while [ ! -s "$STATE/port" ] && [ "$i" -lt 100 ]; do sleep 0.1; i=$((i + 1)); done
[ -s "$STATE/port" ] || { echo "가짜 서버가 뜨지 않았습니다" >&2; exit 2; }
PORT="$(cat "$STATE/port")"
SIG="$(printf 'a%.0s' $(seq 64))"
TV="$(python3 -c 'import json,sys; print(json.load(open(sys.argv[1]))["version"])' "$TABLE")"

pass=0
fail=0
check() { # check <이름> <rc> <실패 사유>
  if [ "$2" -eq 0 ]; then pass=$((pass + 1)); printf '  ok   %s\n' "$1"
  else fail=$((fail + 1)); printf '  FAIL %s — %s\n' "$1" "$3"; fi
}
want() { [ -z "$ONLY" ] || [ "$ONLY" = "$1" ]; }

# ── 모래상자 — 사용자 폴더 이름에 **공백**을 넣는다(셸 글로 이으면 여기서 쪼개진다) ──
fresh() {
  SB="$BASE/sand box $1"
  H="$SB/home/install-jarvis"
  rm -rf "$SB"
  mkdir -p "$SB/home/.local/bin" "$SB/pathbin"
  rm -f "$STATE"/*.json "$STATE"/*.status
  : > "$STATE/requests.jsonl"
  # 가짜 cys — 받은 인자 · 그 순간의 기록 파일 · 실행 번호 파일을 받아 적는다. cys-mode 가 할 일을 정한다.
  cat > "$SB/home/.local/bin/cys" <<'EOF'
#!/bin/bash
H="$(cd "$(dirname "$0")/../.." && pwd)"
{
  printf 'args=%s\n' "$*"
  printf 'no_autostart=%s\n' "${CYS_NO_AUTOSTART:-}"
  printf 'log_has_display=%s\n' "$(grep -c '운영팀 명령: cys status' "$H/install-jarvis/bootstrap.log" 2>/dev/null)"
  printf 'seqfile=%s\n' "$(cat "$H/install-jarvis/remote-help-executed.json" 2>/dev/null)"
} >> "$H/cys-probe.txt"
case "$(cat "$H/cys-mode" 2>/dev/null)" in
  sleep) sleep 5 ;;
  big)   printf '가%.0s' $(seq 3000); printf 'END' ;;
  names) printf 'owner hongkd at /Users/hongkd/x and %s\n' "$(id -un)" ;;
  *)     echo "cys ok" ;;
esac
EOF
  chmod +x "$SB/home/.local/bin/cys"
  printf '#!/bin/bash\ntouch "%s/pathbin-used"\n' "$SB" > "$SB/pathbin/cys"
  chmod +x "$SB/pathbin/cys"
}

# 표준 입력의 조각을 「설치기를 읽어 들인 셸」에서 돌린다 · 창 출력 = $SB/window.txt
inst() {
  cat > "$SB/snip.sh"
  HOME="$SB/home" PATH="$SB/pathbin:$PATH" JARVIS_LIB_ONLY=1 T_SRC="$SRC" T_SNIP="$SB/snip.sh" T_PORT="$PORT" T_SB="$SB" \
    bash -c 'unset CYS_NO_AUTOSTART
. "$T_SRC" || exit 5
HELP_API_URL="http://127.0.0.1:$T_PORT"
REMOTE_HELP_POLL_SEC=0
RH_TMP="$(mktemp -d -t rh-test)"
RH_ID=TEST2345
. "$T_SNIP"' >> "$SB/window.txt" 2>&1
}
tick() { inst <<'EOF'
remote_help_http GET /api/help/TEST2345
remote_help_tick
echo "TICK_RC=$?" > "$T_SB/tick-rc"
EOF
}

cmd() { # cmd <seq> <argv JSON> [덧붙일 칸] — 뒤에 붙인 칸이 같은 이름의 앞 칸을 덮는다(JSON.parse 는 마지막 값)
  printf '{"seq":%s,"from":"operator","kind":"command","shell":"sh","argv":%s,"table_version":"%s","sig":"%s","ts":"t","ack":{"status":"pending"}%s}' \
    "$1" "$2" "$TV" "$SIG" "${3:+,$3}"
}
poll() { # poll <메시지들> [open] [answer]
  printf '{"id":"TEST2345","ok":true,"message":"","status":"open","answer":%s,"session":{"open":%s,"messages":[%s]}}' \
    "${3:-null}" "${2:-true}" "$1" > "$STATE/poll.json"
}
acks() { # 가짜 서버가 받은 ack 한 줄씩 — seq status rc output_tail(JSON 글자)
  python3 - "$STATE/requests.jsonl" <<'PY'
import json, sys
for line in open(sys.argv[1], encoding="utf-8"):
    r = json.loads(line)
    if r["method"] == "POST" and r["path"].endswith("/ack"):
        b = json.loads(r["body"])
        print(b["seq"], b["status"], json.dumps(b.get("rc")), json.dumps(b.get("output_tail"), ensure_ascii=False))
PY
}
ack_line() { acks | awk -v s="$1" '$1 == s'; }
seqfile() { cat "$H/remote-help-executed.json" 2>/dev/null; }
shown_none() { ! grep -q '운영팀 명령' "$SB/window.txt" 2>/dev/null; }

t_table() {
  local canon embedded
  canon="$(shasum -a 256 < "$TABLE" | cut -d' ' -f1)"
  embedded="$(awk "/<<'EOF_REMOTE_HELP_TABLE' \\|\\| true/{f=1;next} /^EOF_REMOTE_HELP_TABLE\$/{f=0} f" "$SRC" | shasum -a 256 | cut -d' ' -f1)"
  [ "$embedded" = "$canon" ]
  check "table-embedded 설치기 안의 표 = install-master/command-table.json (바이트)" $? "$embedded ≠ $canon"
  fresh table
  inst <<'EOF'
printf '%s' "$REMOTE_HELP_TABLE" | shasum -a 256 | cut -d' ' -f1 > "$T_SB/runtime-sha"
EOF
  [ "$(cat "$SB/runtime-sha" 2>/dev/null)" = "$canon" ]
  check "table-runtime 읽어 들인 표 = 사본 (바이트)" $? "$(cat "$SB/runtime-sha" 2>/dev/null)"
  if [ -f "$AI_WEB/docs/command-table.json" ]; then
    [ "$(shasum -a 256 < "$AI_WEB/docs/command-table.json" | cut -d' ' -f1)" = "$canon" ]
    check "table-canon 사본 = ai-jarvis 정본 docs/command-table.json" $? "정본과 다르다"
  else
    printf '  skip table-canon — ai-jarvis 정본 없음(%s)\n' "$AI_WEB"
  fi
  [ "$(grep -c "$TV" "$SRC")" = "1" ]
  check "table-version 판본 글자는 설치기에 한 번(표 안)뿐" $? "$(grep -c "$TV" "$SRC")회"
}

t_diff() {
  local out n mism
  fresh diff
  python3 - "$CASES" "$SIG" "$TV" "$SB" <<'PY'
import json, sys
cases, sig, tv, sb = sys.argv[1:5]
groups, expect, seq = {"sh": [], "ps1": []}, {"sh": {}, "ps1": {}}, 0
for line in open(cases, encoding="utf-8"):
    if line.startswith("#") or not line.strip():
        continue
    group, shell, server, rule, double, text = line.rstrip("\n").split("\t")
    text = json.loads(text)
    seq += 1
    groups[shell].append({"seq": seq, "kind": "command", "shell": shell, "argv": text.split(" "),
                          "table_version": tv, "sig": sig, "ack": {"status": "pending"}})
    expect[shell][str(seq)] = [server, double, text]
for shell in groups:
    json.dump({"session": {"open": True, "messages": groups[shell]}}, open(f"{sb}/poll-{shell}.json", "w"))
    json.dump(expect[shell], open(f"{sb}/expect-{shell}.json", "w"))
PY
  inst <<'EOF'
for s in sh ps1; do
  RH_BODY_FILE="$T_SB/poll-$s.json" RH_TABLE="$REMOTE_HELP_TABLE" RH_SEQ_FILE="$REMOTE_HELP_SEQ_FILE" RH_SHELL=$s \
    remote_help_js poll > "$T_SB/plan-$s.txt"
done
EOF
  out="$(python3 - "$SB" <<'PY'
import json, sys
sb, bad, n = sys.argv[1], [], 0
for shell in ("sh", "ps1"):
    expect = json.load(open(f"{sb}/expect-{shell}.json"))
    got = {}
    for line in open(f"{sb}/plan-{shell}.txt", encoding="utf-8"):
        f = line.split()
        if f and f[0] in ("RUN", "DECLINE"):
            got[f[1]] = "ok" if f[0] == "RUN" else "no"
    for seq, (server, double, text) in expect.items():
        n += 1
        if got.get(seq) != server or double != server:
            bad.append(f"{shell} {text!r} server={server} double={double} installer={got.get(seq)}")
print(n)
print(" | ".join(bad))
PY
)"
  n="$(printf '%s\n' "$out" | head -1)"
  mism="$(printf '%s\n' "$out" | sed -n '2p')"
  [ "$n" = "74" ] && [ -z "$mism" ]
  check "grammar-diff 재검사 = 서버 문법 = 더블 (표 명세 26 · 재현 10 · 난독 38)" $? "사례 $n · 어긋남: $mism"

  # 사례 표의 「서버·더블」 판정은 만들어 둔 값이다(외부 검토 1차 #9) — 그 값을 만든 세 파일이 **지금도 같은 파일인지** 잰다.
  #   다르면 서버 문법이나 더블이 바뀐 것이므로 사례 표를 다시 만들어야 한다(옛 값과 비교하는 초록을 막는다).
  if [ -d "$AI_WEB" ]; then
    local bad_sha rows
    rows="$(grep -c '^# sha256 ' "$CASES")"
    bad_sha="$(grep '^# sha256 ' "$CASES" | while read -r _ _ rel hex; do
      [ "$(shasum -a 256 < "$AI_WEB/$rel" 2>/dev/null | cut -d' ' -f1)" = "$hex" ] || printf '%s ' "$rel"
    done)"
    [ "$rows" = "3" ] && [ -z "$bad_sha" ]
    check "grammar-sha 사례 표를 만든 서버 문법·서버 사례·더블의 sha256 = 지금 ai-jarvis 파일" $? "머리 줄 ${rows}개 · 어긋남: $bad_sha"
  else
    printf '  skip grammar-sha — ai-jarvis 정본 없음(%s)\n' "$AI_WEB"
  fi
}

t_skip() {
  fresh skip
  poll "$(cmd 1 '["ls","-lan"]')" false
  tick; local r1; r1="$(cat "$SB/tick-rc")"
  poll "$(cmd 1 '["ls","-lan"]')" '"true"'
  tick; local r2; r2="$(cat "$SB/tick-rc")"
  [ "$r1" = "TICK_RC=1" ] && [ "$r2" = "TICK_RC=1" ] && [ -z "$(acks)" ] && shown_none
  check "session-open 대화가 열려 있지 않으면(false · \"true\") 실행·ack 0 · 멈춘다" $? "$r1 $r2 $(acks)"

  fresh skip
  poll "$(cmd 2 '["ls","-lan"]' '"ack":{"status":"ran"}'),$(cmd 3 '["ls","-lan"]' '"ack":null'),$(cmd 7 '["ls","-lan"]' '"kind":"text"')"
  tick
  [ "$(cat "$SB/tick-rc")" = "TICK_RC=0" ] && [ -z "$(acks)" ] && shown_none
  check "skip-pending ack 가 pending 이 아니거나 글이면 실행·ack 0" $? "$(acks)"

  fresh skip
  poll "$(cmd 4 '["ls","-lan"]' '"sig":null'),$(cmd 5 '["ls","-lan"]' "\"sig\":\"$(printf 'A%.0s' $(seq 64))\""),$(cmd 8 '["ls","-lan"]' "\"sig\":\"${SIG:0:63}\"")"
  tick
  [ -z "$(acks)" ] && shown_none && [ -z "$(seqfile)" ]
  check "sig-shape 서명이 없거나 64자 소문자 16진이 아니면 실행·ack 0" $? "$(acks)"

  fresh skip
  poll "$(cmd 0 '["ls","-lan"]'),$(cmd -1 '["ls","-lan"]'),$(cmd 1.5 '["ls","-lan"]'),$(cmd 9007199254740992 '["ls","-lan"]'),$(cmd 6 '["ls","-lan"]' '"seq":"6"')"
  tick
  [ -z "$(acks)" ] && shown_none && [ -z "$(seqfile)" ]
  check "seq-shape seq 가 양의 안전 정수가 아니면(0·-1·1.5·2^53·\"6\") 실행·ack 0" $? "$(acks)"
}

t_decline() {
  fresh decline
  poll "$(cmd 1 '["ls","-lan"]' '"shell":"ps1"'),$(cmd 2 '["ls","-lan"]' '"table_version":"v0"')"
  tick
  [ "$(ack_line 1)" = '1 declined null "policy:shell"' ] && ! grep -q '운영팀 명령' "$SB/window.txt"
  check "shell-decline 이 컴퓨터와 셸이 다르면 policy:shell · 실행 0" $? "$(acks)"
  [ "$(ack_line 2)" = '2 declined null "policy:table_version"' ] && shown_none
  check "table-version-decline 표 판본이 다르면 policy:table_version · 실행 0" $? "$(acks)"
}

t_text() {
  fresh text
  poll "$(cmd 1 '["ls","-lan"]' '"text":"rm -rf /"'),$(cmd 2 'null' '"text":"ls -lan"')"
  tick
  ack_line 1 | grep -q '^1 ran 0 .*jarvis-owned' && [ "$(ack_line 2)" = '2 declined null "policy:empty"' ] &&
    [ "$(grep -c '운영팀 명령: ls -lan$' "$SB/window.txt")" = "1" ]
  check "text-ignored text 칸은 읽지 않는다 — argv 만 실행에 닿고 argv 없는 명령은 policy:empty" $? "$(acks)"
}

t_forged() {
  local expected
  fresh forged
  poll "$(cmd 1 '["tail","-f","/etc/passwd"]'),$(cmd 2 '["tail","-n","20","/etc/passwd"]'),$(cmd 3 '["tail","-n","20","../../etc/passwd"]'),$(cmd 4 '["ls","-lan","$(id)"]'),$(cmd 5 '["rm","-rf","/"]'),$(cmd 6 '"ls -lan"')"
  inst <<'EOF'
REMOTE_HELP_CMD_TIMEOUT=2
remote_help_http GET /api/help/TEST2345
remote_help_tick
EOF
  expected='1 declined null "policy:usage_mismatch"
2 declined null "policy:usage_mismatch"
3 declined null "policy:usage_mismatch"
4 declined null "policy:char"
5 declined null "policy:unknown_command"
6 declined null "policy:empty"'
  [ "$(acks)" = "$expected" ] && shown_none && [ -z "$(seqfile)" ]
  check "forged-argv 위조 응답의 표 밖 argv 6종 = 규칙대로 declined · 실행 0" $? "$(acks)"
}

t_path() {
  fresh path
  inst <<'EOF'
:
EOF
  mkdir -p "$SB/outside" "$SB/home/install-jarvis-evil" "$H/logs-real"
  printf 'secret-outside\n' > "$SB/outside/passwd"
  printf 'secret-evil\n' > "$SB/home/install-jarvis-evil/x.log"
  printf 'inside-a\n' > "$H/logs-real/a.log"
  ln -s "$SB/outside" "$H/dl"
  ln -s "$SB/home/install-jarvis-evil" "$H/near"
  ln -s "$SB/nowhere" "$H/dangling"
  ln -s "$H/logs-real" "$H/logs"
  poll "$(cmd 1 '["tail","-n","20","dl/passwd"]'),$(cmd 2 '["tail","-n","5","near/x.log"]'),$(cmd 3 '["ls","-lan","dangling"]'),$(cmd 4 '["tail","-n","5","logs/a.log"]'),$(cmd 5 '["test","-e","nope.txt"]'),$(cmd 6 '["tail","-n","5","nodir/x.log"]'),$(cmd 7 '["ls","-lan","logs"]'),$(cmd 8 '["test","-e","logs"]'),$(cmd 9 '["shasum","-a","256","logs/a.log"]')"
  tick
  local want_sha
  want_sha="$(shasum -a 256 < "$H/logs-real/a.log" | cut -d' ' -f1)"
  ack_line 7 | grep -q '^7 ran 0 .*a\.log' && [ "$(ack_line 8)" = '8 ran 0 ""' ] && ack_line 9 | grep -q "^9 ran 0 \"$want_sha "
  check "path-open 연 것을 읽는다 — 폴더 목록(ls)·폴더 있음(test -e)·파일 지문(shasum) 이 실제 대상과 같다" $? "$(ack_line 7 | cut -c1-80) · $(ack_line 8) · $(ack_line 9)"
  [ "$(ack_line 1)" = '1 declined null "policy:path_outside"' ] && [ "$(ack_line 2)" = '2 declined null "policy:path_outside"' ] &&
    [ "$(ack_line 3)" = '3 declined null "policy:path_outside"' ] && ! grep -q 'secret-' "$STATE/requests.jsonl"
  check "path-outside 링크로 밖(이웃 install-jarvis-evil · 끊어진 링크 포함) = policy:path_outside · 내용 유출 0" $? "$(acks)"
  [ "$(ack_line 4)" = '4 ran 0 "inside-a\n"' ]
  check "path-inside 작업 폴더 안의 링크는 실제 경로로 풀어 실행한다" $? "$(ack_line 4)"
  [ "$(ack_line 5)" = '5 ran 1 ""' ]
  check "path-new 아직 없는 성분은 그대로 붙인다(test -e rc 1)" $? "$(ack_line 5)"
  [ "$(ack_line 6)" = '6 declined null "policy:path_missing"' ] && ! grep -q '운영팀 명령: tail -n 5 nodir/x.log' "$SB/window.txt" &&
    ! seqfile | grep -qE '(^|[\[,])6([],]|$)'
  check "path-missing 없는 폴더 안의 이름(성분 2개 이상 남음)은 표시·번호 기록 전에 policy:path_missing" $? "$(ack_line 6) seq=$(seqfile)"
}

t_toctou() {
  fresh toctou
  inst <<'EOF'
:
EOF
  mkdir -p "$SB/outside" "$H/swap" "$H/swap2"
  printf 'secret-toctou\n' > "$SB/outside/x.log"
  printf 'inside\n' > "$H/swap/x.log"
  printf 'inside\n' > "$H/swap2/x.log"
  poll "$(cmd 1 '["tail","-n","5","swap/x.log"]')"
  # 처음 푼 뒤 · 실행 전(번호를 남기는 순간)에 폴더를 밖으로 가는 링크로 바꿔 끼운다
  inst <<'EOF'
eval "orig_$(declare -f remote_help_js)"
remote_help_js() {
  if [ "$1" = "record" ]; then rm -rf "$JARVIS_HOME/swap"; ln -s "$T_SB/outside" "$JARVIS_HOME/swap"; fi
  orig_remote_help_js "$@"
}
remote_help_http GET /api/help/TEST2345
remote_help_tick
EOF
  [ "$(ack_line 1)" = '1 declined null "policy:path_changed"' ] && ! grep -q 'secret-' "$STATE/requests.jsonl"
  check "toctou-reconfine 실행 직전 다시 푼 경로가 처음과 다르면 policy:path_changed · 유출 0" $? "$(acks)"

  poll "$(cmd 2 '["tail","-n","5","swap2/x.log"]')"
  # 두 번째로 푼 뒤 · 여는 순간 전에 마지막 성분을 밖으로 가는 링크로 바꿔 끼운다
  inst <<'EOF'
eval "orig_$(declare -f remote_help_launch)"
remote_help_launch() {
  rm -f "$JARVIS_HOME/swap2/x.log"; ln -s "$T_SB/outside/x.log" "$JARVIS_HOME/swap2/x.log"
  orig_remote_help_launch "$@"
}
remote_help_http GET /api/help/TEST2345
remote_help_tick
EOF
  [ "$(ack_line 2)" = '2 declined null "policy:path_changed"' ] && ! grep -q 'secret-' "$STATE/requests.jsonl"
  check "toctou-leaf 여는 순간 마지막 성분이 링크면 열지 않는다 · 유출 0" $? "$(ack_line 2)"

  # 외부 검토 1차 재현 — 두 번 풀기와 링크 검사를 **다 통과한 뒤**, 여는 그 순간에만 밖으로 가는 링크로 바꿔 끼운다.
  #   ⑴ 연 뒤 제자리 파일로 되돌린다 = 이름만 보는 검사는 전부 통과한다 → 연 것(fd)과 이름의 정체 대조만이 막는다
  #   ⑵ 링크인 채로 둔다 = 정체는 같다(이름이 링크를 따라가므로) → 연 뒤 다시 본 링크 검사가 막는다
  mkdir -p "$H/swap3" "$H/swap4"
  printf 'inside\n' > "$H/swap3/x.log"
  printf 'inside\n' > "$H/swap4/x.log"
  poll "$(cmd 3 '["tail","-n","5","swap3/x.log"]')"
  inst <<'EOF'
eval "orig_$(declare -f remote_help_open_leaf)"
remote_help_open_leaf() {
  rm -f "./$1"; ln -s "$T_SB/outside/x.log" "./$1"
  orig_remote_help_open_leaf "$1"
  local r=$?
  rm -f "./$1"; printf 'inside\n' > "./$1"
  return $r
}
remote_help_http GET /api/help/TEST2345
remote_help_tick
EOF
  [ "$(ack_line 3)" = '3 declined null "policy:path_outside"' ] && ! grep -q 'secret-' "$STATE/requests.jsonl"
  check "toctou-open 여는 순간에만 링크로 바꿔 끼우고 되돌려도 연 것과 이름의 정체가 달라 policy:path_outside · 유출 0" $? "$(ack_line 3)"

  poll "$(cmd 4 '["tail","-n","5","swap4/x.log"]')"
  inst <<'EOF'
eval "orig_$(declare -f remote_help_open_leaf)"
remote_help_open_leaf() {
  rm -f "./$1"; ln -s "$T_SB/outside/x.log" "./$1"
  orig_remote_help_open_leaf "$1"
}
remote_help_http GET /api/help/TEST2345
remote_help_tick
EOF
  [ "$(ack_line 4)" = '4 declined null "policy:path_outside"' ] && ! grep -q 'secret-' "$STATE/requests.jsonl"
  check "toctou-open-link 여는 순간 링크로 바꿔 끼운 채 두면 연 뒤 다시 본 이름이 링크라 policy:path_outside · 유출 0" $? "$(ack_line 4)"

  # 폴더 — 연 뒤 밖 폴더로 가는 링크로 바꿔 끼운 채 둔다 → 연 뒤 다시 본 이름이 링크라 목록을 내지 않는다
  #   (링크 검사 뒤·폴더에 들어가기 전의 교체는 들어간 곳과 연 것의 정체 대조가 막는다 — 그 사이에는 바꿔 끼울 자리가 없어 여기서는 재지 못한다 · 정직)
  mkdir -p "$SB/outside/secret-dir-marker" "$H/swapd"
  poll "$(cmd 5 '["ls","-lan","swapd"]')"
  inst <<'EOF'
eval "orig_$(declare -f remote_help_open_leaf)"
remote_help_open_leaf() {
  orig_remote_help_open_leaf "$1"
  local r=$?
  rmdir "./$1"; ln -s "$T_SB/outside" "./$1"
  return $r
}
remote_help_http GET /api/help/TEST2345
remote_help_tick
EOF
  [ "$(ack_line 5)" = '5 declined null "policy:path_outside"' ] && ! grep -q 'secret-' "$STATE/requests.jsonl"
  check "toctou-dir 폴더를 연 뒤 링크로 바꿔 끼우면 목록을 내지 않는다 · 유출 0" $? "$(ack_line 5)"

  # 실행 직전 재계산은 **두 결과가 다르면 거절**한다(계약 9-4 ③ 두 번 확인) — 밖으로 가는 교체는 여는 순간의 대조도 막으므로,
  #   이 규칙만 재려면 안쪽 링크를 **다른 안쪽 폴더로** 돌려 끼운다(처음 푼 자리를 그대로 열면 여전히 안이라 다른 관문은 통과한다).
  mkdir -p "$H/in-a" "$H/in-b"
  printf 'a\n' > "$H/in-a/x.log"
  printf 'b\n' > "$H/in-b/x.log"
  ln -s "$H/in-a" "$H/in-link"
  poll "$(cmd 6 '["tail","-n","5","in-link/x.log"]')"
  inst <<'EOF'
eval "orig_$(declare -f remote_help_js)"
remote_help_js() {
  if [ "$1" = "record" ]; then rm -f "$JARVIS_HOME/in-link"; ln -s "$JARVIS_HOME/in-b" "$JARVIS_HOME/in-link"; fi
  orig_remote_help_js "$@"
}
remote_help_http GET /api/help/TEST2345
remote_help_tick
EOF
  [ "$(ack_line 6)" = '6 declined null "policy:path_changed"' ]
  check "toctou-reconfine-inside 실행 직전 다시 푼 경로가 처음과 다르면(안쪽끼리라도) policy:path_changed" $? "$(ack_line 6)"
}

t_seq() {
  fresh seq
  poll "$(cmd 7 '["sw_vers"]')"
  tick
  local first; first="$(seqfile)"
  poll "$(cmd 7 '["sw_vers"]'),$(cmd 8 '["sw_vers"]')"
  tick   # 새 프로세스 = 재부팅 뒤 같은 응답이 다시 온 것
  [ "$first" = "[7]" ] && [ "$(acks | awk '$1==7' | wc -l | tr -d ' ')" = "1" ] &&
    [ "$(acks | awk '$1==8' | wc -l | tr -d ' ')" = "1" ] && [ "$(seqfile)" = "[7,8]" ]
  check "seq-restart 실행 번호는 파일에 남고 · 새 프로세스에서 같은 번호는 다시 돌지 않는다" $? "first=$first now=$(seqfile) $(acks)"

  fresh seq
  inst <<'EOF'
:
EOF
  local bad=0 content
  for content in '{not json' '[1, -2]' 'locked'; do
    rm -f "$H/remote-help-executed.json"
    if [ "$content" = "locked" ]; then printf '[5]' > "$H/remote-help-executed.json"; chmod 000 "$H/remote-help-executed.json"
    else printf '%s' "$content" > "$H/remote-help-executed.json"; fi
    : > "$STATE/requests.jsonl"
    poll "$(cmd 1 '["sw_vers"]')"
    tick
    [ "$(cat "$SB/tick-rc")" = "TICK_RC=2" ] && [ -z "$(acks)" ] || bad=1
    chmod 644 "$H/remote-help-executed.json"
  done
  shown_none || bad=1
  [ "$bad" -eq 0 ]
  check "seq-corrupt 기록 파일이 깨졌거나 읽을 수 없으면 실행 0 · 멈춘다(닫힌 쪽)" $? "$(cat "$SB/tick-rc")"

  # 외부 검토 1차 재현 — 두 프로세스가 같은 번호를 동시에 남긴다. 기록 쪽을 0.5초 늦춰 둘이 같은 순간에 읽게 한다.
  fresh seq
  inst <<'EOF'
eval "orig_$(declare -f remote_help_js)"
remote_help_js() { [ "$1" = "record" ] && sleep 0.5; orig_remote_help_js "$@"; }
( remote_help_record 1; echo "$RH_RECORD" >> "$T_SB/record-results" ) &
( remote_help_record 1; echo "$RH_RECORD" >> "$T_SB/record-results" ) &
wait
EOF
  [ "$(sort "$SB/record-results" 2>/dev/null | tr '\n' ' ')" = "ALREADY OK " ] && [ "$(seqfile)" = "[1]" ] && [ ! -d "$H/remote-help-executed.json.lock" ]
  check "seq-lock 두 프로세스가 같은 번호를 동시에 남기면 OK 1 · ALREADY 1 · 잠금은 풀린다" $? "$(tr '\n' ' ' < "$SB/record-results" 2>/dev/null) seq=$(seqfile)"

  # 다른 창이 잠금을 쥐고 있으면(방금 만든 잠금) 기다리다 거절한다 — 실행·번호 기록 0
  fresh seq
  inst <<'EOF'
:
EOF
  mkdir "$H/remote-help-executed.json.lock"
  poll "$(cmd 1 '["sw_vers"]')"
  tick
  [ "$(ack_line 1)" = '1 declined null "policy:seq_lock"' ] && [ -z "$(seqfile)" ]
  check "seq-lock-busy 잠금을 못 잡으면 실행하지 않고 policy:seq_lock" $? "$(acks) seq=$(seqfile)"
  rmdir "$H/remote-help-executed.json.lock" 2>/dev/null
}

t_display() {
  fresh display
  poll "$(cmd 3 '["cys","status"]')"
  tick
  grep -q 'log_has_display=1' "$SB/home/cys-probe.txt" 2>/dev/null && grep -q '운영팀 명령: cys status' "$SB/window.txt"
  check "display-before-run 명령 글이 실행 전에 창·기록에 찍힌다" $? "$(cat "$SB/home/cys-probe.txt" 2>/dev/null)"
  grep -qx 'seqfile=\[3\]' "$SB/home/cys-probe.txt" 2>/dev/null
  check "seq-before-run 실행 번호가 실행 전에 파일에 있다" $? "$(cat "$SB/home/cys-probe.txt" 2>/dev/null)"
  grep -qx 'args=status' "$SB/home/cys-probe.txt" 2>/dev/null && [ ! -e "$SB/pathbin-used" ] && [ "$(ack_line 3)" = '3 ran 0 "cys ok\n"' ]
  check "exec-cys 공백 든 절대 경로의 cys 를 인자 배열로 부른다 · PATH 의 같은 이름은 부르지 않는다" $? "$(ack_line 3)"
  grep -qx 'no_autostart=1' "$SB/home/cys-probe.txt" 2>/dev/null
  check "no-autostart 원격 실행 환경에 CYS_NO_AUTOSTART=1 — 읽기 명령이 cys 데몬을 깨우지 않는다" $? "$(grep no_autostart "$SB/home/cys-probe.txt" 2>/dev/null)"
}

t_timeout() {
  fresh timeout
  inst <<'EOF'
:
EOF
  echo sleep > "$SB/home/cys-mode"
  poll "$(cmd 1 '["cys","status"]')"
  inst <<'EOF'
REMOTE_HELP_CMD_TIMEOUT=1
started=$SECONDS
remote_help_http GET /api/help/TEST2345
remote_help_tick
echo $((SECONDS - started)) > "$T_SB/elapsed"
EOF
  [ "$(ack_line 1)" = '1 ran null "\ntimeout:1s"' ] && [ "$(cat "$SB/elapsed")" -le 3 ]
  check "timeout 시간 상한을 넘으면 멈추고 rc null · 끝에 timeout:<n>s" $? "$(ack_line 1) elapsed=$(cat "$SB/elapsed" 2>/dev/null)"
}

t_big() {
  fresh big
  inst <<'EOF'
:
EOF
  echo big > "$SB/home/cys-mode"
  poll "$(cmd 1 '["cys","status"]')"
  tick
  python3 - "$STATE/requests.jsonl" <<'PY'
import json, sys
tails = [json.loads(json.loads(l)["body"])["output_tail"] for l in open(sys.argv[1], encoding="utf-8") if json.loads(l)["path"].endswith("/ack")]
sys.exit(0 if len(tails) == 1 and len(tails[0].encode()) <= 4096 and tails[0].endswith("END") else 1)
PY
  check "ack-tail 출력은 끝 4KB 이하만 · 끝이 남는다" $? "$(acks | cut -c1-80)"
}

t_report() {
  local login
  login="$(id -un)"
  fresh report
  inst <<'EOF'
:
EOF
  cat > "$H/env-report.md" <<EOF
[자비스] 환경 보고 v0
USER=hongkd
- path /Users/hongkd/install-jarvis
- mail hong.kd@example.com
- auth Bearer abc.def-ghi
- key sk-abcdefgh12345
- bare hongkd appears
- this machine $login
EOF
  { for i in $(seq 1 300); do echo "line $i"; done; echo "[5/10] 받을 수 없습니다"; echo "whoami: hongkd"; } > "$H/bootstrap.log"
  printf '{"id":"TEST2345","ok":true,"client_token":"%s"}' "$(printf 'b%.0s' $(seq 64))" > "$STATE/report.json"
  echo names > "$SB/home/cys-mode"
  poll "$(cmd 1 '["cys","status"]')"
  inst <<'EOF'
J_CODE=J-NET-02
RH_ID=""
remote_help_report
echo "REPORT_RC=$?" > "$T_SB/report-rc"
remote_help_http GET /api/help/TEST2345
remote_help_tick
remote_help_http POST /api/help/TEST2345/close
EOF
  python3 - "$STATE/requests.jsonl" "$login" <<'PY' > "$SB/report-verdict" 2>&1
import json, sys
reqs = [json.loads(l) for l in open(sys.argv[1], encoding="utf-8")]
login = sys.argv[2]
rep = [json.loads(r["body"]) for r in reqs if r["method"] == "POST" and r["path"] == "/api/help"]
out = []
if len(rep) != 1:
    print("report count", len(rep)); sys.exit(1)
b = rep[0]
shape = (b.get("code") == "J-NET-02" and b.get("step") == "5/10" and b.get("os") == "mac" and b.get("installer_version") == "0.3.15"
         and b.get("notice_shown") is True and len(b.get("log_tail", "").split("\n")) <= 200 and "line 300" in b.get("log_tail", ""))
text = b.get("env_report", "") + b.get("log_tail", "")
secrets = ["hongkd", "hong.kd@example.com", "abc.def-ghi", "sk-abcdefgh12345", login]
scrub = all(s not in text for s in secrets) and "<이메일 지움>" in text and "~user" in text
acks = [r for r in reqs if r["path"].endswith("/ack")]
closes = [r for r in reqs if r["path"].endswith("/close")]
ack_body = json.loads(acks[0]["body"]) if acks else {}
ack_scrub = bool(acks) and all(s not in ack_body.get("output_tail", "") for s in ("hongkd", login))
token = "b" * 64
header = bool(acks) and acks[0].get("client") == token and bool(closes) and closes[0].get("client") == token
print("shape", shape); print("scrub", scrub); print("ack_scrub", ack_scrub); print("header", header)
PY
  grep -qx 'shape True' "$SB/report-verdict" && grep -q '보고 번호 TEST2345' "$SB/window.txt" && grep -q "/help/TEST2345" "$SB/window.txt" &&
    [ "$(cat "$SB/report-rc")" = "REPORT_RC=0" ]
  check "report-shape 묻지 않고 보낸다 · code·step·os·installer_version·notice_shown · 기록 끝 200줄 · 보고 번호와 폰 주소 표시" $? "$(tr '\n' ' ' < "$SB/report-verdict")"
  grep -qx 'scrub True' "$SB/report-verdict"
  check "report-scrub 보내기 전 1차 스크럽 — 표시된 이름(다른 칸의 홀로 나온 이름 포함)·이 기계 로그인 이름·집 폴더·이메일·토큰·키" $? "$(tr '\n' ' ' < "$SB/report-verdict")"
  grep -qx 'ack_scrub True' "$SB/report-verdict"
  check "ack-scrub 명령 출력도 같은 이름 집합으로 지운다" $? "$(acks | cut -c1-120)"
  grep -qx 'header True' "$SB/report-verdict" && [ "$(cat "$H/remote-help-client-token")" = "$(printf 'b%.0s' $(seq 64))" ] &&
    [ "$(stat -f '%Lp' "$H/remote-help-client-token")" = "600" ]
  check "client-token client_token 을 600 파일로 두고 ack·close 에 x-help-client 헤더를 붙인다" $? "$(tr '\n' ' ' < "$SB/report-verdict") mode=$(stat -f '%Lp' "$H/remote-help-client-token" 2>/dev/null)"

  fresh report
  poll "$(cmd 1 '["cys","status"]')"
  inst <<'EOF'
J_CODE=J-NET-02
RH_ID=""
remote_help_report
remote_help_http GET /api/help/TEST2345
remote_help_tick
EOF
  python3 - "$STATE/requests.jsonl" <<'PY'
import json, sys
acks = [json.loads(l) for l in open(sys.argv[1], encoding="utf-8") if json.loads(l)["path"].endswith("/ack")]
sys.exit(0 if len(acks) == 1 and acks[0].get("client") is None else 1)
PY
  [ $? -eq 0 ] && [ ! -e "$H/remote-help-client-token" ] && grep -q '출처 헤더 없음' "$H/bootstrap.log"
  check "client-token-absent 옛 서버(client_token 없음)면 헤더 없이 보내고 기록에 한 줄" $? "$(acks | cut -c1-80)"

  # 토큰 파일을 못 쓰는 자리(그 이름에 폴더가 있다) — 토큰을 버리고 헤더 없이 보낸다(닫힌 쪽 · 메모리의 헤더 파일도 남기지 않는다)
  fresh report
  inst <<'EOF'
:
EOF
  mkdir -p "$H/remote-help-client-token"
  printf '{"id":"TEST2345","ok":true,"client_token":"%s"}' "$(printf 'c%.0s' $(seq 64))" > "$STATE/report.json"
  poll "$(cmd 1 '["sw_vers"]')"
  inst <<'EOF'
J_CODE=J-NET-02
RH_ID=""
remote_help_report
[ -e "$RH_TMP/client-header" ] && echo "HEADER_LEFT" > "$T_SB/header-left"
remote_help_http GET /api/help/TEST2345
remote_help_tick
EOF
  python3 - "$STATE/requests.jsonl" <<'PY'
import json, sys
acks = [json.loads(l) for l in open(sys.argv[1], encoding="utf-8") if json.loads(l)["path"].endswith("/ack")]
sys.exit(0 if len(acks) == 1 and acks[0].get("client") is None else 1)
PY
  [ $? -eq 0 ] && [ ! -e "$SB/header-left" ] && grep -q '출처 토큰을 본인만 읽는 파일로 두지 못해 버렸다' "$H/bootstrap.log"
  check "client-token-failclosed 토큰을 본인만 읽는 파일로 못 두면 버리고 헤더 없이 보낸다 · 기록에 한 줄" $? "$(acks | cut -c1-80)"

  # 외부 검토 1차 재현 — 환경 보고에 백슬래시 96,000개 · 기록 마지막 줄에 128,000개 → 잘라 낸 글 기준이면 448KB 로 불어 413
  fresh report
  inst <<'EOF'
:
EOF
  python3 -c 'import sys; open(sys.argv[1], "w").write("\\" * 96000)' "$H/env-report.md"
  python3 -c 'import sys; open(sys.argv[1], "w").write("[5/10] 받을 수 없습니다\n" + "\\" * 128000 + "\n")' "$H/bootstrap.log"
  rm -f "$STATE/report.json"
  inst <<'EOF'
J_CODE=J-NET-02
RH_ID=""
remote_help_report
echo "REPORT_RC=$?" > "$T_SB/report-rc"
EOF
  python3 - "$STATE/requests.jsonl" <<'PY' > "$SB/size-verdict" 2>&1
import json, sys
reps = [json.loads(l) for l in open(sys.argv[1], encoding="utf-8") if json.loads(l)["path"] == "/api/help"]
b = json.loads(reps[-1]["body"]) if reps else {}
print(len(reps), reps[-1]["bytes"] if reps else -1, len(b.get("env_report", "")), len(b.get("log_tail", "")))
ok = len(reps) == 1 and 0 < reps[0]["bytes"] <= 240000 and len(b.get("env_report", "")) == 96000 and len(b.get("log_tail", "")) > 0 and b.get("step") == "5/10"
sys.exit(0 if ok else 1)
PY
  [ $? -eq 0 ] && [ "$(cat "$SB/report-rc")" = "REPORT_RC=0" ]
  check "report-size 직렬화한 본문을 240,000 바이트 이하로 줄여 보낸다(백슬래시 폭탄 → 413 아님 · 기록 끝부터 줄인다)" $? "보고수·바이트·env·log = $(cat "$SB/size-verdict") $(cat "$SB/report-rc")"
}

t_stop() {
  fresh stop
  echo 410 > "$STATE/poll.status"
  inst <<'EOF'
remote_help_loop
echo "SHOW_RERUN=$SHOW_RERUN" > "$T_SB/rerun"
EOF
  grep -q '원격 해결이 끝났습니다' "$SB/window.txt" && [ "$(cat "$SB/rerun")" = "SHOW_RERUN=1" ] && ! grep -q '같은 한 줄' "$SB/window.txt"
  check "stop-410 410 이면 멈추고 「다시 하시는 법」을 켠다" $? "$(tail -3 "$SB/window.txt")"

  fresh stop
  poll '' false
  inst <<'EOF'
remote_help_loop
EOF
  grep -q '원격 해결이 끝났습니다' "$SB/window.txt"
  check "stop-closed 폴링 응답의 대화가 닫혀 있으면 멈춘다" $? "$(tail -3 "$SB/window.txt")"

  fresh stop
  echo 404 > "$STATE/poll.status"
  inst <<'EOF'
remote_help_loop
EOF
  grep -q '보고가 지워져' "$SB/window.txt"
  check "stop-404 보고가 지워지면 멈춘다" $? "$(tail -3 "$SB/window.txt")"

  fresh stop
  poll "$(cmd 1 '["sw_vers"]')"
  echo 410 > "$STATE/ack.status"
  inst <<'EOF'
remote_help_loop
EOF
  grep -q '원격 해결이 끝났습니다' "$SB/window.txt" && [ "$(grep -c '"GET"' "$STATE/requests.jsonl")" = "1" ]
  check "stop-ack-410 결과를 보낼 때 410 이면 폴링을 멈춘다" $? "$(grep -c '"GET"' "$STATE/requests.jsonl") GET"

  fresh stop
  inst <<'EOF'
REMOTE_HELP_MAX_SEC=0
remote_help_loop
EOF
  grep -q '원격 해결 시간' "$SB/window.txt" && grep -q '"path": "/api/help/TEST2345/close"' "$STATE/requests.jsonl" && ! grep -q '"GET"' "$STATE/requests.jsonl"
  check "stop-max 시간 상한(2시간)이 되면 닫기를 보내고 멈춘다" $? "$(cat "$STATE/requests.jsonl")"

  fresh stop
  BS='\'
  poll '' true "{\"action_no\":3,\"text\":\"복원${BS}u001b[31m 하세요${BS}n둘째 줄\",\"ts\":\"t\"}"
  inst <<'EOF'
remote_help_http GET /api/help/TEST2345
remote_help_tick
remote_help_http GET /api/help/TEST2345
remote_help_tick
EOF
  [ "$(grep -c '처방(조치 3): 복원\[31m 하세요' "$SB/window.txt")" = "1" ] && grep -q '둘째 줄' "$SB/window.txt" && ! LC_ALL=C grep -q "$(printf '\033')" "$SB/window.txt"
  check "answer-display 처방은 번호와 글을 한 번만 · 화면 제어 글자는 지운다" $? "$(grep -a '처방' "$SB/window.txt")"
}

t_close() {
  local pid i gets
  fresh close
  poll ''
  HOME="$SB/home" JARVIS_LIB_ONLY=1 T_SRC="$SRC" T_PORT="$PORT" bash -c '. "$T_SRC" || exit 5
HELP_API_URL="http://127.0.0.1:$T_PORT"
REMOTE_HELP_POLL_SEC=1
J_CODE=J-NET-02
remote_help' >> "$SB/window.txt" 2>&1 &
  pid=$!
  i=0
  while ! grep -q '"GET"' "$STATE/requests.jsonl" && [ "$i" -lt 100 ]; do sleep 0.1; i=$((i + 1)); done
  kill -HUP "$pid"
  i=0
  while kill -0 "$pid" 2>/dev/null && [ "$i" -lt 50 ]; do sleep 0.1; i=$((i + 1)); done
  gets="$(grep -c '"GET"' "$STATE/requests.jsonl")"
  sleep 2
  ! kill -0 "$pid" 2>/dev/null && [ "$(grep -c '"GET"' "$STATE/requests.jsonl")" = "$gets" ] &&
    tail -1 "$STATE/requests.jsonl" | grep -q '"path": "/api/help/TEST2345/close"'
  check "window-close 창이 닫히면(HUP) 닫기를 보내고 프로세스가 끝난다 · 그 뒤 폴링 0" $? "$(tail -2 "$STATE/requests.jsonl" | tr '\n' ' ')"
  kill -9 "$pid" 2>/dev/null
}

t_gate() {
  fresh gate
  inst <<'EOF'
MODE=full; J_CODE=""; remote_help
J_CODE=J-NET-02; REACHED_WAKE=1; remote_help
REACHED_WAKE=0; MODE=dry; remote_help
EOF
  [ ! -s "$STATE/requests.jsonl" ] && grep -q '(dry-run) 원격 해결 진단을 보내지 않았습니다' "$SB/window.txt" && ! grep -q '막혔을 때' "$SB/window.txt"
  check "gate 진단 코드 없음 · 자비스를 깨운 뒤 · dry-run = 보내지 않는다" $? "$(cat "$STATE/requests.jsonl")"

  # D1 기각(외부 검토 1차 재현) — 막힌 단(J-DL-04) 뒤 **깨우기가 실패하면** 원격 해결이 돈다. 진짜 step_wake 를 부른다
  #   (cys 없음 · 클로드 없음 = 이 창에서도 못 띄움 → rc 9) → 끝맺음 → POST /api/help 1건.
  fresh gate
  echo 410 > "$STATE/poll.status"
  inst <<'EOF'
MODE=full; J_CODE=J-DL-04; NOTICE_SHOWN=1; BLOCKED_STEP="cys 설치 파일 받기"
CYS_CLI="$T_SB/no-such-cys"; PATH="/usr/bin:/bin:/usr/sbin:/sbin"
step_wake
echo "WAKE_RC=$? REACHED_WAKE=$REACHED_WAKE" > "$T_SB/wake"
closing_note
EOF
  [ "$(grep -c '"path": "/api/help"' "$STATE/requests.jsonl")" = "1" ] && grep -q 'REACHED_WAKE=0' "$SB/wake" && ! grep -q 'WAKE_RC=0' "$SB/wake" &&
    grep -q '막혔을 때' "$SB/window.txt"
  check "wake-failed 막힌 단(J-DL-04) 뒤 자비스 깨우기가 실패하면 원격 해결이 돈다(보고 1건)" $? "$(cat "$SB/wake" 2>/dev/null) · 보고 $(grep -c '"path": "/api/help"' "$STATE/requests.jsonl")건"

  fresh gate
  echo 410 > "$STATE/poll.status"
  inst <<'EOF'
MODE=full; J_CODE=J-NET-02; NOTICE_SHOWN=0; closing_note
EOF
  [ ! -s "$STATE/requests.jsonl" ] && ! grep -q '막혔을 때' "$SB/window.txt"
  check "closing-notice-gate [1/10] 고지를 못 보여 드린 실행은 끝맺음에서 보내지 않는다" $? "$(cat "$STATE/requests.jsonl")"

  fresh gate
  echo 410 > "$STATE/poll.status"
  inst <<'EOF'
MODE=full; J_CODE=J-NET-02; NOTICE_SHOWN=1; SHOW_RERUN=1; closing_note
EOF
  grep -q '"path": "/api/help"' "$STATE/requests.jsonl" &&
    awk '/막혔을 때/{a=NR} /다시 하시는 법/{b=NR} END{exit !(a && b && a < b)}' "$SB/window.txt"
  check "closing-order 끝맺음이 원격 해결을 부르고 「다시 하시는 법」은 그 뒤 맨 끝에 둔다" $? "$(grep -n '막혔을 때\|다시 하시는 법' "$SB/window.txt" | tr '\n' ' ')"
}

t_static() {
  local region notice page
  fresh static
  inst <<'EOF'
printf '%s' "$REMOTE_HELP_NOTICE" > "$T_SB/notice"
printf '%s\n' "${REMOTE_HELP_LINES[@]}" > "$T_SB/lines"
EOF
  [ "$(cat "$SB/notice")" = "막히면 진단이 서버로 가고 운영 자비스가 원격으로 해결합니다 · 창을 닫으면 멈춥니다 · 자세히: jarvis-install.godmeyou.kr/help/notice" ]
  check "notice-text [1/10] 고지 1줄 = 계약 절7-1 글자 그대로" $? "$(cat "$SB/notice")"
  page="$AI_WEB/src/page.ts"
  if [ -f "$page" ]; then
    python3 - "$page" "$SB/notice" "$SB/lines" <<'PY'
import re, sys
page = open(sys.argv[1], encoding="utf-8").read()
notice = open(sys.argv[2], encoding="utf-8").read()
lines = open(sys.argv[3], encoding="utf-8").read().rstrip("\n").split("\n")
sentence = re.search(r"「([^」]+)」라고 한 줄로", page).group(1)
block = re.search(r"export const REMOTE_LINES = \[(.*?)\] as const;", page, re.S).group(1)
remote = [re.sub(r"</?b>", "", s) for s in re.findall(r'"((?:[^"\\]|\\.)*)"', block)]
sys.exit(0 if notice.startswith(sentence + " · 자세히: ") and lines == remote else 1)
PY
    check "notice-canon 고지 문장·「막혔을 때」 3줄 = page.ts 정본(태그만 뗌)" $? "page.ts 와 다르다"
  else
    printf '  skip notice-canon — page.ts 없음(%s)\n' "$page"
  fi
  awk '/^say "\[1\/10\] 이 컴퓨터를 살펴봅니다\."$/{a=NR} a && NR==a+1 && /^say "     \$REMOTE_HELP_NOTICE"$/{b=NR} b && NR==b+1 && /^NOTICE_SHOWN=1$/{ok=1} END{exit !ok}' "$SRC"
  check "wire-notice 본문 [1/10] 바로 뒤에 고지를 찍고 그때만 NOTICE_SHOWN=1" $? "배선이 없다"
  # D1 기각(외부 검토 1차) — REACHED_WAKE=1 은 파일에 한 자리뿐 · cys 창에 자비스를 연 줄 바로 뒤(주석 건너뜀) · 그 다음이 함대 부르기
  awk '/^[[:space:]]*#/{next}
       /REACHED_WAKE=1/{n++; if (prev ~ /cys 안에서 자비스를 열었습니다/) at=1; want=1; prev=$0; next}
       want{ if ($0 ~ /^[[:space:]]*step_fleet /) nxt=1; want=0 }
       {prev=$0}
       END{exit !(n == 1 && at && nxt)}' "$SRC"
  check "wire-wake REACHED_WAKE=1 은 깨우기가 성공한 뒤(cys 창을 연 갈래)에만 — 한 자리" $? "배선이 다르다"
  region="$(awk '/^# ── 원격 해결 \(help-s2\)/{f=1} /^# 시험이 이 파일을 「함수 묶음」으로만 읽는 문/{f=0} f' "$SRC" | grep -vE '^[[:space:]]*#')"
  ! printf '%s\n' "$region" | grep -qE '(^|[^A-Za-z_])eval |sh -c|bash -c|nohup|disown|setsid|Invoke-Expression' &&
    printf '%s\n' "$region" | grep -qF 'exec "$prog" ${args[@]+"${args[@]}"}'
  check "no-shell-static 원격 해결 절에 eval·sh -c·nohup·disown 0 · 실행은 exec \"\$prog\" \"\${args[@]}\" 한 자리" $? "절에 셸 경유가 있다"
}

want table   && t_table
want diff    && t_diff
want skip    && t_skip
want decline && t_decline
want text    && t_text
want forged  && t_forged
want path    && t_path
want toctou  && t_toctou
want seq     && t_seq
want display && t_display
want timeout && t_timeout
want big     && t_big
want report  && t_report
want stop    && t_stop
want close   && t_close
want gate    && t_gate
want static  && t_static

printf '\n통과 %d · 실패 %d\n' "$pass" "$fail"
[ "$fail" -eq 0 ]
