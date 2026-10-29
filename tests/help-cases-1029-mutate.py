#!/usr/bin/env python3
# help-cases-1029 변이 시험 — 고친 자리를 하나씩 되돌린 사본에서 tests/help-cases-1029-run.sh 가 붉어지는가(시험이 진짜로 그 자리를 재는가).
# 쓰는 법: python3 tests/help-cases-1029-mutate.py   · rc 0 = 변이 전부 잡힘 · 1 = 놓친 변이 있음 · 2 = 측정 무효
import pathlib, subprocess, sys, tempfile
here = pathlib.Path(__file__).resolve().parent
src = (here.parent / 'install-master/bootstrap.ps1').read_text(encoding='utf-8')
run = here / 'help-cases-1029-run.sh'
MUT = [
    ('M1 파일 없음+실패 말 갈래 끄기(J-PATH-01 오진 되살림)',
     "        if (($hasExe -eq '아니오') -and $instFail) {", "        if (($hasExe -eq '아니오') -and $false) {"),
    ('M2 백신 근거를 늘 참으로(백신 단정 되살림)',
     "        $avEvidence = ([bool]$avShown) -or", "        $avEvidence = $true -or ([bool]$avShown) -or"),
    ('M3 대기 바퀴에서 사람·브라우저 재기 빼기',
     "                    Update-LoginPresence $pres\n", ""),
    ('M4 사람 입력 0 을 away 로 안 가르기',
     "    if ($pr.InputCount -eq 0) { return @{ Tag = 'away'", "    if ($false) { return @{ Tag = 'away'"),
    ('M5 브라우저 줄을 보고에 되살림(승인 밖 수집 · 0.3.43 결정)',
     "        ('기다리는 동안 키보드·마우스 사용(이 컴퓨터 전체): ' + $info.Input)\n",
     "        ('기다리는 동안 키보드·마우스 사용(이 컴퓨터 전체): ' + $info.Input),\n        ('브라우저: ' + $info.Browser)\n"),
    ('M6 입력 횟수를 보내는 값에 되살림',
     "$in = if ($pr.InputCount -gt 0) { '있었다' }", "$in = if ($pr.InputCount -gt 0) { ('있었다(' + $pr.InputCount + '번)') }"),
]
base = subprocess.run(['bash', str(run)], capture_output=True, text=True)
if base.returncode != 0:
    print('FAIL 측정 무효: 원본이 붉다\n' + base.stdout[-800:]); sys.exit(2)
missed = 0
with tempfile.TemporaryDirectory() as d:
    for name, old, new in MUT:
        if src.count(old) != 1:
            print('FAIL 측정 무효: 변이 자리를 1곳으로 못 찾았다 — ' + name); sys.exit(2)
        f = pathlib.Path(d) / 'bootstrap.ps1'
        f.write_text(src.replace(old, new), encoding='utf-8')
        r = subprocess.run(['bash', str(run), str(f)], capture_output=True, text=True)
        if r.returncode == 1: print('잡힘  ' + name)
        else: print('놓침  ' + name + ' (rc=' + str(r.returncode) + ')\n' + r.stdout[-400:]); missed += 1
print(('PASS 변이 %d개 전부 잡힘' % len(MUT)) if missed == 0 else ('FAIL 놓친 변이 %d개' % missed))
sys.exit(1 if missed else 0)
