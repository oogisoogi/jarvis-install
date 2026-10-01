# [2/10] 사용자 PATH 쓰기 거부(관리 PC · 표준 계정) — 설치는 끝났는데 PATH 에 못 넣으면 전체 경로로 이어 간다(도움 실사례 10-01)
#   실물 Step-InstallClaude · Seed-LocalBinPath 를 부르고, 공식 설치기(pwsh 이름)·사용자 PATH 읽기·쓰기만 가짜로 준다.
#   ⚠맥 PATH 구분자는 ':' 라 윈 PATH 해석은 재현하지 않는다 — 이 창 PATH 는 글자로, 이어 가기는 별칭 경로로 잰다.
param([string]$Src, [string]$Sb, [string]$Case)
$ErrorActionPreference = 'Continue'
New-Item -ItemType Directory -Force -Path "$Sb/home/install-jarvis", "$Sb/bin", "$Sb/home/.local/bin" | Out-Null
# 가짜 claude.exe(판본·도움말만 답한다)
$fake = "#!/bin/bash`ncase `"`$1`" in --version) echo '9.9.9 (Claude Code)'; exit 0 ;; --help) echo 'Commands:'; echo '  auth    Manage authentication'; exit 0 ;; esac`nexit 0`n"
Set-Content -Path "$Sb/claude-src" -Value $fake -NoNewline; & chmod +x "$Sb/claude-src"
# 가짜 공식 설치기(pwsh 이름) — 칸에 따라 claude.exe 를 두거나 안 두고 곧바로 끝난다
$place = if ($Case -eq 'deny-noexe') { '' } else { "cp '$Sb/claude-src' '$Sb/home/.local/bin/claude.exe'; chmod +x '$Sb/home/.local/bin/claude.exe'" }
Set-Content -Path "$Sb/bin/pwsh" -Value "#!/bin/bash`nsleep 4`n$place`nexit 0`n" -NoNewline; & chmod +x "$Sb/bin/pwsh"
# 이 개발 기기의 진짜 claude(~/.local/bin 등)를 가리지 않으면 흉내가 그것을 잡는다 — 시스템 자리와 가짜 설치기만
$env:PATH = "$Sb/bin:/usr/bin:/bin:/usr/sbin:/sbin:" + (Split-Path (Get-Process -Id $PID).Path -Parent)
$env:USERPROFILE = "$Sb/home"; $env:JARVIS_HOME = "$Sb/home/install-jarvis"; $env:JARVIS_LIB_ONLY = '1'; $env:JARVIS_NO_PROGRESS = '1'
. $Src
$env:JARVIS_LIB_ONLY = ''
$ClaudeInstallWaitMs = 20000; $InstallNoteEverySec = 30
$script:Said = New-Object System.Collections.ArrayList
function Say($t) { [void]$script:Said.Add([string]$t) }
function Write-JCode($c, $w) { $script:JCode = $c; [void]$script:Said.Add('JCODE ' + $c) }
function Invoke-RestMethod { throw 'no network in emulation' }
# 사용자 PATH 읽기·쓰기 — 칸에 따라 거부
$script:UserPath = 'C:\Windows'
function Get-UserPathValue { return $script:UserPath }
function Set-UserPathValue($v) { if ($Case -like 'deny*') { throw [System.UnauthorizedAccessException]::new('Attempted to perform an unauthorized operation.') }; $script:UserPath = $v }
$script:Pass = 0; $script:Fail = 0
function T([bool]$ok, [string]$name, [string]$why) { if ($ok) { $script:Pass++; Write-Output ('  ok   ' + $name) } else { $script:Fail++; Write-Output ('  FAIL ' + $name + '  ← ' + $why) } }
function Log-All { try { Get-Content -LiteralPath $LogFile -Raw -ErrorAction Stop } catch { '' } }
$bin = (Join-Path $env:USERPROFILE '.local\bin').TrimEnd('\')
$deniedWords = '사용자 환경 변수(PATH)를 바꾸지 못하게 막혀 있습니다'
switch ($Case) {
    'deny-exe' {
        # D1: 쓰기 거부 + claude.exe 있음·답함 → J-PATH-01 으로 멈추지 않고 [2/10] 완료
        $rc = @(Step-InstallClaude)[-1]; $s = $script:Said -join ' | '; $lg = Log-All
        T (($rc -eq 0) -and (-not $script:JCode)) 'D1 PATH 쓰기 거부 + claude.exe 있음 → [2/10] 이어 감(rc 0 · J-코드 0)' ('rc=' + $rc + ' j=' + $script:JCode + ' · ' + $s)
        T ($lg -match 'seed-path: denied') 'D1 기록 = seed-path: denied' $lg
        T ($s.Contains($deniedWords) -and $s.Contains('전체 경로로')) 'D1 화면 한 문장(거부일 때만)' $s
    }
    'deny-noexe' {
        # D2: 쓰기 거부 + claude.exe 없음 → 종전 갈래(J-PATH-01 또는 J-DL-07) · 거짓 성공 0 · 이어 간다는 문장 0
        $rc = @(Step-InstallClaude)[-1]; $s = $script:Said -join ' | '
        T (($rc -ne 0) -and ($script:JCode -in @('J-PATH-01', 'J-DL-07')) -and (-not $s.Contains('전체 경로로'))) 'D2 파일 없음 → 종전 진단 코드 · 이어 간다는 말 0' ('rc=' + $rc + ' j=' + $script:JCode + ' · ' + $s)
    }
    'ok-write' {
        # D3: 정상 기기(쓰기 성공) → 거부 문장 0 · rc 0 · 기록 = added
        $rc = @(Step-InstallClaude)[-1]; $s = $script:Said -join ' | '; $lg = Log-All
        T (($rc -eq 0) -and (-not $s.Contains($deniedWords)) -and ($lg -match 'seed-path: added')) 'D3 정상 기기 = 거부 문장 0 · 기록 added · rc 0' ('rc=' + $rc + ' · ' + $s)
    }
    'deny-twice' {
        # D4: 거부여도 이 창 PATH 앞에 ~\.local\bin — 두 번 불러도 한 번만
        $env:Path = 'X'
        [void](Seed-LocalBinPath); [void](Seed-LocalBinPath)
        $n = ([regex]::Matches([string]$env:Path, [regex]::Escape($bin + ';'))).Count
        T (([string]$env:Path).StartsWith($bin + ';') -and ($n -eq 1)) 'D4 거부여도 이 창 PATH 앞에 한 번만' ('Path=' + $env:Path)
    }
    'deny-report' {
        # D5: 환경 보고(보내는 본문)에 거부 1줄
        [void](Step-InstallClaude)
        $rep = try { Get-Content -LiteralPath $ReportFile -Raw -ErrorAction Stop } catch { '' }
        T ($rep -match 'PATH' -and $rep -match '거부') 'D5 환경 보고에 사용자 PATH 쓰기 거부 1줄' $rep
    }
}
Write-Output ('RESULT pass=' + $script:Pass + ' fail=' + $script:Fail)
