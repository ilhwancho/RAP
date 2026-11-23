@AccessControl.authorizationCheck: #NOT_REQUIRED
@EndUserText.label: 'SBOM vs ERP BOM item compare'
define view entity ZI_BomItemCompare
  as select from ZI_BomItemKey as k
    left outer to one join ZI_SbomItem as s
      on  s.IfKey       = k.IfKey
      and s.BomName     = k.BomName
      and s.HeaderSeqNo = k.HeaderSeqNo
      and s.CustId      = k.CustId
      and s.Product     = k.Product
      and s.Plant       = k.Plant
      and s.MatchKey    = k.MatchKey
    left outer to one join ZI_ErpBomItemByHdr as e
      on  e.IfKey       = k.IfKey
      and e.BomName     = k.BomName
      and e.HeaderSeqNo = k.HeaderSeqNo
      and e.CustId      = k.CustId
      and e.Product     = k.Product
      and e.Plant       = k.Plant
      and e.MatchKey    = k.MatchKey
{
  key k.IfKey,
  key k.BomName,
  key k.HeaderSeqNo,
  key k.CustId,
  key k.Product,
  key k.Plant,
  key k.MatchKey,

      // SBOM
      s.SeqNo                        as SbomSeqNo,
      s.MaterialId                   as SbomMaterialId,
      s.OperationId                  as SbomOperationId,
      s.UseQty                       as SbomQuantity,
      s.UseUnit                      as SbomUnit,

      // ERP
      e.BillOfMaterialItemNodeNumber as ErpItemNode,
      e.BillOfMaterialItemNumber     as ErpItemNumber,
      e.BOMItemDescription           as ErpItemDescription,
      e.Component                    as ErpComponent,
      e.ComponentOldId               as ErpComponentOldId,
      e.ItemQuantity                 as ErpQuantity,
      e.ItemUnit                     as ErpUnit,

      case
        when s.MatchKey is null                 then 'ERP_ONLY'
        when e.MatchKey is null                 then 'SBOM_ONLY'
        when s.MaterialId <> e.ComponentOldId
          or e.ComponentOldId is null           then 'COMPONENT_DIFF'
        when s.UseQty <> e.ItemQuantity         then 'QTY_DIFF'
        else 'MATCH'
      end as CompareStatus,

      case
        when s.MatchKey is null or e.MatchKey is null then 1
        when s.MaterialId <> e.ComponentOldId
          or e.ComponentOldId is null                 then 1
        when s.UseQty <> e.ItemQuantity               then 2
        else 3
      end as CompareCriticality
}
