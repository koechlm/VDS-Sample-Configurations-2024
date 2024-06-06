# DISCLAIMER:
# ---------------------------------
# In any case, code, templates, and snippets of this solution are of "work in progress" character.
# Neither Markus Koechl, nor Autodesk represents that these samples are reliable, accurate, complete, or otherwise valid. 
# Accordingly, those configuration samples are provided as is with no warranty of any kind, and you use the applications at your own risk.


$vaultContext.ForceRefresh = $true
$entityId = $vaultContext.CurrentSelectionSet[0].Id

#get the folder where the ECO has it's primary link to
$mTargetLnks = @()		
$mTargetLnks = $vault.DocumentService.GetLinksByTargetEntityIds(@($entityId))

#filter target linked objects are folders and not custom objects
$mTargetLnks = $mTargetLnks | Where-Object { $_.ParEntClsId -eq "FLDR" }

if ($mTargetLnks.Count -gt 0) {
	#we assume that the primary link has been created by this configurations CreateECO* command
	[Autodesk.Connectivity.WebServices.Folder]$mEcoParentFld = $vault.DocumentService.GetFolderById($mTargetLnks[0].ParentId)

	$path = $mEcoParentFld.Fullname
	#navigate to the folder
	$selectionTypeId = [Autodesk.Connectivity.Explorer.Extensibility.SelectionTypeId]::Folder
	$location = New-Object Autodesk.Connectivity.Explorer.Extensibility.LocationContext $selectionTypeId, $path
	$vaultContext.GoToLocation = $location
}
	