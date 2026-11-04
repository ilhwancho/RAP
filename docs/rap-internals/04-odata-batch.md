# 04. OData V4 `$batch` / changeset 처리 (Gateway → SADL → RAP)

## 흐름

### ① Gateway `/IWBEP` ⚠️ (소스 비공개, ADT 404)
- `$batch` 를 changeset 단위와 changeset 밖 개별 요청(GET 등)으로 분해.
- changeset 마다 DPC 의 `/iwbep/if_v4_dp_batch~process_change_set( io_request, io_response )` 호출,
  batch 전체는 `/iwbep/if_v4_dp_batch~process_batch` (SADL 어댑터가 redefine 후 super 호출).

### ② `CL_SADL_GW_V4_DPC_ADAPTER` ✅
- `process_batch`: `io_request->get_todos` 로 JSON batch 의존성(`ids_of_prerequisites`) 확인, `_batch_check_state_relev_ops` 후 `super->process_batch`.
- `process_change_set` (~L1876):
  1. `_prepare_change_set` → changeset 내 모든 operation 을 **종류별로 분리**: `ls_change_set-create / update / delete / action` (+ deep create, bulk action, operation dependency)
  2. sticky discard 면 `_sticky_call_badi_for_discard` 만
  3. bulk action 이면 `mo_dpc->execute_bulk_action`
  4. 아니면 **`mo_dpc->process_change_set(...)` 1회 호출**
  5. `_post_process_change_set` (응답 구성)
  6. 성공 + idempotency 요청이면 `io_response->save_for_idempotency( )` 후 `COMMIT WORK` 한 번 더

### ③ `CL_SADL_GW_V4_GENERIC_DPC->if_sadl_gw_v4_generic_dpc~process_change_set` ✅ (~L793)
- update: `_check_up_nav_path_and_add_src` (내비게이션 경로 update 가 사실상 create 면 implicit create 로 전환), `SAP__Messages` 요청 여부 플래그, `_reject_hidden_elements`
- create: `_check_cr_nav_path_and_add_src` (예: `SalesOrder(...)/_Item` POST → create-by-association)
- delete/action: nav path 해석, action 의 requested elements 계산
- **`lo_changeset->modify( it_create, it_update, it_delete, it_action, iv_is_sticky_session, iv_strict_handling_requested, it_operation_dependency )` 1회**
- 실패: `_get_and_clear_messages` (transition + state messages)
- 성공: `_postprocess_changeset` → `CL_SADL_GW_DPC_BATCH->register_entity_for_read / read_modified_entities` 로 변경 엔티티 재조회, 메시지 매핑

### ④ `CL_RAP_TRANSACTION_MANAGER->if_sadl_changeset~modify` ✅ (~L185)
```abap
RAISE EVENT before_modify_sadl ...
_prepare_operations( ... )        " RAP(bhv) 와 레거시 BOPF(ai) 요청 분리
" (JSON batch 의존성이 있는데 ai 요청이 섞이면 cx_rap_non_rap_dependency)
mo_ai_changeset->modify( ... )    " ai 요청이 있으면
mo_bhv_transaction_processor->modify( ... it_operation_dependency ... )   " = 02 의 interaction phase 와 같은 처리
IF ev_failed = abap_false AND ( 비sticky OR sticky save 액션 ).
  _save( ... )                    " = 03 의 세이브 시퀀스 전체 + COMMIT WORK
ENDIF.
IF ev_failed = abap_true AND 비sticky.
  discard_changes( )              " 버퍼 전부 폐기 (자동 롤백)
ENDIF.
lo_changeset_smsgs->handle_state_messages( ... )
```

## 결론 ✅
- **changeset 1개 = modify 1회 + 세이브 시퀀스 1회 = LUW 1개**, all-or-nothing.
- changeset 여러 개 → 각각 독립 LUW. 뒤 changeset 실패가 앞서 커밋된 changeset 을 되돌리지 않음.
- changeset 안 operation 은 요청 순서대로 1건씩이 아니라 **종류별로 묶여 한 번에** 처리. content-ID(`$1`) 참조는 cid registry / `it_operation_dependency` 로 연결.
- 실패 처리 차이: EML `COMMIT ENTITIES` 실패 → 버퍼 유지 / OData changeset 실패 → `discard_changes` 자동.
- sticky session(BOPF 레거시 draft 등): 세이브는 "sticky save" 액션일 때만, 실패해도 discard 안 함.

## Draft (Fiori Elements) ⚠️ 부분 확인
- 편집 중 PATCH 도 각각 changeset → modify + 세이브 시퀀스. 단 draft 인스턴스는 DSP 세이버(`CL_ABAP_BEHV_SAVER_MNGD_DSP`)가 draft 테이블에 기록.
- active 저장과 validation 은 `Prepare`(draft determine action) / `Activate` 액션 처리 시. BDEF `draft determine action Prepare { validation ... }` 가 `cl_abap_behv_detval=>exec_determine_action( is_draft = abap_true )` 로 연결되는 것으로 보임 (호출점 미확인).
- activate 시 락/프리체크/권한 일부 생략은 ✅ (`m_draft_activate`, 02 참조).

## 메시지
- 실패 시 `et_message` (transition), 성공 시 `SAP__Messages` 요청 엔티티에 state message 재조회 (`_postprocess_changeset`, `_upsert_elist_get_state_msgs`).

## 액션 파라미터 필수 처리 (abstract entity / abstract BDEF) ✅ (2026-11-04 실측, Web API 바인딩)
시험 객체: `ZD_CIH_SOActParam`(root abstract entity) + abstract BDEF(`with hierarchy`, `with control`, `field ( mandatory : execute ) Quantity`),
`ZR_CIH_SalesOrder` 의 `static action testFlatParam parameter ...` / `testDeepParam deep parameter ...`, 서비스 `ZAPI_CIH_SALESORDER_O4`.
- flat `parameter`: 컴파일 경고 "used as a flat type; its BDEF definition ("with hierarchy") is not used" → `mandatory : execute` 무시.
  `$metadata` 에 파라미터 어노테이션 없음 → Gateway 가 **모든 파라미터를 필수**로 취급 (하나라도 빠지면 400 `No value for mandatory parameter`).
- `deep parameter`: `$metadata` 에 `Quantity` = `SAP__common.FieldControl/Mandatory`, 나머지 = `SAP__core.OptionalParameter`.
  `Quantity` 생략 시 400 (`/IWCOR/CX_OD_EP_PARAM_ERROR`, RAP 핸들러 도달 전 Gateway 에서 거부), 나머지 생략은 204 (초기값으로 전달).
- 둘 다 **존재 여부만** 검사: `Quantity: 0` 은 통과. `null` 은 `Nullable=false` 라 400 (파싱 오류). 값 검증은 액션 구현에서 해야 함.
- OData 에서는 덤프가 아니라 400. (EML 에서 `%control` 미설정 시 런타임 오류는 키워드 문서 기준, 미실측)
