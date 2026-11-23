@AccessControl.authorizationCheck: #NOT_REQUIRED
@EndUserText.label: 'SBOM header - latest revision'
// bomname + processcode 별 최신 revision
define view entity ZI_SbomHdrLatestRev
  as select from I_ztmrmd00090
{
  key BomName,
  key ProcessCode,
      max( Revision ) as Revision
}
where UseYn = 'Y'
group by BomName, ProcessCode
