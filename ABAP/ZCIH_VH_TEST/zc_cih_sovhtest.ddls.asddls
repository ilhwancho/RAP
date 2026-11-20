@AccessControl.authorizationCheck: #NOT_REQUIRED
@EndUserText.label: 'Sales Order VH test (OData V2)'
@Metadata.ignorePropagatedAnnotations: true
@UI.headerInfo: { typeName: 'Sales Order', typeNamePlural: 'Sales Orders' }
define view entity ZC_CIH_SOVHTest
  as select from ZR_CIH_SalesOrder
{
      @UI.hidden: true
  key SalesOrderUUID,
      @UI.lineItem: [{ position: 10 }]
      @UI.selectionField: [{ position: 10 }]
      SalesOrderID,
      @UI.lineItem: [{ position: 20 }]
      @UI.selectionField: [{ position: 20 }]
      @Consumption.valueHelpDefinition: [{ entity: { name: 'ZI_CIH_CurrencyVH_Test', element: 'Currency' },
                                           presentationVariantQualifier: 'SortDesc' }]
      CurrencyCode
}
