# OSS Scanner build for jarvis-install (the AI Jarvis workshop installer: bash for macOS, PowerShell for Windows).
# Contract (github.com/anthropics/oss-scanner): the build context is the repository checkout, the build runs
# online, and the audit afterwards runs with NO network. Everything the tests need is fetched here.
#
# There is nothing to compile. The image carries the interpreters the installers and their tests use — bash,
# python3, PowerShell 7 (pwsh, for the Windows scripts' parser checks and emulation tests) and shellcheck — and runs
# the repository's own check suite once so the image is known to work. See .oss-scanner/threat_model.md.
FROM ubuntu:24.04

ENV DEBIAN_FRONTEND=noninteractive
RUN apt-get update && apt-get install -y --no-install-recommends \
      ca-certificates curl git bash python3 shellcheck jq file procps psmisc unzip zip \
      bsdextrautils util-linux build-essential libicu74 \
    && rm -rf /var/lib/apt/lists/*

# PowerShell, pinned to the version the maintainers test with (7.6.6), from the official release archive.
ARG PWSH_VERSION=7.6.6
RUN set -eu; \
    case "$(dpkg --print-architecture)" in amd64) a=x64 ;; arm64) a=arm64 ;; *) echo "no pwsh build for this arch"; exit 1 ;; esac; \
    curl -fsSL -o /tmp/pwsh.tgz \
      "https://github.com/PowerShell/PowerShell/releases/download/v${PWSH_VERSION}/powershell-${PWSH_VERSION}-linux-${a}.tar.gz"; \
    mkdir -p /opt/microsoft/powershell/7; \
    tar -xzf /tmp/pwsh.tgz -C /opt/microsoft/powershell/7; \
    chmod +x /opt/microsoft/powershell/7/pwsh; \
    ln -sf /opt/microsoft/powershell/7/pwsh /usr/local/bin/pwsh; \
    rm -f /tmp/pwsh.tgz; \
    pwsh -NoProfile -Command '$PSVersionTable.PSVersion.ToString()'
ENV POWERSHELL_TELEMETRY_OPTOUT=1 \
    POWERSHELL_UPDATECHECK=Off \
    DOTNET_CLI_TELEMETRY_OPTOUT=1

# Test as an ordinary user, the way the installers run (they never use sudo): several tests check permission denials
# that root bypasses. The scanner's own layer switches back to root afterwards.
RUN useradd -m -s /bin/bash tester \
    && git config --system --add safe.directory /src

# scanner contract: the checkout lives inside the image, at /src
COPY --chown=tester:tester . /src
WORKDIR /src
USER tester

# Run the checks so the image is known to work, but do not let a failing check abort the build. The same list runs
# in CI with --network none (.github/workflows/oss-scanner-image.yml). The log stays in the image. The suite takes
# about 18 minutes on macOS CI; the hard limit keeps the whole build inside the scanner's 45 minutes.
RUN timeout 1800 bash .oss-scanner/run-tests.sh > /tmp/oss-scanner-tests.log 2>&1 \
    || echo "WARNING: .oss-scanner/run-tests.sh reported failures or ran out of time — see /tmp/oss-scanner-tests.log"; \
    tail -12 /tmp/oss-scanner-tests.log

USER root
RUN mv /tmp/oss-scanner-tests.log /var/log/oss-scanner-tests.log
