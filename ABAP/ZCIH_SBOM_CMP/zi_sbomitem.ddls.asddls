@AccessControl.authorizationCheck: #NOT_REQUIRED
@EndUserText.label: 'SBOM item mapped to product'
define view entity ZI_SbomItem
  as select from I_ztmrmd00100 as i
    inner join   ZI_SbomStatus as h on  h.IfKey   = i.IfKey
                                    and h.BomName = i.BomName
                                    and h.SeqNo   = i.HeaderSeqNo
    left outer join I_Product  as comp on comp.ProductOldID = i.MaterialId
{
  key h.IfKey,
  key h.BomName,
  key i.HeaderSeqNo,
  key h.CustId,
  key h.Product,
  key h.Plant,
  key i.SeqNo,
  key cast( coalesce( comp.Product, '' ) as abap.char(40) )            as Component,
      // ERP 아이템번호(POSNR, CHAR4 '0010')와 맞추기 위한 정규화
      cast( lpad( cast( i.SeqNo as abap.char(4) ), 4, '0' ) as abap.char(4) ) as BomItemNumber,
      i.MaterialId,
      i.OperationId,
      cast( i.UseQty as abap.dec(13,3) )                                as UseQty,
      i.UseUnit
}
where i.UseYn = 'Y'
