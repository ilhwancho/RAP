# RAP 프레임워크 내부 동작 지식 베이스

RAP 런타임(EML, 트랜잭션, 세이브 시퀀스)과 OData/Gateway 요청 처리를 **실제 시스템 소스를 읽고** 분석한 결과를 모아 둔 곳입니다.
새 세션에서 RAP 내부 동작 질문을 받으면 **여기부터 읽고**, 부족한 부분만 소스로 확인한 뒤 결과를 다시 여기에 반영합니다.

- 분석 대상 시스템: `Z5U` (S/4HANA Cloud, client 080) — 접속은 `tools/adt/README.md`
- 소스 조회 도구: `python tools/adt/adt_source.py search|get|methods|show ...`

## 문서 목록

| 파일 | 주제 | 핵심 질문 |
|---|---|---|
| [01-architecture.md](01-architecture.md) | 전체 계층 구조, 클래스 지도 | EML/OData 가 어떤 클래스를 거쳐 핸들러·세이버에 도달하나 |
| [02-interaction-phase.md](02-interaction-phase.md) | MODIFY 처리 (권한·락·프리체크·핸들러·on-modify determination) | MODIFY 한 번에 내부에서 무슨 순서로 무엇이 실행되나 |
| [03-save-sequence.md](03-save-sequence.md) | COMMIT / 세이브 시퀀스, DVM | finalize~save 순서, 실패 처리, point of no return |
| [04-odata-batch.md](04-odata-batch.md) | OData V4 `$batch` / changeset 처리 (Gateway → SADL → RAP) | changeset 이 어떻게 LUW 가 되나 |
| [05-open-questions.md](05-open-questions.md) | 미분석 주제, 읽을 수 없는 소스 | 다음에 무엇을 더 파야 하나 |

## 표기 규칙

- ✅ **확인**: 시스템 소스를 직접 읽고 확인한 내용. 근거로 `클래스->메서드` 를 적는다.
- ⚠️ **추정**: 문서·일반 지식·간접 증거 기반. 소스로 확인하지 못함 (이유 기재).
- 줄번호(`~L702`)는 분석 당시 버전 기준 참고값이다. 릴리스가 바뀌면 달라질 수 있으니 **메서드 이름으로 찾는다**.

## 업데이트 규칙 (Claude 용)

1. 질문을 받으면 관련 문서를 먼저 읽고, 문서로 답할 수 있으면 소스 재분석 없이 답한다 (답변에 "문서 기준"임을 밝히고, 필요하면 핵심 메서드 1~2개만 재확인).
2. 문서에 없거나 ⚠️ 인 부분을 소스로 분석했다면, 같은 세션에서 해당 문서를 갱신한다.
   - 새 주제면 `0N-주제.md` 를 추가하고 위 목록에 등록한다.
   - 확인된 사실은 ⚠️ → ✅ 로 바꾸고 근거 메서드를 적는다.
   - `05-open-questions.md` 에서 해결된 항목은 지우고, 새로 생긴 의문은 추가한다.
3. 아래 "분석 이력" 에 한 줄 추가한다.
4. 문서와 실제 소스가 다르면(릴리스 변경 등) 소스를 따르고 문서를 고친다.

## 분석 이력

| 날짜 | 내용 |
|---|---|
| 2026-11-03 | 최초 작성: 아키텍처, interaction phase, save sequence, DVM, OData V4 changeset 처리 (`CL_ABAP_BEHV_CTRL`, `CL_RAP_BHV_PROCESSOR`, `CL_RAP_TRANSACTION_MANAGER`, `CL_ABAP_BEHV_SAVER_DVM`, `CL_ABAP_BEHV_DETVAL`, `CL_SADL_GW_V4_DPC_ADAPTER`, `CL_SADL_GW_V4_GENERIC_DPC`) |
| 2026-11-04 | 세이버 수집 조건(acc_modify), managed `save_modified` 빈 변경 시 호출, rollback/discard 시 cleanup 경로, 앱 class-data 수명 (`GROUP_BEHV_BY_CLSS`, `COLLECT_SAVERS`, `CL_ABAP_BEHV_SAVER_MNGD_CSP`, `_discard_changes`, `EXECUTE_ROLLBACK`) |
