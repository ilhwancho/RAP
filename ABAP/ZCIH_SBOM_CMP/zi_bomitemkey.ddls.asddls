@AccessControl.authorizationCheck: #NOT_REQUIRED
@EndUserText.label: 'BOM item compare - key union'
// SBOM 헤더 1건 범위 안에서: SBOM 아이템 키 ∪ (그 헤더의 Product/Plant 에 해당하는) ERP 아이템 키
// UNION (ALL 없음) → 양쪽에 모두 있는 아이템은 1행으로 중복 제거
define view entity ZI_BomItemKey
  as select from ZI_SbomItem
{
  key IfKey,
  key BomName,
  key HeaderSeqNo,
  key CustId,
  key Product,
  key Plant,
  key BomItemNumber,
  key Component
}
union
  select from ZI_SbomStatus as h
    inner join ZI_ErpBomItem as e on  e.Material = h.Product
                                  and e.Plant    = h.Plant
{
  key h.IfKey,
  key h.BomName,
  key h.SeqNo       as HeaderSeqNo,
  key h.CustId,
  key h.Product,
  key h.Plant,
  key e.BomItemNumber,
  key e.Component
}
