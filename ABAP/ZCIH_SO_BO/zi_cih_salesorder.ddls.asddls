@AccessControl.authorizationCheck: #NOT_REQUIRED
@EndUserText.label: 'Sales Order - Interface'
@Metadata.ignorePropagatedAnnotations: true
define root view entity ZI_CIH_SalesOrder
  provider contract transactional_interface
  as projection on ZR_CIH_SalesOrder
{
  key SalesOrderUUID,
      SalesOrderID,
      CustomerID,
      Description,
      OrderDate,
      DeliveryDate,
      OverallStatus,
      @Semantics.amount.currencyCode: 'CurrencyCode'
      TotalAmount,
      CurrencyCode,
      LocalCreatedBy,
      LocalCreatedAt,
      LocalLastChangedBy,
      LocalLastChangedAt,
      LastChangedAt,

      _Item : redirected to composition child ZI_CIH_SalesOrderItem
}
