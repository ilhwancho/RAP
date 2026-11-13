@AccessControl.authorizationCheck: #NOT_REQUIRED
@EndUserText.label: 'VH additionalBinding test'
@Metadata.ignorePropagatedAnnotations: true
define view entity ZC_CIH_VHTEST
  as select from I_ProductPlantBasic
{
      @UI.selectionField: [{ position: 10 }]
      @UI.lineItem: [{ position: 10 }]
      @Consumption.valueHelpDefinition: [{ entity: { name: 'I_PlantStdVH', element: 'Plant' } }]
  key Plant,

      @UI.selectionField: [{ position: 20 }]
      @UI.lineItem: [{ position: 20 }]
      @Consumption.valueHelpDefinition: [{
          entity: { name: 'I_ProductPlantStdVH', element: 'Product' },
          additionalBinding: [{ localElement: 'Plant',
                                element:      'Plant',
                                usage:        #FILTER_AND_DISPLAY }]
      }]
  key Product
}
