"! ZR_CIH_IF_INFO / ZR_CIH_IF_TARGET 공용 unmanaged query
CLASS zcl_cih_if_info_query DEFINITION PUBLIC FINAL CREATE PUBLIC.
  PUBLIC SECTION.
    INTERFACES if_rap_query_provider.
ENDCLASS.

CLASS zcl_cih_if_info_query IMPLEMENTATION.
  METHOD if_rap_query_provider~select.
    " 요청된 paging/sort/filter 는 꺼내 줘야 함 (안 꺼내면 런타임 오류 가능)
    " 건수가 1~2건이라 실제 적용은 하지 않음
    DATA(lv_skip) = io_request->get_paging( )->get_offset( ).
    DATA(lv_top)  = io_request->get_paging( )->get_page_size( ).
    DATA(lt_sort) = io_request->get_sort_elements( ).
    TRY.
        DATA(lt_ranges) = io_request->get_filter( )->get_as_ranges( ).
      CATCH cx_rap_query_filter_no_range ##NO_HANDLER.
    ENDTRY.

    CASE io_request->get_entity_id( ).
      WHEN 'ZR_CIH_IF_INFO'.
        DATA(lt_info) = zcl_cih_if_info_data=>get_info( ).
        IF io_request->is_total_numb_of_rec_requested( ).
          io_response->set_total_number_of_records( lines( lt_info ) ).
        ENDIF.
        IF io_request->is_data_requested( ).
          io_response->set_data( lt_info ).
        ENDIF.

      WHEN 'ZR_CIH_IF_TARGET'.
        DATA(lt_target) = zcl_cih_if_info_data=>get_target( ).
        IF io_request->is_total_numb_of_rec_requested( ).
          io_response->set_total_number_of_records( lines( lt_target ) ).
        ENDIF.
        IF io_request->is_data_requested( ).
          io_response->set_data( lt_target ).
        ENDIF.
    ENDCASE.
  ENDMETHOD.
ENDCLASS.
