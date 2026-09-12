#!/usr/bin/env python3
# v0.3.8 뮤턴트 배터리(r4·r5) — **새 축이 눈먼 초록이 아닌지** 잰다 (2026-09-10 · 외부 검토 3차 확정분)
#
# ★왜 있는가
#   축을 새로 쓰면 그 축은 **처음부터 초록**이다. 초록인 까닭이 「고쳤기 때문」인지 「그 축이 아무것도
#   못 보기 때문」인지는 **되돌려 봐야만** 갈린다. 이 저장소에서 새 축이 눈먼 채 초록이었던 일이
#   r3 에서 세 번, r4 에서 네 번 있었다(r5 는 이 배터리로 미리 걸렀다)(정의 줄 주석까지 세기 · 두 자리 중 하나만 재기 · 문구만 재고
#   그 문구를 부르는 갈래는 안 재기 · 축 자체를 안 세우기).
#
# 쓰는 법:  python3 tests/v038-mutants.py --root <작업 폴더>
#   ⛔`--root` 는 **스냅샷 worktree** 여야 한다. 라이브 트리에서 돌리지 마라 — 이 스크립트는 파일을
#     고쳤다가 되돌리며, 중간에 죽으면 고친 채로 남는다([[reproduce-in-snapshot-worktree-not-live-tree]]).
import argparse, pathlib, subprocess, sys

_ap = argparse.ArgumentParser()
_ap.add_argument('--root', required=True, help='스냅샷 worktree 경로(라이브 트리 금지)')
WT = pathlib.Path(_ap.parse_args().root).expanduser().resolve()

# (이름, 파일, 찾을 것, 바꿀 것, 붉어져야 하는 축의 조각)
MUTANTS = [
 ("M1 맥 종료 안내를 표준출력으로 되돌린다", "install-master/reset-clean.sh",
  'tell "  cys 자리에서 도는 것을 멈춥니다:"', 'say "  cys 자리에서 도는 것을 멈춥니다:"',
  ["[②] 끄는 대상 인쇄가 그 통로로 간다", "[②] 표준출력으로 찍던 옛 형태 0건"]),
 ("M2 확인 없이 번호로만 TERM 한다", "install-master/reset-clean.sh",
  '  kill_verified TERM "$targets"', '  for pid in $(table_pids "$targets"); do kill -TERM "$pid" 2>/dev/null; done',
  ["[②] TERM·KILL 둘 다 그 확인을 거친다"]),
 ("M3 번호 비교를 통짜 부분일치로 되돌린다", "install-master/reset-clean.sh",
  '    case "$pids" in *" $pid "*) continue ;; esac', '    case "$targets" in *"$pid"*) continue ;; esac',
  ["[N5] 번호 비교가 구분자까지 맞는다", "[N5] 통짜 부분일치 옛 형태 0건"]),
 ("M4 자손 재수집을 뺀다(한 번만 모은다)", "install-master/reset-clean.sh",
  '  targets="$(add_descendants "$targets")"\n  kill_verified KILL "$targets"', '  kill_verified KILL "$targets"',
  ["[N5] 끄기 직전에 자손을 한 번 더 모은다"]),
 ("M5 맥 재진단에서 「모른다」 갈래를 뺀다", "install-master/reset-clean.sh",
  '  if [ "$PURGE_LOGIN" = "1" ] && [ "$_ls" = "unknown" ]; then', '  if [ "x" = "y" ]; then',
  ["[B1] 맥이 끝에서 「모른다」를 실패로 센다"]),
 ("M6 맥 신뢰 칸 정리를 파이프로 되돌린다", "install-master/reset-clean.sh",
  '    while IFS="$(printf \'\\t\')" read -r _cfg _key; do\n      [ -n "$_cfg" ] && [ -n "$_key" ] && strip_trust_seed "$_cfg" "$_key"\n    done <<EOF_TRUST_ROWS\n$TRUST_SEED_ROWS\nEOF_TRUST_ROWS',
  '    printf \'%s\\n\' "$TRUST_SEED_ROWS" | while IFS="$(printf \'\\t\')" read -r _cfg _key; do\n      [ -n "$_cfg" ] && [ -n "$_key" ] && strip_trust_seed "$_cfg" "$_key"\n    done',
  ["[N4] 맥이 신뢰 칸 정리를 파이프 밖에서 돈다", "[N4] 파이프로 돌던 옛 형태 0건"]),
 ("M7 정리 실패해도 작업 폴더를 지운다", "install-master/reset-clean.sh",
  '  if [ "${TRUST_CLEANUP_FAIL:-0}" -gt 0 ]; then', '  if [ 0 -gt 0 ]; then',
  ["[N4] 맥이 그 셈을 보고 작업 폴더를 남긴다"]),
 ("M8 맥 이름 관문을 뺀다", "install-master/reset-clean.sh",
  '  if [ "$(basename "$c")" != "$JARVIS_HOME_BASENAME" ]; then', '  if [ "x" = "y" ]; then',
  ["[N3] 맥도 실경로의 마지막 칸을 견준다"]),
 ("M9 윈 이름 관문을 뺀다", "install-master/reset-clean.ps1",
  '    if ($leaf -ne $JarvisHomeBaseName) {', '    if ($false) {',
  ["[N3] 윈이 실제 경로의 마지막 칸을 견준다"]),
 ("M10 윈 조상 링크 검사를 뺀다", "install-master/reset-clean.ps1",
  '    $rp = Get-ReparseAncestor $full', '    $rp = ""',
  ["[N3] 그 링크 검사를 실제로 부른다"]),
 ("M11 윈 8.3 되풀기를 뺀다", "install-master/reset-clean.ps1",
  '        $it = Get-Item -LiteralPath $full -Force -ErrorAction Stop\n        if ($it.FullName) { $full = [string]$it.FullName }', '        $full = $full',
  ["[N3] 그 되풀기가 실물을 본다"]),
 ("M12 윈 제거기의 현재값 견줌을 뺀다", "install-master/reset-clean.ps1",
  '            if ($cur.Value -ne $true) {', '            if ($false) {',
  ["[N4] 윈 제거기가 현재값을 설치값과 견준다"]),
 ("M13 윈 정리 실패 보존을 뺀다", "install-master/reset-clean.ps1",
  '    if ($script:TrustCleanupFail -gt 0) {', '    if ($false) {',
  ["[N4] 윈도 같은 판정을 한다"]),
 ("M14 맥 설치기가 표식 없는 기존 폴더를 다시 채택한다", "install-master/bootstrap.sh",
  '  refuse_jarvis_home "그 폴더는 이미 있는데 우리 표식이 없습니다(우리가 만든 자리가 아닙니다 — 지울 때 통째로 지우는 자리이므로 채택하지 않습니다)"', '  :',
  ["[N3] 맥도 표식 없는 기존 폴더를 채택하지 않는다"]),
 ("M15 맥 이름 관문을 만들기 뒤로 옮긴다", "install-master/bootstrap.sh",
  'if [ "$(basename "${JARVIS_HOME%/}")" != "$JARVIS_HOME_BASENAME" ]; then\n  refuse_jarvis_home "폴더 이름이 「${JARVIS_HOME_BASENAME}」 이 아닙니다"\nfi\n', '',
  ["[N3] 맥도 안전 검사를 만들기보다 먼저 한다", "[N3] 맥이 네 갈래(이름·이음줄·폴더 아님·표식 없음)에서 다 거부한다"]),
 # ── r5(외부 검토 4차 BLOCK 5건) ────────────────────────────────────────
 ("M24 확인표 못 뜬 번호를 빈 칸으로 표에 넣는다", "install-master/reset-clean.sh",
  '          if tok="$(proc_token "$pid" 2>/dev/null)" && [ -n "$tok" ]; then\n            printf \'%s\\t%s\\t%s\\n\' "$pid" "$tok" "$cmd"',
  '          tok="$(proc_token "$pid" 2>/dev/null)" || tok=""\n          if true; then\n            printf \'%s\\t%s\\t%s\\n\' "$pid" "$tok" "$cmd"',
  ["[②] 확인표를 못 뜬 번호는 표에 안 넣는다", "[②] 빈 칸으로 넣던 옛 형태 0건"]),
 ("M25 빈 확인표를 신호 대상으로 다시 허용한다", "install-master/reset-clean.sh",
  '    [ -n "$tok" ] || { tell "    건너뜀: 번호 $pid 는 확인표가 없어 끄지 않습니다."; continue; }\n    now="$(proc_token "$pid" 2>/dev/null)" || continue\n    if [ "$now" != "$tok" ]; then',
  '    now="$(proc_token "$pid" 2>/dev/null)" || continue\n    if [ -n "$tok" ] && [ "$now" != "$tok" ]; then',
  ["[②] 빈 확인표는 신호 대상이 아니다(두 번째 겹)", "[②] 「확인표가 있을 때만 견주던」 옛 형태 0건"]),
 ("M26 자손 훑기를 예측 가능한 임시 파일로 되돌린다", "install-master/reset-clean.sh",
  '    done <<EOF_PROC_TABLE\n$table\nEOF_PROC_TABLE',
  '    done > /tmp/.jarvis-desc.$$ 2>/dev/null || true\n    rm -f /tmp/.jarvis-desc.$$',
  ["[N5] 지우개가 예측 가능한 임시 파일을 안 쓴다", "[N5] 자손 훑기가 임시 파일 없이 돈다", "[N5] /tmp 에 만들고 지우는 자리가 없다"]),
 ("M27 맥이 「없음」과 「확인 불가」를 다시 한 칸에 담는다", "install-master/bootstrap.sh",
  '  if plutil -convert json -o /dev/null "$cfg" >/dev/null 2>&1; then',
  '  if plutil -lint "$cfg" >/dev/null 2>&1; then',
  ["[N4] 맥이 파일 성함을 JSON 이 받는 계기로 묻는다", "[N4] 맥이 JSON 을 안 받는 계기를 쓰지 않는다"]),
 ("M27b 맥이 되읽지 않고 「없다」고 단정한다", "install-master/bootstrap.sh",
  '             _verify="$(trust_key_state "$cfg" "projects.$HOME.hasTrustDialogAccepted")"',
  '             _verify="absent"',
  ["[N4] 맥이 원복을 되읽어 검증한다"]),
 ("M28 윈이 원복 결과를 안 보고 목록을 비운다", "install-master/bootstrap.ps1",
  '            $st = Undo-TrustSeed $e[0] $e[1]',
  "            Undo-TrustSeed $e[0] $e[1] | Out-Null; $st = 'verified'",
  ["[N4] 윈이 그 목록을 되돌리기 결과에 매어 둔다"]),
 ("M29 맥 열쇠고리 3상태를 두 상태로 되돌린다", "install-master/reset-clean.sh",
  '    44) printf \'absent\' ;;\n    *)  printf \'unknown\' ;;',
  '    *)  printf \'absent\' ;;',
  ["[B1] 「없음」의 근거가 errSecItemNotFound(44) 다"]),
 ("M30 셈 함수를 파이프로 되돌린다", "install-master/reset-clean.sh",
  '  dump="$(security dump-keychain 2>/dev/null)" || { printf \'\'; return 0; }\n  n="$(printf \'%s\\n\' "$dump" | grep -c',
  '  n="$(security dump-keychain 2>/dev/null | grep -c',
  ["[B1] 셈이 조회 실패를 파이프에 안 삼킨다"]),
 ("M31 윈이 표식 없는 기존 폴더를 다시 채택한다", "install-master/bootstrap.ps1",
  '        if (-not $ownerMarkOk) {\n            # 구판 지문이면',
  '        if ($false) {\n            # 구판 지문이면',
  ["[N3] 윈의 그 거부를 지키는 것이 표식 판정이다(두 갈래 다)"]),
 ("M31b 윈이 경합 갈래에서 표식 판정을 끈다", "install-master/bootstrap.ps1",
  '            if (-not $ownerMarkOk) {\n                if (Invoke-OldHomeCleanup) {',
  '            if ($false) {\n                if (Invoke-OldHomeCleanup) {',
  ["[N3] 윈의 그 거부를 지키는 것이 표식 판정이다(두 갈래 다)"]),
 ("M32 맥 설치기의 표식 판정을 끈다", "install-master/bootstrap.sh",
  '  fi\n  owner_mark_ok && return 0', '  fi\n  false && return 0',
  ["[N3] 맥의 그 거부를 지키는 것도 표식 판정이다"]),
 ("M16 윈 설치기 이름 관문을 뺀다", "install-master/bootstrap.ps1",
  '    if ((Split-Path $JarvisHome -Leaf) -ne $JarvisHomeBaseName) {', '    if ($false) {',
  ["[N3] 윈은 안전 검사를 만들기보다 먼저 한다"]),
 ("M17 윈이 쓰기 전에 소유 목록에 적는다", "install-master/bootstrap.ps1",
  '        foreach ($e in $pending) { $script:TrustSeeded += ,$e }\n        Say ', '        Say ',
  ["[R4] 윈은 쓰고 나서 소유 목록에 적는다"]),
 ("M18 윈 기록 실패 되돌리기를 뺀다", "install-master/bootstrap.ps1",
  '            $st = Undo-TrustSeed $e[0] $e[1]', "            $st = 'kept'",
  ["[N4] 윈이 기록 실패 때 그것을 실제로 부른다"]),
 ("M19 윈 기준선 게이트를 뺀다", "install-master/bootstrap.ps1",
  '    if (-not $script:BaselineOk) {', '    if ($false) {',
  ["[N2] 윈이 실패면 판정하지 않는다"]),
 ("M20 맥 기준선 게이트를 뺀다", "install-master/bootstrap.sh",
  '  if [ "$FLEET_BASELINE_OK" != "1" ]; then', '  if [ "x" = "y" ]; then',
  ["[N2] 맥도 실패면 판정하지 않는다"]),
 ("M21 맥 기록 실패 되돌리기를 뺀다", "install-master/bootstrap.sh",
  '               plutil -remove "projects.$HOME.hasTrustDialogAccepted" "$cfg" >/dev/null 2>&1', '               true',
  ["[N4] 맥이 기록 실패 때 넣은 칸을 도로 뺀다"]),
 ("M22 맥 기록 실패 표시를 단계가 안 본다", "install-master/bootstrap.sh",
  '  [ "$TRUST_JOURNAL_FAILED" = "1" ] && return 1', '  true',
  ["[N4] 맥이 그 표시를 단계 판정에서 본다"]),
 # ── v0.3.10 (외부 검토 5차 STILL OPEN 2건 + 노트북 실기 2건 + 자기신고 1건) ──
 ("M33 맥이 마지막 마디를 다시 -p 로 만든다", "install-master/bootstrap.sh",
  '  mkdir "$JARVIS_HOME" 2>/dev/null', '  mkdir -p "$JARVIS_HOME" 2>/dev/null',
  ["[N3] 맥이 마지막 마디를 -p 없이 만든다", "[N3] 맥에 -p 로 만들던 옛 형태 0건"]),
 ("M34 윈 자리 만들기에 -Force 를 붙인다", "install-master/bootstrap.ps1",
  'New-Item -ItemType Directory -Path $JarvisHome -ErrorAction Stop',
  'New-Item -ItemType Directory -Path $JarvisHome -Force -ErrorAction Stop',
  ["[N3] 윈 자리 만들기에 -Force 가 없다", "[N3] 윈이 자리 만들기를 한 자리에서만 한다"]),
 ("M35 맥 단계 문구를 다시 단정으로 되돌린다", "install-master/bootstrap.sh",
  '    say "[4/10] 홈 폴더 신뢰 기록을 남기지 못했습니다 — $(trust_rollback_words) 여기서 멈춥니다."',
  '    say "[4/10] 홈 폴더 신뢰 기록을 남기지 못했습니다 — 그 설정은 도로 뺐고, 여기서 멈춥니다."',
  ["[N4] 맥에 단정하던 옛 단계 문구 0건", "[N4] 맥 단계 두 자리가 내부 상태를 그대로 말한다"]),
 ("M36 윈이 되읽기 실패를 「아직 있다」로 뭉갠다", "install-master/bootstrap.ps1",
  '            Write-Log ("trust seed rollback UNKNOWN (되읽지 못했다): " + (Redact $cfg) + " + " + (Redact $key))\n            return \'unknown\'',
  "            return 'kept'",
  ["[N4] 윈 되읽기 실패가 바로 「확인 불가」로 간다"]),
 ("M37 맥이 사람 확인 없이 구판 폴더를 지운다", "install-master/bootstrap.sh",
  '  if [ "$answer" != "지웁니다" ]; then', '  if false; then',
  ["[구판] 맥은 사람이 친 말 뒤에만 지운다"]),
 ("M38 맥이 빈 폴더도 구판 지문으로 센다", "install-master/bootstrap.sh",
  '  [ "$known" = "1" ] && [ "$sign" = "1" ]', '  [ "$known" = "1" ]',
  ["[구판] 맥은 빈 폴더를 지문으로 세지 않는다"]),
 ("M39 맥이 못 세도 우리 구판이라 한다", "install-master/bootstrap.sh",
  '  entries="$(list_home_entries "$JARVIS_HOME")" || return 1',
  '  entries="$(list_home_entries "$JARVIS_HOME")"',
  ["[구판] 맥은 못 세면 우리 것이라 하지 않는다"]),
 ("M40 윈이 못 세도 우리 구판이라 한다", "install-master/bootstrap.ps1",
  '    if ($null -eq $names) { return $false }', '    if ($false) { return $false }',
  ["[구판] 윈도 못 세면 우리 것이라 하지 않는다"]),
 ("M41 맥 제거기가 닫기 안내를 안 부른다", "install-master/reset-clean.sh",
  '\nnotice_close_cys\n', '\n:\n',
  ["[닫기] 맥이 그 안내를 실제로 부른다"]),
 ("M42 윈 닫기 안내가 실제 판정과 떨어진다", "install-master/reset-clean.ps1",
  '$aliveNow = @(Get-ProcsUnder @($CysDir, $CysDirOld))', "$aliveNow = @('x')",
  ["[닫기] 윈 안내를 지키는 것이 실제 프로세스 판정이다"]),
 ("M43 변수 뒤 한국어 따옴표를 되돌린다", "install-master/bootstrap.sh",
  '「${JARVIS_HOME_BASENAME}」 이 아닙니다', '「$JARVIS_HOME_BASENAME」 이 아닙니다',
  ["[셸] bootstrap.sh 변수 뒤 한국어 글자 0건"]),
 ("M44 치환하다 남은 따옴표 한 글자를 되돌린다", "install-master/bootstrap.ps1",
  "                }\n                Say '        지울 때 이 칸은",
  "                }'\n                Say '        지울 때 이 칸은",
  ["[문법] ps1 셋의 괄호·따옴표가 맞는다"]),
 ("M45 맥이 이음줄이 섞인 폴더도 우리 구판이라 한다", "install-master/bootstrap.sh",
  '    [ -L "$p" ] && known=0', '    [ -L "$p" ] && known=1',
  ["[구판] 맥은 이음줄이 섞이면 우리 것이라 하지 않는다"]),
 ("M46 윈이 이음줄 검사를 뺀다", "install-master/bootstrap.ps1",
  '        if ($it.Attributes -band [IO.FileAttributes]::ReparsePoint) { return $false }',
  '        if ($false) { return $false }',
  ["[구판] 윈도 이음줄이 섞이면 우리 것이라 하지 않는다"]),
 # ── 교차 검토 1차(외부 검토 · BLOCK) 확정분 ──────────────────────────────
 ("M47 맥이 이음줄 자리를 다시 채택한다", "install-master/bootstrap.sh",
  '  if [ -L "$JARVIS_HOME" ]; then\n    refuse_jarvis_home "그 자리는 다른 곳을 가리키는 이음줄입니다',
  '  if false; then\n    refuse_jarvis_home "그 자리는 다른 곳을 가리키는 이음줄입니다',
  ["[구판] 맥은 그 자리 자신이 이음줄이면 거부한다", "[구판] 맥은 그 물음을 채택 갈래 안에서 한다"]),
 ("M48 윈이 이음줄 자리 물음을 한 갈래에서 뺀다", "install-master/bootstrap.ps1",
  '        if (Test-JarvisHomeIsLink) {\n            Deny-JarvisHome',
  '        if ($false) {\n            Deny-JarvisHome',
  ["[구판] 윈은 두 갈래(기존·경합)에서 다 묻는다"]),
 ("M49 맥이 꼬리 빗금을 그대로 둔다", "install-master/bootstrap.sh",
  'while [ "${JARVIS_HOME%/}" != "$JARVIS_HOME" ] && [ ${#JARVIS_HOME} -gt 1 ]; do',
  'while false && [ ${#JARVIS_HOME} -gt 1 ]; do',
  ["[구판] 맥이 꼬리 빗금을 걷어낸다"]),
 ("M50 맥이 부모 자리를 미리 만들지 않는다", "install-master/bootstrap.sh",
  '  if [ ! -d "$parent" ] && ! mkdir -p "$parent" 2>/dev/null; then',
  '  if false; then',
  ["[N3] 맥이 부모 자리를 미리 만든다"]),
 ("M51 윈이 부모 자리를 미리 만들지 않는다", "install-master/bootstrap.ps1",
  '        try { New-Item -ItemType Directory -Path $parent -Force -ErrorAction Stop | Out-Null } catch { return $false }',
  '        $null = $parent',
  ["[N3] 윈도 부모 자리를 미리 만든다"]),
 ("M23 윈 SID 견줌을 이름 접미사로 되돌린다", "install-master/bootstrap.ps1",
  "    $mySid = ''\n    try { $mySid = [string][System.Security.Principal.WindowsIdentity]::GetCurrent().User.Value } catch { $mySid = '' }",
  "    $mySid = ''\n    $mySid = [string]$env:USERNAME",
  ["[⑤] 윈이 현재 사용자를 SID 로 견준다"]),

 # ── v0.3.11 핫픽스로 선 축들 (2026-09-11) ──────────────────────
 #   이 넷은 **오늘 새로 쓴 축**이다 ⇒ 되돌려 붉어지는지 재지 않으면 눈먼 초록인지 알 수 없다.
 ("M52 맥 받을 자리를 최신만 두는 폴더로 되돌린다", "install-master/bootstrap.sh",
  'CYS_DOWNLOAD_DIR="https://github.com/idoforgod/cys-terminal/releases/download/v${CYS_VERSION}/"',
  'CYS_DOWNLOAD_DIR="https://www.cysinsight.com/downloads/"',
  ["[핀] 맥은 판본이 박힌 자리에서 받는다", "[핀] 최신만 두는 배포 폴더를 안 쓴다"]),
 # ★「막지 말아야 할 것」 쪽 뮤턴트다 — 갈래를 넓히면 **망 단절까지 삼켜** 기다리지 않게 된다.
 #   새 방어가 제 범위를 넘는 것을 재는 축이 실제로 보는지 확인한다(r8 이월 규율).
 ("M53 없는 자리 갈래를 모든 실패로 넓힌다", "install-master/bootstrap.sh",
  '      case "$code" in\n        404|410)',
  '      case "$code" in\n        *)',
  ["[핀] 없는 자리 갈래는 404·410 에만 걸린다", "[핀] 없는 자리 갈래 뒤에도 망 기다림이 남아 있다"]),
 ("M54 받을 자리에 뭐라 답하는지 묻지 않는다", "install-master/bootstrap.sh",
  '      code="$(cys_http_code "$CYS_DOWNLOAD_URL")"',
  '      code="000"',
  ["[핀] 받기 실패 자리에서 그것을 부른다"]),
 ("M55 맥이 받은 파일의 지문을 잰 척한다", "install-master/bootstrap.sh",
  '      fresh="$(cys_file_sha256 "$dst")"',
  '      fresh="$CYS_MAC_SHA256"',
  ["[핀] 지문을 두 자리에서 본다(남아 있던 것·방금 받은 것)"]),
]

def run_checks(root):
    r = subprocess.run(['bash','install-master/checks.sh'], cwd=root, capture_output=True, text=True)
    return r.stdout

def main():
    base = run_checks(WT)
    red_base = {ln for ln in base.split('\n') if ln.startswith('  FAIL')}
    print("기준선 적색 %d개(사이트 사본)" % len(red_base))
    bad = 0
    for name, rel, old, new, axes in MUTANTS:
        f = WT / rel
        orig = f.read_text(encoding='utf-8')
        if old not in orig:
            print("SKIP-BROKEN  %-45s ← 앵커를 못 찾았다(뮤턴트가 낡았다)" % name); bad += 1; continue
        f.write_text(orig.replace(old, new, 1), encoding='utf-8')
        try:
            out = run_checks(WT)
            reds = [ln for ln in out.split('\n') if ln.startswith('  FAIL')]
            got = []
            for ax in axes:
                if any(ax in ln for ln in reds): got.append(ax)
            if len(got) == len(axes):
                print("붉음  %-45s ← %s" % (name, ' · '.join(axes)))
            else:
                miss = [a for a in axes if a not in got]
                print("눈멂  %-45s ← 안 붉어진 축: %s" % (name, ' | '.join(miss))); bad += 1
        finally:
            f.write_text(orig, encoding='utf-8')
    after = run_checks(WT)
    if {ln for ln in after.split('\n') if ln.startswith('  FAIL')} != red_base:
        print("::경고:: 원복 뒤 적색 집합이 기준선과 다르다"); bad += 1
    print("\n뮤턴트 %d개 · 눈먼 축 %d개" % (len(MUTANTS), bad))
    return 1 if bad else 0

sys.exit(main())
