@AccessControl.authorizationCheck: #NOT_REQUIRED
@EndUserText.label: 'ERP BOM item per SBOM header + match key'
// SBOM 헤더 1건 범위에서 ERP 아이템의 매칭 키 결정
//   설명이 그 헤더의 SBOM SeqNo 중 하나와 같으면 → 그 SeqNo
//   아니면(빈 값, 수동 텍스트, 이전 revision seqno 등) → '#'+노드번호 (ERP_ONLY 로 각각 표시)
// "SBOM seqno 에 속하지 않는" 조건 = LEFT OUTER JOIN + IS NULL (CDS 에 NOT EXISTS/NOT IN 서브쿼리 없음)
define view entity ZI_ErpBomItemByHdr
  as select from ZI_SbomStatus as h
    inner join   ZI_ErpBomItem as e on  e.Material = h.Product
                                    and e.Plant    = h.Plant
    left outer to one join ZI_SbomItem as s
                                    on  s.IfKey       = h.IfKey
                                    and s.BomName     = h.BomName
                                    and s.HeaderSeqNo = h.SeqNo
                                    and s.CustId      = h.CustId
                                    and s.Product     = h.Product
                                    and s.Plant       = h.Plant
                                    and s.MatchKey    = e.ItemDescKey
{
  key h.IfKey,
  key h.BomName,
  key h.SeqNo       as HeaderSeqNo,
  key h.CustId,
  key h.Product,
  key h.Plant,
  key e.BillOfMaterialItemNodeNumber,
      cast( case when s.MatchKey is null
                 then concat( '#', e.BillOfMaterialItemNodeNumber )
                 else s.MatchKey
            end as abap.char(40) )  as MatchKey,
      e.BillOfMaterialItemNumber,
      e.BOMItemDescription,
      e.Component,
      e.ComponentOldId,
      e.ItemQuantity,
      e.ItemUnit
}
