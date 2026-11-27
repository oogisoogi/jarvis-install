# ps51-enc-probe.ps1 — 첨부 글 파일의 실제 인코딩과 「엄격히 읽어 UTF-8 로 바꾸기」 실측 (TICKET=scrub-split-design-1116)
#   powershell.exe -NoProfile -ExecutionPolicy Bypass -File ps51-enc-probe.ps1     # Windows PowerShell 5.1 (windows-latest 러너)
#   pwsh -NoProfile -File ps51-enc-probe.ps1                                       # PowerShell 7 (견줌)
# 네트워크 0 · 임시 폴더에만 쓴다 · 끝에 지운다. 볼 것 = 맨 끝의 PROBE-SUMMARY 한 줄과 그 위 표.
# 재는 것 둘:
#   ㉠ 설치기가 쓰는 방식 그대로 만든 파일(설치 기록 = AppendAllText UTF-8 · 환경 보고 = WriteAllText UTF-8 · 설치 창 글자 = Start-Transcript)의 머리 바이트
#      + 견줌용(설치기는 쓰지 않는다): Out-File 기본 · `>` · Add-Content 기본 · Set-Content 기본
#   ㉡ 설계의 읽기 함수(엄격한 UTF-8 하나 · 실패 = 통째 가림)가 꼴마다 무엇을 돌려주는가
$ErrorActionPreference = 'Stop'
$ProbeDir = Join-Path ([System.IO.Path]::GetTempPath()) ('enc-probe-' + [guid]::NewGuid().ToString('N'))
[void](New-Item -ItemType Directory -Path $ProbeDir)
$Sample = '가나다 USERNAME=probeuser abc'
$FullMask = '<전부 지움>'

function Get-HeadHex([byte[]]$Bytes, [int]$Count) {
    $take = [math]::Min($Count, $Bytes.Length)
    $parts = @()
    for ($i = 0; $i -lt $take; $i++) { $parts += $Bytes[$i].ToString('X2') }
    return ($parts -join ' ')
}
function Get-NulCount([byte[]]$Bytes) {
    $count = 0
    foreach ($b in $Bytes) { if ($b -eq 0) { $count++ } }
    return $count
}
function Test-StrictUtf8([byte[]]$Bytes) {
    try { [void](New-Object System.Text.UTF8Encoding($false, $true)).GetString($Bytes); return $true } catch { return $false }
}
# 설계의 읽기 함수 — 엄격한 UTF-8 하나뿐이다(추정 없음 · UTF-16 은 머리표가 있어도 읽지 않는다 = 닫힌 실패 · master 결정 11-16).
#   EF BB BF 는 떼고 읽는다 · 한 바이트라도 어긋나면 통째 가림 · 읽은 글에 NUL 글자가 있으면 통째 가림.
function ConvertTo-StrictText([byte[]]$Bytes) {
    try {
        $skip = 0
        if ($Bytes.Length -ge 3 -and $Bytes[0] -eq 0xEF -and $Bytes[1] -eq 0xBB -and $Bytes[2] -eq 0xBF) { $skip = 3 }
        $text = (New-Object System.Text.UTF8Encoding($false, $true)).GetString($Bytes, $skip, $Bytes.Length - $skip)
        if ($text.IndexOf([char]0) -ge 0) { return @{ Full = $true; Why = 'nul'; Text = $FullMask } }
        return @{ Full = $false; Why = ''; Text = $text }
    } catch {
        return @{ Full = $true; Why = 'decode'; Text = $FullMask }
    }
}
function Show-Row([string]$Label, [byte[]]$Bytes) {
    $read = ConvertTo-StrictText $Bytes
    $out = [System.Text.Encoding]::UTF8.GetBytes([string]$read.Text)
    $kept = if ($read.Full) { '-' } elseif (([string]$read.Text).Contains('가나다')) { 'yes' } else { 'NO' }
    $verdict = if ($read.Full) { 'FULL(' + $read.Why + ')' } else { 'text' }
    Write-Host ('{0,-44} len={1,-6} head=[{2,-11}] nul={3,-4} strictUtf8={4,-5} -> {5,-13} hangulKept={6,-3} outStrictUtf8={7} outNul={8}' -f `
        $Label, $Bytes.Length, (Get-HeadHex $Bytes 4), (Get-NulCount $Bytes), (Test-StrictUtf8 $Bytes), $verdict, $kept, (Test-StrictUtf8 $out), (Get-NulCount $out))
    return (Get-HeadHex $Bytes 3)
}

Write-Output ('PSVersion=' + $PSVersionTable.PSVersion + ' Edition=' + $PSVersionTable.PSEdition + ' AnsiCodePage=' + [System.Text.Encoding]::Default.CodePage + ' ConsoleOut=' + [Console]::OutputEncoding.CodePage)
Write-Output '--- (1) 설치기가 쓰는 방식 그대로'
$fLog = Join-Path $ProbeDir 'bootstrap.log'
[System.IO.File]::AppendAllText($fLog, $Sample + [Environment]::NewLine, (New-Object System.Text.UTF8Encoding $false))
[System.IO.File]::AppendAllText($fLog, $Sample + [Environment]::NewLine, (New-Object System.Text.UTF8Encoding $false))
$headLog = Show-Row 'log   AppendAllText(UTF8 no BOM)' ([System.IO.File]::ReadAllBytes($fLog))
$fEnv = Join-Path $ProbeDir 'env-report.md'
[System.IO.File]::WriteAllText($fEnv, $Sample + "`r`n", (New-Object System.Text.UTF8Encoding($false)))
$headEnv = Show-Row 'env   WriteAllText(UTF8 no BOM)' ([System.IO.File]::ReadAllBytes($fEnv))
$fTr = Join-Path $ProbeDir 'transcript.txt'
$headTr = 'NOT-CREATED'
try {
    Start-Transcript -LiteralPath $fTr -Force -ErrorAction Stop | Out-Null
    Write-Host $Sample
    Stop-Transcript | Out-Null
    $headTr = Show-Row 'transcript Start-Transcript -Force' ([System.IO.File]::ReadAllBytes($fTr))
} catch { Write-Output ('transcript FAILED: ' + $_.Exception.GetType().Name + ' ' + $_.Exception.Message) }

Write-Output '--- (2) 견줌용 — 설치기는 이 방식으로 첨부 파일을 쓰지 않는다'
$fOut = Join-Path $ProbeDir 'outfile.txt';   $Sample | Out-File -LiteralPath $fOut
[void](Show-Row 'Out-File (기본)' ([System.IO.File]::ReadAllBytes($fOut)))
$fRed = Join-Path $ProbeDir 'redirect.txt';  $Sample > $fRed
[void](Show-Row '> 리다이렉트 (기본)' ([System.IO.File]::ReadAllBytes($fRed)))
$fAdd = Join-Path $ProbeDir 'addcontent.txt'; Add-Content -LiteralPath $fAdd -Value $Sample
[void](Show-Row 'Add-Content (기본 · v0.3.17 설치 기록)' ([System.IO.File]::ReadAllBytes($fAdd)))
$fSet = Join-Path $ProbeDir 'setcontent.txt'; Set-Content -LiteralPath $fSet -Value $Sample
[void](Show-Row 'Set-Content (기본)' ([System.IO.File]::ReadAllBytes($fSet)))

Write-Output '--- (3) 지어낸 바이트 꼴 — 읽기 함수가 닫히는가'
$le = [System.Text.Encoding]::Unicode.GetBytes($Sample)
[void](Show-Row 'UTF-16LE 머리표 없음' $le)
[void](Show-Row 'UTF-16LE 머리표 + 홀수 끝' ([byte[]](@(0xFF, 0xFE) + $le + @(0x41))))
[void](Show-Row 'UTF-16LE 머리표 + 짝 잃은 서러게이트' ([byte[]](@(0xFF, 0xFE) + $le + @(0x00, 0xD8, 0x41, 0x00))))
[void](Show-Row 'UTF-16BE 머리표' ([byte[]](@(0xFE, 0xFF) + [System.Text.Encoding]::BigEndianUnicode.GetBytes($Sample))))
[void](Show-Row 'UTF-8 머리표' ([byte[]](@(0xEF, 0xBB, 0xBF) + [System.Text.Encoding]::UTF8.GetBytes($Sample))))
[void](Show-Row 'UTF-8 + 틀린 바이트 하나(0xB1)' ([byte[]]([System.Text.Encoding]::UTF8.GetBytes($Sample) + @(0xB1))))
[void](Show-Row 'UTF-8 + NUL 바이트' ([byte[]]([System.Text.Encoding]::UTF8.GetBytes($Sample) + @(0x00, 0x41))))
[void](Show-Row 'UTF-8 끝이 잘린 한글(E3 80)' ([byte[]]([System.Text.Encoding]::UTF8.GetBytes($Sample) + @(0xE3, 0x80))))
try { [void](Show-Row 'CP949(한국어 ANSI)' ([System.Text.Encoding]::GetEncoding(949).GetBytes($Sample))) } catch { Write-Output ('CP949 인코딩을 만들지 못함(pwsh 7 은 기본 미등록): ' + $_.Exception.GetType().Name) }
try { [void](Show-Row '설치 기록에 v0.3.17 의 ANSI 줄이 섞임' ([byte[]]([System.Text.Encoding]::GetEncoding(949).GetBytes($Sample + "`r`n") + [System.Text.Encoding]::UTF8.GetBytes($Sample + "`r`n")))) } catch { }

Remove-Item -LiteralPath $ProbeDir -Recurse -Force -ErrorAction SilentlyContinue
Write-Output ('PROBE-SUMMARY ps=' + $PSVersionTable.PSVersion + ' log_head3=[' + $headLog + '] env_head3=[' + $headEnv + '] transcript_head3=[' + $headTr + ']')
# 기대(문서 근거 · 5.1): transcript_head3=[EF BB BF] · log/env 는 머리표 없음(샘플 첫 글자 「가」 = EA B0 80).
# (1) 절 세 줄이 전부 「-> text · hangulKept=yes」 여야 한다. (3) 절에서 text 인 것은 「UTF-8 머리표」 하나뿐이어야 한다(UTF-16 은 머리표가 있어도 FULL).
# 5.1 에서 transcript_head3 이 [FF FE ..] 로 나오면 = 설치 창 글자 파일이 UTF-16LE 라는 뜻 → (1) 의 그 줄이 FULL(decode) 로 찍힌다.
#   그때는 이 출력을 근거로 「윈 설치기에만 UTF-16LE 머리표 선언 읽기를 더할지」 를 master 에 올린다(지금 설계에는 그 가지가 없다).
