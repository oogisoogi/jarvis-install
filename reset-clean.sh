#!/bin/bash
# 깨끗이 지우기 (맥) — 설치 도우미가 놓은 것을 도로 걷어 낸다
#
# 무엇을 하는가
#   이 컴퓨터의 상태를 먼저 살펴 목록으로 보여 주고, 확인을 받은 뒤 지운다.
#   지우는 것은 `footprint.md` 에 적힌 것뿐이다. 사진·문서 같은 사용자 파일은 손대지 않는다.
#
# 쓰는 법
#   bash reset-clean.sh            지울 목록을 보여 주고 한 번 물은 뒤 지운다
#   bash reset-clean.sh --list     살펴보기만 한다 (아무것도 안 지운다)
#   bash reset-clean.sh --dry-run  지울 목록만 보여 준다 (--list 와 같다)
#   bash reset-clean.sh --yes      묻지 않는다 (재설치 한 줄이 안에서 쓴다)
#   bash reset-clean.sh --purge-login   로그인까지 지운다 (기본은 로그인을 남긴다)
#
# 되돌릴 수 없다.
#
# ★로그인은 기본으로 남긴다. 재설치 뒤 로그인 손 한 번을 아끼기 위해서다.
#   그리고 맥에서는 로그인이 파일이 아니라 **열쇠고리**에 있어서(2026-09-08 실측),
#   `~/.claude` 를 지우는 것만으로는 어차피 안 지워진다. 지우려면 열쇠고리를 건드려야 하고,
#   그것은 `--purge-login` 을 일부러 붙였을 때만 한다.
set -u

MODE="run"; ASSUME_YES=0; PURGE_LOGIN=0
for a in "$@"; do
  case "$a" in
    --list|--dry-run) MODE="list" ;;
    --yes|-y)         ASSUME_YES=1 ;;
    --purge-login)    PURGE_LOGIN=1 ;;
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
CYS_APP="/Applications/cys.app"
CYS_CLI=""
for c in "$CYS_APP/Contents/MacOS/cys" "$HOME/.local/bin/cys" "/usr/local/bin/cys"; do
  [ -x "$c" ] && { CYS_CLI="$c"; break; }
done
PROFILE_MARKER="# added by jarvis installer (claude PATH)"
KEYCHAIN_SERVICE="Claude Code-credentials"

say()  { printf '%s\n' "$*"; }
# 🔴사람에게 하는 말 가운데 **값을 돌려주는 함수 안에서 하는 말**은 이쪽으로 보낸다(3R BLOCK ② 봉인).
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
# 🔴🔴**명령줄 축(`pgrep -f`)을 뺐다**(1R BLOCK ② 봉인 2026-09-10). 두 가지가 틀렸다:
#   ⑴`pgrep -f` 는 **명령줄**을 본다 ⇒ 편집기를 `~/.cys/…` 파일 인자와 함께 열어 둔 것만으로
#     그 편집기가 TERM·KILL 을 받는다. 저장 안 한 남의 작업이 사라진다.
#   ⑵넘긴 경로를 **정규식으로 읽는다** ⇒ `~/.cys/` 의 `.` 이 임의 문자라 `~/acys/…` 처럼
#     **전혀 다른 자리**도 걸린다. 경로를 이스케이프하지 않은 것은 그냥 결함이다.
#   ⇒ 「더 많이 잡는 축」이 아니라 **「엉뚱한 것을 잡는 축」**이었다. 윈도우는 실행 파일 경로만
#     보는데 맥만 명령줄을 봐서 **OS 대칭도 깨져 있었다.** 축을 하나로 줄여 둘을 맞춘다.
#   ⚠줄어든 만큼은 정직하게 적는다: 밖의 해석기가 그 자리 안의 파일을 도는 경우(시스템 파이썬이
#     `~/.cys/…/x.py` 를 도는 경우)는 이제 안 잡는다. 그때는 삭제가 실패하고 **그 사유를 R2 가
#     인쇄한다** — 틀린 것을 죽이는 것보다 못 지웠다고 말하는 편이 낫다.
# ★비교는 **실경로끼리** 한다(2R N5 봉인 2026-09-10). 링크로 적어 둔 별칭에서는 글자 비교가
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
          # 🔴🔴**확인표를 못 뜬 번호는 표에 넣지 않는다**(4R BLOCK ② 봉인 2026-09-10).
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
# 🔴🔴**번호는 이름이 아니다 — 확인표를 함께 들고 다닌다**(3R BLOCK ② 봉인 2026-09-10).
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
# 🔴🔴**검증된 부모의 자손도 함께 끈다**(2R N5 · 3R 보강). 밖의 해석기(시스템 파이썬 등)가 cys 안의
#   helper 를 돌면 그 실행 파일은 `/usr/bin/python3` 라 자리 축에 안 잡힌다. 그런데 맥은 **도는 파일도
#   unlink 된다** — 삭제가 성공하고 helper 는 지워진 코드로 계속 돈다(조용한 잔존).
#   ⇒ 명령줄을 보고 잡는 대신 **혈연**으로 잡는다: 자리 축으로 확인된 pid 의 자손을 훑는다.
#   ★표를 **먼저 한 번 찍어 고정**한다 — 부모를 끈 뒤에 훑으면 그 자손은 이미 고아가 돼 관계가 끊긴다.
proc_descendants() {  # proc_descendants <조상 pid…> → 자손 pid(조상 포함)
  local table out prev pid ppid line
  table="$(ps -Ao pid=,ppid= 2>/dev/null | sed 's/^[[:space:]]*//')"
  out=" $* "
  prev=""
  # 🔴🔴**임시 파일을 아예 쓰지 않는다**(4R REGRESSED N5 봉인 2026-09-10).
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
    # 🔴★번호 비교는 **구분자까지 맞춘다**(3R N5 봉인). 앞 판은 표 전체를 통짜 문자열로 보고
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
    # 🔴**빈 확인표는 신호 대상이 아니다**(4R BLOCK ② 봉인). 여기서 「비었으면 그냥 끈다」로 두면
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
#     TERM 을 무시하고 살아남아도 「없다」로 끝난다(3R N5 지적).
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
# 🔴🔴**사람에게 할 말은 표준오류로 보낸다**(3R BLOCK ② 봉인 2026-09-10).
#   앞 판은 `say`(표준출력)로 「끄는 중: …」을 찍었는데, 부르는 쪽이 `CYS_ALIVE="$(stop_cys_processes …)"`
#   로 **표준출력을 통째로 삼켰다.** 결과가 둘 다 나빴다:
#     ⑴사람은 무엇을 끄는지 **끝까지 못 봤다** — 되돌릴 수 없는 일을 말없이 했다.
#     ⑵그 안내문이 「아직 살아 있는 것 표」로 파싱돼 **엉뚱한 경고**가 됐다.
#   ★한 함수가 사람에게 말하면서 값을 돌려주려면 **채널이 둘이어야 한다.** 값 = 표준출력, 말 = 표준오류.
stop_cys_processes() {
  local targets
  # ★①자리 축으로 **부모를 확인**하고 ②그 자손을 **먼저 모아 고정**한 뒤 ③함께 끈다.
  #   ⛔`pkill -f` 는 쓰지 않는다 — 편집기가 그 경로를 파일 인자로 열기만 해도 죽는다(2R STILL OPEN ②).
  targets="$(procs_under "$@" | sort -u)"
  targets="$(add_descendants "$targets")"
  # 🔴**끄기 전에 무엇을 끄는지 인쇄한다**(1R BLOCK ② · 3R 채널 분리). 강제 종료는 되돌릴 수 없다 —
  #   우리가 무엇을 골랐는지 사람이 볼 수 없으면, 잘못 골랐을 때 아무도 그것을 모른다.
  if [ -n "$targets" ]; then
    tell "  cys 자리에서 도는 것을 멈춥니다:"
    printf '%s\n' "$targets" | while IFS="$(printf '\t')" read -r pid tok cmd; do
      [ -n "$pid" ] && tell "    끄는 중: $cmd  (번호 $pid)"
    done
  fi
  kill_verified TERM "$targets"
  sleep 2
  # ★끄기 직전에 자손을 **한 번 더** 모은다(3R N5 봉인) — 표를 찍은 뒤 새로 생긴 자손은 목록에 없다.
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
#   아래에서 「cys 계정 자리」로 **통째로 지워진다** — 거기 든 로그인도 같이 사라진다.
#   지우는 것을 바꾸지는 않는다(그것은 사람이 결정할 일이다). 다만 **말은 해 준다.**
CYS_CRED_FILE="$HOME/.cys/claude/.credentials.json"
# 🔴🔴**「없다」와 「못 물어봤다」를 가른다**(4R BLOCK N1 봉인 2026-09-10).
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
#     사람이 알 수 있어야 한다(3R N1 지적 — 남은 것을 안 세면 거짓 성공이 된다).
#   🔴🔴**파이프가 조회 실패를 삼키던 자리다**(4R N1 봉인). 앞 판은 `dump-keychain | grep -c` 였다 —
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
  [ -d "$CYS_APP" ]; row $? 'cys 프로그램' "$CYS_APP"
  # footprint: M-DAEMON
  [ -f "$HOME/Library/LaunchAgents/com.cysjavis.cysd.plist" ]; row $? 'cys 상시 가동 등록' "$HOME/Library/LaunchAgents/com.cysjavis.cysd.plist"
  # footprint: M-CYSHOME
  [ -d "$HOME/.cys" ]; row $? 'cys 계정 자리' "$HOME/.cys"
  # footprint: M-CYSSTATE
  [ -d "$HOME/.local/state/cys" ]; row $? 'cys 실행 상태' "$HOME/.local/state/cys"
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
    say "         ⚠이것은 위의 「cys 계정 자리」 안에 들어 있어 함께 지워집니다."
    say "         자비스 창에서 하신 로그인은 다시 하셔야 합니다 — 따로 하신 로그인과는 별개입니다."
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
    say "         ⚠이것은 위의 「cys 계정 자리」 안에 들어 있어 함께 지워집니다(cys 설치의 일부입니다)."
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
# 🔴보존 경로의 실경로는 **지우기 전에 한 번에** 풀어 둔다(4R 지적 채택 2026-09-09).
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
      #   🔴사유를 **경로별로** 함께 담는다(7R 지적 채택 2026-09-09 · 윈도우 쪽과 같은 지적).
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
  printf '%s\n' "$keeps" | while IFS= read -r k; do
    [ -n "$k" ] || continue
    case "$p" in "$k"|"$k"/*) exit 9 ;; esac   # 보존 경로 자신 또는 그 아래
    case "$k" in "$p"/*) exit 9 ;; esac        # 보존 경로의 조상
  done
  [ $? -eq 9 ]
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
#   🔴🔴**열거 자체가 실패할 수 있다**(4R 지적 채택 2026-09-09). 앞 판은 `find` 의 오류를 버리고
#   종료값도 안 봤다 ⇒ **하나도 못 본 날이 「다 지웠다」가 된다.** 그리고 줄 단위로 읽어서
#   **이름에 개행이 든 파일이 두 조각으로 갈렸다.** ⇒ `-print0` 로 받고 종료값을 본다.
#   ★그리고 지운 뒤 **다시 세어** 검산한다 — 「지웠다」는 남은 것이 0일 때만 참이다.
#   ★링크는 이 자리에서 저절로 안전하다(실측 2026-09-09): 폴더를 가리키는 심볼릭 링크에 `rm -rf` 를
#     하면 **링크만 사라지고 대상 폴더·파일은 그대로다**. 윈도우는 그렇지 않아 따로 손을 봤다
#     (윈은 훑는 쪽이 링크로 들어갈 수 있다 — `reset-clean.ps1` 의 `Get-TreeItems`·`Remove-OneItem` 참조.
#      ⚠5.1 `Remove-Item -Recurse` 가 뚫는지는 판본에 따라 다르다 — 2026-09-09 러너 실측: 안 뚫었다).
#   🔴🔴**원문 경로로 훑는다**(6R BLOCK 채택 2026-09-09 · 윈도우와 같은 결함이 여기에도 있었다).
#   앞 판은 실경로(`$t`)를 이 함수에 넘겼다. 그래서 삭제 루트가 링크면 **그 대상 폴더**를 훑어 지웠다.
#   ⇒ 훑는 것은 언제나 원문 루트, 실경로는 **비교에만** 쓴다.
PRUNE_WHY=""
prune_except() {
  local root="$1" root_canon="$2" keeps="$3" list p c enum_fail left why
  PRUNE_FAIL=0; enum_fail=0; left=0
  list="$(mktemp -t jarvis-prune)" || return 1
  find "$root" -depth -mindepth 1 -print0 > "$list" 2>/dev/null || enum_fail=1
  # 🔴2026-09-10 봉인(1R REVISE ⑥) — 앞 판은 항목별 `rm` 의 stderr 를 버리고 마지막에 개수만
  #   말했다. 중첩 보존은 우리가 **지원한다고 명시한 구성**인데, 거기서 「몇 가지를 지우지 못했다」만
  #   남으면 사용자는 어느 파일을 풀어야 하는지 알 수 없다. ⇒ 까닭을 최대 5줄 모아 인쇄한다.
  PRUNE_WHY=""
  while IFS= read -r -d '' p; do
    c="$(item_canon "$p" "$root" "$root_canon")" || c=""
    prune_keep_hit "$c" "$keeps" && continue
    why="$(rm -rf "$p" 2>&1)"
    if [ -n "$why" ]; then
      PRUNE_WHY="$(printf '%s%s\n' "$PRUNE_WHY" "$why")"
    fi
  done < "$list"
  # ★검산 — 남은 것을 다시 센다. 지우기 실패든 열거 실패든 **결과 한 칸**으로 모인다.
  : > "$list"
  find "$root" -depth -mindepth 1 -print0 > "$list" 2>/dev/null || enum_fail=1
  while IFS= read -r -d '' p; do
    c="$(item_canon "$p" "$root" "$root_canon")" || c=""
    prune_keep_hit "$c" "$keeps" && continue
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
drop_dir()  {
  [ -e "$1" ] || [ -L "$1" ] || return 0
  # 🔴지우기 전에 보존 경로와의 중첩을 먼저 본다(검토 지적 채택 2026-09-09).
  local t covers keeps
  # ★남겨야 할 자리 가운데 **있는데 실경로를 못 푼 것**이 있으면 아무것도 지우지 않는다.
  #   무엇을 남겨야 하는지 모르는 채로 지우면 그것이 이 도구의 가장 나쁜 실패다.
  #   (까닭은 위 `resolve_preserve_paths` 참조. 사람이 볼 설명은 purge 가 한 번만 인쇄한다.)
  if [ "${PRESERVE_CANON_FAIL:-0}" -ne 0 ]; then
    KEPT_FAIL=$((KEPT_FAIL+1))
    say "  🔴못 지움: $(short "$1") — 남겨야 할 자리를 확인하지 못해 지우지 않았습니다."
    return 1
  fi
  # 🔴🔴**삭제 루트가 링크면 이름표만 지운다 — 그 안으로 들어가지 않는다**(6R BLOCK 채택 2026-09-09).
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
  if [ -n "$keeps" ]; then
    PRESERVED=$((PRESERVED+1))
    say "  보존(중첩): $(short "$1") 안에 참가 자리가 있어 **그것만 남기고** 지웁니다."
    printf '%s\n' "$keeps" | while IFS= read -r k; do [ -n "$k" ] && say "           남기는 자리: $(short "$k")"; done
    if prune_except "$1" "$t" "$keeps"; then
      REMOVED=$((REMOVED+1)); say "  지움: $(short "$1") (참가 자리는 그대로)"
      return 0
    fi
    KEPT_FAIL=$((KEPT_FAIL+1))
    say "  🔴일부 남음: $(short "$1") — ${PRUNE_FAIL}가지를 지우지 못했습니다(참가 자리는 그대로입니다)."
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
  #   「못 지웠다」로만 끝내면 사람은 무엇을 해야 할지 모른다(적대검증 지적 채택 2026-09-08).
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
    #   🔴적대검증 지적 채택(2026-09-08): 앞 판은 표식 **다음 한 줄을 무조건** 지웠다.
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

strip_json_key() { # strip_json_key <파일> <키> — 파일은 남기고 우리 칸만 뺀다
  [ -f "$1" ] || return 0
  #   ⚠`plutil` 은 키 경로에서 마침표를 구분자로 읽는다. 사용자 폴더 이름에 마침표가 있으면
  #   (예: /Users/first.last) 그 칸을 **가리킬 수가 없다**(2026-09-08 실측: extract·remove 둘 다 실패).
  #   설치기도 같은 방식으로 넣으므로 애초에 안 들어갔을 수 있다. 어느 쪽이든 우리가 할 수 있는 것은
  #   **모른다고 말하는 것**뿐이다 — 조용히 지나가면 「다 지웠다」가 거짓이 된다.
  case "$2" in
    projects.*)
      case "${2#projects.}" in
        *.*) say "  ⚠못 살핌: $(short "$1") 의 $2 칸 — 사용자 폴더 이름에 마침표가 있어 이 칸은 다루지 못합니다."
             return 0 ;;
      esac ;;
  esac
  plutil -extract "$2" raw -o - "$1" >/dev/null 2>&1 || return 0
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

# ── 🔴🔴작업 폴더를 **재귀로 지우기 전에** 그 자리가 안전한지 본다 (3R N3 = 표면 축소 · master 결정) ──
#   `JARVIS_HOME` 은 환경변수라 **무엇이든 들어올 수 있다.** 검사 없이 넘기면 그 값이 홈이거나
#   드라이브 루트일 때 **사진·문서·남의 프로젝트를 통째로** 지운다. 되돌릴 수 없는 손실이다.
# 🔴🔴**앞 판은 「나쁜 값 목록」으로 막으려 했고, 그 목록은 세 라운드 내내 새 구멍을 냈다**
#   (홈·루트·시스템 자리 → 드라이브 루트 → UNC 공유 → 조상 심볼릭 링크 → 8.3 별칭…).
#   ★목록으로 막는 싸움은 **막는 쪽이 항상 뒤늦다.** 값의 모양이 무한하기 때문이다.
#   ⇒ **표면을 줄인다**(master 결정 2026-09-10): 지워도 되는 자리의 이름을 **하나로 못 박는다.**
#     ⑴실경로의 **마지막 칸이 정확히 `install-jarvis`** 다. 그 외의 값은 **거부하고 안내한다.**
#       · 참가자는 기본값을 쓰므로 아무 영향이 없고, 러너의 `…/lp-home/install-jarvis` 도 통과한다.
#       · 이 한 줄로 홈·루트·시스템 자리·UNC 공유·남의 프로젝트가 **한꺼번에** 닫힌다 —
#         그것들의 마지막 칸은 `install-jarvis` 가 아니기 때문이다.
#     ⑵**우리가 만든 표식**이 그 안에 있다 — 설치기는 **자기가 새로 만든 폴더에만** 표식을 놓는다.
#       (앞 판은 이미 있던 남의 폴더에도 표식을 써 줘서 이 관문을 스스로 무효화했다 — 3R BLOCK.)
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
  local f="$1" d="$2" left
  [ -f "$f" ] || return 0
  case "$d" in
    *.*) say "  ⚠못 살핌: $(short "$f") 의 $(short "$d") 폴더 신뢰 칸 — 폴더 이름에 마침표가 있어 다루지 못합니다."
         return 0 ;;
  esac
  # 🔴**우리가 넣은 값과 같을 때만 지운다**(2R N4 봉인). 기록한 뒤 사람이 그 값을 손수 바꿨다면
  #   그것은 이제 그분의 선택이다 — 기록이 있다고 남의 결정을 되돌리지 않는다.
  local cur
  cur="$(plutil -extract "projects.$d.hasTrustDialogAccepted" raw -o - "$f" 2>/dev/null)" || return 0
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
# 🔴🔴**한 번만 도는 것은 「열쇠고리 직접 삭제」뿐이다**(2R N1 봉인 · 1R BLOCK ① 의 범위 축소).
#   아래 660줄 규율은 「열쇠고리 항목을 없어질 때까지 반복해 지우지 않는다 — 그러면 이 사람의
#   다른 클로드 로그인까지 지운다」이다. 그런데 그 뒤에 붙인 **재시도 루프**가 purge 를 최대 네 번
#   부르면서 `security delete-generic-password` 를 매번 다시 불렀다 ⇒ ★규율이 약속한 바로 그
#   반복을 **루프가 밖에서 만들어 냈다.** 한 번에 하나씩, 최대 네 항목이 비가역으로 사라진다.
#   ★교훈: 「이 함수는 한 번만 부른다」를 **주석으로만** 적어 두면, 부르는 쪽을 고치는 사람이
#     그것을 모른다. 불변식은 그 함수 자신이 지켜야 한다.
# 🔴🔴그런데 **함수 전체를 막은 것은 너무 넓었다**(2R N1). 잠긴 로그인 파일 삭제가 처음 실패했을 때
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
    # 🔴적대검증 [1] **부분** 채택(2026-09-08). 열쇠고리에는 같은 이름의 항목이 **여럿** 있을 수 있다 —
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

  # 🔴**자비스 폴더를 지우기 전에** 신뢰 씨앗 기록을 읽어 둔다(1R REVISE ④). 그 기록은 그 폴더
  #   안에 있고 아래에서 그 폴더를 지운다 — 순서를 뒤집으면 「우리가 넣은 것」과 「참가자의 것」을
  #   영영 구별할 수 없다.
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

  # ★순서가 중요하다 — 등록을 떼는 명령이 **프로그램 안에** 들어 있다.
  #   프로그램을 먼저 지우면 등록을 뗄 수단이 사라져 죽은 등록이 남는다.
  # footprint: M-DAEMON
  if [ -n "$CYS_CLI" ]; then
    CYS_NO_AUTOSTART=1 "$CYS_CLI" daemon uninstall >/dev/null 2>&1 && say "  지움: cys 상시 가동 등록"
  fi
  launchctl bootout "gui/$(id -u)/com.cysjavis.cysd" >/dev/null 2>&1 || true
  drop_file "$HOME/Library/LaunchAgents/com.cysjavis.cysd.plist"
  # 🔴🔴`pkill -f 'cys\.app/Contents/MacOS/cysd'` 를 **뺐다**(2R STILL OPEN ② 봉인 2026-09-10).
  #   그것도 **명령줄**을 본다 — 편집기가 그 경로를 **파일 인자로 열기만 해도** 종료된다.
  #   1R 에서 다른 명령줄 축을 빼면서 이 한 줄을 놓쳤다. ★한 축을 지울 때는 **같은 성질의 축이
  #   또 있는지** 세어라. 아래 stop_cys_processes 가 자리 축 + 혈연으로 같은 일을 안전하게 한다.
  # ★이름이 아니라 **자리**로 한 번 더 훑는다(R1) — 데몬이 띄운 자식은 이름이 우리 것이 아니다.
  CYS_ALIVE="$(stop_cys_processes "$CYS_APP" "$HOME/.cys")"
  if [ -n "$CYS_ALIVE" ]; then
    say "  [주의] cys 자리에서 아직 돌고 있는 것이 있습니다 — 폴더가 안 지워질 수 있습니다."
    write_alive_procs "$CYS_ALIVE"
  fi

  # ★로그인도 클로드를 지우기 **전에** 처리한다 — 로그아웃 명령이 클로드 안에 들어 있다.
  purge_login_first

  # ★훅을 프로그램보다 **먼저** 뗀다 — 훅을 고칠 파이썬이 그 프로그램 안에 들어 있다(pick_python).
  #   순서를 뒤집으면 깨끗한 맥에서 훅이 영영 안 지워진다(그 기계엔 다른 파이썬이 없다).
  # footprint: M-HOOK
  strip_hooks "$HOME/.claude/settings.json"

  # footprint: M-APP
  drop_dir "$CYS_APP"
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
  #   🔴🔴**「대상이 있다」로 이전을 마쳤다고 판정하지 않는다**(4R 지적 채택 2026-09-09).
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

  # footprint: M-CYSHOME   (M-CYSPROFILE 은 이 안에 들어 있다)
  if [ "$AGORA_MIGRATE_OK" = "1" ]; then
    drop_dir "$HOME/.cys"
  fi
  # footprint: M-CYSSTATE
  drop_dir "$HOME/.local/state/cys"
  # footprint: M-CLAUDEBIN
  drop_file "$HOME/.local/bin/claude"
  # footprint: M-CLAUDESHARE
  drop_dir "$HOME/.local/share/claude"
  # 🔴**신뢰 키 정리를 작업 폴더 삭제보다 앞에 둔다**(2R N4 봉인 2026-09-10).
  #   기록 파일은 그 폴더 안에 있다. 폴더를 먼저 지우면, 키 정리가 실패했을 때 **다시 해 볼 근거가
  #   사라진다** — 재시도는 「기록 없음」으로 읽고 그 키를 영영 건너뛴다.
  #   ★순서가 곧 안전장치다: 근거를 없애는 일은 그 근거를 다 쓴 뒤에 한다.
  # 🔴홈 폴더 칸은 **기록에 적힌 것만** 뺀다(1R REVISE ④). 우리가 넣은 키만 기록돼 있다.
  #   ⛔경로를 추측해서 지우지 않는다 — 그 추측이 참가자의 값을 지우던 자리였다.
  # 🔴🔴**파이프로 돌리지 않는다**(3R N4 봉인 2026-09-10). `… | while` 의 몸통은 **하위 셸**이라
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
  # 🔴🔴**신뢰 칸 정리에 실패했으면 이 폴더를 남긴다**(3R N4 봉인 2026-09-10). 기록 파일이 이 안에
  #   있다 — 지우면 **다시 해 볼 근거가 사라지고**, 다음 실행은 「기록 없음」으로 읽어 그 칸을
  #   영영 건너뛴다(참가자 컴퓨터에 우리 자국이 남는다).
  #   ★순서를 앞당긴 것만으로는 부족했다: 실패해도 그냥 이어서 지우고 있었다.
  if [ "${TRUST_CLEANUP_FAIL:-0}" -gt 0 ]; then
    KEPT_FAIL=$((KEPT_FAIL+1))
    say "  🔴못 지움: $(short "$JARVIS_HOME") — 폴더 신뢰 칸을 다 되돌리지 못해 **일부러 남겼습니다.**"
    say "         이 폴더 안의 기록(trust-seed.tsv)이 있어야 다시 해 볼 수 있습니다."
    say "         그 칸을 쓰고 있는 프로그램(클로드 창 등)을 닫으신 뒤 아래 「다시 하시는 법」대로 다시 실행해 주십시오."
  elif safe_jarvis_dir "$JARVIS_HOME"; then
    drop_dir "$JARVIS_HOME"
  elif [ -e "$JARVIS_HOME" ]; then
    KEPT_FAIL=$((KEPT_FAIL+1))
    say "  🔴못 지움: $(short "$JARVIS_HOME") — 안전 확인을 통과하지 못해 지우지 않았습니다."
    say "         까닭: $SAFE_WHY"
    say "         그 자리는 손으로 확인해 주십시오. 확실하지 않은 자리를 재귀로 지우지 않습니다."
  fi
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

  # 🔴**요청한 로그인 자국이 정말 사라졌는지 끝에서 다시 본다**(2R N1 봉인). 앞 판은 「지웠다」를
  #   그 순간의 종료값으로만 말했다 ⇒ 파일이 잠겨 남았는데 전체는 성공으로 끝났다.
  #   ★「지웠다」는 **다시 봐서 없을 때만** 참이다.
  # 🔴🔴**재진단은 파일 하나가 아니라 `login_present` 전체로 한다**(3R N1 봉인 2026-09-10).
  #   앞 판은 **로그인 파일만** 다시 봤다. 그런데 맥의 로그인은 열쇠고리에도 있고, 같은 이름의 항목이
  #   **여럿** 있을 수 있다(클로드가 설정 폴더마다 따로 건다) ⇒ 열쇠고리에 남았는데도 화면은
  #   「못 지운 것은 없습니다」로 끝났다. **거짓 성공이다.**
  #   ★「지웠다」는 **다시 봐서 없을 때만** 참이다 — 그 「없다」의 범위가 처음 세던 범위와 같아야 한다.
  #   ⛔남은 항목을 **자동으로 더 지우지는 않는다**(2R N1 규율 유지) — 그러면 우리가 깔지 않은
  #     이 사람의 다른 클로드 로그인까지 사라진다. 우리가 할 일은 **사실대로 말하는 것**이다.
  # ★재진단은 **세 상태**로 받는다(4R N1). 「모른다」를 「없다」로 적으면 그 순간 거짓 성공이다.
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
  # (로그인은 클로드를 지우기 전에 이미 처리했다 — purge_login_first 참조)
  # footprint: M-CLAUDEUSER  — 손대지 않는다
  say "  남김: 클로드 대화·기록"

  say ""
  # 보존한 것이 있으면 반드시 말한다 — 「지웠는데 왜 남아 있지」를 미리 답한다.
  [ "$PRESERVED" -gt 0 ] && say "    (참가 자리와 겹쳐 그대로 둔 자리 $PRESERVED 곳이 있습니다 — 위 「보존(중첩)」 줄)"
  if [ "$KEPT_FAIL" -eq 0 ]; then
    say "=== 끝났습니다 — $REMOVED 가지를 지웠고, 못 지운 것은 없습니다. ==="
    return 0
  fi
  # 🔴사실만 말한다. 「거의 다 됐다」로 얼버무리면 다음 단계가 그 위에 얹힌다.
  say "=== 끝났습니다 — $REMOVED 가지를 지웠고, $KEPT_FAIL 가지를 못 지웠습니다. ==="
  say "    위에 🔴로 표시된 자리가 남아 있습니다. 그대로 두고 다시 설치하면 뒤엉킵니다."
  say "    아래 「다시 하시는 법」대로 한 번 더 해 보시고, 그래도 남으면 이 화면을 사진으로 남겨 알려 주십시오."
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
  alive="$(procs_under "$CYS_APP" "$HOME/.cys" 2>/dev/null | sort -u | wc -l | tr -d ' ')"
  [ "${alive:-0}" -gt 0 ] || return 0
  say ""
  say "cys 가 아직 돌고 있습니다(${alive}가지). 먼저 cys 창을 닫아 주십시오."
  say "     닫지 않으셔도 이 도구가 끕니다 — 다만 저장하지 않으신 것이 사라질 수 있습니다."
  if [ "$ASSUME_YES" != "1" ] && { : < /dev/tty; } 2>/dev/null; then
    printf '  확인하셨으면 Enter 를 눌러 주십시오: '
    read -r _ignored < /dev/tty || true
  fi
  return 0
}
notice_close_cys

if [ "$ASSUME_YES" != "1" ]; then
  say ""
  say "위 목록을 지웁니다. 되돌릴 수 없습니다."
  printf '계속하려면 「지웁니다」라고 쳐 주십시오: '
  read -r answer < /dev/tty || answer=""
  if [ "$answer" != "지웁니다" ]; then
    say "그만둡니다 — 아무것도 지우지 않았습니다."
    exit 1
  fi
fi

# ★그 자리에서 다시 해 본다 — 창을 닫고 명령을 다시 찾는 것보다 Enter 한 번이 싸다(2026-09-10).
#   막힌 까닭 대부분은 **사람이 지금 이 창 앞에서 없앨 수 있는 것**이다. 그때마다 사이트를
#   다시 찾게 하지 않는다. ⚠상한 3회 — 무한 고리는 「막혔다」를 영영 말하지 않는 것과 같다.
#   3회 뒤에는 사실대로 끝내고 **명령 전체를 인쇄**한다(재부팅이 필요한 자리는 재실행으로 안 풀린다).
purge
rc=$?
tries=0
while [ "$rc" -ne 0 ] && [ "$ASSUME_YES" != "1" ] && [ "$tries" -lt 3 ] && [ -r /dev/tty ]; do
  tries=$((tries+1))
  say ""
  printf '  남은 자리를 여기서 바로 다시 지워 볼 수 있습니다. Enter 를 누르면 다시 해 봅니다 (%s/3 · 그만두려면 q): ' "$tries"
  read -r again < /dev/tty || again="q"
  [ "$again" = "q" ] && break
  REMOVED=0; KEPT_FAIL=0; PRESERVED=0
  purge
  rc=$?
done
[ "$rc" -ne 0 ] && show_rerun_how
exit "$rc"
