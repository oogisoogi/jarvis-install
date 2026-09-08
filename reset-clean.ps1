# 깨끗이 지우기 (윈도우) — 설치 도우미가 놓은 것을 도로 걷어 낸다
#
# 무엇을 하는가
#   이 컴퓨터의 상태를 먼저 살펴 목록으로 보여 주고, 확인을 받은 뒤 지운다.
#   지우는 것은 footprint.md 에 적힌 것뿐이다. 사진·문서 같은 개인 파일은 손대지 않는다.
#
# 쓰는 법
#   powershell -ExecutionPolicy Bypass -File reset-clean.ps1
#   powershell -ExecutionPolicy Bypass -File reset-clean.ps1 -List        살펴보기만 한다
#   powershell -ExecutionPolicy Bypass -File reset-clean.ps1 -WhatIf      위와 같다(옛 이름)
#   powershell -ExecutionPolicy Bypass -File reset-clean.ps1 -Yes         묻지 않는다(재설치가 안에서 쓴다)
#   powershell -ExecutionPolicy Bypass -File reset-clean.ps1 -PurgeLogin  로그인까지 지운다
#
# 받아서 바로 돌리는 한 줄 (명령 프롬프트 창에서도 같다)
#   powershell -NoProfile -ExecutionPolicy Bypass -Command "irm https://jarvis.godmeyou.kr/install/reset-clean.ps1 -OutFile ([Environment]::GetFolderPath('UserProfile')+'\reset-clean.ps1'); powershell -ExecutionPolicy Bypass -File ([Environment]::GetFolderPath('UserProfile')+'\reset-clean.ps1')"
#   내려받는 자리를 임시 폴더가 아니라 사용자 폴더로 둔 까닭은 설치 도우미와 같다:
#   임시 폴더는 언제든 비워지고, 회사 컴퓨터는 그 자리에서의 실행 자체를 막아 두는 설정이 흔하다.
#
# 되돌릴 수 없다. 지우기 전에 목록을 보여 주고 한 번 묻는다.
#
# ★로그인은 기본으로 남긴다 (2026-09-08 개정 · 앞 판은 지웠다).
#   앞 판은 %USERPROFILE%\.claude 폴더와 .claude.json 을 통째로 지웠다. 그 한 줄이 로그인과
#   대화 기록과 남의 설정 칸을 한꺼번에 날렸다. 이제 셋을 갈라서 다룬다:
#     전부 우리 것        -> 통째로 지운다
#     남의 파일 속 우리 줄 -> 우리가 넣은 칸만 도로 뺀다. 파일은 안 지운다
#     손대지 않음         -> 아무것도 안 한다(목록에만 적어 사람이 알게 한다)
#   ⚠실험(깨끗한 기계 재설치 채점)에서 로그인까지 지우려면 -PurgeLogin 을 붙여야 한다.
#     이 도구를 쓰는 사람이 둘이기 때문이다 — 재설치하는 사용자와, 손 개수를 재는 실험.
#
# cys 프로그램 자체는 이 스크립트가 지우지 않는다 — 윈도우 설정 앱에서 지우시게 안내한다.
#   왜: 제거 프로그램을 이 스크립트가 직접 띄우면 백신이 그 행위를 막고 PowerShell 을 통째로
#   종료시키는 일이 실제로 있었다(2026-09-05 · V3 · 진단명 Execution/MDP.Powershell.M1201).
#   그때 스크립트는 아무 말도 남기지 못하고 사라지며 아무것도 지워지지 않는다.
#   설정 앱은 사람이 원래 쓰는 길이고, 같은 일을 막히지 않고 한다. (-UseUninstaller 로 옛 방식 선택)
# 창이 갑자기 닫히면 백신이 PowerShell 을 종료한 것일 수 있다. 다시 돌리면 이어서 진행된다.

param([switch]$WhatIf, [switch]$List, [switch]$Yes, [switch]$PurgeLogin, [switch]$UseUninstaller)

$ErrorActionPreference = 'Continue'
try { [Console]::OutputEncoding = [System.Text.Encoding]::UTF8 } catch { }
$ListOnly = ($WhatIf -or $List)

$CysDir     = Join-Path $env:LOCALAPPDATA 'cys'
$CysDirOld  = Join-Path $env:LOCALAPPDATA 'Programs\cys'
$UninstExe  = Join-Path $CysDir 'uninstall.exe'
$RegKey     = 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Uninstall\cys'
$JarvisDir  = Join-Path $env:USERPROFILE 'install-jarvis'
$CysHome    = Join-Path $env:USERPROFILE '.cys'
$ClaudeDir  = Join-Path $env:USERPROFILE '.claude'
$ClaudeJson = Join-Path $env:USERPROFILE '.claude.json'
$ClaudeExe  = Join-Path $env:USERPROFILE '.local\bin\claude.exe'
$ClaudeBin  = (Join-Path $env:USERPROFILE '.local\bin').TrimEnd('\')
$AgoraDir   = Join-Path $env:USERPROFILE '.config\agora'
# 광장 안내를 가리키는 자리(설치기 Set-AgoraSkill 과 같은 규칙 - 있는 것만).
$AgoraSkillDirs = @((Join-Path $env:USERPROFILE '.claude\skills\agora-delegate'))
$AgoraAltHome = Join-Path $env:USERPROFILE '.cys\claude'
if (Test-Path -LiteralPath $AgoraAltHome) {
    $AgoraSkillDirs += (Join-Path $AgoraAltHome 'skills\agora-delegate')
}
$SettingsJs = Join-Path $ClaudeDir 'settings.json'
# ★로그인 파일 자리는 고정이 아니다 — 공식 문서(2026-09-08 확인 · code.claude.com/docs/en/team
#   「Credential management」): 「If you've set the CLAUDE_CONFIG_DIR environment variable, Claude Code
#   keeps the .credentials.json file under that directory instead」.
#   ⇒ 그 변수가 선 창에서 이 스크립트를 돌리면 **우리가 보는 자리와 클로드가 보는 자리가 갈린다.**
#   갈린 채로 「[있음] 로그인」이라고 적으면 그 줄이 거짓이 된다. 클로드가 보는 자리를 본다.
$ClaudeCfgDir = if ($env:CLAUDE_CONFIG_DIR) { $env:CLAUDE_CONFIG_DIR } else { $ClaudeDir }
$CredFile   = Join-Path $ClaudeCfgDir '.credentials.json'
# 자비스 창(cys)이 띄우는 클로드는 CLAUDE_CONFIG_DIR 을 ~\.cys\claude 로 두고 뜬다.
#   그 폴더는 아래에서 「cys 계정 자리」로 **통째로 지워진다** — 거기 든 로그인도 같이 사라진다.
#   지우는 것을 바꾸지는 않는다(그것은 사람이 결정할 일이다). 다만 **말은 해 준다.**
$CysCredFile = Join-Path $CysHome 'claude\.credentials.json'
# 받아 둔 설치기 사본 — 2026-09-06 부터 사용자 폴더에 받는다. 옛 자리(임시 폴더)도 함께 본다.
$HomePs1    = Join-Path $env:USERPROFILE 'install-jarvis.ps1'
$TempPs1    = Join-Path $env:TEMP 'install-jarvis.ps1'

$script:Found = 0
$script:Removed = 0
$script:KeptFail = 0
$script:SkipCysDir = $false

function Short($p) { return ([string]$p).Replace($env:USERPROFILE, '~') }
function Row($label, $path) {
    $exists = Test-Path $path
    if ($exists) { $script:Found++ }
    $mark = if ($exists) { '있음' } else { '없음' }
    Write-Host ("  [{0}] {1} · {2}" -f $mark, $label, (Short $path))
    return $exists
}
function RowFlag($label, $exists, $note) {
    if ($exists) { $script:Found++ }
    $mark = if ($exists) { '있음' } else { '없음' }
    Write-Host ("  [{0}] {1} · {2}" -f $mark, $label, $note)
}
# 시작 메뉴 바로가기는 cys 설치기가 만든다. 공식 제거기가 지워 주는 것이라 평소에는 우리가 안 본다 —
# 그런데 제거기를 못 쓰는 자리(등록 항목이 없는 잔재)에서는 우리가 지우지 않으면 고아로 남는다.
# 자리가 판본마다 다를 수 있으므로 후보를 훑고 **있는 것만** 돌려준다(없으면 빈 목록 = 「없음」).
function Get-StartMenuLinks {
    # ⛔바로가기 **파일(.lnk)만** 후보로 넣는다. 앞 판은 확장자 없는 `cys` 도 넣었는데, 그것이 사람이
    #   다른 뜻으로 만든 폴더면 Drop 이 -Recurse -Force 로 **통째로 지운다**(agy R1 [3] 지적 채택
    #   2026-09-09 · 남의 것을 지울 위험은 「있으면 함께 지운다」의 편의보다 무겁다).
    # ⚠전체 사용자 공용 시작 메뉴(C:\ProgramData\...)는 **후보에 넣지 않는다** — 그 자리는 관리자
    #   영역이고, 이 스크립트는 관리자 권한을 쓰지 않는다(HKLM 을 안 건드리는 것과 같은 규율).
    $out = New-Object System.Collections.ArrayList
    $r = Join-Path $env:APPDATA 'Microsoft\Windows\Start Menu\Programs'
    if ($r) {
        foreach ($c in @((Join-Path $r 'cys.lnk'), (Join-Path $r 'cys\cys.lnk'))) {
            if (Test-Path $c -PathType Leaf) { [void]$out.Add($c) }
        }
    }
    return $out.ToArray()
}

function Drop($label, $path) {
    if (-not (Test-Path $path)) { return }
    try { Remove-Item $path -Recurse -Force -ErrorAction Stop; $script:Removed++; Write-Host ("  지움: " + (Short $path)) }
    catch { $script:KeptFail++; Write-Host ("  [남음] " + (Short $path) + " — " + $_.Exception.Message) }
}

function Get-ClaudeCmd {
    if (Test-Path $ClaudeExe) { return $ClaudeExe }
    $c = Get-Command claude -ErrorAction SilentlyContinue
    if ($c) { return $c.Source }
    return $null
}
function Get-CysCmd {
    foreach ($c in @((Join-Path $CysDir 'cys.exe'), (Join-Path $CysDirOld 'cys.exe'))) {
        if (Test-Path $c) { return $c }
    }
    $g = Get-Command cys -ErrorAction SilentlyContinue
    if ($g) { return $g.Source }
    return $null
}
# 🔴🔴적대검증 [3] BLOCK 채택(2026-09-08): 앞 판은 `-TaskName '*cys*'` 로 잡히는 것을 **전부 지웠다.**
#   `macys-backup`·`cys-project` 처럼 이름이 스치기만 하는 **남의 작업이 함께 영구 삭제된다.**
#   ★이름이 스친다고 우리 것이 아니다. 우리 것의 근거는 이름이 아니라 **그 작업이 무엇을 실행하는가**다.
function Get-CysTasks {
    $cand = @()
    try { $cand = @(Get-ScheduledTask -ErrorAction SilentlyContinue | Where-Object { $_.TaskName -like '*cys*' }) }
    catch { return @() }
    $roots = @($CysDir, $CysDirOld) | Where-Object { $_ }
    $ours = @()
    foreach ($tk in $cand) {
        $mine = $false
        # 이름이 정확히 우리 것이거나(느슨한 부분일치가 아니다) 우리 회사 표식을 달고 있으면 우리 것이다.
        if ($tk.TaskName -ieq 'cys' -or $tk.TaskName -ieq 'cysd' -or $tk.TaskName -imatch 'cysjavis') { $mine = $true }
        # 그리고 결정적인 근거 — 실행하는 파일이 우리 설치 자리 안에 있는가.
        foreach ($a in @($tk.Actions)) {
            $x = $null; try { $x = $a.Execute } catch { }
            if (-not $x) { continue }
            foreach ($r in $roots) { if ($r -and $x -like ($r + '*')) { $mine = $true } }
            if ($x -imatch 'cysd?\.exe$') { $mine = $true }
        }
        if ($mine) { $ours += $tk }
    }
    return $ours
}
function Test-UserPathSeed {
    $u = [Environment]::GetEnvironmentVariable('Path','User')
    if (-not $u) { return $false }
    foreach ($p in ($u -split ';')) {
        if (-not $p) { continue }
        if ([Environment]::ExpandEnvironmentVariables($p).TrimEnd('\') -ieq $ClaudeBin) { return $true }
    }
    return $false
}
function Test-JsonKey($file, $key) {
    if (-not (Test-Path $file)) { return $false }
    $t = Read-TextUtf8 $file
    if ($null -eq $t -or $t -eq '') { return $false }
    try { $o = $t | ConvertFrom-Json -ErrorAction Stop } catch { return $false }
    return ($null -ne $o.PSObject.Properties[$key])
}
function Test-Hooks($file) {
    if (-not (Test-Path $file)) { return $false }
    $t = Read-TextUtf8 $file
    if ($null -eq $t) { return $false }
    return ($t -match 'session-start\.(sh|ps1)|role-bootstrap\.(sh|ps1)')
}
function Test-LoginPresent {
    # ⚠자리가 어디인지 우리는 모른다(공식 문서가 윈도우 자리를 안 적는다 · footprint W-LOGIN).
    #   그래서 「있다/없다」를 단정하지 않고, 우리가 아는 후보 하나만 사실대로 보고한다.
    return (Test-Path $CredFile)
}

function Invoke-Diagnose {
    $script:Found = 0
    Write-Host '=== 이 컴퓨터의 상태 ==='
    # footprint: W-APP
    [void](Row 'cys 프로그램' $CysDir)
    [void](Row 'cys 프로그램(옛 자리)' $CysDirOld)
    foreach ($lnk in (Get-StartMenuLinks)) { [void](Row 'cys 시작 메뉴 바로가기' $lnk) }
    # footprint: W-REG
    [void](Row 'cys 설치 목록 항목' $RegKey)
    # footprint: W-DAEMON
    $tk = @(Get-CysTasks)
    RowFlag 'cys 상시 가동 등록' ($tk.Count -gt 0) '작업 스케줄러'
    # footprint: W-CYSHOME
    [void](Row 'cys 계정 자리' $CysHome)
    # footprint: W-CLAUDEBIN
    [void](Row '클로드 실행 파일' $ClaudeExe)
    # footprint: W-JARVISHOME
    [void](Row '자비스 작업 폴더' $JarvisDir)
    # footprint: W-SCRIPTCOPY
    [void](Row '받아 둔 설치 스크립트' $HomePs1)
    [void](Row '받아 둔 설치 스크립트(옛 자리)' $TempPs1)
    # footprint: W-AGORA
    [void](Row '참가 열쇠·이름' $AgoraDir)
    # footprint: W-AGORASKILL
    $skillHere = $false
    foreach ($sd in $AgoraSkillDirs) { if (Test-Path -LiteralPath $sd) { $skillHere = $true } }
    RowFlag '광장 안내 가리키기' $skillHere ($AgoraSkillDirs[0])
    # footprint: W-PATH
    RowFlag '실행 경로 등록' (Test-UserPathSeed) '사용자 Path 환경변수'
    # footprint: W-CLAUDEJSON
    RowFlag '클로드 설정의 우리 칸' (Test-JsonKey $ClaudeJson 'hasCompletedOnboarding') (Short $ClaudeJson)
    # footprint: W-CLAUDESETTINGS
    RowFlag '클로드 설정 우리 칸 2' (Test-JsonKey $SettingsJs 'skipDangerousModePermissionPrompt') (Short $SettingsJs)
    # footprint: W-HOOK
    RowFlag '각성 훅 등록' (Test-Hooks $SettingsJs) (Short $SettingsJs)

    Write-Host ''
    if ($PurgeLogin) { Write-Host '=== 로그인·개인 자료 ===' } else { Write-Host '=== 손대지 않는 것 (지우지 않습니다) ===' }
    # footprint: W-LOGIN
    if (Test-LoginPresent) { Write-Host ('  [있음] 로그인 · ' + (Short $CredFile)) }
    else { Write-Host '  [없음] 로그인 · 우리가 아는 자리에는 없습니다(다른 자리에 있을 수 있습니다)' }
    if ($PurgeLogin) {
        Write-Host '         -PurgeLogin 을 붙이셨습니다 — 이번에는 로그인도 지웁니다.'
        Write-Host '         이때는 로그인만이 아니라 연결해 둔 다른 서비스의 로그인과 확장 기능의 비밀값도 함께 지워집니다.'
        Write-Host '         (클로드가 그렇게 만들어 두었습니다 — 우리가 고를 수 있는 것이 아닙니다.)'
    } else {
        Write-Host '         기본으로 남깁니다. 재설치 뒤 로그인을 다시 하지 않으셔도 됩니다.'
    }
    # footprint: W-CLAUDEUSER
    if (Test-Path $CysCredFile) {
        Write-Host ('  [있음] 자비스 창 전용 로그인 · ' + (Short $CysCredFile))
        Write-Host '         ⚠이것은 위의 「cys 계정 자리」 안에 들어 있어 **함께 지워집니다.**'
        Write-Host '         자비스 창에서 하신 로그인은 다시 하셔야 합니다 — 윈도우에서 하신 로그인과는 별개입니다.'
    }
    if (Test-Path $ClaudeDir) { Write-Host ('  [있음] 클로드 대화·기록 · ' + (Short $ClaudeDir) + ' (남깁니다)') }
    else { Write-Host ('  [없음] 클로드 대화·기록 · ' + (Short $ClaudeDir)) }
    Write-Host '  사진·문서·내려받기 등 개인 파일은 목록에 없습니다 — 손대지 않습니다.'

    Write-Host ''
    Write-Host '=== 판정 ==='
    if ($script:Found -eq 0) {
        Write-Host '  아무것도 깔려 있지 않습니다 (미설치).'
    } elseif ((Test-Path $CysDir) -and (Test-Path $CysHome) -and (Test-Path $ClaudeExe)) {
        Write-Host ("  설치가 끝난 상태로 보입니다 (찾은 자국 {0} 개)." -f $script:Found)
    } else {
        Write-Host ("  설치가 중간에 멈춘 상태로 보입니다 (찾은 자국 {0} 개)." -f $script:Found)
        Write-Host '  고장이 아닙니다 — 지우고 처음부터 다시 하면 됩니다.'
    }
    if (Test-Path $AgoraDir) { Write-Host '  참가 열쇠를 지우면 다시 설치할 때 참가 이름이 새로 생깁니다(전에 하신 말은 옛 이름으로 남습니다).' }
}

# ── 남의 파일 속 우리 줄 — 파일을 지우지 않는다 ──────────────────
# 🔴적대검증 지적 채택(2026-09-08) — 남의 JSON 을 고쳐 쓸 때 두 가지를 반드시 지킨다.
#   ⑴Set-Content -Encoding UTF8 은 PowerShell 5.1 에서 **맨 앞에 BOM 을 붙인다.** JSON 앞의 BOM 은
#     읽는 쪽(Node 계열)이 파싱에 실패하게 만든다 — 우리가 칸 하나 빼려다 **남의 설정 파일을
#     통째로 못 읽게 만드는** 것이다.
#   ⑵원본에 바로 쓰면 쓰는 도중 멈췄을 때(백신 개입·강제 종료) 남의 파일이 **반쪽으로 남는다.**
#   ⇒ BOM 없는 인코딩으로 **임시 파일에 다 쓴 뒤** 한 번에 자리를 바꾼다.
# 🔴🔴적대검증·러너 실측 채택(2026-09-08 · run 34209137309 이 실물에서 잡았다).
#   `Get-Content $file -Raw` 는 **인코딩을 안 적으면 PowerShell 5.1 에서 ANSI(cp1252·cp949)로 읽는다.**
#   남의 `.claude.json` 은 UTF-8 이다 ⇒ 「자비스 연구소」가 「ìž\x90ë¹„ìŠ¤」 가 되고, 그 깨진 글자를
#   우리가 다시 UTF-8 로 써 넣는다. **칸 하나 빼려다 남의 설정 파일을 통째로 훼손하는 것이다.**
#   (러너가 잡은 실피해: 한글 값·키가 전부 mojibake · `한글칸` 이 깨진 이름의 새 칸으로 생김 ·
#    2048자 문자열이 6144자가 됨 · `projects` 의 우리말 경로 칸이 사라지고 깨진 이름으로 재생성.)
#   ⚠형제 파일 `bootstrap.ps1` 은 같은 자리에서 이미 `-Encoding UTF8` 을 쓰고 있었다(701·723·749).
#   **깔 때는 맞게 읽고 지울 때는 틀리게 읽고 있었다** — 한 쌍으로 도는 일인데 한쪽만 고쳐져 있었다.
function Read-TextUtf8($file) {
    # 성공 = 글자 · 실패 = $null. ★못 알아본 파일은 **손대지 않는다**(반쪽으로 만드는 것보다 낫다).
    try { $bytes = [System.IO.File]::ReadAllBytes($file) } catch { return $null }
    if ($bytes.Length -eq 0) { return '' }
    $skip = 0
    if ($bytes.Length -ge 3 -and $bytes[0] -eq 0xEF -and $bytes[1] -eq 0xBB -and $bytes[2] -eq 0xBF) { $skip = 3 }
    $body = New-Object byte[] ($bytes.Length - $skip)
    [Array]::Copy($bytes, $skip, $body, 0, $body.Length)
    if ($body.Length -eq 0) { return '' }
    # throwOnInvalidBytes — UTF-8 이 아닌 바이트가 있으면 여기서 걸린다(조용히 뭉개지 않는다).
    $enc = New-Object System.Text.UTF8Encoding($false, $true)
    try { $text = $enc.GetString($body) } catch { return $null }
    # 되짚어 본다: 읽은 글자를 다시 바이트로 만들면 원래 바이트와 같아야 한다.
    try { $again = $enc.GetBytes($text) } catch { return $null }
    if ($again.Length -ne $body.Length) { return $null }
    if ([Convert]::ToBase64String($again) -ne [Convert]::ToBase64String($body)) { return $null }
    return $text
}

# ★쓰기에도 자기검증을 붙인다(이중 방어 — 검사 축과 같은 논리를 지우개 안에 넣는다).
#   ⑴글로 옮겼다가 되읽어 **뜻이 같은가**(왕복 손실 — 깊이 잘림·배열 벗겨짐·날짜 변환)
#   ⑵쓴 파일을 되읽어 **글자가 같은가**(인코딩 손실)
#   하나라도 어긋나면 **원본을 건드리지 않고** 사실대로 [남음] 으로 남긴다.
#   되돌릴 수 없는 일에서는 「아마 됐을 것」보다 「안 했다」가 낫다.
function Write-JsonChecked($file, $obj) {
    $json = $obj | ConvertTo-Json -Depth 40
    try { $back = $json | ConvertFrom-Json -ErrorAction Stop } catch { return '글로 옮긴 것을 되읽지 못했습니다' }
    if (($back | ConvertTo-Json -Depth 40 -Compress) -ne ($obj | ConvertTo-Json -Depth 40 -Compress)) {
        return '글로 옮겼다가 되읽으니 뜻이 달라졌습니다'
    }
    $tmp = "$file.jarvis-tmp"
    $enc = New-Object System.Text.UTF8Encoding($false)
    try { [System.IO.File]::WriteAllText($tmp, $json, $enc) } catch { return $_.Exception.Message }
    $rt = Read-TextUtf8 $tmp
    if ($null -eq $rt -or $rt -ne $json) {
        Remove-Item $tmp -Force -ErrorAction SilentlyContinue
        return '쓴 파일을 되읽으니 글자가 달라졌습니다'
    }
    try { Move-Item -Path $tmp -Destination $file -Force -ErrorAction Stop } catch { return $_.Exception.Message }
    return $null
}
function Remove-JsonKey($file, $key) {
    if (-not (Test-Path $file)) { return }
    $raw = Read-TextUtf8 $file
    if ($null -eq $raw) {
        $script:KeptFail++
        Write-Host ("  [남음] " + (Short $file) + " 의 " + $key + " 칸 — 이 파일을 UTF-8 로 읽지 못했습니다. 손대지 않았습니다.")
        return
    }
    try {
        $o = $raw | ConvertFrom-Json -ErrorAction Stop
        if ($null -eq $o.PSObject.Properties[$key]) { return }
        $o.PSObject.Properties.Remove($key)
        $why = Write-JsonChecked $file $o
        if ($why) {
            $script:KeptFail++
            Write-Host ("  [남음] " + (Short $file) + " 의 " + $key + " 칸 — " + $why + " 원본은 그대로 두었습니다.")
            return
        }
        $script:Removed++; Write-Host ("  지움: " + (Short $file) + " 의 " + $key + " 칸 (파일은 그대로)")
    } catch {
        # 주석이 든 설정 파일(JSONC)은 5.1 의 ConvertFrom-Json 이 못 읽는다 — 그때는 안 고치고 사실대로 말한다.
        $script:KeptFail++; Write-Host ("  [남음] " + (Short $file) + " 의 " + $key + " 칸 — " + $_.Exception.Message)
    }
}
function Remove-OurHooks($file) {
    if (-not (Test-Hooks $file)) { return }
    $raw = Read-TextUtf8 $file
    if ($null -eq $raw) {
        $script:KeptFail++
        Write-Host ("  [남음] " + (Short $file) + " 의 각성 훅 — 이 파일을 UTF-8 로 읽지 못했습니다. 손대지 않았습니다.")
        return
    }
    try {
        $o = $raw | ConvertFrom-Json -ErrorAction Stop
        $h = $o.PSObject.Properties['hooks']
        if ($null -eq $h) { return }
        foreach ($ev in @($h.Value.PSObject.Properties.Name)) {
            $keep = @()
            foreach ($entry in @($h.Value.$ev)) {
                $s = ($entry | ConvertTo-Json -Depth 20 -Compress)
                if ($s -notmatch 'session-start|role-bootstrap') { $keep += $entry }
            }
            if ($keep.Count -gt 0) { $h.Value.$ev = $keep } else { $h.Value.PSObject.Properties.Remove($ev) }
        }
        if ($h.Value.PSObject.Properties.Name.Count -eq 0) { $o.PSObject.Properties.Remove('hooks') }
        $why = Write-JsonChecked $file $o
        if ($why) {
            $script:KeptFail++
            Write-Host ("  [남음] " + (Short $file) + " 의 각성 훅 — " + $why + " 원본은 그대로 두었습니다.")
            return
        }
        $script:Removed++; Write-Host ("  지움: " + (Short $file) + " 의 각성 훅 (다른 설정은 그대로)")
    } catch { $script:KeptFail++; Write-Host ("  [남음] " + (Short $file) + " 의 각성 훅 — " + $_.Exception.Message) }
}
function Remove-UserPathSeed {
    # ⚠사용자 Path 만 건드린다. 시스템 Path 는 손대지 않는다(관리자 권한이 필요하고 우리 것이 아니다).
    if (-not (Test-UserPathSeed)) { return }
    try {
        $u = [Environment]::GetEnvironmentVariable('Path','User')
        $keep = @()
        foreach ($p in ($u -split ';')) {
            if (-not $p) { continue }
            if ([Environment]::ExpandEnvironmentVariables($p).TrimEnd('\') -ieq $ClaudeBin) { continue }
            $keep += $p
        }
        [Environment]::SetEnvironmentVariable('Path', ($keep -join ';'), 'User')
        $script:Removed++; Write-Host '  지움: 사용자 실행 경로 등록 (시스템 쪽은 그대로)'
    } catch { $script:KeptFail++; Write-Host ("  [남음] 사용자 실행 경로 등록 — " + $_.Exception.Message) }
}

# footprint: W-LOGIN
# ★공식 명령을 먼저 쓴다 — 그 명령은 두 운영체제에서 같은 뜻이라 대칭이 저절로 맞는다.
#   자리를 직접 치우는 것은 클로드가 이미 없을 때의 폴백이다.
#   ⚠순서 제약: 로그아웃 명령이 클로드 안에 들어 있다. 클로드를 지우기 전에 부른다.
function Invoke-PurgeLoginFirst {
    if (-not $PurgeLogin) { Write-Host '  남김: 로그인 (다음에 다시 하지 않으셔도 됩니다)'; return }
    $claude = Get-ClaudeCmd
    $done = $false
    if ($claude) {
        try { & $claude auth logout 2>&1 | Out-Null; if ($LASTEXITCODE -eq 0) { $done = $true } } catch { }
    }
    if ($done) { $script:Removed++; Write-Host '  지움: 로그인 (공식 로그아웃)'; return }
    if (Test-Path $CredFile) {
        try { Remove-Item $CredFile -Force -ErrorAction Stop; $script:Removed++; Write-Host '  지움: 로그인 (자리를 직접 치웠습니다)' }
        catch { $script:KeptFail++; Write-Host ("  [남음] 로그인 — " + $_.Exception.Message) }
    } else {
        Write-Host '  로그인: 우리가 아는 자리에는 지울 것이 없었습니다.'
    }
}

function Invoke-Purge {
    Write-Host ''
    Write-Host '=== 지웁니다 ==='

    # ★순서가 중요하다 — 등록을 떼는 명령과 로그아웃 명령이 지울 대상 **안에** 들어 있다.
    Invoke-PurgeLoginFirst

    # footprint: W-DAEMON
    $cys = Get-CysCmd
    $daemonDone = $false
    if ($cys) {
        try { & $cys daemon uninstall 2>&1 | Out-Null; $daemonDone = $true; Write-Host '  지움: cys 상시 가동 등록' } catch { }
    }
    # 🔴적대검증 지적 채택(2026-09-08): 프로그램이 이미 없으면(사람이 손으로 지웠거나 백신이 날렸거나)
    #   위 명령을 부를 수단이 없어 **등록만 영원히 남는다.** 맥에는 폴백(launchctl bootout)이 있는데
    #   윈도우에는 없었다 — 두 OS 가 갈리는 자리였다. 스케줄러를 직접 떼는 길을 둔다.
    if (-not $daemonDone) {
        try {
            foreach ($tk in @(Get-CysTasks)) {
                Unregister-ScheduledTask -TaskName $tk.TaskName -Confirm:$false -ErrorAction Stop
                $script:Removed++; Write-Host ('  지움: cys 상시 가동 등록 (' + $tk.TaskName + ')')
            }
        } catch { $script:KeptFail++; Write-Host ('  [남음] cys 상시 가동 등록 — ' + $_.Exception.Message) }
    }

    # footprint: W-HOOK
    Remove-OurHooks $SettingsJs

    # cys 프로그램 지우기 — 기본은 사람이 설정 앱에서 한다(위 머리글의 이유).
    # footprint: W-APP
    # 🔴2026-09-09 실사용자 3호 실기 — 여기가 교착이 났던 자리다.
    #   그 기계는 **폴더는 있는데 설치 목록 항목이 없었다**(지난 설치가 끝까지 못 간 흔한 자리).
    #   설정 앱이 보는 곳이 바로 그 항목이므로, 설정 앱에는 cys 가 **아예 없었다.**
    #   그런데 앞 판은 판별을 「uninstall.exe 가 있는가」 하나로만 했다 ⇒ 사람에게
    #   **설정 앱에서 지우라고 8번 요구**했고, 사람은 할 수 없는 일이라 q 로 빠져나갈 수밖에 없었다.
    #   ⇒ 판별을 두 축으로 가른다. **요구하기 전에 그 항목이 실제로 있는지 먼저 본다** —
    #     사람이 할 수 없는 일을 요구하는 고리가 구조적으로 생기지 못하게.
    $hasRegEntry = Test-Path $RegKey
    if ((Test-Path $UninstExe) -and $UseUninstaller) {
        Write-Host '  cys 제거 프로그램을 실행합니다. (백신이 이 행위를 막을 수 있습니다)'
        try {
            $u = Start-Process -FilePath $UninstExe -ArgumentList '/S' -PassThru -ErrorAction Stop
            if (-not $u.WaitForExit(180000)) { Write-Host '    제거 프로그램이 180초 안에 끝나지 않았습니다. 기다리기를 멈추고 나머지를 지웁니다.' }
        } catch {
            Write-Host ("    제거 프로그램을 실행하지 못했습니다: " + $_.Exception.Message)
            Write-Host '    백신이 막았을 수 있습니다. 그 화면의 이름, 대상 파일, 조치(차단·격리·종료)를 알려 주십시오.'
        }
        Start-Sleep -Seconds 3
    } elseif ((Test-Path $UninstExe) -and $hasRegEntry) {
        Write-Host ''
        Write-Host '  cys 프로그램은 윈도우 설정 앱에서 지워 주십시오 (이 스크립트가 직접 지우지 않습니다).'
        Write-Host '    시작 단추 > 설정 > 앱 > 설치된 앱 > cys > 제거'
        Write-Host '    제거 창이 뜨면 안내대로 진행하시고, 끝나면 이 창으로 돌아오십시오.'
        Write-Host ''
        # 건너뛰기는 없다 — cys 프로그램이 남으면 아래에서 [남음] 이 되고 재설치로 넘어가지 않는다.
        #   (앞 판의 「건너뛰려면 그냥 Enter」는 Enter 만 믿고 곧바로 지우던 시절의 문구였다. 확인 단계가
        #    생긴 뒤에도 그 문구가 남아 있어, 건너뛸 수 있다고 읽히면서 실제로는 멈추게 했다 — 2026-09-08 지적.)
        #   그래서 지워질 때까지 같은 자리에서 다시 묻는다. 그만두고 싶으면 q — 그때는 사실대로 [남음] 으로 남긴다.
        if (-not $Yes) {
            while (Test-Path $UninstExe) {
                $a = Read-Host '  제거를 마치셨으면 Enter 를 눌러 주십시오 (제거하지 않고 여기서 그만두려면 q)'
                if ($a -eq 'q') { break }
                if (Test-Path $UninstExe) { Write-Host '  아직 지워지지 않았습니다. 설정 앱에서 제거를 마친 뒤 이 창으로 돌아와 Enter 를 눌러 주십시오.' }
            }
        }
        # 🔴적대검증 지적 채택(2026-09-08): 앞 판은 Enter 만 믿고 곧바로 폴더와 등록 항목을 뜯어냈다.
        #   사람이 설정 앱에서 지우지 않고 무심코 Enter 만 눌러도 그렇게 됐다 — 그러면 공식 제거기가
        #   해 주는 뒷정리(시작 메뉴 바로가기 등)가 안 된 채 폴더만 사라져 **고아가 남는다.**
        #   ⇒ 정말 지워졌는지 보고, 안 지워졌으면 **우리가 억지로 뜯지 않고** 사실대로 말한다.
        if (Test-Path $UninstExe) {
            $script:KeptFail++
            Write-Host '  [남음] cys 프로그램 — 설정 앱에서 아직 지워지지 않았습니다.'
            Write-Host '         우리가 폴더만 억지로 지우면 시작 메뉴 바로가기 같은 것이 남습니다.'
            Write-Host '         설정 앱에서 제거를 마치신 뒤 같은 줄을 한 번 더 돌려 주십시오.'
            $script:SkipCysDir = $true
        }
    } elseif ((Test-Path $CysDir) -or (Test-Path $CysDirOld)) {
        # 정식 제거 경로를 쓸 수 없는 자리다. 까닭이 둘인데 **사람에게 하는 말이 달라야 한다** —
        #   ⑴목록 항목이 없다  ⇒ 설정 앱에 cys 가 아예 안 보인다(3호가 만난 자리)
        #   ⑵항목은 있는데 제거 프로그램이 없다 ⇒ 설정 앱에서 눌러도 그 자리에서 실패한다
        #   ⛔한 문장으로 뭉뚱그리면 둘 중 하나는 **거짓말**이 된다(agy R1 [1] 지적 채택 2026-09-09 —
        #     앞 판은 ⑵에서도 「항목이 없습니다」라고 적었다. 사람이 설정 앱을 열어 보면 항목이 있다).
        #   ⇒ 이때만 우리가 직접 지운다. 대신 지우기 전에 두 가지를 확인한다 —
        #     ⑴돌고 있지 않은가(돌고 있으면 폴더가 안 지워지고 [남음] 이 거짓이 된다)
        #     ⑵사람이 지금 지워도 된다고 하는가(한 번만 묻는다 · 반복 요구 없음).
        Write-Host ''
        if ($hasRegEntry) {
            Write-Host '  cys 폴더는 있는데 제거 프로그램이 없습니다 (지난 설치가 끝까지 못 간 자리입니다).'
            Write-Host '    설정 앱에 항목은 보이지만 눌러도 그 자리에서 실패합니다 — 그래서 이번에는 이 스크립트가 직접 지웁니다.'
        } else {
            Write-Host '  cys 폴더는 있는데 설치 목록에는 항목이 없습니다 (지난 설치가 끝까지 못 간 자리입니다).'
            Write-Host '    설정 앱에는 cys 가 보이지 않습니다 — 그래서 이번에는 이 스크립트가 직접 지웁니다.'
        }
        foreach ($n in @('cys-app', 'cysd', 'cys')) {
            Get-Process -Name $n -ErrorAction SilentlyContinue | Stop-Process -Force -ErrorAction SilentlyContinue
        }
        Start-Sleep -Seconds 2
        $alive = @(foreach ($n in @('cys-app', 'cysd', 'cys')) { Get-Process -Name $n -ErrorAction SilentlyContinue })
        if ($alive.Count -gt 0) {
            $script:KeptFail++
            $script:SkipCysDir = $true
            Write-Host '  [남음] cys 프로그램 — 아직 실행 중이라 폴더를 지울 수 없습니다.'
            Write-Host '         작업 관리자에서 cys 를 끝내신 뒤 같은 줄을 한 번 더 돌려 주십시오.'
        } elseif (-not $Yes) {
            $a = Read-Host '  이 폴더를 지웁니다. 계속하시려면 Enter 를 눌러 주십시오 (그만두려면 q)'
            if ($a -eq 'q') {
                $script:KeptFail++
                $script:SkipCysDir = $true
                Write-Host '  [남음] cys 프로그램 — 지우지 않고 그만두셨습니다.'
            }
        }
    }

    # cys 가 돌고 있으면 폴더가 지워지지 않는다 — 먼저 멈춘다.
    foreach ($n in @('cys-app', 'cysd', 'cys')) {
        Get-Process -Name $n -ErrorAction SilentlyContinue | Stop-Process -Force -ErrorAction SilentlyContinue
    }
    Start-Sleep -Seconds 2

    if (-not $script:SkipCysDir) {
        Drop 'cys 프로그램' $CysDir
        Drop 'cys 프로그램(옛 자리)' $CysDirOld
        # 공식 제거기가 해 주던 뒷정리다. 우리가 폴더를 지운 길에서는 우리가 함께 지운다.
        $links = @(Get-StartMenuLinks)
        if ($links.Count -eq 0) { Write-Host '  [없음] cys 시작 메뉴 바로가기' }
        else { foreach ($lnk in $links) { Drop 'cys 시작 메뉴 바로가기' $lnk } }
    }
    # footprint: W-REG
    # 🔴2026-09-09 자기규명 — 앞 판은 이 줄이 **조건 없이** 돌았다. 그래서 사람이 설정 앱 제거를 미루고
    #   q 를 누르면(폴더는 그대로 남는데) **목록 항목만 사라졌다.** 그 순간 설정 앱에서 cys 가 없어진다 —
    #   우리가 「저기서 지우십시오」라고 가리킨 바로 그 길을 우리가 없앤 것이다. 다음 실행은 폴더만 남은
    #   상태를 만나고, 앞 판은 거기서 또 설정 앱을 요구했다(= 3호가 만난 교착의 자가 생산 경로).
    #   ⇒ 프로그램을 남겨 두기로 한 실행에서는 그 항목도 함께 남긴다. 둘은 한 쌍이다.
    #   ⚠남긴다는 말은 **설정 앱에서 마저 지우실 수 있을 때만** 참이다. 항목이 애초에 없으면 그 문장은
    #     앞의 안내와 정면으로 어긋난다(agy R1 [1] 지적 채택 — 「항목이 없습니다」라고 말해 놓고
    #     「설정 앱에서 지우실 수 있게 둡니다」라고 적고 있었다).
    if ($script:SkipCysDir -and $hasRegEntry) {
        Write-Host '  남김: cys 설치 목록 항목 (프로그램이 남아 있어 설정 앱에서 지우실 수 있게 둡니다)'
    } else {
        Drop 'cys 설치 목록 항목' $RegKey
    }
    # footprint: W-CYSHOME
    Drop 'cys 계정 자리' $CysHome
    # footprint: W-CLAUDEBIN
    Drop '클로드 실행 파일' $ClaudeExe
    # footprint: W-JARVISHOME
    Drop '자비스 작업 폴더' $JarvisDir
    # footprint: W-SCRIPTCOPY
    Drop '받아 둔 설치 스크립트' $HomePs1
    Drop '받아 둔 설치 스크립트(옛 자리)' $TempPs1
    # footprint: W-AGORA
    Drop '참가 열쇠·이름' $AgoraDir
    # footprint: W-AGORASKILL
    #   ★가리키던 파일이 사라지면 가리키는 쪽도 같이 지운다 - 남겨 두면 다음 자비스가
    #     없는 파일을 읽으려다 막히고, 그것은 안내가 없느니만 못하다.
    foreach ($sd in $AgoraSkillDirs) { Drop '광장 안내 가리키기' $sd }

    # 남의 파일 속 우리 줄 — 파일을 지우지 않는다
    # footprint: W-PATH
    Remove-UserPathSeed
    # footprint: W-CLAUDEJSON
    Remove-JsonKey $ClaudeJson 'hasCompletedOnboarding'
    # footprint: W-CLAUDESETTINGS
    Remove-JsonKey $SettingsJs 'theme'
    Remove-JsonKey $SettingsJs 'skipDangerousModePermissionPrompt'
    Remove-JsonKey $SettingsJs 'remoteControlAtStartup'
    # footprint: W-CLAUDEUSER — 손대지 않는다
    Write-Host '  남김: 클로드 대화·기록'

    Write-Host ''
    if ($script:KeptFail -eq 0) {
        Write-Host ("=== 끝났습니다 — {0} 가지를 지웠고, 못 지운 것은 없습니다. ===" -f $script:Removed)
        return 0
    }
    # 사실만 말한다. 「거의 다 됐다」로 얼버무리면 다음 단계가 그 위에 얹힌다.
    Write-Host ("=== 끝났습니다 — {0} 가지를 지웠고, {1} 가지를 못 지웠습니다. ===" -f $script:Removed, $script:KeptFail)
    Write-Host '    위에 [남음] 으로 표시된 자리가 있습니다. 그대로 두고 다시 설치하면 뒤엉킵니다.'
    Write-Host '    까닭은 보통 셋 중 하나입니다: 프로그램이 아직 돌고 있다 · 백신이 그 파일을 붙들고 있다 · cys 제거를 아직 안 하셨다'
    Write-Host '    같은 줄을 한 번 더 돌려 보시고, 그래도 남으면 그 줄을 알려 주십시오.'
    return 7
}

# ── 본문 ──────────────────────────────────────────────────────────
Invoke-Diagnose
if ($ListOnly) { Write-Host ''; Write-Host '(보기만 했습니다. 아무것도 지우지 않았습니다.)'; exit 0 }

if ($script:Found -eq 0) { Write-Host ''; Write-Host '지울 것이 없습니다.'; exit 0 }

if (-not $Yes) {
    Write-Host ''
    Write-Host '위 목록을 지웁니다. 되돌릴 수 없습니다.'
    $answer = Read-Host '계속하려면 「지웁니다」 라고 쳐 주십시오'
    if ($answer -ne '지웁니다') { Write-Host '그만둡니다 — 아무것도 지우지 않았습니다.'; exit 1 }
}

$rc = Invoke-Purge
exit $rc
