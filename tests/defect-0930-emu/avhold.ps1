# ⓔ 백신 보류 1분 판정 — 받는 파일이 1분 안 늘고 + 진행 전송이 연달아 실패하면 붙든 파일을 지우고 한 번 다시 받는다(재유발 1회 상한).
#   시계 = 가짜 Start-Sleep 이 1초씩 민다(실제로 기다리지 않는다) · 전송 = 함수 묶음 셸의 닫힌 로컬 포트(127.0.0.1:9)로 실제 요청이 catch 까지 간다.
#   ⚠여기서 안 재는 것(윈도우 실기 몫): 백신이 같은 파일을 다시 물어보는가 · 백신 창이 실제로 앞으로 오는가.
param([string]$Src, [string]$Sb, [string]$Case)
. (Join-Path $PSScriptRoot 'lib.ps1') -Src $Src -Sb $Sb
$env:JARVIS_NO_PROGRESS = ''
$Mode = 'full'; $script:NoticeShown = $true
$script:Said = New-Object System.Collections.ArrayList
function Say($t) { [void]$script:Said.Add([string]$t) }
function Send-EvidenceOnce($r) { }
function Get-ProcTree($id) { return @() }
$script:AvTitles = @()
function Get-AvWindowTitles { return @($script:AvTitles) }
$script:FrontCalls = 0
function Show-AvWindowFront { $script:FrontCalls++; return $false }
$script:Clock = 0
$script:OnTick = { }
function Start-Sleep { $script:Clock += 1000; & $script:OnTick }
$script:Procs = New-Object System.Collections.ArrayList
function New-FakeProc {
    $o = [pscustomobject]@{ Id = 999900 + $script:Procs.Count; ExitCode = $null; Dead = $false; ExitAt = -1; Rc = 0 }
    $o | Add-Member -MemberType ScriptProperty -Name HasExited -Value { if ((-not $this.Dead) -and ($this.ExitAt -ge 0) -and ($script:Clock -ge $this.ExitAt)) { $this.Dead = $true; $this.ExitCode = $this.Rc }; $this.Dead }
    $o | Add-Member -MemberType ScriptMethod -Name Kill -Value { $this.Dead = $true; $this.ExitCode = -1 }
    $o | Add-Member -MemberType ScriptMethod -Name WaitForExit -Value { return [bool]$this.HasExited }
    [void]$script:Procs.Add($o)
    return $o
}
function Grow($path, [long]$bytes) {
    New-Item -ItemType Directory -Force -Path (Split-Path -Parent $path) | Out-Null
    $fs = [System.IO.File]::Open($path, [System.IO.FileMode]::OpenOrCreate)
    try { $fs.SetLength($bytes) } finally { $fs.Dispose() }
}
$vdl = Join-Path $env:USERPROFILE '.claude/downloads'
$vfile = Join-Path $vdl 'claude-9.9.9-win32-x64.exe'
$tr = Join-Path $env:JARVIS_HOME 'claude-install.log'
$script:Launch = 0
function Start-ClaudeInstallChild($psExe, $cmd) { $script:Launch++; return (New-FakeProc) }
function Install-ClaudeDirect { $script:DirectCalls++; return $false }
$script:DirectCalls = 0
function Judged { return @($script:Said | Where-Object { $_ -match '1분째 멈춰' }).Count }
function JudgeLines {
    # 판정 문구 = 30초 대기 안내 줄(「아직 설치 중입니다」)을 뺀 나머지 · 그 줄은 이번 판정의 문구가 아니다
    return (@($script:Said | Where-Object { $_ -notmatch '아직 설치 중입니다' }) -join ' | ')
}
function JudgeBlock {
    # 판정 문구 = 「1분째 멈춰」부터 예외 폴더 되돌리기 줄까지(그 뒤의 J-AV-01 카드 문구는 이번 판정의 문구가 아니다)
    $a = @($script:Said); $i = -1; $k = $a.Count - 1
    for ($n = 0; $n -lt $a.Count; $n++) { if (($i -lt 0) -and ($a[$n] -match '1분째 멈춰')) { $i = $n }; if (($i -ge 0) -and ($a[$n] -match '예외에서 지우셔도')) { $k = $n; break } }
    if ($i -lt 0) { return '' }
    return (@($a[$i..$k]) -join ' | ')
}
function Run-Vendor {
    $ClaudeInstallWaitMs = 240000
    $script:rc = $null
    try { $script:rc = Step-InstallClaude } catch { $script:rc = 'ERR ' + $_ }
}
switch ($Case) {
    'vendor-grow-stop' {
        # ⑴ 받는 파일이 10초 자라다 멈춤(크기 값은 판정과 무관 · 맥에서 큰 파일 늘리기는 느려 작게) · 대기 전 전송 1회 성공 뒤 실패 → 1분 안 판정 · 재유발 정확히 1회 · 문구 관측만
        $script:ProgressEverOk = $true; $script:ProgressFailRun = 0
        $script:OnTick = { if ($script:Launch -eq 1 -and $script:Clock -le 10000) { Grow $vfile ([long]$script:Clock * 10) } }
        Run-Vendor
        $j = JudgeBlock
        T ((Judged) -ge 1) 'ⓔ⑴ 자라다(10초) 멈춘 파일 + 전송 연속 실패 → 판정 1' ('said=' + $j)
        T ($script:Launch -eq 2) 'ⓔ⑴ 재유발 = 정확히 1회(공식 설치기 두 번째 실행 1건 · 세 번째 0)' ('launch=' + $script:Launch)
        T (($j -notmatch '파일 전송') -and ($j -notmatch '인터넷')) 'ⓔ⑴ 판정 문구에 「파일 전송」·「인터넷」 0(백신 창 제목 미관측)' $j
        T ($j -match '확인 창이 있으면 그 창의 안내대로 진행을 허용해 주세요\.') 'ⓔ⑴ 판정 문구 = 관측만 · 확인 창 조건부' $j
        T (-not (Test-Path -LiteralPath $vfile)) 'ⓔ⑴ 붙든 파일(우리가 본 그 파일)을 지웠다' ('exists=' + (Test-Path -LiteralPath $vfile))
        T ($script:FrontCalls -ge 1) 'ⓔ⑴ 다시 받은 뒤 백신 창 앞으로 시도' ('front=' + $script:FrontCalls)
        T (($script:DirectCalls -eq 0) -and ($script:rc -eq 4) -and ($script:JCode -eq 'J-AV-01')) 'ⓔ 두 번째 판정 = 다시 받지 않고 J-AV-01(직접 받기 0 · 재유발 한 실행 1회)' ('direct=' + $script:DirectCalls + ' rc=' + $script:rc + ' j=' + $script:JCode)
        $ex = @($script:Said | Where-Object { $_ -match '「예외\(허용\)」에 아래 폴더' }).Count
        $all = (@($AvExceptDirs | Where-Object { $j.Contains('· ' + (Redact $_)) }).Count -eq 3)
        T (($ex -eq 1) -and $all -and ($j -match '설치가 끝나면 그 폴더들을 예외에서 지우셔도')) 'ⓔ 첫 막힘에 예외 폴더 3곳을 한 화면에 한 번 · 되돌리기 한 줄' ('ex=' + $ex + ' all=' + $all + ' · ' + $j)
        T ($j -notmatch '끄') 'ⓔ 백신 끄기 안내 0' $j
        $at = [regex]::Match((Get-Content -LiteralPath $LogFile -Raw), 'av hold judged')
        T ($at.Success) 'ⓔ⑴ 기록 파일에 판정 한 줄' 'log 에 av hold judged 없음'
    }
    'vendor-v3-title' {
        # 백신 창 제목이 V3 로 관측됐을 때만 괄호 속 「파일 전송」 예시
        $script:ProgressEverOk = $true; $script:ProgressFailRun = 0
        $script:AvTitles = @('V3 Lite (V3Lite)')
        Run-Vendor
        $j = JudgeLines
        T ($j -match '이 백신에서는 「파일 전송」 단추로 보였습니다') 'ⓔ V3 창 제목 관측 → 괄호 예시 「파일 전송」' $j
    }
    'vendor-growing' {
        # ⑵ 진행 전송만 실패 · 파일은 계속 자람 → 판정 0
        $script:ProgressEverOk = $true; $script:ProgressFailRun = 0
        $script:OnTick = { Grow $vfile ([long]$script:Clock / 100) }
        Run-Vendor
        T (((Judged) -eq 0) -and ($script:Launch -eq 1)) 'ⓔ⑵ 파일이 자라는 중 → 판정 0 · 재유발 0' ('launch=' + $script:Launch + ' · ' + (JudgeLines))
        T ($script:ProgressFailRun -ge 2) 'ⓔ⑵ 전송 실패는 세어졌다(catch 에서만)' ('failrun=' + $script:ProgressFailRun)
    }
    'vendor-none' {
        # ⑶-벤더 관측 파일 없음 · 설치 기록도 안 자람 + 전송 실패 → 판정 1(노트북 실측 모양 = 받기 폴더 비어 있음)
        $script:ProgressEverOk = $true; $script:ProgressFailRun = 0
        Run-Vendor
        T (((Judged) -ge 1) -and ($script:Launch -eq 2)) 'ⓔ⑶-벤더 파일 미생성 + 기록 정지 → 판정 1 · 재유발 1' ('launch=' + $script:Launch + ' · ' + (JudgeLines))
    }
    'vendor-transcript-grows' {
        # ⑶-벤더 관측 파일 없음이어도 설치 기록이 자라면 판정 0
        $script:ProgressEverOk = $true; $script:ProgressFailRun = 0
        $script:OnTick = { Add-Content -LiteralPath $tr -Value ('line ' + $script:Clock) }
        Run-Vendor
        T (((Judged) -eq 0) -and ($script:Launch -eq 1)) 'ⓔ⑶-벤더 설치 기록이 자람 → 판정 0' ('launch=' + $script:Launch + ' · ' + (JudgeLines))
    }
    'vendor-setup-done' {
        # 공식 설치기가 받기를 끝냈다고 말한 뒤(Setting up Claude Code) 설치 구간에서 멈춤 → 받기 보류로 오인하지 않는다(판정 0)
        $script:ProgressEverOk = $true; $script:ProgressFailRun = 0
        $script:OnTick = { if ($script:Clock -eq 5000) { Grow $vfile 5000000; Add-Content -LiteralPath $tr -Value 'Setting up Claude Code...' } }
        Run-Vendor
        T (((Judged) -eq 0) -and ($script:Launch -eq 1)) 'ⓔ 받기 끝(Setting up Claude Code) 뒤 멈춤 → 판정 0' ('launch=' + $script:Launch + ' · ' + (JudgeLines))
    }
    'vendor-delete-fail' {
        # ⑷ 붙든 파일 지우기 실패 → 다시 받지 않음(재시도 0) · 직접 받기로도 가지 않음 · J-AV-01 길
        $script:ProgressEverOk = $true; $script:ProgressFailRun = 0
        $script:OnTick = { if ($script:Clock -le 3000) { Grow $vfile ([long]$script:Clock * 1000) } }
        function Remove-Item { $p = [string]($args | Where-Object { $_ -is [string] -and $_ -match 'claude-9\.9\.9' } | Select-Object -First 1); if ($p) { throw [System.IO.IOException]::new('in use') }; Microsoft.PowerShell.Management\Remove-Item @args }
        Run-Vendor
        T ($script:Launch -eq 1) 'ⓔ⑷ 지우기 실패 → 다시 받기 0' ('launch=' + $script:Launch)
        T ($script:DirectCalls -eq 0) 'ⓔ⑷ 지우기 실패 → 직접 받기 0(같은 자리에서 또 막힌다)' ('direct=' + $script:DirectCalls)
        T (($script:rc -eq 4) -and ($script:JCode -eq 'J-AV-01')) 'ⓔ⑷ J-AV-01 · rc 4' ('rc=' + $script:rc + ' j=' + $script:JCode)
        T ((Get-Content -LiteralPath $LogFile -Raw) -match 'still held') 'ⓔ⑷ 기록 = 아직 붙들려 있음' 'log 에 still held 없음'
    }
    'vendor-unread-log' {
        # 설치 기록을 못 읽으면(표지 있음·없음을 모름) 판정하지 않는다 — 못 읽음을 「표지 없음」으로 삼키지 않는다
        $script:ProgressEverOk = $true; $script:ProgressFailRun = 0
        function Test-AvSetupDone($p) { return 'unread' }
        $script:OnTick = { if ($script:Clock -le 3000) { Grow $vfile ([long]$script:Clock * 10) } }
        Run-Vendor
        T (((Judged) -eq 0) -and ($script:Launch -eq 1)) 'ⓔ 설치 기록 못 읽음 → 판정 0' ('launch=' + $script:Launch + ' · ' + (JudgeLines))
    }
    'vendor-delete-late' {
        # 끈 설치기의 자식이 잠깐 쥐고 있어 첫 지우기만 실패 → 다시 해 보고 지워지면 한 번 더 받는다(붙들림으로 오판하지 않는다)
        $script:ProgressEverOk = $true; $script:ProgressFailRun = 0
        $script:OnTick = { if (($script:Launch -eq 1) -and ($script:Clock -le 3000)) { Grow $vfile ([long]$script:Clock * 10) } }
        $script:RmFails = 1
        function Remove-Item { $p = [string]($args | Where-Object { $_ -is [string] -and $_ -match 'claude-9\.9\.9' } | Select-Object -First 1); if ($p -and ($script:RmFails -gt 0)) { $script:RmFails--; throw [System.IO.IOException]::new('in use') }; Microsoft.PowerShell.Management\Remove-Item @args }
        Run-Vendor
        T ($script:Launch -eq 2) 'ⓔ 첫 지우기만 실패 → 다시 해 보고 지워지면 다시 받기 1회' ('launch=' + $script:Launch)
    }
    'vendor-no-ok-before' {
        # ⑹ 1/10 부터 전송 실패(대기 전 성공 0) → 판정 0
        $script:ProgressEverOk = $false; $script:ProgressFailRun = 0
        Send-Progress '1/10' 'start' $null $null $null
        Run-Vendor
        T (((Judged) -eq 0) -and ($script:Launch -eq 1)) 'ⓔ⑹ 처음부터 막힌 망 → 판정 0' ('launch=' + $script:Launch + ' everok=' + $script:ProgressEverOk + ' · ' + (JudgeLines))
    }
    'progress-count' {
        # 실패 수 세기 = 실제로 보냈다가 실패한 경우만 · 조기 return(흉내 레버)은 세지 않는다
        $script:ProgressFailRun = 0
        $env:JARVIS_NO_PROGRESS = '1'; Send-Progress '2/10' 'wait' 1 $null $null
        $a = [int]$script:ProgressFailRun
        $env:JARVIS_NO_PROGRESS = ''; Send-Progress '2/10' 'wait' 2 $null $null; Send-Progress '2/10' 'wait' 3 $null $null
        T (($a -eq 0) -and ([int]$script:ProgressFailRun -eq 2)) 'ⓔ 전송 실패 수 = catch 에서만(레버 조기 return 0 · 실패 2)' ('lever=' + $a + ' after=' + $script:ProgressFailRun)
        # 요청을 내보내기 전(본문 준비)에 실패하면 세지 않는다
        $origId = ${function:Get-InstallId}
        function Get-InstallId { throw 'id broken' }
        $b0 = [int]$script:ProgressFailRun
        Send-Progress '2/10' 'wait' 3 $null $null
        T ([int]$script:ProgressFailRun -eq $b0) 'ⓔ 본문 준비 실패(요청 전)는 연속 실패로 세지 않는다' ('before=' + $b0 + ' after=' + $script:ProgressFailRun)
        ${function:Get-InstallId} = $origId
        # 닿으면 연속 실패 수 = 0 · 「한 번이라도 닿았다」 = 참(가짜 응답 · 바깥에 닿지 않는다)
        $script:ProgressEverOk = $false
        function Invoke-WebRequest { return [pscustomobject]@{ Content = '{}' } }
        Send-Progress '2/10' 'wait' 4 $null $null
        T (([int]$script:ProgressFailRun -eq 0) -and $script:ProgressEverOk) 'ⓔ 전송이 닿으면 연속 실패 수 0 · 닿은 적 있음' ('failrun=' + $script:ProgressFailRun + ' everok=' + $script:ProgressEverOk)
    }
    'except-once' {
        # 예외(허용) 폴더 안내는 한 실행에 한 번 — 갈래가 바뀌어 다시 판정돼도 되풀이하지 않는다
        Say-AvExceptDirs; Say-AvExceptDirs
        $n = @($script:Said | Where-Object { $_ -match '「예외\(허용\)」에 아래 폴더' }).Count
        T ($n -eq 1) 'ⓔ 예외 폴더 안내 = 한 실행에 한 번' ('n=' + $n)
    }
    'vendor-progress-ok' {
        # ⑵ 파일이 안 생겨도 진행 전송이 닿고 있으면(연속 실패 0) 판정 0 — 백신 보류는 「받기 정지 + 바깥 연결 끊김」 둘 다일 때만
        $script:ProgressEverOk = $true; $script:ProgressFailRun = 0
        $script:OnTick = { $script:ProgressFailRun = 0 }
        Run-Vendor
        T (((Judged) -eq 0) -and ($script:Launch -eq 1)) 'ⓔ⑵ 받기 정지여도 전송이 닿으면 판정 0' ('launch=' + $script:Launch + ' · ' + (JudgeLines))
    }
    default {
        # 직접 받기 갈래 — 자식 PowerShell 로 받는 동안에도 같은 판정이 돈다(⑶-직접 · ⑸ · ⑺ · ⑻)
        New-Item -ItemType Directory -Force -Path $DlDir | Out-Null   # 실물은 ③ 받기 앞에서 만든다
        $dl = Join-Path $DlDir 'claude-9.9.9-win32-x64.exe'
        $err = Join-Path $DlDir 'claude-download-error.txt'
        $script:DLaunch = 0
        function Start-ClaudeDirectDownload($u, $o, $e) { $script:DLaunch++; $p = New-FakeProc; $script:LastD = $p; & $script:OnLaunch $p; return $p }
        $script:OnLaunch = { param($p) }
        $script:ProgressEverOk = $true; $script:ProgressFailRun = 0
        $r = $null
        switch ($Case) {
            'direct-none' {
                # ⑶-직접 받을 파일이 60초 동안 안 생김 + 전송 실패 → 판정 1 · 다시 받기 1회 · 두 번째는 받아서 끝
                $script:OnLaunch = { param($p) if ($script:DLaunch -eq 2) { $p.ExitAt = $script:Clock + 5000; Grow $dl 100 } }
                try { $r = Receive-ClaudeDirectFile 'u' $dl $err 30000000 } catch { $r = 'ERR ' + $_ }
                T (($r -eq 'ok') -and ($script:DLaunch -eq 2) -and ((Judged) -ge 1)) 'ⓔ⑶-직접·⑺ 자식 받기 갈래에서 미생성 → 판정 1 · 다시 받기 1회 → ok' ('r=' + $r + ' launch=' + $script:DLaunch + ' · ' + (JudgeLines))
            }
            'direct-full-size' {
                # ⑸ 파일 = 기대 크기 · 전송 실패 · 자식이 한동안 안 끝남 → 판정 0
                $script:OnLaunch = { param($p) $p.ExitAt = 150000; Grow $dl 3000 }
                try { $r = Receive-ClaudeDirectFile 'u' $dl $err 3000 } catch { $r = 'ERR ' + $_ }
                T (($r -eq 'ok') -and ($script:DLaunch -eq 1) -and ((Judged) -eq 0)) 'ⓔ⑸ 다 받은 크기 → 판정 0' ('r=' + $r + ' launch=' + $script:DLaunch + ' · ' + (JudgeLines))
            }
            'direct-unknown-size' {
                # ⑻ 기대 크기 미상(0) + 12MB 에서 정지 → 판정 1 · 두 번째 받기도 멈추면 재유발 없이 상한까지(재유발 1회 상한)
                $ClaudeDirectDownloadWaitMs = 200000
                # 자라다가 멈춤(처음 5초 동안 자람 · 크기 값은 판정과 무관 · 맥에서 큰 파일 늘리기는 느려 작게) · 두 번째 받기는 아예 안 생김
                $script:OnTick = { if (($script:DLaunch -eq 1) -and ($script:Clock -le 5000)) { Grow $dl ([long]$script:Clock * 10) } }
                try { $r = Receive-ClaudeDirectFile 'u' $dl $err 0 } catch { $r = 'ERR ' + $_ }
                T (((Judged) -eq 1) -and ($script:DLaunch -eq 2) -and ($r -ne 'ok')) 'ⓔ⑻ 기대 크기 미상 + 12MB 정지 → 판정 1 · 재유발 1회 뒤 상한 = 실패' ('r=' + $r + ' launch=' + $script:DLaunch + ' judged=' + (Judged))
            }
            'direct-first-seen-complete' {
                # 기대 크기 미상 · 첫 관측에 이미 다 된 파일(자라는 것을 못 봄) → 판정 0(미생성도 자라다 멈춤도 아니다)
                $ClaudeDirectDownloadWaitMs = 150000
                $script:OnLaunch = { param($p) Grow $dl 5000; $p.ExitAt = 120000 }
                try { $r = Receive-ClaudeDirectFile 'u' $dl $err 0 } catch { $r = 'ERR ' + $_ }
                T (((Judged) -eq 0) -and ($script:DLaunch -eq 1)) 'ⓔ 기대 크기 미상 · 첫 관측에 다 된 파일 → 판정 0' ('r=' + $r + ' launch=' + $script:DLaunch + ' · ' + (JudgeLines))
            }
            'direct-after-vendor' {
                # 공식 설치기 갈래에서 이미 재유발했다 → 직접 받기에서 판정이 나도 다시 받지 않고 held(J-AV-01 길)
                $script:AvRetriggered = $true
                try { $r = Receive-ClaudeDirectFile 'u' $dl $err 30000000 } catch { $r = 'ERR ' + $_ }
                T (($r -eq 'held') -and ($script:DLaunch -eq 1)) 'ⓔ 재유발은 한 실행에 한 번 — 직접 받기에서 두 번째 판정 = held · 다시 받기 0' ('r=' + $r + ' launch=' + $script:DLaunch)
            }
            'direct-exit-fail' {
                # 자식이 실패로 끝나면 그 까닭(오류 파일)을 돌려준다 — 판정과 무관한 옛 갈래 보존
                $script:OnLaunch = { param($p) $p.ExitAt = 2000; $p.Rc = 1; Set-Content -LiteralPath $err -Value 'boom 404' }
                try { $r = Receive-ClaudeDirectFile 'u' $dl $err 3000 } catch { $r = 'ERR ' + $_ }
                T (($r -match 'boom 404') -and ((Judged) -eq 0)) 'ⓔ 직접 받기 자식 실패 → 까닭 전달 · 판정 0' ('r=' + $r)
            }
        }
    }
}
Write-Output ('RESULT pass=' + $script:Pass + ' fail=' + $script:Fail)
