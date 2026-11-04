@AccessControl.authorizationCheck: #NOT_REQUIRED
@EndUserText.label: 'Sales Order Item - Projection'
@Metadata.allowExtensions: true
@ObjectModel.semanticKey: ['ItemNo']
define view entity ZC_CIH_SalesOrderItem
  as projection on ZR_CIH_SalesOrderItem
{
  key ItemUUID,
      ParentUUID,
      ItemNo,
      ProductID,
      @Semantics.quantity.unitOfMeasure: 'QuantityUnit'
      Quantity,
      @Consumption.valueHelpDefinition: [{ entity: { name: 'I_UnitOfMeasureStdVH', element: 'UnitOfMeasure' }, useForValidation: true }]
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

      _SalesOrder : redirected to parent ZC_CIH_SalesOrder
}
