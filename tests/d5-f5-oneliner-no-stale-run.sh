#!/bin/bash
# D5-F5 검출 시험 — 윈 배포 한 줄(irm … -OutFile …; powershell -File …)이 받기에 실패해도 지난번에 받아 둔 옛 파일을 실행하면 적색.
#   앞 형태는 `;` 로 이어져 있어 받기가 실패해도(-ErrorAction Stop 을 붙여도) 뒤 명령이 돌았다 — 옛 핀의 설치 도우미가 조용히 실행된다.
#   이 맥의 pwsh 로 **머리글의 한 줄을 글자 그대로** 돌린다(주소만 바꾼다). 안쪽 `powershell` 은 PATH 가짜(= pwsh)로 받는다.
#   ⑴실패 갈래: 주소 = 닫힌 자리(127.0.0.1:9) · 옛 파일을 미리 심어 둔다 → 옛 파일 실행 0 · 옛 파일 지워짐 · 안내 문장 · rc≠0
#   ⑵성공 갈래(대조군): 주소 = 이 시험 안에서만 뜨는 로컬 파일 자리 → 새 파일이 실행된다(시험이 눈먼 초록이 아님을 보인다)
#   ⚠[Environment]::GetFolderPath('UserProfile') 는 맥 pwsh 에서 HOME 이다 — HOME 을 시험 폴더로 둔다(경로에 「:」 금지 · pwsh 가 못 뜬다).
# 쓰는 법: bash tests/d5-f5-oneliner-no-stale-run.sh [ps1 경로(기본 install-master/bootstrap.ps1)]   · rc 0 = 통과 · 1 = 결함 · 2 = 측정 무효
set -u
PS1="${1:-$(cd "$(dirname "$0")/.." && pwd)/install-master/bootstrap.ps1}"
command -v pwsh >/dev/null 2>&1 || { echo "FAIL 측정 무효: pwsh 가 없다"; exit 2; }
T="$(mktemp -d "${TMPDIR:-/tmp}/d5f5.XXXXXX")" || exit 2
SRV_PID=""
trap '[ -n "$SRV_PID" ] && kill -- -"$SRV_PID" 2>/dev/null; rm -rf "$T"' EXIT
LINE="$(sed -n 's/^#[[:space:]]*\(powershell -NoProfile .*\)$/\1/p' "$PS1" | head -1)"
[ -n "$LINE" ] || { echo "FAIL 측정 무효: 머리글에서 배포 한 줄을 못 찾았다"; exit 2; }
NAME="$(printf '%s\n' "$LINE" | sed -n "s/.*-OutFile (\[Environment\]::GetFolderPath('UserProfile')+'\\\\\([a-z-]*\.ps1\)').*/\1/p")"
[ -n "$NAME" ] || { echo "FAIL 측정 무효: 받는 자리 이름을 못 찾았다"; exit 2; }
mkdir -p "$T/home" "$T/bin" "$T/srv/install"
printf '#!/bin/bash\nexec pwsh -NoProfile "$@"\n' > "$T/bin/powershell"; chmod +x "$T/bin/powershell"
# 맥 pwsh 는 '\이름' 의 역슬래시를 경로 구분자로 바꾼다 ⇒ 받기·지우기·실행이 가리키는 자리 = HOME/이름(윈에서는 사용자 폴더\이름).
#   ⚠「home\이름」 이라는 이름으로 심으면 대상에 닿지 않아 옛 판 실행 여부를 못 잰다(첫 작성 때 실제로 그랬다).
LANDED="$T/home/$NAME"
run_line() { # run_line <주소> → 출력은 $T/out · rc 반환
  local l="${LINE//https:\/\/jarvis.godmeyou.kr\/install\//$1/install/}"
  [ "$l" != "$LINE" ] || { echo "FAIL 측정 무효: 주소를 못 바꿨다"; exit 2; }
  ( cd "$T" && env HOME="$T/home" PATH="$T/bin:$PATH" perl -e 'alarm 90; exec @ARGV or exit 126' bash -c "$l" ) > "$T/out" 2>&1
}
fail=0
# ⑴ 실패 갈래 — 옛 파일을 심는다(실행되면 표지를 남긴다)
printf "Set-Content -LiteralPath '%s' -Value ran\n" "$T/OLD-RAN" > "$LANDED"
run_line "http://127.0.0.1:9"; rc=$?
if [ -e "$T/OLD-RAN" ]; then echo "FAIL 받기가 실패했는데 옛 파일이 실행됐다(rc=$rc)"; fail=1; fi
if [ -e "$LANDED" ]; then echo "FAIL 옛 파일이 그대로 남았다(다음 실행이 또 옛 판을 집는다)"; fail=1; fi
[ "$rc" -ne 0 ] || { echo "FAIL 받기가 실패했는데 종료 코드가 0 이다"; fail=1; }
grep -q '설치 파일을 받지 못했습니다' "$T/out" || { echo "FAIL 받지 못했다는 안내가 없다:"; tail -3 "$T/out" | sed 's/^/  /'; fail=1; }
# ⑵ 성공 갈래(대조군) — 새 파일이 실제로 실행되는가
printf "Set-Content -LiteralPath '%s' -Value ran\n" "$T/NEW-RAN" > "$T/srv/install/$(basename "$(printf '%s\n' "$LINE" | sed -n 's#.*https://jarvis.godmeyou.kr/install/\([a-z-]*\.ps1\).*#\1#p')")"
PORT="$(python3 -c 'import socket;s=socket.socket();s.bind(("127.0.0.1",0));print(s.getsockname()[1]);s.close()')"
SRV_PID="$(python3 - "$T/srv" "$PORT" <<'EOF'
import subprocess, sys
p = subprocess.Popen([sys.executable, "-m", "http.server", sys.argv[2], "--bind", "127.0.0.1", "--directory", sys.argv[1]],
                     stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL, start_new_session=True)
print(p.pid)
EOF
)"
for _ in 1 2 3 4 5 6 7 8 9 10; do curl -fsS "http://127.0.0.1:$PORT/" >/dev/null 2>&1 && break; sleep 0.3; done
run_line "http://127.0.0.1:$PORT"; rc2=$?
if [ ! -e "$T/NEW-RAN" ]; then echo "FAIL 측정 무효: 받기가 성공해도 새 파일이 실행되지 않았다(rc=$rc2) — 시험이 대상에 닿지 않는다"; tail -3 "$T/out" | sed 's/^/  /'; exit 2; fi
[ "$fail" -eq 0 ] && echo "PASS 받기 실패 → 옛 파일 실행 0 · 옛 파일 지움 · 안내 · rc=$rc / 대조군 받기 성공 → 새 파일 실행(rc=$rc2)"
exit "$fail"
