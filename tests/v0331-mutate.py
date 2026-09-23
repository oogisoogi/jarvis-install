#!/usr/bin/env python3
# 뮤턴트 — 0.3.31(rotate 관측 판정 · 드레인 보호 · 상한 180)의 검사가 **대상을 실제로 때리는가** (TICKET=installer-0331)
#
# ★쓰는 법
#   python3 tests/v0331-mutate.py --root <저장소>           전건(사본에서만 고친다 · 실물 무접촉)
#   python3 tests/v0331-mutate.py --root <저장소> --audit   앵커가 아직 1곳씩 걸리는가만
#
# ★판정 = 기준선(변이 없음)에서 **초록**이던 축이, 변이를 넣은 사본에서 **붉어졌는가**(v0328-mutate 와 같은 규율).
# ★변이가 사본에 실제로 들어갔는지(바뀐 바이트가 있는지) 확인한 뒤에만 잰다.
# ★러너 두 가지 — "checks" = `CHECKS_ONLY=0331 bash install-master/checks.sh`(글자·순서 축) ·
#   "emu" = `bash tests/v0331-emu-run.sh`(동작 축 — 분류·이동·기입을 실제로 부른다). 글자 축은 동작 변이를 못 보므로 둘을 가른다.
# ⚠판정은 러너 출력의 「  FAIL 」 줄에 기대 축 이름이 있는가로 한다(러너의 rc 가 아니라).
import argparse, os, pathlib, shutil, subprocess, sys, tempfile

for _s in (sys.stdout, sys.stderr):
    try: _s.reconfigure(encoding="utf-8", errors="backslashreplace")
    except Exception: pass

PS = "install-master/bootstrap.ps1"
SH = "install-master/bootstrap.sh"

# (이름, 파일, 찾을 것, 바꿀 것, 붉어져야 할 축 조각, 러너)
MUTANTS = [
    # ① 드레인 보호를 빼면 저장 도중에 관측하고(성공처럼 보이면) rotate 를 끊는다.
    ("win-drain-guard-drop", PS,
     "-and $stage -and $stage -ne '1-drain') {",
     "-and $stage) {",
     "[윈 D] 드레인 중 관측 0회", "emu"),
    ("mac-drain-guard-drop", SH,
     "        ''|1-drain) ;;",
     "        '') ;;",
     "[맥 D] 드레인 중 관측 0회", "emu"),
    # ② 주기 관측의 성공 판정을 끄면 09-21 18:57 처럼 상한까지 기다린다.
    ("mac-periodic-observe-drop", SH,
     '           if [ "$v" = ok ]; then',
     '           if false; then',
     "[맥 B] 상한(12s) 전에 끝난다", "emu"),
    ("win-periodic-observe-drop", PS,
     "                if ((Invoke-RotateObserve $Cli $basePid $baseRefs $obsAt $false) -eq 'ok') {",
     "                if ($false) {",
     "[윈 B] 드레인 뒤 단계에서 끊는다", "emu"),
    # ③ 상한 뒤 마지막 관측을 빼면 결과가 성공인데 [재시작] 폴백 안내가 나간다.
    ("mac-final-reobserve-drop", SH,
     "         if [ \"$v\" = ok ]; then printf 'observed-ok",
     "         if false; then printf 'observed-ok",
     "[맥 E] 상한 → 마지막 관측 성공 → observed-ok(폴백 안내 없음)", "emu"),
    ("win-final-reobserve-drop", PS,
     "            if ((Invoke-RotateObserve $Cli $basePid $baseRefs ([int]$sw.Elapsed.TotalSeconds) $true) -eq 'ok') {",
     "            if ($false) {",
     "[윈 E] 상한 → 마지막 관측 성공 → observed-ok(폴백 안내 없음)", "emu"),
    # ④ 판정 조건 — 역할 자리 3 · 기준선 자리 사라짐 · pid 바뀜
    ("win-verdict-role-count", PS,
     "if (@(Get-RotateRoleRefs $ListText).Count -lt 3)",
     "if (@(Get-RotateRoleRefs $ListText).Count -lt 1)",
     "[동형] 윈 Get-RotateObserveVerdict 가 글자까지 같다", "emu"),
    ("mac-verdict-old-seats-drop", SH,
     '    case " $3 " in *" $r "*) echo no:old-seats; return 0 ;; esac',
     '    :',
     "[맥] rotate_observe_verdict 여덟 입력", "emu"),
    ("mac-verdict-pid-same", SH,
     '  [ "$1" != "$2" ] || { echo no:pid; return 0; }',
     '  :',
     "[맥] rotate_observe_verdict 여덟 입력", "emu"),
    # ⑥ 판정 C — 드레인 도중 상한 연장을 빼면 드레인이 끊기고 폴백 안내가 나간다.
    ("mac-drain-extension-drop", SH,
     '      if [ "$stage" = 1-drain ] && [ "$el" -lt "$ROTATE_DRAIN_HARD_SEC" ]; then',
     '      if false; then',
     "[맥 F] 드레인이 상한을 넘겨도 끊지 않고 · 끝난 뒤 관측 성공 → observed-ok", "emu"),
    ("win-drain-extension-drop", PS,
     "                if ($stage -eq '1-drain' -and $sw.ElapsedMilliseconds -lt $RotateDrainHardMs) {",
     "                if ($false) {",
     "[윈 F] 드레인이 상한을 넘겨도 끊지 않고 · 끝난 뒤 관측 성공 → observed-ok", "emu"),
    ("mac-left-running-killed", SH,
     '          left=1; log "rotate left running',
     '          kill "$rp"; left=1; log "rotate left running',
     "[맥 G] 데몬 교체 단계의 rotate 를 끊지 않는다(rotate 프로세스가 살아 있다)", "emu"),
    ("win-left-running-killed", PS,
     "                    Write-Log ('rotate left running at stage '",
     "                    try { $p.Kill() } catch { }; Write-Log ('rotate left running at stage '",
     "[윈 G] 데몬 교체 단계의 rotate 를 끊지 않는다(rotate 프로세스가 살아 있다)", "emu"),
    # ⑤ 성공 갈래 — observed-ok 가 폴백 안내로 떨어지면 안 된다.
    ("win-success-branch-drop", PS,
     " -or $rotateState -eq 'observed-ok' -or",
     " -or",
     "[0331 성공 갈래] 윈: 같음", "checks"),
]


def copy_tree(root, dst):
    for d in ("install-master", "tests"):
        shutil.copytree(root / d, dst / d, symlinks=True)


def run(tree, runner="checks"):
    env = dict(os.environ); env["CHECKS_ONLY"] = "0331"
    cmd = ["bash", "install-master/checks.sh"] if runner == "checks" else ["bash", "tests/v0331-emu-run.sh"]
    r = subprocess.run(cmd, cwd=tree, env=env,
                       capture_output=True, text=True, stdin=subprocess.DEVNULL)
    return r.returncode, [l for l in r.stdout.split("\n") if l.startswith("  FAIL")], r.stdout + r.stderr


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--root", required=True)
    ap.add_argument("--audit", action="store_true")
    ap.add_argument("--only", default="", help="쉼표로 가른 뮤턴트 이름만(기준선은 그대로 잰다)")
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
    base_tmp = pathlib.Path(tempfile.mkdtemp(prefix="v0331-mut-base-"))
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
    only = set(x for x in a.only.split(",") if x)
    for name, rel, old, new, axis, runner in MUTANTS:
        if only and name not in only: continue
        tmp = pathlib.Path(tempfile.mkdtemp(prefix="v0331-mut-"))
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
