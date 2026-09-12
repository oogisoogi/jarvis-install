#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""PowerShell 괄호 균형 검사 — 개발기에서 파싱 오류의 가장 흔한 갈래를 잡는다.

## 왜 이것이 있는가 (2026-09-10 실기)
`.ps1` 을 고치는 개발기에 **pwsh 가 없다.** 그래서 문법 확인이 러너에만 있었고,
인라인 `if` 의 닫는 중괄호 하나를 빠뜨린 판이 그대로 push 됐다. 결과는 부분 실패가 아니다 —
Windows PowerShell 5.1 은 **파일 전체를 파싱하지 못하고**(MissingEndCurlyBrace) 설치기가
한마디도 못 남기고 죽는다. 사용자 화면에는 영어 오류 세 줄만 남는다.

⛔이것은 파서가 **아니다.** 재는 것은 둘뿐이다: **⑴주석과 문자열을 뺀 뒤 `{} () []` 가 맞는가**
   **⑵따옴표가 그 줄 안에서 닫히는가**(2026-09-11 추가 — 아래 「왜 둘째가 생겼는가」).
   그 하나가 실제로 난 사고의 갈래이고, 파서 없이 결정론으로 잴 수 있는 것도 그 하나다.
   ⇒ 통과가 「문법이 옳다」를 뜻하지 않는다. 러너 검증을 대체하지 않는다(앞당길 뿐이다).

## 문자열·주석을 어떻게 건너뛰는가
- `'…'`(작은따옴표) = 안을 통째로 무시 · `''` 는 escape 된 따옴표
- `"…"`(큰따옴표) = 안을 통째로 무시 · `""` escape · 백틱은 다음 한 글자를 escape
  ⚠큰따옴표 안의 `$( )` 는 코드지만 **여기서는 세지 않는다** — 세려면 진짜 파서가 필요하고,
    이 검사기가 잡으려는 사고(문자열 밖의 긴 인라인 식)는 그 밖에 있다.
- `@'` … `'@` · `@"` … `"@`(here-string) = 줄 단위로 통째 무시
- `#` 부터 줄 끝까지 · `<# … #>` 블록 주석

## 왜 둘째가 생겼는가 (2026-09-11 러너 실측)
문자열 치환으로 코드를 고치다 **닫는 따옴표 하나가 남았다**(`}\'`). 괄호는 멀쩡해서 이 검사기가
초록이었고, `bash -n` 도 없는 파일이라 개발기에서 아무도 못 봤다. 러너의 Windows 판이 파싱에서
죽고 나서야 보였다 — 그 한 글자 때문에 **파일 전체**가 안 읽혔다.
★검사기가 「닫히지 않은 채 줄이 끝나는 것」을 **조용히 닫힌 것으로 세고 있었다.** 세는 방법이
틀리면 축은 거짓 초록을 낸다 — 이 저장소가 다른 자리에서 여러 번 밟은 그 함정이다.

쓰는 법: python3 tests/ps-balance.py install-master/bootstrap.ps1 [...]
        rc 0 = 전건 균형 · rc 1 = 어긋난 자리를 찍고 실패
"""
import io
import sys

PAIRS = {"}": "{", ")": "(", "]": "["}
OPEN = set(PAIRS.values())


def check(path):
    text = io.open(path, encoding="utf-8-sig").read()
    lines = text.split("\n")
    stack = []          # (문자, 줄번호)
    problems = []
    in_here = None      # "'" 또는 '"' — here-string 안
    in_block_comment = False
    for ln, line in enumerate(lines, 1):
        if in_here is not None:
            # 닫는 표시는 줄머리에 온다(앞 공백은 허용하지 않는 것이 PowerShell 규칙이다)
            if line.startswith(in_here + "@"):
                in_here = None
            continue
        i = 0
        n = len(line)
        while i < n:
            c = line[i]
            if in_block_comment:
                if c == "#" and i + 1 < n and line[i + 1] == ">":
                    in_block_comment = False
                    i += 2
                    continue
                i += 1
                continue
            if c == "<" and i + 1 < n and line[i + 1] == "#":
                in_block_comment = True
                i += 2
                continue
            if c == "#":
                break                      # 줄 끝까지 주석
            if c == "@" and i + 1 < n and line[i + 1] in "'\"" and line[i + 2:].strip() == "":
                in_here = line[i + 1]      # here-string 시작 — 이 줄의 나머지는 없다
                break
            if c == "'":
                start = i
                i += 1
                closed = False
                while i < n:
                    if line[i] == "'":
                        if i + 1 < n and line[i + 1] == "'":
                            i += 2
                            continue
                        i += 1
                        closed = True
                        break
                    i += 1
                if not closed:
                    # 🔴작은따옴표 문자열은 **줄을 넘지 못한다**(넘는 것은 here-string 뿐이다).
                    #   앞 판은 안 닫힌 채 줄이 끝나면 조용히 닫힌 것으로 셌다 ⇒ 짝 없는 따옴표
                    #   하나가 그대로 나갔고, 5.1 이 파일을 통째로 못 읽었다(2026-09-11 러너 실측:
                    #   치환하다 남은 `}\'` 한 자리 · 괄호는 멀쩡해서 이 검사기가 초록이었다).
                    problems.append(
                        "%s:%d  작은따옴표가 줄 안에서 닫히지 않았다(%d번째 글자)" % (path, ln, start + 1))
                continue
            if c == '"':
                start = i
                i += 1
                closed = False
                while i < n:
                    if line[i] == "`":
                        i += 2
                        continue
                    if line[i] == '"':
                        if i + 1 < n and line[i + 1] == '"':
                            i += 2
                            continue
                        i += 1
                        closed = True
                        break
                    i += 1
                if not closed:
                    # ⚠큰따옴표는 여러 줄에 걸칠 수 있다(PowerShell 규칙). 그래서 **막지 않고 알린다** —
                    #   이 저장소의 두 설치기에는 그런 문자열이 0건이고, 생기면 그때 사람이 판단한다.
                    problems.append(
                        "%s:%d  큰따옴표가 줄 안에서 닫히지 않았다(%d번째 글자 · 여러 줄 문자열이면 이 검사기를 고쳐라)" % (path, ln, start + 1))
                continue
            if c in OPEN:
                stack.append((c, ln))
            elif c in PAIRS:
                if not stack:
                    problems.append("%s:%d  닫는 '%s' 가 짝 없이 나왔다" % (path, ln, c))
                elif stack[-1][0] != PAIRS[c]:
                    o, oln = stack.pop()
                    problems.append(
                        "%s:%d  '%s' 로 닫았는데 열린 것은 %d줄의 '%s' 다" % (path, ln, c, oln, o))
                else:
                    stack.pop()
            i += 1
    for o, oln in stack:
        problems.append("%s:%d  '%s' 가 닫히지 않았다" % (path, oln, o))
    if in_here is not None:
        problems.append("%s  here-string(@%s)이 닫히지 않았다" % (path, in_here))
    return problems


def main():
    args = sys.argv[1:]
    if not args:
        print("쓰는 법: python3 tests/ps-balance.py <파일.ps1> [...]")
        return 2
    bad = 0
    for p in args:
        probs = check(p)
        if probs:
            bad = 1
            for m in probs:
                print("  어긋남 " + m)
        else:
            print("  ok   %s  괄호 균형" % p)
    if bad:
        print("⛔괄호가 어긋났습니다 — 5.1 은 이런 파일을 **통째로** 파싱하지 못합니다.")
    return bad


if __name__ == "__main__":
    sys.exit(main())
