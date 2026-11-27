# review-fix-jarvis-1115 — 윈 설치기 지적 7건을 실물 함수로 잰다(맥 pwsh 에서 도는 것만 · 레지스트리·운영체제 모듈은 윈 실기 목록)
#
# 무엇을 재는가
#   W1 사용자 PATH — 읽기는 펼치지 않은 원래 글자 · 쓰기는 값 종류 유지(REG_EXPAND_SZ) · 쓴 뒤 「환경이 바뀌었다」 알림 · 종류 규칙(순수 함수)
#   W2 남의 설정 파일 쓰기 — 바꿔 끼우기(쓰다 실패하면 원래 파일 그대로 · 같은 예외) · .claude.json·settings.json·되돌리기 세 자리 모두
#   W3 trust-seed.tsv — 지난 실행 기록 줄을 지우지 않고 합친다(겹치면 한 번) · Set-AllProfiles 실물 흐름
#   W4 J-RM-01 — 정상 정리 갈래가 이번 실행의 코드·실패 이벤트를 만들지 않는다 · 화면 두 줄은 남는다
#   W5 원격 해결 표의 함수형 명령(Test-NetConnection·Get-MpComputerStatus) — 정해진 모듈의 함수면 돈다 · 다른 모듈의 같은 이름은 안 돈다
#   W6 글자 첨부 — 기록·설치 창 글자·환경 보고를 지운 뒤 보낸다(로그인 이름·집 폴더·이메일)
#   W7 폴링 GET /api/help/<번호> 에 출처 헤더(x-help-client) · 다른 GET 에는 붙이지 않는다
# ⛔네트워크 0 · 레지스트리 0 · 실제 설치 0 — 함수 묶음으로만 읽는다(JARVIS_LIB_ONLY=1).
#
# 쓰는 법: pwsh -NoProfile -File tests/review-1115-win.ps1 -Dir install-master   · rc 0 = 전건 통과 · 실패는 「FAIL <이름>」 줄
param([Parameter(Mandatory=$true)][string]$Dir)

$ErrorActionPreference = 'Continue'
$script:TPass = 0; $script:TFail = 0
function T-Ck([string]$Name, [bool]$Ok, [string]$Why = '') {
    if ($Ok) { $script:TPass++; Write-Host ('  ok   ' + $Name) } else { $script:TFail++; Write-Host ('  FAIL ' + $Name + '  <- ' + $Why) }
}

$TBase = Join-Path ([System.IO.Path]::GetTempPath()) ('review-1115-' + [guid]::NewGuid().ToString('N'))
$THome = Join-Path $TBase 'install-jarvis'
New-Item -ItemType Directory -Force -Path $THome | Out-Null
[System.IO.File]::WriteAllText((Join-Path $THome '.jarvis-owned'), "jarvis-installer-owned v1`r`n", (New-Object System.Text.UTF8Encoding($false)))

$TPs = Join-Path $Dir 'bootstrap.ps1'
$TSrc = [System.IO.File]::ReadAllText($TPs)
$env:JARVIS_LIB_ONLY = '1'
$env:JARVIS_HOME = $THome
$env:JARVIS_NO_PROGRESS = '1'
. $TPs
$env:JARVIS_LIB_ONLY = ''

# 함수 본문(정의 원문) — 정적 축은 주석을 뺀 본문만 본다
$TAst = [System.Management.Automation.Language.Parser]::ParseInput($TSrc, [ref]$null, [ref]$null)
function T-Body([string]$Name) {
    $f = $TAst.FindAll({ param($n) $n -is [System.Management.Automation.Language.FunctionDefinitionAst] -and $n.Name -ceq $Name }, $true) | Select-Object -First 1
    if ($null -eq $f) { return '' }
    return (($f.Extent.Text -split "`n") | Where-Object { $_ -notmatch '^\s*#' }) -join "`n"
}

# ── W1 사용자 PATH ───────────────────────────────────────────
$g = T-Body 'Get-UserPathValue'
$s = T-Body 'Set-UserPathValue'
T-Ck 'W1 읽기 = 펼치지 않은 원래 글자(DoNotExpandEnvironmentNames) · GetEnvironmentVariable 을 쓰지 않는다' (($g -match 'DoNotExpandEnvironmentNames') -and ($g -notmatch 'GetEnvironmentVariable')) $g
T-Ck 'W1 쓰기 = 레지스트리 SetValue + 값 종류 · SetEnvironmentVariable(''Path'' 를 쓰지 않는다' (($s -match "SetValue\('Path'") -and ($s -match 'RegistryValueKind') -and ($s -notmatch "SetEnvironmentVariable\('Path'")) $s
T-Ck 'W1 쓴 뒤 환경 변경 알림(사용자 환경변수 쓰기 1회 · 값은 지우기 = 변화 0)' ($s -match "SetEnvironmentVariable\('JARVIS_ENV_REFRESH', \`$null, 'User'\)") $s
T-Ck 'W1 종류 규칙 — 원래 REG_EXPAND_SZ 면 유지' ((Get-UserPathKind 'ExpandString' 'C:\a;C:\b') -ceq 'ExpandString')
T-Ck 'W1 종류 규칙 — 값이 없던 자리는 REG_EXPAND_SZ(윈도우 기본)' (((Get-UserPathKind '' '%USERPROFILE%\x') -ceq 'ExpandString') -and ((Get-UserPathKind '' 'C:\a') -ceq 'ExpandString'))
T-Ck 'W1 종류 규칙 — 원래 REG_SZ 면 % 가 있어도 REG_SZ 그대로(뜻이 바뀌지 않게 · F7)' ((Get-UserPathKind 'String' 'a;%JAVA_HOME%\bin') -ceq 'String')
T-Ck 'W1 종류 규칙 — 원래 REG_SZ 이고 % 없으면 REG_SZ 그대로' ((Get-UserPathKind 'String' 'C:\a;C:\b') -ceq 'String')
# 부르는 쪽이 원래 글자를 그대로 이어 붙이는가(흉내: 두 함수만 바꿔 끼운다 — 맥에는 사용자 환경변수 자리가 없다)
$script:TUserPath = '%USERPROFILE%\AppData\Local\Microsoft\WindowsApps;%JAVA_HOME%\bin'
$script:TWritten = $null
function Get-UserPathValue { return $script:TUserPath }
function Set-UserPathValue($value) { $script:TWritten = [string]$value }
$TFakeProfile = Join-Path $TBase 'profile'
New-Item -ItemType Directory -Force -Path (Join-Path $TFakeProfile '.local\bin') | Out-Null
$TSaveProfile = $env:USERPROFILE; $env:USERPROFILE = $TFakeProfile
[void](Seed-LocalBinPath)
$env:USERPROFILE = $TSaveProfile
T-Ck 'W1 Seed-LocalBinPath 는 %참조% 를 펼치지 않은 채 뒤에 덧붙인다' (($null -ne $script:TWritten) -and $script:TWritten.StartsWith('%USERPROFILE%\AppData\Local\Microsoft\WindowsApps;%JAVA_HOME%\bin;')) ([string]$script:TWritten)

# ── W2 바꿔 끼우기 쓰기 ───────────────────────────────────────
#   바꿔 끼우기 자체(Invoke-FileSwap)를 흉내로 바꿔 실패 갈래를 만든다 — 맥 .NET 에는 ReplaceFile 오류 1176·1177 이 없다.
$TCfg = Join-Path $TBase 'claude.json'
$TAtomicBody = T-Body 'Write-TextNoBomAtomic'
T-Ck 'W2 바꿔 끼우기 쓰기는 새로 만들기만(New-TextFileExclusive)으로 임시 파일을 쓰고 Invoke-FileSwap 으로 바꿔 끼운다(흉내가 실패를 넣는 자리)' (($TAtomicBody -match 'New-TextFileExclusive ') -and ($TAtomicBody -match 'Invoke-FileSwap ') -and ((T-Body 'Invoke-FileSwap') -ne '') -and ((T-Body 'New-TextFileExclusive') -ne '')) $TAtomicBody
function T-Leftover([string]$P) { return @(Get-ChildItem -LiteralPath (Split-Path -Parent $P) -Force | Where-Object { $_.Name -like ((Split-Path -Leaf $P) + '.jarvis-tmp*') }).Count }
$script:TSwapReal = ${function:Invoke-FileSwap}
[System.IO.File]::WriteAllText($TCfg, '{"keep":"me"}')
function Invoke-FileSwap($Tmp, $Full) { throw 'emu: 바꿔 끼우기 실패(원래 파일은 그대로)' }
$threw = $false
try { Write-TextNoBomAtomic $TCfg '{"new":1}' } catch { $threw = $true }
T-Ck 'W2 바꿔 끼우기가 실패하고 원래 파일이 있으면 같은 예외 · 원래 파일 한 바이트도 안 바뀜 · 임시 파일 안 남음' ($threw -and ([System.IO.File]::ReadAllText($TCfg) -ceq '{"keep":"me"}') -and ((T-Leftover $TCfg) -eq 0)) ([System.IO.File]::ReadAllText($TCfg))
# F2 — ReplaceFile 오류 1176·1177 꼴: 원래 자리는 비고 새 내용은 임시 이름에만 있다 → 임시 파일을 원래 자리로 옮긴다(지우지 않는다)
function Invoke-FileSwap($Tmp, $Full) { [System.IO.File]::Delete($Full); throw 'emu: ERROR_UNABLE_TO_MOVE_REPLACEMENT(1176)' }
$threw = $false
try { Write-TextNoBomAtomic $TCfg '{"new":2}' } catch { $threw = $true }
T-Ck 'W2 원래 자리가 빈 채 실패하면(1176·1177) 임시 파일을 원래 자리로 옮긴다 — 설정 자리가 비지 않는다' ((Test-Path -LiteralPath $TCfg) -and ([System.IO.File]::ReadAllText($TCfg) -ceq '{"new":2}') -and ((T-Leftover $TCfg) -eq 0)) ("threw=$threw exists=" + (Test-Path -LiteralPath $TCfg))
T-Ck 'W2 옮겨 살렸으면 던지지 않는다(부르는 쪽 되읽기 확인 길로 간다)' (-not $threw)
# N1(2차 검증) — 원래 파일이 없던 자리에서 임시 파일 **쓰기 도중** 실패하면 반쪽 글을 제자리로 옮기지 않는다(지우고 던진다)
Set-Item -Path function:Invoke-FileSwap -Value $script:TSwapReal
$script:TExclReal = ${function:New-TextFileExclusive}
function New-TextFileExclusive($path, $text) { [System.IO.File]::WriteAllText($path, ([string]$text).Substring(0, 5)); throw 'emu: 쓰기 도중 디스크 가득' }
$TNoOrig = Join-Path $TBase 'settings-new.json'
$threw = $false
try { Write-TextNoBomAtomic $TNoOrig '{"theme":"dark","x":1}' } catch { $threw = $true }
T-Ck 'W2 원래 파일이 없던 자리에서 임시 파일 쓰기 도중 실패하면 → 예외 · 제자리 파일 없음 · 임시 파일 안 남음(N1)' ($threw -and -not (Test-Path -LiteralPath $TNoOrig) -and ((T-Leftover $TNoOrig) -eq 0)) ("threw=$threw exists=" + (Test-Path -LiteralPath $TNoOrig) + ' left=' + (T-Leftover $TNoOrig))
Set-Item -Path function:New-TextFileExclusive -Value $script:TExclReal
# F9 — 실행마다 다른 임시 이름
$script:TTmps = @()
function Invoke-FileSwap($Tmp, $Full) { $script:TTmps += [string]$Tmp; & $script:TSwapReal $Tmp $Full }
Write-TextNoBomAtomic $TCfg '{"new":3}'
Write-TextNoBomAtomic $TCfg '{"new":4}'
T-Ck 'W2 임시 이름이 실행마다 다르다(고정 이름 .jarvis-tmp 아님)' (($script:TTmps.Count -eq 2) -and ($script:TTmps[0] -cne $script:TTmps[1]) -and -not ($script:TTmps[0].EndsWith('.jarvis-tmp'))) ($script:TTmps -join ' | ')
T-Ck 'W2 성공하면 새 내용 · 임시 파일 없음 · BOM 없음' (([System.IO.File]::ReadAllText($TCfg) -ceq '{"new":4}') -and ((T-Leftover $TCfg) -eq 0) -and ([System.IO.File]::ReadAllBytes($TCfg)[0] -ne 0xEF))
Set-Item -Path function:Invoke-FileSwap -Value $script:TSwapReal
$TNewF = Join-Path $TBase 'fresh.json'
Write-TextNoBomAtomic $TNewF 'x'
T-Ck 'W2 없던 파일도 만든다' ([System.IO.File]::ReadAllText($TNewF) -ceq 'x')
# F9 — 새로 만들기만: 그 이름에 무엇이 이미 있으면(링크 포함) 실패하고 링크가 가리키는 파일을 덮지 않는다
$TVictim = Join-Path $TBase 'victim.txt'
[System.IO.File]::WriteAllText($TVictim, 'victim')
$TLink = Join-Path $TBase 'planted.jarvis-tmp-x'
New-Item -ItemType SymbolicLink -Path $TLink -Target $TVictim | Out-Null
$threw = $false
try { New-TextFileExclusive $TLink 'overwrite' } catch { $threw = $true }
T-Ck 'W2 새로 만들기만 — 이미 있는 자리(심어 둔 링크)는 실패 · 링크가 가리키는 파일은 그대로' ($threw -and ([System.IO.File]::ReadAllText($TVictim) -ceq 'victim')) ([System.IO.File]::ReadAllText($TVictim))
foreach ($fn in @('Set-ClaudePrefs', 'Set-ClaudeSettings', 'Undo-TrustSeed')) {
    $b = T-Body $fn
    T-Ck ("W2 $fn 의 남의 설정 파일 쓰기는 바꿔 끼우기만(제자리 Write-TextNoBom 0)") (($b -match 'Write-TextNoBomAtomic \$(cfg|sf) ') -and ($b -notmatch 'Write-TextNoBom \$(cfg|sf) ')) (($b -split "`n" | Where-Object { $_ -match 'Write-TextNoBom' }) -join ' | ')
}

# ── W3 trust-seed.tsv 합치기 ──────────────────────────────────
$TrustSeedFile = Join-Path $THome 'trust-seed.tsv'
[System.IO.File]::WriteAllText($TrustSeedFile, "C:\p\.claude.json`tC:\Users\x`r`nC:\p\.claude.json`tC:/Users/x`r`n")
function Get-ProfileTargets { return @() }
$script:TrustSeeded = @(,@('C:\cys\claude\.claude.json', 'C:\Users\x'))
$script:TrustSeeded += ,@('C:\p\.claude.json', 'C:\Users\x')
Set-AllProfiles | Out-Null
$lines = @(([System.IO.File]::ReadAllText($TrustSeedFile) -split "`r?`n") | Where-Object { $_ })
T-Ck 'W3 지난 실행 기록 2줄 + 이번 새 1줄 = 3줄(겹친 줄은 한 번 · 앞 기록이 먼저)' (($lines.Count -eq 3) -and ($lines[0] -ceq "C:\p\.claude.json`tC:\Users\x") -and ($lines[1] -ceq "C:\p\.claude.json`tC:/Users/x") -and ($lines[2] -ceq "C:\cys\claude\.claude.json`tC:\Users\x")) ($lines -join ' | ')
T-Ck 'W3 기록 실패로 보지 않는다' (-not $script:TrustJournalFailed)
Remove-Item -LiteralPath $TrustSeedFile -Force
$script:TrustSeeded = @(,@('C:\a\.claude.json', 'C:\Users\y'))
Set-AllProfiles | Out-Null
T-Ck 'W3 기록 파일이 없으면 이번 줄만' (([System.IO.File]::ReadAllText($TrustSeedFile).Trim()) -ceq "C:\a\.claude.json`tC:\Users\y")

# ── W4 J-RM-01 ───────────────────────────────────────────────
$noCode = -not ($TSrc -match "(?m)^\s*Write-JCode 'J-RM-01'")
T-Ck 'W4 정상 정리 갈래에서 Write-JCode ''J-RM-01'' 을 부르지 않는다' $noCode
T-Ck 'W4 화면에는 진단 코드 줄과 찾아보기 줄이 그대로 남는다' (($TSrc -match [regex]::Escape('Say ("     진단 코드: J-RM-01 — 지난 설치의 자국이 남아 있어 정리했습니다")')) -and ($TSrc -match [regex]::Escape("Say (""     이 코드로 찾아보실 수 있습니다: "" + `$HelpCodeUrl + 'J-RM-01')")))

# ── W5 원격 해결 함수형 명령 ──────────────────────────────────
$TJob = $TAst.FindAll({ param($n) $n -is [System.Management.Automation.Language.ScriptBlockExpressionAst] -and $n.Extent.Text -match 'Get-Command -Name \$name' }, $true) | Select-Object -First 1
if ($null -eq $TJob) {
    T-Ck 'W5 원격 해결 cmdlet 실행 블록을 찾는다(Get-Command -Name $name)' $false '블록 없음'
} else {
    $TMods = Join-Path $TBase 'mods'
    New-Item -ItemType Directory -Force -Path (Join-Path $TMods 'NetTCPIP'), (Join-Path $TMods 'Decoy') | Out-Null
    [System.IO.File]::WriteAllText((Join-Path $TMods 'NetTCPIP/NetTCPIP.psm1'), "function Test-NetConnection { param(`$ComputerName) 'net-ok:' + `$ComputerName }`nExport-ModuleMember -Function Test-NetConnection`n")
    [System.IO.File]::WriteAllText((Join-Path $TMods 'Decoy/Decoy.psm1'), "function Get-MpComputerStatus { 'decoy-ran' }`nExport-ModuleMember -Function Get-MpComputerStatus`n")
    $TSb = [scriptblock]::Create($TJob.Extent.Text.Trim().TrimStart('{').TrimEnd('}'))
    $TSaveMp = $env:PSModulePath
    $env:PSModulePath = $TMods + [System.IO.Path]::PathSeparator + $env:PSModulePath
    $r1 = $null; try { $r1 = & $TSb 'Test-NetConnection' @{ ComputerName = 'jarvis.example' } $TBase } catch { $r1 = 'THREW ' + $_.Exception.Message }
    $r2 = $null; try { $r2 = & $TSb 'Get-MpComputerStatus' @{} $TBase } catch { $r2 = 'THREW ' + $_.Exception.Message }
    $r3 = $null; try { $r3 = & $TSb 'Get-Date' @{ Format = 'yyyy' } $TBase } catch { $r3 = 'THREW ' + $_.Exception.Message }
    $env:PSModulePath = $TSaveMp
    T-Ck 'W5 정해진 모듈(NetTCPIP)의 함수 Test-NetConnection 은 돈다(rc 0)' (($r1 -isnot [string]) -and ([string]$r1.Output -match 'net-ok:jarvis.example') -and ($r1.Rc -eq 0)) ([string]($r1 | Out-String))
    T-Ck 'W5 다른 모듈(Decoy)의 같은 이름 함수는 돌지 않는다(던짐)' (([string]$r2).StartsWith('THREW') -and -not ([string]$r2 -match 'decoy-ran')) ([string]($r2 | Out-String))
    T-Ck 'W5 cmdlet 은 앞 판처럼 돈다(Get-Date)' (($r3 -isnot [string]) -and ([string]$r3.Output -match '^\s*[0-9]{4}') -and ($r3.Rc -eq 0)) ([string]($r3 | Out-String))
}

# ── W6 글자 첨부 지우기 ───────────────────────────────────────
$TLogF = Join-Path $TBase 'transcript.txt'
$TText = "**********************`r`nWindows PowerShell transcript start`r`nUsername: CONTOSO\hongtester`r`nRunAs User: CONTOSO\hongtester`r`nMachine: DESKTOP-ABC (Microsoft Windows NT 10.0)`r`nHost Application: powershell.exe -File C:\Users\hongtester\install-jarvis.ps1`r`nseed-path: added C:\Users\hongtester\.local\bin to User PATH`r`nmail me: hong.tester@example.com`r`nAuthorization: Bearer abcdEFGH1234`r`n"
[System.IO.File]::WriteAllText($TLogF, $TText, (New-Object System.Text.UTF8Encoding($true)))
$script:RhNames = @()
$TBytes = Get-ScrubbedTextBytes $TLogF 900KB
$TOut = if ($null -ne $TBytes) { [System.Text.Encoding]::UTF8.GetString($TBytes) } else { '' }
T-Ck 'W6 지운 글을 돌려준다(빈 것 아님)' ($TOut.Length -gt 0)
T-Ck 'W6 로그인 이름(Username: 줄에서 모은 것) · 집 폴더 경로 · 이메일 · 토큰이 남지 않는다' (($TOut -notmatch 'hongtester') -and ($TOut -notmatch 'hong\.tester@') -and ($TOut -notmatch 'abcdEFGH1234') -and ($TOut -notmatch 'C:\\Users\\')) $TOut
T-Ck 'W6 지운 자리 말고는 남는다(진단 가치)' (($TOut -match 'seed-path: added ~') -and ($TOut -match 'Windows PowerShell transcript start'))
$TBig = Join-Path $TBase 'big.log'
[System.IO.File]::WriteAllText($TBig, (('가' * 1000) + "`n") * 50 + 'END-LINE C:\Users\hongtester\x')
$TBigB = Get-ScrubbedTextBytes $TBig 4096
$TBigT = [System.Text.Encoding]::UTF8.GetString($TBigB)
T-Ck 'W6 상한 안 · 끝을 남긴다 · 글자를 반으로 자르지 않는다' (($TBigB.Length -le 4096) -and $TBigT.EndsWith('END-LINE ~\x') -and ($TBigT -notmatch [char]0xFFFD)) ($TBigB.Length)
T-Ck 'W6 없는 파일 = $null(보내지 않음)' ($null -eq (Get-ScrubbedTextBytes (Join-Path $TBase 'nope.log') 1024))
$sfa = T-Body 'Send-FailAttachments'
T-Ck 'W6 Send-FailAttachments 의 글자 첨부 셋은 지운 바이트로만(log_full·console_text·env_full)' (($sfa -match "'log_full' 'bootstrap.log' \(Get-ScrubbedTextBytes ") -and ($sfa -match "'console_text' 'transcript.txt' \(Get-ScrubbedTextBytes ") -and ($sfa -match "'env_full' 'env-report.md' \(Get-ScrubbedTextBytes ") -and ($sfa -notmatch "(log_full|console_text|env_full).*Get-FileBytesCapped")) $sfa
# W6b 지우는 순서(교차 검증 #2 · installer-0346-scrub-order) — 이름이 sk·Bearer 여도 토큰 값이 남지 않는다
#   보고 본문(env_report·log_tail)·명령 결과(ack)·글자 첨부가 모두 같은 Invoke-RemoteHelpScrub 이라 이 함수 하나를 잰다(가림 v3 · scrub-v3-port-1116 = 글은 .Text).
$TS1 = (Invoke-RemoteHelpScrub 'key=sk-abcdefgh12345678 saved' @('sk')).Text
T-Ck 'W6b 이름이 sk 여도 sk- 키 값이 남지 않는다' (($TS1 -notmatch 'abcdefgh12345678') -and ($TS1 -match '<키 지움>')) $TS1
$TS2 = (Invoke-RemoteHelpScrub 'Authorization: Bearer abcDEF1234567890' @('Bearer')).Text
T-Ck 'W6b 이름이 Bearer 여도 토큰 값이 남지 않는다' (($TS2 -notmatch 'abcDEF1234567890') -and ($TS2 -match 'Bearer <토큰 지움>')) $TS2
$TS3 = (Invoke-RemoteHelpScrub 'mail a.b@example.com key sk-abcdefgh12345678 Authorization: Bearer tok12345678 path C:\Users\hong\x who a.b+(c) and axb+(c) hello' @('키 지움', '토큰', '지움', '이메일', 'Users', 'user', 'a.b+(c)', 'hello')).Text
T-Ck 'W6b 이름이 표식 낱말(토큰·지움·이메일·user)·Users·정규식 특수문자여도 표식·집 폴더 접두가 뭉개지지 않고 값이 남지 않는다' (($TS3 -notmatch 'abcdefgh12345678|tok12345678|hong|a\.b@') -and $TS3.Contains('mail <이메일 지움> key <키 지움> Authorization: Bearer <토큰 지움> path ~\x who ~user and axb+(c) ~user')) $TS3
$TLogS = Join-Path $TBase 'order.log'
[System.IO.File]::WriteAllText($TLogS, "Authorization: Bearer abcDEF1234567890`r`nkey=sk-abcdefgh12345678 saved`r`n", (New-Object System.Text.UTF8Encoding($false)))
$script:RhNames = @('Bearer', 'sk')
$TOutS = [System.Text.Encoding]::UTF8.GetString((Get-ScrubbedTextBytes $TLogS 900KB))
$script:RhNames = @()
T-Ck 'W6b 글자 첨부(보고 때 모은 이름 = Bearer·sk)도 토큰·키 값이 남지 않는다' (($TOutS -notmatch 'abcDEF1234567890|abcdefgh12345678') -and ($TOutS -match 'Bearer <토큰 지움>') -and ($TOutS -match '<키 지움>')) $TOutS

# W6c 공용 벡터(가림 v3 · scrub-v3-port-1116) — 서버 src/scrub.ts · 맥 JXA 와 같은 입력 → 같은 출력(코드 단위 · 서수 비교)
#   벡터 = tests/scrub-v3/model/vectors-v3.json(설계 좌석 split/model 의 바이트 사본 — sha256 고정값으로 묶는다) · 전 관문(161건 + 무작위) = tests/scrub-v3-win.mjs
#   ⚠옛 계약(tests/scrub-vectors.json 45건 · 「다시 가려도 같다」)은 v3 가 약속하지 않는다 — 옛 45건은 새 84건 안에 id 그대로 들어 있고 답이 바뀐 것은 was 칸에 옛 답
$TVecPath = Join-Path $PSScriptRoot 'scrub-v3/model/vectors-v3.json'
$TVecSha = (Get-FileHash -Algorithm SHA256 -LiteralPath $TVecPath).Hash.ToLowerInvariant()
T-Ck 'W6c 벡터 파일 sha256 = 설계 좌석 원본과 같은 고정값' ($TVecSha -ceq 'f539528d57aba26b621be9b228c7263324375806e3bf05f1f2b9e7bbfb2908a5') $TVecSha
$TVec = ([System.IO.File]::ReadAllText($TVecPath, [System.Text.Encoding]::UTF8) | ConvertFrom-Json).vectors
$TVecBad = New-Object System.Collections.Generic.List[string]
#   짝 잃은 서러게이트가 든 7건은 여기서 재지 않는다 — pwsh 7.6 의 ConvertFrom-Json 이 그 글자를 U+FFFD 로 바꿔 읽는다(실측 2026-11-16 · 구현 결함 아님).
#   그 7건은 tests/scrub-v3-win.mjs 가 UTF-16 코드 단위 16진 통로로 잰다(관문 1 · 84/84).
$TVecLone = @('X-lone-high', 'X-lone-high-2', 'X-pair-kept', 'X-lone-in-text', 'X-codex2-tidy-name-nul', 'X-codex2-tidy-text-nul', 'X-codex2-tidy-both')
$TVecSkipped = 0
foreach ($v in $TVec) {
    if ($TVecLone -ccontains [string]$v.id) { $TVecSkipped++; continue }
    $vr = Invoke-RemoteHelpScrub ([string]$v.input) @($v.names)
    $vm = (@(for ($k = 0; $k -lt @($vr.MarkS).Count; $k++) { '' + @($vr.MarkS)[$k] + ',' + @($vr.MarkE)[$k] + ',' + @($vr.MarkR)[$k] }) -join ';')
    $wm = (@(foreach ($m in @($v.marks)) { '' + $m[0] + ',' + $m[1] + ',' + $m[2] }) -join ';')
    # 서수 비교(-ceq 는 NUL·U+FEFF 를 무시한다)
    if (-not [string]::Equals([string]$vr.Text, [string]$v.expected, [System.StringComparison]::Ordinal) -or $vm -cne $wm) { $TVecBad.Add($v.id + ' got=' + (([string]$vr.Text) -replace "`r", '\r' -replace "`n", '\n')) }
}
T-Ck ('W6c 공용 벡터 ' + (@($TVec).Count - $TVecSkipped) + '/' + @($TVec).Count + '건(서러게이트 7건은 scrub-v3-win.mjs) 전부 기대 출력 · 표식 자리까지') ($TVecBad.Count -eq 0 -and @($TVec).Count -eq 84 -and $TVecSkipped -eq 7) ($TVecBad -join ' | ')
# W6d 글 첨부의 새 길(추정 없음) — UTF-16 은 머리표가 있어도 읽지 않는다 · 틀린 UTF-8 · NUL · 넘친 묶음 = <전부 지움> 한 낱말 · 머리표뿐 = 보내지 않음
$TW = Join-Path $TBase 'w6d.log'
$script:RhNames = @()
[System.IO.File]::WriteAllBytes($TW, [byte[]](@(0xFF, 0xFE) + [System.Text.Encoding]::Unicode.GetBytes("USERNAME=hongtester`r`n")))
T-Ck 'W6d UTF-16LE(머리표) 파일 = <전부 지움> 한 낱말(decode)' ([System.Text.Encoding]::UTF8.GetString((Get-ScrubbedTextBytes $TW 900KB)) -ceq '<전부 지움>')
[System.IO.File]::WriteAllBytes($TW, [byte[]]@(0x55, 0x53, 0x45, 0x52, 0x3D, 0xC8, 0xAB, 0xB1, 0xE6, 0x0A))
T-Ck 'W6d 틀린 UTF-8(CP949 한글) = <전부 지움>' ([System.Text.Encoding]::UTF8.GetString((Get-ScrubbedTextBytes $TW 900KB)) -ceq '<전부 지움>')
[System.IO.File]::WriteAllBytes($TW, [byte[]]@(0x6F, 0x6B, 0x00, 0x0A))
T-Ck 'W6d NUL 이 든 파일 = <전부 지움>' ([System.Text.Encoding]::UTF8.GetString((Get-ScrubbedTextBytes $TW 900KB)) -ceq '<전부 지움>')
[System.IO.File]::WriteAllBytes($TW, [byte[]]@(0xEF, 0xBB, 0xBF))
T-Ck 'W6d 머리표뿐인 파일 = $null(보내지 않음)' ($null -eq (Get-ScrubbedTextBytes $TW 900KB))
[System.IO.File]::WriteAllText($TW, "status ok`n", (New-Object System.Text.UTF8Encoding($false)))
$script:RhNames = @{ names = @('acct000'); overflow = $true }
T-Ck 'W6d 보고 때 수확이 넘쳤으면(묶음 overflow) 첨부도 <전부 지움>(harvest)' ([System.Text.Encoding]::UTF8.GetString((Get-ScrubbedTextBytes $TW 900KB)) -ceq '<전부 지움>')
$script:RhNames = @('q')
[System.IO.File]::WriteAllText($TW, "USERNAME=q`nstatus q ok`n", (New-Object System.Text.UTF8Encoding($false)))
T-Ck 'W6d 한 글자 계정 이름(알려진 이름 원본)도 첨부에서 가린다(codex split 1R 발견 1)' ([System.Text.Encoding]::UTF8.GetString((Get-ScrubbedTextBytes $TW 900KB)) -ceq "USERNAME=~user`nstatus ~user ok`n")
$script:RhNames = @()
$TSet = Get-RemoteHelpNames "USERNAME=q`n" @("acct'77", 'q')
T-Ck 'W6d 수확은 알려진 이름을 원본 그대로 넣는다(q · acct''77 · 손질 꼴 acct77 도)' ((@($TSet.Names) -ccontains 'q') -and (@($TSet.Names) -ccontains "acct'77") -and (@($TSet.Names) -ccontains 'acct77') -and -not $TSet.Overflow) (@($TSet.Names) -join ',')

# W9 행동 시험(검증 좌석 5절 빈칸 · scrub-v3-port-1116 고침 1회) — 낱말 일치가 아니라 실물 Send-RemoteHelpReport·Invoke-RemoteHelpCommand 를 태운다(HTTP 만 가로챔)
$TW9 = Join-Path $TBase 'w9'
New-Item -ItemType Directory -Force -Path $TW9 | Out-Null
$TSave9 = @{ Report = $ReportFile; Log = $LogFile; User = $env:USERNAME; Profile = $env:USERPROFILE; Code = $script:JCode }
$ReportFile = Join-Path $TW9 'env-report.md'; $LogFile = Join-Path $TW9 'bootstrap.log'
$env:USERNAME = 'acct077'; $env:USERPROFILE = (Join-Path $TW9 'acct077'); $script:JCode = 'J-TEST-01'
$script:TPosts = New-Object System.Collections.Generic.List[string]
$TReal9 = @{ Http = ${function:Invoke-RemoteHelpHttp}; Saved = ${function:Save-RemoteHelpExecuted}; Launch = ${function:Invoke-RemoteHelpLaunch}; Ack = ${function:Send-RemoteHelpAck} }   # 끝에 되돌린다(W7 은 실물 Invoke-RemoteHelpHttp 를 잰다)
function Invoke-RemoteHelpHttp($Method, $Path, $Body) { $script:TPosts.Add([string]$Body); return @{ Code = 400; Text = '' } }
function Send-W9Report([string]$Env, [string]$Log) {
    [System.IO.File]::WriteAllText($ReportFile, $Env, (New-Object System.Text.UTF8Encoding($false)))
    [System.IO.File]::WriteAllText($LogFile, $Log, (New-Object System.Text.UTF8Encoding($false)))
    $script:TPosts.Clear()
    [void](Send-RemoteHelpReport)
    if ($script:TPosts.Count -lt 1) { return $null }
    return ($script:TPosts[0] | ConvertFrom-Json)
}
$TLines65 = (@(for ($k = 0; $k -lt 65; $k++) { 'USER=acct' + $k.ToString('000') }) -join "`n") + "`n"
$TR = Send-W9Report "- os: Windows 11`n" $TLines65
T-Ck 'W9 표시 이름 65개 보고(수확 넘침) = 보낸 본문의 env_report·log_tail 둘 다 <전부 지움>(실물 Send-RemoteHelpReport · 검증 W1·W5)' (($null -ne $TR) -and ([string]$TR.env_report -ceq '<전부 지움>') -and ([string]$TR.log_tail -ceq '<전부 지움>')) $(if ($TR) { [string]$TR.env_report + ' / ' + [string]$TR.log_tail } else { '본문 없음' })
#   꼭 64개 — 이 컴퓨터에서 실제로 세워지는 알려진 이름 수 K 를 실물 보고로 잰다(표시 줄 없는 보고 → $script:RhNames 의 이름 수).
#   맥 pwsh = 계정 이름 acct077 하나(K=1) · 진짜 윈도 = + WindowsIdentity 이름(컴퓨터\계정)의 원본과 손질 꼴(러너 run 43825552598 에서 63+K 가 넘침이었다)
[void](Send-W9Report "- os: Windows 11`n" "note`n")
$TKnownK = @((ConvertTo-RemoteHelpNameSet $script:RhNames).Names).Count
$TLines64 = (@(for ($k = 0; $k -lt (64 - $TKnownK); $k++) { 'USER=acct' + $k.ToString('000') }) -join "`n") + "`n"
$TR = Send-W9Report "- os: Windows 11`n" $TLines64
$TNames64 = @((ConvertTo-RemoteHelpNameSet $script:RhNames).Names).Count
T-Ck ('W9 꼭 64개(표시 ' + (64 - $TKnownK) + ' + 이 컴퓨터의 알려진 이름 ' + $TKnownK + ') = 넘침 아님(두 칸이 가려진 글)') (($TKnownK -ge 1) -and ($TNames64 -eq 64) -and ($null -ne $TR) -and ([string]$TR.log_tail).StartsWith('USER=~user') -and ([string]$TR.env_report -ceq "- os: Windows 11`n")) ('K=' + $TKnownK + ' 이름 수=' + $TNames64 + ' log_tail=' + $(if ($TR) { [string]$TR.log_tail } else { '본문 없음' }).Substring(0, [Math]::Min(30, $(if ($TR) { ([string]$TR.log_tail).Length } else { 5 }))))
$TR = Send-W9Report "- os: Windows 11`n" ($TLines64 + 'USER=acct999' + "`n")
T-Ck 'W9 그 위에 표시 이름 하나 더(65번째) = 두 칸 <전부 지움>' (($null -ne $TR) -and ([string]$TR.env_report -ceq '<전부 지움>') -and ([string]$TR.log_tail -ceq '<전부 지움>')) $(if ($TR) { [string]$TR.log_tail } else { '본문 없음' })
$TH1 = (@('USERNAME=otheracct') + @(for ($k = 0; $k -lt 205; $k++) { '[2/10] 진행 ' + $k }) + @('otheracct 계정으로 다시 실행')) -join "`n"
$TR = Send-W9Report "- os: Windows 11`n" ($TH1 + "`n")
$TTail = [string]$TR.log_tail
T-Ck 'W9 log_tail = 기록 전체로 수확·가린 뒤 끝 200줄(창 밖 표시 줄의 이름도 가림 · 검증 H1)' (($null -ne $TR) -and $TTail.EndsWith('~user 계정으로 다시 실행') -and -not $TTail.Contains('otheracct') -and (@($TTail.Split([char]10)).Count -eq 200)) ($TTail.Substring([Math]::Max(0, $TTail.Length - 40)))
# 명령 결과 — 실행·기록·경로는 흉내(결과 글만 준다) · 보낸 output_tail 을 본다
$script:TAcks = New-Object System.Collections.Generic.List[string]
function Save-RemoteHelpExecuted($Seq) { return 'OK' }
function Invoke-RemoteHelpLaunch($Entry, $Argv, $Real, $PathIndex) { return @{ Refused = ''; Output = $script:TCmdOut; Rc = 0; TimedOut = $false } }
function Send-RemoteHelpAck([long]$Seq, [string]$Status, $Rc, [string]$Tail) { $script:TAcks.Add($Tail); return 200 }
$TEntry = [pscustomobject]@{ usage = 'cys status'; exec = 'cmdlet' }
$TTok = (@(for ($k = 0; $k -lt 600; $k++) { 'Tk' + ($k % 10) + 'aZ9xQ' }) -join '')
$script:RhNames = @{ names = [string[]]@('acct077'); overflow = $false }
$script:TCmdOut = 'Authorization: Bearer ' + $TTok + "`r`nok"
$script:TAcks.Clear(); [void](Invoke-RemoteHelpCommand 7 $TEntry @('cys', 'status'))
$TAck = $(if ($script:TAcks.Count -gt 0) { $script:TAcks[0] } else { '' })
T-Ck 'W9 Bearer 로 시작하고 4KB 를 넘는 명령 결과 = 보낸 글에 토큰 조각 0 · Bearer <토큰 지움>(가린 뒤 자름 · 검증 W3·W6)' ($TAck.Contains('Bearer <토큰 지움>') -and -not $TAck.Contains('aZ9xQ') -and ([System.Text.Encoding]::UTF8.GetByteCount($TAck) -le 4096)) $TAck
$script:TCmdOut = "USERNAME=cmdother`r`nlast login cmdother ok"
$script:TAcks.Clear(); [void](Invoke-RemoteHelpCommand 8 $TEntry @('cys', 'status'))
$TAck = $(if ($script:TAcks.Count -gt 0) { $script:TAcks[0] } else { '' })
T-Ck 'W9 명령 결과에서 다시 수확한다(보고 묶음에 없던 표시 이름도 가림 · 검증 H2)' ($TAck -ceq "USERNAME=~user`r`nlast login ~user ok") $TAck
$script:RhNames = @{ names = [string[]]@(); overflow = $true }
$script:TCmdOut = 'status ok'
$script:TAcks.Clear(); [void](Invoke-RemoteHelpCommand 9 $TEntry @('cys', 'status'))
T-Ck 'W9 보고 묶음이 넘쳤으면 명령 결과도 <전부 지움>' (($script:TAcks.Count -gt 0) -and ($script:TAcks[0] -ceq '<전부 지움>')) ($script:TAcks -join '|')
$script:RhNames = @()
Set-Item -Path function:Invoke-RemoteHelpHttp -Value $TReal9.Http; Set-Item -Path function:Save-RemoteHelpExecuted -Value $TReal9.Saved; Set-Item -Path function:Invoke-RemoteHelpLaunch -Value $TReal9.Launch; Set-Item -Path function:Send-RemoteHelpAck -Value $TReal9.Ack
$ReportFile = $TSave9.Report; $LogFile = $TSave9.Log; $env:USERNAME = $TSave9.User; $env:USERPROFILE = $TSave9.Profile; $script:JCode = $TSave9.Code

# ── W7 폴링 출처 헤더 ─────────────────────────────────────────
$script:TSeen = @()
function Invoke-WebRequest {
    param([string]$Uri, [string]$Method, [switch]$UseBasicParsing, [int]$TimeoutSec, [hashtable]$Headers, $Body, [string]$ContentType)
    $script:TSeen += ,@($Method, $Uri, $(if ($Headers.ContainsKey('x-help-client')) { $Headers['x-help-client'] } else { '' }))
    return [pscustomobject]@{ StatusCode = 200; RawContentStream = (New-Object System.IO.MemoryStream(,[byte[]][System.Text.Encoding]::UTF8.GetBytes('{}'))) }
}
$script:RhId = 'K7M2Q9XR'
$script:RhClientToken = ('a' * 64)
[void](Invoke-RemoteHelpHttp 'GET' '/api/help/K7M2Q9XR' $null)
[void](Invoke-RemoteHelpHttp 'GET' '/api/help/K7M2Q9XR/other' $null)
[void](Invoke-RemoteHelpHttp 'GET' '/api/help/ZZZZZZZZ' $null)
[void](Invoke-RemoteHelpHttp 'POST' '/api/help/K7M2Q9XR/ack' '{}')
T-Ck 'W7 폴링 GET /api/help/<내 번호> 에 x-help-client' (($script:TSeen.Count -ge 1) -and ($script:TSeen[0][2] -ceq ('a' * 64))) (($script:TSeen | ForEach-Object { $_ -join ' ' }) -join ' | ')
T-Ck 'W7 다른 GET(하위 경로 · 남의 번호)에는 붙이지 않는다' (($script:TSeen[1][2] -ceq '') -and ($script:TSeen[2][2] -ceq ''))
T-Ck 'W7 ack 는 앞 판처럼 붙인다' ($script:TSeen[3][2] -ceq ('a' * 64))

# ── W8 제거기(reset-clean.ps1)·재설치 줄 — 사용자 PATH 원래 글자·값 종류(F1) ───────────────
#   재설치 줄 = reinstall.ps1 → reset-clean.ps1 -KeepApp(Remove-UserPathSeed) → 설치기(Seed-LocalBinPath). 레지스트리는 가짜 한 칸으로 둔다.
$TRs = Join-Path $Dir 'reset-clean.ps1'
$TRsSrc = [System.IO.File]::ReadAllText($TRs)
$TRsAst = [System.Management.Automation.Language.Parser]::ParseInput($TRsSrc, [ref]$null, [ref]$null)
foreach ($fn in @('Get-UserPathSeedDirs', 'Test-UserPathSeed', 'Remove-UserPathSeed', 'Get-UserPathValue', 'Get-UserPathKind', 'Set-UserPathValue')) {
    $def = $TRsAst.FindAll({ param($n) $n -is [System.Management.Automation.Language.FunctionDefinitionAst] -and $n.Name -ceq $fn }, $true) | Select-Object -First 1
    if ($null -ne $def) { . ([scriptblock]::Create($def.Extent.Text)) }
}
$TRsCode = (($TRsSrc -split "`n") | Where-Object { $_ -notmatch '^\s*#' }) -join "`n"
T-Ck 'W8 제거기에 펼친 값 읽기(GetEnvironmentVariable Path User)·REG_SZ 쓰기(SetEnvironmentVariable Path) 자리 0' (($TRsCode -notmatch "GetEnvironmentVariable\('Path', ?'User'\)") -and ($TRsCode -notmatch "SetEnvironmentVariable\('Path'"))
$script:FakeReg = @{ Value = '%USERPROFILE%\AppData\Local\Microsoft\WindowsApps;%USERPROFILE%\.local\bin;%JAVA_HOME%\bin'; Kind = 'ExpandString' }
function Get-UserPathValue { return $script:FakeReg.Value }
function Set-UserPathValue($value) { $script:FakeReg.Kind = (Get-UserPathKind $script:FakeReg.Kind ([string]$value)); $script:FakeReg.Value = [string]$value }
$TSaveProfile = $env:USERPROFILE; $env:USERPROFILE = $TFakeProfile
$ClaudeBin = $env:USERPROFILE + '\.local\bin'; $KeepApp = $true; $CysDir = 'C:\emu\cys\'; $CysDirOld = 'C:\emu\cysold\'
$script:Removed = 0; $script:KeptFail = 0
Remove-UserPathSeed *> $null
T-Ck 'W8 제거기가 클로드 자리만 빼고 나머지 %참조% 는 글자 그대로 · 값 종류 REG_EXPAND_SZ 그대로' (($script:FakeReg.Value -ceq '%USERPROFILE%\AppData\Local\Microsoft\WindowsApps;%JAVA_HOME%\bin') -and ($script:FakeReg.Kind -ceq 'ExpandString')) ($script:FakeReg.Value + ' / ' + $script:FakeReg.Kind)
[void](Seed-LocalBinPath)
$env:USERPROFILE = $TSaveProfile
T-Ck 'W8 재설치 줄 끝(제거기 → 설치기) 뒤에도 %USERPROFILE%·%JAVA_HOME% 가 굳지 않고 REG_EXPAND_SZ' ($script:FakeReg.Value.StartsWith('%USERPROFILE%\AppData\Local\Microsoft\WindowsApps;%JAVA_HOME%\bin;') -and ($script:FakeReg.Kind -ceq 'ExpandString')) ($script:FakeReg.Value + ' / ' + $script:FakeReg.Kind)

Remove-Item -LiteralPath $TBase -Recurse -Force -ErrorAction SilentlyContinue
Write-Host ''
Write-Host ('통과 ' + $script:TPass + ' · 실패 ' + $script:TFail)
if ($script:TFail -gt 0) { exit 1 } else { exit 0 }
