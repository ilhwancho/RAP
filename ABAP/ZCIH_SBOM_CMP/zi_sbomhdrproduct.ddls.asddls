@AccessControl.authorizationCheck: #NOT_REQUIRED
@EndUserText.label: 'SBOM header mapped to product'
// 같은 OldId 자재가 여럿이면 SBOM 헤더 1건 → Product 여러 건 (Product 를 키에 포함)
define view entity ZI_SbomHdrProduct
  as select from ZI_SbomCustOption as s
    inner join   I_Product         as p on p.ProductOldID = s.ProductOldId
{
  key s.IfKey,
  key s.BomName,
  key s.SeqNo,
  key s.CustId,
  key p.Product,
      s.ProductOldId,
      s.BasicProductId,
      s.ProcessCode,
      s.CustOption,
      s.Revision,
      s.FacId
}
