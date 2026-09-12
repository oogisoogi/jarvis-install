#!/usr/bin/env python3
"""치환 감사 — 기준 커밋 대비 바뀐 줄 가운데 「주석·문서가 아닌 줄」을 전부 꺼낸다.

쓰는 법: python3 tests/scrub-diff-audit.py [--base 8a1af52] [--list]
  rc 0 = 바뀐 줄이 전부 주석·문서 줄이고, 파일마다 더한 줄 수 = 뺀 줄 수
  rc 1 = 주석이 아닌 줄이 바뀌었거나(목록 출력) 줄 수가 달라졌다
  rc 2 = 측정을 못 했다(git 실패)

판정 규칙(파일 종류별):
  · .sh .ps1 .py .yml .yaml .tsv 외 스크립트 = 앞 공백 뒤 첫 글자가 # 인 줄만 주석으로 본다
    (PowerShell 블록 주석 · 파이썬 docstring 은 주석으로 세지 않는다 — 문자열이라서 따로 보고한다)
  · .md = 문서 줄로 본다(단 코드 울타리 ``` 안의 줄은 문서가 아니다)
⛔이 도구는 「로직이 안 바뀌었다」를 증명하지 않는다. 주석이 아닌 바뀐 줄을 **빠짐없이 보이게** 할 뿐이다.
"""
import argparse, re, subprocess, sys

ap = argparse.ArgumentParser()
ap.add_argument("--base", default="8a1af52")
ap.add_argument("--list", action="store_true", help="주석 줄 변경도 모두 출력")
a = ap.parse_args()

try:
    numstat = subprocess.run(["git", "diff", "--numstat", a.base, "--"], capture_output=True, text=True, check=True).stdout
    diff = subprocess.run(["git", "diff", "-U0", a.base, "--"], capture_output=True, text=True, check=True).stdout
except subprocess.CalledProcessError as e:
    print(f"git 실패: {e}"); sys.exit(2)

bad_count = []
for line in numstat.splitlines():
    add, dele, path = line.split("\t", 2)
    if add == "-" or dele == "-":
        continue
    if add != dele:
        bad_count.append((path, add, dele))

def is_md(p): return p.endswith(".md")
def comment(line): return re.match(r"^\s*#", line) is not None

# .md 코드 울타리 판정을 위해 새 판 파일 전체를 읽어 줄 번호별 울타리 여부를 만든다
fence_cache = {}
def in_fence(path, lineno):
    if path not in fence_cache:
        inside = False; marks = {}
        try:
            with open(path, encoding="utf-8", errors="replace") as fh:
                for n, l in enumerate(fh, 1):
                    if l.lstrip().startswith("```"):
                        marks[n] = True; inside = not inside; continue
                    marks[n] = inside
        except OSError:
            pass
        fence_cache[path] = marks
    return fence_cache[path].get(lineno, False)

path = None; newno = 0; noncomment = []; comment_changes = 0
for l in diff.splitlines():
    if l.startswith("+++ "):
        path = l[6:] if l.startswith("+++ b/") else None; continue
    if l.startswith("--- "):
        continue
    m = re.match(r"^@@ -\d+(?:,\d+)? \+(\d+)(?:,(\d+))? @@", l)
    if m:
        newno = int(m.group(1)); continue
    if path is None:
        continue
    if l.startswith("-"):
        body = l[1:]
        ok = (is_md(path)) or comment(body)
        if not ok:
            noncomment.append((path, "-", "?", body))
        continue
    if l.startswith("+"):
        body = l[1:]
        if is_md(path):
            ok = not in_fence(path, newno)
        else:
            ok = comment(body)
        if ok:
            comment_changes += 1
            if a.list:
                print(f"  주석 {path}:{newno}  {body.strip()[:120]}")
        else:
            noncomment.append((path, "+", newno, body))
        newno += 1

for p, add, dele in bad_count:
    print(f"  줄 수 변동 {p}: +{add} -{dele}")
for p, sign, n, body in noncomment:
    print(f"  주석 아님 {sign} {p}:{n}  {body.strip()[:140]}")
print(f"주석·문서 줄 변경 {comment_changes} · 주석 아닌 줄 변경 {len(noncomment)} · 줄 수 변동 파일 {len(bad_count)} (기준 {a.base})")
sys.exit(1 if (noncomment or bad_count) else 0)
