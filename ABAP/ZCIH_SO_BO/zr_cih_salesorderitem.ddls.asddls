@AccessControl.authorizationCheck: #NOT_REQUIRED
@EndUserText.label: 'Sales Order Item'
@Metadata.ignorePropagatedAnnotations: true
define view entity ZR_CIH_SalesOrderItem
  as select from zat_cih_soi
  association to parent ZR_CIH_SalesOrder as _SalesOrder on $projection.ParentUUID = _SalesOrder.SalesOrderUUID
{
  key item_uuid             as ItemUUID,
      parent_uuid           as ParentUUID,
      item_no               as ItemNo,
      product_id            as ProductID,
      @Semantics.quantity.unitOfMeasure: 'QuantityUnit'
      quantity              as Quantity,
      quantity_unit         as QuantityUnit,
      @Semantics.amount.currencyCode: 'CurrencyCode'
      unit_price            as UnitPrice,
      @Semantics.amount.currencyCode: 'CurrencyCode'
      net_amount            as NetAmount,
      currency_code         as CurrencyCode,
      @Semantics.user.createdBy: true
      local_created_by      as LocalCreatedBy,
      @Semantics.systemDateTime.createdAt: true
      local_created_at      as LocalCreatedAt,
      @Semantics.user.localInstanceLastChangedBy: true
      local_last_changed_by as LocalLastChangedBy,
      @Semantics.systemDateTime.localInstanceLastChangedAt: true
      local_last_changed_at as LocalLastChangedAt,

      _SalesOrder
}
