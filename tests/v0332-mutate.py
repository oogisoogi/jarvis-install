#!/usr/bin/env python3
# 뮤턴트 — 0.3.32(C1 문구 한 줄 · C2 원문 숨김 · B9 끝 단계 10/10 · B2 로그인 승계 A1)의 시험이 **대상을 실제로 때리는가** (TICKET=installer-0332)
#
# ★쓰는 법
#   python3 tests/v0332-mutate.py --root <저장소>           전건(사본에서만 고친다 · 실물 무접촉)
#   python3 tests/v0332-mutate.py --root <저장소> --audit   앵커가 아직 1곳씩 걸리는가만
#
# ★판정 = 기준선(변이 없음)에서 **초록**이던 축이, 변이를 넣은 사본에서 **붉어졌는가**(v0331-mutate 와 같은 규율).
# ★변이가 사본에 실제로 들어갔는지(바뀐 바이트가 있는지) 확인한 뒤에만 잰다.
# ★러너 두 가지 — "checks" = `CHECKS_ONLY=0332 bash install-master/checks.sh`(글자·순서 축) · "emu" = `bash tests/v0332-emu-run.sh`(동작 축).
# ⚠판정은 러너 출력의 「  FAIL 」 줄에 기대 축 이름이 있는가로 한다(러너의 rc 가 아니라).
import argparse, os, pathlib, shutil, subprocess, sys, tempfile

for _s in (sys.stdout, sys.stderr):
    try: _s.reconfigure(encoding="utf-8", errors="backslashreplace")
    except Exception: pass

PS = "install-master/bootstrap.ps1"
SH = "install-master/bootstrap.sh"

# (이름, 파일, 찾을 것, 바꿀 것, 붉어져야 할 축 조각, 러너)
MUTANTS = [
    # C1 — 건너뛴 갈래에서 「등록 여부」 줄을 또 찍으면 두 줄 모순이 돌아온다.
    ("win-c1-second-line", PS,
     "-not $script:DaemonTemporary -and $daemonRc -ne 'skipped') {",
     "-not $script:DaemonTemporary) {",
     "[윈 C1 A] 이미 돎+등록 yes", "emu"),
    ("mac-c1-second-line", SH,
     '[ "$DAEMON_TEMPORARY" != "1" ] && [ "$autostart_said" != 1 ] && say',
     '[ "$DAEMON_TEMPORARY" != "1" ] && say',
     "[맥 C1 A] 이미 돎+등록 yes", "emu"),
    # C2 — 원문 줄을 선점 판정 앞으로 되돌리면 영문이 창에 찍힌다.
    ("win-c2-raw-before-claim", PS,
     '        Write-Log "new-surface failed: $ref"\n',
     '        Say \'     cys 안에서 열지 못했습니다. 프로그램이 답한 내용은 이렇습니다:\'\n        foreach ($ln in ($ref -split "`n")) { if ($ln.Trim()) { Say "       $ln" } }\n        Write-Log "new-surface failed: $ref"\n',
     "[윈 C2] 선점 거절 → 설치 창에 영문 원문 0줄", "emu"),
    # B9 — 끝맺음 줄에서 [10/10] 을 빼면 끝 증거가 9/10 으로 붙는다.
    ("win-b9-step-drop", PS,
     "Say '[10/10] 설치는 여기까지 끝났습니다.",
     "Say '     설치는 여기까지 끝났습니다.",
     "[윈 B9] 설치 끝 증거가 단계 10/10", "emu"),
    ("mac-b9-step-drop", SH,
     'say "[10/10] 설치는 여기까지 끝났습니다.',
     'say "     설치는 여기까지 끝났습니다.',
     "[맥 B9] 설치 끝 증거가 단계 10/10", "emu"),
    # B2 — 무조건 덮기 복원 · 비교 방향 뒤집기 · 앞 사본 생략 · 앞 사본 누적 · 수정 시각 폴백 제거.
    ("win-b2-always-copy", PS,
     "if ($plan -like 'keep:*') {",
     "if ($false) {",
     "[윈 L3] 자비스 새것 → 그대로", "emu"),
    ("mac-b2-always-copy", SH,
     "    keep:*)\n      hex=\"\"; dhex=\"\"",
     "    keep:__never__)\n      hex=\"\"; dhex=\"\"",
     "[맥 L3] 자비스 새것 → 그대로", "emu"),
    ("win-b2-direction-flip", PS,
     "    if ($a -gt $b) { return 'copy:older' }",
     "    if ($a -lt $b) { return 'copy:older' }",
     "[윈] Get-LoginCopyPlan 여덟 입력", "emu"),
    ("mac-b2-direction-flip", SH,
     '  if [ "$a" -gt "$b" ] 2>/dev/null; then echo copy:older',
     '  if [ "$a" -lt "$b" ] 2>/dev/null; then echo copy:older',
     "[동형] 맥 login_copy_plan 이 글자까지 같다", "emu"),
    ("mac-b2-unknown-mtime-as-zero", SH,
     '  else echo keep:unknown; return 0; fi',
     '  else a="${4:-0}"; b="${5:-0}"; fi',
     "[동형] 맥 login_copy_plan 이 글자까지 같다", "emu"),
    ("win-b2-backup-drop", PS,
     "if ($dstExists) { Copy-Item -LiteralPath $dst -Destination ($dst + '.bak-jarvis')",
     "if ($false) { Copy-Item -LiteralPath $dst -Destination ($dst + '.bak-jarvis')",
     "[윈 L2] 자비스 옛것(만료 시각) → 옮김", "emu"),
    ("mac-b2-backup-accumulate", SH,
     '"$acct" "$svc.bak-jarvis" "$dhex"',
     '"$acct" "$svc.bak-jarvis-$RANDOM" "$dhex"',
     "[맥 L2'] 앞 사본은 1세대만", "emu"),
    ("mac-b2-mtime-fallback-drop", SH,
     '"$(keychain_mdat_of "$acct" "Claude Code-credentials")"',
     '"0"',
     "[맥 L4·L5] 둘 다 만료 시각 없음", "emu"),
    # KW67JGJG — 망 실패 기계의 파일 없음 → J-DL-07 · 자식 오류 글 기록
    ("win-dl07-netfailed-drop", PS,
     "if (($hasExe -eq '아니오') -and ($fastExit -or $script:NetFailed)) {",
     "if (($hasExe -eq '아니오') -and ($fastExit)) {",
     "[윈 망실패] 파일 없음+1-7 실패 → J-DL-07", "emu"),
    ("mac-dl07-netfailed-drop", SH,
     '{ [ "$fast_exit" = 1 ] || [ "$NET_FAILED" = 1 ]; }; then',
     '[ "$fast_exit" = 1 ]; then',
     "[맥 망실패] 파일 없음+1-7 실패 → J-DL-07", "emu"),
    ("win-netfailed-flag-drop", PS,
     "    $script:NetFailed = ($netEnum -eq 'failed')\n",
     "",
     "[0332 KW67] 윈: 1-7 실패 행이 깃발을 세운다", "checks"),
    ("mac-netfailed-flag-drop", SH,
     '  [ "$net_enum" = failed ] && NET_FAILED=1\n',
     "",
     "[0332 KW67] 맥: 같음", "checks"),
    ("win-child-catch-drop", PS,
     """                    "catch { try { Write-Host ('[claude-install error] ' + (`$_ | Out-String).Trim()) } catch { }; throw } " +\n""",
     "",
     "[윈 ③] 설치기가 예외로 죽으면 오류 글이 기록", "emu"),
    ("win-rc-branch-tail-drop", PS,
     "        # v0.3.32(TICKET=installer-0332 ③ · 도움 KW67JGJG): 이 갈래는 설치기가 한 말을 한 줄도 남기지 않았다 — 다음 진단이 추정이 되지 않게 꼬리를 붙인다.\n        Show-ClaudeInstallLogTail\n",
     "",
     "[윈 ③] 종료 코드 실패 갈래도 그 오류 글", "emu"),
    # master 판정 abb77ec4 — 종료 코드 실패 갈래도 같은 축
    ("win-rc-dl07-drop", PS,
     "if ((-not (Test-Path -LiteralPath $rcExe)) -and $script:NetFailed) {",
     "if ($false) {",
     "[윈 종료코드] 파일 없음+1-7 실패 → J-DL-07", "emu"),
    ("mac-rc-hotspot-drop", SH,
     '    elif [ ! -x "$HOME/.local/bin/claude" ] && [ "$NET_FAILED" = 1 ]; then',
     '    elif false; then',
     "[맥 종료코드] 기다림 끝에도 안 붙고", "emu"),
    # master 판정 0c0f5705 — rotate 부서 순회 생략(env 언제나 · 인자는 1.1.3 이상)
    ("win-skip-env-drop", PS,
     "        $psi.EnvironmentVariables['CYS_ROTATE_SKIP_DEPTS'] = '1'\n",
     "",
     "[윈 rotate] 1.1.3 = 인자+env", "emu"),
    ("mac-skip-env-drop", SH,
     'CYS_ROTATE_SKIP_DEPTS=1 "${1:-cys}" rotate --timeout',
     '"${1:-cys}" rotate --timeout',
     "[맥 rotate] 같음", "emu"),
    ("win-skip-threshold-lowered", PS,
     "($a -eq 1 -and $b -eq 1 -and $c -ge 3)",
     "($a -eq 1 -and $b -eq 1 -and $c -ge 2)",
     "[윈 rotate] 1.1.3 = 인자+env", "emu"),
    # master 판정 1b01748b · 899 L5 — 개인 쪽 로그아웃이면 옮기지 않는다
    ("win-src-logged-out-drop", PS,
     "        if (-not (Test-CredHasLogin $src)) {",
     "        if ($false) {",
     "[윈 L6] 개인 쪽 로그아웃", "emu"),
    ("mac-src-logged-out-drop", SH,
     "  if ! printf '%s' \"$hex\" | xxd -r -p | cred_has_login; then",
     "  if false; then",
     "[맥 L6] 같음(판정·기록 줄 동형)", "emu"),
    # 글자 축 — 판번
    ("win-version-back", PS,
     "$InstallerVersion       = '0.3.32'",
     "$InstallerVersion       = '0.3.31'",
     "[0332 판번] 윈 0.3.32", "checks"),
]


def copy_tree(root, dst):
    for d in ("install-master", "tests"):
        shutil.copytree(root / d, dst / d, symlinks=True)


def run(tree, runner="checks"):
    env = dict(os.environ); env["CHECKS_ONLY"] = "0332"
    cmd = ["bash", "install-master/checks.sh"] if runner == "checks" else ["bash", "tests/v0332-emu-run.sh"]
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
    base_tmp = pathlib.Path(tempfile.mkdtemp(prefix="v0332-mut-base-"))
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
        tmp = pathlib.Path(tempfile.mkdtemp(prefix="v0332-mut-"))
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
