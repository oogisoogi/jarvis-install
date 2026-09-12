#!/usr/bin/env python3
# 뮤턴트 — 「멈추지 않는 설치기」 수정이 실제로 서 있는지 재는 도구 (2026-09-09)
#
# 쓰는 법
#   python3 tests/never-stalls-mutate.py --list
#   python3 tests/never-stalls-mutate.py --mutant <이름> --print-src        (어느 폴더를 복사해야 하는가)
#   python3 tests/never-stalls-mutate.py --mutant <이름> --print-expect     (붉어져야 할 축 이름 · checker = 검사기 직접)
#   python3 tests/never-stalls-mutate.py --src <폴더> --dst <사본> --mutant <이름>
#   python3 tests/never-stalls-mutate.py --src <폴더> --audit               (앵커가 아직 걸리는가만)
#
# ⛔실물을 고치지 않는다(언제나 --dst 사본에만).
# ★앵커가 안 걸리면 rc 3 으로 **소리내어** 멈춘다 — 「안 망가뜨린 것」과 「망가뜨렸는데 안 붉어진 것」은 다르다.
import argparse, pathlib, shutil, sys

MUTANTS = {
    # 원인 3종을 한 문장으로 뭉뚱그린다 — 백신 붙듦과 섞여 거짓 안내가 되던 그 모양.
    "net-lump": {
        "srcdir": "install-master", "file": "bootstrap.sh",
        "old": """    none)   printf '인터넷 연결이 없어서' ;;
    ours)   printf '우리 서버가 응답하지 않아서' ;;
    theirs) printf '설치 파일을 받는 바깥 서버가 응답하지 않아서' ;;""",
        "new": """    none|ours|theirs) printf '서버 사정으로' ;;""",
        "expect": "[대기] bootstrap.sh 원인 ①인터넷 없음",
    },
    # 상한을 넘겼는데 성공으로 돌려준다 — 기다리다 만 것을 「됐다」로 적는 자리.
    "net-timeout-zero": {
        "srcdir": "install-master", "file": "bootstrap.sh",
        "old": """  jcode "$(net_cause_code "$cause")" "$(net_cause_words "$cause") 진행하지 못했습니다"
  return 1""",
        "new": """  jcode "$(net_cause_code "$cause")" "$(net_cause_words "$cause") 진행하지 못했습니다"
  return 0""",
        "expect": "[대기] sh 상한 초과는 비영으로 끝난다",
    },
    # 끝맺음을 트랩에서 뗀다 — 어떤 끝에서는 「다음에 할 일」이 사라진다.
    "no-closing": {
        "srcdir": "install-master", "file": "bootstrap.sh",
        "old": """trap 'closing_note; rm -f "$ROWS_FILE"' EXIT""",
        "new": """trap 'rm -f "$ROWS_FILE"' EXIT""",
        "expect": "[끝] sh 끝맺음이 트랩에 매달려 있다",
    },
    # 표가 「윈도우에서만」이라고 적은 코드를 「공통」으로 바꾼다 — 맥에는 없으므로 검사기가 잡아야 한다.
    "os-lump": {
        "srcdir": "tests", "file": "help-rules.tsv",
        "old": "J-AV-03\t지난 실행이 끝을 알리지 않고 멈췄다(창이 갑자기 닫힘)",
        "new": None,   # 줄 끝의 win 을 both 로 바꾼다(아래 특수 처리)
        "expect": "checker",
        "line": True, "swap_tail": ("\twin", "\tboth"),
    },
    # 윈도우 쪽 연결 대기가 상한을 넘기고도 성공을 돌려준다 — 기다리다 만 것을 「됐다」로 적는 자리.
    "ps-timeout-true": {
        "srcdir": "install-master", "file": "bootstrap.ps1",
        "old": """    Write-JCode (Get-NetCauseCode $cause) ((Get-NetCauseWords $cause) + ' 진행하지 못했습니다')
    return $false""",
        "new": """    Write-JCode (Get-NetCauseCode $cause) ((Get-NetCauseWords $cause) + ' 진행하지 못했습니다')
    return $true""",
        "expect": "[대기] ps1 상한 초과는 거짓으로 끝난다",
    },
    # 프로브를 「2xx 만 닿음」으로 되돌린다 — 403 을 주는 망에서 멀쩡한 서버를 「응답 없음」이라 말하게 된다.
    "status-strict": {
        "srcdir": "install-master", "file": "bootstrap.ps1",
        "old": """        try { if ($_.Exception.Response) { return $true } } catch { }
        return $false""",
        "new": """        return $false""",
        "expect": "[대기] ps1 프로브가 상태코드로 닿음을 부정하지 않는다",
    },
    # 규칙 표에서 한 행을 지운다 — 설치기는 그 코드를 계속 내보내는데 사람이 찾을 곳이 없어진다.
    "rule-drop": {
        "srcdir": "tests", "file": "help-rules.tsv",
        "old": "J-DISK-01\t저장 공간이 부족하다\t저장 공간이 부족합니다",
        "new": "# (뮤턴트가 지운 행) J-DISK-01",
        "expect": "checker",
        "line": True,   # 줄 단위로 지운다
    },
}


def read(p):
    b = p.read_bytes()
    bom = b[:3] == b"\xef\xbb\xbf"
    t = b.decode("utf-8-sig")
    crlf = "\r\n" in t
    return t.replace("\r\n", "\n"), bom, crlf


def write(p, t, bom, crlf):
    if crlf:
        t = t.replace("\n", "\r\n")
    p.write_bytes((b"\xef\xbb\xbf" if bom else b"") + t.encode("utf-8"))


def target_text(t, m):
    if m.get("line"):
        for ln in t.split("\n"):
            if ln.startswith(m["old"]):
                return ln
        return None
    return m["old"] if t.count(m["old"]) == 1 else None


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--src"); ap.add_argument("--dst"); ap.add_argument("--mutant")
    ap.add_argument("--print-expect", action="store_true")
    ap.add_argument("--print-src", action="store_true")
    ap.add_argument("--list", action="store_true")
    ap.add_argument("--audit", action="store_true")
    a = ap.parse_args()
    here = pathlib.Path(__file__).resolve().parent.parent

    if a.list:
        print(" ".join(MUTANTS)); return 0
    if a.print_expect or a.print_src:
        if a.mutant not in MUTANTS:
            sys.stderr.write("모르는 뮤턴트: %s\n" % a.mutant); return 2
        print(MUTANTS[a.mutant]["expect" if a.print_expect else "srcdir"]); return 0

    if a.audit:
        bad = []
        for name, m in MUTANTS.items():
            f = here / m["srcdir"] / m["file"]
            t, _, _ = read(f)
            hit = target_text(t, m)
            print("  %-17s %-14s %s" % (name, m["file"], "앵커 1개" if hit else "앵커 없음/여럿"))
            if not hit:
                bad.append(name)
        if bad:
            sys.stderr.write("::error::앵커가 안 걸리는 뮤턴트: %s\n" % " ".join(bad)); return 3
        print("앵커 전건 확인 — 대조 가능합니다."); return 0

    if a.mutant not in MUTANTS or not a.src or not a.dst:
        sys.stderr.write("쓰는 법: --src <폴더> --dst <사본> --mutant <이름>\n"); return 2
    m = MUTANTS[a.mutant]
    src, dst = pathlib.Path(a.src), pathlib.Path(a.dst)
    if dst.exists():
        shutil.rmtree(dst)
    shutil.copytree(src, dst)
    f = dst / m["file"]
    t, bom, crlf = read(f)
    hit = target_text(t, m)
    if not hit:
        sys.stderr.write("::error::앵커가 1개가 아닙니다(%s · %s) — 원본이 바뀌었습니다\n" % (a.mutant, m["file"]))
        return 3
    if m.get("swap_tail"):
        tail_from, tail_to = m["swap_tail"]   # ⚠argparse 의 a 를 가리면 안 된다(첫 판에서 그 자리에 걸렸다)
        if not hit.endswith(tail_from):
            sys.stderr.write("::error::바꿀 꼬리(%s)가 그 줄에 없습니다\n" % tail_from); return 3
        newline = hit[: -len(tail_from)] + tail_to
    else:
        newline = m["new"]
    write(f, t.replace(hit, newline, 1), bom, crlf)
    print("뮤턴트 %s 적용: %s (붉어져야 할 것 = %s)" % (a.mutant, m["file"], m["expect"]))
    return 0


sys.exit(main())
