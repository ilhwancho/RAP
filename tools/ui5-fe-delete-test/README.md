# FE V4 리스트 리포트 Delete 버튼 숨김 실측 하네스

판매오더 샘플 서비스(`ZUI_CIH_SALESORDER_O4`, `/SalesOrder`) 위에 최소 Fiori Elements V4 List Report 를 띄워
테이블 툴바의 Delete 버튼 표시 여부를 확인한다. 결과 정리는 `docs/fe/hide-delete-button-v4.md`.

- `fwd.py` : 127.0.0.1:8766 로컬 서버. `index.html`·`app/*` 서빙, `/sap/*` 는 `adt_login` 세션으로 SAP 중계.
  환경변수 `MAN`(app/ 아래 manifest 파일명), `UI5V`(UI5 버전, 예 1.148.0).
- `app/manifest.json` 기본 / `app/hide.json` `StandardAction::Delete: {visible:false}` / `app/anno.json` 로컬 주석(`annotation.xml`, `UI.DeleteHidden`) 연결.
- `run.js` : Delete 버튼 ID·visible 과 툴바 버튼 텍스트 출력, 스크린샷 저장.

실행 예: `UI5V=1.148.0 tools/ui5-fe-delete-test/go.sh hide.json`
