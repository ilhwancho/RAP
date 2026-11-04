@AccessControl.authorizationCheck: #NOT_REQUIRED
@EndUserText.label: 'Sales Order - Projection'
@Metadata.allowExtensions: true
@Search.searchable: true
@ObjectModel.semanticKey: ['SalesOrderID']
define root view entity ZC_CIH_SalesOrder
  provider contract transactional_query
  as projection on ZR_CIH_SalesOrder
{
  key SalesOrderUUID,
      @Search.defaultSearchElement: true
      SalesOrderID,
      @Search.defaultSearchElement: true
      @Consumption.valueHelpDefinition: [{ entity: { name: 'I_Customer_VH', element: 'Customer' } }]
      CustomerID,
      @Search.defaultSearchElement: true
      Description,
      OrderDate,
      DeliveryDate,
      OverallStatus,
      @Semantics.amount.currencyCode: 'CurrencyCode'
      TotalAmount,
      @Consumption.valueHelpDefinition: [{ entity: { name: 'I_CurrencyStdVH', element: 'Currency' }, useForValidation: true }]
      CurrencyCode,
      LocalCreatedBy,
      LocalCreatedAt,
      LocalLastChangedBy,
      LocalLastChangedAt,
      LastChangedAt,

      _Item : redirected to composition child ZC_CIH_SalesOrderItem
}
