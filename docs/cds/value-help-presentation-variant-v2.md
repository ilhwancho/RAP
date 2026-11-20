# Value help sort with UI.presentationVariant (OData V2)

Checked 2026-11-20: Z5U (Release 920) SADL source and SAPUI5 1.154 `sap.ui.comp` source.

## Conclusion
| What | V2 support |
|---|---|
| `@Consumption.valueHelpDefinition.presentationVariantQualifier` → `Common.ValueList/PresentationVariantQualifier` in `$metadata` | ✅ emitted (`CL_SADL_GW_VOCAN_EXPOSURE`, `_add_value_list`-ish code ~line 1521) |
| `@UI.presentationVariant` (qualifier, sortOrder) on the VH entity → `UI.PresentationVariant` | ✅ emitted (`CL_SADL_GW_VOCAN_PRESNT_VAR`) |
| V2 front end, **type-ahead suggestions / dropdown (ComboBox, fixed values)** | ✅ sorted by the PV (`sap.ui.comp.providers.ValueListProvider._handlePresentationVariantSortOrderAnnotation`) |
| V2 front end, **value help dialog (VHD) table** | ❌ ignores the PV. Always sorts by the key field ascending (`ValueHelpProvider` → `new Sorter(this.sKey)`) |

## UI5 V2 (sap.ui.comp) details
- The `PresentationVariantQualifier` in the ValueList is **not** used to look up the PV.
  `MetadataAnalyser._getPresentationVariantQualifierForVHD` takes the qualifier from a `UI.PresentationVariant#<q>` it finds on the VH entity type.
  If several qualified PVs exist, the last one found wins. If none is qualified, the unqualified PV is used.
- Only `sortOrderFields[0]` (the first sortOrder entry) is used.
- The sort property must be (a) a property of the VH entity type and (b) sortable and part of the ValueList fields. Otherwise UI5 writes `Log.error("ValueListProvider", ...)` and does not sort.
- A ValueList that has a PresentationVariantQualifier goes into the `...WithPVQualifier` bucket in MetadataAnalyser. BaseValueListProvider merges that bucket back in, so the value help itself still works.

## Example
```cds
@UI.presentationVariant: [{ qualifier: 'DefaultSort',
                            sortOrder: [{ by: 'CustomerName', direction: #ASC }] }]
define view entity ZI_XXX_Customer_VH as select from I_Customer { key Customer, CustomerName }

-- consumer
@Consumption.valueHelpDefinition: [{ entity: { name: 'ZI_XXX_Customer_VH', element: 'Customer' },
                                     presentationVariantQualifier: 'DefaultSort' }]
CustomerID,
```
