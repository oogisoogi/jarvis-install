# Threat model — jarvis-install

Read by the OSS Scanner before it starts. Free text, written by the maintainers.

## What this project does

One-line installers for workshop participants. A participant pastes one line into Terminal (macOS) or
Windows PowerShell; the script checks the computer, installs Claude Code through its official installer, installs
the cysr terminal app from our GitHub releases, and starts the "Jarvis" agents. Companion scripts list or remove
what the installer placed (`reset-clean.*`) and remove-then-reinstall (`reinstall.*`).

- macOS: `install-master/bootstrap.sh`, `reset-clean.sh`, `reinstall.sh` (bash 3.2 compatible; root copies are
  identical).
- Windows: `install-master/bootstrap.ps1`, `reset-clean.ps1`, `reinstall.ps1` (Windows PowerShell 5.1+).
- `tests/` holds the test doubles, mutation runners and emulators; `install-master/checks.sh` runs the check suite.

The scripts run as the participant, in the participant's home folder, and never ask for administrator rights
(`sudo` / elevation are not used by design). Participants are beginners who will not read the script first.

## Where untrusted input enters (in order of importance)

1. **The remote-help channel** (bash: `remote_help*` functions in `bootstrap.sh`; PowerShell: the matching section
   of `bootstrap.ps1`; command table `install-master/command-table.json`). When an install stops, the script sends
   a diagnostic report to the help server and then polls it; the server may send back commands that the script
   runs. Intended guarantees, assuming the server or the network path is hostile: every command is re-checked
   against the table built into the script (characters, fields, names, shapes, positions); only the table's
   read-only commands can run; paths are confined to the working folder (no escape through `..`, symbolic links,
   junctions, or a race between check and use); commands run without a shell; each command number is recorded
   before it runs so a replayed number does not run twice; the loop stops when the window closes.
2. **Downloads the installer runs or installs.** Claude Code comes from Anthropic's official installer; the cysr
   app zip comes from our GitHub releases and is pinned by size, sha256 and code-signing identity (CDHash on macOS)
   written into the script. A download that does not match the pins must not be unpacked, moved into place or run.
3. **What the installer sends out.** Progress events and help reports go to our server. Logs, screen captures and
   error text are masked before sending (the masking rules are shared with the server and pinned by the golden
   vectors in `tests/mask-vectors.json`). Leaking
   a credential, token, e-mail address or file content that the participant did not see announced is a finding.
4. **Deletion** (`reset-clean.*`, `reinstall.*`). These remove only what the installer placed. They must never
   follow a symbolic link or junction out of the target, never delete the participant's own files, and keep the
   Claude login (the macOS keychain item; on Windows the `.claude` login files) unless the user explicitly asks
   otherwise (`-PurgeLogin` / `--purge-login`).
5. **Local state the scripts read back** (files under the participant's home that a previous run left, settings
   files they merge, environment variables). Treat them as possibly stale or hand-edited, not as attacker-controlled
   by another account — another local account is out of scope (see below).

## Components that matter most / least

- Most: remote help (item 1), download verification (item 2), deletion safety (item 4).
- In scope: scrubbing of outgoing data (item 3), quoting/word-splitting bugs that turn file names or server text
  into commands, anything that makes a script elevate privileges.
- Windows scripts: in scope for review. This Linux image can parse them (`pwsh` is installed) and runs the
  emulation tests that use `pwsh`, but it cannot run the real Windows paths (registry, Windows Credential Manager,
  installers, Defender). Findings there are welcome as static findings with the reasoning spelled out.
- macOS-only behaviour (keychain, `codesign`, `ditto`, Gatekeeper) cannot run here either; the bash logic around it
  is still in scope.
- Out of scope: `tests/` (test doubles, fake servers bound to 127.0.0.1, mutation runners) except where a test
  hides a real bug in the scripts; `docs/`; the vendor installers we call (Claude Code's own installer, the cysr app
  itself — that app is scanned separately as cys-ro); attacks that need another program already running as the
  participant, or another local account.

## How to exercise it

- Run tests as the ordinary user the image was built with: `runuser -u tester -- bash .oss-scanner/run-tests.sh`.
  As root, permission-denial tests pass vacuously or skip themselves; the products never run as root.
- `bash .oss-scanner/run-tests.sh` runs everything that works offline here: `syntax` (bash -n on every script),
  `ps-parse` (PowerShell parser on every .ps1), `ps-balance`, and `checks` (`install-master/checks.sh`, the main
  suite; it runs the pwsh emulation tests when pwsh is present and skips machine-specific checks it cannot do).
  The log of the run made while the image was built is at `/var/log/oss-scanner-tests.log`.
- Known failure without network: the check `[전환] 윈 핀 = 릴리스 실측` (`tests/win-pin-release.sh`) compares the
  pinned Windows download against the live GitHub release and reports FAIL when it cannot reach it (by design:
  "offline is not a pass"). The macOS twin (`tests/mac-pin-release.sh`) reports skip instead. Neither is a finding.
- The test doubles talk to fake servers on 127.0.0.1 only; loopback works in the offline image.
- Library mode loads the bash functions without running an install: `JARVIS_LIB_ONLY=1 . install-master/bootstrap.sh`
  (see `tests/lib-only-no-live.sh`). The remote-help tests drive the real functions against a fake server:
  `bash tests/remote-help-run.sh` (`tests/remote-help-fake-server.py`).
- Never point the scripts at the live servers. Set `JARVIS_NO_PROGRESS=1`,
  `JARVIS_PROGRESS_URL=http://127.0.0.1:9/x` and `JARVIS_HELP_API_URL=http://127.0.0.1:9/x` (the test runners
  already do), and use a throwaway `HOME`.

## How we rate severity

- **Critical**: the help server or a network attacker gets a command outside the table executed, or a path outside
  the working folder read or written; an unpinned or mismatching download is run or put in place; any route to
  administrator/root.
- **High**: deletion that reaches outside what the installer placed (through a link, a crafted name or a race);
  the Claude login deleted without the user asking; a credential or token sent to our server.
- **Medium**: other personal data sent without the announced notice; replay of a remote-help command; a script that
  hangs forever instead of reaching its stated time limit (the participant is left with a frozen window).
- **Low**: wrong or misleading messages, partial installs that the next run repairs, crashes with no effect beyond
  the participant's own session.

## How we would like reports and patches

- A reproducer that runs in this image without network (a fake server on 127.0.0.1 is fine — the tests show how)
  and the smallest patch to both twins when the bug is in shared logic: bash and PowerShell must stay in parity
  (`install-master/ps1-sh-parity.tsv`).
- Keep existing comments and on-screen text (Korean, intentional; several tests pin the exact wording).

## Anything to leave alone

- Do not contact the live install site, the help server or GitHub release downloads.
- The root-level `bootstrap.*`, `reset-clean.*`, `reinstall.*` are byte copies of `install-master/`; patch
  `install-master/`.
