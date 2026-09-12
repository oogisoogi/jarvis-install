#!/usr/bin/env python3
"""배포 한 줄이 우리말·공백이 든 사용자 폴더에서도 한 덩어리로 넘어가는가.

★경로 문제는 「보통 이름」에서는 절대 안 보인다. 우리 참가자의 사용자 폴더 이름은
  대개 우리말이고 공백이 섞이기도 한다(C:\\Users\\노 현욱). 그 이름에서만 깨지는 결함은
  실기 당일에 처음 드러나고, 그때는 「설치가 안 된다」로 읽힌다.
무엇을 하나
  맥  = 문서에 적힌 한 줄을 **진짜 셸로 실행**한다(주소만 로컬 파일로 바꾼다).
  윈  = 이 기계에 PowerShell 이 없으므로 한 줄에서 자리 식을 꺼내 **같은 값으로 계산**한다
        (문자열 이어 붙이기라 계산이 곧 실행과 같다) + 두 자리(받는 곳·실행하는 곳)가 같은지 본다.
쓰는 법: python3 tests/oneliner-path-parity.py
"""
from __future__ import annotations

import io
import os
import re
import shutil
import subprocess
import tempfile

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
SH = os.path.join(ROOT, "install-master", "bootstrap.sh")
PS = os.path.join(ROOT, "install-master", "bootstrap.ps1")

# 일부러 고약한 이름 — 우리말 + 공백 + 붙임표
HARD_NAME = "노 현욱-테스트"
WIN_PROFILE = "C:\\Users\\" + HARD_NAME

ok = True


def say(good: bool, msg: str) -> None:
    global ok
    print(("ok   " if good else "FAIL ") + msg)
    if not good:
        ok = False


def mac_line() -> str:
    src = io.open(SH, encoding="utf-8").read()
    m = re.search(r'^#\s+(curl -fsSL \S+ -o "\$HOME/[^"]+" && bash "\$HOME/[^"]+")\s*$', src, re.M)
    if not m:
        raise SystemExit("bootstrap.sh 머리에서 배포 한 줄을 못 찾았다 — 이 시험은 무효다")
    return m.group(1)


def check_mac() -> None:
    line = mac_line()
    base = tempfile.mkdtemp()
    home = os.path.join(base, HARD_NAME)
    os.makedirs(home)
    # ★내려받을 원본은 **공백 없는 자리**에 둔다. 진짜 주소에는 공백이 없는데,
    #   시험용 주소에 공백을 넣으면 그 공백 때문에 셸이 인자를 쪼개고,
    #   그 쪼개짐을 「제품이 우리말 경로에서 깨진다」로 잘못 읽게 된다(실제로 한 번 그랬다).
    #   재는 대상은 **받는 자리**($HOME)이지 주는 자리가 아니다.
    payload = os.path.join(base, "payload.sh")
    io.open(payload, "w", encoding="utf-8").write('printf "%s\\n" "돌았다"\n')
    assert " " not in payload, "시험용 원본 자리에 공백이 있으면 이 시험은 무효다"
    # 주소만 로컬 파일로 바꾼다. 자리를 만드는 부분은 문서의 글자 그대로 둔다.
    runnable = re.sub(r'https://\S+', "file://" + payload, line)
    env = dict(os.environ, HOME=home)
    r = subprocess.run(["bash", "-c", runnable], capture_output=True, text=True, env=env)
    say(r.returncode == 0, f"맥 한 줄이 우리말·공백 폴더에서 rc 0 (실제 {r.returncode})")
    say("돌았다" in r.stdout, "맥 한 줄이 받아 놓은 파일을 실제로 실행했다")
    landed = os.path.join(home, "install-jarvis.sh")
    say(os.path.isfile(landed), f"받은 파일이 사용자 폴더 안에 놓였다 ({HARD_NAME}/install-jarvis.sh)")
    say("/tmp/" not in line, "맥 한 줄이 더는 임시 폴더를 쓰지 않는다")
    shutil.rmtree(base, ignore_errors=True)


def win_exprs() -> list[str]:
    src = io.open(PS, encoding="utf-8-sig").read()
    m = re.search(r'^#\s+(powershell -NoProfile[^\n]*)$', src, re.M)
    if not m:
        raise SystemExit("bootstrap.ps1 머리에서 배포 한 줄을 못 찾았다 — 이 시험은 무효다")
    line = m.group(1)
    exprs = re.findall(r'\(\[Environment\]::GetFolderPath\(\'UserProfile\'\)\+\'([^\']*)\'\)', line)
    return line, exprs


def check_win() -> None:
    line, exprs = win_exprs()
    say(len(exprs) == 2, f"윈 한 줄에 자리 식이 둘이다(받는 곳·실행하는 곳) — 실제 {len(exprs)}")
    say(len(set(exprs)) == 1, "그 둘이 글자 그대로 같다(받은 곳과 다른 곳을 실행하지 않는다)")
    if exprs:
        made = WIN_PROFILE + exprs[0]
        print("     계산된 자리:", made)
        say(made == WIN_PROFILE + "\\install-jarvis.ps1", "우리말·공백 이름에서도 자리가 사용자 폴더 바로 아래다")
    say("$" not in line, "윈 한 줄에 $ 가 없다(어느 창에서 붙여넣어도 같다)")
    say("%" not in line, "윈 한 줄에 % 가 없다(cmd 가 바꿔 버릴 자리가 없다)")
    say("GetTempPath" not in line, "윈 한 줄이 더는 임시 폴더를 쓰지 않는다")
    say(line.count("-ExecutionPolicy Bypass") >= 2, "바깥과 안쪽 둘 다 실행 정책을 넘긴다")


def main() -> int:
    print("== 맥 ==")
    check_mac()
    print("== 윈 (정적 계산 · 이 기계에 PowerShell 이 없다) ==")
    check_win()
    return 0 if ok else 1


if __name__ == "__main__":
    raise SystemExit(main())
