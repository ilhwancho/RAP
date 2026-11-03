@EndUserText.label : 'Sales Order Item - Draft'
@AbapCatalog.enhancement.category : #EXTENSIBLE_ANY
@AbapCatalog.tableCategory : #TRANSPARENT
@AbapCatalog.deliveryClass : #A
@AbapCatalog.dataMaintenance : #RESTRICTED
define table zdt_cih_soi {

  key mandt          : mandt not null;
  key itemuuid       : sysuuid_x16 not null;
  parentuuid         : sysuuid_x16;
  itemno             : abap.numc(6);
  productid          : abap.char(40);
  @Semantics.quantity.unitOfMeasure : 'zdt_cih_soi.quantityunit'
  quantity           : abap.quan(13,3);
  quantityunit       : abap.unit(3);
  @Semantics.amount.currencyCode : 'zdt_cih_soi.currencycode'
  unitprice          : abap.curr(15,2);
  @Semantics.amount.currencyCode : 'zdt_cih_soi.currencycode'
  netamount          : abap.curr(15,2);
  currencycode       : abap.cuky;
  localcreatedby     : abp_creation_user;
  localcreatedat     : abp_creation_tstmpl;
  locallastchangedby : abp_locinst_lastchange_user;
  locallastchangedat : abp_locinst_lastchange_tstmpl;
  "%admin"           : include sych_bdl_draft_admin_inc;

}
