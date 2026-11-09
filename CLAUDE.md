# RAP 레포 작업 가이드 (Claude 용)

ABAP RAP 학습/개발용 레포. SAP S/4HANA Cloud 시스템 `Z5U` (`https://my406740.s4hana.cloud.sap`, client 080) 에 ADT 로 접속해 작업한다.

## ADT 접속
- `tools/adt/` 참조 (IAS SAML 로그인, 환경변수 `SAP_ADT_USER`, `SAP_ADT_PASSWARD`).
  - 환경변수 `SAP_ADT_URL` 은 호스트가 아니라 패턴 값이므로 `SAP_ADT_HOST` 로 쓰지 말 것 (기본값 사용).
- 소스 조회: `python tools/adt/adt_source.py search|get|methods|show ...` (SAP 표준 소스 포함)
- ABAP 키워드 문서(F1): `python tools/adt/adt_source.py docu <검색어>` → 결과의 object id 로 `docu <ID> --object`, BDEF 키워드는 `--bdef`.
  - 기본은 **ABAP Cloud 버전**(`version=5`, "ABAP for Cloud Development"). Standard ABAP 은 `--standard`.
  - **ABAP Cloud 로 작업할 때는 ABAP Cloud 버전 문서가 Standard ABAP 문서보다 우선한다.** 두 문서가 다르면 Cloud 버전을 따른다.
    Standard 문서는 Cloud 문서에 없는 배경 설명이 필요할 때만 참고하고, 그 내용이 Cloud 에서 허용되는지 Cloud 문서·released API 여부로 다시 확인한다.
  - 이 시스템(Z5U)의 개발 패키지는 언어 버전 5(ABAP for Cloud Development) 이므로 기본적으로 ABAP Cloud 작업으로 간주한다.
  - 문법·제약을 확인할 때는 추측하지 말고 키워드 문서를 먼저 본다 (시스템 릴리스 기준 문서).
- CDS 조회: `python tools/adt/cds_view.py <CDS명>`
  - `--sql`: 활성 CDS 가 DB 에 만드는 SQL CREATE 문 (식 인라인·association→JOIN 변환 확인용)
- 저장 없이 문법 체크(check run)는 `docs/adt-object-deploy.md` 4절.
- CDS 문법/동작 정리 노트: `docs/cds/` (예: `reuse-expressions.md` — `$projection` 식 재사용, association ON 제약)
- 객체 생성/수정/활성화 흐름(lock → PUT source → unlock → activate)은 `docs/adt-object-deploy.md` 참조.

## RAP 내부 동작 질문 (중요)
RAP 런타임·EML·세이브 시퀀스·draft·OData/Gateway 요청 처리 등 **프레임워크 내부 동작** 질문을 받으면:
1. **먼저 `docs/rap-internals/README.md` 와 관련 문서를 읽는다.** 문서로 답할 수 있으면 소스 재분석 없이 답한다.
2. 문서에 없거나 ⚠️(추정)인 부분만 `tools/adt/adt_source.py` 로 소스를 확인한다.
3. 새로 분석한 내용은 **같은 세션에서** `docs/rap-internals/` 에 반영한다 (README 의 업데이트 규칙·분석 이력 준수).

## 개발 네이밍 규칙 (사용자 지정)
- 모든 개발 객체는 `Z` 로 시작
- 패키지: `ZCIH` 로 시작, 반드시 `ZLOCAL` 하위 (소프트웨어 컴포넌트 ZLOCAL, 이송 불필요)
- Root CDS: `ZR_`, 인터페이스 뷰: `ZI_`, 일반 테이블: `ZAT`, 드래프트 테이블: `ZDT`
- (사용자 미지정, 관례 사용) 프로젝션: `ZC_`, UI 서비스 정의: `ZUI_`, 바인딩: `ZUI_..._O4`
- 사용자 SAP ID: `CB9980000051` (패키지/객체 responsible)
- 예시 BO: `ABAP/ZCIH_SO_BO/` (패키지 `ZCIH_SO_BO`, 판매오더 헤더/아이템 managed + draft, 서비스 `ZUI_CIH_SALESORDER_O4`)
