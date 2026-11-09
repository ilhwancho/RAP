@EndUserText.label : 'Customer Credit Limit (demo)'
@AbapCatalog.enhancement.category : #NOT_EXTENSIBLE
@AbapCatalog.tableCategory : #TRANSPARENT
@AbapCatalog.deliveryClass : #A
@AbapCatalog.dataMaintenance : #RESTRICTED
define table zat_cih_crlim {

  key client      : abap.clnt not null;
  key customer_id : abap.char(10) not null;
  @Semantics.amount.currencyCode : 'zat_cih_crlim.currency_code'
  credit_limit    : abap.curr(15,2);
  currency_code   : abap.cuky;

}
