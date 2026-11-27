$ExecutionContext.SessionState.LanguageMode = 'ConstrainedLanguage'
function Try-It([string]$Label, [scriptblock]$Block) {
    try { $null = & $Block; Write-Output ("ok    " + $Label) } catch { Write-Output ("FAIL  " + $Label + " :: " + $_.FullyQualifiedErrorId) }
}
Write-Output ("mode = " + $ExecutionContext.SessionState.LanguageMode)
Try-It 'New-Object Dictionary[long,int]' { New-Object 'System.Collections.Generic.Dictionary[long,int]' }
Try-It 'New-Object List[int]' { New-Object 'System.Collections.Generic.List[int]' }
Try-It 'New-Object StringBuilder' { New-Object System.Text.StringBuilder }
Try-It 'New-Object Regex' { New-Object System.Text.RegularExpressions.Regex 'a' }
Try-It '[regex]::Matches' { [regex]::Matches('abc', 'b') }
Try-It '[regex]::Replace' { [regex]::Replace('abc', 'b', 'x') }
Try-It 'hashtable + array' { $h = @{}; $h['a'] = 1; $a = @(1, 2, 3); $a[1] }
Try-It 'string.IndexOf / Substring' { 'abcdef'.IndexOf('cd'); 'abcdef'.Substring(2, 2) }
Try-It 'string.ToCharArray' { 'abc'.ToCharArray() }
Try-It '[Array]::Sort' { $k = @(3, 1, 2); [Array]::Sort($k) }
Try-It '[char] / [int] casts' { [int][char]'a'; [string][char]0x41 }
Try-It 'New-Object int[]' { New-Object int[] 4 }
Try-It 'Stopwatch' { [System.Diagnostics.Stopwatch]::StartNew() }
Try-It 'Add-Type' { Add-Type -TypeDefinition 'public class Q1116 {}' }
# 닫힌 실패: 가림 함수 꼴(try 안에서 형식 생성 실패 → catch → 통째 가림 글)
function Scrub-Shape([string]$Text) {
    try { $d = New-Object 'System.Collections.Generic.Dictionary[long,int]'; return $Text } catch { return 'FULL-MASK' }
}
Write-Output ("scrub shape in CLM returns: " + (Scrub-Shape 'secret hong'))
