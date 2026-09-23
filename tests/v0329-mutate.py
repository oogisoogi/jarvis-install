#!/usr/bin/env python3
# 뮤턴트 — 0.3.29(재설치 텔레메트리 · 자동 재시작 · 손 횟수 · 옛 라운드)의 검사가 **대상을 실제로 때리는가** (TICKET=installer-0329)
#
# ★쓰는 법
#   python3 tests/v0329-mutate.py --root <저장소>           전건(사본에서만 고친다 · 실물 무접촉)
#   python3 tests/v0329-mutate.py --root <저장소> --audit   앵커가 아직 1곳씩 걸리는가만
#
# ★판정 = 기준선(변이 없음)에서 **초록**이던 축이, 변이를 넣은 사본에서 **붉어졌는가**(v0328-mutate 와 같은 규율).
# ★변이가 사본에 실제로 들어갔는지(바뀐 바이트가 있는지) 확인한 뒤에만 잰다.
# ★러너 두 가지 — "checks" = `CHECKS_ONLY=0329 bash install-master/checks.sh`(글자·순서 축) ·
#   "emu" = `bash tests/v0329-emu-run.sh`(동작 축 — 분류·이동·기입을 실제로 부른다). 글자 축은 동작 변이를 못 보므로 둘을 가른다.
# ⚠판정은 러너 출력의 「  FAIL 」 줄에 기대 축 이름이 있는가로 한다(러너의 rc 가 아니라).
import argparse, os, pathlib, shutil, subprocess, sys, tempfile

for _s in (sys.stdout, sys.stderr):
    try: _s.reconfigure(encoding="utf-8", errors="backslashreplace")
    except Exception: pass

PS = "install-master/bootstrap.ps1"
SH = "install-master/bootstrap.sh"

# (이름, 파일, 찾을 것, 바꿀 것, 붉어져야 할 축 조각, 러너)
MUTANTS = [
    # ② 등록 전 물음을 없애면 「error: 데몬이 이미 가동 중」이 다시 오류로 계상된다(09-21 맥 VM 재설치 실기).
    ("mac-daemon-precheck-drop", SH,
     '  if "$cli" ping 2>/dev/null | grep -q pong; then\n',
     '  if false; then\n',
     "[0329 전송] 맥: 등록 전에 데몬이 이미 도는지 묻는다", "checks"),
    # ② 재설치 끝의 post-install 증거를 빼면 서버가 「끝까지 갔다」를 모른다.
    ("win-reinstall-evidence-drop", PS,
     "            Send-PostInstallEvidence $cli (Get-MasterSeatRef $cli) 'reinstall'\n",
     "",
     "[0329 전송] 윈: 재설치 끝에도 post-install 증거를 보낸다", "checks"),
    ("mac-reinstall-evidence-drop", SH,
     '      post_install_evidence "$cli" "$(master_seat_ref "$cli")" reinstall\n',
     "",
     "[0329 전송] 맥: 같은 증거를 보낸다", "checks"),
    # ③ rotate 를 안 부르면 사람에게 [재시작] 을 누르게 하는 앞 판으로 돌아간다.
    ("win-rotate-call-drop", PS,
     "            $rotateParts = @((Get-CysRotateState $cli) -split \"`t\", 3)",
     "            $rotateParts = @('absent')",
     "[0329 재시작] 윈: 재설치 끝에 cys rotate 를 부른다", "checks"),
    # ③ 분류가 틀리면 옛 cys 가 「실패」로 계상되거나 성공이 폴백으로 떨어진다(동작 축 — 글자 축은 못 본다).
    ("mac-rotate-absent-misclass", SH,
     "    *\"unrecognized subcommand\"*|*\"unexpected argument\"*|*\"invalid subcommand\"*) printf 'absent\\t%s\\t%s\\n' \"$rc\" \"$note\"; return 0 ;;\n",
     "",
     "[맥 r2] 옛 cys(모르는 하위명령) → absent", "emu"),
    ("win-rotate-ok-misclass", PS,
     "        if ($rc -eq 0 -or $rc -eq 21) { return (\"ok`t\" + $rc + \"`t\" + $note) }",
     "        if ($rc -eq 99 -or $rc -eq 21) { return (\"ok`t\" + $rc + \"`t\" + $note) }",
     "[윈 r1] cys rotate 성공 → ok", "emu"),
    # ④ 빈칸으로 되돌리면 자리의 master 가 다시 「세지 못했다」로 보고한다(윈 실기 09-21 14:2x).
    ("win-hands-blank-revert", PS,
     '    [void]$lines.Add("- 사람 손 (실제로 누른 횟수): **$($script:HumanHands)번** — 설치 창 [9/10] 에 나온 수와 같습니다.")',
     "    [void]$lines.Add('- 사람 손 (실제로 누른 횟수): ____번  ← **직접 적어 주십시오.**')",
     "[윈 ⓓ] 환경 보고의 실제 손 칸 = 화면 계수(2번)", "emu"),
    # ⑤ 옮기기 대신 지우면 되돌릴 길이 사라진다(판정 = 삭제 금지).
    ("mac-archive-rm", SH,
     '    if mv "$e" "$dst/" 2>/dev/null; then',
     '    if rm -rf "$e" 2>/dev/null; then',
     "[맥 ⓒ] 옛 라운드 전부(숨은 파일·하위 폴더 포함)가 archive/<시각>/ 로 갔다", "emu"),
    # ⑤ 숨은 파일을 빠뜨리면 옛 라운드가 일부 남는다(-Force 없으면 점 파일이 안 보인다).
    ("win-archive-skip-hidden", PS,
     "Get-ChildItem -LiteralPath $r -Force -ErrorAction Stop",
     "Get-ChildItem -LiteralPath $r -ErrorAction Stop",
     "[윈 ⓒ] _round 에는 archive 만 남고", "emu"),
    # ②/③ 끝난 master 를 세면 증거가 죽은 자리의 화면을 읽는다.
    ("mac-master-seat-exited-counted", SH,
     ' && $4!="exited=true" {print $1; exit}',
     ' {print $1; exit}',
     "[맥 m1] 살아 있는 master 자리를 찾는다", "emu"),
    # ③ 출력을 명령 치환 파이프로 되돌리면 rotate 가 남긴 새 데몬이 파이프를 쥐어 설치 창이 멈춘다(이종 검토 1R 지적 M).
    ("mac-rotate-pipe-capture", SH,
     # v0.3.30: 받는 자리가 「뒤로 돌려 파일을 들여다보기」로 바뀌어 앵커를 다시 겨눴다(TICKET=installer-0330) — 변이의 뜻은 같다(명령 치환 파이프로 되돌림).
     # v0.3.31: 상한을 고리가 지게 되어 perl alarm 감싸기가 빠졌다 — 앵커를 다시 겨눴다(TICKET=installer-0331 · 변이의 뜻 동일).
     # v0.3.32: 호출 줄에 부서 순회 생략(env·인자)이 붙어 앵커를 다시 겨눴다(TICKET=installer-0332 · 변이의 뜻 동일).
     '  CYS_ROTATE_SKIP_DEPTS=1 "${1:-cys}" rotate --timeout "$ROTATE_DRAIN_TIMEOUT_SEC" $skip_flag >"$tf" 2>"$te" </dev/null &\n  rp=$!\n',
     '  out="$(perl -e \'alarm shift; exec @ARGV or exit 126\' "$ROTATE_WALL_CAP_SEC" "${1:-cys}" rotate --timeout "$ROTATE_DRAIN_TIMEOUT_SEC" 2>&1)"; printf \'%s\\n\' "$out" > "$tf"\n  rp=999999\n',
     "[맥 r5] rotate 가 자식(새 데몬)을 남겨도 설치 창이 기다리지 않는다", "emu"),
    # ⑥ cys 1.1.2 rotate 종료코드 표(TICKET=v112-vm-verify) — 21(저장 일부 미확인)을 실패로 읽으면
    #   끝까지 돈 재시작에 사람에게 [재시작] 을 또 누르게 한다(설계 반대).
    ("mac-rotate-rc21-as-fail", SH,
     "    0|21) printf 'ok\\t%s\\t%s\\n' \"$rc\" \"$note\"; return 0 ;;\n",
     "    0) printf 'ok\\t%s\\t%s\\n' \"$rc\" \"$note\"; return 0 ;;\n",
     "[맥 x21] rc 21(저장 일부 미확인) → ok", "emu"),
    #   25(복원 보류)를 held 로 못 가르면 새 데몬이 이미 섰는데 [재시작] 을 되풀이시킨다(같은 자리에서 또 멈춘다).
    ("win-rotate-rc25-drop", PS,
     "        if ($rc -eq 25) { return (\"held`t\" + $rc + \"`t\" + $note) }",
     "        if ($rc -eq 99) { return (\"held`t\" + $rc + \"`t\" + $note) }",
     "[윈 x25] rc 25(복원 보류) → held", "emu"),
]


def copy_tree(root, dst):
    for d in ("install-master", "tests"):
        shutil.copytree(root / d, dst / d, symlinks=True)


def run(tree, runner="checks"):
    env = dict(os.environ); env["CHECKS_ONLY"] = "0329"
    cmd = ["bash", "install-master/checks.sh"] if runner == "checks" else ["bash", "tests/v0329-emu-run.sh"]
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
    base_tmp = pathlib.Path(tempfile.mkdtemp(prefix="v0329-mut-base-"))
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
        tmp = pathlib.Path(tempfile.mkdtemp(prefix="v0329-mut-"))
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
