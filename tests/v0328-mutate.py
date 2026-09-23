#!/usr/bin/env python3
# 뮤턴트 — 0.3.28(재설치 폴백 마무리 · 로그인 승계 · J-DL-07)의 검사 축이 **대상을 실제로 때리는가**
#
# ★쓰는 법
#   python3 tests/v0328-mutate.py --root <저장소>           전건(사본에서만 고친다 · 실물 무접촉)
#   python3 tests/v0328-mutate.py --root <저장소> --audit   앵커가 아직 1곳씩 걸리는가만
#
# ★판정 = 기준선(변이 없음)에서 **초록**이던 축이, 변이를 넣은 사본에서 **붉어졌는가**.
#   기준선에서 이미 붉은 축을 기대로 쓰면 「공짜 적색」이라 아무것도 증명하지 않는다.
# ★변이가 사본에 실제로 들어갔는지(바뀐 바이트가 있는지) 확인한 뒤에만 잰다 — 안 들어간 변이의 초록은 측정 실패다.
# ★러너 = `CHECKS_ONLY=0328 bash install-master/checks.sh` (그 구역만 · 0.3초) — 네트워크를 때리는
#   윈 핀 대조 축은 이 구역 **밖**이라 여기서 재지 않는다(그 축은 릴리스가 정본이다).
# ⚠판정은 러너 출력의 「  FAIL 」 줄에 기대 축 이름이 있는가로 한다(러너의 rc 가 아니라).
import argparse, os, pathlib, shutil, subprocess, sys, tempfile

for _s in (sys.stdout, sys.stderr):
    try: _s.reconfigure(encoding="utf-8", errors="backslashreplace")
    except Exception: pass

PS = "install-master/bootstrap.ps1"
SH = "install-master/bootstrap.sh"

# (이름, 파일, 찾을 것, 바꿀 것, 붉어져야 할 축 조각)
MUTANTS = [
    # ⓐ 자리 선점 갈래를 없애면 앞 판으로 되돌아간다 — 이 창에서 두 번째 자비스를 띄운다.
    ("win-claim-branch-drop", PS,
     "        if (Test-SeatClaimDenied $ref) {",
     "        if ($false) {",
     "[0328 폴백] 윈: new-surface 답이 자리 선점인지 가른다"),
    ("mac-claim-branch-drop", SH,
     '    if seat_claim_denied "$ref"; then',
     '    if false; then',
     "[0328 폴백] 맥: 같은 갈래가 있다"),
    # ⓑ 앱 자동 실행을 빼면 「사람이 직접 실행하라」로 되돌아간다(박사님 원칙 위반).
    ("win-app-autostart-drop", PS,
     "            $appState = Start-CysAppWindow",
     "            $appState = ''",
     "[0328 폴백] 윈: cysr 앱을 자동으로 띄운다(또는 앞으로)"),
    ("mac-app-autostart-drop", SH,
     '      app_state="$(start_cys_app_window)"',
     '      app_state=""',
     "[0328 폴백] 맥: 같은 자동 실행이 있다"),
    # ⓒ 끝 전송을 한 갈래에서 빼면 그 갈래가 다시 「기록에 없는 끝」이 된다(09-21 07:30 이 그 모습이었다).
    ("win-9of10-end-one-drop", PS,
     "        Send-Progress '9/10' 'end' $null 'wake:no-claude' $null\n",
     "",
     "[0328 전송] 윈: [9/10] 끝을 네 갈래 전부에서 보낸다"),
    ("mac-9of10-end-one-drop", SH,
     "    progress_send '9/10' 'end' '' 'wake:no-claude' ''\n",
     "",
     "[0328 전송] 맥: [9/10] 끝을 네 갈래 전부에서 보낸다"),
    # ⓓ 감싸개를 건너뛰고 직접 부르면 [10/10] 시작·끝이 그 길에서 사라진다.
    ("win-fleet-wrapper-bypass", PS,
     "            [void](Invoke-StepFleet $script:WakeRef)",
     "            [void](Step-Fleet $script:WakeRef)",
     "[0328 전송] 윈: 감싸개를 건너뛰고 Step-Fleet 를 직접 부르는 자리가 없다"),
    # ⓔ 승계를 빼면 이미 로그인된 기기에서 로그인 화면이 다시 뜬다(09-21 07:31 결함 1호).
    ("win-login-sweep-drop", PS,
     "        if (Restore-LoginFromProfiles $claudeExe) { $script:LoggedIn = $true }",
     "        if ($false) { $script:LoggedIn = $true }",
     "[0328 승계] 윈: 로그인 카드 전에 다른 프로필을 묻는다"),
    ("mac-login-sweep-drop", SH,
     "    if restore_login_from_profiles; then S1_LOGGED_IN=1; fi",
     "    if false; then S1_LOGGED_IN=1; fi",
     "[0328 승계] 맥: 같은 자리가 있다"),
    # ⓕ 받는 자리 점검의 본문 판정을 풀면 담벼락의 200 이 통과한다(부재를 0건으로 표현하는 자리).
    ("win-dlprobe-body-relax", PS,
     "        if (([int]$dr.StatusCode -eq 200) -and ($dtxt -match '^[0-9]+\\.[0-9]+\\.[0-9]+')) {",
     "        if ([int]$dr.StatusCode -eq 200) {",
     "[0328 받기] 윈: 200 만으로 통과시키지 않고 판번 한 줄까지 본다"),
    # ⓖ J-DL-07 갈래를 없애면 「받아 오지 못한 기계」에 재시작(J-PATH-01) 처방이 나간다.
    # v0.3.32: 종료 코드 실패 갈래에도 같은 줄이 생겨(TICKET=installer-0332) 앞 줄을 붙여 파일 없음 갈래의 것만 겨눈다(변이의 뜻 동일).
    ("win-jdl07-code-rename", PS,
     "인터넷 연결이 한 곳 이상 실패했습니다.' }\n            Write-JCode 'J-DL-07' '클로드를 내려받는 서버에 닿지 못한 것으로 보입니다'",
     "인터넷 연결이 한 곳 이상 실패했습니다.' }\n            Write-JCode 'J-DL-99' '클로드를 내려받는 서버에 닿지 못한 것으로 보입니다'",
     "[0328 받기] 윈: J-PS32-01 → J-DL-07 → J-PATH-01 순으로 갈린다"),
    ("mac-jdl07-order-swap", SH,
     '      jcode "J-DL-07" "클로드를 내려받는 서버에 닿지 못한 것으로 보입니다"',
     '      jcode "J-DL-77" "클로드를 내려받는 서버에 닿지 못한 것으로 보입니다"',
     "[0328 받기] 맥: J-DL-07 이 J-PATH-01 보다 앞에서 갈린다"),
    # ⓗ 자식 글자 기록을 빼면 「무슨 말을 했나」가 다시 0 이 된다(09-20 22:1x 가 그 모습이었다).
    ("win-transcript-drop", PS,
     "try { Start-Transcript -Path '$logQuoted' -Force | Out-Null } catch { }; ",
     "",
     "[0328 받기] 윈: 자식 설치기의 글자를 파일로도 남긴다"),
    ("mac-tee-drop", SH,
     ' 2>&1 | tee -a "$CLAUDE_INSTALL_LOG"',
     '',
     "[0328 받기] 맥: 같은 글자를 화면과 파일 양쪽으로 보낸다"),
]


def copy_tree(root, dst):
    for d in ("install-master", "tests"):
        shutil.copytree(root / d, dst / d, symlinks=True)


def run(tree):
    env = dict(os.environ); env["CHECKS_ONLY"] = "0328"
    r = subprocess.run(["bash", "install-master/checks.sh"], cwd=tree, env=env,
                       capture_output=True, text=True, stdin=subprocess.DEVNULL)
    return r.returncode, [l for l in r.stdout.split("\n") if l.startswith("  FAIL")], r.stdout + r.stderr


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--root", required=True)
    ap.add_argument("--audit", action="store_true")
    a = ap.parse_args()
    root = pathlib.Path(a.root).expanduser().resolve()
    broken = 0
    for name, rel, old, new, axis in MUTANTS:
        n = (root / rel).read_text(encoding="utf-8-sig").count(old)
        if n != 1:
            print("앵커 %d곳 ✗ %-26s %s" % (n, name, rel)); broken += 1
    if broken:
        print("::error::앵커가 1곳이 아닌 뮤턴트 %d개 — 뮤턴트가 낡았다" % broken); return 3
    if a.audit:
        print("앵커 전건 1곳 — 뮤턴트 %d개 대조 가능" % len(MUTANTS)); return 0
    base_tmp = pathlib.Path(tempfile.mkdtemp(prefix="v0328-mut-base-"))
    try:
        copy_tree(root, base_tmp)
        brc, base, bout = run(base_tmp)
    finally:
        shutil.rmtree(base_tmp, ignore_errors=True)
    if brc != 0:
        print("잴 수 없음 — 기준선 러너 rc %d (전건 통과가 아니다)" % brc)
        print(bout[-800:]); return 2
    print("기준선 — 러너 rc 0 · 적색 %d줄" % len(base))
    bad = 0
    for name, rel, old, new, axis in MUTANTS:
        tmp = pathlib.Path(tempfile.mkdtemp(prefix="v0328-mut-"))
        try:
            copy_tree(root, tmp)
            p = tmp / rel
            raw = p.read_bytes()
            bom = raw[:3] == b"\xef\xbb\xbf"
            text = raw.decode("utf-8-sig")
            mutated = text.replace(old, new, 1)
            if mutated == text:
                print("미적용 %-26s ← 변이가 들어가지 않았다" % name); bad += 1; continue
            p.write_bytes((b"\xef\xbb\xbf" if bom else b"") + mutated.encode("utf-8"))
            if p.read_bytes() == raw:
                print("미적용 %-26s ← 쓴 뒤에도 바이트가 같다" % name); bad += 1; continue
            _, reds, _ = run(tmp)
            if any(axis in l for l in reds):
                print("붉음  %-26s ← %s" % (name, axis))
            else:
                print("눈멂  %-26s ← 안 붉어진 축: %s (그때 붉은 줄 %d)" % (name, axis, len(reds))); bad += 1
                for l in reds[:3]:
                    print("        " + l.strip())
        finally:
            shutil.rmtree(tmp, ignore_errors=True)
    print("\n뮤턴트 %d개 · 실패(눈멂·미적용) %d개" % (len(MUTANTS), bad))
    return 1 if bad else 0


sys.exit(main())
