#!/usr/bin/env python3
# 뮤턴트 — v0.3.18 수정이 「실제로 서 있는가」를 재는 도구 (tests/v0318-emu-run.sh 러너 기준)
#
# ★쓰는 법
#   python3 tests/v0318-mutate.py --root <저장소>           전건(사본에서만 고친다 · 실물 무접촉)
#   python3 tests/v0318-mutate.py --root <저장소> --audit   앵커가 아직 1곳씩 걸리는가만
#
# ★판정 = 기준선(변이 없음)에서 **초록**이던 축이, 변이를 넣은 사본에서 **붉어졌는가**.
# ★앵커가 1곳이 아니면 조용히 지나가지 않는다(rc 3).
# ★변이가 사본에 실제로 들어갔는지(바뀐 바이트가 있는지) 확인한 뒤에만 잰다.
# ★기준선 러너가 전건 통과(rc 0)가 아니면 재지 않는다(rc 2) — 측정이 죽은 것을 「눈멂」으로 세지 않는다.
# ⚠판정은 러너 출력의 「  FAIL 」 줄에 기대 축 이름이 있는가로 한다(러너의 rc 가 아니라).
import argparse, os, pathlib, shutil, subprocess, sys, tempfile

for _s in (sys.stdout, sys.stderr):
    try: _s.reconfigure(encoding="utf-8", errors="backslashreplace")
    except Exception: pass

PS = "install-master/bootstrap.ps1"
# (이름, 파일, 찾을 것, 바꿀 것, 붉어져야 할 축 조각)
MUTANTS = [
    # ⑨ 목록으로 가르지 않으면 좌석과 무관한 실패도 막는다 → 3차 실기의 폴백 결말로 되돌아간다
    ("seat-list-bypass", PS,
     "        if ($SeatFatalItems -contains $name) { $fatal += $name } else { $minor += $name }\n",
     "        $fatal += $name\n",
     "[⑨ 주의만]"),
    # ⑨ 항목 줄을 못 읽을 때의 되돌아가기가 빠지면 모르는 채 통과시킨다
    ("seat-summary-fallback-drop", PS,
     "    if ($items.Count -gt 0) { $seatBad = $fatal.Count } else { $seatBad = $bad }\n",
     "    $seatBad = $fatal.Count\n",
     "[⑨ 못 읽음]"),
    # ⑨ 못 읽은 실패 줄을 막는 쪽으로 세지 않으면 모양이 다른 실패가 통과한다
    ("seat-unread-drop", PS,
     "    if (($items.Count -gt 0) -and ($unread -gt 0)) { $seatBad += $unread }\n",
     "",
     "[⑨ 못 읽은 실패]"),
    # ⑨ 막는 갈래 자체가 빠지면 필요한 항목이 실패여도 이어 간다
    ("seat-block-drop", PS,
     "    if ($seatBad -gt 0) {\n        Say \"[8/10] 자가진단에서 $bad 가지가 통과하지 못했습니다.\"\n",
     "    if ($false) {\n        Say \"[8/10] 자가진단에서 $bad 가지가 통과하지 못했습니다.\"\n",
     "[⑨ 막음]"),
]


def copy_tree(root, dst):
    for d in ("install-master", "tests"):
        shutil.copytree(root / d, dst / d, symlinks=True)


def run(tree):
    r = subprocess.run(["bash", "tests/v0318-emu-run.sh"], cwd=tree, env=dict(os.environ),
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
            print("앵커 %d곳 ✗ %-28s %s" % (n, name, rel)); broken += 1
    if broken:
        print("::error::앵커가 1곳이 아닌 뮤턴트 %d개 — 뮤턴트가 낡았다" % broken); return 3
    if a.audit:
        print("앵커 전건 1곳 — 뮤턴트 %d개 대조 가능" % len(MUTANTS)); return 0
    base_tmp = pathlib.Path(tempfile.mkdtemp(prefix="v0318-mut-base-"))
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
        tmp = pathlib.Path(tempfile.mkdtemp(prefix="v0318-mut-"))
        try:
            copy_tree(root, tmp)
            p = tmp / rel
            raw = p.read_bytes()
            bom = raw[:3] == b"\xef\xbb\xbf"
            text = raw.decode("utf-8-sig")
            mutated = text.replace(old, new, 1)
            if mutated == text:
                print("미적용 %-28s ← 변이가 들어가지 않았다" % name); bad += 1; continue
            p.write_bytes((b"\xef\xbb\xbf" if bom else b"") + mutated.encode("utf-8"))
            if p.read_bytes() == raw:
                print("미적용 %-28s ← 쓴 뒤에도 바이트가 같다" % name); bad += 1; continue
            _, reds, _ = run(tmp)
            if any(axis in l for l in reds):
                print("붉음  %-28s ← %s" % (name, axis))
            else:
                print("눈멂  %-28s ← 안 붉어진 축: %s (그때 붉은 줄 %d)" % (name, axis, len(reds))); bad += 1
            for l in reds[:4]:
                print("        " + l.strip())
        finally:
            shutil.rmtree(tmp, ignore_errors=True)
    print("\n뮤턴트 %d개 · 실패(눈멂·미적용) %d개" % (len(MUTANTS), bad))
    return 1 if bad else 0


sys.exit(main())
