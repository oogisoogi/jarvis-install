#!/usr/bin/env python3
# 뮤턴트 — 재설치 길 로그인·이전 대화 남기기(0.3.36 · TICKET=installer-login-keep)가 「실제로 서 있는가」를 잰다.
#   변이 하나씩 install-master 사본에 넣고 tests/login-keep-run.sh 를 돌려 **적색**(rc≠0)이면 KILLED.
#   바깥에 닿지 않는다 — 사본·시험 모두 mktemp 안(시험 자체의 규율 = login-keep-run.sh 머리 주석).
# 쓰는 법: python3 tests/login-keep-mutate.py [--jobs N] [--only a,b] [--timeout 초]   · rc 0 = 전부 KILLED
#   --timeout = 뮤턴트 한 칸의 시한(기본 900) · 넘으면 그 칸만 TIMEOUT 으로 적고 나머지를 계속 잰다(TIMEOUT 은 KILLED 가 아니다 → rc 1).
import os, shutil, signal, subprocess, sys, tempfile
from concurrent.futures import ThreadPoolExecutor

HERE = os.path.dirname(os.path.abspath(__file__))
SRC = os.path.join(HERE, '..', 'install-master')
RUN = os.path.join(HERE, 'login-keep-run.sh')
RP, RS, RIP, RIS, BP = 'reset-clean.ps1', 'reset-clean.sh', 'reinstall.ps1', 'reinstall.sh', 'bootstrap.ps1'

# (이름, 파일, 찾을 글, 바꿀 글, 적색이어야 할 칸의 글 조각)
MUTANTS = [
    ('ps1-keep-projects-drop', RP, "'.credentials.json', 'projects', 'history.jsonl'", "'.credentials.json', 'history.jsonl'", '[윈] 남길 다섯 자리'),
    ('ps1-keep-cred-drop', RP, "@('.credentials.json', 'projects'", "@('projects'", '[윈] 남길 다섯 자리'),
    ('ps1-flag-ignored', RP, "if ($KeepHistory -and $agoraMigrateOk) {", "if ($agoraMigrateOk) {", '[윈] ⓑⓒ'),
    ('ps1-fail-as-absent', RP, "if (-not $c) { $fail += $p; continue }", "if (-not $c) { continue }", '[윈] 실경로를 못 풀면'),
    ('ps1-location-drop', RP, "        $canon += $at\n", "", '[윈] 바로가기 자체가 남고'),
    ('ps1-diag-old-line', RP, "        if ($KeepHistory) {\n            # 0.3.36: 재설치 길에서는 이 로그인을 남긴다", "        if ($false) {\n            # 0.3.36: 재설치 길에서는 이 로그인을 남긴다", '[윈] ⓓ 재설치 길 화면'),
    ('reinstall-ps1-no-flag', RIP, "-File $ResetFile -KeepApp -KeepHistory -Yes", "-File $ResetFile -KeepApp -Yes", '[정적] ⓛ 윈 재설치'),
    ('bootstrap-plan-flip', BP, "    if ($a -gt $b) { return 'copy:older' }", "    if ($a -lt $b) { return 'copy:older' }", '[윈] 남은 동료 로그인'),
    ('sh-keep-projects-drop', RS, 'HISTORY_KEEP_NAMES=".credentials.json\nprojects\n', 'HISTORY_KEEP_NAMES=".credentials.json\n', '[맥] ⓗ 재설치 길'),
    ('sh-flag-ignored', RS, '    if [ "$KEEP_HISTORY" = "1" ] && ! history_keeps; then', '    if ! history_keeps; then', '[맥] ⓘ-2'),
    # (뺀 변이) sh-flag-ignored-2 = elif 조건을 참으로 — 표지가 없으면 HIST_KEEPS 가 늘 비어 동작이 같다(동치 변이 · 09-26 재측에서 확인).
    ('ps1-ancestor-link-ok', RP, "            if ($clash) { $fail += $p; continue }", "            if ($false) { $fail += $p; continue }", '[윈] pack 을 가리키는'),
    ('sh-ancestor-link-ok', RS, '      if [ "$c" != "$pc/$real" ] && root_clash "$c" "$roots"; then', '      if false; then', '[맥] ⓛ-2'),
    ('ps1-inner-link-loc', RP, " -or (Test-KeepHit (Get-ItemLoc $it $rootLiteral $rootCanon) $keeps)) { continue }\n        try { Remove-OneItem", ") { continue }\n        try { Remove-OneItem", '[윈] 남길 폴더 안 바로가기'),
    ('sh-inner-link-loc', RS, '    [ -L "$p" ] && [ "${p#"$root"/}" != "$p" ] && prune_keep_hit "$root_canon${p#"$root"}" "$keeps" && continue\n    why=', '    why=', '[맥] ⓟ'),
    ('sh-parse-drop', RS, '    --keep-history)   KEEP_HISTORY=1 ;;\n', '', '[정적] ⓛ 지우개가 표지를'),
    ('sh-keeps-not-passed', RS, 'drop_dir "$HOME/.cys" "$HIST_KEEPS"', 'drop_dir "$HOME/.cys"', '[맥] ⓗ 재설치 길'),
    ('sh-fail-as-absent', RS, '  [ -z "$HIST_KEEP_BAD" ]\n}', '  true\n}', '[맥] ⓚ'),
    ('sh-location-drop', RS, '      HIST_KEEPS="${HIST_KEEPS}${pc}/${real}\n"\n', '', '[맥] ⓙ'),
    ('reinstall-sh-arm-only', RIS, 'bash "$RESET_FILE" --yes --keep-history $KEEP_APP_ARG', 'bash "$RESET_FILE" --yes $KEEP_APP_ARG', '[정적] ⓛ 맥 재설치'),
]

def run(m):
    name, f, old, new, want = m
    d = tempfile.mkdtemp(prefix='lkmut-')
    try:
        dst = os.path.join(d, 'install-master')
        shutil.copytree(SRC, dst)
        p = os.path.join(dst, f)
        enc = 'utf-8-sig' if f.endswith('.ps1') else 'utf-8'
        s = open(p, encoding=enc).read()
        if s.count(old) != 1:
            return (name, 'ANCHOR', f'찾을 글 {s.count(old)}곳')
        open(p, 'w', encoding=enc).write(s.replace(old, new))
        # 시한을 넘으면 그 칸만 TIMEOUT(09-26 01:4x 실측: 잡지 않으면 한 칸 시간 초과에 전체가 결과 0줄로 죽었다).
        #   프로세스 묶음째 끊는다 — 손자(pwsh 등)가 출력 관을 쥐고 있으면 자식만 죽여서는 기다림이 안 끝나고 고아가 남는다.
        pr = subprocess.Popen(['bash', RUN, '--dir', dst], stdout=subprocess.PIPE, stderr=subprocess.PIPE, text=True, start_new_session=True)
        try:
            out, _ = pr.communicate(timeout=TIMEOUT)
        except subprocess.TimeoutExpired:
            try:
                os.killpg(pr.pid, signal.SIGKILL)
            except ProcessLookupError:
                pass
            pr.communicate()
            return (name, 'TIMEOUT', f'{TIMEOUT}초 시한 초과 — 판정 못 함(KILLED 아님)')
        r = subprocess.CompletedProcess(pr.args, pr.returncode, out, '')
        fails = [l for l in r.stdout.splitlines() if l.lstrip().startswith('FAIL')]
        hit = any(want in l for l in fails)
        if r.returncode != 0 and hit:
            return (name, 'KILLED', f'적색 {len(fails)}칸')
        return (name, 'SURVIVED', f'rc={r.returncode} · 노린 칸 적색={hit} · 적색 {len(fails)}칸')
    finally:
        shutil.rmtree(d, ignore_errors=True)

ONLY = sys.argv[sys.argv.index('--only') + 1].split(',') if '--only' in sys.argv else None
TIMEOUT = int(sys.argv[sys.argv.index('--timeout') + 1]) if '--timeout' in sys.argv else 900

def main():
    # 원본이 먼저 초록이어야 뮤턴트 적색이 뜻을 가진다(적대 1R 지적 — 시간 초과로 붉어진 칸을 KILLED 로 세지 않게).
    r0 = subprocess.run(['bash', RUN, '--dir', SRC], capture_output=True, text=True, timeout=1800)
    if r0.returncode != 0:
        print('원본이 초록이 아니다 — 뮤턴트를 재지 않는다'); print(r0.stdout[-2000:]); return 2
    jobs = 4
    if '--jobs' in sys.argv:
        jobs = int(sys.argv[sys.argv.index('--jobs') + 1])
    todo = [m for m in MUTANTS if not ONLY or m[0] in ONLY]
    with ThreadPoolExecutor(max_workers=jobs) as ex:
        res = list(ex.map(run, todo))
    bad = 0
    for name, v, why in res:
        print(f'  {v:8s} {name}  ({why})')
        if v != 'KILLED':
            bad += 1
    print(f'\n{len(res) - bad}/{len(res)} KILLED')
    return 1 if bad else 0

if __name__ == '__main__':
    sys.exit(main())
