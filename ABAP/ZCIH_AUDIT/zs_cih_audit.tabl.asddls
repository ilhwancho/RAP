@EndUserText.label : 'Audit fields (include structure)'
@AbapCatalog.enhancement.category : #NOT_EXTENSIBLE
define structure zs_cih_audit {
  created_by : abp_creation_user;
  created_at : abp_creation_tstmpl;
  changed_by : abp_lastchange_user;
  changed_at : abp_lastchange_tstmpl;
}
