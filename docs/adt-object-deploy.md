# ADT REST 로 개발 객체 생성·수정·활성화

`ZCIH_SO_BO` 생성 때 검증한 절차 (2026-11-03~04, Z5U). 세션은 `adt_login.login()` 으로 얻고,
쓰기 요청에는 `x-csrf-token`(GET discovery 에 `x-csrf-token: fetch`) 과 `X-sap-adt-sessiontype: stateful` 헤더를 붙인다.

## 1. 생성 (POST 컬렉션)

공통 속성: `adtcore:name`, `adtcore:description`, `adtcore:masterLanguage="EN"`, **`adtcore:responsible="CB9980000051"`**(없으면 패키지 생성이 PAK 049 오류), `<adtcore:packageRef adtcore:name="패키지"/>`

| 객체 | 컬렉션 | Content-Type | 루트 요소 / type |
|---|---|---|---|
| 패키지 | `/sap/bc/adt/packages` | `application/vnd.sap.adt.packages.v2+xml` | `pak:package` `DEVC/K` |
| 테이블 | `/sap/bc/adt/ddic/tables` | `application/vnd.sap.adt.tables.v2+xml` | `blue:blueSource` `TABL/DT` |
| CDS | `/sap/bc/adt/ddic/ddl/sources` | `application/vnd.sap.adt.ddlSource+xml` | `ddl:ddlSource` `DDLS/DF` |
| BDEF | `/sap/bc/adt/bo/behaviordefinitions` | `application/vnd.sap.adt.blues.v1+xml` | `blue:blueSource` `BDEF/BDO` |
| 클래스 | `/sap/bc/adt/oo/classes` | `application/vnd.sap.adt.oo.classes.v4+xml` | `class:abapClass` `CLAS/OC` |
| 메타데이터 확장 | `/sap/bc/adt/ddic/ddlx/sources` | `application/vnd.sap.adt.ddic.ddlx.v1+xml` | `ddlx:ddlxSource` `DDLX/EX` (ns `http://www.sap.com/adt/ddic/ddlxsources`) |
| 서비스 정의 | `/sap/bc/adt/ddic/srvd/sources` | `application/vnd.sap.adt.ddic.srvd.v1+xml` | `srvd:srvdSource` `SRVD/SRV`, `srvd:srvdSourceType="S"` (ns `http://www.sap.com/adt/ddic/srvdsources`) |
| 서비스 바인딩 | `/sap/bc/adt/businessservices/bindings` | `application/vnd.sap.adt.businessservices.servicebinding.v2+xml` | `srvb:serviceBinding` `SRVB/SVB` (아래 예) |

패키지 본문 예:
```xml
<pak:package xmlns:pak="http://www.sap.com/adt/packages" xmlns:adtcore="http://www.sap.com/adt/core"
  adtcore:name="ZCIH_XXX" adtcore:type="DEVC/K" adtcore:description="..." adtcore:responsible="CB9980000051" adtcore:masterLanguage="EN">
  <adtcore:packageRef adtcore:name="ZCIH_XXX"/>
  <pak:attributes pak:packageType="development" pak:languageVersion="5"/>
  <pak:superPackage adtcore:name="ZLOCAL"/>
  <pak:applicationComponent/>
  <pak:transport><pak:softwareComponent pak:name="ZLOCAL"/><pak:transportLayer pak:name=""/></pak:transport>
  <pak:translation/><pak:useAccesses/><pak:packageInterfaces/><pak:subPackages/>
</pak:package>
```
네임스페이스: blue `http://www.sap.com/wbobj/blue`, ddl `http://www.sap.com/adt/ddic/ddlsources`, class `http://www.sap.com/adt/oo/classes`.

## 2. 소스 쓰기
1. `POST {objuri}?_action=LOCK&accessMode=MODIFY` (Accept `application/*,application/vnd.sap.as+xml;charset=UTF-8;dataname=com.sap.adt.lock.result`) → `<LOCK_HANDLE>`
2. `PUT {objuri}/source/main?lockHandle=...` (`text/plain; charset=utf-8`)
   - 클래스 로컬 타입(행위 풀 lhc_ 등): `{objuri}/includes/implementations`
3. `POST {objuri}?_action=UNLOCK&lockHandle=...`
- ZLOCAL 하위는 이송요청(corrNr) 불필요.

## 3. 활성화
`POST /sap/bc/adt/activation?method=activate&preauditRequested=true`, Content-Type `application/xml`
```xml
<adtcore:objectReferences xmlns:adtcore="http://www.sap.com/adt/core">
  <adtcore:objectReference adtcore:uri="/sap/bc/adt/ddic/tables/zat_x" adtcore:name="ZAT_X"/>
</adtcore:objectReferences>
```
- 응답의 `<msg type="E|W">` 확인. 서로 참조하는 객체(root/child CDS, BDEF+행위풀)는 한 번에 활성화.
- 순서: 테이블 → CDS → BDEF + 행위 풀 → 인터페이스 BDEF.

## 3-1. 서비스 바인딩 생성·게시 (OData V4 UI)
```xml
<srvb:serviceBinding xmlns:srvb="http://www.sap.com/adt/ddic/ServiceBindings" xmlns:adtcore="http://www.sap.com/adt/core"
  adtcore:name="ZUI_X_O4" adtcore:type="SRVB/SVB" adtcore:description="..." adtcore:responsible="CB9980000051" adtcore:masterLanguage="EN">
  <adtcore:packageRef adtcore:name="ZCIH_XXX"/>
  <srvb:services srvb:name="ZUI_X_O4"><srvb:content srvb:version="0001"><srvb:serviceDefinition adtcore:name="ZUI_X"/></srvb:content></srvb:services>
  <srvb:binding srvb:type="ODATA" srvb:version="V4" srvb:category="0"><srvb:implementation adtcore:name="ZUI_X_O4"/></srvb:binding>
</srvb:serviceBinding>
```
- `category="0"` = UI, `"1"` = Web API. 생성 후 activate.
  - Web API 바인딩의 서비스 URL 은 `/srvd/` 대신 `/srvd_a2x/` (`/sap/opu/odata4/sap/<바인딩>/srvd_a2x/sap/<바인딩>/0001/`)
- 게시: `POST /sap/bc/adt/businessservices/odatav4/publishjobs?servicename=ZUI_X_O4&serviceversion=0001`
  본문 `<adtcore:objectReferences><adtcore:objectReference adtcore:type="SCSB/SVB" adtcore:name="ZUI_X_O4"/></adtcore:objectReferences>`
  - 응답이 프록시에서 502 로 끊겨도 실제로는 게시됨 → 바인딩 GET 의 `srvb:published="true"` 로 확인.
- 서비스 URL: `/sap/opu/odata4/sap/<바인딩명 소문자>/srvd/sap/<바인딩명 소문자>/0001/`
  (정확한 값은 `GET /sap/bc/adt/businessservices/odatav4/<바인딩명>?servicename=..&serviceversion=0001&srvdname=..` 의 `serviceUrl`)
- 게시 직후 몇 분간 `403 ... blocked by UCON` 이 날 수 있음 → 잠시 후 재시도하면 200 (UCON 허용 목록 반영 지연).
- 같은 SAML 세션(`adt_login.login()`)으로 OData 호출 가능. side effects 등은 `$metadata` 의 `SAP__common.SideEffects` 로 확인.

## 4. 실행 (if_oo_adt_classrun)
`POST /sap/bc/adt/oo/classrun/{CLASS}` (Accept `text/plain`) — 응답 charset 미지정이라 `r.content.decode('utf-8')` 로 읽을 것.

## 주의
- 패키지가 없는 상태에서 객체 생성 시 `S_ABPLNGVS` 권한 오류로 보임 → 실제 원인은 패키지 미존재.
- 기타 조회: 현재 사용자 `GET /sap/bc/adt/core/http/systeminformation`, 이름 검색 `GET /sap/bc/adt/repository/informationsystem/search?operation=quickSearch&query=Z*`
