@AccessControl.authorizationCheck: #NOT_REQUIRED
@EndUserText.label: 'ERP BOM item (valid today)'
// 매칭 키 = BOMItemDescription (BOM 저장 시 SBOM SeqNo 를 넣은 값)
//   설명이 비어 있는 아이템(수동 추가 등)은 '#'+노드번호로 대체 → UNION 에서 서로 합쳐지지 않게
define view entity ZI_ErpBomItem
  as select from I_BOMComponentWithKeyDate( P_KeyDate: $session.system_date ) as c
    inner join   ZI_ErpBomHdr as h on  h.BillOfMaterial        = c.BillOfMaterial
                                   and h.BillOfMaterialVariant = c.BillOfMaterialVariant
    left outer to one join I_Product as p on p.Product = c.BillOfMaterialComponent
{
  key h.Material,
  key h.Plant,
  key c.BillOfMaterialItemNodeNumber,
      cast( case when c.BOMItemDescription = ''
                 then concat( '#', c.BillOfMaterialItemNodeNumber )
                 else c.BOMItemDescription
            end as abap.char(40) )                        as MatchKey,
      c.BillOfMaterialItemNumber,
      c.BOMItemDescription,
      c.BillOfMaterialComponent                           as Component,
      p.ProductOldID                                      as ComponentOldId,
      cast( c.BillOfMaterialItemQuantity as abap.dec(13,3) ) as ItemQuantity,
      c.BillOfMaterialItemUnit                            as ItemUnit
}
where c.BillOfMaterialCategory = 'M'
