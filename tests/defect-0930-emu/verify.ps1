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
