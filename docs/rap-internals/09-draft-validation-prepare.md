# 09. draft 에서 validation 이 도는 시점과 Prepare

질문: draft PATCH 때는 왜 validation 이 안 도나? Prepare 는 정확히 무엇인가?
분석: 2026-11-09, `CL_ABAP_BEHV_SAVER_MNGD_DSP`, `CL_ABAP_BEHV_SAVER_DVM`, `CL_DSP_PRC_BEHV_CHECK_SAVE`, `CL_ABAP_BEHV_DETVAL`(로컬 구현), `CL_CSP_DVM_CTRL_FLAG_READER`, `CL_CSP_UTL_DFIELDCHANGES_CONV`.

## 1. draft PATCH 가 validation 을 건너뛰는 경로 ✅
draft PATCH 도 changeset 끝에서 세이브 시퀀스(finalize → check_before_save → save)를 탄다 (03 문서). 다만 **draft 인스턴스용 세이버는 DVM 을 부르지 않는다.**

```
세이버 클래스 계층
CL_ABAP_BEHAVIOR_SAVER
 └ CL_ABAP_BEHV_SAVER_MANAGED
    ├ CL_ABAP_BEHV_SAVER_DVM          ← finalize = exec_determinations_on_save
    │  └ CL_ABAP_BEHV_SAVER_MNGD_CSP     check_before_save = exec_validations_on_save
    │      (active 인스턴스)
    └ CL_ABAP_BEHV_SAVER_MNGD_DSP     ← DVM 을 상속하지 않음
       (draft 인스턴스)
```
- `CL_ABAP_BEHV_SAVER_MNGD_DSP->check_before_save` → `CL_DSP_BEHV_HANDLER_FACTORY=>GET_HANDLER_FOR_SAVE` → `CL_DSP_BEHV_HANDLER_FOR_SAVE` → `CL_DSP_PRC_BEHV_CHECK_SAVE` → activity `CL_DSP_ACT_DELEG_CHECK_B4_SAVE` → `io_delegator->check_before_save`
  → `DELEGATE_CHECK_BEFORE_SAVE` 는 앱의 additional/unmanaged sub saver 의 `check_before_save` 만 호출. **`exec_validations_on_save` 호출 없음.** `finalize` 도 같은 구조 (`exec_determinations_on_save` 없음).
- 이중 장치: active 세이버의 DVM 도 draft 변경은 제외한다. `CL_ABAP_BEHV_DETVAL` 로컬 `get_instances` → 커널 모듈 `ab_km_dvm_get_instances`.
  주석으로 남은 원래 ABAP 로직: `where_cond = 'T > LAST_T AND CHANGE-%IS_DRAFT IS INITIAL'` (⚠️ 커널 구현 자체는 비공개, 주석 기준).
- on **modify** determination 은 interaction phase 에서 돌기 때문에 draft PATCH 에서도 실행된다 (02 문서).

## 2. 그러면 트리거는 어떻게 기억하나 — `DRAFTFIELDCHANGES` ✅
OData 는 요청마다 세션이 새로 시작되므로(stateless) "DeliveryDate 가 바뀌었음" 이라는 트리거를 메모리에 둘 수 없다. 그래서 draft 테이블에 저장한다.
- draft 테이블 include `SYCH_BDL_DRAFT_ADMIN_INC`: `draftentitycreationdatetime`, `draftentitylastchangedatetime`, `draftadministrativedatauuid`, `draftentityoperationcode`(C/U…), `hasactiveentity`, **`draftfieldchanges`**.
- `CL_CSP_UTL_DFIELDCHANGES_CONV`: `control_to_draftfieldchanges` / `draftfieldchanges_to_control` — `%control` (필드별 변경 플래그) ↔ `draftfieldchanges` 변환.
- Prepare 때 `CL_ABAP_BEHV_DETVAL` 로컬 `get_instances_filtered( has_draft = X )` 가 버퍼에 없는 인스턴스는 `read_draft_persistency` → `CL_CSP_DVM_CTRL_FLAG_READER->get_persisted_draft_changes` (`CL_CSP_PRC_D_GET_PERSISTD_CHNG`) 로 **저장된 변경 이력을 읽어** 트리거를 평가한다.

실측 (Z5U, `ZDT_CIH_SOH` 데이터 미리보기, 앞부분 바이트 = 필드 순서대로 1바이트씩)
```
생성 직후          01 00 01 00 01 00 01 00 01 01 01 01 01 00 ...   (UUID, CustomerID, OrderDate, OverallStatus, CurrencyCode, admin 필드)
PATCH DeliveryDate 01 00 01 00 01 01 01 00 01 01 01 01 01 00 ...   ← 6번째(DeliveryDate) 00→01
PATCH Description  01 00 01 01 01 01 01 00 01 01 01 01 01 00 ...   ← 4번째(Description) 00→01
```
필드 순서: SalesOrderUUID, SalesOrderID, CustomerID, Description, OrderDate, DeliveryDate, OverallStatus, TotalAmount, CurrencyCode, LocalCreatedBy, LocalCreatedAt, LocalLastChangedBy, LocalLastChangedAt, LastChangedAt.
OverallStatus 가 생성 직후 01 인 것은 on modify determination `setInitialValues` 가 채웠기 때문. 뒤쪽 바이트(압축 데이터로 보임)는 ⚠️ 미해석.

## 3. Prepare 의 정체 ✅
- BDEF: `draft determine action Prepare { validation ...; determination ...; }` — **draft 인스턴스용 determine action**.
  키워드 문서: "executes the determinations and validations that are assigned to it … enables validating draft data before the transition to active data", on save 로 정의된 것만 지정 가능.
- 런타임: `CL_ABAP_BEHV_DETVAL=>EXEC_DETERMINE_ACTION( is_draft = 'X' )` (주석: "The only draft determine action is PREPARE") → 로컬 `if_abap_behv_detval~exec_determine_action`
  1. 세이브 중이거나 validation 실행 중이면 덤프 (`det_act_not_permitted`).
  2. 대상 draft 인스턴스를 읽음 (`get_existing_instances`, `%IS_DRAFT = X` 로 채움).
  3. 지정된 **determination** 을 버퍼 변화가 없을 때까지 반복 실행 (on save determination 과 같은 루프, 횟수 초과 시 `endless_on_save` 덤프). 그 사이 draft 변경을 `flush_pending_operations` 로 draft 테이블에 반영.
  4. 지정된 **validation** 을 실행. 대상은 `get_instances_filtered( last_t = 0, has_draft = X )` → 2절의 저장된 변경 이력까지 포함해 **트리거 조건(create, field …)을 만족한 인스턴스만**.
  5. `optimized` (Activate optimized) 면 `detact_buffer` 에 실행 기록 → Activate 안의 암시적 Prepare 에서 같은 인스턴스 재실행 생략.
- failed 는 Prepare 전용 로그(`cl_dsp_utl_behv_log_factory=>get( )->get_behv_prepare_log( )`)로 모음. 실측상 OData 응답은 validation 이 실패해도 204, 메시지는 state 메시지로 저장 (08 문서).
- Activate 는 Prepare 를 암시적으로 포함 (키워드 문서). Fiori 의 저장 버튼 = Activate.

## 4. 정리
| 시점 | on modify determination | on save determination / validation |
|---|---|---|
| draft CREATE/UPDATE(PATCH) | 실행 | **안 함** — 변경 플래그만 `draftfieldchanges` 에 누적 |
| Prepare | — | Prepare 에 지정된 것만, 누적된 트리거 기준으로 실행 |
| Activate | — | 암시적 Prepare + active 세이브 (optimized 면 중복 생략) |
| active 직접 수정 (draft 없이 EML/API) | 실행 | COMMIT 의 세이브 시퀀스에서 실행 (`CL_ABAP_BEHV_SAVER_DVM`) |

⚠️ 미확인: Prepare 에 지정하지 않은 validation 이 Activate 의 active 세이브에서 도는지, `draftfieldchanges` 가 Activate/Prepare 후 초기화되는 시점.
