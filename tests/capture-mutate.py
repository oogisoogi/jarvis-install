#!/usr/bin/env python3
# 뮤턴트 — 캡처 증거(TICKET=installer-capture-evidence · 2026-09-16)가 「실제로 재지고 있는가」를 재는 도구
#
# ★쓰는 법
#   python3 tests/capture-mutate.py --root <저장소>           전건(사본에서만 고친다 · 실물 무접촉)
#   python3 tests/capture-mutate.py --root <저장소> --audit   앵커가 아직 1곳씩 걸리는가만
#   python3 tests/capture-mutate.py --root <저장소> --only a,b 이름을 골라서
#
# ★판정 = 기준선(변이 없음)에서 **초록**이던 축이, 변이를 넣은 사본에서 **붉어졌는가**(awaken-mutate.py 와 같은 규칙).
#   기준선에서 이미 붉은 축을 기대로 쓰면 「공짜 적색」이라 실격 · 앵커가 1곳이 아니면 rc 3 · 변이가 안 들어갔으면 측정 실패.
# ⚠판정은 러너 출력의 「  FAIL 」 줄에 기대 축 이름이 있는가로 한다 — 러너가 죽으면 FAIL 줄이 없어 「눈멂」으로 드러난다.
import argparse, os, pathlib, shutil, subprocess, sys, tempfile

for _s in (sys.stdout, sys.stderr):
    try: _s.reconfigure(encoding="utf-8", errors="backslashreplace")
    except Exception: pass

PS = "install-master/bootstrap.ps1"
SH = "install-master/bootstrap.sh"
CAP = "tests/capture-evidence-run.sh"
AWK = "tests/awaken-emu-run.sh"
# (이름, 파일, 찾을 것, 바꿀 것, 붉어져야 할 축 조각, 어느 러너로 재는가)
# ⚠러너가 둘인 까닭: ⓕ② 재시도 촉발은 **[10/10] 각성 흐름 안에서만** 일어나 캡처 러너로는 못 잰다.
#   한 러너로 다 재려고 하면 그 축이 조용히 안 재진 채 초록이 된다.
MUTANTS = [
    # ⓐ-2 전체 화면으로 되돌림 — 쓰시는 분의 다른 창이 함께 나간다
    ("fullscreen-back", PS,
     "    [void](Send-Attachment 'screen_png' 'installer-window.jpg' (Get-InstallerWindowJpeg))",
     "    [void](Send-Attachment 'screen_png' 'screen.jpg' (Get-ScreenJpeg))",
     "[전체화면] 부르는 자리가 0 이다", CAP),
    # ⓑ 끝난 뒤 증거를 한 자리에서 뺀다 — 카드 뒤에 선 끝은 조용히 증거가 없어진다
    ("postinstall-drop", PS,
     "        Send-PostInstallEvidence $cli $SurfaceRef   # ⓑ v0.3.20 — 카드 뒤에 선 끝도 같은 증거를 보낸다\n",
     "",
     "[post-install] 성공 두 자리(자동·카드 뒤)에서 부른다", CAP),
    # ⓑ 훅 오류를 세지 않는다 — 09-16 실기에서 아무도 못 본 바로 그 줄이 다시 안 보인다
    ("hook-count-zero", PS,
     "    $hook = @($lines | Where-Object { $_ -match $EvidenceHookErrorPattern }).Count",
     "    $hook = 0",
     "[post-install] seat=master · 훅 오류 3줄 · 끝 40줄 · 마스킹", CAP),
    # ⓑ 끝 40줄 자르기를 없앤다 — 화면 전체가 나간다
    ("tail40-drop", PS,
     "    $from = [math]::Max(0, $lines.Count - 40)\n    $hook =",
     "    $from = 0\n    $hook =",
     "[post-install] seat=master · 훅 오류 3줄 · 끝 40줄 · 마스킹", CAP),
    # 그림 보내기가 죽으면 설치가 함께 죽는다(fail-open 파기)
    ("failopen-drop", PS,
     "    } catch {\n        # 🔴429 는 두 종류다",
     "    } catch { throw\n        # 🔴429 는 두 종류다",
     "[fail-open] 서버가 거절해도 설치가 이어진다", CAP),
    # 429 두 종류를 안 가른다 — 잠시 뒤 다시 올려도 되는 것까지 접어 버린다
    ("429-split-drop", PS,
     "        if ($code -eq 429 -and $errText -match 'image_cap') {",
     "        if ($code -eq 429) {",
     "[429] rate_limited 는 접지 않는다", CAP),
    # ⓕ① 문턱을 2배에서 1배로 — 보통 기계가 늘 「느리다」가 된다
    ("slow-threshold", PS,
     "    return ($Sec -gt ($b * 2))",
     "    return ($Sec -gt $b)",
     "[기준선] 딱 2배는 촉발하지 않는다(초과여야 한다)", CAP),
    # ⓕ① 「모름」을 「느림」으로 읽는다 — master 결정(빈 표 = 꺼짐)의 정반대
    ("slow-unknown-true", PS,
     "    if (-not $script:StepBaselineSec.ContainsKey($Step)) { return $false }",
     "    if (-not $script:StepBaselineSec.ContainsKey($Step)) { return $true }",
     "[기준선] 표가 비면 아무리 느려도 촉발하지 않는다(모름 ≠ 느림)", CAP),
    # ⓕ 설치당 장수 상한을 없앤다 — 오류 글이 쏟아지는 실기에서 그림이 끝없이 나간다
    ("image-cap-drop", PS,
     "    if ($script:EvidenceImageSent -ge $EvidenceImageCap) { Write-Log ('evidence image skip (설치당 ' + $EvidenceImageCap + '장 상한): ' + $Kind); return $false }\n",
     "",
     "[그림] 설치당 12장에서 멈춘다", CAP),
    # 한 장 상한을 없앤다
    ("image-size-cap-drop", PS,
     "    if ($Bytes.Length -gt $EvidenceImageMaxBytes) { Write-Log ('evidence image skip (' + $Bytes.Length + 'B > 한 장 상한): ' + $Kind); return $false }\n",
     "",
     "[그림] 1.5MB 넘는 한 장은 보내지 않는다", CAP),
    # 계약에 없는 종류를 그대로 올린다 — 전체 화면을 app_window 로 이름 붙여 보내는 길이 열린다
    ("kind-allow-drop", PS,
     "    if ($EvidenceImageKinds -notcontains $Kind) { Write-Log ('evidence image skip (계약에 없는 종류): ' + $Kind); return $false }\n",
     "",
     "[종류] 계약에 없는 종류는 올리지 않는다", CAP),
    # 모르는 종류에 전체 화면을 내준다(계약이 가장 크게 금하는 것)
    ("unknown-kind-fullscreen", PS,
     "        default            { Write-Log ('evidence image skip (모르는 종류): ' + $Kind); return $null }",
     "        default            { return (Get-ScreenJpeg) }",
     "[종류] 모르는 종류에 전체 화면을 내주지 않는다", CAP),
    # 자리(토큰) 없이도 올리려 든다 — 두 걸음의 첫 걸음을 건너뛴다
    ("slot-guard-drop", PS,
     "    if ($null -eq $Slot -or -not $Slot.Token) { return $false }\n",
     "",
     "[두 걸음] 자리가 없으면 그림을 올리지 않는다", CAP),
    # 빈 글을 칸에 넣어 보낸다(서버는 400 으로 거절한다)
    ("empty-text-send", PS,
     "        if ($Text) { $fields['text'] = [string]$Text; $fields['masked'] = $true }",
     "        $fields['text'] = [string]$Text; $fields['masked'] = $true",
     "[글자] 빈 글을 칸에 넣어 보내지 않는다", CAP),
    # median 이 null 인 칸을 0 으로 읽어 채운다 — 「아직 모른다」가 「0초」가 된다
    # ⚠앞 판은 이 줄을 **지우기만** 했는데 아래 TryParse 가 같은 일을 해 답이 안 바뀌었다(등가 변이 · 2026-09-16 실측).
    #   ⇒ 계약이 실제로 경고한 실패 모양(모르는 칸을 내장 기본값으로 채우기)으로 바꿨다.
    ("baseline-null-fill", PS,
     "            if ($null -eq $row.median_elapsed_s) { continue }",
     "            if ($null -eq $row.median_elapsed_s) { $script:StepBaselineSec[$step] = 30.0; $n++; continue }",
     "[기준선] median 이 null 인 칸은 내장 기본값으로 대신하지 않는다", CAP),
    # 촬영 요청을 들고 있는다 — 1회성이 아니게 되어 같은 요청이 되풀이된다
    ("capreq-keep", PS,
     "    $script:CaptureRequested = $null   # 1회성\n",
     "",
     "[촬영 요청] 쓰고 버린다(1회성 · 들고 있지 않는다)", CAP),
    # 모르는 종류를 걸러내지 않는다 — 요청에 실려 온 이름을 그대로 믿는다
    ("capreq-kind-filter-drop", PS,
     "        $kinds = @(@($Req.kinds) | Where-Object { $EvidenceImageKinds -contains [string]$_ })   # 모르는 이름은 **그것만** 건너뛴다",
     "        $kinds = @(@($Req.kinds))",
     "[촬영 요청] 진행 답으로 받고 모르는 종류는 그것만 건너뛴다", CAP),
    # 바이트 묶음 못 박기를 뺀다 — 본문이 숫자 글자로 나가 내용이 어긋난 채 닿는다(2026-09-16 실측 결함)
    ("bytes-cast-drop", PS,
     "    if ($null -ne $Bytes) { $Bytes = [byte[]]$Bytes }\n",
     "",
     "[그림] 종류로 골라 온 그림도 바이트가 글자 그대로 닿는다", CAP),
    # ⓕ③ 사유 글 마스킹을 없앤다 — 콘솔 줄에 실린 메일·집 경로가 그대로 나간다
    ("detail-mask-drop", PS,
     "            $head = Get-RemoteHelpTailBytes (Protect-EvidenceText ('[' + $Reason + '] ' + $Detail)) 400",
     "            $head = '[' + $Reason + '] ' + $Detail",
     "[ⓕ③] 촉발 사유 글이 마스킹된 채 나간다", CAP),
    # 맥판에서 끝난 뒤 증거를 뺀다
    ("mac-postinstall-drop", SH,
     '    post_install_evidence "$cli" "$ref"   # ⓑ v0.3.20 — 끝난 그 화면을 기록에 남긴다(훅 오류 줄 수 + 끝 40줄)\n',
     "",
     "[post-install] 맥판도 성공 자리에서 부른다", CAP),
    # ⓕ② 재시도 촉발을 뺀다 — 자식 자리가 몇 번을 되깨워져도 그 순간의 화면이 아무 데도 안 남는다
    ("retry-capture-drop", PS,
     "            Send-CaptureEvidence 'retry' ('awaken:child-retry role=' + $Role + ' seat=' + $Ref + ' n=' + $retry)   # ⓕ② v0.3.20\n",
     "",
     "[3회 실패] 증거 = 이유마다 정확히 1건", AWK),
    # ⓕ 이유 × 단계 한 번을 깬다 — 재시도 3회면 증거가 3건 나간다(오류 글이 쏟아지는 실기에서 폭주하는 모양)
    ("retry-dedupe-drop", PS,
     "        $key = $Reason + '|' + $step\n        if ($script:CaptureSent.ContainsKey($key)) { return }",
     "        $key = $Reason + '|' + $step + '|' + [guid]::NewGuid()\n        if ($script:CaptureSent.ContainsKey($key)) { return }",
     "[3회 실패] 증거 = 이유마다 정확히 1건", AWK),
    # ── 이종 검토 1R(2026-09-16) 지적 채택분 ──────────────────────────────────
    # ③ 기록 파일에 사유 글을 날것으로 — 이 파일은 실패 때 통째로 서버로 간다(보내는 쪽만 가려도 소용없다)
    ("log-mask-drop", PS,
     "        Write-Log ('capture evidence: ' + $key + ' ' + (Protect-EvidenceText ([string]$Detail)))",
     "        Write-Log ('capture evidence: ' + $key + ' ' + [string]$Detail)",
     "[ⓕ③] 기록 파일의 사유 글도 가려져 있다", CAP),
    # ④ 먹통 창 검사를 뺀다 — 응답 없는 창에 PrintWindow 를 보내면 설치기가 멈춘다
    ("hung-check-drop", PS,
     "        try { if ([Jarvis.Win]::IsHungAppWindow($h)) { Write-Log 'window capture skip (창이 응답하지 않는다)'; return $null } } catch { }\n",
     "",
     "[먹통 창] 창 크기를 묻기 전에 먹통인지 먼저 본다", CAP),
    # ① 자리 검사를 뺀다 — 이름만 같으면 남의 창도 찍는다
    ("appdir-check-drop", PS,
     "                if (-not $exe.StartsWith($dir.TrimEnd('\\') + '\\', [System.StringComparison]::OrdinalIgnoreCase)) { continue }\n",
     "",
     "[앱 창] 우리가 깐 자리에서 도는 창만 찍는다", CAP),
    # ① 우리가 깐 자리를 몰라도 찍으려 든다
    # ⚠이 성질은 **맥에서 실물로 못 잰다**(맥 프로세스에는 윈도우 창 손잡이가 없어 관문을 겹쳐 빼도 답이 「그림 없음」으로 같다
    #   — 2026-09-16 실측). ⇒ 글로 재는 정적 축을 겨눈다. 실동작은 윈 실기 몫으로 보고서에 남겼다.
    ("appcli-guard-drop", PS,
     "        if (-not $script:CysCli) { Write-Log 'app window skip (우리가 깐 자리를 모른다)'; return $null }\n",
     "",
     "[앱 창] 우리가 깐 자리를 모르면 찍지 않는다(정적)", CAP),
    # ⓓ 고지를 옛 문안으로 되돌린다 — 그림을 보내면서 「글자만」이라고 말하는 상태(2026-09-16 오전에 실제로 있던 상태)
    ("notice-revert", PS,
     "설치가 막히거나 이상이 보이거나 끝났을 때, 그리고 운영팀이 청할 때 설치 창·로그인 창·자비스 창·첫 자리 화면의 글자와 그림이 함께 보내집니다(다른 창은 찍지 않습니다). 글자에서는 로그인 코드·이메일·계정 이름을 가리지만, 그림은 가릴 수 없어 운영팀만 봅니다.",
     "설치가 막히면 설치 창에 표시된 글자만 보내지며, 로그인 코드·이메일·계정 이름은 가려집니다.",
     "[고지] 고지가 「글자만」이라고 말하지 않는다", CAP),
    # TICKET=installer-0325 c5(2026-09-18) — 원본 파일이 없을 때 사유 코드 대신 빈 글로 되돌림(09-17 10:01 실기 WHm7yvpu 재현)
    ("evidence-text-empty-revert", PS,
     "    if ($null -eq $bytes -or $bytes.Length -eq 0) { return '[text:empty(no-source)]' }",
     "    if ($null -eq $bytes -or $bytes.Length -eq 0) { return '' }",
     "[c5] 원본 파일이 없으면 빈 글이 아니라 사유 코드를 돌려준다", CAP),
    # TICKET=installer-0325 c5(2026-09-18) — 그림 찍기 실패 사유를 글자 칸에 담는 것을 되돌린다(옛 판 = 이 기계 기록에만 남음)
    ("evidence-capture-failnote-revert", PS,
     "        if ($failNote) { $t = ([string]$t) + \"`n\" + $failNote }   # 사진이 안 찍혔으면 그 사유도 글자 칸에 함께 싣는다(c5)\n",
     "",
     "[c5] 그림 찍기가 예외로 죽으면 그 사유가 evidence_text 칸에 실려 서버에 닿는다", CAP),
]


def copy_tree(root, dst):
    for d in ("install-master", "tests", "docs"):
        shutil.copytree(root / d, dst / d, symlinks=True)


def run(tree, runner):
    r = subprocess.run(["bash", runner], cwd=tree, env=dict(os.environ),
                       capture_output=True, text=True, stdin=subprocess.DEVNULL)
    return [l for l in r.stdout.split("\n") if l.startswith("  FAIL")]


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--root", required=True)
    ap.add_argument("--audit", action="store_true")
    ap.add_argument("--only", default="")
    a = ap.parse_args()
    root = pathlib.Path(a.root).expanduser().resolve()
    only = set(x for x in a.only.split(",") if x)
    chosen = [m for m in MUTANTS if not only or m[0] in only]
    broken = 0
    for name, rel, old, new, axis, runner in chosen:
        n = (root / rel).read_text(encoding="utf-8-sig").count(old)
        if n != 1:
            print("앵커 %d곳 ✗ %-20s %s" % (n, name, rel)); broken += 1
    if broken:
        print("::error::앵커가 1곳이 아닌 뮤턴트 %d개 — 뮤턴트가 낡았다" % broken); return 3
    if a.audit:
        print("앵커 전건 1곳 — 뮤턴트 %d개 대조 가능" % len(chosen)); return 0
    # 기준선은 **러너마다** 따로 잰다 — 남의 러너 적색을 기준선으로 쓰면 공짜 적색 판정이 어긋난다
    base = {}
    for runner in sorted(set(m[5] for m in chosen)):
        base_tmp = pathlib.Path(tempfile.mkdtemp(prefix="capture-mut-base-"))
        try:
            copy_tree(root, base_tmp)
            base[runner] = run(base_tmp, runner)
        finally:
            shutil.rmtree(base_tmp, ignore_errors=True)
        print("기준선 적색 %d줄 (%s)" % (len(base[runner]), runner))
        for l in base[runner]:
            print("   (기준선) " + l.strip())
    bad = 0
    for name, rel, old, new, axis, runner in chosen:
        if any(axis in l for l in base[runner]):
            print("실격  %-20s ← 기준선에서 이미 붉은 축(공짜 적색): %s" % (name, axis)); bad += 1; continue
        tmp = pathlib.Path(tempfile.mkdtemp(prefix="capture-mut-"))
        try:
            copy_tree(root, tmp)
            p = tmp / rel
            raw = p.read_bytes()
            bom = raw[:3] == b"\xef\xbb\xbf"
            text = raw.decode("utf-8-sig")
            mutated = text.replace(old, new, 1)
            if mutated == text:
                print("미적용 %-20s ← 변이가 들어가지 않았다" % name); bad += 1; continue
            p.write_bytes((b"\xef\xbb\xbf" if bom else b"") + mutated.encode("utf-8"))
            if p.read_bytes() == raw:
                print("미적용 %-20s ← 쓴 뒤에도 바이트가 같다" % name); bad += 1; continue
            reds = run(tmp, runner)
            if any(axis in l for l in reds):
                print("붉음  %-20s ← %s" % (name, axis))
            else:
                print("눈멂  %-20s ← 안 붉어진 축: %s (그때 붉은 줄 %d)" % (name, axis, len(reds))); bad += 1
                for l in reds[:4]:
                    print("        " + l.strip())
        finally:
            shutil.rmtree(tmp, ignore_errors=True)
    print("\n뮤턴트 %d개 · 실패(눈멂·실격·미적용) %d개" % (len(chosen), bad))
    return 1 if bad else 0


sys.exit(main())
