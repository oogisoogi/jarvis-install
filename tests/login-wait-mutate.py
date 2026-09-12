#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""승인 대기 뮤턴트 — 새 축이 눈먼 초록이 아닌지 잰다 (2026-09-11 · v0.3.13)

★왜: 오늘 쓴 축은 처음부터 전부 초록이었다. 초록인 까닭이 「수정이 섰기 때문」인지
  「축이 아무것도 못 보기 때문」인지는 **되돌려 봐야만** 갈린다. 이 저장소에서 새 축이
  눈먼 채 초록이었던 일이 여러 번 있었다.

쓰는 법: python3 tests/login-wait-mutate.py --root <스냅샷 worktree>
⛔라이브 트리에서 돌리지 마라 — 파일을 고쳤다 되돌리며, 중간에 죽으면 고친 채 남는다.
"""
import argparse, pathlib, subprocess, sys

for _s in (sys.stdout, sys.stderr):
    try: _s.reconfigure(encoding="utf-8", errors="backslashreplace")
    except Exception: pass

ap = argparse.ArgumentParser()
ap.add_argument('--root', required=True)
WT = pathlib.Path(ap.parse_args().root).expanduser().resolve()

# (이름, 찾을 것, 바꿀 것, 붉어져야 하는 축 조각)
MUTANTS = [
 ("M-A 기다리는 동안 아무 말도 안 한다",
  '    tell "     브라우저의 승인 화면에서 「코드」를 복사해 이 창에 붙여넣고 Enter 를 눌러 주십시오."',
  '    :',
  ["[대기] 간격마다 안내를 인쇄한다"]),
 ("M-B 상한 비교를 죽인다(무한 대기로 되돌린다)",
  '    if [ "$waited" -ge "$LOGIN_WAIT_TIMEOUT" ]; then',
  '    if [ "$waited" -ge 999999999 ]; then',
  ["[상한] 상한에서 기다림이 끝난다"]),
 # ⚠「INT 한 줄만 지우기」는 얕다 — 뒤의 TERM 그물이 받아 준다(그물이 둘인 것은 설계대로).
 #   ⇒ 상한이 **아무 신호도 안 보내는** 판으로 되돌린다.
 ("M-C 상한에 말만 하고 아무 신호도 안 보낸다(회복 경로 단절)",
  ['  kill -INT "$pid" 2>/dev/null', '    kill -TERM "$pid" 2>/dev/null'],
  ['  : "$pid"', '    : "$pid"'],
  ["[상한] 상한에서 기다림이 끝난다", "[표적] 제 표적은 실제로 끝낸다"]),
 ("M-D 안내를 화면이 아니라 표준출력으로 흘린다",
  """tell() { printf '%s\\n' "$*" >&2; }""",
  """tell() { printf '%s\\n' "$*"; }""",
  ["[대기] 안내는 화면(stderr)에만 간다"]),
 ("M-E 기다린 시간을 말하지 않는다",
  '    tell "     (기다린 지 $(( waited / 60 ))분 · 창을 닫거나 Ctrl-C 를 누르시면 다시 하는 법을 안내합니다)"',
  '    tell "     (잠시만 기다려 주십시오)"',
  ["[대기] 얼마나 기다렸는지 함께 말한다", "[대기] 빠져나가는 법을 함께 말한다"]),
 # ── 외부 검토 1차 확정분을 되돌려 본다 ────────────────────────────
 ("M-F 표적의 시작 시각을 안 본다(번호만 맞으면 쏜다 · HIGH 되돌리기)",
  '  [ "$now" = "$born" ] || return 0       # 번호가 재사용됐다 — 남의 프로세스다',
  '  : "$born"',
  ["[표적] 시작 시각이 다르면 그 번호에 안 보낸다(번호 재사용 방어)"]),
 ("M-G 감시자가 제 자식(sleep)을 안 데려간다(MEDIUM 되돌리기)",
  """  trap 'kill "$sleep_pid" 2>/dev/null; exit 0' TERM INT""",
  "  :",
  ["[고아] 감시자가 끝나며 제 자식(sleep)도 데려간다"]),
 # ⚠그물이 둘이다(파일이 있는가 · 번호가 숫자인가). 하나만 걷으면 안 붉어진다 — 둘 다 걷는다.
 ("M-H 표적이 없어도 「끝냅니다」라고 말한다(성공 경로 파괴)",
  ['  [ -f "$pidfile" ] || return 0          # 이미 끝났고 표적도 치웠다',
   """  case "$pid" in ''|*[!0-9]*) return 0 ;; esac""",
   '  [ -n "$now" ] || return 0              # 그 번호는 이제 없다'],
  ['  :', '  :', '  :'],
  ["[표적] 표적이 치워졌으면 조용히 물러난다"]),
]

SH = WT / "install-master/bootstrap.sh"

def run_double():
    r = subprocess.run(['bash', 'tests/login-wait-double.sh'], cwd=WT,
                       capture_output=True, text=True)
    return r.stdout

def main():
    base = run_double()
    red_base = [l for l in base.split('\n') if l.startswith('  FAIL')]
    print("기준선 적색 %d개" % len(red_base))
    if red_base:
        print("::경고:: 기준선이 이미 붉다 — 뮤턴트 판정이 의미 없다"); return 1
    bad = 0
    orig = SH.read_text(encoding='utf-8')
    for name, old, new, axes in MUTANTS:
        olds = old if isinstance(old, list) else [old]
        news = new if isinstance(new, list) else [new]
        if any(o not in orig for o in olds):
            print("SKIP-BROKEN  %-48s ← 앵커를 못 찾았다(뮤턴트가 낡았다)" % name); bad += 1; continue
        mutated = orig
        for o, n in zip(olds, news):
            mutated = mutated.replace(o, n, 1)
        SH.write_text(mutated, encoding='utf-8')
        try:
            out = run_double()
            reds = [l for l in out.split('\n') if l.startswith('  FAIL')]
            got = [a for a in axes if any(a in l for l in reds)]
            if len(got) == len(axes):
                print("붉음  %-48s ← %s" % (name, ' · '.join(axes)))
            else:
                miss = [a for a in axes if a not in got]
                print("눈멂  %-48s ← 안 붉어진 축: %s" % (name, ' | '.join(miss))); bad += 1
        finally:
            SH.write_text(orig, encoding='utf-8')
    after = run_double()
    if [l for l in after.split('\n') if l.startswith('  FAIL')]:
        print("::경고:: 원복 뒤에도 적색이 있다"); bad += 1
    print("\n뮤턴트 %d개 · 눈먼 축 %d개" % (len(MUTANTS), bad))
    return 1 if bad else 0

sys.exit(main())
