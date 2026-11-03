@EndUserText.label : 'Sales Order Header - Draft'
@AbapCatalog.enhancement.category : #EXTENSIBLE_ANY
@AbapCatalog.tableCategory : #TRANSPARENT
@AbapCatalog.deliveryClass : #A
@AbapCatalog.dataMaintenance : #RESTRICTED
define table zdt_cih_soh {

  key mandt          : mandt not null;
  key salesorderuuid : sysuuid_x16 not null;
  salesorderid       : abap.char(10);
  customerid         : abap.char(10);
  description        : abap.char(80);
  orderdate          : abap.dats;
  deliverydate       : abap.dats;
  overallstatus      : abap.char(1);
  @Semantics.amount.currencyCode : 'zdt_cih_soh.currencycode'
  totalamount        : abap.curr(15,2);
  currencycode       : abap.cuky;
  localcreatedby     : abp_creation_user;
  localcreatedat     : abp_creation_tstmpl;
  locallastchangedby : abp_locinst_lastchange_user;
  locallastchangedat : abp_locinst_lastchange_tstmpl;
  lastchangedat      : abp_lastchange_tstmpl;
  "%admin"           : include sych_bdl_draft_admin_inc;

}
