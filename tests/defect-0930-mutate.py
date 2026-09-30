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
     "if ($d -and (Test-Path -LiteralPath (Join-Path $d 'cys.exe'))) { $reg = $e; $path = $d; break }",
     "if ($d) { $reg = $e; $path = $d; break }"),
    # ⓐ 실패는 실패로 — 새 판 설치 실패를 성공으로 · [7/10] 옛 판을 넘김
    ("a-install-done", "install",
     "    if ($done) {\n        [void](Save-CysPinStamp", "    if ($true) {\n        [void](Save-CysPinStamp"),
    ("a-verify-old", "verify", "        if ($low) {", "        if ($false) {"),
    # ⓒ 설치 자리를 우리가 정한다(/D)
    ("c-no-d-arg", "install", "('/S /D=' + $dir)", "'/S'"),
    # [8/10] 자동 시작 기대 경로 = 실제 본체 폴더의 cysd.exe
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
    ("e-setup-done", "avhold", "        if ($done) { return $false }\n", ""),
    ("e-count-fail", "avhold",
     "        $script:ProgressFailRun = [int]$script:ProgressFailRun + 1   #", "        $null = 0   #"),
    ("e-reset-ok", "avhold", "        $script:ProgressEverOk = $true; $script:ProgressFailRun = 0\n", "        $script:ProgressEverOk = $true\n"),
    ("e-retrigger-cap", "avhold",
     "        if ((-not $avRetried) -and (Test-AvHoldStall $avWatch $waitedMs)) {", "        if ((Test-AvHoldStall $avWatch $waitedMs)) {"),
    ("e-delete-fail", "avhold", "            $cleared = $false\n", ""),
    ("e-stuck-direct", "avhold", "    if ($avStuck) {", "    if ($false) {"),
    ("e-direct-judge", "avhold",
     "        if ((-not $again) -and (Test-AvHoldStall $w $waited)) {", "        if ($false -and (Test-AvHoldStall $w $waited)) {"),
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
