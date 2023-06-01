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

$mTargetFile = Get-Content "$($env:appdata)\Autodesk\DataStandard 2024\mStrTabClick.txt"

$srchConds = New-Object autodesk.Connectivity.WebServices.SrchCond[] 1
	$srchCond = New-Object autodesk.Connectivity.WebServices.SrchCond
	$propDefs = $vault.PropertyService.GetPropertyDefinitionsByEntityClassId("FILE")
	$propNames = @("Name")
	$propDefIds = @{}
	foreach($name in $propNames) {
		$propDef = $propDefs | Where-Object { $_.SysName -eq $name }
		$propDefIds[$propDef.Id] = $propDef.DispName
	}
	$srchCond.PropDefId = $propDef.Id
	$srchCond.SrchOper = 3
	$srchCond.SrchTxt = $mTargetFile

	$srchCond.PropTyp = [Autodesk.Connectivity.WebServices.PropertySearchType]::SingleProperty
	$srchCond.SrchRule = [Autodesk.Connectivity.WebServices.SearchRuleType]::Must
	$srchConds[0] = $srchCond
	$srchSort = New-Object autodesk.Connectivity.WebServices.SrchSort
	$searchStatus = New-Object autodesk.Connectivity.WebServices.SrchStatus
	$bookmark = ""
$mSearchResult = $vault.DocumentService.FindFilesBySearchConditions($srchConds,$null, $null,$true,$true,[ref]$bookmark,[ref]$searchStatus)
	If (!$mSearchResult) 
	{ 
		[Autodesk.DataManagement.Client.Framework.Forms.Library]::ShowError([String]::Format($UIString["ADSK-DocStructure_02"], $mVal, $_ReplacedByFilePropDispName), $UIString["ADSK-GoToSource_MNU00"])
		return
	}

$folderId = $mSearchResult[0].FolderId
$fileName = $mSearchResult[0].Name

$folder = $vault.DocumentService.GetFolderById($folderId)
$path=$folder.FullName+"/"+$fileName

$selectionId = [Autodesk.Connectivity.Explorer.Extensibility.SelectionTypeId]::File
$location = New-Object Autodesk.Connectivity.Explorer.Extensibility.LocationContext $selectionId, $path
$vaultContext.GoToLocation = $location
