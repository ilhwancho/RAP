CLASS zcl_cih_so_test DEFINITION PUBLIC FINAL CREATE PUBLIC.
  PUBLIC SECTION.
    INTERFACES if_oo_adt_classrun.
ENDCLASS.

CLASS zcl_cih_so_test IMPLEMENTATION.

  METHOD if_oo_adt_classrun~main.
    " 1. 헤더 + 아이템 2건 생성 (Interface BO 경유, active 인스턴스)
    MODIFY ENTITIES OF zi_cih_salesorder
      ENTITY SalesOrder
        CREATE FIELDS ( CustomerID Description DeliveryDate CurrencyCode )
        WITH VALUE #( ( %cid         = 'SO1'
                        %is_draft    = if_abap_behv=>mk-off
                        CustomerID   = '0010100001'
                        Description  = 'EML Test Order'
                        DeliveryDate = cl_abap_context_info=>get_system_date( ) + 7
                        CurrencyCode = 'KRW' ) )
        CREATE BY \_Item FIELDS ( ProductID Quantity QuantityUnit UnitPrice )
        WITH VALUE #( ( %cid_ref  = 'SO1'
                        %is_draft = if_abap_behv=>mk-off
                        %target   = VALUE #( ( %cid = 'I1' %is_draft = if_abap_behv=>mk-off
                                               ProductID = 'TG11' Quantity = 2 QuantityUnit = 'EA' UnitPrice = '1500.00' )
                                             ( %cid = 'I2' %is_draft = if_abap_behv=>mk-off
                                               ProductID = 'TG12' Quantity = 3 QuantityUnit = 'EA' UnitPrice = '2000.00' ) ) ) )
      MAPPED DATA(mapped)
      FAILED DATA(failed)
      REPORTED DATA(reported).

    IF failed IS NOT INITIAL.
      out->write( 'MODIFY failed' ).
      RETURN.
    ENDIF.

    COMMIT ENTITIES RESPONSE OF zi_cih_salesorder
      FAILED DATA(commit_failed)
      REPORTED DATA(commit_reported).

    IF commit_failed IS NOT INITIAL.
      out->write( 'COMMIT failed' ).
      LOOP AT commit_reported-salesorder INTO DATA(r).
        out->write( r-%msg->if_message~get_text( ) ).
      ENDLOOP.
      RETURN.
    ENDIF.

    " 2. 액션 실행 (승인)
    MODIFY ENTITIES OF zi_cih_salesorder
      ENTITY SalesOrder
        EXECUTE acceptOrder FROM VALUE #( FOR m IN mapped-salesorder ( %tky = m-%tky ) ).
    COMMIT ENTITIES.

    " 3. 결과 조회
    SELECT SINGLE FROM zat_cih_soh
      FIELDS sales_order_id, customer_id, overall_status, total_amount, currency_code
      WHERE sales_order_uuid = @( mapped-salesorder[ 1 ]-SalesOrderUUID )
      INTO @DATA(header).
    out->write( header ).

    SELECT FROM zat_cih_soi
      FIELDS item_no, product_id, quantity, quantity_unit, unit_price, net_amount, currency_code
      WHERE parent_uuid = @( mapped-salesorder[ 1 ]-SalesOrderUUID )
      ORDER BY item_no
      INTO TABLE @DATA(items).
    out->write( items ).

    " 3-1. 승인된 오더에 아이템 추가 시도 → feature control(%assoc-_Item) 로 거부되어야 함
    MODIFY ENTITIES OF zi_cih_salesorder
      ENTITY SalesOrder
        CREATE BY \_Item FIELDS ( ProductID Quantity QuantityUnit UnitPrice )
        WITH VALUE #( ( %tky    = mapped-salesorder[ 1 ]-%tky
                        %target = VALUE #( ( %cid = 'I3' %is_draft = if_abap_behv=>mk-off
                                             ProductID = 'TG13' Quantity = 1 QuantityUnit = 'EA' UnitPrice = '100.00' ) ) ) )
      FAILED DATA(cba_failed).
    ROLLBACK ENTITIES.
    out->write( |Accepted order + CREATE BY \\_Item: { COND #( WHEN cba_failed-salesorder IS NOT INITIAL
                                                                THEN `blocked (OK)` ELSE `NOT blocked` ) }| ).

    " 4. 검증 실패 케이스 (고객 없음)
    MODIFY ENTITIES OF zi_cih_salesorder
      ENTITY SalesOrder
        CREATE FIELDS ( Description )
        WITH VALUE #( ( %cid = 'BAD' %is_draft = if_abap_behv=>mk-off Description = 'no customer' ) ).
    COMMIT ENTITIES RESPONSE OF zi_cih_salesorder
      FAILED DATA(bad_failed)
      REPORTED DATA(bad_reported).
    ROLLBACK ENTITIES.
    LOOP AT bad_reported-salesorder INTO DATA(br) WHERE %msg IS BOUND.
      out->write( |Validation: { br-%msg->if_message~get_text( ) }| ).
    ENDLOOP.
  ENDMETHOD.

ENDCLASS.
