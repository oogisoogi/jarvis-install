#!/bin/bash
# 공개 용어 검사 — 공개 저장소에 올라갈 트리에 내부 운영 용어가 남았는지 센다.
#
# 쓰는 법: bash tests/public-terms-check.sh [--root <검사할 폴더>] [--terms <목록>]... [--allow <허용 선언>]
#   · --root 기본 = 이 저장소 루트 · --terms 는 여러 번 줄 수 있다(없으면 tests/public-terms.txt 와,
#     있으면 루트의 .public-terms-private.txt) · --allow 기본 = tests/public-terms-allow.txt
#   · rc 0 = 적중 0건 · rc 1 = 적중 있음 · rc 2 = 검사를 못 했다(목록이 없거나 비었거나 파일을 못 읽었다)
#
# ★목록 파일(한 줄 한 정규식 · 파이썬 re 문법 · # 로 시작하는 줄과 빈 줄은 무시)은 **이 스크립트 밖**에 둔다.
#   이 스크립트 본체에는 찾는 낱말이 한 글자도 없다 — 목록이 공개되면 지운 낱말이 그대로 공개되기 때문이다.
# ★허용 선언은 **파일 단위가 아니라 줄 단위**다: 「<상대경로><TAB><그 줄 전문>」이 글자 그대로 같을 때만 뺀다.
#   뺀 것은 전부 세어 출력한다 — 보이지 않는 억제는 미탐과 구별되지 않는다.
# ⚠측정 못 함 = 통과가 아니다: 목록이 없거나 패턴이 0개이거나 검사한 파일이 0개면 rc 2.
set -u
HERE="$(cd "$(dirname "$0")" && pwd)"
REPO="$(cd "${HERE}/.." && pwd)"
ROOT="${REPO}"
TERMS=()
ALLOW=""
while [ $# -gt 0 ]; do
  case "$1" in
    --root) ROOT="$2"; shift 2 ;;
    --terms) TERMS+=("$2"); shift 2 ;;
    --allow) ALLOW="$2"; shift 2 ;;
    *) echo "모르는 인자: $1" >&2; exit 2 ;;
  esac
done
if [ ${#TERMS[@]} -eq 0 ]; then
  TERMS=("${REPO}/tests/public-terms.txt")
  [ -f "${REPO}/.public-terms-private.txt" ] && TERMS+=("${REPO}/.public-terms-private.txt")
fi
[ -n "${ALLOW}" ] || ALLOW="${REPO}/tests/public-terms-allow.txt"

python3 - "${ROOT}" "${ALLOW}" "${TERMS[@]}" <<'PY'
import os, re, sys
root, allow_path, term_paths = sys.argv[1], sys.argv[2], sys.argv[3:]
root = os.path.realpath(root)

pats = []
for tp in term_paths:
    try:
        with open(tp, encoding="utf-8") as fh:
            for n, line in enumerate(fh, 1):
                s = line.rstrip("\n")
                if not s.strip() or s.lstrip().startswith("#"):
                    continue
                try:
                    pats.append((os.path.basename(tp), n, re.compile(s)))
                except re.error as e:
                    print(f"  목록 오류 {tp}:{n} — {e}")
                    sys.exit(2)
    except OSError as e:
        print(f"  목록을 못 읽었다: {tp} ({e})")
        sys.exit(2)
if not pats:
    print("  패턴이 0개다 — 아무것도 안 잰다(통과 아님)")
    sys.exit(2)

allow = set()
if os.path.isfile(allow_path):
    with open(allow_path, encoding="utf-8") as fh:
        for line in fh:
            s = line.rstrip("\n")
            if not s or s.startswith("#") or "\t" not in s:
                continue
            p, text = s.split("\t", 1)
            allow.add((p, text))

# 목록·허용 선언 파일 자신은 낱말을 품는 것이 정상이다 — 경로로만 빼고, 뺀 사실을 출력한다.
self_files = {os.path.realpath(p) for p in term_paths + [allow_path]}

scanned = 0; hits = []; allowed = []; skipped_self = []; unreadable = []
for dp, dns, fns in os.walk(root):
    dns[:] = [d for d in dns if d != ".git"]
    for fn in fns:
        fp = os.path.join(dp, fn)
        rel = os.path.relpath(fp, root)
        if os.path.realpath(fp) in self_files:
            skipped_self.append(rel); continue
        try:
            with open(fp, "rb") as fh:
                raw = fh.read()
        except OSError:
            unreadable.append(rel); continue
        if b"\0" in raw[:8192]:
            continue  # 이진 파일
        scanned += 1
        text = raw.decode("utf-8", errors="replace")
        for ln, line in enumerate(text.splitlines(), 1):
            for src, pn, rx in pats:
                if rx.search(line):
                    key = (rel, line)
                    if key in allow:
                        allowed.append((rel, ln, src, pn))
                    else:
                        hits.append((rel, ln, src, pn, line.strip()[:120]))
                    break

for rel, ln, src, pn, s in hits:
    print(f"  적중 {rel}:{ln}  [{src}:{pn}]  {s}")
print(f"검사 파일 {scanned} · 적중 {len(hits)} · 허용 선언으로 뺀 줄 {len(allowed)} · 목록 파일이라 뺀 파일 {len(skipped_self)} · 못 읽은 파일 {len(unreadable)}")
for rel in skipped_self:
    print(f"  (목록 파일 제외) {rel}")
for rel in unreadable:
    print(f"  (못 읽음) {rel}")
if scanned == 0 or unreadable:
    sys.exit(2)
sys.exit(1 if hits else 0)
PY
