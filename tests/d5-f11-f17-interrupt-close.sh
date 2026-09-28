#!/bin/bash
# 0.3.36 F11 · F17 행동 시험(맥) — 가상 터미널(pty)에서 실제 bootstrap.sh 를 끊고 닫아 본다.
#
# 재는 것
#   F11 ⓐ 로그인 대기 중 Ctrl-C → 대기 감시자(login_waiter)가 남지 않는다 ⓑ 대기 표식(.login-wait)이 남지 않는다
#   F17 ⓐ 창을 닫으면(pty 닫힘 = HUP) bootstrap.log 의 모든 줄이 시각으로 시작한다(시각 없는 「다음에 할 일」 줄 0)
#       ⓑ 창이 닫힌 끝은 「창이 닫혀 끝났습니다」 한 줄로 남고, 다음 실행은 종전대로 「갑자기 닫힘」(J-AV-03)으로 읽는다(진단을 지우지 않는다)
#       ⓒ 대조군: 창이 살아 있는 채 끝난 실행은 그 줄이 없고 「끝맺음까지 갔다」(closed) — 창 가르기가 거짓 양성을 내지 않는다
# 쓰는 법: bash tests/d5-f11-f17-interrupt-close.sh [--dir <install-master 자리>]   · rc 0 = 통과 · 1 = 실패
# ⛔바깥에 닿지 않는다 — 가짜 HOME · JARVIS_LIB_ONLY · 진행 전송 끔 · 띄운 프로세스는 번호로만 거둔다(이름 매칭 pkill 금지).
set -u
HERE="$(cd "$(dirname "$0")" && pwd)"
DIR="$HERE/../install-master"
[ "${1:-}" = "--dir" ] && DIR="$2"
SH="$(cd "$DIR" && pwd)/bootstrap.sh"
BASE="$(mktemp -d -t d5f11f17)" || exit 2
trap 'rm -rf "$BASE"' EXIT
pass=0; fail=0
t() { if [ "$1" -eq 0 ]; then pass=$((pass+1)); printf '  ok   %s\n' "$2"; else fail=$((fail+1)); printf '  FAIL %s  ← %s\n' "$2" "$3"; fi; }

# ── 자식 두 벌 ──
# F11: 대기 감시자를 띄우고 앞에서 잔다 → Ctrl-C
cat > "$BASE/c11.sh" <<EOF
. '$SH' >/dev/null 2>&1 || exit 9
mkdir -p "\$JARVIS_HOME"
LOGIN_SAY_INTERVAL=4801; LOGIN_WAIT_TIMEOUT=99999
LOGIN_WAIT_MARK="\$JARVIS_HOME/.login-wait"; : > "\$LOGIN_WAIT_MARK"
login_waiter "\$LOGIN_WAIT_MARK" "\$JARVIS_HOME/.login-pid" &
LOGIN_WATCHER=\$!; echo "\$LOGIN_WATCHER" > '$BASE/wpid'
sleep 44
EOF
# F17: 단계 줄 하나를 쓰고 앞에서 파이프로 잔다 → 창 닫기
cat > "$BASE/c17.sh" <<EOF
. '$SH' || exit 9   # 화면을 버리지 않고 읽는다 — 실제 설치처럼 시작 때 화면 = 터미널
mkdir -p "\$JARVIS_HOME"
say "[3/10] (시험) 기다리는 중"
sleep 40 | sleep 41
EOF

cat > "$BASE/drive.py" <<'PY'
import os, pty, sys, time, signal
script, home, mode, out = sys.argv[1:5]
env = dict(os.environ, HOME=home, JARVIS_HOME=home + "/install-jarvis", JARVIS_LIB_ONLY="1", JARVIS_NO_PROGRESS="1")
# ⛔죽일 때는 이 시험이 띄운 무리만(master 규칙 2026-09-24 15:45): 무리 번호 = 우리가 띄운 자식의 번호(pty.fork = 새 세션·새 무리).
#   자식을 거둔 뒤(waitpid)엔 그 번호가 남의 무리에 다시 쓰일 수 있다 — 거두기 전이거나, 기록해 둔 우리 식구가 아직 그 무리에 있을 때만 죽인다.
reaped = False
pid, fd = pty.fork()
if pid == 0:
    os.execve("/bin/bash", ["/bin/bash", script], env)
import select
def drain(sec, until=None):                 # 화면을 비워 주며(아무도 안 읽으면 자식이 쓰기에서 멈춘다) 조건이 설 때까지 기다린다
    t_end = time.time() + sec
    while time.time() < t_end:
        if until and until():
            return True
        r, _, _ = select.select([fd], [], [], 0.2)
        if r:
            try:
                os.read(fd, 65536)
            except OSError:
                return False
    return bool(until and until())
# 고정 초 대신 「자식이 그 자리에 닿았다」는 신호를 기다린다(부하가 큰 전체 검사 안에서 3초로는 모자랐다 · 15:3x 실측)
log = home + "/install-jarvis/bootstrap.log"
if mode == "int":
    drain(30, lambda: os.path.exists(os.path.dirname(script) + "/wpid"))
elif mode == "close":
    drain(30, lambda: os.path.exists(log) and "[3/10]" in open(log, encoding="utf-8", errors="replace").read())
drain(1)
res = {}
if mode == "int":
    os.write(fd, b"\x03")
    drain(10, lambda: not os.path.exists(home + "/install-jarvis/.login-wait"))
    time.sleep(1)
    try:
        w = int(open(os.path.dirname(script) + "/wpid").read().strip())
        try:
            os.kill(w, 0); alive = True
        except ProcessLookupError:
            alive = False
        res["watcher_alive"] = alive
        if alive:
            try:
                if os.getpgid(w) == pid:        # 우리 무리의 식구일 때만(번호가 남에게 넘어갔으면 손대지 않는다)
                    os.kill(w, signal.SIGTERM)
            except ProcessLookupError:
                pass
    except Exception as e:
        res["watcher_alive"] = "unknown:" + str(e)
    res["mark_exists"] = os.path.exists(home + "/install-jarvis/.login-wait")
    os.close(fd)
elif mode == "keep":
    def exited():                           # 창을 연 채로 스스로 끝나게 둔다
        global reaped
        try:
            if os.waitpid(pid, os.WNOHANG)[0] == pid:
                reaped = True
            return reaped
        except ChildProcessError:
            reaped = True
            return True
    drain(30, exited)
    os.close(fd)
else:
    os.close(fd)                            # 창 닫기 = HUP
    for _ in range(100):                    # 끝맺음이 기록을 다 쓸 때까지(최대 20초)
        try:
            if os.waitpid(pid, os.WNOHANG)[0] == pid:
                reaped = True
                break
        except ChildProcessError:
            reaped = True
            break
        time.sleep(0.2)
def ours_in_group():                        # 기록해 둔 우리 식구(대기 감시자)가 아직 이 무리에 있는가
    try:
        w = int(open(os.path.dirname(script) + "/wpid").read().strip())
        return os.getpgid(w) == pid
    except Exception:
        return False
if not reaped or ours_in_group():
    try:
        os.killpg(pid, signal.SIGKILL)       # 이 시험이 띄운 무리뿐(위 조건으로 소유 확인)
    except Exception:
        pass
if not reaped:
    try:
        os.waitpid(pid, 0)
    except Exception:
        pass
open(out, "w").write(repr(res))
PY

echo "== F11 로그인 대기 중 Ctrl-C =="
mkdir -p "$BASE/h11"
python3 "$BASE/drive.py" "$BASE/c11.sh" "$BASE/h11" int "$BASE/r11" 2>/dev/null
r11="$(cat "$BASE/r11" 2>/dev/null)"
case "$r11" in *"'watcher_alive': False"*) true ;; *) false ;; esac; t $? "[F11 ⓐ] Ctrl-C 뒤 대기 감시자가 남지 않는다" "$r11"
case "$r11" in *"'mark_exists': False"*) true ;; *) false ;; esac; t $? "[F11 ⓑ] Ctrl-C 뒤 대기 표식(.login-wait)이 남지 않는다" "$r11"

echo "== F17 창 닫기(HUP) =="
mkdir -p "$BASE/h17"
python3 "$BASE/drive.py" "$BASE/c17.sh" "$BASE/h17" close "$BASE/r17" 2>/dev/null
LOG="$BASE/h17/install-jarvis/bootstrap.log"
if [ -s "$LOG" ]; then
  [ -f "$BASE/h17/install-jarvis/.jarvis-owned" ] || printf 'jarvis-installer-owned v1\n' > "$BASE/h17/install-jarvis/.jarvis-owned"
  bad="$(grep -v '^$' "$LOG" | grep -vE '^[0-9]{4}-[0-9]{2}-[0-9]{2}T[0-9:]{8}[+-][0-9]{4} ' | head -2)"
  [ -z "$bad" ]; t $? "[F17 ⓐ] 창을 닫아도 기록의 모든 줄이 시각으로 시작한다" "$(printf '%s' "$bad" | tr '\n' '|' | cut -c1-200)"
  grep -q ' 다음에 할 일: ' "$LOG"; t $? "[F17 ⓐ] 끝맺음 「다음에 할 일」 줄이 기록에 있다" "$(tail -2 "$LOG" | tr '\n' '|' | cut -c1-200)"
  [ "$(grep -c ' 창이 닫혀 끝났습니다' "$LOG")" = 1 ] && [ "$(tail -1 "$LOG" | grep -c ' 창이 닫혀 끝났습니다')" = 1 ]
  t $? "[F17 ⓑ] 창이 닫힌 끝 = 기록 끝에 「창이 닫혀 끝났습니다」 한 줄" "$(tail -2 "$LOG" | tr '\n' '|' | cut -c1-200)"
  st="$(HOME="$BASE/h17" JARVIS_HOME="$BASE/h17/install-jarvis" JARVIS_LIB_ONLY=1 JARVIS_NO_PROGRESS=1 \
        bash -c ". '$SH' >/dev/null 2>&1; printf '%s' \"\$PREV_RUN_STATE\" >&3" 3>&1 >/dev/null 2>&1 </dev/null)"
  [ "$st" != closed ] && [ "$st" != ended ]; t $? "[F17 ⓑ] 다음 실행은 창 닫힘을 「갑자기 닫힘」(J-AV-03)으로 읽는다" "PREV_RUN_STATE=[$st]"
else
  t 1 "[F17 ⓐ] 기록 파일이 생겼다" "없음"
fi

echo "== F17 대조군: 창이 산 채로 끝남 =="
cat > "$BASE/c17n.sh" <<EOF
. '$SH' || exit 9
mkdir -p "\$JARVIS_HOME"
say "[3/10] (시험) 곧 끝남"
exit 0
EOF
mkdir -p "$BASE/h17n"
python3 "$BASE/drive.py" "$BASE/c17n.sh" "$BASE/h17n" keep "$BASE/r17n" 2>/dev/null
LOGN="$BASE/h17n/install-jarvis/bootstrap.log"
[ -s "$LOGN" ] && [ "$(grep -c ' 창이 닫혀 끝났습니다' "$LOGN")" = 0 ] && grep -q ' 다음에 할 일: ' "$LOGN"
t $? "[F17 ⓒ] 창이 산 채로 끝나면 「창이 닫혀」 줄 0 · 끝맺음 줄 있음" "$(tail -2 "$LOGN" 2>/dev/null | tr '\n' '|' | cut -c1-200)"
printf 'jarvis-installer-owned v1\n' > "$BASE/h17n/install-jarvis/.jarvis-owned" 2>/dev/null
st="$(HOME="$BASE/h17n" JARVIS_HOME="$BASE/h17n/install-jarvis" JARVIS_LIB_ONLY=1 JARVIS_NO_PROGRESS=1 \
      bash -c ". '$SH' >/dev/null 2>&1; printf '%s' \"\$PREV_RUN_STATE\" >&3" 3>&1 >/dev/null 2>&1 </dev/null)"
[ "$st" = closed ]; t $? "[F17 ⓒ] 다음 실행이 「끝맺음까지 갔다」로 읽는다" "PREV_RUN_STATE=[$st]"

echo "== 합계: ok $pass · FAIL $fail =="
[ "$fail" -eq 0 ]
