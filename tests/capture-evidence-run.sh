#!/bin/bash
# 캡처 증거 시험 — TICKET=installer-capture-evidence (2026-09-16 · v0.3.20)
#   계약 정본 = 서버 docs/HELP-API.md §10-2c(그림)·d(기준선)·e(촬영 요청)·§10-7(고지).
#
# 무엇을 재는가
#   ⓐ 두 걸음(증거 이벤트로 자리를 받고 그림을 올린다) · 계약에 없는 종류 거절 · 한 장 1.5MB · 설치당 12장 ·
#      429 두 종류를 갈라 다룬다(image_cap 이면 접는다) · 서버가 죽어도 설치는 이어간다
#   ⓐ-2 전체 화면(Get-ScreenJpeg)을 **부르는 자리가 0** 이다(정적 · 함수는 남아 있다) · 모르는 종류에 전체 화면을 내주지 않는다
#   ⓑ post-install 글자 = seat=master · hook_errors=N · 끝 40줄 · 마스킹
#   ⓓ 고지가 그림·찍는 창의 범위·그림은 못 가림을 말한다
#   ⓕ① 기준선 표가 비면 느림 촉발이 **꺼진다** · median 이 null 인 칸은 안 채운다 · 2배 「초과」에서만 켜진다
#   ⓕ③ 촉발 사유 글이 보내는 쪽·적는 쪽 **둘 다** 가려져 있다
#   ⓕ④ 촬영 요청은 진행 답에 실려 와 다음 자리에서 한 번만 처리된다
#
# 쓰는 법: bash tests/capture-evidence-run.sh [--dir <install-master 자리>]
#   rc 0 = 전건 통과 · 1 = 실패 있음 · 2 = 잴 수 없음(pwsh 가 없다)
# ⛔바깥에 닿지 않는다 — 주소는 127.0.0.1 가짜 서버뿐이고 쓰기는 mktemp -d 안에서만.
# ⚠여기서 **안 재는 것**: 실제 서버가 이 모양을 받는가(윈 실기 몫) · PrintWindow 가 윈도우에서 무엇을 담는지 ·
#   한 장이 1.5MB 안에 들어가는지(맥에는 윈도우 창이 없어 한 번도 못 찍었다) · 맥 화면 기록 권한(TCC).
set -u
HERE="$(cd "$(dirname "$0")" && pwd)"
DIR="$HERE/../install-master"
while [ $# -gt 0 ]; do
  case "$1" in
    --dir) DIR="$2"; shift 2 ;;
    *) echo "모르는 인자: $1" >&2; exit 2 ;;
  esac
done
PS="$(cd "$DIR" && pwd)/bootstrap.ps1"
SHFILE="$(cd "$DIR" && pwd)/bootstrap.sh"
pass=0; fail=0
ok()  { pass=$((pass+1)); printf '  ok   %s\n' "$1"; }
bad() { fail=$((fail+1)); printf '  FAIL %s  ← %s\n' "$1" "$2"; }
t() { if [ "$1" -eq 0 ]; then ok "$2"; else bad "$2" "$3"; fi; }

echo "== 정적(부르는 자리·고지) =="
ndef="$(grep -cE '^function Get-ScreenJpeg' "$PS")"
ncall="$(grep -vE '^\s*#' "$PS" | grep -cE '\(Get-ScreenJpeg\)' | tr -d ' ')"
[ "$ndef" = "1" ]; t $? "[전체화면] 함수는 남아 있다(정의 1)" "정의 ${ndef}개"
[ "$ncall" = "0" ]; t $? "[전체화면] 부르는 자리가 0 이다" "부르는 자리 ${ncall}곳"
grep -q "Send-Attachment 'screen_png' 'installer-window.jpg' (Get-InstallerWindowJpeg)" "$PS"
t $? "[전체화면] 실패 보고 첨부가 설치 창 한정이다" "첨부가 아직 전체 화면이다"
[ "$(grep -c 'Send-PostInstallEvidence \$cli \$SurfaceRef' "$PS")" = "2" ]
t $? "[post-install] 성공 두 자리(자동·카드 뒤)에서 부른다" "$(grep -c 'Send-PostInstallEvidence \$cli \$SurfaceRef' "$PS")곳"
grep -q 'post_install_evidence "\$cli" "\$ref"' "$SHFILE"
t $? "[post-install] 맥판도 성공 자리에서 부른다" "맥판에 호출이 없다"
# 이종 검토 1R ④ — 먹통 창에 PrintWindow 를 보내면 설치기가 통째로 멈춘다(창 크기를 묻기 전에 먼저 본다)
awk '/^function Get-WindowJpeg/{f=1} f&&!a&&/IsHungAppWindow\(\$h\)/{a=NR} f&&!b&&/GetWindowRect\(\$h/{b=NR} f&&/^}/{f=0} END{exit !(a&&b&&a<b)}' "$PS"
t $? "[먹통 창] 창 크기를 묻기 전에 먹통인지 먼저 본다" "먹통 검사가 없거나 순서가 뒤다 — 응답 없는 창에서 설치기가 멈춘다"
grep -q 'StartsWith($dir.TrimEnd' "$PS"
t $? "[앱 창] 우리가 깐 자리에서 도는 창만 찍는다" "이름만 보고 고른다 — 남의 같은 이름 창이 찍힐 수 있다"
# ⚠이 성질은 **맥에서 실물로 잴 수 없다** — 맥의 프로세스에는 윈도우 창 손잡이가 없어 관문을 빼도 답이 똑같이 「그림 없음」이다
#   (2026-09-16 뮤턴트 실측: 겹쳐 빼도 안 붉어졌다). ⇒ 여기서는 **글로** 재고, 실동작은 윈 실기 몫으로 남긴다.
grep -q "if (-not \$script:CysCli) { Write-Log 'app window skip (우리가 깐 자리를 모른다)'; return \$null }" "$PS"
t $? "[앱 창] 우리가 깐 자리를 모르면 찍지 않는다(정적)" "그 관문이 없다 — 자리를 모르는 채로 이름만 보고 찍으려 든다"
# ⓓ 고지 — 화면이 말하는 것과 실제로 나가는 것이 같아야 한다(2026-09-16 08:0x~08:3x 동안 일부러 붉었던 축).
#   ⚠고지 문안의 정본은 서버다. 이 저장소에서 문구를 **지어내지 마라** — 정본이 바뀌면 릴레이로 받아 핀을 간다.
NIMG="$(grep -c 'Send-EvidenceImage ' "$PS")"
[ "$NIMG" -ge 1 ]; t $? "[고지] 그림을 보내는 자리가 실재한다(이 축이 대상에 닿는지 먼저 단언)" "그림 보내는 자리 0곳 — 아래 두 축이 공허해진다"
! grep -q '설치 창에 표시된 글자만 보내지며' "$PS"
t $? "[고지] 고지가 「글자만」이라고 말하지 않는다" "그림을 보내면서 글자만 보낸다고 말한다"
grep -q '그림이 함께 보내집니다' "$PS" && grep -q '다른 창은 찍지 않습니다' "$PS" && grep -q '그림은 가릴 수 없어' "$PS"
t $? "[고지] 고지가 그림·찍는 창의 범위·그림은 못 가림을 말한다" "고지가 그림을 말하지 않는다 — 서버 정본 문안과 어긋났다"

PW="$(command -v pwsh 2>/dev/null)"
if [ -z "$PW" ]; then
  printf '\n통과 %s · 실패 %s · 잴 수 없음(윈도우판 구역): pwsh 가 없다\n' "$pass" "$fail"
  [ "$fail" -eq 0 ] && exit 2 || exit 1
fi

BASE="$(mktemp -d -t capture-emu)" || exit 2
BASE="$(cd "$BASE" && pwd -P)" || exit 2
SRVPID=""
cleanup() { [ -n "$SRVPID" ] && kill "$SRVPID" 2>/dev/null; rm -rf "$BASE"; }
trap cleanup EXIT
ST="$BASE/state"; mkdir -p "$ST"
# median 이 null 인 칸(6/10)을 일부러 섞는다 — 「아직 모른다」를 기본값으로 대신하지 않는지 재려고
cat > "$ST/baseline.json" <<'JSON'
{"os":"win","days":30,"min_samples":5,
 "steps":[{"step":"5/10","median_elapsed_s":10,"samples":61},
          {"step":"6/10","median_elapsed_s":null,"samples":3},
          {"step":"7/10","median_elapsed_s":"not-a-number","samples":9},
          {"step":"8/10","median_elapsed_s":0,"samples":9}]}
JSON
cat > "$ST/capture.json" <<'JSON'
{"id":"abcd1234","kinds":["app_window","full_screen"],"sig":"s","expires_at":"2026-09-16T10:00:00Z"}
JSON
python3 "$HERE/capture-fake-server.py" "$ST" & SRVPID=$!
for _ in 1 2 3 4 5 6 7 8 9 10; do [ -s "$ST/port" ] && break; perl -e 'select undef,undef,undef,0.3'; done
PORT="$(cat "$ST/port" 2>/dev/null)"
[ -n "$PORT" ] || { echo "가짜 서버를 못 열었다" >&2; exit 2; }
URL="http://127.0.0.1:$PORT"

echo
echo "== 두 걸음·상한·fail-open =="
perl -e 'alarm shift; exec @ARGV' 120 "$PW" -NoProfile -File "$HERE/capture-evidence-drive.ps1" \
  -Src "$PS" -Sb "$BASE" -Url "$URL" >"$BASE/out.txt" 2>"$BASE/err.txt"
F="$BASE/facts"
fact() { grep -E "^$1=" "$F" 2>/dev/null | tail -1 | cut -d= -f2-; }
q() { python3 - "$ST/requests.jsonl" "$@" <<'PYEOF'
import json, os, sys
rows = []
if os.path.exists(sys.argv[1]):
    rows = [json.loads(l) for l in open(sys.argv[1], encoding="utf-8") if l.strip()]
what = sys.argv[2]
imgs = [r for r in rows if r.get("what") == "image"]
prog = [r for r in rows if r.get("what") == "progress"]
if what == "img_count":     print(len(imgs))
elif what == "first":       print(json.dumps(imgs[0], ensure_ascii=False) if imgs else "{}")
elif what == "kinds":       print(",".join(sorted(set(r.get("kind") or "" for r in imgs))))
elif what == "maxbytes":    print(max([r.get("bytes") or 0 for r in imgs] or [0]))
elif what == "no_upload":   print(sum(1 for r in imgs if not r.get("upload")))
elif what == "no_clen":     print(sum(1 for r in imgs if not r.get("has_content_length")))
elif what == "ev_reasons":  print(",".join(sorted(set(r.get("reason") or "" for r in prog if r.get("event") == "evidence"))))
elif what == "empty_text":  print(sum(1 for r in prog if r.get("event") == "evidence" and r.get("has_text") and not r.get("text")))
elif what == "notext_ev":   print(sum(1 for r in prog if r.get("event") == "evidence" and not r.get("has_text")))
elif what == "getpaths":    print(",".join(r["path"] for r in rows if r["method"] == "GET"))
PYEOF
}
[ -s "$F" ]; t $? "[몰이] 끝까지 돌았다" "facts 가 비었다(err: $(head -c 200 "$BASE/err.txt"))"
[ -n "$(fact slot_seq)" ] && [ "$(fact slot_token_len)" = "64" ]
t $? "[두 걸음] 증거 이벤트가 그림 자리(seq·올리기 표)를 돌려준다" "seq=$(fact slot_seq) token길이=$(fact slot_token_len)"
FIRST="$(q first)"
printf '%s' "$FIRST" | grep -q '"kind": "installer_window"' && printf '%s' "$FIRST" | grep -q '"filename": "installer_window.jpg"'
t $? "[두 걸음] 종류·파일 이름을 주소에 싣는다" "첫 그림=$FIRST"
[ "$(q no_upload)" = "0" ]; t $? "[두 걸음] 모든 그림이 올리기 표를 머리글에 싣는다" "표 없는 그림 $(q no_upload)장"
[ "$(q no_clen)" = "0" ]; t $? "[두 걸음] 모든 그림이 길이를 싣는다(없으면 411)" "길이 없는 그림 $(q no_clen)장"
[ "$(fact send1)" = "True" ]; t $? "[그림] 보냈다고 답한다" "send1=$(fact send1)"
# 🔴길이·개수만 재면 「보냈다는데 내용이 어긋난 채 닿는」 결함을 놓친다(2026-09-16 실측: 길이 머리글을 손으로 넣어 본문이 통째로 거부됐다).
printf '%s' "$FIRST" | grep -q "\"sha256\": \"$(fact jpg_sha)\""
t $? "[그림] 보낸 바이트가 글자 그대로 닿는다(지문 대조)" "보낸 지문=$(fact jpg_sha) · 받은 것=$FIRST"
[ "$(fact noslot)" = "False" ]; t $? "[두 걸음] 자리가 없으면 그림을 올리지 않는다" "noslot=$(fact noslot)"
[ "$(fact badkind)" = "False" ]; t $? "[종류] 계약에 없는 종류는 올리지 않는다" "badkind=$(fact badkind)"
{ [ "$(fact unknownkind_null)" = "True" ] && [ "$(fact unknownkind_null2)" = "True" ]; }
t $? "[종류] 모르는 종류에 전체 화면을 내주지 않는다" "실물=$(fact unknownkind_null) 흉내끼운뒤=$(fact unknownkind_null2)"
[ "$(fact firstpane_null)" = "True" ]; t $? "[종류] 첫 자리는 그림을 만들지 않는다(앱 창 안의 한 칸 · 글자로 보낸다)" "firstpane_null=$(fact firstpane_null)"
[ "$(fact oversize)" = "False" ]; t $? "[그림] 1.5MB 넘는 한 장은 보내지 않는다" "oversize=$(fact oversize)"
[ "$(q maxbytes)" -le 1572864 ]; t $? "[그림] 서버가 받은 가장 큰 장이 상한 안이다" "$(q maxbytes)B"
[ "$(fact sentcount)" = "12" ]; t $? "[그림] 설치당 12장에서 멈춘다" "sentcount=$(fact sentcount)"
[ "$(q empty_text)" = "0" ]; t $? "[글자] 빈 글을 칸에 넣어 보내지 않는다(빈 글 = 400)" "빈 글을 실은 증거 $(q empty_text)건"
[ "$(q notext_ev)" -ge 1 ]; t $? "[글자] 글자 없는 증거는 칸을 아예 뺀다" "칸을 뺀 증거 0건"
[ "$(fact after_rate_limited_done)" = "False" ]; t $? "[429] rate_limited 는 접지 않는다(잠시 뒤 다시 올려도 된다)" "접었다"
[ "$(fact after_cap_done)" = "True" ]; t $? "[429] image_cap 이면 접는다(재시도해도 같은 답이다)" "안 접었다"
[ "$(fact after_fail)" = "SURVIVED" ]; t $? "[fail-open] 서버가 거절해도 설치가 이어진다" "죽었다"

echo
echo "== 기준선(ⓕ①) =="
[ "$(fact slow_empty_huge)" = "False" ]; t $? "[기준선] 표가 비면 아무리 느려도 촉발하지 않는다(모름 ≠ 느림)" "slow_empty_huge=$(fact slow_empty_huge)"
printf '%s' "$(q getpaths)" | grep -q '/baseline?os=win'
t $? "[기준선] [1/10] 이 서버에 표를 물어본다" "GET 자리=$(q getpaths)"
[ "$(fact baseline_note)" = "ok:1" ]; t $? "[기준선] 쓸 수 있는 칸만 받는다(null·숫자 아님·0 은 버린다)" "note=$(fact baseline_note)"
[ "$(fact baseline_5)" = "10" ]; t $? "[기준선] 받은 값이 표에 들어간다" "5/10=$(fact baseline_5)"
[ "$(fact baseline_6_null)" = "True" ]; t $? "[기준선] median 이 null 인 칸은 내장 기본값으로 대신하지 않는다" "6/10 을 채웠다"
[ "$(fact slow_at_2x)" = "False" ]; t $? "[기준선] 딱 2배는 촉발하지 않는다(초과여야 한다)" "slow_at_2x=$(fact slow_at_2x)"
[ "$(fact slow_over_2x)" = "True" ]; t $? "[기준선] 2배를 넘으면 촉발한다" "slow_over_2x=$(fact slow_over_2x)"
[ "$(fact slow_unknown)" = "False" ]; t $? "[기준선] 표에 없는 단계는 여전히 꺼져 있다" "slow_unknown=$(fact slow_unknown)"

echo
echo "== 촬영 요청(ⓕ④) · post-install(ⓑ) · 마스킹(ⓕ③) =="
[ "$(fact capreq_kinds)" = "app_window" ]; t $? "[촬영 요청] 진행 답으로 받고 모르는 종류는 그것만 건너뛴다" "받은 종류=$(fact capreq_kinds)"
[ "$(fact capreq_after)" = "True" ]; t $? "[촬영 요청] 쓰고 버린다(1회성 · 들고 있지 않는다)" "아직 들고 있다"
[ "$(fact capreq_images)" = "1" ]; t $? "[촬영 요청] 청한 창을 찍어 보낸다" "장수=$(fact capreq_images)"
[ "$(fact capreq_images2)" = "$(fact capreq_images)" ]; t $? "[촬영 요청] 두 번째 호출은 아무 일도 하지 않는다" "또 보냈다"
printf '%s' "$(q ev_reasons)" | grep -q 'requested'
t $? "[촬영 요청] 이유가 requested 로 나간다" "이유=$(q ev_reasons)"
E="$ST/requests.jsonl"
python3 - "$E" <<'PYEOF'
import json, os, sys
rows = [json.loads(l) for l in open(sys.argv[1], encoding="utf-8") if l.strip()] if os.path.exists(sys.argv[1]) else []
ev = [r for r in rows if r.get("what") == "progress" and r.get("reason") == "post-install"]
if len(ev) != 2: sys.exit(1)          # 자리를 아는 호출 + 자리를 모르는 호출
t = ev[0].get("text") or ""
checks = [
    ev[0].get("step") == "10/10", ev[0].get("masked") is True,
    t.startswith("seat=master\nhook_errors=3\n"),
    "DONE-LAST" in t, "CUT-ME-HEAD" not in t, len(t.split("\n")) == 42,
    "hong@example.com" not in t and "hong" not in t,
    not ev[1].get("has_text"),          # 자리를 모르면 글자 칸을 아예 뺀다
]
sys.exit(0 if all(checks) else 1)
PYEOF
t $? "[post-install] seat=master · 훅 오류 3줄 · 끝 40줄 · 마스킹 · 자리를 모르면 글자 칸을 뺀다" "$(python3 -c "
import json,os
p='$E'
rows=[json.loads(l) for l in open(p,encoding='utf-8') if l.strip()] if os.path.exists(p) else []
ev=[r for r in rows if r.get('reason')=='post-install']
print(len(ev),'건',repr((ev[0].get('text') or '')[:110]) if ev else '')")"
[ "$(fact postinstall_images)" = "1" ]; t $? "[post-install] 앱 창 그림 한 장을 보낸다" "장수=$(fact postinstall_images)"
printf '%s' "$(q kinds)" | grep -q 'app_window'
t $? "[post-install] 그림 종류가 app_window 다" "종류=$(q kinds)"
# 🔴종류 이름으로 골라 온 그림도 바이트가 온전해야 한다 — 이 길은 함수를 하나 더 거치므로 모양이 달라질 수 있다.
python3 - "$E" "$(fact stub_sha)" <<'PYEOF'
import json, os, sys
rows = [json.loads(l) for l in open(sys.argv[1], encoding="utf-8") if l.strip()] if os.path.exists(sys.argv[1]) else []
app = [r for r in rows if r.get("what") == "image" and r.get("kind") == "app_window"]
sys.exit(0 if app and all(r.get("sha256") == sys.argv[2] for r in app) else 1)
PYEOF
t $? "[그림] 종류로 골라 온 그림도 바이트가 글자 그대로 닿는다" "받은 app_window 지문이 보낸 것과 다르다(또는 0장)"
python3 - "$E" <<'PYEOF'
import json, os, sys
rows = [json.loads(l) for l in open(sys.argv[1], encoding="utf-8") if l.strip()] if os.path.exists(sys.argv[1]) else []
ev = [r for r in rows if r.get("what") == "progress" and r.get("reason") == "error-text"]
t = (ev[0].get("text") or "") if ev else ""
sys.exit(0 if (len(ev) == 1 and t.startswith("[error-text] failed to open ")
               and "hong@example.com" not in t and "hong" not in t) else 1)
PYEOF
t $? "[ⓕ③] 촉발 사유 글이 마스킹된 채 나간다" "$(python3 -c "
import json,os
p='$E'
rows=[json.loads(l) for l in open(p,encoding='utf-8') if l.strip()] if os.path.exists(p) else []
ev=[r for r in rows if r.get('reason')=='error-text']
print(repr((ev[0].get('text') or '')[:140]) if ev else '증거 0건')")"
LOGF="$BASE/home/install-jarvis/bootstrap.log"
{ grep -q 'capture evidence: error-text' "$LOGF" 2>/dev/null && ! grep -q 'hong' "$LOGF" 2>/dev/null; }
t $? "[ⓕ③] 기록 파일의 사유 글도 가려져 있다(실패 때 이 파일이 통째로 나간다)" "$(grep 'capture evidence: error-text' "$LOGF" 2>/dev/null | head -1 | cut -c1-140)"
[ "$(fact installer_jpeg_null)" = "True" ]; t $? "[설치 창] 맥에는 윈도우 콘솔이 없어 그림 없이 끝난다(죽지 않는다)" "null=$(fact installer_jpeg_null)"
[ "$(fact appwin_nocli_null)" = "True" ]; t $? "[앱 창] 자리를 모를 때 죽지 않고 그림 없이 끝난다" "appwin_nocli_null=$(fact appwin_nocli_null)"

printf '\n통과 %s · 실패 %s\n' "$pass" "$fail"
[ "$fail" -eq 0 ]
