#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""로그인 보존 축 — 지운 뒤의 자리를 씨앗의 기대와 대조한다.

⚠글자로 비교하지 않는다. **파싱한 뒤 뜻으로 비교한다.**
  글자 비교는 줄바꿈·칸 순서만 달라도 붉어져서, 진짜 손실을 덮어 버린다.
  반대로 「파일이 있다」만 보면 안이 텅 비어도 초록이 된다. 그 사이가 이 검사기의 자리다.

무엇을 가려 내는가 (두 등급 — 섞으면 판정이 흐려진다)
  치명 = 값·칸이 없어졌거나 뜻이 바뀌었다. 이것이 하나라도 있으면 적색이다.
  표기 = 뜻은 같은데 적는 모양만 바뀌었다(2.0 을 2 로 적는 따위). 적어 두되 적색으로 세지 않는다.

쓰는 법
  python3 tests/login-verify.py --home <자리> --expect <기대파일> [--expect-fail]
  --expect-fail 은 뮤턴트 시험용이다 — 「치명이 나와야 정상」인 실행에서 쓴다.
"""
import argparse, hashlib, json, os, sys

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

FATAL, COSMETIC = "치명", "표기"


def read_json(path):
    """파일을 읽어 (객체, 오류, BOM여부) 를 돌려준다."""
    if not os.path.exists(path):
        return None, "파일이 없습니다", False
    raw = open(path, "rb").read()
    bom = raw[:3] == b"\xef\xbb\xbf"
    text = raw.decode("utf-8-sig", errors="replace")
    try:
        return json.loads(text), None, bom
    except Exception as e:
        return None, "JSON 으로 읽히지 않습니다: %s" % e, bom


def kind(v):
    if isinstance(v, bool):
        return "참거짓"
    if isinstance(v, (int, float)):
        return "숫자"
    if isinstance(v, str):
        return "글자"
    if isinstance(v, list):
        return "목록"
    if isinstance(v, dict):
        return "묶음"
    if v is None:
        return "없음"
    return type(v).__name__


def compare(exp, got, path, out):
    ke, kg = kind(exp), kind(got)
    if ke != kg:
        # 숫자끼리의 정수·실수 차이만 표기로 본다
        if {ke, kg} == {"숫자"}:
            pass
        else:
            out.append((FATAL, path, "%s 이어야 하는데 %s 입니다 (기대=%r 실제=%r)"
                        % (ke, kg, exp, got)))
            return
    if ke == "묶음":
        for k in exp:
            if k not in got:
                out.append((FATAL, path + "/" + str(k), "칸이 사라졌습니다 (기대=%r)" % (exp[k],)))
            else:
                compare(exp[k], got[k], path + "/" + str(k), out)
        for k in got:
            if k not in exp:
                out.append((FATAL, path + "/" + str(k), "없던 칸이 생겼습니다 (실제=%r)" % (got[k],)))
        return
    if ke == "목록":
        if len(exp) != len(got):
            out.append((FATAL, path, "칸 수가 다릅니다 (기대=%d 실제=%d)" % (len(exp), len(got))))
            return
        for i, (a, b) in enumerate(zip(exp, got)):
            compare(a, b, path + "/[%d]" % i, out)
        return
    if ke == "숫자" or kg == "숫자":
        # 🔴교차 검토 [2] 채택(2026-09-08): 정수끼리는 **실수로 바꾸기 전에** 그대로 견준다.
        #   `float()` 을 거치면 2^53 을 넘는 정수가 뭉개져도 같아 보인다 —
        #   9007199254740993 이 …992 가 되어도 두 실수는 같다. 그러면 **진짜 손실이 표기로 샌다.**
        #   `.claude.json` 에는 밀리초 시각처럼 그만한 정수가 실제로 들어 있다.
        if isinstance(exp, int) and isinstance(got, int):
            if exp == got:
                return
            out.append((FATAL, path, "숫자가 바뀌었습니다 (기대=%r 실제=%r)" % (exp, got)))
            return
        try:
            same = float(exp) == float(got)
        except (OverflowError, ValueError):
            same = False
        if same:
            if type(exp) is not type(got):
                out.append((COSMETIC, path, "값은 같고 적는 모양만 바뀌었습니다 (%r → %r)" % (exp, got)))
            return
        out.append((FATAL, path, "숫자가 바뀌었습니다 (기대=%r 실제=%r)" % (exp, got)))
        return
    if exp != got:
        note = ""
        if ke == "글자" and len(exp) > 60:
            note = " (긴 문자열 — 기대 %d 자, 실제 %d 자)" % (len(exp), len(got))
            out.append((FATAL, path, "글자가 바뀌었습니다%s" % note))
            return
        if ke == "글자" and ("T" in exp and ":" in exp):
            note = " ← 날짜꼴 문자열입니다. 읽고 다시 적는 사이에 날짜로 바뀌었을 수 있습니다"
        out.append((FATAL, path, "값이 바뀌었습니다 (기대=%r 실제=%r)%s" % (exp, got, note)))


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--home", required=True)
    ap.add_argument("--expect", required=True)
    ap.add_argument("--expect-fail", action="store_true")
    ap.add_argument("--expect-fail-at", default="",
                    help="뮤턴트 시험에서 **그 자리에** 치명이 났는지까지 본다")
    a = ap.parse_args()

    home = os.path.abspath(a.home)
    exp = json.load(open(a.expect, encoding="utf-8"))
    out = []

    # ⓐ 로그인 파일 — 바이트가 그대로여야 한다
    cred = os.path.join(home, ".claude", ".credentials.json")
    if not os.path.exists(cred):
        out.append((FATAL, "로그인 파일", "지워졌습니다 · %s" % cred))
    else:
        raw = open(cred, "rb").read()
        got = hashlib.sha256(raw).hexdigest()
        if got != exp["cred_sha256"]:
            out.append((FATAL, "로그인 파일", "내용이 바뀌었습니다 (기대 sha256=%s… %d바이트 · 실제=%s… %d바이트)"
                        % (exp["cred_sha256"][:16], exp["cred_bytes"], got[:16], len(raw))))

    # ⓑ ~/.claude.json — 남의 파일 속에서 우리 칸만 빠졌는가
    for label, rel, key in (("클로드 설정", ".claude.json", "claude_json"),
                            ("클로드 설정2", os.path.join(".claude", "settings.json"), "settings")):
        path = os.path.join(home, rel)
        obj, err, bom = read_json(path)
        if err:
            out.append((FATAL, label, "%s · %s" % (err, path)))
            continue
        if bom:
            # BOM 이 붙으면 우리는 읽히는데 정작 클로드(Node 계열)가 못 읽는다.
            out.append((FATAL, label, "맨 앞에 BOM 이 붙었습니다 — 읽는 쪽이 파싱에 실패합니다 · %s" % path))
        compare(exp[key], obj, label, out)

    fatal = [f for f in out if f[0] == FATAL]
    cosmetic = [f for f in out if f[0] == COSMETIC]

    print("=== 로그인 보존 대조 (%s) ===" % exp.get("os", "?"))
    for lvl, path, msg in out:
        print("  [%s] %s — %s" % (lvl, path, msg))
    if not out:
        print("  다른 곳이 없습니다.")
    print("  치명 %d · 표기 %d" % (len(fatal), len(cosmetic)))

    if a.expect_fail:
        if not fatal:
            print("::error::뮤턴트를 심었는데 축이 초록입니다 — 이 축은 아무것도 재지 못합니다.")
            return 1
        if a.expect_fail_at:
            # ★「적색이 났다」만 보면 **스크립트가 죽어서 난 적색**도 통과한다. 죽으면 씨앗이 그대로
            #   남아 온통 적색이 되기 때문이다. 그때 그 시험이 증명한 것은 「망가뜨렸더니 붉어졌다」가
            #   아니라 「아무것도 안 돌았다」이다. ⇒ **우리가 망가뜨린 자리**에 났는지까지 본다.
            hit = [f for f in fatal if a.expect_fail_at in f[1] or a.expect_fail_at in f[2]]
            if not hit:
                print("::error::적색은 났는데 **엉뚱한 자리**입니다 — 기대한 자리 = %s" % a.expect_fail_at)
                print("        지우개가 아예 안 돌아서 씨앗이 그대로 남았을 수 있습니다(그건 잰 것이 아닙니다).")
                return 1
            print("뮤턴트: 기대한 자리(%s)에 적색이 났습니다 — 축이 제 일을 합니다." % a.expect_fail_at)
            return 0
        print("뮤턴트: 적색이 나왔습니다 — 축이 제 일을 합니다.")
        return 0
    if fatal:
        print("::error::로그인 보존 축 적색 — 위 [치명] 줄을 보십시오.")
        return 1
    print("로그인 보존: 확인 (표기 차이는 적색으로 세지 않습니다)")
    return 0


if __name__ == "__main__":
    sys.exit(main())
