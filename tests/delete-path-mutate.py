#!/usr/bin/env python3
# 0.3.37(TICKET=installer-0337-delete-path) — 「되돌리면 붉어진다」: 제거기 사본에 한 줄씩 변이를 넣고 tests/delete-path-run.sh 가 적색인지 잰다.
#   ⚠원본은 건드리지 않는다 — 스크래치 사본(install-master 통째)만 고친다 · 원본 초록을 먼저 확인한다(거짓 적색 방지).
#   쓰는 법: python3 tests/delete-path-mutate.py [--only 이름,이름] [--os mac|win]  · rc 0 = 전건 KILLED
import os, shutil, subprocess, sys, tempfile

HERE = os.path.dirname(os.path.abspath(__file__))
SRC = os.path.abspath(os.path.join(HERE, "..", "install-master"))
RUN = os.path.join(HERE, "delete-path-run.sh")

# (이름, OS, 파일, 찾을 글자, 바꿀 글자) — 찾을 글자는 정확히 한 번 나와야 한다(아니면 변이 무효 = 실패로 센다)
MUTANTS = [
    ("sh-keep-dept-name", "mac", "reset-clean.sh",
     "-o -name 'pack-dept-*' -o -name 'claude-*' \\) -print0",
     "-o -name 'claude-*' \\) -print0"),
    ("sh-keep-hq-name", "mac", "reset-clean.sh",
     'HISTORY_KEEP_NAMES=".credentials.json\nprojects\n', 'HISTORY_KEEP_NAMES=".credentials.json\n'),
    ("sh-gate-off", "mac", "reset-clean.sh",
     'if [ "$ARCHIVE_FAIL" != "0" ]; then\n    [ "$KEPT_FAIL" -eq 0 ] && KEPT_FAIL=1',
     'if false; then\n    [ "$KEPT_FAIL" -eq 0 ] && KEPT_FAIL=1'),
    ("sh-stat-compare", "mac", "reset-clean.sh",
     '  after="$(tree_stat "$dest")"\n  if [ "$before" != "$after" ]; then\n    ARCHIVE_FAIL=1; ARCHIVE_VERIFY_FAIL=1; KEPT_FAIL=$((KEPT_FAIL+1))',
     '  after="$(tree_stat "$dest")"\n  if false; then\n    ARCHIVE_FAIL=1; ARCHIVE_VERIFY_FAIL=1; KEPT_FAIL=$((KEPT_FAIL+1))'),
    ("sh-same-volume", "mac", "reset-clean.sh",
     '  if ! same_volume "$AROOT" "$(dirname "$src")"; then', '  if false; then'),
    ("sh-mark-first", "mac", "reset-clean.sh",
     'if ! { printf \'%s\\0\' "$hname"; cat "$list"; } > "$AROOT/$RESTORE_MARK" 2>/dev/null; then',
     'if ! { printf \'%s\\0\' "$hname"; cat "$list"; } > /dev/null 2>/dev/null; then'),
    ("sh-resume-off", "mac", "reset-clean.sh",
     '  resume_unfinished_restore\n', '  : resume_unfinished_restore\n'),
    ("sh-restore-keep-left", "mac", "reset-clean.sh",
     '  if ! { cat "$left" > "$mark.tmp" && perl -e \'rename($ARGV[0], $ARGV[1]) or exit 1\' "$mark.tmp" "$mark"; } 2>/dev/null; then',
     '  rm -f "${mark:?}"; if false; then'),
    # r1 F2(master#0337b3fa) — 겹침을 옛 「건너뛰기」로 되돌림 · 지난 되옮기기를 못 끝냈는데 ~/.cys 를 또 옮김
    ("sh-overlap-skip", "mac", "reset-clean.sh",
     '      fail=1; printf \'%s\\0\' "$rel" >> "$left"\n      say "  🔴남음: $(short "$dst") — 같은', '      say "  🔴남음: $(short "$dst") — 같은'),
    ("sh-resume-left-guard", "mac", "reset-clean.sh",
     '  if [ "${RESUME_LEFT:-0}" = "1" ]; then', '  if false; then'),
    # r1 F3 — 표지를 제자리에 바로 덮어씀(임시 파일 + 이름 바꾸기를 뺌)
    ("sh-mark-inplace", "mac", "reset-clean.sh",
     'cat "$left" > "$mark.tmp" && perl -e \'rename($ARGV[0], $ARGV[1]) or exit 1\' "$mark.tmp" "$mark"', 'cat "$left" > "$mark"'),
    # r1 F5 — 맥 진단이 끝나지 않은 되옮기기를 찾은 자국으로 안 셈
    ("sh-diag-found", "mac", "reset-clean.sh",
     '    FOUND=$((FOUND+1))\n    say "  [있음] 끝나지 않은 되옮기기', '    say "  [있음] 끝나지 않은 되옮기기'),
    ("sh-restore-escape", "mac", "reset-clean.sh",
     '    case "$rel" in /*|..|../*|*/..|*/../*)\n', '    case "$rel" in //never//)\n'),
    # r1 F4 · agy F4 — 보관본 속 로그인 파일 정리 표지 · 진단 셈 · 이어 지우기 · 못 읽음을 없음으로
    ("sh-cred-mark-first", "mac", "reset-clean.sh", '  { : > "$1/$CRED_MARK"; } 2>/dev/null ||', '  false ||'),
    ("sh-cred-diag", "mac", "reset-clean.sh",
     '    FOUND=$((FOUND+1))\n    say "  [있음] 보관본 속 로그인', '    say "  [있음] 보관본 속 로그인'),
    ("sh-cred-resume-off", "mac", "reset-clean.sh", '  resume_archived_credentials\n', '  : resume_archived_credentials\n'),
    ("sh-cred-unread", "mac", "reset-clean.sh", '    if [ ! -x "$d" ]; then\n', '    if false; then\n'),
    ("ps-cred-mark-first", "win", "reset-clean.ps1", "    try { [System.IO.File]::WriteAllText((Join-Path $h $CredMark), '') } catch {", "    try { throw 'm' } catch {"),
    ("ps-cred-diag", "win", "reset-clean.ps1",
     "        $script:Found++\n        Write-Host ('  [있음] 보관본 속 로그인", "        Write-Host ('  [있음] 보관본 속 로그인"),
    ("ps-cred-resume-off", "win", "reset-clean.ps1", '    Resume-ArchivedCredentials\n', ''),
    ("ps-cred-unread", "win", "reset-clean.ps1", 'catch { $fi = $null; $unread = $true }', 'catch { $fi = $null }'),
    # r1 F1 — 설치 폴더 바로 아래 exe·dll 을 이름 꼴 전부로 되돌림
    ("ps-exe-all", "win", "reset-clean.ps1",
     '    if ($n -match $CysProgramExeRx) { return $true }', "    if ($n -match '(?i)\\.(exe|dll)$') { return $true }"),
    ("ps-residue-all", "win", "reset-clean.ps1",
     '    if ($n -match $CysProgramResidueRx) { return $true }', "    if ($n -match '(?i)\\.(exe|dll|pyd|node)\\.prev[0-9]*$') { return $true }"),
    # r1 F6 — 맥 완전 삭제에서 끄지 못한 cys 가 남아도 옮김 · ~/.cys 칸만 막음 풀기
    ("sh-proc-block", "mac", "reset-clean.sh",
     '  if [ -n "$CYS_ALIVE" ] && [ "$KEEP_APP" != "1" ]; then\n', '  if false; then\n'),
    ("sh-proc-cyshome", "mac", "reset-clean.sh",
     '  if [ "${PROC_BLOCKED:-0}" = "1" ]; then\n    :   # r1 F6 — cys 가 아직 돌고 있다: ~/.cys', '  if false; then\n    :   # r1 F6 — cys 가 아직 돌고 있다: ~/.cys'),
    # r2 N3 · N4 · N6 — 보관본 자체 못 들어감 · 정리 표지 못 치움 · 되옮길 자리 윗자리 바로가기
    ("sh-cred-home-unread", "mac", "reset-clean.sh", '  if [ -d "$1" ] && { [ ! -x "$1" ] || [ ! -r "$1" ]; }; then', '  if false; then'),
    ("sh-cred-home-noread", "mac", "reset-clean.sh", '  if [ -d "$1" ] && { [ ! -x "$1" ] || [ ! -r "$1" ]; }; then', '  if [ -d "$1" ] && [ ! -x "$1" ]; then'),
    ("sh-cred-mark-rmfail", "mac", "reset-clean.sh",
     '    if ! { rm -f "${1:?}/$CRED_MARK"; } 2>/dev/null || [ -e "$1/$CRED_MARK" ]; then', '    if false; then'),
    ("sh-restore-uplink", "mac", "reset-clean.sh", '    if [ -n "$_lnk" ]; then\n', '    if false; then\n'),
    ("ps-overlap-skip", "win", "reset-clean.ps1",
     "            $fail = $true; [void]$left.Add($rel)\n            Write-Host ('  [남음] ' + (Short $dst) + ' - 같은", "            Write-Host ('  [남음] ' + (Short $dst) + ' - 같은"),
    ("ps-resume-left-guard", "win", "reset-clean.ps1",
     '    if ($script:ResumeLeft) {', '    if ($false) {'),
    ("ps-mark-inplace", "win", "reset-clean.ps1",
     '    if (-not (Save-RestoreMark $mark $left.ToArray())) {', '    if (-not $(try { Write-RestoreMark $mark $left.ToArray(); $true } catch { $true })) {'),
    ("sh-prescan-p", "mac", "reset-clean.sh",
     '      if [ -n "$proots" ] && under_any "$t" "$proots"; then', '      if false; then'),
    ("sh-prescan-find-rc", "mac", "reset-clean.sh",
     '    if ! find "$r" -type l -print0 > "$lst" 2>/dev/null; then', '    if ! { find "$r" -type l -print0 > "$lst" 2>/dev/null; true; }; then'),
    ("sh-prescan-newline", "mac", "reset-clean.sh",
     '      case "$t$p" in *$\'\\n\'*) rm -f "${lst:?}"; PRESCAN_BAD="$(short "$p") (경로에 줄바꿈이 있습니다)"; return 1 ;; esac\n',
     ''),
    ("sh-note-off", "mac", "reset-clean.sh",
     '        PRESCAN_NOTE="${PRESCAN_NOTE}$(short "$p")\n"\n', '        :\n'),
    ("sh-cred-keep", "mac", "reset-clean.sh",
     '        [ -n "$CYS_HOME_ARCHIVED" ] && drop_archived_credentials "$CYS_HOME_ARCHIVED"\n', ''),
    # 후임 ⓑ(master#1cecc145) — 회차마다 기억한 자리를 다시 지우는지: 이번 회차에 옮긴 것만 보던 앞 판으로 되돌리면 적색
    ("sh-cred-retry", "mac", "reset-clean.sh",
     'drop_archived_credentials "$CYS_HOME_ARCHIVED"', 'drop_archived_credentials "$ARCHIVE_LAST"'),
    # 후임 ⓒ — 신뢰 칸 실패 깃발을 회차마다 다시 재는지
    ("sh-trust-remeasure", "mac", "reset-clean.sh",
     '  TRUST_CLEANUP_FAIL=0\n  read_trust_seed_record\n', '  read_trust_seed_record\n'),
    # 결정 ⑵ — 끝나지 않은 되옮기기 표지를 덮지 않는지
    # 맥 웹뷰(master#900d9f23) — 완전 삭제가 앱 화면 자료를 보관하는지
    ("sh-webview", "mac", "reset-clean.sh",
     '      archive_move "$HOME/Library/WebKit/com.cysjavis.terminal" "webview-webkit" "앱 화면 자료"', '      :'),
    ("sh-mark-guard", "mac", "reset-clean.sh",
     '  if [ -e "$AROOT/$RESTORE_MARK" ] || [ -L "$AROOT/$RESTORE_MARK" ]; then', '  if false; then'),
    ("sh-formation-only", "mac", "reset-clean.sh",
     '  elif [ "$KEEP_HISTORY" = "1" ] || [ "$KEEP_APP" = "1" ]; then\n    state_formation_archive\n  else',
     '  elif false; then\n    state_formation_archive\n  else'),
    # F8(master#cf29bfef 결정 A) — 앱 남김 단독을 옛 뜻(KEEP_HISTORY 만 봄)으로 되돌림: purge · 맥 진단 · 윈 진단 휴지통 줄
    ("sh-f8-keepapp-state", "mac", "reset-clean.sh",
     '  elif [ "$KEEP_HISTORY" = "1" ] || [ "$KEEP_APP" = "1" ]; then\n    state_formation_archive\n',
     '  elif [ "$KEEP_HISTORY" = "1" ]; then\n    state_formation_archive\n'),
    ("sh-f8-diag-state", "mac", "reset-clean.sh",
     '  if [ "$KEEP_HISTORY" = "1" ] || [ "$KEEP_APP" = "1" ]; then [ -d "$HOME/.local/state/cys" ];',
     '  if [ "$KEEP_HISTORY" = "1" ]; then [ -d "$HOME/.local/state/cys" ];'),
    ("sh-f8-diag-dept", "mac", "reset-clean.sh",
     '    if [ "$KEEP_HISTORY" = "1" ] || [ "$KEEP_APP" = "1" ]; then say "  [있음] 부서 실행 상태 · ',
     '    if [ "$KEEP_HISTORY" = "1" ]; then say "  [있음] 부서 실행 상태 · '),
    ("sh-f8-diag-trash", "mac", "reset-clean.sh",
     '    if [ "$KEEP_HISTORY" = "1" ] || [ "$KEEP_APP" = "1" ]; then say "  [있음] 닫은 부서 휴지통 · ',
     '    if [ "$KEEP_HISTORY" = "1" ]; then say "  [있음] 닫은 부서 휴지통 · '),
    ("sh-dept-state", "mac", "reset-clean.sh",
     '      archive_move "$_ds" "cys-dept-state/$(basename "$_ds")" "부서 실행 상태"', '      :'),
    ("sh-ask-again", "mac", "reset-clean.sh",
     'notice_close_cys\n# 0.3.37: 「지웁니다」 입력을 묻지 않는다',
     'notice_close_cys\nread -r answer < /dev/tty || answer=""\n# 0.3.37: 「지웁니다」 입력을 묻지 않는다'),
    ("sh-retry-cap", "mac", "reset-clean.sh",
     'while [ "$rc" -ne 0 ] && [ "$tries" -lt 2 ]; do', 'while [ "$rc" -ne 0 ] && [ "$tries" -lt 3 ]; do'),
    ("sh-split-loc-only", "mac", "reset-clean.sh",
     '  if [ -L "$p" ]; then\n    prune_keep_hit "$c" "$pk" && return 0',
     '  if [ -L "$p" ]; then\n    prune_keep_hit "$c" "$pk$hk" && return 0'),
    ("sh-minor-loc", "mac", "reset-clean.sh",
     '    [ -n "$loc" ] && prune_keep_hit "$loc" "$pk" && return 0',
     '    [ -n "$hk" ] && [ -n "$loc" ] && prune_keep_hit "$loc" "$pk" && return 0'),
    ("sh-fallback-note-to-bad", "mac", "reset-clean.sh",
     '        if [ -n "$nested" ]; then rm -f "${lst:?}"; PRESCAN_BAD=', '        if false; then rm -f "${lst:?}"; PRESCAN_BAD='),
    ("sh-fallback-dept", "mac", "reset-clean.sh",
     '        drop_dir "$HOME/.cys" "$HIST_KEEPS$DEPT_KEEPS"', '        drop_dir "$HOME/.cys" "$HIST_KEEPS"'),
    ("sh-claude-link", "mac", "reset-clean.sh",
     '  if [ -L "$HOME/.cys/claude" ]; then\n    KEPT_FAIL=$((KEPT_FAIL+1))',
     '  if false; then\n    KEPT_FAIL=$((KEPT_FAIL+1))'),
    # master#bc5fb4f6 ⑨ — 떼기 첫 칸의 「기계 자리 0」 단언이 실제로 거는지: 떼는 함수 안에 기계 자리 명령이 들어오면 적색이어야 한다
    ("sh-guard-bites", "mac", "reset-clean.sh",
     'same_volume() { local a b;', 'same_volume() { : launchctl print gui; local a b;'),
    # ── 윈 — 전임 서브에이전트 사본 측정 16 을 구동기로 옮김(HANDOFF-0337 §6) + 후임 수정 5 ──
    ("ps-keep-hq-name", "win", "reset-clean.ps1",
     "$HistoryKeepNames = @('.credentials.json', 'projects', 'history.jsonl'", "$HistoryKeepNames = @('.credentials.json', 'history.jsonl'"),
    ("ps-keep-dept-name", "win", "reset-clean.ps1",
     "'dept-snapshots', 'pack-dept-*', 'claude-*')", "'dept-snapshots', 'claude-*')"),
    ("ps-gate-off", "win", "reset-clean.ps1",
     'if (($script:ArchiveFail -ne 0) -or ($script:ArchiveVerifyFail -ne 0)) {', 'if ($false) {'),
    ("ps-read-host", "win", "reset-clean.ps1",
     "# ── 「cys 를 곧 끕니다」 (v0.3.10", "$null = Read-Host '지웁니다'\n# ── 「cys 를 곧 끕니다」 (v0.3.10"),
    ("ps-same-volume", "win", "reset-clean.ps1",
     '    if (-not (Test-SameVolume $script:ARoot (Split-Path -Parent $src))) {', '    if ($false) {'),
    ("ps-uninst-key-loc", "win", "reset-clean.ps1",
     "function Test-OurUninstallKey($key) {   # 설치 목록 항목이 우리 설치 자리를 가리키는가(InstallLocation 또는 UninstallString 의 uninstall.exe 자리)\n",
     "function Test-OurUninstallKey($key) {\n    return $true\n"),
    ("ps-prescan-p", "win", "reset-clean.ps1",
     '            if (Test-UnderAny $t $proots) {', '            if ($false) {'),
    ("ps-mark-first", "win", "reset-clean.ps1",
     '    try { Write-RestoreMark $markPath (@($hname) + @($list)) }', '    try { $null = 0 }'),
    ("ps-cred-keep", "win", "reset-clean.ps1",
     '                    if ($script:CysHomeArchived) { Remove-ArchivedCredentials $script:CysHomeArchived }\n', ''),
    ("ps-lnk-target", "win", "reset-clean.ps1",
     "        if (-not (Test-OurExe $t)) { Write-Host ('  남김: ' + (Short $lnk) + ' - 우리 설치 자리를 가리키지 않아 손대지 않았습니다.'); continue }\n", ''),
    ("ps-split-loc-only", "win", "reset-clean.ps1",
     '        if (Test-KeepHit $c $keeps) { return $true }\n        if ($loc -and (Test-KeepHit $loc $keeps)) { return $true }',
     '        if (Test-KeepHit $c (@($keeps) + @($hkeeps))) { return $true }\n        if ($loc -and (Test-KeepHit $loc $keeps)) { return $true }'),
    ("ps-verify-sticky", "win", "reset-clean.ps1",
     '    $script:Archived = 0\n}', '    $script:Archived = 0\n    $script:ArchiveVerifyFail = 0\n}'),
    ("ps-uninstaller-run", "win", "reset-clean.ps1",
     'if ((Test-Path $UninstExe) -and $UseUninstaller) {', 'if (Test-Path $UninstExe) {'),
    ("ps-treestat-link", "win", "reset-clean.ps1",
     '                if (($i.Attributes -band [System.IO.FileAttributes]::ReparsePoint) -ne 0) { $n++; continue }\n', ''),
    ("ps-desktop-links", "win", "reset-clean.ps1",
     "foreach ($c in @((Join-Path $d 'cys.lnk'), (Join-Path $d 'cysr.lnk'))) {", "foreach ($c in @((Join-Path $d 'cys.lnk'))) {"),
    ("ps-dept-state", "win", "reset-clean.ps1",
     "[void](Archive-Move (Join-Path $dir $k.Name) ('cys-dept-state\\' + $k.Name) '부서 실행 상태'); continue }", "continue }"),
    ("ps-claude-link", "win", "reset-clean.ps1",
     "    if (Test-IsReparsePath (Join-Path $CysHome 'claude')) {", '    if ($false) {'),
    ("ps-cred-retry", "win", "reset-clean.ps1",
     'if ($script:CysHomeArchived) { Remove-ArchivedCredentials $script:CysHomeArchived }', 'if ($script:ArchiveLast) { Remove-ArchivedCredentials $script:ArchiveLast }'),
    ("ps-reg-guard", "win", "reset-clean.ps1",
     "function Invoke-OurRegistryCleanup {\n    # 0.3.37: 남겨야", "function Invoke-OurRegistryCleanup {\n    $script:PreserveCanonFail = @()\n    # 0.3.37: 남겨야"),
    ("ps-trust-remeasure", "win", "reset-clean.ps1",
     '    $script:TrustCleanupFail = 0\n    $script:TrustSeedRows = @(Read-TrustSeedRecord)', '    $script:TrustSeedRows = @(Read-TrustSeedRecord)'),
    ("ps-mark-guard", "win", "reset-clean.ps1",
     '    if (Test-PathOrLink $markPath) {', '    if ($false) {'),
    ("ps-f8-diag-trash", "win", "reset-clean.ps1",
     "        if ($KeepApp -or $KeepHistory) { Write-Host ('  [있음] 닫은 부서 휴지통 · '", "        if ($KeepHistory) { Write-Host ('  [있음] 닫은 부서 휴지통 · '"),
]

def run(d, os_):
    r = subprocess.run(["bash", RUN, "--dir", d, "--only", os_], capture_output=True, text=True)
    return r.returncode, r.stdout

def main():
    only = None; os_filter = None
    a = sys.argv[1:]
    if "--only" in a: only = set(a[a.index("--only") + 1].split(","))
    if "--os" in a: os_filter = a[a.index("--os") + 1]
    muts = [m for m in MUTANTS if (only is None or m[0] in only) and (os_filter is None or m[1] == os_filter)]
    for os_ in sorted({m[1] for m in muts}):
        rc, out = run(SRC, os_)
        if rc != 0:
            print(f"원본이 초록이 아니다({os_}) — 변이를 잴 수 없다\n" + out[-1500:]); return 2
        print(f"원본 초록 확인({os_})")
    killed = 0; bad = []
    for name, os_, fn, old, new in muts:
        tmp = tempfile.mkdtemp(prefix="dpmut-")
        try:
            d = os.path.join(tmp, "install-master"); shutil.copytree(SRC, d)
            p = os.path.join(d, fn); s = open(p, encoding="utf-8").read()
            if s.count(old) != 1:
                print(f"  INVALID  {name} (찾을 글자 {s.count(old)}번)"); bad.append(name); continue
            open(p, "w", encoding="utf-8").write(s.replace(old, new))
            rc, out = run(d, os_)
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
