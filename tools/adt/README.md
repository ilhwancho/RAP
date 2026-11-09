# ADT 도구

SAP S/4HANA Cloud(`my406740.s4hana.cloud.sap`)에 IAS SAML 로그인으로 ADT 세션을 받아 오브젝트를 조회하는 스크립트입니다.

## 준비
- Python 패키지: `pip install requests beautifulsoup4 lxml`
- 환경변수 (레포에 커밋하지 마세요):
  - `SAP_ADT_USER` – IAS 사용자
  - `SAP_ADT_PASSWARD` (또는 `SAP_ADT_PASSWORD`) – IAS 비밀번호
  - `SAP_ADT_HOST` – (선택) 기본값 `https://my406740.s4hana.cloud.sap`
- 네트워크: `my406740.s4hana.cloud.sap`, `aznlwebqs.accounts.cloud.sap` 접속 허용 필요

## 사용법
```bash
python tools/adt/adt_login.py              # 로그인 테스트
python tools/adt/cds_view.py I_Country     # CDS 소스 + 데이터 10행
python tools/adt/cds_view.py I_Country --rows 20
python tools/adt/cds_view.py I_Country --source-only
python tools/adt/cds_view.py I_Country --sql      # DB 에 생성된 SQL CREATE 문 (--raw: 줄바꿈 없이)

# ABAP 소스 검색/조회 (SAP 표준 포함, 기본 저장 위치 /tmp/adt_src)
python tools/adt/adt_source.py search "CL_RAP_*"
python tools/adt/adt_source.py get CL_RAP_TRANSACTION_MANAGER
python tools/adt/adt_source.py methods CL_RAP_TRANSACTION_MANAGER
python tools/adt/adt_source.py show CL_RAP_TRANSACTION_MANAGER _process_save_sequence
python tools/adt/adt_source.py get I_SALESORDERTP --type bdef

# ABAP 키워드 문서 (F1 도움말) - 기본 ABAP Cloud 버전, Standard ABAP 은 --standard
python tools/adt/adt_source.py docu COMMIT ENTITIES
python tools/adt/adt_source.py docu COMMIT ENTITIES --standard
python tools/adt/adt_source.py docu ABAPMODIFY_ENTITY_ENTITIES --object
python tools/adt/adt_source.py docu "determination on save" --bdef
```

## 참고
- 받는 것은 OAuth 토큰이 아니라 SAML 로그인 세션 쿠키입니다. 실행할 때마다 새로 로그인합니다.
- IAS에 2단계 인증(TFA)이 켜져 있으면 이 방식은 동작하지 않습니다.
