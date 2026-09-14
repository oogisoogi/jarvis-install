# 지우기 전 클로드 끄기 흉내 (pwsh 7 · 맥) — reset-clean.ps1 에서 함수 넷만 파서로 떼어 정의하고, 이름에 「\」 가 든 파일로
#   윈도우 경로 접두(…\) 비교를 그대로 태운다. ⚠Invoke-Purge·Drop·레지스트리는 윈도우 전용이라 여기서 안 돈다.
param([string]$Src, [string]$Sb)
$ErrorActionPreference = 'Continue'
New-Item -ItemType Directory -Force -Path "$Sb/home" | Out-Null
$tok = $null; $err = $null
$ast = [System.Management.Automation.Language.Parser]::ParseFile($Src, [ref]$tok, [ref]$err)
foreach ($name in @('Short', 'Get-ProcsUnder', 'Write-AliveProcs', 'Stop-ClaudeUnderBin')) {
    $fn = $ast.Find({ param($n) ($n -is [System.Management.Automation.Language.FunctionDefinitionAst]) -and ($n.Name -eq $name) }, $true)
    if (-not $fn) { "MISSING $name"; exit 3 }
    . ([scriptblock]::Create($fn.Extent.Text))
}
$env:USERPROFILE = "$Sb/home"
$ClaudeBin = "$Sb/home/bin"          # 비교 접두 = "$Sb/home/bin\"
$exeName = "$Sb/home/bin\claude.exe" # 맥에서는 「bin\claude.exe」 라는 한 파일 이름이다
# pwsh 는 「\」 를 경로 구분자로 바꿔 읽는다 — 이름에 「\」 가 든 파일은 셸로 만든다
# 시스템 sleep 을 복사하면 서명 때문에 곧바로 죽는다 — 작은 대기 프로그램을 그 이름으로 짓는다
& /bin/sh -c 'printf "#include <unistd.h>\nint main(void){for(;;){sleep(1);}return 0;}\n" > "$0"' "$Sb/w.c"
& /usr/bin/cc -w -x c "$Sb/w.c" -o $exeName
$procId = [int](& /bin/bash -c ('"$0" 3044 >/dev/null 2>&1 & echo $!') $exeName)
Start-Sleep -Milliseconds 500
$dbg = $null; try { $dbg = Get-Process -Id $procId -ErrorAction Stop } catch { }
"debug: alive-after-start=$([bool]$dbg) name=$($dbg.ProcessName) path=$($dbg.Path)"
$before = @(Get-ProcsUnder @($ClaudeBin))
"before: count=$($before.Count) ids=$(@($before | ForEach-Object { $_.Id }) -join ',') started=$procId path=$(@($before | ForEach-Object { $_.Path }) -join ',')"
$out = @(& { $script:left = @(Stop-ClaudeUnderBin) } 6>&1 | ForEach-Object { [string]$_ })
$out | ForEach-Object { '  | ' + $_ }
$alive = $false; try { $null = Get-Process -Id $procId -ErrorAction Stop; $alive = $true } catch { $alive = $false }
"after: returned-left=$(@($script:left).Count) process-alive=$alive"
if ($alive) { Stop-Process -Id $procId -Force -ErrorAction SilentlyContinue }
