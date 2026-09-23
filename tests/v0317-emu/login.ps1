# [3/10] v0.3.17 로그인 흉내 (pwsh 7 · 맥) — 가짜 claude 로 「새 창 로그인」의 다섯 갈래와 실패 질문·끝맺음 기록을 실제로 부른다
#   승인 지연 · 즉시 반환 · 무한 대기 · 파일만 생성(창이 안 닫힘) · 확인 명령 없음
#   + 확인 명령이 「아니다」라고 답하는 파일 · 예전 로그인이 남긴 파일 · 이 창 폴백 · 끝맺음 오류 분류
param([string]$Src, [string]$Scenario, [string]$Sb)
$ErrorActionPreference = 'Continue'
New-Item -ItemType Directory -Force -Path "$Sb/home/install-jarvis", "$Sb/bin" | Out-Null
$fake = @'
#!/bin/bash
SB="$(cd "$(dirname "$0")/.." && pwd)"
S="$(cat "$SB/scenario")"
CRED="$SB/home/.claude/.credentials.json"
GOOD='EMUgoodCODEvalue_-0123456789#EMUgoodSTATEvalue_-9876543210'
BAD='EMUbadCODEvalue_-01234567890#EMUbadSTATEvalue_-98765432100'
cred() { mkdir -p "$SB/home/.claude"; printf '{"claudeAiOauth":{"accessToken":"emu-%0180d","subscriptionType":"pro"}}' 0 > "$CRED"; }
case "$1 $2" in
  "--help "*) echo "Commands:"; echo "  auth    Manage authentication"; exit 0 ;;
  "auth login")
     n=$(( $(cat "$SB/calls" 2>/dev/null || echo 0) + 1 )); echo "$n" > "$SB/calls"
     case "$S" in
       slow-approve) /bin/sleep 3; cred; touch "$SB/logged"; exit 0 ;;
       instant-return) exit 1 ;;
       hang|hang-ask) exec -a "$SB/emu-sleep" /bin/sleep 3071 ;;
       file-only) ( /bin/sleep 1; cred; touch "$SB/logged" ) >/dev/null 2>&1 & exec -a "$SB/emu-sleep" /bin/sleep 3072 ;;
       no-status) ( /bin/sleep 1; cred ) >/dev/null 2>&1 & exec -a "$SB/emu-sleep" /bin/sleep 3073 ;;
       file-not-logged) ( /bin/sleep 1; cred ) >/dev/null 2>&1 & exec -a "$SB/emu-sleep" /bin/sleep 3074 ;;
       stale-file) exec -a "$SB/emu-sleep" /bin/sleep 3075 ;;
       status-hang) exec -a "$SB/emu-sleep" /bin/sleep 3077 ;;
       inline) echo "EMU-VENDOR-LOGIN-OUTPUT"; cred; touch "$SB/logged"; exit 0 ;;
       clip-*)
         # 사람의 「복사」를 흉내 낸다 — 복사된 내용 파일을 시간차로 바꾼다
         case "$S" in
           clip-inject) ( /bin/sleep 1; printf '%s' "$GOOD" > "$SB/clip" ) >/dev/null 2>&1 & ;;
           clip-junk) ( /bin/sleep 1; printf '%s' 'https://claude.ai/oauth/authorize?code=true#EMUJUNKSTATEvalue1234' > "$SB/clip"; /bin/sleep 1; printf '%s' 'short#code' > "$SB/clip" ) >/dev/null 2>&1 & ;;
           clip-repeat) ( /bin/sleep 1; printf '%s' "$BAD" > "$SB/clip" ) >/dev/null 2>&1 & ;;
           clip-many) ( for i in 1 2 3 4 5 6; do /bin/sleep 0.8; printf '%s' "EMUmanyCODEvalue000${i}#EMUmanySTATEvalue000${i}" > "$SB/clip"; done ) >/dev/null 2>&1 & ;;
         esac
         # 벤더와 같은 방식 — 표준 입력의 한 줄을 「코드#state」로 받는다(원문은 남기지 않고 줄 수만 센다)
         while IFS= read -r line; do
           m=$(( $(cat "$SB/lines" 2>/dev/null || echo 0) + 1 )); echo "$m" > "$SB/lines"
           line="$(printf '%s' "$line" | tr -d '\r')"
           if [ "$S" = "clip-inject" ] && [ "$line" = "$GOOD" ]; then cred; touch "$SB/logged"; echo "Login successful."; exit 0; fi
           echo "Invalid code. Please make sure the full code was copied." >&2
         done
         exec -a "$SB/emu-sleep" /bin/sleep 3078 ;;
     esac ;;
  "auth status")
     case "$S" in
       no-status|stale-file) echo "error: unknown command"; exit 1 ;;
       status-hang) exec -a "$SB/emu-sleep" /bin/sleep 3076 ;;
     esac
     if [ -f "$SB/logged" ]; then echo '{"loggedIn": true, "authMethod": "claude.ai", "email": "emu-person@example.com", "subscriptionType": "pro"}'; exit 0
     else echo '{"loggedIn": false}'; exit 1; fi ;;
esac
exit 0
'@
Set-Content -Path "$Sb/bin/claude" -Value $fake -NoNewline
& chmod +x "$Sb/bin/claude"
Set-Content -Path "$Sb/scenario" -Value $Scenario -NoNewline
if ($Scenario -eq 'stale-file') {
    # 예전 로그인이 남긴 파일(크기는 하한 위) — 이번에 안 고쳐졌으면 성공으로 읽으면 안 된다
    New-Item -ItemType Directory -Force -Path "$Sb/home/.claude" | Out-Null
    Set-Content -Path "$Sb/home/.claude/.credentials.json" -Value ('{"old":"' + ('x' * 200) + '"}') -NoNewline
}
$env:PATH = "$Sb/bin:" + $env:PATH
$env:USERPROFILE = "$Sb/home"
$env:JARVIS_HOME = "$Sb/home/install-jarvis"
$env:JARVIS_LIB_ONLY = '1'
$env:JARVIS_NO_PROGRESS = '1'   # 이 흉내는 로그인 갈래만 잰다 — 진행 전송은 telemetry-emu 가 따로 잰다(실서버 무접촉)
. $Src
$env:JARVIS_LIB_ONLY = ''
$LoginPollInterval = 1; $LoginConfirmTries = 3; $LoginSayInterval = 5; $LoginWaitTimeout = 10
$LoginCheckpointSec = 3; $LoginStatusEverySec = 2; $LoginAskWaitSec = 2; $LoginStatusWaitMs = 1500
if ($Scenario -eq 'hang-ask') { function Read-LoginFailKey([int]$waitSec) { return '2' } }
$LoginTickMs = 300
# 복사된 내용은 이 기계의 진짜 클립보드를 절대 읽지 않는다 — 흉내 파일(가짜 claude 가 「사람의 복사」를 흉내 내 쓴다)만 읽는다.
function Get-LoginClipText { if (Test-Path -LiteralPath "$Sb/clip") { return [System.IO.File]::ReadAllText("$Sb/clip") } return $null }
if ($Scenario -eq 'clip-stale') { Set-Content -Path "$Sb/clip" -Value 'AAAAbbbbCCCCdddd_-_OLDCODE#SSSSttttUUUUvvvv_-_OLDSTATE' -NoNewline }
elseif ($Scenario -like 'clip-*') { Set-Content -Path "$Sb/clip" -Value 'emu-before-login-unrelated-text' -NoNewline }
if ($Scenario -eq 'inline') {
    # 입력을 쥔 로그인 프로세스만 못 띄우게 한다 — 확인 명령은 Start-Process 로 띄우므로 그대로 둔다
    function Start-LoginPipeProc { param([string]$FilePath, [string[]]$ArgumentList) throw 'emu: the login process cannot be started' }
}
if ($Scenario -like 'closing-*') {
    $Error.Clear()
    if ($Scenario -eq 'closing-quiet') { [void](Get-Command emu-no-such-command-v0317 -ErrorAction SilentlyContinue) }
    if ($Scenario -eq 'closing-loud') {
        [void](Get-Command emu-no-such-command-v0317 -ErrorAction SilentlyContinue)
        try { [void](Get-Item -LiteralPath "$Sb/emu-no-such-file-v0317" -ErrorAction Stop) } catch { }
    }
    $script:LoginStage = 'confirm'
    $script:NoticeShown = $false
    try { Write-ClosingNote } finally { Write-Log 'TEST finally' }
    return
}
try { Step-Login; $rc = $script:LoginRc; Write-Log ("TEST rc=" + $rc + " JCode=" + $script:JCode + " LoggedIn=" + $script:LoggedIn) }
finally { Write-Log 'TEST finally' }
