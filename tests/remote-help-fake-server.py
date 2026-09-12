#!/usr/bin/env python3
"""원격 해결 시험용 가짜 서버 — 설치기의 요청을 받아 적고, 시험이 적어 둔 답을 돌려준다.

쓰는 법: python3 tests/remote-help-fake-server.py <상태 폴더>
  상태 폴더/port            = 서버가 연 포트(시작 뒤 쓴다)
  상태 폴더/requests.jsonl  = 받은 요청 한 줄씩 {method, path, body}
  상태 폴더/<이름>.json      = 돌려줄 본문 · <이름>.status = 돌려줄 코드(없으면 기본값)
    이름 = report(POST /api/help) · poll(GET /api/help/<id>) · ack · close · delete

⛔바깥에 닿지 않는다(127.0.0.1 만 연다). 매 요청마다 파일을 새로 읽으므로 시험이 도중에 답을 바꿀 수 있다.
"""
import json
import os
import re
import sys
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer

STATE = sys.argv[1]
MAX_BODY_BYTES = 262144
DEFAULTS = {
    "report": (201, {"id": "TEST2345", "ok": True, "message": "", "status": "open", "truncated": False,
                     "session": {"open": True, "expires_at": "2026-09-11T00:00:00.000Z"}}),
    "poll": (200, {"id": "TEST2345", "ok": True, "message": "", "status": "open", "answer": None,
                   "session": {"open": True, "messages": []}}),
    "ack": (200, {"id": "TEST2345", "ok": True, "message": ""}),
    "close": (200, {"id": "TEST2345", "ok": True, "message": "", "session": {"open": False}}),
    "delete": (200, {"id": "TEST2345", "ok": True, "message": ""}),
}


def route(method, path):
    if method == "POST" and path == "/api/help":
        return "report"
    m = re.fullmatch(r"/api/help/[A-Z0-9]{8}(/(ack|close|delete))?", path)
    if m is None:
        return None
    if m.group(2):
        return m.group(2) if method == "POST" else None
    return "poll" if method == "GET" else None


class Handler(BaseHTTPRequestHandler):
    def log_message(self, *args):
        pass

    def handle_any(self):
        length = int(self.headers.get("content-length") or 0)
        body = self.rfile.read(length).decode("utf-8", "replace") if length else ""
        with open(os.path.join(STATE, "requests.jsonl"), "a", encoding="utf-8") as f:
            f.write(json.dumps({"method": self.command, "path": self.path, "body": body, "bytes": length,
                                "client": self.headers.get("x-help-client")}, ensure_ascii=False) + "\n")
        name = route(self.command, self.path)
        if length > MAX_BODY_BYTES:   # 진짜 서버와 같은 상한(계약 1절·6절 — 256KB 넘으면 413 too_large)
            code, payload = 413, {"id": None, "ok": False, "error": "too_large"}
        elif name is None:
            code, payload = 404, {"id": None, "ok": False, "error": "not_found"}
        else:
            code, payload = DEFAULTS[name]
            status_file = os.path.join(STATE, name + ".status")
            body_file = os.path.join(STATE, name + ".json")
            if os.path.exists(status_file):
                code = int(open(status_file).read().strip())
            if os.path.exists(body_file):
                payload = open(body_file, encoding="utf-8").read()
        raw = payload if isinstance(payload, str) else json.dumps(payload)
        data = raw.encode("utf-8")
        self.send_response(code)
        self.send_header("content-type", "application/json")
        self.send_header("content-length", str(len(data)))
        self.end_headers()
        self.wfile.write(data)

    do_GET = handle_any
    do_POST = handle_any


server = ThreadingHTTPServer(("127.0.0.1", 0), Handler)
with open(os.path.join(STATE, "port.tmp"), "w") as f:
    f.write(str(server.server_address[1]))
os.replace(os.path.join(STATE, "port.tmp"), os.path.join(STATE, "port"))
server.serve_forever()
