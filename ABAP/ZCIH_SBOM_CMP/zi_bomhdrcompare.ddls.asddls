@AccessControl.authorizationCheck: #NOT_REQUIRED
@EndUserText.label: 'SBOM vs ERP BOM header compare'
// SBOM 기준: SBOM 헤더는 모두 표시, ERP BOM 은 있으면 매핑
define view entity ZI_BomHdrCompare
  as select from ZI_SbomStatus as s
    left outer to one join ZI_ErpBomHdr     as e on  e.Material = s.Product
                                                 and e.Plant    = s.Plant
    left outer to one join ZI_BomItemCmpSum as c on  c.IfKey       = s.IfKey
                                                 and c.BomName     = s.BomName
                                                 and c.HeaderSeqNo = s.SeqNo
                                                 and c.CustId      = s.CustId
                                                 and c.Product     = s.Product
                                                 and c.Plant       = s.Plant
  association [0..*] to ZI_BomItemCompare as _Item
    on  _Item.IfKey       = $projection.IfKey
    and _Item.BomName     = $projection.BomName
    and _Item.HeaderSeqNo = $projection.SeqNo
    and _Item.CustId      = $projection.CustId
    and _Item.Product     = $projection.Product
    and _Item.Plant       = $projection.Plant
{
  key s.IfKey,
  key s.BomName,
  key s.SeqNo,
  key s.CustId,
  key s.Product,
  key s.Plant,

      // SBOM
      s.BasicProductId,
      s.ProcessCode,
      s.Revision,
      s.CustOption,
      s.ProductOldId,

      // ERP
      e.BillOfMaterial         as ErpBillOfMaterial,
      e.BillOfMaterialVariant  as ErpBomVariant,

      // 아이템 요약
      c.ItemCount,
      c.MatchCount,
      c.SbomOnlyCount,
      c.ErpOnlyCount,
      c.QtyDiffCount,

      case
        when e.Material is null                       then 'ERP_BOM_MISSING'
        when c.SbomOnlyCount + c.ErpOnlyCount
           + c.QtyDiffCount > 0                       then 'ITEM_DIFF'
        else 'MATCH'
      end as HeaderStatus,

      case
        when e.Material is null                       then 1
        when c.SbomOnlyCount + c.ErpOnlyCount
           + c.QtyDiffCount > 0                       then 2
        else 3
      end as HeaderCriticality,

      _Item
}
