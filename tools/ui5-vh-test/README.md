# UI5 V2 값 도움말 테스트 하네스

`ZUI_CIH_SOVHTEST_O2` (패키지 `ZCIH_VH_TEST`) 값 도움말 동작을 브라우저에서 실측하는 도구. 결과 정리는 `docs/cds/value-help-presentation-variant-v2.md`.

- `fwd.py` : 로컬 서버(127.0.0.1:8765). `index.html`·`fe.html`·`feapp/*` 를 서빙하고 `/sap/opu/*` 는 `adt_login` 세션으로 SAP 에 중계(같은 origin → CORS·로그인 불필요).
  환경변수: `STRIP`(ValueList 의 PresentationVariantQualifier 제거), `FIXED`(ValueListWithFixedValues 주입), `EDITABLE`(ZC 엔티티셋 creatable/updatable 로 서빙),
  `UI5V`(UI5 버전, 예 1.120.53), `MANIFEST`(variants/ 의 manifest), `LOCAL`(variants/ 의 로컬 주석 파일).
- `index.html` : SmartFilterBar + SmartField 하네스. `fe.html` + `feapp/` : 최소 Fiori Elements V2 List Report.
- `run3.js` / `go.sh <tag>` : 다이얼로그 (a) SmartFilterBar (b) SmartField (c) FE 측정.
- `run4.js` / `go4.sh <tag> <manifest> <local>` : FE 에서 로컬 주석·확장 변형 측정 (`USERSORT=1` 이면 사용자 컬럼 정렬도).
- `fe4.html` + `fe4app/` + `run5.js` / `go5.sh <tag>` : Fiori Elements V4 List Report (바인딩 `ZUI_CIH_SOVHTEST_O4`) 자동완성·다이얼로그 측정.
- `run6.js` / `go6.sh [shotdir]` : FE V4 파라미터 CDS 값 도움말 필터 필드(`CurrConst`·`CurrElem`·`CurrSys`·`CurrNone`) 측정. 결과 `docs/cds/parameterized-value-help-v4.md`.
- `feapp/ext/ListReportExt.controller.js` : 다이얼로그 기본 정렬을 바꾸는 FE V2 컨트롤러 확장 예.

실행 예: `UI5V=1.120.53 tools/ui5-vh-test/go.sh test` (Playwright, 스크린샷은 `../shots` 기준 경로에 저장).
