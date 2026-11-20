import sys, json, threading, os, re
sys.path.insert(0, os.path.join(os.path.dirname(os.path.abspath(__file__)), '..', 'adt'))
from http.server import ThreadingHTTPServer, BaseHTTPRequestHandler
from adt_login import HOST, login
s = login(); LOG = open(sys.argv[2], "a"); lock = threading.Lock()
PAGE = open(sys.argv[1], "rb").read()
class H(BaseHTTPRequestHandler):
    def _go(self, method):
        lp = self.path.split("?")[0].lstrip("/")
        if lp in ("index.html", "fe.html", "fe4.html") or lp.startswith("feapp/") or lp.startswith("fe4app/"):
            base = os.path.dirname(os.path.abspath(__file__)); fp = os.path.join(base, lp)
            if lp == "feapp/manifest.json" and os.environ.get('MANIFEST'): fp = os.path.join(base, "variants", os.environ['MANIFEST'])
            if lp == "feapp/local.xml": fp = os.path.join(base, "variants", os.environ.get('LOCAL', 'local-none.xml'))
            data = open(fp, "rb").read()
            if os.environ.get('UI5V'): data = data.replace(b'https://ui5.sap.com/resources', ('https://ui5.sap.com/' + os.environ['UI5V'] + '/resources').encode())
            ct = "text/html" if lp.endswith(".html") else "application/xml" if lp.endswith(".xml") else ("application/json" if lp.endswith(".json") else "application/javascript")
            self.send_response(200); self.send_header("Content-Type", ct); self.send_header("Content-Length", str(len(data))); self.end_headers(); self.wfile.write(data); return
        n = int(self.headers.get("Content-Length") or 0); body = self.rfile.read(n) if n else None
        hdr = {k: v for k, v in self.headers.items() if k.lower() not in ("host", "cookie", "content-length", "accept-encoding", "connection", "origin", "referer")}
        r = s.request(method, HOST + self.path, data=body, headers=hdr)
        with lock: LOG.write(json.dumps({"m": method, "p": self.path, "s": r.status_code}) + "\n"); LOG.flush()
        self.send_response(r.status_code)
        for k, v in r.headers.items():
            if k.lower() not in ("content-encoding", "transfer-encoding", "content-length", "set-cookie", "connection"): self.send_header(k, v)
        c = r.content
        if os.environ.get('STRIP') and '$metadata' in self.path: c = re.sub(rb'<PropertyValue Property="PresentationVariantQualifier"[^>]*/>', b'', c)
        if os.environ.get('EDITABLE') and '$metadata' in self.path:
            c = re.sub(rb'(<EntitySet Name="ZC_CIH_SOVHTest"[^>]*?)sap:creatable="false" sap:updatable="false"', rb'\1sap:creatable="true" sap:updatable="true"', c)
        if os.environ.get('FIXED') and '$metadata' in self.path: c = c.replace(b'<Annotation Term="Common.ValueList">', b'<Annotation Term="Common.ValueListWithFixedValues"/><Annotation Term="Common.ValueList">', 1)
        self.send_header("Content-Length", str(len(c))); self.end_headers(); self.wfile.write(c)
    def do_GET(self): self._go("GET")
    def do_POST(self): self._go("POST")
    def do_HEAD(self): self._go("HEAD")
    def log_message(self, *a): pass
ThreadingHTTPServer(("127.0.0.1", 8765), H).serve_forever()
