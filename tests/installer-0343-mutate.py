#!/usr/bin/env python3
# installer-0343 변이 시험 — 고친 자리를 하나씩 되돌린 사본에서 두 행동 시험(윈 installer-0343-run.sh · 맥 installer-0343-mac-run.sh)이 붉어지는가.
#   과잉 변이(P8 · 안전 연결 판정을 늘 참으로)도 넣는다 — 새 갈래가 J-DL-07 을 삼키면 대조군이 잡아야 한다.
# 쓰는 법: python3 tests/installer-0343-mutate.py   · rc 0 = 변이 전부 잡힘 · 1 = 놓친 변이 있음 · 2 = 측정 무효
import pathlib, subprocess, sys, tempfile
here = pathlib.Path(__file__).resolve().parent
im = here.parent / 'install-master'
WIN = [
    ('P1 종료 코드 갈래의 J-NET-04 끄기',
     "if ((-not (Test-Path -LiteralPath $rcExe)) -and (Test-ClaudeTlsTrustFail)) {", "if ((-not (Test-Path -LiteralPath $rcExe)) -and $false) {"),
    ('P2 명령 안 잡힘 갈래의 J-NET-04 끄기',
     "        if (($hasExe -eq '아니오') -and (Test-ClaudeTlsTrustFail)) {", "        if (($hasExe -eq '아니오') -and $false) {"),
    ('P3 점검 문구가 claude.ai 실패를 안 말함(「닿았습니다」 오해 되살림)',
     "    if ($script:InstallUrlProbe -eq 'fail')  { return", "    if ($false)  { return"),
    ('P4 7 판 안쪽 예외(AuthenticationException) 낱말 빼기',
     "|AuthenticationException|", "|"),
    ('P4b 윈 실측 문구(트러스트 관계) 빼기',
     "'트러스트 관계|trust relationship|", "'trust relationship|"),
    ('P5 J-DL-08 갈래 끄기(코드 없이 rc 5 되살림)',
     "    if (@($script:DlShort).Count -ge 2) {", "    if ($false) {"),
    ('P6 화면 용량 손글씨 되살림',
     "(약 ${dlMB}MB · 잠시 걸립니다)", "(약 132MB · 잠시 걸립니다)"),
    ('P7 J-APP-02 지우기(코드 없이 rc 8 되살림)',
     "        Write-JCode 'J-APP-02' '자비스 바탕 프로그램이 준비됐는데 답하지 않습니다'\n", ""),
    ('P8 과잉: 안전 연결 판정을 늘 참으로(J-DL-07 삼킴)',
     "    if ($script:InstallUrlProbe -eq 'trust') { return $true }", "    return $true"),
]
MAC = [
    ('S1 1-7 안전 연결 판정 끄기',
     'if tls_trust_words < "$uerr"; then', 'if false; then'),
    ('S2 종료 코드 갈래의 J-NET-04 끄기',
     '    elif [ ! -x "$HOME/.local/bin/claude" ] && claude_tls_trust_fail; then', '    elif false; then'),
    ('S3 점검 문구가 claude.ai 실패를 안 말함',
     "    fail)  printf '%s' 'claude.ai 에는 설치 시작 전에도 닿지 못했습니다 · downloads.claude.ai 는 ' ;;\n", ""),
    ('S4 J-DL-08 갈래 끄기',
     'if [ "$dl_short_n" -ge 2 ]', 'if [ "$dl_short_n" -ge 9 ]'),
    ('S5 J-APP-02 지우기',
     '    jcode "J-APP-02" "자비스 바탕 프로그램이 준비됐는데 답하지 않습니다"\n', ''),
    ('S6 화면 용량을 손글씨로',
     '(약 $((CYS_MAC_BYTES / 1000000))MB · 잠시 걸립니다)', '(약 132MB · 잠시 걸립니다)'),
]
def base_ok(cmd):
    r = subprocess.run(cmd, capture_output=True, text=True)
    if r.returncode != 0:
        print('FAIL 측정 무효: 원본이 붉다 ' + ' '.join(cmd) + '\n' + r.stdout[-800:]); sys.exit(2)
base_ok(['bash', str(here / 'installer-0343-run.sh')])
base_ok(['bash', str(here / 'installer-0343-mac-run.sh')])
missed = 0
with tempfile.TemporaryDirectory() as d:
    for kind, muts, fname in (('win', WIN, 'bootstrap.ps1'), ('mac', MAC, 'bootstrap.sh')):
        src = (im / fname).read_text(encoding='utf-8')
        for name, old, new in muts:
            if src.count(old) != 1:
                print('FAIL 측정 무효: 변이 자리를 1곳으로 못 찾았다(%d) — %s' % (src.count(old), name)); sys.exit(2)
            dd = pathlib.Path(d) / name.split()[0]; dd.mkdir()
            (dd / fname).write_text(src.replace(old, new), encoding='utf-8')
            if kind == 'win':
                r = subprocess.run(['bash', str(here / 'installer-0343-run.sh'), str(dd / fname)], capture_output=True, text=True)
                hit = r.returncode == 1
            else:
                r = subprocess.run(['bash', str(here / 'installer-0343-mac-run.sh'), '--dir', str(dd)], capture_output=True, text=True)
                hit = r.returncode != 0 and 'FAIL' in r.stdout
            if hit: print('잡힘  ' + name)
            else: print('놓침  ' + name + ' (rc=' + str(r.returncode) + ')\n' + r.stdout[-400:]); missed += 1
n = len(WIN) + len(MAC)
print(('PASS 변이 %d개 전부 잡힘' % n) if missed == 0 else ('FAIL 놓친 변이 %d개' % missed))
sys.exit(1 if missed else 0)
