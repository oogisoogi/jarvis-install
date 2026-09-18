# 캡처 증거 흉내 몰이 (pwsh 7 · 맥 · TICKET=installer-capture-evidence 2026-09-16)
#   실물 bootstrap.ps1 을 함수 묶음(JARVIS_LIB_ONLY)으로 읽고 새 함수들을 직접 몬다.
#   ⛔바깥에 닿지 않는다 — 주소는 전부 127.0.0.1 의 가짜 서버이고 쓰기는 $Sb 안에서만.
param([string]$Src, [string]$Sb, [string]$Url)
$ErrorActionPreference = 'Continue'
$jh = "$Sb/home/install-jarvis"
New-Item -ItemType Directory -Force -Path $jh, "$Sb/bin" | Out-Null
$env:USERPROFILE = "$Sb/home"
$env:JARVIS_HOME = $jh
$env:JARVIS_PROGRESS_URL = $Url
$env:JARVIS_NO_PROGRESS = ''      # 🔴이 구역은 레버를 **일부러 끈다** — 레버가 켜져 있으면 재려는 그 길이 통째로 잠든다
$env:JARVIS_LIB_ONLY = '1'
. $Src
$env:JARVIS_LIB_ONLY = ''
function Out-Fact($k, $v) { Add-Content -Path "$Sb/facts" -Value ("$k=$v") -Encoding utf8 }

$jpg = [byte[]]::new(64)
for ($i = 0; $i -lt 64; $i++) { $jpg[$i] = [byte]($i % 251) }

# ⓪ 실물 함수 — 맥에는 윈도우 창이 없다. **흉내로 갈아 끼우기 전에** 실물을 잰다(뒤로 가면 흉내를 재게 된다).
Out-Fact 'installer_jpeg_null' ($null -eq (Get-InstallerWindowJpeg))
$script:CysCli = ''
Out-Fact 'appwin_nocli_null' ($null -eq (Get-AppWindowJpeg))
Out-Fact 'firstpane_null' ($null -eq (Get-EvidenceKindJpeg 'first_pane'))   # 윈도우에서 첫 자리는 앱 창 안의 한 칸이라 따로 찍을 창이 없다
Out-Fact 'unknownkind_null' ($null -eq (Get-EvidenceKindJpeg 'full_screen')) # ⛔모르는 종류에 전체 화면을 내주지 않는다

# 여기서부터 창 그림 함수를 **흉내로 갈아 끼운다**(윈도우 전용이라 맥에서는 언제나 $null · 그대로 두면 배선이 안 재진다)
$script:StubJpeg = $jpg
function Get-InstallerWindowJpeg { return $script:StubJpeg }
function Get-AppWindowJpeg { return $script:StubJpeg }
# 🔴전체 화면 함수도 흉내로 갈아 끼운다 — 맥에서는 실물이 언제나 $null 이라, 「모르는 종류에 전체 화면을 내준다」는
#   변이를 넣어도 답이 $null 로 같아 **그 축이 조용히 통과한다**(2026-09-16 뮤턴트 실측: 눈멂). 흉내를 둬야 갈린다.
function Get-ScreenJpeg { return $script:StubJpeg }

Out-Fact 'unknownkind_null2' ($null -eq (Get-EvidenceKindJpeg 'full_screen'))   # 흉내를 끼운 뒤 = 전체 화면을 내주면 여기서 갈린다

# ① 두 걸음 — 증거 이벤트로 자리를 받고 그림을 올린다
$slot = Send-EvidenceEvent 'stall' 'hello'
Out-Fact 'slot_seq' ([string]$slot.Seq)
Out-Fact 'slot_token_len' ([string]([string]$slot.Token).Length)
Out-Fact 'send1' (Send-EvidenceImage $slot 'installer_window' $jpg)
Out-Fact 'jpg_sha' ((Get-FileHash -InputStream ([System.IO.MemoryStream]::new($jpg)) -Algorithm SHA256).Hash.ToLower())
# ② 자리가 없으면(증거 이벤트 실패) 그림을 올리지 않는다
Out-Fact 'noslot' (Send-EvidenceImage $null 'installer_window' $jpg)
# ③ 계약에 없는 종류는 올리지 않는다
Out-Fact 'badkind' (Send-EvidenceImage $slot 'full_screen' $jpg)
# ④ 한 장 상한
Out-Fact 'oversize' (Send-EvidenceImage $slot 'installer_window' ([byte[]]::new($EvidenceImageMaxBytes + 1)))
# ⑤ 설치당 장수 상한
for ($i = 0; $i -lt 20; $i++) { [void](Send-EvidenceImage $slot 'installer_window' $jpg) }
Out-Fact 'sentcount' $script:EvidenceImageSent

# ⑥ 글자 없는 증거 — 빈 글은 400 이라 칸을 아예 빼야 한다
[void](Send-EvidenceEvent 'requested' '')

# ⑦ 기준선 — 표가 비면 어떤 소요도 느림이 아니다
Out-Fact 'slow_empty_huge' (Test-StepSlow '5/10' 99999)
Update-StepBaselines
Out-Fact 'baseline_note' $script:StepBaselineNote
Out-Fact 'baseline_5' $(if ($script:StepBaselineSec.ContainsKey('5/10')) { $script:StepBaselineSec['5/10'] } else { 'none' })
Out-Fact 'baseline_6_null' (-not $script:StepBaselineSec.ContainsKey('6/10'))   # median 이 null 인 칸은 안 채운다
Out-Fact 'slow_at_2x'   (Test-StepSlow '5/10' 20)
Out-Fact 'slow_over_2x' (Test-StepSlow '5/10' 20.5)
Out-Fact 'slow_unknown' (Test-StepSlow '9/10' 99999)

# ⑧ 운영팀 촬영 요청 — 진행 답에 실려 오고, 다음 처리 자리에서 찍힌다(1회성)
$script:EvidenceImageSent = 0
Send-Progress '5/10' 'end' $null 'rc=0' $null      # 이 답에 capture 칸이 실려 온다(가짜 서버가 준다)
Out-Fact 'capreq_kinds' (($script:CaptureRequested -join ','))
Invoke-CaptureRequested
Out-Fact 'capreq_after' ($null -eq $script:CaptureRequested)   # 1회성 — 쓰고 버린다
Out-Fact 'capreq_images' $script:EvidenceImageSent
Invoke-CaptureRequested                                         # 두 번째 호출은 아무 일도 하지 않는다
Out-Fact 'capreq_images2' $script:EvidenceImageSent

# ⑨ post-install 글자 — 첫 자리 화면 끝 40줄 · 훅 오류 줄 수 · 마스킹
# ⚠줄 수를 41 이상으로 둔다 — 첫 판은 딱 40줄이라 **아무것도 안 잘렸고**, 그래서 자르기 축이 헛돌았다(첫 실행이 잡았다).
$lines = @('CUT-ME-HEAD 이 줄은 끝 40줄 밖이라 나가면 안 된다')
for ($i = 1; $i -le 44; $i++) { $lines += ('line ' + $i) }
$lines += 'hong@example.com 으로 로그인했습니다'
$lines += 'Stop hook error: bash: command not found'
$lines += 'Stop hook error: bash 를 찾지 못했습니다'
$lines += 'hook error: 세 번째 줄'
$lines += 'C:\Users\hong\install-jarvis 에서 돕니다'
$lines += 'DONE-LAST 마지막 줄'
$script:StubScreen = ($lines -join "`n")
function Invoke-CysCapped([string]$Cli, [string]$ArgLine, [int]$CapMs) { return $script:StubScreen }
$script:EvidenceImageSent = 0
# 실물은 [10/10] 을 찍은 뒤에 이 증거를 보낸다 — 증거가 「지금 어느 단계인가」를 싣는지 재려면 그 자리를 흉내내야 한다
#   (안 하면 단계 칸이 0/10 으로 나가고, 그 어긋남을 시험이 잡는다 · 첫 실행이 그렇게 잡았다).
Say '[10/10] 함대가 섰습니다'
Send-PostInstallEvidence 'cys' 'surface:9'
Out-Fact 'postinstall_images' $script:EvidenceImageSent
Out-Fact 'stub_sha' ((Get-FileHash -InputStream ([System.IO.MemoryStream]::new([byte[]]$script:StubJpeg)) -Algorithm SHA256).Hash.ToLower())
$script:CaptureSent.Remove('post-install|10/10')
Send-PostInstallEvidence 'cys' ''                  # 자리를 모르면 글자는 없고 그림만(fail-open)

# ⑩ 촉발 사유 글 마스킹(ⓕ③) — 콘솔 줄을 통째로 넘기는 자리
$script:TranscriptOn = $false
Send-CaptureEvidence 'error-text' 'failed to open hong@example.com C:\Users\hong\x'

# ⑪ 오늘 몫을 다 썼다(429 image_cap) — 더 시도하지 않는다 · rate_limited 와 갈린다
Set-Content -Path "$Sb/state/image.status" -Value '429' -NoNewline
Set-Content -Path "$Sb/state/image.error" -Value 'rate_limited' -NoNewline
$script:EvidenceImageSent = 0
[void](Send-EvidenceImage $slot 'installer_window' $jpg)
Out-Fact 'after_rate_limited_done' $script:EvidenceImageDone   # 잠시 뒤 다시 올려도 되는 종류 = 접지 않는다
Set-Content -Path "$Sb/state/image.error" -Value 'image_cap' -NoNewline
[void](Send-EvidenceImage $slot 'installer_window' $jpg)
Out-Fact 'after_cap_done' $script:EvidenceImageDone
[void](Send-EvidenceImage $slot 'installer_window' $jpg)       # 접힌 뒤에는 요청 자체를 안 보낸다
Out-Fact 'after_fail' 'SURVIVED'
Remove-Item -Path "$Sb/state/image.status", "$Sb/state/image.error" -ErrorAction SilentlyContinue   # 아래 두 시험엔 무관 — 정상 응답으로 되돌린다

# ⑫ TICKET=installer-0325 c5(2026-09-18) — 못 읽으면(원본 파일이 없다) 빈 글이 아니라 사유 코드를 돌려준다
$script:LogFileSaved = $LogFile
$LogFile = (Join-Path $Sb 'no-such-log-c5.log')   # 존재하지 않는 자리 — Get-FileBytesCapped 가 $null 을 준다
$script:TranscriptOn = $false
Out-Fact 'evtext_empty_reason' (Get-EvidenceText)
$LogFile = $script:LogFileSaved

# ⑬ TICKET=installer-0325 c5(2026-09-18) — 그림 찍기가 예외로 죽어도 그 사유가 evidence_text 칸에 실려 서버에 닿는다
#   (옛 판은 catch 가 Write-Log 로 이 기계의 파일에만 적고 서버엔 아무 신호도 안 갔다 · 09-17 10:01 실기 WHm7yvpu)
function Get-InstallerWindowJpeg { throw 'boom-c5-capture' }
$script:EvidenceImageSent = 0
Send-EvidenceOnce 'c5-capture-fail'
Out-Fact 'c5_capture_images_sent' $script:EvidenceImageSent
