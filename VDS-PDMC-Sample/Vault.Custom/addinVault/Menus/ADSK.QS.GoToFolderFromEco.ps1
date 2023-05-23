#region disclaimer
#=============================================================================
# PowerShell script sample for Vault Data Standard                            
#                                                                             
# Copyright (c) Autodesk - All rights reserved.                               
#                                                                             
# THIS SCRIPT/CODE IS PROVIDED "AS IS" WITHOUT WARRANTY OF ANY KIND, EITHER   
# EXPRESSED OR IMPLIED, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED WARRANTIES 
# OF MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE, OR NON-INFRINGEMENT.  
#=============================================================================
#endregion

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
	