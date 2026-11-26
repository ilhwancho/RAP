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
      @Consumption.valueHelpDefinition: [{ entity: { name: 'ZI_CIH_CurrencyVH_Test', element: 'Currency' } }]
      CurrencyCode,
      // parameterized VH tests
      @UI.selectionField: [{ position: 30 }]
      @EndUserText.label: 'Curr (param=const 3)'
      @Consumption.valueHelpDefinition: [{ entity: { name: 'ZI_CIH_CurrVHParam', element: 'Currency' },
                                           additionalBinding: [{ parameter: 'P_MinDecimals', localConstant: '3' }] }]
      CurrencyCode                as CurrConst,
      @UI.selectionField: [{ position: 40 }]
      @EndUserText.label: 'Min decimals'
      cast( 0 as int1 )    as MinDecimals,
      @UI.selectionField: [{ position: 50 }]
      @EndUserText.label: 'Curr (param=local element)'
      @Consumption.valueHelpDefinition: [{ entity: { name: 'ZI_CIH_CurrVHParam', element: 'Currency' },
                                           additionalBinding: [{ parameter: 'P_MinDecimals', localElement: 'MinDecimals' }] }]
      CurrencyCode                as CurrElem,
      @UI.selectionField: [{ position: 60 }]
      @EndUserText.label: 'Curr (param=system field)'
      @Consumption.valueHelpDefinition: [{ entity: { name: 'ZI_CIH_CurrVHSys', element: 'Currency' } }]
      CurrencyCode                as CurrSys,
      @UI.selectionField: [{ position: 70 }]
      @EndUserText.label: 'Curr (param unbound)'
      @Consumption.valueHelpDefinition: [{ entity: { name: 'ZI_CIH_CurrVHParam', element: 'Currency' } }]
      CurrencyCode                as CurrNone
}
