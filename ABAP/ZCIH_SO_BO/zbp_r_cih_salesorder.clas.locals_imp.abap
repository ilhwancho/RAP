CLASS lhc_salesorder DEFINITION INHERITING FROM cl_abap_behavior_handler.
  PRIVATE SECTION.
    CONSTANTS:
      BEGIN OF c_status,
        open     TYPE c LENGTH 1 VALUE 'O',
        accepted TYPE c LENGTH 1 VALUE 'A',
        rejected TYPE c LENGTH 1 VALUE 'X',
      END OF c_status,
      c_default_currency TYPE c LENGTH 5 VALUE 'KRW'.

    METHODS get_global_authorizations FOR GLOBAL AUTHORIZATION
      IMPORTING REQUEST requested_authorizations FOR SalesOrder RESULT result.

    METHODS get_instance_features FOR INSTANCE FEATURES
      IMPORTING keys REQUEST requested_features FOR SalesOrder RESULT result.

    METHODS acceptOrder FOR MODIFY
      IMPORTING keys FOR ACTION SalesOrder~acceptOrder RESULT result.

    METHODS rejectOrder FOR MODIFY
      IMPORTING keys FOR ACTION SalesOrder~rejectOrder RESULT result.

    METHODS recalcTotalAmount FOR MODIFY
      IMPORTING keys FOR ACTION SalesOrder~recalcTotalAmount.

    METHODS testFlatParam FOR MODIFY
      IMPORTING keys FOR ACTION SalesOrder~testFlatParam.

    METHODS testDeepParam FOR MODIFY
      IMPORTING keys FOR ACTION SalesOrder~testDeepParam.

    METHODS setSalesOrderID FOR DETERMINE ON SAVE
      IMPORTING keys FOR SalesOrder~setSalesOrderID.

    METHODS setInitialValues FOR DETERMINE ON MODIFY
      IMPORTING keys FOR SalesOrder~setInitialValues.

    METHODS validateCustomer FOR VALIDATE ON SAVE
      IMPORTING keys FOR SalesOrder~validateCustomer.

    METHODS validateDates FOR VALIDATE ON SAVE
      IMPORTING keys FOR SalesOrder~validateDates.
ENDCLASS.

CLASS lhc_salesorder IMPLEMENTATION.

  METHOD get_global_authorizations.
    result = VALUE #( %create             = if_abap_behv=>auth-allowed
                      %update             = if_abap_behv=>auth-allowed
                      %delete             = if_abap_behv=>auth-allowed
                      %action-acceptOrder = if_abap_behv=>auth-allowed
                      %action-rejectOrder = if_abap_behv=>auth-allowed
                      %action-Edit        = if_abap_behv=>auth-allowed
                      %action-testFlatParam = if_abap_behv=>auth-allowed
                      %action-testDeepParam = if_abap_behv=>auth-allowed ).
  ENDMETHOD.

  METHOD get_instance_features.
    READ ENTITIES OF zr_cih_salesorder IN LOCAL MODE
      ENTITY SalesOrder
        FIELDS ( OverallStatus ) WITH CORRESPONDING #( keys )
      RESULT DATA(orders)
      FAILED failed.

    result = VALUE #( FOR order IN orders
                      ( %tky                = order-%tky
                        %action-acceptOrder = COND #( WHEN order-OverallStatus = c_status-accepted
                                                      THEN if_abap_behv=>fc-o-disabled
                                                      ELSE if_abap_behv=>fc-o-enabled )
                        %action-rejectOrder = COND #( WHEN order-OverallStatus = c_status-rejected
                                                      THEN if_abap_behv=>fc-o-disabled
                                                      ELSE if_abap_behv=>fc-o-enabled )
                        " 승인된 오더에는 아이템 추가 불가 (create-by-association 동적 제어)
                        %assoc-_Item        = COND #( WHEN order-OverallStatus = c_status-accepted
                                                      THEN if_abap_behv=>fc-o-disabled
                                                      ELSE if_abap_behv=>fc-o-enabled ) ) ).
  ENDMETHOD.

  METHOD acceptOrder.
    MODIFY ENTITIES OF zr_cih_salesorder IN LOCAL MODE
      ENTITY SalesOrder
        UPDATE FIELDS ( OverallStatus )
        WITH VALUE #( FOR key IN keys ( %tky = key-%tky OverallStatus = c_status-accepted ) ).

    READ ENTITIES OF zr_cih_salesorder IN LOCAL MODE
      ENTITY SalesOrder
        ALL FIELDS WITH CORRESPONDING #( keys )
      RESULT DATA(orders).

    result = VALUE #( FOR order IN orders ( %tky = order-%tky %param = order ) ).
  ENDMETHOD.

  METHOD rejectOrder.
    MODIFY ENTITIES OF zr_cih_salesorder IN LOCAL MODE
      ENTITY SalesOrder
        UPDATE FIELDS ( OverallStatus )
        WITH VALUE #( FOR key IN keys ( %tky = key-%tky OverallStatus = c_status-rejected ) ).

    READ ENTITIES OF zr_cih_salesorder IN LOCAL MODE
      ENTITY SalesOrder
        ALL FIELDS WITH CORRESPONDING #( keys )
      RESULT DATA(orders).

    result = VALUE #( FOR order IN orders ( %tky = order-%tky %param = order ) ).
  ENDMETHOD.

  METHOD recalcTotalAmount.
    READ ENTITIES OF zr_cih_salesorder IN LOCAL MODE
      ENTITY SalesOrder
        FIELDS ( TotalAmount ) WITH CORRESPONDING #( keys )
      RESULT DATA(orders)
      ENTITY SalesOrder BY \_Item
        FIELDS ( ParentUUID NetAmount ) WITH CORRESPONDING #( keys )
      RESULT DATA(items).

    LOOP AT orders ASSIGNING FIELD-SYMBOL(<order>).
      <order>-TotalAmount = 0.
      LOOP AT items INTO DATA(item) WHERE %is_draft  = <order>-%is_draft
                                      AND ParentUUID = <order>-SalesOrderUUID.
        <order>-TotalAmount += item-NetAmount.
      ENDLOOP.
    ENDLOOP.

    MODIFY ENTITIES OF zr_cih_salesorder IN LOCAL MODE
      ENTITY SalesOrder
        UPDATE FIELDS ( TotalAmount )
        WITH CORRESPONDING #( orders ).
  ENDMETHOD.

  METHOD testFlatParam.
    " 시험용: 받은 파라미터를 메시지로 돌려준다
    LOOP AT keys INTO DATA(key).
      APPEND VALUE #( %cid = key-%cid
                      %msg = new_message_with_text(
                               severity = if_abap_behv_message=>severity-information
                               text     = |flat: Quantity={ key-%param-Quantity } Remark={ key-%param-Remark }| ) )
             TO reported-salesorder.
    ENDLOOP.
  ENDMETHOD.

  METHOD testDeepParam.
    LOOP AT keys INTO DATA(key).
      APPEND VALUE #( %cid = key-%cid
                      %msg = new_message_with_text(
                               severity = if_abap_behv_message=>severity-information
                               text     = |deep: Quantity={ key-%param-Quantity } Remark={ key-%param-Remark } | &&
                                          |Items={ lines( key-%param-_Item ) } | &&
                                          |Products={ REDUCE string( INIT s = `` FOR i IN key-%param-_Item NEXT s = s && i-ProductID && `;` ) }| ) )
             TO reported-salesorder.
    ENDLOOP.
  ENDMETHOD.

  METHOD setSalesOrderID.
    READ ENTITIES OF zr_cih_salesorder IN LOCAL MODE
      ENTITY SalesOrder
        FIELDS ( SalesOrderID ) WITH CORRESPONDING #( keys )
      RESULT DATA(orders).

    DELETE orders WHERE SalesOrderID IS NOT INITIAL.
    CHECK orders IS NOT INITIAL.

    SELECT SINGLE FROM zat_cih_soh
      FIELDS MAX( sales_order_id )
      INTO @DATA(max_id).

    DATA(next_id) = CONV i( max_id ).

    MODIFY ENTITIES OF zr_cih_salesorder IN LOCAL MODE
      ENTITY SalesOrder
        UPDATE FIELDS ( SalesOrderID )
        WITH VALUE #( FOR order IN orders INDEX INTO idx
                      ( %tky         = order-%tky
                        SalesOrderID = |{ next_id + idx WIDTH = 10 ALIGN = RIGHT PAD = '0' }| ) ).
  ENDMETHOD.

  METHOD setInitialValues.
    READ ENTITIES OF zr_cih_salesorder IN LOCAL MODE
      ENTITY SalesOrder
        FIELDS ( OverallStatus OrderDate CurrencyCode ) WITH CORRESPONDING #( keys )
      RESULT DATA(orders).

    DATA(today) = cl_abap_context_info=>get_system_date( ).

    MODIFY ENTITIES OF zr_cih_salesorder IN LOCAL MODE
      ENTITY SalesOrder
        UPDATE FIELDS ( OverallStatus OrderDate CurrencyCode )
        WITH VALUE #( FOR order IN orders
                      ( %tky          = order-%tky
                        OverallStatus = COND #( WHEN order-OverallStatus IS INITIAL
                                                THEN c_status-open ELSE order-OverallStatus )
                        OrderDate     = COND #( WHEN order-OrderDate IS INITIAL
                                                THEN today ELSE order-OrderDate )
                        CurrencyCode  = COND #( WHEN order-CurrencyCode IS INITIAL
                                                THEN c_default_currency ELSE order-CurrencyCode ) ) ).
  ENDMETHOD.

  METHOD validateCustomer.
    READ ENTITIES OF zr_cih_salesorder IN LOCAL MODE
      ENTITY SalesOrder
        FIELDS ( CustomerID ) WITH CORRESPONDING #( keys )
      RESULT DATA(orders).

    LOOP AT orders INTO DATA(order).
      APPEND VALUE #( %tky = order-%tky %state_area = 'VALIDATE_CUSTOMER' ) TO reported-salesorder.

      IF order-CustomerID IS INITIAL.
        APPEND VALUE #( %tky = order-%tky ) TO failed-salesorder.
        APPEND VALUE #( %tky                = order-%tky
                        %state_area         = 'VALIDATE_CUSTOMER'
                        %msg                = new_message_with_text(
                                                severity = if_abap_behv_message=>severity-error
                                                text     = '고객번호를 입력하세요.' )
                        %element-CustomerID = if_abap_behv=>mk-on ) TO reported-salesorder.
      ENDIF.
    ENDLOOP.
  ENDMETHOD.

  METHOD validateDates.
    READ ENTITIES OF zr_cih_salesorder IN LOCAL MODE
      ENTITY SalesOrder
        FIELDS ( OrderDate DeliveryDate ) WITH CORRESPONDING #( keys )
      RESULT DATA(orders).

    LOOP AT orders INTO DATA(order).
      APPEND VALUE #( %tky = order-%tky %state_area = 'VALIDATE_DATES' ) TO reported-salesorder.

      IF order-DeliveryDate IS NOT INITIAL AND order-DeliveryDate < order-OrderDate.
        APPEND VALUE #( %tky = order-%tky ) TO failed-salesorder.
        APPEND VALUE #( %tky                  = order-%tky
                        %state_area           = 'VALIDATE_DATES'
                        %msg                  = new_message_with_text(
                                                  severity = if_abap_behv_message=>severity-error
                                                  text     = '납품일은 주문일 이후여야 합니다.' )
                        %element-OrderDate    = if_abap_behv=>mk-on
                        %element-DeliveryDate = if_abap_behv=>mk-on ) TO reported-salesorder.
      ENDIF.
    ENDLOOP.
  ENDMETHOD.

ENDCLASS.


CLASS lhc_salesorderitem DEFINITION INHERITING FROM cl_abap_behavior_handler.
  PRIVATE SECTION.
    METHODS setItemDefaults FOR DETERMINE ON MODIFY
      IMPORTING keys FOR SalesOrderItem~setItemDefaults.

    METHODS calcNetAmount FOR DETERMINE ON MODIFY
      IMPORTING keys FOR SalesOrderItem~calcNetAmount.

    METHODS validateQuantity FOR VALIDATE ON SAVE
      IMPORTING keys FOR SalesOrderItem~validateQuantity.
ENDCLASS.

CLASS lhc_salesorderitem IMPLEMENTATION.

  METHOD setItemDefaults.
    " 부모 오더 (통화)
    READ ENTITIES OF zr_cih_salesorder IN LOCAL MODE
      ENTITY SalesOrderItem BY \_SalesOrder
        FIELDS ( CurrencyCode ) WITH CORRESPONDING #( keys )
      RESULT DATA(orders).

    " 같은 오더의 전체 아이템 (최대 품목번호 계산용)
    READ ENTITIES OF zr_cih_salesorder IN LOCAL MODE
      ENTITY SalesOrder BY \_Item
        FIELDS ( ItemNo ) WITH CORRESPONDING #( orders )
      RESULT DATA(all_items).

    READ ENTITIES OF zr_cih_salesorder IN LOCAL MODE
      ENTITY SalesOrderItem
        FIELDS ( ParentUUID ItemNo ) WITH CORRESPONDING #( keys )
      RESULT DATA(items).

    DATA updates TYPE TABLE FOR UPDATE zr_cih_salesorder\\SalesOrderItem.

    LOOP AT orders INTO DATA(order).
      DATA(max_no) = 0.
      LOOP AT all_items INTO DATA(other) WHERE %is_draft  = order-%is_draft
                                           AND ParentUUID = order-SalesOrderUUID.
        IF CONV i( other-ItemNo ) > max_no.
          max_no = other-ItemNo.
        ENDIF.
      ENDLOOP.

      LOOP AT items INTO DATA(item) WHERE %is_draft  = order-%is_draft
                                      AND ParentUUID = order-SalesOrderUUID.
        DATA(item_no) = item-ItemNo.
        IF item_no IS INITIAL.
          max_no += 10.
          item_no = max_no.
        ENDIF.
        APPEND VALUE #( %tky         = item-%tky
                        ItemNo       = item_no
                        CurrencyCode = order-CurrencyCode ) TO updates.
      ENDLOOP.
    ENDLOOP.

    MODIFY ENTITIES OF zr_cih_salesorder IN LOCAL MODE
      ENTITY SalesOrderItem
        UPDATE FIELDS ( ItemNo CurrencyCode ) WITH updates.
  ENDMETHOD.

  METHOD calcNetAmount.
    READ ENTITIES OF zr_cih_salesorder IN LOCAL MODE
      ENTITY SalesOrderItem
        FIELDS ( ParentUUID Quantity UnitPrice ) WITH CORRESPONDING #( keys )
      RESULT DATA(items).

    MODIFY ENTITIES OF zr_cih_salesorder IN LOCAL MODE
      ENTITY SalesOrderItem
        UPDATE FIELDS ( NetAmount )
        WITH VALUE #( FOR item IN items
                      ( %tky      = item-%tky
                        NetAmount = item-Quantity * item-UnitPrice ) ).

    " 헤더 총액 재계산
    DATA parents TYPE TABLE FOR ACTION IMPORT zr_cih_salesorder\\SalesOrder~recalcTotalAmount.
    LOOP AT items INTO DATA(i).
      APPEND VALUE #( %is_draft = i-%is_draft SalesOrderUUID = i-ParentUUID ) TO parents.
    ENDLOOP.
    SORT parents BY %is_draft SalesOrderUUID.
    DELETE ADJACENT DUPLICATES FROM parents COMPARING %is_draft SalesOrderUUID.

    MODIFY ENTITIES OF zr_cih_salesorder IN LOCAL MODE
      ENTITY SalesOrder
        EXECUTE recalcTotalAmount FROM parents.
  ENDMETHOD.

  METHOD validateQuantity.
    READ ENTITIES OF zr_cih_salesorder IN LOCAL MODE
      ENTITY SalesOrderItem
        FIELDS ( ParentUUID Quantity ) WITH CORRESPONDING #( keys )
      RESULT DATA(items).

    LOOP AT items INTO DATA(item).
      APPEND VALUE #( %tky = item-%tky %state_area = 'VALIDATE_QUANTITY' ) TO reported-salesorderitem.

      IF item-Quantity <= 0.
        APPEND VALUE #( %tky = item-%tky ) TO failed-salesorderitem.
        APPEND VALUE #( %tky              = item-%tky
                        %state_area       = 'VALIDATE_QUANTITY'
                        %msg              = new_message_with_text(
                                              severity = if_abap_behv_message=>severity-error
                                              text     = '수량은 0보다 커야 합니다.' )
                        %element-Quantity = if_abap_behv=>mk-on
                        %path             = VALUE #( salesorder-%is_draft      = item-%is_draft
                                                     salesorder-SalesOrderUUID = item-ParentUUID ) )
             TO reported-salesorderitem.
      ENDIF.
    ENDLOOP.
  ENDMETHOD.

ENDCLASS.
