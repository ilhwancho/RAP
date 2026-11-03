# 03. Save Sequence (COMMIT)

## 진입 경로 ✅

- EML: `COMMIT ENTITIES` → `CL_ABAP_BEHV_CTRL=>EXECUTE_COMMIT` → `cl_abap_behv_transaction_ctrl=>pause( )` → `eml_processor->save( )` (simulate 면 `simulate_save`)
  → `CL_RAP_TRANSACTION_MANAGER->_save` → `_process_save_sequence`
- OData changeset: `CL_RAP_TRANSACTION_MANAGER->if_sadl_changeset~modify` 안에서 바로 `_save` (04 참조)
- 외부 `COMMIT WORK`: `CL_ABAP_BEHV_TRANSACTION_CTRL=>CALL_SAVE` → `save_without_commit` (exit mode `before_commit`: COMMIT WORK 는 호출자가 이미 하는 중이므로 생략)

## 핵심: `CL_RAP_TRANSACTION_MANAGER->_process_save_sequence` ✅ (~L702)

```
(ai = 레거시 BOPF 트랜잭션, bhv = RAP)
1. ai->finalize            → bhv->finalize( reporter )          실패 가능
2. ai->check_before_save   → bhv->check_before_save( reporter ) 실패 가능 (+ strict mode 평가)
   실패 또는 simulate(at_point_of_no_return):
       cleanup_finalization (ai, bhv) → RAP_RUNTIME_RECALL_WATCHDOG → RETURN    ← 버퍼는 유지
   ═══════════ POINT OF NO RETURN (소스 주석 그대로) ═══════════
3. SET UPDATE TASK LOCAL  (실패 시 __after_set_upd_task_local: 너무 일찍 등록된 update FM 감지 → ASSERT)
   io_reporter->switch_failure_mode( forbidden )   ← 이후 failed 는 "late failure"
4. adjust_numbers (ai, bhv)   — late numbering
5. save (ai, bhv)
6. legacy 트랜잭션이 늦게 abort 했으면: before_commit 모드면 _cleanup(+덤프 예정), 아니면 _discard_changes. RETURN
7. cl_rap_state_message_handler=>get_instance( )->save( )   — state message 영속화
8. CALL FUNCTION 'RAP_RUNTIME_UPDATE_DUMMY' IN UPDATE TASK
9. before_commit 모드면 RETURN, 아니면 COMMIT WORK (로컬 update task 실패 시 COMMIT WORK AND WAIT)
```
`_save` 는 전후로 watchdog 등록/해제, 성공 시 `_cleanup( )` (cleanup phase).

## bhv 단계 → 세이버 호출 ✅

`CL_RAP_BHV_PROCESSOR->if_rap_transaction_processor~finalize / check_before_save / adjust_numbers / save / cleanup`
→ `_execute_save_phase( iv_phase )` → `CL_ABAP_BEHV_CTRL=>CALL_COLLECTED_SAVERS( phase, log )`

`CALL_COLLECTED_SAVERS` (~L1308):
- 이번 LUW 에서 수집된 세이버(`saver_collector->savers`) 를 정리: projection 세이버가 base 세이버를 감싸면 base 직접 호출을 제거(중복 방지), managed 의 sub saver(앱 unmanaged save 등) 정리 → `preprocess_savers`.
- 수정 접근(`acc_modify`)이 없는 세이버는 CLEANUP 외 단계에서 건너뜀.
- **FINALIZE 는 반복**: 어떤 세이버의 finalize 가 실제 구현돼 있으면 `repeat = 'X'` → 다른 BO 세이버를 다시 호출 (finalize 안의 MODIFY 가 다른 BO 를 바꿀 수 있어서).
- **SAVE 는 필수**: 구현 없는 root 는 `unhandled_roots` → `cx_rap_handler_not_implemented`.
- 단계 후처리: finalize → `cl_abap_behv_detval=>check_finalize_is_complete`, cleanup_finalize → `detval=>cleanup_finalize`, cleanup → `cleanup_krn`(커널) + `detval=>cleanup` + `reset_singletons`.

## Managed BO: determination/validation 은 세이버 단계에서 ✅

`CL_ABAP_BEHV_SAVER_MNGD_CSP` 의 부모 **`CL_ABAP_BEHV_SAVER_DVM`**:
```abap
method finalize.            " determination on save
  cl_abap_behv_detval=>exec_determinations_on_save( root_entity_name = m_root log = log ).
  assert log->failed_entities is initial.      " determination 은 실패(failed) 할 수 없다
method check_before_save.   " validation
  cl_abap_behv_detval=>exec_validations_on_save( root_entity_name = m_root log = log ).
```
- 실제 DB 쓰기·late numbering 은 `CL_ABAP_BEHV_SAVER_MNGD_CSP` → `cl_csp_behv_handler_factory=>get_handler_for_save` 의 프레임워크 세이버. 앱에 unmanaged save(`with unmanaged save`/`additional save`)가 있으면 sub saver 의 `save_modified` 를 호출 (`CALL_SAVE_MODIFIED`).
- draft: `CL_ABAP_BEHV_SAVER_MNGD_DSP` → `CL_DSP_BEHV_HANDLER_FACTORY=>GET_HANDLER_FOR_SAVE`.

### DVM 세부 (`CL_ABAP_BEHV_DETVAL` 로컬 구현) ✅
- `exec_determinations_on_save`: BO load 에서 `kind 'D' / exec_type 'S'` determination 목록 → 구현 클래스별 그룹 → `buffer->get_instances( last_t = exec_t )` 로 **지난 실행 이후 변경된 인스턴스만** 대상 → `do..enddo` 로 버퍼 변화가 없을 때까지 반복. 실행 횟수가 `max_det_on_save_exec_count` 초과 시 `endless_on_save` 덤프.
- draft 전용(`flag_draft_only`) determination/validation 은 active 세이브에서 제외.
- activate optimized (`draft action Activate optimized`) 이면 `detact_buffer->filter_instances` 로 이미 Prepare 에서 처리된 인스턴스를 걸러 재실행 방지.
- `exec_validations`: `kind 'V'` 전부 `exec_type 'S'` (validation 은 on save 만). 실행 중 `val_active = abap_true` → MODIFY 시 덤프.

## COMMIT ENTITIES 결과 ✅ (`EXECUTE_COMMIT`)
- `rc = 0` 성공, `rc = 4` early failure(finalize/check_before_save), `rc = 8` late failure(point of no return 이후).
- 실패 시 `transaction_ctrl=>resume( )` — **버퍼는 남는다** → 앱이 `ROLLBACK ENTITIES` 하거나 수정 후 재COMMIT. (OData 는 자동 discard, 04 참조)
- interface BDEF 로 요청한 응답은 `CL_ABAP_BEHV_SAVER_PROJ=>TRANSFER_RESP_TO_PROJ_LOG` 로 base → interface 매핑.
- `COMMIT ENTITIES BEGIN ... END` (scope 'E') 는 `close_save` 만.

## 우리 BO 매핑 예
`setSalesOrderID` = finalize, `validateCustomer/validateDates/validateQuantity` = check_before_save.
