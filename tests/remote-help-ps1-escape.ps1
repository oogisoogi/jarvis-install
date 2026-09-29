# 원격 해결 윈도우 탈출 시험 — 여는 순간 조상 폴더를 정션으로 바꿔 끼워도 밖의 표식이 결과에 닿지 않는가
#
# 무엇을 재는가 (검토 지적 2건의 재현)
#   두 번의 경로 확인을 다 통과한 뒤 · 여는 바로 그 순간에 `logs` 를 밖으로 가는 정션으로 바꿔 끼운다.
#   글자 경로(FullName)와 마지막 성분의 속성은 그대로라 이름만 보는 검사는 전부 통과한다 ⇒ **연 핸들의 최종 경로**만이 막는다.
#     file-ancestor = 파일 끝 N줄(Get-Content) — 밖 파일 내용이 결과에 없어야 한다
#     file-hash     = 파일 지문(Get-FileHash) — 밖 파일의 지문이 결과에 없어야 한다
#     dir-ancestor  = 폴더 목록(Get-ChildItem) — 밖 폴더의 파일 이름이 결과에 없어야 한다
#     inside        = 바꿔 끼우지 않으면 제대로 읽는다(시험이 모든 것을 거절해서 초록이 된 것이 아님을 잰다)
#   -Mutant  = 설치기 사본에서 「연 핸들이 작업 폴더 안인가」 판정을 지운 뒤 같은 사례를 돌린다 → 탈출이 **일어나야** 한다(시험이 그 관문을 실제로 재는가).
#
# ⛔윈도우에서만 돈다(정션·핸들 최종 경로). 만든 곳(맥)에는 PowerShell 이 없어 **이 파일은 아직 한 번도 실행되지 않았다** — 윈도우 실기·러너 몫.
#
# 쓰는 법
#   powershell -NoProfile -ExecutionPolicy Bypass -File tests\remote-help-ps1-escape.ps1 -Dir install-master
#   powershell -NoProfile -ExecutionPolicy Bypass -File tests\remote-help-ps1-escape.ps1 -Dir install-master -Mutant
#   rc 0 = 기대대로(보통 = 탈출 0 · -Mutant = 탈출이 잡힘) · rc 1 = 아님 · rc 4 = 시작할 수 없음
param(
    [Parameter(Mandatory=$true)][string]$Dir,
    [switch]$Mutant
)

$ErrorActionPreference = 'Continue'
try { [Console]::OutputEncoding = [System.Text.Encoding]::UTF8 } catch { }
if ($env:OS -ne 'Windows_NT') { Write-Host '::error::윈도우에서만 돕니다(정션·핸들 최종 경로).'; exit 4 }

$src = Join-Path (Resolve-Path $Dir).Path 'bootstrap.ps1'
$sand = Join-Path ([System.IO.Path]::GetTempPath()) ('rh-escape-' + [guid]::NewGuid().ToString('N'))
$jh = Join-Path $sand 'install-jarvis'
$outside = Join-Path $sand 'outside'
New-Item -ItemType Directory -Force -Path $jh, $outside | Out-Null
[System.IO.File]::WriteAllText((Join-Path $outside 'x.log'), "SECRET-ESCAPE-LINE`r`n")
[System.IO.File]::WriteAllText((Join-Path $outside 'SECRET-DIR-MARKER.txt'), 'x')

$lib = $src
if ($Mutant) {
    $text = [System.IO.File]::ReadAllText($src, [System.Text.Encoding]::UTF8)
    $anchor = "if (-not `$inside) { return @{ Refused = 'path_outside' } }"
    if (([regex]::Matches($text, [regex]::Escape($anchor))).Count -ne 1) { Write-Host '::error::뮤턴트 앵커가 1곳이 아닙니다 — 설치기가 바뀌었습니다'; exit 4 }
    $lib = Join-Path $sand 'bootstrap-mutant.ps1'
    [System.IO.File]::WriteAllText($lib, $text.Replace($anchor, ''), (New-Object System.Text.UTF8Encoding($true)))
}

$env:JARVIS_HOME = $jh
$env:JARVIS_LIB_ONLY = '1'
. $lib
$table = ConvertFrom-Json -InputObject $RemoteHelpTableJson
function Get-Entry([string]$Id) { return @($table.entries | Where-Object { $_.shell -ceq 'ps1' -and $_.id -ceq $Id })[0] }

$script:escapes = 0
$script:fails = 0
function Check([string]$Name, [bool]$Ok, [string]$Why) {
    if ($Ok) { Write-Host "  ok   $Name" } else { $script:fails++; Write-Host "  FAIL $Name — $Why" }
}

# 여는 순간 교체 — 원래 폴더를 옆으로 치우고 같은 이름에 밖으로 가는 정션을 놓은 뒤, 설치기 자신의 여는 함수를 부른다
function Set-Swap([string]$Folder) {
    $script:SwapFolder = $Folder
    function global:Open-RemoteHelpLeaf([string]$Path) {
        $f = Join-Path $jh $script:SwapFolder
        try {
            Rename-Item -LiteralPath $f -NewName ($script:SwapFolder + '-moved') -ErrorAction Stop
            New-Item -ItemType Junction -Path $f -Target $outside -ErrorAction Stop | Out-Null
            $script:Swapped = $true
        } catch { $script:Swapped = $false; Write-Host ('       (교체 실패: ' + $_.Exception.Message + ')') }
        return [JarvisRemoteHelpFs]::Open($Path)
    }
}

function Invoke-Case([string]$Name, [string]$Id, [string[]]$Argv, [string]$Rel, [int]$PathIndex, [string]$Folder, [string]$Marker) {
    $resolved = Resolve-RemoteHelpPath $Rel
    if ($resolved.Rule) { Check $Name $false ('준비 단계에서 거절됨: ' + $resolved.Rule); return }
    Set-Swap $Folder
    $script:Swapped = $false
    $run = Invoke-RemoteHelpLaunch (Get-Entry $Id) $Argv $resolved.Real $PathIndex
    $out = [string]$run.Output
    $leaked = $out.Contains($Marker)
    if ($leaked) { $script:escapes++ }
    if ($Mutant) { return }
    if (-not $script:Swapped) { Check $Name $true '교체 자체가 막혔다(열린 핸들이 이름 바꾸기를 막음)'; return }
    Check $Name ((-not $leaked) -and $run.Refused -ceq 'path_outside') ('Refused=' + $run.Refused + ' 표식 유출=' + $leaked)
}

function Reset-Folder([string]$Folder, [string]$File, [string]$Body) {
    $f = Join-Path $jh $Folder
    if (Test-Path -LiteralPath $f) { [System.IO.Directory]::Delete($f, $false) }   # 정션만 지운다(대상은 건드리지 않는다)
    $moved = Join-Path $jh ($Folder + '-moved')
    if (Test-Path -LiteralPath $moved) { Remove-Item -LiteralPath $moved -Recurse -Force }
    New-Item -ItemType Directory -Force -Path $f | Out-Null
    [System.IO.File]::WriteAllText((Join-Path $f $File), $Body)
}

$outsideHash = (Get-FileHash -LiteralPath (Join-Path $outside 'x.log') -Algorithm SHA256).Hash

Reset-Folder 'logs' 'x.log' "inside-line`r`n"
Invoke-Case 'file-ancestor 끝 N줄 · 조상 폴더를 정션으로' 'file.tail' @('Get-Content', '-LiteralPath', 'logs\x.log', '-Tail', '5') 'logs\x.log' 2 'logs' 'SECRET-ESCAPE-LINE'

Reset-Folder 'logs' 'x.log' "inside-line`r`n"
Invoke-Case 'file-hash 지문 · 조상 폴더를 정션으로' 'file.hash' @('Get-FileHash', '-LiteralPath', 'logs\x.log', '-Algorithm', 'SHA256') 'logs\x.log' 2 'logs' $outsideHash

Reset-Folder 'data' 'in.txt' 'inside'
Invoke-Case 'dir-ancestor 폴더 목록 · 그 폴더를 정션으로' 'dir.list' @('Get-ChildItem', '-LiteralPath', 'data') 'data' 2 'data' 'SECRET-DIR-MARKER'

if (-not $Mutant) {
    # 바꿔 끼우지 않으면 제대로 읽는다
    function global:Open-RemoteHelpLeaf([string]$Path) { return [JarvisRemoteHelpFs]::Open($Path) }
    Reset-Folder 'logs' 'x.log' "inside-line`r`n"
    $resolved = Resolve-RemoteHelpPath 'logs\x.log'
    $run = Invoke-RemoteHelpLaunch (Get-Entry 'file.tail') @('Get-Content', '-LiteralPath', 'logs\x.log', '-Tail', '5') $resolved.Real 2
    Check 'inside 교체가 없으면 연 핸들로 읽는다' ((-not $run.Refused) -and ([string]$run.Output).Contains('inside-line')) ('Refused=' + $run.Refused + ' Output=' + $run.Output)
    $run = Invoke-RemoteHelpLaunch (Get-Entry 'dir.root') @('Get-ChildItem') '' -1
    Check 'inside 작업 폴더 맨 위 목록도 핸들로 읽는다' ((-not $run.Refused) -and ([string]$run.Output).Contains('logs')) ('Refused=' + $run.Refused + ' Output=' + $run.Output)
}

try { Get-ChildItem -LiteralPath $jh -Force | Where-Object { $_.Attributes -band [System.IO.FileAttributes]::ReparsePoint } | ForEach-Object { [System.IO.Directory]::Delete($_.FullName, $false) } } catch { }
Remove-Item -LiteralPath $sand -Recurse -Force -ErrorAction SilentlyContinue

if ($Mutant) {
    Write-Host ("뮤턴트(소속 판정 제거): 탈출 " + $script:escapes + "건 — " + $(if ($script:escapes -gt 0) { 'KILLED' } else { 'SURVIVED' }))
    exit $(if ($script:escapes -gt 0) { 0 } else { 1 })
}
Write-Host ("`n실패 " + $script:fails + " · 탈출 " + $script:escapes)
exit $(if ($script:fails -eq 0 -and $script:escapes -eq 0) { 0 } else { 1 })
