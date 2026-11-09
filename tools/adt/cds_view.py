"""CDS 뷰 소스와 데이터 미리보기를 ADT 로 조회.

사용법:
  python tools/adt/cds_view.py I_Country
  python tools/adt/cds_view.py I_Country --rows 20
  python tools/adt/cds_view.py I_Country --source-only
  python tools/adt/cds_view.py DEMO_CDS_EXPRESSION_REUSE --sql   # DB 에 생성된 SQL CREATE 문
"""
import argparse
import re

from bs4 import BeautifulSoup

from adt_login import HOST, csrf_token, login


def read_source(s, name):
    r = s.get(f"{HOST}/sap/bc/adt/ddic/ddl/sources/{name.lower()}/source/main",
              headers={"Accept": "text/plain"})
    r.raise_for_status()
    return r.text


def sql_create_statements(s, name):
    """활성 CDS 의 DB 측 SQL CREATE 문 (ADT 'Show SQL CREATE Statement').

    POST /sap/bc/adt/ddic/ddl/createstatements/{name} (빈 본문 = 활성 버전, GET 은 405).
    반환: [(객체명, statement)]
    """
    r = s.post(f"{HOST}/sap/bc/adt/ddic/ddl/createstatements/{name.lower()}",
               headers={"x-csrf-token": csrf_token(s), "Content-Type": "text/plain", "Accept": "*/*"},
               data=b"")
    r.raise_for_status()
    x = BeautifulSoup(r.text, "xml")
    return [(c.get("adtcore:name"), c.find("statement").text) for c in x.find_all("createStatement")]


def format_sql(stmt):
    """읽기 쉽게 주요 절 앞에서 줄바꿈 (문자열 리터럴 안은 건드리지 않음)."""
    parts = re.split(r"('(?:[^']|'')*')", stmt)
    card = r"((EXACT )?(ONE|MANY) TO (EXACT )?(ONE|MANY) )?"
    kw = (r" (FROM|WHERE|GROUP BY|HAVING|UNION ALL|UNION|ON|WITH READ ONLY"
          r"|((LEFT|RIGHT) OUTER |INNER |CROSS )?" + card + r"JOIN)(?= |$)")
    out = []
    for i, part in enumerate(parts):
        if i % 2 == 0:
            part = re.sub(r"\s{2,}", " ", part)
            part = re.sub(kw, lambda m: f"\n{m.group(1)}", part)
            part = part.replace(" AS SELECT ", " AS\nSELECT ")
        out.append(part)
    return "".join(out)


def data_preview(s, name, rows):
    r = s.post(f"{HOST}/sap/bc/adt/datapreview/ddic",
               params={"rowNumber": rows, "ddicEntityName": name.upper()},
               headers={"x-csrf-token": csrf_token(s),
                        "Accept": "application/xml, application/vnd.sap.adt.datapreview.table.v1+xml",
                        "Content-Type": "text/plain"},
               data="")
    r.raise_for_status()
    x = BeautifulSoup(r.text, "xml")
    cols = x.find_all("columns")
    header = [c.find("metadata").get("dataPreview:name") or c.find("metadata").get("name") for c in cols]
    data = [[d.text for d in c.find_all("data")] for c in cols]
    return header, list(zip(*data))[:rows]


def main():
    p = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    p.add_argument("name", help="CDS 뷰 이름 (예: I_Country)")
    p.add_argument("--rows", type=int, default=10, help="미리보기 행 수 (기본 10)")
    p.add_argument("--source-only", action="store_true", help="소스만 조회")
    p.add_argument("--sql", action="store_true", help="DB 에 생성된 SQL CREATE 문만 조회 (활성 버전)")
    p.add_argument("--raw", action="store_true", help="--sql 결과를 줄바꿈 없이 원문 그대로")
    a = p.parse_args()

    s = login()
    if a.sql:
        for obj, stmt in sql_create_statements(s, a.name):
            print(f"=== {obj} SQL CREATE ===")
            print(stmt if a.raw else format_sql(stmt))
        return
    print(f"=== {a.name} 소스 ===")
    print(read_source(s, a.name))
    if a.source_only:
        return
    header, rows = data_preview(s, a.name, a.rows)
    print(f"\n=== {a.name} 데이터 ({len(rows)}행) ===")
    print(" | ".join(header))
    for row in rows:
        print(" | ".join(row))


if __name__ == "__main__":
    main()
