"! <p class="shorttext synchronized">감사필드 값 제공자 - 기본 구현</p>
CLASS zcl_cih_audit_context DEFINITION PUBLIC FINAL CREATE PUBLIC.
  PUBLIC SECTION.
    INTERFACES zif_cih_audit_context.
ENDCLASS.


CLASS zcl_cih_audit_context IMPLEMENTATION.

  METHOD zif_cih_audit_context~get_user.
    rv_user = cl_abap_context_info=>get_user_technical_name( ).
  ENDMETHOD.

  METHOD zif_cih_audit_context~get_now.
    rv_now = utclong_current( ).
  ENDMETHOD.

ENDCLASS.
