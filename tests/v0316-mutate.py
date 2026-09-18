#!/usr/bin/env python3
# 뮤턴트 — v0.3.16(2026-09-14 워크숍 교훈) 수정이 「실제로 서 있는가」를 재는 도구
#
# ★쓰는 법
#   python3 tests/v0316-mutate.py --root <저장소>           전건(사본에서만 고친다 · 실물 무접촉)
#   python3 tests/v0316-mutate.py --root <저장소> --audit   앵커가 아직 1곳씩 걸리는가만
#
# ★판정 = 기준선(변이 없음)에서 **초록**이던 축이, 변이를 넣은 사본에서 **붉어졌는가**.
#   기준선에서 이미 붉은 축을 기대로 쓰면 「공짜 적색」이라 아무것도 증명하지 않는다 — 그런 뮤턴트는 실격으로 센다.
# ★앵커가 1곳이 아니면 조용히 지나가지 않는다(rc 3) — 「안 망가뜨린 것」과 「망가뜨렸는데 안 붉어진 것」은 다르다.
# ⚠checks 러너 뮤턴트는 흉내 실행 축을 끄고(V0316_EMU_SKIP=1) 돈다 — 흉내 축은 emu 러너 뮤턴트가 따로 잰다.
import argparse, os, pathlib, shutil, subprocess, sys, tempfile

for _s in (sys.stdout, sys.stderr):
    try: _s.reconfigure(encoding="utf-8", errors="backslashreplace")
    except Exception: pass

PS = "install-master/bootstrap.ps1"
RS = "install-master/reset-clean.ps1"
SH = "install-master/bootstrap.sh"
# (이름, 파일, 찾을 것, 바꿀 것, 붉어져야 할 축 조각, 러너)
MUTANTS = [
    ("diag-drop", PS, "        $tree = @(Write-ClaudeInstallDiag $p '공식 설치기')\n", "        $tree = @()\n",
     "[v0316] 설치 상한에 닿으면 진단을 먼저 적고 설치기를 끈다", "checks"),
    ("hash-skip", PS, "        if ($got -cne $sum) {\n", "        if ($false) {\n",
     "[v0316] 직접 받은 파일은 해시 대조 뒤에만 실행한다", "checks"),
    ("url-swap", PS, "$ClaudeDirectBaseUrl       = 'https://downloads.claude.ai/claude-code-releases'", "$ClaudeDirectBaseUrl       = 'https://example.invalid/claude'",
     "[v0316] 받는 자리는 공식 설치기와 같은 주소", "checks"),
    ("step5-skip", PS, "            if (Wait-ProcBounded $ip $ClaudeDirectInstallWaitMs '받은 파일로 설치하는 중입니다') {\n", "            if ($false) {\n",
     "[v0316] 받은 파일로 공식 설치를 3분 상한으로 먼저 해 본다", "checks"),
    ("retry-cap-off", PS, "    $waitCap = if ($prevHold -ge 1) { $ClaudeInstallRetryWaitMs } else { $ClaudeInstallWaitMs }\n", "    $waitCap = $ClaudeInstallWaitMs\n",
     "[v0316] 같은 자리 2회째부터 설치 상한 5분", "checks"),
    ("round-back", PS, "$mm = [int][math]::Floor($waitedMs / 60000)", "$mm = [int]($waitedMs / 60000)",
     "[v0316] 대기 시간 표시는 버림으로 센다", "checks"),
    ("card-late", PS, "    Say '[3/10] 지금 로그인 화면을 엽니다. 브라우저가 나타나면 승인을 눌러 주십시오.'\n    foreach ($ln in $LoginCardLines) { Say $ln }\n",
     "    Say '[3/10] 지금 로그인 화면을 엽니다. 브라우저가 나타나면 승인을 눌러 주십시오.'\n",
     "[v0316] 로그인 화면을 열기 전에 카드를 보여 준다", "checks"),
    ("reopen-endless", PS, "                    $reopened = $true\n", "",
     "[v0316] 코드 실패 뒤 다시 열기는 한 번뿐", "checks"),
    ("jcode-stays", PS, "                    $script:JCode = ''\n", "",
     "[v0316] J-LOGIN-02 는 끝의 코드로 남지 않는다", "checks"),
    ("login-timeout-silent", PS, "Write-Log ('login wait timeout ' + [int]($LoginWaitTimeout / 60) + 'min: CloseMainWindow')", "[void]('login wait timeout ' + [int]($LoginWaitTimeout / 60) + 'min: CloseMainWindow')",
     "[v0316] 로그인 대기 상한 도달을 기록 파일에 적는다", "checks"),
    ("prevrun-jav03", PS, "    if (($script:PrevRunState -eq 'answer') -or ($script:PrevRunState -eq 'wait')) {\n", "    if ($false) {\n",
     "[v0316] 원격 해결 대기 중 닫힌 실행에는 J-AV-03 을 붙이지 않는다", "checks"),
    ("tail-uncut", PS, '    Say "       $tail"\n', '    Say "       $script:PrevTail"\n',
     "[v0316] 지난 실행 마지막 줄은 120자에서 자른다", "checks"),
    ("reset-no-stop", RS, "    if (Test-Path $ClaudeExe) { $claudeAlive = @(Stop-ClaudeUnderBin) }\n", "    $claudeAlive = @()\n",
     "[v0316] 지우기는 클로드 실행 파일을 지우기 직전에 그 자리의 클로드를 끈다", "checks"),
    ("mac-card-drop", SH, '  say "     2) 「Authentication code」 화면에서 복사 단추로 코드만 복사하십시오 (주소창의 주소는 안 됩니다)."\n', "",
     "[v0316] 맥 로그인 카드 세 가지", "checks"),
    # 「없다」를 재는 축도 되돌려 봐야 눈멂이 갈린다 — 지우기에만 둔 끄기를 첫 설치에 넣는다.
    ("first-install-stop", PS, "        Stop-ProcTree $p $tree\n", "        Stop-ProcTree $p $tree\n        $null = @(Stop-ClaudeUnderBin)\n",
     "[v0316] 첫 설치에는 클로드를 끄는 자리가 없다", "checks"),
    # 흉내 러너 — 정적 축이 못 보는 「실제로 부르면 그렇게 되는가」
    ("emu-place-skip", PS, "                    Move-Item -LiteralPath $tmp -Destination $exe -Force -ErrorAction Stop\n", "",
     "[hang5] 받은 파일을 제자리에 둔다", "emu"),
    ("emu-reopen-endless", PS, "                    $reopened = $true\n", "",
     "[reopen-fail] 다시 열어도 안 되면 한 번으로 닫히고 J-LOGIN-01", "emu"),
    ("emu-kill-child", PS, "    foreach ($t in @(@($tree) | Sort-Object Depth -Descending)) {\n        try { Stop-Process -Id $t.Id -Force -ErrorAction Stop } catch { }\n    }\n", "",
     "[hang5] 끈 설치기의 자식이 남지 않는다", "emu"),
]


def copy_tree(root, dst):
    for d in ("install-master", "tests", "docs"):
        shutil.copytree(root / d, dst / d, symlinks=True)


def run(runner, tree):
    env = dict(os.environ)
    if runner == "checks":
        env["V0316_EMU_SKIP"] = "1"
        r = subprocess.run(["bash", "install-master/checks.sh"], cwd=tree, env=env, capture_output=True, text=True)
    else:
        r = subprocess.run(["bash", "tests/v0316-emu-run.sh"], cwd=tree, env=env, capture_output=True, text=True)
    return [l for l in r.stdout.split("\n") if l.startswith("  FAIL")]


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
            print("앵커 %d곳 ✗ %-22s %s" % (n, name, rel)); broken += 1
    if broken:
        print("::error::앵커가 1곳이 아닌 뮤턴트 %d개 — 뮤턴트가 낡았다" % broken); return 3
    if a.audit:
        print("앵커 전건 1곳 — 뮤턴트 %d개 대조 가능" % len(MUTANTS)); return 0
    base_tmp = pathlib.Path(tempfile.mkdtemp(prefix="v0316-mut-base-"))
    try:
        copy_tree(root, base_tmp)
        base = {"checks": run("checks", base_tmp), "emu": run("emu", base_tmp)}
    finally:
        shutil.rmtree(base_tmp, ignore_errors=True)
    print("기준선 적색 — checks %d줄 · emu %d줄" % (len(base["checks"]), len(base["emu"])))
    for l in base["checks"] + base["emu"]:
        print("   (기준선) " + l.strip())
    bad = 0
    for name, rel, old, new, axis, runner in MUTANTS:
        if any(axis in l for l in base[runner]):
            print("실격  %-22s ← 기준선에서 이미 붉은 축(공짜 적색): %s" % (name, axis)); bad += 1; continue
        tmp = pathlib.Path(tempfile.mkdtemp(prefix="v0316-mut-"))
        try:
            copy_tree(root, tmp)
            p = tmp / rel
            raw = p.read_bytes()
            bom = raw[:3] == b"\xef\xbb\xbf"
            text = raw.decode("utf-8-sig")
            mutated = text.replace(old, new, 1)
            if mutated == text:
                print("미적용 %-22s ← 변이가 들어가지 않았다" % name); bad += 1; continue
            p.write_bytes((b"\xef\xbb\xbf" if bom else b"") + mutated.encode("utf-8"))
            reds = run(runner, tmp)
            if any(axis in l for l in reds):
                print("붉음  %-22s ← %s" % (name, axis))
            else:
                print("눈멂  %-22s ← 안 붉어진 축: %s (그때 붉은 줄 %d)" % (name, axis, len(reds))); bad += 1
        finally:
            shutil.rmtree(tmp, ignore_errors=True)
    print("\n뮤턴트 %d개 · 실패(눈멂·실격·미적용) %d개" % (len(MUTANTS), bad))
    return 1 if bad else 0


sys.exit(main())
