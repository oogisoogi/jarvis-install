# jarvis-install — 자비스 설치 도우미

터미널에 한 줄을 붙여넣으면 설치 도우미가 컴퓨터를 살펴보고, 클로드(Claude Code)와 cys를 설치하고, cys 창 안에서 자비스를 깨웁니다. AI 자비스 워크숍 참가자용입니다.

참가자 안내 페이지: https://jarvis.godmeyou.kr/install/

## 윈도우

1. 시작 메뉴에서 `powershell`을 검색해 **Windows PowerShell**을 엽니다. 「관리자 권한으로 실행」이나 「(x86)」이 붙은 것은 고르지 마십시오.
2. 아래 한 줄을 통째로 붙여넣고 Enter를 누릅니다.

```
irm https://jarvis.godmeyou.kr/install/bootstrap.ps1 -OutFile $env:TEMP\install-jarvis.ps1; powershell -ExecutionPolicy Bypass -File $env:TEMP\install-jarvis.ps1
```

## 맥

1. **Terminal**(터미널) 앱을 엽니다.
2. 아래 한 줄을 통째로 붙여넣고 Enter를 누릅니다.

```
curl -fsSL https://jarvis.godmeyou.kr/install/bootstrap.sh -o "$HOME/install-jarvis.sh" && bash "$HOME/install-jarvis.sh"
```

## 진행 순서

설치는 열한 단계로 진행됩니다. 화면에 `[1/11]`부터 `[11/11]`까지 차례로 나옵니다. 마지막 `[11/11]`은 워크숍 토론장(아고라) 참가 등록으로, 지금 되지 않으면 이유를 말하고 넘어갑니다. 중간에 멈춘 것처럼 보여도 기다려 주십시오. 무엇을 하고 있는지 화면이 계속 알려 드립니다.

## 사람이 하실 일은 세 가지입니다

1. **로그인 승인** — 브라우저가 열리면 Claude 로그인을 승인해 주십시오. 승인 후 창은 닫으셔도 됩니다.
2. **보안 경고** — 파란 「Windows에서 PC를 보호했습니다」 창이 뜨면 **[추가 정보] → [실행]**. 서명되지 않은 프로그램에 뜨는 알려진 경고입니다.
3. **마지막 한마디** — 설치가 끝나면 cys 창에 **jarvis**라는 창이 열립니다. 거기에 **「너는 마스터다」**라고 직접 쳐 주십시오. 이 한마디만은 설치 도우미가 대신 쳐 드릴 수 없습니다. 사람이 직접 친 말만 팀을 부르도록 안전장치가 걸려 있기 때문이며, 설치 도우미는 그 장치를 우회하지 않습니다.

## 백신이 「악성코드 차단」이라고 뜨면

설치 도우미가 서명 없는 설치 프로그램을 띄우는 것을 백신이 막은 것입니다. 그 화면의 이름 · 대상 파일 · 조치(차단 · 격리 · 종료)가 보이게 사진으로 남겨 주십시오. 허용을 누를지는 쓰시는 분의 판단이며, 설치 도우미가 대신 백신 예외를 등록하지 않습니다.

화면이 아무 말 없이 닫혔다면 백신이 PowerShell을 종료한 것입니다. 그때는 아무것도 지워지거나 설치되지 않습니다. 같은 한 줄을 다시 치시면 끝난 단계는 건너뛰고 이어서 진행됩니다.

## 끝났는지 확인하는 법

화면에 **「함대가 섰습니다: master · cso · worker」**가 나오고, cys 창에 자비스와 동료들의 창이 열려 있으면 끝난 것입니다.

## 삭제하고 재설치하기

중간에 멈췄거나 뭔가 꼬인 것 같을 때 쓰십시오. 지금 상태가 어떻든 깨끗이 지우고 처음부터 다시 깝니다. 먼저 무엇을 지울지 목록으로 보여 드리고 한 번 여쭙니다. 그때 그만두셔도 됩니다.

- **되돌릴 수 없습니다.** 「지웁니다」라고 치시면 그때부터 지워집니다.
- **로그인은 그대로 둡니다.** 다시 깐 뒤에도 로그인 화면이 다시 뜨지 않습니다.
- **사진·문서·내려받기 같은 파일은 손대지 않습니다.** 설치 도우미가 놓은 것만 지웁니다.

윈도우 — PowerShell:

```
powershell -NoProfile -ExecutionPolicy Bypass -Command "irm https://jarvis.godmeyou.kr/install/reinstall.ps1 -OutFile ([Environment]::GetFolderPath('UserProfile')+'\reinstall-jarvis.ps1'); powershell -ExecutionPolicy Bypass -File ([Environment]::GetFolderPath('UserProfile')+'\reinstall-jarvis.ps1')"
```

맥 — 터미널:

```
curl -fsSL https://jarvis.godmeyou.kr/install/reinstall.sh -o "$HOME/reinstall-jarvis.sh" && bash "$HOME/reinstall-jarvis.sh"
```

지우지 않고 무엇이 깔려 있는지만 보시려면 `reset-clean.sh --list`(맥) 또는 `reset-clean.ps1 -List`(윈도우)를 쓰십시오. 아무것도 바꾸지 않고 목록만 보여 드립니다. 윈도우에서 cys 프로그램은 설정 → 앱에서 직접 제거하셔야 합니다(스크립트가 그 화면으로 안내합니다).

계정을 바꾸고 싶으신 경우는 다른 일입니다. 창에 `claude auth logout`을 치신 뒤 다시 로그인하시면 됩니다. 다시 깔 필요는 없습니다.

## 파일

| 파일 | 역할 |
|---|---|
| `bootstrap.ps1` | 윈도우 설치 도우미 (PowerShell 5.1 이상) |
| `bootstrap.sh` | 맥 설치 도우미 (bash) |
| `reinstall.ps1` | 윈도우 삭제 후 재설치 진입점 (지우기가 실패하면 설치로 넘어가지 않음) |
| `reinstall.sh` | 맥 삭제 후 재설치 진입점 |
| `reset-clean.ps1` | 윈도우 상태 진단(`-List`)·깨끗이 지우기 |
| `reset-clean.sh` | 맥 상태 진단(`--list`)·깨끗이 지우기 |

이 스크립트는 사용자 폴더 안에서만 동작하며 관리자 권한을 요구하지 않습니다. 설치는 클로드 공식 설치 경로와 cys 공식 배포 파일만 사용합니다.

## 라이선스

MIT

## 원작자 표기

이 설치 도우미가 설치하는 cys 터미널의 원작자는 CYSJavis(GitHub: idoforgod)입니다. 설치 도우미가 내려받는 cys 배포본은 원작자의 허락을 받아 oogisoogi가 원작(MIT)을 바탕으로 빌드·서명·배포하는 파생판입니다. 원작 저장소: https://github.com/idoforgod/cys-terminal
