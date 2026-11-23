@AccessControl.authorizationCheck: #NOT_REQUIRED
@EndUserText.label: 'ERP BOM item (valid today)'
define view entity ZI_ErpBomItem
  as select from I_BOMComponentWithKeyDate( P_KeyDate: $session.system_date ) as c
    inner join   ZI_ErpBomHdr as h on  h.BillOfMaterial        = c.BillOfMaterial
                                   and h.BillOfMaterialVariant = c.BillOfMaterialVariant
{
  key h.Material,
  key h.Plant,
  key c.BillOfMaterialItemNodeNumber,
      cast( c.BillOfMaterialItemNumber as abap.char(4) )   as BomItemNumber,
      cast( c.BillOfMaterialComponent  as abap.char(40) )  as Component,
      cast( c.BillOfMaterialItemQuantity as abap.dec(13,3) ) as ItemQuantity,
      c.BillOfMaterialItemUnit                              as ItemUnit
}
where c.BillOfMaterialCategory = 'M'
