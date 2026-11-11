"! <p class="shorttext synchronized">감사필드 값 제공자 (사용자/현재시각)</p>
"! 운영: ZCL_CIH_AUDIT_CONTEXT. 유닛 테스트에서는 고정값을 돌려주는 test double 로 교체.
"! (프레임워크 CL_CSP_ACT_SET_ADMIN_DATA 의 lif_admin_data_provider 와 같은 역할)
INTERFACE zif_cih_audit_context PUBLIC.
  METHODS get_user RETURNING VALUE(rv_user) TYPE string.
  METHODS get_now  RETURNING VALUE(rv_now)  TYPE utclong.
ENDINTERFACE.
