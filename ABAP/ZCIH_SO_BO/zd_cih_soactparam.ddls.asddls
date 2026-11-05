@EndUserText.label: 'Sales Order - Action Parameter'
define root abstract entity ZD_CIH_SOActParam
{
  @Semantics.quantity.unitOfMeasure: 'QuantityUnit'
  Quantity     : abap.quan(13,3);
  QuantityUnit : abap.unit(3);
  Remark       : abap.char(40);
}
