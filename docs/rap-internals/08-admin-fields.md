# 08. 관리(감사) 필드 자동 세팅 — `@Semantics.user.*` / `@Semantics.systemDateTime.*`

managed BO 에서 CDS 요소에 `@Semantics.user.createdBy` 등을 달면 프레임워크가 값을 채운다.
그 처리를 Z5U 소스로 추적한 결과. (분석일 2026-11-11)

## 1. 한눈에 보기

```
CDS 어노테이션 (@Semantics.user.createdBy ...)
  └─ 메타데이터 로드: CL_CSP_MD_ANNOTATION_READER → CL_CSP_MD_ENTITY (요소명 목록)
COMMIT ENTITIES → 세이브 시퀀스 → managed save (CSP)
  └─ CL_CSP_RUNTIME_CATALOG 의 SAVE_ACTIVE / SAVE_DRAFT 프로세스
       └─ CL_CSP_ACT_SET_ADMIN_DATA  ← 실제로 값을 넣는 곳
```

- ✅ **언제**: interaction phase(MODIFY) 가 아니라 **세이브 시 managed save 프로세스 안**에서 채운다.
  카탈로그에서 `SET_ADMIN_DATA` 는 SAVE_ACTIVE / SAVE_DRAFT 프로세스에만 등장한다.
  ⚠️ 따라서 MODIFY 직후(세이브 전) READ 하면 관리 필드가 비어 있을 것으로 추정 (실행 확인은 안 함).
- ✅ **값**: 사용자 `sy-uname`, 시각 `utclong_current( )` — 한 LUW(한 번의 save)에서 **한 번만** 구해 모든 인스턴스에 같은 값.
  (`CL_CSP_ACT_SET_ADMIN_DATA` 로컬 `lcl_admin_data_provider->get_admin_data`)

## 2. 어노테이션 → 메타데이터 (✅)

- 어노테이션 이름 상수: `CT_CSP_ELEMENT_ANNOTATION_NAME=>value`

  | 상수 | 어노테이션 |
  |---|---|
  | `created_by` | `SEMANTICS.USER.CREATEDBY` |
  | `created_at` | `SEMANTICS.SYSTEMDATETIME.CREATEDAT` |
  | `last_changed_by` | `SEMANTICS.USER.LASTCHANGEDBY` |
  | `last_changed_at` | `SEMANTICS.SYSTEMDATETIME.LASTCHANGEDAT` |
  | `local_last_changed_by` | `SEMANTICS.USER.LOCALINSTANCELASTCHANGEDBY` |
  | `local_last_changed_at` | `SEMANTICS.SYSTEMDATETIME.LOCALINSTANCELASTCHANGEDAT` |

- `CL_CSP_MD_ANNOTATION_READER->get_element_system_admin_type` 가 요소별 관리 필드 종류를 판정 →
  엔터티 메타데이터 로드에 `sysadm_created_by_names` 등 **요소명 목록**으로 저장.
- 런타임 조회: `CL_CSP_MD_ENTITY->get_created_by_element_names( )`, `get_created_at_element_names`,
  `get_last_chgd_by/at_element_names`, `get_lcl_last_chgd_by/at_ele_names`, `has_sys_admin_data_element`.
  → 같은 종류의 어노테이션이 여러 요소에 있어도 모두 채운다 (목록).

## 3. 세이브 프로세스 안의 위치 (✅ `CL_CSP_RUNTIME_CATALOG->define_processes`)

**SAVE_ACTIVE**
1. `GET_BUF_CHANGES_TO_SAVE` — 버퍼 변경분 수집
2. 결정 `ANCESTOR_ENTITIES_HAVE_ADMIN_DATA_ELEMENTS` (`CL_CSP_DEC_ADMDAT_ON_ANCESTORS`)
   → 변경된 엔터티의 **조상(부모·루트)에 last changed 필드가 있으면**
   `GET_INSTANCES_FOR_ADMIN_DATA_PROPAGATION`(`CL_CSP_ACT_GET_FOR_ADMD_AGGREG`) +
   `ADD_UPDATES_FOR_BUSINESS_ADMIN_DATA_PROPAGATION`(`CL_CSP_ACT_ADD_UPD_4_ADMD_PROP`) — 조상에 대한 update 를 추가
3. 결정 `CHANGED_ENTITIES_WITH_ADMIN_DATA` (`CL_CSP_DEC_SET_ADMIN_DATA`, `has_sys_admin_data_element`)
   → 있으면 **`SET_ADMIN_DATA`(`CL_CSP_ACT_SET_ADMIN_DATA`)** + `ADD_UPDATES_FROM_ADMIN_DATA_PROPAGATION_TO_PARTIAL_UPDATES`(`CL_CSP_ACT_ADD_ADMD_PROP_TO_PU`)
4. `SET_KEY_FOR_PID` → `MERGE_DELETE_CREATE` → (buffer sync) → `A_MAP_BUF_CHANGES_TO_DB` → `MERGE_RECREATE_UPDATE` → `SAVE_TO_UPDATE_TASK`

**SAVE_DRAFT**: `TRY_FLUSH_PENDING_OP` → `GET_BUF_CHANGES_TO_SAVE` → (관리 필드 있으면) `SET_ADMIN_DATA` → … → `D_MAP_BUF_CHANGES_TO_DB` → `SET_DRAFT_ADMIN_DATA`(draft admin 테이블, 별개) → … (조상 전파 단계 없음)

## 4. `CL_CSP_ACT_SET_ADMIN_DATA` 동작 (✅ locals_imp)

`lcl_implementation->execute`: 엔터티별(`ct_modify_buf`)로 관리 필드 요소명을 구하고, 없으면 skip.

| 버퍼 변경 종류 | active 전략 (`lcl_admdat_strategy_for_active`) |
|---|---|
| creates | created_by/at, last_changed_by/at, local_last_changed_by/at **전부** |
| recreates (삭제 후 같은 키로 재생성) | update 와 동일 (last/local_last 만) |
| updates (partial update) | last_changed_by/at + local_last_changed_by/at 만 (created_* 유지) |
| 조상 전파 update (`updates_for_admdat_prop_ref`) | **last_changed_by/at 만** (local_* 는 안 건드림) |
| deletes | 대상 아님 |

**draft 전략 (`lcl_admdat_strategy_for_draft`)**
- 요소명 목록에 **created_* 와 local_last_changed_* 만** 포함 (`last_changed_*` 는 draft 에서 세팅 안 함).
- draft 인스턴스의 active 대비 상태(`operation_on_active`)로 분기:
  `create`/`recreate` → create 매핑, `update`/`delete`/`redelete` → update 매핑,
  `unchanged`(Edit 으로 복사만 된 인스턴스) → **skip, active 값 유지**.
- `sysadm_exclude_on_draft` 로 표시된 요소는 control 에서 제외.

**값을 넣는 방식**
- 매핑 테이블 `cl_abap_corresponding=>mapping_value`(요소명 → 값 참조) + 마지막에 `mapping_except_all` 을 붙여
  `cl_abap_corresponding=>create_with_value( )->execute( )` 로 **관리 필드만** 덮어쓴다 (나머지 필드는 그대로).
- 타임스탬프 타입 처리: 요소가 `UTCLONG` 이면 그대로, 아니면 `TIMESTAMP`/`TIMESTAMPL` 로 `cl_abap_tstmp=>move` 변환.
  호환되지 않는 타입이면 `cx_csp_act_request=>incomp_type_for_timestamp` 로 **short dump**.
- 값을 넣은 뒤 각 레코드의 `%control`(x) 에 해당 필드 플래그를 `BIT-OR` (`new_struct_for_flagged_control( sysadm_create | sysadm_update | sysadm_update_propagate )`)
  → 이후 DB 매핑 단계에서 partial update 대상 컬럼에 관리 필드가 포함된다.

## 5. 직접 만든 헬퍼(`ABAP/ZCIH_AUDIT/zcl_cih_audit`)와 비교

| | 프레임워크 | `zcl_cih_audit` |
|---|---|---|
| 필드 식별 | CDS 어노테이션 → 메타데이터 요소명 목록 | 고정 필드명(`CREATED_BY` 등) + RTTI (그룹명 없는 인클루드 OK) |
| 사용자 | `sy-uname` | `cl_abap_context_info=>get_user_technical_name( )` |
| 시각 | `utclong_current( )` 1회 → 필드 타입별 변환 | 동일 (`utclong_current( )` 1회 → UTCLONG/TIMESTAMPL/TIMESTAMP 변환) |
| create / update 구분 | 버퍼가 이미 구분 (creates/updates/recreates) | 호출자가 메서드 선택 |
| update 시 created 보호 | partial update + `%control` 플래그로 관리 필드 컬럼만 추가 | 호출자 책임 (전체 덮어쓰는 UPDATE 주의) |
| 부모 last changed 전파 | 있음 (조상 엔터티에 update 추가) | 없음 |
| draft | 별도 전략 | 해당 없음 |
| 테스트 용이성 | provider 를 `lif_admin_data_provider` 로 분리 (테스트에서 교체) | 동일 (`ZIF_CIH_AUDIT_CONTEXT` 주입) |
