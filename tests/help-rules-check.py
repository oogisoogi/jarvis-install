#!/usr/bin/env python3
# 진단 규칙 축 — 표 · 설치기 · 안내 문서 **셋이 같은 코드 집합을 갖는가**를 잰다.
#
# ★왜 셋을 함께 재는가
#   표에서 행을 지우면 설치기는 그 코드를 계속 내보내는데 사람이 찾을 곳이 없어진다.
#   설치기에 코드를 새로 넣고 표를 안 고치면 사이트에 그 페이지가 없다.
#   문서만 고치고 표를 안 고치면 다음 사람이 문서를 정본으로 읽는다.
#   ⇒ 한 방향만 재면 나머지 두 방향이 조용히 갈라진다.
#
# 쓰는 법: python3 tests/help-rules-check.py [--dir install-master] [--docs docs/help-codes.md]
import argparse, pathlib, re, sys

CODE_RE = re.compile(r'J-[A-Z]+-[0-9]{2}')


def read_rows(p):
    rows = []
    for ln in p.read_text(encoding="utf-8").split("\n"):
        if ln.startswith("#") or not ln.strip():
            continue
        f = ln.split("\t")
        if len(f) >= 6:
            rows.append(f)
    return rows


def main():
    ap = argparse.ArgumentParser()
    here = pathlib.Path(__file__).resolve().parent
    ap.add_argument("--dir", default=str(here.parent / "install-master"))
    ap.add_argument("--docs", default=str(here.parent / "docs/help-codes.md"))
    ap.add_argument("--rules", default=str(here / "help-rules.tsv"))
    ap.add_argument("--fixtures", default=str(here / "help-fixtures.tsv"))
    a = ap.parse_args()

    rules = read_rows(pathlib.Path(a.rules))
    if not rules:
        print("::error::규칙 표가 비었습니다"); return 1
    table = {r[0]: r for r in rules}
    bad = 0
    print("규칙 %d개 · 축 %s" % (len(rules), " ".join(sorted({c.split('-')[1] for c in table}))))

    # ① 설치기 ↔ 표 (양방향 · **OS 별로 따로**)
    # 🔴두 파일을 하나로 합쳐 보면, 한쪽 OS 에서 코드가 사라져도 다른 쪽에 남아 있어 통과한다
    #   (외부 검토 1차 [6] 지적 채택 2026-09-09). 다만 「둘 다 있어야 한다」는 틀렸다 — 레지스트리처럼
    #   한쪽 OS 에만 있는 개념이 있다. ⇒ **표가 어느 OS 라고 적었는지**를 기준으로 각각 단언한다.
    files = {"mac": pathlib.Path(a.dir) / "bootstrap.sh", "win": pathlib.Path(a.dir) / "bootstrap.ps1"}
    found = {}
    for osname, f in files.items():
        found[osname] = set(CODE_RE.findall(f.read_text(encoding="utf-8", errors="replace"))) if f.exists() else set()
    for code, r in sorted(table.items()):
        want = r[6].strip() if len(r) > 6 else "both"
        targets = ["mac", "win"] if want == "both" else [want]
        for osname in targets:
            if code not in found[osname]:
                print("::error::표가 %s 라고 적은 %s 를 %s 설치기가 내보내지 않습니다"
                      % (want, code, "맥" if osname == "mac" else "윈")); bad = 1
        for osname in set(("mac", "win")) - set(targets):
            if code in found[osname]:
                print("::error::%s 는 표에 %s 전용인데 %s 설치기에도 있습니다 — 표를 고치십시오"
                      % (code, want, "맥" if osname == "mac" else "윈")); bad = 1
    extra_src = sorted((found["mac"] | found["win"]) - set(table))
    if extra_src:
        print("::error::설치기가 내보내는데 표에 없는 코드: %s" % " ".join(extra_src)); bad = 1

    # ② 안내 문서 ↔ 표 (양방향) — 사람이 찾아갈 자리가 실제로 있는가
    doc = pathlib.Path(a.docs).read_text(encoding="utf-8") if pathlib.Path(a.docs).exists() else ""
    in_doc = set(re.findall(r'^## (J-[A-Z]+-[0-9]{2})', doc, re.M))
    miss_doc = sorted(set(table) - in_doc)
    extra_doc = sorted(in_doc - set(table))
    if miss_doc:
        print("::error::표에는 있는데 안내 문서에 절이 없는 코드: %s" % " ".join(miss_doc)); bad = 1
    if extra_doc:
        print("::error::안내 문서에만 있고 표에 없는 코드: %s" % " ".join(extra_doc)); bad = 1

    # ③ 증상 픽스처 → 코드 (표의 표식으로 실제로 갈라지는가)
    fx = []
    for ln in pathlib.Path(a.fixtures).read_text(encoding="utf-8").split("\n"):
        if ln.startswith("#") or not ln.strip():
            continue
        f = ln.split("\t")
        if len(f) >= 2:
            fx.append((f[0], f[1].strip()))
    for line, want in fx:
        hit = [r[0] for r in rules if r[2] and r[2] in line]
        if hit != [want]:
            print("::error::픽스처가 %s 하나로 안 갈립니다(잡힌 것: %s) ← %s"
                  % (want, ",".join(hit) if hit else "없음", line[:60]))
            bad = 1
    print("픽스처 %d줄 대조 완료" % len(fx))

    # ④ 행동 두 줄이 비어 있지 않은가 — 코드만 있고 할 일이 없으면 사람은 그대로 멈춘다
    for r in rules:
        if not r[3].strip() or not r[4].strip():
            print("::error::%s 의 행동 두 줄 중 빈 것이 있습니다" % r[0]); bad = 1
        if len(r) < 7 or r[6].strip() not in ("both", "mac", "win"):
            print("::error::%s 에 어느 OS 인지가 없습니다(both|mac|win)" % r[0]); bad = 1

    if bad:
        return 1
    print("표 · 설치기 · 안내 문서가 같은 %d개 코드를 가리킵니다." % len(table))
    return 0


sys.exit(main())
