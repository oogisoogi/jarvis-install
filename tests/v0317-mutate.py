#!/usr/bin/env python3
# 뮤턴트 — v0.3.17(로그인은 새로 뜬 창에서 · 2026-09-15) 수정이 「실제로 서 있는가」를 재는 도구
#
# ★쓰는 법
#   python3 tests/v0317-mutate.py --root <저장소>           전건(사본에서만 고친다 · 실물 무접촉)
#   python3 tests/v0317-mutate.py --root <저장소> --audit   앵커가 아직 1곳씩 걸리는가만
#   python3 tests/v0317-mutate.py --root <저장소> --only a,b 이름을 골라서
#
# ★판정 = 기준선(변이 없음)에서 **초록**이던 축이, 변이를 넣은 사본에서 **붉어졌는가**.
#   기준선에서 이미 붉은 축을 기대로 쓰면 「공짜 적색」이라 아무것도 증명하지 않는다 — 그런 뮤턴트는 실격으로 센다.
# ★앵커가 1곳이 아니면 조용히 지나가지 않는다(rc 3) — 「안 망가뜨린 것」과 「망가뜨렸는데 안 붉어진 것」은 다르다.
# ★변이가 사본에 실제로 들어갔는지(바뀐 바이트가 있는지) 확인한 뒤에만 잰다 — 안 들어간 변이의 초록은 측정 실패다.
# ⚠checks 러너 뮤턴트는 흉내 실행 축 둘을 끄고(V0316_EMU_SKIP=1 · V0317_EMU_SKIP=1) 돈다 — 흉내 축은 emu 러너 뮤턴트가 따로 잰다.
# ⚠판정은 러너 출력의 「  FAIL 」 줄에 기대 축 이름이 있는가로 한다(러너의 rc 가 아니라) — 러너 자체가 죽으면 FAIL 줄이 없어 「눈멂」으로 드러난다.
import argparse, os, pathlib, shutil, subprocess, sys, tempfile

for _s in (sys.stdout, sys.stderr):
    try: _s.reconfigure(encoding="utf-8", errors="backslashreplace")
    except Exception: pass

PS = "install-master/bootstrap.ps1"
RS = "install-master/reset-clean.ps1"
# (이름, 파일, 찾을 것, 바꿀 것, 붉어져야 할 축 조각, 러너)
MUTANTS = [
    # ── 흉내(동작) ──
    ("poll-in-wait-drop", PS, "                        $doneBy = Resolve-LoginDone $authNow $credBefore\n", "",
     "[파일만 생김] 창이 안 닫혀도 로그인을 알아채고 창을 닫아 준다", "emu"),
    ("cap-drop", PS, "                    if ($w -ge $LoginWaitTimeout) {\n", "                    if ($false) {\n",
     "[무한 대기] 상한에서 창을 끝내고 J-LOGIN-01", "emu"),
    ("file-judge-drop", PS, "    if (Test-LoginCredFresh $credBefore) { return 'file' }\n", "",
     "[확인 명령 없음] 로그인 파일이 이번에 생겼으면 그것으로 판정한다", "emu"),
    ("status-false-wins-drop", PS, "    if ($authText -match '\"loggedIn\"\\s*:\\s*false') { return '' }\n", "",
     "[아니다라는 답]", "emu"),
    ("fresh-check-drop", PS, "    return ($now.Ticks -ne $before.Ticks)\n", "    return $true\n",
     "[예전 파일]", "emu"),
    ("ask-drop", PS, "                    $ans = Invoke-LoginFailQuestion\n", "                    $ans = @{ Answer = '묻지 않음'; Keys = '-' }\n",
     "[무한 대기 · 답 2]", "emu"),
    ("subscription-leak", PS, "    Write-Log ('login subscription: ' + (Get-LoginSubscription $authText))\n", "    Write-Log ('login subscription: ' + $authText)\n",
     "[승인 지연] 구독 종류만 적고", "emu"),
    ("closing-filter-drop", PS, "        $loudErr  = @($Error | Where-Object { -not (Test-QuietErrorRecord $_) })\n",
     "        $loudErr  = @($Error)\n",
     "[끝맺음] 조용히 넘긴 확인 오류만 있으면", "emu"),
    ("report-drop", PS, "        Add-LoginReport $info\n", "",
     "[즉시 반환] 로그인 단계에서 본 것을 환경 보고", "emu"),
    # ⚠두 뮤턴트의 기대 축 = 「[status-hang]」 조각(2026-09-15 r2) — 재판정도 같은 함수를 타게 되어, 상한이 빠지면
    #   로그인 단계 입구에서 멈춰 흉내가 기록을 못 남긴다(「[status-hang] 기록 파일」 줄로 붉어진다 · 뒤 축들은 그 갈래에서 건너뛴다).
    ("status-unbounded", PS, "        if (-not $p.WaitForExit($LoginStatusWaitMs)) {\n", "        [void]$p.WaitForExit(); if ($false) {\n",
     "[status-hang]", "emu"),
    ("rejudge-unbounded", PS, "        try { $reauth = Get-LoginStatusText $claudeExe } catch { $reauth = '' }\n", "        $reauth = (& claude auth status 2>$null) -join \"`n\"\n",
     "[status-hang]", "emu"),
    # ── 정적(checks) ──
    ("success-drain-drop", PS, "    $stray = Get-LoginStrayKeyCount\n    if ($stray -gt 0) { Write-Log ('login stray keys in installer window cleared=' + $stray) }\n", "",
     "[v0317] 로그인 성공 때도 설치 창에 쌓인 글자를 비운다", "checks"),
    ("closing-wording-revert", PS, "'아래 「다시 하시는 법」대로 다시 실행하시면 로그인 창이 다시 열립니다.'", "'브라우저에서 승인을 누르신 뒤 아래 「다시 하시는 법」대로 다시 실행해 주십시오.'",
     "[v0317] J-LOGIN-01 끝맺음은 다시 실행하면 로그인 창이 다시 열린다고 말한다", "checks"),
    ("pipe-revert", PS, "    $psi.RedirectStandardInput = $true\n", "    $psi.RedirectStandardInput = $false\n",
     "[login-clip] 로그인 입력은 설치기가 쥔다", "checks"),
    # ── 코드 넣기(2026-09-15 윈도우 샌드박스 · 흉내) ──
    ("clip-poll-drop", PS, "                        $clip = Get-LoginClipText\n", "                        $clip = $null\n",
     "[클립보드 코드] 복사만 하면", "emu"),
    ("clip-shape-drop", PS, "    return ($s.Trim() -cmatch '^[A-Za-z0-9._~-]{16,512}#[A-Za-z0-9._~-]{16,512}$')\n", "    return ($s.Trim().Length -gt 0)\n",
     "[클립보드 모양 아님]", "emu"),
    ("clip-base-drop", PS, "($clipHash -ne $clipBase) -and ", "",
     "[클립보드 예전 코드] 로그인을 열기 전부터", "emu"),
    ("clip-dedupe-drop", PS, " -and ($clipHash -ne $lastSent)", "",
     "[클립보드 같은 코드]", "emu"),
    ("clip-cap-drop", PS, "                    if ($clipSends -lt $LoginClipMaxSends) {\n", "                    if ($true) {\n",
     "[클립보드 여러 코드]", "emu"),
    ("clip-log-leak", PS, "                                    Write-Log ('login code sent from clipboard ' + $clipSends + ' after ' + $w + 's')\n",
     "                                    Write-Log ('login code sent from clipboard ' + $clipSends + ' after ' + $w + 's ' + $clip)\n",
     "[클립보드 코드] 코드 원문을", "emu"),
    ("inline-back", PS, "                Write-Log 'login proc: could not start'\n", "                Write-Log 'login proc: could not start'\n                & claude auth login\n",
     "[띄우기 실패] 로그인 프로세스를 못 띄우면", "emu"),
    ("selffix-drop", PS, "        foreach ($ln in $LoginSelfFixLines) { Say $ln }\n", "",
     "[무한 대기] 로그인이 끝내 안 되면 스스로 푸는 법", "emu"),
    ("clip-report-drop", PS, "        ('코드 넣기: ' + $info.Send),\n", "",
     "[클립보드 예전 코드] 코드 넣기 횟수를", "emu"),
    ("caller-capture", PS, "    Step-Login; $rc = $script:LoginRc; if ($rc -ne 0) { exit $rc }", "    $rc = Step-Login; if ($rc -ne 0) { exit $rc }",
     "[v0317] 부르는 쪽이 로그인 결과를 반환값으로 받지 않는다", "checks"),
    ("card-subscription-drop", PS, "    '     Claude 유료 구독 계정(Pro 이상)이어야 합니다 — 무료 계정으로는 로그인 승인이 끝나지 않습니다.',\n", "",
     "[v0317] 로그인 카드 첫 줄은 유료 구독 조건", "checks"),
    ("rerun-before-drop", PS, "    if ($script:NoticeShown -and $script:ShowRerun -and $script:JCode -and ($Mode -eq 'full') -and (-not $script:ReachedWake)) { Show-RerunHow }\n", "",
     "[v0317] 원격 해결 대기 앞에도 다시 하시는 법", "checks"),
    ("wallclock-revert", PS, "                    $w = [int]$sw.Elapsed.TotalSeconds\n", "                    $w += 5\n",
     "[v0317] 상한은 벽시계로 잰다", "checks"),
    ("confirm-poll-back", PS, "$LoginConfirmTries = 3 ", "$LoginConfirmTries = 300 ",
     "[v0317] 창이 끝나면 몇 번만 확인한다", "checks"),
    ("window-key-revert", RS, "⊞ 윈도우 키(키보드 왼쪽 아래, Ctrl과 Alt 사이)를 누르고", "시작 단추를 누르고",
     "[v0317] 다시 하시는 법 첫 줄은 윈도우 키", "checks"),
]


def copy_tree(root, dst):
    for d in ("install-master", "tests", "docs"):
        shutil.copytree(root / d, dst / d, symlinks=True)


def run(runner, tree):
    env = dict(os.environ)
    if runner == "checks":
        env["V0316_EMU_SKIP"] = "1"
        env["V0317_EMU_SKIP"] = "1"
        r = subprocess.run(["bash", "install-master/checks.sh"], cwd=tree, env=env, capture_output=True, text=True, stdin=subprocess.DEVNULL)
    else:
        r = subprocess.run(["bash", "tests/v0317-emu-run.sh"], cwd=tree, env=env, capture_output=True, text=True, stdin=subprocess.DEVNULL)
    return [l for l in r.stdout.split("\n") if l.startswith("  FAIL")]


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--root", required=True)
    ap.add_argument("--audit", action="store_true")
    ap.add_argument("--only", default="")
    a = ap.parse_args()
    root = pathlib.Path(a.root).expanduser().resolve()
    only = set(x for x in a.only.split(",") if x)
    chosen = [m for m in MUTANTS if not only or m[0] in only]
    broken = 0
    for name, rel, old, new, axis, runner in chosen:
        n = (root / rel).read_text(encoding="utf-8-sig").count(old)
        if n != 1:
            print("앵커 %d곳 ✗ %-24s %s" % (n, name, rel)); broken += 1
    if broken:
        print("::error::앵커가 1곳이 아닌 뮤턴트 %d개 — 뮤턴트가 낡았다" % broken); return 3
    if a.audit:
        print("앵커 전건 1곳 — 뮤턴트 %d개 대조 가능" % len(chosen)); return 0
    runners = sorted(set(m[5] for m in chosen))
    base_tmp = pathlib.Path(tempfile.mkdtemp(prefix="v0317-mut-base-"))
    try:
        copy_tree(root, base_tmp)
        base = {r: run(r, base_tmp) for r in runners}
    finally:
        shutil.rmtree(base_tmp, ignore_errors=True)
    print("기준선 적색 — " + " · ".join("%s %d줄" % (r, len(base[r])) for r in runners))
    for r in runners:
        for l in base[r]:
            print("   (기준선) " + l.strip())
    bad = 0
    for name, rel, old, new, axis, runner in chosen:
        if any(axis in l for l in base[runner]):
            print("실격  %-24s ← 기준선에서 이미 붉은 축(공짜 적색): %s" % (name, axis)); bad += 1; continue
        tmp = pathlib.Path(tempfile.mkdtemp(prefix="v0317-mut-"))
        try:
            copy_tree(root, tmp)
            p = tmp / rel
            raw = p.read_bytes()
            bom = raw[:3] == b"\xef\xbb\xbf"
            text = raw.decode("utf-8-sig")
            mutated = text.replace(old, new, 1)
            if mutated == text:
                print("미적용 %-24s ← 변이가 들어가지 않았다" % name); bad += 1; continue
            p.write_bytes((b"\xef\xbb\xbf" if bom else b"") + mutated.encode("utf-8"))
            if p.read_bytes() == raw:
                print("미적용 %-24s ← 쓴 뒤에도 바이트가 같다" % name); bad += 1; continue
            reds = run(runner, tmp)
            if any(axis in l for l in reds):
                print("붉음  %-24s ← %s" % (name, axis))
            else:
                print("눈멂  %-24s ← 안 붉어진 축: %s (그때 붉은 줄 %d)" % (name, axis, len(reds))); bad += 1
                for l in reds[:4]:
                    print("        " + l.strip())
        finally:
            shutil.rmtree(tmp, ignore_errors=True)
    print("\n뮤턴트 %d개 · 실패(눈멂·실격·미적용) %d개" % (len(chosen), bad))
    return 1 if bad else 0


sys.exit(main())
