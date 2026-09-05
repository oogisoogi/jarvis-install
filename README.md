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
curl -fsSL https://jarvis.godmeyou.kr/install/bootstrap.sh -o /tmp/install-jarvis.sh && bash /tmp/install-jarvis.sh
```

## 진행 순서

설치는 열 단계로 진행됩니다. 화면에 `[1/10]`부터 `[10/10]`까지 차례로 나옵니다. 중간에 멈춘 것처럼 보여도 기다려 주십시오. 무엇을 하고 있는지 화면이 계속 알려 드립니다.

## 사람이 하실 일은 세 가지입니다

1. **로그인 승인** — 브라우저가 열리면 Claude 로그인을 승인해 주십시오. 승인 후 창은 닫으셔도 됩니다.
2. **보안 경고** — 파란 「Windows에서 PC를 보호했습니다」 창이 뜨면 **[추가 정보] → [실행]**. 서명되지 않은 프로그램에 뜨는 알려진 경고입니다.
3. **마지막 한마디** — 설치가 끝나면 cys 창에 **jarvis**라는 창이 열립니다. 거기에 **「너는 마스터다」**라고 직접 쳐 주십시오. 이 한마디만은 설치 도우미가 대신 쳐 드릴 수 없습니다. 사람이 직접 친 말만 팀을 부르도록 안전장치가 걸려 있기 때문이며, 설치 도우미는 그 장치를 우회하지 않습니다.

## 백신이 「악성코드 차단」이라고 뜨면

설치 도우미가 서명 없는 설치 프로그램을 띄우는 것을 백신이 막은 것입니다. 그 화면의 이름 · 대상 파일 · 조치(차단 · 격리 · 종료)가 보이게 사진으로 남겨 주십시오. 허용을 누를지는 쓰시는 분의 판단이며, 설치 도우미가 대신 백신 예외를 등록하지 않습니다.

화면이 아무 말 없이 닫혔다면 백신이 PowerShell을 종료한 것입니다. 그때는 아무것도 지워지거나 설치되지 않습니다. 같은 한 줄을 다시 치시면 끝난 단계는 건너뛰고 이어서 진행됩니다.

## 끝났는지 확인하는 법

화면에 **「함대가 섰습니다: master · cso · worker」**가 나오고, cys 창에 자비스와 동료들의 창이 열려 있으면 끝난 것입니다.

## 깨끗이 지우기 (처음 상태로 되돌리기)

설치 도우미가 놓은 것과 cys · 클로드를 모두 지웁니다. 되돌릴 수 없고, 로그인도 지워집니다. 먼저 윈도우 설정 → 앱에서 cys를 제거한 뒤 실행하십시오.

```
irm https://jarvis.godmeyou.kr/install/reset-clean.ps1 -OutFile $env:TEMP\reset-clean.ps1; powershell -ExecutionPolicy Bypass -File $env:TEMP\reset-clean.ps1
```

## 파일

| 파일 | 역할 |
|---|---|
| `bootstrap.ps1` | 윈도우 설치 도우미 (PowerShell 5.1 이상) |
| `bootstrap.sh` | 맥 설치 도우미 (bash) |
| `reset-clean.ps1` | 윈도우 깨끗이 지우기 |

이 스크립트는 사용자 폴더 안에서만 동작하며 관리자 권한을 요구하지 않습니다. 설치는 클로드 공식 설치 경로와 cys 공식 배포 파일만 사용합니다.

## 라이선스

MIT
