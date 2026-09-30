# ⓑ 본체 판정 — 등록 값 따옴표 · cysr 우선 · cys.exe 실재 · 파일 판번 먼저(설계 DESIGN-defect-0930 3절 ⓑ)
param([string]$Src, [string]$Sb, [string]$Case)
. (Join-Path $PSScriptRoot 'lib.ps1') -Src $Src -Sb $Sb
$L = $env:LOCALAPPDATA
switch ($Case) {
    'laptop' {
        # 노트북 모양 — 두 항목 모두 없는 폴더(따옴표 값) · cysr 항목이 먼저 열거 · 실파일은 %LOCALAPPDATA%\cys 에 옛 0.14.29
        $script:FakeUninstall = @((Entry 'cysr' '1.1.6' '"C:\Users\cys"'), (Entry 'cys' '0.14.29' '"C:\Users\cys"'))
        Put-Bins (Join-Path $L 'cys') '0.14.29' @('cys.exe', 'cysd.exe', 'uninstall.exe')
        $b = Test-CysBody; $v = Get-CysInstalledVersion $b
        T ($b.Body -and ($b.Path -eq (Join-Path $L 'cys')) -and ($v -eq '0.14.29')) 'ⓑ 노트북 모양 = 본체 %LOCALAPPDATA%\cys · 판번은 파일(0.14.29) — 등록의 1.1.6 을 믿지 않음' ('body=' + $b.Body + ' path=' + $b.Path + ' ver=' + $v)
    }
    'quoted-elsewhere' {
        # 다른 폴더에 제대로 깔린 cysr(따옴표 값) · %LOCALAPPDATA%\cys 비어 있음
        $d = Join-Path $Sb 'apps/cysr'; Put-Bins $d '1.1.6'
        $script:FakeUninstall = @((Entry 'cysr' '1.1.6' ('"' + $d + '"')))
        $b = Test-CysBody
        T ($b.Body -and ($b.Path -eq (Resolve-Path $d).Path)) 'ⓑ 따옴표 든 InstallLocation 을 벗겨 그 폴더를 본체로' ('body=' + $b.Body + ' path=' + $b.Path)
    }
    'no-cys-exe' {
        # 옛 자리에 cys.exe 없이 다른 exe 만 — 본체 아님(앞 판 = 아무 *.exe 첫 것)
        Put-Bins (Join-Path $L 'cys') '0.14.29' @('uninstall.exe')
        $b = Test-CysBody
        T (-not $b.Body) 'ⓑ cys.exe 가 없으면 본체로 채택하지 않음(uninstall.exe 만 있는 폴더)' ('body=' + $b.Body + ' path=' + $b.Path)
    }
    'envvar' {
        $d = Join-Path $L 'cysx'; Put-Bins $d '1.1.6'
        $script:FakeUninstall = @((Entry 'cysr' '1.1.6' '"%LOCALAPPDATA%\cysx"'))
        $b = Test-CysBody
        T ($b.Body -and (($b.Path -replace '\\', '/') -eq ($d -replace '\\', '/'))) 'ⓑ 환경변수 든 InstallLocation 을 풀어 그 폴더를 본체로' ('body=' + $b.Body + ' path=' + $b.Path)
    }
}
Write-Output ('RESULT pass=' + $script:Pass + ' fail=' + $script:Fail)
