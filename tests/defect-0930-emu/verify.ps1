# ⓐ [5/10] 건너뛰기 3파일 · [7/10] 판번 대조 (설계 DESIGN-defect-0930 3절 ⓐ·ⓑ)
param([string]$Src, [string]$Sb, [string]$Case)
. (Join-Path $PSScriptRoot 'lib.ps1') -Src $Src -Sb $Sb
$L = $env:LOCALAPPDATA
$script:Said = New-Object System.Collections.ArrayList
function Say($t) { [void]$script:Said.Add([string]$t) }
function Write-JCode($c, $w) { $script:JCode = $c; [void]$script:Said.Add('JCODE ' + $c) }
function Seed-CysPath($d) { }
$Mode = 'full'
switch ($Case) {
    'dl-skip-missing' {
        $d = Join-Path $L 'cys'; Put-Bins $d '1.1.6' @('cys.exe', 'cysd.exe')
        $script:FakeUninstall = @((Entry 'cysr' '1.1.6' ('"' + $d + '"')))
        function Get-CysContentState($b) { return 'match' }
        $Mode = 'dry'   # 건너뛰기 판정은 dry 갈래보다 앞 — 받기는 하지 않는다
        [void](Step-DownloadCys); $s = $script:Said -join ' | '
        T ($s -notmatch '받지 않고 건너뜁니다') 'ⓑ [5/10] 지문 일치여도 cys-app.exe 없으면 건너뛰지 않는다' $s
    }
    'verify-old' {
        # [7/10] 옛 판(0.14.29)이 답함 → 준비되었습니다 대신 실패 rc 7
        $d = Join-Path $L 'cys'; Put-Bins $d '0.14.29' @('cys.exe', 'cysd.exe')
        function Invoke-CysProbe($cli, $a) { 'cys 0.14.29' }
        $rc = @(Step-VerifyCys)[-1]; $s = $script:Said -join ' | '
        T (($rc -eq 7) -and ($s -notmatch '준비되었습니다')) 'ⓐ [7/10] 답한 판번 0.14.29 < 1.1.6 → rc 7 · 「준비되었습니다」 0' ('rc=' + $rc + ' · ' + $s)
    }
    'verify-body-dir' {
        # [6/10] 이 확정한 본체 폴더가 있으면 [7/10] 도 그 폴더를 본다 — 설치 목록이 먼저 가리키는 옛 cys.exe 만 남은 폴더를 부르지 않는다
        $old = Join-Path $Sb 'apps/cysr-old'; Put-Bins $old '0.14.29' @('cys.exe')
        $script:FakeUninstall = @((Entry 'cysr' '0.14.29' ('"' + $old + '"')))
        $d = Join-Path $L 'cys'; Put-Bins $d '1.1.6'
        $script:CysBodyDir = (Resolve-Path $d).Path
        function Invoke-CysProbe($cli, $a) { if ([string]$cli -like '*cysr-old*') { 'cys 0.14.29' } else { 'cysr 1.1.6' } }
        $rc = @(Step-VerifyCys)[-1]; $s = $script:Said -join ' | '
        T (($rc -eq 0) -and ([string]$script:CysCli -like ('*' + [IO.Path]::DirectorySeparatorChar + 'cys' + [IO.Path]::DirectorySeparatorChar + 'cys.exe')) -and ([string]$script:CysCli -notlike '*cysr-old*')) '[7/10] = [6/10] 본체 폴더의 cys.exe(설치 목록의 옛 폴더 아님) → rc 0' ('rc=' + $rc + ' cli=' + $script:CysCli + ' · ' + $s)
    }
    'app-body-dir' {
        # 창 실행 파일도 [6/10] 이 확정한 본체 폴더가 먼저 — 설치 목록의 옛 폴더에 cys.exe·cys-app.exe 가 남아 있어도
        $old = Join-Path $Sb 'apps/cysr-old'; Put-Bins $old '0.14.29' @('cys.exe', 'cys-app.exe')
        $script:FakeUninstall = @((Entry 'cysr' '0.14.29' ('"' + $old + '"')))
        $d = Join-Path $L 'cys'; Put-Bins $d '1.1.6'
        $script:CysBodyDir = (Resolve-Path $d).Path
        $app = [string](Get-CysAppExe)
        T (($app -like ((Resolve-Path $d).Path + '*')) -and ($app -notlike '*cysr-old*')) '창 실행 파일 = [6/10] 본체 폴더의 것' ('app=' + $app)
    }
    'skipped-no-error' {
        # 버린 항목 진단이 없는 드라이브를 가리켜도 오류를 내지 않는다(앞 항목에서 본체를 찾은 뒤에도 뒤 항목을 살핀다)
        $d = Join-Path $L 'cys'; Put-Bins $d '1.1.6'
        $script:FakeUninstall = @((Entry 'cysr' '1.1.5' '"Q:\cysr"'), (Entry 'cysr' '1.1.6' ('"' + $d + '"')), (Entry 'cys' '0.14.29' '"Q:\cys"'))
        $Error.Clear()
        $b = Test-CysBody
        T (($Error.Count -eq 0) -and (@($b.Skipped) -join ' ') -match 'cys 0\.14\.29 loc=Q:\\cys cys\.exe=no') '버린 항목이 없는 드라이브여도 오류 0 · 기록 칸은 채움' ('errors=' + $Error.Count + ' · ' + (@($Error | ForEach-Object { $_.Exception.GetType().Name }) -join ',') + ' · skipped=' + (@($b.Skipped) -join ' ; '))
    }
    'rh-body-dir' {
        # 원격 해결이 부르는 cys 도 [6/10] 본체 폴더가 먼저 — 설치 목록의 옛 폴더에 cys.exe 가 남아 있어도
        $old = Join-Path $Sb 'apps/cysr-old'; Put-Bins $old '0.14.29' @('cys.exe')
        $script:FakeUninstall = @((Entry 'cysr' '0.14.29' ('"' + $old + '"')))
        $d = Join-Path $L 'cys'; Put-Bins $d '1.1.6'
        $script:CysBodyDir = (Resolve-Path $d).Path
        $rh = [string](Get-RemoteHelpCysPath)
        T (($rh -like ((Resolve-Path $d).Path + '*cys.exe')) -and ($rh -notlike '*cysr-old*')) '원격 해결의 cys = [6/10] 본체 폴더의 cys.exe' ('rh=' + $rh)
    }
    'verify-ok' {
        $d = Join-Path $L 'cys'; Put-Bins $d '1.1.6'
        function Invoke-CysProbe($cli, $a) { 'cysr 1.1.6' }
        $rc = @(Step-VerifyCys)[-1]; $s = $script:Said -join ' | '
        T (($rc -eq 0) -and ($s -match '준비되었습니다 \(버전 1\.1\.6\)')) 'ⓐ [7/10] 답한 판번 = 1.1.6 → rc 0 · 준비되었습니다' ('rc=' + $rc + ' · ' + $s)
    }
    'autostart-old-folder' {
        # 새 판이 %LOCALAPPDATA%\cys 에 깔렸는데 예약 작업은 옛 %LOCALAPPDATA%\Programs\cys\cysd.exe → 우리 것 아님(다시 등록 대상)
        $d = Join-Path $L 'cys'; Put-Bins $d '1.1.6'
        $script:FakeUninstall = @((Entry 'cysr' '1.1.6' ('"' + $d + '"')))
        $script:TaskCmd = (Join-Path $L 'Programs\cys\cysd.exe')
        function schtasks { $global:LASTEXITCODE = 0; '<?xml version="1.0"?><Task><Settings><Enabled>true</Enabled></Settings><Triggers><LogonTrigger><Enabled>true</Enabled></LogonTrigger></Triggers><Actions><Exec><Command>"' + $script:TaskCmd + '"</Command></Exec></Actions></Task>' }
        $st = Get-CysAutoStartState (Join-Path $d 'cys.exe')
        T ($st -eq 'other') 'ⓒ [8/10] 예약 작업이 옛 폴더 cysd.exe 를 가리키면 우리 것이 아니다(다시 등록)' ('state=' + $st)
    }
    'autostart-one-value' {
        # [6/10] 이 이번 실행에 %LOCALAPPDATA%\cys 로 깔았다(CysBodyDir) · 등록 목록의 첫 항목은 옛 Programs\cys(파일 있음) · 작업 = 옛 cysd → 우리 것 아님
        $old = Join-Path $L 'Programs/cys'; Put-Bins $old '0.14.29'
        $new = Join-Path $L 'cys'; Put-Bins $new '1.1.6'
        $script:FakeUninstall = @((Entry 'cys' '0.14.29' ('"' + $old + '"')))
        $script:CysBodyDir = $new
        $script:TaskCmd = (Join-Path $old 'cysd.exe')
        function schtasks { $global:LASTEXITCODE = 0; '<?xml version="1.0"?><Task><Settings><Enabled>true</Enabled></Settings><Triggers><LogonTrigger><Enabled>true</Enabled></LogonTrigger></Triggers><Actions><Exec><Command>"' + $script:TaskCmd + '"</Command></Exec></Actions></Task>' }
        $st = Get-CysAutoStartState (Join-Path $old 'cys.exe')
        T ($st -eq 'other') 'ⓒ [8/10] 기대 경로 = [6/10] 이 확정한 본체 폴더 하나 — 등록 첫 항목(옛 폴더)의 cysd 는 우리 것 아님' ('state=' + $st)
    }
    'autostart-body' {
        # 본체가 %LOCALAPPDATA%\cysr(훅 예외 기기) · 작업 = 그 cysd · 부르는 길이 이름뿐(cys) → 우리 것(경로 단계 통과)
        $d = Join-Path $L 'cysr'; Put-Bins $d '1.1.6'
        $script:FakeUninstall = @((Entry 'cysr' '1.1.6' ('"' + $d + '"')))
        $script:TaskCmd = (Join-Path $d 'cysd.exe')
        function schtasks { $global:LASTEXITCODE = 0; '<?xml version="1.0"?><Task><Settings><Enabled>true</Enabled></Settings><Triggers><LogonTrigger><Enabled>true</Enabled></LogonTrigger></Triggers><Actions><Exec><Command>"' + $script:TaskCmd + '"</Command></Exec></Actions></Task>' }
        $st = Get-CysAutoStartState 'cys'
        T ($st -ne 'other') 'ⓒ [8/10] 예약 작업 = 실제 본체 폴더의 cysd.exe → 우리 것(부르는 길이 이름뿐이어도)' ('state=' + $st)
    }
}
Write-Output ('RESULT pass=' + $script:Pass + ' fail=' + $script:Fail)
