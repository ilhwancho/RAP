@AccessControl.authorizationCheck: #NOT_REQUIRED
@EndUserText.label: 'Currency VH (PV sort test)'
@ObjectModel.dataCategory: #VALUE_HELP
@Search.searchable: true
@ObjectModel.resultSet.sizeCategory: #XS
@UI.presentationVariant: [{ qualifier: 'SortDesc',
                            sortOrder: [{ by: 'Currency', direction: #DESC }],
                            visualizations: [{ type: #AS_LINEITEM }] }]
define view entity ZI_CIH_CurrencyVH_Test
  as select from I_Currency
{
      @Search.defaultSearchElement: true
      @UI.lineItem: [{ position: 10 }]
  key Currency,
      @UI.lineItem: [{ position: 20 }]
      Decimals,
      @Search.defaultSearchElement: true
      @UI.lineItem: [{ position: 30 }]
      CurrencyISOCode
}
