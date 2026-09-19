#!/usr/bin/env python3
# 완료 직후 재실행 시험(tests/rerun-after-done-run.sh)의 축이 **정말 무는가** — TICKET=installer-0326 C1.
#
# 판정 순서(뮤턴트마다): ①원본 사본에서 시험이 전건 초록 ②변이가 찾을 글자에 정확히 1번 걸렸다(적용 확인 먼저 —
#   안 걸린 변이의 「초록」은 측정 실패다) ③기대한 축이 붉다 ④붉어진 축이 기대 집합 안에 있다(곁가지 적색 = 킬 아님).
# ⛔원본은 건드리지 않는다 — install-master 를 임시 폴더로 떠서 거기에만 변이를 건다.
# 쓰는 법: python3 tests/rerun-after-done-mutate.py [install-master 경로]   · rc 0 = 전건 통과
import os, re, shutil, subprocess, sys, tempfile

HERE = os.path.dirname(os.path.abspath(__file__))
SRC = os.path.abspath(sys.argv[1] if len(sys.argv) > 1 else os.path.join(HERE, '..', 'install-master'))
RUN = os.path.join(HERE, 'rerun-after-done-run.sh')

# (id, 찾을 글자, 바꿀 글자, 기대 적색 축의 머리 표지 목록)
MUTANTS = [
    ('R1', "        $doneWhy = Test-RecentInstallDone ([datetimeoffset]::Now)\n",
           "        $doneWhy = ''\n", ['[ⓔ]']),
    ('R2', "$RerunDoneWindowSec = 600 ", "$RerunDoneWindowSec = 6000 ", ['[ⓑ] 601초', '[ⓒ] 옛 판 성공 끝맺음 700초', '[ⓕ]']),   # ⓕ(11분 묵은 표지)도 6000초 창 안이라 함께 붉는 것이 맞다
    ('R3', "    $script:ShowRerun = $false\n    Write-InstallDoneMark\n}", "    $script:ShowRerun = $false\n}", ['[ⓐ] install-done.txt']),
    ('R4', "    try { return @(& claude @args 2>$null) } catch {\n        try { Write-Log ('claude call failed (' + ($args -join ' ') + '): ' + $_.Exception.GetType().Name) } catch { }\n    }",
           "    return @(& claude @args 2>$null)", ['[ⓓ] 안전 호출', '[ⓓ] ~/.local', '[ⓓ] 대신 부른', '[ⓖ]']),
    ('R5', "if ($ln -match '^(\\S+)\\s+다음에 할 일: 없습니다 — 설치가 끝났습니다') {",
           "if ($ln -match '^(\\S+)\\s+다음에 할 일: 없습니다 — 설치가 끝났다') {", ['[ⓒ] 옛 판 성공 끝맺음 2초']),
    ('R6', "        $cver = (Invoke-ClaudeCli --version | Select-Object -First 1)",
           "        $cver = (& claude --version 2>$null | Select-Object -First 1)", ['[ⓖ]']),
    ('R7', "            if (($age -ge 0) -and ($age -le $RerunDoneWindowSec)) { return ('mark ' + [int]$age + 's') }",
           "            if ($age -le $RerunDoneWindowSec) { return ('mark ' + [int]$age + 's') }", ['[ⓑ] 표지가 미래']),
    ('R8', "    if (($Mode -eq 'full') -and ($env:JARVIS_ENTRY -ne 'reinstall')) {", "    if (($Mode -eq 'never') -and ($env:JARVIS_ENTRY -ne 'reinstall')) {", ['[ⓔ]']),
    ('R9', "    if (($Mode -eq 'full') -and ($env:JARVIS_ENTRY -ne 'reinstall')) {", "    if ($Mode -eq 'full') {", ['[ⓗ]']),
]

def run(d):
    p = subprocess.run(['bash', RUN, '--dir', d], capture_output=True, text=True, timeout=900)
    red = [m.group(1) for m in re.finditer(r'^  FAIL (.*?)  ← ', p.stdout, re.M)]
    return p.returncode, red, p.stdout

passed = failed = 0
def ck(ok, name, why=''):
    global passed, failed
    if ok: passed += 1; print('  ok   ' + name)
    else: failed += 1; print('  FAIL ' + name + '  ← ' + why[:300])

tmp = tempfile.mkdtemp()
try:
    base = os.path.join(tmp, 'orig'); shutil.copytree(SRC, base)
    rc, red, out = run(base)
    ck(rc == 0 and not red, '[원본] 시험 전건 초록', '|'.join(red) or out[-300:])
    for mid, old, new, want in MUTANTS:
        d = os.path.join(tmp, mid); shutil.copytree(SRC, d)
        f = os.path.join(d, 'bootstrap.ps1')
        t = open(f, encoding='utf-8', newline='').read()
        n = t.count(old)
        ck(n == 1, '[%s] 변이 적용 = 찾을 글자 정확히 1곳' % mid, 'count=%d' % n)
        if n != 1: continue
        open(f, 'w', encoding='utf-8', newline='').write(t.replace(old, new))
        rc, red, out = run(d)
        hit = [w for w in want if any(r.startswith(w) for r in red)]
        ck(rc != 0 and len(hit) >= 1, '[%s] 기대 축이 붉다(%s)' % (mid, ' · '.join(want)), 'red=' + '|'.join(red))
        stray = [r for r in red if not any(r.startswith(w) for w in want)]
        ck(not stray, '[%s] 곁가지 적색 0' % mid, '|'.join(stray))
finally:
    shutil.rmtree(tmp, ignore_errors=True)
print('통과 %d · 실패 %d' % (passed, failed))
sys.exit(0 if failed == 0 and passed > 0 else 1)
