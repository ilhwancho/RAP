# 05. 미분석 / 미확인 주제

해결하면 해당 문서에 반영하고 여기서 지운다.

## 미확인 (⚠️)
- [ ] managed BO 의 on-modify determination 호출점 (CSP 버퍼 쪽). 후보: `CL_CSP_BEHV_INTERACT_HANDLER`, `CL_CSP_BEHV_A_INTERACT_HANDLER`, `CL_ABAP_BEHV_HANDLER_MNGD_CSP`
- [ ] draft `Prepare` / `Activate` 내부 흐름: `exec_determine_action` 호출점, draft → active 복사, `CL_DSP_BEHV_HANDLER_MANAGED`, `CL_CSP_BEHV_DRAFT_SERVICES`
- [ ] lock / etag 처리: `cl_rap_bhv_concurrency_control`, `CL_RAP_BHV_LOCK_CC`, `CL_RAP_BHV_DRAFT_ETAG`, total etag
- [ ] late numbering 상세: `adjust_numbers` 와 preliminary key (`cl_rap_bhv_prelim_key_registry`, `get_preliminary_key_converter`)
- [ ] feature control / instance features 호출 시점: `if_rap_eml_processor~feature_check`, `CL_RAP_BHV_FEATURE_CONTROL`
- [ ] READ ENTITIES 흐름: `EXECUTE_READ` → `if_rap_eml_processor~read`
- [ ] OData 단건 요청(비 batch) 경로, `$expand` deep create (`deep_create_data`), list upsert (`CL_RAP_BHV_LIST_UPSERT`)
- [ ] strict mode / state message 처리 (`mo_strict_mode_handler`, `CL_RAP_CHANGESET_STATE_MSGS`)
- [ ] 외부 `COMMIT WORK` 경로의 cleanup 호출 시점 (`CL_ABAP_BEHV_TRANSACTION_CTRL=>CALL_CLEANUP`)
- [ ] 한 `$batch` 의 여러 changeset 이 같은 ABAP 세션인지 (static/class-data 공유 여부)
- [ ] 이벤트 (`raise entity event`, `CL_ABAP_BEHV_EVENTS`) 발행 시점

## 소스로 확인 불가
- Gateway `/IWBEP/*` (ADT 404): batch 분해, changeset 경계, HTTP 응답 조립
- 커널 (`by kernel module ab_km_behv_*`, EML 문장 컴파일/디스패치)
