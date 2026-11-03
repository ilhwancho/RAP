@AccessControl.authorizationCheck: #NOT_REQUIRED
@EndUserText.label: 'Sales Order Item - Interface'
@Metadata.ignorePropagatedAnnotations: true
define view entity ZI_CIH_SalesOrderItem
  as projection on ZR_CIH_SalesOrderItem
{
  key ItemUUID,
      ParentUUID,
      ItemNo,
      ProductID,
      @Semantics.quantity.unitOfMeasure: 'QuantityUnit'
      Quantity,
      QuantityUnit,
      @Semantics.amount.currencyCode: 'CurrencyCode'
      UnitPrice,
      @Semantics.amount.currencyCode: 'CurrencyCode'
      NetAmount,
      CurrencyCode,
      LocalCreatedBy,
      LocalCreatedAt,
      LocalLastChangedBy,
      LocalLastChangedAt,

      _SalesOrder : redirected to parent ZI_CIH_SalesOrder
}
