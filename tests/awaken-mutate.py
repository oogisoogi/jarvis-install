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
     "[성공] 붙여넣기가 남은 자리에 Return 1회"),
    # 윈: 입력줄 구역 대신 화면 전체에서 붙여넣기를 찾음 — 이미 보낸 기록을 멈춤으로 읽어 Return 을 계속 넣는다
    ("box-region-drop", PS,
     "return ((Get-SeatInputBox $Screen) -match '\\[Pasted text')",
     "return ($Screen -match '\\[Pasted text')",
     "[성공] 붙여넣기가 남은 자리에 Return 1회"),
    # 윈: Return 을 넣지 않음 — 멈춘 자리를 깨우지 못한다
    ("return-key-drop", PS,
     "                [void](Invoke-CysCapped $Cli ('send-key --surface ' + $Ref + ' Return') $ChildReadCapMs)\n",
     "",
     "[성공] 붙여넣기가 남은 자리에 Return 1회"),
    # 윈: 3회 상한 제거 — 멈춘 자리에 상한(60초)까지 Return 을 쏟는다
    ("retry-cap-drop", PS,
     "                if ($retry -ge $ChildAwakeMaxRetry) { break }\n",
     "",
     "[3회 실패] Return 3회 뒤에도 붙여넣기가 남으면 정직 문구"),
    # 윈: 답 판정을 늘 거짓으로 — 이미 깬 자리를 못 알아본다
    ("answer-judge-drop", PS,
     "    return (($Screen -match 'esc to interrupt|DIRECTIVE-ACK') -or ($Screen -match '(^|\\n)\\s*[⏺●]'))",
     "    return $false",
     "[이미 깸] 두 자식이 이미 답했으면 Return 0회"),
    # 윈: 증거 마스킹 제거 — 자식 화면의 이름·이메일이 기계 밖으로 나간다
    ("evidence-mask-drop", PS,
     "Get-RemoteHelpTailBytes (Protect-EvidenceText $tail) $EvidenceTextBytes",
     "Get-RemoteHelpTailBytes $tail $EvidenceTextBytes",
     "[3회 실패] 증거 1건 = reason=stall"),
    # 윈: 실패도 「깨움 확인」이라 말함 — 정직 문구 제거
    ("fail-phrase-lie", PS,
     "            Say ('     ' + $r + ' 자리는 열렸으나 아직 답이 없습니다 — 자비스가 이어서 깨웁니다(사람 손 0)')",
     "            Say ('     ' + $r + ' 자리 깨움 확인')",
     "[3회 실패] Return 3회 뒤에도 붙여넣기가 남으면 정직 문구"),
    # 윈: 카드 뒤 성공 자리의 확인 부르기 제거
    ("fallback-confirm-drop", PS,
     "        [void](Confirm-ChildSeats $cli)\n        Set-FleetFinished",
     "        Set-FleetFinished",
     "[폴백 뒤 섬] 카드 뒤에 선 자식 자리도 깸을 확인한다"),
    # 맥: 입력줄 구역 대신 화면 전체
    ("mac-box-region-drop", SH,
     "seat_paste_residue() { printf '%s\\n' \"$1\" | seat_input_box | LC_ALL=C grep -q '\\[Pasted text'; }",
     "seat_paste_residue() { printf '%s\\n' \"$1\" | LC_ALL=C grep -q '\\[Pasted text'; }",
     "[맥 success] 붙여넣기가 남은 자리에 Return 1회"),
    # 맥: 3회 상한 제거
    ("mac-retry-cap-drop", SH,
     "        [ \"$CHILD_RETRY\" -lt \"$CHILD_AWAKE_MAX_RETRY\" ] || break\n",
     "",
     "[맥 child-stall] Return 3회 뒤에도 붙여넣기가 남으면 정직 문구"),
    # 맥: Return 을 넣지 않음
    ("mac-return-key-drop", SH,
     "        cys_capped \"$CHILD_READ_CAP_SEC\" \"$cli\" send-key --surface \"$ref\" Return >/dev/null\n",
     "",
     "[맥 success] 붙여넣기가 남은 자리에 Return 1회"),
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
