#!/usr/bin/env python3
"""진행 전송·첨부 시험용 가짜 서버 — 설치기가 보낸 것을 받아 적고 계약대로 답한다.

쓰는 법: python3 tests/telemetry-fake-server.py <상태 폴더>
  상태 폴더/port           = 연 포트(시작 뒤 쓴다)
  상태 폴더/requests.jsonl = 받은 요청 한 줄씩 {method, path, client, event|kind, body}
  상태 폴더/progress.status = 있으면 /api/progress 응답 코드를 그것으로 덮는다(서버 장애 흉내)

계약(web-install src/telemetry.ts) 그대로:
  POST /api/progress            토큰 없음 · 본문 8KB · 201 {ok, notice}
  POST /api/help                보고 열기 · 201 {id, client_token}
  POST /api/help/<id>/attach    x-help-client 필수 · 항목 900KB · 10건까지 · 201 {ok}
⛔바깥에 닿지 않는다(127.0.0.1 만 연다). 매 요청마다 파일을 새로 읽으므로 시험이 도중에 답을 바꿀 수 있다.
"""
import json
import os
import re
import sys
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer

STATE = sys.argv[1]
PROGRESS_MAX = 8 * 1024
ATTACH_MAX = 900 * 1024
ATTACH_REQUEST_MAX = (ATTACH_MAX * 4) // 3 + 64 * 1024


class Handler(BaseHTTPRequestHandler):
    def log_message(self, *args):
        pass

    def do_POST(self):
        length = int(self.headers.get("content-length") or 0)
        raw = self.rfile.read(length) if length else b""
        body = raw.decode("utf-8", "replace")
        parsed = {}
        try:
            parsed = json.loads(body)
        except Exception:
            parsed = {}
        rec = {
            "method": "POST",
            "path": self.path,
            "client": self.headers.get("x-help-client"),
            "bytes": length,
            "event": parsed.get("event"),
            "kind": parsed.get("kind"),
            "step": parsed.get("step"),
            "install_id": parsed.get("install_id"),
            "has_token_field": ("token" in parsed or "client_token" in parsed),
            "body": body,
        }
        with open(os.path.join(STATE, "requests.jsonl"), "a", encoding="utf-8") as f:
            f.write(json.dumps(rec, ensure_ascii=False) + "\n")

        if self.path == "/api/progress":
            if length > PROGRESS_MAX:
                return self._send(413, {"ok": False, "error": "too_large"})
            override = os.path.join(STATE, "progress.status")
            if os.path.exists(override):
                return self._send(int(open(override).read().strip()), {"ok": False})
            return self._send(201, {"ok": True, "notice": "N"})
        if self.path == "/api/help":
            return self._send(201, {"id": "TEST2345", "ok": True, "client_token": "a" * 64,
                                    "session": {"open": True}})
        if re.fullmatch(r"/api/help/[A-Z0-9]{8}/attach", self.path):
            if not self.headers.get("x-help-client"):
                return self._send(401, {"ok": False, "error": "client_unauthorized"})
            if length > ATTACH_REQUEST_MAX:
                return self._send(413, {"ok": False, "error": "too_large"})
            return self._send(201, {"ok": True})
        return self._send(404, {"ok": False, "error": "not_found"})

    def _send(self, code, payload):
        data = json.dumps(payload).encode("utf-8")
        self.send_response(code)
        self.send_header("content-type", "application/json")
        self.send_header("content-length", str(len(data)))
        self.end_headers()
        self.wfile.write(data)


server = ThreadingHTTPServer(("127.0.0.1", 0), Handler)
with open(os.path.join(STATE, "port.tmp"), "w") as f:
    f.write(str(server.server_address[1]))
os.replace(os.path.join(STATE, "port.tmp"), os.path.join(STATE, "port"))
server.serve_forever()
