@Metadata.ignorePropagatedAnnotations: true
@AccessControl.authorizationCheck: #NOT_REQUIRED
@EndUserText.label: 'BOM item compare - key union'
// SBOM 헤더 1건 범위 안에서: SBOM 아이템 키(SeqNo) ∪ ERP 아이템 키(ZI_ErpBomItemByHdr.MatchKey)
// UNION (ALL 없음) → 모든 열(=키)이 같은 행, 즉 양쪽에 모두 있는 아이템은 1행
define view entity ZI_BomItemKey
  as select from ZI_SbomItem
{
  key IfKey,
  key BomName,
  key HeaderSeqNo,
  key CustId,
  key Product,
  key Plant,
  key MatchKey
}
union
  select from ZI_ErpBomItemByHdr
{
  key IfKey,
  key BomName,
  key HeaderSeqNo,
  key CustId,
  key Product,
  key Plant,
  key MatchKey
}
