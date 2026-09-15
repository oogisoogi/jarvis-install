# 재설치 흉내 (pwsh 7 · 맥) — 실물 reinstall.ps1 을 처음부터 끝까지 부른다: 받기(가짜) → 지우기(실물 reset-clean · 자식 pwsh) → 설치 도우미(가짜)
#   받기 = Invoke-RestMethod 를 함수로 덮어 install-master 사본을 복사 · 「powershell -File …」 = 함수로 덮어 자식 pwsh 로 부른다($LASTEXITCODE 가 그대로 넘어온다)
param([string]$Src, [string]$Sb, [string]$Pw)
$ErrorActionPreference = 'Continue'
$U = "$Sb/C:/Users/emu"   # 맥 실경로 — 지우개에게는 C:\Users\emu 로 보인다(reset-host.ps1 의 C: 드라이브)
$Emu = $PSScriptRoot

# ── 설치가 끝난 기계의 자국 ──
New-Item -ItemType Directory -Force -Path "$U/AppData/Local/cys", "$U/AppData/Local/Temp", "$U/AppData/Roaming", "$U/.cys", "$U/install-jarvis", "$Sb/reg/Software/Microsoft/Windows/CurrentVersion/Uninstall/cys", "$Sb/childhome" | Out-Null
& /bin/ln -s "$Sb/C:" "$Sb/cdrv"
Set-Content -LiteralPath "$U/AppData/Local/cys/uninstall.exe" -Value 'emu uninstaller' -NoNewline
# 지난 설치가 남긴 cys 편성 기록 — 윈도우 기본 cys 의 상태 자리가 곧 프로그램 폴더라 여기에 있다(2026-09-15 윈 2차 재설치 실기).
#   재설치는 이것을 지우고(동료 좌석이 되살아나는 원천) 프로그램 파일(pack.tar.gz · runtime\ · cys.exe)은 남겨야 한다.
New-Item -ItemType Directory -Force -Path "$U/AppData/Local/cys/phoenix", "$U/AppData/Local/cys/boot-intents", "$U/AppData/Local/cys/runtime" | Out-Null
Set-Content -LiteralPath "$U/AppData/Local/cys/topology.json" -Value '{"topology":[{"role":"master"},{"role":"cso"},{"role":"worker"}]}' -NoNewline
Set-Content -LiteralPath "$U/AppData/Local/cys/topology.json.corrupt-1" -Value 'emu' -NoNewline
Set-Content -LiteralPath "$U/AppData/Local/cys/phoenix/desired_roster.json" -Value '{}' -NoNewline
Set-Content -LiteralPath "$U/AppData/Local/cys/boot-intents/emu.json.done" -Value '{}' -NoNewline
Set-Content -LiteralPath "$U/AppData/Local/cys/dept_tombstones.json" -Value '[]' -NoNewline
Set-Content -LiteralPath "$U/AppData/Local/cys/pack.tar.gz" -Value 'emu' -NoNewline
Set-Content -LiteralPath "$U/AppData/Local/cys/runtime/emu.txt" -Value 'emu' -NoNewline
# ⚠cys.exe 는 실행 가능한 가짜로 둔다 — 지우개가 「cys daemon uninstall」 을 부른다(Get-CysCmd). 실행 권한 없는 파일은 pwsh 가 맥 기본 앱(open)으로 넘길 수 있다.
Set-Content -LiteralPath "$U/AppData/Local/cys/cys.exe" -Value "#!/bin/sh`necho `"`$*`" >> '$Sb/cys-calls.log'`nexit 0`n" -NoNewline
& chmod +x "$U/AppData/Local/cys/cys.exe"
Set-Content -LiteralPath "$U/.cys/emu.txt" -Value 'emu' -NoNewline
Set-Content -LiteralPath "$U/install-jarvis/emu.txt" -Value 'emu' -NoNewline
# 설치기가 새로 만든 작업 폴더에만 놓는 표식 — 없으면 지우개가 안전 관문에서 [남음] 으로 남긴다(Test-SafeJarvisDir)
Set-Content -LiteralPath "$U/install-jarvis/.jarvis-owned" -Value 'jarvis-installer-owned v1' -NoNewline
Set-Content -LiteralPath "$U/install-jarvis.ps1" -Value '# emu old installer copy' -NoNewline

$env:USERPROFILE  = 'C:\Users\emu'
$env:LOCALAPPDATA = 'C:\Users\emu\AppData\Local'
$env:APPDATA      = 'C:\Users\emu\AppData\Roaming'
$env:TEMP         = 'C:\Users\emu\AppData\Local\Temp'
$env:JARVIS_HOME  = 'C:\Users\emu\install-jarvis'
$env:HOME         = $U   # 재설치의 [Environment]::GetFolderPath('UserProfile') 는 맥에서 HOME 이다 — 실제 홈에 받지 않게
$env:JARVIS_BASE_URL = 'http://127.0.0.1:9/emu-install'   # 덮기가 빠져도 바깥에 안 닿게(닫힌 자리)
$env:JARVIS_NO_PROGRESS = '1'
Remove-Item -LiteralPath "$Sb/readhost.log" -Force -ErrorAction SilentlyContinue

# ── 바꿔 끼우는 것 ──
function Invoke-RestMethod {
    [CmdletBinding()] param([Parameter(Position = 0)] [string]$Uri, [string]$OutFile)
    Add-Content -LiteralPath "$Sb/net.log" -Value ("IRM $Uri -> $OutFile")
    if ($Uri -like '*/reset-clean.ps1') { [System.IO.File]::Copy("$Src/reset-clean.ps1", $OutFile, $true); return }
    if ($Uri -like '*/bootstrap.ps1') {
        [System.IO.File]::WriteAllText($OutFile, "Add-Content -LiteralPath '$Sb/bootstrap-marker.txt' -Value 'FAKE-BOOTSTRAP-RAN'`nexit 0`n")
        return
    }
    throw "emu: 모르는 주소 $Uri"
}
function powershell {
    $file = ''; $sw = @(); $i = 0
    while ($i -lt $args.Count) {
        $a = [string]$args[$i]
        if ($a -eq '-ExecutionPolicy') { $i += 2; continue }
        if ($a -eq '-File') { $file = [string]$args[$i + 1]; $i += 2; continue }
        if ($a.StartsWith('-')) { $sw += $a.Substring(1) }
        $i++
    }
    Add-Content -LiteralPath "$Sb/calls.log" -Value ('powershell ' + (Split-Path $file -Leaf) + ' [' + ($sw -join ',') + ']')
    # ⚠자식 pwsh 는 HOME 에 「:」 가 들면 뜨지 못한다(모듈 경로를 「:」 로 가르다 「The shell cannot be started … startIndex」 · rc 70 실측 2026-09-15).
    #   HOME 을 「C:」 폴더 안으로 둔 것은 재설치의 받는 자리 때문이다 — 지우개·설치 도우미는 HOME 을 안 쓰므로 자식에게만 따로 준다.
    $savedHome = $env:HOME
    $env:HOME = "$Sb/childhome"
    try {
        if ((Split-Path $file -Leaf) -eq 'reset-clean.ps1') {
            & perl -e 'alarm shift; exec @ARGV' 120 $Pw -NoProfile -NonInteractive -File "$Emu/reset-host.ps1" -Target $file -Log "$Sb/readhost.log" -Switches ($sw -join ',') -Sb $Sb 2>&1 |
                ForEach-Object { [string]$_ } | Tee-Object -Append -FilePath "$Sb/reset-out.txt"
            Set-Content -LiteralPath "$Sb/reset-rc.txt" -Value ([string]$LASTEXITCODE) -NoNewline
            return
        }
        & perl -e 'alarm shift; exec @ARGV' 60 $Pw -NoProfile -NonInteractive -File $file
    } finally { $env:HOME = $savedHome }
}

& "$Src/reinstall.ps1"
$reinstallRc = $LASTEXITCODE

$rl = if (Test-Path -LiteralPath "$Sb/readhost.log") { @(Get-Content -LiteralPath "$Sb/readhost.log").Count } else { 0 }
@(
    "reinstall_rc=$reinstallRc"
    'reset_rc=' + $(if (Test-Path -LiteralPath "$Sb/reset-rc.txt") { Get-Content -LiteralPath "$Sb/reset-rc.txt" -Raw } else { '' })
    'cys_dir=' + (Test-Path -LiteralPath "$U/AppData/Local/cys")
    'uninstall_exe=' + (Test-Path -LiteralPath "$U/AppData/Local/cys/uninstall.exe")
    'cys_home=' + (Test-Path -LiteralPath "$U/.cys")
    'jarvis_dir=' + (Test-Path -LiteralPath "$U/install-jarvis")
    'bootstrap_marker=' + (Test-Path -LiteralPath "$Sb/bootstrap-marker.txt")
    "readhost_lines=$rl"
) | Set-Content -LiteralPath "$Sb/summary.txt"
