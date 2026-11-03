"""CDS 뷰 소스와 데이터 미리보기를 ADT 로 조회.

사용법:
  python tools/adt/cds_view.py I_Country
  python tools/adt/cds_view.py I_Country --rows 20
  python tools/adt/cds_view.py I_Country --source-only
"""
import argparse

from bs4 import BeautifulSoup

from adt_login import HOST, csrf_token, login


def read_source(s, name):
    r = s.get(f"{HOST}/sap/bc/adt/ddic/ddl/sources/{name.lower()}/source/main",
              headers={"Accept": "text/plain"})
    r.raise_for_status()
    return r.text


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
    a = p.parse_args()

    s = login()
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
