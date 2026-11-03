@EndUserText.label : 'Sales Order Header'
@AbapCatalog.enhancement.category : #NOT_EXTENSIBLE
@AbapCatalog.tableCategory : #TRANSPARENT
@AbapCatalog.deliveryClass : #A
@AbapCatalog.dataMaintenance : #RESTRICTED
define table zat_cih_soh {

  key client            : abap.clnt not null;
  key sales_order_uuid  : sysuuid_x16 not null;
  sales_order_id        : abap.char(10);
  customer_id           : abap.char(10);
  description           : abap.char(80);
  order_date            : abap.dats;
  delivery_date         : abap.dats;
  overall_status        : abap.char(1);
  @Semantics.amount.currencyCode : 'zat_cih_soh.currency_code'
  total_amount          : abap.curr(15,2);
  currency_code         : abap.cuky;
  local_created_by      : abp_creation_user;
  local_created_at      : abp_creation_tstmpl;
  local_last_changed_by : abp_locinst_lastchange_user;
  local_last_changed_at : abp_locinst_lastchange_tstmpl;
  last_changed_at       : abp_lastchange_tstmpl;

}
