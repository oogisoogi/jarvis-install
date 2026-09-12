#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""로그인 보존 축 — 뮤턴트를 심는다(축이 정말 재는지 확인하는 용도).

왜 필요한가
  검사 축이 초록이라는 말은 두 가지 중 하나다 — 「수정이 서 있다」이거나 「축이 아무것도 안 잰다」.
  둘을 가르는 유일한 방법은 **일부러 망가뜨려 보고 붉어지는지 보는 것**이다.

무엇을 심는가 (지우개가 실제로 저지를 법한 실수만)
  mac-cred-delete     로그인 파일을 같이 지운다        → ⓐ 가 붉어져야 한다
  mac-hook-overreach  남의 훅까지 싹 지운다            → ⓒ 가 붉어져야 한다
  mac-json-overreach  로그인과 이어진 칸까지 뺀다      → ⓑ 가 붉어져야 한다
  win-cred-delete     로그인 파일을 같이 지운다        → ⓐ
  win-shallow-depth   JSON 왕복 깊이를 2로 줄인다      → ⓑ (깊은 칸이 뭉개진다)
  win-hook-overreach  남의 훅까지 싹 지운다            → ⓒ

★넷째 칸은 **검사기가 찍는 자리 문자열**이다(사람 말이 아니라 대조용 값이다).
  왜: 「적색이 났다」만 보면 **뮤턴트가 아니라 스크립트가 죽어서 난 적색**도 통과한다 —
  스크립트가 죽으면 씨앗이 그대로 남아 검사기가 온통 적색을 내기 때문이다. 그러면 그 시험은
  「망가뜨렸더니 붉어졌다」가 아니라 「아무것도 안 돌았다」를 증명한 것이 된다.
  ⇒ **붉어진 자리가 우리가 망가뜨린 자리인지**까지 본다(`--expect-fail-at`).

⚠앵커를 못 찾으면 **조용히 지나가지 않는다.** 조용히 지나가면 「뮤턴트를 심었다」가 거짓이 되고,
  그 거짓 위에서 축이 초록을 내면 우리는 안 잰 것을 잰 것으로 세게 된다.

쓰는 법
  python3 tests/login-mutate.py --src install-master --dst <임시> --mutant <이름>
"""
import argparse, os, shutil, sys

# ⚠윈도우의 파이썬은 stdout 을 그 기계의 코드페이지(cp1252·cp949)로 잡는다 — 이 파일은 한글로
#   말하므로 **첫 줄을 찍는 순간** UnicodeEncodeError 로 죽는다(러너 첫 실행 실측 2026-09-08 ·
#   같은 날 운영자 노트북에서 난 즉사와 같은 병이다). 여기서 UTF-8 로 되돌린다.
#   errors="backslashreplace" 인 까닭: 못 찍는 글자가 있어도 **죽지 않고 그 자리를 보여 주는** 것이
#   검사 축에서는 낫다. 죽으면 잰 것이 없어지고, 남으면 무엇이 문제인지 다음 사람이 본다.
for _s in (sys.stdout, sys.stderr):
    try:
        _s.reconfigure(encoding="utf-8", errors="backslashreplace")
    except Exception:
        pass

MUTANTS = {
    # 이름: (파일, 찾을 것, 바꿀 것, 붉어져야 할 자리, 앵커가 걸려야 하는 **곳 수**)
    #
    # 🔴다섯째 칸이 왜 생겼나(러너 3차 실행 2026-09-08 · run 34210064678):
    #   인코딩 수정으로 `ConvertTo-Json -Depth 40` 이 한 곳에서 **세 곳**이 됐다. 하네스는
    #   「앵커가 3 곳」이라며 정직하게 멈췄는데(그건 잘한 일이다), **그 사실을 알아내는 데 러너 한 판을
    #   썼다.** 곳 수를 표에 적어 두면 `--audit` 이 개발기에서 0.2초에 잡는다.
    #   ★정직한 실패는 옳지만, **더 싼 자리에서 실패하는 것이 더 옳다.**
    "mac-cred-delete": (
        "reset-clean.sh",
        '  say "  남김: 클로드 대화·기록"',
        '  rm -f "$HOME/.claude/.credentials.json"\n  say "  남김: 클로드 대화·기록"',
        "로그인 파일",
        1,
    ),
    "mac-hook-overreach": (
        "reset-clean.sh",
        "            kept=[e for e in v if not ours(e)]",
        "            kept=[]",
        "클로드 설정2/hooks",
        1,
    ),
    "mac-json-overreach": (
        "reset-clean.sh",
        "  strip_json_key \"$HOME/.claude.json\" 'hasCompletedOnboarding'",
        "  strip_json_key \"$HOME/.claude.json\" 'hasCompletedOnboarding'\n"
        "  strip_json_key \"$HOME/.claude.json\" 'oauthAccount'",
        "클로드 설정/oauthAccount",
        1,
    ),
    "win-cred-delete": (
        "reset-clean.ps1",
        "    Write-Host '  남김: 클로드 대화·기록'",
        "    Remove-Item $CredFile -Force -ErrorAction SilentlyContinue\n"
        "    Write-Host '  남김: 클로드 대화·기록'",
        "로그인 파일",
        1,
    ),
    "win-shallow-depth": (
        "reset-clean.ps1",
        "ConvertTo-Json -Depth 40",
        "ConvertTo-Json -Depth 2",
        "클로드 설정/deep",
        # ⚠셋 다 바꾼다. 쓰는 자리 하나만 얕게 하면 이제 **제품의 자기검증이 잡아내 안 쓴다**
        #   (그건 제품이 세진 것이다). 그러면 붉어지는 자리가 「우리 칸이 안 빠졌다」가 되어
        #   「지우개가 아예 안 돌았다」와 구별되지 않는다. 실제로 날 법한 회귀는
        #   **직렬화 깊이가 전체적으로 얕아지는 것**이므로 그 모양으로 심는다.
        3,
    ),
    "win-hook-overreach": (
        "reset-clean.ps1",
        "if ($s -notmatch 'session-start|role-bootstrap') { $keep += $entry }",
        "if ($false) { $keep += $entry }",
        "클로드 설정2/hooks",
        1,
    ),
    # ★러너가 실물에서 잡은 결함을 되돌리는 뮤턴트(2026-09-08 run 34209137309).
    #   읽는 인코딩 하나만 그 기계 기본값으로 되돌리면 남의 한글이 통째로 깨져 다시 쓰인다.
    "win-no-encoding": (
        "reset-clean.ps1",
        "$enc = New-Object System.Text.UTF8Encoding($false, $true)",
        "$enc = [System.Text.Encoding]::Default",
        # 🔴러너 4차 실행이 가르쳐 준 것(2026-09-08 · run 34210608389):
        #   읽는 인코딩을 되돌려도 **더 이상 남의 파일이 깨지지 않는다** — 쓰기 자기검증이 먼저 잡아
        #   「원본은 그대로 두었습니다」로 끝난다. 수정이 실제로 서 있다는 뜻이라 좋은 소식이다.
        #   ⇒ 그러니 이 뮤턴트가 증명할 것은 「한글이 깨진다」가 아니라 **「방어가 발화한다」**이다.
        #   붉어지는 자리는 「우리 칸이 안 빠졌다」가 되는데, 그것만으로는 「지우개가 아예 안 돌았다」와
        #   구별되지 않는다. 그래서 **지우개가 그때 하는 말**까지 함께 본다(CLEANER_SAYS).
        "클로드 설정/hasCompletedOnboarding",
        1,
    ),
    # ⚠이 하나만 --src 가 다르다: 지우개가 아니라 **입구의 거절 장치**를 망가뜨린다.
    #   `--src tests --dst <임시>` 로 부른다. 붉어져야 할 자리 = 「거절하지 않는다」.
    #   (살아 있는 기계에서 시험이 시작되는 것을 막는 장치가 정말 막고 있는지 재는 유일한 길이다 —
    #    장치를 빼 보고 그때 **안 멈추는지** 확인해야 앞의 초록이 장치 덕분임이 증명된다.)
    "guard-removed": (
        "login-seed.py",
        "    rc = refuse_if_live_machine(home, a.allow_live)\n    if rc:\n        return rc",
        "    rc = 0  # (뮤턴트) 거절 장치를 뺐다",
        "입구가 살아 있는 기계에서 멈추지 않는다",
        1,
    ),
}


# 뮤턴트에 따라서는 「어디가 붉어졌는가」만으로 모자란다. 지우개가 그때 **무슨 말을 했는가**까지 봐야
# 「방어가 발화해서 안 고쳤다」와 「그냥 안 돌았다」가 갈린다. 값이 있으면 입구가 지우개 화면에서 찾는다.
CLEANER_SAYS = {
    "win-no-encoding": "쓴 파일을 되읽으니 글자가 달라졌습니다",
}


# 🔴러너 5차 실행이 가르쳐 준 것(2026-09-08 · run 34211220569).
#   윈도우 체크아웃은 `.py` 를 **CRLF** 로 받는다(Git for Windows 기본 autocrlf). 그런데 앵커
#   가운데 하나는 **여러 줄**이라, 줄바꿈이 `\r\n` 이면 `\n` 으로 적은 앵커가 **한 곳도 안 걸린다.**
#   ⇒ 「거절 장치 뮤턴트」가 윈도우에서만 「앵커를 못 찾았습니다」로 멈췄다.
#   ★개발기 `--audit` 은 이것을 못 잡는다 — 여기 파일은 LF 이기 때문이다. **같은 파일이 기계마다
#     다른 바이트로 놓인다**는 것을 앵커가 몰랐던 것이다.
#   ⇒ 세는 것도 바꾸는 것도 **줄바꿈을 고른 뒤** 한다. 쓸 때는 원래 쓰던 줄바꿈으로 되돌린다.
#   (`.gitattributes` 로 `tests/*.py` 를 LF 로 못박아 두기도 했다 — 이건 그것과 무관하게 서는 벨트다.)
def _norm(text):
    return text.replace("\r\n", "\n")


def count_anchor(path, find):
    try:
        text = open(path, "rb").read().decode("utf-8-sig")
    except Exception:
        return None
    return _norm(text).count(_norm(find))


def patch(path, find, repl, want):
    raw = open(path, "rb").read()
    bom = raw[:3] == b"\xef\xbb\xbf"
    text = raw.decode("utf-8-sig")
    crlf = "\r\n" in text
    flat = _norm(text)
    n = flat.count(_norm(find))
    if n != want:
        return n
    flat = flat.replace(_norm(find), _norm(repl))
    if crlf:
        flat = flat.replace("\n", "\r\n")
    out = flat.encode("utf-8")
    if bom:
        out = b"\xef\xbb\xbf" + out
    open(path, "wb").write(out)
    return n


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--src", default="install-master")
    ap.add_argument("--dst", default="")
    ap.add_argument("--mutant", choices=sorted(MUTANTS))
    ap.add_argument("--print-expect", action="store_true",
                    help="붉어져야 할 자리 문자열만 찍고 끝낸다(러너가 검사기에 넘겨 준다)")
    ap.add_argument("--print-cleaner-says", action="store_true",
                    help="지우개가 해야 할 말을 찍고 끝낸다(없으면 빈 줄)")
    ap.add_argument("--audit", action="store_true",
                    help="뮤턴트를 심지 않고, 앵커가 표에 적힌 곳 수만큼 걸리는지만 본다")
    a = ap.parse_args()

    if a.audit:
        # ★러너에서 알아내면 한 판(수십 분)을 쓴다. 여기서는 0.2초다.
        here = os.path.dirname(os.path.abspath(__file__))
        bad = 0
        for name in sorted(MUTANTS):
            fn, fd, _rp, _ex, want = MUTANTS[name]
            base = here if fn.endswith(".py") else os.path.abspath(a.src)
            n = count_anchor(os.path.join(base, fn), fd)
            if n is None:
                print("  [적색] %-18s 파일을 못 읽었습니다: %s" % (name, fn)); bad += 1
            elif n != want:
                print("  [적색] %-18s 앵커가 %s 곳 — 표에 적힌 것은 %d 곳입니다 (%s)"
                      % (name, n, want, fn)); bad += 1
            else:
                print("  ok     %-18s 앵커 %d 곳 (%s)" % (name, n, fn))
        if bad:
            print("::error::뮤턴트 앵커 %d 개가 표와 어긋납니다 — 러너에 보내기 전에 여기서 고치십시오."
                  % bad, file=sys.stderr)
            return 1
        return 0

    if a.print_expect:
        sys.stdout.write(MUTANTS[a.mutant][3])
        return 0

    if a.print_cleaner_says:
        sys.stdout.write(CLEANER_SAYS.get(a.mutant, ""))
        return 0

    if not a.mutant:
        print("--mutant 가 필요합니다(--audit 일 때만 없어도 됩니다).", file=sys.stderr)
        return 2

    fname, find, repl, expect, want = MUTANTS[a.mutant]
    if not a.dst:
        print("--dst 가 필요합니다.", file=sys.stderr); return 2
    if os.path.exists(a.dst):
        shutil.rmtree(a.dst)
    shutil.copytree(a.src, a.dst)

    target = os.path.join(a.dst, fname)
    n = patch(target, find, repl, want)
    if n != want:
        if n == 0:
            print("::error::뮤턴트 앵커를 못 찾았습니다 — %s 안의 그 줄이 바뀌었습니다: %r"
                  % (fname, find), file=sys.stderr)
        else:
            print("::error::앵커가 %d 곳에서 걸립니다 — 표에는 %d 곳이라고 적혀 있습니다."
                  % (n, want), file=sys.stderr)
        print("        축을 고치기 전에는 이 뮤턴트가 아무것도 증명하지 못합니다.", file=sys.stderr)
        print("        `--audit` 을 개발기에서 돌리면 러너를 쓰지 않고 이 줄을 볼 수 있습니다.", file=sys.stderr)
        return 2

    print("뮤턴트 %s 심음 · 파일 %s · 곳 수 %d · 붉어져야 할 자리 = %s" % (a.mutant, fname, n, expect))
    return 0


if __name__ == "__main__":
    sys.exit(main())
