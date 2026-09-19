#!/bin/bash
# 완료 직후 재실행 시험 — TICKET=installer-0326 C1 (2026-09-18 · 실전 2건 09-17 PhsTjiL0 · 09-18 UHHFFFZJ)
#
# 무엇을 재는가 (계약 = master#eeaa7413 A안 · 브리프 C1 처방)
#   ⓐ 성공 끝(Set-FleetFinished)이 작업 폴더에 완료 표지(install-done.txt · 한 줄 「done <시각> installer <판> cys <판>」)를 쓴다
#   ⓑ Test-RecentInstallDone — 표지가 쓰인 지 10분(600초) 안이면 맞다 · 600초 경계 포함 · 601초면 아니다 · 미래 시각(시계 되돌림)이면 아니다
#   ⓒ 표지가 없는 옛 판 완료 — 지난 기록의 **마지막 실행**이 「다음에 할 일: 없습니다 — 설치가 끝났습니다」로 끝났고 그 시각이 창 안이면 맞다 ·
#      그 뒤에 새 실행 머리글이 있으면(마지막 실행이 아니면) 아니다 · 실패 끝맺음(「다시 하시는 법」)이면 아니다
#   ⓓ Invoke-ClaudeCli — 명령은 잡히는데 가리키는 실행 파일이 없는 클로드(npm claude.ps1 모양 · 09-18 실물 오류와 같은 형)를
#      본문 try 안에서 불러도 죽지 않는다 · ~\.local\bin\claude.exe 가 있으면 그것을 대신 부른다 · 대조군: 맨몸 호출은 같은 자리에서 죽는다
#   ⓔ 실물 전체 실행 — 방금 쓴 표지가 있는 작업 폴더에서 설치 도우미를 돌리면: rc 0 · 「설치가 이미 끝나 있습니다」 ·
#      [1/10] 0줄 · 진단 코드 0 · 「다시 하시는 법」 0 · 기록에 「rerun after done: nothing to do」
#   ⓕ 대조군 — 표지가 11분 묵었으면 정상 진행한다([1/10] 이 찍힌다)
#   ⓗ 재설치 길(JARVIS_ENTRY=reinstall)은 방금 쓴 표지가 있어도 정상 진행한다(지우기가 작업 폴더를 남긴 경우)
#   ⓖ 맨몸 `& claude` 호출이 코드에 남지 않았다(정적 · 허용 2자리)
#
# 쓰는 법: bash tests/rerun-after-done-run.sh [--dir <install-master 자리>]
#   rc 0 = 전건 통과 · 1 = 실패 있음 · 2 = 잴 수 없음(pwsh 가 없다)
# ⛔바깥에 닿지 않는다 — USERPROFILE·HOME·JARVIS_HOME 은 mktemp -d 안 · PATH 에는 가짜 claude 만(진짜 claude·cys 를 안 본다) ·
#   ⓕ 는 [1/10] 뒤로 진행하므로 네트워크를 닫은 대리 서버(127.0.0.1:9)로 막고 60초 상한으로 끊는다 · 진행 기록 레버 JARVIS_NO_PROGRESS=1.
# ⚠여기서 안 재는 것(윈 실기 몫): 진짜 윈도우 콘솔에서 재기동이 왜 일어났는가(원인 미확정 · HANDOFF) · Windows PowerShell 5.1 자체.
export JARVIS_NO_PROGRESS=1
set -u
HERE="$(cd "$(dirname "$0")" && pwd)"
DIR="$HERE/../install-master"
while [ $# -gt 0 ]; do
  case "$1" in
    --dir) DIR="$2"; shift 2 ;;
    *) echo "모르는 인자: $1" >&2; exit 2 ;;
  esac
done
PW="$(command -v pwsh 2>/dev/null)"
[ -n "$PW" ] || { echo "잴 수 없음: pwsh 가 없다" >&2; exit 2; }
PS="$(cd "$DIR" && pwd)/bootstrap.ps1"
SB="$(mktemp -d)"; SB="$(cd "$SB" && pwd -P)"
trap 'rm -rf "$SB"' EXIT
pass=0; fail=0
t() { if [ "$1" -eq 0 ]; then pass=$((pass+1)); printf '  ok   %s\n' "$2"; else fail=$((fail+1)); printf '  FAIL %s  ← %s\n' "$2" "$(printf '%s' "${3:-}" | tr '\n' '|' | cut -c1-300)"; fi; }

# 가짜 도구 자리 — claude 는 「명령은 있는데 가리키는 파일이 없는」 npm 모양(09-18 실물: …/node_modules/@anthropic-ai/claude-code/bin/claude.exe not recognized)
mkdir -p "$SB/bin"
cat > "$SB/bin/claude.ps1" <<'EOF'
& "$PSScriptRoot/node_modules/@anthropic-ai/claude-code/bin/claude.exe" @args
EOF
BASEPATH="$SB/bin:/usr/bin:/bin"   # 진짜 claude·cys 가 있는 자리를 PATH 에서 뺀다
newhome() { # newhome <이름> → 표식 있는 작업 폴더를 가진 사용자 폴더
  local h="$SB/$1"
  mkdir -p "$h/install-jarvis"
  printf 'jarvis-installer-owned v1\r\n' > "$h/install-jarvis/.jarvis-owned"
  printf '%s' "$h"
}
run_lib() { # run_lib <사용자폴더> <pwsh 명령>
  USERPROFILE="$1" HOME="$1" JARVIS_HOME="$1/install-jarvis" PATH="$BASEPATH" JARVIS_LIB_ONLY=1 \
    perl -e 'alarm shift; exec @ARGV or exit 126' 60 "$PW" -NoProfile -Command ". '$PS' *> \$null; $2" 2>&1
}

echo "== ⓐ 성공 끝이 완료 표지를 쓴다 =="
H="$(newhome a)"
out="$(run_lib "$H" "Set-FleetFinished; Write-Output ('NEXT=' + \$script:NextStep)")"
f="$H/install-jarvis/install-done.txt"
[ -f "$f" ] && grep -qE '^done [0-9]{4}-[0-9]{2}-[0-9]{2}T[0-9]{2}:[0-9]{2}:[0-9]{2}[+-][0-9]{2}:[0-9]{2} installer [0-9]+\.[0-9]+\.[0-9]+ cys [0-9]+\.[0-9]+\.[0-9]+' "$f"
t $? "[ⓐ] install-done.txt = 「done <시각> installer <판> cys <판>」 한 줄" "$(cat "$f" 2>&1) $out"
printf '%s' "$out" | grep -qF 'NEXT=없습니다 — 설치가 끝났습니다. 이 창을 닫으셔도 됩니다.'
t $? "[ⓐ] 끝맺음 문구는 그대로다(옛 판 기록 판정이 이 문구를 읽는다)" "$out"

echo "== ⓑ 표지 창(600초) 경계 =="
H="$(newhome b)"; f="$H/install-jarvis/install-done.txt"; printf 'done x\r\n' > "$f"
out="$(run_lib "$H" "
\$w = [datetimeoffset](Get-Item -LiteralPath '$f').LastWriteTime
foreach (\$s in 5, 600, 601, -30) { Write-Output ('s' + \$s + '=[' + (Test-RecentInstallDone (\$w.AddSeconds(\$s))) + ']') }
")"
printf '%s' "$out" | grep -qx 's5=\[mark 5s\]';   t $? "[ⓑ] 5초 뒤 = 맞다(mark 5s)" "$out"
printf '%s' "$out" | grep -qx 's600=\[mark 600s\]'; t $? "[ⓑ] 600초(경계) = 맞다" "$out"
printf '%s' "$out" | grep -qx 's601=\[\]';        t $? "[ⓑ] 601초 = 아니다(정상 진행)" "$out"
printf '%s' "$out" | grep -qx 's-30=\[\]';        t $? "[ⓑ] 표지가 미래(시계 되돌림) = 아니다" "$out"

echo "== ⓒ 표지 없는 옛 판 완료 기록 =="
T0='2026-09-18T11:43:16+09:00'
H="$(newhome c1)"
printf '%s === 자비스 설치 도우미 — cysr 1.0.1 · 설치 도우미 0.3.24 (모드: full) ===\n%s [1/10] 이 컴퓨터를 살펴봅니다.\n%s 다음에 할 일: 없습니다 — 설치가 끝났습니다. 이 창을 닫으셔도 됩니다.\n%s   막히면 이 두 파일을 보내 주십시오: x\n' "$T0" "$T0" "$T0" "$T0" > "$H/install-jarvis/bootstrap.log"
out="$(run_lib "$H" "
\$d = [datetimeoffset]::Parse('$T0', [Globalization.CultureInfo]::InvariantCulture)
Write-Output ('in=[' + (Test-RecentInstallDone (\$d.AddSeconds(2))) + ']')
Write-Output ('out=[' + (Test-RecentInstallDone (\$d.AddSeconds(700))) + ']')
")"
printf '%s' "$out" | grep -qx 'in=\[log 2s\]'; t $? "[ⓒ] 옛 판 성공 끝맺음 2초 뒤 = 맞다(log 2s · 09-18 UHHFFFZJ 모양)" "$out"
printf '%s' "$out" | grep -qx 'out=\[\]';       t $? "[ⓒ] 옛 판 성공 끝맺음 700초 뒤 = 아니다" "$out"
H="$(newhome c2)"
{ cat "$SB/c1/install-jarvis/bootstrap.log"; printf '%s === 자비스 설치 도우미 — cysr 1.0.1 · 설치 도우미 0.3.24 (모드: full) ===\n%s 다음에 할 일: 아래 「다시 하시는 법」대로 다시 실행해 주십시오.\n' "$T0" "$T0"; } > "$H/install-jarvis/bootstrap.log"
out="$(run_lib "$H" "Write-Output ('r=[' + (Test-RecentInstallDone ([datetimeoffset]::Parse('$T0', [Globalization.CultureInfo]::InvariantCulture).AddSeconds(2))) + ']')")"
printf '%s' "$out" | grep -qx 'r=\[\]'; t $? "[ⓒ] 성공 뒤 실패로 끝난 실행이 마지막이면 = 아니다(마지막 실행만 본다)" "$out"

echo "== ⓓ 부를 수 없는 클로드 =="
H="$(newhome d)"
out="$(run_lib "$H" "
try { \$v = (Invoke-ClaudeCli --version | Select-Object -First 1); Write-Output ('SAFE=[' + \$v + ']') } catch { Write-Output ('SAFE-DIED=' + \$_.Exception.GetType().Name) }
try { \$w = (& claude --version 2>\$null | Select-Object -First 1); Write-Output 'BARE-SURVIVED' } catch { Write-Output ('BARE-DIED=' + \$_.Exception.GetType().Name) }
")"
printf '%s' "$out" | grep -qx 'SAFE=\[\]'; t $? "[ⓓ] 안전 호출은 try 안에서도 살아남고 빈 값을 돌려준다" "$out"
printf '%s' "$out" | grep -qx 'BARE-DIED=CommandNotFoundException'; t $? "[ⓓ 대조군] 맨몸 호출은 같은 자리에서 CommandNotFoundException 으로 죽는다(09-18 실물과 같은 형)" "$out"
mkdir -p "$H/.local/bin"
printf '#!/bin/sh\necho "9.9.9 (Claude Code)"\n' > "$H/.local/bin/claude.exe"; chmod +x "$H/.local/bin/claude.exe"
out="$(run_lib "$H" "Write-Output ('FB=[' + (Invoke-ClaudeCli --version | Select-Object -First 1) + ']')")"
printf '%s' "$out" | grep -qx 'FB=\[9.9.9 (Claude Code)\]'; t $? "[ⓓ] ~/.local/bin/claude.exe 가 있으면 그것을 대신 불러 판본을 읽는다" "$out"
grep -q 'claude call fallback: ' "$H/install-jarvis/bootstrap.log" 2>/dev/null; t $? "[ⓓ] 대신 부른 사실이 기록에 한 줄 남는다" "$(tail -3 "$H/install-jarvis/bootstrap.log" 2>&1)"

echo "== ⓔ 실물 전체 실행 — 방금 끝난 설치 위의 재실행 =="
run_full() { # run_full <사용자폴더> → 화면 = $1.out · rc = $1.rc
  ( cd "$1" && USERPROFILE="$1" HOME="$1" JARVIS_HOME="$1/install-jarvis" PATH="$BASEPATH" \
      HTTPS_PROXY=http://127.0.0.1:9 HTTP_PROXY=http://127.0.0.1:9 https_proxy=http://127.0.0.1:9 http_proxy=http://127.0.0.1:9 \
      perl -e 'alarm shift; exec @ARGV or exit 126' 60 "$PW" -NoProfile -File "$PS" > "$1.out" 2>&1 < /dev/null; echo $? > "$1.rc" )
}
H="$(newhome e)"; printf 'done 2026-09-18T11:43:16+09:00 installer 0.3.25 cys 1.0.2\r\n' > "$H/install-jarvis/install-done.txt"
run_full "$H"
L="$H/install-jarvis/bootstrap.log"
[ "$(cat "$H.rc")" = "0" ]; t $? "[ⓔ] 종료 코드 0" "rc=$(cat "$H.rc") $(tail -5 "$H.out")"
grep -qF '설치가 이미 끝나 있습니다. 새로 하실 일은 없습니다.' "$H.out"; t $? "[ⓔ] 화면 = 「설치가 이미 끝나 있습니다」" "$(tail -8 "$H.out")"
grep -qF '다음에 할 일: 없습니다 — 이 창은 닫으셔도 됩니다. 자비스 창에서 이어서 하시면 됩니다.' "$H.out"; t $? "[ⓔ] 다음에 할 일 = 닫으셔도 됨 · 자비스 창에서 이어서" "$(tail -8 "$H.out")"
! grep -qF '[1/10]' "$H.out"; t $? "[ⓔ] [1/10] 0줄(아무것도 살피지 않았다)" "$(grep -F '[1/10]' "$H.out")"
! grep -qE '진단 코드: J-' "$H.out"; t $? "[ⓔ] 진단 코드 0(카드 0)" "$(grep -E '진단 코드' "$H.out")"
! grep -qF '다시 하시는 법' "$H.out"; t $? "[ⓔ] 「다시 하시는 법」 0" "$(grep -F '다시 하시는 법' "$H.out")"
grep -qE 'rerun after done: nothing to do \(mark [0-9]+s\)' "$L"; t $? "[ⓔ] 기록 = rerun after done: nothing to do (mark Ns)" "$(tail -5 "$L" 2>&1)"

echo "== ⓕ 대조군 — 11분 묵은 표지는 정상 진행 =="
H="$(newhome f)"; printf 'done x\r\n' > "$H/install-jarvis/install-done.txt"
touch -t "$(date -v-11M +%Y%m%d%H%M.%S)" "$H/install-jarvis/install-done.txt"
run_full "$H"
grep -qF '[1/10] 이 컴퓨터를 살펴봅니다.' "$H.out"; t $? "[ⓕ] 11분 묵은 표지 = [1/10] 부터 정상 진행" "$(head -12 "$H.out")"
! grep -q 'rerun after done' "$H/install-jarvis/bootstrap.log"; t $? "[ⓕ] 「rerun after done」 기록 0" "$(grep 'rerun after done' "$H/install-jarvis/bootstrap.log")"

echo "== ⓗ 재설치 길은 표지가 있어도 정상 진행 =="
# 지우기(reset-clean)가 신뢰 칸 정리 실패로 작업 폴더를 남기면 표지도 남는다 — 사람이 고른 재설치를 삼키면 안 된다.
H="$(newhome h)"; printf 'done x\r\n' > "$H/install-jarvis/install-done.txt"
( cd "$H" && JARVIS_ENTRY=reinstall USERPROFILE="$H" HOME="$H" JARVIS_HOME="$H/install-jarvis" PATH="$BASEPATH" \
    HTTPS_PROXY=http://127.0.0.1:9 HTTP_PROXY=http://127.0.0.1:9 https_proxy=http://127.0.0.1:9 http_proxy=http://127.0.0.1:9 \
    perl -e 'alarm shift; exec @ARGV or exit 126' 60 "$PW" -NoProfile -File "$PS" > "$H.out" 2>&1 < /dev/null )
grep -qF '[1/10] 이 컴퓨터를 살펴봅니다.' "$H.out"; t $? "[ⓗ] 재설치 길(JARVIS_ENTRY=reinstall) = 방금 쓴 표지가 있어도 [1/10] 부터 진행" "$(head -12 "$H.out")"
! grep -q 'rerun after done' "$H/install-jarvis/bootstrap.log"; t $? "[ⓗ] 「rerun after done」 기록 0" "$(grep 'rerun after done' "$H/install-jarvis/bootstrap.log")"

echo "== ⓖ 맨몸 클로드 호출이 남지 않았다(정적) =="
# 허용 = Invoke-ClaudeCli 안의 한 줄 · 환경 수집의 try 로 감싼 한 줄(Get-InstallEnv — 자기 catch 가 있다). 그 밖의 `& claude ` = 적색.
py="$(python3 - "$PS" <<'PYEOF'
import re, sys
bad=[]; ok=0
for i,l in enumerate(open(sys.argv[1],encoding='utf-8-sig').read().split('\n'),1):
    s=l.split('#',1)[0] if not l.lstrip().startswith('#') else ''
    if '& claude ' not in s: continue
    if 'try { return @(& claude @args 2>$null) } catch {' in s: ok+=1; continue
    if s.strip().startswith('try { $cv = (& claude --version 2>$null'): ok+=1; continue
    bad.append(str(i))
print(('OK' if not bad and ok==2 else 'BAD') + ' allowed=' + str(ok) + ' bare=' + ','.join(bad))
PYEOF
)"
case "$py" in OK*) r=0 ;; *) r=1 ;; esac
t $r "[ⓖ] 맨몸 \`& claude\` = 0 · 허용 자리 2(안전 호출 · 환경 수집 try)" "$py"

echo "통과 ${pass} · 실패 ${fail}"
[ "${fail}" -eq 0 ] && [ "${pass}" -gt 0 ]
