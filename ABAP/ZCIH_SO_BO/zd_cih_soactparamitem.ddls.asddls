@EndUserText.label: 'Sales Order - Action Parameter Item'
define abstract entity ZD_CIH_SOActParamItem
{
  ItemNo    : abap.numc(6);
  ProductID : abap.char(40);
  _Header   : association to parent ZD_CIH_SOActParam;
}
