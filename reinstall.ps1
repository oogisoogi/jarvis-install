# 삭제하고 재설치하기 (윈도우) — 지우고 나서 처음부터 다시 깐다
#
# 무엇을 하는가
#   1) 이 컴퓨터의 상태를 살펴 목록으로 보여 준다
#   2) 확인을 받고 지운다 (설치 도우미가 놓은 것만)
#   3) 최신 설치 도우미를 새로 받아 처음부터 다시 돌린다
#
# 쓰는 법 — 창에 이 한 줄을 붙여넣으십시오 (명령 프롬프트 창에서도 같습니다)
#   powershell -NoProfile -ExecutionPolicy Bypass -Command "irm https://jarvis.godmeyou.kr/install/reinstall.ps1 -OutFile ([Environment]::GetFolderPath('UserProfile')+'\reinstall-jarvis.ps1'); powershell -ExecutionPolicy Bypass -File ([Environment]::GetFolderPath('UserProfile')+'\reinstall-jarvis.ps1')"
#
#   뒤에 -List 를 붙이면 무엇을 지울지 보기만 합니다 (아무것도 안 바꿉니다).
#
# ★로그인은 남깁니다. 다시 깐 뒤에도 로그인 화면이 안 뜹니다.
#   계정을 바꾸고 싶으실 때만 claude auth logout 을 하시고 다시 로그인하시면 됩니다.
#   (그것은 이 도구가 하는 일이 아닙니다 — 재설치와 계정 바꾸기는 다른 일입니다.)
#
# 한 트랜잭션입니다: 지우기가 중간에 실패하면 재설치로 넘어가지 않습니다.
#   반쯤 지운 위에 설치가 얹히면 어느 쪽 상태인지 아무도 모르게 되기 때문입니다.
#   그때는 멈추고 무엇이 남았는지 말합니다. 같은 줄을 다시 돌리면 거기서부터 이어서 갑니다.
#
# 창이 갑자기 닫히면 백신이 PowerShell 을 종료한 것일 수 있습니다. 다시 돌리면 이어서 진행됩니다.

param([switch]$List)

$ErrorActionPreference = 'Continue'
try { [Console]::OutputEncoding = [System.Text.Encoding]::UTF8 } catch { }

$Base          = 'https://jarvis.godmeyou.kr/install'
$Home_         = [Environment]::GetFolderPath('UserProfile')
$ResetFile     = Join-Path $Home_ 'reset-clean.ps1'
$BootstrapFile = Join-Path $Home_ 'install-jarvis.ps1'

Write-Host '=== 삭제하고 재설치하기 ==='
Write-Host ''

# ── 1단 · 지우는 도구를 받는다 ────────────────────────────────────
# 사이트에서 새로 받는다 — 이 컴퓨터에 남아 있던 옛 사본을 쓰면 옛 규칙으로 지운다.
try {
    Invoke-RestMethod ($Base + '/reset-clean.ps1') -OutFile $ResetFile -ErrorAction Stop
} catch {
    Write-Host '지우는 도구를 받지 못했습니다. 인터넷 연결을 확인하고 같은 줄을 다시 돌려 주십시오.'
    exit 2
}

if ($List) {
    powershell -ExecutionPolicy Bypass -File $ResetFile -List
    Write-Host ''
    Write-Host '(보기만 했습니다. 아무것도 지우지 않았고, 설치도 하지 않았습니다.)'
    exit 0
}

# ── 2단 · 지운다 ──────────────────────────────────────────────────
# 목록을 보여 주고 한 번 묻는 일은 지우는 도구가 한다. 여기서 두 번 묻지 않는다.
powershell -ExecutionPolicy Bypass -File $ResetFile
$resetRc = $LASTEXITCODE

if ($resetRc -eq 1) {
    # 사람이 그만두겠다고 답한 경우다. 실패가 아니다.
    Write-Host ''
    Write-Host '재설치도 하지 않았습니다. 이 컴퓨터는 그대로입니다.'
    exit 0
}

if ($resetRc -ne 0) {
    Write-Host ''
    Write-Host '지우다가 멈췄습니다 — 그래서 다시 설치하지 않았습니다.'
    Write-Host '   반쯤 지운 위에 설치를 얹으면 무엇이 어떤 상태인지 알 수 없게 됩니다.'
    Write-Host '   위에 남아 있다고 표시된 자리를 확인하시고, 같은 줄을 한 번 더 돌려 주십시오.'
    exit $resetRc
}

# ── 3단 · 처음부터 다시 깐다 ──────────────────────────────────────
Write-Host ''
Write-Host '=== 이제 처음부터 다시 깝니다 ==='
Write-Host ''
try {
    Invoke-RestMethod ($Base + '/bootstrap.ps1') -OutFile $BootstrapFile -ErrorAction Stop
} catch {
    Write-Host '설치 도우미를 받지 못했습니다. 인터넷 연결을 확인해 주십시오.'
    Write-Host '지우기는 끝났으므로, 이 컴퓨터는 지금 「아무것도 안 깔린 상태」입니다.'
    Write-Host '같은 줄을 다시 돌리시면 설치부터 이어서 갑니다.'
    exit 3
}

powershell -ExecutionPolicy Bypass -File $BootstrapFile
exit $LASTEXITCODE
