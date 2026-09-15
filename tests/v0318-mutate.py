#!/usr/bin/env python3
# 뮤턴트 — v0.3.18 수정이 「실제로 서 있는가」를 재는 도구 (tests/v0318-emu-run.sh 러너 기준)
#
# ★쓰는 법
#   python3 tests/v0318-mutate.py --root <저장소>           전건(사본에서만 고친다 · 실물 무접촉)
#   python3 tests/v0318-mutate.py --root <저장소> --audit   앵커가 아직 1곳씩 걸리는가만
#
# ★판정 = 기준선(변이 없음)에서 **초록**이던 축이, 변이를 넣은 사본에서 **붉어졌는가**.
# ★앵커가 1곳이 아니면 조용히 지나가지 않는다(rc 3).
# ★변이가 사본에 실제로 들어갔는지(바뀐 바이트가 있는지) 확인한 뒤에만 잰다.
# ★기준선 러너가 전건 통과(rc 0)가 아니면 재지 않는다(rc 2) — 측정이 죽은 것을 「눈멂」으로 세지 않는다.
# ⚠판정은 러너 출력의 「  FAIL 」 줄에 기대 축 이름이 있는가로 한다(러너의 rc 가 아니라).
import argparse, os, pathlib, shutil, subprocess, sys, tempfile

for _s in (sys.stdout, sys.stderr):
    try: _s.reconfigure(encoding="utf-8", errors="backslashreplace")
    except Exception: pass

PS = "install-master/bootstrap.ps1"
RS = "install-master/reset-clean.ps1"
SH = "install-master/bootstrap.sh"
# (이름, 파일, 찾을 것, 바꿀 것, 붉어져야 할 축 조각)
MUTANTS = [
    # ⑨ 목록으로 가르지 않으면 좌석과 무관한 실패도 막는다 → 3차 실기의 폴백 결말로 되돌아간다
    ("seat-list-bypass", PS,
     "        if ($SeatFatalItems -contains $name) { $fatal += $name } else { $minor += $name }\n",
     "        $fatal += $name\n",
     "[⑨ 주의만]"),
    # ⑨ 항목 줄을 못 읽을 때의 되돌아가기가 빠지면 모르는 채 통과시킨다
    ("seat-summary-fallback-drop", PS,
     "    if ($items.Count -gt 0) { $seatBad = $fatal.Count } else { $seatBad = $bad }\n",
     "    $seatBad = $fatal.Count\n",
     "[⑨ 못 읽음]"),
    # ⑨ 못 읽은 실패 줄을 막는 쪽으로 세지 않으면 모양이 다른 실패가 통과한다
    ("seat-unread-drop", PS,
     "    if (($items.Count -gt 0) -and ($unread -gt 0)) { $seatBad += $unread }\n",
     "",
     "[⑨ 못 읽은 실패]"),
    # ⑨ 막는 갈래 자체가 빠지면 필요한 항목이 실패여도 이어 간다
    ("seat-block-drop", PS,
     "    if ($seatBad -gt 0) {\n        Say \"[8/10] 자가진단에서 $bad 가지가 통과하지 못했습니다.\"\n",
     "    if ($false) {\n        Say \"[8/10] 자가진단에서 $bad 가지가 통과하지 못했습니다.\"\n",
     "[⑨ 막음]"),
    # ① 판본 비교가 빠지면(앞 판 = 몸통만 보고 건너뜀) 옛 판 기기에 새 판이 안 들어간다
    ("ver-compare-drop", PS,
     "    $b0 = Test-CysBody\n    if ($b0.Body) {\n        $have0 = Get-CysInstalledVersion $b0\n        if ($have0 -eq $CysVersion) {\n            $cs0 = Get-CysContentState $b0\n",
     "    $b0 = Test-CysBody\n    if ($b0.Body) { Say '[6/10] cys 가 이미 설치돼 있습니다 — 건너뜁니다.'; return 0 }\n    if ($false) {\n        $have0 = Get-CysInstalledVersion $b0\n        if ($have0 -eq $CysVersion) {\n            $cs0 = Get-CysContentState $b0\n",
     "[① 옛 판]"),
    # ① 덮어 깐 뒤 몸통만 보고 마쳤다고 하면 판본이 안 바뀐 실패가 성공으로 보인다
    ("ver-done-by-body", PS,
     "            if ($bNow.Body -and ((-not $upgradeFrom) -or ((Get-CysInstalledVersion $bNow) -eq $CysVersion)) -and ((-not $refresh) -or ($p.HasExited -and $p.ExitCode -eq 0))) {",
     "            if ($bNow.Body) {",
     "[① 덮어 깔기 실패]"),
    # ② 같은 판 건너뛰기가 빠지면 132MB 를 다시 받는다
    ("dl-same-skip-drop", PS,
     "        if ($have0 -eq $CysVersion) {\n            # v0.3.18 — 같은 판번이어도",
     "        if ($false) {\n            # v0.3.18 — 같은 판번이어도",
     "[② 같은 판·같은 지문]"),
    # ④ 기록을 기본 글자표(Add-Content)로 되돌리면 윈 5.1 에서 「→」·한글이 UTF-8 로 안 적힌다
    ("log-add-content", PS,
     "    try { [System.IO.File]::AppendAllText($LogFile, \"$ts $msg\" + [Environment]::NewLine, (New-Object System.Text.UTF8Encoding $false)) } catch { }\n",
     "    Add-Content -Path $LogFile -Value \"$ts $msg\"\n",
     "[④ 기록 글자표]"),
    # ④ 지난 실행 꼬리를 기본 글자표로 읽으면 UTF-8 로 적은 한글 줄을 못 알아본다
    ("prev-read-encoding-drop", PS,
     "Get-Content $LogFile -ErrorAction SilentlyContinue -Encoding UTF8 |",
     "Get-Content $LogFile -ErrorAction SilentlyContinue |",
     "[④ 지난 실행]"),
    # ⑤ 구문 판정이 빠지면(앞 판 글자 필터만) 네 형태가 「참고 오류」로 적힌다
    ("quiet-ast-drop", PS,
     "    if (-not $file -or $ln -le 0 -or $col -le 0) { return $lineQuiet }\n",
     "    return $lineQuiet\n",
     "[⑤ 조용한 형태]"),
    # ⑤ 바깥 명령으로 올라가 보지 않으면 & { … } 2>$null 로 막은 오류가 참고 오류로 적힌다(교차 검토 1R F4)
    ("quiet-parent-walk-drop", PS,
     "    for ($node = $hit; $node; $node = $node.Parent) {\n",
     "    for ($node = $hit; $node; $node = $null) {\n",
     "[⑤ 조용한 형태]"),
    # ⑤ 줄 글자 필터를 앞에서 먼저 쓰면 같은 줄의 다른 명령 -EA 로 조용하지 않은 오류가 거짓 통과한다(교차 검토 1R F3)
    ("quiet-line-fastpath-back", PS,
     "    $file = [string]$ii.ScriptName; $ln = [int]$ii.ScriptLineNumber; $col = [int]$ii.OffsetInLine\n",
     "    if ($lineQuiet) { return $true }\n    $file = [string]$ii.ScriptName; $ln = [int]$ii.ScriptLineNumber; $col = [int]$ii.OffsetInLine\n",
     "[⑤ 섞임]"),
    # ⑥ [7/10] 의 호출이 빠지면 새 창에서 cys 를 못 찾는다
    ("cys-path-call-drop", PS,
     "        if ($b.Cli -and ((Split-Path $b.Cli -Leaf) -ieq 'cys.exe')) { [void](Seed-CysPath (Split-Path $b.Cli -Parent)) }\n",
     "",
     "[⑥ 부르는 자리]"),
    # ⑥ 같은 자리 확인이 빠지면 실행할 때마다 사용자 PATH 에 cys 자리가 쌓인다
    ("cys-path-dedup-drop", PS,
     "-ieq $want) { $have = $true; break }",
     "-ieq $want) { }",
     "[⑥ 멱등]"),
    # ⑥ 지우개가 -KeepApp 에서도 cys 자리를 빼면 남긴 프로그램을 새 창에서 못 부른다
    ("reset-keepapp-path-drop", RS,
     "    if (-not $KeepApp) { $d += $CysDir.TrimEnd('\\'); $d += $CysDirOld.TrimEnd('\\') }\n",
     "    $d += $CysDir.TrimEnd('\\'); $d += $CysDirOld.TrimEnd('\\')\n",
     "[⑥ 지우는 쪽]"),
    # ③ 화면 줄에 ⚠ 가 돌아오면 윈 5.1 콘솔에서 그 절 뒤 줄들이 겹쳐 찍힌다
    ("reset-emoji-back", RS,
     "        Write-Host '         주의: 이것은 위의 「cys 계정 자리」 안에 들어 있어 **함께 지워집니다.**'\n",
     "        Write-Host '         ⚠이것은 위의 「cys 계정 자리」 안에 들어 있어 **함께 지워집니다.**'\n",
     "[③ 기호 이모지] reset-clean.ps1"),
    # ── v0.3.18 final (installer-v0318-final) ──
    # 이중 대조: [5/10] 이 판번만 보고 건너뛰면 같은 판번으로 다시 발행한 빌드가 안 닿는다
    ("dl-version-only-skip", PS,
     "            if ($cs0 -eq 'match') { Say \"[5/10]",
     "            if ($true) { Say \"[5/10]",
     "[이중 대조 · 핀 바뀜]"),
    # 이중 대조: [6/10] 이 판번만 보고 건너뛰면 받아 놓고도 덮어 깔지 않는다
    ("install-version-only-skip", PS,
     "            if ($cs0 -eq 'match') { Say \"[6/10]",
     "            if ($true) { Say \"[6/10]",
     "[이중 대조 · 핀 바뀜]"),
    # 표지의 핀 지문 대조가 빠지면 핀이 바뀐 것을 모른다
    ("pin-compare-drop", PS,
     "    if ([string]$st.setup_sha256 -cne [string]$CysWinSha256) { return 'pin-changed' }\n",
     "",
     "[이중 대조 · 핀 바뀜]"),
    # 깔린 cys.exe 실측 지문 대조가 빠지면 다른 경로로 깔린 같은 판번의 다른 파일을 모른다
    ("exe-compare-drop", PS,
     "    if ($exeSha -cne ([string]$st.exe_sha256).ToLower()) { return 'exe-changed' }\n",
     "",
     "[이중 대조 · 깔린 파일 다름]"),
    # 같은 판을 덮어 깔 때 설치기 성공(0) 확인이 빠지면 판번이 처음부터 같아 실패가 성공으로 보인다
    ("refresh-exitcode-drop", PS,
     " -and ((-not $refresh) -or ($p.HasExited -and $p.ExitCode -eq 0))) {",
     ") {",
     "[이중 대조 · 덮어 깔기 실패]"),
    # 설치 뒤 표지를 안 남기면 다음 실행이 매번 다시 받는다
    ("stamp-save-drop", PS,
     "                [void](Save-CysPinStamp $bNow)\n",
     "",
     "[① 옛 판]"),
    # 표지를 작업 폴더에 두면 재설치(-KeepApp)가 지워 ② 건너뜀이 죽는다 — 설치 자리에 둬야 한다
    ("stamp-in-workdir", PS,
     "    if ($b -and $b.Path) { return (Join-Path $b.Path 'jarvis-cys-pin.json') }",
     "    if ($b -and $b.Path) { return (Join-Path $JarvisHome 'jarvis-cys-pin.json') }",
     "[② 같은 판·같은 지문]"),
    # 보안 경계: 웹 표식을 지문 대조 **전에** 지우면 모르는 파일의 경고까지 지운다
    ("motw-before-verify", PS,
     "        $hash = Get-CysFileSha256 $dst\n",
     "        [void](Clear-WebMark $dst 'early')\n        $hash = Get-CysFileSha256 $dst\n",
     "[MOTW 경계]"),
    # 지문 확인 뒤 표식 해제 호출이 빠지면 SmartScreen 손 1 이 그대로 남는다
    ("motw-call-drop", PS,
     "        if ($hash -eq $CysWinSha256) { [void](Clear-WebMark $dst 'cys setup'); Say",
     "        if ($hash -eq $CysWinSha256) { Say",
     "[MOTW 해제]"),
    # 대기 표지 전송이 빠지면 서버가 [6/10] 정체를 못 알아본다
    ("heartbeat-drop", PS,
     "                Send-Progress '6/10' 'wait' ([int]($waitedMs / 1000)) $null $null\n",
     "",
     "[대기 표지]"),
    # 조각을 상한으로 자르지 않으면 마지막 조각이 상한을 넘겨 기다린다
    ("heartbeat-chunk-cap-drop", PS,
     "                $chunk = [Math]::Min(60000, $limit - $waitedMs)\n",
     "                $chunk = 60000\n",
     "[대기 표지]"),
    # 클로드 설치 인자가 latest 로 돌아가면 참가자 화면이 자동 판올림으로 바뀐다
    ("channel-arg-drop", PS,
     "\"& ([scriptblock]::Create((irm '$ClaudeInstallUrl' -UseBasicParsing))) $ClaudeChannel\")",
     "\"irm '$ClaudeInstallUrl' | iex\")",
     "[stable 설치]"),
    # 설정 열쇠가 빠지면 이미 깔린 클로드는 latest 채널을 따른다
    ("settings-channel-drop", PS,
     "        $o | Add-Member -NotePropertyName autoUpdatesChannel -NotePropertyValue $ClaudeChannel -Force\n",
     "",
     "[stable 설정]"),
    # 맥 설치 인자가 빠지면 맥 참가자만 latest 로 깔린다
    ("mac-channel-drop", SH,
     "curl -fsSL --max-time 600 \"$CLAUDE_INSTALL_URL\" | bash -s \"$CLAUDE_CHANNEL\" ) || rc=$?",
     "curl -fsSL --max-time 600 \"$CLAUDE_INSTALL_URL\" | bash ) || rc=$?",
     "[stable 맥]"),
    # 오진 문구가 돌아오면 좌석 무관 항목이 기록·보고에서 「실패」로 읽힌다
    ("minor-wording-back", PS,
     "Say ('     참고: 자가진단 ' + $minor.Count + ' 가지는 자비스 창과 무관한 항목이라 이어 갑니다 ('",
     "Say ('     주의: 자가진단 ' + $minor.Count + ' 가지가 통과하지 못했습니다 ('",
     "[⑨ 주의만]"),
    # 머리글이 핀 변수를 안 쓰면 판을 올려도 화면 표기가 옛 판이다
    ("header-pin-drop", PS,
     "Say \"=== 자비스 설치 도우미 — $CysDisplayName $CysVersion · 설치 도우미 $InstallerVersion (모드: $Mode) ===\"",
     "Say \"=== 자비스 설치 도우미 $BootstrapVersion (모드: $Mode) ===\"",
     "[머리글 윈]"),
    # ── 증거 이벤트(evidence · 진행 전송 계약의 증거 절) ──
    # 마스킹 식이 대조표와 한 글자라도 갈리면 같은 입력 → 같은 출력이 깨진다
    ("mask-rule-drift", PS,
     "    @('\\bsk-[A-Za-z0-9_-]{8,}', '<TOKEN>'),\n",
     "    @('\\bsk-[A-Za-z0-9_-]{9,}', '<TOKEN>'),\n",
     "[마스킹 벡터]"),
    # 표시된 이름 수집이 빠지면 USERNAME=… 로 알려진 이름이 본문에 남는다
    ("mask-harvest-drop", PS,
     "    if ($names.Count -gt 0) {\n        $alt =",
     "    if ($false) {\n        $alt =",
     "[마스킹 벡터]"),
    # 보내기 전 마스킹을 건너뛰면 개인 정보가 기계 밖으로 나간다
    ("evidence-mask-skip", PS,
     "    $masked = Protect-EvidenceText $raw\n",
     "    $masked = $raw\n",
     "[증거 · 마스킹]"),
    # [6/10] 정체 문턱의 증거 호출이 빠지면 3분 넘게 선 설치의 창 글자가 안 온다
    ("evidence-stall-drop", PS,
     "                if ($waitedMs -ge 180000) { Send-EvidenceOnce 'stall' }   # 대기 3분 이상 = 정체 증거\n",
     "",
     "[증거 · 정체]"),
    # 한 번만 보내는 막이 빠지면 3분 뒤 매 조각마다 증거가 쌓인다(설치당 분당 30 한도를 먹는다)
    ("evidence-once-drop", PS,
     "        if ($script:EvidenceSent.ContainsKey($key)) { return }\n",
     "",
     "[증거 · 정체]"),
    # 문턱이 빠지면 3분 전부터 증거를 보낸다
    ("evidence-threshold-drop", PS,
     "                if ($waitedMs -ge 180000) { Send-EvidenceOnce 'stall' }   # 대기 3분 이상 = 정체 증거\n",
     "                Send-EvidenceOnce 'stall'\n",
     "[증거 · 정체 문턱]"),
    # 실패(진단 코드) 자리의 증거 호출이 빠지면 실패 증거가 안 온다
    ("evidence-fail-drop", PS,
     "    Send-EvidenceOnce 'fail'   # v0.3.18 — 실패 증거(설치 창 끝부분 · 마스킹 뒤)\n",
     "",
     "[증거 · 실패]"),
    # 추가 칸이 본문에 안 실리면 서버가 evidence 를 400 으로 버린다
    ("progress-extra-drop", PS,
     "        if ($null -ne $extra)   { foreach ($k in @($extra.Keys)) { $fields[[string]$k] = $extra[$k] } }\n",
     "",
     "[증거 · 본문 칸]"),
    # ── 맥 로그인 코드 자동 넣기(ⓗ) ──
    # 로그인을 열기 전 복사돼 있던 코드를 거르지 않으면 지난 시도의 낡은 코드가 들어간다
    ("mac-clip-base-drop", SH,
     "      if login_code_shape \"$clip\" && [ \"$clip\" != \"$base\" ] && [ \"$clip\" != \"$last\" ]; then\n",
     "      if login_code_shape \"$clip\" && [ \"$clip\" != \"$last\" ]; then\n",
     "[맥 로그인 · 복사 전 코드]"),
    # 로그인 프로세스가 끝났는지 안 보면 넣는 쪽이 영영 안 끝나 설치가 선다
    ("mac-feeder-exit-drop", SH,
     "    if [ -n \"$pid\" ] && ! kill -0 \"$pid\" 2>/dev/null; then break; fi   # 로그인 프로세스가 끝났다 → 넣기를 멈춘다\n",
     "",
     "[맥 로그인 · 끝남]"),
    # 복사된 코드를 넣는 줄이 빠지면 자동 넣기가 안 된다
    ("mac-clip-send-drop", SH,
     "        printf '%s\\n' \"$clip\" || break\n",
     "        : \n",
     "[맥 로그인 · 새 코드]"),
    # 반복 상한 255 를 넘는 식으로 되돌리면 맥 bash 3.2 에서 모양 판정이 늘 거짓이다
    ("mac-shape-dupmax-back", SH,
     "  [[ \"$s\" =~ ^[A-Za-z0-9._~-]+#[A-Za-z0-9._~-]+$ ]] || return 1\n",
     "  [[ \"$s\" =~ ^[A-Za-z0-9._~-]{16,512}#[A-Za-z0-9._~-]{16,512}$ ]] || return 1\n",
     "[맥 로그인 · 새 코드]"),
    # 자리표(sentinel)를 건너뛰고 표식을 곧바로 쓰면 이름 치환이 C:\Users\ 접두사·<EMAIL> 표식을 뭉갠다(대조표 order_dependency_3·4)
    ("mask-sentinel-drop", PS,
     "            return ([string][char]0 + 'M' + ($sentinels.Count - 1) + [string][char]0)\n",
     "            return $res\n",
     "[마스킹 벡터]"),
    # 이름을 구조 규칙보다 먼저 지우면 hong@… 이 <USER>@… 가 된다(order_dependency_1)
    ("mask-names-before-rules", PS,
     "    $sentinels = New-Object System.Collections.Generic.List[string]\n    $text = $Raw\n",
     "    $sentinels = New-Object System.Collections.Generic.List[string]\n    $text = $Raw\n    if ($names.Count -gt 0) { $text = [regex]::Replace($text, (@($names | ForEach-Object { [regex]::Escape($_) }) -join '|'), '<USER>') }\n",
     "[마스킹 벡터]"),
]


def copy_tree(root, dst):
    for d in ("install-master", "tests"):
        shutil.copytree(root / d, dst / d, symlinks=True)


def run(tree):
    r = subprocess.run(["bash", "tests/v0318-emu-run.sh"], cwd=tree, env=dict(os.environ),
                       capture_output=True, text=True, stdin=subprocess.DEVNULL)
    return r.returncode, [l for l in r.stdout.split("\n") if l.startswith("  FAIL")], r.stdout + r.stderr


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--root", required=True)
    ap.add_argument("--audit", action="store_true")
    a = ap.parse_args()
    root = pathlib.Path(a.root).expanduser().resolve()
    broken = 0
    for name, rel, old, new, axis in MUTANTS:
        n = (root / rel).read_text(encoding="utf-8-sig").count(old)
        if n != 1:
            print("앵커 %d곳 ✗ %-28s %s" % (n, name, rel)); broken += 1
    if broken:
        print("::error::앵커가 1곳이 아닌 뮤턴트 %d개 — 뮤턴트가 낡았다" % broken); return 3
    if a.audit:
        print("앵커 전건 1곳 — 뮤턴트 %d개 대조 가능" % len(MUTANTS)); return 0
    base_tmp = pathlib.Path(tempfile.mkdtemp(prefix="v0318-mut-base-"))
    try:
        copy_tree(root, base_tmp)
        brc, base, bout = run(base_tmp)
    finally:
        shutil.rmtree(base_tmp, ignore_errors=True)
    if brc != 0:
        print("잴 수 없음 — 기준선 러너 rc %d (전건 통과가 아니다)" % brc)
        print(bout[-600:])
        return 2
    print("기준선 — 러너 rc 0 · 적색 %d줄" % len(base))
    bad = 0
    for name, rel, old, new, axis in MUTANTS:
        tmp = pathlib.Path(tempfile.mkdtemp(prefix="v0318-mut-"))
        try:
            copy_tree(root, tmp)
            p = tmp / rel
            raw = p.read_bytes()
            bom = raw[:3] == b"\xef\xbb\xbf"
            text = raw.decode("utf-8-sig")
            mutated = text.replace(old, new, 1)
            if mutated == text:
                print("미적용 %-28s ← 변이가 들어가지 않았다" % name); bad += 1; continue
            p.write_bytes((b"\xef\xbb\xbf" if bom else b"") + mutated.encode("utf-8"))
            if p.read_bytes() == raw:
                print("미적용 %-28s ← 쓴 뒤에도 바이트가 같다" % name); bad += 1; continue
            _, reds, _ = run(tmp)
            if any(axis in l for l in reds):
                print("붉음  %-28s ← %s" % (name, axis))
            else:
                print("눈멂  %-28s ← 안 붉어진 축: %s (그때 붉은 줄 %d)" % (name, axis, len(reds))); bad += 1
            for l in reds[:4]:
                print("        " + l.strip())
        finally:
            shutil.rmtree(tmp, ignore_errors=True)
    print("\n뮤턴트 %d개 · 실패(눈멂·미적용) %d개" % (len(MUTANTS), bad))
    return 1 if bad else 0


sys.exit(main())
