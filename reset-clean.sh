#!/bin/bash
# 깨끗이 지우기 (맥) — 설치 도우미가 놓은 것을 도로 걷어 낸다
#
# 무엇을 하는가
#   이 컴퓨터의 상태를 먼저 살펴 목록으로 보여 주고, 묻지 않고 치운다(0.3.37 · 사람 손 0).
#   지우는 것은 `footprint.md` 에 적힌 것 가운데 **다시 받을 수 있는 프로그램 파일·등록뿐**이다.
#   사람이 쌓은 자료(자비스 작업 폴더 · ~/.cys · 실행 상태 · 부서 기록)는 `install-jarvis-backup-<날짜-시각>` 보관 폴더로 옮긴다.
#   사진·문서 같은 사용자 파일은 손대지 않는다.
#
# 쓰는 법
#   bash reset-clean.sh            목록을 보여 주고 묻지 않고 치운다(자료는 보관 폴더로 · 0.3.37)
#   bash reset-clean.sh --list     살펴보기만 한다 (아무것도 안 지운다)
#   bash reset-clean.sh --dry-run  지울 목록만 보여 준다 (--list 와 같다)
#   bash reset-clean.sh --yes      알림 뒤 5초를 기다리지 않는다 (재설치 한 줄이 안에서 쓴다 · 0.3.37 부터 묻는 단계는 없다)
#   bash reset-clean.sh --purge-login   로그인까지 지운다 (기본은 로그인을 남긴다)
#   bash reset-clean.sh --keep-app      cys 프로그램은 남긴다 (재설치 한 줄이 안에서 쓴다)
#   bash reset-clean.sh --keep-history  자비스 창 로그인·이전 대화·부서 기록을 제자리에 둔다 (재설치 한 줄이 안에서 늘 쓴다 · 0.3.36·0.3.37)
# 지운 프로그램은 다시 설치하면 돌아온다. 자료는 보관 폴더에 남는다.
#
# ★로그인은 기본으로 남긴다. 재설치 뒤 로그인 손 한 번을 아끼기 위해서다.
#   그리고 맥에서는 로그인이 파일이 아니라 **열쇠고리**에 있어서(2026-09-08 실측),
#   `~/.claude` 를 지우는 것만으로는 어차피 안 지워진다. 지우려면 열쇠고리를 건드려야 하고,
#   그것은 `--purge-login` 을 일부러 붙였을 때만 한다.
set -u

MODE="run"; ASSUME_YES=0; PURGE_LOGIN=0; KEEP_APP=0; KEEP_HISTORY=0
for a in "$@"; do
  case "$a" in
    --list|--dry-run) MODE="list" ;;
    --yes|-y)         ASSUME_YES=1 ;;
    --purge-login)    PURGE_LOGIN=1 ;;
    --keep-app)       KEEP_APP=1 ;;
    --keep-history)   KEEP_HISTORY=1 ;;
    -h|--help)        sed -n '1,25p' "$0"; exit 0 ;;
  esac
done

JARVIS_HOME="${JARVIS_HOME:-$HOME/install-jarvis}"
# 아고라(토론장) 자리 — 🔴**우리가 만들지 않는다**(v0.3.5부터 설치기에서 뗐다).
#   따로 참가하신 분의 자산이므로 **지우지 않고 「있음 · 남깁니다」로 보이기만 한다.**
#   ⚠여기 있는 것은 지우려고 두는 것이 아니라 **손대지 않는다고 말하려고** 두는 것이다.
AGORA_HOME="${AGORA_HOME:-$HOME/.config/agora}"
AGORA_SKILL="$HOME/.claude/skills/agora-delegate"             # 밖 — 남는다
AGORA_SKILL_IN_CYS="$HOME/.cys/claude/skills/agora-delegate"  # cys 계정 자리 안 — 함께 지워진다
# 🔴🔴**보존 경로 목록 — 지우는 자리 「안에」 들어 있어도 지우지 않는다**(검토 지적 채택 2026-09-09).
#   왜 이 목록이 필요한가: 참가 자리는 사람이 `AGORA_HOME` 으로 옮겨 둘 수 있다. 그것이
#   `~/.cys/forum` 이나 `~/install-jarvis/forum` 처럼 **우리가 지우는 자리 안**이면,
#   화면은 「남깁니다」라고 말한 뒤 **상위를 통째로 지워** 열쇠를 함께 날린다.
#   ⇒ 말이 아니라 **지우는 동작**이 보존을 알아야 한다.
#   ⛔임시로 옮겼다 되돌리는 방식은 쓰지 않는다 — 되돌리는 도중 멈추면 그 자리에서 유실된다.
#   한 줄에 한 경로다(공백 든 경로를 쪼개지 않으려고 줄로 나눈다).
PRESERVE_PATHS="$AGORA_HOME
$AGORA_SKILL"
CYS_APP="/Applications/cysr.app"   # 1.0.1 부터 새 이름(installer-speed-pin-0320) · 없으면 옛 이름 자리를 본다
[ -d "$CYS_APP" ] || CYS_APP="/Applications/cys.app"
CYS_APP_OLD=""   # 새 이름이 있는데 옛 이름(cys.app)도 남은 맥 — 둘 다 같은 규칙으로 남기거나 지운다
[ "$CYS_APP" = "/Applications/cysr.app" ] && [ -d /Applications/cys.app ] && CYS_APP_OLD="/Applications/cys.app"
CYS_CLI=""
for c in "$CYS_APP/Contents/MacOS/cys" "$HOME/.local/bin/cys" "/usr/local/bin/cys"; do
  [ -x "$c" ] && { CYS_CLI="$c"; break; }
done
PROFILE_MARKER="# added by jarvis installer (claude PATH)"
KEYCHAIN_SERVICE="Claude Code-credentials"

say()  { printf '%s\n' "$*"; }
# 🔴사람에게 하는 말 가운데 **값을 돌려주는 함수 안에서 하는 말**은 이쪽으로 보낸다(3차 BLOCK ② 확정).
#   `say` 는 표준출력이라 `x="$(그 함수)"` 가 통째로 삼킨다 — 화면에서 사라지고 값이 오염된다.
tell() { printf '%s\n' "$*" >&2; }
short() { printf '%s' "${1/#$HOME/~}"; }

# ── 다시 하시는 법 — 「같은 줄을 다시 돌려 주십시오」는 쓰지 않는다 ───────────
# 🔴2026-09-10 실기에서 **사용자 막힘으로 확정**된 문구다. 「줄」이 무엇인지, 「돌린다」가
#   무슨 뜻인지 모르고, 무엇보다 **그 명령이 화면 어디에도 없었다.** 창이 닫힌 뒤 사이트를
#   다시 찾는 것 자체가 손 하나이고, 사이트에는 명령이 둘이라 어느 쪽인지 고를 수도 없다.
#   ⇒ 막힌 자리에서는 ①창 여는 법 ②복사 ③붙여넣기+Enter 를 적고 **명령 전체를 인쇄한다.**
# ★어느 명령을 인쇄할지는 **들어온 길**이 정한다 — 재설치가 안에서 부를 때 JARVIS_ENTRY=reinstall
#   을 넘겨 준다. 그 길에서 지우기 한 줄을 인쇄하면 사람은 지우기만 되풀이하고 재설치에 못 닿는다.
JARVIS_RERUN_RESET='curl -fsSL https://jarvis.godmeyou.kr/install/reset-clean.sh -o "$HOME/reset-clean.sh" && bash "$HOME/reset-clean.sh"'
JARVIS_RERUN_REINSTALL='curl -fsSL https://jarvis.godmeyou.kr/install/reinstall.sh -o "$HOME/reinstall-jarvis.sh" && bash "$HOME/reinstall-jarvis.sh"'
rerun_cmd() {
  if [ "${JARVIS_ENTRY:-}" = "reinstall" ]; then printf '%s\n' "$JARVIS_RERUN_REINSTALL"
  else printf '%s\n' "$JARVIS_RERUN_RESET"; fi
}
show_rerun_how() {
  say ""
  say "  == 다시 하시는 법 (이대로 따라 하시면 됩니다) =="
  say "   1) Command(⌘)+스페이스를 누르고 터미널 이라고 치신 뒤 [터미널] 을 여십시오."
  say "   2) 아래 명령을 처음부터 끝까지 끌어 선택한 뒤 Command(⌘)+C 를 누르십시오."
  say "   3) 터미널 창을 한 번 누르고 Command(⌘)+V 로 붙여넣은 뒤 Enter(리턴) 를 누르십시오."
  say ""
  say "$(rerun_cmd)"
  say ""
  say "  이미 지워진 것은 다시 지우지 않습니다 — 남은 자리부터 이어서 갑니다."
}

# ── 자리 기준으로 끈다 — 이름으로 끄면 우리가 아는 이름만 꺼진다 (R1 · 2026-09-10) ─────
# 🔴윈도우 실기에서 폴더 삭제를 막은 것은 cysd 가 띄운 **고아 python3**(office-bridge)였다.
#   맥도 같은 구조다(cys.app 안의 런타임이 자식을 띄운다) — 이름만 끄면 그 자식은 안 꺼진다.
# ★재는 것은 **실행 파일이 그 자리 안에 있는가** 하나다(`ps -o comm=` = 윈도우 프로세스 `.Path`).
# 🔴🔴**명령줄 축(`pgrep -f`)을 뺐다**(1차 BLOCK ② 확정 2026-09-10). 두 가지가 틀렸다:
#   ⑴`pgrep -f` 는 **명령줄**을 본다 ⇒ 편집기를 `~/.cys/…` 파일 인자와 함께 열어 둔 것만으로
#     그 편집기가 TERM·KILL 을 받는다. 저장 안 한 남의 작업이 사라진다.
#   ⑵넘긴 경로를 **정규식으로 읽는다** ⇒ `~/.cys/` 의 `.` 이 임의 문자라 `~/acys/…` 처럼
#     **전혀 다른 자리**도 걸린다. 경로를 이스케이프하지 않은 것은 그냥 결함이다.
#   ⇒ 「더 많이 잡는 축」이 아니라 **「엉뚱한 것을 잡는 축」**이었다. 윈도우는 실행 파일 경로만
#     보는데 맥만 명령줄을 봐서 **OS 대칭도 깨져 있었다.** 축을 하나로 줄여 둘을 맞춘다.
#   ⚠줄어든 만큼은 정직하게 적는다: 밖의 해석기가 그 자리 안의 파일을 도는 경우(시스템 파이썬이
#     `~/.cys/…/x.py` 를 도는 경우)는 이제 안 잡는다. 그때는 삭제가 실패하고 **그 사유를 R2 가
#     인쇄한다** — 틀린 것을 죽이는 것보다 못 지웠다고 말하는 편이 낫다.
# ★비교는 **실경로끼리** 한다(2차 N5 확정 2026-09-10). 링크로 적어 둔 별칭에서는 글자 비교가
#   빗나간다 — 우리가 지우는 자리도, 도는 프로세스의 실행 파일도 같은 방식으로 풀어 놓고 견준다.
procs_under() {  # procs_under <자리…> → "pid<탭>확인표<탭>실행 파일" 줄들
  local d pid cmd line roots rc tok
  roots=""
  for d in "$@"; do
    [ -n "$d" ] || continue
    rc="$(canon "$d" 2>/dev/null)" || rc="$d"
    roots="$roots
${rc%/}"
  done
  ps -Ao pid=,comm= 2>/dev/null | sed 's/^[[:space:]]*//' | while IFS= read -r line; do
    pid="${line%% *}"; cmd="${line#* }"
    [ -n "$pid" ] || continue
    # ⚠우리 자신과 **우리를 부른 쪽**은 건드리지 않는다 — 재설치가 안에서 이 스크립트를 부르므로
    #   부모를 죽이면 지우기 도중에 재설치가 통째로 사라진다(반쯤 지운 기계가 남는다).
    [ "$pid" = "$$" ] && continue
    [ "$pid" = "${PPID:-0}" ] && continue
    cmd="$(canon "$cmd" 2>/dev/null || printf '%s' "$cmd")"
    printf '%s\n' "$roots" | while IFS= read -r d; do
      [ -n "$d" ] || continue
      # ★`case` 의 패턴은 **glob** 이다(정규식이 아니다) — `.` 을 글자 그대로 본다.
      case "$cmd" in
        "$d"/*)
          # 🔴🔴**확인표를 못 뜬 번호는 표에 넣지 않는다**(4차 BLOCK ② 확정 2026-09-10).
          #   앞 판은 빈 확인표로 넣었고, 신호 직전 검사는 「확인표가 있을 때만」 견줬다 ⇒ **빈 칸이
          #   곧 통과권**이었다(fail-open). 「첫 조회 실패 → 그 사이 그 번호가 남에게 넘어감」이면
          #   우리가 남의 프로그램에 TERM·KILL 을 보낸다.
          #   ★비워 둔 칸을 「모른다」로 읽는 곳과 「괜찮다」로 읽는 곳이 갈리면, 그 칸은 결국 통과권이 된다.
          #   ⇒ 못 뜬 번호는 **아예 대상에서 뺀다.** 그러면 아래 최종 셈이 「아직 도는 것」으로 잡아
          #     사람에게 그 번호를 말한다 — 못 끄는 것보다 **틀린 것을 끄는 쪽**이 훨씬 비싸다.
          if tok="$(proc_token "$pid" 2>/dev/null)" && [ -n "$tok" ]; then
            printf '%s\t%s\t%s\n' "$pid" "$tok" "$cmd"
          else
            tell "    건너뜀: 번호 $pid 의 상태를 읽지 못해 끄지 않습니다($cmd)."
          fi ;;
      esac
    done
  done
}
# 🔴🔴**번호는 이름이 아니다 — 확인표를 함께 들고 다닌다**(3차 BLOCK ② 확정 2026-09-10).
#   앞 판은 표를 한 번 찍은 뒤 **번호만** 보고 `kill` 했다. 그 사이 대상이 스스로 끝나고 운영체제가
#   같은 번호를 **다른 프로그램에 다시 내주면**, 우리가 보내는 TERM·KILL 은 **남의 프로그램**이 받는다.
#   ⇒ 번호마다 **시작시각 + 실행 파일**을 확인표로 떠 두고, 신호를 보내기 직전에 **다시 읽어 견준다.**
#     같지 않으면 그 번호는 이제 우리 것이 아니다 — 건드리지 않고 그 사실을 말한다.
#   ★되돌릴 수 없는 일(강제 종료)의 대상은 **그 순간에** 확인해야 한다. 표는 과거의 사실이다.
proc_token() {  # proc_token <pid> → "시작시각 실행 파일" (못 읽으면 rc 1)
  local t
  t="$(ps -p "$1" -o lstart=,comm= 2>/dev/null)" || return 1
  [ -n "$t" ] || return 1
  printf '%s' "$t" | tr -s '[:space:]' ' ' | sed 's/^ //; s/ $//'
}
# 🔴🔴**검증된 부모의 자손도 함께 끈다**(2차 N5 · 3차 보강). 밖의 해석기(시스템 파이썬 등)가 cys 안의
#   helper 를 돌면 그 실행 파일은 `/usr/bin/python3` 라 자리 축에 안 잡힌다. 그런데 맥은 **도는 파일도
#   unlink 된다** — 삭제가 성공하고 helper 는 지워진 코드로 계속 돈다(조용한 잔존).
#   ⇒ 명령줄을 보고 잡는 대신 **혈연**으로 잡는다: 자리 축으로 확인된 pid 의 자손을 훑는다.
#   ★표를 **먼저 한 번 찍어 고정**한다 — 부모를 끈 뒤에 훑으면 그 자손은 이미 고아가 돼 관계가 끊긴다.
proc_descendants() {  # proc_descendants <조상 pid…> → 자손 pid(조상 포함)
  local table out prev pid ppid line
  table="$(ps -Ao pid=,ppid= 2>/dev/null | sed 's/^[[:space:]]*//')"
  out=" $* "
  prev=""
  # 🔴🔴**임시 파일을 아예 쓰지 않는다**(4차 REGRESSED N5 확정 2026-09-10).
  #   앞 판은 `/tmp/.jarvis-desc.$$` 를 `>` 로 열었다. 그 이름은 **미리 알 수 있고**(pid 는 작은 수다),
  #   같은 사용자의 다른 프로그램이 그 자리에 **남의 파일을 가리키는 링크**를 미리 만들어 두면
  #   우리 리다이렉션이 그 링크를 따라가 **그 파일을 0바이트로 만들고**, 뒤이어 `rm -f` 가 링크를 지운다.
  #   ⇒ 지우개가 **엉뚱한 파일을 부순다.** r3→r4 에서 우리가 새로 만든 공격면이다.
  #   ★파일을 안전하게 만드는 법을 고민하기 전에 **파일이 정말 필요한지**를 먼저 물어라.
  #     여기서는 필요 없었다 — 파이프 대신 here-doc 으로 읽으면 몸통이 **현재 셸**에서 돌아
  #     변수 대입이 그대로 남는다(임시 파일은 애초에 그 하위 셸 문제를 우회하려던 것이었다).
  # 자손의 자손까지 — 목록이 더 늘지 않을 때까지 훑는다(깊이 상한 = 목록 크기)
  while [ "$out" != "$prev" ]; do
    prev="$out"
    while IFS= read -r line; do
      [ -n "$line" ] || continue
      pid="${line%% *}"; ppid="${line##* }"
      [ -n "$pid" ] || continue
      case "$out" in *" $pid "*) continue ;; esac
      case "$prev" in *" $ppid "*) out="$out$pid " ;; esac
    done <<EOF_PROC_TABLE
$table
EOF_PROC_TABLE
  done
  printf '%s\n' $out
}
# 표에 있는 번호만 뽑는다 — 앞뒤에 **빈칸을 붙여** 돌려준다(구분자 정확 일치용).
table_pids() {
  printf ' '
  printf '%s\n' "$1" | while IFS="$(printf '\t')" read -r pid _; do
    [ -n "$pid" ] && printf '%s ' "$pid"
  done
}
# 표에 없는 자손을 **확인표까지 떠서** 표에 더한다. 몇 번을 불러도 같은 결과다(멱등).
add_descendants() {  # add_descendants <표> → 자손이 더해진 표
  local table="$1" pids pid tok
  pids="$(table_pids "$table")"
  [ "$(printf '%s' "$pids" | tr -d ' ')" = "" ] && { printf '%s\n' "$table"; return 0; }
  for pid in $(proc_descendants $pids | sort -u); do
    [ -n "$pid" ] || continue
    [ "$pid" = "$$" ] && continue
    [ "$pid" = "${PPID:-0}" ] && continue
    # 🔴★번호 비교는 **구분자까지 맞춘다**(3차 N5 확정). 앞 판은 표 전체를 통짜 문자열로 보고
    #   `case "$targets" in *"$pid"*)` 로 물었다 ⇒ 「1234」가 다른 번호나 경로 글자 안에 들어 있기만
    #   해도 **이미 있는 것으로 읽고 그 자손을 목록에서 빠뜨렸다**(그래서 못 끈다).
    case "$pids" in *" $pid "*) continue ;; esac
    tok="$(proc_token "$pid" 2>/dev/null)" || continue
    table="$(printf '%s\n%s\t%s\t%s' "$table" "$pid" "$tok" "(cys 가 띄운 자식)")"
    pids="$pids$pid "
  done
  printf '%s\n' "$table"
}
# 확인표가 그대로일 때만 신호를 보낸다. 달라졌으면 그 번호는 이제 남의 것이다.
kill_verified() {  # kill_verified <신호> <표>
  local sig="$1" pid tok cmd now
  while IFS="$(printf '\t')" read -r pid tok cmd; do
    [ -n "$pid" ] || continue
    # 🔴**빈 확인표는 신호 대상이 아니다**(4차 BLOCK ② 확정). 여기서 「비었으면 그냥 끈다」로 두면
    #   위쪽에서 아무리 걸러도 이 한 줄이 문을 다시 연다 — 같은 규칙을 두 곳에서 세운다.
    [ -n "$tok" ] || { tell "    건너뜀: 번호 $pid 는 확인표가 없어 끄지 않습니다."; continue; }
    now="$(proc_token "$pid" 2>/dev/null)" || continue
    if [ "$now" != "$tok" ]; then
      tell "    건너뜀: 번호 $pid 는 그 사이 다른 프로그램이 되었습니다 — 끄지 않습니다."
      continue
    fi
    kill "-$sig" "$pid" 2>/dev/null
  done <<EOF_KV
$2
EOF_KV
  return 0
}
# 아직 도는 것을 센다 = **자리 축으로 새로 훑은 것** + **우리가 모아 둔 자손 가운데 살아남은 것**.
#   ★뒤쪽을 빼면 안 된다 — 밖의 해석기 자손(`/usr/bin/python3`)은 자리 축에 안 잡혀서,
#     TERM 을 무시하고 살아남아도 「없다」로 끝난다(3차 N5 지적).
alive_after() {  # alive_after <표> <자리…>
  local table="$1"; shift
  local fresh out pids pid tok cmd now
  fresh="$(procs_under "$@" | sort -u)"
  out="$fresh"
  pids="$(table_pids "$fresh")"
  while IFS="$(printf '\t')" read -r pid tok cmd; do
    [ -n "$pid" ] || continue
    case "$pids" in *" $pid "*) continue ;; esac
    now="$(proc_token "$pid" 2>/dev/null)" || continue
    [ -n "$tok" ] && [ "$now" != "$tok" ] && continue
    out="$(printf '%s\n%s\t%s\t%s' "$out" "$pid" "$tok" "$cmd")"
    pids="$pids$pid "
  done <<EOF_AA
$table
EOF_AA
  printf '%s\n' "$out" | sed '/^$/d' | sort -u
}
# 끄고 2초 기다린 뒤 **다시 세어** 남은 것을 찍는다. 「보냈다」는 꺼졌다는 뜻이 아니다.
# 🔴🔴**사람에게 할 말은 표준오류로 보낸다**(3차 BLOCK ② 확정 2026-09-10).
#   앞 판은 `say`(표준출력)로 「끄는 중: …」을 찍었는데, 부르는 쪽이 `CYS_ALIVE="$(stop_cys_processes …)"`
#   로 **표준출력을 통째로 삼켰다.** 결과가 둘 다 나빴다:
#     ⑴사람은 무엇을 끄는지 **끝까지 못 봤다** — 되돌릴 수 없는 일을 말없이 했다.
#     ⑵그 안내문이 「아직 살아 있는 것 표」로 파싱돼 **엉뚱한 경고**가 됐다.
#   ★한 함수가 사람에게 말하면서 값을 돌려주려면 **채널이 둘이어야 한다.** 값 = 표준출력, 말 = 표준오류.
stop_cys_processes() {
  local targets
  # ★①자리 축으로 **부모를 확인**하고 ②그 자손을 **먼저 모아 고정**한 뒤 ③함께 끈다.
  #   ⛔`pkill -f` 는 쓰지 않는다 — 편집기가 그 경로를 파일 인자로 열기만 해도 죽는다(2차 STILL OPEN ②).
  targets="$(procs_under "$@" | sort -u)"
  targets="$(add_descendants "$targets")"
  # 🔴**끄기 전에 무엇을 끄는지 인쇄한다**(1차 BLOCK ② · 3차 채널 분리). 강제 종료는 되돌릴 수 없다 —
  #   우리가 무엇을 골랐는지 사람이 볼 수 없으면, 잘못 골랐을 때 아무도 그것을 모른다.
  if [ -n "$targets" ]; then
    tell "  cys 자리에서 도는 것을 멈춥니다:"
    printf '%s\n' "$targets" | while IFS="$(printf '\t')" read -r pid tok cmd; do
      [ -n "$pid" ] && tell "    끄는 중: $cmd  (번호 $pid)"
    done
  fi
  kill_verified TERM "$targets"
  sleep 2
  # ★끄기 직전에 자손을 **한 번 더** 모은다(3차 N5 확정) — 표를 찍은 뒤 새로 생긴 자손은 목록에 없다.
  #   부모가 먼저 끝나면 그 자손은 고아가 돼 혈연으로 다시 찾을 길이 없으므로, 지금이 마지막 기회다.
  targets="$(add_descendants "$targets")"
  kill_verified KILL "$targets"
  sleep 1
  alive_after "$targets" "$@"
}
# 남은 것을 **사람이 활성 상태 보기에서 찾을 수 있는 만큼** 적는다(최대 5).
write_alive_procs() {
  local n=0 pid tok cmd
  printf '%s\n' "$1" | while IFS="$(printf '\t')" read -r pid tok cmd; do
    [ -n "$pid" ] || continue
    n=$((n+1))
    [ "$n" -gt 5 ] && { say "         (그 밖에 더 있습니다.)"; break; }
    say "         돌고 있는 것: $cmd  (번호 $pid)"
  done
  say "         활성 상태 보기(Activity Monitor)에서 위 번호를 끝내시거나, 컴퓨터를 다시 켜 주십시오."
}

# ── 살펴보기 ──────────────────────────────────────────────────────
# 있는 것만 세는 것이 아니라 **없는 것도 적는다** — 「어디까지 갔는가」가 그 대조에서 나온다.
FOUND=0
row() { # row <있음판정 rc> <이름> <자리>
  #   ⚠칸 맞추기(%-22s)를 쓰지 않는다 — 우리말 한 글자가 여러 바이트라 자리가 어긋나 보인다
  #   (실측 2026-09-08 · 게스트 출력이 삐뚤어졌다). 가운뎃점으로 가르면 어긋날 자리가 없다.
  if [ "$1" -eq 0 ]; then FOUND=$((FOUND+1)); printf '  [있음] %s · %s\n' "$2" "$(short "$3")"
  else                    printf '  [없음] %s · %s\n' "$2" "$(short "$3")"; fi
}
has_marker() { [ -f "$1" ] && grep -qF "$PROFILE_MARKER" "$1" 2>/dev/null; }
profile_with_marker() {
  local f
  for f in "$HOME/.zprofile" "$HOME/.zshrc" "$HOME/.zshenv" "$HOME/.profile" "$HOME/.bash_profile" "$HOME/.bashrc"; do
    has_marker "$f" && { printf '%s\n' "$f"; }
  done
  return 0
}
json_has() { # json_has <파일> <키>  — plutil 로만 본다(파일을 파싱해 흉내내지 않는다)
  [ -f "$1" ] || return 1
  plutil -extract "$2" raw -o - "$1" >/dev/null 2>&1
}
hook_present() { # 각성 훅이 남의 settings.json 에 병합돼 있는가
  [ -f "$1" ] || return 1
  grep -q 'session-start\.sh\|role-bootstrap\.sh' "$1" 2>/dev/null
}
# 🔴자리가 **둘**이다(공식 문서 2026-09-08 확인 · code.claude.com/docs/en/troubleshoot-install):
#   「On macOS, Claude Code saves credentials to the login Keychain. When the Keychain rejects the
#    write, such as when it's locked in an SSH session …, Claude Code saves your login to the
#    plaintext ~/.claude/.credentials.json file instead.」
#   ⇒ 열쇠고리만 보면 **원격으로 로그인한 기계에서는 못 찾는다.** 둘 다 본다.
#   ⑶그리고 자리는 **고정이 아니다**: 「If you've set the CLAUDE_CONFIG_DIR environment variable,
#     Claude Code keeps the .credentials.json file under that directory instead, including the file
#     the macOS fallback writes, and keys the macOS Keychain entry to that directory too」
#     (같은 문서 · 2026-09-08 확인). ⇒ 그 변수가 선 창에서 이 스크립트를 돌리면 **우리가 보는 자리와
#     클로드가 보는 자리가 갈린다.** 갈린 채로 「있음」이라고 적으면 그 줄이 거짓이 된다.
CLAUDE_CFG_DIR="${CLAUDE_CONFIG_DIR:-$HOME/.claude}"
CRED_FILE="$CLAUDE_CFG_DIR/.credentials.json"
# 자비스 창(cys)이 띄우는 클로드는 CLAUDE_CONFIG_DIR 을 ~/.cys/claude 로 두고 뜬다. 그 폴더는
#   아래에서 「cys 계정 자리」로 지워진다 — 혼자 돌리는 지우기에서는 거기 든 것이 같이 사라진다.
#   ★재설치 길(--keep-history)에서는 이전 대화를 **남긴다**(0.3.36 · 아래 HISTORY_KEEP_NAMES).
CYS_CRED_FILE="$HOME/.cys/claude/.credentials.json"
# 🔴0.3.36(09-25 윈 실기 · 윈 $HistoryKeepNames 의 짝): 앞 판은 재설치 길에서도 ~/.cys 를 통째로 지웠다
#   ⇒ 자비스 창의 대화 기록(projects/)이 사라졌다(윈은 좌석들의 가장 새 로그인까지 사라져 세 자리 모두 로그인을 다시 물었다).
#   맥 로그인은 열쇠고리 항목(「Claude Code-credentials-<경로 지문>」)이라 이 도구가 원래 안 지운다(purge_login_first 는 기본 이름 하나 · --purge-login 때만).
#   ⇒ 재설치 길에서는 아래 다섯 자리만 **제자리에** 남기고 나머지는 종전대로 지운다. 이름·근거는 두 OS 같다
#   (공식 문서 code.claude.com/docs/en/claude-directory · 설계 = docs/install-master/DESIGN-login-keep-0336.md 1절).
#   ⚠CLAUDE.md · settings.json · .claude.json · skills 는 남기지 않는다 — cys·설치 도우미가 다시 만든다(CLAUDE.md 는 「없을 때만」 만든다).
#   (.credentials.json 은 맥에 보통 없다 — 있으면 윈과 같이 남긴다.) 한 줄에 한 이름.
HISTORY_KEEP_NAMES=".credentials.json
projects
history.jsonl
file-history
agent-memory"
# 🔴🔴**「없다」와 「못 물어봤다」를 가른다**(4차 BLOCK N1 확정 2026-09-10).
#   앞 판은 `find-generic-password` 가 **어떤 까닭으로든** 0 이 아니면 「없다」로 읽었다. 그런데
#   열쇠고리가 잠겼거나 조회가 거부되면 rc 는 0 도 44 도 아닌 값이다 ⇒ **항목이 남아 있는데도**
#   「없다」가 되고, 로그인 파일까지 없으면 지우기 전체가 **성공으로 끝났다**(거짓 성공).
#   ⇒ 세 상태로 나눈다: rc 0 = present · rc 44(errSecItemNotFound) = absent · 그 밖 = **unknown**.
#   ★이 저장소가 세 라운드 내내 되풀이한 형태다: **모르는 것을 없는 것으로 적으면 실패가 성공이 된다.**
login_keychain_state() {  # → present | absent | unknown
  security find-generic-password -s "$KEYCHAIN_SERVICE" >/dev/null 2>&1
  case $? in
    0)  printf 'present' ;;
    44) printf 'absent' ;;
    *)  printf 'unknown' ;;
  esac
}
login_present() {
  [ "$(login_keychain_state)" = "present" ] && return 0
  [ -f "$CRED_FILE" ]
}
# 로그인 자국을 **세 상태로** 답한다 — 「지웠다」를 말해도 되는지는 이 답이 정한다.
login_state() {  # → present | absent | unknown
  local k
  k="$(login_keychain_state)"
  [ "$k" = "present" ] && { printf 'present'; return 0; }
  [ -f "$CRED_FILE" ] && { printf 'present'; return 0; }
  [ "$k" = "unknown" ] && { printf 'unknown'; return 0; }
  printf 'absent'
}
# 열쇠고리에 같은 이름의 항목이 **몇 개** 있는지 센다(못 세면 빈 값 = 「모른다」).
#   ⚠`-d` 를 붙이지 않으므로 **속성만** 읽는다 — 비밀값을 읽지 않고 암호 확인 창도 뜨지 않는다
#     (이 개발기에서 실측). 값은 어디에도 찍지 않는다.
#   ★왜 세는가: 끝에서 「로그인을 지웠다」를 말할 때 **하나만 지웠는데 여럿 남은 경우**를
#     사람이 알 수 있어야 한다(3차 N1 지적 — 남은 것을 안 세면 거짓 성공이 된다).
#   🔴🔴**파이프가 조회 실패를 삼키던 자리다**(4차 N1 확정). 앞 판은 `dump-keychain | grep -c` 였다 —
#     `dump` 가 실패해도 `grep -c` 는 **0** 을 찍고, 주석이 약속한 「못 세면 빈 값」이 지켜지지 않았다.
#     ⇒ 앞단의 종료값을 **따로 받아** 실패면 빈 값(= 모른다)으로 돌려준다.
#     ★셸에서 「실패를 잃는 자리」는 언제나 파이프다. 이 파일에서 같은 형태를 r4 에도 고쳤다.
login_keychain_count() {
  local dump n=""
  dump="$(security dump-keychain 2>/dev/null)" || { printf ''; return 0; }
  n="$(printf '%s\n' "$dump" | grep -c "\"svce\"<blob>=\"$KEYCHAIN_SERVICE\"" || true)"
  case "$n" in ''|*[!0-9]*) n="" ;; esac
  printf '%s' "$n"
}
# 결정 2026-09-08: 진단 화면에 「현재 로그인」 한 줄을 보인다(값은 안 찍는다).
#   자리를 뒤지는 것보다 **클로드에게 묻는 것**이 낫다 — 자리가 기계마다 다르기 때문이다.
#   클로드가 없으면 그때만 우리가 아는 자리 둘을 본다.
login_status() {
  local c="$HOME/.local/bin/claude"
  [ -x "$c" ] || c="$(command -v claude 2>/dev/null)"
  if [ -n "$c" ]; then
    case "$("$c" auth status 2>/dev/null | tr -d ' ')" in
      *'"loggedIn":true'*)  printf '있음'; return 0 ;;
      *'"loggedIn":false'*) printf '없음'; return 1 ;;
    esac
  fi
  if login_present; then printf '있음(자리로 판단)'; return 0; fi
  printf '없음(우리가 아는 자리 기준)'; return 1
}
login_where() {
  local w=""
  security find-generic-password -s "$KEYCHAIN_SERVICE" >/dev/null 2>&1 && w="열쇠고리"
  [ -f "$CRED_FILE" ] && w="${w:+$w · }파일($(short "$CRED_FILE"))"
  printf '%s' "${w:-없음}"
}

diagnose() {
  FOUND=0
  say "=== 이 컴퓨터의 상태 ==="
  # footprint: M-APP
  if [ "$KEEP_APP" = "1" ]; then
    # 재설치 길 — 프로그램은 남긴다(윈도우 -KeepApp 과 같다). 다시 깔 때 설치 도우미가 판을 확인해
    #   이번 판이면 그대로 쓰고, 아니면 이번 판으로 바꿔 넣는다 — 그래서 여기서 지울 까닭이 없다.
    #   ⚠실행 상태(~/.local/state/cys)는 아래에서 **지난 편성 기록만** 보관 폴더로 옮기고 나머지는 제자리에 둔다
    #     (0.3.37 · 윈 Get-CysStateItems 와 같은 모양 · 앞 판은 통째로 지워 검색 기록까지 사라졌다).
    [ -d "$CYS_APP" ] && say "  [있음] cys 프로그램 · $CYS_APP (남깁니다 — 다시 깔 때 판을 확인해 그대로 쓰거나 바꿉니다)" \
                      || say "  [없음] cys 프로그램 · $CYS_APP"
    [ -n "$CYS_APP_OLD" ] && say "  [있음] cys 프로그램(옛 이름) · $CYS_APP_OLD (남깁니다 — 다시 깔 때 새 이름으로 바꿔 넣으며 한 벌 보관합니다)"
  else
    [ -d "$CYS_APP" ]; row $? 'cys 프로그램' "$CYS_APP"
    if [ -n "$CYS_APP_OLD" ]; then [ -d "$CYS_APP_OLD" ]; row $? 'cys 프로그램(옛 이름)' "$CYS_APP_OLD"; fi
  fi
  # footprint: M-DAEMON
  [ -f "$HOME/Library/LaunchAgents/com.cysjavis.cysd.plist" ]; row $? 'cys 상시 가동 등록' "$HOME/Library/LaunchAgents/com.cysjavis.cysd.plist"
  # footprint: M-CYSHOME
  if [ "$KEEP_HISTORY" = "1" ]; then [ -d "$HOME/.cys" ]; row $? 'cys 계정 자리(로그인·이전 대화·부서 기록은 제자리로 되옮기고 나머지는 보관합니다)' "$HOME/.cys"
  else [ -d "$HOME/.cys" ]; row $? 'cys 계정 자리(보관 폴더로 옮깁니다)' "$HOME/.cys"; fi
  # footprint: M-CYSSTATE
  if [ "$KEEP_HISTORY" = "1" ] || [ "$KEEP_APP" = "1" ]; then [ -d "$HOME/.local/state/cys" ]; row $? 'cys 실행 상태(지난 편성 기록만 보관합니다)' "$HOME/.local/state/cys"
  else [ -d "$HOME/.local/state/cys" ]; row $? 'cys 실행 상태(보관 폴더로 옮깁니다)' "$HOME/.local/state/cys"; fi
  # footprint: M-DEPTSTATE (0.3.37 · 부서 실행 상태 — 재설치는 제자리 · 완전 삭제는 보관)
  local _ds
  for _ds in "$HOME/.local/state"/cys-dept-*; do
    [ -e "$_ds" ] || continue
    if [ "$KEEP_HISTORY" = "1" ] || [ "$KEEP_APP" = "1" ]; then say "  [있음] 부서 실행 상태 · $(short "$_ds") (제자리에 둡니다 — 부서가 그대로 이어집니다)"
    else row 0 '부서 실행 상태(보관 폴더로 옮깁니다)' "$_ds"; fi
  done
  # footprint: M-TRASH (0.3.37 · 닫은 부서 휴지통 — 재설치는 제자리 · 완전 삭제는 보관)
  if [ -d "$HOME/.local/state/cys-trash" ]; then
    if [ "$KEEP_HISTORY" = "1" ] || [ "$KEEP_APP" = "1" ]; then say "  [있음] 닫은 부서 휴지통 · $(short "$HOME/.local/state/cys-trash") (제자리에 둡니다)"
    else row 0 '닫은 부서 휴지통(보관 폴더로 옮깁니다)' "$HOME/.local/state/cys-trash"; fi
  fi
  # footprint: M-WEBVIEW (0.3.37 · 앱 화면(웹뷰) 자료 — 완전 삭제는 보관 · 재설치는 무접촉 · 윈 W-WEBVIEW 짝)
  if [ "$KEEP_HISTORY" != "1" ] && [ "$KEEP_APP" != "1" ]; then
    local _wv
    for _wv in "$HOME/Library/WebKit/com.cysjavis.terminal" "$HOME/Library/Caches/com.cysjavis.terminal" "$HOME/Library/Preferences/com.cysjavis.terminal.plist"; do
      [ -e "$_wv" ] && row 0 '앱 화면 자료(보관 폴더로 옮깁니다)' "$_wv"
    done
  fi
  # 0.3.37: 지난 재설치의 되옮기기가 끊긴 보관본(다음 실행이 먼저 이어서 끝낸다) — 찾은 자국으로 센다(r1 F5 · 윈 짝 $script:Found++):
  #   안 세면 다른 자국이 없을 때 「지울 것이 없습니다」 로 끝나 이어 하기(resume_unfinished_restore)가 영영 안 돈다.
  local _bk _p2=""
  [ "$(dirname "$JARVIS_HOME")" != "$HOME" ] && _p2="$(dirname "$JARVIS_HOME")"   # 두 자리가 같으면 한 번만 센다(r2 N2 · resume 과 같은 거르기)
  for _bk in "$HOME/${JARVIS_BACKUP_PREFIX}"* ${_p2:+"$_p2/${JARVIS_BACKUP_PREFIX}"*}; do
    is_jarvis_backup "$_bk" && [ -f "$_bk/$RESTORE_MARK" ] || continue
    FOUND=$((FOUND+1))
    say "  [있음] 끝나지 않은 되옮기기 · $(short "$_bk") (이번에 먼저 이어서 끝냅니다)"
  done
  # 0.3.37 r1 F4: 완전 삭제 보관본 속 로그인 파일 정리가 남은 것 — 찾은 자국으로 센다(안 세면 「지울 것이 없습니다」 로 끝나 비밀값이 남는다)
  while IFS= read -r _bk; do
    [ -n "$_bk" ] || continue
    FOUND=$((FOUND+1))
    say "  [있음] 보관본 속 로그인 파일 지우기가 남음 · $(short "$_bk") (이번에 이어서 지웁니다)"
  done <<CRED_DIAG
$(cred_pending_homes)
CRED_DIAG
  # footprint: M-CLAUDEBIN
  [ -e "$HOME/.local/bin/claude" ]; row $? '클로드 실행 파일' "$HOME/.local/bin/claude"
  # footprint: M-CLAUDESHARE
  [ -d "$HOME/.local/share/claude" ]; row $? '클로드 실물' "$HOME/.local/share/claude"
  # footprint: M-JARVISHOME
  [ -d "$JARVIS_HOME" ]; row $? '자비스 작업 폴더' "$JARVIS_HOME"
  # footprint: M-SCRIPTCOPY
  [ -f "$HOME/install-jarvis.sh" ]; row $? '받아 둔 설치 스크립트' "$HOME/install-jarvis.sh"
  # footprint: M-PROFILE
  local pf; pf="$(profile_with_marker | head -1)"
  [ -n "$pf" ]; row $? '실행 경로 한 줄' "${pf:-$HOME/.zprofile}"
  # footprint: M-CLAUDEJSON
  json_has "$HOME/.claude.json" 'hasCompletedOnboarding'; row $? '클로드 설정의 우리 칸' "$HOME/.claude.json"
  # footprint: M-CLAUDESETTINGS
  json_has "$HOME/.claude/settings.json" 'skipDangerousModePermissionPrompt'; row $? '클로드 설정 우리 칸 2' "$HOME/.claude/settings.json"
  # footprint: M-HOOK
  hook_present "$HOME/.claude/settings.json"; row $? '각성 훅 등록' "$HOME/.claude/settings.json"
  # footprint: M-CYSPROFILE
  [ -d "$HOME/.cys/claude" ]; row $? '자비스 전용 클로드 설정' "$HOME/.cys/claude"

  say ""
  if [ "$PURGE_LOGIN" = "1" ]; then say "=== 로그인·개인 자료 ==="; else say "=== 손대지 않는 것 (지우지 않습니다) ==="; fi
  # footprint: M-LOGIN
  say "  현재 로그인: $(login_status)"
  if [ "$PURGE_LOGIN" = "1" ]; then
    say "         ⚠--purge-login 을 붙이셨습니다 — 이번에는 로그인도 지웁니다."
    say "         이때는 로그인만이 아니라 연결해 둔 다른 서비스의 로그인과 확장 기능의 비밀값도 함께 지워집니다."
    say "         (클로드가 그렇게 만들어 두었습니다 — 우리가 고를 수 있는 것이 아닙니다.)"
  else
    say "         기본으로 남깁니다. 재설치 뒤 로그인을 다시 하지 않으셔도 됩니다."
  fi
  if [ -f "$CYS_CRED_FILE" ]; then
    say "  [있음] 자비스 창 전용 로그인 · $(short "$CYS_CRED_FILE")"
    if [ "$KEEP_HISTORY" = "1" ]; then
      # 0.3.36: 재설치 길에서는 이 로그인을 남긴다(HISTORY_KEEP_NAMES) — 앞 판의 「다시 하셔야 합니다」는 이 길에서 거짓이다.
      say "         다시 까는 길이라 이 로그인은 지우지 않고 그대로 둡니다 — 자비스 창에서 로그인을 다시 하지 않으셔도 됩니다."
    else
      say "         ⚠이 로그인 파일은 보관 폴더에 넣지 않고 지웁니다(비밀값은 보관하지 않습니다)."
      say "         자비스 창에서 하신 로그인은 다시 하셔야 할 수 있습니다 — 따로 하신 로그인과는 별개입니다."
    fi
  fi
  # 0.3.36: 자비스 창의 이전 대화(재설치 길에서만 남긴다) — 남긴다고 말하는 것이 사실일 때만 적는다.
  if [ "$KEEP_HISTORY" = "1" ] && [ -d "$HOME/.cys/claude/projects" ]; then
    say "  [있음] 자비스 창 이전 대화 · $(short "$HOME/.cys/claude/projects") (다시 까는 길이라 남깁니다)"
  fi
  # footprint: M-CLAUDEUSER
  [ -d "$HOME/.claude" ] && say "  [있음] 클로드 대화·기록 · $(short "$HOME/.claude") (남깁니다)" \
                         || say "  [없음] 클로드 대화·기록 · $(short "$HOME/.claude")"
  # footprint: M-AGORA
  #   🔴설치기가 만들지 않는다. 토론장에 따로 참가하신 분이 만든 것이므로 **지우지 않는다.**
  [ -d "$AGORA_HOME" ] && say "  [있음] 토론장 참가 열쇠·이름 · $(short "$AGORA_HOME") (남깁니다)" \
                       || say "  [없음] 토론장 참가 열쇠·이름 · $(short "$AGORA_HOME")"
  # footprint: M-AGORASKILL
  #   🔴자리가 둘이고 **운명이 다르다.** 밖(`~/.claude/`)은 남고, cys 계정 자리 안(`~/.cys/claude/`)은
  #   위의 「cys 계정 자리」를 통째로 지울 때 **함께 지워진다.** 「남깁니다」라고 한 줄로 뭉치면
  #   그 줄이 거짓말이 된다 — 이 표가 막으려는 바로 그 형태다. 그래서 두 자리를 갈라 말한다.
  [ -d "$AGORA_SKILL" ] \
    && say "  [있음] 토론장 안내 가리키기 · $(short "$AGORA_SKILL") (남깁니다)" \
    || say "  [없음] 토론장 안내 가리키기 · $(short "$AGORA_SKILL")"
  if [ -d "$AGORA_SKILL_IN_CYS" ]; then
    say "  [있음] 토론장 안내 가리키기(자비스 창 쪽) · $(short "$AGORA_SKILL_IN_CYS")"
    say "         ⚠이것은 위의 「cys 계정 자리」 안에 들어 있어 그 자리와 함께 옮겨지거나 새로 만들어집니다(cys 설치의 일부입니다)."
    if [ -d "$AGORA_SKILL" ]; then
      say "         같은 안내가 $(short "$AGORA_SKILL") 에도 있어 그쪽은 남습니다."
    else
      say "         지우기 전에 $(short "$AGORA_SKILL") 로 옮겨 둡니다 — 없어지지 않습니다."
    fi
    say "         토론장 참가 열쇠·이름은 어느 경우에도 그대로 남습니다."
  fi
  say "  사진·문서·내려받기 등 개인 파일은 목록에 없습니다 — 손대지 않습니다."

  say ""
  say "=== 판정 ==="
  if [ "$FOUND" -eq 0 ]; then
    say "  아무것도 깔려 있지 않습니다 (미설치)."
  elif [ -d "$CYS_APP" ] && [ -d "$HOME/.cys" ] && [ -e "$HOME/.local/bin/claude" ]; then
    say "  설치가 끝난 상태로 보입니다 (찾은 자국 $FOUND 개)."
  else
    say "  설치가 중간에 멈춘 상태로 보입니다 (찾은 자국 $FOUND 개)."
    say "  고장이 아닙니다 — 지우고 처음부터 다시 하면 됩니다."
  fi
}

# ── 지우기 ────────────────────────────────────────────────────────
REMOVED=0; KEPT_FAIL=0; PRESERVED=0

# 🔴🔴**경로를 실경로로 푼 뒤에 비교한다**(2차 검토 지적 채택 2026-09-09).
#   앞 판은 **끝 슬래시만** 떼고 글자로 비교했다. 그러면 `~/.cys/./forum` · `~/.cys/../.cys/forum` ·
#   심볼릭 링크로 적어 둔 자리가 **중첩 판정을 빠져나가** 열쇠가 지워진다 — 첫 비교는 중첩으로 받는데
#   `find` 가 내는 정규화된 경로와 저장해 둔 날것 경로가 서로 달라 남길 대상을 못 알아본다.
#   ⇒ 양쪽을 **같은 방식으로 푼 뒤** 비교한다. `realpath` 는 맥 기본이 아니라 셸로 푼다.
canon() {  # 실경로를 찍는다. 못 풀면 아무것도 안 찍고 rc 1.
  local p="$1" d b
  [ -n "$p" ] || return 1
  if [ -d "$p" ]; then ( cd -P "$p" 2>/dev/null && pwd -P ) && return 0; return 1; fi
  d="$(dirname "$p")"; b="$(basename "$p")"
  d="$( cd -P "$d" 2>/dev/null && pwd -P )" || return 1
  printf '%s/%s\n' "${d%/}" "$b"
}
# 🔴보존 경로의 실경로는 **지우기 전에 한 번에** 풀어 둔다(4차 지적 채택 2026-09-09).
#   앞 판은 `canon` 이 실패하면 `continue` 로 그 경로를 **보존 목록에서 조용히 뺐다.**
#   그러면 지켜야 할 자리가 목록에 없는 채로 상위가 통째로 지워진다.
#   ★「그 자리가 없다」와 「그 자리를 못 풀었다」는 다른 답인데 한 칸에 넣고 있었다.
#   ⇒ **있는데 못 푼 경로가 하나라도 있으면 그 실행은 아무것도 지우지 않는다**(fail-closed).
#     ⚠막는 범위를 넓히지 않는다: **없는 경로는 그냥 건너뛴다**(지킬 것이 없다는 뜻이므로 안전하다).
PRESERVE_CANON=""
PRESERVE_CANON_FAIL=0
PRESERVE_CANON_BAD=""
resolve_preserve_paths() {
  local p c why
  PRESERVE_CANON=""; PRESERVE_CANON_FAIL=0; PRESERVE_CANON_BAD=""
  while IFS= read -r p; do
    [ -n "$p" ] || continue
    [ -e "$p" ] || continue
    if c="$(canon "$p")" && [ -n "$c" ]; then
      PRESERVE_CANON="${PRESERVE_CANON}${c}
"
    else
      PRESERVE_CANON_FAIL=$((PRESERVE_CANON_FAIL+1))
      #   🔴사유를 **경로별로** 함께 담는다(7차 지적 채택 2026-09-09 · 윈도우 쪽과 같은 지적).
      #   사유를 「지금 막 실패한 것 하나」에만 담아 두면 실패가 둘이 되는 순간 첫째의 까닭이 사라진다.
      if [ -L "$p" ]; then why="가리키는 곳을 따라갈 수 없습니다(링크가 끊겼거나 너무 깊습니다)"
      elif [ ! -r "$p" ]; then why="이 계정으로 열 수 없습니다"
      else why="실제 경로를 확인하지 못했습니다"; fi
      PRESERVE_CANON_BAD="${PRESERVE_CANON_BAD}${p}	${why}
"
    fi
  done <<PRESERVE_LIST
$PRESERVE_PATHS
PRESERVE_LIST
}
# 보존 경로 가운데 이 자리 **안에** 있는 것을 실경로로 한 줄씩 찍는다.
preserved_under() {
  local root="$1" c
  printf '%s' "$PRESERVE_CANON" | while IFS= read -r c; do
    [ -n "$c" ] || continue
    case "$c" in "$root"/*) printf '%s\n' "$c" ;; esac
  done
}
# root_clash <실경로> <뿌리들(한 줄에 하나)> → rc 0 = 그 뿌리 자신·안·조상이다(0.3.36 · history_keeps).
root_clash() {
  local c="$1" r
  while IFS= read -r r; do
    [ -n "$r" ] || continue
    case "$c" in "$r"|"$r"/*) return 0 ;; esac
    case "$r" in "$c"/*) return 0 ;; esac
  done <<< "$2"
  return 1
}
# 재설치 길에서 ~/.cys/claude 안에 남길 자리의 실경로(0.3.36 · HISTORY_KEEP_NAMES 머리 주석) → HIST_KEEPS(한 줄에 하나).
#   ★「없다」와 「못 풀었다」를 가른다(resolve_preserve_paths 와 같은 규율) — 없는 것은 건너뛰고,
#     있는데 못 푼 것이 하나라도 있으면 rc 1 · HIST_KEEP_BAD 에 담는다(부르는 쪽이 ~/.cys 를 하나도 지우지 않는다).
#   ⚠「있다」는 `-e` 만이 아니라 `-L` 도 본다 — 끊어진 바로가기는 `-e` 가 거짓이다(그러면 남길 것을 모른 채 지운다).
#   ★남길 것은 **두 모양**으로 적는다(윈 Get-HistoryKeeps 와 같은 까닭 · 시험 실측 2026-09-25): ①그 자리 자체(부모 실경로/이름)
#     ②그것이 가리키는 곳(실경로). 바깥을 가리키는 바로가기는 ②만으로는 「이 안」에서 빠져 바로가기와 그 부모가 지워진다.
HIST_KEEPS=""; HIST_KEEP_BAD=""
#   🔴검토 1회차(09-25) 반례 셋을 막는다: ⑴바로가기가 ~/.cys 자신·조상·그 안의 다른 자리(pack 등)를 가리키면 그곳 전체가 남아
#     「지움」 · 못 지움 0 으로 끝났다 → **못 풂**으로 센다(삭제 0) ⑵`canon` 은 파일 바로가기를 풀지 않아 가리키는 곳(pack 안)이 지워졌다
#     → 바로가기는 perl Cwd::abs_path 로 끝까지 푼다(못 풀면 못 풂 · 윈과 같아짐) ⑶APFS 는 대소문자를 안 가르는데 비교는 가른다 —
#     `Projects` 가 지워졌다 → 실제 이름을 목록에서 대소문자 무시로 찾아 그 이름으로 적는다.
history_keeps() {
  local n p c pc hc real
  HIST_KEEPS=""; HIST_KEEP_BAD=""
  [ -e "$HOME/.cys/claude" ] || [ -L "$HOME/.cys/claude" ] || return 0
  # 🔴교차 검토 1회차(09-25) 반영 — 아래는 전부 **못 풂**(삭제 0): ⓐ홈 경로에 줄바꿈(남길 목록이 줄 단위라 쪼개진다)
  #   ⓑ~/.cys 나 ~/.cys/claude 자체가 바로가기(이름표만 지우면 새 ~/.cys 에선 안 보이고 · 통째로 남기면 옛 CLAUDE.md 가 새 라우터를 막는다)
  #   ⓒ~/.cys/claude 목록을 못 읽음(find 실패를 「남길 것 없음」으로 읽으면 안 된다)
  case "$HOME" in *$'\n'*) HIST_KEEP_BAD="(홈 경로에 줄바꿈)
"; return 1 ;; esac
  if [ -L "$HOME/.cys" ] || [ -L "$HOME/.cys/claude" ]; then HIST_KEEP_BAD="$HOME/.cys/claude
"; return 1; fi
  ls -A "$HOME/.cys/claude/" >/dev/null 2>&1 || { HIST_KEEP_BAD="$HOME/.cys/claude
"; return 1; }
  pc="$(canon "$HOME/.cys/claude")" && [ -n "$pc" ] || { HIST_KEEP_BAD="$HOME/.cys/claude
"; return 1; }
  hc="$(canon "$HOME/.cys")" && [ -n "$hc" ] || { HIST_KEEP_BAD="$HOME/.cys
"; return 1; }
  # 바로가기가 가리키는 곳이 이 지우개가 지우는 다른 자리 안·그 조상이면 못 풂(그 자리를 지울 때 함께 사라진다 · 교차 검토).
  local roots="$hc" r rc2
  for r in "$HOME/.local/state/cys" "$HOME/.local/share/claude" "$HOME/.local/bin" "$JARVIS_HOME"; do
    [ -e "$r" ] || continue
    rc2="$(canon "$r")" && [ -n "$rc2" ] && roots="$roots
$rc2"
  done
  while IFS= read -r n; do
    [ -n "$n" ] || continue
    while IFS= read -r -d '' real; do
      real="${real##*/}"
      p="$HOME/.cys/claude/$real"
      if [ -L "$p" ]; then
        c="$(perl -MCwd=abs_path -e '$r = abs_path($ARGV[0]); (defined $r && -e $r) or exit 1; print $r' "$p" 2>/dev/null)" || c=""
      else
        c="$(canon "$p")" || c=""
      fi
      if [ -z "$c" ]; then
        HIST_KEEP_BAD="${HIST_KEEP_BAD}${p}
"; continue
      fi
      if [ "$c" != "$pc/$real" ] && root_clash "$c" "$roots"; then
        HIST_KEEP_BAD="${HIST_KEEP_BAD}${p}
"; continue
      fi
      HIST_KEEPS="${HIST_KEEPS}${pc}/${real}
"
      [ "$c" = "$pc/$real" ] || HIST_KEEPS="${HIST_KEEPS}${c}
"
    done < <(find "$HOME/.cys/claude/" -mindepth 1 -maxdepth 1 -iname "$n" -print0 2>/dev/null)
  done <<HIST_LIST
$HISTORY_KEEP_NAMES
HIST_LIST
  [ -z "$HIST_KEEP_BAD" ]
}
# 목록(한 줄에 하나) 가운데 이 자리 **안에** 든 것만 찍는다(0.3.36 · drop_dir 의 남길 목록).
#   ⚠함수로 둔다 — 맥 기본 bash 3.2 는 `$( … case … in 무늬) … esac … )` 를 잘못 읽는다(시험 실측 2026-09-25).
paths_under() {
  local root="$1" k
  printf '%s\n' "$2" | while IFS= read -r k; do
    [ -n "$k" ] || continue
    case "$k" in "$root"/*) printf '%s\n' "$k" ;; esac
  done
}
# 이 자리 **자신이** 보존 대상이거나 보존 경로의 아래인가(그러면 손대지 않는다).
preserve_covers() {
  local t="$1" c
  printf '%s' "$PRESERVE_CANON" | while IFS= read -r c; do
    [ -n "$c" ] || continue
    case "$t" in "$c"|"$c"/*) printf '%s\n' "$c" ;; esac
  done
}
# 이 **실경로**가 보존 경로 자신·그 아래·그 조상인가(그러면 지우지 않는다).
#   ⚠넘기는 것은 항상 실경로다 — 원문 경로로 비교하면 링크를 거친 자리에서 어긋난다.
prune_keep_hit() {
  local p="$1" keeps="$2" k
  [ -n "$p" ] || return 1          # 실경로를 못 푼 것은 「남겨야 한다」가 아니다
  # 0.3.36: 파이프(하위 셸)가 아니라 here-string 으로 돈다 — 뜻은 같고 항목마다 프로세스를 띄우지 않는다
  #   (검토 실측: 재설치 길에서 이 함수가 ~/.cys 전 항목에 두 번씩 불려 4천 항목에 26초).
  while IFS= read -r k; do
    [ -n "$k" ] || continue
    case "$p" in "$k"|"$k"/*) return 0 ;; esac   # 보존 경로 자신 또는 그 아래
    case "$k" in "$p"/*) return 0 ;; esac        # 보존 경로의 조상
  done <<< "$keeps"
  return 1
}
# 0.3.37(DESIGN-0337 6-1절 ⑤·MINOR): 남길 목록을 **둘로 가른다** —
#   ⑴참가 자리(keeps) = 가리키는 곳(실경로)과 바로가기 **자리** 둘 다로 비교(0.3.36 그대로 · 모든 길)
#     ★MINOR 처방(「자리 비교는 표지 길에만」)은 **기각**했다 — 그렇게 하면 표지 없는 길에서 참가 자리 **안**의 바로가기
#       (참가자가 만든 것)를 다시 지운다(0.3.35 동작 · 더 지우는 쪽). 더 남기는 쪽을 유지하고 시험으로 고정한다(delete-path 칸 ⓓM).
#   ⑵재설치 남길 것(hkeeps) = 바로가기는 **자리로만**(가리키는 곳으로 보지 않는다) — 앞 판은 가리키는 곳으로도 봐서
#     `pack` 이 `projects` 안을 가리키는 바로가기면 pack 이름표가 남았다(반례 ⑤ · 옛 팩 → 병합 대기).
prune_keep_hit_split() { # <항목 원문> <실경로(바로가기면 가리키는 곳)> <루트 원문> <루트 실경로> <참가 자리> <재설치 남길 것>
  local p="$1" c="$2" root="$3" rc="$4" pk="$5" hk="$6" loc=""
  [ "${p#"$root"/}" != "$p" ] && loc="$rc${p#"$root"}"
  if [ -L "$p" ]; then
    prune_keep_hit "$c" "$pk" && return 0
    [ -n "$loc" ] && prune_keep_hit "$loc" "$pk" && return 0
    [ -n "$hk" ] && [ -n "$loc" ] && prune_keep_hit "$loc" "$hk" && return 0
    return 1
  fi
  prune_keep_hit "$c" "$pk" && return 0
  [ -n "$hk" ] && prune_keep_hit "$c" "$hk" && return 0
  return 1
}
# 항목의 실경로를 **싸게** 낸다. `find` 는 링크를 따라가지 않으므로 루트 아래 조상 마디에는
#   링크가 없다 ⇒ 「루트 실경로 + 나머지 마디」. 항목 **자신이** 링크일 때만 따로 푼다.
item_canon() { # item_canon <항목 원문> <루트 원문> <루트 실경로>
  local p="$1" rl="$2" rc="$3"
  if [ -L "$p" ]; then canon "$p"; return $?; fi
  case "$p" in
    "$rl"/*) printf '%s%s\n' "$rc" "${p#"$rl"}" ;;
    *) canon "$p" ;;
  esac
}
# 보존 경로만 남기고 그 자리를 비운다. 보존 경로와 **그 위 조상들**은 건드리지 않는다.
#   ★깊은 것부터(-depth) 지운다 — 자식을 먼저 치우지 않으면 부모를 못 지운다.
#   🔴**못 지운 것을 세어 돌려준다**(2차 검토 지적 채택): 앞 판은 개별 실패를 통째로 삼키고도
#   「지움」이라 말했다. 지우는 도구가 「거의 다 지웠다」를 성공으로 보고하면 그것이 곧 거짓 상태 보고다.
#   🔴🔴**열거 자체가 실패할 수 있다**(4차 지적 채택 2026-09-09). 앞 판은 `find` 의 오류를 버리고
#   종료값도 안 봤다 ⇒ **하나도 못 본 날이 「다 지웠다」가 된다.** 그리고 줄 단위로 읽어서
#   **이름에 개행이 든 파일이 두 조각으로 갈렸다.** ⇒ `-print0` 로 받고 종료값을 본다.
#   ★그리고 지운 뒤 **다시 세어** 검산한다 — 「지웠다」는 남은 것이 0일 때만 참이다.
#   ★링크는 이 자리에서 저절로 안전하다(실측 2026-09-09): 폴더를 가리키는 심볼릭 링크에 `rm -rf` 를
#     하면 **링크만 사라지고 대상 폴더·파일은 그대로다**. 윈도우는 그렇지 않아 따로 손을 봤다
#     (윈은 훑는 쪽이 링크로 들어갈 수 있다 — `reset-clean.ps1` 의 `Get-TreeItems`·`Remove-OneItem` 참조.
#      ⚠5.1 `Remove-Item -Recurse` 가 뚫는지는 판본에 따라 다르다 — 2026-09-09 러너 실측: 안 뚫었다).
#   🔴🔴**원문 경로로 훑는다**(6차 BLOCK 채택 2026-09-09 · 윈도우와 같은 결함이 여기에도 있었다).
#   앞 판은 실경로(`$t`)를 이 함수에 넘겼다. 그래서 삭제 루트가 링크면 **그 대상 폴더**를 훑어 지웠다.
#   ⇒ 훑는 것은 언제나 원문 루트, 실경로는 **비교에만** 쓴다.
PRUNE_WHY=""
prune_except() {
  local root="$1" root_canon="$2" keeps="$3" hkeeps="${4:-}" list p c enum_fail left why
  PRUNE_FAIL=0; enum_fail=0; left=0
  list="$(mktemp -t jarvis-prune)" || return 1
  find "$root" -depth -mindepth 1 -print0 > "$list" 2>/dev/null || enum_fail=1
  # 🔴2026-09-10 확정(1차 REVISE ⑥) — 앞 판은 항목별 `rm` 의 stderr 를 버리고 마지막에 개수만
  #   말했다. 중첩 보존은 우리가 **지원한다고 명시한 구성**인데, 거기서 「몇 가지를 지우지 못했다」만
  #   남으면 사용자는 어느 파일을 풀어야 하는지 알 수 없다. ⇒ 까닭을 최대 5줄 모아 인쇄한다.
  PRUNE_WHY=""
  while IFS= read -r -d '' p; do
    # 0.3.36: 링크가 아니면 item_canon 과 같은 값을 프로세스 없이 낸다(「루트 실경로 + 나머지 마디」 — item_canon 머리 주석)
    if [ ! -L "$p" ] && [ "${p#"$root"/}" != "$p" ]; then c="$root_canon${p#"$root"}"
    else c="$(item_canon "$p" "$root" "$root_canon")" || c=""; fi
    prune_keep_hit_split "$p" "$c" "$root" "$root_canon" "$keeps" "$hkeeps" && continue
    why="$(rm -rf "$p" 2>&1)"
    if [ -n "$why" ]; then
      PRUNE_WHY="$(printf '%s%s\n' "$PRUNE_WHY" "$why")"
    fi
  done < "$list"
  # ★검산 — 남은 것을 다시 센다. 지우기 실패든 열거 실패든 **결과 한 칸**으로 모인다.
  : > "$list"
  find "$root" -depth -mindepth 1 -print0 > "$list" 2>/dev/null || enum_fail=1
  while IFS= read -r -d '' p; do
    if [ ! -L "$p" ] && [ "${p#"$root"/}" != "$p" ]; then c="$root_canon${p#"$root"}"
    else c="$(item_canon "$p" "$root" "$root_canon")" || c=""; fi
    prune_keep_hit_split "$p" "$c" "$root" "$root_canon" "$keeps" "$hkeeps" && continue
    left=$((left+1))
  done < "$list"
  rm -f "$list"
  PRUNE_FAIL=$((left + enum_fail))
  if [ "$enum_fail" -ne 0 ]; then
    say "         (이 자리의 목록을 끝까지 읽지 못했습니다 — 이 계정으로 못 여는 하위 자리가 있습니다.)"
  fi
  if [ "${PRUNE_FAIL:-0}" -ne 0 ] && [ -n "$PRUNE_WHY" ]; then
    say "         지우지 못한 자리:"
    printf '%s\n' "$PRUNE_WHY" | head -5 | while IFS= read -r l; do [ -n "$l" ] && say "           $l"; done
  fi
  [ "${PRUNE_FAIL:-0}" -eq 0 ]
}

# 두 자리의 **파일 목록과 내용**이 같은가. 「폴더가 생겼다」로는 옮겼다고 말할 수 없다.
#   ⚠임시 파일은 **바깥**에 만든다 — 대조하는 자리 안에 만들면 그 파일이 목록에 끼어 자기 자신을 어긋나게 한다.
sha_of() { shasum -a 256 "$1" 2>/dev/null | awk '{print $1}'; }
tree_same() {
  local a="$1" b="$2" la lb rel rc=0
  [ -d "$a" ] && [ -d "$b" ] || return 1
  la="$(mktemp -t jarvis-ta)" || return 1
  lb="$(mktemp -t jarvis-tb)" || { rm -f "$la"; return 1; }
  ( cd "$a" 2>/dev/null && find . -type f | LC_ALL=C sort ) > "$la" 2>/dev/null || rc=1
  ( cd "$b" 2>/dev/null && find . -type f | LC_ALL=C sort ) > "$lb" 2>/dev/null || rc=1
  if [ "$rc" -eq 0 ] && cmp -s "$la" "$lb"; then
    while IFS= read -r rel; do
      [ -n "$rel" ] || continue
      [ "$(sha_of "$a/$rel")" = "$(sha_of "$b/$rel")" ] || { rc=1; break; }
    done < "$la"
  else
    rc=1
  fi
  rm -f "$la" "$lb"
  return "$rc"
}

PRUNE_FAIL=0
# $2 (0.3.36) = 이번에만 더 남길 실경로 목록(재설치 길의 로그인·이전 대화 · history_keeps · 한 줄에 하나). 없으면 종전과 같다.
drop_dir()  {
  [ -e "$1" ] || [ -L "$1" ] || return 0
  # 🔴지우기 전에 보존 경로와의 중첩을 먼저 본다(검토 지적 채택 2026-09-09).
  local t covers keeps hist what
  # ★남겨야 할 자리 가운데 **있는데 실경로를 못 푼 것**이 있으면 아무것도 지우지 않는다.
  #   무엇을 남겨야 하는지 모르는 채로 지우면 그것이 이 도구의 가장 나쁜 실패다.
  #   (까닭은 위 `resolve_preserve_paths` 참조. 사람이 볼 설명은 purge 가 한 번만 인쇄한다.)
  if [ "${PRESERVE_CANON_FAIL:-0}" -ne 0 ]; then
    KEPT_FAIL=$((KEPT_FAIL+1))
    say "  🔴못 지움: $(short "$1") — 남겨야 할 자리를 확인하지 못해 지우지 않았습니다."
    return 1
  fi
  # 🔴🔴**삭제 루트가 링크면 이름표만 지운다 — 그 안으로 들어가지 않는다**(6차 BLOCK 채택 2026-09-09).
  #   앞 판은 실경로를 먼저 구해 그 **대상**을 훑는 함수에 넘겼다. 그래서 `~/.cys` 가 남의 폴더를
  #   가리키는 링크이고 참가 자리가 그 안에 있으면 **그 남의 폴더를 열어 안을 지웠다.**
  #   ★링크를 따라간 것은 `rm` 이 아니라 **그 앞의 「실경로 → 훑을 자리」 변환**이었다.
  #   ⚠keep 이 있든 없든 마찬가지다 — 「그 안에 남길 것이 있으니 들어가도 된다」가 바로 그 함정이다.
  if [ -L "$1" ]; then
    if rm -f "$1" 2>/dev/null; then
      REMOVED=$((REMOVED+1)); say "  지움: $(short "$1") (가리키기만 지웠습니다 — 가리키던 자리는 그대로입니다)"
      return 0
    fi
    KEPT_FAIL=$((KEPT_FAIL+1)); say "  🔴못 지움: $(short "$1")"
    return 1
  fi
  # ★실경로를 못 풀면 **지우지 않는다**(fail-closed). 무엇을 지우는지 확신할 수 없는 상태에서
  #   지우는 것이 이 도구가 낼 수 있는 가장 나쁜 실패다. 이 값은 **비교에만** 쓴다.
  t="$(canon "$1")" || {
    KEPT_FAIL=$((KEPT_FAIL+1))
    say "  🔴못 지움: $(short "$1") — 이 자리의 실제 경로를 확인하지 못해 **지우지 않았습니다.**"
    say "         (확인할 수 없는 자리를 지우면 엉뚱한 것을 지울 수 있습니다.)"
    return 1
  }
  covers="$(preserve_covers "$t")"
  if [ -n "$covers" ]; then
    PRESERVED=$((PRESERVED+1))
    say "  보존(중첩): $(short "$1") — 참가 자리와 겹쳐 지우지 않습니다."
    return 0
  fi
  keeps="$(preserved_under "$t")"
  # 0.3.36: 재설치 길에서 남길 로그인·이전 대화 — 이 자리 안에 든 것만 받는다(참가 자리와 말을 갈라 적는다).
  #   ⚠「이 안에 든 것」으로 거르지 않는다 — 바로가기가 가리키는 곳(②)은 밖에 있어도 비교에 있어야 그 바로가기가 남는다(history_keeps).
  hist="$(printf '%s' "${2:-}" | grep -v '^$')"
  if [ -n "$keeps" ] || [ -n "$hist" ]; then
    if [ -n "$keeps" ]; then
      PRESERVED=$((PRESERVED+1))
      say "  보존(중첩): $(short "$1") 안에 참가 자리가 있어 **그것만 남기고** 지웁니다."
      printf '%s\n' "$keeps" | while IFS= read -r k; do [ -n "$k" ] && say "           남기는 자리: $(short "$k")"; done
    fi
    if [ -n "$hist" ]; then
      say "  남김: $(short "$1") 안의 자비스 창 이전 대화 (다시 까는 길이라 그것만 남기고 지웁니다)"
      paths_under "$t" "$hist" | while IFS= read -r k; do [ -n "$k" ] && say "           남기는 자리: $(short "$k")"; done
    fi
    if [ -z "$hist" ]; then what='참가 자리'; elif [ -z "$keeps" ]; then what='이전 대화'; else what='참가 자리와 이전 대화'; fi
    if prune_except "$1" "$t" "$keeps" "$hist"; then
      REMOVED=$((REMOVED+1)); say "  지움: $(short "$1") (${what}는 그대로)"
      return 0
    fi
    KEPT_FAIL=$((KEPT_FAIL+1))
    say "  🔴일부 남음: $(short "$1") — ${PRUNE_FAIL}가지를 지우지 못했습니다(${what}는 그대로입니다)."
    return 1
  fi
  # 🔴2026-09-10 수리(R2) — 앞 판은 `2>/dev/null` 로 **까닭을 통째로 버렸다.** 화면에 남는 것이
  #   「못 지움」 한 줄뿐이라 사용자도 우리도 다음 손을 정할 수 없었다(윈도우판에서 실제로 그랬다).
  #   ⇒ 받아 두었다가 **최대 5줄** 적는다. 버리지 않는다.
  RM_WHY="$(rm -rf "$1" 2>&1)"; RM_RC=$?
  if [ "$RM_RC" -eq 0 ] && [ ! -e "$1" ] && [ ! -L "$1" ]; then REMOVED=$((REMOVED+1)); say "  지움: $(short "$1")"; return 0; fi
  KEPT_FAIL=$((KEPT_FAIL+1)); say "  🔴못 지움: $(short "$1")"
  if [ -n "$RM_WHY" ]; then
    say "         지우지 못한 자리:"
    printf '%s\n' "$RM_WHY" | head -5 | while IFS= read -r l; do [ -n "$l" ] && say "           $l"; done
  elif [ -e "$1" ]; then
    say "         (오류는 없었는데 그 자리가 아직 있습니다 — 다른 프로그램이 붙들고 있을 수 있습니다.)"
  fi
  #   가장 흔한 까닭이 권한이다 — 다른 계정이 깐 프로그램은 이 계정으로 못 지운다.
  #   「못 지웠다」로만 끝내면 사람은 무엇을 해야 할지 모른다(교차 검토 지적 채택 2026-09-08).
  if [ ! -w "$(dirname "$1")" ]; then
    say "         이 자리는 이 계정으로 지울 수 없습니다(다른 계정이 놓았거나 관리자 자리입니다)."
    say "         그 프로그램을 설치한 계정으로 로그인해서 다시 하시거나, 관리자에게 부탁해 주십시오."
  fi
}
drop_file() { drop_dir "$1"; }

PROFILE_LINE='export PATH="$HOME/.local/bin:$PATH"'
strip_profile_marker() { # 우리 표식 블록 2줄만 뺀다 — 사용자의 다른 줄은 건드리지 않는다
  local f tmp
  for f in $(profile_with_marker); do
    tmp="$(mktemp -t jarvis-prof)" || continue
    #   🔴교차 검토 지적 채택(2026-09-08): 앞 판은 표식 **다음 한 줄을 무조건** 지웠다.
    #   사용자가 표식 바로 아래에 자기 줄을 넣어 두었으면 **그 줄을 말없이 삼킨다.**
    #   ⇒ 다음 줄은 **우리가 쓴 그 줄일 때만** 지운다. 아니면 표식만 지우고 그 줄은 남긴다.
    #   그리고 우리 줄을 못 지운 경우에는 **그 사실을 말한다** — 조용히 두면 「다 지웠다」가 거짓이 된다.
    #   ⛔파일 어디서나 그것과 똑같은 내용의 줄을 찾아 지우지는 않는다: 공식 설치기가 사람에게
    #   **바로 그 줄**을 직접 넣으라고 시키므로, 그 줄이 사용자 자신의 것일 수 있다.
    awk -v m="$PROFILE_MARKER" -v l="$PROFILE_LINE" '
      $0 == m { pend = 1; next }
      pend == 1 { pend = 0; if ($0 == l) next; else kept = 1 }
      { print }
      END { if (kept) print "JARVIS_LINE_KEPT" > "/dev/stderr" }
    ' "$f" > "$tmp" 2>"$tmp.err" || { rm -f "$tmp" "$tmp.err"; continue; }
    if grep -q JARVIS_LINE_KEPT "$tmp.err" 2>/dev/null; then
      say "  ⚠$(short "$f") — 표식은 지웠으나, 우리가 쓴 경로 줄이 표식 바로 아래가 아니어서 남겨 두었습니다."
      say "         그 자리에 손수 넣으신 줄이 있어 함께 지우지 않았습니다. 해롭지 않습니다."
    fi
    rm -f "$tmp.err"
    #   🔴원본에 바로 쓰지 않는다 — 쓰는 도중 멈추면 남의 파일이 반쪽으로 남는다(같은 지적).
    #   임시 파일에 다 쓴 뒤 한 번에 자리를 바꾼다. 권한·소유자를 잃지 않게 mv 대신 cp 로 되돌린다.
    if [ -s "$tmp" ] || [ ! -s "$f" ]; then
      if cp "$tmp" "$f" 2>/dev/null; then REMOVED=$((REMOVED+1)); say "  지움: $(short "$f") 의 실행 경로 한 줄 (다른 줄은 그대로)"
      else KEPT_FAIL=$((KEPT_FAIL+1)); say "  🔴못 지움: $(short "$f") 의 실행 경로 한 줄"; fi
    else
      KEPT_FAIL=$((KEPT_FAIL+1)); say "  🔴못 지움: $(short "$f") — 고쳐 쓴 내용이 비어 원본을 그대로 두었습니다"
    fi
    rm -f "$tmp"
  done
}

# 🔴**폴더 이름에 마침표가 있는 신뢰 칸**(0.3.36 F15 · 설치기 trust_json_prepare 와 짝).
#   `plutil` 키 경로는 마침표를 구분자로만 읽어 /Users/first.last 같은 칸을 **가리킬 수가 없다**
#   (2026-09-08 실측: extract·remove 둘 다 실패). 설치기가 이제 그 칸을 JavaScript 로 넣으므로,
#   제거기도 같은 방법으로 빼야 한다 — 짝이 안 맞으면 넣은 칸이 **지울 수 없는 자국**이 된다.
#   ⇒ macOS 기본 `osascript`(JavaScript)로 폴더 이름을 **통째 한 열쇠**로 다룬다(jq·python 없이).
#   ops: get = 신뢰 키 값(「present=값」 또는 absent) · strip = 신뢰 키만 빼고 빈 칸이면 칸째 ·
#        drop = 그 폴더 칸을 칸째(자비스 작업 폴더 — 처음부터 끝까지 우리 것) · top = 최상위 칸 하나(dir 자리에 키 이름).
IFS= read -r -d '' DIR_KEY_JS <<'EOF_DIR_KEY_JS' || true
ObjC.import("Foundation");
function run(argv) {
  var op = argv[0], cfg = argv[1], dir = argv[2], out = argv[3];
  var raw = $.NSString.stringWithContentsOfFileEncodingError(cfg, $.NSUTF8StringEncoding, null);
  if (raw.isNil()) throw new Error("read");
  var txt = ObjC.unwrap(raw);
  // 다시 쓰면 값이 바뀌는 수가 있는가(이종 검토 3회차) — 자릿수가 아니라 「그 수를 읽어 다시 쓴 글자가 같은 값인가」로 잰다.
  //   글자 칸("…") 안 숫자는 수가 아니므로 먼저 비운다. 1e000·정확한 16자리 정수는 통과 · 9.007199254740993e15·긴 소수·1e400 은 걸린다.
  function lossy(t) {
    function norm(s) {
      var m = /^(-?)(\d+)(?:\.(\d+))?(?:[eE]([+-]?\d+))?$/.exec(s); if (!m) return null;
      var f = m[3] || "", d = (m[2] + f).replace(/^0+/, ""), e = parseInt(m[4] || "0", 10) - f.length;
      if (d === "") return "0";
      var z = d.length - d.replace(/0+$/, "").length; return m[1] + d.slice(0, d.length - z) + "e" + (e + z);
    }
    var b = t.replace(/"(?:[^"\\]|\\.)*"/g, '""'), re = /-?\d+(?:\.\d+)?(?:[eE][+-]?\d+)?/g, m;
    while ((m = re.exec(b))) if (norm(m[0]) !== norm(String(Number(m[0])))) return true;
    return false;
  }
  if (/^\s*$/.test(txt)) return "absent";   // 빈 설정 파일 = 칸 없음(이종 검토 — 못 읽음으로 세면 재설치가 영영 막힌다)
  // 0.3.36 이종 검토 지적: JSON.parse 는 2^53 을 넘는 정수·긴 소수·1e400 을 뭉갠다 — 다시 쓰면 값이 바뀌는 수가 있으면 고쳐 쓰지 않는다(위 lossy).
  //   ⚠읽기·「뺄 것 없음」은 막지 않는다 — 뭉개지는 것은 **실제로 고쳐 쓸 때뿐**이다(아래 쓰기 바로 앞에서 잰다 · 정밀 디버깅:
  //     앞에서 재면 뺄 칸이 없는 성한 설정도 「못 읽음」 으로 세어 재설치가 막혔다).
  var o = JSON.parse(txt);
  function isObj(v) { return v !== null && typeof v === "object" && !Array.isArray(v); }
  var has = Object.prototype.hasOwnProperty;
  var p = isObj(o) && has.call(o, "projects") ? o.projects : undefined;
  var e = isObj(p) && has.call(p, dir) ? p[dir] : undefined;
  var flag = isObj(e) && has.call(e, "hasTrustDialogAccepted");
  if (op === "get") return flag ? "present=" + String(e.hasTrustDialogAccepted) : "absent";
  if (op === "strip") {
    if (!flag) return "absent";
    delete e.hasTrustDialogAccepted;
    if (Object.keys(e).length === 0) delete p[dir];
  } else if (op === "drop") {
    if (e === undefined) return "absent";
    delete p[dir];
  } else if (op === "top") {   // 최상위 칸 하나(plutil 이 못 읽는 성한 설정의 대체 길 · strip_json_key)
    if (!isObj(o) || !has.call(o, dir)) return "absent";
    delete o[dir];
  } else throw new Error("op");
  if (lossy(txt)) return "lossy";   // 고쳐 쓰면 남의 수가 바뀐다 — 쓰지 않는다(호출부가 까닭을 따로 말한다)
  if (!$(JSON.stringify(o, null, 2) + "\n").writeToFileAtomicallyEncodingError(out, false, $.NSUTF8StringEncoding, null)) throw new Error("write");
  return "removed";
}
EOF_DIR_KEY_JS
REAL=""
real_path() { # real_path <경로> → REAL = 바로가기(심볼릭 링크)를 끝까지 푼 자리(40단) · rc 1 = 고리·너무 깊음·못 읽음
  #   ⚠운영체제는 32단까지만 따라간다 — `[ -f 링크 ]` 가 33단 이상에서 「없음」 이 되어 정리를 조용히 건너뛰었다(이종 검토 3회차).
  #   ⇒ 파일 검사는 언제나 푼 자리에 한다. 끊긴 링크는 REAL = 없는 자리(rc 0 · 호출부가 「칸 없음」 으로 본다).
  local l n=0
  REAL="$1"
  while [ -L "$REAL" ]; do
    [ "$n" -lt 40 ] || return 1
    l="$(readlink "$REAL")" || return 1
    case "$l" in /*) REAL="$l" ;; *) REAL="$(dirname "$REAL")/$l" ;; esac
    n=$((n+1))
  done
  return 0
}
DIR_KEY_RESULT=""
dir_key_json() { # dir_key_json <get|strip|drop|top> <파일> <폴더|키> — 결과 낱말은 DIR_KEY_RESULT 에 · rc 1 = 못 읽었다 · rc 2 = 뺄 것을 못 썼다 · rc 3 = 고쳐 쓰면 다른 수가 바뀌어 쓰지 않았다
  local tmp r f
  DIR_KEY_RESULT=""
  # ⚠이름 바꾸기는 바로가기(심볼릭 링크)를 보통 파일로 갈아 끼운다 ⇒ 링크면 **실제 파일**을 풀어 그 자리에서 다룬다
  #   (이종 검토: 설치 뒤 dotfile 도구로 링크가 된 설정을 거절하면 정리 실패가 영구 → 재설치 거부). 링크는 그대로 남는다.
  real_path "$2" || return 1
  f="$REAL"
  [ -f "$f" ] && [ ! -L "$f" ] || return 1
  tmp="$(mktemp "$f.jarvis.XXXXXX" 2>/dev/null)" || return 1
  r="$(/usr/bin/osascript -l JavaScript -e "$DIR_KEY_JS" "$1" "$f" "$3" "$tmp" </dev/null 2>/dev/null)" || r=""
  case "$r" in
    removed)
      # 바꾼 내용은 곁 파일에 있다 — 제자리 이름 바꾸기로 한 번에 들인다(권한은 원래 파일 것을 따른다).
      chmod "$(stat -f %Lp "$f" 2>/dev/null || echo 600)" "$tmp" 2>/dev/null
      if [ -s "$tmp" ] && mv -f "$tmp" "$f" 2>/dev/null; then DIR_KEY_RESULT="removed"; return 0; fi
      rm -f "$tmp"; return 2 ;;
    absent|present*) rm -f "$tmp"; DIR_KEY_RESULT="$r"; return 0 ;;
    lossy) rm -f "$tmp"; DIR_KEY_RESULT="lossy"; return 3 ;;
  esac
  rm -f "$tmp"; return 1
}

strip_json_key() { # strip_json_key <파일> <키> — 파일은 남기고 우리 칸만 뺀다
  if ! real_path "$1"; then KEPT_FAIL=$((KEPT_FAIL+1)); say "  🔴못 살핌: $(short "$1") 의 $2 칸 — 바로가기(링크)를 끝까지 풀지 못했습니다(고리 또는 너무 깊음)."; return 0; fi
  [ -f "$REAL" ] || return 0   # 없는 파일·끊긴 링크 = 칸 없음
  [ -s "$REAL" ] || return 0   # 빈 설정 파일 = 칸 없음(이종 검토)
  #   ⚠`plutil` 은 키 경로에서 마침표를 구분자로 읽는다. 사용자 폴더 이름에 마침표가 있으면
  #   (예: /Users/first.last) 그 칸을 **가리킬 수가 없다**(2026-09-08 실측: extract·remove 둘 다 실패).
  #   ⇒ 그 칸은 위 dir_key_json 으로 뺀다(설치기도 같은 방법으로 넣는다). plutil 만 못 읽는 성한 설정
  #   (짝 없는 서로게이트 · 1e400 — 이종 검토)도 같은 길로 한 번 더 본다. 그것마저 못 하면
  #   **못 지운 것으로 센다** — 조용히 지나가면 「다 지웠다」가 거짓이 된다(B-Z28 과 같은 병 · 이종 검토).
  local op=top k="$2" js=""
  case "$2" in projects.*) op=drop; k="${2#projects.}"; case "$k" in *.*) js=1 ;; esac ;; esac
  [ -z "$js" ] && ! plutil -convert json -o /dev/null "$1" >/dev/null 2>&1 && js=1
  if [ -n "$js" ]; then
    dir_key_json "$op" "$1" "$k"
    case "$?" in
      0) [ "$DIR_KEY_RESULT" = "removed" ] && { REMOVED=$((REMOVED+1)); say "  지움: $(short "$1") 의 $2 칸 (파일은 그대로)"; } ;;
      2) KEPT_FAIL=$((KEPT_FAIL+1)); say "  🔴못 지움: $(short "$1") 의 $2 칸" ;;
      3) KEPT_FAIL=$((KEPT_FAIL+1)); say "  🔴못 지움: $(short "$1") 의 $2 칸 — 고쳐 쓰면 그 파일의 다른 수가 바뀌어 손대지 않았습니다(그 칸을 손으로 빼 주십시오)." ;;
      *) # 못 읽었다(잘린 파일 등) — 그 키 이름이 글자로도 없으면 우리 칸은 없다(다시 해도 같은 영구 실패를 만들지 않는다 · 이종 검토 3회차).
         #   작업 폴더 키는 plutil 이 쓴 꼴(/ → \/)로도 찾는다.
         if ! grep -qF "\"$k\"" "$REAL" 2>/dev/null && ! grep -qF "\"$(printf '%s' "$k" | sed 's#/#\\/#g')\"" "$REAL" 2>/dev/null; then return 0; fi
         KEPT_FAIL=$((KEPT_FAIL+1)); say "  🔴못 살핌: $(short "$1") 의 $2 칸 — 설정 파일이 깨져 있어 그 칸을 뺄 수 없습니다(파일을 고치거나 그 줄을 손으로 빼 주십시오)." ;;
    esac
    return 0
  fi
  plutil -extract "$2" raw -o - "$1" >/dev/null 2>&1 || return 0   # 파일은 읽힌다(위에서 확인) ⇒ 칸 없음
  if plutil -remove "$2" "$1" >/dev/null 2>&1; then REMOVED=$((REMOVED+1)); say "  지움: $(short "$1") 의 $2 칸 (파일은 그대로)"
  else KEPT_FAIL=$((KEPT_FAIL+1)); say "  🔴못 지움: $(short "$1") 의 $2 칸"; fi
}

# 🔴글을 다루는 도구를 고를 때 `python3` 를 그냥 부르면 안 된다.
#   깨끗한 맥에는 개발자 도구가 없어서 `/usr/bin/python3` 는 **설치 대화상자를 띄우고 실패한다**
#   (2026-09-06 실측 · rc=1). 그러면 지우는 중에 창이 하나 뜨고 훅은 안 지워진다.
#   ⇒ cys 프로그램 안에 동봉된 파이썬을 먼저 쓴다. 배포물 자신도 같은 이유로 그렇게 한다.
pick_python() {
  local c
  for c in "$CYS_APP/Contents/Resources/runtime/python/bin/python3" "$HOME/.local/share/claude/runtime/python/bin/python3"; do
    [ -x "$c" ] && { printf '%s' "$c"; return 0; }
  done
  # 개발자 도구가 이미 있는 기계에서만 이것이 답한다. 없으면 빈손으로 돌아간다(대화상자를 안 띄운다).
  if [ -n "$(xcode-select -p 2>/dev/null)" ] && [ -x /usr/bin/python3 ]; then
    printf '%s' /usr/bin/python3; return 0
  fi
  return 1
}

# ── 🔴🔴작업 폴더를 **재귀로 지우기 전에** 그 자리가 안전한지 본다 (3차 N3 = 표면 축소 · 관리자 결정) ──
#   `JARVIS_HOME` 은 환경변수라 **무엇이든 들어올 수 있다.** 검사 없이 넘기면 그 값이 홈이거나
#   드라이브 루트일 때 **사진·문서·남의 프로젝트를 통째로** 지운다. 되돌릴 수 없는 손실이다.
# 🔴🔴**앞 판은 「나쁜 값 목록」으로 막으려 했고, 그 목록은 세 라운드 내내 새 구멍을 냈다**
#   (홈·루트·시스템 자리 → 드라이브 루트 → UNC 공유 → 조상 심볼릭 링크 → 8.3 별칭…).
#   ★목록으로 막는 싸움은 **막는 쪽이 항상 뒤늦다.** 값의 모양이 무한하기 때문이다.
#   ⇒ **표면을 줄인다**(관리자 결정 2026-09-10): 지워도 되는 자리의 이름을 **하나로 못 박는다.**
#     ⑴실경로의 **마지막 칸이 정확히 `install-jarvis`** 다. 그 외의 값은 **거부하고 안내한다.**
#       · 참가자는 기본값을 쓰므로 아무 영향이 없고, 러너의 `…/lp-home/install-jarvis` 도 통과한다.
#       · 이 한 줄로 홈·루트·시스템 자리·UNC 공유·남의 프로젝트가 **한꺼번에** 닫힌다 —
#         그것들의 마지막 칸은 `install-jarvis` 가 아니기 때문이다.
#     ⑵**우리가 만든 표식**이 그 안에 있다 — 설치기는 **자기가 새로 만든 폴더에만** 표식을 놓는다.
#       (앞 판은 이미 있던 남의 폴더에도 표식을 써 줘서 이 관문을 스스로 무효화했다 — 3차 BLOCK.)
#   ⚠비교는 **실경로**로 한다: 링크로 만든 별칭(`~/install-jarvis` → `~/valuable`)은 실경로의
#     마지막 칸이 `valuable` 이라 저절로 거부된다. 조상 쪽 링크도 `pwd -P` 가 함께 풀어 준다.
#   ⚠정직하게 남는 것: 사람이 손수 `JARVIS_HOME=/어딘가/install-jarvis` 로 설치기를 돌려 그 자리를
#     **새로 만들게** 했다면 그 자리는 지워진다. 그것은 그분이 만드신 우리 폴더다(자국 표에 적는다).
JARVIS_OWNER_MARK="jarvis-installer-owned v1"
JARVIS_HOME_BASENAME="install-jarvis"
safe_jarvis_dir() { # safe_jarvis_dir <경로> → rc 0 = 지워도 된다 · 사유는 SAFE_WHY
  local p="$1" c
  SAFE_WHY=""
  case "$p" in
    /*) ;;
    *) SAFE_WHY="절대 경로가 아닙니다"; return 1 ;;
  esac
  c="$(canon "$p" 2>/dev/null)" || { SAFE_WHY="실제 경로를 확인하지 못했습니다"; return 1; }
  c="${c%/}"
  [ -n "$c" ] || { SAFE_WHY="빈 경로입니다"; return 1; }
  # ⑴이름 관문 — 실경로의 마지막 칸이 정확히 그 이름일 때만.
  if [ "$(basename "$c")" != "$JARVIS_HOME_BASENAME" ]; then
    SAFE_WHY="이 도구가 지우는 폴더의 이름은 「${JARVIS_HOME_BASENAME}」 하나입니다(실제 경로: $c)"
    return 1
  fi
  # ⑵표식 관문 — 설치기가 **새로 만든 폴더에만** 놓는다.
  [ -f "$c/.jarvis-owned" ] || { SAFE_WHY="설치 도우미가 놓은 표식이 없습니다(우리가 만든 폴더가 아닙니다)"; return 1; }
  grep -qF "$JARVIS_OWNER_MARK" "$c/.jarvis-owned" 2>/dev/null || { SAFE_WHY="표식의 내용이 우리 것이 아닙니다"; return 1; }
  return 0
}

# ── 작업 폴더 보관 이동(0.3.36) — 지우지 않고 같은 자리 옆 「install-jarvis-backup-<날짜-시각>」 으로 옮긴다 ──
#   까닭: 재설치·삭제 뒤에도 이전 자비스 자료가 남아 있어야 한다(사용자 손 0 · 자료 보존이 우선).
#   ★이름 바꾸기만 쓴다(perl rename = 시스템 rename 한 번) — `mv` 는 다른 볼륨이면 복사한 뒤 원본을 지운다.
#     이름 바꾸기가 안 되면(다른 볼륨·잠김·권한) **아무것도 지우지 않고 그 자리에 둔다** — 못 지운 것으로 세지 않는다
#     (재설치는 그 폴더 위에 이어서 간다 · 새 설치는 표식이 있는 폴더를 그대로 쓴다).
#   ★옮긴 뒤 파일 수·총 바이트를 옮기기 전과 대조한다 — 다르면 「보관 확인 실패」로 알리고 어느 쪽도 지우지 않는다.
#   ★보관본의 마지막 칸은 `install-jarvis` 가 아니다 ⇒ safe_jarvis_dir(이름 관문)가 다음 지우기에서 보관본을 절대 겨냥하지 않는다.
#   ★정리는 최근 JARVIS_BACKUP_KEEP 개만 남긴다 — 단 **설치기가 만든 이름만 든 보관본**만 정리한다(적대 검토 반례: 연속 재설치로
#     진짜 작업이 든 보관본이 밀려 지워졌다). 모르는 이름(사용자·자비스가 만든 것 · _round 등)이 하나라도 있으면 늘 남긴다 — 모르는 것은 보관 쪽.
#     대상 = 이름 꼴 ∧ 우리 표식 ∧ 진짜 폴더 ∧ 설치기 이름뿐 · 정리 실패는 못 지움으로 세지 않는다(재설치를 멈추지 않는다 · 안내 1줄).
#   다시 받을 수 있는 것은 **알려진 설치기 산출물 이름만** 뺀다(dl 안 claude-*·cys* · backup 안 cys* — 자국 표 M-JARVISHOME·M-APP) ·
#     그 밖의 파일(사용자가 둔 것)은 그대로 · 빈 폴더가 되면 폴더만 치운다.
JARVIS_BACKUP_PREFIX="install-jarvis-backup-"
JARVIS_BACKUP_KEEP=3
JARVIS_BACKUP_INSTALLER_NAMES=".jarvis-owned bootstrap.log env-report.md install-directive.md trust-seed.tsv wake.sh wake.ps1 install-id help-attempts.json remote-help-executed.json remote-help-executed.json.lock remote-help-client-token claude-install.log awake-master.ok install-done.txt transcript.txt .rotate-out .rotate-err .login-wait .login-pid .login-capped"
BACKUP_NOTE=""
tree_stat() { # tree_stat <폴더> → 「파일 수 총바이트」(폴더 제외 · 링크는 따라가지 않고 그 자신) · 하나라도 못 읽으면 rc 1
  perl -MFile::Find -e '
    use warnings;
    my ($e, $n, $b) = (0, 0, 0);
    local $SIG{__WARN__} = sub { $e = 1 };
    find({ no_chdir => 1, wanted => sub {
      my @s = lstat($_); unless (@s) { $e = 1; return }
      return if -d _;
      $n++; $b += $s[7];
    } }, $ARGV[0]);
    exit 2 if $e;
    print "$n $b\n";' "$1" 2>/dev/null   # use warnings 가 없으면 File::Find 의 「못 엶」 경고가 안 나와 못 읽은 하위를 조용히 뺀다(적대 검토 반례)
}
is_jarvis_backup() { # is_jarvis_backup <경로> → rc 0 = 이름 꼴 ∧ 진짜 폴더 ∧ 우리 표식(두 축)
  local b
  b="$(basename "$1")"
  printf '%s' "$b" | grep -qE "^${JARVIS_BACKUP_PREFIX}[0-9]{8}-[0-9]{6}(-[0-9]+)?\$" || return 1
  [ -d "$1" ] && [ ! -L "$1" ] || return 1
  [ -f "$1/.jarvis-owned" ] && grep -qF "$JARVIS_OWNER_MARK" "$1/.jarvis-owned" 2>/dev/null
}
installer_only_backup() { # installer_only_backup <보관본> → rc 0 = 설치기가 만든 이름만 들어 있다(그때만 정리 대상) · 못 세면 rc 1
  local d="$1" e b
  [ -r "$d" ] && [ -x "$d" ] || return 1
  for e in "$d"/* "$d"/.[!.]* "$d"/..?*; do
    [ -e "$e" ] || [ -L "$e" ] || continue
    b="$(basename "$e")"
    case " $JARVIS_BACKUP_INSTALLER_NAMES " in *" $b "*) [ -L "$e" ] && return 1; continue ;; esac
    case "$b" in capture-*.jpg) [ -f "$e" ] && [ ! -L "$e" ] && continue ;; .progress.*) { [ -f "$e" ] || [ -d "$e" ]; } && [ ! -L "$e" ] && continue ;; esac   # .progress.* = mktemp -d 폴더
    return 1
  done
  return 0
}
prune_jarvis_backups() { # prune_jarvis_backups <부모 폴더> <방금 만든 보관본> — 최근 KEEP 개만 남긴다(방금 것은 늘 남긴다)
  local parent="$1" fresh="$2" all n drop p
  all="$(find "$parent" -mindepth 1 -maxdepth 1 -name "${JARVIS_BACKUP_PREFIX}*" 2>/dev/null | LC_ALL=C sort)" || return 0
  n=0
  while IFS= read -r p; do [ -n "$p" ] && is_jarvis_backup "$p" && installer_only_backup "$p" && n=$((n+1)); done <<BK_COUNT
$all
BK_COUNT
  drop=$((n - JARVIS_BACKUP_KEEP))
  [ "$drop" -gt 0 ] || return 0
  while IFS= read -r p; do
    [ "$drop" -gt 0 ] || break
    [ -n "$p" ] && [ "$p" != "$fresh" ] && is_jarvis_backup "$p" && installer_only_backup "$p" || continue
    # 정리 실패는 못 지움으로 세지 않는다 — 셈을 되돌리고 한 줄만 알린다(재설치가 rc 7 로 멈추지 않게 · 적대 검토 반례)
    #   실패해도 한 번 시도한 것으로 센다 — 대신 더 새 보관본을 지우지 않는다(윈 짝)
    #   ⚠drop_dir 는 실패해도 rc 0 으로 끝나는 갈래가 있다 — 반환 코드가 아니라 셈이 늘었는지로 가른다(적대 검토 2회차 반례 · 윈 짝)
    local kf="$KEPT_FAIL"
    drop_dir "$p"
    if [ "$KEPT_FAIL" -gt "$kf" ]; then KEPT_FAIL="$kf"; say "  남김: $(short "$p") — 오래된 보관본을 정리하지 못했습니다(자료는 그대로입니다)."; fi
    drop=$((drop-1))
  done <<BK_DROP
$all
BK_DROP
  return 0
}
keep_jarvis_dir() { # keep_jarvis_dir <작업 폴더(안전 확인 통과)> — 보관 이동 · 마지막 안내 1줄 = BACKUP_NOTE
  local src="${1%/}" parent stamp dest n before after c f
  # 링크면 종전대로 이름표만 지운다(가리키던 자리 = 실제 자료는 그대로 남는다).
  if [ -L "$src" ]; then drop_dir "$src"; return; fi
  # 참가 자리(보존 경로)가 안에 있으면 옮기지 않는다 — 옮기면 그 자리도 함께 옮겨진다(보존 규율 · 옮겼다 되돌리기 금지).
  if [ "${PRESERVE_CANON_FAIL:-0}" -ne 0 ] || [ -n "$(preserved_under "$(canon "$src" 2>/dev/null)")" ] || [ -n "$(preserve_covers "$(canon "$src" 2>/dev/null)")" ]; then
    say "  남김: $(short "$src") — 안에 따로 두신 자리가 있어 옮기지 않고 그대로 두었습니다."
    BACKUP_NOTE="이전 자비스 자료는 $(short "$src") 에 그대로 두었습니다. 지운 것은 없습니다."
    return 0
  fi
  parent="$(dirname "$src")"
  stamp="$(date +%Y%m%d-%H%M%S)"
  dest="$parent/${JARVIS_BACKUP_PREFIX}${stamp}"; n=1
  while [ -e "$dest" ] || [ -L "$dest" ]; do n=$((n+1)); dest="$parent/${JARVIS_BACKUP_PREFIX}${stamp}-$n"; done
  if ! before="$(tree_stat "$src")" || [ -z "$before" ] || ! perl -e 'rename($ARGV[0], $ARGV[1]) or exit 1' "$src" "$dest" 2>/dev/null; then
    say "  남김: $(short "$src") — 다른 곳으로 옮기지 못해 그 자리에 그대로 두었습니다(지운 것 없음)."
    BACKUP_NOTE="이전 자비스 자료는 옮기지 못해 $(short "$src") 에 그대로 두었습니다. 지운 것은 없습니다."
    return 0
  fi
  after="$(tree_stat "$dest")"
  ARCHIVE_DEST="$dest"   # 0.3.37: 이번 실행의 보관 폴더 — 뒤의 cys 자료도 여기로 모은다(archive_root)
  if [ "$before" != "$after" ]; then
    ARCHIVE_FAIL=1; ARCHIVE_VERIFY_FAIL=1   # 0.3.37: 대조가 어긋나면 뒤 단계를 하지 않는다 · 다시 해 보기도 이 깃발은 안 지운다
    say "  🔴보관 확인 실패: $(short "$dest") — 옮기기 전과 파일 수·크기가 달라 아무것도 지우지 않았습니다(전 $before · 뒤 ${after:-못 셈})."
    BACKUP_NOTE="이전 자비스 자료를 $(short "$dest") 로 옮겼지만 빠짐없이 옮겨졌는지 확인하지 못했습니다. 아무것도 지우지 않았습니다."
    return 0
  fi
  # 다시 받는 것 = 알려진 설치기 산출물 이름만(dl: claude-*·cys* · backup: cys*) · 사용자가 둔 다른 파일은 그대로(적대 검토 반례)
  #   ⚠부모 dl·backup 이 링크면 들어가지 않는다 — 따라 들어가 바깥(예: 받은 파일 폴더)의 claude-*·cys* 를 지운다(적대 검토 2회차 반례 · 윈 짝)
  for c in dl backup; do
    [ -d "$dest/$c" ] && [ ! -L "$dest/$c" ] || continue
    for f in "$dest/$c"/claude-* "$dest/$c"/cys*; do
      [ "$c" = backup ] && case "$(basename "$f")" in claude-*) continue ;; esac
      [ -e "$f" ] || [ -L "$f" ] || continue
      rm -rf "$f" 2>/dev/null
    done
  done
  for c in dl backup; do [ -d "$dest/$c" ] && [ ! -L "$dest/$c" ] && rmdir "$dest/$c" 2>/dev/null; done
  say "  보관: $(short "$src") → $(short "$dest") (파일 ${before% *}개 · 옮긴 뒤 수·크기 같음)"
  prune_jarvis_backups "$parent" "$dest"
  BACKUP_NOTE="이전 자비스 자료는 $(short "$dest") 에 그대로 보관해 두었습니다."
  return 0
}

# ── 0.3.37 보관 이동 넓히기 — 지우는 것은 다시 받는 프로그램 파일뿐 · 사람이 쌓은 자료는 보관 폴더로 옮긴다 ──
#   설계 = docs/install-master/DESIGN-0337.md 3·4절.
#   ★옮기기 = 같은 볼륨 안 이름 바꾸기 한 번(perl rename)뿐 — 복사하지 않는다. 다른 볼륨이면 옮기지 않고 멈춘다(ARCHIVE_FAIL).
#   ★옮긴 뒤 파일 수·총 바이트를 대조한다(tree_stat) — 어긋나면 ARCHIVE_FAIL · purge 가 그 뒤 단계(프로그램 지우기 등)를 하지 않는다.
#   ★보관 폴더 = 작업 폴더 보관(keep_jarvis_dir)이 만든 것(ARCHIVE_DEST)에 모은다 — 그것이 없거나 홈과 다른 볼륨이면
#     홈에 같은 이름 꼴로 새로 만들고 우리 표식을 놓는다(ARCHIVE_HOME). 사람 자료가 든 보관본은 자동 정리 대상이 아니다
#     (installer_only_backup 이 설치기 이름 밖의 것을 보면 늘 남긴다 — 0.3.36 규칙 그대로).
ARCHIVE_DEST=""; ARCHIVE_HOME=""; ARCHIVE_FAIL=0; ARCHIVED=0; ARCHIVE_LAST=""; ARCHIVE_VERIFY_FAIL=0; CYS_HOME_ARCHIVED=""
CRED_MARK=".jarvis-cred-pending"   # 완전 삭제 보관본 속 로그인 파일 정리가 남았다(보관된 옛 ~/.cys 맨 위 · 빈 파일) — 다음 실행이 이어서 지운다(r1 F4)
RESTORE_MARK=".jarvis-restore-pending"   # 재설치 되옮기기 진행 표지(보관 폴더 맨 위 · NUL 로 가른 상대 이름 목록) — 다음 실행이 이어서 끝낸다
# 재설치 길에서 본부 상태(~/.local/state/cys) 안에서 보관 폴더로 옮길 편성 기록(윈 Get-CysStateItems 짝 · DESIGN-0337 📌4 ⓑ) — 나머지는 제자리
STATE_FORMATION_NAMES="topology.json
phoenix
boot-intents
dept_tombstones.json"
volume_of() { stat -f %d "$1" 2>/dev/null; }
same_volume() { local a b; a="$(volume_of "$1")"; b="$(volume_of "$2")"; [ -n "$a" ] && [ "$a" = "$b" ]; }
new_backup_dir() { # new_backup_dir <부모> → 새 보관 폴더(우리 표식 · 이름 꼴 install-jarvis-backup-<시각>[-n])를 찍는다 · 못 만들면 rc 1
  local parent="$1" stamp d n=1
  stamp="$(date +%Y%m%d-%H%M%S)"
  d="$parent/${JARVIS_BACKUP_PREFIX}${stamp}"
  while [ -e "$d" ] || [ -L "$d" ]; do n=$((n+1)); d="$parent/${JARVIS_BACKUP_PREFIX}${stamp}-$n"; done
  mkdir "$d" 2>/dev/null || return 1
  chmod 700 "$d" 2>/dev/null
  if ! printf '%s\n' "$JARVIS_OWNER_MARK" > "$d/.jarvis-owned" 2>/dev/null; then rmdir "$d" 2>/dev/null; return 1; fi
  printf '%s' "$d"
}
# archive_move <원 자리> <보관 폴더 안 이름> <화면 이름> — 자료 한 자리를 보관 폴더로 옮긴다. 실패 = ARCHIVE_FAIL · 못 지움 +1 · rc 1
#   링크면 종전대로 이름표만 지운다(가리키던 실제 자료는 무접촉) · 참가 자리가 안에 있으면 옮기지 않고 그대로 둔다(옮겼다 되돌리기 금지)
#   ⚠보관 폴더는 하위 셸($(…))에서 정하면 ARCHIVE_HOME 이 부모에 안 남는다 — 그래서 archive_root_set 이 부모 셸에서 정해 AROOT 에 둔다.
archive_root_set() { # 부모 셸에서 보관 폴더를 정해 AROOT 에 둔다 · 못 만들면 rc 1
  AROOT=""
  if [ -n "$ARCHIVE_DEST" ] && [ -d "$ARCHIVE_DEST" ] && same_volume "$ARCHIVE_DEST" "$HOME"; then AROOT="$ARCHIVE_DEST"; return 0; fi
  if [ -z "$ARCHIVE_HOME" ] || [ ! -d "$ARCHIVE_HOME" ]; then ARCHIVE_HOME="$(new_backup_dir "$HOME")" || { ARCHIVE_HOME=""; return 1; }; fi
  AROOT="$ARCHIVE_HOME"
}
free_rel() { # free_rel <보관 폴더> <이름> → 비어 있는 이름(겹치면 -2, -3 …) — 다시 해 보기가 같은 이름을 또 쓸 때 덮지 않는다
  local r="$2" n=1
  while [ -e "$1/$r" ] || [ -L "$1/$r" ]; do n=$((n+1)); r="$2-$n"; done
  printf '%s' "$r"
}
archive_move() {
  local src="$1" rel="$2" what="$3" dest before after c
  [ -e "$src" ] || [ -L "$src" ] || return 0
  if [ -L "$src" ]; then drop_dir "$src"; return $?; fi
  c="$(canon "$src" 2>/dev/null)" || c=""
  if [ "${PRESERVE_CANON_FAIL:-0}" -ne 0 ] || [ -z "$c" ] || [ -n "$(preserved_under "$c")" ] || [ -n "$(preserve_covers "$c")" ]; then
    PRESERVED=$((PRESERVED+1))
    say "  남김: $(short "$src") — 안에 따로 두신 자리가 있거나 실제 경로를 확인하지 못해 옮기지 않고 그대로 두었습니다(지운 것 없음)."
    return 0
  fi
  if ! archive_root_set; then
    ARCHIVE_FAIL=1; KEPT_FAIL=$((KEPT_FAIL+1))
    say "  🔴못 옮김: $(short "$src") — 보관 폴더를 만들지 못해 그대로 두었습니다(지운 것 없음)."
    return 1
  fi
  if ! same_volume "$AROOT" "$(dirname "$src")"; then
    ARCHIVE_FAIL=1; KEPT_FAIL=$((KEPT_FAIL+1))
    say "  🔴못 옮김: $(short "$src") — 보관 폴더와 다른 디스크에 있어 옮기지 않았습니다(복사하지 않습니다 · 지운 것 없음)."
    return 1
  fi
  mkdir -p "$(dirname "$AROOT/$rel")" 2>/dev/null
  dest="$AROOT/$(free_rel "$AROOT" "$rel")"
  if ! before="$(tree_stat "$src")" || [ -z "$before" ] \
     || ! perl -e 'rename($ARGV[0], $ARGV[1]) or exit 1' "$src" "$dest" 2>/dev/null; then
    ARCHIVE_FAIL=1; KEPT_FAIL=$((KEPT_FAIL+1))
    say "  🔴못 옮김: $(short "$src") — 보관 폴더로 옮기지 못해 그대로 두었습니다(지운 것 없음 · 쓰고 있는 프로그램이 있을 수 있습니다)."
    return 1
  fi
  after="$(tree_stat "$dest")"
  if [ "$before" != "$after" ]; then
    ARCHIVE_FAIL=1; ARCHIVE_VERIFY_FAIL=1; KEPT_FAIL=$((KEPT_FAIL+1))
    say "  🔴보관 확인 실패: $(short "$dest") — 옮기기 전과 파일 수·크기가 다릅니다(전 $before · 뒤 ${after:-못 셈}). 이 뒤로는 아무것도 지우지 않습니다."
    return 1
  fi
  ARCHIVED=$((ARCHIVED+1)); ARCHIVE_LAST="$dest"
  say "  보관: ${what} $(short "$src") → $(short "$dest")"
  return 0
}
# 완전 삭제 보관본에서는 자비스 창 전용 로그인 파일을 빼고 지운다(DESIGN-0337 📌3 · 보관 폴더는 사람이 옮기고 나눠 줄 수 있는 자리 —
#   비밀값이 남으면 안 된다). 맥은 로그인이 열쇠고리라 보통 파일이 없다. 바로가기는 따라가지 않는다(이름표도 건드리지 않음).
#   r1 F4: 지우기 **전에** 그 보관본 맨 위에 「정리 남음」 표지(CRED_MARK)를 먼저 둔다 — 창이 닫히거나 끝내 실패해도 **다음 실행**이
#   진단에서 찾은 자국으로 세고 지우기 맨 앞에서 이어서 지운다(resume_archived_credentials). 다 지우면 표지를 치운다.
#   (앞 판은 보관 자리를 이 실행의 변수로만 기억해, 회차 사이만 이어지고 새 실행은 「지울 것 없음」 → 비밀값이 보관본에 남았다.)
drop_archived_credentials() { # drop_archived_credentials <보관된 옛 ~/.cys>
  local f d fail=0 next="다시 실행하시면 이어서 지웁니다."
  # 표지를 못 쓰면 다음 실행이 이어서 지울 근거가 없다 — 그때는 「이어서 지웁니다」 라고 약속하지 않는다(r3 M3)
  { : > "$1/$CRED_MARK"; } 2>/dev/null || next="그 폴더의 쓰기 권한을 확인해 주십시오(정리 표지를 쓰지 못해 다음 실행이 스스로 이어 지우지 못합니다): $(short "$1")"
  if [ -d "$1" ] && { [ ! -x "$1" ] || [ ! -r "$1" ]; }; then   # 보관된 옛 ~/.cys 를 못 들어가거나 목록을 못 읽으면(claude-* 가 안 펼쳐짐 · r3 M1) 「없음」 이 아니다(r2 N3 · 윈 Get-ChildItem 예외 짝)
    KEPT_FAIL=$((KEPT_FAIL+1)); say "  🔴못 지움: 보관본 속 로그인 파일을 찾지 못했습니다: $(short "$1") — $next"
    return 0
  fi
  for d in "$1"/claude "$1"/claude-*; do
    [ -d "$d" ] && [ ! -L "$d" ] || continue   # 폴더(claude*)가 바로가기면 바깥 파일이다 — 손대지 않는다
    # 못 들어가는 폴더(권한)면 「없음」 으로 넘기지 않는다 — 못 지움으로 센다(r1 F4-2 · 윈 짝)
    if [ ! -x "$d" ]; then
      fail=1; KEPT_FAIL=$((KEPT_FAIL+1)); say "  🔴못 지움: 보관본 속 로그인 파일을 읽지 못했습니다: $(short "$d") — $next"
      continue
    fi
    f="$d/.credentials.json"
    [ -f "$f" ] && [ ! -L "$f" ] || continue
    if rm -f "$f" 2>/dev/null && [ ! -e "$f" ]; then
      say "  지움: 보관본 속 자비스 창 로그인 파일 $(short "$f") (비밀값은 보관하지 않습니다 — 다시 설치하실 때 이어서 로그인됩니다)"
    else
      fail=1; KEPT_FAIL=$((KEPT_FAIL+1)); say "  🔴못 지움: 보관본 속 로그인 파일 $(short "$f") — $next"
    fi
  done
  if [ "$fail" -eq 0 ] && { [ -e "$1/$CRED_MARK" ] || [ -L "$1/$CRED_MARK" ]; }; then
    # 다 지웠는데 표지를 못 치우면 다음 실행마다 「남음」 으로 세게 된다 — 조용히 넘기지 않는다(r2 N4)
    if ! { rm -f "${1:?}/$CRED_MARK"; } 2>/dev/null || [ -e "$1/$CRED_MARK" ]; then
      KEPT_FAIL=$((KEPT_FAIL+1)); say "  🔴못 지움: 보관본 속 정리 표지 $(short "$1/$CRED_MARK") — 로그인 파일은 지웠습니다. 그 폴더의 쓰기 권한을 확인해 주십시오."
    fi
  fi
  return 0
}
# 로그인 파일 정리가 남은 완전 삭제 보관본의 옛 ~/.cys(보관 폴더 두 자리 · 한 줄에 하나) — 되옮기기 표지가 있는 재설치 보관본은 뺀다(그 안 로그인은 되옮길 것)
cred_pending_homes() {
  local d p h parents="$HOME"
  [ "$(dirname "$JARVIS_HOME")" != "$HOME" ] && parents="$parents
$(dirname "$JARVIS_HOME")"
  while IFS= read -r d; do
    [ -n "$d" ] || continue
    while IFS= read -r p; do
      [ -n "$p" ] || continue
      is_jarvis_backup "$p" && [ ! -e "$p/$RESTORE_MARK" ] || continue
      for h in "$p"/cys-home "$p"/cys-home-[0-9]*; do
        [ -d "$h" ] && [ ! -L "$h" ] && [ -f "$h/$CRED_MARK" ] && printf '%s\n' "$h"
      done
    done <<CRED_LIST
$(find "$d" -mindepth 1 -maxdepth 1 -name "${JARVIS_BACKUP_PREFIX}*" 2>/dev/null | LC_ALL=C sort)
CRED_LIST
  done <<CRED_PARENTS
$parents
CRED_PARENTS
}
resume_archived_credentials() {
  local h
  while IFS= read -r h; do
    [ -n "$h" ] || continue
    say "  지난번에 끝나지 않은 보관본 속 로그인 파일 지우기를 이어서 합니다: $(short "$h")"
    drop_archived_credentials "$h"
  done <<CRED_HOMES
$(cred_pending_homes)
CRED_HOMES
}
# 재설치 길에서 ~/.cys 로 되옮길 것을 ~/.cys 기준 상대 이름으로 NUL 로 갈라 찍는다(DESIGN-0337 4-2절) — 한 층 · 목록을 못 읽으면 rc 1
#   본부 = claude/ 안 HISTORY_KEEP_NAMES(0.3.36 · 대소문자 무시) · 부서 = depts.json · dept-catalog.json · dept-missions ·
#   dept-requests · dept-snapshots · pack-dept-* · claude-*(부서·계정별 좌석 프로필 — 통째로).
#   ★줄 목록을 쓰지 않는다(NUL) — 경로·이름에 줄바꿈이 있어도 쪼개지지 않는다(0.3.36 반례 ③).
#   ★find 종료값을 직접 받는다 — 「못 읽음」을 「남길 것 없음」으로 읽지 않는다(반례 ④).
reinstall_keep_list() {
  local n out
  out="$(mktemp -t jarvis-keep)" || return 1
  if ! find "$HOME/.cys" -mindepth 1 -maxdepth 1 \( -name 'depts.json' -o -name 'dept-catalog.json' -o -name 'dept-missions' \
      -o -name 'dept-requests' -o -name 'dept-snapshots' -o -name 'pack-dept-*' -o -name 'claude-*' \) -print0 > "$out" 2>/dev/null; then
    rm -f "${out:?}"; return 1
  fi
  if [ -d "$HOME/.cys/claude" ] && [ ! -L "$HOME/.cys/claude" ]; then
    while IFS= read -r n; do
      [ -n "$n" ] || continue
      if ! find "$HOME/.cys/claude" -mindepth 1 -maxdepth 1 -iname "$n" -print0 >> "$out" 2>/dev/null; then rm -f "${out:?}"; return 1; fi
    done <<KEEP_NAMES
$HISTORY_KEEP_NAMES
KEEP_NAMES
  fi
  JK_ROOT="$HOME/.cys" perl -0 -ne 'chomp; my $h = $ENV{JK_ROOT}; print substr($_, length($h) + 1), "\0" if substr($_, 0, length($h) + 1) eq "$h/"' "$out" 2>/dev/null
  rm -f "${out:?}"
}
# 예외 갈래(참가 자리가 ~/.cys 안 · DESIGN-0337 4-4절)의 부서 남길 것 실경로(한 줄에 하나) → DEPT_KEEPS · 목록 못 읽음·줄바꿈 = rc 1
#   바로가기는 **자리**(부모 실경로 + 이름)로 적는다 — 가리키는 곳이 ~/.cys 안 남길 것 밖이면 사전 훑기가 이미 멈췄다(반례 ①).
DEPT_KEEPS=""
dept_keeps() {
  local lst hc
  DEPT_KEEPS=""
  hc="$(canon "$HOME/.cys" 2>/dev/null)" || return 1
  lst="$(mktemp -t jarvis-dk)" || return 1
  if ! reinstall_keep_list > "$lst"; then rm -f "${lst:?}"; return 1; fi
  DEPT_KEEPS="$(JK_HC="$hc" perl -0 -ne 'chomp; exit 3 if /\n/; next if m{^claude/}; print "$ENV{JK_HC}/$_\n"' "$lst" 2>/dev/null)" || { rm -f "${lst:?}"; DEPT_KEEPS=""; return 1; }
  rm -f "${lst:?}"
  [ -n "$DEPT_KEEPS" ] && DEPT_KEEPS="$DEPT_KEEPS
"
  return 0
}
# restore_from <보관 폴더> — 되옮기기 진행 표지에 적힌 것을 cys-home 에서 ~/.cys 로 이름 바꾸기로 되옮긴다.
#   ~/.cys 에 같은 이름이 이미 있으면 덮지 않는다 — **되옮기기 실패와 같다**(r1 F2 · master#0337b3fa · DESIGN-0337 4절 5 · 10절):
#     그 이름은 보관 폴더에 그대로 · 표지에 남김 · 쉬운 말 1줄 · rc 1 → 재설치를 멈춘다(rc 7). 옛 판은 건너뛰고 표지를 지워 rc 0 이었다.
#   하나라도 못 옮기면 표지에 남은 것만 적어 두고 못 지움 +1 · rc 1(다음 실행이 이어서 끝낸다) · 전부 끝나면 표지를 지운다.
#   표지 고쳐 쓰기 = 임시 파일에 다 쓴 뒤 이름 바꾸기(r1 F3) — 도중에 끊기거나 못 쓰면 옛 표지가 그대로 남는다(반쪽 표지 → 「할 것 없음」 → 표지 지움 금지).
restore_from() {
  local root="$1" mark rel src dst fail=0 left home="" _up _lnk
  mark="${root:?}/$RESTORE_MARK"
  [ -f "$mark" ] || return 0
  left="$(mktemp -t jarvis-left)" || return 1
  # 표지 첫 칸 = 보관 폴더 안 옛 ~/.cys 의 이름(보통 cys-home · 다시 해 보기면 cys-home-2 …) · 나머지 = 되옮길 상대 이름
  IFS= read -r -d '' home < "$mark" || home=""
  case "$home" in cys-home|cys-home-[0-9]*) : ;; *) rm -f "${left:?}"; KEPT_FAIL=$((KEPT_FAIL+1)); ARCHIVE_FAIL=1
    say "  🔴되옮기기 표지를 읽지 못했습니다: $(short "$mark") — 자료는 보관 폴더에 그대로 있습니다."; return 1 ;; esac
  printf '%s\0' "$home" > "$left"
  if [ ! -d "$HOME/.cys" ]; then mkdir "$HOME/.cys" 2>/dev/null; chmod 700 "$HOME/.cys" 2>/dev/null; fi
  while IFS= read -r -d '' rel; do
    [ -n "$rel" ] || continue
    [ "$rel" = "$home" ] && continue                        # 첫 칸
    # 표지는 우리가 쓴 것이지만 손으로 고쳐졌을 수 있다 — ~/.cys 밖을 가리키는 칸(절대경로 · ..)은 되옮기지 않는다(윈 Restore-From 짝 · r1 F5-2)
    case "$rel" in /*|..|../*|*/..|*/../*)
      fail=1; printf '%s\0' "$rel" >> "$left"
      say "  🔴남음: 되옮기기 표지의 한 칸을 알아보지 못했습니다: $rel — 자료는 보관 폴더에 그대로 있습니다."
      continue ;;
    esac
    src="$root/$home/$rel"; dst="$HOME/.cys/$rel"
    [ -e "$src" ] || [ -L "$src" ] || continue            # 이미 되옮겼다
    # 되옮길 자리의 윗자리(~/.cys 안 · 예: ~/.cys/claude)가 바로가기면 따라가지 않는다 — 따라가면 ~/.cys 밖으로 옮겨진다(r2 N6 · cys_home_reinstall 과 같은 판정)
    _up="$(dirname "$rel")"; _lnk=""
    while [ "$_up" != "." ] && [ "$_up" != "/" ]; do [ -L "$HOME/.cys/$_up" ] && _lnk="$_up"; _up="$(dirname "$_up")"; done
    if [ -n "$_lnk" ]; then
      fail=1; printf '%s\0' "$rel" >> "$left"
      say "  🔴남음: $(short "$HOME/.cys/$_lnk") 가 바로가기라 $(short "$dst") 를 되옮기지 않았습니다 — 예전 자료는 보관 폴더에 그대로 있습니다: $(short "$src")"
      continue
    fi
    if [ -e "$dst" ] || [ -L "$dst" ]; then
      fail=1; printf '%s\0' "$rel" >> "$left"
      say "  🔴남음: $(short "$dst") — 같은 이름의 자료가 이미 있어 덮지 않았습니다. 예전 자료는 보관 폴더에 그대로 있습니다: $(short "$src")"
      say "         새로 생긴 쪽($(short "$dst"))을 다른 이름으로 바꿔 두신 뒤 다시 실행하시면 예전 자료를 제자리로 옮깁니다 — 바꿔 둔 새 쪽은 그때 보관 폴더로 함께 옮겨집니다(어느 쪽도 지우지 않습니다)."
      continue
    fi
    mkdir -p "$(dirname "$dst")" 2>/dev/null
    if perl -e 'rename($ARGV[0], $ARGV[1]) or exit 1' "$src" "$dst" 2>/dev/null; then
      say "  되옮김: $(short "$dst")"
    else
      fail=1; printf '%s\0' "$rel" >> "$left"
      say "  🔴되옮기지 못함: $(short "$src") — 보관 폴더에 그대로 있습니다(지운 것 없음)."
    fi
  done < "$mark"
  if [ "$fail" -eq 0 ]; then rm -f "${mark:?}" "${left:?}"; return 0; fi   # (left 의 첫 칸 = home 이름 · 남은 것만 뒤에)
  if ! { cat "$left" > "$mark.tmp" && perl -e 'rename($ARGV[0], $ARGV[1]) or exit 1' "$mark.tmp" "$mark"; } 2>/dev/null; then
    rm -f "${mark:?}.tmp"
    say "  🔴되옮기기 표지를 고쳐 쓰지 못해 지난 표지를 그대로 두었습니다 — 자료는 보관 폴더에 그대로 있고, 다시 실행하시면 이어서 옮깁니다."
  fi
  rm -f "${left:?}"
  KEPT_FAIL=$((KEPT_FAIL+1)); ARCHIVE_FAIL=1
  return 1
}
# 끝나지 않은 되옮기기를 먼저 끝낸다(보관 이동 승인 조건 ⑴) — 보관 폴더 두 자리(홈 · 작업 폴더 부모)에서 표지가 있는 우리 보관본을 오래된 것부터.
#   하나라도 못 끝내면 RESUME_LEFT=1 — 이 실행의 ~/.cys 재설치 길은 이어 가지 않는다(r1 F2 · DESIGN-0337 10절 「이어 가지 않고 멈춘다」).
resume_unfinished_restore() {
  local p d parents
  RESUME_LEFT=0
  parents="$HOME"
  [ "$(dirname "$JARVIS_HOME")" != "$HOME" ] && parents="$parents
$(dirname "$JARVIS_HOME")"
  while IFS= read -r d; do
    [ -n "$d" ] || continue
    while IFS= read -r p; do
      [ -n "$p" ] || continue
      is_jarvis_backup "$p" && [ -f "$p/$RESTORE_MARK" ] || continue
      if [ -L "$HOME/.cys" ]; then
        KEPT_FAIL=$((KEPT_FAIL+1)); ARCHIVE_FAIL=1; RESUME_LEFT=1
        say "  🔴되옮기기를 이어 가지 못했습니다: $(short "$HOME/.cys") 가 바로가기입니다 — 자료는 $(short "$p") 에 그대로 있습니다."
        continue
      fi
      say "  지난번에 끝나지 않은 되옮기기를 이어서 합니다: $(short "$p")"
      restore_from "$p" || RESUME_LEFT=1
    done <<RESUME_LIST
$(find "$d" -mindepth 1 -maxdepth 1 -name "${JARVIS_BACKUP_PREFIX}*" 2>/dev/null | LC_ALL=C sort)
RESUME_LIST
  done <<RESUME_PARENTS
$parents
RESUME_PARENTS
}
# ~/.cys 재설치 길(R2 · DESIGN-0337 4절): 통째로 보관 폴더로 옮긴 뒤 남길 것만 되옮긴다 — 지우는 것 0.
cys_home_reinstall() {
  local list hname
  if [ -L "$HOME/.cys" ]; then
    KEPT_FAIL=$((KEPT_FAIL+1))
    say "  🔴못 지움: $(short "$HOME/.cys") — 바로가기라 이전 대화를 제자리로 되옮길 수 없어 **아무것도 바꾸지 않았습니다.**"
    return 1
  fi
  # ~/.cys/claude 자체가 바로가기면 못 푼다(0.3.36 ⓠ 그대로) — 이름표만 되옮기면 가리키는 곳의 옛 CLAUDE.md 가 새 판을 막고,
  #   안 되옮기면 새 자리에서 이전 대화가 안 보인다 ⇒ 아무것도 바꾸지 않고 멈춘다(가리키는 곳의 자료는 원래 무접촉).
  if [ -L "$HOME/.cys/claude" ]; then
    KEPT_FAIL=$((KEPT_FAIL+1))
    say "  🔴못 지움: $(short "$HOME/.cys/claude") — 바로가기라 이전 대화를 제자리로 되옮길 수 없어 **아무것도 바꾸지 않았습니다.**"
    return 1
  fi
  # 지난번 되옮기기를 이번 실행에서 끝내지 못했으면(겹침 · 못 옮김) ~/.cys 를 또 옮기지 않는다 — 옛 자료가 보관본 두 곳으로 갈라진다.
  if [ "${RESUME_LEFT:-0}" = "1" ]; then
    KEPT_FAIL=$((KEPT_FAIL+1)); ARCHIVE_FAIL=1
    say "  🔴남음: 지난번 옮기기가 아직 끝나지 않아 이번에는 $(short "$HOME/.cys") 를 바꾸지 않았습니다."
    say "         예전 자료는 보관 폴더에 그대로 있고, 위 🔴 줄의 까닭이 풀린 뒤 다시 실행하시면 이어서 제자리로 옮깁니다."
    return 1
  fi
  list="$(mktemp -t jarvis-rl)" || return 1
  if ! reinstall_keep_list > "$list" || ! ls -A "$HOME/.cys" >/dev/null 2>&1; then
    rm -f "${list:?}"; KEPT_FAIL=$((KEPT_FAIL+1)); ARCHIVE_FAIL=1
    say "  🔴못 지움: $(short "$HOME/.cys") — 남길 자리의 목록을 읽지 못해 **아무것도 바꾸지 않았습니다.**"
    return 1
  fi
  if ! archive_root_set; then
    rm -f "${list:?}"; KEPT_FAIL=$((KEPT_FAIL+1)); ARCHIVE_FAIL=1
    say "  🔴못 옮김: $(short "$HOME/.cys") — 보관 폴더를 만들지 못해 그대로 두었습니다(지운 것 없음)."
    return 1
  fi
  # 이 보관 폴더에 아직 끝나지 않은 되옮기기 표지가 있으면 덮지 않는다(윈 Invoke-CysHomeReinstall 짝) —
  #   덮으면 그 목록을 잃어, 앞 회차 보관본에 남은 로그인·대화가 제자리로 영영 안 돌아온다(스스로 다시 해 보기가 그렇게 rc 0 으로 끝났다).
  if [ -e "$AROOT/$RESTORE_MARK" ] || [ -L "$AROOT/$RESTORE_MARK" ]; then
    rm -f "${list:?}"; KEPT_FAIL=$((KEPT_FAIL+1)); ARCHIVE_FAIL=1
    say "  🔴남음: 지난번 옮기기가 아직 끝나지 않아 이번에는 $(short "$HOME/.cys") 를 바꾸지 않았습니다."
    say "         자료는 $(short "$AROOT") 에 그대로 있고, 다시 실행하시면 이어서 제자리로 옮깁니다."
    return 1
  fi
  # 표지를 **먼저** 쓴다 — 옮긴 직후 멈춰도 다음 실행이 무엇을 되옮길지 안다. 첫 칸 = 보관 폴더 안 이름(겹치지 않게 고른다).
  hname="$(free_rel "$AROOT" "cys-home")"
  if ! { printf '%s\0' "$hname"; cat "$list"; } > "$AROOT/$RESTORE_MARK" 2>/dev/null; then
    rm -f "${list:?}"; KEPT_FAIL=$((KEPT_FAIL+1)); ARCHIVE_FAIL=1
    say "  🔴못 옮김: 되옮기기 표지를 쓰지 못해 $(short "$HOME/.cys") 를 그대로 두었습니다(지운 것 없음)."
    return 1
  fi
  rm -f "${list:?}"
  if ! archive_move "$HOME/.cys" "$hname" "cys 계정 자리(다시 까는 길 — 남길 것은 곧 제자리로 되옮깁니다)"; then
    [ -e "$HOME/.cys" ] && rm -f "${AROOT:?}/$RESTORE_MARK"   # 원자리가 그대로면 아무것도 안 옮긴 것 — 표지를 거둔다
    return 1
  fi
  mkdir "$HOME/.cys" 2>/dev/null; chmod 700 "$HOME/.cys" 2>/dev/null
  restore_from "$AROOT" || return 1
  say "  남김: 자비스 창 로그인·이전 대화 · 부서 등록부·부서 좌석 기록 (다시 까는 길이라 제자리로 되옮겼습니다)"
  return 0
}
# 재설치 길 — 본부 상태 안의 편성 기록만 보관 폴더로(나머지 제자리 · 윈 Get-CysStateItems 짝 · 📌4 ⓑ)
state_formation_archive() {
  local d="$HOME/.local/state/cys" n f
  if [ -L "$d" ]; then drop_dir "$d"; return $?; fi
  [ -d "$d" ] || return 0
  while IFS= read -r n; do
    [ -n "$n" ] || continue
    archive_move "$d/$n" "cys-state/$n" "cys 지난 편성 기록" || return 1
  done <<SF_NAMES
$STATE_FORMATION_NAMES
SF_NAMES
  for f in "$d"/topology.json.*; do
    [ -e "$f" ] || [ -L "$f" ] || continue
    archive_move "$f" "cys-state/$(basename "$f")" "cys 지난 편성 기록" || return 1
  done
  return 0
}
# 사전 훑기(읽기만 · 첫 변경 전 · DESIGN-0337 6-1절 ②③④) — 옮길 자료 자리 아래 바로가기가 이 실행이 **지우는** 프로그램 자리를
#   가리키거나(그곳 자료가 사라진다) · 경로에 줄바꿈이 있거나 · 목록을 못 읽으면 rc 1 → 이 실행은 아무것도 바꾸지 않는다.
#   남길 것 안 바로가기가 ~/.cys 의 남길 것 밖을 가리키면 PRESCAN_NOTE(재설치 · 멈추지 않음 · 가리키던 자료는 보관 폴더에 있다 = 반례 ①).
PRESCAN_BAD=""; PRESCAN_NOTE=""
lc() { printf '%s' "$1" | tr '[:upper:]' '[:lower:]'; }   # APFS 기본 = 대소문자 무시 ⇒ 비교는 소문자로(더 많이 잡는 쪽)
under_any() { # under_any <경로> <뿌리들(한 줄에 하나)> → rc 0 = 그 뿌리 자신이거나 그 아래
  local c r
  c="$(lc "$1")"
  while IFS= read -r r; do
    [ -n "$r" ] || continue
    r="$(lc "$r")"
    case "$c" in "$r"|"$r"/*) return 0 ;; esac
  done <<< "$2"
  return 1
}
prescan_links() {
  local roots p pc r c t lst proots="" keeps="" hc="" prc nested=""
  PRESCAN_BAD=""; PRESCAN_NOTE=""
  case "$HOME" in *$'\n'*) PRESCAN_BAD="(홈 경로에 줄바꿈이 있습니다)"; return 1 ;; esac
  # 이 실행이 지우는 프로그램 자리(P)
  for p in "$HOME/.local/share/claude" "$HOME/.local/bin/claude" "$HOME/install-jarvis.sh"; do
    [ -e "$p" ] || [ -L "$p" ] || continue
    c="$(canon "$p" 2>/dev/null)" && [ -n "$c" ] && proots="$proots$c
"
  done
  if [ "$KEEP_APP" != "1" ]; then
    for p in "$CYS_APP" ${CYS_APP_OLD:+"$CYS_APP_OLD"}; do
      [ -e "$p" ] || continue
      c="$(canon "$p" 2>/dev/null)" && [ -n "$c" ] && proots="$proots$c
"
    done
  fi
  # 재설치 길의 남길 것(반례 ① 판정용 · 실경로 한 줄에 하나 — 줄바꿈 든 이름은 못 풂)
  if [ "$KEEP_HISTORY" = "1" ] && [ -d "$HOME/.cys" ] && [ ! -L "$HOME/.cys" ]; then
    hc="$(canon "$HOME/.cys" 2>/dev/null)" || { PRESCAN_BAD="$(short "$HOME/.cys") (실제 경로를 확인하지 못했습니다)"; return 1; }
    lst="$(mktemp -t jarvis-pk)" || return 1
    if ! reinstall_keep_list > "$lst"; then rm -f "${lst:?}"; PRESCAN_BAD="$(short "$HOME/.cys") (목록을 읽지 못했습니다)"; return 1; fi
    keeps="$(JK_HC="$hc" perl -0 -ne 'chomp; exit 3 if /\n/; print "$ENV{JK_HC}/$_\n"' "$lst" 2>/dev/null)"; prc=$?
    rm -f "${lst:?}"
    [ "$prc" -eq 0 ] || { PRESCAN_BAD="(남길 자리 이름에 줄바꿈이 있습니다)"; return 1; }
    # 참가 자리가 ~/.cys 안인가(예외 갈래 · 4-4절) — 읽기만(보존 경로 실경로 풀기)
    resolve_preserve_paths
    nested="$(preserved_under "$hc")"
  fi
  roots="$HOME/.cys
$HOME/.local/state/cys
$HOME/.local/state/cys-trash
$JARVIS_HOME"
  for r in "$HOME/.local/state"/cys-dept-*; do [ -d "$r" ] && roots="$roots
$r"; done
  lst="$(mktemp -t jarvis-pl)" || return 1
  while IFS= read -r r; do
    [ -n "$r" ] || continue
    [ -d "$r" ] && [ ! -L "$r" ] || continue
    : > "$lst"
    if ! find "$r" -type l -print0 > "$lst" 2>/dev/null; then rm -f "${lst:?}"; PRESCAN_BAD="$(short "$r") (목록을 끝까지 읽지 못했습니다)"; return 1; fi
    while IFS= read -r -d '' p; do
      t="$(perl -MCwd=abs_path -e '$r = abs_path($ARGV[0]); (defined $r && -e $r) or exit 1; print $r' "$p" 2>/dev/null)" || continue   # 끊긴 바로가기 = 뒤에 자료 없음
      case "$t$p" in *$'\n'*) rm -f "${lst:?}"; PRESCAN_BAD="$(short "$p") (경로에 줄바꿈이 있습니다)"; return 1 ;; esac
      if [ -n "$proots" ] && under_any "$t" "$proots"; then
        rm -f "${lst:?}"; PRESCAN_BAD="$(short "$p") → $(short "$t") (지울 프로그램 자리를 가리킵니다)"; return 1
      fi
      # 바로가기 **자리**의 실경로 = 부모 실경로 + 이름(canon 은 폴더를 가리키는 바로가기를 따라가 버린다) — 남길 목록은 실경로다
      pc="$(canon "$(dirname "$p")" 2>/dev/null)" && pc="$pc/$(basename "$p")" || pc="$p"
      if [ -n "$keeps" ] && under_any "$pc" "$keeps" && under_any "$t" "$hc" && ! under_any "$t" "$keeps"; then
        # 예외 갈래(참가 자리가 ~/.cys 안)는 남길 것 밖을 **지운다** ⇒ 가리키던 자료가 사라진다 → 못 풂(반례 ① 처방 · 삭제 0)
        if [ -n "$nested" ]; then rm -f "${lst:?}"; PRESCAN_BAD="$(short "$p") → $(short "$t") (남길 자리 밖을 가리킵니다)"; return 1; fi
        PRESCAN_NOTE="${PRESCAN_NOTE}$(short "$p")
"
      fi
    done < "$lst"
  done <<< "$roots"
  rm -f "${lst:?}"
  return 0
}
# 끝 요약 한 줄 — 보관 폴더 자리와 크기(쉬운 말)
human_size() { # human_size <KB>
  local k="${1:-0}"
  if [ "$k" -ge 1048576 ]; then printf '약 %s.%sGB' "$((k/1048576))" "$(( (k%1048576)*10/1048576 ))"
  elif [ "$k" -ge 1024 ]; then printf '약 %sMB' "$(( (k+1023)/1024 ))"
  else printf '1MB 미만'; fi
}
archive_summary() {
  local d k
  for d in "$ARCHIVE_DEST" "$ARCHIVE_HOME"; do
    [ -n "$d" ] && [ -d "$d" ] || continue
    [ "$d" = "$ARCHIVE_HOME" ] && [ "$ARCHIVE_HOME" = "$ARCHIVE_DEST" ] && continue
    k="$(du -sk "$d" 2>/dev/null | awk '{print $1}')"
    say "    이전 자료는 $(short "$d") 폴더에 모두 보관해 두었습니다 ($(human_size "${k:-0}")). 필요 없으시면 나중에 그 폴더를 지우셔도 됩니다."
  done
}

# 우리가 홈에 **새로 넣은** 신뢰 키의 기록을 읽는다 — 설치기가 적어 둔 TSV(설정파일<탭>키).
#   ⚠파일이 없으면 빈 목록이다 ⇒ 홈 신뢰 칸에는 **손대지 않는다.** 모르는 것을 지우지 않는다.
#     (설치기가 그 키를 넣었다면 기록도 함께 남는다 — 기록이 없다는 것은 안 넣었다는 뜻이다.)
#   ★반드시 **자비스 폴더를 지우기 전에** 읽어야 한다. 그 폴더 안에 있는 파일이다.
TRUST_SEED_ROWS=""
TRUST_CLEANUP_FAIL=0
read_trust_seed_record() {
  local f="$JARVIS_HOME/trust-seed.tsv"
  TRUST_SEED_ROWS=""
  [ -f "$f" ] || return 0
  # ★기록이 있는데 못 읽은 것도 **정리 실패**다 — 그 기록이 든 폴더를 지우면 다시 해 볼 길이 사라진다.
  if ! TRUST_SEED_ROWS="$(cat "$f" 2>/dev/null)"; then
    TRUST_SEED_ROWS=""
    TRUST_CLEANUP_FAIL=$((TRUST_CLEANUP_FAIL+1))
    say "  [남음] 폴더 신뢰 기록을 읽지 못했습니다 — 홈 신뢰 칸은 손대지 않습니다."
  fi
}

# 폴더 신뢰 씨앗만 도로 뺀다 (2026-09-10 · 설치기가 홈에도 심기 시작했다)
strip_trust_seed() { # strip_trust_seed <파일> <자리>
  local f="$1" d="$2" left js=""
  if ! real_path "$f"; then
    KEPT_FAIL=$((KEPT_FAIL+1)); TRUST_CLEANUP_FAIL=$((TRUST_CLEANUP_FAIL+1))
    say "  🔴못 살핌: $(short "$f") 의 $(short "$d") 폴더 신뢰 칸 — 바로가기(링크)를 끝까지 풀지 못했습니다(고리 또는 너무 깊음 · 기록을 남깁니다)."
    return 0
  fi
  [ -f "$REAL" ] || return 0   # 없는 파일·끊긴 링크 = 칸 없음
  [ -s "$REAL" ] || return 0   # 빈 설정 파일 = 칸 없음(이종 검토 — 못 읽음으로 세면 폴더가 남고 재설치가 영영 막힌다)
  # 마침표 든 이름은 plutil 이 못 가리킨다 — 같은 규칙(값이 우리 것일 때만 · 키 하나만 · 빈 칸이면 칸째)을
  #   dir_key_json 으로 한다(0.3.36 F15). plutil 만 못 읽는 성한 설정(서로게이트 · 1e400)도 같은 길로 한 번 더 본다(이종 검토).
  case "$d" in *.*) js=1 ;; esac
  [ -z "$js" ] && ! plutil -convert json -o /dev/null "$f" >/dev/null 2>&1 && js=1
  case "$js" in
    #   🔴0.3.36(B-Z28): 설정을 **읽지 못한 것도 정리 실패**다 — 세지 않으면 게이트가 기록(trust-seed.tsv)이 든 폴더를
    #     지워 되돌릴 근거가 사라지고, 우리 칸은 남은 채 요약이 「완료」 로 읽힌다(잠시 깨진 설정 재현).
    1) if ! dir_key_json get "$f" "$d"; then
           KEPT_FAIL=$((KEPT_FAIL+1)); TRUST_CLEANUP_FAIL=$((TRUST_CLEANUP_FAIL+1))
           say "  🔴못 살핌: $(short "$f") 의 $(short "$d") 폴더 신뢰 칸 — 설정 파일을 읽지 못했습니다(기록을 남겨 다시 해 볼 수 있게 둡니다)."
           return 0
         fi
         case "$DIR_KEY_RESULT" in
           absent) return 0 ;;
           present=true|present=1|present=YES|present=yes) ;;
           *) say "  남김: $(short "$f") 의 $(short "$d") 폴더 신뢰 칸 (우리가 넣은 값과 달라 손대지 않습니다: ${DIR_KEY_RESULT#present=})"
              return 0 ;;
         esac
         if dir_key_json strip "$f" "$d" && [ "$DIR_KEY_RESULT" = "removed" ]; then
           REMOVED=$((REMOVED+1)); say "  지움: $(short "$f") 의 $(short "$d") 폴더 신뢰 칸 (나머지 칸은 그대로)"
         else
           KEPT_FAIL=$((KEPT_FAIL+1)); TRUST_CLEANUP_FAIL=$((TRUST_CLEANUP_FAIL+1))
           say "  🔴못 지움: $(short "$f") 의 $(short "$d") 폴더 신뢰 칸"
         fi
         return 0 ;;
  esac
  # 🔴**우리가 넣은 값과 같을 때만 지운다**(2차 N4 확정). 기록한 뒤 사람이 그 값을 손수 바꿨다면
  #   그것은 이제 그분의 선택이다 — 기록이 있다고 남의 결정을 되돌리지 않는다.
  local cur
  if ! cur="$(plutil -extract "projects.$d.hasTrustDialogAccepted" raw -o - "$f" 2>/dev/null)"; then
    # 칸이 없는 것(할 일 없음)과 파일을 못 읽은 것(정리 실패 · B-Z28)을 가른다 — 파일 전체를 읽어 보면 된다.
    plutil -convert json -o /dev/null "$f" >/dev/null 2>&1 && return 0
    KEPT_FAIL=$((KEPT_FAIL+1)); TRUST_CLEANUP_FAIL=$((TRUST_CLEANUP_FAIL+1))
    say "  🔴못 살핌: $(short "$f") 의 $(short "$d") 폴더 신뢰 칸 — 설정 파일을 읽지 못했습니다(기록을 남겨 다시 해 볼 수 있게 둡니다)."
    return 0
  fi
  case "$cur" in
    true|1|YES|yes) ;;
    *) say "  남김: $(short "$f") 의 $(short "$d") 폴더 신뢰 칸 (우리가 넣은 값과 달라 손대지 않습니다: $cur)"
       return 0 ;;
  esac
  if plutil -remove "projects.$d.hasTrustDialogAccepted" "$f" >/dev/null 2>&1; then
    REMOVED=$((REMOVED+1)); say "  지움: $(short "$f") 의 $(short "$d") 폴더 신뢰 칸 (나머지 칸은 그대로)"
  else
    KEPT_FAIL=$((KEPT_FAIL+1)); TRUST_CLEANUP_FAIL=$((TRUST_CLEANUP_FAIL+1))
    say "  🔴못 지움: $(short "$f") 의 $(short "$d") 폴더 신뢰 칸"
    return 0
  fi
  # 우리 칸 하나만 있던 자리면 이제 비었다 — 빈 칸을 남기면 다음 진단이 자국으로 센다.
  left="$(plutil -extract "projects.$d" json -o - "$f" 2>/dev/null | tr -d ' \n')"
  [ "$left" = "{}" ] && plutil -remove "projects.$d" "$f" >/dev/null 2>&1
  return 0
}

strip_hooks() { # 각성 훅만 뺀다. 사용자의 다른 훅은 건드리지 않는다.
  local sf="$1" tmp py
  hook_present "$sf" || return 0
  if ! py="$(pick_python)"; then
    KEPT_FAIL=$((KEPT_FAIL+1))
    say "  🔴못 지움: $(short "$sf") 의 각성 훅 (설정을 고칠 도구가 이 컴퓨터에 없습니다)"
    say "         그 훅은 이제 없는 자리를 가리킵니다. 그 파일에서 session-start·role-bootstrap 줄을 지워 주십시오."
    return 0
  fi
  tmp="$(mktemp -t jarvis-hook)" || return 0
  if "$py" - "$sf" > "$tmp" 2>/dev/null <<'PY'
import json,sys
p=sys.argv[1]
# ⚠인코딩을 안 적으면 그 기계의 로케일로 읽는다 — 남의 설정 파일은 UTF-8 이다.
#   같은 병이 윈도우판에서 실제로 났다(러너 실측 2026-09-08: 한글이 통째로 깨져 다시 쓰였다).
d=json.load(open(p,encoding="utf-8"))
h=d.get("hooks")
def ours(entry):
    s=json.dumps(entry)
    return "session-start.sh" in s or "role-bootstrap.sh" in s
if isinstance(h,dict):
    for ev in list(h.keys()):
        v=h[ev]
        if isinstance(v,list):
            kept=[e for e in v if not ours(e)]
            if kept: h[ev]=kept
            else: del h[ev]
    if not h: d.pop("hooks",None)
# 화면(stdout)도 로케일을 타므로 바이트로 직접 내보낸다.
sys.stdout.buffer.write(json.dumps(d,ensure_ascii=False,indent=2).encode("utf-8"))
PY
  then
    if cat "$tmp" > "$sf" 2>/dev/null; then REMOVED=$((REMOVED+1)); say "  지움: $(short "$sf") 의 각성 훅 (다른 설정은 그대로)"
    else KEPT_FAIL=$((KEPT_FAIL+1)); say "  🔴못 지움: $(short "$sf") 의 각성 훅"; fi
  else
    KEPT_FAIL=$((KEPT_FAIL+1)); say "  🔴못 지움: $(short "$sf") 의 각성 훅 (설정 파일을 읽지 못했습니다)"
  fi
  rm -f "$tmp"
}

# footprint: M-LOGIN
# ★공식 명령을 먼저 쓴다. 우리가 열쇠고리 항목과 파일을 직접 지우는 것보다 낫다 —
#   공식 문서가 「logout 은 저장된 자격을 전부 지운다(평문 파일 내용 포함)」고 적고 있고,
#   그 명령은 **두 운영체제에서 같은 뜻**이라 대칭이 저절로 맞는다. 손으로 지우는 것은 폴백이다.
# 🔴🔴**한 번만 도는 것은 「열쇠고리 직접 삭제」뿐이다**(2차 N1 확정 · 1차 BLOCK ① 의 범위 축소).
#   아래 660줄 규율은 「열쇠고리 항목을 없어질 때까지 반복해 지우지 않는다 — 그러면 이 사람의
#   다른 클로드 로그인까지 지운다」이다. 그런데 그 뒤에 붙인 **재시도 루프**가 purge 를 최대 네 번
#   부르면서 `security delete-generic-password` 를 매번 다시 불렀다 ⇒ ★규율이 약속한 바로 그
#   반복을 **루프가 밖에서 만들어 냈다.** 한 번에 하나씩, 최대 네 항목이 비가역으로 사라진다.
#   ★교훈: 「이 함수는 한 번만 부른다」를 **주석으로만** 적어 두면, 부르는 쪽을 고치는 사람이
#     그것을 모른다. 불변식은 그 함수 자신이 지켜야 한다.
# 🔴🔴그런데 **함수 전체를 막은 것은 너무 넓었다**(2차 N1). 잠긴 로그인 파일 삭제가 처음 실패했을 때
#   사람이 잠금을 풀고 Enter 를 눌러도 이 함수가 통째로 건너뛰어졌고, 나머지가 성공하면 **로그인
#   파일이 남은 채 전체 성공**으로 끝났다 — 거짓 성공이다.
#   ⇒ 되돌릴 수 없는 것만 한 번으로 막는다: **열쇠고리 직접 삭제**(항목이 여럿이라 부를 때마다 하나씩
#     사라진다). 공식 logout 과 파일 삭제는 몇 번을 해도 결과가 같으므로 **재시도할 수 있게** 둔다.
LOGIN_KEYCHAIN_DONE=0
purge_login_first() {
  [ "$PURGE_LOGIN" = "1" ] || { say "  남김: 로그인 (다음에 다시 하지 않으셔도 됩니다)"; return 0; }
  local claude_bin="$HOME/.local/bin/claude"
  [ -x "$claude_bin" ] || claude_bin="$(command -v claude 2>/dev/null)"
  if [ -n "$claude_bin" ] && "$claude_bin" auth logout >/dev/null 2>&1; then
    REMOVED=$((REMOVED+1)); say "  지움: 로그인 (공식 로그아웃)"
  else
    # 클로드가 이미 없거나 명령이 안 될 때 — 자리 둘을 직접 치운다
    local did=0
    # ★여기만 한 번이다 — 같은 이름의 항목이 여럿이고 이 명령은 한 번에 하나를 지운다.
    if [ "$LOGIN_KEYCHAIN_DONE" != "1" ]; then
      LOGIN_KEYCHAIN_DONE=1
      security delete-generic-password -s "$KEYCHAIN_SERVICE" >/dev/null 2>&1 && did=1
    fi
    [ -f "$CRED_FILE" ] && rm -f "$CRED_FILE" 2>/dev/null && did=1
    # 🔴교차 검토 [1] **부분** 채택(2026-09-08). 열쇠고리에는 같은 이름의 항목이 **여럿** 있을 수 있다 —
    #   클로드가 설정 폴더마다 따로 걸기 때문이다(공식 문서 · 이 개발기에 실측 8개).
    #   `security delete-generic-password` 는 그 가운데 **하나만** 지운다.
    #   ⛔「없어질 때까지 반복해 지운다」는 안 한다 — 그러면 **이 사람의 다른 클로드 로그인까지**
    #     지운다(우리가 깔지 않은 것도 포함). 지우는 범위를 넓히는 것은 사람이 정할 일이다.
    #   ✅우리가 할 수 있는 것은 **사실대로 말하는 것**이다. 조용히 지나가면 「로그인까지 지웠다」가 거짓이 된다.
    if security find-generic-password -s "$KEYCHAIN_SERVICE" >/dev/null 2>&1; then
      _kc="$(login_keychain_count)"
      say "  ⚠열쇠고리에 같은 이름의 로그인 항목이 더 남아 있습니다${_kc:+ (${_kc}개)} — 클로드가 설정 폴더마다 따로 겁니다."
      say "     우리가 아는 자리 하나만 지웠습니다. 나머지는 그 폴더를 쓰는 클로드에서 로그아웃해 주십시오."
    fi
    if [ "$did" = "1" ]; then REMOVED=$((REMOVED+1)); say "  지움: 로그인 (자리를 직접 치웠습니다)"
    else say "  로그인: 지울 것이 없었습니다."; fi
  fi
}

purge() {
  say ""
  say "=== 지웁니다 ==="

  # 🔴**자비스 폴더를 지우기 전에** 신뢰 씨앗 기록을 읽어 둔다(1차 REVISE ④). 그 기록은 그 폴더
  #   안에 있고 아래에서 그 폴더를 지운다 — 순서를 뒤집으면 「우리가 넣은 것」과 「참가자의 것」을
  #   영영 구별할 수 없다.
  # 0.3.37: 신뢰 칸 실패 깃발은 **이 회차가 다시 잰 값**이다 — 바로 아래 기록 읽기·칸 되돌리기가 이번 회차에 다시 돌며
  #   실패하면 다시 세운다(무조건 풀기가 아니다). 앞 판은 회차 사이에 안 풀어, 1회차에 잠깐 잠겼던 칸이 풀려도
  #   스스로 다시 해 보기 2·3회차가 늘 작업 폴더를 남기고 rc 7 로 끝났다.
  TRUST_CLEANUP_FAIL=0
  read_trust_seed_record

  # ★남겨야 할 자리의 실경로를 **먼저 한 번에** 푼다. 하나라도 못 풀면 이 실행은 아무것도 지우지 않는다.
  resolve_preserve_paths
  if [ "$PRESERVE_CANON_FAIL" -ne 0 ]; then
    say "  🔴남겨야 할 자리 ${PRESERVE_CANON_FAIL}곳의 실제 경로를 확인하지 못했습니다 — **이번에는 아무것도 지우지 않습니다.**"
    printf '%s' "$PRESERVE_CANON_BAD" | while IFS="$(printf '\t')" read -r bad why; do
      [ -n "$bad" ] || continue
      say "         확인 못한 자리: $(short "$bad")"
      [ -n "$why" ] && say "           까닭: $why"
    done
    say "         무엇을 남겨야 하는지 모르는 채로 지우면 참가 열쇠를 잃을 수 있습니다."
    say "         그 자리를 살펴보신 뒤(링크가 끊겼거나 권한이 없을 수 있습니다) 아래 「다시 하시는 법」대로 다시 실행해 주십시오."
  fi

  # 0.3.37(보관 이동 승인 조건 ⑴): 지난 재설치의 되옮기기가 도중에 끊겼으면 **그것부터** 이어서 끝낸다(자료는 보관 폴더에 온전하다).
  resume_unfinished_restore
  # r1 F4: 지난 실행에서 끝내지 못한 보관본 속 로그인 파일 지우기를 이어서 한다(어느 길이든 — 완전 삭제 보관본만 · 비밀값을 보관본에 두지 않는다)
  resume_archived_credentials

  # ★순서가 중요하다 — 등록을 떼는 명령이 **프로그램 안에** 들어 있다.
  #   프로그램을 먼저 지우면 등록을 뗄 수단이 사라져 죽은 등록이 남는다.
  # footprint: M-DAEMON
  if [ -n "$CYS_CLI" ]; then
    CYS_NO_AUTOSTART=1 "$CYS_CLI" daemon uninstall >/dev/null 2>&1 && say "  지움: cys 상시 가동 등록"
  fi
  launchctl bootout "gui/$(id -u)/com.cysjavis.cysd" >/dev/null 2>&1 || true
  drop_file "$HOME/Library/LaunchAgents/com.cysjavis.cysd.plist"
  # 🔴🔴`pkill -f 'cys\.app/Contents/MacOS/cysd'` 를 **뺐다**(2차 STILL OPEN ② 확정 2026-09-10).
  #   그것도 **명령줄**을 본다 — 편집기가 그 경로를 **파일 인자로 열기만 해도** 종료된다.
  #   1차 검토에서 다른 명령줄 축을 빼면서 이 한 줄을 놓쳤다. ★한 축을 지울 때는 **같은 성질의 축이
  #   또 있는지** 세어라. 아래 stop_cys_processes 가 자리 축 + 혈연으로 같은 일을 안전하게 한다.
  # ★이름이 아니라 **자리**로 한 번 더 훑는다(R1) — 데몬이 띄운 자식은 이름이 우리 것이 아니다.
  CYS_ALIVE="$(stop_cys_processes "$CYS_APP" ${CYS_APP_OLD:+"$CYS_APP_OLD"} "$HOME/.cys")"
  #   ★끈 뒤에도 돌고 있으면(완전 삭제 길 · 앱을 지우는 길) 이번에는 아무것도 옮기지 않는다(r1 F6 · 윈 $procBlocked 짝) —
  #   붙잡힌 폴더를 옮기다 반쪽이 되느니, 스스로 다시 해 보기가 그 사이 창을 닫을 틈을 준다. 재설치(앱 남김)는 알림만.
  PROC_BLOCKED=0
  if [ -n "$CYS_ALIVE" ] && [ "$KEEP_APP" != "1" ]; then
    PROC_BLOCKED=1; ARCHIVE_FAIL=1; KEPT_FAIL=$((KEPT_FAIL+1))
    say "  🔴남음: cys 프로그램 — 아직 실행 중이라 옮기거나 지울 수 없어 이번에는 아무것도 옮기지 않았습니다."
    write_alive_procs "$CYS_ALIVE"
    say "         cys 창을 모두 닫아 주십시오 — 닫힌 뒤 다시 해 보면 이어서 옮깁니다(자료는 원래 자리에 그대로 있습니다)."
  elif [ -n "$CYS_ALIVE" ]; then
    say "  [주의] cys 자리에서 아직 돌고 있는 것이 있습니다 — 폴더가 안 지워질 수 있습니다."
    write_alive_procs "$CYS_ALIVE"
  fi

  # ★로그인도 클로드를 지우기 **전에** 처리한다 — 로그아웃 명령이 클로드 안에 들어 있다.
  purge_login_first

  # ★훅을 프로그램보다 **먼저** 뗀다 — 훅을 고칠 파이썬이 그 프로그램 안에 들어 있다(pick_python).
  #   순서를 뒤집으면 깨끗한 맥에서 훅이 영영 안 지워진다(그 기계엔 다른 파이썬이 없다).
  # footprint: M-HOOK
  strip_hooks "$HOME/.claude/settings.json"

  # footprint: M-APP — 0.3.37: 자료를 보관 폴더로 다 옮긴 **뒤에** 지운다(아래 「보관 관문」 · DESIGN-0337 3-3절 순서)
  # 🔴cys 계정 자리를 지우기 **전에** 토론장 안내 파일을 밖으로 옮겨 둔다(검토 지적 채택 2026-09-09).
  #   까닭: `~/.cys/claude/skills/agora-delegate` 는 cys 설치의 일부라 cys 와 함께 사라지는 것이 맞다.
  #   그런데 그대로 두면 다시 깐 뒤 「아고라에 참가해」가 **안 먹는 공백**이 생긴다 — 참가 열쇠는
  #   남아 있는데 그걸 어떻게 쓰는지 적은 종이만 없어진 꼴이다.
  #   ⇒ 밖(`~/.claude/skills/`)에 같은 것이 **없을 때만** 옮겨 둔다(있으면 손대지 않는다 = 멱등).
  #   ⛔밖에 이미 있는 것을 덮어쓰지 않는다 — 사람이 손수 고쳐 둔 것일 수 있다.
  #   🔴🔴**옮겼다고 말하기 전에 바이트를 대조한다**(2차 검토 지적 채택). 앞 판은 `cp` 의 종료값만 봤다 —
  #   폴더만 만들어지고 알맹이가 반만 복사돼도 「옮겼습니다」라고 말한 뒤 원본을 지웠고,
  #   ★**다음 실행은 「대상이 이미 있다」며 이전을 건너뛰어 반쪽이 영구히 고착된다.**
  #   ⇒ 대조에 실패하면 **원본(`~/.cys`)을 지우지 않는다**(fail-closed). 사람 손 한 번이 유실보다 싸다.
  #   🔴🔴**「대상이 있다」로 이전을 마쳤다고 판정하지 않는다**(4차 지적 채택 2026-09-09).
  #   앞 판의 조건은 `[ ! -d "$AGORA_SKILL" ]` 였다. 그래서 지난 실행이 **반쪽 대상을 남긴 채**
  #   (치우기가 잠김·권한으로 실패해서) 끝났으면, **다음 실행은 그 반쪽을 「이미 있다」로 읽고
  #   이전 분기를 통째로 건너뛰어** `AGORA_MIGRATE_OK` 기본값 1 로 `.cys` 원본을 지웠다.
  #   ⇒ 반쪽이 영구히 고착되는 것을 막으려던 장치가, **재실행에서 스스로 그 고착을 완성**하고 있었다.
  #   ★판정 기준을 「있다」에서 **`tree_same` 통과**로 옮긴다 — 이전은 내용이 같을 때만 끝난 것이다.
  AGORA_MIGRATE_OK=1
  if [ -d "$AGORA_SKILL_IN_CYS" ]; then
    if [ -d "$AGORA_SKILL" ] && tree_same "$AGORA_SKILL_IN_CYS" "$AGORA_SKILL"; then
      # 이미 같은 것이 밖에 있다(멱등) — 덮지 않는다.
      say "  이미 있음: 토론장 안내가 $(short "$AGORA_SKILL") 에 그대로 있습니다(내용까지 대조했습니다)."
    elif [ -d "$AGORA_SKILL" ]; then
      # 있는데 내용이 다르다 = 지난 실행의 반쪽이거나, 사람이 손수 고쳐 둔 것이다.
      #   어느 쪽인지 우리는 모른다 ⇒ 덮지도 지우지도 않고 **원본을 남긴다**(fail-closed).
      AGORA_MIGRATE_OK=0
      KEPT_FAIL=$((KEPT_FAIL+1))
      say "  🔴$(short "$AGORA_SKILL") 에 있는 토론장 안내가 $(short "$AGORA_SKILL_IN_CYS") 와 달라"
      say "         $(short "$HOME/.cys") 를 **지우지 않았습니다.** 지웠다면 안 옮겨진 쪽이 사라졌을 것입니다."
      say "         지난번에 옮기다 만 것일 수도, 손수 고쳐 두신 것일 수도 있어 저희가 고르지 않습니다."
      say "         $(short "$AGORA_SKILL") 를 손으로 정리하신 뒤 아래 「다시 하시는 법」대로 다시 실행해 주십시오."
      say "         참가 열쇠·이름은 어느 경우에도 그대로 있습니다."
    elif mkdir -p "$(dirname "$AGORA_SKILL")" 2>/dev/null && cp -R "$AGORA_SKILL_IN_CYS" "$AGORA_SKILL" 2>/dev/null \
       && tree_same "$AGORA_SKILL_IN_CYS" "$AGORA_SKILL"; then
      say "  옮김: 토론장 안내를 $(short "$AGORA_SKILL") 로 옮겨 두었습니다(내용까지 같은지 확인했습니다)."
    else
      AGORA_MIGRATE_OK=0
      KEPT_FAIL=$((KEPT_FAIL+1))
      say "  🔴토론장 안내를 밖으로 옮기지 못했습니다 — 그래서 $(short "$HOME/.cys") 를 **지우지 않았습니다.**"
      say "         지웠다면 그 안내가 영영 사라졌을 것입니다. 참가 열쇠·이름은 그대로 있습니다."
      say "         $(short "$AGORA_SKILL_IN_CYS") 를 손으로 $(short "$AGORA_SKILL") 에 옮기신 뒤 아래 「다시 하시는 법」대로 다시 실행해 주십시오."
      # 반쪽만 생긴 대상은 치운다 — 치우기가 실패해도 이제는 안전하다(다음 실행이 위 「다르다」 갈래로 들어가
      #   원본을 남긴다). 앞 판은 이 치우기가 실패하면 다음 실행이 원본을 지웠다.
      if [ -d "$AGORA_SKILL" ] && ! tree_same "$AGORA_SKILL_IN_CYS" "$AGORA_SKILL"; then
        rm -rf "$AGORA_SKILL" 2>/dev/null \
          || say "         (옮기다 만 $(short "$AGORA_SKILL") 도 치우지 못했습니다 — 그 자리를 손으로 정리해 주십시오.)"
      fi
    fi
  fi

  # 🔴**신뢰 키 정리를 작업 폴더 삭제보다 앞에 둔다**(2차 N4 확정 2026-09-10).
  #   기록 파일은 그 폴더 안에 있다. 폴더를 먼저 지우면, 키 정리가 실패했을 때 **다시 해 볼 근거가
  #   사라진다** — 재시도는 「기록 없음」으로 읽고 그 키를 영영 건너뛴다.
  #   ★순서가 곧 안전장치다: 근거를 없애는 일은 그 근거를 다 쓴 뒤에 한다.
  # 🔴홈 폴더 칸은 **기록에 적힌 것만** 뺀다(1차 REVISE ④). 우리가 넣은 키만 기록돼 있다.
  #   ⛔경로를 추측해서 지우지 않는다 — 그 추측이 참가자의 값을 지우던 자리였다.
  # 🔴🔴**파이프로 돌리지 않는다**(3차 N4 확정 2026-09-10). `… | while` 의 몸통은 **하위 셸**이라
  #   그 안에서 올린 `KEPT_FAIL` 이 부모로 돌아오지 않는다 ⇒ 신뢰 칸 정리가 실패해도 부모는 그것을
  #   **모른 채** 바로 다음 줄에서 기록 파일이 든 작업 폴더를 지웠다. 실패의 근거가 사라진 것이다.
  #   ★셸에서 「센 것을 잃는 자리」는 언제나 파이프다 — 세는 루프는 파이프 밖에 둔다.
  if [ -z "$TRUST_SEED_ROWS" ]; then
    say "  남김: 홈 폴더 신뢰 칸 (우리가 넣은 기록이 없어 손대지 않습니다)"
  else
    while IFS="$(printf '\t')" read -r _cfg _key; do
      [ -n "$_cfg" ] && [ -n "$_key" ] && strip_trust_seed "$_cfg" "$_key"
    done <<EOF_TRUST_ROWS
$TRUST_SEED_ROWS
EOF_TRUST_ROWS
  fi

  # footprint: M-JARVISHOME
  # 🔴🔴**신뢰 칸 정리에 실패했으면 이 폴더를 남긴다**(3차 N4 확정 2026-09-10). 기록 파일이 이 안에
  #   있다 — 지우면 **다시 해 볼 근거가 사라지고**, 다음 실행은 「기록 없음」으로 읽어 그 칸을
  #   영영 건너뛴다(참가자 컴퓨터에 우리 자국이 남는다).
  #   ★순서를 앞당긴 것만으로는 부족했다: 실패해도 그냥 이어서 지우고 있었다.
  if [ "${TRUST_CLEANUP_FAIL:-0}" -gt 0 ]; then
    KEPT_FAIL=$((KEPT_FAIL+1))
    say "  🔴못 지움: $(short "$JARVIS_HOME") — 폴더 신뢰 칸을 다 되돌리지 못해 **일부러 남겼습니다.**"
    say "         이 폴더 안의 기록(trust-seed.tsv)이 있어야 다시 해 볼 수 있습니다."
    say "         그 칸을 쓰고 있는 프로그램(클로드 창 등)을 닫으신 뒤 아래 「다시 하시는 법」대로 다시 실행해 주십시오."
  elif [ "${PROC_BLOCKED:-0}" = "1" ]; then
    say "  [남김] $(short "$JARVIS_HOME") — cys 가 아직 돌고 있어 이번에는 옮기지 않았습니다(다음에 그대로 옮깁니다)."
  elif safe_jarvis_dir "$JARVIS_HOME"; then
    keep_jarvis_dir "$JARVIS_HOME"   # 0.3.36: 지우지 않고 보관 이동(위 keep_jarvis_dir)
  elif [ -e "$JARVIS_HOME" ]; then
    KEPT_FAIL=$((KEPT_FAIL+1))
    say "  🔴못 지움: $(short "$JARVIS_HOME") — 안전 확인을 통과하지 못해 지우지 않았습니다."
    say "         까닭: $SAFE_WHY"
    say "         그 자리는 손으로 확인해 주십시오. 확실하지 않은 자리를 재귀로 지우지 않습니다."
  fi
  # footprint: M-CYSHOME   (M-CYSPROFILE 은 이 안에 들어 있다)
  # 0.3.37(DESIGN-0337 3절 · 4절): 지우지 않고 보관 폴더로 옮긴다 — 완전 삭제 = 통째로 · 재설치 = 통째로 옮긴 뒤 남길 것만 되옮긴다(R2).
  #   ★작업 폴더 보관(위 keep_jarvis_dir)이 먼저다 — 그 보관 폴더에 모은다(archive_root_set). 신뢰 칸 기록은 이미 위에서 다 썼다.
  #   참가 자리가 ~/.cys 안이면(사람이 AGORA_HOME 을 옮겨 둔 드문 경우) 통째로 옮길 수 없다 — 재설치는 0.3.36 장치(남기고 지우기)로,
  #   완전 삭제는 옮기지 않고 그대로 둔다(archive_move 가 「남김」 으로 말한다 · 옮겼다 되돌리기 금지).
  if [ "${PROC_BLOCKED:-0}" = "1" ]; then
    :   # r1 F6 — cys 가 아직 돌고 있다: ~/.cys 는 이번에 옮기지 않는다(윈 짝)
  elif [ "$AGORA_MIGRATE_OK" = "1" ]; then
    CYS_NESTED=""
    if [ -d "$HOME/.cys" ] && [ ! -L "$HOME/.cys" ]; then CYS_NESTED="$(preserved_under "$(canon "$HOME/.cys" 2>/dev/null)")"; fi
    if [ "$KEEP_HISTORY" = "1" ] && [ -n "$CYS_NESTED" ]; then
      if ! history_keeps; then
        KEPT_FAIL=$((KEPT_FAIL+1))
        say "  🔴못 지움: $(short "$HOME/.cys") — 남겨야 할 이전 대화 자리를 확인하지 못해 **아무것도 지우지 않았습니다.**"
        printf '%s' "$HIST_KEEP_BAD" | while IFS= read -r bad; do [ -n "$bad" ] && say "         확인 못한 자리: $(short "$bad")"; done
        say "         확인할 수 없는 채로 지우면 이전 대화를 잃을 수 있습니다(바로가기가 끊겼거나 권한이 없을 수 있습니다)."
      elif ! dept_keeps; then
        KEPT_FAIL=$((KEPT_FAIL+1))
        say "  🔴못 지움: $(short "$HOME/.cys") — 남겨야 할 부서 기록의 목록을 읽지 못해 **아무것도 지우지 않았습니다.**"
      else
        drop_dir "$HOME/.cys" "$HIST_KEEPS$DEPT_KEEPS"
      fi
    elif [ "$KEEP_HISTORY" = "1" ]; then
      [ -e "$HOME/.cys" ] || [ -L "$HOME/.cys" ] && cys_home_reinstall
    else
      # 0.3.37(설계 결정 3): 보관한 옛 ~/.cys 자리를 회차 사이에 기억해 두고 **회차마다** 그 안 로그인 파일을 지운다 —
      #   앞 판은 이번 회차에 옮긴 때만 지워, 1회차 지우기가 실패하면 다시 해 보기가 그 파일을 안 보고 rc 0 으로 끝났다(비밀값이 보관 폴더에 남음).
      ARCHIVE_LAST=""
      if archive_move "$HOME/.cys" "cys-home" "cys 계정 자리(대화·부서 기록)"; then
        [ -n "$ARCHIVE_LAST" ] && CYS_HOME_ARCHIVED="$ARCHIVE_LAST"
        [ -n "$CYS_HOME_ARCHIVED" ] && drop_archived_credentials "$CYS_HOME_ARCHIVED"
      fi
    fi
  fi
  # footprint: M-CYSSTATE
  # footprint: M-DEPTSTATE
  # footprint: M-TRASH
  #   재설치(--keep-app · --keep-history 어느 쪽이든 · 윈 짝) = 편성 기록만 보관(본부 좌석이 설치기보다 먼저 뜨지 않게 · 나머지와 부서 상태는 제자리 — 부서가 그대로 되살아난다)
  #   완전 삭제 = 본부 상태 · 부서 상태 · 휴지통을 모두 보관(자국 표 M-DEPTSTATE·M-TRASH = 0.3.37 전에는 아무도 안 치웠다)
  if [ "${PROC_BLOCKED:-0}" = "1" ]; then
    :   # r1 F6 — cys 가 아직 돌고 있다: 상태 · 부서 상태 · 휴지통 · 앱 화면 자료도 이번에 옮기지 않는다(윈 짝)
  elif [ "$KEEP_HISTORY" = "1" ] || [ "$KEEP_APP" = "1" ]; then
    state_formation_archive
  else
    archive_move "$HOME/.local/state/cys" "cys-state" "cys 실행 상태"
    for _ds in "$HOME/.local/state"/cys-dept-*; do
      [ -e "$_ds" ] || [ -L "$_ds" ] || continue
      archive_move "$_ds" "cys-dept-state/$(basename "$_ds")" "부서 실행 상태"
    done
    archive_move "$HOME/.local/state/cys-trash" "cys-trash" "닫은 부서 휴지통"
    # footprint: M-WEBVIEW
    # 앱 화면(웹뷰) 자료 — 윈 W-WEBVIEW 와 같은 뜻(자리 = cys 1.1.7 가지 src/factory_reset.rs 「macOS GUI 층」).
    #   완전 삭제에서만 보관 폴더로 옮긴다(재설치·--keep-app = 무접촉 · 앱이 쓰는 자리). DARWIN_USER_CACHE_DIR 쪽 캐시는 OS 임시 자리라 손대지 않는다(DESIGN-0337 10절).
    if [ "$KEEP_APP" != "1" ]; then
      archive_move "$HOME/Library/WebKit/com.cysjavis.terminal" "webview-webkit" "앱 화면 자료"
      archive_move "$HOME/Library/Caches/com.cysjavis.terminal" "webview-caches" "앱 화면 자료"
      archive_move "$HOME/Library/Preferences/com.cysjavis.terminal.plist" "webview-prefs/com.cysjavis.terminal.plist" "앱 화면 자료"
    fi
  fi

  # ── 보관 관문(0.3.37 · 보관 이동 승인 조건 ⑴⑵⑶) — 옮기기·대조가 하나라도 어긋났으면 이 뒤(프로그램 지우기·설정 칸 빼기)를 하지 않는다 ──
  #   ⚠이미 끝난 것: 데몬 등록 떼기 · 프로세스 끄기 · 훅 떼기(설치 도우미가 다시 한다). 사람 자료는 어느 쪽이든 한 곳(원자리 또는 보관 폴더)에 온전하다.
  if [ "$ARCHIVE_FAIL" != "0" ]; then
    [ "$KEPT_FAIL" -eq 0 ] && KEPT_FAIL=1
    say "  🔴보관을 끝까지 마치지 못해 프로그램과 설정 칸은 지우지 않고 그대로 두었습니다."
    say "         이전 자료는 원래 자리나 보관 폴더 한쪽에 그대로 있습니다 — 사라진 것은 없습니다."
  else
    if [ "$KEEP_APP" = "1" ]; then
      say "  [남김] cys 프로그램 · $CYS_APP (다시 깔 때 판을 확인해 그대로 쓰거나 바꿉니다)"
      [ -n "$CYS_APP_OLD" ] && say "  [남김] cys 프로그램(옛 이름) · $CYS_APP_OLD (다시 깔 때 새 이름으로 바꿔 넣으며 한 벌 보관합니다)"
    else
      drop_dir "$CYS_APP"
      [ -n "$CYS_APP_OLD" ] && drop_dir "$CYS_APP_OLD"
    fi
    # footprint: M-CLAUDEBIN
    drop_file "$HOME/.local/bin/claude"
    # footprint: M-CLAUDESHARE
    drop_dir "$HOME/.local/share/claude"
    # footprint: M-SCRIPTCOPY
    drop_file "$HOME/install-jarvis.sh"
    # 남의 파일 속 우리 줄 — 파일을 지우지 않는다
    # footprint: M-PROFILE
    strip_profile_marker
    #   🔴표에 적힌 칸을 **전건** 빼야 한다. 실기에서 두 칸을 빠뜨렸더니(2026-09-08 게스트 실측)
    #   다 지운 뒤에도 진단기가 자국 1 개를 계속 찾아내 **「중간에 멈춘 상태」로 오보**했다.
    #   ⇒ 「거의 다 지웠다」는 이 도구에서 곧 **거짓 상태 보고**가 된다.
    # footprint: M-CLAUDEJSON
    strip_json_key "$HOME/.claude.json" 'hasCompletedOnboarding'
    # 큰 화면 권유 질문을 미리 넘기려고 설치기가 99 로 적어 둔 칸. 우리 자국이니 우리가 뺀다.
    #   ⚠오래 전부터 심고 있었는데 표에 없어서 아무도 안 지웠다(2026-09-10 자국 표를 채우다 드러났다).
    strip_json_key "$HOME/.claude.json" 'fullscreenUpsellSeenCount'
    strip_json_key "$HOME/.claude.json" 'projects.'"$JARVIS_HOME"
    # footprint: M-CLAUDESETTINGS
    strip_json_key "$HOME/.claude/settings.json" 'theme'
    strip_json_key "$HOME/.claude/settings.json" 'skipDangerousModePermissionPrompt'
    strip_json_key "$HOME/.claude/settings.json" 'remoteControlAtStartup'
  fi

  # 🔴**요청한 로그인 자국이 정말 사라졌는지 끝에서 다시 본다**(2차 N1 확정). 앞 판은 「지웠다」를
  #   그 순간의 종료값으로만 말했다 ⇒ 파일이 잠겨 남았는데 전체는 성공으로 끝났다.
  #   ★「지웠다」는 **다시 봐서 없을 때만** 참이다.
  # 🔴🔴**재진단은 파일 하나가 아니라 `login_present` 전체로 한다**(3차 N1 확정 2026-09-10).
  #   앞 판은 **로그인 파일만** 다시 봤다. 그런데 맥의 로그인은 열쇠고리에도 있고, 같은 이름의 항목이
  #   **여럿** 있을 수 있다(클로드가 설정 폴더마다 따로 건다) ⇒ 열쇠고리에 남았는데도 화면은
  #   「못 지운 것은 없습니다」로 끝났다. **거짓 성공이다.**
  #   ★「지웠다」는 **다시 봐서 없을 때만** 참이다 — 그 「없다」의 범위가 처음 세던 범위와 같아야 한다.
  #   ⛔남은 항목을 **자동으로 더 지우지는 않는다**(2차 N1 규율 유지) — 그러면 우리가 깔지 않은
  #     이 사람의 다른 클로드 로그인까지 사라진다. 우리가 할 일은 **사실대로 말하는 것**이다.
  # ★재진단은 **세 상태**로 받는다(4차 N1). 「모른다」를 「없다」로 적으면 그 순간 거짓 성공이다.
  _ls="$(login_state)"
  if [ "$PURGE_LOGIN" = "1" ] && [ "$_ls" = "unknown" ]; then
    KEPT_FAIL=$((KEPT_FAIL+1))
    say "  🔴확인 못함: 로그인이 지워졌는지 **확인하지 못했습니다**(열쇠고리가 잠겼거나 조회가 막혔습니다)."
    say "         지웠다고 말하지 않겠습니다 — 열쇠고리를 열어 주신 뒤 아래 「다시 하시는 법」대로 다시 해 주십시오."
  elif [ "$PURGE_LOGIN" = "1" ] && [ "$_ls" = "present" ]; then
    KEPT_FAIL=$((KEPT_FAIL+1))
    say "  🔴못 지움: 로그인 자국이 아직 남아 있습니다 — $(login_where)"
    _kc="$(login_keychain_count)"
    if [ -n "$_kc" ] && [ "$_kc" -gt 0 ]; then
      say "         열쇠고리에 같은 이름의 항목이 ${_kc}개 남아 있습니다(클로드가 설정 폴더마다 따로 겁니다)."
      say "         그 폴더를 쓰는 클로드에서 로그아웃해 주십시오 — 우리는 우리가 아는 자리 하나만 지웁니다."
    fi
    [ -f "$CRED_FILE" ] && say "         로그인 파일을 쓰고 있는 프로그램(클로드 창 등)을 닫으신 뒤 아래 「다시 하시는 법」대로 다시 해 주십시오."
  fi
  # 0.3.37 반례 ①(DESIGN-0337 6-1절): 되옮긴 자리 안 바로가기가 보관 폴더로 간 자리를 가리키면 한 줄 알린다(자료는 보관 폴더에 있다)
  if [ -n "$PRESCAN_NOTE" ]; then
    say "  [안내] 아래 바로가기가 가리키던 자료는 보관 폴더(cys-home)에 그대로 있습니다 — 새 자리에서는 그 자료가 보이지 않을 수 있습니다."
    printf '%s' "$PRESCAN_NOTE" | head -5 | while IFS= read -r l; do [ -n "$l" ] && say "           $l"; done
  fi
  # (로그인은 클로드를 지우기 전에 이미 처리했다 — purge_login_first 참조)
  # footprint: M-CLAUDEUSER  — 손대지 않는다
  say "  남김: 클로드 대화·기록"

  say ""
  # 보존한 것이 있으면 반드시 말한다 — 「지웠는데 왜 남아 있지」를 미리 답한다.
  [ "$PRESERVED" -gt 0 ] && say "    (참가 자리와 겹쳐 그대로 둔 자리 $PRESERVED 곳이 있습니다 — 위 「보존(중첩)」 줄)"
  if [ "$KEPT_FAIL" -eq 0 ]; then
    say "=== 끝났습니다 — $REMOVED 가지를 지웠고, 못 지운 것은 없습니다. ==="
    # 0.3.36 안내 1줄(보관 자리)은 0.3.37 부터 archive_summary 가 크기와 함께 말한다 — 작업 폴더를 못 옮긴 갈래의 안내만 따로 남긴다
    [ -n "$BACKUP_NOTE" ] && [ -z "$ARCHIVE_DEST" ] && say "    $BACKUP_NOTE"
    archive_summary                                  # 0.3.37: 보관 폴더 자리·크기 1줄
    return 0
  fi
  # 🔴사실만 말한다. 「거의 다 됐다」로 얼버무리면 다음 단계가 그 위에 얹힌다.
  say "=== 끝났습니다 — $REMOVED 가지를 지웠고, $KEPT_FAIL 가지를 못 지웠습니다. ==="
  say "    위에 🔴로 표시된 자리가 남아 있습니다. 그대로 두고 다시 설치하면 뒤엉킵니다."
  say "    아래 「다시 하시는 법」대로 한 번 더 해 보시고, 그래도 남으면 이 화면을 사진으로 남겨 알려 주십시오."
  [ -n "$BACKUP_NOTE" ] && { [ -z "$ARCHIVE_DEST" ] || [ "$ARCHIVE_FAIL" != "0" ]; } && say "    $BACKUP_NOTE"
  archive_summary
  return 7
}

# ── 본문 ──────────────────────────────────────────────────────────
diagnose
[ "$MODE" = "list" ] && exit 0

if [ "$FOUND" -eq 0 ]; then
  say ""
  say "지울 것이 없습니다."
  exit 0
fi

# ── 🔴「cys 를 먼저 닫아 주십시오」 (v0.3.10 · 실제 노트북에서 겪은 일 2026-09-10) ─────────────
#   이 도구는 자리 기준으로 프로세스를 끈다. 그래도 **사람에게 먼저 말한다**:
#   ⑴우리가 창을 끄면 사람은 「갑자기 꺼졌다」로 읽는다 ⑵쓰던 것을 저장할 틈을 드린다
#   ⑶끄지 못한 프로세스가 폴더를 붙잡고 있으면 삭제가 그 자리에서 실패한다(실제로 그랬다).
#   ⚠묻는 것이 아니라 **알리는 것**이다 — 답을 안 받아도 진행한다(사람이 없는 자리에서는 안 묻는다).
notice_close_cys() {
  local alive
  alive="$(procs_under "$CYS_APP" ${CYS_APP_OLD:+"$CYS_APP_OLD"} "$HOME/.cys" 2>/dev/null | sort -u | wc -l | tr -d ' ')"
  [ "${alive:-0}" -gt 0 ] || return 0
  say ""
  say "cys 를 곧 끕니다. 저장하지 않으신 것이 있으면 지금 저장해 주세요."
  # 0.3.37: 묻지 않는다(사람 손 0 · 알림 뒤 5초) — 알리고 잠깐 기다린 뒤 이 도구가 끈다. 재설치 한 줄(--yes)은 기다리지 않는다.
  [ "$ASSUME_YES" = "1" ] || sleep "${JARVIS_NOTICE_WAIT:-5}"
  return 0
}
# ── 0.3.37 사전 훑기(읽기만 · 첫 변경 전 · DESIGN-0337 6-1절 ②③④) — 막히면 아무것도 바꾸지 않고 멈춘다 ──
if ! prescan_links; then
  say ""
  say "🔴이번에는 아무것도 바꾸지 않았습니다."
  say "   옮겨 둘 자료 가운데 확인할 수 없는 자리가 있습니다: $PRESCAN_BAD"
  say "   그대로 지우면 그 자료가 사라질 수 있어 멈췄습니다. 그 바로가기나 폴더를 살펴보신 뒤 아래 「다시 하시는 법」대로 다시 실행해 주십시오."
  show_rerun_how
  exit 7
fi

say ""
say "위 목록의 자료는 지우지 않고 보관 폴더로 옮깁니다(다시 받을 수 있는 프로그램 파일만 지웁니다). 보관 자리는 끝에 알려 드립니다."
notice_close_cys
# 0.3.37: 「지웁니다」 입력을 묻지 않는다(사람 손 0 · 은행 책임 원칙) — 사람 자료는 보관 폴더로 옮기므로 되돌릴 수 있다.
#   --yes 는 받아서 넘긴다(옛 재설치 입구 호환 · 알림 대기만 건너뛴다).

# ★그 자리에서 다시 해 본다 — 창을 닫고 명령을 다시 찾는 것보다 Enter 한 번이 싸다(2026-09-10).
#   막힌 까닭 대부분은 **사람이 지금 이 창 앞에서 없앨 수 있는 것**이다. 그때마다 사이트를
#   다시 찾게 하지 않는다. ⚠상한 3회 — 무한 고리는 「막혔다」를 영영 말하지 않는 것과 같다.
#   3회 뒤에는 사실대로 끝내고 **명령 전체를 인쇄**한다(재부팅이 필요한 자리는 재실행으로 안 풀린다).
purge
rc=$?
tries=0
# 0.3.37: 묻지 않고 스스로 다시 해 본다 — 최대 2회 · 사이 5초(보관 이동 승인 조건 ⑵ · 잠깐 붙들린 파일이 풀릴 틈). 상한은 그대로 둔다.
while [ "$rc" -ne 0 ] && [ "$tries" -lt 2 ]; do
  tries=$((tries+1))
  say ""
  say "  남은 자리가 있어 ${JARVIS_RETRY_WAIT:-5}초 뒤 스스로 한 번 더 해 봅니다 (${tries}/2 · 창을 닫지 말고 기다려 주세요)."
  sleep "${JARVIS_RETRY_WAIT:-5}"
  REMOVED=0; KEPT_FAIL=0; PRESERVED=0; ARCHIVE_FAIL="$ARCHIVE_VERIFY_FAIL"; ARCHIVED=0   # 대조 실패는 끝까지 남긴다(윈 짝 적대 발견 · 다시 해 보기가 관문을 열던 구멍)   # 보관 폴더(ARCHIVE_DEST·HOME)는 이어 쓴다 — 끝 요약이 첫 번째 것도 말하게
  prescan_links || break
  purge
  rc=$?
done
[ "$rc" -ne 0 ] && show_rerun_how
exit "$rc"
