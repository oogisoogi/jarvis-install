#!/usr/bin/env python3
"""원격 해결(help-s2) 윈도우 축 — PowerShell 이 없는 맥에서 bootstrap.ps1 을 **정적으로** 잰다(+ 맥판과 글자 대조).

⚠정적 검사가 증명하는 것은 「그 자리에 그 글이 그 순서로 있는가」까지다. 실행 성질 — 정션·8.3 이름 해소,
  5.1 의 JSON 형 변환, Start-Job 시간 상한, 핸들 읽기 러너, Mutex, 창 닫힘 때 멈춤 — 은 **윈도우 실기 몫**이다(내부 문서 「실기 필요 축」).
★맥판(bootstrap.sh)은 같은 계약을 실제로 부르는 시험(tests/remote-help-run.sh)이 잰다. 이 파일은 윈도우판이
  같은 자리에 같은 관문을 두었는지를 재고, 뮤턴트로 「그 관문을 지우면 이 검사가 빨개지는가」를 잰다.

쓰는 법
  python3 tests/remote-help-ps1-static.py              검사 · rc 0 = 전건 통과
  python3 tests/remote-help-ps1-static.py --mutants    윈도우판 사본을 한 자리씩 망가뜨려 그 자리의 검사가 빨개지는지
"""
import os
import re
import shutil
import subprocess
import sys
import tempfile

HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.dirname(HERE)
PS = os.path.join(ROOT, "install-master", "bootstrap.ps1")
SH = os.path.join(ROOT, "install-master", "bootstrap.sh")
TABLE = os.path.join(ROOT, "install-master", "command-table.json")
BALANCE = os.path.join(HERE, "ps-balance.py")


def region(src):
    a = src.find("# ── 원격 해결 (help-s2)")
    b = src.find("# 시험이 이 파일을 「함수 묶음」으로만 읽는 문", a)
    return src[a:b] if a >= 0 and b > a else ""


def code(text):
    return "\n".join(line for line in text.split("\n") if not line.lstrip().startswith("#"))


def fn(src, name):
    m = re.search(r"^function " + re.escape(name) + r"\b.*?(?=^function |^# 시험이 이 파일을|\Z)", src, re.S | re.M)
    return m.group(0) if m else ""


def ordered(text, *marks):
    pos = [text.find(m) for m in marks]
    return all(p >= 0 for p in pos) and pos == sorted(pos) and len(set(pos)) == len(pos)


def checks(path):
    raw = open(path, "rb").read()
    src = raw.decode("utf-8-sig")
    sh = open(SH, encoding="utf-8").read()
    table = open(TABLE, "rb").read()
    reg = region(src)
    rc = code(reg)
    tick = fn(src, "Invoke-RemoteHelpTick")
    cmd = fn(src, "Invoke-RemoteHelpCommand")
    launch = fn(src, "Invoke-RemoteHelpLaunch")
    stream = fn(src, "Invoke-RemoteHelpStreamRead")
    report = fn(src, "Send-RemoteHelpReport")
    resolve = fn(src, "Resolve-RemoteHelpPath")
    out = []

    def ck(name, ok, why):
        out.append((name, bool(ok), why))

    ck("ps1-bom", raw[:3] == bytes([0xEF, 0xBB, 0xBF]), "BOM 이 없다(5.1 이 한글을 깨뜨린다)")
    ck("ps1-region", bool(reg), "원격 해결 절을 못 찾았다")

    m = re.search(r"\$RemoteHelpTableJson = @'\n(.*?)\n'@", src, re.S)
    ck("ps1-table", m is not None and m.group(1).encode("utf-8") + b"\n" == table, "here-string 표 ≠ command-table.json(바이트)")
    ck("ps1-version-once", src.count("v1-2026-09-11") == 1, "판본 글자가 표 밖에도 있다")

    try:
        ps_url = re.search(r"^\$RemoteHelpNoticeUrl\s*=\s*'([^']*)'", src, re.M).group(1)
        ps_notice = re.search(r"^\$RemoteHelpNotice\s*=\s*'([^']*)' \+ \$RemoteHelpNoticeUrl", src, re.M).group(1) + ps_url
        ps_lines = re.findall(r"^    '([^']*)',?$", re.search(r"^\$RemoteHelpLines = @\((.*?)\n\)", src, re.S | re.M).group(1), re.M)
        sh_url = re.search(r'^REMOTE_HELP_NOTICE_URL="([^"]*)"', sh, re.M).group(1)
        sh_notice = re.search(r'^REMOTE_HELP_NOTICE="([^"]*)"', sh, re.M).group(1).replace("$REMOTE_HELP_NOTICE_URL", sh_url)
        sh_lines = re.findall(r'^  "([^"]*)"$', re.search(r"^REMOTE_HELP_LINES=\((.*?)\n\)", sh, re.S | re.M).group(1), re.M)
        parity = ps_notice == sh_notice and ps_lines == sh_lines and len(ps_lines) == 3
    except AttributeError:
        parity = False
    ck("ps1-notice-parity", parity, "고지 1줄·「막혔을 때」 3줄이 맥판과 글자가 다르다")

    bad = re.findall(r"Invoke-Expression|\biex\b|(?<![A-Za-z])-Command\b|-EncodedCommand|\[scriptblock\]::Create|Start-Process|cmd(?:\.exe)?\s+/c|powershell(?:\.exe)?\s+-", rc, re.I)
    ck("ps1-no-shell", not bad and "Get-Command -Name $name -CommandType Cmdlet" in rc and "& $command @params" in rc and "& $cysPath @cysArgs" in rc,
       f"셸 경유 {bad} 또는 두 실행 모양이 없다")

    ck("ps1-session-type", "-not ($session.open -is [bool]) -or -not $session.open) { return 1 }" in tick, "대화 열림을 형으로 보지 않는다")
    ck("ps1-sig-shape", "-not ($m.sig -cmatch '\\A[0-9a-f]{64}\\z')) { continue }" in tick, "서명 모양 검사가 없다")
    seqfn = fn(src, "Test-RemoteHelpSeq")
    ck("ps1-seq-shape", "Test-RemoteHelpSeq $m.seq" in tick and "-is [int] -or $Value -is [long]" in seqfn and "9007199254740991" in seqfn, "seq 형·범위 검사가 없다")
    ck("ps1-pending", "$m.ack.status -ceq 'pending'" in tick, "pending 검사가 없다")
    ck("ps1-shell-decline", "$m.shell -ceq 'ps1'" in tick and "Send-RemoteHelpDecline $seq 'shell'" in tick, "셸 비교·거절이 없다")
    ck("ps1-version-decline", "$m.table_version -ceq $table.version" in tick and "Send-RemoteHelpDecline $seq 'table_version'" in tick, "표 판본 비교·거절이 없다")
    ck("ps1-recheck", "$verdict = Test-RemoteHelpArgv $table 'ps1' $m.argv" in tick and "Invoke-RemoteHelpCommand $seq $verdict.Entry $verdict.Argv" in tick
       and ".text" not in code(tick) + code(cmd), "argv 재검사를 거치지 않거나 명령 글 칸을 읽는다")
    argvfn = fn(src, "Test-RemoteHelpArgv")
    slotfn = fn(src, "Test-RemoteHelpSlot")
    ck("ps1-case", "-not ($v -cmatch $tokenPattern)" in argvfn and "'\\A(?:'" in argvfn and "')\\z'" in argvfn and "-ceq $tokens[0]" in argvfn
       and "-ccontains $Value" in slotfn, "대소문자·끝 줄바꿈을 가르는 비교가 아니다")

    marks = [cmd.find("$first = Resolve-RemoteHelpPath $rel"), cmd.find("Say ('     운영팀 명령: ' + ($Argv -join ' '))"),
             cmd.find("$saved = Save-RemoteHelpExecuted $Seq"), cmd.find("$real = Resolve-RemoteHelpPath $rel"),
             cmd.find("$run = Invoke-RemoteHelpLaunch"), cmd.find("Send-RemoteHelpAck $Seq 'ran'")]
    ck("ps1-order", marks[0] >= 0 and marks == sorted(marks) and len(set(marks)) == 6, f"경로→표시→번호 기록→다시 풂→실행→ack 순서가 아니다 {marks}")
    ck("ps1-boundary", "StartsWith($root.TrimEnd('\\') + '\\', [System.StringComparison]::OrdinalIgnoreCase)) { return @{ Real = ''; Rule = 'path_outside' } }" in resolve,
       "경로 성분 경계 검사가 없다")
    # 없는 폴더 안의 이름 = 표시·번호 기록 전에 path_missing(마지막 성분만 없는 이름으로 붙인다)
    ck("ps1-path-missing", "if ($i -lt $segments.Count - 1) { return @{ Real = ''; Rule = 'path_missing' } }" in resolve
       and ordered(cmd, "if ($first.Rule) { return (Send-RemoteHelpDecline $Seq $first.Rule) }", "Say ('     운영팀 명령: ", "$saved = Save-RemoteHelpExecuted $Seq")
       and "Split-Path -Parent $real" not in code(cmd), "없는 폴더 안의 이름을 표시·번호 기록 전에 거절하지 않는다")
    # TOCTOU(외부 검토 1차 BLOCKER) — 다시 풀어 같은지 · 파일은 **먼저 열고** 연 뒤 다시 확인하고 · 그 핸들로 읽는다(작업 뒤로 넘기지 않는다)
    ck("ps1-toctou", "if ($real.Rule -or -not ($real.Real -ieq $first.Real)) { return (Send-RemoteHelpDecline $Seq 'path_changed') }" in cmd
       and ordered(code(launch), "[System.IO.FileAttributes]::ReparsePoint)) { return @{ Refused = 'path_changed' } }",
                   "$stream = [System.IO.File]::Open($RealPath, 'Open', 'Read', 'Read')",
                   "$again = Get-Item -LiteralPath $RealPath -Force -ErrorAction SilentlyContinue",
                   "-not ($again.FullName -ieq $RealPath))) {",
                   "return (Invoke-RemoteHelpStreamRead $Argv[0] $stream $tail)",
                   "$job = Start-Job"),
       "열기→다시 확인→핸들 읽기 순서가 아니다(또는 실행 직전 재계산이 없다)")
    ck("ps1-handle-read", "($Argv[0] -ceq 'Get-Content' -or $Argv[0] -ceq 'Get-FileHash' -or $Argv[0] -ceq 'Test-Path')" in launch
       and "return (Invoke-RemoteHelpStreamRead $Argv[0] $stream $tail)" in code(launch)
       and "New-Object System.IO.StreamReader($stream, [System.Text.Encoding]::Default, $true)" in stream
       and "Get-FileHash -InputStream $stream -Algorithm SHA256" in stream
       and "$async.AsyncWaitHandle.WaitOne($RemoteHelpCmdTimeout * 1000)" in stream
       and not re.search(r"LiteralPath|\$RealPath|Get-Content", code(stream)),
       "파일 읽기 명령이 연 핸들이 아니라 이름으로 읽는다(또는 시간 상한이 없다)")
    readfn = fn(src, "Read-RemoteHelpExecuted")
    ck("ps1-seq-corrupt", readfn.count("catch { return $null }") == 2 and "if (-not ($parsed -is [array])) { return $null }" in readfn
       and "if ($null -eq $executed) { Say" in tick, "깨진 기록 파일을 닫힌 쪽으로 다루지 않는다")
    savefn = fn(src, "Save-RemoteHelpExecuted")
    ck("ps1-seq-atomic", ordered(savefn, "$fs.Flush($true)", "[System.IO.File]::Replace($tmp"), "임시 파일에 쓰고 디스크까지 내린 뒤 바꿔 끼우지 않는다")
    ck("ps1-seq-lock", ordered(savefn, "New-Object System.Threading.Mutex($false, 'Local\\JarvisRemoteHelpSeq')",
                               "try { $held = $mutex.WaitOne(2000) } catch [System.Threading.AbandonedMutexException] { $held = $true }",
                               "if (-not $held) { return 'LOCKED' }", "$executed = Read-RemoteHelpExecuted", "if ($held) { try { $mutex.ReleaseMutex() } catch { } }")
       and "if ($saved -ceq 'LOCKED') { return (Send-RemoteHelpDecline $Seq 'seq_lock') }" in cmd,
       "기록 읽기·쓰기를 잠금 안에서 하지 않는다(또는 못 잡으면 거절하지 않는다)")
    ck("ps1-no-autostart", ordered(launch, "$env:CYS_NO_AUTOSTART = '1'", "& $cysPath @cysArgs", "} finally { $env:CYS_NO_AUTOSTART = $prev }"),
       "원격 cys 실행에 CYS_NO_AUTOSTART=1 이 없다")
    ck("ps1-timeout", "$done = Wait-Job -Job $job -Timeout $RemoteHelpCmdTimeout" in launch and re.search(r"^\$RemoteHelpCmdTimeout\s*=\s*60\b", src, re.M)
       and "\"`ntimeout:\" + $RemoteHelpCmdTimeout + 's'; $rc = $null" in cmd, "60초 상한·시간 초과 표기가 없다")
    scrubfn = fn(src, "Invoke-RemoteHelpScrub")
    ck("ps1-scrub", "(Invoke-RemoteHelpScrub $envText $script:RhNames)" in report and "(Invoke-RemoteHelpScrub $logText $script:RhNames)" in report
       and "Invoke-RemoteHelpScrub $output $script:RhNames" in cmd and all(t in scrubfn for t in ("<이메일 지움>", "Bearer <토큰 지움>", "<키 지움>", "'~user'")),
       "보고·결과를 스크럽하지 않는다")
    ck("ps1-report-size", re.search(r"^\$RemoteHelpReportMaxBytes\s*=\s*240000\b", src, re.M)
       and ordered(report, "$body = $fields | ConvertTo-Json -Compress", "@(@{ Name = 'log_tail'; Tail = $true }, @{ Name = 'env_report'; Tail = $false })",
                   "if ([System.Text.Encoding]::UTF8.GetByteCount($body) -le $RemoteHelpReportMaxBytes) { break }",
                   "GetByteCount(($fields | ConvertTo-Json -Compress)) -le $RemoteHelpReportMaxBytes", "Invoke-RemoteHelpHttp 'POST' '/api/help' $body"),
       "직렬화한 본문을 재어 줄이지 않는다")
    ck("ps1-header", "if ($script:RhClientToken -and ($Path -like '*/ack' -or $Path -like '*/close')) { $headers['x-help-client'] = $script:RhClientToken }"
       in fn(src, "Invoke-RemoteHelpHttp"), "ack·close 에 출처 헤더를 붙이지 않는다")
    tokenfn = fn(src, "Save-RemoteHelpToken")
    ck("ps1-token", ordered(tokenfn, "[System.IO.File]::WriteAllBytes($full, [byte[]]@())", "SetAccessRuleProtection($true, $false)",
                            "Set-Acl -LiteralPath $full -AclObject $acl -ErrorAction Stop", "WriteAllText($full, ($Token", "return $true",
                            "Remove-Item -LiteralPath $RemoteHelpTokenFile -Force -ErrorAction SilentlyContinue", "return $false")
       and ordered(report, "if (Save-RemoteHelpToken $token) {", "$script:RhClientToken = $token", "$script:RhClientToken = ''")
       and "출처 헤더 없음" in report and "client_token -cmatch '\\A[0-9a-f]{64}\\z'" in report,
       "권한을 먼저 건 빈 파일에 쓰지 않거나 · 실패 때 파일·토큰을 버리지 않는다")
    ck("ps1-wire-notice", re.search(r"^    Say '\[1/10\] 이 컴퓨터를 살펴봅니다\.'\n    Say \('     ' \+ \$RemoteHelpNotice\)\n    \$script:NoticeShown = \$true$", src, re.M),
       "[1/10] 바로 뒤 고지·NoticeShown 배선이 없다")
    wake = fn(src, "Step-Wake")
    # D1 기각 — ReachedWake 는 깨우기가 성공한 두 자리(cys 창을 열었다 · 이 창의 자비스가 종료 코드 0)에만
    ck("ps1-wire-wake", code(src).count("$script:ReachedWake = $true") == 2 and code(wake).count("$script:ReachedWake = $true") == 2
       and re.search(r"if \(\$ref -match 'surface:'\) \{\n\s+Say \"     cys 안에서 자비스를 열었습니다[^\n]*\n(?:\s+#[^\n]*\n)*\s+\$script:ReachedWake = \$true\n", wake)
       and ordered(wake, "$global:LASTEXITCODE = -1", "& claude --dangerously-skip-permissions $firstPrompt", "if ($global:LASTEXITCODE -eq 0) { $script:ReachedWake = $true }"),
       "깨우기 성공 뒤에만 ReachedWake 를 세우지 않는다")
    close = fn(src, "Write-ClosingNote")
    ck("ps1-wire-closing", -1 < close.find("if ($script:NoticeShown) { Invoke-RemoteHelp }") < close.find("if ($script:ShowRerun) { Show-RerunHow }"),
       "끝맺음이 고지 조건으로 원격 해결을 부르고 그 뒤에 「다시 하시는 법」을 두지 않는다")
    entry = fn(src, "Invoke-RemoteHelp")
    ck("ps1-gate", "if (-not $script:JCode) { return }" in entry and "if ($script:ReachedWake) { return }" in entry and "if ($Mode -ne 'full')" in entry,
       "진단 코드·자비스 뒤·dry-run 관문이 없다")
    ck("ps1-close", ordered(entry, "$script:RhOpen = $true", "Register-EngineEvent -SourceIdentifier PowerShell.Exiting", "Watch-RemoteHelp",
                            "} finally {", "if ($script:RhOpen) {", "Invoke-RemoteHelpHttp 'POST' ('/api/help/' + $script:RhId + '/close') $null",
                            "Unregister-Event -SourceIdentifier PowerShell.Exiting"),
       "중단·예외로 끝나도 열린 원격 해결을 닫지 않는다(finally · 엔진 종료)")
    watch = fn(src, "Watch-RemoteHelp")
    ck("ps1-stop", "$r.Code -eq 404" in watch and "$r.Code -eq 410" in watch and "$RemoteHelpMaxSec" in watch and "/close" in watch, "404·410·2시간 멈춤이 없다")
    ck("ps1-answer-control", "[regex]::Replace($answer.text, '[' + $class + ']', '')" in fn(src, "Show-RemoteHelpAnswer"), "처방 글의 화면 제어 글자를 지우지 않는다")
    if os.path.exists(BALANCE):
        bal = subprocess.run([sys.executable, BALANCE, path], capture_output=True, text=True)
        ck("ps1-balance", bal.returncode == 0, "괄호·따옴표 짝 " + bal.stdout[-200:])
    return out


MUTANTS = [
    ("P1 대화 열림을 형으로 보지 않음", "if ($null -eq $session -or -not ($session.open -is [bool]) -or -not $session.open) { return 1 }", "if ($null -eq $session) { return 1 }", "ps1-session-type"),
    ("P2 서명 모양 검사 제거", "        if (-not ($m.sig -is [string]) -or -not ($m.sig -cmatch '\\A[0-9a-f]{64}\\z')) { continue }\n", "", "ps1-sig-shape"),
    ("P3 표시 없이 실행", "    Say ('     운영팀 명령: ' + ($Argv -join ' '))", "    $null = ($Argv -join ' ')", "ps1-order"),
    ("P4 재검사 우회", "        $verdict = Test-RemoteHelpArgv $table 'ps1' $m.argv", "        $verdict = @{ Ok = $true; Entry = @($table.entries)[0]; Argv = [string[]]$m.argv }", "ps1-recheck"),
    ("P5 실행 번호를 남기지 않음", "    $saved = Save-RemoteHelpExecuted $Seq", "    $saved = 'OK'", "ps1-order"),
    ("P6 명령 글로 이어 실행", "            $text = & $command @params 2>&1", "            $text = Invoke-Expression ($name + ' ' + ($params.Values -join ' ')) 2>&1", "ps1-no-shell"),
    ("P7 표 판본 비교 제거", "        if (-not ($m.table_version -is [string]) -or -not ($m.table_version -ceq $table.version)) {\n            if ((Send-RemoteHelpDecline $seq 'table_version') -eq 3) { return 3 }\n            continue\n        }\n", "", "ps1-version-decline"),
    ("P8 경로 성분 경계 제거", "        if (-not ($real -ieq $root) -and -not $real.StartsWith($root.TrimEnd('\\') + '\\', [System.StringComparison]::OrdinalIgnoreCase)) { return @{ Real = ''; Rule = 'path_outside' } }\n", "", "ps1-boundary"),
    ("P9 보고 스크럽 제거", "        env_report        = (Get-RemoteHelpHeadBytes (Invoke-RemoteHelpScrub $envText $script:RhNames) 96000)", "        env_report        = (Get-RemoteHelpHeadBytes $envText 96000)", "ps1-scrub"),
    ("P10 실행 직전 재계산 제거", "        if ($real.Rule -or -not ($real.Real -ieq $first.Real)) { return (Send-RemoteHelpDecline $Seq 'path_changed') }\n", "", "ps1-toctou"),
    ("P11 출처 헤더 제거", "    if ($script:RhClientToken -and ($Path -like '*/ack' -or $Path -like '*/close')) { $headers['x-help-client'] = $script:RhClientToken }\n", "", "ps1-header"),
    ("P12 고지 없이 보냄", "    if ($script:NoticeShown) { Invoke-RemoteHelp }", "    Invoke-RemoteHelp", "ps1-wire-closing"),
    ("P13 대소문자·끝 줄바꿈 무시", "-not ($v -cmatch $tokenPattern)", "-not ($v -match $tokenPattern)", "ps1-case"),
    ("P14 시간 상한 제거", "    $done = Wait-Job -Job $job -Timeout $RemoteHelpCmdTimeout", "    $done = Wait-Job -Job $job", "ps1-timeout"),
    ("P15 연 뒤 다시 확인 제거", "        $again = Get-Item -LiteralPath $RealPath -Force -ErrorAction SilentlyContinue\n", "        $again = $leaf\n", "ps1-toctou"),
    ("P16 핸들이 아니라 이름으로 읽음", "            return (Invoke-RemoteHelpStreamRead $Argv[0] $stream $tail)\n", "", "ps1-handle-read"),
    ("P17 기록 잠금 제거", "        if (-not $held) { return 'LOCKED' }\n", "", "ps1-seq-lock"),
    ("P18 CYS_NO_AUTOSTART 제거", "            $env:CYS_NO_AUTOSTART = '1'\n", "", "ps1-no-autostart"),
    ("P19 권한 없이 토큰 씀", "        Set-Acl -LiteralPath $full -AclObject $acl -ErrorAction Stop\n", "", "ps1-token"),
    ("P20 본문 상한 제거", "        if ([System.Text.Encoding]::UTF8.GetByteCount($body) -le $RemoteHelpReportMaxBytes) { break }", "        break", "ps1-report-size"),
    ("P21 깨우기 전에 ReachedWake(D1)", "    # 여기는 마지막 문장이라", "    $script:ReachedWake = $true\n    # 여기는 마지막 문장이라", "ps1-wire-wake"),
    ("P22 중단 때 닫기 제거", "        if ($script:RhOpen) {", "        if ($false) {", "ps1-close"),
    ("P23 없는 폴더 안의 이름을 붙임", "            if ($i -lt $segments.Count - 1) { return @{ Real = ''; Rule = 'path_missing' } }\n", "", "ps1-path-missing"),
]


def report(results):
    fails = 0
    for name, ok, why in results:
        if ok:
            print(f"  ok   {name}")
        else:
            fails += 1
            print(f"  FAIL {name} — {why}")
    print(f"\n통과 {len(results) - fails} · 실패 {fails}")
    return fails


def mutants():
    source = open(PS, "rb").read().decode("utf-8")
    work = tempfile.mkdtemp(prefix="remote-help-ps1-mutate-")
    killed = 0
    try:
        for name, old, new, expect in MUTANTS:
            if source.count(old) != 1:
                print(f"::error::{name} — 앵커가 {source.count(old)}곳입니다(1곳이어야 한다)")
                return 3
            copy = os.path.join(work, "bootstrap.ps1")
            open(copy, "wb").write(source.replace(old, new, 1).encode("utf-8"))
            failed = [n for n, ok, _ in checks(copy) if not ok]
            hit = expect in failed
            killed += 1 if hit else 0
            print(f"{'KILLED ' if hit else 'SURVIVED'} {name} — 기대 {expect} · FAIL {failed}")
    finally:
        shutil.rmtree(work, ignore_errors=True)
    print(f"\n뮤턴트 {killed}/{len(MUTANTS)} KILLED")
    return 0 if killed == len(MUTANTS) else 1


if __name__ == "__main__":
    if "--mutants" in sys.argv:
        sys.exit(mutants())
    sys.exit(1 if report(checks(PS)) else 0)
