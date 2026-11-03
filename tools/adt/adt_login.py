"""SAP S/4HANA Cloud ADT 로그인 (IAS SAML 경유).

환경변수:
  SAP_ADT_HOST      기본값 https://my406740.s4hana.cloud.sap
  SAP_ADT_USER      IAS 사용자
  SAP_ADT_PASSWARD  IAS 비밀번호 (SAP_ADT_PASSWORD 도 허용)
  REQUESTS_CA_BUNDLE / SAP_ADT_CA_BUNDLE  (선택) CA 번들 경로

단독 실행 시 로그인 후 ADT discovery 결과를 출력합니다.
"""
import os
import sys
from urllib.parse import urljoin

import requests
from bs4 import BeautifulSoup

HOST = os.environ.get("SAP_ADT_HOST", "https://my406740.s4hana.cloud.sap").rstrip("/")


def _submit(session, form, base, extra=None):
    action = urljoin(base, form.get("action") or base)
    data = {i.get("name"): i.get("value", "") for i in form.find_all("input") if i.get("name")}
    if extra:
        data.update(extra)
    return session.post(action, data=data)


def login(host=HOST, user=None, password=None, max_steps=10):
    """IAS SAML 로그인 후 인증된 requests.Session 을 반환."""
    user = user or os.environ["SAP_ADT_USER"]
    password = password or os.environ.get("SAP_ADT_PASSWARD") or os.environ["SAP_ADT_PASSWORD"]

    s = requests.Session()
    ca = os.environ.get("SAP_ADT_CA_BUNDLE") or os.environ.get("REQUESTS_CA_BUNDLE")
    if not ca and os.path.exists("/root/.ccr/ca-bundle.crt"):
        ca = "/root/.ccr/ca-bundle.crt"
    if ca:
        s.verify = ca
    s.headers["User-Agent"] = "Mozilla/5.0 (adt-client)"

    r = s.get(host + "/sap/bc/adt/discovery")
    for _ in range(max_steps):
        if "atomsvc" in r.headers.get("content-type", ""):
            return s
        forms = BeautifulSoup(r.text, "html.parser").find_all("form")
        if not forms:
            break
        form = forms[0]
        names = {i.get("name") for i in form.find_all("input")}
        extra = {"j_username": user, "j_password": password} if "j_password" in names else None
        r = _submit(s, form, r.url, extra)
    raise RuntimeError(f"ADT 로그인 실패 (마지막 URL: {r.url}, status {r.status_code})")


def csrf_token(session, host=HOST):
    r = session.get(host + "/sap/bc/adt/discovery", headers={"x-csrf-token": "fetch"})
    return r.headers.get("x-csrf-token")


if __name__ == "__main__":
    s = login()
    r = s.get(HOST + "/sap/bc/adt/discovery", headers={"Accept": "application/atomsvc+xml"})
    titles = [t.text for t in BeautifulSoup(r.text, "xml").find_all("title")]
    print(f"로그인 성공: discovery {r.status_code}, 항목 {len(titles)}개")
    print("CSRF 토큰:", "OK" if csrf_token(s) else "없음")
    sys.exit(0)
