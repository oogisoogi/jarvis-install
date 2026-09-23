#!/bin/bash
# 0.3.29 흉내 실행 시험 — 새 갈래를 **실제로 부른다**(글자 대조가 아니라 실행 · TICKET=installer-0329).
#
# 재는 것
#   ⓐ 재시작 한 명령(윈 Get-CysRotateState · 맥 cys_rotate_state)이 가짜 cys 네 가지에서 정확히 갈린다
#      — 성공(rc 0) → ok · 옛 cys(모르는 하위명령 · rc 2) → absent · 실패(rc 1) → fail-1 · 실행 파일 없음 → absent
#      ⇒ ok 가 아닌 셋은 설치기가 종전 [재시작] 1클릭 안내로 돌아가는 갈래다(master 판정 859ceeb2 ⓑ).
#   ⓐ-2 cys 1.1.2 rotate 종료코드 표(TICKET=v112-vm-verify · master 판정 aa4419f8) —
#      21 → ok(rc 21) · 25 → held · 22·23·24 → fail-<rc> · 호출 인자 = rotate --timeout 120 ·
#      사후 알림 = **표준 출력**의 마지막 줄(오류 쪽 단계 진행 줄이 아니다)
#   ⓑ 살아 있는 master 자리 찾기(윈 Get-MasterSeatRef · 맥 master_seat_ref) — 끝난(exited=true) master 는 안 센다
#   ⓒ 옛 라운드 옮기기(윈 Move-OldRound · 맥 archive_old_round) — 전부 _round/archive/<시각>/ 로 가고
#      이미 있던 archive 는 그대로 · 지워진 파일 0 · _round 가 없으면 「_round 없음」 한 줄
#   ⓓ 환경 보고의 「사람 손 (실제로 누른 횟수)」 칸에 화면 계수와 같은 값이 적힌다(빈칸 0)
#
# 쓰는 법: bash tests/v0329-emu-run.sh [--dir <install-master 자리>]
#   rc 0 = 전건 통과 · 1 = 실패 있음 · 2 = 잴 수 없음(pwsh 가 없다)
# ⛔바깥에 닿지 않는다 — 네트워크 0 · 앱 실행 0 · 실물 cys 무접촉(가짜 cys · 가짜 HOME).
# ⚠여기서 안 재는 것: 실물 `cys rotate`(1.1.2 · 891)의 실제 동작·걸리는 시간 · 앱 창이 새 데몬에 붙는가(실기 몫).
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
SH="$(cd "$DIR" && pwd)/bootstrap.sh"
PW="$(command -v pwsh 2>/dev/null)"
[ -n "$PW" ] || { echo "잴 수 없음: pwsh 가 없다" >&2; exit 2; }
BASE="$(mktemp -d -t v0329emu)" || exit 2
trap 'rm -rf "$BASE"' EXIT
pass=0; fail=0
t() { if [ "$1" -eq 0 ]; then pass=$((pass+1)); printf '  ok   %s\n' "$2"; else fail=$((fail+1)); printf '  FAIL %s  ← %s\n' "$2" "$3"; fi; }

# ── 가짜 cys 네 벌 ──
mkstub() { # mkstub <이름> <본문>
  printf '#!/bin/bash\n%s\n' "$2" > "$BASE/$1"; chmod +x "$BASE/$1"
}
mkstub cys-ok     'case "$1" in rotate) echo "[rotate] ① 진행" >&2; echo "rotated"; echo "재시작 완료 — 알림 (rc=0)"; echo "[rotate] 끝" >&2; exit 0 ;; esac; exit 9'
# 1.1.2 종료코드 표 — rc 를 이름에서 받는다 · 받은 인자를 파일에 남겨 호출 인자까지 잰다
for rc in 21 22 23 24 25; do
  mkstub "cys-rc$rc" 'case "$1" in rotate) printf "%s\n" "$*" > "'"$BASE"'/args-rc'"$rc"'-$$"; echo "재시작 완료 — rc'"$rc"' 알림"; exit '"$rc"' ;; esac; exit 9'
done
mkstub cys-absent 'echo "error: unrecognized subcommand '"'"'$1'"'"'" >&2; exit 2'
mkstub cys-fail   'case "$1" in rotate) echo "drain timeout" >&2; exit 1 ;; esac; exit 9'
mkstub cys-list   'case "$1" in list)
printf "surface:3\trole=worker\tpid=11\texited=false\tworker\t/x\n"
printf "surface:5\trole=master\tpid=12\texited=true\tmaster\t/x\n"
printf "surface:7\trole=master\tpid=13\texited=false\tmaster\t/x\n"
exit 0 ;; esac; exit 9'
# rotate 가 끝나며 새 데몬을 남기는 모양 — 자식이 표준 출력을 쥔 채 30초 산다(agy 1R 지적 M: 명령 치환 파이프가 안 닫혀 설치 창이 멈춘다)
mkstub cys-leak   'case "$1" in rotate) sleep 30 & echo "rotated"; exit 0 ;; esac; exit 9'
NOPE="$BASE/no-such-cys"

# ── 옛 라운드 두 벌(윈·맥 각자) ──
mkround() { # mkround <집>
  mkdir -p "$1/_round/archive/old-1" "$1/_round/tasks"
  echo keep > "$1/_round/archive/old-1/a.md"
  echo s > "$1/_round/SESSION_STATE.md"
  echo c > "$1/_round/checkpoint-x-3.md"
  echo t > "$1/_round/tasks/t1.json"
  echo h > "$1/_round/.hidden"
}
mkround "$BASE/wh"; mkround "$BASE/mh"
mkdir -p "$BASE/wh-empty" "$BASE/mh-empty"

echo "== 윈(ps1) =="
out="$(JARVIS_LIB_ONLY=1 JARVIS_HOME="$BASE/wh" perl -e 'alarm shift; exec @ARGV or exit 126' 120 "$PW" -NoProfile -Command ". '$PS' *> \$null;
\$script:LogFile = '$BASE/wlog'
function Write-Log([string]\$m) { Add-Content -LiteralPath '$BASE/wlog' -Value \$m -Encoding UTF8 }
Write-Output ('r1=' + (Get-CysRotateState '$BASE/cys-ok'))
Write-Output ('r2=' + (Get-CysRotateState '$BASE/cys-absent'))
Write-Output ('r3=' + (Get-CysRotateState '$BASE/cys-fail'))
Write-Output ('r4=' + (Get-CysRotateState '$NOPE'))
foreach (\$rc in 21,22,23,24,25) { Write-Output ('x' + \$rc + '=' + (Get-CysRotateState ('$BASE/cys-rc' + \$rc))) }
Write-Output ('n1=' + (Get-CysRotateState '$BASE/cys-ok'))
Write-Output ('m1=' + (Get-MasterSeatRef '$BASE/cys-list'))
Write-Output ('m2=[' + (Get-MasterSeatRef '$BASE/cys-absent') + ']')
Move-OldRound
\$JarvisHome = '$BASE/wh-empty'; Move-OldRound
\$script:HumanHands = 2
\$JarvisHome = '$BASE/wh'; \$ReportFile = '$BASE/wh/env-report.md'
Write-Report *> \$null
" 2>&1)"
raw1="$out"   # 판정 줄 = 「<판정>\t<rc>\t<알림>」 — 옛 r1~r4 축은 판정 칸만 본다
wst() { printf '%s\n' "$raw1" | sed -n "s/^$1=//p" | cut -f1; }
wfd() { printf '%s\n' "$raw1" | sed -n "s/^$1=//p" | cut -f"$2"; }
out="$(printf '%s\n' "$raw1" | awk -F'\t' '/^r[1-4]=/{print $1; next} {print}')"
printf '%s' "$out" | grep -q '^r1=ok$';     t $? "[윈 r1] cys rotate 성공 → ok" "$out"
printf '%s' "$out" | grep -q '^r2=absent$'; t $? "[윈 r2] 옛 cys(모르는 하위명령) → absent(버튼 안내로 폴백)" "$out"
printf '%s' "$out" | grep -q '^r3=fail-1$'; t $? "[윈 r3] rotate 실패 rc 1 → fail-1(버튼 안내로 폴백)" "$out"
printf '%s' "$out" | grep -q '^r4=absent$'; t $? "[윈 r4] 실행 파일 없음 → absent(죽지 않는다)" "$out"
[ "$(wst x21)" = ok ] && [ "$(wfd x21 2)" = 21 ]; t $? "[윈 x21] rc 21(저장 일부 미확인) → ok · rc 21 을 넘긴다" "$(wst x21)|$(wfd x21 2)"
[ "$(wst x25)" = held ]; t $? "[윈 x25] rc 25(복원 보류) → held" "$(wst x25)"
[ "$(wst x22)" = fail-22 ] && [ "$(wst x23)" = fail-23 ] && [ "$(wst x24)" = fail-24 ]; t $? "[윈 x22-24] 도중 멈춤 → fail-<rc>" "$(wst x22) $(wst x23) $(wst x24)"
[ "$(wfd n1 3)" = "재시작 완료 — 알림 (rc=0)" ]; t $? "[윈 n1] 사후 알림 = 표준 출력 마지막 줄(오류 쪽 줄이 아니다)" "[$(wfd n1 3)]"
[ "$(wfd x21 3)" = "재시작 완료 — rc21 알림" ]; t $? "[윈 n2] rc 21 도 알림 줄을 넘긴다" "[$(wfd x21 3)]"
printf '%s' "$out" | grep -q '^m1=surface:7$'; t $? "[윈 m1] 살아 있는 master 자리를 찾는다(끝난 master 5 는 안 센다)" "$out"
printf '%s' "$out" | grep -q '^m2=\[\]$';  t $? "[윈 m2] 목록을 못 받으면 빈 값" "$out"
wa="$(ls -d "$BASE"/wh/_round/archive/2* 2>/dev/null | head -1)"
[ -n "$wa" ] && [ -f "$wa/SESSION_STATE.md" ] && [ -f "$wa/checkpoint-x-3.md" ] && [ -f "$wa/tasks/t1.json" ] && [ -f "$wa/.hidden" ]
t $? "[윈 ⓒ] 옛 라운드 전부(숨은 파일·하위 폴더 포함)가 archive/<시각>/ 로 갔다" "$(cd "$BASE/wh/_round" && find . | sort | tr '\n' ' ')"
[ "$(ls -A "$BASE/wh/_round" | tr '\n' ' ')" = "archive " ] && [ -f "$BASE/wh/_round/archive/old-1/a.md" ]
t $? "[윈 ⓒ] _round 에는 archive 만 남고 이미 있던 archive 는 그대로다" "$(ls -A "$BASE/wh/_round" | tr '\n' ' ')"
grep -q '^round archive: _round 없음$' "$BASE/wlog" 2>/dev/null; t $? "[윈 ⓒ] _round 가 없으면 「_round 없음」 한 줄" "$(cat "$BASE/wlog" 2>/dev/null | tr '\n' '|')"
grep -q '^round archive: _round\\archive\\[0-9-]* 로 옮김 — ' "$BASE/wlog" 2>/dev/null; t $? "[윈 ⓒ] 옮긴 목록을 기록 한 줄에 남긴다" "$(cat "$BASE/wlog" 2>/dev/null | tr '\n' '|')"
grep -q '실제로 누른 횟수): \*\*2번\*\*' "$BASE/wh/env-report.md" 2>/dev/null; t $? "[윈 ⓓ] 환경 보고의 실제 손 칸 = 화면 계수(2번)" "$(grep '사람 손' "$BASE/wh/env-report.md" 2>/dev/null | tr '\n' '|')"
! grep -q '____' "$BASE/wh/env-report.md" 2>/dev/null && [ -s "$BASE/wh/env-report.md" ]; t $? "[윈 ⓓ] 보고가 있고 빈칸(____)이 없다" "보고 없음 또는 빈칸 잔존"

echo "== 맥(sh) =="
mkdir -p "$BASE/home"
# ⚠이미 있는 폴더를 JARVIS_HOME 으로 주고 읽으면 설치기가 J-HOME-01 로 멈춘다(자기가 만든 폴더만 쓴다) —
#   없는 자리로 읽어 들인 뒤 함수를 부르기 전에 옮긴다.
run_sh() { HOME="$BASE/home" TMPDIR="$BASE" JARVIS_HOME="$BASE/home/install-jarvis" JARVIS_LIB_ONLY=1 \
  perl -e 'alarm shift; exec @ARGV or exit 126' 120 bash -c ". '$SH' >/dev/null 2>&1; JARVIS_HOME='$1'; LOG_FILE='$BASE/mlog'; $2" 2>/dev/null; }
out2="$(run_sh "$BASE/mh" '
for rc in 21 22 23 24 25; do printf "x%s=%s\n" "$rc" "$(cys_rotate_state "'"$BASE"'/cys-rc$rc")"; done
printf "n1=%s\n" "$(cys_rotate_state "'"$BASE"'/cys-ok")"
printf "r1=%s\n" "$(cys_rotate_state "'"$BASE"'/cys-ok")"
printf "r2=%s\n" "$(cys_rotate_state "'"$BASE"'/cys-absent")"
printf "r3=%s\n" "$(cys_rotate_state "'"$BASE"'/cys-fail")"
printf "r4=%s\n" "$(cys_rotate_state "'"$NOPE"'")"
t0=$SECONDS; printf "r5=%s\n" "$(cys_rotate_state "'"$BASE"'/cys-leak")"; printf "r5s=%s\n" "$((SECONDS - t0))"
printf "m1=%s\n" "$(master_seat_ref "'"$BASE"'/cys-list")"
printf "m2=[%s]\n" "$(master_seat_ref "'"$BASE"'/cys-absent")"
archive_old_round
JARVIS_HOME="'"$BASE"'/mh-empty"; archive_old_round
JARVIS_HOME="'"$BASE"'/mh"; REPORT_FILE="$JARVIS_HOME/env-report.md"; HUMAN_HANDS=2; : > "$ROWS_FILE"; write_report >/dev/null 2>&1
')"
mst() { printf '%s\n' "$out2" | sed -n "s/^$1=//p" | cut -f1; }
mfd() { printf '%s\n' "$out2" | sed -n "s/^$1=//p" | cut -f"$2"; }
raw2="$out2"
out2="$(printf '%s\n' "$raw2" | awk -F'\t' '/^r[1-5]=/{print $1; next} {print}')"
[ "$(mst x21)" = ok ] && [ "$(mfd x21 2)" = 21 ]; t $? "[맥 x21] rc 21(저장 일부 미확인) → ok · rc 21 을 넘긴다" "$(mst x21)|$(mfd x21 2)"
[ "$(mst x25)" = held ]; t $? "[맥 x25] rc 25(복원 보류) → held" "$(mst x25)"
[ "$(mst x22)" = fail-22 ] && [ "$(mst x23)" = fail-23 ] && [ "$(mst x24)" = fail-24 ]; t $? "[맥 x22-24] 도중 멈춤 → fail-<rc>" "$(mst x22) $(mst x23) $(mst x24)"
[ "$(mfd n1 3)" = "재시작 완료 — 알림 (rc=0)" ]; t $? "[맥 n1] 사후 알림 = 표준 출력 마지막 줄(오류 쪽 줄이 아니다)" "[$(mfd n1 3)]"
[ "$(mfd x21 3)" = "재시작 완료 — rc21 알림" ]; t $? "[맥 n2] rc 21 도 알림 줄을 넘긴다" "[$(mfd x21 3)]"
# 호출 인자 — 두 OS 다 rotate --timeout 120 으로 불렀는가(rc21 가짜가 남긴 인자 파일 전부)
na=0; for f in "$BASE"/args-rc21-*; do [ -f "$f" ] || continue; na=$((na+1)); [ "$(cat "$f")" = "rotate --timeout 120" ] || na=999; done
[ "$na" -eq 2 ]; t $? "[동형 인자] 두 OS 다 rotate --timeout 120 으로 부른다(인자 파일 2개 · 전부 일치)" "na=$na · $(cat "$BASE"/args-rc21-* 2>/dev/null | tr '\n' '|')"
printf '%s' "$out2" | grep -q '^r1=ok$';     t $? "[맥 r1] cys rotate 성공 → ok" "$out2"
printf '%s' "$out2" | grep -q '^r2=absent$'; t $? "[맥 r2] 옛 cys(모르는 하위명령) → absent(버튼 안내로 폴백)" "$out2"
printf '%s' "$out2" | grep -q '^r3=fail-1$'; t $? "[맥 r3] rotate 실패 rc 1 → fail-1(버튼 안내로 폴백)" "$out2"
printf '%s' "$out2" | grep -q '^r4=absent$'; t $? "[맥 r4] 실행 파일 없음 → absent(죽지 않는다)" "$out2"
r5s="$(printf '%s\n' "$out2" | sed -n 's/^r5s=//p')"
printf '%s' "$out2" | grep -q '^r5=ok$' && [ -n "$r5s" ] && [ "$r5s" -lt 10 ]; t $? "[맥 r5] rotate 가 자식(새 데몬)을 남겨도 설치 창이 기다리지 않는다(10초 안 · ok)" "r5s=${r5s:-?}s · $out2"
printf '%s' "$out2" | grep -q '^m1=surface:7$'; t $? "[맥 m1] 살아 있는 master 자리를 찾는다(끝난 master 5 는 안 센다)" "$out2"
printf '%s' "$out2" | grep -q '^m2=\[\]$';  t $? "[맥 m2] 목록을 못 받으면 빈 값" "$out2"
ma="$(ls -d "$BASE"/mh/_round/archive/2* 2>/dev/null | head -1)"
[ -n "$ma" ] && [ -f "$ma/SESSION_STATE.md" ] && [ -f "$ma/checkpoint-x-3.md" ] && [ -f "$ma/tasks/t1.json" ] && [ -f "$ma/.hidden" ]
t $? "[맥 ⓒ] 옛 라운드 전부(숨은 파일·하위 폴더 포함)가 archive/<시각>/ 로 갔다" "$(cd "$BASE/mh/_round" && find . | sort | tr '\n' ' ')"
[ "$(ls -A "$BASE/mh/_round" | tr '\n' ' ')" = "archive " ] && [ -f "$BASE/mh/_round/archive/old-1/a.md" ]
t $? "[맥 ⓒ] _round 에는 archive 만 남고 이미 있던 archive 는 그대로다" "$(ls -A "$BASE/mh/_round" | tr '\n' ' ')"
grep -q ' round archive: _round 없음$' "$BASE/mlog" 2>/dev/null; t $? "[맥 ⓒ] _round 가 없으면 「_round 없음」 한 줄" "$(cat "$BASE/mlog" 2>/dev/null | tr '\n' '|')"
grep -q ' round archive: _round/archive/[0-9-]* 로 옮김 — ' "$BASE/mlog" 2>/dev/null; t $? "[맥 ⓒ] 옮긴 목록을 기록 한 줄에 남긴다" "$(cat "$BASE/mlog" 2>/dev/null | tr '\n' '|')"
grep -q '실제로 누른 횟수): \*\*2번\*\*' "$BASE/mh/env-report.md" 2>/dev/null; t $? "[맥 ⓓ] 환경 보고의 실제 손 칸 = 화면 계수(2번)" "$(grep '사람 손' "$BASE/mh/env-report.md" 2>/dev/null | tr '\n' '|')"

# ★두 OS 의 분류가 같은가 — 한쪽만 고치면 텔레메트리 표기가 갈린다.
cw="$(printf '%s\n' "$out"  | grep -E '^(r[1-4])=' ; printf '%s\n' "$raw1" | grep -E '^(x2[1-5]|n1)=')"
cw="$(printf '%s\n' "$cw" | sort -u | tr '\n' ' ')"
cm="$(printf '%s\n' "$out2" | grep -E '^(r[1-4])=' ; printf '%s\n' "$raw2" | grep -E '^(x2[1-5]|n1)=')"
cm="$(printf '%s\n' "$cm" | sort -u | tr '\n' ' ')"
[ -n "$cw" ] && [ "$cw" = "$cm" ]; t $? "[동형] 두 OS 의 rotate 분류(옛 네 가지 + 1.1.2 표 다섯 + 알림)가 글자까지 같다" "윈[$cw] ≠ 맥[$cm]"

printf '\n통과 %s · 실패 %s\n' "$pass" "$fail"
[ "$fail" -eq 0 ]
