# 02. Interaction Phase (MODIFY 처리)

## 진입: `CL_ABAP_BEHV_CTRL=>EXECUTE_MODIFY` ✅

1. `failed/mapped/reported` 가 요청됐으면 비우고 `cl_abap_behv_log=>create_for_eml` 로 응답 로그 생성
2. interface BDEF(I_*) 로 호출됐으면 base BO 로 연결 (`roots_modified` 에 orig/real 기록 → COMMIT 시 응답 매핑에 사용)
3. `eml_processor->modify( job )` → `CL_RAP_BHV_PROCESSOR`
4. `cl_abap_behv_transaction_ctrl=>start( internal )` → 이 LUW 는 RAP 소유가 됨

projection 핸들러 실행 중(`curr_proj_hdlr`)이면 직접 실행하지 않고 `add_augment_activities` 로 base 요청에 합류시킨다 (augment).

## 처리 순서: `CL_RAP_BHV_PROCESSOR->if_rap_eml_processor~modify` ✅ (~L440)

| # | 코드 | 의미 |
|---|---|---|
| 0 | `if_rap_legacy_transaction~check_is_not_aborted` | 이미 중단된 트랜잭션이면 거부 |
| 1 | `cl_rap_bhv_modification_set=>get( cid_registry, lock_registry, activities )` | 요청을 activity 집합으로. `%cid` 레지스트리(`cl_rap_bhv_cid_registry`), 동시성 제어(`cl_rap_bhv_concurrency_control`) |
| 2 | `eml_global_permission_checks` | **global authorization** |
| 3 | `register_locks_and_cid_refs` | 락 대상·cid 참조 등록 |
| 4 | `execute_locking` | **lock** — `io_job->m_draft_activate` 이면 생략 (activate 중 중복 락 방지) |
| 5 | `cl_abap_behv_ctrl=>call_precheckers` | **precheck** — draft activate 중 생략 |
| 6 | `eml_instance_permission_checks` | **instance authorization** (+ feature control 관련은 별도 `feature_check`) |
| 7 | `call_handlers_modify( lo_job )` | 실제 create/update/delete/action 핸들러 |

- 각 단계 실패 인스턴스는 `lo_failure_reduction` 으로 걸러져 다음 단계(특히 핸들러)로 가지 않는다. 로그는 `cl_rap_bhv_log_factory=>eml_precheck_wrapper / eml_modify_wrapper` 로 감싸짐.
- 이 단계에서는 **DB 에 쓰지 않는다.** 모든 변경은 트랜잭션 버퍼(managed: 프레임워크 버퍼, unmanaged: 앱 버퍼)에만.

## Determination on modify ✅

- 트리거 수집: 버퍼 변경 시 `cl_abap_behv_detval=>add_change_notification_tab` → 로컬 구현이 `pending_det_on_mod_instances` 에 (entity, determination, instances) 적재.
- 실행: `CL_ABAP_BEHV_CTRL=>CALL_HANDLER` 끝(~L2206)
  ```abap
  if handler->kind eq 'M' and cl_abap_behv_job_base=>content_active eq job->m_content.
    cl_abap_behv_detval=>exec_determinations_on_modify( root_entity_name = root  log = job->log  for_unmanaged = 'X' ).
  ```
  → `CL_ABAP_BEHV_DETVAL` 로컬 `if_abap_behv_detval~exec_determinations_on_modify` 가 pending 을 정렬·중복제거 후 djob 으로 일괄 실행.
- ⚠️ managed BO 에서 on-modify determination 이 정확히 어느 호출점에서 트리거되는지는 미확인 (위 호출은 `for_unmanaged = 'X'` 라 unmanaged 대상). managed 버퍼(CSP) 쪽 호출점을 찾아야 함 → 05 참조.
- 안전장치 (DETVAL 로컬 구현의 dump kind):
  - validation 실행 중 MODIFY → `modify_in_validation`
  - BO 간 determination 순환 → `cross_bo_modify_cycle_in_det` (`bo_stack->push` 가 `lcx_duplicative_bo`)
  - 깊이 초과 → `endless_on_modify` (`lcx_depth_exceeded`)

## 트랜잭션 제어 ✅ `CL_ABAP_BEHV_TRANSACTION_CTRL`

- MODIFY 후 `start` → 이후 애플리케이션이 `COMMIT WORK` 를 직접 하면 이벤트 `COMMIT_REQUESTED` → `CALL_SAVE` 가 `eml_processor->save_without_commit` 으로 세이브 시퀀스 실행.
- 그 세이브가 실패하면 `raise shortdump CX_ABAP_BEHV_COMMIT_FAILED` (소스 주석: FAILED 가 CHECK_BEFORE_SAVE/FINALIZE/ADJUST_NUMBERS/SAVE/SAVE_MODIFIED 에서 채워진 경우).
- EML `COMMIT ENTITIES` 중에는 `pause` → 끝나면 성공 시 `stop`, 실패/simulate 시 `resume` (03 참조).

## 우리 BO 매핑 예 (ZR_CIH_SalesOrder)

`setInitialValues`, `setItemDefaults`, `calcNetAmount`(+ 내부 액션 `recalcTotalAmount`) 가 이 단계에서 실행.
