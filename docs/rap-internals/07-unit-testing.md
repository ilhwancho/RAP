# 07. RAP BO 유닛 테스트 (ABAP Unit)

RAP BO 를 ABAP Unit 으로 테스트하는 방법. ABAP Cloud 키워드 문서(Z5U, 릴리스 920, `version=5`)와
시스템의 실제 테스트 클래스(`BP_DEMO_MANAGED_ROOT_2`, `CL_SD_BEHV_SALESORDER`)를 읽고 정리했다.

- 테스트 include 조회: `python tools/adt/adt_source.py get <클래스>` → `/tmp/adt_src/<클래스>.testclasses.abap`
- ✅ 방식 A(핸들러 직접 호출), 방식 A'(규칙 클래스 분리 + 주입), fixture 4개 데모를 `ZCIH_SO_BO` 에 적용해 Z5U 에서 실행 확인 (2026-11-09) → **7절**.
- ⚠️ 방식 B(4절) 예시 코드는 아직 실행해 보지 않았다.

## 1. 키워드 문서가 말하는 것 (✅ 문서 확인)

| 문서 object id | 내용 |
|---|---|
| `ABAPCREATE_OBJECT_FOR_TESTING` | "ABAP EML – Testing RAP Business Objects" 섹션의 유일한 항목. RAP handler 클래스는 `CREATE OBJECT ref FOR TESTING` 으로만 인스턴스화 가능. 상세는 RAP Development Guide "Test" 로 링크. 예제: `BP_DEMO_MANAGED_ROOT_2` |
| `ABAPCLASS_FOR_TESTING` | `CLASS ... FOR TESTING [RISK LEVEL CRITICAL\|DANGEROUS\|HARMLESS] [DURATION SHORT\|MEDIUM\|LONG]`. RISK LEVEL 기본값 `CRITICAL`, `DANGEROUS` = 영속 데이터 변경. 테스트 클래스는 운영 코드에서 참조 불가(운영 클래스가 `FRIENDS` 로 지정하는 것만 예외). fixture: `setup`/`teardown`(인스턴스, 테스트마다), `class_setup`/`class_teardown`(static, 1회). 클래스 풀의 로컬 테스트 클래스는 test include(ADT "Test Classes" 탭)에. 전역 테스트 클래스는 test relation 필수 |
| `ABAPMETHODS_TESTING` | `METHODS m FOR TESTING [RAISING ...]`. 검증은 `CL_ABAP_UNIT_ASSERT` (`ASSERT_EQUALS`, `ASSERT_INITIAL`, `ASSERT_NOT_INITIAL`, `ASSERT_BOUND`, `ASSERT_SUBRC`, `FAIL` …). fixture 메서드엔 `FOR TESTING` 불가. 테스트 메서드 개수 제한 없음 |
| `ABENABAP_UNIT` | test double 은 `INTERFACES ... PARTIALLY IMPLEMENTED` 로 직접 만들거나 `CL_ABAP_TESTDOUBLE`(ABAP Test Double Framework) 사용 |
| `ABENTEST_RELATIONS` | `"! @testing [kind:]name` — 테스트 클래스/메서드를 다른 저장소 객체에 연결 → 그 객체에서 ADT 로 테스트 실행 가능. BDEF 는 `BDEF:` 필수, CDS·클래스는 이름만 |
| "CLASS, LOCAL FRIENDS" (`docu "LOCAL FRIENDS"`) | **전역 클래스 전용**. 로컬 handler 클래스의 private 메서드를 테스트하려면 handler 정의에 `FRIENDS ltc_...` 를 직접 붙인다 (아래 2) |
| `ABENTEST_SEAMS` | `TEST-SEAM` / `TEST-INJECTION` — 운영 코드 일부를 테스트 시 교체 |

## 2. 방식 A — handler 메서드 단위 테스트 (키워드 문서 예제 방식, ✅ `BP_DEMO_MANAGED_ROOT_2`)

행동 구현 클래스의 **Test Classes 탭**에 로컬 테스트 클래스를 두고, handler 메서드를 EML 없이 직접 호출한다.

**locals_imp** (handler 정의):
```abap
CLASS ltc_managed DEFINITION DEFERRED FOR TESTING.
CLASS lhc_demo_managed_root_2 DEFINITION INHERITING FROM cl_abap_behavior_handler FRIENDS ltc_managed.
```

**testclasses** (요약):
```abap
"! @testing BDEF:DEMO_MANAGED_ROOT_2
CLASS ltc_managed DEFINITION FINAL FOR TESTING DURATION SHORT RISK LEVEL HARMLESS.
  PRIVATE SECTION.
    CLASS-DATA: class_under_test     TYPE REF TO lhc_demo_managed_root_2,
                cds_test_environment TYPE REF TO if_cds_test_environment,
                sql_test_environment TYPE REF TO if_osql_test_environment.
    ...
METHOD class_setup.
  CREATE OBJECT class_under_test FOR TESTING.
  cds_test_environment = cl_cds_test_environment=>create( i_for_entity = 'DEMO_MANAGED_ROOT_2' ).
  sql_test_environment = cl_osql_test_environment=>create( i_dependency_list = VALUE #( ( 'DEMO_TAB_ROOT_2' ) ) ).
ENDMETHOD.
METHOD class_teardown. cds_test_environment->destroy( ). sql_test_environment->destroy( ). ENDMETHOD.
METHOD setup.          cds_test_environment->clear_doubles( ). sql_test_environment->clear_doubles( ). ENDMETHOD.
METHOD teardown.       ROLLBACK ENTITIES. ENDMETHOD.

METHOD validate_field.
  cds_test_environment->insert_test_data( cds_mock_data ).
  DATA failed   TYPE RESPONSE FOR FAILED LATE demo_managed_root_2.
  DATA reported TYPE RESPONSE FOR REPORTED LATE demo_managed_root_2.
  class_under_test->validate_field( EXPORTING keys = CORRESPONDING #( cds_mock_data )
                                    CHANGING  failed = failed reported = reported ).
  cl_abap_unit_assert=>assert_initial( act = failed ).
ENDMETHOD.
```

포인트:
- handler 안의 `READ ENTITIES ... IN LOCAL MODE` 도 동작한다 — 데이터는 CDS/OSQL double 에서 읽힌다.
  (따라서 "IN LOCAL MODE EML 이 있으면 handler 를 떼어 테스트할 수 없다" 는 틀린 생각이다.)
- validation/determination 의 `failed`/`reported` 는 `RESPONSE FOR ... LATE` 타입.

## 3. 방식 A' — 위임 구조 + 인터페이스 test double (✅ `CL_SD_BEHV_SALESORDER`)

SAP 표준 판매오더 BO 의 행동 구현 클래스. Test include 7,818줄, 테스트 메서드 147개.
메서드를 이렇게 많이 둘 수 있는 건 **handler 메서드 하나 = 테스트 하나** 로 떼어 낼 수 있게 설계했기 때문:

1. `locals_imp` 에서 `class ltcl_sd_behv_salesorder definition deferred for testing.` 후
   `class lhc_salesorder definition inheriting from cl_abap_behavior_handler final friends ltcl_sd_behv_salesorder.`
   (saver 도 `lcl_saver ... friends ltcl_saver`). 전역 클래스엔 test include 에서 `CLASS cl_sd_behv_salesorder DEFINITION LOCAL FRIENDS ltcl_sd_behv_salesorder.`
2. `setup` 에서 `CREATE OBJECT mo_cut FOR TESTING.`
3. handler 는 로직 없이 위임만 한다:
   `cl_sd_rap_so_factory=>so_instance->get_so_behavior( )->get_entity_feature_control( ... )`
4. 테스트는 위임 대상을 double 로 주입:
   ```abap
   mo_so_behavior_double ?= cl_abap_testdouble=>create( 'IF_SD_SALESORDER_BEHAVIOR' ).
   tcl_sd_rap_so_factory=>inject_salesorder_behavior( mo_so_behavior_double ).
   ```
5. 각 테스트 = 설정(`cl_abap_testdouble=>configure_call( double )->set_parameter( ... )->and_expect( )->is_called_once( )`)
   → handler 직접 호출(`mo_cut->get_head_fc( ... )`) → 결과 pass-through 검증 + `verify_expectations`.
   반복은 `configure_*` / `assert_*` 헬퍼로 뺐고, `ldcl_sd_salesorder_behavior`(`PARTIALLY IMPLEMENTED`) 같은 수동 double 도 함께 쓴다.

EML·DB·트랜잭션 버퍼·세이브 시퀀스가 전혀 없어 빠르고 독립적이다. 실제 로직은 `IF_SD_SALESORDER_BEHAVIOR` 뒤(레거시 SD 엔진)에서 따로 테스트된다.

## 4. 방식 B — EML 로 BO 전체 테스트 (통합 테스트 성격)

별도 전역 테스트 클래스(test relation 필요) 또는 아무 클래스의 Test Classes 탭에서 EML 로 BO 를 호출한다.
**어디에 두느냐가 아니라 EML 대상(`OF zi_...` vs `OF zc_...`)이 테스트 대상을 정한다.**

```abap
"! @testing ZI_CIH_SALESORDER
CLASS ztc_cih_salesorder DEFINITION PUBLIC FINAL FOR TESTING RISK LEVEL HARMLESS DURATION SHORT.
  PRIVATE SECTION.
    CLASS-DATA sql_env TYPE REF TO if_osql_test_environment.
    ...
METHOD class_setup.
  " BO 가 쓰는 테이블 전부 (active + draft)
  sql_env = cl_osql_test_environment=>create(
              i_dependency_list = VALUE #( ( 'ZAT_CIH_SOH' ) ( 'ZAT_CIH_SOI' ) ( 'ZDT_CIH_SOH' ) ( 'ZDT_CIH_SOI' ) ) ).
ENDMETHOD.
METHOD setup.    sql_env->clear_doubles( ). ENDMETHOD.
METHOD teardown. ROLLBACK ENTITIES. ENDMETHOD.

METHOD create_with_items.
  MODIFY ENTITIES OF zi_cih_salesorder ENTITY SalesOrder
    CREATE FIELDS ( CustomerID Description DeliveryDate CurrencyCode )
    WITH VALUE #( ( %cid = 'SO1' %is_draft = if_abap_behv=>mk-off CustomerID = '0010100001' ... ) )
    ...
    MAPPED DATA(mapped) FAILED DATA(failed).
  cl_abap_unit_assert=>assert_initial( failed ).
  COMMIT ENTITIES RESPONSE OF zi_cih_salesorder FAILED DATA(commit_failed).
  cl_abap_unit_assert=>assert_initial( commit_failed ).
  READ ENTITIES OF zi_cih_salesorder ... RESULT DATA(orders).
  cl_abap_unit_assert=>assert_not_initial( orders[ 1 ]-SalesOrderID ).
ENDMETHOD.
```

- ⚠️ `COMMIT ENTITIES` 의 managed 세이브가 OSQL double 테이블로 쓰는지는 Z5U 에서 아직 실행 확인 전.
- 채번(`setSalesOrderID` 가 `ZAT_CIH_SOH` SELECT)은 빈 double 기준 → 특정 번호를 기대하면 `insert_test_data` 로 선행 데이터.
- draft 경로: `%is_draft = mk-on` CREATE → `EXECUTE Activate` → `COMMIT ENTITIES`.

## 5. 어떤 도구를 언제

| 목적 | 도구 |
|---|---|
| handler 메서드 단위 테스트 (방식 A) | `CREATE OBJECT ... FOR TESTING` + `CL_CDS_TEST_ENVIRONMENT` / `CL_OSQL_TEST_ENVIRONMENT` |
| 위임 대상 mock (방식 A') | `CL_ABAP_TESTDOUBLE`, `INTERFACES ... PARTIALLY IMPLEMENTED` |
| BO 전체 동작 (방식 B) | 실제 EML + `CL_OSQL_TEST_ENVIRONMENT` |
| BO 를 **호출하는 쪽** 코드 테스트 (BO 는 가짜) | `CL_BOTD_TXBUFDBL_BO_TEST_ENV`(트랜잭션 버퍼 double), `CL_BOTD_MOCKEMLAPI_BO_TEST_ENV`(EML 응답 mock) |
| CDS 뷰 로직 | `CL_CDS_TEST_ENVIRONMENT` |

위 클래스들은 모두 Z5U 에 존재함을 확인(✅ `adt_source.py search`).

## 6. 이 레포 BO 에 적용

- 인터페이스 BO(`ZI_CIH_SalesOrder`)는 행동 구현 클래스가 없다 → 방식 B 는 별도 클래스 또는 `ZBP_R_CIH_SALESORDER` 의 Test Classes 탭.
- projection BDEF 에 `projection implementation in class zbp_c_... unique;` 를 넣어 행동 구현 클래스를 만들 수도 있다
  (`ABENBDL_IN_CLASS_UNIQUE`: projection 은 선택, 새 action/function 이 있으면 필수). 하지만 비어 있는 클래스라 방식 A 의 실익은 없다.
- 방식 A 를 `ZBP_R_CIH_SALESORDER` 에 적용: `lhc_salesorder` 에 `FRIENDS ltc_...` 추가 → `ZR_CIH_SalesOrder`/`ZAT_CIH_SOH`/`ZDT_CIH_SOH` double
  → `class_under_test->validatecustomer( ... )` 직접 호출.
- ADT: 클래스에서 `Ctrl+Shift+F10` (ABAP Unit), 커버리지 `Ctrl+Shift+F11`.

## 7. 실측: `ZCIH_SO_BO` 에 적용 (✅ 2026-11-09, Z5U)

### 7.1 무엇을 어디서 테스트했나
| 대상 | 테스트 위치 (ADT Test Classes 탭) | 방식 | 결과 |
|---|---|---|---|
| `acceptOrder` 액션 핸들러 | `ZBP_R_CIH_SALESORDER` | A: 핸들러 직접 호출 + CDS/OSQL double | 4/4 PASS |
| 신용한도 규칙 | `ZCL_CIH_CREDIT_CHECK` | A': 규칙 클래스 분리 + 가짜 데이터 부품 주입 | 4/4 PASS |
| 신용한도 데이터 DB 조회 | `ZCL_CIH_CREDIT_DATA_DB` | OSQL double, **fixture 4개 모두 사용** | 5/5 PASS |

- **정답: 둘 다.** 핸들러(`lhc_*`)는 행위 풀의 로컬 클래스라 **행위 풀 Test Classes 탭**에서만 접근 가능 → 핸들러 테스트는 거기.
  업무 규칙은 운영 코드 설계상 별도 클래스로 빼고 **그 클래스의 Test Classes 탭**에서 꼼꼼히. 핸들러는 위임만 하게 얇게.
- 각 테스트에 일부러 틀린 기대값을 넣어 FAIL 이 나는 것도 확인 (예: `Expected [X] Actual [A]`). 실행 후 실제 테이블에 테스트 데이터 0건.
- 소스: `ABAP/ZCIH_SO_BO/` (`*.clas.testclasses.abap` = Test Classes 탭). 시스템 active 버전을 그대로 받아 저장.

### 7.2 확인된 사실
- 핸들러 클래스에 `FRIENDS` + 앞에 `DEFINITION DEFERRED FOR TESTING` 을 두면 테스트 클래스에서 private 핸들러 메서드 직접 호출 가능.
- `CREATE OBJECT mo_cut FOR TESTING` 으로 핸들러 생성 (`NEW` 불가).
- 핸들러 안의 `READ ENTITIES ... IN LOCAL MODE` 는 `CL_CDS_TEST_ENVIRONMENT( 'ZR_CIH_SALESORDER' )` 에 넣은 데이터를 읽는다
  (`insert_test_data` 에는 엔티티가 아니라 **데이터 소스 테이블(`ZAT_CIH_SOH`) 행**을 넣음).
- 핸들러가 부르는 다른 클래스의 **직접 ABAP SQL**(`SELECT ... FROM zat_cih_soh / zat_cih_crlim`)은 `CL_OSQL_TEST_ENVIRONMENT` 에 같은 데이터를 넣어 해결.
  → 같은 테이블을 CDS env 와 OSQL env 양쪽에 넣었고 문제 없었다 (SAP 예제 `BP_DEMO_MANAGED_ROOT_2` 도 두 env 병용).
- 액션 핸들러 직접 호출 시그니처: `EXPORTING keys` / `CHANGING result mapped failed reported`,
  타입 `TABLE FOR ACTION IMPORT|RESULT ...~acceptOrder`, `RESPONSE FOR MAPPED|FAILED|REPORTED EARLY`.
  (validation/determination 은 `... LATE` — 2절)
- `teardown` 의 `ROLLBACK ENTITIES` 로 핸들러가 바꾼 트랜잭션 버퍼를 버린다. COMMIT 없이 액션 로직만 검증 가능.
- `"! @testing BDEF:ZR_CIH_SALESORDER` 로 BDEF 에서 우클릭 실행 가능 (CDS/BDEF 자체에는 테스트가 없으므로 test relation 필요).
- fixture 메서드 이름은 고정(`class_setup`/`class_teardown`/`setup`/`teardown`), PRIVATE, `FOR TESTING` 금지 (`ABAPCLASS_FOR_TESTING`).
  `FOR TESTING` 클래스는 테스트 메서드가 없어도 됨(test double·헬퍼) — 운영 코드에서 참조 불가, 운영 시스템에 생성되지 않음.

### 7.3 방식 A 코드 — 행위 풀
Local Types (`zbp_r_cih_salesorder.clas.locals_imp.abap`) 앞부분:
```abap
CLASS ltc_accept_order DEFINITION DEFERRED FOR TESTING.

CLASS lhc_salesorder DEFINITION INHERITING FROM cl_abap_behavior_handler FRIENDS ltc_accept_order.
```
`acceptOrder` (규칙은 `zcl_cih_credit_check` 에 위임):
```abap
  METHOD acceptOrder.
    READ ENTITIES OF zr_cih_salesorder IN LOCAL MODE
      ENTITY SalesOrder
        FIELDS ( CustomerID TotalAmount CurrencyCode ) WITH CORRESPONDING #( keys )
      RESULT DATA(orders_in).

    " 신용한도 체크는 별도 클래스에 위임 (zcl_cih_credit_check)
    DATA(lo_credit) = zcl_cih_credit_check=>create( ).
    DATA lt_update TYPE TABLE FOR UPDATE zr_cih_salesorder\\SalesOrder.

    LOOP AT orders_in INTO DATA(order_in).
      TRY.
          lo_credit->check( iv_customer = order_in-CustomerID
                            iv_amount   = order_in-TotalAmount
                            iv_currency = order_in-CurrencyCode ).
          APPEND VALUE #( %tky = order_in-%tky OverallStatus = c_status-accepted ) TO lt_update.
        CATCH zcx_cih_credit INTO DATA(lx_credit).            " 한도 초과 / 미등록 고객
          APPEND VALUE #( %tky = order_in-%tky ) TO failed-salesorder.
          APPEND VALUE #( %tky = order_in-%tky
                          %msg = new_message_with_text( severity = if_abap_behv_message=>severity-error
                                                        text     = lx_credit->get_text( ) ) )
                 TO reported-salesorder.
      ENDTRY.
    ENDLOOP.

    CHECK lt_update IS NOT INITIAL.

    MODIFY ENTITIES OF zr_cih_salesorder IN LOCAL MODE
      ENTITY SalesOrder
        UPDATE FIELDS ( OverallStatus ) WITH lt_update.

    READ ENTITIES OF zr_cih_salesorder IN LOCAL MODE
      ENTITY SalesOrder
        ALL FIELDS WITH CORRESPONDING #( lt_update )
      RESULT DATA(orders).

    result = VALUE #( FOR order IN orders ( %tky = order-%tky %param = order ) ).

    " 시험용: 인스턴스에 묶인 transition 메시지 (OData 메시지 경로 확인, docs/rap-internals/07)
    LOOP AT orders INTO DATA(order_ok).
      APPEND VALUE #( %tky = order_ok-%tky
                      %msg = new_message_with_text(
                               severity = if_abap_behv_message=>severity-success
                               text     = |Order { order_ok-SalesOrderID } accepted| ) ) TO reported-salesorder.
    ENDLOOP.
  ENDMETHOD.
```
Test Classes (`zbp_r_cih_salesorder.clas.testclasses.abap`) 전문:
```abap
"! acceptOrder 액션 핸들러 테스트 (방식 A: 핸들러 메서드 직접 호출, EML 없이)
"! @testing BDEF:ZR_CIH_SALESORDER
CLASS ltc_accept_order DEFINITION FINAL FOR TESTING DURATION SHORT RISK LEVEL HARMLESS.
  PRIVATE SECTION.
    TYPES tt_keys     TYPE TABLE FOR ACTION IMPORT zr_cih_salesorder\\SalesOrder~acceptOrder.
    TYPES tt_result   TYPE TABLE FOR ACTION RESULT zr_cih_salesorder\\SalesOrder~acceptOrder.

    CLASS-DATA mo_cut TYPE REF TO lhc_salesorder.              " 테스트 대상: 핸들러 (FRIENDS 로 private 메서드 접근)
    CLASS-DATA go_cds TYPE REF TO if_cds_test_environment.     " ZR_CIH_SalesOrder 를 가짜 데이터로
    CLASS-DATA go_sql TYPE REF TO if_osql_test_environment.    " 신용한도 클래스가 직접 SELECT 하는 테이블을 가짜로

    DATA ms_result   TYPE tt_result.
    DATA ms_mapped   TYPE RESPONSE FOR MAPPED EARLY zr_cih_salesorder.
    DATA ms_failed   TYPE RESPONSE FOR FAILED EARLY zr_cih_salesorder.
    DATA ms_reported TYPE RESPONSE FOR REPORTED EARLY zr_cih_salesorder.

    CLASS-METHODS class_setup.
    CLASS-METHODS class_teardown.
    METHODS setup.
    METHODS teardown.

    METHODS accept_within_limit     FOR TESTING.
    METHODS reject_over_limit       FOR TESTING.
    METHODS reject_with_open_amount FOR TESTING.
    METHODS reject_unknown_customer FOR TESTING.

    " ── 헬퍼 ──
    METHODS given_order
      IMPORTING iv_uuid TYPE sysuuid_x16 iv_customer TYPE zat_cih_soh-customer_id
                iv_amount TYPE zat_cih_soh-total_amount iv_status TYPE zat_cih_soh-overall_status DEFAULT 'O'.
    METHODS given_limit
      IMPORTING iv_customer TYPE zat_cih_crlim-customer_id iv_limit TYPE zat_cih_crlim-credit_limit.
    METHODS when_accept
      IMPORTING iv_uuid TYPE sysuuid_x16.
    METHODS first_message RETURNING VALUE(rv) TYPE string.
ENDCLASS.

CLASS ltc_accept_order IMPLEMENTATION.

  METHOD class_setup.
    CREATE OBJECT mo_cut FOR TESTING.     " RAP 핸들러는 NEW 불가, 이 방법으로만 생성
    go_cds = cl_cds_test_environment=>create( i_for_entity = 'ZR_CIH_SALESORDER' ).
    go_sql = cl_osql_test_environment=>create( i_dependency_list = VALUE #( ( 'ZAT_CIH_SOH' ) ( 'ZAT_CIH_CRLIM' ) ) ).
  ENDMETHOD.

  METHOD class_teardown.
    go_cds->destroy( ).
    go_sql->destroy( ).
  ENDMETHOD.

  METHOD setup.
    go_cds->clear_doubles( ).
    go_sql->clear_doubles( ).
    CLEAR: ms_result, ms_mapped, ms_failed, ms_reported.
  ENDMETHOD.

  METHOD teardown.
    ROLLBACK ENTITIES.                    " 핸들러가 바꾼 트랜잭션 버퍼 버리기
  ENDMETHOD.


  METHOD accept_within_limit.
    given_order( iv_uuid = '000000000000000000000000000000A1' iv_customer = 'TC1' iv_amount = '60.00' ).
    given_limit( iv_customer = 'TC1' iv_limit = '100.00' ).

    when_accept( '000000000000000000000000000000A1' ).

    cl_abap_unit_assert=>assert_initial( act = ms_failed-salesorder msg = 'failed 가 비어 있어야 함' ).
    cl_abap_unit_assert=>assert_equals( act = lines( ms_result ) exp = 1 ).
    cl_abap_unit_assert=>assert_equals( act = ms_result[ 1 ]-%param-OverallStatus exp = 'A' ).
  ENDMETHOD.

  METHOD reject_over_limit.
    given_order( iv_uuid = '000000000000000000000000000000A2' iv_customer = 'TC2' iv_amount = '60.00' ).
    given_limit( iv_customer = 'TC2' iv_limit = '50.00' ).

    when_accept( '000000000000000000000000000000A2' ).

    cl_abap_unit_assert=>assert_not_initial( act = ms_failed-salesorder msg = '거부되어야 함' ).
    cl_abap_unit_assert=>assert_initial( act = ms_result ).
    cl_abap_unit_assert=>assert_char_cp( act = first_message( ) exp = '한도초과*' ).
  ENDMETHOD.

  METHOD reject_with_open_amount.
    given_order( iv_uuid = '000000000000000000000000000000A3' iv_customer = 'TC3' iv_amount = '60.00' ).
    given_order( iv_uuid = '000000000000000000000000000000A4' iv_customer = 'TC3' iv_amount = '60.00' iv_status = 'A' ).
    given_limit( iv_customer = 'TC3' iv_limit = '100.00' ).        " 기승인 60 + 이번 60 > 100

    when_accept( '000000000000000000000000000000A3' ).

    cl_abap_unit_assert=>assert_not_initial( act = ms_failed-salesorder msg = '기승인 금액 포함 시 거부되어야 함' ).
  ENDMETHOD.

  METHOD reject_unknown_customer.
    given_order( iv_uuid = '000000000000000000000000000000A5' iv_customer = 'TC9' iv_amount = '60.00' ).

    when_accept( '000000000000000000000000000000A5' ).

    cl_abap_unit_assert=>assert_not_initial( act = ms_failed-salesorder ).
    cl_abap_unit_assert=>assert_char_cp( act = first_message( ) exp = '*TC9*' ).
  ENDMETHOD.


  METHOD given_order.
    DATA lt_order TYPE STANDARD TABLE OF zat_cih_soh WITH EMPTY KEY.
    lt_order = VALUE #( ( sales_order_uuid = iv_uuid customer_id = iv_customer overall_status = iv_status
                          total_amount = iv_amount currency_code = 'KRW' ) ).
    go_cds->insert_test_data( lt_order ).   " 핸들러의 READ ENTITIES 용
    go_sql->insert_test_data( lt_order ).   " 신용한도 클래스의 SELECT 용
  ENDMETHOD.

  METHOD given_limit.
    DATA lt_limit TYPE STANDARD TABLE OF zat_cih_crlim WITH EMPTY KEY.
    lt_limit = VALUE #( ( customer_id = iv_customer credit_limit = iv_limit currency_code = 'KRW' ) ).
    go_sql->insert_test_data( lt_limit ).
  ENDMETHOD.

  METHOD when_accept.
    mo_cut->acceptorder( EXPORTING keys     = VALUE tt_keys( ( %tky-%is_draft = if_abap_behv=>mk-off
                                                               %tky-SalesOrderUUID = iv_uuid ) )
                         CHANGING  result   = ms_result
                                   mapped   = ms_mapped
                                   failed   = ms_failed
                                   reported = ms_reported ).
  ENDMETHOD.

  METHOD first_message.
    LOOP AT ms_reported-salesorder INTO DATA(r) WHERE %msg IS BOUND.
      rv = r-%msg->if_message~get_text( ).
      RETURN.
    ENDLOOP.
  ENDMETHOD.

ENDCLASS.
```

### 7.4 방식 A' 코드 — 규칙 클래스 + 가짜 부품 주입
```abap
"! 신용한도 체크 - 쓰는 쪽(RAP, 배치, 리포트)은 이 인터페이스만 안다
INTERFACE zif_cih_credit_check PUBLIC.
  TYPES ty_customer TYPE c LENGTH 10.
  TYPES ty_amount   TYPE p LENGTH 8 DECIMALS 2.   " abap.curr(15,2) 와 같은 기술 타입
  TYPES ty_currency TYPE c LENGTH 5.

  "! 한도를 넘으면 zcx_cih_credit_exceeded, 한도 미등록 고객이면 zcx_cih_customer_unknown
  METHODS check
    IMPORTING iv_customer TYPE ty_customer
              iv_amount   TYPE ty_amount
              iv_currency TYPE ty_currency
    RAISING   zcx_cih_credit.
ENDINTERFACE.

"! 신용한도 체크에 필요한 데이터 조회 - DB 를 직접 보지 않게 떼어낸 부분
INTERFACE zif_cih_credit_data PUBLIC.
  METHODS get_limit
    IMPORTING iv_customer     TYPE zif_cih_credit_check=>ty_customer
    RETURNING VALUE(rv_limit) TYPE zif_cih_credit_check=>ty_amount
    RAISING   zcx_cih_customer_unknown.

  "! 이미 승인(A)된 오더 금액 합계
  METHODS get_open_amount
    IMPORTING iv_customer    TYPE zif_cih_credit_check=>ty_customer
    RETURNING VALUE(rv_open) TYPE zif_cih_credit_check=>ty_amount.
ENDINTERFACE.
```
```abap
"! 신용한도 체크 본체 - NEW 금지, create( ) 로만 생성
CLASS zcl_cih_credit_check DEFINITION PUBLIC FINAL CREATE PRIVATE.
  PUBLIC SECTION.
    INTERFACES zif_cih_credit_check.

    "! 운영용: 진짜 DB 조회 부품을 넣어서 만든다
    CLASS-METHODS create
      RETURNING VALUE(ro_check) TYPE REF TO zif_cih_credit_check.

    "! 테스트용: 데이터 조회 부품을 밖에서 넣는다
    CLASS-METHODS create_with
      IMPORTING io_data         TYPE REF TO zif_cih_credit_data
      RETURNING VALUE(ro_check) TYPE REF TO zif_cih_credit_check.

    METHODS constructor
      IMPORTING io_data TYPE REF TO zif_cih_credit_data.

  PRIVATE SECTION.
    DATA mo_data TYPE REF TO zif_cih_credit_data.
ENDCLASS.

CLASS zcl_cih_credit_check IMPLEMENTATION.
  METHOD create.
    ro_check = NEW zcl_cih_credit_check( io_data = NEW zcl_cih_credit_data_db( ) ).
  ENDMETHOD.

  METHOD create_with.
    ro_check = NEW zcl_cih_credit_check( io_data = io_data ).
  ENDMETHOD.

  METHOD constructor.
    mo_data = io_data.
  ENDMETHOD.

  METHOD zif_cih_credit_check~check.
    DATA(lv_limit) = mo_data->get_limit( iv_customer ).
    DATA(lv_open)  = mo_data->get_open_amount( iv_customer ).

    IF lv_open + iv_amount > lv_limit.
      RAISE EXCEPTION NEW zcx_cih_credit_exceeded( customer     = iv_customer
                                                   credit_limit = lv_limit
                                                   open_amount  = lv_open
                                                   order_amount = iv_amount
                                                   currency     = iv_currency ).
    ENDIF.
  ENDMETHOD.
ENDCLASS.
```
Test Classes (`zcl_cih_credit_check.clas.testclasses.abap`):
```abap
"! 가짜 데이터 부품: DB 대신 테스트가 정한 값을 돌려준다
CLASS ltd_credit_data DEFINITION FINAL FOR TESTING.
  PUBLIC SECTION.
    INTERFACES zif_cih_credit_data.
    DATA mv_limit TYPE zif_cih_credit_check=>ty_amount.
    DATA mv_open  TYPE zif_cih_credit_check=>ty_amount.
    DATA mv_known TYPE abap_bool VALUE abap_true.
ENDCLASS.

CLASS ltd_credit_data IMPLEMENTATION.
  METHOD zif_cih_credit_data~get_limit.
    IF mv_known = abap_false.
      RAISE EXCEPTION NEW zcx_cih_customer_unknown( customer = iv_customer ).
    ENDIF.
    rv_limit = mv_limit.
  ENDMETHOD.

  METHOD zif_cih_credit_data~get_open_amount.
    rv_open = mv_open.
  ENDMETHOD.
ENDCLASS.


CLASS ltc_credit_check DEFINITION FINAL FOR TESTING DURATION SHORT RISK LEVEL HARMLESS.
  PRIVATE SECTION.
    DATA mo_data  TYPE REF TO ltd_credit_data.
    DATA mo_check TYPE REF TO zif_cih_credit_check.

    METHODS setup.
    METHODS within_limit_passes     FOR TESTING RAISING cx_static_check.
    METHODS exact_limit_passes      FOR TESTING RAISING cx_static_check.
    METHODS over_limit_raises       FOR TESTING.
    METHODS unknown_customer_raises FOR TESTING.
ENDCLASS.

CLASS ltc_credit_check IMPLEMENTATION.
  METHOD setup.
    mo_data = NEW ltd_credit_data( ).
    mo_data->mv_limit = 1000.
    mo_data->mv_open  = 700.
    mo_check = zcl_cih_credit_check=>create_with( mo_data ).    " ← 가짜 부품 주입
  ENDMETHOD.

  METHOD within_limit_passes.
    mo_check->check( iv_customer = 'C1' iv_amount = 200 iv_currency = 'EUR' ).   " 700 + 200 <= 1000
  ENDMETHOD.

  METHOD exact_limit_passes.
    mo_check->check( iv_customer = 'C1' iv_amount = 300 iv_currency = 'EUR' ).   " 700 + 300 = 1000
  ENDMETHOD.

  METHOD over_limit_raises.
    TRY.
        mo_check->check( iv_customer = 'C1' iv_amount = 301 iv_currency = 'EUR' ).
        cl_abap_unit_assert=>fail( '한도 초과인데 예외가 나지 않음' ).
      CATCH zcx_cih_credit_exceeded INTO DATA(lx).
        cl_abap_unit_assert=>assert_equals( act = lx->open_amount  exp = 700 ).
        cl_abap_unit_assert=>assert_equals( act = lx->order_amount exp = 301 ).
      CATCH zcx_cih_credit.
        cl_abap_unit_assert=>fail( '다른 종류의 예외' ).
    ENDTRY.
  ENDMETHOD.

  METHOD unknown_customer_raises.
    mo_data->mv_known = abap_false.
    TRY.
        mo_check->check( iv_customer = 'C9' iv_amount = 1 iv_currency = 'EUR' ).
        cl_abap_unit_assert=>fail( '미등록 고객인데 예외가 나지 않음' ).
      CATCH zcx_cih_customer_unknown INTO DATA(lx).
        cl_abap_unit_assert=>assert_equals( act = lx->customer exp = 'C9' ).
      CATCH zcx_cih_credit.
        cl_abap_unit_assert=>fail( '다른 종류의 예외' ).
    ENDTRY.
  ENDMETHOD.
ENDCLASS.
```
예외 가족: `ZCX_CIH_CREDIT`(abstract, `CX_STATIC_CHECK`) ← `ZCX_CIH_CREDIT_EXCEEDED`, `ZCX_CIH_CUSTOMER_UNKNOWN` (`if_message~get_text` 재정의). DB 구현 `ZCL_CIH_CREDIT_DATA_DB`, 한도 테이블 `ZAT_CIH_CRLIM`, 시연 `ZCL_CIH_CREDIT_DEMO`(if_oo_adt_classrun) — 소스는 `ABAP/ZCIH_SO_BO/`.

### 7.5 fixture 4개를 모두 쓰는 예 — DB 조회 클래스
```abap
"! ZCL_CIH_CREDIT_DATA_DB 테스트 - fixture 메서드 4개(class_setup / setup / teardown / class_teardown)를 모두 사용하는 데모
"! 진짜 테이블 대신 CL_OSQL_TEST_ENVIRONMENT 가 만든 가짜 테이블에 SELECT 하게 한다.
CLASS ltc_credit_data_db DEFINITION FINAL FOR TESTING DURATION SHORT RISK LEVEL HARMLESS.
  PRIVATE SECTION.
    CLASS-DATA go_env   TYPE REF TO if_osql_test_environment.  " 클래스 전체가 같이 쓰는 가짜 DB 환경
    CLASS-DATA gt_trace TYPE string_table.                     " fixture 호출 기록 (데모용)

    DATA mo_cut TYPE REF TO zif_cih_credit_data.                " 테스트 대상 (Code Under Test)

    " ── fixture: 이름이 정해져 있고 PRIVATE, FOR TESTING 을 붙이지 않는다 ──
    CLASS-METHODS class_setup.       " 모든 테스트 전에 1번
    CLASS-METHODS class_teardown.    " 모든 테스트 후에 1번
    METHODS setup.                   " 테스트 메서드마다 실행 전
    METHODS teardown.                " 테스트 메서드마다 실행 후

    " ── 테스트 메서드 ──
    METHODS limit_of_registered_customer FOR TESTING RAISING cx_static_check.
    METHODS unknown_customer_raises      FOR TESTING.
    METHODS open_sums_only_accepted      FOR TESTING.
    METHODS open_is_zero_without_orders  FOR TESTING.
    METHODS fixture_order                FOR TESTING.
ENDCLASS.

CLASS ltc_credit_data_db IMPLEMENTATION.

  METHOD class_setup.
    " 비용이 큰 준비는 한 번만: 두 테이블의 가짜(double)를 만들고, 이후 SELECT 를 가짜로 돌린다
    go_env = cl_osql_test_environment=>create( i_dependency_list = VALUE #( ( 'ZAT_CIH_CRLIM' ) ( 'ZAT_CIH_SOH' ) ) ).
    APPEND `CLASS_SETUP` TO gt_trace.
  ENDMETHOD.

  METHOD class_teardown.
    " 가짜 환경 해제 → 이후 SELECT 는 다시 진짜 테이블로
    go_env->destroy( ).
  ENDMETHOD.

  METHOD setup.
    " 테스트마다 같은 출발점: 테스트 데이터 넣고, 테스트 대상 새로 만들기
    DATA lt_limit TYPE STANDARD TABLE OF zat_cih_crlim WITH EMPTY KEY.
    DATA lt_order TYPE STANDARD TABLE OF zat_cih_soh   WITH EMPTY KEY.
    lt_limit = VALUE #( ( customer_id = 'C1' credit_limit = '100.00' currency_code = 'KRW' ) ).
    lt_order = VALUE #( ( sales_order_uuid = '01' customer_id = 'C1' overall_status = 'A' total_amount = '10.00' )
                        ( sales_order_uuid = '02' customer_id = 'C1' overall_status = 'A' total_amount = '20.00' )
                        ( sales_order_uuid = '03' customer_id = 'C1' overall_status = 'O' total_amount = '40.00' )   " 미승인 → 제외
                        ( sales_order_uuid = '04' customer_id = 'C1' overall_status = 'X' total_amount = '80.00' )   " 거절 → 제외
                        ( sales_order_uuid = '05' customer_id = 'C2' overall_status = 'A' total_amount = '99.00' ) ). " 다른 고객 → 제외
    go_env->insert_test_data( i_data = lt_limit ).
    go_env->insert_test_data( i_data = lt_order ).

    mo_cut = NEW zcl_cih_credit_data_db( ).
    APPEND `SETUP` TO gt_trace.
  ENDMETHOD.

  METHOD teardown.
    " 테스트마다 뒷정리: 가짜 테이블을 비워서 다음 테스트에 데이터가 남지 않게
    go_env->clear_doubles( ).
    CLEAR mo_cut.
    APPEND `TEARDOWN` TO gt_trace.
  ENDMETHOD.


  METHOD limit_of_registered_customer.
    cl_abap_unit_assert=>assert_equals( act = mo_cut->get_limit( 'C1' ) exp = '100.00' ).
  ENDMETHOD.

  METHOD unknown_customer_raises.
    TRY.
        mo_cut->get_limit( 'C9' ).
        cl_abap_unit_assert=>fail( '미등록 고객인데 예외가 나지 않음' ).
      CATCH zcx_cih_customer_unknown INTO DATA(lx).
        cl_abap_unit_assert=>assert_equals( act = lx->customer exp = 'C9' ).
    ENDTRY.
  ENDMETHOD.

  METHOD open_sums_only_accepted.
    " C1 의 승인(A) 오더만: 10 + 20 = 30
    cl_abap_unit_assert=>assert_equals( act = mo_cut->get_open_amount( 'C1' ) exp = '30.00' ).
  ENDMETHOD.

  METHOD open_is_zero_without_orders.
    cl_abap_unit_assert=>assert_equals( act = mo_cut->get_open_amount( 'C3' ) exp = 0 ).
  ENDMETHOD.

  METHOD fixture_order.
    " 테스트 순서는 보장되지 않지만, 어느 테스트에서 봐도 항상 성립하는 것:
    "  - 맨 처음은 CLASS_SETUP (1번만)
    "  - 맨 끝은 방금 실행된 SETUP (지금 이 테스트 직전)
    "  - SETUP 은 TEARDOWN 보다 정확히 1번 더 많다 (지금 테스트의 TEARDOWN 은 아직 안 불림)
    cl_abap_unit_assert=>assert_equals( act = gt_trace[ 1 ] exp = `CLASS_SETUP` ).
    cl_abap_unit_assert=>assert_equals( act = gt_trace[ lines( gt_trace ) ] exp = `SETUP` ).
    DATA(lv_setup)    = REDUCE i( INIT n = 0 FOR t IN gt_trace WHERE ( table_line = `SETUP` )    NEXT n = n + 1 ).
    DATA(lv_teardown) = REDUCE i( INIT n = 0 FOR t IN gt_trace WHERE ( table_line = `TEARDOWN` ) NEXT n = n + 1 ).
    DATA(lv_cls)      = REDUCE i( INIT n = 0 FOR t IN gt_trace WHERE ( table_line = `CLASS_SETUP` ) NEXT n = n + 1 ).
    cl_abap_unit_assert=>assert_equals( act = lv_setup - lv_teardown exp = 1 ).
    cl_abap_unit_assert=>assert_equals( act = lv_cls exp = 1 ).
  ENDMETHOD.

ENDCLASS.
```
- `class_setup`: OSQL double 생성(비싼 작업 1회) / `setup`: 테스트 데이터 + 대상 객체 / `teardown`: `clear_doubles` / `class_teardown`: `destroy`.
- `fixture_order` 는 순서가 보장되지 않는 테스트 실행에서도 항상 성립하는 것만 검증.

### 7.6 실습 중 발견한 것
- EML 로 KRW 금액을 넣을 때는 **외부 금액**(`UnitPrice = '3000.00'` = 3,000 KRW)으로 넣는다. DB·`READ ENTITIES` 값은 내부값(`30.00`)으로 서로 일치.
  (처음 `'30.00'` 으로 넣어 30 KRW 가 되어 한도 시연이 어긋났었음)
- `new_message_with_text` 텍스트는 **50자**에서 잘린다 → 예외 메시지를 짧게 바꿈. 운영에서는 T100 메시지 클래스 권장.
- 같은 시스템 객체를 여러 세션이 PUT 하면 덮어쓴다 → PUT 직전 시스템 소스와 비교 (`docs/adt-object-deploy.md` 2절).

