# bench-port.ps1 — 「제품」 윈 설치기의 가림 v3(bootstrap.ps1 Invoke-RemoteHelpScrub · Invoke-RemoteHelpScrubField)를 앞 좌석 측정 꼴로 잰다(TICKET=scrub-v3-port-1116 · ROLE=win)
#
#   powershell.exe -NoProfile -ExecutionPolicy Bypass -File tests\scrub-v3\ps51\bench-port.ps1 -Dir install-master     # 5.1 (windows-latest 러너 · master 집행)
#   pwsh -NoProfile -File tests/scrub-v3/ps51/bench-port.ps1 -Dir install-master                                         # 견줌
#
# 꼴·크기·기대 해시 = 같은 폴더의 bench.ps1 · spec.json · expected.json(앞 좌석 ps51-bench 의 바이트 사본 — 참조 모델이 낸 답의 코드 단위 sha256 앞 16자).
# 출력(탭으로 가른 줄):
#   ENV     <항목> <값>
#   RESULT  scrub  <꼴> <글자 수> <ms> <해시> match|MISMATCH|ERROR           ← 가림 함수 하나(예산 없음) · 답이 모델과 같은가
#   FIELD   field  <꼴> <글자 수> <ms> text|full:<까닭>                       ← 칸 처리(크기 문지기 + 예산 20초 + 전체 가림) · 제품이 실제로 부르는 꼴
#   SUMMARY port   mismatch=<n> max_ms=<n> field_full=<n>
# ⛔네트워크 0 · 쓰기 0(임시 폴더의 표식 파일뿐).
param([Parameter(Mandatory = $true)][string]$Dir, [string]$Sizes = '', [string]$Cases = '')
$ErrorActionPreference = 'Stop'
$here = Split-Path -Parent $MyInvocation.MyCommand.Path
$utf8 = New-Object System.Text.UTF8Encoding $false
$spec = [System.IO.File]::ReadAllText((Join-Path $here 'spec.json'), $utf8) | ConvertFrom-Json
$expected = [System.IO.File]::ReadAllText((Join-Path $here 'expected.json'), $utf8) | ConvertFrom-Json
$TBase = Join-Path ([System.IO.Path]::GetTempPath()) ('bench-port-' + [guid]::NewGuid().ToString('N'))
$THome = Join-Path $TBase 'install-jarvis'
New-Item -ItemType Directory -Force -Path $THome | Out-Null
[System.IO.File]::WriteAllText((Join-Path $THome '.jarvis-owned'), "jarvis-installer-owned v1`r`n", $utf8)
$env:JARVIS_LIB_ONLY = '1'; $env:JARVIS_HOME = $THome; $env:JARVIS_NO_PROGRESS = '1'
. (Join-Path $Dir 'bootstrap.ps1')
$env:JARVIS_LIB_ONLY = ''
$ErrorActionPreference = 'Stop'
function Write-Row([string[]]$Cells) { [Console]::Out.WriteLine(($Cells -join "`t")) }
Write-Row @('ENV', 'powershell', [string]$PSVersionTable.PSVersion)
Write-Row @('ENV', 'language_mode', [string]$ExecutionContext.SessionState.LanguageMode)

$shaAlg = [System.Security.Cryptography.SHA256]::Create()
function Get-Digest([string]$Text) {
    $chars = $Text.ToCharArray()
    $bytes = New-Object byte[] ($chars.Length * 2)
    [System.Buffer]::BlockCopy($chars, 0, $bytes, 0, $bytes.Length)
    return (([System.BitConverter]::ToString($shaAlg.ComputeHash($bytes))) -replace '-', '').ToLowerInvariant().Substring(0, 16)
}
# 꼴 만들기 — bench.ps1 New-Case 그대로(글자가 같아야 기대 해시가 맞는다)
$hong = ([string][char]0xD64D) + ([string][char]0xAE38) + ([string][char]0xB3D9)
function New-Case([string]$Id, [int]$N) {
    switch ($Id) {
        'log' {
            $sb = New-Object System.Text.StringBuilder
            for ($i = 0; $sb.Length -lt $N; $i++) {
                [void]$sb.Append('[').Append($i % 10).Append('/10] step ').Append($i).Append(' ok - /Users/hongtester/.local/bin/tool --flag - C:\Users\hongtester\AppData - user hongtester done - mail a').Append($i).Append('@example.com').Append([char]10)
            }
            $names = New-Object 'System.Collections.Generic.List[string]'
            for ($i = 0; $i -lt 194; $i++) { $names.Add('name' + $i + 'x') }
            $names.Add('hongtester')
            return @{ Text = $sb.ToString().Substring(0, $N); Names = $names.ToArray() }
        }
        'arun' { return @{ Text = ('a' * $N); Names = [string[]]@('aa', 'aaa') } }
        'chain' { return @{ Text = ('r' + ('x' * ($N - 1))); Names = [string[]]@('rx') } }
        'tilde' { return @{ Text = ('~' * $N); Names = [string[]]@(('~' * 256)) } }
        'nested' { return @{ Text = (('/Users/' * [int][Math]::Floor($N / 7)) + 'x'); Names = [string[]]@() } }
        'email' { return @{ Text = ('a@b.co ' * [int][Math]::Floor($N / 7)); Names = [string[]]@() } }
        'samehead' {
            $names = New-Object 'System.Collections.Generic.List[string]'
            for ($i = 0; $i -lt 256; $i++) { $names.Add(('a' * 200) + ([string]$i).PadLeft(56, [char]'b')) }
            return @{ Text = ('a' * $N); Names = $names.ToArray() }
        }
        'hits' { return @{ Text = ('ab ' * [int][Math]::Floor($N / 3)); Names = [string[]]@('ab') } }
        'korean' {
            $line = $hong + ' log /Users/' + $hong + '/x ok' + [char]10
            return @{ Text = ($line * [int][Math]::Floor($N / $line.Length)); Names = [string[]]@($hong) }
        }
    }
    throw "unknown case $Id"
}
$sizeList = @($spec.sizes | ForEach-Object { [int]$_ })
if ($Sizes) { $sizeList = @($Sizes -split ',' | ForEach-Object { [int]$_.Trim() }) }
$caseList = @($spec.cases | ForEach-Object { [string]$_ })
if ($Cases) { $caseList = @($Cases -split ',' | ForEach-Object { $_.Trim() }) }
$mismatch = 0; $maxMs = 0; $fieldFull = 0
try {
    foreach ($case in $caseList) {
        foreach ($size in $sizeList) {
            $made = New-Case $case $size
            $watch = [System.Diagnostics.Stopwatch]::StartNew()
            $status = 'match'; $digest = ''
            try {
                $out = Invoke-RemoteHelpScrub $made.Text $made.Names
                $watch.Stop()
                $digest = Get-Digest ([string]$out.Text)
                if ($digest -cne [string]$expected.("$($case):$size").digest) { $status = 'MISMATCH'; $mismatch++ }
            } catch { $watch.Stop(); $status = 'ERROR'; $mismatch++ }
            $ms = [int]$watch.Elapsed.TotalMilliseconds
            if ($ms -gt $maxMs) { $maxMs = $ms }
            Write-Row @('RESULT', 'scrub', $case, [string]$size, [string]$ms, $digest, $status)
            # 제품이 부르는 꼴 — 이름은 수확 묶음으로(넘침 없음 · 알려진 이름 = 이 꼴의 이름) · 예산 20초 · 자르지 않음
            $watch = [System.Diagnostics.Stopwatch]::StartNew()
            $field = Invoke-RemoteHelpScrubField $made.Text @{ names = $made.Names; overflow = $false } $null 'tail' $script:RhScrubBudgetMs
            $watch.Stop()
            $how = 'text'
            if ($field.Full) { $how = 'full:' + $field.Reason; $fieldFull++ }
            Write-Row @('FIELD', 'field', $case, [string]$size, [string][int]$watch.Elapsed.TotalMilliseconds, $how)
        }
    }
} finally { Remove-Item -LiteralPath $TBase -Recurse -Force -ErrorAction SilentlyContinue }
Write-Row @('SUMMARY', 'port', "mismatch=$mismatch", "max_ms=$maxMs", "field_full=$fieldFull")
