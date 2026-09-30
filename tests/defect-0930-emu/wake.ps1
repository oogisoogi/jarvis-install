# ⓓ [9/10] 창을 여는 실행 파일 실재 판정 — 없으면 자리를 열지 않고 실패 경로(J-APP-01 · 다음 할 일 한 줄) (설계 DESIGN-defect-0930 3절 ⓓ)
param([string]$Src, [string]$Sb, [string]$Case)
. (Join-Path $PSScriptRoot 'lib.ps1') -Src $Src -Sb $Sb
$L = $env:LOCALAPPDATA
$script:Said = New-Object System.Collections.ArrayList
function Say($t) { [void]$script:Said.Add([string]$t) }
$script:CysCalls = New-Object System.Collections.ArrayList
function cys { [void]$script:CysCalls.Add(($args -join ' ')); $global:LASTEXITCODE = 1; 'emu' }
function Clear-MasterMark { } ; function Move-OldRound { } ; function Set-FleetBaseline($c) { }
function Invoke-StepFleet($r) { [void]$script:CysCalls.Add('FLEET') ; return 0 }
$Mode = 'full'; $script:CysCli = 'cys'; $script:ReachedWake = $false; $script:NextStep = ''; $script:ShowRerun = $false
switch ($Case) {
    'no-app-exe' {
        $d = Join-Path $L 'cys'; Put-Bins $d '1.1.6' @('cys.exe', 'cysd.exe')
        $script:FakeUninstall = @((Entry 'cysr' '1.1.6' ('"' + $d + '"')))
        [void](Step-Wake); $s = $script:Said -join ' | '
        $seat = @($script:CysCalls | Where-Object { $_ -like 'new-surface*' -or $_ -eq 'FLEET' }).Count
        T ($seat -eq 0) 'ⓓ 창 실행 파일 없음 → 자리 열기(new-surface)·동료 부르기 0' ('calls=' + ($script:CysCalls -join ' ; '))
        T ((-not $script:ReachedWake) -and ($script:JCode -eq 'J-APP-01') -and ($s -match '프로그램 창을 열 파일이 없습니다')) 'ⓓ 깨움 도달 표시 0 · J-APP-01 · 한 문장' ('reached=' + $script:ReachedWake + ' j=' + $script:JCode + ' · ' + $s)
        T ($script:NextStep -and ($script:NextStep -notmatch '다시 하시는 법') -and ($script:NextStep -match '다시 붙여넣')) 'ⓓ 다음에 할 일 = 명시 한 줄(전송 확인 못 함 → 다시 붙여넣기 · 기본 「다시 하시는 법」 문구 아님)' ('next=' + $script:NextStep)
        T ($s -notmatch '알렸습니다') 'ⓓ 전송을 확인 못 했으면 「알렸습니다」 0' $s
    }
    'card-hint' {
        # 사람 카드의 창 여는 길 1줄 — 바탕화면 cysr 바로가기가 실재하고 대상도 실재할 때만 「바탕화면」 · 아니면 「시작 메뉴」
        $desk = Join-Path $Sb 'desk'; New-Item -ItemType Directory -Force -Path $desk | Out-Null
        function Get-DesktopDir { return (Join-Path $Sb 'desk') }
        $app = Join-Path $L 'cys/cys-app.exe'; Put-Bins (Join-Path $L 'cys') '1.1.6'
        Set-Content -Path (Join-Path $desk 'cysr.lnk') -Value 'x' -NoNewline
        $script:LnkTarget = $app
        function Get-ShortcutTarget($lnk) { return $script:LnkTarget }
        $h1 = ''; $h2 = ''; $h3 = ''
        try { $h1 = Get-CysWindowOpenHint } catch { $h1 = 'ERR ' + $_ }
        $script:LnkTarget = (Join-Path $L 'gone/cys-app.exe')
        try { $h2 = Get-CysWindowOpenHint } catch { $h2 = 'ERR ' + $_ }
        Remove-Item -LiteralPath (Join-Path $desk 'cysr.lnk')
        try { $h3 = Get-CysWindowOpenHint } catch { $h3 = 'ERR ' + $_ }
        T (($h1 -match '바탕화면의 cysr 아이콘') -and ($h2 -match '시작 메뉴') -and ($h3 -match '시작 메뉴')) 'ⓓ 사람 카드 창 여는 길 = 바로가기·대상 실재 → 바탕화면 · 대상 없음·바로가기 없음 → 시작 메뉴' ('h1=' + $h1 + ' | h2=' + $h2 + ' | h3=' + $h3)
        $src = Get-Content -LiteralPath $Src -Raw
        $blk = $src.Substring($src.IndexOf("'awaken:manual-fallback'"), 1500)
        T ($blk -match 'Get-CysWindowOpenHint') 'ⓓ 사람 카드(awaken:manual-fallback) 가 창 여는 길 1줄을 싣는다' 'manual-fallback 블록에 Get-CysWindowOpenHint 없음'
    }
}
Write-Output ('RESULT pass=' + $script:Pass + ' fail=' + $script:Fail)
