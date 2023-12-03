
Add-Type @'
public class myBom
{
	public string Position;
	public string PartNumber;
	public string ComponentType;
	public float Quantity;
	public string Name;
	public byte[] Thumbnail;
	public string Title;
	public string Description;
	public string Material;
}
'@

function GetFileBOM($fileID)
{
	#Get Thumbnail PropertyDefinition 
	$propDefs = $vault.PropertyService.GetPropertyDefinitionsByEntityClassId('FILE')
	$thumbnailPropDef = $propDefs | Where-Object {$_.SysName -eq 'Thumbnail'}

	$dsDiag.Trace(">> Starting GetFileBOM($fileID)")
	$bom = $vault.DocumentService.GetBOMByFileId($fileID)
	$cldIds =@()
	$bom.InstArray | Where-Object { $_.ParId -eq 0 } | ForEach-Object { 
		$CldId = $_.CldId
		$comp = $bom.CompArray | Where-Object { $_.Id -eq $CldId }
		if ($comp.XRefId -ne -1) {
			$cldIds += $comp.XRefId
		}
	}
	$dsDiag.Trace("   cldIds: "+$cldIds.Count)
	$bomItems = @()
	if($cldIds.Count -gt 0) #the file contains BOM information, so continue
	{
		$CldBoms = $vault.DocumentService.GetBOMByFileIds($cldIds)
		$schm = $bom.SchmArray | Where-Object { $_.SchmTyp -eq "Structured" -and $_.RootCompId -eq 0}
		$cldBomCounter = 0

		$bom.InstArray | Where-Object { $_.ParId -eq 0 } | ForEach-Object {
			$bomItem = New-Object myBom
			$CldId = $_.CldId
            if ($_.QuantOverde -eq -1)
			{
                $bomItem.Quantity = $_.Quant
            }
            else {
                $bomItem.Quantity = $_.QuantOverde
            }
			$comp = $bom.CompArray | Where-Object { $_.Id -eq $CldId }

			$occur = $bom.SchmOccArray | Where-Object { $_.SchmId -eq $schm.Id -and $_.CompId -eq $CldId }
			$bomItem.Position = $occur.DtlId

			if ($comp.XRefId -eq -1) {
				$cldBom = $bom
			}
			else {
				$cldBom = $CldBoms[$cldBomCounter++]
			}
			$UniqueId = $comp.UniqueId
			#find component in current file bom only
			$cldComp = $cldBom.CompArray | Where-Object { $_.UniqueId -eq $UniqueId -and $_.XRefId -eq -1} | Select -First 1
			if(-not $cldComp){
				$cldComp = $cldBom.CompArray[0]
				$dsDiag.Trace("Can not find cld comp for uniqueId:" + $UniqueId + ", use first data.")
			}
			$bomItem.Name = $cldComp.Name
			$bomItem.ComponentType = $cldComp.CompTyp
			$cldCompAttrArray = $cldBom.CompAttrArray | Where-Object { $_.CompId -eq $cldComp.Id}
			if($cldCompAttrArray.Count -eq 0){
				$cldCompAttrArray = $cldBom.CompAttrArray
				$dsDiag.Trace("cld comp attr array is empty for compId:" + $cldComp.Id + ",use entire array.")
			}
			$PropPartNumber = $cldBom.PropArray | Where-Object { $_.dispName -eq "Part Number"}
			$prop = ($cldCompAttrArray | Where-Object { $_.PropId -eq $PropPartNumber.Id}) | Select -First 1
			$bomItem.PartNumber = $prop.Val
			$bomItems += $bomItem
			#add Inventor default BOM columns
			$thumbnailProp = $vault.PropertyService.GetProperties('FILE', @($cldIds[$cldBomCounter - 1]), @($thumbnailPropDef.Id))[0]
			$bomItem.Thumbnail = $thumbnailProp.Val
			$m_Prop = $cldBom.PropArray | Where-Object { $_.dispName -eq "Title"}
			$prop = $cldCompAttrArray | Where-Object { $_.PropId -eq $m_Prop.Id} | Select -First 1
			$bomItem.Title = $prop.Val
			$m_Prop = $cldBom.PropArray | Where-Object { $_.dispName -eq "Description"}
			$prop = $cldCompAttrArray | Where-Object { $_.PropId -eq $m_Prop.Id} | Select -First 1
			$bomItem.Description = $prop.Val
			$m_Prop = $cldBom.PropArray | Where-Object { $_.dispName -eq "Material"}
			$prop = $cldCompAttrArray | Where-Object { $_.PropId -eq $m_Prop.Id} | Select -First 1
			$bomItem.Material = $prop.Val
		}
	}
	$dsDiag.Trace("<< Ending GetFileBOM with $($bomItems.Count) items found")
	return $bomItems
}