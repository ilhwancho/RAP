@AccessControl.authorizationCheck: #NOT_REQUIRED
@EndUserText.label: 'Sales Order - Root'
@Metadata.ignorePropagatedAnnotations: true
define root view entity ZR_CIH_SalesOrder
  as select from zat_cih_soh
  composition [0..*] of ZR_CIH_SalesOrderItem as _Item
{
  key sales_order_uuid      as SalesOrderUUID,
      sales_order_id        as SalesOrderID,
      customer_id           as CustomerID,
      description           as Description,
      order_date            as OrderDate,
      delivery_date         as DeliveryDate,
      overall_status        as OverallStatus,
      @Semantics.amount.currencyCode: 'CurrencyCode'
      total_amount          as TotalAmount,
      currency_code         as CurrencyCode,
      @Semantics.user.createdBy: true
      local_created_by      as LocalCreatedBy,
      @Semantics.systemDateTime.createdAt: true
      local_created_at      as LocalCreatedAt,
      @Semantics.user.localInstanceLastChangedBy: true
      local_last_changed_by as LocalLastChangedBy,
      @Semantics.systemDateTime.localInstanceLastChangedAt: true
      local_last_changed_at as LocalLastChangedAt,
      @Semantics.systemDateTime.lastChangedAt: true
      last_changed_at       as LastChangedAt,

      _Item
}
