# Q6LNC844 ⓑ 흉내 몰이 — 설치 창 그림을 별도 프로세스 + 시간 상한으로 찍는다(pwsh 7 · 맥 · 2026-11-09)
#   실물 Invoke-IsolatedWindowJpeg 를 몬다. 자식이 실행할 「찍기」 함수(Get-WindowJpeg)만 이 세션에서 흉내로 바꾼다 —
#   자식 대본은 살아 있는 함수 정의에서 만들어지므로 흉내가 자식에 그대로 실린다(맥에는 윈도우 창이 없다).
#   ⛔바깥에 닿지 않는다 — 진행 전송 끔 · 쓰기는 $Sb 안에서만 · 자식은 번호로만 거둔다.
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
function Count-Left { @(Get-ChildItem -LiteralPath $jh -Filter 'capture-*' -ErrorAction SilentlyContinue).Count }
Out-Fact 'has_fn' ([bool](Get-Command Invoke-IsolatedWindowJpeg -ErrorAction SilentlyContinue))

# ① 성공 — 자식이 찍은 바이트가 그대로 돌아오고, 자식이 적은 기록 줄이 설치 기록으로 옮겨진다
function Get-WindowJpeg($h) { Write-Log 'stub-child-line'; return [byte[]](1..64) }
$b = Invoke-IsolatedWindowJpeg ([IntPtr]123)
Out-Fact 'ok_len' $(if ($b) { $b.Length } else { 0 })
Out-Fact 'ok_same' $(if ($b) { [bool](($b -join ',') -eq ((1..64) -join ',')) } else { $false })
Out-Fact 'ok_left' (Count-Left)

# ② 멈춤 — 자식이 상한 안에 안 끝나면 끄고 그림 없이 돌아온다(상한을 3초로 줄여 잰다)
$WindowCaptureCapSec = 3
function Get-WindowJpeg($h) { Start-Sleep -Seconds 60; return [byte[]](1..8) }
$sw = [System.Diagnostics.Stopwatch]::StartNew()
$b = Invoke-IsolatedWindowJpeg ([IntPtr]123)
Out-Fact 'hang_null' ($null -eq $b)
Out-Fact 'hang_sec' ([int]$sw.Elapsed.TotalSeconds)
$alive = $false
if ($script:CaptureChildPid) { $alive = [bool](Get-Process -Id $script:CaptureChildPid -ErrorAction SilentlyContinue) }
Out-Fact 'hang_child_alive' $alive
Start-Sleep -Milliseconds 500
Out-Fact 'hang_left' (Count-Left)

# ③ 자식 오류 — 자식 안에서 던지면 그 사유와 종료 코드가 설치 기록에 남고 그림 없이 돌아온다(교차 검토 2차)
$WindowCaptureCapSec = 10
function Get-WindowJpeg($h) { throw 'stub-child-boom' }
$b = Invoke-IsolatedWindowJpeg ([IntPtr]123)
Out-Fact 'err_null' ($null -eq $b)
Out-Fact 'err_left' (Count-Left)
