@EndUserText.label: '인터페이스 정보'
@ObjectModel.query.implementedBy: 'ABAP:ZCL_CIH_IF_INFO_QUERY'
@Metadata.allowExtensions: true
define root custom entity ZR_CIH_IF_INFO
{
      @EndUserText.label: '인터페이스 ID'
  key IfId           : abap.char(20);
      @EndUserText.label: '인터페이스명'
      IfName         : abap.char(60);
      @EndUserText.label: '방향'
      Direction      : abap.char(30);
      @EndUserText.label: '처리 방식'
      ProcMode       : abap.char(20);
      @EndUserText.label: '실행 방식'
      TriggerMode    : abap.char(20);
      @EndUserText.label: '송신 시스템'
      SenderSystem   : abap.char(40);
      @EndUserText.label: '수신 서비스'
      ReceiveService : abap.char(60);
      @EndUserText.label: '대상 테이블 수'
      TargetCount    : abap.int4;
      @EndUserText.label: '예상 처리량(건/회)'
      ExpectedVolume : abap.int4;
      @EndUserText.label: '담당자'
      Owner          : abap.char(40);
      @EndUserText.label: '처리 상세'
      ProcDetail     : abap.char(80);

      _Target        : composition [0..*] of ZR_CIH_IF_TARGET;
}
