# FE V4 리스트 리포트 Delete 버튼 숨김 실측 하네스

판매오더 샘플 서비스(`ZUI_CIH_SALESORDER_O4`, `/SalesOrder`) 위에 최소 Fiori Elements V4 List Report 를 띄워
테이블 툴바의 Delete 버튼 표시 여부를 확인한다. 결과 정리는 `docs/fe/hide-delete-button-v4.md`.

- `fwd.py` : 127.0.0.1:8766 로컬 서버. `index.html`·`app/*` 서빙, `/sap/*` 는 `adt_login` 세션으로 SAP 중계.
  환경변수 `MAN`(app/ 아래 manifest 파일명), `UI5V`(UI5 버전, 예 1.148.0).
- `app/manifest.json` 기본 / `app/hide.json` `StandardAction::Delete: {visible:false}` / `app/anno.json` 로컬 주석(`annotation.xml`, `UI.DeleteHidden`) 연결.
- `run.js` : Delete 버튼 ID·visible 과 툴바 버튼 텍스트 출력, 스크린샷 저장.

실행 예: `UI5V=1.148.0 tools/ui5-fe-delete-test/go.sh hide.json`

## 커스텀 열 Excel Export 측정 (2026-11-26)
결과 정리 `docs/fe/custom-column-export-v4.md`.
- `app/exp.json` + `exp_anno.xml` : LR 커스텀 열 (`properties` 가 UI.Hidden 속성 / 숨긴 DataField / 바인딩 없음). `run_export_lr.js`
- `app/expop.json` + `expop_anno.xml` : OP 아이템 테이블(`_Item`) 커스텀 열. `expop_pv.json`(PresentationVariant RequestAtLeast), `expop_fix.json`(프래그먼트에 숨김 바인딩). `run_export_op.js`
- 실행 예: `pkill -f "python fwd.py"; (cd tools/ui5-fe-delete-test; MAN=expop.json UI5V=1.148.12 python fwd.py &) ; NODE_PATH=$(npm root -g) node tools/ui5-fe-delete-test/run_export_op.js`
- 출력: Export 열 설정(`property`), 테이블 row binding `getDownloadUrl()` 의 `$select`, 그 URL 로 받은 첫 행.
