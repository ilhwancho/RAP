CLASS lhc_IfInfo DEFINITION INHERITING FROM cl_abap_behavior_handler.
  PRIVATE SECTION.
    METHODS get_global_authorizations FOR GLOBAL AUTHORIZATION
      IMPORTING REQUEST requested_authorizations FOR IfInfo RESULT result.

    METHODS read FOR READ
      IMPORTING keys FOR READ IfInfo RESULT result.

    METHODS rba_Target FOR READ
      IMPORTING keys_rba FOR READ IfInfo\_Target FULL result_requested RESULT result LINK association_links.

    METHODS lock FOR LOCK
      IMPORTING keys FOR LOCK IfInfo.

    METHODS receiveInterface FOR MODIFY
      IMPORTING keys FOR ACTION IfInfo~receiveInterface.
ENDCLASS.

CLASS lhc_IfInfo IMPLEMENTATION.
  METHOD get_global_authorizations.
    " 필요 시 권한 체크
  ENDMETHOD.

  METHOD read.
    DATA(lt_info) = zcl_cih_if_info_data=>get_info( ).
    LOOP AT keys INTO DATA(k).
      READ TABLE lt_info INTO DATA(ls) WITH KEY ifid = k-IfId.
      IF sy-subrc = 0.
        APPEND CORRESPONDING #( ls ) TO result.
      ELSE.
        APPEND VALUE #( %tky = k-%tky ) TO failed-ifinfo.
      ENDIF.
    ENDLOOP.
  ENDMETHOD.

  METHOD rba_Target.
    DATA(lt_target) = zcl_cih_if_info_data=>get_target( ).
    LOOP AT keys_rba INTO DATA(k).
      LOOP AT lt_target INTO DATA(ls) WHERE ifid = k-IfId.
        APPEND VALUE #( source-%tky      = k-%tky
                        target-IfId      = ls-ifid
                        target-TableName = ls-tablename ) TO association_links.
        IF result_requested = abap_true.
          APPEND CORRESPONDING #( ls ) TO result.
        ENDIF.
      ENDLOOP.
    ENDLOOP.
  ENDMETHOD.

  METHOD lock.
    " 잠글 데이터 없음
  ENDMETHOD.

  METHOD receiveInterface.
    LOOP AT keys INTO DATA(k).
      " TODO: EAI 호출 (Communication Arrangement)
      "   cl_http_destination_provider=>create_by_comm_arrangement( comm_scenario = 'ZCIH_IF_EAI_OUT' service_id = '...' )
      "   cl_web_http_client_manager=>create_by_http_destination( ) → execute( if_web_http_client=>post )
      DATA(lv_ok)  = abap_true.                                         " EAI 응답 판정 결과
      DATA(lv_msg) = CONV string( 'EAI 수신 요청이 정상 접수되었습니다.' ).

      IF lv_ok = abap_true.
        " 성공 → Fiori Elements 토스트
        APPEND new_message_with_text( severity = if_abap_behv_message=>severity-success
                                      text     = lv_msg ) TO reported-%other.
      ELSE.
        " 실패 → 400 응답, Fiori Elements 오류 팝업
        APPEND VALUE #( %tky = k-%tky ) TO failed-ifinfo.
        APPEND VALUE #( %tky = k-%tky
                        %msg = new_message_with_text( severity = if_abap_behv_message=>severity-error
                                                      text     = lv_msg ) ) TO reported-ifinfo.
      ENDIF.
    ENDLOOP.
  ENDMETHOD.
ENDCLASS.

CLASS lhc_IfTarget DEFINITION INHERITING FROM cl_abap_behavior_handler.
  PRIVATE SECTION.
    METHODS read FOR READ
      IMPORTING keys FOR READ IfTarget RESULT result.

    METHODS rba_Info FOR READ
      IMPORTING keys_rba FOR READ IfTarget\_Info FULL result_requested RESULT result LINK association_links.
ENDCLASS.

CLASS lhc_IfTarget IMPLEMENTATION.
  METHOD read.
    DATA(lt_target) = zcl_cih_if_info_data=>get_target( ).
    LOOP AT keys INTO DATA(k).
      READ TABLE lt_target INTO DATA(ls) WITH KEY ifid = k-IfId tablename = k-TableName.
      IF sy-subrc = 0.
        APPEND CORRESPONDING #( ls ) TO result.
      ELSE.
        APPEND VALUE #( %tky = k-%tky ) TO failed-iftarget.
      ENDIF.
    ENDLOOP.
  ENDMETHOD.

  METHOD rba_Info.
    DATA(lt_info) = zcl_cih_if_info_data=>get_info( ).
    LOOP AT keys_rba INTO DATA(k).
      READ TABLE lt_info INTO DATA(ls) WITH KEY ifid = k-IfId.
      IF sy-subrc = 0.
        APPEND VALUE #( source-%tky = k-%tky
                        target-IfId = ls-ifid ) TO association_links.
        IF result_requested = abap_true.
          APPEND CORRESPONDING #( ls ) TO result.
        ENDIF.
      ENDIF.
    ENDLOOP.
  ENDMETHOD.
ENDCLASS.

CLASS lsc_ZR_CIH_IF_INFO DEFINITION INHERITING FROM cl_abap_behavior_saver.
  PROTECTED SECTION.
    METHODS finalize          REDEFINITION.
    METHODS check_before_save REDEFINITION.
    METHODS save              REDEFINITION.
    METHODS cleanup           REDEFINITION.
    METHODS cleanup_finalize  REDEFINITION.
ENDCLASS.

CLASS lsc_ZR_CIH_IF_INFO IMPLEMENTATION.
  METHOD finalize.          ENDMETHOD.
  METHOD check_before_save. ENDMETHOD.
  METHOD save.              ENDMETHOD.   " 저장할 데이터 없음
  METHOD cleanup.           ENDMETHOD.
  METHOD cleanup_finalize.  ENDMETHOD.
ENDCLASS.
