@AccessControl.authorizationCheck: #NOT_REQUIRED
@EndUserText.label: 'SBOM status (product x plant)'
define view entity ZI_SbomStatus
  as select from ZI_SbomHdrProduct as h
    cross join   I_Plant           as pl
{
  key h.IfKey,
  key h.BomName,
  key h.SeqNo,
  key h.CustId,
  key h.Product,
  key pl.Plant,
      h.ProductOldId,
      h.BasicProductId,
      h.ProcessCode,
      h.CustOption,
      h.Revision,
      h.FacId
}
where pl.Plant = '1010'          // TODO: 대상 플랜트로 제한
