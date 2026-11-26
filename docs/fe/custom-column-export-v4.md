# FE V4 커스텀 열(manifest `columns`) Excel Export 값이 비는 이유 (2026-11-26 실측)

## 결론
- `@UI.hidden`(속성) 이나 `@UI.lineItem` 숨김(DataField `UI.Hidden`) 은 **Export 열 설정을 막지 않는다.** 커스텀 열 Export 의 `property` 는 manifest `properties` 그대로 나온다.
- 값이 비는 원인은 **데이터 요청 `$select`**. Export 는 테이블 row binding 의 다운로드 URL(`getDownloadUrl()`)로 데이터를 받는데,
  **Object Page 테이블은 셀 템플릿에 바인딩된 필드만 `$select` 에 넣는다** (autoExpandSelect). manifest `properties` 만으로는 안 들어간다.
  - 숨긴 DataField 열은 렌더링되지 않으므로 그 필드를 `$select` 로 끌어오지 못한다. → "lineItem 을 숨겼더니 Excel 이 빈다" 는 이 경로.
- 해결: 커스텀 열 프래그먼트 안에서 그 필드를 바인딩한다 (보이지 않아도 됨).
  ```xml
  <HBox><Text text="..."/><Text text="{ProductID}" visible="false"/></HBox>
  <!-- 또는 -->
  <Text text="..."><customData><core:CustomData key="x" value="{CurrencyCode}"/></customData></Text>
  ```
  둘 다 `$select` 에 들어가고 값이 옴 (1.148 실측).

## 실측 (서비스 `ZUI_CIH_SALESORDER_O4`, 하네스 `tools/ui5-fe-delete-test/`)
로컬 주석으로 LineItem 을 `ItemNo` + `CurrencyCode`(DataField `UI.Hidden`) 로 바꾸고 커스텀 열 추가.

| 위치 | 커스텀 열 `properties` | 프래그먼트 바인딩 | `$select` 포함 | UI5 |
|---|---|---|---|---|
| OP `_Item` | `ItemUUID` (속성 `@UI.hidden`, 키) | 있음/없음 | O (키라서 항상) | 1.148.9, 1.154 |
| OP `_Item` | `CurrencyCode` (DataField UI.Hidden) | 있음 | O | 1.148.9, 1.154 |
| OP `_Item` | `CurrencyCode` (DataField UI.Hidden) | **없음** | **X** | 1.148.9 |
| OP `_Item` | `ProductID` (LineItem 에 없음) | **없음** | **X** | 1.148.9, 1.154 |
| OP `_Item` | `Quantity` | 있음 | O | 1.148.9 |
| OP `_Item` | `ProductID` + PresentationVariant `RequestAtLeast: [ProductID]` (LineItem 시각화) | 없음 | X | 1.148.9, 1.154 |
| OP `_Item` | 위 숨김 `Text` / `CustomData` 바인딩 | 있음(숨김) | O | 1.148.9 |
| LR | `SalesOrderUUID`·`CurrencyCode`(숨김)·`CustomerID`·`Description` | 일부 없음 | 모두 O | 1.120.51, 1.148.9, 1.154 |

- Export 열 설정(`_createExportColumnConfiguration`)은 모든 경우 `property=[<properties 값>]` 으로 정상.
- LR 은 바인딩 없는 `CustomerID` 도 `$select` 에 들어감. ⚠️ 이유 미확인 (LR 의 다른 경로 — 헤더 정보·필터 등 — 로 추정). OP 와 동작이 다르므로 LR 결과로 OP 를 판단하지 말 것.

## 소스 근거 (UI5 1.154)
- `sap/fe/core/converters/controls/Common/table/Columns.js`
  - `getColumnsFromManifest` → 커스텀 열 `_getPropertyNames(properties)` → 같은 relativePath 의 annotation 열 이름(숨김이어도) 또는 `_createRelatedColumns` 로 property 열 생성.
  - `getCustomExportSettings` → `property`/`template`. annotation 열·property 열의 `exportSettings` 생성(`createColumnExportSettings`)에 Hidden 조건 없음.
- `sap/ui/mdc/table/PropertyHelper.getColumnExportSettings` → `property: getSimpleProperties().map(p => p.path)`.
- `sap/ui/mdc/Table._onExport` → `dataSource: this.getRowBinding()` (데이터는 row binding 의 요청 파라미터, 즉 `$select` 를 따름).
