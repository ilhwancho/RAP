"! 신용한도 체크 시연 (실습용)
CLASS zcl_cih_credit_demo DEFINITION PUBLIC FINAL CREATE PUBLIC.
  PUBLIC SECTION.
    INTERFACES if_oo_adt_classrun.
  PRIVATE SECTION.
    DATA mo_out TYPE REF TO if_oo_adt_classrun_out.
    METHODS create_order
      IMPORTING iv_customer    TYPE zif_cih_credit_check=>ty_customer
      RETURNING VALUE(rs_key)  TYPE sysuuid_x16.
    METHODS accept
      IMPORTING iv_uuid TYPE sysuuid_x16
                iv_label TYPE string
                out      TYPE REF TO if_oo_adt_classrun_out.
ENDCLASS.

CLASS zcl_cih_credit_demo IMPLEMENTATION.
  METHOD if_oo_adt_classrun~main.
    mo_out = out.
    " 0. 실습 데이터 초기화: 시연 고객의 기존 오더 삭제, 한도 10,000 KRW 등록 (KRW 는 내부값 100.00 = 10,000)
    SELECT sales_order_uuid FROM zat_cih_soh WHERE customer_id IN ( 'ZCIHTEST01', 'ZCIHNOLIM' ) INTO TABLE @DATA(lt_old).
    LOOP AT lt_old INTO DATA(ls_old).
      DELETE FROM zat_cih_soi WHERE parent_uuid = @ls_old-sales_order_uuid.
    ENDLOOP.
    DELETE FROM zat_cih_soh WHERE customer_id IN ( 'ZCIHTEST01', 'ZCIHNOLIM' ).
    DELETE FROM zat_cih_crlim WHERE customer_id = 'ZCIHNOLIM'.
    MODIFY zat_cih_crlim FROM @( VALUE #( customer_id = 'ZCIHTEST01' credit_limit = '100.00' currency_code = 'KRW' ) ).
    COMMIT WORK.
    out->write( `한도: ZCIHTEST01 = 10,000 KRW, ZCIHNOLIM = 미등록` ).

    " 1. 6,000 KRW 오더 승인 → 통과
    accept( iv_uuid = create_order( 'ZCIHTEST01' ) iv_label = `오더 A (6,000)` out = out ).
    " 2. 6,000 KRW 오더 하나 더 → 6,000 + 6,000 > 10,000 이라 막혀야 함
    accept( iv_uuid = create_order( 'ZCIHTEST01' ) iv_label = `오더 B (6,000)` out = out ).
    " 3. 한도 미등록 고객 → 막혀야 함
    accept( iv_uuid = create_order( 'ZCIHNOLIM' ) iv_label = `오더 C (미등록 고객)` out = out ).
  ENDMETHOD.

  METHOD create_order.
    " 아이템 1건: 2 EA x 3,000 KRW = 6,000 KRW (EML 에는 3000.00 으로 넣음)
    MODIFY ENTITIES OF zi_cih_salesorder
      ENTITY SalesOrder
        CREATE FIELDS ( CustomerID Description CurrencyCode )
        WITH VALUE #( ( %cid = 'H' %is_draft = if_abap_behv=>mk-off
                        CustomerID = iv_customer Description = 'credit demo' CurrencyCode = 'KRW' ) )
        CREATE BY \_Item FIELDS ( ProductID Quantity QuantityUnit UnitPrice )
        WITH VALUE #( ( %cid_ref = 'H' %is_draft = if_abap_behv=>mk-off
                        %target = VALUE #( ( %cid = 'I' %is_draft = if_abap_behv=>mk-off
                                             ProductID = 'TG11' Quantity = 2 QuantityUnit = 'EA' UnitPrice = '3000.00' ) ) ) )
      MAPPED DATA(mapped).
    COMMIT ENTITIES.
    rs_key = mapped-salesorder[ 1 ]-SalesOrderUUID.
    " 단위 확인: RAP 로 읽은 값 vs DB 값
    READ ENTITIES OF zi_cih_salesorder ENTITY SalesOrder FIELDS ( TotalAmount )
      WITH VALUE #( ( %key-SalesOrderUUID = rs_key %is_draft = if_abap_behv=>mk-off ) ) RESULT DATA(lt_read).
    SELECT SINGLE total_amount FROM zat_cih_soh WHERE sales_order_uuid = @rs_key INTO @DATA(lv_db).
    mo_out->write( |  [단위 확인] READ ENTITIES TotalAmount = { lt_read[ 1 ]-TotalAmount }, DB total_amount = { lv_db }| ).
  ENDMETHOD.

  METHOD accept.
    MODIFY ENTITIES OF zi_cih_salesorder
      ENTITY SalesOrder
        EXECUTE acceptOrder FROM VALUE #( ( %key-SalesOrderUUID = iv_uuid %is_draft = if_abap_behv=>mk-off ) )
      FAILED DATA(failed)
      REPORTED DATA(reported).

    IF failed-salesorder IS INITIAL.
      COMMIT ENTITIES.
      SELECT SINGLE overall_status FROM zat_cih_soh WHERE sales_order_uuid = @iv_uuid INTO @DATA(lv_status).
      out->write( |{ iv_label }: 승인됨 (status = { lv_status })| ).
    ELSE.
      ROLLBACK ENTITIES.
      DATA(lv_msg) = VALUE string( ).
      LOOP AT reported-salesorder INTO DATA(r) WHERE %msg IS BOUND.
        lv_msg = r-%msg->if_message~get_text( ).
      ENDLOOP.
      out->write( |{ iv_label }: 거부됨 → { lv_msg }| ).
    ENDIF.
  ENDMETHOD.
ENDCLASS.
