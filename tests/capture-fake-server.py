#!/usr/bin/env python3
"""캡처 증거 시험용 가짜 서버 — 계약(그림 증거 · 두 걸음)대로 답한다.

쓰는 법: python3 tests/capture-fake-server.py <상태 폴더>
  상태 폴더/port           = 연 포트(시작 뒤 쓴다)
  상태 폴더/requests.jsonl = 받은 요청 한 줄씩
  상태 폴더/image.status   = 있으면 그림 응답 코드를 그것으로 덮는다(서버 장애·상한 흉내 · 예: 429)
  상태 폴더/image.error    = 위와 함께 본문 error 값(예: image_cap · rate_limited)
  상태 폴더/baseline.json  = 있으면 그 내용을 기준선 답으로 준다(없으면 404)
  상태 폴더/capture.json   = 있으면 진행 201 의 capture 칸에 실어 준다(한 번 실으면 지운다 = 1회성)

계약(서버 docs/HELP-API.md §10-2c·d·e):
  POST <진행 주소>                       event=evidence → 201 {seq, upload_token, upload{…}, capture, notice}
  POST <진행 주소>/evidence/<seq>/image?kind=&filename=   머리글 x-progress-upload · 본문 = 그림 바이트 → 201
  GET  <진행 주소>/baseline?os=win       {os, days, min_samples, steps:[{step, median_elapsed_s, samples}]}
⛔바깥에 닿지 않는다(127.0.0.1 만 연다).
"""
import hashlib
import json
import os
import re
import sys
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer

STATE = sys.argv[1]
SEQ = [800]
TOKEN = "t" * 64


class Handler(BaseHTTPRequestHandler):
    def log_message(self, *args):
        pass

    def _rec(self, rec):
        with open(os.path.join(STATE, "requests.jsonl"), "a", encoding="utf-8") as f:
            f.write(json.dumps(rec, ensure_ascii=False) + "\n")

    def do_POST(self):
        length = int(self.headers.get("content-length") or 0)
        raw = self.rfile.read(length) if length else b""
        m = re.match(r"^/evidence/([^/]+)/image(?:\?(.*))?$", self.path)
        if m:
            q = dict(p.split("=", 1) for p in (m.group(2) or "").split("&") if "=" in p)
            self._rec({
                "method": "POST", "what": "image", "seq": m.group(1),
                "kind": q.get("kind"), "filename": q.get("filename"),
                "upload": self.headers.get("x-progress-upload"),
                "has_content_length": self.headers.get("content-length") is not None,
                "ctype": self.headers.get("content-type"),
                "bytes": len(raw), "sha256": hashlib.sha256(raw).hexdigest(),
            })
            st = os.path.join(STATE, "image.status")
            if os.path.exists(st):
                err = ""
                ep = os.path.join(STATE, "image.error")
                if os.path.exists(ep):
                    err = open(ep, encoding="utf-8").read().strip()
                return self._send(int(open(st).read().strip()), {"ok": False, "error": err})
            return self._send(201, {"image_id": "i" * 32, "n": 1, "kind": q.get("kind"),
                                    "bytes": len(raw), "content_type": "image/jpeg"})
        # 진행 이벤트
        try:
            body = json.loads(raw.decode("utf-8", "replace"))
        except Exception:
            body = {}
        self._rec({"method": "POST", "what": "progress", "event": body.get("event"),
                   "reason": body.get("reason"), "step": body.get("step"),
                   "has_text": "text" in body, "text": body.get("text"),
                   "masked": body.get("masked"), "bytes": len(raw)})
        out = {"notice": "…"}
        cp = os.path.join(STATE, "capture.json")
        if os.path.exists(cp):
            out["capture"] = json.load(open(cp, encoding="utf-8"))
            os.remove(cp)          # 1회성 — 같은 요청을 두 번 실어 주지 않는다
        else:
            out["capture"] = None
        if body.get("event") == "evidence":
            SEQ[0] += 1
            out.update({"seq": SEQ[0], "upload_token": TOKEN,
                        "upload": {"max_bytes": 1572864, "per_install_per_day": 12,
                                   "kinds": ["installer_window", "login_window", "app_window", "first_pane"],
                                   "window_minutes": 60, "content_types": ["image/jpeg", "image/png"]}})
        else:
            out.update({"seq": None, "upload_token": None})
        return self._send(201, out)

    def do_GET(self):
        self._rec({"method": "GET", "path": self.path})
        bl = os.path.join(STATE, "baseline.json")
        if self.path.startswith("/baseline") and os.path.exists(bl):
            return self._send(200, json.load(open(bl, encoding="utf-8")))
        return self._send(404, {"ok": False})

    def _send(self, code, obj):
        body = json.dumps(obj).encode("utf-8")
        self.send_response(code)
        self.send_header("content-type", "application/json; charset=utf-8")
        self.send_header("content-length", str(len(body)))
        self.end_headers()
        self.wfile.write(body)


srv = ThreadingHTTPServer(("127.0.0.1", 0), Handler)
with open(os.path.join(STATE, "port"), "w", encoding="utf-8") as f:
    f.write(str(srv.server_address[1]))
srv.serve_forever()
