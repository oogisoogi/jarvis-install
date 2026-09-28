#!/bin/bash
# 0.3.36 기기 모델명(hw_model) 시험 — 진행 이벤트 env 에 기기 모델명이 실리고, 기기 고유번호는 절대 실리지 않는가.
# 0.3.36 ④: 메모리 크기(mem_gb)·남은 디스크(disk_free_gb) — 정수 GB(2^30 바이트 · 반올림) 글자 · 못 읽으면 칸을 만들지 않는다.
#   메모리 0(반올림 뒤) = 못 읽음으로 본다(칸 없음 · 두 OS 같은 뜻) · 디스크 0 은 실재 값이라 「0」.
#
# 재는 것
#   맥: progress_send … env 가 실제로 만드는 본문(가짜 progress_post 가 받아 적는다 · 네트워크 0)에서
#       ⓐ hw_model = 이 맥의 `sysctl -n hw.model` 값 ⓑ env 열쇠 ⊆ 서버가 받는 열쇠
#       ⓒ 어느 값에도 이 맥의 시리얼·하드웨어 UUID 가 없다(값은 화면·기록에 찍지 않고 이 셸 안에서만 비교한다)
#   윈: Get-InstallEnv 를 가짜 CIM(제조사·모델 + 고유번호 칸을 모두 채운 대역)으로 불러
#       ⓐ hw_model = 「제조사 모델」(앞뒤 빈칸 걷음) ⓑ env 열쇠 ⊆ 서버가 받는 열쇠 ⓒ 어느 값에도 고유번호 대역 글자(SECRET)가 없다
#       ⓓ 제조사·모델이 비었으면 hw_model 칸을 만들지 않는다
#   ⇒ 고유번호가 흘러들게 바꾸면(모델 대신 시리얼 · 고유번호 칸 추가) 여기서 붉어진다.
#
# 쓰는 법: bash tests/hw-model-env.sh [--dir <install-master 자리>]   · rc 0 = 통과 · 1 = 실패 · 2 = 잴 수 없음(pwsh 없음)
set -u
HERE="$(cd "$(dirname "$0")" && pwd)"
DIR="$HERE/../install-master"
[ "${1:-}" = "--dir" ] && DIR="$2"
SH="$(cd "$DIR" && pwd)/bootstrap.sh"
PS="$(cd "$DIR" && pwd)/bootstrap.ps1"
PW="$(command -v pwsh 2>/dev/null)"
[ -n "$PW" ] || { echo "잴 수 없음: pwsh 가 없다" >&2; exit 2; }
BASE="$(mktemp -d -t hwmodel)" || exit 2
trap 'rm -rf "$BASE"' EXIT
pass=0; fail=0
t() { if [ "$1" -eq 0 ]; then pass=$((pass+1)); printf '  ok   %s\n' "$2"; else fail=$((fail+1)); printf '  FAIL %s  ← %s\n' "$2" "$3"; fi; }

echo "== 맥 =="
mkdir -p "$BASE/home"
HOME="$BASE/home" TMPDIR="$BASE" JARVIS_HOME="$BASE/home/install-jarvis" JARVIS_LIB_ONLY=1 \
  perl -e 'alarm shift; exec @ARGV or exit 126' 60 bash -c ". '$SH' >/dev/null 2>&1; unset JARVIS_NO_PROGRESS; MODE=full; NOTICE_SHOWN=1; mkdir -p \"\$JARVIS_HOME\"
progress_post() { cp \"\$2\" '$BASE/mbody.json'; PG_HTTP=500; PG_ERR=''; }
progress_send '1/10' 'info' '' 'arch:test' env" >/dev/null 2>&1
if [ ! -s "$BASE/mbody.json" ]; then
  t 1 "[맥] 본문이 만들어졌다" "본문 없음"
else
  want="$(/usr/sbin/sysctl -n hw.model 2>/dev/null | head -1)"
  serial="$(ioreg -rd1 -c IOPlatformExpertDevice 2>/dev/null | awk -F'"' '/"IOPlatformSerialNumber"/{print $4; exit}')"
  hwuuid="$(ioreg -rd1 -c IOPlatformExpertDevice 2>/dev/null | awk -F'"' '/"IOPlatformUUID"/{print $4; exit}')"
  memb="$(/usr/sbin/sysctl -n hw.memsize 2>/dev/null | head -1)"
  diskk="$(/bin/df -Pk "$BASE/home" 2>/dev/null | awk 'NR==2{print $4}')"
  WANT="$want" SERIAL="$serial" HWUUID="$hwuuid" MEMB="$memb" DISKK="$diskk" python3 - "$BASE/mbody.json" > "$BASE/mres" <<'PY'
import json, os, sys
e = json.load(open(sys.argv[1])).get("env") or {}
allowed = {"claude_ver", "cys_ver", "mac_ver", "hw_model", "mem_gb", "disk_free_gb", "admin"}
print("model=" + ("1" if e.get("hw_model") == os.environ["WANT"] and os.environ["WANT"] else "0"))
print("keys=" + ("1" if set(e) <= allowed else "0:" + ",".join(sorted(set(e) - allowed))))
secrets = [s for s in (os.environ["SERIAL"], os.environ["HWUUID"]) if s]
vals = " ".join(str(v) for v in e.values())
print("nosecret=" + ("1" if not any(s in vals for s in secrets) else "0"))
print("secrets_read=%d" % len(secrets))
MEM = int(os.environ["MEMB"]) if os.environ["MEMB"].isdigit() else -1
print("mem=" + ("1" if MEM > 0 and e.get("mem_gb") == str((MEM + 2**29) // 2**30) else "0:" + repr(e.get("mem_gb"))))
DK = int(os.environ["DISKK"]) if os.environ["DISKK"].isdigit() else -1
d = e.get("disk_free_gb")
print("disk=" + ("1" if DK >= 0 and isinstance(d, str) and d.isdigit() and abs(int(d) - (DK + 2**19) // 2**20) <= 1 else "0:" + repr(d)))
PY
  grep -q '^model=1$' "$BASE/mres"; t $? "[맥 ⓐ] hw_model = 이 맥의 sysctl hw.model 값" "$(grep '^model' "$BASE/mres")"
  grep -q '^keys=1$' "$BASE/mres"; t $? "[맥 ⓑ] env 열쇠 ⊆ 서버가 받는 열쇠" "$(grep '^keys' "$BASE/mres")"
  if grep -q '^secrets_read=0$' "$BASE/mres"; then
    echo "  skip [맥 ⓒ] 이 맥의 고유번호를 못 읽었다(비교 불가 — 통과로 세지 않는다)"
  else
    grep -q '^nosecret=1$' "$BASE/mres"; t $? "[맥 ⓒ] 어느 값에도 이 맥의 시리얼·하드웨어 UUID 가 없다" "고유번호가 실렸다(값은 찍지 않는다)"
  fi
  grep -q '^mem=1$' "$BASE/mres"; t $? "[맥 ⓔ] mem_gb = 이 맥 hw.memsize 의 정수 GB(반올림)" "$(grep '^mem' "$BASE/mres")"
  grep -q '^disk=1$' "$BASE/mres"; t $? "[맥 ⓕ] disk_free_gb = 집 폴더 볼륨 남은 공간의 정수 GB(±1 · 재는 사이 변동)" "$(grep '^disk' "$BASE/mres")"
fi

# 맥 경계 — 읽는 함수(env_mem_bytes · env_disk_free_kib)를 대역으로 바꿔 본문 env 두 칸만 본다.
mac_edge() { # mac_edge <mem 대역 출력(바이트)> <disk 대역 출력(KiB)> → 「mem_gb|disk_free_gb」(칸이 없으면 -)
  rm -f "$BASE/ebody.json"
  HOME="$BASE/home" TMPDIR="$BASE" JARVIS_HOME="$BASE/home/install-jarvis" JARVIS_LIB_ONLY=1 EM="$1" ED="$2" \
    perl -e 'alarm shift; exec @ARGV or exit 126' 60 bash -c ". '$SH' >/dev/null 2>&1; unset JARVIS_NO_PROGRESS; MODE=full; NOTICE_SHOWN=1; mkdir -p \"\$JARVIS_HOME\"
env_mem_bytes() { printf '%s' \"\$EM\"; }
env_disk_free_kib() { printf '%s' \"\$ED\"; }
progress_post() { cp \"\$2\" '$BASE/ebody.json'; PG_HTTP=500; PG_ERR=''; }
progress_send '1/10' 'info' '' 'arch:test' env" >/dev/null 2>&1
  [ -s "$BASE/ebody.json" ] || { echo "no-body"; return; }
  python3 -c 'import json,sys; e=json.load(open(sys.argv[1])).get("env") or {}; print("%s|%s" % (e.get("mem_gb","-"), e.get("disk_free_gb","-")))' "$BASE/ebody.json"
}
r="$(mac_edge 17179869184 0)";          [ "$r" = "16|0" ];    t $? "[맥 경계] 16 GiB · 남은 0 → 「16」·「0」" "$r"
r="$(mac_edge 17716740096 4294967296)"; [ "$r" = "17|4096" ]; t $? "[맥 경계] 16.5 GiB 반올림 → 「17」 · 4 TiB → 「4096」" "$r"
r="$(mac_edge 17716740095 524287)";     [ "$r" = "16|0" ];    t $? "[맥 경계] 반올림 경계 바로 아래 → 「16」·「0」" "$r"
r="$(mac_edge 0 5)";                     [ "$r" = "-|0" ];     t $? "[맥 경계] 메모리 0 → 칸 없음(못 읽음) · 디스크 5 KiB → 「0」(실재 값)" "$r"
r="$(mac_edge 536870911 1048576)";       [ "$r" = "-|1" ];     t $? "[맥 경계] 메모리 0.5 GiB 미만(반올림 0) → 칸 없음 · 디스크 1 GiB → 「1」" "$r"
r="$(mac_edge '' '')";                  [ "$r" = "-|-" ];     t $? "[맥 경계] 못 읽으면(빈 출력) 두 칸을 만들지 않는다" "$r"
r="$(mac_edge '12abc' '-5')";           [ "$r" = "-|-" ];     t $? "[맥 경계] 숫자가 아니면 칸을 만들지 않는다" "$r"
r="$(mac_edge 99999999999999999999 99999999999999999999)"; [ "$r" = "-|-" ]; t $? "[맥 경계] 19자리 넘는 값(정수 넘침) → 칸을 만들지 않는다" "$r"

echo "== 윈 =="
run_ps() { # run_ps <제조사> <모델> [<CIM 대역: ok|throw>] [<남은 디스크 바이트 대역 · throw 면 예외>]
  JARVIS_LIB_ONLY=1 JARVIS_HOME="$BASE/wh" perl -e 'alarm shift; exec @ARGV or exit 126' 90 "$PW" -NoProfile -Command ". '$PS' *> \$null;
function Write-Log([string]\$m) { }
function claude { 'claude 9.9.9' }
function Get-CimInstance { param([string]\$Namespace, [string]\$ClassName, [int]\$OperationTimeoutSec, [switch]\$Dummy)
  if ('${3:-ok}' -eq 'throw') { throw 'cim unavailable' }
  if ('${3:-ok}' -eq 'mem1' -and \$ClassName -eq 'Win32_PhysicalMemory') { return @([pscustomobject]@{ Capacity = [uint64]1 }) }
  if (\$ClassName -eq 'Win32_PhysicalMemory') { return @([pscustomobject]@{ Capacity = [uint64]8589934592; SerialNumber = 'SN-SECRET-10'; PartNumber = 'PN-SECRET-11'; Tag = 'TAG-SECRET-12' }, [pscustomobject]@{ Capacity = [uint64]8589934592; SerialNumber = 'SN-SECRET-13' }) }
  [pscustomobject]@{ TotalPhysicalMemory = [uint64]12000000000;  Manufacturer = '$1'; Model = '$2'; displayName = 'Defender'; SerialNumber = 'SN-SECRET-1'; IdentifyingNumber = 'ID-SECRET-2'; UUID = 'UUID-SECRET-3'; SMBIOSAssetTag = 'TAG-SECRET-4'; SystemSKUNumber = 'SKU-SECRET-5'; Name = 'PC-SECRET-6'; UserName = 'DOM\\USER-SECRET-7'; PrimaryOwnerName = 'OWNER-SECRET-8'; Domain = 'DOMAIN-SECRET-9' } }
function Get-InstallDiskFreeBytes { if ('${4:-107374182400}' -eq 'throw') { throw 'no drive' }; return [uint64]'${4:-107374182400}' }
Get-InstallEnv | ConvertTo-Json -Compress" 2>/dev/null | tail -1
}
w1="$(run_ps ' LENOVO ' '20XW0055KR ')"
w2="$(run_ps '' '')"
w3="$(run_ps 'HP' 'X' throw 0)"
w4="$(run_ps 'HP' 'X' ok 4398046511104)"
w5="$(run_ps 'HP' 'X' ok throw)"
w6="$(run_ps 'HP' 'X' ok 536870912)"
w9="$(run_ps 'HP' 'X' mem1)"
# 실제 Get-InstallDiskFreeBytes(대역 없이) — 맥 pwsh 라 LOCALAPPDATA 를 이 시험 폴더로 준다(윈에선 %LOCALAPPDATA% 드라이브).
w7="$(LOCALAPPDATA="$BASE" JARVIS_LIB_ONLY=1 JARVIS_HOME="$BASE/wh" perl -e 'alarm shift; exec @ARGV or exit 126' 90 "$PW" -NoProfile -Command ". '$PS' *> \$null; function Write-Log([string]\$m) { }; function Get-CimInstance { throw 'x' }; Get-InstallEnv | ConvertTo-Json -Compress" 2>/dev/null | tail -1)"
printf '%s' "$w1" | python3 -c '
import json, sys
e = json.load(sys.stdin)
allowed = {"claude_ver","cys_ver","win_build","ps_ver","av","browser","hw_model","mem_gb","disk_free_gb","admin"}
print("model=" + ("1" if e.get("hw_model") == "LENOVO 20XW0055KR" else "0:" + str(e.get("hw_model"))))
print("keys=" + ("1" if set(e) <= allowed else "0:" + ",".join(sorted(set(e) - allowed))))
print("nosecret=" + ("1" if "SECRET" not in json.dumps(e) else "0"))' > "$BASE/wres" 2>/dev/null
printf '%s' "$w2" | python3 -c 'import json,sys; print("empty=" + ("1" if "hw_model" not in json.load(sys.stdin) else "0"))' >> "$BASE/wres" 2>/dev/null
grep -q '^model=1$' "$BASE/wres"; t $? "[윈 ⓐ] hw_model = 「제조사 모델」(앞뒤 빈칸 걷음)" "$(grep '^model' "$BASE/wres") · $w1"
grep -q '^keys=1$' "$BASE/wres"; t $? "[윈 ⓑ] env 열쇠 ⊆ 서버가 받는 열쇠" "$(grep '^keys' "$BASE/wres")"
grep -q '^nosecret=1$' "$BASE/wres"; t $? "[윈 ⓒ] 어느 값에도 고유번호·개인 문자열(시리얼·UUID·자산 태그·SKU·PC 이름·사용자·소유자·도메인) 대역 글자가 없다" "$w1"
grep -q '^empty=1$' "$BASE/wres"; t $? "[윈 ⓓ] 제조사·모델이 비었으면 hw_model 칸을 만들지 않는다" "$w2"
wkv() { printf '%s' "$1" | python3 -c 'import json,sys
try:
    e = json.load(sys.stdin)
except Exception:
    print("bad"); sys.exit()
def v(k):
    x = e.get(k, "-")
    return x if isinstance(x, str) else "<%s>%r" % (type(x).__name__, x)   # 글자가 아니면 드러나게(숫자 16 과 글자 「16」을 가른다)
print("%s|%s|%s" % (v("hw_model"), v("mem_gb"), v("disk_free_gb")))' 2>/dev/null; }
r="$(wkv "$w1")"; [ "$r" = "LENOVO 20XW0055KR|16|100" ]; t $? "[윈 ⓔ] mem_gb = 꽂힌 메모리 합(8+8 GiB) 「16」 · disk_free_gb = 「100」(글자)" "$r"
r="$(wkv "$w3")"; [ "$r" = "-|-|0" ];        t $? "[윈 경계] CIM 을 못 쓰면 모델·메모리 칸 없음 · 디스크는 CIM 없이 「0」" "$r"
r="$(wkv "$w4")"; [ "$r" = "HP X|16|4096" ]; t $? "[윈 경계] 남은 4 TiB → 「4096」" "$r"
r="$(wkv "$w5")"; [ "$r" = "HP X|16|-" ];    t $? "[윈 경계] 디스크를 못 읽으면 그 칸만 없다(나머지 칸은 그대로)" "$r"
r="$(wkv "$w9")"; [ "$r" = "HP X|-|100" ];   t $? "[윈 경계] 메모리 합 1 바이트(반올림 0) → 칸 없음(맥과 같은 뜻) · 디스크는 그대로" "$r"
r="$(wkv "$w6")"; [ "$r" = "HP X|16|1" ];    t $? "[윈 경계] 정확히 0.5 GiB → 「1」(반올림 = 올림 · 맥과 같은 뜻 · 은행가 반올림이면 0)" "$r"
r="$(wkv "$w7")"; bk="$(/bin/df -Pk "$BASE" 2>/dev/null | awk 'NR==2{print $4}')"
case "$r" in -\|-\|[0-9]*) [[ "${r##*|}" =~ ^[0-9]+$ ]] && [[ "$bk" =~ ^[0-9]+$ ]] && d=$(( ${r##*|} - (bk + 524288) / 1048576 )) && [ "${d#-}" -le 1 ] ;; *) false ;; esac
t $? "[윈 실경로] 대역 없는 Get-InstallDiskFreeBytes = 그 폴더 볼륨 남은 공간(df)의 정수 GB(±1)" "$r · df ${bk}KiB"
# 변환 함수 직접 — 못 읽는 값($null·빈 글자·글자·음수)은 빈 글자(부르는 쪽 가드가 없어져도 「0」 이 나가지 않게)
wc="$(JARVIS_LIB_ONLY=1 JARVIS_HOME="$BASE/wh" perl -e 'alarm shift; exec @ARGV or exit 126' 90 "$PW" -NoProfile -Command ". '$PS' *> \$null; @(\$null, '', 'abc', -1, 536870912, [double]17179869184) | ForEach-Object { '[' + (ConvertTo-InstallGb \$_) + ']' } | Out-String" 2>/dev/null | tr -d '\r\n ')"
[ "$wc" = "[][][][][1][16]" ]; t $? "[윈 경계] ConvertTo-InstallGb: \$null·빈 글자·글자·음수 → 빈 글자 · 0.5 GiB → 1 · 16 GiB(double) → 16" "$wc"
w8="$(LOCALAPPDATA='' USERPROFILE="$BASE" JARVIS_LIB_ONLY=1 JARVIS_HOME="$BASE/wh" perl -e 'alarm shift; exec @ARGV or exit 126' 90 "$PW" -NoProfile -Command ". '$PS' *> \$null; function Write-Log([string]\$m) { }; function Get-CimInstance { throw 'x' }; Get-InstallEnv | ConvertTo-Json -Compress" 2>/dev/null | tail -1)"
r="$(wkv "$w8")"; case "$r" in "-|-|"[0-9]*) true ;; *) false ;; esac; t $? "[윈 경계] %LOCALAPPDATA% 가 비면 사용자 폴더 드라이브로 잰다(disk 칸 있음)" "$r"
# 정적 — Get-InstallEnv·progress_env_fields 본문(주석 걷음)에 고유번호를 읽는 길이 없다(대역이 덮지 못하는 Get-WmiObject·wmic·ioreg 경로까지)
st="$(python3 - "$PS" "$SH" <<'PYS'
import re, sys
ps = open(sys.argv[1], encoding="utf-8-sig").read()
sh = open(sys.argv[2], encoding="utf-8").read()
def body(src, start, stop):
    i = src.index(start); j = src.index(stop, i)
    return "\n".join(l.split("#", 1)[0] for l in src[i:j].splitlines())   # 주석 걷음(설명 속 금지어에 걸리지 않게)
pb = body(ps, "function Get-InstallEnv {", "\n# ──")
sb = body(sh, "progress_env_fields() {", "\nprogress_send() {")
bad = [w for w in ("Win32_BIOS", "SerialNumber", "IdentifyingNumber", "UUID", "SMBIOSAssetTag", "SystemSKUNumber", "PartNumber", "COMPUTERNAME", "Get-WmiObject", "wmic", "TotalFreeSpace") if w.lower() in pb.lower()]
bad += ["sh:" + w for w in ("ioreg", "IOPlatform", "system_profiler", "hw.uuid", "kern.uuid", "hostname", "scutil") if w.lower() in sb.lower()]
db = body(ps, "function Get-InstallDiskFreeBytes {", "function ConvertTo-InstallGb")   # 주석 걷은 디스크 함수 본문(설명문에 걸리지 않게)
ok = ".AvailableFreeSpace" in db and "TotalFreeSpace" not in db and "Capacity" in pb
print("ok" if not bad and ok else "bad:" + ",".join(bad) + ("" if ok else ",no-AvailableFreeSpace/Capacity"))
PYS
)"
[ "$st" = "ok" ]; t $? "[정적] 두 OS env 본문(주석 제외)에 고유번호를 읽는 이름 0 · 윈 디스크 = AvailableFreeSpace(사용자 할당량 반영)" "$st"
printf '%s%s%s%s' "$w3" "$w4" "$w5" "$w6" | grep -q SECRET; [ $? -ne 0 ]; t $? "[윈 ⓒ+] 메모리 칸을 읽어도 모듈 시리얼·부품 번호 대역 글자 0" "SECRET 이 실렸다"

echo "== 합계: ok $pass · FAIL $fail =="
[ "$fail" -eq 0 ]
