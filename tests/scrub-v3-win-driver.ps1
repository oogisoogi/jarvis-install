# scrub-v3-win-driver.ps1 — 윈 설치기(bootstrap.ps1)의 가림 v3 를 「실물 함수」로 돌려 결과를 JSONL 로 내는 구동기(TICKET=scrub-v3-port-1116 · ROLE=win)
#
#   판정은 하지 않는다 — tests/scrub-v3-win.mjs 가 일을 만들어 주고(공용 벡터 161 · 씨앗 고정 무작위) 결과를 참조 모델·잣대와 견준다.
#   글은 전부 UTF-16 코드 단위의 16진(한 단위 = 넉 자)으로 주고받는다 — JSON 직렬화가 짝 잃은 서러게이트를 바꾸지 못하게(코드 단위 대조).
#   바이트는 16진. ⛔네트워크 0 · 파일 쓰기 = 임시 폴더의 시험 파일뿐(JARVIS_LIB_ONLY=1 로 함수 묶음만 읽는다).
#
#   pwsh -NoProfile -File tests/scrub-v3-win-driver.ps1 -Dir install-master -Jobs <일.jsonl> -Out <결과.jsonl>
param([Parameter(Mandatory = $true)][string]$Dir, [Parameter(Mandatory = $true)][string]$Jobs, [Parameter(Mandatory = $true)][string]$Out)

$ErrorActionPreference = 'Stop'
$TBase = Join-Path ([System.IO.Path]::GetTempPath()) ('scrub-v3-win-' + [guid]::NewGuid().ToString('N'))
$THome = Join-Path $TBase 'install-jarvis'
New-Item -ItemType Directory -Force -Path $THome | Out-Null
[System.IO.File]::WriteAllText((Join-Path $THome '.jarvis-owned'), "jarvis-installer-owned v1`r`n", (New-Object System.Text.UTF8Encoding($false)))
$env:JARVIS_LIB_ONLY = '1'
$env:JARVIS_HOME = $THome
$env:JARVIS_NO_PROGRESS = '1'
. (Join-Path $Dir 'bootstrap.ps1')
$env:JARVIS_LIB_ONLY = ''
$ErrorActionPreference = 'Stop'
# 첨부 파일 길의 「이 컴퓨터가 아는 이름」 은 일이 준 이름만 — 시험 기계의 계정 이름을 섞지 않는다
$env:USERNAME = ''
$env:USERPROFILE = ''

function Read-Units([string]$Hex) {
    if ($Hex.Length -eq 0) { return '' }
    $chars = New-Object char[] ($Hex.Length / 4)
    for ($k = 0; $k -lt $chars.Length; $k++) { $chars[$k] = [char][Convert]::ToInt32($Hex.Substring($k * 4, 4), 16) }
    return (New-Object string (, $chars))
}
function Write-Units([string]$Text) {
    if ($null -eq $Text) { return $null }
    $sb = New-Object System.Text.StringBuilder ($Text.Length * 4)
    for ($k = 0; $k -lt $Text.Length; $k++) { [void]$sb.Append(([int]$Text[$k]).ToString('x4')) }
    return $sb.ToString()
}
function Read-HexBytes([string]$Hex) {
    $bytes = New-Object byte[] ($Hex.Length / 2)
    for ($k = 0; $k -lt $bytes.Length; $k++) { $bytes[$k] = [Convert]::ToByte($Hex.Substring($k * 2, 2), 16) }
    return , $bytes
}
function Write-HexBytes($Bytes) { return ([System.BitConverter]::ToString([byte[]]$Bytes)).Replace('-', '').ToLowerInvariant() }
# 이름 칸: { t:'list', v:[<hex>|null|수] } · { t:'set', names:[…], overflow:<값> } · { t:'raw', v:<JSON 값 그대로> }
function Get-NameArg($Spec) {
    if ($null -eq $Spec) { return $null }
    $decode = {
        param($items)
        $list = New-Object System.Collections.ArrayList
        foreach ($x in @($items)) { if ($x -is [string]) { [void]$list.Add((Read-Units $x)) } else { [void]$list.Add($x) } }
        return , $list.ToArray()
    }
    if ($Spec.t -ceq 'list') { return , (& $decode $Spec.v) }
    if ($Spec.t -ceq 'set') { return @{ names = (& $decode $Spec.names); overflow = $Spec.overflow } }
    return $Spec.v
}
function Get-Runs($S, $E, $R) {
    $runs = New-Object System.Collections.ArrayList
    for ($k = 0; $k -lt @($S).Count; $k++) { [void]$runs.Add(@([int]@($S)[$k], [int]@($E)[$k], [int]@($R)[$k])) }
    return , $runs.ToArray()
}
function Get-ScrubOut($Res) {
    return [ordered]@{ text = (Write-Units $Res.Text); full = [bool]$Res.Full; reason = $Res.Reason; runs = (Get-Runs $Res.RunS $Res.RunE $Res.RunR); marks = (Get-Runs $Res.MarkS $Res.MarkE $Res.MarkR); rescans = [int]$Res.Rescans; work = [long]$Res.Work }
}
function Get-FieldOut($Res) {
    $runs = $null
    if (-not $Res.Full) { if ($null -eq $Res.Result) { $runs = @() } else { $runs = (Get-Runs $Res.Result.RunS $Res.Result.RunE $Res.Result.RunR) } }
    return [ordered]@{ text = (Write-Units $Res.Text); full = [bool]$Res.Full; reason = $Res.Reason; truncated = [bool]$Res.Truncated; runs = $runs }
}
function Get-SentOut($Sent) {
    if ($null -eq $Sent) { return $null }
    $runs = $null
    if ($null -ne $Sent.Result) { $runs = (Get-Runs $Sent.Result.RunS $Sent.Result.RunE $Sent.Result.RunR) }
    $names = New-Object System.Collections.ArrayList
    foreach ($n in @($Sent.Names)) { if ($n -is [string]) { [void]$names.Add((Write-Units $n)) } else { [void]$names.Add($n) } }
    return [ordered]@{ hex = (Write-HexBytes $Sent.Bytes); text = (Write-Units $Sent.Text); full = [bool]$Sent.Full; reason = $Sent.Reason; names = $names.ToArray(); overflow = [bool]$Sent.Overflow; runs = $runs }
}
function New-Clock($Values) {
    $script:ClockVals = @(@($Values) | ForEach-Object { if ($_ -is [string] -and $_ -ceq 'NaN') { [double]::NaN } else { $_ } })
    $script:ClockAt = 0
    return { $v = $script:ClockVals[[Math]::Min($script:ClockAt, $script:ClockVals.Count - 1)]; $script:ClockAt++; $v }
}
# 서버 첨부(serverAttachment) 꼴 — 설치기에는 서버 길이 없다 · 공용 벡터 22건을 이 구현의 부품(수확·칸 처리)으로 재려고 시험 안에서만 모델 순서대로 조합한다
function Invoke-ServerViaPort($Bytes, $Known) {
    $given = ConvertTo-RemoteHelpNameSet $Known
    if ($given.IsSet -and -not $given.NamesOk) { $given = @{ Names = @(); Overflow = $false; IsSet = $true; NamesOk = $true } }
    $full = { param($why, $set) $n = $given.Names; $o = $given.Overflow; if ($null -ne $set) { $n = $set.Names; $o = $set.Overflow }; return @{ path = 'full'; Text = $script:RhScrubFull; Reason = $why; Names = $n; Overflow = $o; Runs = $null } }
    if ($Bytes.Length -eq 0) { return @{ path = 'empty'; Text = ''; Reason = $null; Names = $given.Names; Overflow = $given.Overflow; Runs = @() } }
    if ($Bytes.Length -gt $script:RhFieldUnitsMax) { return (& $full 'size' $null) }
    if ([Array]::IndexOf([byte[]]$Bytes, [byte]0) -ge 0) { return (& $full 'nul' $null) }
    $text = $null
    try { $text = (New-Object System.Text.UTF8Encoding($false, $true)).GetString([byte[]]$Bytes) } catch { return (& $full 'not_utf8' $null) }
    $lead = 0
    while ($lead -lt $text.Length -and [int]$text[$lead] -eq 0xFEFF) { $lead++ }
    $text = $text.Substring($lead)
    $found = Get-RemoteHelpNames $text @{ names = $given.Names; overflow = $given.Overflow }
    $field = Invoke-RemoteHelpScrubField $text @{ names = $found.Names; overflow = $found.Overflow }
    if ($field.Full) { return (& $full $field.Reason $found) }
    return @{ path = 'text'; Text = $field.Text; Reason = $null; Names = $found.Names; Overflow = $found.Overflow; Result = $field.Result }
}

$writer = New-Object System.IO.StreamWriter($Out, $false, (New-Object System.Text.UTF8Encoding($false)))
$reader = New-Object System.IO.StreamReader($Jobs, (New-Object System.Text.UTF8Encoding($false)))
$fileAt = 0
try {
    while ($null -ne ($line = $reader.ReadLine())) {
        if ($line.Length -eq 0) { continue }
        $job = $line | ConvertFrom-Json
        $res = [ordered]@{ id = $job.id }
        try {
            switch ($job.op) {
                'scrub' { $res.out = Get-ScrubOut (Invoke-RemoteHelpScrub (Read-Units $job.input) (Get-NameArg $job.names)) }
                'harvest' {
                    $got = Get-RemoteHelpNames (Read-Units $job.input) (Get-NameArg $job.known)
                    $res.out = [ordered]@{ names = @($got.Names | ForEach-Object { Write-Units $_ }); overflow = [bool]$got.Overflow }
                }
                'field' {
                    # 이름 = 이 구현의 수확(harvest 가 있으면) 또는 받은 인자 그대로
                    $names = Get-NameArg $job.names
                    if ($null -ne $job.harvest) { $hv = Get-RemoteHelpNames (Read-Units $job.input) (Get-NameArg $job.harvest); $names = @{ names = $hv.Names; overflow = $hv.Overflow }; $res.set = [ordered]@{ names = @($hv.Names | ForEach-Object { Write-Units $_ }); overflow = [bool]$hv.Overflow } }
                    $o = $job.opts
                    $clock = $null
                    if ($null -ne $o.clockValues) { $clock = New-Clock $o.clockValues }
                    $keep = 'tail'; if ($o.keep -ceq 'head') { $keep = 'head' }
                    $res.out = Get-FieldOut (Invoke-RemoteHelpScrubField (Read-Units $job.input) $names $o.maxBytes $keep $o.budgetMs $clock $o.unitsMax)
                }
                'attach' {
                    # 설치기 첨부 — 바이트에서(ConvertTo-RemoteHelpAttachment) · 그리고 실제 파일 길(Get-ScrubbedTextBytes = 크기 문지기 + 파일 읽기 + 같은 함수)
                    $bytes = Read-HexBytes $job.hex
                    $known = Get-NameArg $job.known
                    $res.out = Get-SentOut (ConvertTo-RemoteHelpAttachment $bytes $known $job.max)
                    if ($job.file) {
                        $fileAt++
                        $p = Join-Path $TBase ('f' + $fileAt + '.log')
                        [System.IO.File]::WriteAllBytes($p, [byte[]]$bytes)
                        $script:RhNames = $known
                        $wire = Get-ScrubbedTextBytes $p $job.max
                        if ($null -eq $wire) { $res.file = $null } else { $res.file = (Write-HexBytes ([byte[]]$wire)) }
                        Remove-Item -LiteralPath $p -Force
                    }
                }
                'server' {
                    $got = Invoke-ServerViaPort (Read-HexBytes $job.hex) (Get-NameArg $job.known)
                    $runs = $null
                    if ($got.path -ceq 'empty') { $runs = @() } elseif ($got.path -ceq 'text' -and $null -eq $got.Result) { $runs = @() } elseif ($null -ne $got.Result) { $runs = (Get-Runs $got.Result.RunS $got.Result.RunE $got.Result.RunR) }
                    $res.out = [ordered]@{ path = $got.path; text = (Write-Units $got.Text); reason = $got.Reason; names = @(@($got.Names) | ForEach-Object { if ($_ -is [string]) { Write-Units $_ } else { $_ } }); overflow = [bool]$got.Overflow; runs = $runs }
                }
                default { $res.error = 'unknown op ' + $job.op }
            }
        } catch { $res.error = 'THROW ' + $_.Exception.Message }
        $writer.WriteLine(($res | ConvertTo-Json -Compress -Depth 6))
    }
} finally {
    $writer.Dispose(); $reader.Dispose()
    Remove-Item -LiteralPath $TBase -Recurse -Force -ErrorAction SilentlyContinue
}
