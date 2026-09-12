#!/usr/bin/env python3
"""토론장 참가 자리 보존 축 — 씨앗과 대조 (교차 검토 1차·2차 수정의 독립 시험)

무엇을 재는가 — 말이 아니라 **동작**이다.
  ⑴ AGORA_HOME 이 **삭제 루트 안**에 있어도(중첩) 열쇠 파일이 **바이트 그대로** 남는가.
  ⑵ cys 자리 안의 안내 파일이 지워지기 전에 **밖으로 옮겨졌는가**(1차 결착).
  ⑶ 중첩된 삭제 루트의 **나머지**는 제대로 지워졌는가(보존이 삭제를 통째로 막아 버리면 그것도 결함이다).

★왜 「진단 화면에 남깁니다라고 찍혔다」로 재지 않는가: 그 화면이 참인지가 바로 이 축이 묻는 것이다.
  교차 검토 2차가 잡은 것이 정확히 그 자리였다 — 화면은 남긴다고 말하고 동작은 지웠다.

쓰는 법:
  python3 tests/agora-preserve.py seed   --home <샌드박스> --os mac|win [--allow-live]
                                         [--stale-out] [--unreadable]
  python3 tests/agora-preserve.py verify --home <샌드박스> [--expect-fail] [--expect-cys-kept]

★`--stale-out` · `--unreadable` 은 **실패를 실제로 주입하는** 씨앗이다(4차 지적 채택 2026-09-09).
  「장치를 넣었다」를 확인하는 것과 「장치가 문다」를 재는 것은 다른 일이다 — 뒤엣것만이 축이다.
  · `--stale-out`  = 밖에 **내용이 다른 반쪽 안내**를 미리 놓는다(지난 실행이 치우기에 실패한 상태).
                     그 상태에서 제거기를 돌리면 **원본(`~/.cys`)을 지우면 안 된다**(1차-RETRY).
  · `--unreadable` = 삭제 루트 안에 **이 계정으로 못 여는 자리**를 놓는다. 열거·삭제가 실제로 실패한다.
                     그때 제거기는 「지웠다」가 아니라 **「일부 남음」**이라고 말해야 한다(2차-NEW-ENUM).
  · `--outside-link` = 삭제 루트 안에 **바깥 폴더를 가리키는 링크**(윈 junction·symlink · 맥 symlink)를 놓는다.
                     지우개는 **링크만** 지우고 바깥 폴더·파일은 바이트 그대로 남겨야 한다.
                     맥 `rm -rf` 는 링크만 지운다(실측). 두 OS 를 같은 뜻으로 맞춘 것을 여기서 잰다.
                     ⚠윈 5.1 이 링크를 뚫는지는 **판본에 따라 다르다**(2026-09-09 러너 실측: 안 뚫었다).
                     그래서 본체 축은 「뚫었는가」가 아니라 **「열거하지 못한 자리를 지웠는가」**다.
"""
import argparse
import hashlib
import importlib.util
import json
import os
import sys

HERE = os.path.dirname(os.path.abspath(__file__))

# 🔴살아 있는 기계 거절 판정은 **한 곳에만** 적는다. 여기서 다시 쓰지 않고 그 파일을 불러 쓴다
#   (판정을 두 곳에 적으면 한쪽만 고쳐지는 날이 온다 — 이 저장소가 이미 겪은 형태다).
def _load_gate():
    path = os.path.join(HERE, "login-seed.py")
    spec = importlib.util.spec_from_file_location("login_seed", path)
    mod = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(mod)
    return mod.refuse_if_live_machine


def sha(path):
    with open(path, "rb") as f:
        return hashlib.sha256(f.read()).hexdigest()


def wr(path, text):
    os.makedirs(os.path.dirname(path), exist_ok=True)
    with open(path, "w", encoding="utf-8", newline="\n") as f:
        f.write(text)


def make_link(target, link, osname):
    """같은 곳을 가리키되 글자가 다른 자리를 만든다. 윈도우는 권한이 없으면 junction 으로 대신한다."""
    if os.path.islink(link) or os.path.exists(link):
        try:
            os.remove(link)
        except OSError:
            import shutil
            shutil.rmtree(link, ignore_errors=True)
    try:
        os.symlink(target, link, target_is_directory=True)
        return "symlink"
    except (OSError, NotImplementedError, AttributeError):
        if osname != "win":
            raise
        # 윈도우에서 symlink 는 권한을 탄다. junction 은 안 탄다 — 같은 것을 재는 데 충분하다.
        import subprocess
        subprocess.run(["cmd", "/c", "mklink", "/J", link, target],
                       check=True, stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
        return "junction"


def make_junction(target, link):
    """윈도우 junction — 권한을 안 타는 길이다. 만들었으면 True."""
    import subprocess
    r = subprocess.run(["cmd", "/c", "mklink", "/J", link, target],
                       stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
    return r.returncode == 0


def seed(home, osname, allow_live, shape, stale_out=False, unreadable=False, outside_link=False,
         link_in_subdir=False, dangling_link=False, root_link=False, chain=0):
    rc = _load_gate()(home, allow_live)
    if rc:
        return rc

    # ★중첩이 이 시험의 전부다 — 참가 자리를 **우리가 지우는 자리 안**에 둔다.
    #   `~/.cys` 는 제거기가 통째로 지우는 자리다(맥 M-CYSHOME · 윈 W-CYSHOME).
    agora = os.path.join(home, ".cys", "forum")
    key = os.path.join(agora, "id_ed25519")
    wr(key, "PRESERVE-ME-BYTES-0123456789\n")
    wr(os.path.join(agora, "participant.json"), '{"id":"jarvis-preserve"}\n')

    # 중첩 루트의 **나머지** — 이건 지워져야 한다(보존이 삭제를 통째로 막으면 그것도 결함).
    wr(os.path.join(home, ".cys", "pack", "must-die.txt"), "gone\n")

    # 1차 — cys 자리 안의 안내 파일. 밖에는 없어야 옮기기가 일어난다.
    wr(os.path.join(home, ".cys", "claude", "skills", "agora-delegate", "SKILL.md"),
       "name: agora-delegate\n")

    # 제거기가 「미설치」로 끝내 버리면 아무것도 안 지운다 ⇒ 잴 것이 없다. 자국 하나를 더 놓는다.
    wr(os.path.join(home, "install-jarvis", "bootstrap.log"), "seed\n")
    # 🔴설치 도우미는 자기 작업 폴더에 **소유 표식**을 놓는다(2026-09-10 · 2차 N3). 제거기는 그 표식이
    #   있을 때만 그 폴더를 재귀로 지운다 — JARVIS_HOME 은 환경변수라 무엇이든 들어올 수 있어서다.
    #   ★이 씨앗은 「설치가 끝난 기계」를 흉내 내는 것이므로 **설치기가 놓는 것을 똑같이 놓아야 한다.**
    #     안 놓으면 제거기가 「우리 폴더가 아니다」로 옳게 판정하고, 축은 그것을 손실로 읽는다.
    wr(os.path.join(home, "install-jarvis", ".jarvis-owned"), "jarvis-installer-owned v1\n")

    # 🔴이전될 안내의 **내용까지** 적어 둔다(2차 검토 지적 채택). 앞 판은 목적지 **폴더가 생겼는지**만
    #   봤다 — 폴더만 만들어지고 알맹이가 반만 와도 통과했고, 그 반쪽은 다음 실행에서
    #   「이미 있다」로 건너뛰어 **영구히 고착**된다.
    skill_in = os.path.join(home, ".cys", "claude", "skills", "agora-delegate")
    skill_files = {}
    for root, _dirs, files in os.walk(skill_in):
        for fn in files:
            full = os.path.join(root, fn)
            skill_files[os.path.relpath(full, skill_in).replace("\\", "/")] = sha(full)

    # ★`AGORA_HOME` 으로 넘길 값 — 겉모습만 다르고 **가리키는 곳은 같은** 자리다.
    #   `plain` = 정규 경로 · `dotseg` = `.`·`..` 가 낀 경로 · `symlink` = 링크를 거친 경로.
    #   앞 판은 `plain` 한 형태만 심었고, 그래서 나머지 둘로는 열쇠가 지워지는 것을 못 봤다.
    if shape == "dotseg":
        handed = os.path.join(home, ".cys", ".", "..", ".cys", "forum")
    elif shape == "symlink":
        link = os.path.join(home, "forum-link")
        kind = make_link(agora, link, osname)
        print("  링크 모양 = " + kind)
        handed = link
    else:
        handed = agora

    # 🔴**링크 사슬** — 계약은 「32겹까지 따라간다」다(7차 지적 채택 2026-09-09).
    #   경계를 말로만 적어 두면 한 칸 어긋난 채로 오래 산다 — 실제로 32겹째에서 실패하고 있었다.
    #   ⇒ 2단·32단(되어야 한다) · 33단(사유와 함께 실패해야 한다)을 실기로 심는다.
    #   ⚠맥은 사슬 길이를 **OS 가** 정한다(`cd -P` · SYMLOOP_MAX). 32/33 축은 윈도우 전용이고
    #     맥에는 어느 판본에서도 안전한 2단만 건다.
    if chain > 0:
        prev = agora
        for i in range(1, chain + 1):
            link = os.path.join(home, "chain-%03d" % i)
            if osname == "win":
                if not make_junction(prev, link):
                    print("::error::사슬 %d번째 마디를 못 만들었습니다" % i)
                    return 3
            else:
                os.symlink(prev, link)
            prev = link
        handed = prev
        print("  링크 사슬 %d겹을 심었습니다: %s" % (chain, handed))

    expect = {
        "os": osname,
        "shape": shape,
        "agora_home": agora,
        "handed": handed,
        "key": key,
        "key_sha": sha(key),
        "must_die": os.path.join(home, ".cys", "pack", "must-die.txt"),
        "skill_in_cys": skill_in,
        "skill_out": os.path.join(home, ".claude", "skills", "agora-delegate"),
        "skill_files": skill_files,
        "stale_out": bool(stale_out),
        "unreadable": "",
        "outside": None,
        "dangling": [],
        "root_link": None,
        "chain": int(chain),
        # ★보존과 무관한 **정상 루트** — 이것이 사라졌는지도 재야 한다(7차 지적 채택).
        #   앞 판은 「남겨야 할 것이 남았는가」만 봤다. 그러면 이번 수정이 **정상 삭제를 막는 회귀**를
        #   내도 축이 초록이다. 남기는 축과 지우는 축은 짝이어야 한다.
        "normal_root": os.path.join(home, "install-jarvis"),
    }

    # 🔴🔴**삭제 루트 자신이 링크**인 경우 — `~/.cys` 가 남의 폴더를 가리키고 참가 자리가 그 안에 있다.
    #   앞 판은 실경로를 구해 **그 대상 폴더**를 훑어 지웠다(6차 BLOCK). 지우개는 **이름표만** 지워야 한다.
    #   ⛔이 갈래는 나머지 대조를 쓰지 않는다 — 대상 안엣것은 **하나도 없어지면 안 되기** 때문이다.
    if root_link:
        import shutil
        target = os.path.join(home, "shared-root")
        if os.path.exists(target):
            shutil.rmtree(target)
        shutil.move(os.path.join(home, ".cys"), target)
        link = os.path.join(home, ".cys")
        if osname == "win":
            if not make_junction(target, link):
                print("::error::삭제 루트 링크를 못 만들었습니다")
                return 3
        else:
            os.symlink(target, link)
        survive = [
            os.path.join(target, "pack", "must-die.txt"),
            os.path.join(target, "claude", "skills", "agora-delegate", "SKILL.md"),
        ]
        expect["root_link"] = {
            "link": link,
            "target": target,
            "key": os.path.join(target, "forum", "id_ed25519"),
            "key_sha": expect["key_sha"],
            "survive": survive,
        }
        print("  삭제 루트를 링크로 바꿨습니다: " + link + " -> " + target)

    # 🔴삭제 루트 안에 **바깥을 가리키는 링크**를 놓는다. 지우개는 링크만 지워야 한다.
    #   ⛔「링크가 사라졌다」로 끝내지 않는다 — 바깥 파일의 **바이트**까지 대조한다.
    if outside_link:
        out_dir = os.path.join(home, "outside-target")
        out_file = os.path.join(out_dir, "keepme.txt")
        wr(out_file, "OUTSIDE-BYTES-DO-NOT-TOUCH\n")
        # ★링크를 **하위 폴더 안**에 두는 갈래 — 그 폴더의 열거가 실패했을 때 삭제 단계가
        #   그 폴더를 다시 뚫는지(두 번째 재귀) 보는 자리다(5차 BLOCK).
        parent = os.path.join(home, ".cys", "sub") if link_in_subdir else os.path.join(home, ".cys")
        os.makedirs(parent, exist_ok=True)
        links = []
        if osname == "win":
            j = os.path.join(parent, "link-junction")
            if make_junction(out_dir, j):
                links.append(j)
            else:
                print("  ⚠junction 을 못 만들었습니다 — 이 축은 그만큼 덜 잽니다")
            sym = os.path.join(parent, "link-symlink")
            try:
                os.symlink(out_dir, sym, target_is_directory=True)
                links.append(sym)
            except OSError:
                print("  ⚠symlink 는 권한이 없어 못 만들었습니다(junction 으로만 잽니다)")
        else:
            sym = os.path.join(parent, "link-symlink")
            os.symlink(out_dir, sym)
            links.append(sym)
        if not links:
            print("::error::바깥 링크를 하나도 못 만들었습니다 — 이 축은 아무것도 재지 못합니다")
            return 3
        expect["outside"] = {
            "dir": out_dir,
            "file": out_file,
            "file_sha": sha(out_file),
            "links": links,
            # ★하위 폴더에 두는 갈래에서는 **링크가 남는 것이 정답**이다 — 그 폴더의 열거가 실패하도록
            #   짠 자리라 지우개가 그 안을 볼 수 없다. 여기서 재는 것은 「바깥이 무사한가」와
            #   「사실대로 말하는가」이지 「링크가 사라졌는가」가 아니다.
            "links_may_remain": bool(link_in_subdir),
            # ★그리고 **그 폴더 자신은 남아 있어야** 한다. 열거하지 못한 자리를 지우는 것은
            #   「무엇을 지우는지 모르는 채로 지운 것」이다 — 삭제층의 두 번째 재귀가 하던 일이 정확히 그것이다.
            #   이 칸이 그 뮤턴트를 잡는 축이다(뮤턴트는 그 폴더를 통째로 지운다).
            "parent_must_remain": parent if link_in_subdir else "",
        }
        print("  바깥 폴더를 가리키는 링크 " + str(len(links)) + "개를 " + parent + " 에 심었습니다")

    # 🔴**끊어진 링크**(가리키던 곳이 사라진 이름표) — 흔한 잔재다.
    #   `Test-Path` 가 거짓이라 앞 판은 이것을 건너뛰고 정상 트리까지 「[남음]」으로 만들었다.
    if dangling_link:
        gone = os.path.join(home, "gone-target")
        wr(os.path.join(gone, "x.txt"), "will-be-removed\n")
        dang = []
        d = os.path.join(home, ".cys", "dangling-link")
        made = False
        if osname == "win":
            made = make_junction(gone, d)
        else:
            os.symlink(gone, d)
            made = True
        if not made:
            print("::error::끊어진 링크를 못 만들었습니다")
            return 3
        import shutil
        shutil.rmtree(gone)          # ★가리키던 곳을 없앤다 = 이름표만 남는다
        dang.append(d)
        expect["dangling"] = dang
        print("  끊어진 링크를 심었습니다: " + d)

    # 🔴반쪽 안내를 **밖에 미리** 놓는다 — 지난 실행이 옮기다 말고 치우기에도 실패한 상태다.
    #   앞 판은 이 상태에서 「대상이 있다」며 이전 분기를 건너뛰고 원본을 지웠다(1차-RETRY).
    if stale_out:
        wr(os.path.join(expect["skill_out"], "SKILL.md"), "STALE-HALF-COPY\n")
        print("  반쪽 안내를 밖에 심었습니다(내용이 다릅니다): " + expect["skill_out"])

    # 🔴열거·삭제가 **실제로 실패**하는 자리를 삭제 루트 안에 놓는다(권한을 뺏는다).
    #   ⛔「가드를 넣었는지」를 보는 것이 아니라 「가드가 무는지」를 본다.
    if unreadable:
        locked = os.path.join(home, ".cys", "locked")
        wr(os.path.join(locked, "inside.txt"), "cannot-read\n")
        if osname == "win":
            # 윈도우에는 `chmod 000` 이 없다 — 같은 뜻은 **이 계정에 대한 거부 ACE** 다.
            #   ⛔심지 못했으면 그냥 죽는다: 「축이 조용히 아무것도 안 재는」 길을 만들지 않는다.
            import subprocess
            user = os.environ.get("USERNAME") or ""
            if not user:
                print("::error::USERNAME 을 못 읽어 못 여는 자리를 심지 못했습니다")
                return 3
            r = subprocess.run(["icacls", locked, "/deny", user + ":(OI)(CI)(RX,DE)"],
                               stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
            if r.returncode != 0:
                print("::error::거부 ACE 를 심지 못했습니다(icacls rc=" + str(r.returncode) + ")")
                return 3
        else:
            os.chmod(locked, 0o000)
        expect["unreadable"] = locked
        print("  못 여는 자리를 심었습니다: " + locked)
    with open(os.path.join(home, "agora-expect.json"), "w", encoding="utf-8") as f:
        json.dump(expect, f, ensure_ascii=False, indent=2)
    print("씨앗을 놓았습니다(중첩 설정 · 모양=" + shape + "): " + agora)
    print("  AGORA_HOME 으로 넘길 값 = " + handed)
    print("  열쇠 지문 = " + expect["key_sha"][:16] + "…")
    print("  안내 파일 " + str(len(skill_files)) + "개의 지문을 적어 두었습니다")
    return 0


def verify_cys_kept(home, e):
    """이 실행은 **원본을 남겼어야 한다**(fail-closed 가 물었는가)."""
    bad = []
    cys = os.path.join(home, ".cys")
    if not os.path.isdir(cys):
        bad.append("원본을 지웠다 — 남겨야 하는 실행인데 지웠다: " + cys)
    if not os.path.isfile(e["key"]):
        bad.append("참가 열쇠가 사라졌다: " + e["key"])
    elif sha(e["key"]) != e["key_sha"]:
        bad.append("참가 열쇠의 내용이 바뀌었다: " + e["key"])
    if not os.path.exists(e["must_die"]):
        bad.append("원본 안엣것을 지웠다: " + e["must_die"])
    if not os.path.isdir(e["skill_in_cys"]):
        bad.append("cys 자리 안의 안내를 지웠다(밖으로 못 옮긴 채로): " + e["skill_in_cys"])
    for b in bad:
        print("  어긋남: " + b)
    if not bad:
        print("  대조 통과: 원본(" + cys + ")이 그대로 있고 열쇠 바이트도 같습니다 — 지우개가 멈췄습니다.")
    return 0 if not bad else 1


def verify_root_link(e):   # noqa: 인자 e 에 normal_root 도 들어 있다
    """삭제 루트가 링크였다 — **이름표만** 사라지고 가리키던 자리는 통째로 남아야 한다."""
    bad = []
    r = e["root_link"]
    if os.path.lexists(r["link"]):
        bad.append("가리키기(이름표)가 남았다: " + r["link"])
    if not os.path.isdir(r["target"]):
        bad.append("링크를 따라가 남의 폴더를 지웠다: " + r["target"])
    else:
        if not os.path.isfile(r["key"]):
            bad.append("링크를 따라가 참가 열쇠를 지웠다: " + r["key"])
        elif sha(r["key"]) != r["key_sha"]:
            bad.append("참가 열쇠의 내용이 바뀌었다: " + r["key"])
        for f in r["survive"]:
            if not os.path.exists(f):
                bad.append("링크를 따라가 남의 자리 안엣것을 지웠다: " + f)
    nr = e.get("normal_root")
    if nr and os.path.exists(nr):
        bad.append("보존과 무관한 정상 자리를 못 지웠다: " + nr)
    for b in bad:
        print("  어긋남: " + b)
    if not bad:
        print("  대조 통과: 이름표만 사라지고 가리키던 자리(" + r["target"] + ")는 통째로 그대로입니다.")
    return 0 if not bad else 1


def verify(home, expect_fail, expect_cys_kept=False):
    with open(os.path.join(home, "agora-expect.json"), encoding="utf-8") as f:
        e = json.load(f)
    if expect_cys_kept:
        return verify_cys_kept(home, e)
    if e.get("root_link"):
        rc = verify_root_link(e)
        if expect_fail:
            if rc == 0:
                print("::error::적색이 나와야 하는 실행인데 통과했다(뮤턴트가 살아남았다)")
                return 1
            print("기대대로 적색입니다(뮤턴트가 잡혔습니다).")
            return 0
        return rc
    bad = []

    # ⑴ 열쇠가 **바이트 그대로** 살아 있는가 — 존재만 보면 「새로 만들어졌다」를 통과시킨다.
    if not os.path.isfile(e["key"]):
        bad.append("참가 열쇠가 사라졌다: " + e["key"])
    elif sha(e["key"]) != e["key_sha"]:
        bad.append("참가 열쇠의 내용이 바뀌었다: " + e["key"])

    # ⑵-0 보존과 무관한 **정상 루트**는 통째로 사라졌는가(지우는 축).
    nr = e.get("normal_root")
    if nr and os.path.exists(nr):
        bad.append("보존과 무관한 정상 자리를 못 지웠다: " + nr)

    # ⑵ 중첩 루트의 나머지는 지워졌는가
    if os.path.exists(e["must_die"]):
        bad.append("보존이 삭제를 통째로 막았다(지워졌어야 할 것이 남았다): " + e["must_die"])

    # ⑶ 1차 — cys 안의 안내는 사라지고, 밖에 **바이트까지 같은 것**이 있어야 한다.
    #   ⛔「폴더가 있다」로 판정하지 않는다 — 반쪽 복사가 그 판정을 통과하고 영구히 고착된다.
    if os.path.exists(e["skill_in_cys"]):
        bad.append("cys 자리 안의 안내가 남았다(그 자리는 cys 와 함께 사라지는 것이 맞다): " + e["skill_in_cys"])
    out = e["skill_out"]
    if not os.path.isdir(out):
        bad.append("안내를 밖으로 옮기지 않았다 — 재설치 뒤 「아고라에 참가해」가 안 먹는다: " + out)
    else:
        got = {}
        for root, _dirs, files in os.walk(out):
            for fn in files:
                full = os.path.join(root, fn)
                got[os.path.relpath(full, out).replace("\\", "/")] = sha(full)
        want = e.get("skill_files", {})
        for rel, want_sha in want.items():
            if rel not in got:
                bad.append("옮긴 안내에 파일이 빠졌다(반쪽 이전): " + rel)
            elif got[rel] != want_sha:
                bad.append("옮긴 안내의 내용이 다르다: " + rel)
        for rel in got:
            if rel not in want:
                bad.append("옮긴 안내에 없던 파일이 생겼다: " + rel)

    # ⑷ 바깥을 가리키는 링크 — **링크만** 사라지고 대상은 바이트 그대로여야 한다.
    o = e.get("outside")
    if o:
        if not os.path.isdir(o["dir"]):
            bad.append("링크를 뚫고 바깥 폴더를 지웠다: " + o["dir"])
        elif not os.path.isfile(o["file"]):
            bad.append("링크를 뚫고 바깥 파일을 지웠다: " + o["file"])
        elif sha(o["file"]) != o["file_sha"]:
            bad.append("바깥 파일의 내용이 바뀌었다: " + o["file"])
        pm = o.get("parent_must_remain")
        if pm and not os.path.isdir(pm):
            bad.append("열거하지 못한 폴더를 통째로 지웠다(무엇을 지우는지 모르는 채로): " + pm)
        if not o.get("links_may_remain"):
            for lk in o["links"]:
                if os.path.lexists(lk):
                    bad.append("삭제 루트 안의 링크가 남았다: " + lk)
        if not bad:
            print("  바깥 대조 통과: 링크는 사라지고 바깥 폴더·파일은 바이트 그대로입니다.")

    # ⑸ 끊어진 링크는 **지워져 있어야** 한다(이름표만 있는 자리도 우리가 놓은 자국이다).
    for lk in e.get("dangling", []):
        if os.path.lexists(lk):
            bad.append("끊어진 링크가 남았다: " + lk)

    ok = not bad
    for b in bad:
        print("  어긋남: " + b)
    if ok:
        print("  대조 통과: 열쇠 바이트 동일 · 나머지는 지워짐 · 안내는 밖으로 옮겨짐")

    if expect_fail:
        if ok:
            print("::error::적색이 나와야 하는 실행인데 통과했다(뮤턴트가 살아남았다)")
            return 1
        print("기대대로 적색입니다(뮤턴트가 잡혔습니다).")
        return 0
    return 0 if ok else 1


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("mode", choices=["seed", "verify"])
    ap.add_argument("--home", required=True)
    ap.add_argument("--os", default="mac", choices=["mac", "win"])
    ap.add_argument("--allow-live", action="store_true")
    ap.add_argument("--expect-fail", action="store_true")
    ap.add_argument("--shape", default="plain", choices=["plain", "dotseg", "symlink"],
                    help="AGORA_HOME 으로 넘길 경로의 모양(같은 곳을 가리키되 글자가 다르다)")
    ap.add_argument("--stale-out", action="store_true",
                    help="밖에 내용이 다른 반쪽 안내를 미리 놓는다(재실행 고착 시험)")
    ap.add_argument("--unreadable", action="store_true",
                    help="삭제 루트 안에 이 계정으로 못 여는 자리를 놓는다(열거·삭제 실패 주입)")
    ap.add_argument("--outside-link", action="store_true",
                    help="삭제 루트 안에 바깥 폴더를 가리키는 링크를 놓는다(뚫고 지우는지 본다)")
    ap.add_argument("--link-in-subdir", action="store_true",
                    help="바깥 링크를 .cys 바로 밑이 아니라 .cys\\sub 안에 놓는다")
    ap.add_argument("--chain", type=int, default=0,
                    help="AGORA_HOME 을 N겹 링크 사슬 끝으로 넘긴다(경계 계약 시험)")
    ap.add_argument("--root-link", action="store_true",
                    help="삭제 루트(~/.cys) 자신을 바깥 폴더를 가리키는 링크로 만든다")
    ap.add_argument("--dangling-link", action="store_true",
                    help="가리키던 곳이 사라진 링크(끊어진 이름표)를 삭제 루트 안에 놓는다")
    ap.add_argument("--expect-cys-kept", action="store_true",
                    help="이 실행은 원본(~/.cys)을 남겼어야 한다")
    a = ap.parse_args()
    home = os.path.abspath(a.home)
    if a.mode == "seed":
        return seed(home, a.os, a.allow_live, a.shape, a.stale_out, a.unreadable, a.outside_link,
                    a.link_in_subdir, a.dangling_link, a.root_link, a.chain)
    return verify(home, a.expect_fail, a.expect_cys_kept)


if __name__ == "__main__":
    sys.exit(main())
