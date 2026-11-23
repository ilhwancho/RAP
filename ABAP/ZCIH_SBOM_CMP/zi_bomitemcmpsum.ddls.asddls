@AccessControl.authorizationCheck: #NOT_REQUIRED
@EndUserText.label: 'BOM item compare - summary per header'
define view entity ZI_BomItemCmpSum
  as select from ZI_BomItemCompare
{
  key IfKey,
  key BomName,
  key HeaderSeqNo,
  key CustId,
  key Product,
  key Plant,
      count( * )                                                          as ItemCount,
      sum( case when CompareStatus = 'MATCH'          then 1 else 0 end ) as MatchCount,
      sum( case when CompareStatus = 'SBOM_ONLY'      then 1 else 0 end ) as SbomOnlyCount,
      sum( case when CompareStatus = 'ERP_ONLY'       then 1 else 0 end ) as ErpOnlyCount,
      sum( case when CompareStatus = 'COMPONENT_DIFF' then 1 else 0 end ) as ComponentDiffCount,
      sum( case when CompareStatus = 'QTY_DIFF'       then 1 else 0 end ) as QtyDiffCount
}
group by IfKey, BomName, HeaderSeqNo, CustId, Product, Plant
