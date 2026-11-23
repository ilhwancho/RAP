@AccessControl.authorizationCheck: #NOT_REQUIRED
@EndUserText.label: 'ERP BOM item (valid today)'
// 아이템 설명(BOMItemDescription) = BOM 저장 시 넣은 SBOM SeqNo
// SBOM 과의 매칭 키 결정은 ZI_ErpBomItemByHdr 에서 (SBOM 헤더 범위 안티 조인)
define view entity ZI_ErpBomItem
  as select from I_BOMComponentWithKeyDate( P_KeyDate: $session.system_date ) as c
    inner join   ZI_ErpBomHdr as h on  h.BillOfMaterial        = c.BillOfMaterial
                                   and h.BillOfMaterialVariant = c.BillOfMaterialVariant
    left outer to one join I_Product as p on p.Product = c.BillOfMaterialComponent
{
  key h.Material,
  key h.Plant,
  key c.BillOfMaterialItemNodeNumber,
      cast( c.BOMItemDescription as abap.char(40) )      as ItemDescKey,
      c.BillOfMaterialItemNumber,
      c.BOMItemDescription,
      c.BillOfMaterialComponent                           as Component,
      p.ProductOldID                                      as ComponentOldId,
      cast( c.BillOfMaterialItemQuantity as abap.dec(13,3) ) as ItemQuantity,
      c.BillOfMaterialItemUnit                            as ItemUnit
}
where c.BillOfMaterialCategory = 'M'
