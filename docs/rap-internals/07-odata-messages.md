# 07. OData V4 응답 메시지 (`sap-messages` 헤더 vs `SAP__Messages`)

성공한 요청에서 RAP 메시지(`reported`)가 OData 응답의 어디로 가는지.
분석: 2026-11-09, `CL_SADL_GW_V4_DPC_ADAPTER`, `CL_SADL_GW_V4_GENERIC_DPC`, `CL_RAP_RT_MESSAGE_HANDLER`.

## 요약
| 메시지 종류 | `$select` 에 `SAP__Messages` 있음 | 없음 |
|---|---|---|
| **state** 메시지 (인스턴스에 저장된 메시지) | 엔티티 본문의 `SAP__Messages` 속성 | 버려짐 (헤더로도 안 감) |
| **transition** 메시지 (그 요청에서만 유효, 대부분의 `reported`) | 인스턴스를 가리키면 `SAP__Messages` 에, 대상이 없거나 매핑 실패면 헤더 | **응답 헤더** (`sap-messages`) |

- 성공 응답(2xx)의 성공/정보/경고 메시지는 대개 **헤더**로 나간다. 오류(실패)는 헤더가 아니라 OData error 본문(4xx/5xx)이다.
- Fiori Elements(UI5 V4 모델)는 보통 `SAP__Messages` 를 `$select` 하므로 state 메시지를 본문에서 받는다. 외부 API 클라이언트는 보통 안 하므로 transition 메시지를 **헤더에서만** 받는다.

## 근거 (✅)

### 1. `SAP__Messages` 요청 여부 판정
- `CL_SADL_GW_V4_GENERIC_DPC->_adapt_requested_elements`: `$select` 에 `SAP__Messages` 가 있으면 요청 필드에서 지우고 `message_mode = all`. 없으면 `none`.
- update/create: `requested_elements` 에서 `SAP__Messages` 를 지운 결과(`sy-subrc = 0`)로 `messages_requested` 플래그 설정 (주석: "true: state messages are read during (after save) reread of entities").
- bulk action: `CL_SADL_GW_V4_DPC_ADAPTER->/iwbep/if_v4_dp_advanced~bulk_execute_action` 에서 `lv_messages_are_requested`.

### 2. 메시지 수명(lifetime)
- `if_sadl_message_handler=>co_lifetime-state | transition`.
- state 는 `CL_RAP_RT_MESSAGE_HANDLER` 가 `CL_RAP_STATE_MESSAGE_HANDLER->read` 로 읽은 메시지에 `lifetime = state` 를 붙인다 (draft 의 `%state_area` 메시지 등, 인스턴스에 지속).
  ⚠️ 그 밖의 `reported` 가 모두 transition 이 되는 지점은 직접 확인하지 않음 (기본값으로 추정).

### 3. 본문(`SAP__Messages`)으로 보내기
- `CL_SADL_GW_V4_GENERIC_DPC->_update_message_table`: 메시지 location 이 현재 엔티티 키와 맞으면 엔티티 데이터의 `SAP__Messages` 컴포넌트에 추가 (`is_transition_message` 플래그 포함). transition 은 보낸 뒤 목록에서 삭제.
- 액션 파라미터를 가리키는 메시지는 `SAP__Messages` 가 아니라 operation 헤더로 보낸다 (`_proc_msgs_targting_opertn_par`, 주석 "belong in (operation) header").

### 4. 요청하지 않은 경우
- `_process_unrequested_messages`: **state 가 아닌 것만 남기고**(`DELETE ct_messages WHERE NOT lifetime = transition`), transition 은 `io_operation_messages` (`CL_SADL_V4_OPERATION_MESSAGES`) 에 넣는다.
- function: "Return transition messages without target in the header if SAP_Messages are not requested" (location 을 지워 헤더로 보냄).

### 5. 헤더로 내보내기
- `CL_SADL_GW_V4_DPC_ADAPTER` 의 `create_entity`, `update_entity`, `delete_entity`, `execute_action`, `execute_function`, `bulk_execute_action`, `_post_process_succ_change_set`($batch changeset) 가 성공 시
  1. `_write_msg_into_table`: location 이 없거나 transition 인 메시지를 헤더용으로 변환 (`target` 은 NULL)
  2. `_add_not_requested_msgs`: operation messages 추가
  3. `io_response->set_header_messages( it_message, iv_do_more_messages_exist )`
- 개수 제한: `io_response->get_header_message_limit( )` (adapter 상수 `co_max_header_messages = 20`). 넘으면 `do_more_messages_exist = true`.
- 실패 시에는 `_raise` → 예외의 message container (`_write_msg_into_msg_container`, `add_t100`) → OData error 응답.

### 6. HTTP 헤더 직렬화 — ⚠️ 소스 비공개
`set_header_messages` 이후 실제 헤더 이름·형식은 Gateway(`/IWBEP/*`, ADT 404) 에서 처리한다.
일반 문서 기준: OData V4 는 응답 헤더 `sap-messages` 에 JSON 배열(`code`, `message`, `numericSeverity`, `target`, `transition`, `longtextUrl` …).
XSLT `/IWBEP/ST_OD_MESSAGE_HEADER` 가 존재 (V2 `sap-message` 헤더용으로 추정). V2 는 단수형 `sap-message`.
