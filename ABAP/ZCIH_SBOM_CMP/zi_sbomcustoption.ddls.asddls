@AccessControl.authorizationCheck: #NOT_REQUIRED
@EndUserText.label: 'SBOM header + custoption'
// 최신 revision 헤더만 + custoption 매핑 → ProductOldId = basicproductid || custoption
define view entity ZI_SbomCustOption
  as select from I_ztmrmd00090       as h
    inner join   ZI_SbomHdrLatestRev as r on  r.BomName     = h.BomName
                                          and r.ProcessCode = h.ProcessCode
                                          and r.Revision    = h.Revision
    inner join   I_ztmrmd00130       as c on  c.BasicProductId = h.BasicProductId
                                          and c.ProcessCode    = h.ProcessCode
{
  key h.IfKey,
  key h.BomName,
  key h.SeqNo,
  key c.CustId,
      h.FacId,
      h.BasicProductId,
      h.ProcessCode,
      h.Revision,
      c.CustOption,
      cast( concat( h.BasicProductId, c.CustOption ) as productoldid ) as ProductOldId
}
where h.UseYn = 'Y'
