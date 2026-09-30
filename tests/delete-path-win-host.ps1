# 0.3.37 삭제 길 윈 흉내 호스트 (pwsh 7 · 맥) — tests/delete-path-run.sh 의 run_win 이 부른다. 실물 reset-clean.ps1 을 스위치 그대로 부르고 종료 코드를 넘긴다.
#   바탕 = tests/reinstall-keepapp-emu/reset-host.ps1(C: 드라이브 = 샌드박스 「cdrv」 · HKCU = 샌드박스 reg 폴더 · Read-Host·Stop-Process 기록 가짜)
#   더한 가짜(이 파일에서만 · 옛 호출자는 reset-host.ps1 을 그대로 쓴다):
#     ⑴레지스트리 **값** = 키 폴더 안 「<값 이름>.regval」 파일(Get-ItemProperty · Remove-ItemProperty · HKCU: 만 · 그 밖은 진짜 명령으로 넘긴다)
#     ⑵바로가기 대상 = New-Object -ComObject WScript.Shell 가짜 — .lnk 파일 내용(한 줄)이 대상 경로 · 내용이 UNREADABLE 이면 읽기 실패(예외)
#   ⛔진짜 제거 프로그램(uninstall.exe)은 가짜로 덮지 않는다 — 시험이 실행 표지 파일을 쓰는 가짜 uninstall.exe 를 두고, 불리면 표지가 남는다.
param([string]$Target, [string]$Log, [string]$Switches, [string]$Sb)
$ErrorActionPreference = 'Continue'
$h = @{}
foreach ($n in ($Switches -split ',')) { if ($n) { $h[$n] = $true } }

New-PSDrive -Name C -PSProvider FileSystem -Root "$Sb/cdrv" -Scope Global | Out-Null
[Environment]::CurrentDirectory = $Sb
New-PSDrive -Name HKCU -PSProvider FileSystem -Root "$Sb/reg" -Scope Global | Out-Null
$env:PATH = '/usr/bin:/bin'

function Read-Host {
    param([Parameter(Position = 0)] $Prompt, [switch]$AsSecureString)
    Add-Content -LiteralPath $Log -Value ([string]$Prompt)
    return ''
}
function Stop-Process {
    [CmdletBinding()] param([Parameter(ValueFromPipeline = $true)] $InputObject, [int[]]$Id, [switch]$Force)
    process {
        $what = if ($InputObject) { [string]$InputObject.ProcessName + '#' + $InputObject.Id } else { 'id ' + ($Id -join ',') }
        Add-Content -LiteralPath "$Sb/stop-process.log" -Value ('would-stop ' + $what)
    }
}
function Get-EmuRegDir([string]$p) {
    if ($p -match '^HKCU:\\(.*)$') { return (Join-Path "$Sb/reg" ($Matches[1] -replace '\\', '/')) }
    return $null
}
function Get-ItemProperty {
    [CmdletBinding()] param([Parameter(Position = 0)] [string[]]$Path, [string[]]$LiteralPath, [Parameter(Position = 1)] [string[]]$Name)
    $p = if ($LiteralPath) { $LiteralPath[0] } else { $Path[0] }
    $d = Get-EmuRegDir $p
    if ($null -eq $d) { return (Microsoft.PowerShell.Management\Get-ItemProperty @PSBoundParameters) }
    $o = [ordered]@{}
    foreach ($n in @($Name)) {
        $f = Join-Path $d ($n + '.regval')
        if (Test-Path -LiteralPath $f) { $o[$n] = [System.IO.File]::ReadAllText($f) }
    }
    if ($o.Count -eq 0) { throw ('emu: no registry value ' + ($Name -join ',') + ' at ' + $p) }
    return [pscustomobject]$o
}
function Remove-ItemProperty {
    [CmdletBinding()] param([Parameter(Position = 0)] [string[]]$Path, [string[]]$LiteralPath, [Parameter(Position = 1)] [string[]]$Name, [switch]$Force)
    $p = if ($LiteralPath) { $LiteralPath[0] } else { $Path[0] }
    $d = Get-EmuRegDir $p
    if ($null -eq $d) { Microsoft.PowerShell.Management\Remove-ItemProperty @PSBoundParameters; return }
    foreach ($n in @($Name)) {
        $f = Join-Path $d ($n + '.regval')
        if (-not (Test-Path -LiteralPath $f)) { throw ('emu: no registry value ' + $n) }
        Remove-Item -LiteralPath $f -Force
    }
}
function New-Object {
    [CmdletBinding(DefaultParameterSetName = 'Net')]
    param(
        [Parameter(ParameterSetName = 'Net', Mandatory = $true, Position = 0)] [string]$TypeName,
        [Parameter(ParameterSetName = 'Net', Position = 1)] [Alias('Args')] [object[]]$ArgumentList,
        [Parameter(ParameterSetName = 'Com', Mandatory = $true)] [string]$ComObject,
        [Parameter(ParameterSetName = 'Com')] [switch]$Strict,
        [System.Collections.IDictionary]$Property)
    if ($PSCmdlet.ParameterSetName -eq 'Com') {
        if ($ComObject -ne 'WScript.Shell') { throw ('emu: no COM ' + $ComObject) }
        $sh = [pscustomobject]@{ Sb = $Sb }
        $sh | Add-Member -MemberType ScriptMethod -Name CreateShortcut -Value {
            param($lnk)
            Add-Content -LiteralPath (Join-Path $this.Sb 'shortcut-read.log') -Value ([string]$lnk)
            $t = ([System.IO.File]::ReadAllText([string]$lnk)).Trim()
            if ($t -eq 'UNREADABLE') { throw 'emu: shortcut unreadable' }
            return [pscustomobject]@{ TargetPath = $t }
        }
        return $sh
    }
    Microsoft.PowerShell.Utility\New-Object @PSBoundParameters
}

& $Target @h
$rc = $LASTEXITCODE
if ($null -eq $rc) { $rc = 0 }
exit $rc
