@EndUserText.label: '인터페이스 수신 대상 테이블'
@ObjectModel.query.implementedBy: 'ABAP:ZCL_CIH_IF_INFO_QUERY'
@Metadata.allowExtensions: true
define custom entity ZR_CIH_IF_TARGET
{
      @EndUserText.label: '인터페이스 ID'
  key IfId         : abap.char(20);
      @EndUserText.label: '테이블'
  key TableName    : abap.char(30);
      @EndUserText.label: '설명'
      Description  : abap.char(60);
      @EndUserText.label: '반영 방식'
      UpdateMethod : abap.char(20);
      @EndUserText.label: '주요 키'
      KeyFields    : abap.char(60);

      _Info        : association to parent ZR_CIH_IF_INFO on $projection.IfId = _Info.IfId;
}
