#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""로그인 보존 축 — 씨앗을 심고, 지운 뒤에 어떤 모습이어야 하는지(기대)를 함께 적는다.

왜 씨앗을 코드로 심는가
  「지우고 다시 깐다」 뒤에 로그인이 살아 있는지는 **사람 노트북에서만** 재고 있었다.
  그래서 그 문장(「로그인은 그대로 둡니다」)은 윈도우에서 한 번도 기계가 재 본 적이 없다.
  씨앗을 코드로 심으면 러너가 매번 같은 조건으로 잰다.

무엇을 심는가 (세 가지)
  ⓐ ~/.claude/.credentials.json   — 로그인이 파일로 떨어졌을 때의 자리. 바이트가 그대로여야 한다.
  ⓑ ~/.claude.json                — 남의 파일이면서 우리 칸 하나가 섞여 있는 자리.
                                     실물 모양을 흉내낸다: 깊이 8 · 한글 · 이모지 · 긴 문자열 ·
                                     정수/실수 · 빈 배열 · 빈 객체 · null · 날짜꼴 문자열 ·
                                     oauthAccount 모양 칸.
  ⓒ ~/.claude/settings.json       — 우리 훅과 **남의 훅**이 같이 든 자리.

⚠기대를 여기서 함께 적는 까닭
  기대를 검사기 쪽에 적으면 씨앗을 고칠 때 기대를 같이 못 고치는 일이 생긴다.
  씨앗과 기대는 한 곳에서 나와야 한다.

쓰는 법
  python3 tests/login-seed.py --home <자리> --os mac|win --jarvis-home <자리> --out <기대파일>
"""
import argparse, hashlib, json, os, sys

# ⚠윈도우의 파이썬은 stdout 을 그 기계의 코드페이지(cp1252·cp949)로 잡는다 — 이 파일은 한글로
#   말하므로 **첫 줄을 찍는 순간** UnicodeEncodeError 로 죽는다(러너 첫 실행 실측 2026-09-08 ·
#   같은 날 운영자 노트북에서 난 즉사와 같은 병이다). 여기서 UTF-8 로 되돌린다.
#   errors="backslashreplace" 인 까닭: 못 찍는 글자가 있어도 **죽지 않고 그 자리를 보여 주는** 것이
#   검사 축에서는 낫다. 죽으면 잰 것이 없어지고, 남으면 무엇이 문제인지 다음 사람이 본다.
for _s in (sys.stdout, sys.stderr):
    try:
        _s.reconfigure(encoding="utf-8", errors="backslashreplace")
    except Exception:
        pass

CRED_TEXT = (
    '{\n'
    '  "claudeAiOauth": {\n'
    '    "accessToken": "sk-ant-oat01-회상-씨앗-값-입니다-0123456789",\n'
    '    "refreshToken": "sk-ant-ort01-씨앗-갱신-값-9876543210",\n'
    '    "expiresAt": 1789000000000,\n'
    '    "scopes": ["user:inference", "user:profile"],\n'
    '    "subscriptionType": "max"\n'
    '  }\n'
    '}\n'
)


def claude_json(jarvis_home, home):
    return {
        # 우리 칸 — 지워져야 한다
        "hasCompletedOnboarding": True,
        # 설치기가 큰 화면 권유 질문을 미리 넘기려고 99 로 적어 두는 칸 — 우리 자국이니 지워져야 한다.
        #   ⚠이 칸은 오래 전부터 심고 있었는데 **씨앗에도 표에도 없어서** 아무도 안 지웠다
        #     (2026-09-10 자국 표를 채우다 드러났다). 씨앗에 넣어 축이 실제로 재게 한다.
        "fullscreenUpsellSeenCount": 99,
        # 로그인과 이어진 칸 — 살아 있어야 한다
        "oauthAccount": {
            "accountUuid": "9f1c0b2e-7a44-4d8e-9c31-000000000001",
            "emailAddress": "owner@example.com",
            "organizationUuid": "9f1c0b2e-7a44-4d8e-9c31-000000000002",
            "organizationRole": "admin",
            "workspaceRole": None,
            "organizationName": "자비스 연구소 \U0001f3e2",
        },
        "userID": "0123456789abcdef0123456789abcdef0123456789abcdef0123456789abcdef",
        # 날짜꼴 문자열 — 왕복하면서 날짜로 바뀌어 버리는 일이 있다(그러면 여기서 붉어진다)
        "firstStartTime": "2026-03-01T09:15:30.123Z",
        "lastReleaseNotesSeen": "2026-09-01T00:00:00Z",
        # 숫자 세 갈래
        "numStartups": 137,
        "zeroValue": 0,
        "floatValue": 1.5,
        "wholeFloat": 2.0,
        "bigNumber": 1789000000000,
        # 2^53 을 넘는 정수 — 실수로 바꿔 견주면 뭉개져도 같아 보인다(교차 검토 [2]).
        "hugeInteger": 9007199254740993,
        # 참·거짓·빈 것·없는 것
        "isQualifiedForDataSharing": False,
        "emptyArray": [],
        "emptyObject": {},
        "nullValue": None,
        # 한 칸짜리 배열 — 왕복에서 배열이 벗겨지는 일이 있다(그러면 여기서 붉어진다)
        "oneItemArray": [{"only": 1}],
        "mixedArray": [1, 2.5, "셋", True, None],
        # 한글·이모지·긴 문자열
        "한글칸": "값이 그대로 있어야 합니다 ✅",
        "emojiValue": "\U0001f40b\U0001f1f0\U0001f1f7✨",
        "longString": "가" * 2048,
        "escapes": "줄바꿈\n탭\t따옴표\"역슬\\슬래쉬/",
        # 깊이 8 — 왕복 깊이 제한에 걸리면 여기서 붉어진다
        "deep": {"l2": {"l3": {"l4": {"l5": {"l6": {"l7": {"l8": "바닥 \U0001f3af"}}}}}}},
        "projects": {
            jarvis_home: {"allowedTools": [], "hasTrustDialogAccepted": True},
            "/남의/프로젝트": {"allowedTools": ["Bash"], "hasTrustDialogAccepted": True},
            # 🔴사용자 **홈** 칸 — 설치기가 이 자리에도 신뢰를 심게 됐다(2026-09-10). 그런데 이 칸은
            #   참가자가 이미 쓰던 것일 수 있고 `allowedTools` 같은 그분의 값이 함께 있다.
            #   ★이 시험에서는 설치기를 돌리지 않으므로 「우리가 넣었다」는 기록이 없다 ⇒ 제거기는
            #     이 칸에 **손대면 안 된다**(칸도 신뢰 값도 그대로 남아야 한다).
            #   그것이 1차 REVISE ④ 가 가리킨 자리이고, 이 픽스처가 그 자리를 재는 유일한 축이다.
            home: {"allowedTools": ["Read"], "hasTrustDialogAccepted": True},
        },
        "mcpServers": {},
        "tipsHistory": {"new-user-warmup": 1, "shift-enter": 12},
    }


def settings_json():
    return {
        # 우리 칸 셋 — 지워져야 한다
        "theme": "dark",
        "skipDangerousModePermissionPrompt": True,
        "remoteControlAtStartup": True,
        # 남의 칸 — 살아 있어야 한다
        "model": "opus",
        "남의칸": {"보존": "되어야 합니다 ✅", "깊이": {"l3": [1, 2, 3]}},
        "env": {"MY_VAR": "값"},
        "hooks": {
            "SessionStart": [
                # 우리 훅 — 이것만 빠져야 한다
                {"matcher": "startup", "hooks": [
                    {"type": "command", "command": "bash ~/.cys/pack/bin/session-start.sh"}]},
                # 남의 훅 — 남아야 한다. 빠지고 나면 이 목록은 한 칸짜리가 된다
                # (한 칸짜리 배열이 왕복에서 벗겨지면 여기서 붉어진다)
                {"matcher": "startup", "hooks": [
                    {"type": "command", "command": "bash ~/my-own/greet.sh"}]},
            ],
            "PreToolUse": [
                {"matcher": "Bash", "hooks": [
                    {"type": "command", "command": "bash ~/my-own/pre.sh"}]},
            ],
        },
    }


def expected_claude_json(seed, target_os, jarvis_home):
    d = json.loads(json.dumps(seed))
    d.pop("hasCompletedOnboarding", None)
    d.pop("fullscreenUpsellSeenCount", None)
    # 🔴2026-09-10 개정 — **두 OS 가 같아졌다.** 앞 판은 「맥만 뺀다 · 윈은 안 뺀다」였고, 그 갈림을
    #   기대에 갈라 적어 두어 **갈림이 굳어 있었다**(축이 옛 동작을 지키는 자리가 됐다).
    #   ★자비스 작업 폴더의 projects 칸은 처음부터 끝까지 **우리가 만든 자국**이다 — 설치기가 심고,
    #     재설치가 다시 심는다. 그러므로 지우개는 그 칸을 **칸째** 뺀다(footprint W-/M-CLAUDEJSON).
    #   ⚠사용자 홈의 칸은 다르다: 제거기는 **설치기가 적어 둔 기록에 있는 키만** 뺀다.
    #     이 시험은 설치기를 돌리지 않아 그 기록이 없다 ⇒ 홈 칸은 **통째로 그대로 남아야 한다.**
    #     (그래서 아래에서 홈 키를 pop 하지 않는다 — 그것이 이 축이 재는 바로 그 성질이다.)
    d["projects"].pop(jarvis_home, None)
    return d


def expected_settings(seed):
    d = json.loads(json.dumps(seed))
    for k in ("theme", "skipDangerousModePermissionPrompt", "remoteControlAtStartup"):
        d.pop(k, None)
    d["hooks"]["SessionStart"] = [e for e in d["hooks"]["SessionStart"]
                                  if "session-start" not in json.dumps(e)
                                  and "role-bootstrap" not in json.dumps(e)]
    return d


def refuse_if_live_machine(home, allow_live):
    """살아 있는 기계에서 이 시험이 시작되는 것을 막는다.

    🔴왜 이 칸이 여기 있는가 (2026-09-08 사고 · 개발 에이전트 자신이 낸 것)
      개발 에이전트가 `HOME` 만 임시 폴더로 바꿔 놓고 개발기에서 제거기를 돌렸다. 그런데 제거기 안의
      `CYS_APP` 은 `/Applications/cys.app` 로 **절대경로**라 HOME 과 아무 상관이 없다.
      그 한 줄에 **살아 있는 앱이 지워졌다.** 「HOME 을 바꿨으니 격리다」가 틀렸던 것이다.
    ★그래서 조심하라고 적지 않는다 — 시작 자리에서 **거절**한다.
      제거기를 부르는 모든 길은 먼저 여기를 지나기 때문이다(씨앗 없이는 잴 것이 없다).
    """
    if os.path.abspath(os.path.expanduser("~")) == home:
        print("실제 사용자 폴더에는 씨앗을 심지 않습니다: " + home, file=sys.stderr)
        return 3
    if allow_live or os.environ.get("CI"):
        return 0
    live = []
    if os.path.isdir("/Applications/cys.app"):
        live.append("/Applications/cys.app")
    la = os.environ.get("LOCALAPPDATA")
    if la and os.path.isdir(os.path.join(la, "cys")):
        live.append(os.path.join(la, "cys"))
    if not live:
        return 0
    print("", file=sys.stderr)
    print("이 기계에는 cys 가 실제로 깔려 있습니다: " + " · ".join(live), file=sys.stderr)
    print("이 시험은 제거기를 돌립니다. 제거기가 지우는 자리 가운데 몇은 HOME 과 무관한", file=sys.stderr)
    print("절대경로라, HOME 을 바꿔 놓아도 **이 기계의 것이 지워집니다.**", file=sys.stderr)
    print("러너나 지워도 되는 게스트에서 돌리십시오(CI 환경변수가 서 있으면 그냥 진행합니다).", file=sys.stderr)
    print("정말 지울 각오가 된 기계라면 --allow-live 를 붙이십시오.", file=sys.stderr)
    return 4


def write_text(path, text):
    os.makedirs(os.path.dirname(path), exist_ok=True)
    # BOM 없이·줄바꿈은 LF 로. 두 운영체제에서 같은 바이트가 나와야 비교가 성립한다.
    with open(path, "w", encoding="utf-8", newline="\n") as f:
        f.write(text)


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--home", required=True)
    ap.add_argument("--os", dest="target_os", required=True, choices=["mac", "win"])
    ap.add_argument("--jarvis-home", default=None)
    ap.add_argument("--out", required=True)
    ap.add_argument("--allow-live", action="store_true",
                    help="살아 있는 기계에서의 거절을 푼다 — 지울 각오가 된 게스트에서만")
    a = ap.parse_args()

    home = os.path.abspath(a.home)
    jarvis_home = a.jarvis_home or os.path.join(home, "install-jarvis")

    rc = refuse_if_live_machine(home, a.allow_live)
    if rc:
        return rc

    # 맥판은 plutil 키 경로를 쓰므로 **경로 어디에든** 마침표가 있으면 그 칸을 못 가리킨다
    #   (실측 2026-09-08: 씨앗을 /tmp/lp.81ZHSN 에 심었더니 스크립트가 「못 살핌」으로 정직하게
    #    비켜 갔고, 축은 그것을 손실로 읽어 붉어졌다 — 스크립트가 아니라 **씨앗이 틀린 것**이었다).
    #   ⇒ 앞자리만 보면 안 된다. 경로 전체를 본다.
    if a.target_os == "mac" and "." in jarvis_home:
        print("씨앗 자리 경로에 마침표가 있어 맥 기대를 세울 수 없습니다(plutil 키 경로 제약): "
              + jarvis_home, file=sys.stderr)
        return 2

    cj = claude_json(jarvis_home, home)
    st = settings_json()

    write_text(os.path.join(home, ".claude.json"),
               json.dumps(cj, ensure_ascii=False, indent=2) + "\n")
    write_text(os.path.join(home, ".claude", "settings.json"),
               json.dumps(st, ensure_ascii=False, indent=2) + "\n")
    write_text(os.path.join(home, ".claude", ".credentials.json"), CRED_TEXT)

    expect = {
        "os": a.target_os,
        "home": home,
        "jarvis_home": jarvis_home,
        "cred_sha256": hashlib.sha256(CRED_TEXT.encode("utf-8")).hexdigest(),
        "cred_bytes": len(CRED_TEXT.encode("utf-8")),
        "claude_json": expected_claude_json(cj, a.target_os, jarvis_home),
        "settings": expected_settings(st),
    }
    os.makedirs(os.path.dirname(os.path.abspath(a.out)) or ".", exist_ok=True)
    with open(a.out, "w", encoding="utf-8", newline="\n") as f:
        json.dump(expect, f, ensure_ascii=False, indent=2)

    print("씨앗 심음:")
    print("  " + os.path.join(home, ".claude", ".credentials.json") +
          "  sha256=" + expect["cred_sha256"][:16] + "…")
    print("  " + os.path.join(home, ".claude.json"))
    print("  " + os.path.join(home, ".claude", "settings.json"))
    print("기대 적음: " + a.out)
    return 0


if __name__ == "__main__":
    sys.exit(main())
