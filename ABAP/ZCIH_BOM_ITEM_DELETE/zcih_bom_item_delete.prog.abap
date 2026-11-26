REPORT zcih_bom_item_delete.

PARAMETERS p_test AS CHECKBOX DEFAULT 'X'.   "체크 = 조회만, 해제 = 실제 삭제

TYPES: BEGIN OF ty_in,
         stlnr TYPE stpo-stlnr,     "헤더 BOM 번호
         posnr TYPE stpo-posnr,     "지울 아이템 번호
       END OF ty_in.

TYPES: BEGIN OF ty_work,
         stlnr TYPE stpo-stlnr,
         matnr TYPE mast-matnr,
         werks TYPE mast-werks,
         stlan TYPE mast-stlan,
         stlal TYPE mast-stlal,
         posnr TYPE stpo-posnr,
         idnrk TYPE stpo-idnrk,
         postp TYPE stpo-postp,
       END OF ty_work.

DATA: lt_in   TYPE STANDARD TABLE OF ty_in,
      lt_work TYPE STANDARD TABLE OF ty_work,
      lt_stpo TYPE STANDARD TABLE OF stpo_api03,
      ls_stko TYPE stko_api01,
      lv_warn TYPE capiflag-flwarning.

START-OF-SELECTION.

  "1) 지울 대상 (100개 정도) – 실제로는 엑셀 업로드 등으로 채우면 됨
  lt_in = VALUE #(
    ( stlnr = '00001234' posnr = '0010' )
    ( stlnr = '00001234' posnr = '0020' )
    ( stlnr = '00005678' posnr = '0010' )
  ).
  IF lt_in IS INITIAL. RETURN. ENDIF.

  "2) STLNR → MAST 키(재료/플랜트/용도/대체) + 아이템 식별값(부품/품목범주)
  SELECT DISTINCT p~stlnr, m~matnr, m~werks, m~stlan, m~stlal,
                  p~posnr, p~idnrk, p~postp
    FROM stpo AS p
    INNER JOIN mast AS m ON m~stlnr = p~stlnr
    FOR ALL ENTRIES IN @lt_in
    WHERE p~stlty = 'M'
      AND p~stlnr = @lt_in-stlnr
      AND p~posnr = @lt_in-posnr
    INTO TABLE @lt_work.

  "MAST 에서 못 찾은 건 (헤더/할당까지 사라진 경우) 표시
  LOOP AT lt_in INTO DATA(ls_in).
    IF NOT line_exists( lt_work[ stlnr = ls_in-stlnr posnr = ls_in-posnr ] ).
      WRITE: / '대상 없음(MAST/STPO):', ls_in-stlnr, ls_in-posnr.
    ENDIF.
  ENDLOOP.

  SORT lt_work BY matnr werks stlan stlal posnr.

  "3) BOM(재료/플랜트/용도/대체) 단위로 묶어서 한 번씩 호출
  LOOP AT lt_work INTO DATA(ls_grp)
       GROUP BY ( matnr = ls_grp-matnr werks = ls_grp-werks
                  stlan = ls_grp-stlan stlal = ls_grp-stlal )
       INTO DATA(grp).

    CLEAR: lt_stpo, ls_stko, lv_warn.

    LOOP AT GROUP grp INTO DATA(ls_w).
      APPEND VALUE #( id_item_no = ls_w-posnr      "식별: 아이템번호
                      id_comp    = ls_w-idnrk      "식별: 부품
                      id_itm_ctg = ls_w-postp      "식별: 품목범주
                      fldelete   = 'X' )           "★ 삭제 플래그
             TO lt_stpo.
    ENDLOOP.

    IF p_test = 'X'.
      WRITE: / '[TEST]', grp-matnr, grp-werks, grp-stlan, grp-stlal,
               lines( lt_stpo ), '건 삭제 예정'.
      CONTINUE.
    ENDIF.

    CALL FUNCTION 'CSAP_MAT_BOM_MAINTAIN'
      EXPORTING
        material           = grp-matnr
        plant              = grp-werks
        bom_usage          = grp-stlan
        alternative        = grp-stlal
*       valid_from         = '26.11.2026'   "변경번호 관리 BOM이면 지정
*       change_no          = '...'
        i_stko             = ls_stko        "필수 파라미터 → 빈 값으로 넘김(헤더 변경 없음)
        fl_commit_and_wait = 'X'
        fl_default_values  = space
      IMPORTING
        fl_warning         = lv_warn
      TABLES
        t_stpo             = lt_stpo
      EXCEPTIONS
        error              = 1
        OTHERS             = 2.

    IF sy-subrc = 0.
      WRITE: / 'OK  ', grp-matnr, grp-werks, grp-stlan, grp-stlal,
               lines( lt_stpo ), '건 삭제'.
    ELSE.
      MESSAGE ID sy-msgid TYPE 'I' NUMBER sy-msgno
              WITH sy-msgv1 sy-msgv2 sy-msgv3 sy-msgv4 INTO DATA(lv_msg).
      WRITE: / 'ERR ', grp-matnr, grp-werks, grp-stlan, grp-stlal, lv_msg.
    ENDIF.
  ENDLOOP.
