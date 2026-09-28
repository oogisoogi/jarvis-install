#!/bin/bash
# 0.3.36 — 첫 화면 진행 고지가 첫 전송보다 먼저 뜬다(두 OS) · 고지 전에는 맥 설치기가 아무것도 보내지 않는다.
#
# 까닭: 맥 설치기는 진행 단계·기기 정보를 보내면서 첫 화면에 그 고지가 없었다(윈만 있었다 · 개인정보 원칙 위반 · master#ecd6c2b5).
# 재는 것
#   ⓐ 두 OS 첫 화면 고지 문구 = 박사님 확정 문구 그대로(윈 = 문단 첫 문장 · 맥 = 한 줄)
#   ⓑ 본문 순서(주석 걷음): 「[1/10]」 → 고지 줄 → 첫 전송 호출 — 두 OS 모두 고지가 첫 전송보다 앞
#   ⓒ 맥 행동: NOTICE_SHOWN=1 전에는 progress_send·증거 전송이 가짜 curl 을 한 번도 부르지 않는다(끝맺음 실패 이벤트 포함)
#      대조군: NOTICE_SHOWN=1 뒤에는 부른다(0건이 공허하지 않다)
#   ⓔ 맥 첫 화면 반 줄(0.3.36): 창 글자를 보낸다는 고지 = 확정 문구 글자 그대로 ·
#      진행 고지 바로 다음 줄 · 첫 전송보다 먼저(창 글자는 증거 전송으로 나가므로 그보다 앞서야 한다)
#   ⓕ 맥 행동(0.3.36 · 적대 검토 반례): 고지 전에 지난 실행 꼬리의 오류 줄([5/10] … failed)이 찍혀도 촉발 증거의 「한 번」 표시를
#      남기지 않는다 — 고지 뒤 이번 실행 [5/10] 의 진짜 오류 줄이 증거를 보낸다(대조군 = [6/10] 도 보낸다 · 흉내 = show_prev_run_note → say)
#   ⓓ 윈 행동(이종 검토 3회차 반례): $script:NoticeShown 이 거짓이면 Send-Progress·Send-EvidenceEvent·Send-CaptureEvidence 가
#      Invoke-WebRequest 를 한 번도 부르지 않는다(지난 실행 꼬리의 error-text 촉발·끝맺음 J-UNK-00 이 고지 전에 나가던 길) · 대조군 = 고지 뒤엔 부른다
# 쓰는 법: bash tests/notice-before-send.sh [--dir <install-master 자리>]   · rc 0 = 통과 · 1 = 실패
set -u
HERE="$(cd "$(dirname "$0")" && pwd)"
DIR="$HERE/../install-master"
[ "${1:-}" = "--dir" ] && DIR="$2"
SH="$(cd "$DIR" && pwd)/bootstrap.sh"
PS="$(cd "$DIR" && pwd)/bootstrap.ps1"
BASE="$(mktemp -d /tmp/noticeXXXXXX)" || exit 2
trap 'rm -rf "$BASE"' EXIT
pass=0; fail=0
t() { if [ "$1" -eq 0 ]; then pass=$((pass+1)); printf '  ok   %s\n' "$2"; else fail=$((fail+1)); printf '  FAIL %s  ← %s\n' "$2" "$3"; fi; }
OWNER='설치가 잘 되는지 보려고 진행 단계와 기기 정보(모델, 메모리, 남은 공간)를 자동으로 보냅니다.'
OWNER_CAP='설치가 끝나거나 막히거나 이상이 보이면, 도와드리기 위해 이 창과 자비스 창의 글자를 운영팀에 보냅니다(개인정보는 가리고 30일 뒤 지웁니다).'

r="$(OWNER="$OWNER" OWNER_CAP="$OWNER_CAP" python3 - "$SH" "$PS" <<'PY'
import os, re, sys
own = os.environ["OWNER"]
own_cap = os.environ["OWNER_CAP"]
sh = open(sys.argv[1], encoding="utf-8").read()
ps = open(sys.argv[2], encoding="utf-8-sig").read()
out = []
m = re.search(r'^PROGRESS_NOTICE="([^"]*)"', sh, re.M)
out.append("mac-text=" + ("1" if m and m.group(1) == own else "0:" + (m.group(1) if m else "none")))
m = re.search(r"^\$ProgressNotice = '([^']*)'", ps, re.M)
out.append("win-text=" + ("1" if m and m.group(1).startswith(own + " ") else "0"))
def order(src, start, notice_pat, send_pat):
    i = src.index(start)
    lines = [l.split("#", 1)[0] for l in src[i:].splitlines()]   # 주석 걷음
    a = next((k for k, l in enumerate(lines) if "[1/10] 이 컴퓨터를 살펴봅니다" in l), None)
    n = next((k for k, l in enumerate(lines) if re.search(notice_pat, l)), None)
    s = next((k for k, l in enumerate(lines) if re.search(send_pat, l)), None)
    return "1" if None not in (a, n, s) and a < n < s else "0:%s,%s,%s" % (a, n, s)
out.append("mac-order=" + order(sh, "# ── 본문", r'^say "     \$PROGRESS_NOTICE"', r'^\s*(progress_send|evidence_once|evidence_event_send)\b'))
m = re.search(r'^CAPTURE_NOTICE="([^"]*)"', sh, re.M)
out.append("mac-cap-text=" + ("1" if m and m.group(1) == own_cap else "0:" + (m.group(1) if m else "none")))
body = [l.split("#", 1)[0] for l in sh[sh.index("# ── 본문"):].splitlines()]
pn = next((k for k, l in enumerate(body) if re.search(r'^say "     \$PROGRESS_NOTICE"', l)), None)
# 줄 끝까지 고정(주석은 이미 걷었다) — `>/dev/null` 같은 꼬리로 화면에서 숨기면 적색(이종 검토 반례)
cn = next((k for k, l in enumerate(body) if re.search(r'^say "     \$CAPTURE_NOTICE"\s*$', l)), None)
fs = next((k for k, l in enumerate(body) if re.search(r'^\s*(progress_send|evidence_once|evidence_event_send|capture_evidence)\b', l)), None)
# 전송 문(NOTICE_SHOWN=1)은 창 글자 고지 뒤 · 첫 전송 앞 — 고지를 찍는 사이에 멈추면 고지 없이 나갈 틈이 생긴다(이종 검토 반례)
ns = next((k for k, l in enumerate(body) if re.search(r'^NOTICE_SHOWN=1\s*$', l)), None)
# 대입 횟수(주석 걷고 파일 전체) — 본문 밖·다른 자리에서 문을 먼저 열거나 문구를 비우면 줄 위치 시험만으로는 안 보인다(적대 검토 2회차 반례)
code = "\n".join(l.split("#", 1)[0] for l in sh.splitlines())
na = re.findall(r'(?m)^\s*(?:export\s+|declare\s+(?:-\w+\s+)?|local\s+|readonly\s+)?NOTICE_SHOWN=(\S*)', code) + re.findall(r'[;&|]\s*NOTICE_SHOWN=(\S*)', code)
# 대입 문 밖의 쓰기 모양(printf -v · read · eval 글자 안 · declare -g 등)도 0 이어야 한다(적대 검토 r5 NIT)
na += ["other"] * len(re.findall(r'printf\s+-v\s+NOTICE_SHOWN|\bread\b[^\n]*\bNOTICE_SHOWN\b|eval[^\n]*NOTICE_SHOWN', code))
ca = re.findall(r'(?m)^\s*(?:export\s+|declare\s+(?:-\w+\s+)?|local\s+)?CAPTURE_NOTICE=', code) + re.findall(r'[;&|]\s*CAPTURE_NOTICE=', code)
out.append("mac-assign=" + ("1" if sorted(v.strip(chr(34) + chr(39)) for v in na) == ["0", "1"] and len(ca) == 1 else "0:NOTICE_SHOWN%s,CAPTURE_NOTICE%d" % (na, len(ca))))
out.append("mac-cap-order=" + ("1" if None not in (pn, cn, fs, ns) and cn == pn + 1 and cn < ns < fs else "0:%s,%s,%s,%s" % (pn, cn, ns, fs)))
out.append("win-order=" + order(ps, "Say '[1/10] 이 컴퓨터를 살펴봅니다.'", r"^\s*Say \('     ' \+ \$ProgressNotice\)", r'^\s*(Send-Progress|Send-EvidenceOnce|Send-EvidenceEvent)\b'))
# 윈 전송 문(0.3.36 · 맥과 같은 자리): $script:NoticeShown = $true 는 고지 줄($ProgressNotice)을 찍은 **뒤** · 첫 전송 앞 · 파일 전체에 대입은 초기값 거짓 1 + 참 1
pb = [l.split("#", 1)[0] for l in ps[ps.index("Say '[1/10] 이 컴퓨터를 살펴봅니다.'"):].splitlines()]
wn = next((k for k, l in enumerate(pb) if re.search(r"^\s*Say \('     ' \+ \$ProgressNotice\)\s*$", l)), None)
wf = next((k for k, l in enumerate(pb) if re.search(r"^\s*\$script:NoticeShown\s*=\s*\$true\s*$", l)), None)
ws = next((k for k, l in enumerate(pb) if re.search(r'^\s*(Send-Progress|Send-EvidenceOnce|Send-EvidenceEvent|Send-CaptureEvidence)\b', l)), None)
pcode = "\n".join(l.split("#", 1)[0] for l in ps.splitlines())
# 대입은 접두(script:) 유무·오른쪽 값 모양과 무관하게 전부 센다 + Set-Variable 형태(적대 검토 r5 반례: `= 1` · `$NoticeShown =` · Set-Variable 이 거짓 초록)
wa = re.findall(r"(?<![\w:])\$(?:script:)?NoticeShown\s*=(?!=)\s*(\S+)", pcode)
wsv = len(re.findall(r"Set-Variable\b[^\n]*NoticeShown", pcode, re.I))
out.append("win-flag=" + ("1" if None not in (wn, wf, ws) and wn < wf < ws and sorted(wa) == ["$false", "$true"] and wsv == 0 else "0:%s,%s,%s,%s,sv=%d" % (wn, wf, ws, wa, wsv)))
print(" ".join(out))
PY
)"
case "$r" in *mac-text=1*) true ;; *) false ;; esac; t $? "[ⓐ 맥] 첫 화면 고지 한 줄 = 박사님 확정 문구 그대로" "$r"
case "$r" in *win-text=1*) true ;; *) false ;; esac; t $? "[ⓐ 윈] 첫 화면 고지 첫 문장 = 박사님 확정 문구 그대로" "$r"
case "$r" in *mac-order=1*) true ;; *) false ;; esac; t $? "[ⓑ 맥] 본문 순서 [1/10] → 고지 → 첫 전송" "$r"
case "$r" in *win-order=1*) true ;; *) false ;; esac; t $? "[ⓑ 윈] 본문 순서 [1/10] → 고지 → 첫 전송" "$r"
case "$r" in *mac-cap-text=1*) true ;; *) false ;; esac; t $? "[ⓔ 맥] 창 글자 고지 반 줄 = 확정 문구 글자 그대로" "$r"
case "$r" in *mac-cap-order=1*) true ;; *) false ;; esac; t $? "[ⓔ 맥] 진행 고지 바로 다음 줄(화면에 찍힘) · 전송 문은 그 뒤 · 첫 전송보다 먼저" "$r"
case "$r" in *win-flag=1*) true ;; *) false ;; esac; t $? "[ⓑ 윈] 전송 문(NoticeShown)은 고지 줄을 찍은 뒤 · 첫 전송 앞 · 대입은 초기값 거짓 1 + 참 1 뿐" "$r"
case "$r" in *mac-assign=1*) true ;; *) false ;; esac; t $? "[ⓔ 맥] 전송 문 대입은 파일 전체에 초기값 0 한 번 · 본문 1 한 번뿐 · 창 글자 고지 문구 대입 한 번뿐" "$r"

mkdir -p "$BASE/bin"
cat > "$BASE/bin/curl" <<EOF
#!/bin/bash
for a in "\$@"; do case "\$a" in http://*|https://*) echo "\$a" >> "\$CURL_LOG" ;; esac; done
printf 000; exit 7
EOF
chmod +x "$BASE/bin/curl"
mac_run() { # mac_run <이름> <NOTICE_SHOWN 값>
  local h="$BASE/$1"; mkdir -p "$h"; : > "$BASE/$1.calls"
  env -i PATH="$BASE/bin:/usr/bin:/bin:/usr/sbin:/sbin" HOME="$h" TMPDIR="$BASE" JARVIS_HOME="$h/install-jarvis" JARVIS_LIB_ONLY=1 \
      JARVIS_PROGRESS_URL="http://127.0.0.1:9/fake" CURL_LOG="$BASE/$1.calls" SH="$SH" NS="$2" \
    perl -e 'alarm 60; exec @ARGV or exit 126' /bin/bash -c '. "$SH" >/dev/null 2>&1; mkdir -p "$JARVIS_HOME"; MODE=full; NOTICE_SHOWN="$NS"
progress_send "1/10" start "" "" ""; evidence_event_send stall >/dev/null 2>&1; exit 1' >/dev/null 2>&1
}
mac_run before 0
n="$(grep -c . "$BASE/before.calls" 2>/dev/null)"; [ "${n:-0}" = "0" ]; t $? "[ⓒ 맥] 고지 전(NOTICE_SHOWN=0)에는 진행·증거·끝맺음 실패 전송이 한 번도 안 나간다" "호출 $n 건"
mac_run after 1
n="$(grep -c . "$BASE/after.calls" 2>/dev/null)"; [ "${n:-0}" -ge 1 ]; t $? "[ⓒ 대조군] 고지 뒤(NOTICE_SHOWN=1)에는 보낸다" "호출 ${n:-0} 건"

# ⓕ — 지난 꼬리 오류 줄이 고지 전에 촉발 표시를 먹지 않는다
prev_tail_run() { # prev_tail_run <이름> → 고지 뒤 전송 호출 수를 <이름>.calls 에
  local h="$BASE/$1"; mkdir -p "$h"; : > "$BASE/$1.calls"
  env -i PATH="$BASE/bin:/usr/bin:/bin:/usr/sbin:/sbin" HOME="$h" TMPDIR="$BASE" JARVIS_HOME="$h/install-jarvis" JARVIS_LIB_ONLY=1 \
      JARVIS_PROGRESS_URL="http://127.0.0.1:9/fake" CURL_LOG="$BASE/$1.pre" SH="$SH" OUT="$BASE/$1.calls" STEP="$2" \
    perl -e 'alarm 60; exec @ARGV or exit 126' /bin/bash -c '. "$SH" >/dev/null 2>&1; mkdir -p "$JARVIS_HOME"; MODE=full; NOTICE_SHOWN=0
PREV_TAIL="[5/10] npm ERR! install failed"; PREV_RUN_STATE=""; show_prev_run_note >/dev/null 2>&1
NOTICE_SHOWN=1; export CURL_LOG="$OUT"
say "[$STEP] 이번 실행 단계" >/dev/null 2>&1; say "     npm ERR! install failed" >/dev/null 2>&1; exit 0' >/dev/null 2>&1
}
prev_tail_run tail5 5/10
n="$(grep -c . "$BASE/tail5.calls" 2>/dev/null)"; p="$(grep -c . "$BASE/tail5.pre" 2>/dev/null)"
[ "${n:-0}" -ge 1 ] && [ "${p:-0}" = "0" ]; t $? "[ⓕ 맥] 지난 꼬리 오류 줄([5/10])이 고지 전에 찍혀도 이번 [5/10] 오류 증거가 나간다(고지 전 전송 0)" "고지 뒤 호출 ${n:-0} · 고지 전 호출 ${p:-0}"
prev_tail_run tail6 6/10
n="$(grep -c . "$BASE/tail6.calls" 2>/dev/null)"; [ "${n:-0}" -ge 1 ]; t $? "[ⓕ 대조군] 다른 단계([6/10]) 오류 증거는 원래 나간다(흉내가 공허하지 않다)" "호출 ${n:-0}"

PW="$(command -v pwsh 2>/dev/null)"
if [ -z "$PW" ]; then
  t 1 "[ⓓ 윈] pwsh 가 있어야 윈 고지 전 전송 0 을 잰다(건너뜀 ≠ 통과)" "pwsh 없음"
else
  win_notice() { # win_notice <$true|$false> → 부른 주소 수
    env -u JARVIS_NO_PROGRESS -u JARVIS_PROGRESS_URL JARVIS_LIB_ONLY=1 JARVIS_HOME="$BASE/wh" \
      perl -e 'alarm 90; exec @ARGV or exit 126' "$PW" -NoProfile -Command ". '$PS' *> \$null; function Write-Log([string]\$m) { }
\$script:seen = @(); function Invoke-WebRequest { param(\$Uri) \$script:seen += [string]\$Uri; throw 'no network in test' }
\$Mode = 'full'; \$script:NoticeShown = $1
try { Send-Progress '0/10' 'fail' \$null 'J-UNK-00' \$null } catch { }
try { [void](Send-EvidenceEvent 'fail' 'x') } catch { }
try { Send-CaptureEvidence 'error-text' 'Access is denied' } catch { }
'calls=' + \$script:seen.Count" 2>/dev/null | grep -o 'calls=[0-9]*' | tail -1
  }
  r="$(win_notice '$false')"; [ "$r" = "calls=0" ]; t $? "[ⓓ 윈] 고지 전(NoticeShown 거짓)에는 진행·증거·촉발 증거를 보내지 않는다" "$r"
  r="$(win_notice '$true')"; case "$r" in calls=[1-9]*) true ;; *) false ;; esac; t $? "[ⓓ 윈 대조군] 고지 뒤에는 부른다(0건이 공허하지 않다)" "$r"
fi

echo "== 합계: ok $pass · FAIL $fail =="
[ "$fail" -eq 0 ]
