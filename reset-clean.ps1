# 깨끗이 지우기 (윈도우) — 설치 도우미가 놓은 것을 도로 걷어 낸다
#
# 무엇을 하는가
#   이 컴퓨터의 상태를 먼저 살펴 목록으로 보여 주고, 묻지 않고 치운다(0.3.37 · 사람 손 0).
#   지우는 것은 footprint.md 에 적힌 것 가운데 **다시 받을 수 있는 프로그램 파일·등록뿐**이다.
#   사람이 쌓은 자료(자비스 작업 폴더 · ~\.cys · 프로그램 폴더 안 실행 기록 · 부서 기록)는
#   「install-jarvis-backup-<날짜-시각>」 보관 폴더로 옮긴다. 사진·문서 같은 개인 파일은 손대지 않는다.
#
# 쓰는 법
#   powershell -ExecutionPolicy Bypass -File reset-clean.ps1              목록을 보여 주고 묻지 않고 치운다(자료는 보관 폴더로)
#   powershell -ExecutionPolicy Bypass -File reset-clean.ps1 -List        살펴보기만 한다
#   powershell -ExecutionPolicy Bypass -File reset-clean.ps1 -WhatIf      위와 같다(옛 이름)
#   powershell -ExecutionPolicy Bypass -File reset-clean.ps1 -Yes         알림 뒤 5초를 기다리지 않는다(재설치가 안에서 쓴다 · 0.3.37 부터 묻는 단계는 없다)
#   powershell -ExecutionPolicy Bypass -File reset-clean.ps1 -PurgeLogin  로그인까지 지운다
#
# 받아서 바로 돌리는 한 줄 (명령 프롬프트 창에서도 같다)
#   powershell -NoProfile -ExecutionPolicy Bypass -Command "try { Remove-Item ([Environment]::GetFolderPath('UserProfile')+'\reset-clean.ps1') -ErrorAction SilentlyContinue; irm https://jarvis.godmeyou.kr/install/reset-clean.ps1 -OutFile ([Environment]::GetFolderPath('UserProfile')+'\reset-clean.ps1') -ErrorAction Stop; powershell -ExecutionPolicy Bypass -File ([Environment]::GetFolderPath('UserProfile')+'\reset-clean.ps1') } catch { Write-Host '설치 파일을 받지 못했습니다. 인터넷 연결을 확인하신 뒤 이 줄을 다시 붙여 넣어 주십시오.'; exit 1 }"
#   내려받는 자리를 임시 폴더가 아니라 사용자 폴더로 둔 까닭은 설치 도우미와 같다:
#   임시 폴더는 언제든 비워지고, 회사 컴퓨터는 그 자리에서의 실행 자체를 막아 두는 설정이 흔하다.
#
# 지운 프로그램은 다시 설치하면 돌아온다. 자료는 보관 폴더에 남는다 — 그래서 확인 질문을 두지 않는다(0.3.37).
#
# ★로그인은 기본으로 남긴다 (2026-09-08 개정 · 앞 판은 지웠다).
#   앞 판은 %USERPROFILE%\.claude 폴더와 .claude.json 을 통째로 지웠다. 그 한 줄이 로그인과
#   대화 기록과 남의 설정 칸을 한꺼번에 날렸다. 이제 셋을 갈라서 다룬다:
#     전부 우리 것        -> 통째로 지운다
#     남의 파일 속 우리 줄 -> 우리가 넣은 칸만 도로 뺀다. 파일은 안 지운다
#     손대지 않음         -> 아무것도 안 한다(목록에만 적어 사람이 알게 한다)
#   ⚠실험(깨끗한 기계 재설치 채점)에서 로그인까지 지우려면 -PurgeLogin 을 붙여야 한다.
#     이 도구를 쓰는 사람이 둘이기 때문이다 — 재설치하는 사용자와, 손 개수를 재는 실험.
#
# cys 프로그램은 제거 프로그램(uninstall.exe)을 띄우지 않고 이 스크립트가 **프로그램 파일만** 직접 지운다(0.3.37).
#   왜: 제거 프로그램을 이 스크립트가 직접 띄우면 백신이 그 행위를 막고 PowerShell 을 통째로
#   종료시키는 일이 실제로 있었다(2026-09-05 · V3 · 진단명 Execution/MDP.Powershell.M1201).
#   그때 스크립트는 아무 말도 남기지 못하고 사라지며 아무것도 지워지지 않는다.
#   앞 판은 설정 앱 제거를 사람에게 시켰다 — 0.3.37 부터는 공식 제거기가 하던 뒷정리(설치 목록 항목 · 바로가기 ·
#   설치 위치 기록 · 자동 실행 값)를 **우리 설치 자리를 가리킬 때만** 우리가 한다(Remove-CysProgramFiles · Remove-OurShortcuts · Invoke-OurRegistryCleanup). (-UseUninstaller 로 옛 방식 선택)
# 창이 갑자기 닫히면 백신이 PowerShell 을 종료한 것일 수 있다. 그때는 Show-RerunHow 가 인쇄한
#   명령 전체를 다시 붙여넣으면 이어서 진행된다(사람에게 「같은 줄」이라고 말하지 않는다 - 아래 참조).

param([switch]$WhatIf, [switch]$List, [switch]$Yes, [switch]$PurgeLogin, [switch]$UseUninstaller, [switch]$KeepApp, [switch]$KeepHistory)
# -KeepApp : cys 프로그램은 지우지 않는다(재설치 길 · reinstall.ps1 이 -Yes 와 함께 넘긴다).
# -KeepHistory : 자비스 창의 로그인과 이전 대화는 지우지 않는다(재설치 길 · reinstall.ps1 이 늘 넘긴다 · 0.3.36 ·
#   Get-HistoryKeeps 머리 주석). -KeepApp 과 따로 선다 — 혼자 돌리는 지우기에는 붙지 않는다(종전대로 지운다).
#   그 길에서는 프로그램 걷기(프로그램 파일 지우기 · 설치 목록 항목 · 바로가기)를 통째로 건너뛴다 — 사람 손 0.
#   프로그램과 한 쌍인 시작 메뉴 바로가기 · 설치 목록 항목도 함께 남긴다(프로그램만 남고 그 둘이 사라지면 고아가 된다).
#   프로세스 끄기 · 상시 가동 등록 떼기 · 설정 · 로그인 처리는 종전대로 한다.
#   ⚠프로그램 폴더 안의 **지난 편성 기록**(동료 좌석을 되살리는 기록)은 보관 폴더로 옮긴다(0.3.37 · 앞 판은 지웠다) — Get-CysStateItems 머리 주석.
#   0.3.37: -KeepHistory 길은 ~\.cys 를 통째로 보관 폴더로 옮긴 뒤 남길 것(로그인·대화 · 부서 기록)만 제자리로 되옮긴다(Invoke-CysHomeReinstall).

$ErrorActionPreference = 'Continue'
try { [Console]::OutputEncoding = [System.Text.Encoding]::UTF8 } catch { }
$ListOnly = ($WhatIf -or $List)

$CysDir     = Join-Path $env:LOCALAPPDATA 'cys'
$CysDirOld  = Join-Path $env:LOCALAPPDATA 'Programs\cys'
$UninstExe  = Join-Path $CysDir 'uninstall.exe'
$RegKey     = 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Uninstall\cys'
# 0.3.37: 1.1.x 의 설치 목록 항목 이름은 cysr 다(설치 템플릿 UNINSTKEY = Uninstall\<제품 이름> · installer.nsi:66 · tauri.conf.json:3 productName).
#   옛 이름 cys 항목은 새 판 설치가 지운다(nsis-hooks.nsh:862~868) — 둘 다 보되 **우리 설치 자리를 가리킬 때만** 지운다.
$RegKeyR    = 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Uninstall\cysr'
# 설치 위치 기록 = Software\<제조사>\<제품 이름> 의 기본값(installer.nsi:67~68·708). 제조사 = tauri.conf.json 에 publisher 가 없어
#   기본값 「식별자의 둘째 칸」(tauri-utils config.rs publisher 설명 · 식별자 com.cysjavis.terminal) = cysjavis.
$ManuKey    = 'HKCU:\Software\cysjavis'
$RunKey     = 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Run'
# 앱 화면(웹뷰) 자료 — 설치 템플릿의 「앱 데이터 삭제」 칸이 지우는 자리(installer.nsi:910~911 · 식별자 = tauri.conf.json:5).
#   완전 삭제에서 보관 폴더로 옮긴다(지우지 않는다). 재설치 길은 무접촉.
$WebviewRoaming = Join-Path $env:APPDATA 'com.cysjavis.terminal'
$WebviewLocal   = Join-Path $env:LOCALAPPDATA 'com.cysjavis.terminal'
# 닫은 부서 휴지통(cys 가 부서를 닫을 때 옮겨 두는 자리) — 완전 삭제 = 보관 · 재설치 = 제자리.
$CysTrash   = Join-Path $env:USERPROFILE '.local\state\cys-trash'
# 🔴재설치 길(-KeepApp)에서 프로그램과 함께 남으면 안 되는 것 = cys 의 **지난 편성 기록**이다(2026-09-15 윈 2차 재설치).
#   윈도우 기본 cys 의 상태 자리가 곧 프로그램 폴더다(cys 코드: 상태 자리 = %LOCALAPPDATA%\cys).
#   cys 는 켜지자마자 그 자리의 편성 기록으로 지난 동료 좌석을 되살린다. 프로그램만 남기려다 이것까지 남기면,
#   로그인·첫 실행 설정이 지워진 빈 자리로 동료 셋이 설치 도우미보다 먼저 떠서 첫 실행 질문 앞에 선다.
#   ⇒ 프로그램 파일은 남기고 **아래 이름만** 보관 폴더로 옮긴다(0.3.37 · 앞 판은 지웠다 · 이름은 cys 코드에서 읽었다 — 모르는 것은 건드리지 않는다).
function Get-CysStateItems {
    $out = New-Object System.Collections.ArrayList
    foreach ($n in @('topology.json', 'phoenix', 'boot-intents', 'dept_tombstones.json')) {
        $p = Join-Path $CysDir $n
        if (Test-Path -LiteralPath $p) { [void]$out.Add($p) }
    }
    # 같은 기록의 손상 격리본·임시본(topology.json.corrupt-<시각> 등)
    #   ⚠실경로(FullName)가 아니라 이름으로 다시 잇는다 — 지우는 함수는 원문 자리 모양(C:\…)만 받는다(Drop · 링크를 따라가지 않는 규칙).
    foreach ($f in @(Get-ChildItem -LiteralPath $CysDir -Filter 'topology.json.*' -Force -ErrorAction SilentlyContinue)) { [void]$out.Add((Join-Path $CysDir $f.Name)) }
    return $out.ToArray()
}
# 🔴설치기가 `JARVIS_HOME` 을 존중하므로 제거기도 존중해야 한다(1차 REVISE ⑦ 확정 2026-09-10).
#   앞 판은 고정 `%USERPROFILE%\install-jarvis` 만 지웠다 ⇒ 사용자 지정 폴더로 깐 기계에서는
#   ⑴진짜 작업 폴더와 그 신뢰 자국이 **그대로 남고** ⑵기본 자리에 같은 이름의 남의 폴더가 있으면
#   **엉뚱한 폴더를 지운다.** 맥 제거기는 원래 환경변수를 따랐다 — 두 OS 가 갈려 있던 자리다.
$JarvisDir  = if ($env:JARVIS_HOME) { $env:JARVIS_HOME } else { Join-Path $env:USERPROFILE 'install-jarvis' }
$CysHome    = Join-Path $env:USERPROFILE '.cys'
$ClaudeDir  = Join-Path $env:USERPROFILE '.claude'
$ClaudeJson = Join-Path $env:USERPROFILE '.claude.json'
$ClaudeExe  = Join-Path $env:USERPROFILE '.local\bin\claude.exe'
$ClaudeBin  = (Join-Path $env:USERPROFILE '.local\bin').TrimEnd('\')
# 아고라(토론장) 자리 - 우리가 만들지 않는다(v0.3.5 부터 설치기에서 뗐다).
#   따로 참가하신 분의 자산이므로 지우지 않고 「있음 · 남깁니다」로 보이기만 한다.
#   여기 있는 것은 지우려고 두는 것이 아니라 손대지 않는다고 말하려고 두는 것이다.
# 맥판과 같은 해석이다 - AGORA_HOME 이 서 있으면 그것을 쓴다(검토 지적: 윈도우만 안 읽어 갈렸다).
$AgoraDir   = if ($env:AGORA_HOME) { $env:AGORA_HOME } else { Join-Path $env:USERPROFILE '.config\agora' }
$AgoraSkill      = Join-Path $env:USERPROFILE '.claude\skills\agora-delegate'          # 밖 - 남는다
$AgoraSkillInCys = Join-Path $env:USERPROFILE '.cys\claude\skills\agora-delegate'      # cys 계정 자리 안 - 함께 지워진다
# 보존 경로 목록 - 지우는 자리 「안에」 들어 있어도 지우지 않는다(검토 지적 채택 2026-09-09).
#   참가 자리는 사람이 AGORA_HOME 으로 옮겨 둘 수 있고, 그것이 우리가 지우는 자리 안이면
#   화면은 「남깁니다」라고 말한 뒤 상위를 통째로 지워 열쇠를 함께 날린다.
#   말이 아니라 지우는 동작이 보존을 알아야 한다. 임시 이동·복원 방식은 쓰지 않는다(도중에 멈추면 유실).
$PreservePaths = @($AgoraDir, $AgoraSkill)
$SettingsJs = Join-Path $ClaudeDir 'settings.json'
# ★로그인 파일 자리는 고정이 아니다 — 공식 문서(2026-09-08 확인 · code.claude.com/docs/en/team
#   「Credential management」): 「If you've set the CLAUDE_CONFIG_DIR environment variable, Claude Code
#   keeps the .credentials.json file under that directory instead」.
#   ⇒ 그 변수가 선 창에서 이 스크립트를 돌리면 **우리가 보는 자리와 클로드가 보는 자리가 갈린다.**
#   갈린 채로 「[있음] 로그인」이라고 적으면 그 줄이 거짓이 된다. 클로드가 보는 자리를 본다.
$ClaudeCfgDir = if ($env:CLAUDE_CONFIG_DIR) { $env:CLAUDE_CONFIG_DIR } else { $ClaudeDir }
$CredFile   = Join-Path $ClaudeCfgDir '.credentials.json'
# 자비스 창(cys)이 띄우는 클로드는 CLAUDE_CONFIG_DIR 을 ~\.cys\claude 로 두고 뜬다.
#   그 폴더는 아래에서 「cys 계정 자리」로 지워진다 — 혼자 돌리는 지우기에서는 거기 든 로그인도 같이 사라진다.
#   ★재설치 길(-KeepHistory)에서는 로그인과 이전 대화를 **남긴다**(0.3.36 · 아래 Get-HistoryKeeps).
$CysCredFile = Join-Path $CysHome 'claude\.credentials.json'
# 🔴0.3.36(09-25 윈 실기): 재설치 한 줄 뒤 본부 세 자리가 전부 「Login expired」였다.
#   앞 판은 재설치 길에서도 ~\.cys 를 통째로 지웠다 ⇒ 좌석들이 갱신해 온 **가장 새 로그인**(.credentials.json)이 사라지고,
#   설치 도우미 [8/10] 이 첫 설치 때의 **옛 로그인**(~\.claude, 이미 못 쓰게 된 것)을 대신 이어 두었다. 대화 기록(projects\)도 함께 사라졌다.
#   ⇒ 재설치 길에서는 아래 다섯 자리만 **제자리에** 남기고 나머지는 종전대로 지운다(동료가 그 자리에서 찾아야 하므로 옮기지 않는다).
#   근거 = 공식 문서 code.claude.com/docs/en/claude-directory(CLAUDE_CONFIG_DIR 을 두면 그 아래로 온다) · 설계 = docs/install-master/DESIGN-login-keep-0336.md 1절.
#   ⚠CLAUDE.md · settings.json · .claude.json · skills 는 남기지 않는다 — cys·설치 도우미가 다시 만든다(CLAUDE.md 는 「없을 때만」 만들어서, 남기면 새 판이 못 들어간다).
$HistoryKeepNames = @('.credentials.json', 'projects', 'history.jsonl', 'file-history', 'agent-memory')
# 받아 둔 설치기 사본 — 2026-09-06 부터 사용자 폴더에 받는다. 옛 자리(임시 폴더)도 함께 본다.
$HomePs1    = Join-Path $env:USERPROFILE 'install-jarvis.ps1'
$TempPs1    = Join-Path $env:TEMP 'install-jarvis.ps1'

$script:Found = 0
$script:Removed = 0
$script:KeptFail = 0
$script:Preserved = 0
$script:SkipCysDir = $false

function Short($p) { return ([string]$p).Replace($env:USERPROFILE, '~') }

# ── 다시 하시는 법 - 「같은 줄을 다시 돌려 주십시오」는 쓰지 않는다 ───────────
# 🔴2026-09-10 실기에서 **사용자 막힘으로 확정**된 문구다(쓰신 분의 말: 「같은 줄을 한 번 더 돌려
#   주십시오 - 이게 뭔지 모르겠다」). 「줄」이 무엇인지, 「돌린다」가 무슨 뜻인지 모르고,
#   무엇보다 **그 명령이 화면 어디에도 없었다.** 창이 닫힌 뒤 사이트를 다시 찾는 것 자체가 손
#   하나이고, 사이트에는 명령이 둘(지우기·재설치)이라 어느 쪽인지 사람이 고를 수도 없다.
#   ⇒ 막힌 자리에서는 ①창 여는 법 ②복사 ③붙여넣기+Enter 를 적고 **명령 전체를 인쇄한다.**
# ★어느 명령을 인쇄할지는 **들어온 길**이 정한다. 재설치가 이 스크립트를 안에서 부를 때
#   JARVIS_ENTRY=reinstall 을 넘겨 준다 - 그 길에서 지우기 한 줄을 인쇄하면 사람은 지우기만
#   되풀이하고 재설치에는 영영 못 닿는다.
# ⚠아래 두 줄은 사이트가 게시하는 명령과 **글자까지 같아야 한다**(머리글의 한 줄 · 대문 · 절차서).
#   갈리면 사람이 화면에서 복사한 명령이 사이트의 것과 달라진다 - checks.sh 가 그 동일성을 잰다.
$JarvisRerunReset = @'
powershell -NoProfile -ExecutionPolicy Bypass -Command "try { Remove-Item ([Environment]::GetFolderPath('UserProfile')+'\reset-clean.ps1') -ErrorAction SilentlyContinue; irm https://jarvis.godmeyou.kr/install/reset-clean.ps1 -OutFile ([Environment]::GetFolderPath('UserProfile')+'\reset-clean.ps1') -ErrorAction Stop; powershell -ExecutionPolicy Bypass -File ([Environment]::GetFolderPath('UserProfile')+'\reset-clean.ps1') } catch { Write-Host '설치 파일을 받지 못했습니다. 인터넷 연결을 확인하신 뒤 이 줄을 다시 붙여 넣어 주십시오.'; exit 1 }"
'@
$JarvisRerunReinstall = @'
powershell -NoProfile -ExecutionPolicy Bypass -Command "try { Remove-Item ([Environment]::GetFolderPath('UserProfile')+'\reinstall-jarvis.ps1') -ErrorAction SilentlyContinue; irm https://jarvis.godmeyou.kr/install/reinstall.ps1 -OutFile ([Environment]::GetFolderPath('UserProfile')+'\reinstall-jarvis.ps1') -ErrorAction Stop; powershell -ExecutionPolicy Bypass -File ([Environment]::GetFolderPath('UserProfile')+'\reinstall-jarvis.ps1') } catch { Write-Host '설치 파일을 받지 못했습니다. 인터넷 연결을 확인하신 뒤 이 줄을 다시 붙여 넣어 주십시오.'; exit 1 }"
'@
function Get-RerunCmd {
    if ($env:JARVIS_ENTRY -eq 'reinstall') { return $JarvisRerunReinstall }
    return $JarvisRerunReset
}
function Show-RerunHow {
    Write-Host ''
    Write-Host '  == 다시 하시는 법 (이대로 따라 하시면 됩니다) =='
    Write-Host '   1) ⊞ 윈도우 키(키보드 왼쪽 아래, Ctrl과 Alt 사이)를 누르고 powershell 이라고 치신 뒤 [Windows PowerShell] 을 여십시오.'
    Write-Host '   2) 아래 명령을 처음부터 끝까지 마우스로 끌어 선택한 뒤 Ctrl+C 를 누르십시오.'
    Write-Host '   3) 그 창을 한 번 누르고 마우스 오른쪽 단추를 눌러 붙여넣은 뒤 Enter 를 누르십시오.'
    Write-Host ''
    Write-Host (Get-RerunCmd)
    Write-Host ''
    Write-Host '  이미 지워진 것은 다시 지우지 않습니다 - 남은 자리부터 이어서 갑니다.'
}
function Row($label, $path) {
    $exists = Test-Path $path
    if ($exists) { $script:Found++ }
    $mark = if ($exists) { '있음' } else { '없음' }
    Write-Host ("  [{0}] {1} · {2}" -f $mark, $label, (Short $path))
    return $exists
}
function RowFlag($label, $exists, $note) {
    if ($exists) { $script:Found++ }
    $mark = if ($exists) { '있음' } else { '없음' }
    Write-Host ("  [{0}] {1} · {2}" -f $mark, $label, $note)
}
# 시작 메뉴 바로가기는 cys 설치기가 만든다. 공식 제거기가 지워 주는 것이라 평소에는 우리가 안 본다 —
# 그런데 제거기를 못 쓰는 자리(등록 항목이 없는 잔재)에서는 우리가 지우지 않으면 고아로 남는다.
# 자리가 판본마다 다를 수 있으므로 후보를 훑고 **있는 것만** 돌려준다(없으면 빈 목록 = 「없음」).
function Get-StartMenuLinks {
    # ⛔바로가기 **파일(.lnk)만** 후보로 넣는다. 앞 판은 확장자 없는 `cys` 도 넣었는데, 그것이 사람이
    #   다른 뜻으로 만든 폴더면 Drop 이 -Recurse -Force 로 **통째로 지운다**(검토 지적 채택
    #   2026-09-09 · 남의 것을 지울 위험은 「있으면 함께 지운다」의 편의보다 무겁다).
    # ⚠전체 사용자 공용 시작 메뉴(C:\ProgramData\...)는 **후보에 넣지 않는다** — 그 자리는 관리자
    #   영역이고, 이 스크립트는 관리자 권한을 쓰지 않는다(HKLM 을 안 건드리는 것과 같은 규율).
    # 0.3.37: 1.1.x 의 제품 이름은 cysr 다(설치 템플릿 installer.nsi:66·853~877 = $SMPROGRAMS\<제품 이름>.lnk · 폴더 안 <제품 이름>.lnk).
    #   앞 판은 cys.lnk 만 보아 1.1.x 기계에서 cysr.lnk 가 고아로 남았다. 지우는 쪽은 **대상이 우리 설치 자리일 때만** 지운다(Remove-OurShortcuts).
    $out = New-Object System.Collections.ArrayList
    $r = Join-Path $env:APPDATA 'Microsoft\Windows\Start Menu\Programs'
    if ($r) {
        foreach ($c in @((Join-Path $r 'cys.lnk'), (Join-Path $r 'cys\cys.lnk'), (Join-Path $r 'cysr.lnk'), (Join-Path $r 'cysr\cysr.lnk'))) {
            if (Test-Path $c -PathType Leaf) { [void]$out.Add($c) }
        }
    }
    return $out.ToArray()
}
# 바탕화면 바로가기(설치 템플릿이 $DESKTOP\<제품 이름>.lnk 를 만든다 · installer.nsi:870~876 · 옛 이름 cys 포함 nsis-hooks.nsh:885~893).
#   바탕화면 자리 = 이 계정의 셸 폴더 기록(User Shell Folders\Desktop · 원드라이브로 옮긴 바탕화면도 여기 적힌다) → 없으면 %USERPROFILE%\Desktop.
#   ⚠[Environment]::GetFolderPath 를 쓰지 않는다 — 윈도우 밖(시험 흉내)에서는 그 값이 흉내 밖의 진짜 바탕화면을 가리킨다.
function Get-DesktopLinks {
    $out = New-Object System.Collections.ArrayList
    $d = ''
    try {
        $o = Get-ItemProperty -LiteralPath 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\User Shell Folders' -Name 'Desktop' -ErrorAction Stop
        $d = [Environment]::ExpandEnvironmentVariables([string]$o.Desktop)
    } catch { $d = '' }
    if (-not $d) { $d = Join-Path $env:USERPROFILE 'Desktop' }
    foreach ($c in @((Join-Path $d 'cys.lnk'), (Join-Path $d 'cysr.lnk'))) {
        if (Test-Path -LiteralPath $c -PathType Leaf) { [void]$out.Add($c) }
    }
    return $out.ToArray()
}

# 경로 비교는 문자열로 한다. 끝 구분자와 대소문자를 맞춰 두지 않으면 「안에 있다」를 놓친다.
#   🔴🔴끝 구분자만 떼는 것으로는 부족하다(2차 검토 지적 채택 2026-09-09).
#   `%USERPROFILE%\.cys\.\forum` 이나 `..` 이 낀 자리, 링크로 적어 둔 자리는 글자가 달라
#   중첩 판정을 빠져나가고, 그러면 참가 열쇠가 지워진다. ⇒ **실경로로 푼 뒤** 비교한다.
function Norm-Path($p) {
    if (-not $p) { return '' }
    return ([string]$p).TrimEnd('\','/')
}
# 🔴이 자리는 **파일 경로만** 다룬다. `Drop` 은 레지스트리 항목(`HKCU:\...`)에도 쓰이는데
#   그것을 파일 경로로 풀려 하면 실패하고, fail-closed 규칙에 걸려 **멀쩡한 등록 항목을 안 지운다**
#   (2026-09-09 러너 실측 — 이 가드를 넣은 내가 낸 회귀다).
#   ★보존해야 할 참가 자리는 언제나 파일이다 ⇒ 파일 경로가 아니면 중첩 검사 자체가 뜻이 없다.
#   판별: `D:\…`(드라이브 한 글자) 또는 `\\서버\공유`. `HKCU:\…` 는 한 글자가 아니라 안 걸린다.
function Test-IsFilePath($p) {
    if (-not $p) { return $false }
    return (([string]$p) -match '^(\\\\|[A-Za-z]:[\\/])')
}
# 실경로. 못 풀면 빈 문자열을 돌려준다(그때 부르는 쪽은 지우지 않는다 = fail-closed).
#   🔴🔴앞 판은 `Resolve-Path` 가 실패해도 `GetFullPath` 가 만든 **글자만의 경로를 정상값처럼** 돌려줬다
#   (4차 지적 채택 2026-09-09). 그러면 링크가 끊긴 자리·이 계정으로 못 여는 자리가 「풀렸다」로 통과하고,
#   그 값은 `find`/`Get-ChildItem` 이 내는 실경로와 달라 **보존 목록에서 조용히 빠진다** - 상위가 통째로 지워진다.
#   ★「못 풀었다」를 성공값과 같은 모양으로 돌려주면 부르는 쪽은 그것을 영영 모른다. 실패는 실패 모양으로 돌려준다.
#   ⚠부르는 자리는 모두 **이미 있는 것이 확인된 경로**만 넘긴다(없는 자리는 부르기 전에 걸러진다).
#   🔴🔴그리고 `Resolve-Path` 는 **링크를 안 편다**(윈 러너 실측 2026-09-09 · 새로 넣은 symlink 모양 축이
#   물었다). 참가 자리를 링크로 넘기면 그 값이 그대로 돌아와 `.cys` 아래로 안 보이고,
#   **`.cys` 가 통째로 지워지며 열쇠가 사라졌다.** 맥은 `cd -P` 가 사슬을 다 펴서 멀쩡했다 — 두 OS 가
#   같은 것을 재고 있지 않았던 것이다(그래서 `plain` 한 모양만 부르던 앞 판이 이것을 못 봤다).
#   ⇒ 뿌리부터 **한 마디씩 내려가며** 링크(symlink·junction)를 편다. 5.1 에도 있는 길만 쓴다.
#     (`ResolveLinkTarget` 은 .NET 6+ 라 참가자 기계의 5.1 에는 없다.)
# 이 자리가 링크(symlink·junction)인가. 링크는 **그 자리에 있는 이름표**이지 그 안엣것이 아니다.
function Test-IsReparse($it) {
    try { return [bool]($it.Attributes -band [System.IO.FileAttributes]::ReparsePoint) } catch { return $false }
}
# 한 마디를 편다. 돌려주는 값이 **세 가지**다(5차 지적 채택 2026-09-09):
#   · 받은 값 그대로 = 「링크가 아니다」 · 다른 경로 = 「한 겹 폈다」 · `$null` = **「폈어야 하는데 못 폈다」**
#   앞 판은 셋째를 첫째와 같은 모양으로 돌려줘, 못 편 것이 「링크가 아니다」로 읽혔다.
$script:ReparseWhy = ''
function Resolve-ReparseOnce($p) {
    $script:ReparseWhy = ''
    $it = $null
    try { $it = Get-Item -LiteralPath $p -Force -ErrorAction Stop }
    catch { $script:ReparseWhy = '자리를 열지 못했다: ' + $p; return $null }
    if (-not (Test-IsReparse $it)) { return $p }
    $t = $null
    try { $t = $it.Target } catch { $t = $null }
    if ($t -is [System.Array]) { if ($t.Count -gt 0) { $t = $t[0] } else { $t = $null } }
    if (-not $t) { $script:ReparseWhy = '링크인데 가리키는 곳을 못 읽었다: ' + $p; return $null }
    $t = [string]$t
    # junction 의 대상은 `\??\` 가 붙어 오는 판본이 있다.
    if ($t.StartsWith('\??\')) { $t = $t.Substring(4) }
    elseif ($t.StartsWith('\\?\')) { $t = $t.Substring(4) }
    if (-not [System.IO.Path]::IsPathRooted($t)) {
        try { $t = [System.IO.Path]::GetFullPath((Join-Path (Split-Path -Parent $p) $t)) }
        catch { $script:ReparseWhy = '링크가 가리키는 곳을 풀지 못했다: ' + $p; return $null }
    }
    return $t.TrimEnd('\')
}
# 뿌리부터 내려가며 **처음 만나는 링크 마디**를 펴고, 그 자리에서 멈춘다.
#   돌려주는 것: @{ ok=$bool; changed=$bool; path=<경로> }
#   🔴🔴앞 판은 링크의 **대상 문자열을 그대로 결과로 삼았다**(6차 지적 채택 2026-09-09).
#   그러면 그 대상 **안에 있는 중간 링크**를 못 본다 — 예: `L1` 의 대상이 `C:\H\L2\forum` 이고
#   `L2` 가 또 링크면, 앞 판은 마지막 마디 `forum` 만 보고 「다 폈다」고 말한다.
#   그 값은 `.cys` 아래가 아니어서 **보존 중첩을 놓치고 열쇠가 지워진다.**
#   ⇒ 한 마디를 펼 때마다 **뿌리부터 다시** 훑는다(아래 `Canon-Path` 의 되풀이).
function Expand-FirstReparse($full) {
    $root = [System.IO.Path]::GetPathRoot($full)
    if (-not $root) { $script:ReparseWhy = '뿌리를 알 수 없다: ' + $full; return @{ ok = $false } }
    $cur = $root.TrimEnd('\')
    $segs = @($full.Substring($root.Length) -split '[\\/]' | Where-Object { $_ -ne '' })
    for ($i = 0; $i -lt $segs.Count; $i++) {
        $cur = $cur + '\' + $segs[$i]
        $next = Resolve-ReparseOnce $cur
        if ($null -eq $next) { return @{ ok = $false } }
        if ($next -ne $cur) {
            # 이 마디가 링크였다 — 편 자리에 **남은 마디를 이어 붙이고** 처음부터 다시 본다.
            $rest = ''
            for ($j = $i + 1; $j -lt $segs.Count; $j++) { $rest = $rest + '\' + $segs[$j] }
            return @{ ok = $true; changed = $true; path = ($next.TrimEnd('\') + $rest) }
        }
    }
    return @{ ok = $true; changed = $false; path = $cur }
}
# 실경로. 못 풀면 빈 문자열(그때 부르는 쪽은 지우지 않는다 = fail-closed).
#   ⛔**적어 두지 않는다**(6차 지적 채택). 앞 판은 답을 캐시했는데, 같은 실행 중에 링크의 대상이
#   바뀌어도 **옛 답이 그대로 적중**했다(적중 검사가 「옛 답이 아직 살아 있는가」만 봤다).
#   ★대신 **비싸지 않게** 만들었다: 열거는 링크 안으로 안 들어가므로 루트 아래 조상 마디에는 링크가
#     없다 ⇒ 항목의 실경로는 「루트 실경로 + 나머지 마디」로 곧바로 나온다(`Get-ItemCanon`).
#     그래서 이 무거운 함수는 **보존 경로·삭제 루트·링크 항목**에만 불린다.
function Canon-Path($p) {
    if (-not $p) { return '' }
    $script:ReparseWhy = ''
    $cur = ''
    try { $cur = [System.IO.Path]::GetFullPath(([string]$p)) } catch { return '' }
    if (-not (Test-Path -LiteralPath $cur)) { return '' }
    # 🔴**경계가 한 칸 어긋나 있었다**(7차 지적 채택 2026-09-09): 한 바퀴가 「한 겹을 편다」인데
    #   32바퀴만 돌면 **32겹째를 편 뒤 그것이 종단인지 확인할 바퀴가 없다** ⇒ 정확히 32겹도 실패했다.
    #   계약은 「32겹까지 된다」이므로 **펴는 32바퀴 + 종단 확인 1바퀴** = 33바퀴를 돈다.
    $maxHops = 32
    for ($hop = 0; $hop -le $maxHops; $hop++) {
        $r = Expand-FirstReparse $cur
        if (-not $r.ok) { return '' }
        if (-not $r.changed) { return (Norm-Path $r.path) }
        $cur = $r.path
    }
    $script:ReparseWhy = ('링크 사슬이 너무 깊다(' + $maxHops + '겹까지만 따라갑니다): ' + $p)
    return ''
}
function Path-IsUnder($child, $parent) {
    $c = Norm-Path $child; $r = Norm-Path $parent
    if (-not $c -or -not $r) { return $false }
    return $c.StartsWith($r + '\', [System.StringComparison]::OrdinalIgnoreCase)
}
function Path-IsSame($a, $b) {
    return ((Norm-Path $a) -ieq (Norm-Path $b))
}
# 🔴남겨야 할 자리의 실경로는 **지우기 전에 한 번에** 푼다(4차 지적 채택 2026-09-09).
#   앞 판은 `if (-not $c) { continue }` 로 **못 푼 보존 경로를 목록에서 조용히 뺐다** - 지켜야 할 자리가
#   목록에 없는 채로 상위가 통째로 지워진다. 「그 자리가 없다」와 「그 자리를 못 풀었다」는 다른 답이다.
#   ⇒ **있는데 못 푼 경로가 하나라도 있으면 그 실행은 파일을 지우지 않는다**(fail-closed).
#   ⚠막는 범위를 넓히지 않는다: **없는 경로는 그냥 건너뛴다**(지킬 것이 없다는 뜻이므로 안전하다).
#     레지스트리 항목도 막지 않는다 - 보존 대상은 언제나 파일이라 겹칠 수가 없다(r4 회귀의 교훈).
$script:PreserveCanon = @()
$script:PreserveCanonFail = @()
#   🔴사유는 **경로별로** 담는다(7차 지적 채택 2026-09-09). 앞 판은 실패 목록에 경로만 넣었고,
#   까닭은 전역 `ReparseWhy` 에만 있어 **다음 경로를 풀 때 덮였다** ⇒ 사람이 보는 화면에 안 나왔다.
#   ★사유를 「지금 막 실패한 것 하나」에만 담아 두면, 실패가 둘이 되는 순간 첫째의 까닭이 사라진다.
function Initialize-PreserveCanon {
    $script:PreserveCanon = @()
    $script:PreserveCanonFail = @()
    foreach ($p in $PreservePaths) {
        if (-not $p) { continue }
        if (-not (Test-Path -LiteralPath $p)) { continue }
        $script:ReparseWhy = ''
        $c = Canon-Path $p
        if ($c) { $script:PreserveCanon += $c }
        else {
            $why = $script:ReparseWhy
            if (-not $why) { $why = '실제 경로를 확인하지 못했습니다' }
            $script:PreserveCanonFail += @{ path = $p; why = $why }
        }
    }
}
# 재설치 길에서 ~\.cys\claude 안에 남길 자리의 실경로(0.3.36 · $HistoryKeepNames 머리 주석).
#   돌려주는 것 = @{ Canon = 실경로 목록; Fail = 있는데 실경로를 못 푼 자리 목록 }.
#   ★「없다」와 「못 풀었다」를 가른다(Initialize-PreserveCanon 과 같은 규율) — 없는 것은 건너뛰고,
#     있는데 못 푼 것이 하나라도 있으면 부르는 쪽이 ~\.cys 를 **하나도 지우지 않는다**.
#   ⚠「있다」는 그 폴더의 **목록**으로 본다 — 지우는 쪽(Get-TreeItems)이 보는 것과 같은 눈이다.
#     Test-Path 는 끊어진 링크를 「없다」로 답하고, Get-Item 은 읽기 실패도 「없다」와 같은 모양(예외)으로 낸다
#     (시험 실측 2026-09-25: 바깥을 가리키는 링크를 Get-Item 이 못 읽어 「없다」로 넘어가고 그대로 지워졌다).
#     ⇒ 목록을 못 읽으면 남길 것을 모르는 것이므로 **실패**로 돌려준다.
function Get-HistoryKeeps {
    $canon = @(); $fail = @()
    $prof = Join-Path $CysHome 'claude'
    if (-not (Test-Path -LiteralPath $prof)) { return @{ Canon = $canon; Fail = $fail } }
    $kids = @()
    try { $kids = @(Get-ChildItem -LiteralPath $prof -Force -ErrorAction Stop) }
    catch { return @{ Canon = $canon; Fail = @($prof) } }
    # ★남길 것은 **두 모양**으로 적는다(시험 실측 2026-09-25): ①그 자리 자체(부모 실경로 + 이름) ②그것이 가리키는 곳(실경로).
    #   바로가기(projects → D:\data 등)는 실경로가 ~\.cys 밖이라 ②만 적으면 「이 안에 든 것」에서 빠지고, 지우는 쪽은
    #   그 바로가기와 그것을 담은 폴더를 지운다(가리키던 자료는 남지만 동료가 찾는 자리가 사라진다). ①이 있어야 자리와 그 조상이 남는다.
    $profCanon = Canon-Path $prof
    $homeCanon = Canon-Path $CysHome
    if ((-not $profCanon) -or (-not $homeCanon)) { return @{ Canon = @(); Fail = @($prof) } }
    # 🔴교차 검토 1회차(09-25) 반영: ~\.cys 나 ~\.cys\claude 자체가 바로가기면 **못 풂**이다 — 지우는 쪽은 바로가기 이름표만 지우거나
    #   (새 ~\.cys 에선 옛 로그인이 안 보인다) 그 안의 옛 CLAUDE.md 까지 통째로 남긴다(새 라우터가 못 들어간다). 어느 쪽도 「이어진다」가 아니다.
    foreach ($lp in @($CysHome, $prof)) {
        $li = $null
        try { $li = Get-Item -LiteralPath $lp -Force -ErrorAction Stop } catch { $li = $null }
        if ((-not $li) -or (Test-IsReparse $li)) { return @{ Canon = @(); Fail = @($lp) } }
    }
    # 바로가기가 가리키는 곳이 이 지우개가 지우는 다른 자리 안·그 조상이면 못 풂(그 자리를 지울 때 함께 사라진다 · 교차 검토).
    $dropRoots = @($homeCanon)
    foreach ($r in @($CysDir, $CysDirOld, $ClaudeBin, $JarvisDir)) { if ($r -and (Test-Path -LiteralPath $r)) { $rc = Canon-Path $r; if ($rc) { $dropRoots += $rc } } }
    foreach ($kid in @($kids | Where-Object { $n = $_.Name; @($HistoryKeepNames | Where-Object { $_ -ieq $n }).Count -gt 0 })) {
        $p = Join-Path $prof $kid.Name
        $script:ReparseWhy = ''
        $c = Canon-Path $p
        if (-not $c) { $fail += $p; continue }
        $at = Norm-Path ($profCanon + '\' + $kid.Name)
        # 🔴검토 1회차(09-25) 반례: 바로가기가 ~\.cys 자신·그 조상·그 안의 다른 자리(pack 등)를 가리키면 그곳 전체가 「남길 곳」이 되어
        #   아무것도 안 지우고도 「지움」 · rc 0 으로 끝났다(재설치가 병합 대기 위로 이어짐). ⇒ 그런 바로가기는 **못 풂**으로 센다(삭제 0 · 멈춤).
        if (-not (Path-IsSame $c $at)) {
            $clash = $false
            foreach ($dr in $dropRoots) { if ((Path-IsSame $c $dr) -or (Path-IsUnder $dr $c) -or (Path-IsUnder $c $dr)) { $clash = $true } }
            if ($clash) { $fail += $p; continue }
        }
        $canon += $at
        if (-not (Path-IsSame $c $at)) { $canon += $c }
    }
    return @{ Canon = $canon; Fail = $fail }
}
# 이 자리 안에 있는 보존 경로들(실경로로 · 없으면 빈 배열).
function Get-PreservedUnder($root) {
    $out = @()
    foreach ($c in $script:PreserveCanon) {
        if (Path-IsUnder $c $root) { $out += $c }
    }
    return $out
}
# 이 자리 자신이 보존 대상이거나 보존 경로의 아래인가.
function Test-PreserveCovers($target) {
    foreach ($c in $script:PreserveCanon) {
        if ((Path-IsSame $target $c) -or (Path-IsUnder $target $c)) { return $true }
    }
    return $false
}
# 보존 경로와 그 조상만 남기고 그 자리를 비운다. 깊은 것부터 지운다.
#   🔴**못 지운 것을 세어 돌려준다**(2차 검토 지적 채택): 앞 판은 개별 실패를 통째로 삼키고도
#   「지움」이라 말했다. 지우는 도구가 「거의 다 지웠다」를 성공으로 보고하면 그것이 곧 거짓 상태 보고다.
# 항목의 실경로를 **싸게** 낸다(6차 지적 채택 2026-09-09).
#   열거가 링크 안으로 들어가지 않으므로 **루트 아래 조상 마디에는 링크가 없다** — 그 사실을 쓴다.
#   ⇒ 항목의 실경로 = 「루트 실경로 + 나머지 마디」. 항목 **자신이** 링크일 때만 따로 푼다.
#   ★이래서 캐시가 필요 없다. 캐시를 없앴더니 낡은 답을 재사용하던 자리(TOCTOU)도 함께 사라졌다.
function Get-ItemCanon($it, $rootLiteral, $rootCanon) {
    if (Test-IsReparse $it) { return (Canon-Path $it.FullName) }
    $full = Norm-Path $it.FullName
    $rl = Norm-Path $rootLiteral
    if (-not $full.StartsWith($rl + '\', [System.StringComparison]::OrdinalIgnoreCase)) {
        return (Canon-Path $it.FullName)   # 예상 밖의 모양이면 정직하게 비싼 길로
    }
    return (Norm-Path ($rootCanon + $full.Substring($rl.Length)))
}
# 항목의 **자리** 실경로(그 자신이 바로가기여도 풀지 않는다 · 0.3.36 · 교차 검토 반영).
#   남길 폴더(projects 등) **안에 든 바로가기**는 Get-ItemCanon 이 가리키는 곳으로 풀어 비교하므로 남길 목록에 안 맞아 지워졌다.
#   ⇒ 자리로도 한 번 더 본다 — 자리가 남길 곳 안이면 남긴다(더 남기는 쪽이라 참가 자리 판정에도 안전하다). 모양이 어긋나면 빈 값.
#   ⚠바로가기 항목에만 값을 낸다(바로가기가 아니면 Get-ItemCanon 이 곧 자리다) · 부모 실경로 + 이름으로 낸다(글자 앞머리 비교는 모양이 어긋나면 빗나간다).
function Get-ItemLoc($it, $rootLiteral, $rootCanon) {
    if (-not (Test-IsReparse $it)) { return '' }
    $pc = Canon-Path (Split-Path -Parent $it.FullName)
    if (-not $pc) { return '' }
    return (Norm-Path ($pc + '\' + $it.Name))
}
# 이 실경로를 남겨야 하는가 — 🔴**보존 목록과 맞아떨어질 때만** 참이다(5차 지적 채택).
#   못 푼 것(빈 문자열)은 참이 아니다 — 「모르겠다」를 「남겨야 한다」로 번역하면 다음 줄에서 「없다」가 된다.
#   ⚠이 판정은 마지막 방어선이 아니다: 삭제는 `-Recurse` 를 아예 쓰지 않아 폴더는 **비어 있을 때만**
#     지워진다 ⇒ 남길 자리가 든 폴더는 판정과 무관하게 안 지워진다.
function Test-KeepHit($canon, $keeps) {
    if (-not $canon) { return $false }
    foreach ($k in $keeps) {
        if ((Path-IsSame $canon $k) -or (Path-IsUnder $canon $k) -or (Path-IsUnder $k $canon)) { return $true }
    }
    return $false
}
# 🔴🔴**우리 손으로 훑는다 — `Get-ChildItem -Recurse` 는 5.1 에서 링크 안으로 들어간다.**
#   그러면 `~\.cys` 안에 바깥을 가리키는 junction 이 하나 있을 때 그 **바깥 폴더의 파일이 목록에 올라
#   하나씩 지워진다.** 우리가 지우기로 한 것은 `.cys` 뿐인데 남의 자리를 지우는 것이다.
#   ⇒ 자식은 한 겹씩만 묻고, **링크면 그 안으로 들어가지 않는다.**
#   ★내는 순서는 **깊이 우선·후위**다 — 자식이 먼저, 부모가 나중. 그래야 부모를 지울 때가 되면 비어 있다.
#   ★맥은 이 위험이 없다(실측 2026-09-09: 폴더를 가리키는 심볼릭 링크에 `rm -rf` 를 하면
#     **링크만 사라지고 대상 폴더·파일은 그대로다**). 윈도우를 그 뜻에 맞춘다.
$script:EnumFail = 0
function Add-TreeItems($dir, $out, $depth) {
    if ($depth -gt 64) { $script:EnumFail++; return }
    $kids = @()
    try { $kids = @(Get-ChildItem -LiteralPath $dir -Force -ErrorAction Stop) }
    catch { $script:EnumFail++; return }
    foreach ($k in $kids) {
        if ($k.PSIsContainer -and -not (Test-IsReparse $k)) { Add-TreeItems $k.FullName $out ($depth + 1) }
        [void]$out.Add($k)
    }
}
function Get-TreeItems($root) {
    $script:EnumFail = 0
    $out = New-Object System.Collections.ArrayList
    Add-TreeItems $root $out 0
    return $out.ToArray()
}
# 한 자리를 지운다. 🔴🔴**`-Recurse` 를 쓰지 않는다**(5차 BLOCK 채택 2026-09-09).
#   앞 판은 링크를 **열거**에서만 막고, 삭제는 일반 폴더마다 `Remove-Item -Recurse` 를 다시 불렀다.
#   ⇒ 어떤 폴더의 열거가 실패하면(권한·경쟁) 그 폴더는 목록에 남고, **삭제 단계의 두 번째 재귀가
#     그 안으로 들어간다.** 열거층에서 막은 것을 삭제층이 무효로 만든 것이다.
#   ⚠그 재귀가 **링크까지 뚫는지는 판본에 따라 다르다**(2026-09-09 러너 실측: 그 러너에서는 안 뚫었다).
#     결함의 본체는 그것이 아니라 **열거하지 못한 자리를 지운다**는 것이다 - 그쪽은 판본과 무관하다.
#   ★한 층만 막는 것은 안 막은 것과 같다 — 지나가는 길이 둘이면 둘 다 막아야 한다.
#   ⇒ 폴더는 **비어 있을 때만** 지워진다(비재귀). 안 비었으면 안 지우고 실패로 센다 = 그 자체가 검산이다.
#   ⇒ 링크는 이름표만 사라진다(대상 무접촉). **끊어진 링크도 여기로 온다** — 가리키는 곳이 없어도
#     그 자리에 이름표는 있으므로 지워야 한다(앞 판은 `Test-Path` 가 거짓이라 건너뛰고 [남음]을 냈다).
function Remove-OneItem($it) {
    $p = $it.FullName
    # 읽기 전용 표시가 있으면 떼고 지운다(예전 `-Force` 가 하던 일).
    try {
        if ($it.Attributes -band [System.IO.FileAttributes]::ReadOnly) {
            $it.Attributes = ($it.Attributes -band (-bnot [System.IO.FileAttributes]::ReadOnly))
        }
    } catch { }
    if ($it.PSIsContainer) {
        if (-not (Test-IsReparse $it) -and -not [System.IO.Directory]::Exists($p)) { return }  # 이미 없다
        [System.IO.Directory]::Delete($p, $false)
        return
    }
    [System.IO.File]::Delete($p)   # 없는 파일에는 아무 일도 일어나지 않는다
}
# 한 자리를 통째로 지운다 — 링크는 뚫지 않는다. 못 지운 수를 돌려준다.
# 🔴2026-09-10 실기에서 고친 것(R2) — 앞 판은 항목별 예외를 `catch { }` 로 **전부 삼키고** 개수만 셌다.
#   그래서 화면에 남는 것이 「1가지를 지우지 못했습니다」 한 줄뿐이었고, **사용자는 무엇이 남았는지
#   알 길이 없었다.** 그 한 줄로는 우리도 원인을 못 찾는다(실제로 못 찾아 실기 중에 손으로 뒤졌다).
#   ⇒ 실패한 자리와 까닭을 **최대 5개** 담아 두고, 부르는 쪽(Drop)이 인쇄한다.
#   ⚠세는 값(fails)의 뜻은 바꾸지 않는다 - 검산은 여전히 「뿌리가 비었는가」다. 담는 것만 늘린다.
$script:TreeFailWhy = @()
function Add-TreeFailWhy($path, $why) {
    if ($script:TreeFailWhy.Count -ge 5) { return }
    $script:TreeFailWhy += ((Short $path) + '  ← ' + $why)
}
function Remove-TreeSafe($path) {
    $script:TreeFailWhy = @()
    $it = $null
    try { $it = Get-Item -LiteralPath $path -Force -ErrorAction Stop } catch { Add-TreeFailWhy $path $_.Exception.Message; return 1 }
    if ((-not $it.PSIsContainer) -or (Test-IsReparse $it)) {
        try { Remove-OneItem $it; return 0 } catch { Add-TreeFailWhy $path $_.Exception.Message; return 1 }
    }
    $fails = 0
    $items = @(Get-TreeItems $it.FullName)
    if ($script:EnumFail -gt 0) { $fails++; Add-TreeFailWhy $it.FullName ('안을 끝까지 읽지 못했습니다(못 연 자리 ' + $script:EnumFail + '곳)') }
    foreach ($x in $items) {
        try { Remove-OneItem $x } catch { Add-TreeFailWhy $x.FullName $_.Exception.Message }
    }
    # 검산 — 뿌리는 비어 있을 때만 지워진다. 안 지워지면 무엇인가 남은 것이다.
    try { [System.IO.Directory]::Delete($it.FullName, $false) } catch { $fails++; Add-TreeFailWhy $it.FullName $_.Exception.Message }
    return $fails
}
# 담아 둔 실패 사유를 인쇄한다. 없으면 아무 말도 하지 않는다(빈 제목만 찍지 않는다).
function Write-TreeFailWhy {
    if ($script:TreeFailWhy.Count -eq 0) { return }
    Write-Host '         지우지 못한 자리:'
    foreach ($w in $script:TreeFailWhy) { Write-Host ('           ' + $w) }
}
# 0.3.37(DESIGN-0337 6-1절 ⑤): 남길 목록을 **둘로 가른다** —
#   ⑴참가 자리($keeps) = 가리키는 곳(실경로)과 바로가기 **자리** 둘 다로 비교(0.3.36 그대로 · 모든 길 · 더 남기는 쪽)
#   ⑵재설치 남길 것($hkeeps · 로그인·대화 · 부서 기록) = 바로가기는 **자리로만**(가리키는 곳으로 보지 않는다) — 앞 판은 가리키는 곳으로도 봐서
#     `pack` 이 `projects` 안을 가리키는 바로가기면 pack 이름표가 남았다(반례 ⑤ · 옛 팩 → 병합 대기).
function Test-KeepHitSplit($it, $rootLiteral, $rootCanon, $keeps, $hkeeps) {
    $c = Get-ItemCanon $it $rootLiteral $rootCanon
    if (Test-IsReparse $it) {
        $loc = Get-ItemLoc $it $rootLiteral $rootCanon
        if (Test-KeepHit $c $keeps) { return $true }
        if ($loc -and (Test-KeepHit $loc $keeps)) { return $true }
        if ($loc -and (@($hkeeps).Count -gt 0) -and (Test-KeepHit $loc $hkeeps)) { return $true }
        return $false
    }
    if (Test-KeepHit $c $keeps) { return $true }
    if ((@($hkeeps).Count -gt 0) -and (Test-KeepHit $c $hkeeps)) { return $true }
    return $false
}
function Remove-ExceptPreserved($rootLiteral, $rootCanon, $keeps, $hkeeps = @()) {
    $script:TreeFailWhy = @()
    $enumFail = 0
    $items = @(Get-TreeItems $rootLiteral)
    if ($script:EnumFail -gt 0) {
        $enumFail = 1
        Write-Host ('         (이 자리의 목록을 끝까지 읽지 못했습니다 - 못 연 자리 ' + $script:EnumFail + '곳.)')
    }
    foreach ($it in $items) {
        if (Test-KeepHitSplit $it $rootLiteral $rootCanon $keeps $hkeeps) { continue }
        try { Remove-OneItem $it } catch { }
    }
    # 검산 - 남은 것을 **다시 열거해서** 센다. 지우기 실패든 열거 실패든 결과 한 칸으로 모인다.
    #   ★남은 자리도 **적어 둔다**(R2) - 개수만으로는 사용자도 우리도 다음 손을 못 정한다.
    $left = 0
    $rest = @(Get-TreeItems $rootLiteral)
    if ($script:EnumFail -gt 0) { $enumFail = 1 }
    foreach ($it in $rest) {
        if (Test-KeepHitSplit $it $rootLiteral $rootCanon $keeps $hkeeps) { continue }
        $left++
        Add-TreeFailWhy $it.FullName '아직 남아 있습니다(다른 프로그램이 붙들고 있을 수 있습니다)'
    }
    return ($left + $enumFail)
}

# 두 자리의 파일 목록과 내용이 같은가. 「폴더가 생겼다」로는 옮겼다고 말할 수 없다.
# 🔴**`Get-FileHash` 에 기대지 않는다**(러너 실측 2026-09-09 · 이 저장소가 이미 아는 함정).
#   사용자 폴더를 갈아 끼운 5.1 환경에서 그 명령을 **못 찾는 일이 있다**(모듈 자동 적재가 어긋난다).
#   참가자 기계에서도 같은 일이 날 수 있고, 그때 「대조 실패」로 읽혀 제거기가 멈춘다.
#   ⇒ .NET 으로 직접 센다. 어느 판본·어느 환경에서도 있는 길이다.
function Get-Sha256File($path) {
    $fs = $null; $sha = $null
    try {
        $sha = [System.Security.Cryptography.SHA256]::Create()
        $fs = [System.IO.File]::Open($path, [System.IO.FileMode]::Open, [System.IO.FileAccess]::Read, [System.IO.FileShare]::ReadWrite)
        return [System.BitConverter]::ToString($sha.ComputeHash($fs)).Replace('-', '')
    } finally {
        if ($fs) { $fs.Dispose() }
        if ($sha) { $sha.Dispose() }
    }
}

$script:TreeSameWhy = ''
function Test-TreeSame($a, $b) {
    $script:TreeSameWhy = ''
    if (-not (Test-Path -LiteralPath $a)) { $script:TreeSameWhy = "원본이 없다: $a"; return $false }
    if (-not (Test-Path -LiteralPath $b)) { $script:TreeSameWhy = "옮긴 자리가 없다: $b"; return $false }
    try {
        $ra = (Resolve-Path -LiteralPath $a).ProviderPath.TrimEnd('\')
        $rb = (Resolve-Path -LiteralPath $b).ProviderPath.TrimEnd('\')
        $fa = @(Get-ChildItem -LiteralPath $ra -Recurse -File -Force -ErrorAction Stop |
                ForEach-Object { $_.FullName.Substring($ra.Length) } | Sort-Object)
        $fb = @(Get-ChildItem -LiteralPath $rb -Recurse -File -Force -ErrorAction Stop |
                ForEach-Object { $_.FullName.Substring($rb.Length) } | Sort-Object)
        if ($fa.Count -ne $fb.Count) {
            $script:TreeSameWhy = ("파일 수가 다르다: 원본 {0} · 옮긴 것 {1} (원본=[{2}] 옮긴것=[{3}])" -f $fa.Count, $fb.Count, ($fa -join ','), ($fb -join ','))
            return $false
        }
        for ($i = 0; $i -lt $fa.Count; $i++) {
            if ($fa[$i] -ne $fb[$i]) { $script:TreeSameWhy = ("이름이 다르다: {0} vs {1}" -f $fa[$i], $fb[$i]); return $false }
        }
        foreach ($rel in $fa) {
            $ha = Get-Sha256File ($ra + $rel)
            $hb = Get-Sha256File ($rb + $rel)
            if ($ha -ne $hb) { $script:TreeSameWhy = ("내용이 다르다: " + $rel); return $false }
        }
        return $true
    } catch {
        $script:TreeSameWhy = ("대조 중 오류: " + $_.Exception.Message)
        return $false
    }
}

# 이 자리가 레지스트리 키인가 — 🔴**모양이 아니라 provider 로 판정한다**(6차 지적 채택 2026-09-09).
#   앞 판은 「파일 경로처럼 안 생겼으면 레지스트리」라는 **소거법**이었다. 그러면 새 호출부가
#   엉뚱한 모양을 넘길 때 그것이 조용히 재귀 삭제 갈래로 흘러든다.
#   ⚠받아들이는 뿌리는 **`HKCU:` 하나뿐**이다. 이 도구는 이 계정 것만 지운다 —
#     기계 전체(시스템 영역) 뿌리는 아예 이 갈래로 들어오지 못하게 하고, 들어오면 지우지 않는다.
#     (검사 축이 이 파일에 그 낱말이 있는 것 자체를 막는다 — 그 축이 옳다.)
function Test-IsRegistryPath($p) {
    if (-not $p) { return $false }
    if (([string]$p) -notmatch '^HKCU:\\') { return $false }
    try {
        $it = Get-Item -LiteralPath $p -ErrorAction Stop
        return ($it.PSProvider.Name -eq 'Registry')
    } catch { }
    return $true   # 접두는 맞는데 못 열었다 - 레지스트리로 다룬다(Drop 이 Test-Path 로 이미 걸렀다)
}
# $histKeeps (0.3.36) = 이번에만 더 남길 실경로 목록(재설치 길의 로그인·이전 대화 · Get-HistoryKeeps). 없으면 종전과 같다.
function Drop($label, $path, $histKeeps = @()) {
    if (-not (Test-Path $path)) { return }
    # 레지스트리 키 — 하위 키를 함께 지우려면 `-Recurse` 가 필요하다. 레지스트리엔 링크가 없어
    #   파일 쪽의 「두 번째 재귀」 위험이 없다. 이 파일에서 `-Recurse` 를 쓰는 유일한 자리다.
    if (Test-IsRegistryPath $path) {
        try { Remove-Item $path -Recurse -Force -ErrorAction Stop; $script:Removed++; Write-Host ("  지움: " + (Short $path)) }
        catch { $script:KeptFail++; Write-Host ("  [남음] " + (Short $path) + " — " + $_.Exception.Message) }
        return
    }
    # ★파일도 레지스트리도 아닌 모양이 들어왔다 = 부르는 쪽이 틀렸다. **지우지 않는다.**
    if (-not (Test-IsFilePath $path)) {
        $script:KeptFail++
        Write-Host ("  [남음] " + (Short $path) + " - 다룰 수 있는 자리 모양이 아닙니다(지우지 않았습니다).")
        return
    }
    # ★남겨야 할 자리 가운데 **있는데 실경로를 못 푼 것**이 있으면 파일은 하나도 지우지 않는다.
    #   (까닭은 Initialize-PreserveCanon 참조. 사람이 볼 설명은 Invoke-Purge 가 한 번만 인쇄한다.)
    if ($script:PreserveCanonFail.Count -gt 0) {
        $script:KeptFail++
        Write-Host ("  [남음] " + (Short $path) + " - 남겨야 할 자리를 확인하지 못해 지우지 않았습니다.")
        return
    }
    # 🔴🔴**삭제 루트가 링크면 이름표만 지운다 — 그 안으로 들어가지 않는다**(6차 BLOCK 채택 2026-09-09).
    #   앞 판은 실경로를 먼저 구해 그 **대상**을 삭제 함수에 넘겼다. 그래서 `~\.cys` 가 `D:\shared` 를
    #   가리키는 링크이고 참가 자리가 그 안에 있으면, **남의 폴더 `D:\shared` 를 열어 그 안을 지웠다.**
    #   ★링크를 따라간 것은 삭제 API 가 아니라 **그 앞의 「실경로 → 삭제 인자」 변환**이었다.
    #     비재귀로 바꾼 것만으로는 안 닫힌다 — 원칙을 고정한다:
    #     ①삭제 루트는 **원문 경로 그대로** 다룬다 ②실경로는 **보존 경로 비교에만** 쓴다.
    #     ⚠keep 이 있든 없든 마찬가지다 — 「그 안에 남길 것이 있으니 들어가도 된다」가 바로 그 함정이다.
    $rootItem = $null
    try { $rootItem = Get-Item -LiteralPath $path -Force -ErrorAction Stop } catch { $rootItem = $null }
    if ($rootItem -and (Test-IsReparse $rootItem)) {
        try {
            Remove-OneItem $rootItem
            $script:Removed++
            Write-Host ("  지움: " + (Short $path) + " (가리키기만 지웠습니다 - 가리키던 자리는 그대로입니다)")
        } catch {
            $script:KeptFail++
            Write-Host ("  [남음] " + (Short $path) + " — " + $_.Exception.Message)
        }
        return
    }
    $t = Canon-Path $path      # ★비교에만 쓴다. 삭제 인자로는 절대 넘기지 않는다.
    if (-not $t) {
        $script:KeptFail++
        Write-Host ("  [남음] " + (Short $path) + " - 이 자리의 실제 경로를 확인하지 못해 지우지 않았습니다.")
        Write-Host '         (확인할 수 없는 자리를 지우면 엉뚱한 것을 지울 수 있습니다.)'
        if ($script:ReparseWhy) { Write-Host ('         까닭: ' + $script:ReparseWhy) }
        return
    }
    if (Test-PreserveCovers $t) {
        $script:Preserved++
        Write-Host ("  보존(중첩): " + (Short $path) + " - 참가 자리와 겹쳐 지우지 않습니다.")
        return
    }
    $keeps = @(Get-PreservedUnder $t)
    # 0.3.36: 재설치 길에서 남길 로그인·이전 대화(참가 자리와 말을 갈라 적는다).
    #   ⚠「이 안에 든 것」으로 거르지 않는다 — 바로가기가 가리키는 곳(②)은 밖에 있어도 비교에 있어야 그 바로가기가 남는다(Get-HistoryKeeps).
    #     화면에는 이 자리 안의 것만 적는다.
    $hist = @($histKeeps | Where-Object { $_ })
    $histShow = @($hist | Where-Object { Path-IsUnder $_ $t })
    if (($keeps.Count -gt 0) -or ($hist.Count -gt 0)) {
        if ($keeps.Count -gt 0) {
            $script:Preserved++
            Write-Host ("  보존(중첩): " + (Short $path) + " 안에 참가 자리가 있어 그것만 남기고 지웁니다.")
            foreach ($k in $keeps) { Write-Host ("           남기는 자리: " + (Short $k)) }
        }
        if ($hist.Count -gt 0) {
            Write-Host ("  남김: " + (Short $path) + " 안의 자비스 창 로그인·이전 대화·부서 기록 (다시 까는 길이라 그것만 남기고 지웁니다)")
            foreach ($k in $histShow) { Write-Host ("           남기는 자리: " + (Short $k)) }
        }
        $what = if ($hist.Count -eq 0) { '참가 자리' } elseif ($keeps.Count -eq 0) { '로그인·이전 대화' } else { '참가 자리와 로그인·이전 대화' }
        # ★원문 경로로 열거하고, 실경로는 비교에만 · 참가 자리와 재설치 남길 것은 갈라 넘긴다(0.3.37 · Test-KeepHitSplit)
        $fails = Remove-ExceptPreserved $path $t @($keeps) @($hist)
        if ($fails -gt 0) {
            $script:KeptFail++
            Write-Host ("  [일부 남음] " + (Short $path) + " - {0}가지를 지우지 못했습니다({1}는 그대로입니다)." -f $fails, $what)
            Write-TreeFailWhy
            return
        }
        $script:Removed++
        Write-Host ("  지움: " + (Short $path) + " (" + $what + "는 그대로)")
        return
    }
    $fails = Remove-TreeSafe $path
    if ($fails -eq 0) { $script:Removed++; Write-Host ("  지움: " + (Short $path)) }
    else { $script:KeptFail++; Write-Host ("  [남음] " + (Short $path) + " - " + $fails + "가지를 지우지 못했습니다."); Write-TreeFailWhy }
}

# ── 자리 기준으로 끈다 - 이름으로 끄면 우리가 아는 이름만 꺼진다 (R1 · 2026-09-10) ─────
# 🔴실기에서 `%LOCALAPPDATA%\cys` 삭제가 실패했다. 붙들고 있던 것은 cys-app·cysd·cys 가 아니라
#   cysd 가 띄운 **python3.exe**(office-bridge)였고, **cysd 가 사라진 뒤에도 고아로 살아남아**
#   런타임 dll 을 붙들었다. 앞 판은 이름 셋만 Stop-Process 했으니 이 프로세스를 볼 수 없었다.
#   ★자국은 이름이 아니라 **자리**다 - 그 폴더 안의 실행 파일로 도는 것은 전부 우리가 놓은 것이다.
#   ⇒ 이름 축은 그대로 두고(권한 때문에 Path 를 못 읽는 우리 프로세스가 있다) **자리 축을 더한다.**
#     두 축은 서로를 대체하지 않는다.
function Get-ProcsUnder($dirs) {
    $out = @()
    foreach ($pr in @(Get-Process -ErrorAction SilentlyContinue)) {
        if ($pr.Id -eq $PID) { continue }   # 우리 자신은 세지 않는다
        $path = $null
        try { $path = $pr.Path } catch { $path = $null }   # 남의(또는 상승된) 프로세스는 못 읽는다
        if (-not $path) { continue }
        foreach ($d in $dirs) {
            if (-not $d) { continue }
            $pre = ([string]$d).TrimEnd('\') + '\'
            if ($path.StartsWith($pre, [System.StringComparison]::OrdinalIgnoreCase)) { $out += $pr; break }
        }
    }
    return $out
}
# 끄고 2초 기다린 뒤 **다시 세어** 남은 것을 돌려준다. 「Stop-Process 를 불렀다」는 꺼졌다는 뜻이 아니다.
function Stop-CysProcesses {
    foreach ($n in @('cys-app', 'cysd', 'cys')) {
        Get-Process -Name $n -ErrorAction SilentlyContinue | Stop-Process -Force -ErrorAction SilentlyContinue
    }
    foreach ($pr in @(Get-ProcsUnder @($CysDir, $CysDirOld))) {
        try { Stop-Process -Id $pr.Id -Force -ErrorAction Stop } catch { }
    }
    Start-Sleep -Seconds 2
    return @(Get-ProcsUnder @($CysDir, $CysDirOld))
}
# 남은 프로세스를 **사람이 작업 관리자에서 찾을 수 있는 만큼** 적는다.
#   앞 판은 「아직 실행 중입니다」로 끝냈다 - 무엇을 끝내야 하는지 알 길이 없었다(실기 실측).
function Write-AliveProcs($alive) {
    $n = 0
    foreach ($pr in @($alive)) {
        $n++
        if ($n -gt 5) { Write-Host ('         (그 밖에 ' + ($alive.Count - 5) + '개 더 있습니다.)'); break }
        $path = ''
        try { $path = [string]$pr.Path } catch { $path = '' }
        Write-Host ('         돌고 있는 것: ' + $pr.ProcessName + '  (번호 ' + $pr.Id + ')  ' + (Short $path))
    }
    Write-Host '         작업 관리자(Ctrl+Shift+Esc)에서 위 번호의 항목을 끝내시거나, 컴퓨터를 다시 켜 주십시오.'
}
# 🔴2026-09-14 워크숍 사진 — 「지우고 다시 깔기」에서 ~\.local\bin\claude.exe 가 Access denied 로 3번 다 안 지워졌고
#   「지우다가 멈췄습니다 — 그래서 다시 설치하지 않았습니다」로 끝났다. 붙들고 있던 것은 직전 설치 창에서 남은 claude 였다.
#   ⇒ 그 파일을 지우기 **직전에만** 그 자리에서 도는 것을 끈다(자리 = 우리가 [2/10] 에서 놓은 파일 · cys 를 자리 기준으로 끄는 것과 같은 원칙).
#   ⚠이 도구(지우기·재설치)에서만 한다 — 첫 설치에서 끄면 다른 창의 클로드 대화가 끊긴다.
#   ⚠cys 를 끄는 함수(Stop-CysProcesses)에 섞지 않는다 — 그 결과가 「cys 폴더를 지워도 되는가」 판정에 쓰인다.
function Stop-ClaudeUnderBin {
    $procs = @(Get-ProcsUnder @($ClaudeBin))
    foreach ($pr in $procs) {
        Write-Host ('  ' + $pr.ProcessName + '.exe(번호 ' + $pr.Id + ')가 돌고 있습니다 — 끄고 지웁니다.')
        try { Stop-Process -Id $pr.Id -Force -ErrorAction Stop } catch { }
    }
    if ($procs.Count -gt 0) { Start-Sleep -Seconds 2 }
    return @(Get-ProcsUnder @($ClaudeBin))
}
function Get-ClaudeCmd {
    if (Test-Path $ClaudeExe) { return $ClaudeExe }
    $c = Get-Command claude -ErrorAction SilentlyContinue
    if ($c) { return $c.Source }
    return $null
}
function Get-CysCmd {
    foreach ($c in @((Join-Path $CysDir 'cys.exe'), (Join-Path $CysDirOld 'cys.exe'))) {
        if (Test-Path $c) { return $c }
    }
    $g = Get-Command cys -ErrorAction SilentlyContinue
    if ($g) { return $g.Source }
    return $null
}
# 🔴🔴교차 검토 [3] BLOCK 채택(2026-09-08): 앞 판은 `-TaskName '*cys*'` 로 잡히는 것을 **전부 지웠다.**
#   `macys-backup`·`cys-project` 처럼 이름이 스치기만 하는 **남의 작업이 함께 영구 삭제된다.**
#   ★이름이 스친다고 우리 것이 아니다. 우리 것의 근거는 이름이 아니라 **그 작업이 무엇을 실행하는가**다.
function Get-CysTasks {
    $cand = @()
    try { $cand = @(Get-ScheduledTask -ErrorAction SilentlyContinue | Where-Object { $_.TaskName -like '*cys*' }) }
    catch { return @() }
    $roots = @($CysDir, $CysDirOld) | Where-Object { $_ }
    $ours = @()
    foreach ($tk in $cand) {
        $mine = $false
        # 이름이 정확히 우리 것이거나(느슨한 부분일치가 아니다) 우리 회사 표식을 달고 있으면 우리 것이다.
        if ($tk.TaskName -ieq 'cys' -or $tk.TaskName -ieq 'cysd' -or $tk.TaskName -imatch 'cysjavis') { $mine = $true }
        # 그리고 결정적인 근거 — 실행하는 파일이 우리 설치 자리 안에 있는가.
        foreach ($a in @($tk.Actions)) {
            $x = $null; try { $x = $a.Execute } catch { }
            if (-not $x) { continue }
            foreach ($r in $roots) { if ($r -and $x -like ($r + '*')) { $mine = $true } }
            if ($x -imatch 'cysd?\.exe$') { $mine = $true }
        }
        if ($mine) { $ours += $tk }
    }
    return $ours
}
# 우리가 사용자 Path 에 심은 조각 — 클로드 자리(~\.local\bin)와, 프로그램까지 지울 때는 cys 자리(v0.3.18 · bootstrap Seed-CysPath).
#   -KeepApp 이면 cys 프로그램이 남으므로 그 자리도 남긴다(남은 프로그램을 새 창에서 부를 수 있어야 한다).
function Get-UserPathSeedDirs {
    $d = @($ClaudeBin)
    if (-not $KeepApp) { $d += $CysDir.TrimEnd('\'); $d += $CysDirOld.TrimEnd('\') }
    return $d
}
function Test-UserPathSeed {
    $u = [Environment]::GetEnvironmentVariable('Path','User')
    if (-not $u) { return $false }
    $seeds = @(Get-UserPathSeedDirs)
    foreach ($p in ($u -split ';')) {
        if (-not $p) { continue }
        if ($seeds -contains [Environment]::ExpandEnvironmentVariables($p).TrimEnd('\')) { return $true }
    }
    return $false
}
function Test-JsonKey($file, $key) {
    if (-not (Test-Path $file)) { return $false }
    $t = Read-TextUtf8 $file
    if ($null -eq $t -or $t -eq '') { return $false }
    try { $o = $t | ConvertFrom-Json -ErrorAction Stop } catch { return $false }
    return ($null -ne $o.PSObject.Properties[$key])
}
function Test-Hooks($file) {
    if (-not (Test-Path $file)) { return $false }
    $t = Read-TextUtf8 $file
    if ($null -eq $t) { return $false }
    return ($t -match 'session-start\.(sh|ps1)|role-bootstrap\.(sh|ps1)')
}
function Test-LoginPresent {
    # ⚠자리가 어디인지 우리는 모른다(공식 문서가 윈도우 자리를 안 적는다 · footprint W-LOGIN).
    #   그래서 「있다/없다」를 단정하지 않고, 우리가 아는 후보 하나만 사실대로 보고한다.
    return (Test-Path $CredFile)
}

function Invoke-Diagnose {
    $script:Found = 0
    Write-Host '=== 이 컴퓨터의 상태 ==='
    # footprint: W-APP
    if ($KeepApp) {
        # 재설치 길 — 지울 목록에 넣지 않는다(개수에도 안 센다). 무엇을 남기는지는 말한다.
        Write-Host '  [남김] cys 프로그램 — 프로그램 파일은 지우지 않고 그대로 둡니다(다시 깔 때 이 프로그램을 씁니다)'
        # 지난 편성 기록은 보관 폴더로 옮긴다(Get-CysStateItems 머리 주석 · 0.3.37) — 있으면 목록에 센다.
        foreach ($s in (Get-CysStateItems)) { [void](Row 'cys 지난 편성 기록(동료 좌석을 되살리는 기록 · 보관 폴더로 옮깁니다)' $s) }
    } else {
        [void](Row 'cys 프로그램(프로그램 파일은 지우고, 안의 실행 기록은 보관 폴더로 옮깁니다)' $CysDir)
        [void](Row 'cys 프로그램(옛 자리)' $CysDirOld)
        foreach ($lnk in (Get-StartMenuLinks)) { [void](Row 'cys 시작 메뉴 바로가기(우리 설치 자리를 가리킬 때만 지웁니다)' $lnk) }
        foreach ($lnk in (Get-DesktopLinks)) { [void](Row 'cys 바탕화면 바로가기(우리 설치 자리를 가리킬 때만 지웁니다)' $lnk) }
    }
    # 0.3.37: 부서 실행 상태(프로그램 폴더 안 cys-dept-<n>) · 닫은 부서 휴지통 · 앱 화면 자료 — 재설치는 제자리 · 완전 삭제는 보관
    # footprint: W-DEPTSTATE
    foreach ($ds in @(Get-ChildItem -LiteralPath $CysDir -Force -Directory -Filter 'cys-dept-*' -ErrorAction SilentlyContinue)) {
        $dsp = Join-Path $CysDir $ds.Name
        if ($KeepApp -or $KeepHistory) { Write-Host ('  [있음] 부서 실행 상태 · ' + (Short $dsp) + ' (제자리에 둡니다 - 부서가 그대로 이어집니다)') }
        else { [void](Row '부서 실행 상태(보관 폴더로 옮깁니다)' $dsp) }
    }
    # footprint: W-TRASH
    if (Test-Path -LiteralPath $CysTrash) {
        if ($KeepApp -or $KeepHistory) { Write-Host ('  [있음] 닫은 부서 휴지통 · ' + (Short $CysTrash) + ' (제자리에 둡니다)') }
        else { [void](Row '닫은 부서 휴지통(보관 폴더로 옮깁니다)' $CysTrash) }
    }
    # footprint: W-WEBVIEW
    if ((-not $KeepApp) -and (-not $KeepHistory)) {
        foreach ($w in @($WebviewRoaming, $WebviewLocal)) { if (Test-Path -LiteralPath $w) { [void](Row '앱 화면 자료(보관 폴더로 옮깁니다)' $w) } }
    }
    # 0.3.37: 지난 재설치의 되옮기기가 끊긴 보관본(이번 실행이 먼저 이어서 끝낸다)
    foreach ($bk in @(Get-UnfinishedRestoreDirs)) {
        $script:Found++
        Write-Host ('  [있음] 끝나지 않은 되옮기기 · ' + (Short $bk) + ' (이번에 먼저 이어서 끝냅니다)')
    }
    # 0.3.37 r1 F4: 완전 삭제 보관본 속 로그인 파일 정리가 남은 것 — 찾은 자국으로 센다(안 세면 「지울 것이 없습니다」 로 끝나 비밀값이 남는다)
    foreach ($hp in @(Get-CredPendingHomes)) {
        $script:Found++
        Write-Host ('  [있음] 보관본 속 로그인 파일 지우기가 남음 · ' + (Short $hp) + ' (이번에 이어서 지웁니다)')
    }
    # footprint: W-REG
    if (-not $KeepApp) {
        [void](Row 'cys 설치 목록 항목(우리 설치 자리를 가리킬 때만 지웁니다)' $RegKeyR)
        [void](Row 'cys 설치 목록 항목(옛 이름 · 우리 설치 자리를 가리킬 때만 지웁니다)' $RegKey)
    }
    # footprint: W-DAEMON
    $tk = @(Get-CysTasks)
    RowFlag 'cys 상시 가동 등록' ($tk.Count -gt 0) '작업 스케줄러'
    # footprint: W-CYSHOME
    if ($KeepHistory) { [void](Row 'cys 계정 자리(로그인·이전 대화·부서 기록은 제자리로 되옮기고 나머지는 보관합니다)' $CysHome) }
    else { [void](Row 'cys 계정 자리(보관 폴더로 옮깁니다)' $CysHome) }
    # footprint: W-CLAUDEBIN
    [void](Row '클로드 실행 파일' $ClaudeExe)
    # footprint: W-JARVISHOME
    [void](Row '자비스 작업 폴더' $JarvisDir)
    # footprint: W-SCRIPTCOPY
    [void](Row '받아 둔 설치 스크립트' $HomePs1)
    [void](Row '받아 둔 설치 스크립트(옛 자리)' $TempPs1)
    # footprint: W-PATH
    RowFlag '실행 경로 등록' (Test-UserPathSeed) '사용자 Path 환경변수'
    # footprint: W-CLAUDEJSON
    RowFlag '클로드 설정의 우리 칸' (Test-JsonKey $ClaudeJson 'hasCompletedOnboarding') (Short $ClaudeJson)
    # footprint: W-CLAUDESETTINGS
    RowFlag '클로드 설정 우리 칸 2' (Test-JsonKey $SettingsJs 'skipDangerousModePermissionPrompt') (Short $SettingsJs)
    # footprint: W-HOOK
    RowFlag '각성 훅 등록' (Test-Hooks $SettingsJs) (Short $SettingsJs)

    Write-Host ''
    if ($PurgeLogin) { Write-Host '=== 로그인·개인 자료 ===' } else { Write-Host '=== 손대지 않는 것 (지우지 않습니다) ===' }
    # footprint: W-LOGIN
    if (Test-LoginPresent) { Write-Host ('  [있음] 로그인 · ' + (Short $CredFile)) }
    else { Write-Host '  [없음] 로그인 · 우리가 아는 자리에는 없습니다(다른 자리에 있을 수 있습니다)' }
    if ($PurgeLogin) {
        Write-Host '         -PurgeLogin 을 붙이셨습니다 — 이번에는 로그인도 지웁니다.'
        Write-Host '         이때는 로그인만이 아니라 연결해 둔 다른 서비스의 로그인과 확장 기능의 비밀값도 함께 지워집니다.'
        Write-Host '         (클로드가 그렇게 만들어 두었습니다 — 우리가 고를 수 있는 것이 아닙니다.)'
    } else {
        Write-Host '         기본으로 남깁니다. 재설치 뒤 로그인을 다시 하지 않으셔도 됩니다.'
    }
    # footprint: W-CLAUDEUSER
    if (Test-Path $CysCredFile) {
        Write-Host ('  [있음] 자비스 창 전용 로그인 · ' + (Short $CysCredFile))
        # 🔴v0.3.18 — 화면 줄에 기호 이모지(⚠ U+26A0)를 쓰지 않는다. 윈 4차 실기(2026-09-15): Windows PowerShell 5.1 콘솔이 이 글자 뒤 칸 폭을 잘못 세어
        #   이 절의 뒤 줄들이 「남남깁깁니니다다」로 겹쳐 찍혔다(이 글자가 없는 다른 절은 정상) — 인코딩이 아니라 글자 폭 문제다. ⇒ 글자로 쓴다.
        if ($KeepHistory) {
            # 0.3.36: 재설치 길에서는 이 로그인을 남긴다($HistoryKeepNames 머리 주석) — 앞 판의 「다시 하셔야 합니다」는 이 길에서 거짓이다.
            Write-Host '         다시 까는 길이라 이 로그인은 지우지 않고 그대로 둡니다 — 자비스 창에서 로그인을 다시 하지 않으셔도 됩니다.'
        } else {
            Write-Host '         주의: 이 로그인 파일은 보관 폴더에 넣지 않고 지웁니다(비밀값은 보관하지 않습니다).'
            Write-Host '         자비스 창에서 하신 로그인은 다시 하셔야 할 수 있습니다 — 윈도우에서 하신 로그인과는 별개입니다.'
        }
    }
    # 0.3.36: 자비스 창의 이전 대화(재설치 길에서만 남긴다) — 남긴다고 말하는 것이 사실일 때만 적는다.
    $cysProjects = Join-Path $CysHome 'claude\projects'
    if ($KeepHistory -and (Test-Path -LiteralPath $cysProjects)) {
        Write-Host ('  [있음] 자비스 창 이전 대화 · ' + (Short $cysProjects) + ' (다시 까는 길이라 남깁니다)')
    }
    if (Test-Path $ClaudeDir) { Write-Host ('  [있음] 클로드 대화·기록 · ' + (Short $ClaudeDir) + ' (남깁니다)') }
    else { Write-Host ('  [없음] 클로드 대화·기록 · ' + (Short $ClaudeDir)) }
    # footprint: W-AGORA
    #   설치기가 만들지 않는다. 토론장에 따로 참가하신 분이 만든 것이므로 지우지 않는다.
    if (Test-Path $AgoraDir) { Write-Host ('  [있음] 토론장 참가 열쇠·이름 · ' + (Short $AgoraDir) + ' (남깁니다)') }
    else { Write-Host ('  [없음] 토론장 참가 열쇠·이름 · ' + (Short $AgoraDir)) }
    # footprint: W-AGORASKILL
    #   자리가 둘이고 운명이 다르다. 밖(.claude)은 남고, cys 계정 자리 안(.cys\claude)은
    #   위의 「cys 계정 자리」를 통째로 지울 때 함께 지워진다. 한 줄로 뭉치면 그 줄이 거짓말이 된다.
    if (Test-Path -LiteralPath $AgoraSkill) { Write-Host ('  [있음] 토론장 안내 가리키기 · ' + (Short $AgoraSkill) + ' (남깁니다)') }
    else { Write-Host ('  [없음] 토론장 안내 가리키기 · ' + (Short $AgoraSkill)) }
    if (Test-Path -LiteralPath $AgoraSkillInCys) {
        Write-Host ('  [있음] 토론장 안내 가리키기(자비스 창 쪽) · ' + (Short $AgoraSkillInCys))
        Write-Host '         이것은 위의 「cys 계정 자리」 안에 들어 있어 그 자리와 함께 옮겨지거나 새로 만들어집니다(cys 설치의 일부입니다).'
        if (Test-Path -LiteralPath $AgoraSkill) {
            Write-Host ('         같은 안내가 ' + (Short $AgoraSkill) + ' 에도 있어 그쪽은 남습니다.')
        } else {
            Write-Host ('         지우기 전에 ' + (Short $AgoraSkill) + ' 로 옮겨 둡니다 - 없어지지 않습니다.')
        }
        Write-Host '         토론장 참가 열쇠·이름은 어느 경우에도 그대로 남습니다.'
    }
    Write-Host '  사진·문서·내려받기 등 개인 파일은 목록에 없습니다 — 손대지 않습니다.'

    Write-Host ''
    Write-Host '=== 판정 ==='
    if ($script:Found -eq 0) {
        Write-Host '  아무것도 깔려 있지 않습니다 (미설치).'
    } elseif ((Test-Path $CysDir) -and (Test-Path $CysHome) -and (Test-Path $ClaudeExe)) {
        Write-Host ("  설치가 끝난 상태로 보입니다 (찾은 자국 {0} 개)." -f $script:Found)
    } else {
        Write-Host ("  설치가 중간에 멈춘 상태로 보입니다 (찾은 자국 {0} 개)." -f $script:Found)
        Write-Host '  고장이 아닙니다 — 지우고 처음부터 다시 하면 됩니다.'
    }
}

# ── 남의 파일 속 우리 줄 — 파일을 지우지 않는다 ──────────────────
# 🔴교차 검토 지적 채택(2026-09-08) — 남의 JSON 을 고쳐 쓸 때 두 가지를 반드시 지킨다.
#   ⑴Set-Content -Encoding UTF8 은 PowerShell 5.1 에서 **맨 앞에 BOM 을 붙인다.** JSON 앞의 BOM 은
#     읽는 쪽(Node 계열)이 파싱에 실패하게 만든다 — 우리가 칸 하나 빼려다 **남의 설정 파일을
#     통째로 못 읽게 만드는** 것이다.
#   ⑵원본에 바로 쓰면 쓰는 도중 멈췄을 때(백신 개입·강제 종료) 남의 파일이 **반쪽으로 남는다.**
#   ⇒ BOM 없는 인코딩으로 **임시 파일에 다 쓴 뒤** 한 번에 자리를 바꾼다.
# 🔴🔴교차 검토·러너 실측 채택(2026-09-08 · run 34209137309 이 실물에서 잡았다).
#   `Get-Content $file -Raw` 는 **인코딩을 안 적으면 PowerShell 5.1 에서 ANSI(cp1252·cp949)로 읽는다.**
#   남의 `.claude.json` 은 UTF-8 이다 ⇒ 「자비스 연구소」가 「ìž\x90ë¹„ìŠ¤」 가 되고, 그 깨진 글자를
#   우리가 다시 UTF-8 로 써 넣는다. **칸 하나 빼려다 남의 설정 파일을 통째로 훼손하는 것이다.**
#   (러너가 잡은 실피해: 한글 값·키가 전부 mojibake · `한글칸` 이 깨진 이름의 새 칸으로 생김 ·
#    2048자 문자열이 6144자가 됨 · `projects` 의 우리말 경로 칸이 사라지고 깨진 이름으로 재생성.)
#   ⚠형제 파일 `bootstrap.ps1` 은 같은 자리에서 이미 `-Encoding UTF8` 을 쓰고 있었다(701·723·749).
#   **깔 때는 맞게 읽고 지울 때는 틀리게 읽고 있었다** — 한 쌍으로 도는 일인데 한쪽만 고쳐져 있었다.
function Read-TextUtf8($file) {
    # 성공 = 글자 · 실패 = $null. ★못 알아본 파일은 **손대지 않는다**(반쪽으로 만드는 것보다 낫다).
    try { $bytes = [System.IO.File]::ReadAllBytes($file) } catch { return $null }
    if ($bytes.Length -eq 0) { return '' }
    $skip = 0
    if ($bytes.Length -ge 3 -and $bytes[0] -eq 0xEF -and $bytes[1] -eq 0xBB -and $bytes[2] -eq 0xBF) { $skip = 3 }
    $body = New-Object byte[] ($bytes.Length - $skip)
    [Array]::Copy($bytes, $skip, $body, 0, $body.Length)
    if ($body.Length -eq 0) { return '' }
    # throwOnInvalidBytes — UTF-8 이 아닌 바이트가 있으면 여기서 걸린다(조용히 뭉개지 않는다).
    $enc = New-Object System.Text.UTF8Encoding($false, $true)
    try { $text = $enc.GetString($body) } catch { return $null }
    # 되짚어 본다: 읽은 글자를 다시 바이트로 만들면 원래 바이트와 같아야 한다.
    try { $again = $enc.GetBytes($text) } catch { return $null }
    if ($again.Length -ne $body.Length) { return $null }
    if ([Convert]::ToBase64String($again) -ne [Convert]::ToBase64String($body)) { return $null }
    return $text
}

# ★쓰기에도 자기검증을 붙인다(이중 방어 — 검사 축과 같은 논리를 지우개 안에 넣는다).
#   ⑴글로 옮겼다가 되읽어 **뜻이 같은가**(왕복 손실 — 깊이 잘림·배열 벗겨짐·날짜 변환)
#   ⑵쓴 파일을 되읽어 **글자가 같은가**(인코딩 손실)
#   하나라도 어긋나면 **원본을 건드리지 않고** 사실대로 [남음] 으로 남긴다.
#   되돌릴 수 없는 일에서는 「아마 됐을 것」보다 「안 했다」가 낫다.
function Write-JsonChecked($file, $obj) {
    $json = $obj | ConvertTo-Json -Depth 40
    try { $back = $json | ConvertFrom-Json -ErrorAction Stop } catch { return '글로 옮긴 것을 되읽지 못했습니다' }
    if (($back | ConvertTo-Json -Depth 40 -Compress) -ne ($obj | ConvertTo-Json -Depth 40 -Compress)) {
        return '글로 옮겼다가 되읽으니 뜻이 달라졌습니다'
    }
    $tmp = "$file.jarvis-tmp"
    $enc = New-Object System.Text.UTF8Encoding($false)
    try { [System.IO.File]::WriteAllText($tmp, $json, $enc) } catch { return $_.Exception.Message }
    $rt = Read-TextUtf8 $tmp
    if ($null -eq $rt -or $rt -ne $json) {
        Remove-Item $tmp -Force -ErrorAction SilentlyContinue
        return '쓴 파일을 되읽으니 글자가 달라졌습니다'
    }
    try { Move-Item -Path $tmp -Destination $file -Force -ErrorAction Stop } catch { return $_.Exception.Message }
    return $null
}
function Remove-JsonKey($file, $key) {
    if (-not (Test-Path $file)) { return }
    $raw = Read-TextUtf8 $file
    if ($null -eq $raw) {
        $script:KeptFail++
        Write-Host ("  [남음] " + (Short $file) + " 의 " + $key + " 칸 — 이 파일을 UTF-8 로 읽지 못했습니다. 손대지 않았습니다.")
        return
    }
    try {
        $o = $raw | ConvertFrom-Json -ErrorAction Stop
        if ($null -eq $o.PSObject.Properties[$key]) { return }
        $o.PSObject.Properties.Remove($key)
        $why = Write-JsonChecked $file $o
        if ($why) {
            $script:KeptFail++
            Write-Host ("  [남음] " + (Short $file) + " 의 " + $key + " 칸 — " + $why + " 원본은 그대로 두었습니다.")
            return
        }
        $script:Removed++; Write-Host ("  지움: " + (Short $file) + " 의 " + $key + " 칸 (파일은 그대로)")
    } catch {
        # 주석이 든 설정 파일(JSONC)은 5.1 의 ConvertFrom-Json 이 못 읽는다 — 그때는 안 고치고 사실대로 말한다.
        $script:KeptFail++; Write-Host ("  [남음] " + (Short $file) + " 의 " + $key + " 칸 — " + $_.Exception.Message)
    }
}
# 🔴`projects` 아래의 우리 자국을 뺀다 — **자리에 따라 뺄 범위가 다르다**(2026-09-10) ─────────
#   ⑴**우리 폴더**(자비스 작업 폴더) = 그 칸은 처음부터 끝까지 우리가 만든 것이다 ⇒ **칸째** 뺀다.
#   ⑵**사용자 홈** = 참가자가 이미 쓰던 자리일 수 있다 ⇒ 우리가 넣은 신뢰 칸 **하나만** 뺀다.
#   ★맥판이 ⑴을 이미 칸째 빼고 있었고 윈도우판은 아무것도 안 뺐다 — 두 OS 가 갈려 있었다.
#     기대까지 갈라 적어 두었길래(시험 표) 갈림이 굳어 있었다. 이 판에서 ⑴을 맞춘다.
function Remove-ProjectEntry($file, $dirs) {
    if (-not (Test-Path $file)) { return }
    $raw = Read-TextUtf8 $file
    if ($null -eq $raw) {
        $script:KeptFail++
        Write-Host ("  [남음] " + (Short $file) + " 의 자비스 폴더 칸 — 이 파일을 UTF-8 로 읽지 못했습니다. 손대지 않았습니다.")
        return
    }
    try {
        $o = $raw | ConvertFrom-Json -ErrorAction Stop
        $prj = $o.PSObject.Properties['projects']
        if ($null -eq $prj -or $null -eq $prj.Value) { return }
        $hit = 0
        foreach ($k in @($dirs)) {
            if ($null -ne $prj.Value.PSObject.Properties[$k]) { $prj.Value.PSObject.Properties.Remove($k); $hit++ }
        }
        if ($hit -eq 0) { return }
        $why = Write-JsonChecked $file $o
        if ($why) {
            $script:KeptFail++
            Write-Host ("  [남음] " + (Short $file) + " 의 자비스 폴더 칸 — " + $why + " 원본은 그대로 두었습니다.")
            return
        }
        $script:Removed++
        Write-Host ("  지움: " + (Short $file) + " 의 자비스 폴더 칸 " + $hit + "곳 (파일과 남의 칸은 그대로)")
    } catch {
        $script:KeptFail++; Write-Host ("  [남음] " + (Short $file) + " 의 자비스 폴더 칸 — " + $_.Exception.Message)
    }
}
# ── 🔴🔴작업 폴더를 **재귀로 지우기 전에** 그 자리가 안전한지 본다 (3차 N3 = 표면 축소 · 관리자 결정) ──
#   `JARVIS_HOME` 은 환경변수라 **무엇이든 들어올 수 있다.** 검사 없이 넘기면 그 값이 사용자 홈이거나
#   드라이브 루트일 때 **사진·문서·남의 프로젝트를 통째로** 지운다. 되돌릴 수 없는 손실이다.
# 🔴🔴**앞 판은 「나쁜 값 목록」으로 막으려 했고, 그 목록은 세 라운드 내내 새 구멍을 냈다**
#   (홈·드라이브 루트·시스템 자리 → `D:\custom` → UNC 공유 하위 → **조상 junction** → **8.3 짧은 이름**…).
#   ★목록으로 막는 싸움은 **막는 쪽이 항상 뒤늦다.** 값의 모양이 무한하기 때문이다.
#   ⇒ **표면을 줄인다**(관리자 결정 2026-09-10): 지워도 되는 자리의 이름을 **하나로 못 박는다.**
#     ⑴실제 경로의 **마지막 칸이 정확히 `install-jarvis`** 다. 그 외의 값은 **거부하고 안내한다.**
#       · 참가자는 기본값을 쓰므로 아무 영향이 없고, 러너의 `…\lp-home\install-jarvis` 도 통과한다.
#       · 이 한 줄로 홈·드라이브 루트·시스템 자리·UNC 공유·남의 프로젝트가 **한꺼번에** 닫힌다 —
#         그것들의 마지막 칸은 `install-jarvis` 가 아니기 때문이다.
#     ⑵조상 어디에도 **링크(junction·symlink)가 없다.** 중간 한 칸이 링크면 글자로 보는 검사는
#       모두 빗나가고, 그 안을 열거하는 순간 **남의 자리**를 훑는다(3차 REVISE).
#     ⑶**우리가 만든 표식**이 그 안에 있다 — 설치기는 **자기가 새로 만든 폴더에만** 표식을 놓는다.
#       (앞 판은 이미 있던 남의 폴더에도 표식을 써 줘서 이 관문을 스스로 무효화했다 — 3차 BLOCK.)
#   ⚠`GetFullPath` 는 `..` 과 상대 경로만 편다 — **8.3 짧은 이름**(`PROGRA~1`)은 그대로 남는다.
#     실물이 있으면 `Get-Item` 의 `FullName` 이 긴 이름으로 다시 써 준다 ⇒ 그 값으로 이름을 견준다.
$JarvisOwnerMark = 'jarvis-installer-owned v1'
$JarvisHomeBaseName = 'install-jarvis'
$script:SafeWhy = ''
$script:TrustCleanupFail = 0
function Resolve-RealPath($p) {
    $full = [System.IO.Path]::GetFullPath($p)
    try {
        $it = Get-Item -LiteralPath $full -Force -ErrorAction Stop
        if ($it.FullName) { $full = [string]$it.FullName }
    } catch { }
    return $full.TrimEnd('\')
}
function Get-ReparseAncestor($p) {   # 자기 자신부터 위로 훑어 **처음 만나는 링크**를 돌려준다(없으면 '')
    $cur = $p
    while ($cur) {
        try {
            $it = Get-Item -LiteralPath $cur -Force -ErrorAction Stop
            if (($it.Attributes -band [System.IO.FileAttributes]::ReparsePoint) -eq [System.IO.FileAttributes]::ReparsePoint) {
                return [string]$cur
            }
        } catch { }
        $parent = Split-Path $cur -Parent
        if ((-not $parent) -or ($parent -eq $cur)) { break }
        $cur = $parent
    }
    return ''
}
function Test-SafeJarvisDir($p) {
    $script:SafeWhy = ''
    if (-not $p) { $script:SafeWhy = '빈 경로입니다'; return $false }
    $full = $null
    try { $full = Resolve-RealPath $p } catch { $script:SafeWhy = '실제 경로를 확인하지 못했습니다'; return $false }
    if (-not $full) { $script:SafeWhy = '빈 경로입니다'; return $false }
    if (-not [System.IO.Path]::IsPathRooted($full)) { $script:SafeWhy = '절대 경로가 아닙니다'; return $false }
    # ⑴이름 관문 — 실제 경로의 마지막 칸이 정확히 그 이름일 때만.
    $leaf = ''
    try { $leaf = [string](Split-Path $full -Leaf) } catch { $leaf = '' }
    if ($leaf -ne $JarvisHomeBaseName) {
        $script:SafeWhy = ('이 도구가 지우는 폴더의 이름은 「' + $JarvisHomeBaseName + '」 하나입니다(실제 경로: ' + $full + ')')
        return $false
    }
    # ⑵링크 관문 — 자기 자신을 포함해 조상 어디에도 링크가 없어야 한다.
    $rp = Get-ReparseAncestor $full
    if ($rp) {
        $script:SafeWhy = ('그 자리로 가는 길에 바로가기(junction·symlink)가 있습니다: ' + $rp)
        return $false
    }
    # ⑶표식 관문 — 설치기가 **새로 만든 폴더에만** 놓는다.
    $mark = Join-Path $full '.jarvis-owned'
    if (-not (Test-Path -LiteralPath $mark)) {
        $script:SafeWhy = '설치 도우미가 놓은 표식이 없습니다(우리가 만든 폴더가 아닙니다)'; return $false
    }
    # ★이 파일이 이미 가진 UTF-8 읽기 도우미를 쓴다 — `Get-Content -Raw` 는 5.1 에서 ANSI 로 읽는다.
    $body = Read-TextUtf8 $mark
    if ($null -eq $body -or $body -notmatch [regex]::Escape($JarvisOwnerMark)) {
        $script:SafeWhy = '표식의 내용이 우리 것이 아닙니다'; return $false
    }
    return $true
}

# ── 작업 폴더 보관 이동(0.3.36 · 맥 keep_jarvis_dir 짝) — 지우지 않고 같은 자리 옆 「install-jarvis-backup-<날짜-시각>」 으로 옮긴다 ──
#   ★이름 바꾸기만 쓴다([IO.Directory]::Move — 같은 드라이브 안에서만 되고, 다른 드라이브면 복사하지 않고 실패한다).
#     안 되면(다른 드라이브·잠긴 파일·권한) **아무것도 지우지 않고 그 자리에 둔다** — 못 지운 것으로 세지 않는다(재설치는 그 위에 이어서 간다).
#   ★옮긴 뒤 파일 수·총 바이트를 옮기기 전과 대조 — 다르면 「보관 확인 실패」로 알리고 어느 쪽도 지우지 않는다.
#   ★보관본의 마지막 칸은 install-jarvis 가 아니다 ⇒ Test-SafeJarvisDir(이름 관문)가 다음 지우기에서 보관본을 겨냥하지 않는다.
#   ★정리 = 최근 $JarvisBackupKeep 개만 · 대상 = 이름 꼴 ∧ 우리 표식 ∧ 바로가기 아님 ∧ **설치기가 만든 이름만**(모르는 이름이 있으면 늘 남긴다 · 맥 짝)
#     · 정리 실패는 못 지움으로 세지 않는다(재설치를 멈추지 않는다) · 다시 받는 것은 알려진 설치기 산출물 이름만 뺀다(dl 안 claude-*·cys* · backup 안 cys*).
$JarvisBackupPrefix = 'install-jarvis-backup-'
$JarvisBackupKeep   = 3
$JarvisBackupInstallerNames = @('.jarvis-owned','bootstrap.log','env-report.md','install-directive.md','trust-seed.tsv','wake.sh','wake.ps1','install-id','help-attempts.json','remote-help-executed.json','remote-help-executed.json.lock','remote-help-client-token','claude-install.log','awake-master.ok','install-done.txt','transcript.txt','.rotate-out','.rotate-err','.login-wait','.login-pid','.login-capped')
$script:BackupNote  = ''
function Get-TreeStat($p) {   # 「파일 수 총바이트」 · 하나라도 못 읽으면 $null
    #   0.3.37: 바로가기(symlink·junction)는 따라가지 않고 **이름표 하나(0 바이트)** 로 센다 — 옮기기 전후로 같은 값이 나와야 대조가 뜻을 가진다
    #     (맥 tree_stat 의 lstat 셈과 같은 모양). 앞 판은 Get-ChildItem -Recurse 로 셌다: 트리 안 다른 자리를 가리키는 바로가기가
    #     옮긴 뒤 끊어지면(가리키는 곳이 옛 자리) 폴더에서 파일 모양으로 바뀌어 수가 달라졌고(대조 실패 오보 · 시험 반례①⑤),
    #     5.1 은 junction 안까지 따라 들어가 남의 자리 크기가 섞였다. ⚠이 함수는 혼자 선다(다른 함수를 부르지 않는다 · 보관 시험이 떼어 부른다).
    try {
        $root = Get-Item -LiteralPath $p -Force -ErrorAction Stop
        if (($root.Attributes -band [System.IO.FileAttributes]::ReparsePoint) -ne 0) { return '1 0' }
        if (-not $root.PSIsContainer) { return ('1 {0}' -f [long]$root.Length) }
        $n = 0; $bytes = [long]0
        $stack = New-Object System.Collections.Stack
        $stack.Push([string]$root.FullName)
        while ($stack.Count -gt 0) {
            $d = [string]$stack.Pop()
            foreach ($i in @(Get-ChildItem -LiteralPath $d -Force -ErrorAction Stop)) {
                if (($i.Attributes -band [System.IO.FileAttributes]::ReparsePoint) -ne 0) { $n++; continue }
                if ($i.PSIsContainer) { $stack.Push([string]$i.FullName); continue }
                $n++; $bytes += [long]$i.Length
            }
        }
        return ('{0} {1}' -f $n, $bytes)
    } catch { return $null }
}
function Test-JarvisBackup($p) {   # 이름 꼴 ∧ 진짜 폴더(바로가기 아님) ∧ 우리 표식
    $leaf = [string](Split-Path $p -Leaf)
    if ($leaf -notmatch ('^' + [regex]::Escape($JarvisBackupPrefix) + '[0-9]{8}-[0-9]{6}(-[0-9]+)?$')) { return $false }
    try { $it = Get-Item -LiteralPath $p -Force -ErrorAction Stop } catch { return $false }
    if (-not $it.PSIsContainer) { return $false }
    if (($it.Attributes -band [System.IO.FileAttributes]::ReparsePoint) -eq [System.IO.FileAttributes]::ReparsePoint) { return $false }
    $body = Read-TextUtf8 (Join-Path $p '.jarvis-owned')
    return ($null -ne $body -and $body -match [regex]::Escape($JarvisOwnerMark))
}
function Test-InstallerOnlyBackup($p) {   # 설치기가 만든 이름만 들어 있는가(그때만 정리 대상) · 못 세면 $false
    try { $items = @(Get-ChildItem -LiteralPath $p -Force -ErrorAction Stop) } catch { return $false }
    foreach ($i in $items) {
        if (($i.Attributes -band [System.IO.FileAttributes]::ReparsePoint) -eq [System.IO.FileAttributes]::ReparsePoint) { return $false }
        if ($JarvisBackupInstallerNames -contains $i.Name) { continue }
        if ((-not $i.PSIsContainer) -and ($i.Name -like 'capture-*.jpg' -or $i.Name -like 'login-cap-*.jpg' -or $i.Name -like '.progress.*')) { continue }   # login-cap-N.jpg = 로그인 대기 캡처(설치기)
        return $false
    }
    return $true
}
function Remove-OldJarvisBackups($parent, $fresh) {   # 최근 Keep 개만 남긴다(방금 것은 늘 남긴다)
    $all = @()
    try { $all = @(Get-ChildItem -LiteralPath $parent -Force -Directory -ErrorAction Stop | Where-Object { (Test-JarvisBackup $_.FullName) -and (Test-InstallerOnlyBackup $_.FullName) } | Sort-Object Name) } catch { return }
    $drop = $all.Count - $JarvisBackupKeep
    foreach ($d in $all) {
        if ($drop -le 0) { break }
        if ($d.FullName -eq $fresh) { continue }
        # 정리 실패는 못 지움으로 세지 않는다 — 셈을 되돌리고 한 줄만(재설치가 7 로 멈추지 않게 · 적대 검토 반례)
        $kf = $script:KeptFail
        Drop '오래된 자비스 보관본' $d.FullName
        if ($script:KeptFail -gt $kf) { $script:KeptFail = $kf; Write-Host ('  [남김] ' + (Short $d.FullName) + ' - 오래된 보관본을 정리하지 못했습니다(자료는 그대로입니다).') }
        $drop--
    }
}
function Keep-JarvisDir($src) {   # 보관 이동 · 마지막 안내 1줄 = $script:BackupNote
    $src = ([string]$src).TrimEnd('\')
    if ($script:PreserveCanonFail.Count -gt 0 -or @(Get-PreservedUnder (Resolve-RealPath $src)).Count -gt 0 -or (Test-PreserveCovers (Resolve-RealPath $src))) {
        Write-Host ('  [남김] ' + (Short $src) + ' - 안에 따로 두신 자리가 있어 옮기지 않고 그대로 두었습니다.')
        $script:BackupNote = ('이전 자비스 자료는 ' + (Short $src) + ' 에 그대로 두었습니다. 지운 것은 없습니다.')
        return
    }
    $parent = Split-Path $src -Parent
    $stamp = (Get-Date).ToString('yyyyMMdd-HHmmss')
    $dest = Join-Path $parent ($JarvisBackupPrefix + $stamp); $n = 1
    while (Test-Path -LiteralPath $dest) { $n++; $dest = Join-Path $parent ($JarvisBackupPrefix + $stamp + '-' + $n) }
    $before = Get-TreeStat $src
    $moved = $false
    if ($before) {
        try { [System.IO.Directory]::Move($src, $dest); $moved = $true } catch { $moved = $false }
    }
    if (-not $moved) {
        Write-Host ('  [남김] ' + (Short $src) + ' - 다른 곳으로 옮기지 못해 그 자리에 그대로 두었습니다(지운 것 없음).')
        $script:BackupNote = ('이전 자비스 자료는 옮기지 못해 ' + (Short $src) + ' 에 그대로 두었습니다. 지운 것은 없습니다.')
        return
    }
    $after = Get-TreeStat $dest
    $script:ArchiveDest = $dest   # 0.3.37: 이번 실행의 보관 폴더 — 뒤의 cys 자료도 여기로 모은다(Set-ArchiveRoot)
    if ($after -ne $before) {
        $script:ArchiveFail = 1   # 0.3.37: 대조가 어긋나면 뒤 단계(프로그램 지우기 등)를 하지 않는다(Invoke-Purge 의 보관 관문이 센다)
        $script:ArchiveVerifyFail = 1
        Write-Host ('  [남음] 보관 확인 실패: ' + (Short $dest) + ' - 옮기기 전과 파일 수·크기가 달라 아무것도 지우지 않았습니다(전 ' + $before + ' · 뒤 ' + $after + ').')
        $script:BackupNote = ('이전 자비스 자료를 ' + (Short $dest) + ' 로 옮겼지만 빠짐없이 옮겨졌는지 확인하지 못했습니다. 아무것도 지우지 않았습니다.')
        return
    }
    # 다시 받는 것 = 알려진 설치기 산출물 이름만(dl: claude-*·cys* · backup: cys*) · 사용자가 둔 다른 파일은 그대로 · 빈 폴더가 되면 폴더만 치운다
    foreach ($pair in @(@('dl', 'claude-*'), @('dl', 'cys*'), @('backup', 'cys*'))) {
        $cd = Join-Path $dest $pair[0]
        try {
            $it = Get-Item -LiteralPath $cd -Force -ErrorAction Stop
            if (-not $it.PSIsContainer -or (($it.Attributes -band [System.IO.FileAttributes]::ReparsePoint) -eq [System.IO.FileAttributes]::ReparsePoint)) { continue }
            foreach ($f in @(Get-ChildItem -LiteralPath $cd -Force -Filter $pair[1] -ErrorAction Stop)) {
                if ($f.PSIsContainer -and (($f.Attributes -band [System.IO.FileAttributes]::ReparsePoint) -ne [System.IO.FileAttributes]::ReparsePoint)) { [System.IO.Directory]::Delete($f.FullName, $true) }
                else { [System.IO.File]::Delete($f.FullName) }
            }
        } catch { }
    }
    foreach ($c in @('dl', 'backup')) {
        $cd = Join-Path $dest $c
        try { if (@(Get-ChildItem -LiteralPath $cd -Force -ErrorAction Stop).Count -eq 0) { [System.IO.Directory]::Delete($cd, $false) } } catch { }
    }
    Write-Host ('  [보관] ' + (Short $src) + ' -> ' + (Short $dest) + ' (파일 ' + ($before -split ' ')[0] + '개 · 옮긴 뒤 수·크기 같음)')
    Remove-OldJarvisBackups $parent $dest
    $script:BackupNote = ('이전 자비스 자료는 ' + (Short $dest) + ' 에 그대로 보관해 두었습니다.')
}

# ── 0.3.37 보관 이동 넓히기 — 지우는 것은 다시 받는 프로그램 파일뿐 · 사람이 쌓은 자료는 보관 폴더로 옮긴다 ──
#   설계 = docs/install-master/DESIGN-0337.md 3·4절 · 맥 reset-clean.sh 의 archive_move · cys_home_reinstall · prescan_links 와 짝.
#   ★옮기기 = 같은 드라이브 안 이름 바꾸기 한 번([IO.Directory]::Move / [IO.File]::Move)뿐 — 복사하지 않는다.
#     다른 드라이브면 옮기지 않고 멈춘다(ArchiveFail).
#   ★옮긴 뒤 파일 수·총 바이트를 대조한다(Get-TreeStat) — 어긋나면 ArchiveFail · Invoke-Purge 가 그 뒤 단계(프로그램 지우기 등)를 하지 않는다.
#   ★보관 폴더 = 작업 폴더 보관(Keep-JarvisDir)이 만든 것(ArchiveDest)에 모은다 — 없거나 사용자 폴더와 다른 드라이브면
#     사용자 폴더에 같은 이름 꼴로 새로 만들고 우리 표식을 놓는다(ArchiveHome). 사람 자료가 든 보관본은 자동 정리 대상이 아니다
#     (Test-InstallerOnlyBackup 이 설치기 이름 밖의 것을 보면 늘 남긴다 — 0.3.36 규칙 그대로).
$script:ArchiveDest = ''
$script:ArchiveHome = ''
$script:ArchiveFail = 0
# 옮긴 뒤 수·크기 대조가 어긋난 일(한 번이라도) — 스스로 다시 해 보기가 지우지 **않는다**(ArchiveFail 과 달리 되풀이 사이에 풀지 않는다).
#   옮기기 실패(잠김)는 잠깐 뒤 풀릴 수 있어 다시 해 볼 뜻이 있지만, 대조 실패는 이미 옮긴 뒤라 다시 해도 같은 자리를 다시 재지 않는다 —
#   풀어 버리면 두 번째 시도가 「못 지운 것 없음」으로 끝나며 프로그램을 지운다(시험 ⓓ 가 잡은 틈).
$script:ArchiveVerifyFail = 0
$script:Archived = 0
$script:ArchiveLast = ''
$script:CysHomeArchived = ''   # 완전 삭제에서 보관한 옛 ~\.cys 자리 — 회차 사이에 풀지 않는다(다시 해 보기가 그 안 로그인 파일을 다시 지운다)
$script:ARoot = ''
# 재설치 되옮기기 진행 표지(보관 폴더 맨 위) — UTF-8 · 칸마다 NUL 로 끝난다 · 첫 칸 = 보관 폴더 안 옛 ~\.cys 이름(cys-home · 겹치면 cys-home-2 …)
#   · 나머지 = ~\.cys 기준 상대 이름(구분 = \). 다음 실행이 이 표지를 보고 이어서 끝낸다(Resume-UnfinishedRestore).
$RestoreMark = '.jarvis-restore-pending'
$CredMark = '.jarvis-cred-pending'   # 완전 삭제 보관본 속 로그인 파일 정리가 남았다(보관된 옛 ~\.cys 맨 위 · 빈 파일) — 다음 실행이 이어서 지운다(r1 F4)
$script:ResumeLeft = $false   # 이 실행에서 지난 되옮기기를 끝내지 못했다(Resume-UnfinishedRestore) — 재설치 길을 이어 가지 않는다
# 재설치 길에서 ~\.cys 바로 아래에서 제자리로 되옮길 부서 자료(DESIGN-0337 4-2절 · 맥 reinstall_keep_list 짝 · 이름 꼴 · 대소문자 무시)
#   부서 등록부 · 카탈로그 · 임무 · 요청 · 닫기 스냅샷 · 부서 팩 사본 · 부서·계정별 좌석 프로필(claude-* 통째로).
$ReinstallKeepTop = @('depts.json', 'dept-catalog.json', 'dept-missions', 'dept-requests', 'dept-snapshots', 'pack-dept-*', 'claude-*')
# 프로그램 파일(다시 받을 수 있는 것) — 설치 폴더 **바로 아래** 이름으로만 판정한다. 근거 = 설치 템플릿 Section Uninstall(installer.nsi:818~848 ·
#   주 실행 파일 · 부속 실행 파일 cys·cysd · 리소스 pack.tar.gz·pack-manifest.json·runtime-manifest.json·runtime\ · uninstall.exe) ·
#   우리 훅 PREUNINSTALL(nsis-hooks.nsh:931~943 · *.new.exe · *.prev*.exe · cysr.exe · 판 표지 · 설치 실패 기록 · runtime\) ·
#   잠금 스윕 잔해(nsis-hooks.nsh:660~685 · <이름>.exe|dll|pyd|node.prev<수>) · 설치 도우미 판 표지(jarvis-cys-pin.json · footprint W-APP).
#   ★이 밖의 이름은 모두 자료로 친다(모르면 보관) — 편성·묘비·검색 기록(transcripts.db)·부서 상태(cys-dept-<n>\) 등.
$CysProgramNames = @('uninstall.exe', 'cys-installed-version.txt', 'cys-install-failure.txt', 'jarvis-cys-pin.json', 'pack.tar.gz', 'pack-manifest.json', 'runtime-manifest.json')
$CysProgramDirs  = @('runtime', 'resources')
# 실행 파일(exe·dll)은 **설치기가 실제로 까는 이름만**(r1 F1 · 앞 판은 이름 꼴 *.exe·*.dll 전부 = 사람이 둔 exe 가 보관 없이 사라졌다) —
#   주 실행 파일·부속 실행 파일 cys·cysd·cys-app·cysr(nsis-hooks.nsh:822~827 · tauri.conf.json externalBin) · 교체 슬롯 <이름>.new.exe ·
#   <이름>.prev[<수>].exe(prev·prev2·prev3·tick = prev<GetTickCount> · nsis-hooks.nsh:246~277) · WebView2Loader.dll ·
#   잠금 스윕 잔해 <그 이름>.exe|dll.prev<수>(nsis-hooks.nsh:620~644). ★이 밖의 exe·dll 은 자료로 친다(모르면 보관).
$CysProgramExeRx = '(?i)^(cys|cysd|cys-app|cysr)(\.new|\.prev[0-9]*)?\.exe$|^webview2loader\.dll$'
$CysProgramResidueRx = '(?i)^((cys|cysd|cys-app|cysr)\.exe|webview2loader\.dll)\.prev[0-9]*$'
function Test-CysProgramItem($it) {
    if (Test-IsReparse $it) { return $false }   # 바로가기는 프로그램 파일이 아니다(자료 쪽 = 이름표만 치운다)
    $n = [string]$it.Name
    if ($it.PSIsContainer) { return (@($CysProgramDirs | Where-Object { $_ -ieq $n }).Count -gt 0) }
    if (@($CysProgramNames | Where-Object { $_ -ieq $n }).Count -gt 0) { return $true }
    if ($n -match $CysProgramExeRx) { return $true }
    if ($n -match $CysProgramResidueRx) { return $true }
    return $false
}
function Norm-Slash($p) { return ([string]$p).Replace('/', '\').TrimEnd('\') }
function Test-IsReparsePath($p) {   # 그 자리 자체가 바로가기(symlink·junction)인가 · 없거나 못 읽으면 $false
    try { return (Test-IsReparse (Get-Item -LiteralPath $p -Force -ErrorAction Stop)) } catch { return $false }
}
# 있거나 이름표만 있는(끊어진 바로가기) 자리 → $true. 「없다」와 「못 읽었다」를 가르는 쪽은 부르는 곳이 Get-Item 으로 따로 본다.
function Test-PathOrLink($p) {
    if (Test-Path -LiteralPath $p) { return $true }
    try { $null = Get-Item -LiteralPath $p -Force -ErrorAction Stop; return $true } catch { return $false }
}
function Get-VolumeRoot($p) {   # 그 자리의 드라이브 뿌리(C:\ · \\서버\공유\) · 못 풀면 ''
    try { return [string][System.IO.Path]::GetPathRoot([System.IO.Path]::GetFullPath([string]$p)) } catch { return '' }
}
function Test-SameVolume($a, $b) {
    $ra = Get-VolumeRoot $a
    $rb = Get-VolumeRoot $b
    return ([bool]$ra -and ($ra -ieq $rb))
}
function New-BackupDir($parent) {   # 새 보관 폴더(우리 표식 · 이름 꼴 install-jarvis-backup-<시각>[-n]) · 못 만들면 ''
    $stamp = (Get-Date).ToString('yyyyMMdd-HHmmss')
    $d = Join-Path $parent ($JarvisBackupPrefix + $stamp); $n = 1
    while (Test-PathOrLink $d) { $n++; $d = Join-Path $parent ($JarvisBackupPrefix + $stamp + '-' + $n) }
    try { [void][System.IO.Directory]::CreateDirectory($d) } catch { return '' }
    try { [System.IO.File]::WriteAllText((Join-Path $d '.jarvis-owned'), ($JarvisOwnerMark + "`n"), (New-Object System.Text.UTF8Encoding($false))) }
    catch { try { [System.IO.Directory]::Delete($d, $false) } catch { }; return '' }
    return $d
}
function Set-ArchiveRoot {   # 보관 폴더를 정해 $script:ARoot 에 둔다 · 못 만들면 $false
    $script:ARoot = ''
    if ($script:ArchiveDest -and (Test-Path -LiteralPath $script:ArchiveDest -PathType Container) -and (Test-SameVolume $script:ArchiveDest $env:USERPROFILE)) {
        $script:ARoot = $script:ArchiveDest
        return $true
    }
    if ((-not $script:ArchiveHome) -or (-not (Test-Path -LiteralPath $script:ArchiveHome -PathType Container))) {
        $script:ArchiveHome = New-BackupDir $env:USERPROFILE
        if (-not $script:ArchiveHome) { return $false }
    }
    $script:ARoot = $script:ArchiveHome
    return $true
}
function Get-FreeRel($root, $rel) {   # 비어 있는 이름(겹치면 -2, -3 …) — 다시 해 보기가 같은 이름을 또 쓸 때 덮지 않는다
    $r = $rel; $n = 1
    while (Test-PathOrLink (Join-Path $root $r)) { $n++; $r = $rel + '-' + $n }
    return $r
}
# 이름 바꾸기 한 번(같은 드라이브) — 복사하지 않는다 · 실패 = 예외. 바로가기는 이름표째 옮긴다(가리키는 곳은 그대로).
function Move-OneEntry($src, $dst) {
    $it = Get-Item -LiteralPath $src -Force -ErrorAction Stop
    if ($it.PSIsContainer) { [System.IO.Directory]::Move($src, $dst) } else { [System.IO.File]::Move($src, $dst) }
}
# 자료 한 자리를 보관 폴더로 옮긴다 — 돌려주는 값 = 성공($true: 옮김 · 없음 · 남김) / 실패($false: ArchiveFail · 못 지움 +1).
#   바로가기면 종전대로 이름표만 지운다(가리키던 실제 자료는 무접촉 · Drop) · 참가 자리가 안에 있으면 옮기지 않고 그대로 둔다(옮겼다 되돌리기 금지).
#   ⚠「목록을 못 읽었다」를 「없다」로 읽지 않는다 — Get-Item 이 실패했는데 Test-Path 가 있다고 하면 실패로 센다.
function Archive-Move($src, $rel, $what) {
    $it = $null
    try { $it = Get-Item -LiteralPath $src -Force -ErrorAction Stop } catch { $it = $null }
    if (-not $it) {
        if (-not (Test-Path -LiteralPath $src)) { return $true }
        $script:ArchiveFail = 1; $script:KeptFail++
        Write-Host ('  [남음] ' + (Short $src) + ' - 이 자리를 읽지 못해 옮기지 않고 그대로 두었습니다(지운 것 없음).')
        return $false
    }
    if (Test-IsReparse $it) {
        $kf = $script:KeptFail
        Drop $what $src
        return ($script:KeptFail -eq $kf)
    }
    $c = Canon-Path $src
    if (($script:PreserveCanonFail.Count -gt 0) -or (-not $c)) {
        # 남겨야 할 자리를 확인하지 못했거나 이 자리의 실제 경로를 못 풀었다 — 옮기지도 지우지도 않고 못 지움으로 센다(Drop 과 같은 규율).
        $script:KeptFail++
        Write-Host ('  [남음] ' + (Short $src) + ' - 실제 경로나 남겨야 할 자리를 확인하지 못해 옮기지 않고 그대로 두었습니다(지운 것 없음).')
        return $true
    }
    if ((@(Get-PreservedUnder $c).Count -gt 0) -or (Test-PreserveCovers $c)) {
        $script:Preserved++
        Write-Host ('  남김: ' + (Short $src) + ' - 안에 따로 두신 자리(참가 자리)가 있어 옮기지 않고 그대로 두었습니다(지운 것 없음).')
        return $true
    }
    if (-not (Set-ArchiveRoot)) {
        $script:ArchiveFail = 1; $script:KeptFail++
        Write-Host ('  [남음] ' + (Short $src) + ' - 보관 폴더를 만들지 못해 옮기지 않고 그대로 두었습니다(지운 것 없음).')
        return $false
    }
    if (-not (Test-SameVolume $script:ARoot (Split-Path -Parent $src))) {
        $script:ArchiveFail = 1; $script:KeptFail++
        Write-Host ('  [남음] ' + (Short $src) + ' - 보관 폴더와 다른 드라이브에 있어 옮기지 않았습니다(복사하지 않습니다 · 지운 것 없음).')
        return $false
    }
    $dest = Join-Path $script:ARoot (Get-FreeRel $script:ARoot $rel)
    $dp = Split-Path -Parent $dest
    try { if (-not (Test-Path -LiteralPath $dp)) { [void][System.IO.Directory]::CreateDirectory($dp) } } catch { }
    $before = Get-TreeStat $src
    $moved = $false
    if ($before) { try { Move-OneEntry $src $dest; $moved = $true } catch { $moved = $false } }
    if (-not $moved) {
        $script:ArchiveFail = 1; $script:KeptFail++
        Write-Host ('  [남음] ' + (Short $src) + ' - 보관 폴더로 옮기지 못해 그대로 두었습니다(지운 것 없음 · 쓰고 있는 프로그램이 있을 수 있습니다).')
        return $false
    }
    $after = Get-TreeStat $dest
    if ($after -ne $before) {
        $script:ArchiveFail = 1; $script:ArchiveVerifyFail = 1; $script:KeptFail++
        Write-Host ('  [남음] 보관 확인 실패: ' + (Short $dest) + ' - 옮기기 전과 파일 수·크기가 다릅니다(전 ' + $before + ' · 뒤 ' + $after + '). 이 뒤로는 아무것도 지우지 않습니다.')
        return $false
    }
    $script:Archived++
    $script:ArchiveLast = $dest
    Write-Host ('  보관: ' + $what + ' ' + (Short $src) + ' -> ' + (Short $dest))
    return $true
}
# 완전 삭제 보관본에서는 자비스 창 전용 로그인 파일을 빼고 지운다(DESIGN-0337 결정 3 · 보관 폴더는 사람이 옮기고 나눠 줄 수 있는 자리 —
#   비밀값이 남으면 안 된다). 보통 파일만 · 바로가기는 따라가지 않는다(그 파일도, 그것을 담은 폴더도 바로가기면 건드리지 않는다).
#   r1 F4: 지우기 **전에** 그 보관본 맨 위에 「정리 남음」 표지($CredMark)를 먼저 둔다 — 창이 닫히거나 끝내 실패해도 **다음 실행**이
#   진단에서 찾은 자국으로 세고 지우기 맨 앞에서 이어서 지운다(Resume-ArchivedCredentials). 다 지우면 표지를 치운다.
#   (앞 판은 보관 자리를 이 실행의 변수로만 기억해, 회차 사이만 이어지고 새 실행은 「지울 것 없음」 → 비밀값이 보관본에 남았다.)
#   파일을 읽지 못하면(권한) 「없음」 으로 넘기지 않는다 — 자리가 있으면 못 지움으로 센다(r1 F4-2).
function Remove-ArchivedCredentials($h) {
    if (-not $h) { return }
    # 표지를 못 쓰면 다음 실행이 이어서 지울 근거가 없다 — 그때는 「이어서 지웁니다」 라고 약속하지 않는다(r3 M3)
    $credNext = '다시 실행하시면 이어서 지웁니다.'
    try { [System.IO.File]::WriteAllText((Join-Path $h $CredMark), '') } catch { $credNext = '그 폴더의 쓰기 권한을 확인해 주십시오(정리 표지를 쓰지 못해 다음 실행이 스스로 이어 지우지 못합니다): ' + (Short $h) }
    $fail = $false
    $dirs = @()
    try { $dirs = @(Get-ChildItem -LiteralPath $h -Force -Directory -ErrorAction Stop) }
    catch { $script:KeptFail++; Write-Host ('  [남음] 보관본 속 로그인 파일을 찾지 못했습니다: ' + (Short $h) + ' - ' + $credNext); return }
    foreach ($d in $dirs) {
        if (Test-IsReparse $d) { continue }
        if (-not (($d.Name -ieq 'claude') -or ($d.Name -ilike 'claude-*'))) { continue }
        $f = Join-Path (Join-Path $h $d.Name) '.credentials.json'
        $fi = $null
        $unread = $false
        try { $fi = Get-Item -LiteralPath $f -Force -ErrorAction Stop }
        catch [System.Management.Automation.ItemNotFoundException] { $fi = $null }
        catch { $fi = $null; $unread = $true }   # 권한 등 — Test-Path 도 「없음」 으로 답하므로 예외 종류로 가른다
        if ($unread) { $fail = $true; $script:KeptFail++; Write-Host ('  [남음] 보관본 속 로그인 파일을 읽지 못했습니다: ' + (Short $f) + ' - ' + $credNext); continue }
        if (-not $fi) { continue }
        if ($fi.PSIsContainer -or (Test-IsReparse $fi)) { continue }
        try { [System.IO.File]::Delete($f) } catch { }
        if (Test-PathOrLink $f) { $fail = $true; $script:KeptFail++; Write-Host ('  [남음] 보관본 속 로그인 파일 ' + (Short $f) + ' - ' + $credNext) }
        else { Write-Host ('  지움: 보관본 속 자비스 창 로그인 파일 ' + (Short $f) + ' (비밀값은 보관하지 않습니다 - 다시 설치하실 때 이어서 로그인됩니다)') }
    }
    if (-not $fail) {
        # 다 지웠는데 표지를 못 치우면 다음 실행마다 「남음」 으로 세게 된다 — 조용히 넘기지 않는다(r2 N4)
        $cm = Join-Path $h $CredMark
        try { [System.IO.File]::Delete($cm) } catch { }
        if (Test-Path -LiteralPath $cm -PathType Leaf) { $script:KeptFail++; Write-Host ('  [남음] 보관본 속 정리 표지 ' + (Short $cm) + ' - 로그인 파일은 지웠습니다. 그 폴더의 쓰기 권한을 확인해 주십시오.') }
    }
}
# 로그인 파일 정리가 남은 완전 삭제 보관본의 옛 ~\.cys(사용자 폴더 · 작업 폴더의 부모) — 되옮기기 표지가 있는 재설치 보관본은 뺀다(그 안 로그인은 되옮길 것)
function Get-CredPendingHomes {
    $parents = New-Object System.Collections.ArrayList
    [void]$parents.Add([string]$env:USERPROFILE)
    $jp = ''
    try { $jp = [string](Split-Path -Parent $JarvisDir) } catch { $jp = '' }
    if ($jp -and ((Norm-Slash $jp) -ine (Norm-Slash $env:USERPROFILE))) { [void]$parents.Add($jp) }
    $out = New-Object System.Collections.ArrayList
    foreach ($d in $parents) {
        $cands = @()
        try { $cands = @(Get-ChildItem -LiteralPath $d -Force -Directory -Filter ($JarvisBackupPrefix + '*') -ErrorAction Stop | Sort-Object Name) } catch { continue }
        foreach ($c in $cands) {
            $p = Join-Path $d $c.Name
            if (-not (Test-JarvisBackup $p)) { continue }
            if (Test-PathOrLink (Join-Path $p $RestoreMark)) { continue }
            $hs = @()
            try { $hs = @(Get-ChildItem -LiteralPath $p -Force -Directory -ErrorAction Stop | Where-Object { $_.Name -match '^cys-home(-[0-9]+)?$' }) } catch { continue }
            foreach ($hh in $hs) {
                if (Test-IsReparse $hh) { continue }
                $hp = Join-Path $p $hh.Name
                if (Test-Path -LiteralPath (Join-Path $hp $CredMark) -PathType Leaf) { [void]$out.Add($hp) }
            }
        }
    }
    return $out.ToArray()   # 부르는 쪽이 @(…) 로 받는다
}
function Resume-ArchivedCredentials {
    foreach ($hp in @(Get-CredPendingHomes)) {
        Write-Host ('  지난번에 끝나지 않은 보관본 속 로그인 파일 지우기를 이어서 합니다: ' + (Short $hp))
        Remove-ArchivedCredentials $hp
    }
}
# 재설치 길에서 ~\.cys 로 되옮길 것 = ~\.cys 기준 상대 이름 목록(구분 = \ · 한 층) — 목록을 못 읽으면 $null(「없음」과 가른다 · 0.3.36 반례 ④).
#   본부 = claude\ 안 $HistoryKeepNames(대소문자 무시) · 부서 = $ReinstallKeepTop. ~\.cys\claude 가 바로가기면 그 안은 보지 않는다.
function Get-ReinstallKeepList {
    $out = New-Object System.Collections.ArrayList
    $kids = $null
    try { $kids = @(Get-ChildItem -LiteralPath $CysHome -Force -ErrorAction Stop) } catch { return $null }
    foreach ($k in $kids) {
        foreach ($pat in $ReinstallKeepTop) { if ($k.Name -ilike $pat) { [void]$out.Add([string]$k.Name); break } }
    }
    $prof = Join-Path $CysHome 'claude'
    $pi = $null
    try { $pi = Get-Item -LiteralPath $prof -Force -ErrorAction Stop } catch { $pi = $null }
    if ($pi -and $pi.PSIsContainer -and -not (Test-IsReparse $pi)) {
        $pk = $null
        try { $pk = @(Get-ChildItem -LiteralPath $prof -Force -ErrorAction Stop) } catch { return $null }
        foreach ($k in $pk) {
            $n = [string]$k.Name
            if (@($HistoryKeepNames | Where-Object { $_ -ieq $n }).Count -gt 0) { [void]$out.Add('claude\' + $n) }
        }
    } elseif ((-not $pi) -and (Test-Path -LiteralPath $prof)) { return $null }
    return ,($out.ToArray())
}
# 예외 갈래(참가 자리가 ~\.cys 안 · DESIGN-0337 4-4절)의 부서 남길 것 — **자리** 실경로(바로가기도 자리로) · 목록 못 읽음·줄바꿈 = $null
function Get-DeptKeeps {
    $hc = Canon-Path $CysHome
    if (-not $hc) { return $null }
    $list = Get-ReinstallKeepList
    if ($null -eq $list) { return $null }
    $out = @()
    foreach ($r in $list) {
        if ([string]$r -match "[`r`n]") { return $null }
        if (([string]$r).StartsWith('claude\', [System.StringComparison]::OrdinalIgnoreCase)) { continue }
        $out += (Norm-Path ($hc + '\' + $r))
    }
    return ,$out
}
function Write-RestoreMark($mark, $recs) {   # 칸마다 NUL 로 끝난다(맥 printf '%s\0' 과 같은 모양) · UTF-8(BOM 없음)
    $sb = New-Object System.Text.StringBuilder
    foreach ($r in @($recs)) { [void]$sb.Append([string]$r); [void]$sb.Append([char]0) }
    [System.IO.File]::WriteAllText($mark, $sb.ToString(), (New-Object System.Text.UTF8Encoding($false)))
}
# 표지 고쳐 쓰기(r1 F3) — 임시 파일에 다 쓴 뒤 이름 바꾸기. 도중에 끊기거나 못 쓰면 옛 표지가 그대로 남는다($false · 임시 파일 치움).
function Save-RestoreMark($mark, $recs) {
    $tmp = $mark + '.tmp'
    try {
        Write-RestoreMark $tmp $recs
        if (Test-Path -LiteralPath $mark -PathType Leaf) { [System.IO.File]::Replace($tmp, $mark, $null) } else { [System.IO.File]::Move($tmp, $mark) }
        return $true
    } catch {
        try { [System.IO.File]::Delete($tmp) } catch { }
        return $false
    }
}
# 되옮기기 표지에 적힌 것을 보관 폴더의 cys-home 에서 ~\.cys 로 이름 바꾸기로 되옮긴다.
#   ~\.cys 에 같은 이름이 이미 있으면 덮지 않는다 — **되옮기기 실패와 같다**(r1 F2 · master#0337b3fa · DESIGN-0337 4절 5 · 10절):
#     그 이름은 보관 폴더에 그대로 · 표지에 남김 · 쉬운 말 1줄 · $false → 재설치를 멈춘다(rc 7). 옛 판은 건너뛰고 표지를 지워 rc 0 이었다.
#   하나라도 못 옮기면 표지에 남은 것만 적어 두고 못 지움 +1 · ArchiveFail · $false(다음 실행이 이어서 끝낸다) · 전부 끝나면 표지를 지운다.
function Restore-From($root) {
    $mark = Join-Path $root $RestoreMark
    if (-not (Test-Path -LiteralPath $mark -PathType Leaf)) { return $true }
    $recs = @()
    try {
        $text = (New-Object System.Text.UTF8Encoding($false, $true)).GetString([System.IO.File]::ReadAllBytes($mark))
        $recs = @($text.Split([char]0) | Where-Object { $_ -ne '' })
    } catch { $recs = @() }
    $hname = ''
    if ($recs.Count -gt 0) { $hname = [string]$recs[0] }
    if ($hname -notmatch '^cys-home(-[0-9]+)?$') {
        $script:KeptFail++; $script:ArchiveFail = 1
        Write-Host ('  [남음] 되옮기기 표지를 읽지 못했습니다: ' + (Short $mark) + ' - 자료는 보관 폴더에 그대로 있습니다.')
        return $false
    }
    if (-not (Test-PathOrLink $CysHome)) { try { [void][System.IO.Directory]::CreateDirectory($CysHome) } catch { } }
    $left = New-Object System.Collections.ArrayList
    [void]$left.Add($hname)
    $fail = $false
    for ($i = 1; $i -lt $recs.Count; $i++) {
        $rel = [string]$recs[$i]
        if ($rel -eq $hname) { continue }
        # 표지는 우리가 쓴 것이지만 손으로 고쳐졌을 수 있다 — ~\.cys 밖을 가리키는 칸(뿌리 · ..)은 되옮기지 않는다
        if ([System.IO.Path]::IsPathRooted($rel) -or ($rel -match '(^|[\\/])\.\.([\\/]|$)') -or ($rel -match ':')) {
            $fail = $true; [void]$left.Add($rel)
            Write-Host ('  [남음] 되옮기기 표지의 한 칸을 알아보지 못했습니다: ' + $rel + ' - 자료는 보관 폴더에 그대로 있습니다.')
            continue
        }
        $src = Join-Path (Join-Path $root $hname) $rel
        $dst = Join-Path $CysHome $rel
        if (-not (Test-PathOrLink $src)) { continue }   # 이미 되옮겼다
        # 되옮길 자리의 윗자리(~\.cys 안 · 예: ~\.cys\claude)가 바로가기면 따라가지 않는다 — 따라가면 ~\.cys 밖으로 옮겨진다(r2 N6)
        $lnk = ''
        $up = Split-Path -Parent ($rel -replace '/', '\')
        while ($up) { if (Test-IsReparsePath (Join-Path $CysHome $up)) { $lnk = $up }; $up = Split-Path -Parent $up }
        if ($lnk) {
            $fail = $true; [void]$left.Add($rel)
            Write-Host ('  [남음] ' + (Short (Join-Path $CysHome $lnk)) + ' 가 바로가기라 ' + (Short $dst) + ' 를 되옮기지 않았습니다 - 예전 자료는 보관 폴더에 그대로 있습니다: ' + (Short $src))
            continue
        }
        if (Test-PathOrLink $dst) {
            $fail = $true; [void]$left.Add($rel)
            Write-Host ('  [남음] ' + (Short $dst) + ' - 같은 이름의 자료가 이미 있어 덮지 않았습니다. 예전 자료는 보관 폴더에 그대로 있습니다: ' + (Short $src))
            Write-Host ('         새로 생긴 쪽(' + (Short $dst) + ')을 다른 이름으로 바꿔 두신 뒤 다시 실행하시면 예전 자료를 제자리로 옮깁니다 - 바꿔 둔 새 쪽은 그때 보관 폴더로 함께 옮겨집니다(어느 쪽도 지우지 않습니다).')
            continue
        }
        $dp = Split-Path -Parent $dst
        try { if (-not (Test-Path -LiteralPath $dp)) { [void][System.IO.Directory]::CreateDirectory($dp) } } catch { }
        try {
            Move-OneEntry $src $dst
            Write-Host ('  되옮김: ' + (Short $dst))
        } catch {
            $fail = $true; [void]$left.Add($rel)
            Write-Host ('  [남음] 되옮기지 못함: ' + (Short $src) + ' - 보관 폴더에 그대로 있습니다(지운 것 없음).')
        }
    }
    if (-not $fail) { try { [System.IO.File]::Delete($mark) } catch { }; return $true }
    if (-not (Save-RestoreMark $mark $left.ToArray())) {
        Write-Host '  [남음] 되옮기기 표지를 고쳐 쓰지 못해 지난 표지를 그대로 두었습니다 - 자료는 보관 폴더에 그대로 있고, 다시 실행하시면 이어서 옮깁니다.'
    }
    $script:KeptFail++; $script:ArchiveFail = 1
    return $false
}
# 끝나지 않은 되옮기기가 있는 우리 보관본(사용자 폴더 · 작업 폴더의 부모) — 오래된 것부터
function Get-UnfinishedRestoreDirs {
    $parents = New-Object System.Collections.ArrayList
    [void]$parents.Add([string]$env:USERPROFILE)
    $jp = ''
    try { $jp = [string](Split-Path -Parent $JarvisDir) } catch { $jp = '' }
    if ($jp -and ((Norm-Slash $jp) -ine (Norm-Slash $env:USERPROFILE))) { [void]$parents.Add($jp) }
    $out = New-Object System.Collections.ArrayList
    foreach ($d in $parents) {
        $cands = @()
        try { $cands = @(Get-ChildItem -LiteralPath $d -Force -Directory -Filter ($JarvisBackupPrefix + '*') -ErrorAction Stop | Sort-Object Name) } catch { continue }
        foreach ($c in $cands) {
            $p = Join-Path $d $c.Name
            if (-not (Test-JarvisBackup $p)) { continue }
            if (Test-Path -LiteralPath (Join-Path $p $RestoreMark) -PathType Leaf) { [void]$out.Add($p) }
        }
    }
    return $out.ToArray()   # 부르는 쪽이 @(…) 로 받는다
}
# 지난 재설치의 되옮기기가 도중에 끊겼으면(창이 닫힘 · 전원) **그것부터** 이어서 끝낸다 — 자료는 보관 폴더에 온전하다.
#   하나라도 못 끝내면 ResumeLeft — 이 실행의 ~\.cys 재설치 길은 이어 가지 않는다(r1 F2 · DESIGN-0337 10절 「이어 가지 않고 멈춘다」).
function Resume-UnfinishedRestore {
    $script:ResumeLeft = $false
    foreach ($p in @(Get-UnfinishedRestoreDirs)) {
        $hi = $null
        try { $hi = Get-Item -LiteralPath $CysHome -Force -ErrorAction Stop } catch { $hi = $null }
        if ($hi -and (Test-IsReparse $hi)) {
            $script:KeptFail++; $script:ArchiveFail = 1; $script:ResumeLeft = $true
            Write-Host ('  [남음] 되옮기기를 이어 가지 못했습니다: ' + (Short $CysHome) + ' 가 바로가기입니다 - 자료는 ' + (Short $p) + ' 에 그대로 있습니다.')
            continue
        }
        Write-Host ('  지난번에 끝나지 않은 되옮기기를 이어서 합니다: ' + (Short $p))
        if (-not (Restore-From $p)) { $script:ResumeLeft = $true }
    }
}
# ~\.cys 재설치 길(DESIGN-0337 4절 · 통째 보관 후 되옮기기): 통째로 보관 폴더로 옮긴 뒤 남길 것만 되옮긴다 — 지우는 것 0.
#   ★표지를 **옮기기 전에** 쓴다 — 옮긴 직후 멈춰도 다음 실행이 무엇을 되옮길지 안다.
#   ★되옮기기 하나라도 실패하면 재설치를 멈춘다(rc 7) — 로그인이 빠진 채 이어 가면 좌석이 「Login expired」 로 선다(0.3.36 결함 A).
function Invoke-CysHomeReinstall {
    $hi = $null
    try { $hi = Get-Item -LiteralPath $CysHome -Force -ErrorAction Stop } catch { $hi = $null }
    if (-not $hi) {
        if (-not (Test-Path -LiteralPath $CysHome)) { return $true }
        $script:KeptFail++; $script:ArchiveFail = 1
        Write-Host ('  [남음] ' + (Short $CysHome) + ' - 이 자리를 읽지 못해 아무것도 바꾸지 않았습니다.')
        return $false
    }
    if (Test-IsReparse $hi) {
        $script:KeptFail++
        Write-Host ('  [남음] ' + (Short $CysHome) + ' - 바로가기라 이전 대화를 제자리로 되옮길 수 없어 아무것도 바꾸지 않았습니다.')
        return $false
    }
    # ~\.cys\claude 자체가 바로가기면 못 푼다(0.3.36 규칙 그대로 · 맥 짝) — 이름표만 되옮기면 가리키는 곳의 옛 CLAUDE.md 가 새 판을 막고,
    #   안 되옮기면 새 자리에서 이전 대화가 안 보인다 ⇒ 아무것도 바꾸지 않고 멈춘다(가리키는 곳의 자료는 원래 무접촉).
    if (Test-IsReparsePath (Join-Path $CysHome 'claude')) {
        $script:KeptFail++
        Write-Host ('  [남음] ' + (Short (Join-Path $CysHome 'claude')) + ' - 바로가기라 이전 대화를 제자리로 되옮길 수 없어 아무것도 바꾸지 않았습니다.')
        return $false
    }
    # 지난번 되옮기기를 이번 실행에서 끝내지 못했으면(겹침 · 못 옮김) ~\.cys 를 또 옮기지 않는다 — 옛 자료가 보관본 두 곳으로 갈라진다.
    if ($script:ResumeLeft) {
        $script:KeptFail++; $script:ArchiveFail = 1
        Write-Host ('  [남음] 지난번 옮기기가 아직 끝나지 않아 이번에는 ' + (Short $CysHome) + ' 를 바꾸지 않았습니다.')
        Write-Host '         예전 자료는 보관 폴더에 그대로 있고, 위 [남음] 줄의 까닭이 풀린 뒤 다시 실행하시면 이어서 제자리로 옮깁니다.'
        return $false
    }
    $list = Get-ReinstallKeepList
    if ($null -eq $list) {
        $script:KeptFail++; $script:ArchiveFail = 1
        Write-Host ('  [남음] ' + (Short $CysHome) + ' - 남길 자리의 목록을 읽지 못해 아무것도 바꾸지 않았습니다.')
        return $false
    }
    if (-not (Set-ArchiveRoot)) {
        $script:KeptFail++; $script:ArchiveFail = 1
        Write-Host ('  [남음] ' + (Short $CysHome) + ' - 보관 폴더를 만들지 못해 그대로 두었습니다(지운 것 없음).')
        return $false
    }
    $markPath = Join-Path $script:ARoot $RestoreMark
    if (Test-PathOrLink $markPath) {
        # 이 보관 폴더에 아직 끝나지 않은 되옮기기가 있다 — 덮어쓰면 그 목록을 잃는다(자료는 남아도 제자리로 못 돌아온다).
        $script:KeptFail++; $script:ArchiveFail = 1
        Write-Host ('  [남음] 지난번 옮기기가 아직 끝나지 않아 이번에는 ' + (Short $CysHome) + ' 를 바꾸지 않았습니다.')
        Write-Host ('         자료는 ' + (Short $script:ARoot) + ' 에 그대로 있고, 다시 실행하시면 이어서 제자리로 옮깁니다.')
        return $false
    }
    $hname = Get-FreeRel $script:ARoot 'cys-home'
    try { Write-RestoreMark $markPath (@($hname) + @($list)) }
    catch {
        $script:KeptFail++; $script:ArchiveFail = 1
        Write-Host ('  [남음] 되옮기기 표지를 쓰지 못해 ' + (Short $CysHome) + ' 를 그대로 두었습니다(지운 것 없음).')
        return $false
    }
    $kf = $script:KeptFail
    $ok = Archive-Move $CysHome $hname 'cys 계정 자리(다시 까는 길 - 남길 것은 곧 제자리로 되옮깁니다)'
    if ((-not $ok) -or (Test-PathOrLink $CysHome)) {
        # 원자리가 그대로면 아무것도 안 옮긴 것 — 표지를 거둔다(자료는 원자리에 온전). 재설치는 여기서 멈춘다(옛 ~\.cys 위에 이어 가지 않는다).
        if (Test-PathOrLink $CysHome) { try { [System.IO.File]::Delete($markPath) } catch { } }
        $script:ArchiveFail = 1
        if ($script:KeptFail -eq $kf) { $script:KeptFail++ }
        return $false
    }
    try { [void][System.IO.Directory]::CreateDirectory($CysHome) } catch { }
    if (-not (Restore-From $script:ARoot)) { return $false }
    Write-Host '  남김: 자비스 창 로그인·이전 대화는 그대로 · 부서 등록부·부서 좌석 기록도 그대로 (다시 까는 길이라 보관 폴더에서 제자리로 되옮겼습니다)'
    return $true
}
# 완전 삭제 길 — 프로그램 폴더 안에서 프로그램 파일이 아닌 것(실행 기록 · 부서 상태 · 모르는 이름)을 보관 폴더로 옮긴다(DESIGN-0337 3-4절).
#   프로그램 파일은 보관 관문 **뒤에서** 지운다(Remove-CysProgramFiles). 폴더 자체가 바로가기면 여기서는 손대지 않는다(뒤에서 이름표만).
function Invoke-CysAppStateArchive($dir) {
    $di = $null
    try { $di = Get-Item -LiteralPath $dir -Force -ErrorAction Stop } catch { $di = $null }
    if (-not $di) {
        if (Test-Path -LiteralPath $dir) {
            $script:ArchiveFail = 1; $script:KeptFail++
            Write-Host ('  [남음] ' + (Short $dir) + ' - 이 자리를 읽지 못해 아무것도 옮기지 않았습니다.')
        }
        return
    }
    if (Test-IsReparse $di) { return }
    $kids = $null
    try { $kids = @(Get-ChildItem -LiteralPath $dir -Force -ErrorAction Stop) }
    catch {
        $script:ArchiveFail = 1; $script:KeptFail++
        Write-Host ('  [남음] ' + (Short $dir) + ' - 안의 목록을 읽지 못해 아무것도 옮기지 않았습니다.')
        return
    }
    foreach ($k in $kids) {
        if (Test-CysProgramItem $k) { continue }
        # 부서 실행 상태(cys-dept-<n>)는 맥과 같은 자리(cys-dept-state\) — 두 OS 보관 폴더 모양을 같게(DESIGN-0337 3-3절)
        if ([string]$k.Name -ilike 'cys-dept-*') { [void](Archive-Move (Join-Path $dir $k.Name) ('cys-dept-state\' + $k.Name) '부서 실행 상태'); continue }
        [void](Archive-Move (Join-Path $dir $k.Name) ('cys-app-state\' + $k.Name) 'cys 실행 기록')
    }
}
# 보관 관문 뒤 — 프로그램 폴더에서 프로그램 파일만 지우고, 비었으면 폴더도 지운다(설치 템플릿 RMDir "$INSTDIR" 와 같다 · 비었을 때만).
function Remove-CysProgramFiles($dir, $label) {
    $di = $null
    try { $di = Get-Item -LiteralPath $dir -Force -ErrorAction Stop } catch { $di = $null }
    if (-not $di) {
        if (Test-Path -LiteralPath $dir) { $script:KeptFail++; Write-Host ('  [남음] ' + $label + ' · ' + (Short $dir) + ' - 이 자리를 읽지 못해 지우지 않았습니다.') }
        return
    }
    $kids = $null
    try { $kids = @(Get-ChildItem -LiteralPath $dir -Force -ErrorAction Stop) }
    catch { $script:KeptFail++; Write-Host ('  [남음] ' + $label + ' · ' + (Short $dir) + ' - 안의 목록을 읽지 못해 지우지 않았습니다.'); return }
    foreach ($k in $kids) {
        if (Test-CysProgramItem $k) { Drop ($label + ' 파일') (Join-Path $dir $k.Name) }
    }
    $rest = $null
    try { $rest = @(Get-ChildItem -LiteralPath $dir -Force -ErrorAction Stop) } catch { $rest = $null }
    if (($null -ne $rest) -and ($rest.Count -eq 0)) { Drop $label $dir }
    elseif ($null -ne $rest) { Write-Host ('  남김: ' + (Short $dir) + ' - 프로그램 파일은 지웠고, 안에 남은 기록 ' + $rest.Count + '가지는 그대로 둡니다.') }
}
# ── 우리 설치 자리를 가리키는 등록·바로가기만 지운다(공식 제거기의 뒷정리 · installer.nsi:853~907 · 남의 같은 이름 항목 무접촉) ──
function Test-OurInstallDir($p) {   # 이 자리가 우리 설치 자리(%LOCALAPPDATA%\cys · 옛 Programs\cys)인가 — 글자 비교(대소문자 무시 · 따옴표 뗌)
    if (-not $p) { return $false }
    $x = Norm-Slash ([Environment]::ExpandEnvironmentVariables(([string]$p).Trim().Trim('"')))
    foreach ($d in @($CysDir, $CysDirOld)) { if ($d -and ($x -ieq (Norm-Slash $d))) { return $true } }
    return $false
}
function Get-ExePathOf($cmd) {   # 명령 줄에서 실행 파일 자리만(따옴표 안 · 따옴표가 없으면 .exe 까지)
    $s = ([string]$cmd).Trim()
    if ($s -match '^"([^"]+)"') { return $Matches[1] }
    if ($s -match '^(.+?\.exe)(\s|$)') { return $Matches[1] }
    return $s
}
function Test-OurExe($exe) {   # 우리 설치 자리 **바로 안의** 실행 파일인가
    if (-not $exe) { return $false }
    $e = Norm-Slash ([Environment]::ExpandEnvironmentVariables([string]$exe))
    if ($e -notmatch '(?i)\.exe$') { return $false }
    $i = $e.LastIndexOf('\')
    if ($i -le 0) { return $false }
    return (Test-OurInstallDir $e.Substring(0, $i))
}
function Get-RegValue($key, $name) {   # 값이 없거나 못 읽으면 $null
    try { $o = Get-ItemProperty -LiteralPath $key -Name $name -ErrorAction Stop; return $o.$name } catch { return $null }
}
function Test-OurUninstallKey($key) {   # 설치 목록 항목이 우리 설치 자리를 가리키는가(InstallLocation 또는 UninstallString 의 uninstall.exe 자리)
    if (Test-OurInstallDir (Get-RegValue $key 'InstallLocation')) { return $true }
    $exe = Get-ExePathOf (Get-RegValue $key 'UninstallString')
    if ((Test-OurExe $exe) -and ((Split-Path -Leaf (Norm-Slash $exe)) -ieq 'uninstall.exe')) { return $true }
    return $false
}
function Remove-RegKeyOurs($key, $label) {   # 이 계정(HKCU) 키만 · 하위 키째(레지스트리에는 링크가 없다)
    if (([string]$key) -notmatch '^HKCU:\\') { $script:KeptFail++; Write-Host ('  [남음] ' + $label + ' · ' + $key + ' - 다룰 수 있는 자리 모양이 아닙니다(지우지 않았습니다).'); return $false }
    try { Remove-Item -LiteralPath $key -Recurse -Force -ErrorAction Stop; $script:Removed++; Write-Host ('  지움: ' + $label + ' · ' + $key); return $true }
    catch { $script:KeptFail++; Write-Host ('  [남음] ' + $label + ' · ' + $key + ' - ' + $_.Exception.Message); return $false }
}
function Invoke-OurRegistryCleanup {
    # 0.3.37: 남겨야 할 자리를 확인하지 못한 실행은 프로그램 파일·바로가기를 안 지운다(Drop · Remove-OurShortcuts) —
    #   등록만 지우면 설정 앱 항목 없는 고아 프로그램이 남는다 ⇒ 등록도 함께 남긴다(프로그램과 한 쌍).
    if ($script:PreserveCanonFail.Count -gt 0) {
        $script:KeptFail++
        Write-Host '  [남음] cys 설치 목록 항목·설치 위치 기록·자동 실행 값 - 남겨야 할 자리를 확인하지 못해 프로그램과 함께 그대로 두었습니다.'
        return
    }
    # 설치 목록 항목(설정 앱 목록 · installer.nsi:880~887 · 옛 이름 nsis-hooks.nsh:863~868)
    foreach ($k in @($RegKeyR, $RegKey)) {
        if (-not (Test-Path -LiteralPath $k)) { continue }
        if (Test-OurUninstallKey $k) { [void](Remove-RegKeyOurs $k 'cys 설치 목록 항목') }
        else { Write-Host ('  남김: ' + $k + ' - 우리 설치 자리를 가리키지 않아 손대지 않았습니다(다른 설치일 수 있습니다).') }
    }
    # 설치 위치 기록 Software\<제조사>\<제품 이름> 기본값(installer.nsi:708·902~907) — 값이 우리 설치 자리일 때만
    $manuHit = $false
    foreach ($n in @('cysr', 'cys')) {
        $k = $ManuKey + '\' + $n
        if (-not (Test-Path -LiteralPath $k)) { continue }
        if (Test-OurInstallDir (Get-RegValue $k '(default)')) { if (Remove-RegKeyOurs $k 'cys 설치 위치 기록') { $manuHit = $true } }
        else { Write-Host ('  남김: ' + $k + ' - 우리 설치 자리를 가리키지 않아 손대지 않았습니다.') }
    }
    # 제조사 키가 이제 비었으면(하위 키·값 없음) 지운다 — 설치 템플릿 DeleteRegKey /ifempty 와 같다(installer.nsi:906)
    if ($manuHit -and (Test-Path -LiteralPath $ManuKey)) {
        $sub = $null
        try { $sub = @(Get-ChildItem -LiteralPath $ManuKey -Force -ErrorAction Stop) } catch { $sub = $null }
        $vals = @('?')
        try { $vals = @(@((Get-Item -LiteralPath $ManuKey -ErrorAction Stop).Property) | Where-Object { $_ }) } catch { $vals = @('?') }
        if (($null -ne $sub) -and ($sub.Count -eq 0) -and ($vals.Count -eq 0)) { [void](Remove-RegKeyOurs $ManuKey 'cys 제조사 기록(빈 칸)') }
    }
    # 자동 실행 값 Run\<제품 이름>(installer.nsi:893~895) — 값이 우리 실행 파일일 때만
    foreach ($n in @('cysr', 'cys')) {
        $v = Get-RegValue $RunKey $n
        if ($null -eq $v) { continue }
        if (Test-OurExe (Get-ExePathOf $v)) {
            try { Remove-ItemProperty -LiteralPath $RunKey -Name $n -ErrorAction Stop; $script:Removed++; Write-Host ('  지움: cys 자동 실행 값 (' + $n + ')') }
            catch { $script:KeptFail++; Write-Host ('  [남음] cys 자동 실행 값 (' + $n + ') - ' + $_.Exception.Message) }
        } else { Write-Host ('  남김: 자동 실행 값 ' + $n + ' - 우리 프로그램을 가리키지 않아 손대지 않았습니다.') }
    }
}
function Get-ShortcutTarget($lnk) {   # 바로가기가 가리키는 실행 파일 · 못 읽으면 ''(그때 부르는 쪽은 지우지 않는다 = 모르면 남김)
    try {
        $sh = New-Object -ComObject WScript.Shell
        return [string]$sh.CreateShortcut($lnk).TargetPath
    } catch { return '' }
}
function Remove-OurShortcuts {   # 시작 메뉴 · 바탕화면 — 대상이 우리 설치 자리 실행 파일일 때만(installer.nsi:853~877)
    $links = @(Get-StartMenuLinks) + @(Get-DesktopLinks)
    if ($links.Count -eq 0) { Write-Host '  [없음] cys 시작 메뉴 바로가기'; return }
    if ($script:PreserveCanonFail.Count -gt 0) {
        $script:KeptFail++
        Write-Host '  [남음] cys 바로가기 - 남겨야 할 자리를 확인하지 못해 이번에는 지우지 않았습니다.'
        return
    }
    foreach ($lnk in $links) {
        $li = $null
        try { $li = Get-Item -LiteralPath $lnk -Force -ErrorAction Stop } catch { $li = $null }
        if ((-not $li) -or $li.PSIsContainer -or (Test-IsReparse $li)) { continue }
        $t = Get-ShortcutTarget $lnk
        if (-not $t) { Write-Host ('  남김: ' + (Short $lnk) + ' - 가리키는 곳을 확인하지 못해 그대로 두었습니다(모르면 남깁니다).'); continue }
        if (-not (Test-OurExe $t)) { Write-Host ('  남김: ' + (Short $lnk) + ' - 우리 설치 자리를 가리키지 않아 손대지 않았습니다.'); continue }
        try { [System.IO.File]::Delete($lnk) } catch { }
        if (Test-PathOrLink $lnk) { $script:KeptFail++; Write-Host ('  [남음] cys 바로가기 · ' + (Short $lnk)); continue }
        $script:Removed++
        Write-Host ('  지움: cys 바로가기 · ' + (Short $lnk))
        # 폴더 안 바로가기(cys\cys.lnk · cysr\cysr.lnk)면 그 폴더도 — 비었을 때만(installer.nsi:861)
        $pd = Split-Path -Parent $lnk
        $pl = [string](Split-Path -Leaf $pd)
        if (($pl -ieq 'cys') -or ($pl -ieq 'cysr')) {
            try { if (@(Get-ChildItem -LiteralPath $pd -Force -ErrorAction Stop).Count -eq 0) { [System.IO.Directory]::Delete($pd, $false) } } catch { }
        }
    }
}
# ── 사전 훑기(읽기만 · 첫 변경 전 · DESIGN-0337 6-1절 ②③④) ──
#   옮길 자료 자리 아래 바로가기가 이 실행이 **지우는** 프로그램 자리를 가리키거나(그곳 자료가 사라진다) · 경로에 줄바꿈이 있거나 ·
#   목록을 못 읽으면 $false → 이 실행은 아무것도 바꾸지 않는다(rc 7).
#   남길 것(재설치) 안 바로가기가 ~\.cys 의 남길 것 밖을 가리키면 PrescanNote(멈추지 않음 · 가리키던 자료는 보관 폴더에 있다 = 반례 ①) —
#   단 참가 자리가 ~\.cys 안인 예외 갈래(남기고 지우기)에서는 그 자료가 지워지므로 못 풂(삭제 0).
#   ★목록은 한 층씩 훑고 바로가기 안으로 들어가지 않는다(Get-TreeItems) · 읽기 실패 = 못 풂(「Get-Item 읽기 실패 = 없음 모양」 함정).
$script:PrescanBad = ''
$script:PrescanNote = @()
function Test-UnderAny($p, $roots) {
    foreach ($r in @($roots)) { if ($r -and ((Path-IsSame $p $r) -or (Path-IsUnder $p $r))) { return $true } }
    return $false
}
function Invoke-Prescan {
    $script:PrescanBad = ''
    $script:PrescanNote = @()
    foreach ($s in @([string]$env:USERPROFILE, [string]$JarvisDir)) {
        if ($s -match "[`r`n]") { $script:PrescanBad = '(사용자 폴더나 작업 폴더 경로에 줄바꿈이 있습니다)'; return $false }
    }
    # 이 실행이 지우는 프로그램 자리(실경로)
    $proots = @()
    foreach ($p in @($ClaudeExe, $HomePs1, $TempPs1)) {
        if (Test-PathOrLink $p) { $c = Canon-Path $p; if ($c) { $proots += $c } }
    }
    $dataRoots = New-Object System.Collections.ArrayList
    foreach ($d in @($CysDir, $CysDirOld)) {
        $di = $null
        try { $di = Get-Item -LiteralPath $d -Force -ErrorAction Stop } catch { $di = $null }
        if (-not $di) {
            if (Test-Path -LiteralPath $d) { $script:PrescanBad = (Short $d) + ' (이 자리를 읽지 못했습니다)'; return $false }
            continue
        }
        if (Test-IsReparse $di) { continue }
        $kids = $null
        try { $kids = @(Get-ChildItem -LiteralPath $d -Force -ErrorAction Stop) } catch { $script:PrescanBad = (Short $d) + ' (목록을 읽지 못했습니다)'; return $false }
        $dc = ''
        if (-not $KeepApp) { $dc = Canon-Path $d; if (-not $dc) { $script:PrescanBad = (Short $d) + ' (실제 경로를 확인하지 못했습니다)'; return $false } }
        foreach ($k in $kids) {
            if (Test-CysProgramItem $k) { if ($dc) { $proots += (Norm-Path ($dc + '\' + $k.Name)) } }
            else { [void]$dataRoots.Add((Join-Path $d $k.Name)) }
        }
    }
    # 재설치 길의 남길 것(반례 ① 판정용 · 실경로)
    $keeps = @(); $hc = ''; $nested = $false
    if ($KeepHistory) {
        $hi = $null
        try { $hi = Get-Item -LiteralPath $CysHome -Force -ErrorAction Stop } catch { $hi = $null }
        if ((-not $hi) -and (Test-Path -LiteralPath $CysHome)) { $script:PrescanBad = (Short $CysHome) + ' (이 자리를 읽지 못했습니다)'; return $false }
        if ($hi -and $hi.PSIsContainer -and -not (Test-IsReparse $hi)) {
            $hc = Canon-Path $CysHome
            if (-not $hc) { $script:PrescanBad = (Short $CysHome) + ' (실제 경로를 확인하지 못했습니다)'; return $false }
            $list = Get-ReinstallKeepList
            if ($null -eq $list) { $script:PrescanBad = (Short $CysHome) + ' (목록을 읽지 못했습니다)'; return $false }
            foreach ($r in $list) {
                if ([string]$r -match "[`r`n]") { $script:PrescanBad = '(남길 자리 이름에 줄바꿈이 있습니다)'; return $false }
                $keeps += (Norm-Path ($hc + '\' + $r))
            }
            # 참가 자리가 ~\.cys 안인가(예외 갈래 · 4-4절) — 읽기만(보존 경로 실경로 풀기)
            Initialize-PreserveCanon
            $nested = (@(Get-PreservedUnder $hc).Count -gt 0)
        }
    }
    foreach ($r in @($CysHome, $JarvisDir, $CysTrash)) { [void]$dataRoots.Add($r) }
    foreach ($r in $dataRoots) {
        $ri = $null
        try { $ri = Get-Item -LiteralPath $r -Force -ErrorAction Stop } catch { $ri = $null }
        if (-not $ri) {
            if (Test-Path -LiteralPath $r) { $script:PrescanBad = (Short $r) + ' (이 자리를 읽지 못했습니다)'; return $false }
            continue
        }
        if (Test-IsReparse $ri) { continue }   # 뿌리 자체가 바로가기 = 이름표만 다룬다(안으로 안 들어간다)
        if (-not $ri.PSIsContainer) { continue }
        $items = @(Get-TreeItems $r)
        if ($script:EnumFail -gt 0) { $script:PrescanBad = (Short $r) + ' (목록을 끝까지 읽지 못했습니다)'; return $false }
        foreach ($it in $items) {
            if (-not (Test-IsReparse $it)) { continue }
            $full = [string]$it.FullName
            if ($full -match "[`r`n]") { $script:PrescanBad = (Short $full) + ' (경로에 줄바꿈이 있습니다)'; return $false }
            $t = Canon-Path $full
            if (-not $t) { continue }   # 끊긴 바로가기 = 뒤에 자료 없음
            if ($t -match "[`r`n]") { $script:PrescanBad = (Short $full) + ' (경로에 줄바꿈이 있습니다)'; return $false }
            if (Test-UnderAny $t $proots) {
                $script:PrescanBad = (Short $full) + ' -> ' + (Short $t) + ' (지울 프로그램 자리를 가리킵니다)'
                return $false
            }
            if ($keeps.Count -gt 0) {
                # 바로가기 **자리**의 실경로 = 부모 실경로 + 이름(Canon-Path 는 바로가기를 따라가 버린다)
                $pc = Canon-Path (Split-Path -Parent $full)
                $loc = ''
                if ($pc) { $loc = Norm-Path ($pc + '\' + $it.Name) }
                if ($loc -and (Test-UnderAny $loc $keeps) -and (Test-UnderAny $t @($hc)) -and -not (Test-UnderAny $t $keeps)) {
                    if ($nested) { $script:PrescanBad = (Short $full) + ' -> ' + (Short $t) + ' (남길 자리 밖을 가리킵니다)'; return $false }
                    $script:PrescanNote += (Short $full)
                }
            }
        }
    }
    return $true
}
# 끝 요약 한 줄 — 보관 폴더 자리와 크기(쉬운 말)
function Get-HumanSize($bytes) {
    $k = [long][Math]::Ceiling([double]$bytes / 1024)
    if ($k -ge 1048576) { return ('약 {0}.{1}GB' -f [long][Math]::Floor($k / 1048576), [long][Math]::Floor(($k % 1048576) * 10 / 1048576)) }
    if ($k -ge 1024) { return ('약 {0}MB' -f [long][Math]::Floor(($k + 1023) / 1024)) }
    return '1MB 미만'
}
function Write-ArchiveSummary {
    $seen = @()
    foreach ($d in @($script:ArchiveDest, $script:ArchiveHome)) {
        if (-not $d) { continue }
        if (-not (Test-Path -LiteralPath $d -PathType Container)) { continue }
        if (@($seen | Where-Object { $_ -ieq $d }).Count -gt 0) { continue }
        $seen += $d
        # 크기는 바로가기를 따라가지 않고 잰다(Get-TreeStat — junction 고리에서 끝없이 돌지 않는다) · 못 재면 크기 없이 말한다
        $st = Get-TreeStat $d
        $sz = ''
        if ($st) { $sz = ' (' + (Get-HumanSize ([long](([string]$st -split ' ')[1]))) + ')' }
        Write-Host ('    이전 자료는 ' + (Short $d) + ' 폴더에 모두 보관해 두었습니다' + $sz + '. 필요 없으시면 나중에 그 폴더를 지우셔도 됩니다.')
    }
}

# 우리가 홈에 **새로 넣은** 신뢰 키의 목록을 읽는다 — 설치기가 적어 둔 TSV(설정파일<탭>키).
#   ⚠파일이 없으면 빈 목록이다 ⇒ 홈 신뢰 칸에는 **손대지 않는다.** 모르는 것을 지우지 않는다.
#     (설치기가 그 키를 넣었다면 기록도 함께 남는다 — 기록이 없다는 것은 안 넣었다는 뜻이다.)
function Read-TrustSeedRecord {
    $f = Join-Path $JarvisDir 'trust-seed.tsv'
    if (-not (Test-Path $f)) { return @() }
    $rows = @()
    try {
        $raw = Read-TextUtf8 $f
        if ($null -eq $raw) { throw 'UTF-8 로 읽지 못했습니다' }
        foreach ($ln in ($raw -split "`r?`n")) {
            if (-not $ln) { continue }
            $parts = $ln -split "`t"
            if ($parts.Count -ge 2 -and $parts[0] -and $parts[1]) {
                $rows += ,@($parts[0], $parts[1])
            }
        }
    } catch {
        # ★기록을 못 읽은 것도 **정리 실패**다 — 그 기록이 든 폴더를 지우면 다시 해 볼 길이 사라진다.
        $script:TrustCleanupFail++
        Write-Host ('  [남음] 폴더 신뢰 기록을 읽지 못했습니다 — 홈 신뢰 칸은 손대지 않습니다: ' + $_.Exception.Message)
        return @()
    }
    return $rows
}
# 홈 쪽 — 우리가 넣은 신뢰 칸 하나만 뺀다 ─────────
#   ⛔`projects.<홈>` 칸을 **통째로 지우지 않는다** — 그 칸에는 참가자가 쌓은 값(allowedTools 등)이
#     함께 들어 있을 수 있다. 우리가 넣은 것은 `hasTrustDialogAccepted` 하나이므로 그 하나만 뺀다.
#   ★그 칸이 비면(우리가 만든 칸이었다는 뜻) 칸째 지운다 — 빈 칸을 남기면 다음 진단이 자국으로 센다.
function Remove-TrustSeed($file, $dirs) {
    if (-not (Test-Path $file)) { return }
    $raw = Read-TextUtf8 $file
    if ($null -eq $raw) {
        $script:KeptFail++; $script:TrustCleanupFail++
        Write-Host ("  [남음] " + (Short $file) + " 의 폴더 신뢰 칸 — 이 파일을 UTF-8 로 읽지 못했습니다. 손대지 않았습니다.")
        return
    }
    try {
        $o = $raw | ConvertFrom-Json -ErrorAction Stop
        $prj = $o.PSObject.Properties['projects']
        if ($null -eq $prj -or $null -eq $prj.Value) { return }
        $hit = 0
        foreach ($k in @($dirs)) {
            $ex = $prj.Value.PSObject.Properties[$k]
            if ($null -eq $ex -or $null -eq $ex.Value) { continue }
            $cur = $ex.Value.PSObject.Properties['hasTrustDialogAccepted']
            if ($null -eq $cur) { continue }
            # 🔴🔴**우리가 넣은 값과 같을 때만 지운다**(3차 N4 확정 2026-09-10 · 맥판은 이미 이렇게 한다).
            #   앞 판은 **칸이 있기만 하면** 지웠다. 기록한 뒤 사람이 그 값을 손수 `false` 로 바꾸셨다면
            #   그것은 이제 **그분의 선택**이다 — 기록이 있다고 남의 결정을 되돌리지 않는다.
            if ($cur.Value -ne $true) {
                Write-Host ("  남김: " + (Short $file) + " 의 " + (Short $k) + " 폴더 신뢰 칸 (우리가 넣은 값과 달라 손대지 않습니다: " + $cur.Value + ")")
                continue
            }
            $ex.Value.PSObject.Properties.Remove('hasTrustDialogAccepted')
            $hit++
            # 우리 칸 하나만 있던 자리면 이제 비었다 — 빈 칸은 남기지 않는다.
            if (@($ex.Value.PSObject.Properties).Count -eq 0) { $prj.Value.PSObject.Properties.Remove($k) }
        }
        if ($hit -eq 0) { return }
        $why = Write-JsonChecked $file $o
        if ($why) {
            $script:KeptFail++; $script:TrustCleanupFail++
            Write-Host ("  [남음] " + (Short $file) + " 의 폴더 신뢰 칸 — " + $why + " 원본은 그대로 두었습니다.")
            return
        }
        $script:Removed++
        Write-Host ("  지움: " + (Short $file) + " 의 폴더 신뢰 칸 " + $hit + "곳 (파일과 나머지 칸은 그대로)")
    } catch {
        $script:KeptFail++; $script:TrustCleanupFail++
        Write-Host ("  [남음] " + (Short $file) + " 의 폴더 신뢰 칸 — " + $_.Exception.Message)
    }
}
function Remove-OurHooks($file) {
    if (-not (Test-Hooks $file)) { return }
    $raw = Read-TextUtf8 $file
    if ($null -eq $raw) {
        $script:KeptFail++
        Write-Host ("  [남음] " + (Short $file) + " 의 각성 훅 — 이 파일을 UTF-8 로 읽지 못했습니다. 손대지 않았습니다.")
        return
    }
    try {
        $o = $raw | ConvertFrom-Json -ErrorAction Stop
        $h = $o.PSObject.Properties['hooks']
        if ($null -eq $h) { return }
        foreach ($ev in @($h.Value.PSObject.Properties.Name)) {
            $keep = @()
            foreach ($entry in @($h.Value.$ev)) {
                $s = ($entry | ConvertTo-Json -Depth 20 -Compress)
                if ($s -notmatch 'session-start|role-bootstrap') { $keep += $entry }
            }
            if ($keep.Count -gt 0) { $h.Value.$ev = $keep } else { $h.Value.PSObject.Properties.Remove($ev) }
        }
        if ($h.Value.PSObject.Properties.Name.Count -eq 0) { $o.PSObject.Properties.Remove('hooks') }
        $why = Write-JsonChecked $file $o
        if ($why) {
            $script:KeptFail++
            Write-Host ("  [남음] " + (Short $file) + " 의 각성 훅 — " + $why + " 원본은 그대로 두었습니다.")
            return
        }
        $script:Removed++; Write-Host ("  지움: " + (Short $file) + " 의 각성 훅 (다른 설정은 그대로)")
    } catch { $script:KeptFail++; Write-Host ("  [남음] " + (Short $file) + " 의 각성 훅 — " + $_.Exception.Message) }
}
function Remove-UserPathSeed {
    # ⚠사용자 Path 만 건드린다. 시스템 Path 는 손대지 않는다(관리자 권한이 필요하고 우리 것이 아니다).
    if (-not (Test-UserPathSeed)) { return }
    try {
        $u = [Environment]::GetEnvironmentVariable('Path','User')
        $seeds = @(Get-UserPathSeedDirs)
        $keep = @()
        foreach ($p in ($u -split ';')) {
            if (-not $p) { continue }
            if ($seeds -contains [Environment]::ExpandEnvironmentVariables($p).TrimEnd('\')) { continue }
            $keep += $p
        }
        [Environment]::SetEnvironmentVariable('Path', ($keep -join ';'), 'User')
        $script:Removed++; Write-Host '  지움: 사용자 실행 경로 등록 (시스템 쪽은 그대로)'
    } catch { $script:KeptFail++; Write-Host ("  [남음] 사용자 실행 경로 등록 — " + $_.Exception.Message) }
}

# footprint: W-LOGIN
# ★공식 명령을 먼저 쓴다 — 그 명령은 두 운영체제에서 같은 뜻이라 대칭이 저절로 맞는다.
#   자리를 직접 치우는 것은 클로드가 이미 없을 때의 폴백이다.
#   ⚠순서 제약: 로그아웃 명령이 클로드 안에 들어 있다. 클로드를 지우기 전에 부른다.
# 🔴**이 함수는 한 실행에 한 번만 돈다**(1차 BLOCK ① 확정 2026-09-10 · 맥과 같은 불변식).
#   맥에서는 재시도 루프가 이 자리를 되부르며 열쇠고리 항목을 하나씩 **최대 네 개** 지웠다.
#   윈도우는 파일 하나라 되불러도 결과가 같지만, ★불변식을 한쪽 OS 에만 두면 다음 사람이
#   「윈도우는 되불러도 되는 자리」로 읽고 그 위에 무언가를 얹는다. 두 판을 같게 둔다.
# 🔴🔴**함수 전체를 막은 것은 너무 넓었다**(2차 N1 확정 2026-09-10). 잠긴 로그인 파일 삭제가 처음
#   실패했을 때 사람이 잠금을 풀고 Enter 를 눌러도 이 함수가 통째로 건너뛰어졌고, 나머지가 성공하면
#   **파일이 남은 채 전체 성공**으로 끝났다 — 거짓 성공이다.
#   ⇒ 되돌릴 수 없는 것만 한 번으로 막는다(맥은 열쇠고리 직접 삭제가 그것이다). 윈도우에는 아직
#     그런 명령이 없지만 **이름과 자리를 맥과 같게 둔다** — 생기는 날 여기가 그 자리다.
#   여러 번 해도 결과가 같은 것(공식 logout · 파일 삭제)은 **재시도할 수 있게** 둔다.
$script:LoginKeychainDone = $false
function Invoke-PurgeLoginFirst {
    if (-not $PurgeLogin) { Write-Host '  남김: 로그인 (다음에 다시 하지 않으셔도 됩니다)'; return }
    $claude = Get-ClaudeCmd
    $done = $false
    if ($claude) {
        try { & $claude auth logout 2>&1 | Out-Null; if ($LASTEXITCODE -eq 0) { $done = $true } } catch { }
    }
    if ($done) { $script:Removed++; Write-Host '  지움: 로그인 (공식 로그아웃)'; return }
    if (Test-Path $CredFile) {
        try { Remove-Item $CredFile -Force -ErrorAction Stop; $script:Removed++; Write-Host '  지움: 로그인 (자리를 직접 치웠습니다)' }
        catch { $script:KeptFail++; Write-Host ("  [남음] 로그인 — " + $_.Exception.Message) }
    } else {
        Write-Host '  로그인: 우리가 아는 자리에는 지울 것이 없었습니다.'
    }
}

function Invoke-Purge {
    Write-Host ''
    Write-Host '=== 지웁니다 ==='

    # 🔴**자비스 폴더를 지우기 전에** 신뢰 씨앗 기록을 읽어 둔다(1차 REVISE ④ 확정 2026-09-10).
    #   그 기록 파일은 자비스 작업 폴더 안에 있고, 아래에서 그 폴더를 지운다 — 순서를 뒤집으면
    #   기록이 먼저 사라져 「우리가 넣은 것」과 「참가자의 것」을 영영 구별할 수 없다.
    # 0.3.37(맥 짝): 신뢰 칸 실패 깃발은 **이 회차가 다시 잰 값**이다 — 바로 아래 기록 읽기·칸 되돌리기가 이번 회차에 다시 돌며
    #   실패하면 다시 세운다(무조건 풀기가 아니다). 앞 판은 회차 사이에 안 풀어, 1회차에 잠깐 잠겼던 칸이 풀려도
    #   스스로 다시 해 보기 2·3회차가 늘 작업 폴더를 남기고 rc 7 로 끝났다.
    $script:TrustCleanupFail = 0
    $script:TrustSeedRows = @(Read-TrustSeedRecord)

    # ★남겨야 할 자리의 실경로를 **먼저 한 번에** 푼다. 하나라도 못 풀면 이 실행은 파일을 지우지 않는다.
    Initialize-PreserveCanon
    if ($script:PreserveCanonFail.Count -gt 0) {
        Write-Host ('  [남음] 남겨야 할 자리 ' + $script:PreserveCanonFail.Count + '곳의 실제 경로를 확인하지 못했습니다 - 이번에는 파일을 지우지 않습니다.')
        foreach ($bad in $script:PreserveCanonFail) {
            Write-Host ('         확인 못한 자리: ' + (Short $bad.path))
            Write-Host ('           까닭: ' + $bad.why)
        }
        Write-Host '         무엇을 남겨야 하는지 모르는 채로 지우면 참가 열쇠를 잃을 수 있습니다.'
        Write-Host '         그 자리를 살펴보신 뒤(링크가 끊겼거나 권한이 없을 수 있습니다) 아래 「다시 하시는 법」대로 다시 실행해 주십시오.'
    }

    # 0.3.37: 지난 재설치의 되옮기기가 도중에 끊겼으면(창이 닫힘 · 전원) **그것부터** 이어서 끝낸다(자료는 보관 폴더에 온전하다).
    Resume-UnfinishedRestore
    # r1 F4: 지난 실행에서 끝내지 못한 보관본 속 로그인 파일 지우기를 이어서 한다(어느 길이든 — 완전 삭제 보관본만)
    Resume-ArchivedCredentials

    # ★순서가 중요하다 — 등록을 떼는 명령과 로그아웃 명령이 지울 대상 **안에** 들어 있다.
    Invoke-PurgeLoginFirst

    # footprint: W-DAEMON
    $cys = Get-CysCmd
    $daemonDone = $false
    if ($cys) {
        try { & $cys daemon uninstall 2>&1 | Out-Null; $daemonDone = $true; Write-Host '  지움: cys 상시 가동 등록' } catch { }
    }
    # 🔴교차 검토 지적 채택(2026-09-08): 프로그램이 이미 없으면(사람이 손으로 지웠거나 백신이 날렸거나)
    #   위 명령을 부를 수단이 없어 **등록만 영원히 남는다.** 맥에는 폴백(launchctl bootout)이 있는데
    #   윈도우에는 없었다 — 두 OS 가 갈리는 자리였다. 스케줄러를 직접 떼는 길을 둔다.
    if (-not $daemonDone) {
        try {
            foreach ($tk in @(Get-CysTasks)) {
                Unregister-ScheduledTask -TaskName $tk.TaskName -Confirm:$false -ErrorAction Stop
                $script:Removed++; Write-Host ('  지움: cys 상시 가동 등록 (' + $tk.TaskName + ')')
            }
        } catch { $script:KeptFail++; Write-Host ('  [남음] cys 상시 가동 등록 — ' + $_.Exception.Message) }
    }

    # footprint: W-HOOK
    Remove-OurHooks $SettingsJs

    # footprint: W-APP
    # 0.3.37(DESIGN-0337 3-4절): 설정 앱 제거를 사람에게 시키지 않는다(사람 손 0) · 제거 프로그램도 띄우지 않는다(머리글의 까닭 ·
    #   -UseUninstaller 를 붙이셨을 때만 옛 방식). 순서 = 자리 기준 끄기 → 자료 보관(작업 폴더 · ~\.cys · 실행 기록 · 휴지통 · 앱 화면 자료)
    #   → 보관 관문 → 프로그램 파일 지우기 · 우리 설치 자리를 가리키는 설치 목록 항목 · 바로가기 · 설치 위치 기록 · 자동 실행 값.
    #   🔴앞 판의 설정 앱 안내 · 「제거를 마치셨으면 Enter」 고리 · 「이 폴더를 지웁니다」 확인은 사람이 할 수 없는 일을 요구하다 막힌 일이 셋이었다
    #     (설정 앱에 없는 항목을 여덟 번 요구 · Enter 만 믿고 뜯음 · 1.1.x 의 cysr 항목을 몰라 「설정 앱에는 cys 가 보이지 않습니다」 라는 틀린 말).
    $hasRegEntry = Test-Path $RegKey
    # cys 가 돌고 있으면 폴더·기록이 옮겨지지 않는다 — 먼저 자리 기준으로 끈다(R1 · 고아가 된 python3.exe 가 정확히 이 자리에서 걸렸다).
    #   ★끈 뒤에도 돌고 있으면(완전 삭제 길) 이번에는 아무것도 옮기지 않는다 — 스스로 다시 해 보기가 그 사이 창을 닫을 틈을 준다.
    $procBlocked = $false
    $alive = @(Stop-CysProcesses)
    if (($alive.Count -gt 0) -and (-not $KeepApp)) {
        $procBlocked = $true
        $script:SkipCysDir = $true
        $script:ArchiveFail = 1
        $script:KeptFail++
        Write-Host ('  [남음] cys 프로그램 — 아직 실행 중이라 옮기거나 지울 수 없어 이번에는 아무것도 옮기지 않았습니다(' + $alive.Count + '가지).')
        Write-AliveProcs $alive
        Write-Host '         cys 창을 모두 닫아 주십시오 — 닫힌 뒤 다시 해 보면 이어서 옮깁니다(자료는 원래 자리에 그대로 있습니다).'
    } elseif ($alive.Count -gt 0) {
        Write-Host ('  [주의] cys 자리에서 아직 ' + $alive.Count + '개가 돌고 있습니다 — 지난 편성 기록이 안 옮겨질 수 있습니다.')
        Write-AliveProcs $alive
    }

    # cys 계정 자리를 지우기 전에 토론장 안내 파일을 밖으로 옮겨 둔다(검토 지적 채택 2026-09-09).
    #   .cys\claude\skills\agora-delegate 는 cys 설치의 일부라 함께 사라지는 것이 맞다. 그런데 그대로 두면
    #   다시 깐 뒤 「아고라에 참가해」가 안 먹는 공백이 생긴다 - 참가 열쇠는 남았는데 쓰는 법만 없어진 꼴이다.
    #   밖(.claude\skills)에 같은 것이 없을 때만 옮긴다(있으면 손대지 않는다 = 멱등 · 손수 고친 것을 덮지 않는다).
    #   🔴🔴옮겼다고 말하기 전에 바이트를 대조한다(2차 검토 지적 채택). 앞 판은 Copy-Item 이 던지지만
    #   않으면 「옮겼습니다」라고 말한 뒤 원본을 지웠다 - 폴더만 생기고 알맹이가 반만 와도 그랬고,
    #   ★다음 실행은 「대상이 이미 있다」며 이전을 건너뛰어 반쪽이 영구히 고착된다.
    #   대조에 실패하면 원본(.cys)을 지우지 않는다(fail-closed). 사람 손 한 번이 유실보다 싸다.
    #   🔴🔴**「대상이 있다」로 이전을 마쳤다고 판정하지 않는다**(4차 지적 채택 2026-09-09).
    #   앞 판의 조건은 `-not (Test-Path $AgoraSkill)` 였다. 그래서 지난 실행이 **반쪽 대상을 남긴 채**
    #   (치우기가 잠김·권한으로 실패해서) 끝났으면, 다음 실행은 그 반쪽을 「이미 있다」로 읽고
    #   이 분기를 통째로 건너뛰어 $agoraMigrateOk 기본값 $true 로 .cys 원본을 지웠다.
    #   ⇒ 반쪽 고착을 막으려던 장치가 **재실행에서 스스로 그 고착을 완성**하고 있었다.
    #   ★판정 기준을 「있다」에서 **Test-TreeSame 통과**로 옮긴다 - 이전은 내용이 같을 때만 끝난 것이다.
    $agoraMigrateOk = $true
    if ((Test-Path -LiteralPath $AgoraSkillInCys) -and (Test-Path -LiteralPath $AgoraSkill)) {
        if (Test-TreeSame $AgoraSkillInCys $AgoraSkill) {
            # 이미 같은 것이 밖에 있다(멱등) - 덮지 않는다.
            Write-Host ('  이미 있음: 토론장 안내가 ' + (Short $AgoraSkill) + ' 에 그대로 있습니다(내용까지 대조했습니다).')
        } else {
            # 있는데 내용이 다르다 = 지난 실행의 반쪽이거나, 사람이 손수 고쳐 둔 것이다.
            #   어느 쪽인지 우리는 모른다 ⇒ 덮지도 지우지도 않고 **원본을 남긴다**(fail-closed).
            $agoraMigrateOk = $false
            $script:KeptFail++
            Write-Host ('  [남음] ' + (Short $AgoraSkill) + ' 에 있는 토론장 안내가 ' + (Short $AgoraSkillInCys) + ' 와 달라')
            Write-Host ('         ' + (Short $CysHome) + ' 를 지우지 않았습니다. 지웠다면 안 옮겨진 쪽이 사라졌을 것입니다.')
            Write-Host ('         까닭: ' + $script:TreeSameWhy)
            Write-Host '         지난번에 옮기다 만 것일 수도, 손수 고쳐 두신 것일 수도 있어 저희가 고르지 않습니다.'
            Write-Host ('         ' + (Short $AgoraSkill) + ' 를 손으로 정리하신 뒤 아래 「다시 하시는 법」대로 다시 실행해 주십시오.')
            Write-Host '         참가 열쇠·이름은 어느 경우에도 그대로 있습니다.'
        }
    } elseif ((Test-Path -LiteralPath $AgoraSkillInCys) -and -not (Test-Path -LiteralPath $AgoraSkill)) {
        $copied = $false
        $why = ''
        try {
            $parent = Split-Path -Parent $AgoraSkill
            if (-not (Test-Path -LiteralPath $parent)) { [void](New-Item -ItemType Directory -Path $parent -Force -ErrorAction Stop) }
            # ⚠`Copy-Item <폴더> -Destination <없는 폴더> -Recurse` 는 판본에 따라 안을 복사하기도,
            #   그 폴더째 안에 넣기도 한다. 어느 쪽이든 되게 하려고 목적지를 먼저 만들고 안엣것을 하나씩 옮긴다.
            # 🔴⛔와일드카드(`\*`)를 `-LiteralPath` 로 넘기지 마라 — **글자 그대로 `*` 라는 이름을 찾는다.**
            #   러너 실측(2026-09-09): 아무것도 복사되지 않았는데 **던지지도 않았다** ⇒ 목적지 폴더만 생겼다.
            #   ★바이트 대조가 그것을 잡았다(「파일 수가 다르다: 원본 1 · 옮긴 것 0」). 종료값만 봤다면
            #   「옮겼습니다」라고 말한 뒤 원본을 지웠을 것이다 — 이 축이 막으려던 바로 그 사고다.
            #   ⇒ 자식을 **하나씩 실제 경로로** 옮긴다(대괄호 든 이름에도 안전하다).
            if (-not (Test-Path -LiteralPath $AgoraSkill)) { [void](New-Item -ItemType Directory -Path $AgoraSkill -Force -ErrorAction Stop) }
            foreach ($child in @(Get-ChildItem -LiteralPath $AgoraSkillInCys -Force -ErrorAction SilentlyContinue)) {
                Copy-Item -LiteralPath $child.FullName -Destination $AgoraSkill -Recurse -Force -ErrorAction Stop
            }
            $copied = $true
        } catch { $copied = $false; $why = "복사가 실패했다: " + $_.Exception.Message }
        if ($copied) { if (-not (Test-TreeSame $AgoraSkillInCys $AgoraSkill)) { $why = $script:TreeSameWhy } }
        if ($copied -and -not $why) {
            Write-Host ("  옮김: 토론장 안내를 " + (Short $AgoraSkill) + " 로 옮겨 두었습니다(내용까지 같은지 확인했습니다).")
        } else {
            $agoraMigrateOk = $false
            $script:KeptFail++
            Write-Host ("  [남음] 토론장 안내를 밖으로 옮기지 못했습니다 - 그래서 " + (Short $CysHome) + " 를 지우지 않았습니다.")
            if ($why) { Write-Host ("         까닭: " + $why) }
            Write-Host '         지웠다면 그 안내가 영영 사라졌을 것입니다. 참가 열쇠·이름은 그대로 있습니다.'
            Write-Host ("         " + (Short $AgoraSkillInCys) + " 를 손으로 " + (Short $AgoraSkill) + " 에 옮기신 뒤 아래 「다시 하시는 법」대로 다시 실행해 주십시오.")
            # 반쪽만 생긴 대상은 치운다 - 치우기가 실패해도 이제는 안전하다(다음 실행이 위 「다르다」 갈래로
            #   들어가 원본을 남긴다). 앞 판은 이 치우기가 실패하면 다음 실행이 원본을 지웠다.
            if ((Test-Path -LiteralPath $AgoraSkill) -and -not (Test-TreeSame $AgoraSkillInCys $AgoraSkill)) {
                [void](Remove-TreeSafe $AgoraSkill)   # 여기도 `-Recurse` 를 쓰지 않는다(같은 까닭)
                if (Test-Path -LiteralPath $AgoraSkill) {
                    Write-Host ('         (옮기다 만 ' + (Short $AgoraSkill) + ' 도 치우지 못했습니다 - 그 자리를 손으로 정리해 주십시오.)')
                }
            }
        }
    }

    # 🔴**신뢰 키 정리를 작업 폴더 삭제보다 앞에 둔다**(2차 N4 확정 2026-09-10).
    #   기록 파일은 그 폴더 안에 있다. 폴더를 먼저 지우면, 키 정리가 실패했을 때 **다시 해 볼 근거가
    #   사라진다** — 재시도는 「기록 없음」으로 읽고 그 키를 영영 건너뛴다.
    #   ★순서가 곧 안전장치다: 근거를 없애는 일은 그 근거를 다 쓴 뒤에 한다.
    #   ⑵사용자 홈 = **기록에 적힌 것만** 뺀다. 우리가 넣은 키만 기록돼 있다(1차 REVISE ④).
    #   ⛔경로를 추측해서 지우지 않는다 — 그 추측이 참가자의 값을 지우던 자리였다.
    if ($script:TrustSeedRows.Count -eq 0) {
        Write-Host '  남김: 홈 폴더 신뢰 칸 (우리가 넣은 기록이 없어 손대지 않습니다)'
    } else {
        $byCfg = @{}
        foreach ($row in $script:TrustSeedRows) {
            if (-not $byCfg.ContainsKey($row[0])) { $byCfg[$row[0]] = @() }
            $byCfg[$row[0]] += $row[1]
        }
        foreach ($cfgPath in @($byCfg.Keys)) { Remove-TrustSeed $cfgPath $byCfg[$cfgPath] }
    }

    # footprint: W-JARVISHOME
    # 🔴🔴**신뢰 칸 정리에 실패했으면 이 폴더를 남긴다**(3차 N4 확정 2026-09-10). 기록 파일이 이 안에
    #   있다 — 지우면 **다시 해 볼 근거가 사라지고**, 다음 실행은 「기록 없음」으로 읽어 그 칸을
    #   영영 건너뛴다(참가자 컴퓨터에 우리 자국이 남는다).
    #   ★순서를 앞당긴 것만으로는 부족했다: 실패해도 그냥 이어서 지우고 있었다.
    if ($procBlocked) {
        Write-Host ('  [남김] ' + (Short $JarvisDir) + ' - cys 가 아직 돌고 있어 이번에는 옮기지 않았습니다(다음에 그대로 옮깁니다).')
    } elseif ($script:TrustCleanupFail -gt 0) {
        $script:KeptFail++
        Write-Host ('  [남음] ' + (Short $JarvisDir) + ' - 폴더 신뢰 칸을 다 되돌리지 못해 일부러 남겼습니다.')
        Write-Host '         이 폴더 안의 기록(trust-seed.tsv)이 있어야 다시 해 볼 수 있습니다.'
        Write-Host '         그 칸을 쓰고 있는 프로그램(클로드 창 등)을 닫으신 뒤 아래 「다시 하시는 법」대로 다시 실행해 주십시오.'
    } elseif (Test-SafeJarvisDir $JarvisDir) {
        Keep-JarvisDir $JarvisDir   # 0.3.36: 지우지 않고 보관 이동(위 Keep-JarvisDir)
    } elseif (Test-Path $JarvisDir) {
        $script:KeptFail++
        Write-Host ('  [남음] ' + (Short $JarvisDir) + ' - 안전 확인을 통과하지 못해 지우지 않았습니다.')
        Write-Host ('         까닭: ' + $script:SafeWhy)
        Write-Host '         그 자리는 손으로 확인해 주십시오. 확실하지 않은 자리를 재귀로 지우지 않습니다.'
    }

    if (-not $procBlocked) {
        # footprint: W-CYSHOME
        # 0.3.37(DESIGN-0337 3·4절): 지우지 않고 보관 폴더로 옮긴다 — 완전 삭제 = 통째로 · 재설치(-KeepHistory) = 통째로 옮긴 뒤 남길 것만 되옮긴다.
        #   ★작업 폴더 보관(위 Keep-JarvisDir)이 먼저다 — 그 보관 폴더에 모은다(Set-ArchiveRoot). 신뢰 칸 기록은 이미 위에서 다 썼다.
        #   참가 자리가 ~\.cys 안이면(사람이 AGORA_HOME 을 옮겨 둔 드문 경우) 통째로 옮길 수 없다 — 재설치는 0.3.36 장치(남기고 지우기)에
        #   부서 남길 것을 더해서, 완전 삭제는 옮기지 않고 그대로 둔다(Archive-Move 가 「남김」 으로 말한다 · 옮겼다 되돌리기 금지).
        if ($agoraMigrateOk) {
            $cysNested = $false
            $hi = $null
            try { $hi = Get-Item -LiteralPath $CysHome -Force -ErrorAction Stop } catch { $hi = $null }
            if ($hi -and $hi.PSIsContainer -and -not (Test-IsReparse $hi)) {
                $hcn = Canon-Path $CysHome
                if ($hcn -and (@(Get-PreservedUnder $hcn).Count -gt 0)) { $cysNested = $true }
            }
            if ($KeepHistory -and $cysNested) {
                # 🔴남길 자리가 있는데 실경로를 못 풀었으면 ~\.cys 를 **하나도 지우지 않고** 못 지움으로 센다(재설치는 여기서 멈춘다).
                $hk = Get-HistoryKeeps
                $dk = $null
                if ($hk.Fail.Count -eq 0) { $dk = Get-DeptKeeps }
                if ($hk.Fail.Count -gt 0) {
                    $script:KeptFail++
                    Write-Host ('  [남음] ' + (Short $CysHome) + ' - 남겨야 할 로그인·이전 대화 자리를 확인하지 못해 아무것도 지우지 않았습니다.')
                    foreach ($bad in $hk.Fail) { Write-Host ('         확인 못한 자리: ' + (Short $bad)) }
                    Write-Host '         확인할 수 없는 채로 지우면 로그인이나 이전 대화를 잃을 수 있습니다(바로가기가 끊겼거나 권한이 없을 수 있습니다).'
                } elseif ($null -eq $dk) {
                    $script:KeptFail++
                    Write-Host ('  [남음] ' + (Short $CysHome) + ' - 남겨야 할 부서 기록의 목록을 읽지 못해 아무것도 지우지 않았습니다.')
                } else {
                    Drop 'cys 계정 자리' $CysHome (@($hk.Canon) + @($dk))
                }
            } elseif ($KeepHistory) {
                if ($hi -or (Test-PathOrLink $CysHome)) { [void](Invoke-CysHomeReinstall) }
            } else {
                # 0.3.37(설계 결정 3): 보관한 옛 ~\.cys 자리를 회차 사이에 기억해 두고 **회차마다** 그 안 로그인 파일을 지운다 —
                #   앞 판은 이번 회차에 옮긴 때만 지워, 1회차 지우기가 실패하면 다시 해 보기가 그 파일을 안 보고 rc 0 으로 끝났다(비밀값이 보관 폴더에 남음).
                $script:ArchiveLast = ''
                if (Archive-Move $CysHome 'cys-home' 'cys 계정 자리(대화·부서 기록)') {
                    if ($script:ArchiveLast) { $script:CysHomeArchived = $script:ArchiveLast }
                    if ($script:CysHomeArchived) { Remove-ArchivedCredentials $script:CysHomeArchived }
                }
            }
        }
        # 프로그램 폴더 안 실행 기록 · 닫은 부서 휴지통 · 앱 화면 자료
        #   재설치(-KeepApp · -KeepHistory) = 지난 편성 기록만 보관(본부 좌석이 설치 도우미보다 먼저 뜨지 않게) · 나머지와 부서 상태(cys-dept-<n>)는 제자리
        #   완전 삭제 = 프로그램 폴더 안의 프로그램 파일이 아닌 것 전부 · 휴지통 · 앱 화면 자료를 보관(프로그램 파일은 관문 뒤에서 지운다)
        if ($KeepApp -or $KeepHistory) {
            foreach ($s in (Get-CysStateItems)) { [void](Archive-Move $s ('cys-state\' + (Split-Path -Leaf $s)) 'cys 지난 편성 기록') }
        } else {
            # footprint: W-DEPTSTATE
            foreach ($d in @($CysDir, $CysDirOld)) { Invoke-CysAppStateArchive $d }
            # footprint: W-TRASH
            [void](Archive-Move $CysTrash 'cys-trash' '닫은 부서 휴지통')
            # footprint: W-WEBVIEW
            [void](Archive-Move $WebviewRoaming 'webview-appdata' '앱 화면 자료')
            [void](Archive-Move $WebviewLocal 'webview-localappdata' '앱 화면 자료')
        }
    }

    # ── 보관 관문(0.3.37) — 옮기기·대조가 하나라도 어긋났으면 이 뒤(프로그램 지우기·설정 칸 빼기)를 하지 않는다 ──
    #   ⚠이미 끝난 것: 상시 가동 등록 떼기 · 프로세스 끄기 · 훅 떼기 · 신뢰 칸(설치 도우미가 다시 한다).
    #     사람 자료는 어느 쪽이든 한 곳(원자리 또는 보관 폴더)에 온전하다.
    if (($script:ArchiveFail -ne 0) -or ($script:ArchiveVerifyFail -ne 0)) {
        if ($script:KeptFail -eq 0) { $script:KeptFail = 1 }
        Write-Host '  [남음] 보관을 끝까지 마치지 못해 프로그램과 설정 칸은 지우지 않고 그대로 두었습니다.'
        Write-Host '         이전 자료는 원래 자리나 보관 폴더 한쪽에 그대로 있습니다 - 사라진 것은 없습니다.'
    } else {
        if ($KeepApp) {
            # 재설치 길(-KeepApp) — 프로그램 걷기를 통째로 건너뛴다. 재설치는 곧바로 다시 까는 길이라 프로그램을 지울 까닭이 없다.
            Write-Host '  남김: cys 프로그램 (재설치 — 지우지 않고 그대로 씁니다)'
            if ($hasRegEntry -or (Test-Path $RegKeyR)) { Write-Host '  남김: cys 설치 목록 항목 (프로그램과 한 쌍이라 함께 둡니다)' }
        } else {
            if ((Test-Path $UninstExe) -and $UseUninstaller) {
                Write-Host '  cys 제거 프로그램을 실행합니다. (백신이 이 행위를 막을 수 있습니다)'
                try {
                    $u = Start-Process -FilePath $UninstExe -ArgumentList '/S' -PassThru -ErrorAction Stop
                    if (-not $u.WaitForExit(180000)) { Write-Host '    제거 프로그램이 180초 안에 끝나지 않았습니다. 기다리기를 멈추고 나머지를 지웁니다.' }
                } catch {
                    Write-Host ("    제거 프로그램을 실행하지 못했습니다: " + $_.Exception.Message)
                    Write-Host '    백신이 막았을 수 있습니다. 그 화면의 이름, 대상 파일, 조치(차단·격리·종료)를 알려 주십시오.'
                }
                Start-Sleep -Seconds 3
            }
            if ((Test-Path $CysDir) -or (Test-Path $CysDirOld)) {
                # 프로그램 파일만 지운다(자료는 위에서 보관 폴더로 옮겼다) — 폴더 자체가 바로가기면 이름표만(가리키던 자리는 그대로)
                if (Test-IsReparsePath $CysDir) { Drop 'cys 프로그램' $CysDir } else { Remove-CysProgramFiles $CysDir 'cys 프로그램' }
                if (Test-IsReparsePath $CysDirOld) { Drop 'cys 프로그램(옛 자리)' $CysDirOld } else { Remove-CysProgramFiles $CysDirOld 'cys 프로그램(옛 자리)' }
            }
            # 공식 제거기가 해 주던 뒷정리 — 우리 설치 자리를 가리키는 것만(남의 같은 이름 항목 무접촉 · 모르면 남김)
            Remove-OurShortcuts
            # footprint: W-REG
            Invoke-OurRegistryCleanup
        }
        # footprint: W-CLAUDEBIN
        # ★지우기 직전에 그 자리에서 도는 클로드를 끈다(Stop-ClaudeUnderBin 참조) — 스스로 다시 해 보기(1/2)도 이 자리를 다시 지난다.
        $claudeAlive = @()
        if (Test-Path $ClaudeExe) { $claudeAlive = @(Stop-ClaudeUnderBin) }
        Drop '클로드 실행 파일' $ClaudeExe
        if ((Test-Path $ClaudeExe) -and ($claudeAlive.Count -gt 0)) { Write-AliveProcs $claudeAlive }
        # footprint: W-SCRIPTCOPY
        Drop '받아 둔 설치 스크립트' $HomePs1
        Drop '받아 둔 설치 스크립트(옛 자리)' $TempPs1
        # 남의 파일 속 우리 줄 — 파일을 지우지 않는다
        # footprint: W-PATH
        Remove-UserPathSeed
        # footprint: W-CLAUDEJSON
        Remove-JsonKey $ClaudeJson 'hasCompletedOnboarding'
        # 큰 화면 권유 질문을 미리 넘기려고 설치기가 99 로 적어 둔 칸이다. 우리 자국이니 우리가 뺀다.
        #   ⚠이 칸은 오래 전부터 심고 있었는데 표에 없어서 아무도 안 지웠다(2026-09-10 자국 표를 채우다 드러났다).
        Remove-JsonKey $ClaudeJson 'fullscreenUpsellSeenCount'
        # 폴더 신뢰 씨앗 — 설치기가 심은 자리를 되돌린다. **범위가 자리마다 다르다**(위 함수 머리글 참조).
        #   ⑴자비스 작업 폴더(백슬래시·슬래시 2형) = 우리가 만든 칸이므로 칸째 뺀다(맥판과 같아진다).
        Remove-ProjectEntry $ClaudeJson @($JarvisDir, ($JarvisDir -replace '\\','/'))
        # footprint: W-CLAUDESETTINGS
        Remove-JsonKey $SettingsJs 'theme'
        Remove-JsonKey $SettingsJs 'skipDangerousModePermissionPrompt'
        Remove-JsonKey $SettingsJs 'remoteControlAtStartup'
    }
    # 🔴**요청한 로그인 자국이 정말 사라졌는지 끝에서 다시 본다**(2차 N1 확정). 앞 판은 「지웠다」를
    #   그 순간의 종료값으로만 말했다 ⇒ 파일이 잠겨 남았는데 전체는 성공으로 끝났다.
    #   ★「지웠다」는 **다시 봐서 없을 때만** 참이다.
    if ($PurgeLogin -and (Test-Path $CredFile)) {
        $script:KeptFail++
        Write-Host ('  [남음] ' + (Short $CredFile) + ' - 로그인 파일이 아직 남아 있습니다.')
        Write-Host '         그 파일을 쓰고 있는 프로그램(클로드 창 등)을 닫으신 뒤 다시 해 주십시오.'
    }
    # 0.3.37 반례 ①(DESIGN-0337 6-1절): 되옮긴 자리 안 바로가기가 보관 폴더로 간 자리를 가리키면 한 줄 알린다(자료는 보관 폴더에 있다)
    if (@($script:PrescanNote).Count -gt 0) {
        Write-Host '  [안내] 아래 바로가기가 가리키던 자료는 보관 폴더(cys-home)에 그대로 있습니다 - 새 자리에서는 그 자료가 보이지 않을 수 있습니다.'
        foreach ($l in @($script:PrescanNote | Select-Object -First 5)) { Write-Host ('           ' + $l) }
    }
    # footprint: W-CLAUDEUSER — 손대지 않는다
    Write-Host '  남김: 클로드 대화·기록'

    Write-Host ''
    # 보존한 것이 있으면 반드시 말한다 - 「지웠는데 왜 남아 있지」를 미리 답한다.
    if ($script:Preserved -gt 0) {
        Write-Host ("    (참가 자리와 겹쳐 그대로 둔 자리 {0} 곳이 있습니다 - 위 「보존(중첩)」 줄)" -f $script:Preserved)
    }
    if ($script:KeptFail -eq 0) {
        Write-Host ("=== 끝났습니다 — {0} 가지를 지웠고, 못 지운 것은 없습니다. ===" -f $script:Removed)
        # 0.3.36 안내 1줄(보관 자리)은 0.3.37 부터 Write-ArchiveSummary 가 크기와 함께 말한다 — 작업 폴더를 못 옮긴 갈래의 안내만 따로 남긴다
        if ($script:BackupNote -and (-not $script:ArchiveDest)) { Write-Host ('    ' + $script:BackupNote) }
        Write-ArchiveSummary
        return 0
    }
    # 사실만 말한다. 「거의 다 됐다」로 얼버무리면 다음 단계가 그 위에 얹힌다.
    Write-Host ("=== 끝났습니다 — {0} 가지를 지웠고, {1} 가지를 못 지웠습니다. ===" -f $script:Removed, $script:KeptFail)
    Write-Host '    위에 [남음] 으로 표시된 자리가 있습니다. 그대로 두고 다시 설치하면 뒤엉킵니다.'
    Write-Host '    까닭은 보통 둘 중 하나입니다: 프로그램이 아직 돌고 있다 · 백신이 그 파일을 붙들고 있다'
    Write-Host '    아래 「다시 하시는 법」대로 한 번 더 해 보시고, 그래도 남으면 이 화면을 사진으로 남겨 알려 주십시오.'
    if ($script:BackupNote -and ((-not $script:ArchiveDest) -or ($script:ArchiveFail -ne 0) -or ($script:ArchiveVerifyFail -ne 0))) { Write-Host ('    ' + $script:BackupNote) }
    Write-ArchiveSummary
    return 7
}

# ── 본문 ──────────────────────────────────────────────────────────
Invoke-Diagnose
if ($ListOnly) { Write-Host ''; Write-Host '(보기만 했습니다. 아무것도 지우지 않았습니다.)'; exit 0 }

if ($script:Found -eq 0) { Write-Host ''; Write-Host '지울 것이 없습니다.'; exit 0 }

# ── 0.3.37 사전 훑기(읽기만 · 첫 변경 전 · DESIGN-0337 6-1절 ②③④) — 막히면 아무것도 바꾸지 않고 멈춘다 ──
if (-not (Invoke-Prescan)) {
    Write-Host ''
    Write-Host '이번에는 아무것도 바꾸지 않았습니다.'
    Write-Host ('   옮겨 둘 자료 가운데 확인할 수 없는 자리가 있습니다: ' + $script:PrescanBad)
    Write-Host '   그대로 지우면 그 자료가 사라질 수 있어 멈췄습니다. 그 바로가기나 폴더를 살펴보신 뒤 아래 「다시 하시는 법」대로 다시 실행해 주십시오.'
    Show-RerunHow
    exit 7
}

Write-Host ''
Write-Host '위 목록의 자료는 지우지 않고 보관 폴더로 옮깁니다(다시 받을 수 있는 프로그램 파일만 지웁니다). 보관 자리는 끝에 알려 드립니다.'
# ── 「cys 를 곧 끕니다」 (v0.3.10 · 실제 노트북에서 겪은 일 2026-09-10 · 맥판과 같다) ──
#   자리 기준으로 끄더라도 **사람에게 먼저 알린다**: 갑자기 꺼진 것으로 읽히지 않게 하고, 저장할 틈을 드린다.
#   0.3.37: 묻지 않는다(사람 손 0 · Enter 없음) — 알리고 5초 기다린 뒤 이 도구가 끈다. 재설치(-Yes)는 기다리지 않는다.
#   「지웁니다」 입력도 묻지 않는다 — 사람 자료는 보관 폴더로 옮기므로 되돌릴 수 있다. -Yes 는 받아서 넘긴다(옛 재설치 입구 호환).
$aliveNow = @(Get-ProcsUnder @($CysDir, $CysDirOld))
if ($aliveNow.Count -gt 0) {
    Write-Host ''
    Write-Host 'cys 를 곧 끕니다. 저장하지 않으신 것이 있으면 지금 저장해 주세요.'
    if (-not $Yes) {
        $noticeWait = 5
        if ([string]$env:JARVIS_NOTICE_WAIT -match '^[0-9]+$') { $noticeWait = [int]$env:JARVIS_NOTICE_WAIT }
        Start-Sleep -Seconds $noticeWait
    }
}

# ★남은 자리가 있으면 스스로 다시 해 본다 — 최대 2회 · 사이 5초(0.3.37 · 잠깐 붙들린 파일이 풀릴 틈 · Enter 를 묻지 않는다).
#   ⚠상한은 그대로 둔다 - 무한 고리는 「막혔다」를 영영 말하지 않는 것과 같다. 상한 뒤에는 사실대로 끝내고
#     **명령 전체를 인쇄**한다(재부팅이 필요한 자리는 재실행으로 안 풀린다).
function Reset-PurgeCounters {
    $script:Removed = 0
    $script:KeptFail = 0
    $script:Preserved = 0
    $script:SkipCysDir = $false
    $script:ArchiveFail = 0   # 보관 폴더(ArchiveDest·ArchiveHome)는 이어 쓴다 — 끝 요약이 첫 번째 것도 말하게 · 대조 실패(ArchiveVerifyFail)는 풀지 않는다
    $script:Archived = 0
}
$rc = Invoke-Purge
$tries = 0
while (($rc -ne 0) -and ($tries -lt 2)) {
    $tries++
    $retryWait = 5
    if ([string]$env:JARVIS_RETRY_WAIT -match '^[0-9]+$') { $retryWait = [int]$env:JARVIS_RETRY_WAIT }
    Write-Host ''
    Write-Host ('  남은 자리가 있어 ' + $retryWait + '초 뒤 스스로 한 번 더 해 봅니다 (' + $tries + '/2 · 창을 닫지 말고 기다려 주세요).')
    Start-Sleep -Seconds $retryWait
    Reset-PurgeCounters
    if (-not (Invoke-Prescan)) { Write-Host ('  확인할 수 없는 자리가 생겨 다시 해 보기를 멈췄습니다(아무것도 더 바꾸지 않았습니다): ' + $script:PrescanBad); break }
    $rc = Invoke-Purge
}
if ($rc -ne 0) { Show-RerunHow }
exit $rc
