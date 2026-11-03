"""ADT 로 ABAP 소스(클래스/인터페이스/BDEF/CDS) 검색·다운로드.

RAP 프레임워크 내부 분석용. 로그인은 adt_login.py 를 재사용합니다.

사용법:
  python tools/adt/adt_source.py search "CL_ABAP_BEHV*" "CL_RAP_*"     # 이름 검색 (와일드카드)
  python tools/adt/adt_source.py get CL_RAP_TRANSACTION_MANAGER         # 소스 다운로드 (클래스는 include 포함)
  python tools/adt/adt_source.py get I_SALESORDERTP --type bdef
  python tools/adt/adt_source.py get I_SALESORDERTP --type ddls
  python tools/adt/adt_source.py methods CL_RAP_TRANSACTION_MANAGER     # 메서드 목록 + 줄번호
  python tools/adt/adt_source.py show CL_RAP_TRANSACTION_MANAGER _process_save_sequence  # 메서드 본문 출력
  python tools/adt/adt_source.py docu COMMIT ENTITIES                   # ABAP 키워드 문서 (검색/본문)
  python tools/adt/adt_source.py docu ABAPMODIFY_ENTITY_ENTITIES --object
  python tools/adt/adt_source.py docu determination --bdef              # BDEF 키워드 문서 검색

다운로드 위치: 환경변수 ADT_SRC_DIR (기본 /tmp/adt_src). 이미 받은 파일은 재사용 (--refresh 로 강제 갱신).
"""
import argparse
import html
import os
import re
import sys
from urllib.parse import quote

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from adt_login import HOST, login  # noqa: E402

SRC_DIR = os.environ.get("ADT_SRC_DIR", "/tmp/adt_src")
_session = None


def session():
    global _session
    if _session is None:
        _session = login()
    return _session


def _get(path, accept="text/plain", **params):
    return session().get(HOST + path, params=params or None, headers={"Accept": accept})


def guess_type(name):
    n = name.upper().split("/")[-1] if name.startswith("/") else name.upper()
    return "intf" if n.startswith("IF_") else "clas"


def base_uri(name, typ):
    q = quote(name.lower(), safe="")
    return {
        "clas": f"/sap/bc/adt/oo/classes/{q}",
        "intf": f"/sap/bc/adt/oo/interfaces/{q}",
        "bdef": f"/sap/bc/adt/bo/behaviordefinitions/{q}",
        "ddls": f"/sap/bc/adt/ddic/ddl/sources/{q}",
    }[typ]


def local_name(name, part):
    return os.path.join(SRC_DIR, f"{name.upper().replace('/', '#')}.{part}.abap")


def get(name, typ=None, refresh=False):
    """소스를 받아 로컬 파일 경로 목록을 반환."""
    typ = typ or guess_type(name)
    os.makedirs(SRC_DIR, exist_ok=True)
    parts = [("main", "/source/main")]
    if typ == "clas":
        parts += [("locals_imp", "/includes/implementations"), ("locals_def", "/includes/definitions"),
                  ("macros", "/includes/macros")]
    files = []
    for part, sub in parts:
        fn = local_name(name, part)
        if os.path.exists(fn) and not refresh:
            files.append(fn)
            continue
        r = _get(base_uri(name, typ) + sub)
        if r.ok:
            text = r.content.decode("utf-8", "replace")
            if text.strip():
                open(fn, "w", encoding="utf-8").write(text)
                files.append(fn)
        elif part == "main":
            print(f"[{r.status_code}] {name} 소스 없음 (권한/비공개일 수 있음)", file=sys.stderr)
    return files


def search(pattern, maxres=100):
    r = _get("/sap/bc/adt/repository/informationsystem/search", accept="application/xml",
             operation="quickSearch", query=pattern, maxResults=str(maxres))
    return re.findall(r'adtcore:type="([^"]*)" adtcore:name="([^"]*)"', r.text)


def methods(name, typ=None):
    out = []
    for fn in get(name, typ):
        for i, line in enumerate(open(fn, encoding="utf-8"), 1):
            if re.match(r"\s*method\s+[\w~/]+", line, re.I):
                out.append(f"{os.path.basename(fn)}:{i}: {line.strip()}")
    return out


def show(name, method, typ=None):
    pat = re.compile(r"\s*method\s+" + re.escape(method) + r"\b", re.I)
    for fn in get(name, typ):
        lines = open(fn, encoding="utf-8").read().splitlines()
        for i, line in enumerate(lines):
            if pat.match(line):
                for j in range(i, len(lines)):
                    print(f"{j + 1:5}: {lines[j]}")
                    if re.match(r"\s*endmethod\b", lines[j], re.I):
                        return
    print(f"메서드 {method} 를 찾지 못함", file=sys.stderr)


DOCU_ACCEPT = "application/vnd.sap.adt.docu.v1+html"


def _html_to_text(h):
    h = re.sub(r"(?s)<(script|style|head)\b.*?</\1>", "", h)
    h = re.sub(r"(?i)<br\s*/?>|</(p|div|h\d|li|tr|pre)>", "\n", h)
    h = re.sub(r"<[^>]+>", "", h)
    h = html.unescape(h)
    lines = [re.sub(r"[ \t]+", " ", ln).strip() for ln in h.splitlines()]
    return "\n".join(ln for ln in lines if ln)


def docu(query=None, obj=None, kind="abap"):
    """ABAP 키워드 문서 조회. query: 검색어, obj: 문서 object id (예 ABAPMODIFY_ENTITY_ENTITIES).
    반환: (본문 텍스트, [(object_id, 제목), ...] 검색결과 링크)"""
    if kind == "bdef":
        path, params = "/sap/bc/adt/bo/behaviordefinitions/docu/langu", {"searchWord": query}
    elif obj:
        path, params = "/sap/bc/adt/docu/abap/langu", {"sap-language": "EN", "version": "X", "object": obj}
    else:
        path, params = "/sap/bc/adt/docu/abap/langu", {"format": "eclipse", "language": "EN", "query": query}
    r = _get(path, accept=DOCU_ACCEPT, **params)
    t = r.content.decode("utf-8", "replace")
    links = []
    for oid, title in re.findall(r'href="adtcom:[^"]*object=([A-Z0-9_]+)[^"]*"[^>]*>(.*?)</a>', t, re.S):
        title = html.unescape(re.sub(r"<[^>]+>", "", title)).strip()
        if (oid, title) not in links:
            links.append((oid, title))
    return _html_to_text(t), links


def main():
    p = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    p.add_argument("cmd", choices=["search", "get", "methods", "show", "docu"])
    p.add_argument("args", nargs="+")
    p.add_argument("--type", choices=["clas", "intf", "bdef", "ddls"])
    p.add_argument("--refresh", action="store_true")
    p.add_argument("--object", action="store_true", help="docu: 인자를 문서 object id 로 취급")
    p.add_argument("--bdef", action="store_true", help="docu: BDEF 키워드 문서 검색")
    a = p.parse_args()
    if a.cmd == "search":
        for pat in a.args:
            print(pat, "->", ", ".join(f"{n}({t})" for t, n in search(pat)) or "(없음)")
    elif a.cmd == "get":
        for n in a.args:
            for fn in get(n, a.type, a.refresh):
                print(fn, sum(1 for _ in open(fn, encoding="utf-8")), "lines")
    elif a.cmd == "methods":
        print("\n".join(methods(a.args[0], a.type)))
    elif a.cmd == "show":
        show(a.args[0], a.args[1], a.type)
    elif a.cmd == "docu":
        q = " ".join(a.args)
        text, links = docu(obj=q if a.object else None, query=None if a.object else q,
                           kind="bdef" if a.bdef else "abap")
        if not a.object and links and text.count("\n") < 40:
            print("검색 결과 (--object <ID> 로 본문 조회):")
            for oid, title in links:
                print(f"  {oid:40} {title}")
        else:
            print(text)


if __name__ == "__main__":
    main()
