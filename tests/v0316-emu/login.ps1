# [3/10] 로그인 흉내 (pwsh 7 · 맥) — 가짜 claude 로 승인 창이 끝나는 모양을 바꿔 가며 Step-Login 을 실제로 부른다
param([string]$Src, [string]$Scenario, [string]$Sb)
$ErrorActionPreference = 'Continue'
New-Item -ItemType Directory -Force -Path "$Sb/home/install-jarvis", "$Sb/bin" | Out-Null
$fake = @'
#!/bin/bash
SB="$(cd "$(dirname "$0")/.." && pwd)"
S="$(cat "$SB/scenario")"
case "$1 $2" in
  "--help "*) echo "Commands:"; echo "  auth    Manage authentication"; exit 0 ;;
  "auth login")
     n=$(( $(cat "$SB/calls" 2>/dev/null || echo 0) + 1 )); echo "$n" > "$SB/calls"
     case "$S" in
       reopen-ok) [ "$n" -ge 2 ] && touch "$SB/logged"; exit 0 ;;
       reopen-fail) exit 1 ;;
       poll-exc) rm -f "$0"; exit 0 ;;
       reopen-then-poll-exc)
          if [ "$n" -ge 2 ]; then touch "$SB/logged"; mv "$0" "$SB/claude.away"; ( /bin/sleep 2; mv "$SB/claude.away" "$SB/bin/claude" ) >/dev/null 2>&1 & fi
          exit 0 ;;
       ok-first) touch "$SB/logged"; exit 0 ;;
       timeout) /bin/sleep 3033; exit 0 ;;
     esac ;;
  "auth status") if [ -f "$SB/logged" ]; then echo '{"loggedIn": true}'; else echo '{"loggedIn": false}'; fi; exit 1 ;;
esac
exit 0
'@
Set-Content -Path "$Sb/bin/claude" -Value $fake -NoNewline
& chmod +x "$Sb/bin/claude"
Set-Content -Path "$Sb/scenario" -Value $Scenario -NoNewline
$env:PATH = "$Sb/bin:" + $env:PATH
$env:USERPROFILE = "$Sb/home"
$env:JARVIS_HOME = "$Sb/home/install-jarvis"
$env:JARVIS_LIB_ONLY = '1'
. $Src
$env:JARVIS_LIB_ONLY = ''
$LoginPollInterval = 1; $LoginPollTimeout = 4; $LoginSayInterval = 5; $LoginWaitTimeout = 10
try { $rc = @(Step-Login)[-1]; Write-Log ("TEST rc=" + $rc + " JCode=" + $script:JCode + " LoggedIn=" + $script:LoggedIn) }
finally { Write-Log 'TEST finally' }
