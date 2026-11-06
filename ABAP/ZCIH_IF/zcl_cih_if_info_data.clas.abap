"! 인터페이스 수신 화면 표시값 (고정). query 클래스와 behavior read 에서 공용.
CLASS zcl_cih_if_info_data DEFINITION PUBLIC FINAL CREATE PUBLIC.
  PUBLIC SECTION.
    TYPES tt_info   TYPE STANDARD TABLE OF zr_cih_if_info   WITH EMPTY KEY.
    TYPES tt_target TYPE STANDARD TABLE OF zr_cih_if_target WITH EMPTY KEY.

    CONSTANTS c_if_id TYPE zr_cih_if_info-ifid VALUE 'IF_CBO_001'.

    CLASS-METHODS get_info   RETURNING VALUE(rt) TYPE tt_info.
    CLASS-METHODS get_target RETURNING VALUE(rt) TYPE tt_target.
ENDCLASS.

CLASS zcl_cih_if_info_data IMPLEMENTATION.
  METHOD get_info.
    rt = VALUE #( ( ifid           = c_if_id
                    ifname         = 'CBO 마스터 수신'
                    direction      = 'EAI → S/4HANA'
                    procmode       = '비동기'
                    triggermode    = '수동'
                    sendersystem   = 'EAI (사내 EAI 서버)'
                    receiveservice = 'ZAPI_CIH_CBO_O4 / receiveData'
                    targetcount    = 2
                    expectedvolume = 10000
                    owner          = '홍길동 (IT운영팀)'
                    procdetail     = 'EAI 접수 후 백그라운드 반영' ) ).
  ENDMETHOD.

  METHOD get_target.
    rt = VALUE #( ( ifid = c_if_id tablename = 'ZAT_A' description = 'CBO 헤더'
                    updatemethod = '전체 교체' keyfields = 'KEY_A1' )
                  ( ifid = c_if_id tablename = 'ZAT_B' description = 'CBO 상세'
                    updatemethod = '전체 교체' keyfields = 'KEY_A1, SEQ' ) ).
  ENDMETHOD.
ENDCLASS.
