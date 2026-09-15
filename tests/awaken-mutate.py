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
     "[success] 창에 글을 밀어 넣지 않는다"),
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
     "        [void](Confirm-ChildSeats $cli)\n        Say ''",
     "        Say ''",
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
    # 윈: 파일 안 cwd 로 찾기 제거 — 폴더 이름 규칙에만 기댄다
    ("fallback-scan-drop", PS,
     "            foreach ($ln in (Read-SessionLines $f.FullName)) { if ($ln.Contains($needle)) { return $f.FullName } }\n",
     "",
     "[다른 폴더] 폴더 이름 규칙이 안 맞으면"),
    # 윈: 증거 마스킹 제거 — 자식 화면의 이름·이메일이 기계 밖으로 나간다
    ("evidence-mask-drop", PS,
     "Get-RemoteHelpTailBytes (Protect-EvidenceText $tail) $EvidenceTextBytes",
     "Get-RemoteHelpTailBytes $tail $EvidenceTextBytes",
     "[3회 실패] 증거 1건 = reason=stall"),
    # 윈: 실패도 「깨움 확인」이라 말함 — 정직 문구 제거
    ("fail-phrase-lie", PS,
     "            Say ('     ' + $r + ' 자리는 열렸으나 아직 답이 없습니다 — 자비스가 이어서 깨웁니다(사람 손 0)')",
     "            Say ('     ' + $r + ' 자리 깨움 확인')",
     "[3회 실패] Return 3회 뒤에도 세션 기록이 없으면"),
    # 윈: 카드 뒤 성공 자리의 확인 부르기 제거
    ("fallback-confirm-drop", PS,
     "        [void](Confirm-ChildSeats $cli)\n        Set-FleetFinished",
     "        Set-FleetFinished",
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
    ("mac-confirm-call-drop", SH,
     "    confirm_child_seats \"$cli\"\n    return 0",
     "    return 0",
     "[맥·윈] 자식 자리 확인을 [10/10] 두 자리에서 부른다"),
    # 자동 관측 상한을 90초로 되돌림 — 자비스 첫 턴보다 짧아 카드가 오발한다(2026-09-15 윈 실기 결함 ①)
    ("cap-revert-90", PS,
     "$FleetAwakeTries = 48 ",
     "$FleetAwakeTries = 18 ",
     "[성공] 자동 관측 상한은 240초"),
]


def copy_tree(root, dst):
    for d in ("install-master", "tests", "docs"):
        shutil.copytree(root / d, dst / d, symlinks=True)


def run(tree):
    r = subprocess.run(["bash", "tests/awaken-emu-run.sh"], cwd=tree, env=dict(os.environ),
                       capture_output=True, text=True, stdin=subprocess.DEVNULL)
    return [l for l in r.stdout.split("\n") if l.startswith("  FAIL")]


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--root", required=True)
    ap.add_argument("--audit", action="store_true")
    ap.add_argument("--only", default="")
    a = ap.parse_args()
    root = pathlib.Path(a.root).expanduser().resolve()
    only = set(x for x in a.only.split(",") if x)
    chosen = [m for m in MUTANTS if not only or m[0] in only]
    broken = 0
    for name, rel, old, new, axis in chosen:
        n = (root / rel).read_text(encoding="utf-8-sig").count(old)
        if n != 1:
            print("앵커 %d곳 ✗ %-18s %s" % (n, name, rel)); broken += 1
    if broken:
        print("::error::앵커가 1곳이 아닌 뮤턴트 %d개 — 뮤턴트가 낡았다" % broken); return 3
    if a.audit:
        print("앵커 전건 1곳 — 뮤턴트 %d개 대조 가능" % len(chosen)); return 0
    base_tmp = pathlib.Path(tempfile.mkdtemp(prefix="awaken-mut-base-"))
    try:
        copy_tree(root, base_tmp)
        base = run(base_tmp)
    finally:
        shutil.rmtree(base_tmp, ignore_errors=True)
    print("기준선 적색 %d줄" % len(base))
    for l in base:
        print("   (기준선) " + l.strip())
    bad = 0
    for name, rel, old, new, axis in chosen:
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
            reds = run(tmp)
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
