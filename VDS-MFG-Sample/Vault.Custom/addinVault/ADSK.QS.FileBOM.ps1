# DISCLAIMER:
# ---------------------------------
# In any case, code, templates, and snippets of this solution are of "work in progress" character.
# Neither Markus Koechl, nor Autodesk represents that these samples are reliable, accurate, complete, or otherwise valid. 
# Accordingly, those configuration samples are provided as is with no warranty of any kind, and you use the applications at your own risk.


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
	Try{
		#Get Thumbnail PropertyDefinition 
		$propDefs = $vault.PropertyService.GetPropertyDefinitionsByEntityClassId('FILE')
		$thumbnailPropDef = $propDefs | Where-Object {$_.SysName -eq 'Thumbnail'}

		$bom = $vault.DocumentService.GetBOMByFileId($fileID)
		$cldIds =@()
		$bom.InstArray | Where-Object { $_.ParId -eq 0 } | ForEach-Object { 
			$CldId = $_.CldId
			$comp = $bom.CompArray | Where-Object { $_.Id -eq $CldId }
			if ($comp.XRefId -ne -1) {
				$cldIds += $comp.XRefId
			}
		}

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
				$cldComp = $cldBom.CompArray | Where-Object { $_.UniqueId -eq $UniqueId -and $_.XRefId -eq -1} | Select-Object -First 1
				if(-not $cldComp){
					$cldComp = $cldBom.CompArray[0]
				}
				$bomItem.Name = $cldComp.Name
				$bomItem.ComponentType = $cldComp.CompTyp
				$cldCompAttrArray = $cldBom.CompAttrArray | Where-Object { $_.CompId -eq $cldComp.Id}
				if($cldCompAttrArray.Count -eq 0){
					$cldCompAttrArray = $cldBom.CompAttrArray
				}
				$PropPartNumber = $cldBom.PropArray | Where-Object { $_.dispName -eq "Part Number"}
				$prop = ($cldCompAttrArray | Where-Object { $_.PropId -eq $PropPartNumber.Id}) | Select-Object -First 1
				$bomItem.PartNumber = $prop.Val
				$bomItems += $bomItem

				#add Inventor default BOM columns
				$thumbnailProp = $vault.PropertyService.GetProperties('FILE', @($cldIds[$cldBomCounter - 1]), @($thumbnailPropDef.Id))[0]
				$bomItem.Thumbnail = $thumbnailProp.Val
				$m_Prop = $cldBom.PropArray | Where-Object { $_.dispName -eq "Title"}
				$prop = $cldCompAttrArray | Where-Object { $_.PropId -eq $m_Prop.Id} | Select-Object -First 1
				$bomItem.Title = $prop.Val
				$m_Prop = $cldBom.PropArray | Where-Object { $_.dispName -eq "Description"}
				$prop = $cldCompAttrArray | Where-Object { $_.PropId -eq $m_Prop.Id} | Select-Object -First 1
				$bomItem.Description = $prop.Val
				$m_Prop = $cldBom.PropArray | Where-Object { $_.dispName -eq "Material"}
				$prop = $cldCompAttrArray | Where-Object { $_.PropId -eq $m_Prop.Id} | Select-Object -First 1
				$bomItem.Material = $prop.Val
			}
		}
		return $bomItems
	}
	catch {
		[Autodesk.DataManagement.Client.Framework.Forms.Library]::ShowError("CAD-BOM creation failed due to incomplete data; check-out, save and check-in the assembly before you try again.", "Data Standard – CAD-BOM")
	}
	
}