# 반복 막힘 단계별 안내 — 윈도우 실행 입구 (설치기를 함수 묶음으로 읽고 셈·화면·보고서를 잰다)
#
# 무엇을 재는가 (맥판 tests/help-attempts-run.sh 와 같은 11항)
#   ①첫 셈 = 1회·단계1  ②같은 코드 2번째 = 단계2 · 공통 줄 + 그 코드의 두 번째 방법  ③3번째 = 담당자 4줄 + 번호
#   ④다른 코드가 더 뒤 단계에서 나면 앞 코드를 지운다  ⑤같은 단계의 다른 코드는 남긴다
#   ⑥성공 끝(코드 없음·깨우기 도달) = 코드 전부 지움 · 보고 기록은 남김  ⑦깨진 파일 = 단계1 + 올바른 모양으로 다시 씀
#   ⑧곧바로 연락 코드(J-DL-05) 2번째 = 담당자 안내  ⑨미리보기·감지만 = 파일을 만들지 않는다
#   ⑩보고 기록 뒤 다음 셈의 「이전 보고」 글  ⑪환경 보고의 두 줄은 교체된다(중복 0) · 화면 자리
#   ⑫(윈도우 전용) 원격 해결 실행 번호 기록 — 1·2번째 둘 다 OK · 같은 번호 ALREADY · 그 자리를 $null 로 되돌린 사본(새 프로세스)은 2번째가 FAIL
# ★기대 문구는 설치기 상수가 아니라 정본(tests/help-escalation.tsv)에서 읽는다 — 설치기가 틀리면 여기서 붉어진다.
# ⛔네트워크 0 · 실제 설치 0 — 고지를 보이지 않은 실행이라 끝맺음이 원격 해결을 부르지 않는다.
#
# 쓰는 법: powershell -ExecutionPolicy Bypass -File tests\help-attempts-run.ps1 -Dir install-master
#   rc 0 = 전건 통과 · 실패는 「FAIL <이름>」 줄
param([Parameter(Mandatory=$true)][string]$Dir)

$ErrorActionPreference = 'Continue'
try { [Console]::OutputEncoding = [System.Text.Encoding]::UTF8 } catch { }
$THere  = Split-Path -Parent $MyInvocation.MyCommand.Path
$TPhone = '010-7745-5885'
$TTs    = '[0-9]{4}-[0-9]{2}-[0-9]{2}T[0-9]{2}:[0-9]{2}:[0-9]{2}[+-][0-9]{4}'

# 정본 문구
$TS2 = @()
$TS3 = @()
$TOk = ''
$TNo = ''
$TWays = @{}
foreach ($TLn in [System.IO.File]::ReadAllLines((Join-Path $THere 'help-escalation.tsv'), [System.Text.Encoding]::UTF8)) {
    if (-not $TLn -or $TLn.StartsWith('#')) { continue }
    $TP = @($TLn -split "`t")
    if ($TP.Count -ne 3) { continue }
    if ($TP[0] -ceq 'stage2') {
        $TS2 += $TP[2]
    } elseif ($TP[0] -ceq 'stage3') {
        $TS3 += $TP[2]
    } elseif ($TP[0] -ceq 'sent' -and $TP[1] -ceq 'ok') {
        $TOk = $TP[2]
    } elseif ($TP[0] -ceq 'sent' -and $TP[1] -ceq 'no') {
        $TNo = $TP[2]
    } elseif ($TP[0] -ceq 'way') {
        if (-not $TWays.ContainsKey($TP[1])) { $TWays[$TP[1]] = @() }
        $TWays[$TP[1]] += $TP[2]
    }
}
if ($TS2.Count -lt 3 -or $TS3.Count -lt 3 -or -not $TOk -or -not $TNo) { Write-Host '::error::정본(help-escalation.tsv)을 읽지 못했습니다'; exit 2 }

# 스크래치 작업 폴더 — 이름은 install-jarvis · 우리 표식을 둔다(설치기는 표식이 있는 폴더에서만 센다)
$TBase = Join-Path $env:TEMP ('help-attempts-' + [guid]::NewGuid().ToString('N'))
$THome = Join-Path $TBase 'install-jarvis'
New-Item -ItemType Directory -Force -Path $THome | Out-Null
[System.IO.File]::WriteAllText((Join-Path $THome '.jarvis-owned'), "jarvis-installer-owned v1`r`n", (New-Object System.Text.UTF8Encoding($false)))

# 함수 묶음으로만 읽는다(본문은 돌지 않는다).
$env:JARVIS_LIB_ONLY = '1'
$env:JARVIS_HOME = $THome
. (Join-Path $Dir 'bootstrap.ps1')
$env:JARVIS_LIB_ONLY = ''
if (-not (Get-Command Update-HelpAttempts -ErrorAction SilentlyContinue)) { Write-Host '::error::설치기에 Update-HelpAttempts 가 없습니다'; exit 2 }

$TPass = 0
$TFail = 0
function Test-Axis($Name, $Ok, $Why) {
    if ($Ok) {
        $script:TPass++
        Write-Host ('  ok   ' + $Name)
    } else {
        $script:TFail++
        Write-Host ('  FAIL ' + $Name + ' — ' + $Why)
    }
}
# 한 번의 설치 실행을 흉내 낸다 — 끝맺음 전의 전역 상태만 채운다
function Start-Run([string]$Code, [int]$StepN) {
    $script:JCode = $Code
    $script:StepLog.Clear()
    if ($StepN -gt 0) { [void]$script:StepLog.Add('[' + $StepN + '/10] 시험 단계') }
    $script:ReachedWake = $false
    $script:ClosingDone = $false
    $script:NextStep = ''
    $script:ShowRerun = $false
    $script:NoticeShown = $false
}
# Write-Host 는 5.x 에서 정보 스트림(6)으로도 흐른다 — 그것을 받아 화면 줄로 센다
function Get-Screen([scriptblock]$Block) {
    return ,@(& $Block 6>&1 | ForEach-Object { [string]$_ })
}
function Get-StateLines {
    if (-not (Test-Path -LiteralPath $HelpAttemptsFile)) { return ,@() }
    return ,@([System.IO.File]::ReadAllText($HelpAttemptsFile, [System.Text.Encoding]::UTF8) -split "`n")
}
function Find-CodeLine($Code) {
    $re = '\A"' + [regex]::Escape($Code) + '":\{"count":([0-9]+),"first":"(' + $TTs + ')","last":"(' + $TTs + ')","step":"([0-9]+)"\},?\z'
    foreach ($ln in (Get-StateLines)) {
        if ($ln -cmatch $re) { return @{ N = [int]$Matches[1]; First = $Matches[2]; Last = $Matches[3]; Step = [int]$Matches[4] } }
    }
    return $null
}
function Get-Stage2Expect($Code) {
    $e = @('')
    foreach ($t in $TS2) {
        if ($t -cne '<WAY>') { $e += $t; continue }
        $ws = @($TWays[$Code])
        for ($i = 0; $i -lt $ws.Count; $i++) {
            if ($i -eq 0) { $e += ('   - ' + $ws[$i]) } else { $e += ('     ' + $ws[$i]) }
        }
    }
    return ,$e
}
function Get-Stage3Expect($Code) {
    $e = @('')
    foreach ($t in $TS3) { $e += $t.Replace('<PHONE>', $TPhone).Replace('<CODE>', $Code) }
    return ,$e
}
function Test-SameLines($A, $B) {
    return (($A -join "`n") -ceq ($B -join "`n"))
}
function Get-LineIndex($Lines, $Text, [switch]$Prefix) {
    for ($i = 0; $i -lt $Lines.Count; $i++) {
        if ($Prefix) {
            if (([string]$Lines[$i]).StartsWith($Text)) { return $i }
        } elseif ($Lines[$i] -ceq $Text) {
            return $i
        }
    }
    return -1
}

Write-Host '-- 반복 막힘 단계별 안내 (윈도우 · 함수 묶음) --'
try {
    $Mode = 'full'
    Remove-Item -LiteralPath $HelpAttemptsFile -Force -ErrorAction SilentlyContinue

    # ① 첫 셈
    Start-Run 'J-AV-01' 3
    Update-HelpAttempts
    $TScr = Get-Screen { Write-HelpEscalation }
    $TC = Find-CodeLine 'J-AV-01'
    $TLines = Get-StateLines
    $TRaw = [byte[]]@()
    if (Test-Path -LiteralPath $HelpAttemptsFile) { $TRaw = [System.IO.File]::ReadAllBytes($HelpAttemptsFile) }
    $TBom = ($TRaw.Length -ge 3) -and ($TRaw[0] -eq 0xEF) -and ($TRaw[1] -eq 0xBB) -and ($TRaw[2] -eq 0xBF)
    $TShape = ($TRaw.Length -gt 0) -and (-not $TBom) -and ($TRaw -notcontains 13) -and ($TLines[0] -ceq '{"v":1,') -and ($TLines[1] -ceq '"codes":{')
    $TLogged = @(Get-Content -LiteralPath $LogFile | Where-Object { $_ -like '*help attempts: J-AV-01 count=1 step=3' }).Count -eq 1
    $TOkv = ($script:HelpStage -eq 1) -and ($null -ne $TC) -and ($TC.N -eq 1) -and ($TC.Step -eq 3) -and ($TC.First -ceq $TC.Last) -and ($TScr.Count -eq 0) -and $TShape -and $TLogged
    Test-Axis '① 첫 셈 = 1회 · 단계1 · 화면에 더하는 줄 없음 · 고정 모양(BOM·CR 없음) · 기록 한 줄' $TOkv ('단계=' + $script:HelpStage + ' 파일=' + ($TLines -join ' | ') + ' 화면=' + ($TScr -join ' | ') + ' 기록=' + $TLogged)

    # ② 같은 코드 2번째
    $TFirst1 = ''
    if ($null -ne $TC) { $TFirst1 = $TC.First }
    Start-Run 'J-AV-01' 3
    Update-HelpAttempts
    $TScr = Get-Screen { Write-HelpEscalation }
    $TC = Find-CodeLine 'J-AV-01'
    $TExp = Get-Stage2Expect 'J-AV-01'
    $TOkv = ($script:HelpStage -eq 2) -and ($null -ne $TC) -and ($TC.N -eq 2) -and ($TC.First -ceq $TFirst1) -and (Test-SameLines $TScr $TExp) -and (-not $script:HelpStage3)
    Test-Axis '② 같은 코드 2번째 = 단계2 · 공통 줄 + 그 코드의 두 번째 방법(글자 그대로 · 순서)' $TOkv ('단계=' + $script:HelpStage + ' 화면=' + ($TScr -join ' | '))

    # ③ 3번째
    Start-Run 'J-AV-01' 3
    Update-HelpAttempts
    $TScr = Get-Screen { Write-HelpEscalation }
    $TExp = Get-Stage3Expect 'J-AV-01'
    $TPhoneShown = @($TScr | Where-Object { $_.Contains($TPhone) }).Count -eq 1
    $TOkv = ($script:HelpStage -eq 3) -and (Test-SameLines $TScr $TExp) -and $TPhoneShown -and $script:HelpStage3
    Test-Axis '③ 3번째 = 단계3 · 담당자 4줄 + 번호 + 진단 코드' $TOkv ('단계=' + $script:HelpStage + ' 화면=' + ($TScr -join ' | '))

    # ④ 다른 코드가 더 뒤 단계에서 나면 앞 코드를 지운다(D4)
    Start-Run 'J-LOGIN-01' 5
    Update-HelpAttempts
    $TGone = $null -eq (Find-CodeLine 'J-AV-01')
    $TC = Find-CodeLine 'J-LOGIN-01'
    $TOkv = $TGone -and ($null -ne $TC) -and ($TC.N -eq 1) -and ($TC.Step -eq 5) -and ($script:HelpStage -eq 1)
    Test-Axis '④ 더 뒤 단계의 다른 코드 = 앞 단계 코드를 지운다' $TOkv ('파일=' + ((Get-StateLines) -join ' | '))

    # ⑤ 같은 단계의 다른 코드는 남긴다 · 코드 이름순 · 마지막 코드 줄만 쉼표 없음
    Start-Run 'J-NET-01' 5
    Update-HelpAttempts
    $TLines = Get-StateLines
    $TIL = Get-LineIndex $TLines '"J-LOGIN-01"' -Prefix
    $TIN = Get-LineIndex $TLines '"J-NET-01"' -Prefix
    $TOkv = ($null -ne (Find-CodeLine 'J-LOGIN-01')) -and ($null -ne (Find-CodeLine 'J-NET-01')) -and ($TIL -ge 0) -and ($TIL -lt $TIN) -and $TLines[$TIL].EndsWith(',') -and (-not $TLines[$TIN].EndsWith(','))
    Test-Axis '⑤ 같은 단계의 다른 코드는 남긴다(이름순 · 쉼표 모양)' $TOkv ('파일=' + ($TLines -join ' | '))

    # ⑥ 성공 끝 = 코드 전부 지움 · 보고 기록은 남김
    Start-Run 'J-NET-01' 5
    $script:RhId = 'CGVJ9YVQ'
    Save-HelpLastReport
    Start-Run '' 10
    $script:ReachedWake = $true
    Update-HelpAttempts
    $TLines = Get-StateLines
    $TCodeLeft = @($TLines | Where-Object { $_ -cmatch '\A"J-' }).Count
    $TRep = @($TLines | Where-Object { $_ -cmatch ('\A"last_report":\{"id":"CGVJ9YVQ","at":"' + $TTs + '","code":"J-NET-01"\}\z') }).Count
    $TSt = Read-HelpAttempts
    $TOkv = ($TCodeLeft -eq 0) -and ($TRep -eq 1) -and ($script:HelpStage -eq 1) -and ($TLines[0] -ceq '{"v":1,') -and ($TSt.Codes.Count -eq 0) -and ($null -ne $TSt.Report) -and ($TSt.Report.Id -ceq 'CGVJ9YVQ')
    Test-Axis '⑥ 성공 끝(코드 없음 · 깨우기 도달) = 코드 줄 전부 지움 · last_report 유지' $TOkv ('파일=' + ($TLines -join ' | '))

    # ⑦ 깨진 파일 = 단계1 + 올바른 모양으로 다시 씀
    [System.IO.File]::WriteAllText($HelpAttemptsFile, "not json {`n", (New-Object System.Text.UTF8Encoding($false)))
    Start-Run 'J-AV-02' 4
    Update-HelpAttempts
    $TC = Find-CodeLine 'J-AV-02'
    $TLines = Get-StateLines
    $TLogged = @(Get-Content -LiteralPath $LogFile | Where-Object { $_ -like '*help attempts: unreadable - reset' }).Count -ge 1
    $TOkv = ($script:HelpStage -eq 1) -and ($null -ne $TC) -and ($TC.N -eq 1) -and ($TLines.Count -eq 6) -and ($TLines[0] -ceq '{"v":1,') -and ($TLines[1] -ceq '"codes":{') -and ($TLines[3] -ceq '}') -and ($TLines[4] -ceq '}') -and ($TLines[5] -ceq '') -and $TLogged
    Test-Axis '⑦ 깨진 파일 = 단계1 · 올바른 모양으로 다시 씀 · 기록 한 줄' $TOkv ('파일=' + ($TLines -join ' | ') + ' 기록=' + $TLogged)

    # ⑧ 곧바로 연락 코드(J-DL-05) 2번째 = 담당자 안내
    Remove-Item -LiteralPath $HelpAttemptsFile -Force -ErrorAction SilentlyContinue
    Start-Run 'J-DL-05' 5
    Update-HelpAttempts
    $TScr1 = Get-Screen { Write-HelpEscalation }
    Start-Run 'J-DL-05' 5
    Update-HelpAttempts
    $TScr2 = Get-Screen { Write-HelpEscalation }
    $TExp = Get-Stage3Expect 'J-DL-05'
    $TOkv = ($TScr1.Count -eq 0) -and ($script:HelpStage -eq 2) -and (Test-SameLines $TScr2 $TExp) -and $script:HelpStage3
    Test-Axis '⑧ J-DL-05 2번째 = 곧바로 담당자 안내(stage3)' $TOkv ('1회=' + ($TScr1 -join ' | ') + ' 2회=' + ($TScr2 -join ' | '))

    # ⑨ 미리보기·감지만 = 읽지도 쓰지도 않는다
    Remove-Item -LiteralPath $HelpAttemptsFile -Force -ErrorAction SilentlyContinue
    $TMade = $false
    $TStageBad = $false
    $TSaid = 0
    foreach ($TM in @('dry', 'detect')) {
        $Mode = $TM
        Start-Run 'J-AV-01' 3
        Update-HelpAttempts
        Update-HelpAttempts
        $script:RhId = 'CGVJ9YVQ'
        Save-HelpLastReport
        $TScr = Get-Screen { Write-HelpEscalation }
        if (Test-Path -LiteralPath $HelpAttemptsFile) { $TMade = $true }
        if ($script:HelpStage -ne 1) { $TStageBad = $true }
        $TSaid += $TScr.Count
    }
    $Mode = 'full'
    $TOkv = (-not $TMade) -and (-not $TStageBad) -and ($TSaid -eq 0)
    Test-Axis '⑨ 미리보기·감지만 = 파일 안 생김 · 단계1 · 화면 줄 없음' $TOkv ('파일생김=' + $TMade + ' 단계틀림=' + $TStageBad + ' 화면줄=' + $TSaid)

    # ⑩ 보고 기록 뒤 다음 셈의 「이전 보고」 글
    Remove-Item -LiteralPath $HelpAttemptsFile -Force -ErrorAction SilentlyContinue
    Start-Run 'J-AV-01' 3
    Update-HelpAttempts
    $TPrev0 = $script:HelpPrevReport
    $script:RhId = 'CGVJ9YVQ'
    Save-HelpLastReport
    Start-Run 'J-AV-01' 3
    Update-HelpAttempts
    $TPrevSame = $script:HelpPrevReport
    Start-Run 'J-AV-02' 3
    Update-HelpAttempts
    $TPrevOther = $script:HelpPrevReport
    $TC = Find-CodeLine 'J-AV-01'
    $TOkv = ($TPrev0 -ceq '') -and ($TPrevSame -cmatch ('\ACGVJ9YVQ \(' + $TTs + ' · 같은 코드\)\z')) -and ($TPrevOther -cmatch ('\ACGVJ9YVQ \(' + $TTs + ' · 다른 코드 J-AV-01\)\z')) -and ($null -ne $TC) -and ($TC.N -eq 2)
    Test-Axis '⑩ last_report 저장 뒤 이전 보고 = 「ID (시각 · 같은 코드|다른 코드 코드명)」' $TOkv ('처음=' + $TPrev0 + ' 같은=' + $TPrevSame + ' 다른=' + $TPrevOther)

    # ⑪ 끝맺음 세 번 — 환경 보고의 두 줄은 교체(중복 0) · 화면 자리(진단 코드 줄 다음 · 회수 경로 줄 앞 · 사진 부탁은 다시 하시는 법 앞)
    Remove-Item -LiteralPath $HelpAttemptsFile -Force -ErrorAction SilentlyContinue
    [System.IO.File]::WriteAllText($ReportFile, ("[자비스] 환경 보고 v0`r`n`r`n- 진단 코드: **J-AV-01** (x)`r`n"), (New-Object System.Text.UTF8Encoding($false)))
    Start-Run 'J-AV-01' 3
    $script:RhId = 'CGVJ9YVQ'
    Save-HelpLastReport
    $TScrA = Get-Screen { Write-ClosingNote }
    Start-Run 'J-AV-01' 3
    $TScrB = Get-Screen { Write-ClosingNote }
    Start-Run 'J-AV-01' 3
    $TScrC = Get-Screen { Write-ClosingNote }
    $TRepLines = @(Get-Content -LiteralPath $ReportFile -Encoding UTF8)
    $TNCode = @($TRepLines | Where-Object { $_ -match '^- 진단 코드: ' }).Count
    $TNSame = @($TRepLines | Where-Object { $_ -match '^- 같은 진단 코드: ' }).Count
    $TNPrev = @($TRepLines | Where-Object { $_ -match '^- 이전 보고: ' }).Count
    $TSameOk = @($TRepLines | Where-Object { $_ -cmatch ('\A- 같은 진단 코드: 3회째 \(이 컴퓨터 · 첫 기록 ' + $TTs + '\)\z') }).Count -eq 1
    $TPrevOk = @($TRepLines | Where-Object { $_ -cmatch ('\A- 이전 보고: CGVJ9YVQ \(' + $TTs + ' · 같은 코드\)\z') }).Count -eq 1
    $TOkv = ($TNCode -eq 1) -and ($TNSame -eq 1) -and ($TNPrev -eq 1) -and $TSameOk -and $TPrevOk
    Test-Axis '⑪ 환경 보고 「같은 진단 코드」·「이전 보고」 줄이 교체된다(중복 0)' $TOkv ('보고=' + ($TRepLines -join ' | '))

    $TPosA = ($TScrA -cnotcontains $TS2[0]) -and ($TScrA -cnotcontains $TS3[0])
    $TICodeB = Get-LineIndex $TScrB '  진단 코드: J-AV-01' -Prefix
    $TIS2B = Get-LineIndex $TScrB $TS2[0]
    $TISendB = Get-LineIndex $TScrB '  막히면 이 두 파일을 보내 주십시오: ' -Prefix
    $TPosB = ($TICodeB -ge 0) -and ($TScrB[$TICodeB + 1] -ceq '') -and ($TIS2B -eq $TICodeB + 2) -and ($TISendB -gt $TIS2B) -and ($TScrB -cnotcontains $TNo)
    $TICodeC = Get-LineIndex $TScrC '  진단 코드: J-AV-01' -Prefix
    $TIS3C = Get-LineIndex $TScrC $TS3[0]
    $TISendC = Get-LineIndex $TScrC '  막히면 이 두 파일을 보내 주십시오: ' -Prefix
    $TINoC = Get-LineIndex $TScrC $TNo
    $TIRerunC = Get-LineIndex $TScrC '  == 다시 하시는 법' -Prefix
    $TPosC = ($TICodeC -ge 0) -and ($TScrC[$TICodeC + 1] -ceq '') -and ($TIS3C -eq $TICodeC + 2) -and ($TISendC -gt $TIS3C) -and ($TINoC -gt $TISendC) -and ($TIRerunC -gt $TINoC) -and ($TScrC -cnotcontains $TOk)
    $TOkv = $TPosA -and $TPosB -and $TPosC
    Test-Axis '⑪ 화면 자리 = 진단 코드 줄 다음 · 회수 경로 줄 앞 · 전송 못 한 끝의 사진 부탁은 다시 하시는 법 앞' $TOkv ('1회=' + $TPosA + ' 2회=' + $TPosB + ' 3회=' + $TPosC + ' 3회 화면=' + ($TScrC -join ' | '))

    # ⑫ (윈도우 전용) 원격 해결 실행 번호 기록 — 1번째 = 새 파일(Move) · 2번째부터 = 바꿔 끼우기(File.Replace)
    #   백업 이름 자리에 $null 을 넘기던 판은 2번째 기록이 FAIL 이었다(= 둘째 명령부터 실행 0). 부르는 쪽처럼 그대로 받는다(글 하나여야 한다).
    Remove-Item -LiteralPath $RemoteHelpSeqFile -Force -ErrorAction SilentlyContinue
    $TR1 = Save-RemoteHelpExecuted 101
    $TR2 = Save-RemoteHelpExecuted 102
    $TR3 = Save-RemoteHelpExecuted 101
    $TSeqText = ''
    if (Test-Path -LiteralPath $RemoteHelpSeqFile) { $TSeqText = [System.IO.File]::ReadAllText($RemoteHelpSeqFile, [System.Text.Encoding]::UTF8) }
    $TOkv = ($TR1 -is [string]) -and ($TR1 -ceq 'OK') -and ($TR2 -is [string]) -and ($TR2 -ceq 'OK') -and ($TR3 -is [string]) -and ($TR3 -ceq 'ALREADY') -and ($TSeqText -ceq '[101,102]') -and (-not (Test-Path -LiteralPath ($RemoteHelpSeqFile + '.tmp')))
    Test-Axis '⑫ 실행 번호 기록 = 1번째(새 파일)·2번째(바꿔 끼우기) 둘 다 OK · 같은 번호 = ALREADY · 파일 = [101,102]' $TOkv ('1=' + $TR1 + ' 2=' + $TR2 + ' 3=' + $TR3 + ' 파일=' + $TSeqText)

    # ⑫ 뮤턴트 — 설치기 사본에서 이 기록 자리 하나만 진짜 null → $null 로 되돌려 **새 powershell 프로세스**에서 부른다.
    #   왜 새 프로세스인가: 같은 프로세스에서 사본을 다시 읽으면 함수·전역($RemoteHelpSeqFile 등)이 이 시험의 것을 덮는다 —
    #   자식 범위(& { . 사본 })로 감싸도 사본 안의 $script: 대입은 이 스크립트 범위로 샌다. 프로세스는 끝나면 아무것도 남기지 않는다.
    #   대조군(바꾸지 않은 사본)을 같은 길로 불러 OK OK 를 받아야 한다 — 뮤턴트의 FAIL 이 불러 오는 길이 아니라 그 한 자리 때문임을 보인다.
    #   (되돌린 글은 이어 붙여 만든다 — 저장소의 「Replace 에 $null」 grep 이 이 시험 파일에서 거짓으로 잡히지 않게)
    $TSeqGood = '[System.IO.File]::Replace($tmp, $RemoteHelpSeqFile, [NullString]::Value)'
    $TSeqBad  = $TSeqGood.Replace('[NullString]::Value', ('$' + 'null'))
    $TAttGood = '[System.IO.File]::Replace($fullTmp, $full, [NullString]::Value)'
    $TSrc = [System.IO.File]::ReadAllText((Join-Path $Dir 'bootstrap.ps1'), [System.Text.Encoding]::UTF8)
    $TMut = $TSrc.Replace($TSeqGood, $TSeqBad)
    $TSites = [regex]::Matches($TSrc, [regex]::Escape($TSeqGood)).Count
    $TMutOk = ($TSites -eq 1) -and ([regex]::Matches($TSrc, [regex]::Escape($TSeqBad)).Count -eq 0) -and ([regex]::Matches($TMut, [regex]::Escape($TSeqBad)).Count -eq 1) -and ([regex]::Matches($TMut, [regex]::Escape($TSeqGood)).Count -eq 0) -and ([regex]::Matches($TMut, [regex]::Escape($TAttGood)).Count -eq 1) -and ($TMut.Length -eq ($TSrc.Length - $TSeqGood.Length + $TSeqBad.Length))
    $TChild = Join-Path $TBase 'seq-child.ps1'
    [System.IO.File]::WriteAllText($TChild, (@(
        'param([string]$Lib, [string]$SeqHome)',
        '$env:JARVIS_LIB_ONLY = ''1''',
        '$env:JARVIS_HOME = $SeqHome',
        '. $Lib',
        '$a = Save-RemoteHelpExecuted 201',
        '$b = Save-RemoteHelpExecuted 202',
        'Write-Output (''SEQREC '' + $a + '' '' + $b)'
    ) -join "`r`n"), (New-Object System.Text.UTF8Encoding($true)))
    # 이 시험을 돌리는 바로 그 powershell 실행 파일(5.1) — PATH 의 다른 판을 집지 않는다
    $TPsExe = [System.Diagnostics.Process]::GetCurrentProcess().MainModule.FileName
    $TSeen = @{}
    foreach ($TCase in @(@{ N = 'control'; Text = $TSrc }, @{ N = 'mutant'; Text = $TMut })) {
        $TLib = Join-Path $TBase ($TCase.N + '-bootstrap.ps1')
        $TSeqHome = Join-Path $TBase ($TCase.N + '-home')
        New-Item -ItemType Directory -Force -Path $TSeqHome | Out-Null
        # BOM 을 붙여 쓴다 — 5.1 은 BOM 없는 .ps1 을 ANSI 로 읽어 한글 리터럴이 깨진다(설치기 머리말)
        [System.IO.File]::WriteAllText($TLib, $TCase.Text, (New-Object System.Text.UTF8Encoding($true)))
        $TOut = @(& $TPsExe -NoProfile -NonInteractive -ExecutionPolicy Bypass -File $TChild $TLib $TSeqHome 2>&1 | ForEach-Object { [string]$_ })
        $TLine = @($TOut | Where-Object { $_ -cmatch '\ASEQREC ' })
        if ($TLine.Count -eq 1) {
            $TSeen[$TCase.N] = $TLine[0]
        } else {
            $TAll = $TOut -join ' | '
            if ($TAll.Length -gt 600) { $TAll = $TAll.Substring(0, 600) }
            $TSeen[$TCase.N] = 'none(' + $TAll + ')'
        }
    }
    $TOkv = $TMutOk -and ($TSeen['control'] -ceq 'SEQREC OK OK') -and ($TSeen['mutant'] -ceq 'SEQREC OK FAIL')
    Test-Axis '⑫ 뮤턴트 = 이 기록 자리만 $null 로 되돌린 사본은 2번째 기록이 FAIL · 대조 사본 = OK OK (새 프로세스)' $TOkv ('자리=' + $TSites + ' 한 자리 치환=' + $TMutOk + ' 대조=' + $TSeen['control'] + ' 뮤턴트=' + $TSeen['mutant'])
} catch {
    $TFail++
    Write-Host ('  FAIL 예외 — ' + $_.Exception.Message)
} finally {
    Remove-Item -LiteralPath $TBase -Recurse -Force -ErrorAction SilentlyContinue
    $env:JARVIS_HOME = ''
}

Write-Host ''
Write-Host ('통과 ' + $TPass + ' · 실패 ' + $TFail)
if ($TFail -eq 0 -and $TPass -gt 0) { exit 0 }
exit 1
