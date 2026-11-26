@AccessControl.authorizationCheck: #NOT_REQUIRED
@EndUserText.label: 'Currency VH with parameter (test)'
@ObjectModel.dataCategory: #VALUE_HELP
@Search.searchable: true
define view entity ZI_CIH_CurrVHParam
  with parameters
    P_MinDecimals : int1
  as select from I_Currency
{
      @Search.defaultSearchElement: true
      @UI.lineItem: [{ position: 10 }]
  key Currency,
      @UI.lineItem: [{ position: 20 }]
      Decimals,
      @UI.lineItem: [{ position: 30 }]
      CurrencyISOCode
}
where
  Decimals >= $parameters.P_MinDecimals
