#!/usr/bin/env python3
# 뮤턴트 — 2026-09-09 실사용자 3호 수정이 「실제로 서 있는가」를 재는 도구
#
# ★쓰는 법
#   python3 tests/win-v3-mutate.py --src install-master --dst <사본자리> --mutant <이름>
#   python3 tests/win-v3-mutate.py --mutant <이름> --print-expect   (붉어져야 할 축의 이름)
#   python3 tests/win-v3-mutate.py --src install-master --audit     (앵커가 아직 걸리는가만 본다)
#
# ⛔실물을 고치지 않는다. 언제나 사본(--dst)에만 변이를 낸다.
# ★앵커가 하나도 안 걸리면 조용히 지나가지 않고 rc 3 으로 멈춘다 —
#   「망가뜨렸더니 붉어졌다」와 「애초에 안 망가뜨렸다」는 다른 일이고, 뒤엣것은 초록으로 보인다.
# ⚠줄바꿈을 고른 뒤 대조한다(윈도우 체크아웃은 CRLF 로 놓는다 · 2026-09-08 러너 실측).
import argparse, pathlib, shutil, sys

MUTANTS = {
    # ⓑ 판별을 되돌린다 — 등록 항목이 없어도 설정 앱에서 지우라고 요구한다(그 기계에서 교착이 난 그 모양).
    "reg-blind": {
        "file": "reset-clean.ps1",
        "old": "} elseif ((Test-Path $UninstExe) -and $hasRegEntry) {",
        "new": "} elseif (Test-Path $UninstExe) {",
        "expect": "[⑥] 설정 앱 요구는 항목이 있을 때만",
    },
    # ⓐ 상한을 넘겼는데 0 을 돌려준다 — 설치가 안 된 채 조용히 다음 단계로 간다.
    "silent-timeout": {
        "file": "bootstrap.ps1",
        # ⚠앵커에 **안내 문구 전문**을 박아 두었더니 문구를 고치는 날 앵커가 0곳이 됐다(2026-09-10 러너 실측).
        #   재는 것은 「상한을 넘겼는데 0 을 돌려주지 않는가」이고 문구는 그 성질과 무관하다.
        #   ⇒ 앵커를 **그 갈래의 반환값 자리**로 좁힌다.
        "old": "        Set-NextStepRerun '작업 표시줄에서 백신 창을 찾아 [파일 전송] 또는 [실행] 을 누르신 뒤, 아래 「다시 하시는 법」대로 다시 실행해 주십시오.'\n        return 4",
        "new": "        Set-NextStepRerun '작업 표시줄에서 백신 창을 찾아 [파일 전송] 또는 [실행] 을 누르신 뒤, 아래 「다시 하시는 법」대로 다시 실행해 주십시오.'\n        return 0",
        "expect": "[2] 상한 초과는 비영으로 끝난다",
    },
    # ⓐ 못 읽은 종료 코드를 다시 0 으로 덮는다 — 실패를 삼켜 「성공한 것처럼」 적게 된다.
    "swallow-rc": {
        "file": "bootstrap.ps1",
        "old": "    $installRc = $p.ExitCode\n    $rcShown = if ($null -eq $installRc) { '읽지 못함' } else { [string]$installRc }",
        "new": "    $installRc = if ($null -eq $p.ExitCode) { 0 } else { $p.ExitCode }\n    $rcShown = [string]$installRc",
        "expect": "[2] 못 읽은 종료 코드를 0 으로 덮지 않는다",
    },
    # ⓑ 프로그램을 남기기로 한 실행에서 목록 항목만 지운다 — 설정 앱에서 cys 가 사라진다(교착 자가 생산).
    "reg-orphan": {
        "file": "reset-clean.ps1",
        "old": """    if ($script:SkipCysDir -and $hasRegEntry) {
        Write-Host '  남김: cys 설치 목록 항목 (프로그램이 남아 있어 설정 앱에서 지우실 수 있게 둡니다)'
    } else {
        Drop 'cys 설치 목록 항목' $RegKey
    }""",
        "new": "    Drop 'cys 설치 목록 항목' $RegKey",
        "expect": "[⑥] 프로그램을 남기면 목록 항목도 남긴다",
    },
    # ⓑ 돌고 있는지 보지 않고 지운다 — 폴더가 안 지워졌는데 지웠다고 적게 된다.
    "no-proc-check": {
        "file": "reset-clean.ps1",
        "old": "        $alive = @(Stop-CysProcesses)",
        "new": "        $alive = @()",
        "expect": "[⑥] 그 확인이 실측이다",
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


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--src")
    ap.add_argument("--dst")
    ap.add_argument("--mutant")
    ap.add_argument("--print-expect", action="store_true")
    ap.add_argument("--audit", action="store_true")
    a = ap.parse_args()

    if a.print_expect:
        if a.mutant not in MUTANTS:
            sys.stderr.write("모르는 뮤턴트: %s\n" % a.mutant); return 2
        print(MUTANTS[a.mutant]["expect"]); return 0

    if not a.src:
        sys.stderr.write("--src 가 필요합니다\n"); return 2
    src = pathlib.Path(a.src)

    if a.audit:
        bad = []
        for name, m in MUTANTS.items():
            t, _, _ = read(src / m["file"])
            n = t.count(m["old"])
            print("  %-16s %s  앵커 %d 개" % (name, m["file"], n))
            if n != 1:
                bad.append("%s(%d)" % (name, n))
        if bad:
            sys.stderr.write("::error::앵커가 1개가 아닌 뮤턴트: %s\n" % " ".join(bad)); return 3
        print("앵커 전건 1개 — 대조 가능합니다."); return 0

    if a.mutant not in MUTANTS:
        sys.stderr.write("모르는 뮤턴트: %s\n" % a.mutant); return 2
    if not a.dst:
        sys.stderr.write("--dst 가 필요합니다\n"); return 2
    m = MUTANTS[a.mutant]
    dst = pathlib.Path(a.dst)
    if dst.exists():
        shutil.rmtree(dst)
    shutil.copytree(src, dst)

    f = dst / m["file"]
    t, bom, crlf = read(f)
    if t.count(m["old"]) != 1:
        sys.stderr.write("::error::앵커가 1개가 아닙니다(%s · %s) — 원본이 바뀌었습니다\n" % (a.mutant, m["file"]))
        return 3
    write(f, t.replace(m["old"], m["new"], 1), bom, crlf)
    print("뮤턴트 %s 적용: %s (붉어져야 할 축 = %s)" % (a.mutant, m["file"], m["expect"]))
    return 0


sys.exit(main())
