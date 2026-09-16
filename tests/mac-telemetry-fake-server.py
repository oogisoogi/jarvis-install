#!/usr/bin/env python3
"""맥 진행 전송·증거·첨부 시험용 가짜 서버 — 받은 본문을 **통째로** 적는다(칸 이름·순서·값을 글자로 대조하려고).

쓰는 법: python3 tests/mac-telemetry-fake-server.py <상태 폴더>
  상태 폴더/port            = 연 포트(시작 뒤 쓴다)
  상태 폴더/requests.jsonl  = 받은 요청 한 줄씩 {method, path, headers{…}, body(글) | bytes·sha256(그림·첨부)}
  상태 폴더/progress.status = 있으면 진행 응답 코드를 그것으로 덮는다(서버 장애 흉내)
  상태 폴더/image.status    = 있으면 그림 응답 코드를 그것으로 덮는다 · image.error = 본문 error 값(예: image_cap)
  상태 폴더/baseline.json   = 있으면 기준선 답(없으면 404)
  상태 폴더/capture.json    = 있으면 다음 진행 201 의 capture 칸에 한 번 실어 준다(실으면 지운다)

계약 = web-install src/telemetry.ts·help-api.ts(feat/evidence-images a3e170a):
  POST /api/progress                          201 {seq, upload_token(evidence 만), capture, notice}
  POST /api/progress/evidence/<seq>/image     머리글 x-progress-upload · 201
  GET  /api/progress/baseline?os=             {steps:[{step, median_elapsed_s, samples}]}
  POST /api/help/<id>/attach                  x-help-client 필수 · 201
⛔바깥에 닿지 않는다(127.0.0.1 만 연다). capture-fake-server.py 와 같은 답을 주되 본문 칸 전부를 남긴다는 점만 다르다
  (그쪽은 윈판 시험이 쓰는 칸만 적어서 install_id·os·at·env 를 대조할 수 없었다).
"""
import hashlib
import json
import os
import re
import sys
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer

STATE = sys.argv[1]
SEQ = [900]
TOKEN = "f" * 64


def path_of(name):
    return os.path.join(STATE, name)


class Handler(BaseHTTPRequestHandler):
    def log_message(self, *args):
        pass

    def _rec(self, rec):
        rec["headers"] = {k.lower(): v for k, v in self.headers.items()}
        with open(path_of("requests.jsonl"), "a", encoding="utf-8") as f:
            f.write(json.dumps(rec, ensure_ascii=False) + "\n")

    def do_POST(self):
        length = int(self.headers.get("content-length") or 0)
        raw = self.rfile.read(length) if length else b""
        m = re.match(r"^/api/progress/evidence/([^/]+)/image(?:\?(.*))?$", self.path)
        if m:
            self._rec({"method": "POST", "what": "image", "path": self.path, "seq": m.group(1),
                       "bytes": len(raw), "sha256": hashlib.sha256(raw).hexdigest()})
            if os.path.exists(path_of("image.status")):
                err = open(path_of("image.error"), encoding="utf-8").read().strip() if os.path.exists(path_of("image.error")) else ""
                return self._send(int(open(path_of("image.status")).read().strip()), {"ok": False, "error": err})
            return self._send(201, {"image_id": "i" * 32, "n": 1})
        if re.fullmatch(r"/api/help/[A-Za-z0-9]{8}/attach", self.path):
            body = {}
            try:
                body = json.loads(raw.decode("utf-8"))
            except Exception:
                pass
            self._rec({"method": "POST", "what": "attach", "path": self.path, "kind": body.get("kind"),
                       "filename": body.get("filename"), "b64_len": len(body.get("content_b64") or ""),
                       "bytes": len(raw)})
            if not self.headers.get("x-help-client"):
                return self._send(401, {"ok": False, "error": "client_unauthorized"})
            return self._send(201, {"ok": True})
        if self.path == "/api/progress":
            text = raw.decode("utf-8", "replace")
            self._rec({"method": "POST", "what": "progress", "path": self.path, "bytes": len(raw), "body": text})
            if os.path.exists(path_of("progress.status")):
                return self._send(int(open(path_of("progress.status")).read().strip()), {"ok": False})
            try:
                body = json.loads(text)
            except Exception:
                return self._send(400, {"ok": False, "error": "invalid_json"})
            out = {"ok": True, "notice": "N", "capture": None, "seq": None, "upload_token": None}
            if os.path.exists(path_of("capture.json")):
                out["capture"] = json.load(open(path_of("capture.json"), encoding="utf-8"))
                os.remove(path_of("capture.json"))
            if body.get("event") == "evidence":
                SEQ[0] += 1
                out["seq"] = SEQ[0]
                out["upload_token"] = TOKEN
            return self._send(201, out)
        self._rec({"method": "POST", "what": "unknown", "path": self.path})
        return self._send(404, {"ok": False, "error": "not_found"})

    def do_GET(self):
        self._rec({"method": "GET", "what": "get", "path": self.path})
        if self.path.startswith("/api/progress/baseline") and os.path.exists(path_of("baseline.json")):
            return self._send(200, json.load(open(path_of("baseline.json"), encoding="utf-8")))
        return self._send(404, {"ok": False})

    def _send(self, code, obj):
        data = json.dumps(obj).encode("utf-8")
        self.send_response(code)
        self.send_header("content-type", "application/json; charset=utf-8")
        self.send_header("content-length", str(len(data)))
        self.end_headers()
        self.wfile.write(data)


srv = ThreadingHTTPServer(("127.0.0.1", 0), Handler)
with open(path_of("port.tmp"), "w", encoding="utf-8") as f:
    f.write(str(srv.server_address[1]))
os.replace(path_of("port.tmp"), path_of("port"))
srv.serve_forever()
