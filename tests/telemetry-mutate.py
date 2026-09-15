#!/usr/bin/env python3
# 뮤턴트 — 진행 텔레메트리(계약 v1 2026-09-15)의 세 축이 「실제로 서 있는가」를 재는 도구
#
# ★쓰는 법
#   python3 tests/telemetry-mutate.py --root <저장소>          전건(사본에서만 고친다 · 실물 무접촉)
#   python3 tests/telemetry-mutate.py --root <저장소> --audit  앵커가 아직 1곳씩 걸리는가만
#   python3 tests/telemetry-mutate.py --root <저장소> --only a,b
#
# ★판정 = 기준선(변이 없음)에서 초록이던 축이, 변이를 넣은 사본에서 붉어졌는가.
#   기준선에서 이미 붉은 축을 기대로 쓰면 「공짜 적색」이라 실격으로 센다.
# ★앵커가 1곳이 아니면 rc 3(뮤턴트가 낡았다) · 변이가 사본에 실제로 들어갔는지 확인한 뒤에만 잰다.
# ★판정은 러너의 「  FAIL 」 줄에 기대 축 이름이 있는가로 한다(러너가 죽으면 FAIL 줄이 없어 눈멂으로 드러난다).
# ⚠pwsh 가 없으면 이 러너는 rc 2 를 내어 잴 수 없다 — 뮤턴트도 잴 수 없다(호출 쪽에서 건너뛴다).
import argparse, os, pathlib, shutil, subprocess, sys, tempfile

for _s in (sys.stdout, sys.stderr):
    try: _s.reconfigure(encoding="utf-8", errors="backslashreplace")
    except Exception: pass

PS = "install-master/bootstrap.ps1"
# (이름, 파일, 찾을 것, 바꿀 것, 붉어져야 할 축 조각)
MUTANTS = [
    # 전송 제거 — 진행 전송이 아무 데도 안 간다(막다른 주소로 돌린다) → 서버에 이벤트가 도착하지 않는다
    ("transmission-drop", PS, "-Uri $url -Method POST", "-Uri 'http://127.0.0.1:1/api/progress' -Method POST",
     "[진행] 단계 이벤트가 서버에 도착한다"),
    # fail-open 제거 — 전송이 실패하면 그대로 튄다 → 죽은 서버에서 설치가 멈춘다
    ("failopen-drop", PS, "        if (-not $script:ProgressWarned) {", "        throw; if (-not $script:ProgressWarned) {",
     "[fail-open] 서버가 죽어도"),
    # 첨부(자료 수집) 제거 — 보고가 열려도 아무 자료도 안 붙는다
    ("attach-drop", PS, "    if (-not $script:RhId) { return $false }", "    if ($true) { return $false }",
     "[첨부] 보고가 열리면 진단 자료를 붙인다"),
]


def copy_tree(root, dst):
    for d in ("install-master", "tests"):
        shutil.copytree(root / d, dst / d, symlinks=True)


def run(tree):
    r = subprocess.run(["bash", "tests/telemetry-emu-run.sh"], cwd=tree, capture_output=True, text=True, stdin=subprocess.DEVNULL)
    if r.returncode == 2:
        return None  # 잴 수 없음(pwsh 없음)
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
            print("앵커 %d곳 ✗ %-20s %s" % (n, name, rel)); broken += 1
    if broken:
        print("::error::앵커가 1곳이 아닌 뮤턴트 %d개 — 뮤턴트가 낡았다" % broken); return 3
    if a.audit:
        print("앵커 전건 1곳 — 뮤턴트 %d개 대조 가능" % len(chosen)); return 0
    base_tmp = pathlib.Path(tempfile.mkdtemp(prefix="tele-mut-base-"))
    try:
        copy_tree(root, base_tmp)
        base = run(base_tmp)
    finally:
        shutil.rmtree(base_tmp, ignore_errors=True)
    if base is None:
        print("잴 수 없음: pwsh 가 없다"); return 2
    print("기준선 적색 %d줄" % len(base))
    for l in base:
        print("   (기준선) " + l.strip())
    bad = 0
    for name, rel, old, new, axis in chosen:
        if any(axis in l for l in base):
            print("실격  %-20s ← 기준선에서 이미 붉은 축(공짜 적색): %s" % (name, axis)); bad += 1; continue
        tmp = pathlib.Path(tempfile.mkdtemp(prefix="tele-mut-"))
        try:
            copy_tree(root, tmp)
            p = tmp / rel
            raw = p.read_bytes()
            bom = raw[:3] == b"\xef\xbb\xbf"
            text = raw.decode("utf-8-sig")
            mutated = text.replace(old, new, 1)
            if mutated == text:
                print("미적용 %-20s ← 변이가 들어가지 않았다" % name); bad += 1; continue
            p.write_bytes((b"\xef\xbb\xbf" if bom else b"") + mutated.encode("utf-8"))
            if p.read_bytes() == raw:
                print("미적용 %-20s ← 쓴 뒤에도 바이트가 같다" % name); bad += 1; continue
            reds = run(tmp)
            if reds is None:
                print("잴 수 없음: pwsh 가 없다"); return 2
            if any(axis in l for l in reds):
                print("붉음  %-20s ← %s" % (name, axis))
            else:
                print("눈멂  %-20s ← 안 붉어진 축: %s (그때 붉은 줄 %d)" % (name, axis, len(reds))); bad += 1
                for l in reds[:4]:
                    print("        " + l.strip())
        finally:
            shutil.rmtree(tmp, ignore_errors=True)
    print("\n뮤턴트 %d개 · 실패(눈멂·실격·미적용) %d개" % (len(chosen), bad))
    return 1 if bad else 0


sys.exit(main())
