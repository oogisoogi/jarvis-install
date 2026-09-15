#!/usr/bin/env python3
# 뮤턴트 — 재설치 사람 손 0(-KeepApp -Yes · 2026-09-15) 수정이 「실제로 서 있는가」를 재는 도구
#
# ★쓰는 법
#   python3 tests/reinstall-keepapp-mutate.py --root <저장소>           전건(사본에서만 고친다 · 실물 무접촉)
#   python3 tests/reinstall-keepapp-mutate.py --root <저장소> --audit   앵커가 아직 1곳씩 걸리는가만
#
# ★판정 = 기준선(변이 없음)에서 **초록**이던 축이, 변이를 넣은 사본에서 **붉어졌는가**.
#   기준선에서 이미 붉은 축을 기대로 쓰면 「공짜 적색」이라 아무것도 증명하지 않는다 — 그런 뮤턴트는 실격으로 센다.
# ★앵커가 1곳이 아니면 조용히 지나가지 않는다(rc 3).
# ★변이가 사본에 실제로 들어갔는지(바뀐 바이트가 있는지) 확인한 뒤에만 잰다 — 안 들어간 변이의 초록은 측정 실패다.
# ★기준선 러너가 전건 통과(rc 0)가 아니면 재지 않는다(rc 2) — pwsh 가 없으면 러너가 FAIL 줄 없이 rc 2 로 끝나
#   모든 뮤턴트가 「눈멂」으로 보이는데, 그것은 뮤턴트가 아니라 측정이 죽은 것이다.
# ⚠판정은 러너 출력의 「  FAIL 」 줄에 기대 축 이름이 있는가로 한다(러너의 rc 가 아니라).
import argparse, os, pathlib, shutil, subprocess, sys, tempfile

for _s in (sys.stdout, sys.stderr):
    try: _s.reconfigure(encoding="utf-8", errors="backslashreplace")
    except Exception: pass

RS = "install-master/reset-clean.ps1"
RI = "install-master/reinstall.ps1"
# (이름, 파일, 찾을 것, 바꿀 것, 붉어져야 할 축 조각)
MUTANTS = [
    # W-APP 절의 -KeepApp 갈래가 빠지면 설정 앱 갈래를 탄다 → -Yes 라 Enter 고리는 없지만 제거 프로그램이 남아 [남음] · 종료 코드 7
    #   → 재설치가 설치 도우미로 넘어가지 않는다.
    ("keepapp-branch-drop", RS,
     "    if ($KeepApp) {\n        # 재설치 길(-KeepApp) — 이 절 전체를 건너뛴다.",
     "    if ($false) {\n        # 재설치 길(-KeepApp) — 이 절 전체를 건너뛴다.",
     "[재설치] 지운 뒤 설치 도우미까지 간다"),
    # -Yes 가 빠지면 「지웁니다」 확인을 사람에게 묻는다(흉내의 Read-Host 가 기록하고 빈 답 → 그만둠).
    ("yes-drop", RI,
     "powershell -ExecutionPolicy Bypass -File $ResetFile -KeepApp -Yes\n",
     "powershell -ExecutionPolicy Bypass -File $ResetFile -KeepApp\n",
     "[재설치] 재설치 길에서 사람에게 묻는 자리가 0"),
    # 편성 기록 지우기가 빠지면 프로그램 폴더 안의 topology.json 등이 남는다 → cys 가 켜지자마자 지난 동료 좌석을 되살린다(2026-09-15 윈 2차 재설치).
    ("state-drop-drop", RS,
     "        foreach ($s in (Get-CysStateItems)) { Drop 'cys 지난 편성 기록' $s }\n",
     "",
     "[재설치] 지난 편성 기록(동료 좌석을 되살리는 기록)은 지우고 프로그램 파일은 남긴다"),
]


def copy_tree(root, dst):
    for d in ("install-master", "tests"):
        shutil.copytree(root / d, dst / d, symlinks=True)


def run(tree):
    r = subprocess.run(["bash", "tests/reinstall-keepapp-emu-run.sh"], cwd=tree, env=dict(os.environ),
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
            print("앵커 %d곳 ✗ %-22s %s" % (n, name, rel)); broken += 1
    if broken:
        print("::error::앵커가 1곳이 아닌 뮤턴트 %d개 — 뮤턴트가 낡았다" % broken); return 3
    if a.audit:
        print("앵커 전건 1곳 — 뮤턴트 %d개 대조 가능" % len(MUTANTS)); return 0
    base_tmp = pathlib.Path(tempfile.mkdtemp(prefix="reinstall-keepapp-mut-base-"))
    try:
        copy_tree(root, base_tmp)
        brc, base, bout = run(base_tmp)
    finally:
        shutil.rmtree(base_tmp, ignore_errors=True)
    if brc != 0:
        print("잴 수 없음 — 기준선 러너 rc %d (전건 통과가 아니다)" % brc)
        print(bout[-600:])
        return 2
    print("기준선 — 러너 rc 0 · 적색 %d줄" % len(base))
    bad = 0
    for name, rel, old, new, axis in MUTANTS:
        tmp = pathlib.Path(tempfile.mkdtemp(prefix="reinstall-keepapp-mut-"))
        try:
            copy_tree(root, tmp)
            p = tmp / rel
            raw = p.read_bytes()
            bom = raw[:3] == b"\xef\xbb\xbf"
            text = raw.decode("utf-8-sig")
            mutated = text.replace(old, new, 1)
            if mutated == text:
                print("미적용 %-22s ← 변이가 들어가지 않았다" % name); bad += 1; continue
            p.write_bytes((b"\xef\xbb\xbf" if bom else b"") + mutated.encode("utf-8"))
            if p.read_bytes() == raw:
                print("미적용 %-22s ← 쓴 뒤에도 바이트가 같다" % name); bad += 1; continue
            _, reds, _ = run(tmp)
            if any(axis in l for l in reds):
                print("붉음  %-22s ← %s" % (name, axis))
            else:
                print("눈멂  %-22s ← 안 붉어진 축: %s (그때 붉은 줄 %d)" % (name, axis, len(reds))); bad += 1
            for l in reds[:4]:
                print("        " + l.strip())
        finally:
            shutil.rmtree(tmp, ignore_errors=True)
    print("\n뮤턴트 %d개 · 실패(눈멂·미적용) %d개" % (len(MUTANTS), bad))
    return 1 if bad else 0


sys.exit(main())
