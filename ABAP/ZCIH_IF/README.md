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

## 앱 (`app/webapp/`, 참고용 발췌)
BAS *List Report Page* 템플릿으로 `ZUI_CIH_IF_O4` 연결해 생성 (child Object Page 는 생성하지 않음) 후:
- `annotations/annotation.xml`: IsActionCritical 블록 추가
- `ext/fragment/Guide.fragment.xml`: 안내 섹션
- `manifest.objectpage-target.json`: manifest 의 Object Page target 설정 발췌
- `Component.js`: 시작 시 Object Page 로 바로 진입

## 확인 필요 (⚠️)
1. custom entity 에 대한 메타데이터 확장 / composition 탐색 시 child query 호출 / strict(2) unmanaged 필수 메서드
2. `IsActionCritical` 팝업 문구는 SAP 표준 (변경은 controller extension 필요)
3. `Component.js` 해시 교체 방식이 FLP 안에서 동작하는지
4. 액션의 EAI 호출부는 TODO (Communication Scenario/Arrangement 구성 후 구현)
