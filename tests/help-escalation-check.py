#!/usr/bin/env python3
# 반복 막힘 단계별 안내 — 문구 정본(tests/help-escalation.tsv)과 세 자리(두 설치기 · 도움말 문서)가 같은가.
#
# 쓰는 법: python3 tests/help-escalation-check.py <축> [--root 저장소]   · rc 0 = 그 축 통과 · 1 = 틀림 · 2 = 잴 수 없음
#   축: tsv · ps1 · sh · docs · phone · width
# ★정본 한 곳 + 세 자리 대조: 설치 창·도움말·운영자 답이 같은 말을 해야 사람이 헷갈리지 않는다.
#   한 곳만 고치면 이 검사가 붉어진다(고친 자리를 모두 맞추거나 정본부터 고친다).
# ⚠설치기 안의 표현(변수 자리)은 두 설치기가 달라서, 줄을 자리표(<PHONE> · <CODE> · <WAY>)에서 쪼갠
#   조각이 **글자 그대로** 들어 있는지를 잰다. 어느 코드에 어느 줄이 붙는지는 실행 시험이 잰다.
import argparse, collections, pathlib, re, sys, unicodedata

PHONE = "010-7745-5885"
ap = argparse.ArgumentParser()
ap.add_argument("axis", choices=["tsv", "ps1", "sh", "docs", "phone", "width"])
ap.add_argument("--root", default=str(pathlib.Path(__file__).resolve().parent.parent))
a = ap.parse_args()
root = pathlib.Path(a.root)


def die(msg, rc=1):
    print("  " + msg)
    sys.exit(rc)


def read(rel):
    p = root / rel
    if not p.is_file():
        die("잴 수 없음: 파일 없음 " + rel, 2)
    return p.read_text(encoding="utf-8-sig")


rows = []
for n, line in enumerate(read("tests/help-escalation.tsv").splitlines(), 1):
    if not line.strip() or line.startswith("#"):
        continue
    parts = line.split("\t")
    if len(parts) != 3:
        die("정본 %d행: 칸이 3개가 아니다" % n)
    rows.append(parts)
common = [(k, key, t) for k, key, t in rows if k in ("stage2", "stage3", "sent")]
ways = collections.OrderedDict()
direct = []
for k, key, t in rows:
    if k == "way":
        ways.setdefault(key, []).append(t)
    elif k == "direct":
        direct.append(key)
rules = [l.split("\t") for l in read("tests/help-rules.tsv").splitlines() if l.startswith("J-")]
codes = [r[0] for r in rules]
# 설치기마다 그 OS 에서 나는 코드만 품는다(표 7번째 칸 both|mac|win) — 윈 전용 코드를 맥 설치기에 적으면
#   코드 표 검사(help-rules-check)가 「맥 설치기가 윈 전용 코드를 낸다」로 붉어진다.
os_of = {r[0]: (r[6] if len(r) > 6 else "both") for r in rules}


def pieces(t):
    return [p for p in re.split(r"<PHONE>|<CODE>", t) if p.strip()]


if a.axis == "tsv":
    bad = [c for c in codes if c not in ways and c not in direct]
    extra = [c for c in list(ways) + direct if c not in codes]
    kinds = collections.Counter(k for k, _, _ in rows)
    if bad or extra:
        die("코드 표와 어긋남 · 빠진 코드 %s · 표에 없는 코드 %s" % (bad, extra))
    if kinds["stage2"] < 3 or kinds["stage3"] < 3 or sorted(key for k, key, _ in rows if k == "sent") != ["no", "ok"]:
        die("공통 줄 모양이 틀림 %s" % dict(kinds))
    if sum(1 for k, _, t in rows if k == "stage2" and t == "<WAY>") != 1 or not any("<PHONE>" in t for k, _, t in rows if k == "stage3"):
        die("자리표가 빠짐(<WAY> 1개 · <PHONE>)")
    print("  코드 %d개 전부 두 번째 방법 또는 곧바로 연락 · 공통 줄 %d" % (len(codes), len(common)))
    sys.exit(0)

if a.axis in ("ps1", "sh"):
    rel = "install-master/bootstrap." + a.axis
    src = read(rel)
    miss = []
    for k, key, t in common:
        if t == "<WAY>":
            continue
        for p in pieces(t):
            if p not in src:
                miss.append("%s/%s: %s" % (k, key, p))
    mine = ("both", "win") if a.axis == "ps1" else ("both", "mac")
    for c, ls in ways.items():
        if os_of.get(c, "both") not in mine:
            continue
        for t in ls:
            if t not in src:
                miss.append("way/%s: %s" % (c, t))
    for c in direct:
        if os_of.get(c, "both") in mine and c not in src:
            miss.append("direct: " + c)
    if miss:
        die("%s 에 정본 줄이 글자 그대로 없다 %d건 · 첫 줄 = %s" % (rel, len(miss), miss[0]))
    print("  %s 가 정본 줄 %d조각을 모두 품는다" % (rel, sum(len(pieces(t)) for k, _, t in common if t != "<WAY>") + sum(len(v) for k2, v in ways.items() if os_of.get(k2, "both") in mine)))
    sys.exit(0)

if a.axis == "docs":
    doc = read("docs/help-codes.md")
    secs = {m.group(1): m.group(0) for m in re.finditer(r"(?ms)^## (J-[A-Z]+-[0-9]{2}).*?(?=^## J-|\Z)", doc)}
    miss = []
    for c in codes:
        sec = secs.get(c, "")
        if "**계속 막히시면**" not in sec:
            miss.append(c + ": 절 없음")
            continue
        tail = sec.split("**계속 막히시면**", 1)[1]
        if c in ways and ("1. " + " ".join(ways[c])) not in tail:
            miss.append(c + ": 두 번째 방법이 정본과 다름")
        if PHONE not in tail:
            miss.append(c + ": 담당자 번호 없음")
    if miss:
        die("도움말 문서 「계속 막히시면」 절이 정본과 어긋남 %d건 · 첫 건 = %s" % (len(miss), miss[0]))
    print("  도움말 문서 %d개 코드 절이 정본과 같다" % len(codes))
    sys.exit(0)

if a.axis == "phone":
    bad = []
    for rel in ("install-master/bootstrap.ps1", "install-master/bootstrap.sh"):
        n = read(rel).count(PHONE)
        if n != 1:
            bad.append("%s 에 번호 글자 %d곳(1곳이어야 한다)" % (rel, n))
    if bad:
        die(" · ".join(bad))
    print("  두 설치기 모두 담당자 번호를 상수 1곳에만 둔다")
    sys.exit(0)

if a.axis == "width":
    def w(s):
        return sum(2 if unicodedata.east_asian_width(ch) in "WF" else 1 for ch in s)
    longest_code = max(codes, key=len)
    worst = []
    for k, key, t in common:
        if t != "<WAY>":
            worst.append((w(t.replace("<PHONE>", PHONE).replace("<CODE>", longest_code)), k, t))
    for c, ls in ways.items():
        for i, t in enumerate(ls):
            worst.append((w(("   - " if i == 0 else "     ") + t), c, t))
    over = [x for x in worst if x[0] > 80]
    if over:
        die("80칸을 넘는 화면 줄 %d · 첫 줄 %d칸 = %s" % (len(over), over[0][0], over[0][2]))
    print("  화면 줄 %d개 · 가장 긴 줄 %d칸(80 이하)" % (len(worst), max(worst)[0]))
    sys.exit(0)
