# ZCIH_IF – 인터페이스 수신 화면 (Object Page)

Fiori Object Page 에서 [인터페이스 수신 실행] 버튼 → RAP 액션 → EAI 호출 → 성공/실패 응답.
화면 표시값(인터페이스 정보, 수신 대상 테이블)은 DB 없이 custom entity + 상수 클래스로 제공.

> ⚠️ 설계안 코드. **시스템(Z5U)에 아직 생성·활성화하지 않음.** 활성화 시 오류/경고가 날 수 있음.

## 백엔드 객체
| 파일 | 객체 | 역할 |
|---|---|---|
| `zr_cih_if_info.ddls.asddls` | root custom entity `ZR_CIH_IF_INFO` | 인터페이스 정보 1건 |
| `zr_cih_if_target.ddls.asddls` | custom entity `ZR_CIH_IF_TARGET` | 수신 대상 테이블 (child) |
| `*.ddlx.asddlxs` | 메타데이터 확장 | Object Page UI 어노테이션 |
| `zcl_cih_if_info_data.clas.abap` | `ZCL_CIH_IF_INFO_DATA` | 화면 고정값 |
| `zcl_cih_if_info_query.clas.abap` | `ZCL_CIH_IF_INFO_QUERY` | unmanaged query (두 엔티티 공용) |
| `zr_cih_if_info.bdef.asbdef` | BDEF (unmanaged) | 인스턴스 액션 `receiveInterface` |
| `zbp_r_cih_if_info.clas.*` | behavior pool | read / rba / action / 빈 saver |
| `zui_cih_if.srvd.srvdsrv` | 서비스 `ZUI_CIH_IF` | 바인딩 `ZUI_CIH_IF_O4` (OData V4 - UI) |

## 화면 매핑
| 화면 | 구현 |
|---|---|
| 헤더 제목/부제 | `@UI.headerInfo` |
| 헤더 정보 묶음 / 숫자 | `@UI.fieldGroup` / `@UI.dataPoint` + `@UI.facet` (HEADER) |
| 인터페이스 개요 | `@UI.fieldGroup` 'Overview' |
| 수신 대상 테이블 | `_Target` + `@UI.lineItem` |
| 하단 실행 버튼 | `@UI.identification` `determining: true` |
| 확인 팝업 | `app/webapp/annotations/annotation.xml` `Common.IsActionCritical` |
| 안내 3줄 | `app/webapp/ext/fragment/Guide.fragment.xml` (custom section) |
| 결과 | 성공: `reported-%other` success → 토스트 / 실패: `failed` + error → 팝업 |

## 앱 (`app/webapp/`)
Fiori Elements V4 (Object Page 단독, List Report 라우트 없음, 앱 ID `zcih.ifinfo`). BAS 로 생성한 프로젝트의 `webapp/` 에 덮어쓰면 됨.
- `manifest.json`: dataSource(`ZUI_CIH_IF_O4`), FLP inbound(`ZCIH_IfReceive-display`), routing(Object Page 라우트만. List Report 라우트가 없으면 셸 제목 메뉴에 상위 페이지 항목이 생기지 않음), OP 설정(안내 custom section, 대상 테이블 설정, 하위 네비게이션 없음)
- `i18n/i18n.properties`: 앱 제목 등
- `annotations/annotation.xml`: IsActionCritical
- `ext/fragment/Guide.fragment.xml`: 안내 섹션
- Object Page 바로 진입
  - 런치패드: `manifest.json` inbound 의 파라미터 `IfId` 기본값(`IF_CBO_001`) → 시작 파라미터로 키가 전달되면 Fiori Elements 가 Object Page 를 바로 연다 (커스텀 코드 없음)
  - `Component.js`: 해시가 비어 있으면 `initializeFeatureToggles`(FE public 비동기 훅, 라우팅 초기화 전에 await 됨)에서 `IfInfo` 첫 행을 GET 조회해 그 Object Page 로 진입. 키 하드코딩 없음. 조회 실패 시 오류 팝업

## 확인 필요 (⚠️)
1. custom entity 에 대한 메타데이터 확장 / composition 탐색 시 child query 호출 / strict(2) unmanaged 필수 메서드
2. `IsActionCritical` 팝업 문구는 SAP 표준 (변경은 controller extension 필요)
3. 런치패드 시작 파라미터(`IfId`)로 Object Page 가 바로 열리는지 (S/4 Cloud 에서 manifest inbound 가 Target Mapping 으로 반영되는지 포함)
4. 액션의 EAI 호출부는 TODO (Communication Scenario/Arrangement 구성 후 구현)
