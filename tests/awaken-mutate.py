#!/usr/bin/env python3
# 뮤턴트 — [9/10]~[10/10] 자동 각성(2026-09-15) 수정이 「실제로 서 있는가」를 재는 도구
#
# ★쓰는 법
#   python3 tests/awaken-mutate.py --root <저장소>           전건(사본에서만 고친다 · 실물 무접촉)
#   python3 tests/awaken-mutate.py --root <저장소> --audit   앵커가 아직 1곳씩 걸리는가만
#   python3 tests/awaken-mutate.py --root <저장소> --only a,b 이름을 골라서
#
# ★판정 = 기준선(변이 없음)에서 **초록**이던 축이, 변이를 넣은 사본에서 **붉어졌는가**(tests/v0317-mutate.py 와 같은 규칙).
#   기준선에서 이미 붉은 축을 기대로 쓰면 「공짜 적색」이라 실격 · 앵커가 1곳이 아니면 rc 3 · 변이가 안 들어갔으면 측정 실패.
# ⚠판정은 러너 출력의 「  FAIL 」 줄에 기대 축 이름이 있는가로 한다 — 러너가 죽으면 FAIL 줄이 없어 「눈멂」으로 드러난다.
import argparse, os, pathlib, shutil, subprocess, sys, tempfile

for _s in (sys.stdout, sys.stderr):
    try: _s.reconfigure(encoding="utf-8", errors="backslashreplace")
    except Exception: pass

PS = "install-master/bootstrap.ps1"
SH = "install-master/bootstrap.sh"
# (이름, 파일, 찾을 것, 바꿀 것, 붉어져야 할 축 조각)
MUTANTS = [
    # 실측 검증 제거 — 동료 자리를 안 보고 「깨어났습니다」
    ("seat-judge-drop", PS,
     "    if (Test-DeclarationSeen $live) {\n        Write-Log ('fleet awaken: auto",
     "    if ($true) {\n        Write-Log ('fleet awaken: auto",
     "[동료 안 섬] 「깨어났습니다」·「함대가 섰습니다」를 말하지 않는다"),
    # 폴백 제거 — 동료가 안 서도 사람 카드 없이 끝
    ("fallback-drop", PS,
     "    Write-Log \"fleet awaken: no child seat within",
     "    return 10\n    Write-Log \"fleet awaken: no child seat within",
     "[동료 안 섬] 상한까지 안 서면 그때만 사람 카드"),
    # 선언 줄 제거 — 첫 프롬프트에 선언이 없다(사람 손이 되살아난다)
    ("decl-line-drop", PS,
     "        $wakePrompt = $FleetTrigger + \"`n\" + $firstPrompt\n",
     "        $wakePrompt = $firstPrompt\n",
     "[성공] 선언은 첫 프롬프트의 그 자체 첫 줄"),
    # 거절되는 길로 되돌림 — 창에 선언을 밀어 넣는다
    ("send-inject", PS,
     "    Write-Log \"fleet: auto awaken - watching child seats",
     "    [void](& $cli send --surface $SurfaceRef $FleetTrigger)\n    Write-Log \"fleet: auto awaken - watching child seats",
     "[success] 창에 밀어 넣는 것은 자식 Return 과 마스터 보충 한 줄뿐"),
    # 작은따옴표 두 번 쓰기 제거 — 경로에 ' 가 있으면 wake.ps1 이 안 돈다(검토 Q1)
    ("quote-escape-drop", PS,
     "        $wakeQuoted = $wakePrompt -replace \"'\", \"''\"\n",
     "        $wakeQuoted = $wakePrompt\n",
     "[성공] 선언은 첫 프롬프트의 그 자체 첫 줄"),
    # 설치 창 입력 버퍼 비우기 제거(검토 Q3)
    ("stray-drain-drop", PS,
     "    $n = Get-LoginStrayKeyCount\n    Write-Log ('fleet stray keys in installer window cleared=' + $n)\n",
     "",
     "[동료 안 섬] 떠나기 전에 설치 창 입력 버퍼를 비운다"),
    # 자리 번호 없는 줄 건너뛰기 제거 — 경고 글의 역할 글자를 동료로 센다(검토 Q2)
    ("noseat-line-drop", PS,
     "        if (-not $mid.Success) { continue }\n",
     "",
     "[동료 안 섬] 「깨어났습니다」·「함대가 섰습니다」를 말하지 않는다"),
    # 끝났다고 적지 않음 — 끝맺음이 「다시 실행」을 인쇄한다(2026-09-15 윈 실기 결함 ②)
    ("nextstep-drop", PS,
     "    $script:NextStep = '없습니다 — 설치가 끝났습니다. 이 창을 닫으셔도 됩니다.'\n",
     "",
     "[성공] 끝맺음이 「설치가 끝났습니다」"),
    # ── installer-awaken-verify(2026-09-15) — 자식 자리 각성 검증 ──
    # 윈: 확인 부르기 제거 — 자리가 선 것만으로 끝낸다(거짓 완료로 되돌림)
    ("child-confirm-drop", PS,
     "        [void](Confirm-ChildSeats $cli)\n        Send-PostInstallEvidence $cli $SurfaceRef   # \u24d1 v0.3.20 \u2014 \ub05d\ub09c",
     "        Send-PostInstallEvidence $cli $SurfaceRef   # \u24d1 v0.3.20 \u2014 \ub05d\ub09c",
     "[성공] 제출 전 자리(세션 기록 없음)에 Return 1회"),
    # ── installer-awaken-jsonl(2026-09-16) — 판정 = 세션 기록(jsonl) · 화면 파싱 폐기 ──
    # ── installer-awaken-verify-r2(2026-09-16) — 판정 = 사용자 레코드 ≥1(답 레코드 불요) · 유예 1회 ──
    # 윈: 답 레코드 조건 되살림 — 제출은 됐고 답이 늦는 자리를 실패로 찍는다(샌드박스 7차 거짓 실패로 되돌림)
    ("judge-requires-assistant", PS,
     "        if ($c.u -ge 1) { return @{ ok = $true",
     "        if ($c.u -ge 1 -and $c.a -ge 1) { return @{ ok = $true",
     "[제출만] 사용자 레코드만 있고 답 레코드가 아직 없어도"),
    # 윈: 판정을 늘 참으로 — 화면 거짓 양성과 같은 결말(세션 기록 없이 「깸 확인」)
    ("jsonl-judge-true", PS,
     "        if ($c.u -ge 1) { return @{ ok = $true",
     "        if ($true) { return @{ ok = $true",
     "[화면 거짓] 화면이 답한 모양이어도"),
    # 윈: 유예 제거 — 마지막 Return 뒤 늦게 생긴 기록을 못 보고 실패로 찍는다
    ("grace-drop", PS,
     "        } elseif (-not $graced) {",
     "        } elseif ($false) {",
     "[유예] 마지막 Return 뒤 기록이 늦게 생겨도"),
    # 윈: 빠른 편집 끄기 부르기 제거 — 창 클릭 한 번에 설치가 멈춘다(정적 축)
    ("quickedit-call-drop", PS,
     "    Disable-ConsoleQuickEdit   # 창 클릭",
     "    # 창 클릭",
     "[윈 정적] 설치 창 빠른 편집을"),
    # 윈: 되돌리기 제거 — 설치가 끝난 창에서 글을 선택·복사할 수 없게 남는다(정적 축)
    ("quickedit-restore-drop", PS,
     "    try { Write-ClosingNote } finally { Restore-ConsoleQuickEdit }",
     "    Write-ClosingNote",
     "[윈 정적] 설치 창 빠른 편집을"),
    # ── installer-speed-pin-0320 ⓔ' — 로그인 대기 구간에서는 빠른 편집 켜짐 ──
    # 윈: 로그인 앞 되돌리기 제거 — 로그인 주소를 마우스로 긁지 못한다(샌드박스 실기 적색으로 되돌림)
    ("quickedit-login-restore-drop", PS,
     "    Restore-ConsoleQuickEdit   # [3/10] 로그인 대기",
     "    # [3/10] 로그인 대기",
     "[윈 정적] 로그인 대기 구간에서는 빠른 편집을 켠다"),
    # 윈: 로그인 뒤 다시 끄기 제거 — 뒤 단계([4/10]~[10/10])에서 창 클릭 멈춤이 되살아난다
    ("quickedit-login-redisable-drop", PS,
     "    Disable-ConsoleQuickEdit   # [3/10] 로그인이 끝났다",
     "    # [3/10] 로그인이 끝났다",
     "[윈 정적] 로그인 대기 구간에서는 빠른 편집을 켠다"),
    # 윈: 비트 계산을 틀리게 — 빠른 편집 비트(0x40)를 끄지 않는다(정적 축)
    ("quickedit-mask-wrong", PS,
     "-band 4294967231)",
     "-band 4294967295)",
     "[윈 정적] 설치 창 빠른 편집을"),
    # 윈: Return 을 넣지 않음 — 제출 전 자리를 깨우지 못한다
    ("return-key-drop", PS,
     "            [void](Invoke-CysCapped $Cli ('send-key --surface ' + $Ref + ' Return') $ChildReadCapMs)\n",
     "",
     "[성공] 제출 전 자리(세션 기록 없음)에 Return 1회"),
    # 윈: 3회 상한 제거 — 제출 안 된 자리에 상한(60초)까지 Return 을 쏟는다
    ("retry-cap-drop", PS,
     "        if ($retry -lt $ChildAwakeMaxRetry) {",
     "        if ($true) {",
     "[3회 실패] Return 3회 뒤에도 세션 기록이 없으면"),
    # 윈: 기준선 시각 거르기 제거 — 지난 설치의 기록을 이번 깸으로 센다
    ("since-filter-drop", PS,
     "        Where-Object { $_.CreationTimeUtc -ge $script:ChildAwakeSince } | ",
     "        ",
     "[지난 기록] 기준선 전에 생긴"),
    # ── installer-0322-awaken(2026-09-16) — 마스터 각성 판정이 master 자리를 실제로 재는가 ──
    # 윈: 판정을 무시하고 앞 판으로 되돌림 — 동료 자리만 보고 「깨어났습니다」(2026-09-16 거짓 초록)
    ("master-judge-drop", PS,
     "        if ($mres.state -eq 'verified') {",
     "        if ($true) {",
     "[마스터 거부] 동료가 서도 그것을 마스터 각성으로 세지 않는다"),
    # 윈: 표지 축 제거 — 「말만 했다」를 「일을 시작했다」로 센다(거부가 초록으로 통과한다)
    ("master-mark-ignored", PS,
     "    if ($r.mark) { return 'verified' }",
     "    if ($r.a -ge 1) { return 'verified' }",
     "[마스터 거부] 답은 있고 표지가 없으면"),
    # 윈: 셋을 둘로 합침 — 「판정 못 함」을 「거절」로 말한다(못 잰 것을 실패로 단정)
    ("master-unknown-collapse", PS,
     "    return 'unknown'                 ",
     "    return 'no-start'                ",
     "[판정 못 함] 답도 표지도 없으면"),
    # 윈: 재시도 제거 — 보충 한 줄을 받으면 시작했을 자비스를 못 깨운다
    ("master-retry-drop", PS,
     "    if ((-not $r.mark) -and ($r.a -ge 1) -and ($MasterRetryMax -ge 1)) {",
     "    if ($false) {",
     "[마스터 늦게 시작] 보충 한 줄을 받고 시작하면"),
    # 윈: 표지 시각 검사 제거(벨트 ②) — 지난 설치의 표지를 이번 각성으로 센다
    ("master-mark-time-drop", PS,
     "        return ($t -ge $script:ChildAwakeSince.AddSeconds(-5))",
     "        return $true",
     "[지난 표지·시각] 표지가 있어도 이번 설치 기준선보다 앞서 쓰였으면"),
    # 윈: 깨우기 전 지우기 제거(벨트 ①) — 깨우기 전부터 있던 표지가 살아남는다
    #   ★두 벨트를 **따로** 재려고 시나리오도 둘이다(master-stale-mark · master-prior-mark).
    #     한 시나리오로 재면 다른 벨트가 이 변이를 가려 초록이 된다([[layered-defense-hides-each-mutation]]).
    ("master-clear-drop", PS,
     "    Clear-MasterMark\n    Set-FleetBaseline $cli",
     "    Set-FleetBaseline $cli",
     "[지난 표지·지우기] 깨우기 전부터 놓여 있던 표지를 지워"),
    # 윈: 첫 지시를 앞 판(맹목 실행 + 첫 줄 대본)으로 되돌림 — 거부를 부른 그 문구
    ("coercive-prompt-restore", PS,
     '    $firstPrompt = "install-jarvis 폴더의 install-directive.md($DirectiveFile) 를 읽고, 거기 적힌 준비 작업을 해 주세요."',
     '    $firstPrompt = "Read the file $DirectiveFile and do exactly what it says. Your first line must be the fixed line specified there."',
     "[성공] 선언은 첫 프롬프트의 그 자체 첫 줄"),
    # 윈: 파일 안 cwd 로 찾기 제거 — 폴더 이름 규칙에만 기댄다
    ("fallback-scan-drop", PS,
     "            foreach ($ln in (Read-SessionLines $f.FullName)) { if ($ln.Contains($needle)) { return $f.FullName } }\n",
     "",
     "[다른 폴더] 폴더 이름 규칙이 안 맞으면"),
    # 윈: 증거 마스킹 제거 — 자식 화면의 이름·이메일이 기계 밖으로 나간다
    ("evidence-mask-drop", PS,
     "Get-RemoteHelpTailBytes (Protect-EvidenceText $tail) $EvidenceTextBytes",
     "Get-RemoteHelpTailBytes $tail $EvidenceTextBytes",
     # N6-b(t4-fix): 축 이름이 v0.3.20(64aa71a)에서 「증거 = 이유마다 정확히 1건 …」으로 바뀌었는데 기대 조각이 옛 이름이라 붉어져도 「눈멂」으로 셌다(전건 실행 첫 성공에서 드러남)
     "[3회 실패] 증거 = 이유마다 정확히 1건"),
    # 윈: 실패도 「깨움 확인」이라 말함 — 정직 문구 제거
    ("fail-phrase-lie", PS,
     "            Say ('     ' + $r + ' 자리는 열렸으나 아직 답이 없습니다 — 자비스가 이어서 깨웁니다(사람 손 0)')",
     "            Say ('     ' + $r + ' 자리 깨움 확인')",
     "[3회 실패] Return 3회 뒤에도 세션 기록이 없으면"),
    # 윈: 카드 뒤 성공 자리의 확인 부르기 제거
    ("fallback-confirm-drop", PS,
     "        [void](Confirm-ChildSeats $cli)\n        Send-PostInstallEvidence $cli $SurfaceRef   # \u24d1 v0.3.20 \u2014 \uce74\ub4dc",
     "        Send-PostInstallEvidence $cli $SurfaceRef   # \u24d1 v0.3.20 \u2014 \uce74\ub4dc",
     "[폴백 뒤 섬] 카드 뒤에 선 자식 자리도 깸을 확인한다"),
    # 맥: 3회 상한 제거
    ("mac-retry-cap-drop", SH,
     "    if [ \"$CHILD_RETRY\" -lt \"$CHILD_AWAKE_MAX_RETRY\" ]; then\n",
     "    if true; then\n",
     "[맥 child-stall] Return 3회 뒤에도 세션 기록이 없으면"),
    # 맥: Return 을 넣지 않음
    ("mac-return-key-drop", SH,
     "      cys_capped \"$CHILD_READ_CAP_SEC\" \"$cli\" send-key --surface \"$ref\" Return >/dev/null\n",
     "",
     "[맥 success] 제출 전 자리에 Return 1회"),
    # 맥: 판정을 늘 참으로 — 화면 거짓 양성과 같은 결말
    ("mac-judge-true", SH,
     "    if [ \"$CHILD_U\" -ge 1 ]; then CHILD_WHY=jsonl",
     "    if true; then CHILD_WHY=jsonl",
     "[맥 screen-lies] 화면이 답한 모양이어도"),
    # 맥: 답 레코드 조건 되살림 — 답이 늦는 자리를 실패로 찍는다(샌드박스 7차 거짓 실패로 되돌림)
    ("mac-judge-requires-assistant", SH,
     "    if [ \"$CHILD_U\" -ge 1 ]; then CHILD_WHY=jsonl",
     "    if [ \"$CHILD_U\" -ge 1 ] && [ \"$CHILD_A\" -ge 1 ]; then CHILD_WHY=jsonl",
     "[맥 no-answer] 사용자 레코드만 있고 답 레코드가 아직 없어도"),
    # 맥: 유예 제거
    ("mac-grace-drop", SH,
     "    elif [ \"$graced\" = 0 ]; then",
     "    elif false; then",
     "[맥 grace] 마지막 Return 뒤 기록이 늦게 생겨도"),
    # 맥: 대기 간격을 옛 3·5·8 로 되돌림
    ("mac-gaps-revert", SH,
     "CHILD_AWAKE_GAPS='5 10 20'",
     "CHILD_AWAKE_GAPS='3 5 8'",
     "[맥 success] 자식 자리 확인 상한"),
    # 맥: 기준선 시각 거르기 제거
    ("mac-since-drop", SH,
     "  [ -n \"$b\" ] && [ \"$b\" -ge \"$CHILD_AWAKE_SINCE\" ] || return 1\n",
     "  [ -n \"$b\" ] || return 1\n",
     "[맥 stale-session] 기준선 전에 생긴"),
    # 맥: 파일 안 cwd 로 찾기 제거
    ("mac-fallback-scan-drop", SH,
     "      LC_ALL=C grep -qF -- \"$needle\" \"$f\" && { best=\"$f\"; bestb=\"$b\"; }\n",
     "",
     "[맥 fallback-dir] 폴더 이름 규칙이 안 맞으면"),
    # 맥: 성공 경로의 확인 부르기 제거
    #   N6(t4-fix): T1 이 폴백 뒤 성공 갈래에도 같은 두 줄을 넣어 앵커가 2곳이 됐다(--audit rc 3 · 전건 실행 0초 정지) ⇒ 자동 각성 갈래의 머리 주석까지 묶어 1곳으로 재조준.
    ("mac-confirm-call-drop", SH,
     "    # ★자리가 선 것만으로 끝내지 않는다 — 선 자식 자리가 실제로 깼는지 확인하고, 멈췄으면 깨운다.\n    confirm_child_seats \"$cli\"\n    post_install_evidence",
     "    # ★자리가 선 것만으로 끝내지 않는다 — 선 자식 자리가 실제로 깼는지 확인하고, 멈췄으면 깨운다.\n    post_install_evidence",
     "[맥·윈] 자식 자리 확인을 [10/10] 두 자리에서 부른다"),
    # 맥: N13(t4-fix) — 마스터 verified 갈래 제거 → 이미 깬 자비스에게 「너는 마스터다」 다시 치기 카드(거짓 카드 회귀)
    ("mac-verified-card-drop", SH,
     "  if [ \"$MASTER_STATE\" = verified ]; then\n    say \"[10/10] 마스터는 깨어났습니다",
     "  if false; then\n    say \"[10/10] 마스터는 깨어났습니다",
     "[맥 마스터 깸·동료 늦음] 카드 문구에"),
    # 맥: N16(t4-fix) — 앱 창 대기 기록을 바퀴 수로 되돌림(최악 약 120초가 「waited=20s」로 남는 거짓 기록)
    ("mac-app-wait-log-tries", SH,
     "waited=$((SECONDS - t0))s tries=${i}\"",
     "waited=${i}s tries=${i}\"",
     "[맥 앱 창 app-slow-ping] 대기 기록 waited 는 실제 흐른 초"),
    # 맥: N3(t4-fix) — 「그 창에서 깨어납니다」를 자리 열기 전(앱 창 열자마자)으로 되돌림
    ("mac-app-sentence-early", SH,
     "  CYS_APP_OPENED=1\n  i=0; t0=\"$SECONDS\"",
     "  CYS_APP_OPENED=0\n  say \"     cys 앱 창을 열었습니다 — 자비스는 그 창(제목 jarvis)에서 깨어납니다.\"\n  i=0; t0=\"$SECONDS\"",
     "[맥 앱 창 app-no-surface] 자리를 못 열면"),
    # 자동 관측 상한을 90초로 되돌림 — 자비스 첫 턴보다 짧아 카드가 오발한다(2026-09-15 윈 실기 결함 ①)
    ("cap-revert-90", PS,
     "$FleetAwakeTries = 120 ",
     "$FleetAwakeTries = 45 ",
     "[성공] 자동 관측 상한은 240초"),
    # ── mac-parity-0323 (TICKET=mac-parity-t3-gates · 2026-09-16) — checks.sh 맥 동등화 축(러너 = checks · CHECKS_ONLY=mac-parity) ──
    #   앵커 = T1 벨트 b010f14 의 실물 줄. 여섯째 칸 "checks" = 이 뮤턴트는 흉내 러너가 아니라 checks.sh 맥 구역으로 잰다.
    # [10/10] 마스터 보충 한 줄을 우리말(ps1 글자)로 되돌림 — H-M2 축(ASCII) 회귀 · 판정 master#63749eda
    ("mac-retry-msg-korean", SH,
     "MASTER_RETRY_MSG='The earlier request asks you to read install-directive.md,",
     "MASTER_RETRY_MSG='앞서 보낸 요청은 install-directive.md 를 읽고 판단하신 뒤 준비 작업을 해 달라는 뜻입니다. The earlier request asks you to read install-directive.md,",
     "[맥 master] 보충 한 줄 정본"),
    # 진행 전송 지점 하나 제거(child-verified) — 23자리 대조표 축이 sh 쪽 누락을 잡는가
    ("mp-progress-point-drop", SH,
     "      progress_send '10/10' 'info' '' 'awaken:child-verified' ''   # ps1 3675\n",
     "",
     "[맥동등 전송] ps1 진행 전송 23자리", "checks"),
    # 전송 레버 제거 — JARVIS_NO_PROGRESS=1 이어도 나간다(대조군과 구별 안 됨)
    ("mp-progress-lever-drop", SH,
     '  [ "${JARVIS_NO_PROGRESS:-}" = "1" ] && return 0   # 흉내 시험이 실제 서버로',
     '  : # lever removed   # 흉내 시험이 실제 서버로',
     "[맥동등 전송] JARVIS_NO_PROGRESS=1 이면", "checks"),
    # 진행 전송 os 칸을 win 으로 — 레버·지점 축은 못 보고 T2 실물 러너만 잡는 변이(편입 축이 실제로 러너를 부른다는 증명)
    ("mp-telemetry-os-win", SH,
     '    f.os = "mac";\n',
     '    f.os = "win";\n',
     "[맥동등 전송] 실물 전송 러너 전건 통과", "checks"),
    # [6/10] 실행 비트 벨트 제거
    ("mp-chmod-belt-drop", SH,
     '    chmod +x "$app/Contents/MacOS/"* >>"$LOG_FILE" 2>&1 || log "app exec belt: chmod failed"\n',
     "",
     "[맥동등 6/10] 실행 비트 벨트", "checks"),
    # [6/10] 실행 확인에서 cysd 비트 검사 제거
    ("mp-exec-cysd-x-drop", SH,
     '  [ -x "$m/cysd" ] || { CYS_APP_EXEC_WHY="cysd-not-executable"; return 1; }\n',
     "",
     "[맥동등 6/10] 실행 확인 함수", "checks"),
    # [6/10] 넣은 자리 실행 확인 제거(임시 자리 확인만 남김)
    ("mp-installed-exec-drop", SH,
     '  if ! cys_app_exec_ok "$CYS_FORK_APP"; then\n',
     "  if false; then\n",
     "[맥동등 6/10] 실행 확인을 임시 자리·넣은 자리 두 곳에서", "checks"),
    # [6/10] 재시도 한 번 → 무한(두 번째 시도 표지를 안 올림)
    ("mp-retry-attempt-drop", SH,
     "    attempt=2\n",
     "",
     "[맥동등 6/10] 실행이 안 되면 설치 파일을 버리고 한 번만 다시 받는다", "checks"),
]


def copy_tree(root, dst):
    for d in ("install-master", "tests", "docs"):
        shutil.copytree(root / d, dst / d, symlinks=True)


def run(tree, runner="emu"):
    if runner == "checks":
        # 맥 동등화 구역만 — 가짜 zip 실행 시험(⑤)은 tests/mac-install-mutate.sh --mutants 가 따로 잰다(무한 재시도 뮤턴트가 120초씩 먹지 않게)
        env = dict(os.environ, CHECKS_ONLY="mac-parity", MAC_INSTALL_GATE_SKIP="1")
        cmd = ["bash", "install-master/checks.sh"]
    else:
        env = dict(os.environ)
        cmd = ["bash", "tests/awaken-emu-run.sh"]
    r = subprocess.run(cmd, cwd=tree, env=env, capture_output=True, text=True, stdin=subprocess.DEVNULL)
    return [l for l in r.stdout.split("\n") if l.startswith("  FAIL")]


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--root", required=True)
    ap.add_argument("--audit", action="store_true")
    ap.add_argument("--only", default="")
    a = ap.parse_args()
    root = pathlib.Path(a.root).expanduser().resolve()
    only = set(x for x in a.only.split(",") if x)
    chosen = [(m + ("emu",))[:6] for m in MUTANTS if not only or m[0] in only]
    broken = 0
    for name, rel, old, new, axis, _r in chosen:
        n = (root / rel).read_text(encoding="utf-8-sig").count(old)
        if n != 1:
            print("앵커 %d곳 ✗ %-18s %s" % (n, name, rel)); broken += 1
    if broken:
        print("::error::앵커가 1곳이 아닌 뮤턴트 %d개 — 뮤턴트가 낡았다" % broken); return 3
    if a.audit:
        print("앵커 전건 1곳 — 뮤턴트 %d개 대조 가능" % len(chosen)); return 0
    bases = {}
    for runner in sorted(set(m[5] for m in chosen)):
        base_tmp = pathlib.Path(tempfile.mkdtemp(prefix="awaken-mut-base-"))
        try:
            copy_tree(root, base_tmp)
            bases[runner] = run(base_tmp, runner)
        finally:
            shutil.rmtree(base_tmp, ignore_errors=True)
        print("기준선(%s) 적색 %d줄" % (runner, len(bases[runner])))
        for l in bases[runner]:
            print("   (기준선) " + l.strip())
    bad = 0
    for name, rel, old, new, axis, runner in chosen:
        base = bases[runner]
        if any(axis in l for l in base):
            print("실격  %-18s ← 기준선에서 이미 붉은 축(공짜 적색): %s" % (name, axis)); bad += 1; continue
        tmp = pathlib.Path(tempfile.mkdtemp(prefix="awaken-mut-"))
        try:
            copy_tree(root, tmp)
            p = tmp / rel
            raw = p.read_bytes()
            bom = raw[:3] == b"\xef\xbb\xbf"
            text = raw.decode("utf-8-sig")
            mutated = text.replace(old, new, 1)
            if mutated == text:
                print("미적용 %-18s ← 변이가 들어가지 않았다" % name); bad += 1; continue
            p.write_bytes((b"\xef\xbb\xbf" if bom else b"") + mutated.encode("utf-8"))
            if p.read_bytes() == raw:
                print("미적용 %-18s ← 쓴 뒤에도 바이트가 같다" % name); bad += 1; continue
            reds = run(tmp, runner)
            if any(axis in l for l in reds):
                print("붉음  %-18s ← %s" % (name, axis))
            else:
                print("눈멂  %-18s ← 안 붉어진 축: %s (그때 붉은 줄 %d)" % (name, axis, len(reds))); bad += 1
                for l in reds[:4]:
                    print("        " + l.strip())
        finally:
            shutil.rmtree(tmp, ignore_errors=True)
    print("\n뮤턴트 %d개 · 실패(눈멂·실격·미적용) %d개" % (len(chosen), bad))
    return 1 if bad else 0


sys.exit(main())
