# 07. RAP BO 유닛 테스트 (ABAP Unit)

RAP BO 를 ABAP Unit 으로 테스트하는 방법. ABAP Cloud 키워드 문서(Z5U, 릴리스 920, `version=5`)와
시스템의 실제 테스트 클래스(`BP_DEMO_MANAGED_ROOT_2`, `CL_SD_BEHV_SALESORDER`)를 읽고 정리했다.

- 테스트 include 조회: `python tools/adt/adt_source.py get <클래스>` → `/tmp/adt_src/<클래스>.testclasses.abap`
- ⚠️ 이 문서의 `ZCIH_SO_BO` 적용 예시 코드는 아직 시스템에서 활성화/실행해 보지 않았다.

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
