import sys, os
sys.path.insert(0, os.path.join(os.path.dirname(os.path.abspath(__file__)), '..', 'adt'))
from http.server import ThreadingHTTPServer, BaseHTTPRequestHandler
from adt_login import HOST, login
s = login(); BASE = os.path.dirname(os.path.abspath(__file__))
class H(BaseHTTPRequestHandler):
    def _go(self, m):
        lp = self.path.split("?")[0].lstrip("/")
        if lp == "index.html" or lp.startswith("app/"):
            if lp == "app/manifest.json": lp = "app/" + os.environ.get("MAN", "manifest.json")
            d = open(os.path.join(BASE, lp), "rb").read()
            if os.environ.get('UI5V'): d = d.replace(b'https://ui5.sap.com/resources', ('https://ui5.sap.com/' + os.environ['UI5V'] + '/resources').encode())
            ct = "application/xml" if lp.endswith(".xml") else "text/html" if lp.endswith(".html") else "application/json" if lp.endswith(".json") else "application/javascript"
            self.send_response(200); self.send_header("Content-Type", ct); self.send_header("Content-Length", str(len(d))); self.end_headers(); self.wfile.write(d); return
        n = int(self.headers.get("Content-Length") or 0); body = self.rfile.read(n) if n else None
        hdr = {k: v for k, v in self.headers.items() if k.lower() not in ("host","cookie","content-length","accept-encoding","connection","origin","referer")}
        r = s.request(m, HOST + self.path, data=body, headers=hdr)
        self.send_response(r.status_code)
        for k, v in r.headers.items():
            if k.lower() not in ("content-encoding","transfer-encoding","content-length","set-cookie","connection"): self.send_header(k, v)
        c = r.content; self.send_header("Content-Length", str(len(c))); self.end_headers(); self.wfile.write(c)
    def do_GET(self): self._go("GET")
    def do_POST(self): self._go("POST")
    def log_message(self, *a): pass
ThreadingHTTPServer(("127.0.0.1", 8766), H).serve_forever()
