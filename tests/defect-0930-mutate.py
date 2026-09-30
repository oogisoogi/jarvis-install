#!/usr/bin/env python3
# 0.3.38 윈 설치기 결함 묶음 — 「되돌리면 붉어진다」: bootstrap.ps1 사본에 한 줄씩 변이를 넣고 tests/defect-0930-run.sh 가 적색인지 잰다.
#   ⚠원본은 건드리지 않는다 — 스크래치 사본(install-master 통째)만 고친다 · 원본 초록을 먼저 확인한다(거짓 적색 방지).
#   변이마다 그 결함의 시험 묶음만 돈다(--only) — 묶음 전체는 2분 남짓이라 변이 × 전체는 너무 길다.
#   쓰는 법: python3 tests/defect-0930-mutate.py [--only 이름,이름]  · rc 0 = 전건 KILLED
import os, shutil, subprocess, sys, tempfile

HERE = os.path.dirname(os.path.abspath(__file__))
SRC = os.path.abspath(os.path.join(HERE, "..", "install-master"))
RUN = os.path.join(HERE, "defect-0930-run.sh")
FN = "bootstrap.ps1"

# (이름, 시험 묶음, 찾을 글자, 바꿀 글자) — 찾을 글자는 정확히 한 번 나와야 한다(아니면 변이 무효 = 실패로 센다)
MUTANTS = [
    # ⓑ 본체 판정 = 파일 실측
    ("b-bins-trust", "install",
     "foreach ($n in @('cys.exe', 'cysd.exe', 'cys-app.exe')) { if (-not (Test-Path -LiteralPath (Join-Path $dir $n))) { return $false } }",
     "$null = 0"),
    ("b-reg-trust", "body",
     "if ($d -and (Test-Path -LiteralPath ([System.IO.Path]::Combine($d, 'cys.exe')) -ErrorAction SilentlyContinue)) { $reg = $e; $path = $d; break }",
     "if ($d) { $reg = $e; $path = $d; break }"),
    # ⓐ 실패는 실패로 — 새 판 설치 실패를 성공으로 · [7/10] 옛 판을 넘김
    ("a-install-done", "install",
     "    if ($done) {\n        [void](Save-CysPinStamp", "    if ($true) {\n        [void](Save-CysPinStamp"),
    ("a-verify-old", "verify", "        if ($low) {", "        if ($false) {"),
    # ⓒ 설치 자리를 우리가 정한다(/D)
    ("c-no-d-arg", "install", "('/S /D=' + $dir)", "'/S'"),
    # [8/10] 자동 시작 기대 경로 = 실제 본체 폴더의 cysd.exe
    ("autostart-one-value", "verify", "    if ($script:CysBodyDir) {\n        $wantList +=", "    if ($false) {\n        $wantList +="),
    ("autostart-body", "verify",
     "if ($bb.Body -and $bb.Path) { $wantList += (Join-Path $bb.Path 'cysd.exe') }", "if ($false) { }"),
    # ⓓ 창 실행 파일 실재 · 창 여는 길 · 「알렸습니다」는 전송 성공 때만
    ("d-app-exe", "wake", "    if (-not (Get-CysAppExe)) {", "    if ($false) {"),
    ("d-hint-target", "wake",
     "if ($t -and (Test-Path -LiteralPath $t)) { return '창이 안 보이면 바탕화면", "if ($t) { return '창이 안 보이면 바탕화면"),
    ("d-told-ops", "wake",
     "if ($script:ProgressLastOk) { $script:NextStep = '자비스 운영팀에", "if ($true) { $script:NextStep = '자비스 운영팀에"),
    # ⓔ 백신 보류 1분 판정 — 전제 넷 · 재유발 1회 · 지우기 실패 · 자식 받기 · 전송 세기 · 안내 한 번
    ("e-everok", "avhold", "    if (-not $w.EverOk) { return $false }\n", ""),
    ("e-failrun", "avhold", "    if ([int]$script:ProgressFailRun -lt 2) { return $false }", "    if ([int]$script:ProgressFailRun -lt 0) { return $false }"),
    ("e-window", "avhold", "    if (([long]$nowMs - $w.LastMoveMs) -lt $AvHoldJudgeMs) { return $false }\n", ""),
    ("e-expected", "avhold", "    if ($w.Expected -gt 0) { return ($w.Len -lt $w.Expected) }", "    if ($w.Expected -gt 0) { return $true }"),
    ("e-setup-done", "avhold", "        if ((Test-AvSetupDone $w.Aux) -ne 'no') { return $false }   #", "        if ($false) { return $false }   #"),
    ("e-count-fail", "avhold",
     "        if ($reqSent) { $script:ProgressFailRun = [int]$script:ProgressFailRun + 1 }   #", "        $null = 0   #"),
    ("e-reset-ok", "avhold", "        $script:ProgressEverOk = $true; $script:ProgressFailRun = 0\n", "        $script:ProgressEverOk = $true\n"),
    ("e-retrigger-cap", "avhold",
     "            if ($script:AvRetriggered) {\n                # 두 번째 판정", "            if ($false) {\n                # 두 번째 판정"),
    ("e-direct-cap", "avhold",
     "            if ($script:AvRetriggered) {\n                Write-Log 'av hold judged again (직접 받기)", "            if ($false) {\n                Write-Log 'av hold judged again (직접 받기)"),
    ("e-unread-log", "avhold", "        if ((Test-AvSetupDone $w.Aux) -ne 'no') { return $false }", "        if ((Test-AvSetupDone $w.Aux) -eq 'yes') { return $false }"),
    ("e-count-sent-only", "avhold", "        if ($reqSent) { $script:ProgressFailRun", "        if ($true) { $script:ProgressFailRun"),
    ("e-history", "avhold", "    if (-not ((($w.Len -eq 0) -and $w.Seen0) -or $w.Grew)) { return $false }\n", ""),
    ("e-delete-retry", "avhold", "        for ($try = 1; $try -le 5; $try++) {", "        for ($try = 1; $try -le 1; $try++) {"),
    ("b-target-regloc", "install", "(Test-CysDirHasBins $b.Path) -and\n", "(Test-CysDirHasBins $b.Path) -and $true -or\n"),
    ("e-delete-fail", "avhold", "            $cleared = $false\n", ""),
    ("e-stuck-direct", "avhold", "    if ($avStuck) {", "    if ($false) {"),
    ("e-direct-judge", "avhold",
     "        if (Test-AvHoldStall $w $waited) {\n            if ($script:AvRetriggered) {\n                Write-Log", "        if ($false -and (Test-AvHoldStall $w $waited)) {\n            if ($script:AvRetriggered) {\n                Write-Log"),
    # ⑵ 옛 이름 설치 자리 기억(\cys) 정리 — 성공 뒤 호출 · 같은 자리 · cys.exe 있음 · 못 읽음 · 없는 드라이브 · 기록 1줄 · 실패 흡수
    ("m2-call-done", "install", "        [void](Clear-CysStaleInstallMemory $dir)   #", "        $null = 0   #"),
    ("m2-call-skip", "install", "$script:CysBodyDir = [string]$b0.Path; [void](Clear-CysStaleInstallMemory $script:CysBodyDir); Say \"[6/10]", "$script:CysBodyDir = [string]$b0.Path; Say \"[6/10]"),
    ("m2-none", "install", "        if (-not $mem) { return 'none' }\n", ""),
    ("m2-same", "install", "        if ($mem.TrimEnd('\\', '/') -ieq ([string]$dir).TrimEnd('\\', '/')) { return 'same' }", "        if ($false) { return 'same' }"),
    ("m2-exe-kept", "install", "            Write-Log ('install memory \\cys kept (cys.exe there): ' + (Redact $raw)); return 'kept'", "            $null = 0"),
    ("m2-unread", "install", "        } catch { Write-Log ('install memory \\cys kept (unread): ' + (Redact $raw) + ' · ' + $_.Exception.GetType().Name); return 'unread' }", "        } catch { }"),
    ("m2-drive", "install", "        } catch [System.Management.Automation.DriveNotFoundException] {\n", ""),
    ("m2-log-was", "install", "        if (-not (Write-LogChecked ('install memory \\cys removed · was=' + (Redact $raw) + ' · body=' + (Redact $dir)))) { return 'nolog' }", "        $null = 0"),
    ("m2-absorb", "install", "    } catch { Write-Log ('install memory \\cys not removed: ' + $_.Exception.Message); return 'fail' }", "    } finally { }"),
    # 두 번째 코드 검토 — [7/10] 본체 폴더 · 같은 판 덮어 깔기 기다림 · 남아 있다는 말 · 기록 못 하면 안 지움
    ("r2-verify-body", "verify", "    if ($script:CysBodyDir -and (Test-Path -LiteralPath (Join-Path $script:CysBodyDir 'cys.exe')) -and\n", "    if ($false -and\n"),
    ("r2-refresh-wait", "install", "            if ($refresh -and $p.HasExited -and ($p.ExitCode -ne 0)) { break }", "            if ($refresh -and $p.HasExited) { break }"),
    ("r2-no-left-refresh", "install", "    $oldLeft = $b0.Body -and (-not $refresh) -and", "    $oldLeft = $b0.Body -and"),
    ("r2-log-guard", "install", "        if (-not (Write-LogChecked ('install memory \\cys removed · was=' + (Redact $raw) + ' · body=' + (Redact $dir)))) { return 'nolog' }", "        [void](Write-LogChecked ('install memory \\cys removed · was=' + (Redact $raw) + ' · body=' + (Redact $dir)))"),
    # 두 번째 코드 검토 결정분 — 본 창에 맞춘 단추 이름 · 버린 설치 목록 후보 기록
    ("r2-button-hint", "avhold", "    if ([string]$title -match '\\bV3\\b|AhnLab|안랩') { return ' (이 백신에서는 「파일 전송」 단추로 보였습니다)' }\n    return ''", "    return ' (이 백신에서는 「파일 전송」 단추로 보였습니다)'"),
    ("r2-skipped-log", "install", "    if (@($b0.Skipped).Count -gt 0) { Write-Log", "    if ($false) { Write-Log"),
    # 세 번째 코드 검토 — 창 실행 파일도 본체 폴더 먼저 · 없는 드라이브에서 오류 0(진단·선택 둘 다)
    ("r3-app-body", "verify", "    if ($script:CysBodyDir) { [void]$roots.Add([string]$script:CysBodyDir) }\n", ""),
    ("r3-skip-combine", "verify", "if (Test-Path -LiteralPath ([System.IO.Path]::Combine($d, 'cys.exe')) -ErrorAction Stop) { $ex = 'yes' }", "if (Test-Path -LiteralPath (Join-Path $d 'cys.exe')) { $ex = 'yes' }"),
    ("r3-loop-combine", "verify", "        if ($d -and (Test-Path -LiteralPath ([System.IO.Path]::Combine($d, 'cys.exe')) -ErrorAction SilentlyContinue)) { $reg = $e; $path = $d; break }", "        if ($d -and (Test-Path -LiteralPath (Join-Path $d 'cys.exe'))) { $reg = $e; $path = $d; break }"),
    ("r3-rh-body", "verify", "        if ([System.IO.Path]::IsPathRooted($c) -and (Test-Path -LiteralPath $c -PathType Leaf)) { return $c }", "        $null = 0"),
    ("e-except-once", "avhold", "    if (($d.Count -eq 0) -or $script:AvExceptShown) { return }", "    if ($d.Count -eq 0) { return }"),
]

def run(d, grp):
    r = subprocess.run(["bash", RUN, "--dir", d, "--only", grp], capture_output=True, text=True)
    return r.returncode, r.stdout

def main():
    only = None
    a = sys.argv[1:]
    if "--only" in a: only = set(a[a.index("--only") + 1].split(","))
    muts = [m for m in MUTANTS if only is None or m[0] in only]
    for grp in sorted({m[1] for m in muts}):
        rc, out = run(SRC, grp)
        if rc != 0:
            print(f"원본이 초록이 아니다({grp}) — 변이를 잴 수 없다\n" + out[-1500:]); return 2
        print(f"원본 초록 확인({grp})")
    killed = 0; bad = []
    for name, grp, old, new in muts:
        tmp = tempfile.mkdtemp(prefix="d0930mut-")
        try:
            d = os.path.join(tmp, "install-master"); shutil.copytree(SRC, d)
            p = os.path.join(d, FN)
            raw = open(p, "rb").read()
            bom = raw.startswith(b"\xef\xbb\xbf")
            s = raw.decode("utf-8-sig")
            if s.count(old) != 1:
                print(f"  INVALID  {name} (찾을 글자 {s.count(old)}번)"); bad.append(name); continue
            open(p, "wb").write((b"\xef\xbb\xbf" if bom else b"") + s.replace(old, new).encode("utf-8"))
            rc, out = run(d, grp)
            if rc != 0:
                killed += 1
                first = next((l for l in out.splitlines() if l.startswith("  FAIL")), "")[:150]
                print(f"  KILLED   {name}  ← {first}")
            else:
                print(f"  SURVIVED {name}"); bad.append(name)
        finally:
            shutil.rmtree(tmp, ignore_errors=True)
    print(f"== 변이 {len(muts)} · KILLED {killed} · 남음 {len(bad)} {' '.join(bad)} ==")
    return 0 if not bad else 1

if __name__ == "__main__":
    sys.exit(main())
