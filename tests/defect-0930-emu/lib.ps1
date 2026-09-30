# 0.3.38 윈 설치기 결함 묶음 — 흉내 공용: 실물 bootstrap.ps1 을 함수 묶음으로 읽고, 설치 목록(HKLM/HKCU Uninstall)·실행 파일 판만 가짜로 준다.
#   ⚠맥 pwsh 는 PE 판 정보를 못 읽는다(VersionInfo 빈 값 실측) ⇒ 판은 가짜 표로(Get-CysExeVersion 가리기 · 앞 판에는 그 함수가 없어 Get-Item 가리기도 함께).
param([string]$Src, [string]$Sb)
$ErrorActionPreference = 'Continue'
$script:FakeUninstall = @()      # 가짜 설치 목록 항목(pscustomobject: DisplayName · DisplayVersion · InstallLocation · DisplayIcon · UninstallString)
$script:FakeVer = @{}            # 실행 파일 전체 경로 → 판 문자열
New-Item -ItemType Directory -Force -Path "$Sb/home/install-jarvis", "$Sb/local", "$Sb/pf" | Out-Null
$env:USERPROFILE = "$Sb/home"; $env:LOCALAPPDATA = "$Sb/local"; $env:ProgramFiles = "$Sb/pf"
$env:JARVIS_HOME = "$Sb/home/install-jarvis"; $env:JARVIS_LIB_ONLY = '1'; $env:JARVIS_NO_PROGRESS = '1'
. $Src
$env:JARVIS_LIB_ONLY = ''
function Get-ChildItem {
    $p = @($args | Where-Object { $_ -is [string] -or $_ -is [array] } | ForEach-Object { $_ })
    if ($p.Count -gt 0 -and ([string]$p[0]) -like 'HK*:*') { return $script:FakeUninstall }
    Microsoft.PowerShell.Management\Get-ChildItem @args
}
function Get-ItemProperty { process { if ($_ -and $_.PSObject.Properties['DisplayName']) { $_ } } }
function Get-CysExeVersion($p) { $k = [string]$p; if ($script:FakeVer.ContainsKey($k)) { return $script:FakeVer[$k] }; return '' }
${function:Get-ItemOrig} = ${function:Microsoft.PowerShell.Management\Get-Item}
function Get-Item {
    # 앞 판(Get-CysExeVersion 없음)의 VersionInfo 읽기도 같은 가짜 표로 받는다
    $o = Microsoft.PowerShell.Management\Get-Item @args
    if ($o -and $o.PSObject.Properties['FullName'] -and $script:FakeVer.ContainsKey([string]$o.FullName)) {
        $v = $script:FakeVer[[string]$o.FullName]
        $o | Add-Member -Force -MemberType NoteProperty -Name VersionInfo -Value ([pscustomobject]@{ ProductVersion = $v; FileVersion = $v })
    }
    $o
}
function Put-Bins($dir, $ver, [string[]]$names = @('cys.exe', 'cysd.exe', 'cys-app.exe')) {
    New-Item -ItemType Directory -Force -Path $dir | Out-Null
    foreach ($n in $names) { $f = Join-Path $dir $n; Set-Content -Path $f -Value 'x' -NoNewline; $script:FakeVer[(Resolve-Path $f).Path] = $ver }
}
function Entry($name, $ver, $loc) { [pscustomobject]@{ DisplayName = $name; DisplayVersion = $ver; InstallLocation = $loc; DisplayIcon = ''; UninstallString = '' } }
$script:Pass = 0; $script:Fail = 0
function T([bool]$ok, [string]$name, [string]$why) {
    if ($ok) { $script:Pass++; Write-Output ('  ok   ' + $name) } else { $script:Fail++; Write-Output ('  FAIL ' + $name + '  ← ' + $why) }
}
