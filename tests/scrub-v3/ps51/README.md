# tests/scrub-v3/ps51/ — 윈 5.1 러너에서 돌릴 것(관문 5 · 실행 = master)

TICKET=scrub-v3-port-1116 · ROLE=win 이 **준비만** 했다(이 좌석은 러너를 돌리지 않는다). 전부 네트워크 0 · 임시 폴더에만 쓴다.
저장소 뿌리에서(일곱째 줄은 검증 좌석 폴더를 옮긴 자리에서 · windows-latest · `powershell.exe` = Windows PowerShell 5.1 · `pwsh` = 견줌):

```
powershell.exe -NoProfile -ExecutionPolicy Bypass -File tests\scrub-v3\ps51\ps51-enc-probe.ps1
powershell.exe -NoProfile -ExecutionPolicy Bypass -File tests\scrub-v3\ps51\bench.ps1 -Shapes ps-ac
powershell.exe -NoProfile -ExecutionPolicy Bypass -File tests\scrub-v3\ps51\bench-port.ps1 -Dir install-master
node tests\scrub-v3-win.mjs --pwsh powershell.exe --n 6000 --jsonl win51-random-6000x2.jsonl
powershell.exe -NoProfile -ExecutionPolicy Bypass -File tests\scrub-v3\ps51\clm-probe.ps1
pwsh -NoProfile -File tests\scrub-v3\ps51\bench.ps1 -Shapes ps-ac -Cases log,email,hits
$env:PWSH='powershell.exe'; $env:WIN_DIR='install-master'; $env:SRV_SCRUB='<web-install\src\scrub.ts>'; node --experimental-strip-types repro\diff3.mjs --jobs work\jobs.jsonl --work work\diff51 --skip-mac   # PowerShell 꼴
```

| 줄 | 무엇 | 볼 것 |
|---|---|---|
| 1 | 설계 좌석 `split/ps51-enc-probe.ps1` 사본 | 끝 줄 `PROBE-SUMMARY` — `transcript_head3=[EF BB BF]` · (1) 절 세 줄 전부 `text · hangulKept=yes` · (3) 절에서 `text` 인 것이 「UTF-8 머리표」 하나뿐. 머리가 `FF FE` 면 그 출력을 근거로 master 에(윈에만 UTF-16LE 읽기를 더할지 = 설계 6절) |
| 2 | 앞 좌석 `ps51-bench/bench.ps1` 사본(측정 스크립트 · 제품 아님) | `VECTORS ps-ac 84/84` · `SUMMARY ps-ac mismatch=0` · 3회 돌려 같은가 |
| 3 | **제품 함수**(`bootstrap.ps1` 의 `Invoke-RemoteHelpScrub` · `Invoke-RemoteHelpScrubField`)를 같은 꼴·같은 기대 해시로 | `SUMMARY port mismatch=0` · `FIELD` 줄의 921600 꼴 시간과 `full:budget` 수(예산 20초를 넘는 꼴이 있는가 = 그 꼴의 첨부가 통째 가림이 되는가) |
| 4 | 관문 1·2 를 **5.1 에서**(node 가 일을 만들고 `powershell.exe` 가 제품 함수를 돈다) | `관문 1 — 공용 벡터 161/161` · `관문 2 … 위반 0` · `RESULT: PASS`(5.1 의 엄격한 UTF-8 디코더가 손 검사기와 같은지도 attach 갈래 6,000건이 잰다) |
| 5 | 앞 좌석 `clm-probe.ps1` 사본 | 끝 줄 `FULL-MASK` |
| 6 | pwsh 7 이 느린가(앞 좌석 남은 물음) | `log·email·hits` 의 65K → 262K → 921K 가 네 배씩인가 |
| 7 | 독립 검증 좌석 `~/axdev/reviews/scrub-port-verify-1116/` 의 `repro/diff3.mjs`(REPORT 6절 끝 제안) — **실물 `Send-RemoteHelpReport`(HTTP 만 가로챔)와 `Get-ScrubbedTextBytes` 를 5.1 에서** 2,406건. 6절 표의 2·3·4·5·12(`Get-Content -Encoding UTF8` · `ConvertTo-Json` 의 5.1 이스케이프 · 크기 맞추기 반복 등)를 한 번에 지나간다 | 누출(indexOf)이 0 인가(고침 1회 뒤 H1 꼴도 닫힘) · 윈에서는 `WindowsIdentity` 이름이 더해져 차이 표는 무시. ⚠그 폴더의 `repro/`·`work/jobs.jsonl` 을 러너로 옮겨야 한다(이 저장소에 없음) |

- **사본과 원본의 차이 하나**: `ps51-enc-probe.ps1` 맨 앞에 UTF-8 머리표 3바이트(`EF BB BF`)를 붙였다 — 원본에는 머리표가 없고 코드 줄에 한글 글자(`'가나다 …'` · `'<전부 지움>'`)가 있어, 5.1 이 ANSI 로 읽으면 그 글자가 깨진 채 비교된다(재는 뜻이 흐려진다). 그 밖의 다섯 파일은 바이트 그대로(`SHA256SUMS`).
- 제한 언어 모드에서 **설치기 전체 경로**가 닫히는지(보낸 본문의 모든 글 칸이 `<전부 지움>`)는 이 폴더가 재지 않는다 — 실기 항목(설계 물음 5 ⓑ 해소 판정).
