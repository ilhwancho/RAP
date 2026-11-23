@AccessControl.authorizationCheck: #NOT_REQUIRED
@EndUserText.label: 'SBOM vs ERP BOM item compare'
define view entity ZI_BomItemCompare
  as select from ZI_BomItemKey as k
    left outer to one join ZI_SbomItem as s
      on  s.IfKey         = k.IfKey
      and s.BomName       = k.BomName
      and s.HeaderSeqNo   = k.HeaderSeqNo
      and s.CustId        = k.CustId
      and s.Product       = k.Product
      and s.Plant         = k.Plant
      and s.BomItemNumber = k.BomItemNumber
      and s.Component     = k.Component
    left outer to one join ZI_ErpBomItem as e
      on  e.Material      = k.Product
      and e.Plant         = k.Plant
      and e.BomItemNumber = k.BomItemNumber
      and e.Component     = k.Component
{
  key k.IfKey,
  key k.BomName,
  key k.HeaderSeqNo,
  key k.CustId,
  key k.Product,
  key k.Plant,
  key k.BomItemNumber,
  key k.Component,

      // SBOM
      s.SeqNo         as SbomSeqNo,
      s.MaterialId    as SbomMaterialId,
      s.OperationId   as SbomOperationId,
      s.UseQty        as SbomQuantity,
      s.UseUnit       as SbomUnit,

      // ERP
      e.BillOfMaterialItemNodeNumber as ErpItemNode,
      e.ItemQuantity  as ErpQuantity,
      e.ItemUnit      as ErpUnit,

      case
        when s.SeqNo is null                        then 'ERP_ONLY'
        when e.BillOfMaterialItemNodeNumber is null then 'SBOM_ONLY'
        when s.UseQty <> e.ItemQuantity             then 'QTY_DIFF'
        else 'MATCH'
      end as CompareStatus,

      case
        when s.SeqNo is null or e.BillOfMaterialItemNodeNumber is null then 1
        when s.UseQty <> e.ItemQuantity                                then 2
        else 3
      end as CompareCriticality
}
