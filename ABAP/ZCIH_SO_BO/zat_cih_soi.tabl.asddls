@EndUserText.label : 'Sales Order Item'
@AbapCatalog.enhancement.category : #NOT_EXTENSIBLE
@AbapCatalog.tableCategory : #TRANSPARENT
@AbapCatalog.deliveryClass : #A
@AbapCatalog.dataMaintenance : #RESTRICTED
define table zat_cih_soi {

  key client            : abap.clnt not null;
  key item_uuid         : sysuuid_x16 not null;
  parent_uuid           : sysuuid_x16;
  item_no               : abap.numc(6);
  product_id            : abap.char(40);
  @Semantics.quantity.unitOfMeasure : 'zat_cih_soi.quantity_unit'
  quantity              : abap.quan(13,3);
  quantity_unit         : abap.unit(3);
  @Semantics.amount.currencyCode : 'zat_cih_soi.currency_code'
  unit_price            : abap.curr(15,2);
  @Semantics.amount.currencyCode : 'zat_cih_soi.currency_code'
  net_amount            : abap.curr(15,2);
  currency_code         : abap.cuky;
  local_created_by      : abp_creation_user;
  local_created_at      : abp_creation_tstmpl;
  local_last_changed_by : abp_locinst_lastchange_user;
  local_last_changed_at : abp_locinst_lastchange_tstmpl;

}
