@AccessControl.authorizationCheck: #NOT_REQUIRED
@EndUserText.label: 'SBOM item (per SBOM header x plant)'
// 매칭 키 = SeqNo (S시스템 아이템 일련번호, CHAR20)
//   ERP BOM 저장 시 SeqNo 를 아이템 설명(BOMItemDescription, POTX1)에 넣으므로 그 값과 1:1 매칭
// 구성품목은 I_Product 로 매핑하지 않음 (OldId 중복 시 행이 늘어나 키가 깨지므로)
//   → 비교는 ERP 구성품목의 ProductOldID 와 MaterialId 로
define view entity ZI_SbomItem
  as select from I_ztmrmd00100 as i
    inner join   ZI_SbomStatus as h on  h.IfKey   = i.IfKey
                                    and h.BomName = i.BomName
                                    and h.SeqNo   = i.HeaderSeqNo
{
  key h.IfKey,
  key h.BomName,
  key i.HeaderSeqNo,
  key h.CustId,
  key h.Product,
  key h.Plant,
  key cast( i.SeqNo as abap.char(40) )  as MatchKey,
      i.SeqNo,
      i.MaterialId,
      i.OperationId,
      cast( i.UseQty as abap.dec(13,3) ) as UseQty,
      i.UseUnit
}
where i.UseYn = 'Y'
