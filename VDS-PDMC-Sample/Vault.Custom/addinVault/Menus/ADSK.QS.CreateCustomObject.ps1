# DISCLAIMER:
# ---------------------------------
# In any case, code, templates, and snippets of this solution are of "work in progress" character.
# Neither Markus Koechl, nor Autodesk represents that these samples are reliable, accurate, complete, or otherwise valid. 
# Accordingly, those configuration samples are provided as is with no warranty of any kind, and you use the applications at your own risk.


#$vaultContext.ForceRefresh = $true
$selectionSet = $vaultContext.CurrentSelectionSet[0]
$id = $selectionSet.Id
$dialog = $dsCommands.GetCreateCustomObjectDialog($id)

$CustEntCatName = $vault.CategoryService.GetCategoryById($dialog.CurrentEntity.Cat.CatId).Name

#override the default dialog file assigned
$xamlFile = New-Object CreateObject.WPF.XamlFile "ADSK.QS.CustomObject.xaml", "C:\ProgramData\Autodesk\Vault 2024\Extensions\DataStandard\Vault.Custom\Configuration\ADSK.QS.CustomObject.xaml"
$dialog.XamlFile = $xamlFile

$result = $dialog.Execute()

if ($result) {
	$custent = $dialog.CurrentEntity
	$cat = $vault.CategoryService.GetCategoryById($custent.Cat.CatId)
	switch ($cat.Name) {
		"Person" {
			try {		
				$companyID = Get-Content "$($env:appdata)\Autodesk\DataStandard 2024\mOrganisationId.txt"	
				if ($companyID -ne "") { $link1 = $vault.DocumentService.AddLink($companyID, "CUSTENT", $dialog.CurrentEntity.Id, "Organisation->Person") } #Add Person as content to Organisation
			}
			catch {
				#$dsDiag.Trace("CreateCustomObject.ps1 - AddLink command failed") 
			}
		}
		"Task" {
			try {
				$contactID = Get-Content "$($env:appdata)\Autodesk\DataStandard 2024\mPersonId.txt"
				if ($contactID -ne $null) { $link3 = $vault.DocumentService.AddLink($dialog.CurrentEntity.Id, "CUSTENT", $contactID, "Task->Person") }
			}
			catch {
				$dsDiag.Trace("CreateTaskForECO.ps1 - AddLink command failed") 
			}		
		}
	}

	#goto location
	$entityNumber = $dialog.CurrentEntity.Num
	$entityGuid = $selectionSet.TypeId.EntityClassSubType
	$selectionTypeId = New-Object Autodesk.Connectivity.Explorer.Extensibility.SelectionTypeId $entityGuid
	$location = New-Object Autodesk.Connectivity.Explorer.Extensibility.LocationContext $selectionTypeId, $entityNumber
	$vaultContext.GoToLocation = $location
}

#in any case don't use the last entry twice...
$null | Out-File "$($env:appdata)\Autodesk\DataStandard 2024\mOrganisationId.txt"
$null | Out-File "$($env:appdata)\Autodesk\DataStandard 2024\mPersonId.txt"