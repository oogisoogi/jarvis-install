#!/usr/bin/env python3
# 뮤턴트 — 0.3.30(데몬 선확인 · rotate 생략 판정 · rotate 경과 기록)의 검사가 **대상을 실제로 때리는가** (TICKET=installer-0330)
#
# ★쓰는 법
#   python3 tests/v0330-mutate.py --root <저장소>           전건(사본에서만 고친다 · 실물 무접촉)
#   python3 tests/v0330-mutate.py --root <저장소> --audit   앵커가 아직 1곳씩 걸리는가만
#
# ★판정 = 기준선(변이 없음)에서 **초록**이던 축이, 변이를 넣은 사본에서 **붉어졌는가**(v0328-mutate 와 같은 규율).
# ★변이가 사본에 실제로 들어갔는지(바뀐 바이트가 있는지) 확인한 뒤에만 잰다.
# ★러너 두 가지 — "checks" = `CHECKS_ONLY=0330 bash install-master/checks.sh`(글자·순서 축) ·
#   "emu" = `bash tests/v0330-emu-run.sh`(동작 축 — 분류·이동·기입을 실제로 부른다). 글자 축은 동작 변이를 못 보므로 둘을 가른다.
# ⚠판정은 러너 출력의 「  FAIL 」 줄에 기대 축 이름이 있는가로 한다(러너의 rc 가 아니라).
import argparse, os, pathlib, shutil, subprocess, sys, tempfile

for _s in (sys.stdout, sys.stderr):
    try: _s.reconfigure(encoding="utf-8", errors="backslashreplace")
    except Exception: pass

PS = "install-master/bootstrap.ps1"
SH = "install-master/bootstrap.sh"

# (이름, 파일, 찾을 것, 바꿀 것, 붉어져야 할 축 조각, 러너)
MUTANTS = [
    # ① 선확인을 없애면 살아 있는 데몬에 등록을 다시 걸어 재기동시킨다(09-21 18:18 윈 실기 · pid 14888→22660).
    ("win-precheck-drop", PS,
     "    if ($prePong -and $preState -eq 'yes') {",
     "    if ($false) {",
     "[윈 A] daemon install 을 부르지 않는다", "emu"),
    # ② pid 가 바뀐 것을 못 보면 방금 되살아난 자리 위에서 rotate 를 또 부른다(18:19~18:25 실기).
    ("win-plan-pid-ignored", PS,
     "    if ([int64]$PrePid -ne [int64]$PostPid) { return 'skip:pid' }",
     "    if ($false) { return 'skip:pid' }",
     "[윈 B] 답함·등록 no·등록이 재기동 → skip:pid", "emu"),
    # ② 맥 판정이 윈과 갈리면 텔레메트리 rotate= 가 두 OS 에서 다른 뜻이 된다.
    ("mac-plan-fresh-misclass", SH,
     "  [ \"$1\" = 1 ] || { echo skip:fresh; return 0; }",
     "  [ \"$1\" = 1 ] || { echo run:unknown; return 0; }",
     "[동형] 맥 rotate_plan 이 글자까지 같다", "emu"),
    # ② 생략 관문을 없애면 판정은 남아도 rotate 가 불린다.
    ("win-skip-gate-drop", PS,
     "            if ($script:RotatePlan -like 'skip:*') {",
     "            if ($false) {",
     "[0330 생략] 윈: 이미 새 데몬이면 rotate 를 부르지 않는다", "checks"),
    # ③ 단계 기록을 빼면 18:25 실기처럼 어느 단계에서 멈췄는지 로그로 못 가른다.
    ("win-stage-log-drop", PS,
     "                if ($st -and $st -ne $stage) {",
     "                if ($false) {",
     "[윈 R] 단계 1-drain·5-restore 가 경과초와 함께 남는다", "emu"),
    ("win-stopped-at-drop", PS,
     "            Write-Log ('rotate stopped at: ' + $where",
     "            Write-Log ('rotate halted: ' + $where",
     "[윈 H] 멈춘 단계 한 줄(1-drain)", "emu"),
    ("mac-stopped-at-drop", SH,
     '    if [ -n "$stage" ]; then log "rotate stopped at: $stage',
     '    if [ -n "$stage" ]; then log "rotate halted: $stage',
     "[맥 H] 멈춘 단계 한 줄(1-drain)", "emu"),
    ("mac-pid-parse-broken", SH,
     'sed -n \'s/.*"daemon_pid"[[:space:]]*:',
     'sed -n \'s/.*"daemon_pidx"[[:space:]]*:',
     "[맥] daemon_pid_of 가 identify 의 daemon_pid 를 읽는다", "emu"),
]


def copy_tree(root, dst):
    for d in ("install-master", "tests"):
        shutil.copytree(root / d, dst / d, symlinks=True)


def run(tree, runner="checks"):
    env = dict(os.environ); env["CHECKS_ONLY"] = "0330"
    cmd = ["bash", "install-master/checks.sh"] if runner == "checks" else ["bash", "tests/v0330-emu-run.sh"]
    r = subprocess.run(cmd, cwd=tree, env=env,
                       capture_output=True, text=True, stdin=subprocess.DEVNULL)
    return r.returncode, [l for l in r.stdout.split("\n") if l.startswith("  FAIL")], r.stdout + r.stderr


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--root", required=True)
    ap.add_argument("--audit", action="store_true")
    a = ap.parse_args()
    root = pathlib.Path(a.root).expanduser().resolve()
    broken = 0
    for name, rel, old, new, axis, runner in MUTANTS:
        n = (root / rel).read_text(encoding="utf-8-sig").count(old)
        if n != 1:
            print("앵커 %d곳 ✗ %-30s %s" % (n, name, rel)); broken += 1
    if broken:
        print("::error::앵커가 1곳이 아닌 뮤턴트 %d개 — 뮤턴트가 낡았다" % broken); return 3
    if a.audit:
        print("앵커 전건 1곳 — 뮤턴트 %d개 대조 가능" % len(MUTANTS)); return 0
    base_tmp = pathlib.Path(tempfile.mkdtemp(prefix="v0330-mut-base-"))
    try:
        copy_tree(root, base_tmp)
        brc, base, bout = run(base_tmp, "checks")
        erc, ebase, eout = run(base_tmp, "emu")
    finally:
        shutil.rmtree(base_tmp, ignore_errors=True)
    if brc != 0 or erc != 0:
        print("잴 수 없음 — 기준선 러너 rc %d · 흉내 rc %d (전건 통과가 아니다)" % (brc, erc))
        print((bout + eout)[-800:]); return 2
    print("기준선 — 러너 rc 0 · 흉내 rc 0 · 적색 %d줄" % (len(base) + len(ebase)))
    bad = 0
    for name, rel, old, new, axis, runner in MUTANTS:
        tmp = pathlib.Path(tempfile.mkdtemp(prefix="v0330-mut-"))
        try:
            copy_tree(root, tmp)
            p = tmp / rel
            raw = p.read_bytes()
            bom = raw[:3] == b"\xef\xbb\xbf"
            text = raw.decode("utf-8-sig")
            mutated = text.replace(old, new, 1)
            if mutated == text:
                print("미적용 %-30s ← 변이가 들어가지 않았다" % name); bad += 1; continue
            p.write_bytes((b"\xef\xbb\xbf" if bom else b"") + mutated.encode("utf-8"))
            if p.read_bytes() == raw:
                print("미적용 %-30s ← 쓴 뒤에도 바이트가 같다" % name); bad += 1; continue
            _, reds, _ = run(tmp, runner)
            if any(axis in l for l in reds):
                print("붉음  %-30s ← [%s] %s" % (name, runner, axis))
            else:
                print("눈멂  %-30s ← [%s] 안 붉어진 축: %s (그때 붉은 줄 %d)" % (name, runner, axis, len(reds))); bad += 1
                for l in reds[:3]:
                    print("        " + l.strip())
        finally:
            shutil.rmtree(tmp, ignore_errors=True)
    print("\n뮤턴트 %d개 · 실패(눈멂·미적용) %d개" % (len(MUTANTS), bad))
    return 1 if bad else 0


sys.exit(main())
