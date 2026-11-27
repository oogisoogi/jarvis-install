#!/usr/bin/env python3
# scrub-v3-win-mutants.py — 윈 설치기 가림 v3 포팅의 관문 3(TICKET=scrub-v3-port-1116 · ROLE=win)
#
#   python3 tests/scrub-v3-win-mutants.py [--n 800] [--only M1,M2] [--log <파일>]
#
# 「규칙 하나를 다르게」 한 변종을 bootstrap.ps1 의 **사본**에만 내고(실물은 고치지 않는다) tests/scrub-v3-win.mjs(관문 1·2)를 그 사본에 돌린다.
#   rc ≠ 0 = KILLED(관문이 변종을 잡았다) · rc 0 = SURVIVED(관문의 빈칸).
# ★앵커가 하나라도 안 걸리면 조용히 지나가지 않고 rc 3 으로 멈춘다 — 「망가뜨렸더니 붉어졌다」 와 「애초에 안 망가뜨렸다」 는 다른 일이다.
# 먼저 변이 없는 사본이 초록인지 본다(그것이 붉으면 뮤턴트 판정은 뜻이 없다 → rc 4).
import argparse, pathlib, shutil, subprocess, sys, tempfile, time

HERE = pathlib.Path(__file__).resolve().parent
SRC = HERE.parent / "install-master"

MUTANTS = {
    # 3R 발견 3 — 수확이 한도에 닿으면 넘침을 알리지 않고 조용히 멈춘다(옛 꼴)
    "M1-harvest-silent-cap": [
        ("        if ($list.Count -ge $script:RhHarvestMax) { $state.Overflow = $true; return }",
         "        if ($list.Count -ge $script:RhHarvestMax) { return }"),
    ],
    # 3R 발견 4 — 셋째 수확 가지가 줄 끝 개행을 먹는다(연속 DOMAIN 줄의 둘째 줄을 놓친다)
    "M2-harvest-consume-newline": [
        ("[ \\t]*(?=\\r?\\n|\\z)'", "[ \\t]*(?:\\r?\\n|\\z)'"),
    ],
    # 3R 발견 6 — 칸의 크기 문지기가 없다
    "M3-no-size-gate": [
        ("        if ($source.Length -gt $limit) { return (& $full 'size') }\n", ""),
    ],
    # 2R 발견 4 — 자르기가 가림보다 먼저(가운데 순서: 원문을 먼저 상한으로 줄이고 가린다)
    "M4-cut-before-scrub": [
        ("        $result = Invoke-RemoteHelpScrub $source $set.Names $tick\n",
         "        if ($null -ne $MaxBytes) { if ($Keep -ceq 'head') { $source = Get-RemoteHelpCutHead $source ([int]$MaxBytes) } else { $source = Get-RemoteHelpCutTail $source ([int]$MaxBytes) } }\n        $result = Invoke-RemoteHelpScrub $source $set.Names $tick\n"),
    ],
    # split 1R 발견 1 — 알려진 이름을 원본으로 넣지 않고 손질한 꼴만(지금 공개된 0.3.46 의 꼴)
    "M5-groom-known-only": [
        ("        if ($raw.Length -gt 0 -and (Get-RemoteHelpTrimWide $raw).Length -gt 0) { & $put $raw }\n", ""),
    ],
    # 설계 좌석 M35 — 표시 값을 따옴표 뗀 꼴로만
    "M6-stripped-only": [
        ("        if ($whole.Length -ge 2) { & $put $whole }\n", ""),
        ("        if ($piece.Length -ge 2) { & $put $piece }\n        if ($value.Length -ge 2) { & $put $value }\n", "        if ($value.Length -ge 2) { & $put $value }\n"),
    ],
    # 부록 E · 모델 M21 — 이름 구간을 스택으로 합치지 않는다
    "M7-no-stack-merge": [
        ("        while ($top -ge 0 -and $spanE[$top] -ge $start) {", "        while ($false) {"),
    ],
    # split 1R 발견 4 — 시계 초기화가 문지기(넘침·크기)보다 먼저
    "M8-clock-before-gates": [
        ("        if ($set.IsSet -and $set.Overflow) { return (& $full 'harvest') }\n", ""),
        ("            $budget.Started = & $readClock   # 시계를 처음 읽는다 — 고장이면 여기서 clock\n",
         "            $budget.Started = & $readClock   # 시계를 처음 읽는다 — 고장이면 여기서 clock\n        }\n        if ($set.IsSet -and $set.Overflow) { return (& $full 'harvest') }\n        if ($null -ne $BudgetMs) {\n"),
    ],
    # 설계 좌석 M31 — 설치기 첨부가 느슨하게 읽는다(틀린 바이트를 U+FFFD 로)
    "M9-attach-lenient-decode": [
        ("        $strict = New-Object System.Text.UTF8Encoding($false, $true)", "        $strict = New-Object System.Text.UTF8Encoding($false, $false)"),
    ],
    # 첨부의 NUL 판정이 없다
    "M10-attach-allow-nul": [
        ("        if ($text.IndexOf([char]0) -ge 0) { return (& $send $script:RhScrubFull 'nul' $null $null) }\n", ""),
    ],
    # 첨부 맨 앞의 U+FEFF 를 떼지 않는다(줄 처음에 닻을 둔 수확이 머리표에 가린다)
    "M11-attach-keep-bom": [
        ("        if ($lead -gt 0) { $text = $text.Substring($lead) }\n", ""),
    ],
    # 2R 발견 1 · 모델 M15 — 정리 순서를 뒤집는다(서러게이트 치환이 NUL 제거보다 먼저)
    "M12-tidy-order": [
        ("    $clean = $Value.Replace(([string][char]0), '')\n    return $script:RhLoneSurrogateRe.Replace($clean, ([string][char]0xFFFD))",
         "    $clean = $script:RhLoneSurrogateRe.Replace($Value, ([string][char]0xFFFD))\n    return $clean.Replace(([string][char]0), '')"),
    ],
    # split 1R 발견 2 · 모델 M37 — 받은 묶음의 넘침을 버린다
    "M13-drop-known-overflow": [
        ("    $out.Overflow = (($over -is [bool]) -and $over)", "    $out.Overflow = $false"),
    ],
    # 3R 발견 6 · 모델 M26 의 한 조각 — 시계 값이 유한한 수인지 보지 않는다
    "M14-clock-unchecked": [
        ("                if (-not (Test-RemoteHelpScrubNumber $now)) { throw 'RhScrubStop:clock' }\n", ""),
    ],
    # 모델 M4 — 구조 재확인을 하지 않는다
    "M15-no-rescan": [
        ("            $found = Get-RemoteHelpStructStreams $rendered.Text $Tick\n", "            $found = @()\n"),
    ],
}

# 호출처 뮤턴트(독립 검증 좌석 5절 W1·W3·W5·W6 + 고침 1회의 H1·H2 되돌림) — 관문 판정기가 아니라 실물 보고·명령 함수를 태우는
# tests/review-1115-win.ps1(W9 행동 시험)로 잰다:  python3 tests/scrub-v3-win-mutants.py --suite review
CALLSITE = {
    "W1-report-env-array": [
        ("(Invoke-RemoteHelpScrubField $envText $script:RhNames 96000", "(Invoke-RemoteHelpScrubField $envText $script:RhNames.names 96000"),
    ],
    "W3-cmd-cut-same-line": [
        ("(Invoke-RemoteHelpScrubField $output $cmdNames 4096", "(Invoke-RemoteHelpScrubField (Get-RemoteHelpCutTail $output 4096) $cmdNames 4096"),
    ],
    "W5-report-overflow-false": [
        ("$script:RhNames = @{ names = $found.Names; overflow = $found.Overflow } }", "$script:RhNames = @{ names = $found.Names; overflow = $false } }"),
    ],
    "W6-cmd-cut-line-before": [
        ("    try { $cmdFound = Get-RemoteHelpNames $output $script:RhNames;", "    $output = Get-RemoteHelpCutTail $output 4096\n    try { $cmdFound = Get-RemoteHelpNames $output $script:RhNames;"),
    ],
    "H1-log-tail-before-scrub": [
        ("            else { $logText = (@(Get-Content -LiteralPath $LogFile -Encoding UTF8 -ErrorAction Stop) -join \"`n\") }",
         "            else { $logText = (@(Get-Content -LiteralPath $LogFile -Tail 200 -Encoding UTF8 -ErrorAction Stop) -join \"`n\") }"),
    ],
    "H2-cmd-no-reharvest": [
        ("$cmdNames = @{ names = $cmdFound.Names; overflow = $cmdFound.Overflow } }", "$cmdNames = $script:RhNames }"),
    ],
}


def callsite(only, log):
    src = (SRC / "bootstrap.ps1").read_bytes().decode("utf-8-sig").replace("\r\n", "\n")
    names = [m for m in CALLSITE if not only or m.split("-")[0] in only.split(",")]
    out = []
    for name in names:
        for old, _ in CALLSITE[name]:
            if src.count(old) != 1:
                print(f"ANCHOR {name}: 앵커가 {src.count(old)}번 걸림 — {old[:70]!r}")
                sys.exit(3)

    def run(text):
        with tempfile.TemporaryDirectory(prefix="scrub-v3-win-cs-") as tmp:
            dst = pathlib.Path(tmp) / "install-master"
            shutil.copytree(SRC, dst)
            (dst / "bootstrap.ps1").write_bytes(b"\xef\xbb\xbf" + text.encode("utf-8"))
            r = subprocess.run(["pwsh", "-NoProfile", "-File", str(HERE / "review-1115-win.ps1"), "-Dir", str(dst)], capture_output=True, text=True)
            fails = [x.strip()[:90] for x in r.stdout.splitlines() if x.startswith("  FAIL")]
            return r.returncode, fails

    rc0, f0 = run(src)
    out.append(f"BASELINE rc={rc0} FAIL={len(f0)}")
    print(out[-1], flush=True)
    if rc0 != 0:
        sys.exit(4)
    killed = 0
    for name in names:
        text = src
        for old, new in CALLSITE[name]:
            text = text.replace(old, new)
        rc, fails = run(text)
        killed += rc != 0
        out.append(f"{'KILLED' if rc != 0 else 'SURVIVED'} {name} rc={rc} · " + " | ".join(fails[:3]))
        print(out[-1], flush=True)
    out.append(f"호출처 뮤턴트 KILLED {killed}/{len(names)}")
    print(out[-1])
    if log:
        pathlib.Path(log).write_text("\n".join(out) + "\n", encoding="utf-8")
    sys.exit(0 if killed == len(names) else 1)


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--n", default="800")
    ap.add_argument("--only", default="")
    ap.add_argument("--log", default="")
    ap.add_argument("--suite", default="gates")
    a = ap.parse_args()
    if a.suite == "review":
        callsite(a.only, a.log)
    names = [m for m in MUTANTS if not a.only or m.split("-")[0] in a.only.split(",") or m in a.only.split(",")]
    src = (SRC / "bootstrap.ps1").read_bytes().decode("utf-8-sig").replace("\r\n", "\n")
    out_lines = []

    def say(line):
        print(line, flush=True)
        out_lines.append(line)

    for name in names:
        for old, _ in MUTANTS[name]:
            if src.count(old) != 1:
                say(f"ANCHOR {name}: 앵커가 {src.count(old)}번 걸림(1번이어야) — {old[:70]!r}")
                sys.exit(3)

    def run(text, label):
        with tempfile.TemporaryDirectory(prefix="scrub-v3-win-mut-") as tmp:
            dst = pathlib.Path(tmp) / "install-master"
            dst.mkdir()
            (dst / "bootstrap.ps1").write_bytes(b"\xef\xbb\xbf" + text.encode("utf-8"))
            started = time.time()
            r = subprocess.run(["node", str(HERE / "scrub-v3-win.mjs"), "--dir", str(dst), "--n", a.n], capture_output=True, text=True)
            took = time.time() - started
            tail = [x for x in r.stdout.splitlines() if x.startswith(("관문", "RESULT", "  ✗"))][:4]
            return r.returncode, took, tail

    rc0, took, tail = run(src, "baseline")
    say(f"BASELINE rc={rc0} {took:.0f}s · " + " | ".join(tail))
    if rc0 != 0:
        sys.exit(4)
    killed = 0
    for name in names:
        text = src
        for old, new in MUTANTS[name]:
            text = text.replace(old, new)
        rc, took, tail = run(text, name)
        verdict = "KILLED" if rc != 0 else "SURVIVED"
        killed += rc != 0
        say(f"{verdict} {name} rc={rc} {took:.0f}s · " + " | ".join(tail[1:] if len(tail) > 1 else tail))
    say(f"뮤턴트 KILLED {killed}/{len(names)}")
    if a.log:
        pathlib.Path(a.log).write_text("\n".join(out_lines) + "\n", encoding="utf-8")
    sys.exit(0 if killed == len(names) else 1)


if __name__ == "__main__":
    main()
