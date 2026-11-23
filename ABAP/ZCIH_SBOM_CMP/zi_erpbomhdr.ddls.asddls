@AccessControl.authorizationCheck: #NOT_REQUIRED
@EndUserText.label: 'ERP BOM header (compare scope)'
// 사용 중인 ERP 헤더 뷰(I_BomCurrentDate 등)로 바꿔도 됨. Material + Plant 당 1건이 되도록 제한
define view entity ZI_ErpBomHdr
  as select from I_MaterialBOMLink
{
  key Material,
  key Plant,
      BillOfMaterial,
      BillOfMaterialVariant,
      BillOfMaterialVariantUsage
}
where BillOfMaterialVariantUsage = '1'
  and BillOfMaterialVariant      = '01'
