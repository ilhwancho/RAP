# 01. 전체 아키텍처와 클래스 지도

## 한 장 요약

```
EML MODIFY / READ / COMMIT ENTITIES (커널 문장)
   └─► CL_ABAP_BEHV_CTRL=>EXECUTE_MODIFY / EXECUTE_READ / EXECUTE_COMMIT / EXECUTE_ROLLBACK
          └─► get_eml_processor (매크로) = CL_RAP_EML_PROCESSOR_FACTORY=>GET( )
                 └─► CL_RAP_TRANSACTION_MANAGER->get_eml_processor( )
                        └─► IF_RAP_EML_PROCESSOR = CL_RAP_BHV_PROCESSOR  ◄─────────────┐
                                                                                         │
OData V4 $batch / 단건 요청                                                              │
   └─► /IWBEP (Gateway, 소스 비공개)                                                     │
          └─► CL_SADL_GW_V4_DPC_ADAPTER  (/iwbep/if_v4_dp_batch~process_change_set)      │
                 └─► CL_SADL_GW_V4_GENERIC_DPC->process_change_set                       │
                        └─► CL_SADL_CHANGESET_FACTORY=>create_changeset_processor        │
                               = CL_RAP_TRANSACTION_MANAGER (if_sadl_changeset~modify)   │
                                      └─► mo_bhv_transaction_processor ─────────────────┘
                                          (= CL_RAP_BHV_PROCESSOR=>create_instance( ))

CL_RAP_BHV_PROCESSOR
   ├─ interaction: 권한 / 락 / 프리체크 / call_handlers_modify ─► 핸들러
   │      managed: 프레임워크 버퍼 (CSP: CL_CSP_BEHV_*, draft DSP: CL_DSP_BEHV_*)
   │      unmanaged: 애플리케이션 lhc_* (CL_ABAP_BEHAVIOR_HANDLER 상속)
   └─ save: _execute_save_phase ─► CL_ABAP_BEHV_CTRL=>CALL_COLLECTED_SAVERS( phase )
          ─► 세이버 (CL_ABAP_BEHAVIOR_SAVER 계열)
               managed: CL_ABAP_BEHV_SAVER_MNGD_CSP (부모 CL_ABAP_BEHV_SAVER_DVM)
               draft  : CL_ABAP_BEHV_SAVER_MNGD_DSP
               BOPF기반: CL_ABAP_BEHV_SAVER_MNGD_BSP
               interface/projection: CL_ABAP_BEHV_SAVER_PROJ
          ─► determination/validation 엔진: CL_ABAP_BEHV_DETVAL (DVM)
```

✅ 핵심: **EML 과 OData 는 같은 `CL_RAP_TRANSACTION_MANAGER` / `CL_RAP_BHV_PROCESSOR` 로 수렴**한다.
근거: `CL_ABAP_BEHV_CTRL` macros `get_eml_processor`, `CL_RAP_EML_PROCESSOR_FACTORY` locals `lcl_eml_processor->get_eml_processor`,
`CL_RAP_TRANSACTION_MANAGER->constructor` (`mo_bhv_transaction_processor = cl_rap_bhv_processor=>create_instance( )`).

## 클래스 지도

| 클래스 | 역할 | 비고 |
|---|---|---|
| `CL_ABAP_BEHV_CTRL` | EML 문장의 ABAP 측 진입점. 핸들러/세이버 호출 디스패처 | 8천 줄+. `EXECUTE_*`, `CALL_HANDLER`, `CALL_SAVER`, `CALL_COLLECTED_SAVERS` |
| `CL_RAP_EML_PROCESSOR_FACTORY` | EML 프로세서 싱글턴 획득 | 로컬 `lcl_eml_processor` 가 트랜잭션 매니저에 위임 |
| `CL_RAP_TRANSACTION_MANAGER` | **트랜잭션 소유자**. changeset modify, 세이브 시퀀스 전체, COMMIT WORK | `_process_save_sequence` 가 핵심 |
| `CL_RAP_BHV_PROCESSOR` | RAP BO 처리기 (IF_RAP_EML_PROCESSOR + IF_RAP_TRANSACTION_PROCESSOR) | modify 단계 순서, save phase → 세이버 |
| `CL_ABAP_BEHV_TRANSACTION_CTRL` | LUW 를 "RAP 소유" 로 표시(start/pause/resume/stop). 외부 COMMIT WORK 시 `CALL_SAVE` | 실패 시 `CX_ABAP_BEHV_COMMIT_FAILED` 덤프 |
| `CL_ABAP_BEHAVIOR_HANDLER` / `CL_ABAP_BEHAVIOR_SAVER` | 애플리케이션 핸들러/세이버 베이스 | 세이버 메서드: finalize, check_before_save, adjust_numbers, save, save_modified, cleanup, cleanup_finalize, map_messages |
| `CL_ABAP_BEHV_SAVER_DVM` | managed 세이버 공통 부모. **finalize = determination on save, check_before_save = validation** | 03 참조 |
| `CL_ABAP_BEHV_DETVAL` | DVM: determination/validation 트리거 수집·실행, 무한루프 방지 | 로컬 클래스에 실구현 |
| `CL_SADL_GW_V4_DPC_ADAPTER` | Gateway V4 ↔ SADL 어댑터. batch/changeset 진입 | `/iwbep/if_v4_dp_batch~*` |
| `CL_SADL_GW_V4_GENERIC_DPC` | changeset 을 create/update/delete/action 테이블로 만들어 한 번에 modify | `if_sadl_gw_v4_generic_dpc~process_change_set` |
| `CL_SADL_GW_DPC_BATCH` | changeset 후 변경 엔티티 재조회 (응답 생성) | 미분석 상세 |

## 소스를 읽을 수 없는 영역 (⚠️)

- EML 문장 자체(MODIFY ENTITIES 등)의 커널 처리, `ab_km_behv_*` 커널 모듈 (`by kernel module`)
- Gateway `/IWBEP/*` 클래스/인터페이스 → ADT 소스 요청 시 404 (비공개). batch 를 changeset/GET 으로 나누는 부분은 ⚠️ 추정
