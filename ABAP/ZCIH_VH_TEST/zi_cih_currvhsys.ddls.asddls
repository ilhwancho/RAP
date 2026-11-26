@AccessControl.authorizationCheck: #NOT_REQUIRED
@EndUserText.label: 'Currency VH, system field param (test)'
@ObjectModel.dataCategory: #VALUE_HELP
@Search.searchable: true
define view entity ZI_CIH_CurrVHSys
  with parameters
    @Environment.systemField: #SYSTEM_LANGUAGE
    P_Language : spras
  as select from I_CurrencyText
{
      @Search.defaultSearchElement: true
      @UI.lineItem: [{ position: 10 }]
  key Currency,
      @UI.lineItem: [{ position: 20 }]
      Language,
      @Search.defaultSearchElement: true
      @UI.lineItem: [{ position: 30 }]
      CurrencyName
}
where
  Language = $parameters.P_Language
