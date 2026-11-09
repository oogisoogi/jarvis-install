# Q6LNC844 흉내 몰이 (pwsh 7 · 맥 · 2026-11-09)
#   실물 bootstrap.ps1 을 함수 묶음(JARVIS_LIB_ONLY)으로 읽고 설치 창 그림 함수를 직접 부른다.
#   ⛔바깥에 닿지 않는다 — 진행 전송 끔 · 쓰기는 $Sb 안에서만.
param([string]$Src, [string]$Sb)
$ErrorActionPreference = 'Continue'
$jh = "$Sb/home/install-jarvis"
New-Item -ItemType Directory -Force -Path $jh | Out-Null
$env:USERPROFILE = "$Sb/home"
$env:JARVIS_HOME = $jh
$env:JARVIS_NO_PROGRESS = '1'
$env:JARVIS_LIB_ONLY = '1'
. $Src
$env:JARVIS_LIB_ONLY = ''
function Out-Fact($k, $v) { Add-Content -Path "$Sb/facts" -Value ("$k=$v") -Encoding utf8 }

# ⓐ 처음 부르기 전에는 형식이 없다(이 축이 대상에 닿는지 먼저 단언 — 이미 있으면 아래 두 축이 공허하다)
Out-Fact 'type_before' ([bool](([System.Management.Automation.PSTypeName]'Jarvis.Win').Type))
$Error.Clear()
[void](Get-InstallerWindowJpeg)
# ⓑ 설치 창 그림을 한 번 부르면 형식이 생겨 있어야 한다(앞 판 = 형식을 만드는 함수가 손잡이 0 에서 먼저 돌아가 영영 안 생겼다)
Out-Fact 'type_after' ([bool](([System.Management.Automation.PSTypeName]'Jarvis.Win').Type))
# ⓒ 그 호출이 「형식을 찾을 수 없다」 오류를 $Error 에 남기지 않는다 — 남기면 끝맺음이 그 줄을 「마지막 오류」로 적어 진짜 끝을 가린다
$tnf = @($Error | Where-Object { $_.FullyQualifiedErrorId -eq 'TypeNotFound' }).Count
Out-Fact 'typenotfound' $tnf
