
#=============================================================================#
# PowerShell script sample for Vault Data Standard                            
#			 Autodesk Vault - VDS MFG Sample 2024								  
# This sample is based on VDS 2024 RTM and adds functionality and rules		  
#                                                                             
# Copyright (c) Autodesk - All rights reserved.                               
#                                                                             
# THIS SCRIPT/CODE IS PROVIDED "AS IS" WITHOUT WARRANTY OF ANY KIND, EITHER   
# EXPRESSED OR IMPLIED, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED WARRANTIES 
# OF MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE, OR NON-INFRINGEMENT.  
#=============================================================================#

#this function will be called to check if the Ok button can be enabled
function ActivateOkButton
{
		return Validate;
}

# sample validation function
# finds all function definition with names beginning with
# ValidateFile, ValidateFolder and ValidateTask respectively
# these funcions should return a boolean value, $true if the Property is valid
# $false otherwise
# As soon as one property validation function returns $false the entire Validate function will return $false
function Validate
{
	if ($Prop["_ReadOnly"].Value){
		return $false
	}

	$mWindowName = $dsWindow.Name
	switch($mWindowName)
	{
		"FileWindow"
		{
			foreach ($func in Get-ChildItem function:ValidateFile*) { if(!(&$func)) { return $false } }
			return $true
		}
		"FolderWindow"
		{
			foreach ($func in Get-ChildItem function:ValidateFolder*) { if(!(&$func)) { return $false } }
			return $true
		}
		"CustomObjectWindow"
		{
			foreach ($func in Get-ChildItem function:ValidateCustomObject*) { if(!(&$func)) { return $false } }
			return $true
		}
		default { return $true }
	}
    
}

# sample validation function for the FileName property
# if the File Name is empty the validation will fail
function ValidateFileName
{
	if($Prop["_FileName"].Value -or !$dsWindow.FindName("DSNumSchmsCtrl").NumSchmFieldsEmpty)
	{
		return $true;
	}
	$dsDiag.Inspect()
	return $false;
}

function ValidateFolderName
{
	if($Prop["_FolderName"].Value -or !$dsWindow.FindName("DSNumSchmsCtrl").NumSchmFieldsEmpty)
	{
		return $true;
	}
	return $false;
}

function ValidateCustomObjectName
{
	if($Prop["_CustomObjectName"].Value -or !$dsWindow.FindName("DSNumSchmsCtrl").NumSchmFieldsEmpty)
	{
		return $true;
	}
	return $false;
}

function InitializeTabWindow
{
	#$dsDiag.ShowLog()
	#$dsDiag.Inspect()
}

function InitializeWindow
{	      
	#begin rules applying commonly
    InitializeWindowTitle
    InitializeNumSchm
    ADSK.QS.InitializeCategory
    InitializeNameValidation
	#end rules applying commonly
	$mWindowName = $dsWindow.Name
	switch($mWindowName)
	{
		"FileWindow"
		{
			if($Prop["_CreateMode"].Value -eq $true) {
			
				$dsWindow.FindName("TemplateCB").add_SelectionChanged({
					#update the category = selected template's category
					m_TemplateChanged
				})
			
				#preset the author or designer with the current user
				$mUser = $vault.AdminService.Session.User
				if($Prop["_XLTN_DESIGNER"]){
					$Prop["XLTN_DESIGNER"].Value = $mUser.Name
				}
				if($Prop["_XLTN_AUTHOR"]){
					$Prop["_XLTN_AUTHOR"].Value = $mUser.Name
				}
		
			}

			
		}
		"FolderWindow"
		{
			#region VDS MFG Sample - for imported folders easily set title to folder name on edit
			If ($Prop["_EditMode"].Value) {
				If ($Prop["_XLTN_TITLE"]){
					IF ($null -eq $Prop["_XLTN_TITLE"].Value) {
						$Prop["_XLTN_TITLE"].Value = $Prop["Name"].Value
					}
				}
			}
			#endregion VDS MFG Sample
		}
		"CustomObjectWindow"
		{
			$dsWindow.Title = SetWindowTitle $UIString["LBL61"] $UIString["LBL62"] $Prop["_CustomObjectName"].Value
			if ($Prop["_CreateMode"].Value)
			{
				$Prop["_Category"].Value = $Prop["_CustomObjectDefName"].Value

				#region VDS MFG Sample
					$dsWindow.FindName("Categories").IsEnabled = $false
					$dsWindow.FindName("NumSchms").Visibility = "Collapsed"
					$Prop["_NumSchm"].Value = $Prop["_Category"].Value
				#endregion
			}
		}

		"ReserveNumberWindow"
		{
			$dsWindow.FindName("cmbNumType").add_SelectionChanged({
				mGetNumSchms
			})
		}

	}
}

function InitializeWindowTitle()
{
    $mWindowName = $dsWindow.Name
	switch($mWindowName)
	{
		"FileWindow"
		{
			#rules applying for File
			$dsWindow.Title = SetWindowTitle $UIString["LBL24"] $UIString["LBL25"] $Prop["_FileName"].Value
		}
		"FolderWindow"
		{
			#rules applying for Folder
			$dsWindow.Title = SetWindowTitle $UIString["LBL29"] $UIString["LBL30"] $Prop["_FolderName"].Value
		}
		"CustomObjectWindow"
		{
			#rules applying for Custom Object
			$dsWindow.Title = SetWindowTitle $UIString["LBL61"] $UIString["LBL62"] $Prop["_CustomObjectName"].Value
		}
	}
}

function ADSK.QS.InitializeCategory()
{
	$Prop["_Category"].add_PropertyChanged({
        if ($_.PropertyName -eq "Value")
        {
			m_CategoryChanged
        }		
    })
    $mWindowName = $dsWindow.Name
	switch($mWindowName)
	{
		"FileWindow"
		{
			if ($Prop["_CreateMode"].Value)
			{
				if ($Prop["_IsOfficeClient"].Value)
				{
					$Prop["_Category"].Value = $UIString["CAT2"]
				}
				else
				{
					$Prop["_Category"].Value = $UIString["CAT1"]
				}
			}			
		}
		"FolderWindow"
		{
			if ($Prop["_CreateMode"].Value)
			{
				$Prop["_Category"].Value = $UIString["CAT5"]
			}
		}
		"CustomObjectWindow"
		{
			if ($Prop["_CreateMode"].Value)
			{
				$Prop["_Category"].Value = $Prop["_CustomObjectDefName"].Value
			}
		}
	}
}


function InitializeNumSchm()
{
	#Adopted from a DocumentService call, which always pulls FILE class numbering schemes
	$global:numSchems = @($vault.NumberingService.GetNumberingSchemes('FILE', 'Activated')) 
    $Prop["_Category"].add_PropertyChanged({
        if ($_.PropertyName -eq "Value")
        {
            $numSchm = $numSchems | Where-Object {$_.Name -eq $Prop["_Category"].Value}
            if($numSchm)
			{
                $Prop["_NumSchm"].Value = $numSchm.Name
            }
        }		
    })
}

function InitializeNameValidation() {
	$mWindowName = $dsWindow.Name
	switch ($mWindowName) {
		"FileWindow" {
			$nameProp = "_FileName"
		}
		"FolderWindow" {
			$nameProp = "_FolderName"
		}
		"CustomObjectWindow" {
			$nameProp = "_CustomObjectName"
		}
		default {
			$nameProp = ""
		}
	}
	if ($Prop[$nameProp].Length -ne 0) {
		$Prop[$nameProp].CustomValidation = { NameCustomValidation }
	}
}

function NameCustomValidation()
{
	$DSNumSchmsCtrl = $dsWindow.FindName("DSNumSchmsCtrl")
	if ($DSNumSchmsCtrl -and -not $DSNumSchmsCtrl.NumSchmFieldsEmpty)
	{
		return $true
	}

	$mWindowName = $dsWindow.Name
	switch($mWindowName)
	{
		"FileWindow"
		{
			$nameProp = "_FileName"
		}
		"FolderWindow"
		{
			$nameProp = "_FolderName"
		}
		"CustomObjectWindow"
		{
			$nameProp = "_CustomObjectName"
		}
	}
	$folderName = $Prop[$nameProp].Value
	if($folderName)
	{
		if ($folderName.IndexOfAny([System.IO.Path]::GetInvalidFileNameChars()) -ne -1)
		{
			$Prop[$nameProp].CustomValidationErrorMessage = "$($UIString["VAL10"])"
			return $false
		}

		return $true;
	} 
	else 
	{
		$Prop[$nameProp].CustomValidationErrorMessage = "$($UIString["VAL1"])"
		return $false
	}
	
	return $false;
}

function SetWindowTitle($newFile, $editFile, $name)
{
       if ($Prop["_CreateMode"].Value)
       {
              $windowTitle = $newFile            
       }
       elseif ($Prop["_EditMode"].Value)
       {
			if ($Prop["_ReadOnly"].Value){
				$windowTitle = "$($editFile) - $($name) - $($UIString["LBL26"])"
				$dsWindow.FindName("btnOK").ToolTip = $UIString["LBL26"]
            }
			else{
				$windowTitle = "$($editFile) - $($name)"
			}
       }
       return $windowTitle
}


function OnLogOn
{
	#Executed when User logs on Vault; $vaultUsername can be used to get the username, which is used in Vault on login
}
function OnLogOff
{
	#Executed when User logs off Vault
}

function GetTitleWindow
{
	$message = "Autodesk Data Standard - Create/Edit "+$Prop["_FileName"]
	return $message
}

#fired when the file selection changes
function OnTabContextChanged
{
	$xamlFile = [System.IO.Path]::GetFileName($VaultContext.UserControl.XamlFile)
	
	if ($VaultContext.SelectedObject.TypeId.SelectionContext -eq "FileMaster" -and $xamlFile -eq "ADSK.QS.CAD BOM.xaml")
	{
		$fileMasterId = $vaultContext.SelectedObject.Id
		$file = $vault.DocumentService.GetLatestFileByMasterId($fileMasterId)
		$bom = @(GetFileBOM($file.id))
		$dsWindow.FindName("bomList").ItemsSource = $bom
	}
	if ($VaultContext.SelectedObject.TypeId.SelectionContext -eq "ItemMaster" -and $xamlFile -eq "Associated Files.xaml")
	{
		$items = $vault.ItemService.GetItemsByIds(@($vaultContext.SelectedObject.Id))
		$item = $items[0]
		$itemids = @($item.Id)
		$assocFiles = @(GetAssociatedFiles $itemids $([System.IO.Path]::GetDirectoryName($VaultContext.UserControl.XamlFile)))
		$dsWindow.FindName("AssoicatedFiles").ItemsSource = $assocFiles
	}

}

function GetNewCustomObjectName
{
	#region VDS MFG Sample
		$m_Cat = $Prop["_Category"].Value
		switch ($m_Cat)
		{
			$UIString["MSDCE_CO02"] #Person
			{
				if($dsWindow.FindName("DSNumSchmsCtrl").NumSchmFieldsEmpty -eq $false)
				{
					$Prop["_XLTN_IDENTNUMBER"].Value = $Prop["_GeneratedNumber"].Value
				}
				$customObjectName = $Prop["_XLTN_FIRSTNAME"].Value + " " + $Prop["_XLTN_LASTNAME"].Value
				return $customObjectName
			}

			Default 
			{
				#region - default configuration's behavior
				if($dsWindow.FindName("DSNumSchmsCtrl").NumSchmFieldsEmpty)
				{	
					#$dsDiag.Trace("read text from TextBox CUSTOMOBJECTNAME")
					$customObjectName = $dsWindow.FindName("CUSTOMOBJECTNAME").Text
					#$dsDiag.Trace("customObjectName = $customObjectName")
				}
				else{
					#$dsDiag.Trace("-> GenerateNumber")
					$customObjectName = $Prop["_GeneratedNumber"].Value
					#$dsDiag.Trace("customObjectName = $customObjectName")
				}
				return $customObjectName
				#endregion - default configuration's behavior
			}
		}
	#endregion VDS MFG Sample
}

#Constructs the filename(numschems based or handtyped)and returns it.
function GetNewFileName
{
	#$dsDiag.Trace(">> GetNewFileName")
	if($dsWindow.FindName("DSNumSchmsCtrl").NumSchmFieldsEmpty)
	{	
		#$dsDiag.Trace("read text from TextBox FILENAME")
		$fileName = $dsWindow.FindName("FILENAME").Text
		#$dsDiag.Trace("fileName = $fileName")
	}
	else{
		#$dsDiag.Trace("-> GenerateNumber")
		$fileName = $Prop["_GeneratedNumber"].Value
		#$dsDiag.Trace("fileName = $fileName")
		#VDS-MFG-Sample: write new number or keep user override
			If($Prop["_XLTN_PARTNUMBER"] -and ([string]::IsNullOrEmpty($Prop["_XLTN_PARTNUMBER"].Value)))
			{ 
				$Prop["_XLTN_PARTNUMBER"].Value = $Prop["_GeneratedNumber"].Value
			}
		#VDS-MFG-Sample
	}
	$newfileName = $fileName + $Prop["_FileExt"].Value
	#$dsDiag.Trace("<< GetNewFileName $newfileName")
	return $newfileName
}

function GetNewFolderName
{
	#$dsDiag.Trace(">> GetNewFolderName")
	if($dsWindow.FindName("DSNumSchmsCtrl").NumSchmFieldsEmpty)
	{	
		#$dsDiag.Trace("read text from TextBox FOLDERNAME")
		$folderName = $dsWindow.FindName("FOLDERNAME").Text
		#$dsDiag.Trace("folderName = $folderName")
	}
	else{
		#$dsDiag.Trace("-> GenerateNumber")
		$folderName = $Prop["_GeneratedNumber"].Value
		#$dsDiag.Trace("folderName = $folderName")
	}
	#$dsDiag.Trace("<< GetNewFolderName $folderName")
	return $folderName
}

# This function can be used to force a specific folder when using "New Standard File" or "New Standard Folder" functions.
# If an empty string is returned the selected folder is used
# ! Do not remove the function
function GetParentFolderName
{
	$folderName = ""
	return $folderName
}

function GetCategories
{
	if ($dsWindow.Name -eq "FileWindow")
	{
		#return $vault.CategoryService.GetCategoriesByEntityClassId("FILE", $true)
		#region VDS MFG Sample
			$global:mFileCategories = $Prop["_Category"].ListValues # $vault.CategoryService.GetCategoriesByEntityClassId("FILE", $true)
			return $global:mFileCategories | Sort-Object -Property Name #ascending is the default
		#endregion
	}
	elseif ($dsWindow.Name -eq "FolderWindow")
	{
		return $vault.CategoryService.GetCategoriesByEntityClassId("FLDR", $true)
	}
	elseif ($dsWindow.Name -eq "CustomObjectWindow")
	{
		return $vault.CategoryService.GetCategoriesByEntityClassId("CUSTENT", $true)
	}
}

function GetNumSchms
{
	if ($Prop["_CreateMode"].Value)
	{
		try
		{
			#Adopted from a DocumentService call, which always pulls FILE class numbering schemes
			[System.Collections.ArrayList]$numSchems = @($vault.NumberingService.GetNumberingSchemes('FILE', 'Activated'))

			if ($numSchems.Count -gt 1)
			{
				$mWindowName = $dsWindow.Name
				switch ($mWindowName) {
					"FileWindow" {
						$_FilteredNumSchems = $numSchems | Where-Object { $_.IsDflt -eq $true }
						$Prop["_NumSchm"].Value = $_FilteredNumSchems[0].Name
						$dsWindow.FindName("NumSchms").IsEnabled = $false
						return $_FilteredNumSchems
					}

					"FolderWindow" {
						#numbering schemes are available for items and files specificly; 
						#for folders we use the file numbering schemes and filter to these, that have a corresponding name in folder categories
						$_FolderCats = $vault.CategoryService.GetCategoriesByEntityClassId("FLDR", $true)
						$_FilteredNumSchems = @()
						Foreach ($item in $_FolderCats) {
							$_temp = $numSchems | Where-Object { $_.Name -eq $item.Name }
							$_FilteredNumSchems += ($_temp)
						}
						#we need an option to unselect a previosly selected numbering; to achieve that we add a virtual one, named "None"
						$noneNumSchm = New-Object 'Autodesk.Connectivity.WebServices.NumSchm'
						$noneNumSchm.Name = "None"
						$_FilteredNumSchems += ($noneNumSchm)

						return $_FilteredNumSchems
					}

					"CustomObjectWindow" {
						$_FilteredNumSchems = $numSchems | Where-Object { $_.Name -eq $Prop["_Category"].Value }
						return $_FilteredNumSchems
					}

					default {
						$numSchems = $numSchems | Sort-Object -Property IsDflt -Descending
						return $numSchems
					}
				}
			}
			Else {
				$dsWindow.FindName("NumSchms").IsEnabled = $false				
			}
			return $numSchems
		}
		catch [System.Exception]
		{		
			[Autodesk.DataManagement.Client.Framework.Forms.Library]::ShowError($error, "VDS Sample Configuration")
		}
	}
}


# Decides if the NumSchmes field should be visible
function IsVisibleNumSchems
{
	$ret = "Collapsed"
	$numSchems = $vault.DocumentService.GetNumberingSchemesByType([Autodesk.Connectivity.WebServices.NumSchmType]::Activated)
	if($numSchems.Length -gt 0)
	{	$ret = "Visible" }
	return $ret
}

#Decides if the FileName should be enabled, it should only when the NumSchmField isnt
function ShouldEnableFileName
{
	$ret = "true"
	$numSchems = $vault.DocumentService.GetNumberingSchemesByType([Autodesk.Connectivity.WebServices.NumSchmType]::Activated)
	if($numSchems.Length -gt 0)
	{	$ret = "false" }
	return $ret
}

function ShouldEnableNumSchms
{
	$ret = "false"
	$numSchems = $vault.DocumentService.GetNumberingSchemesByType([Autodesk.Connectivity.WebServices.NumSchmType]::Activated)
	if($numSchems.Length -gt 0)
	{	$ret = "true" }
	return $ret
}

#define the parametrisation for the number generator here
function GenerateNumber
{
	$selected = $dsWindow.FindName("NumSchms").Text
	if($selected -eq "") { return "na" }

	$ns = $global:numSchems | Where-Object { $_.Name.Equals($selected) }
	switch ($selected) {
		"Sequential" { $NumGenArgs = @(""); break; }
		default      { $NumGenArgs = @(""); break; }
	}

	$vault.DocumentService.GenerateFileNumber($ns.SchmID, $NumGenArgs)

}

#define here how the numbering preview should look like
function GetNumberPreview
{
	$selected = $dsWindow.FindName("NumSchms").Text
	switch ($selected) {
		"Sequential" { $Prop["_FileName"].Value="???????"; break; }
		"Short" { $Prop["_FileName"].Value=$Prop["Project"].Value + "-?????"; break; }
		"Long" { $Prop["_FileName"].Value=$Prop["Project"].Value + "." + $Prop["Material"].Value + "-?????"; break; }
		default { $Prop["_FileName"].Value="NA" }
	}
}

#Workaround for Property names containing round brackets
#Xaml fails to parse
function ItemTitle
{
    if ($Prop)
	{
       $val = $Prop["_XLTN_TITLE_ITEM_CO"].Value
	   return $val
    }
}

#Workaround for Property names containing round brackets
#Xaml fails to parse
function ItemDescription
{
	if($Prop)#Tab gets loaded before the SelectionChanged event gets fired resulting with null Prop. Happens when the vault is started with Change Order as the last view.
    {
       $val = $Prop["_XLTN_DESCRIPTION_ITEM_CO"].Value
	   return $val
    }
}

 
function m_TemplateChanged {
	#check if cmbTemplates is empty
	if ($dsWindow.FindName("TemplateCB").ItemsSource.Count -lt 1)
	{
		return
	}
	$mContext = $dsWindow.DataContext
	$mTemplatePath = $mContext.TemplatePath
	$mTemplateFile = $mContext.SelectedTemplate
	#$mTemplate = $mTemplatePath + "/" + $mTemplateFile
	$mFolder = $vault.DocumentService.GetFolderByPath($mTemplatePath)
	$mFiles = $vault.DocumentService.GetLatestFilesByFolderId($mFolder.Id,$false)
	$mTemplateFile = $mFiles | Where-Object { $_.Name -eq $mTemplateFile }
	$Prop["_Category"].Value = $mTemplateFile.Cat.CatName
	$mCatName = $mTemplateFile.Cat.CatName
	$dsWindow.FindName("Categories").SelectedValue = $mCatName
	If ($mCatName) #if something went wrong the user should be able to select a category
	{
		$dsWindow.FindName("Categories").IsEnabled = $false #comment out this line if admins like to release the choice to the user
	}
	#$dsDiag.Trace(" ... TemplateChanged finished <<")
}

function m_CategoryChanged 
{
	$mWindowName = $dsWindow.Name
    switch($mWindowName)
	{
		"FileWindow"
		{
			#VDS MFG Sample uses the default numbering scheme for files; GoTo GetNumSchms function to disable this filter incase you'd like to apply numbering per category for files as well
			If ($Prop['_XLTN_AUTHOR'])
			{
				$Prop['_XLTN_AUTHOR'].Value = $VaultConnection.UserName
			}
		}

		"FolderWindow" 
		{
			$dsWindow.FindName("NumSchms").SelectedItem = $null
			$dsWindow.FindName("NumSchms").Visibility = "Collapsed"
			$dsWindow.FindName("DSNumSchmsCtrl").Visibility = "Collapsed"
			$dsWindow.FindName("FOLDERNAME").Visibility = "Visible"
					
			$Prop["_NumSchm"].Value = $Prop["_Category"].Value
			IF ($dsWindow.FindName("DSNumSchmsCtrl").Scheme.Name -eq $Prop["_Category"].Value) 
			{
				$dsWindow.FindName("DSNumSchmsCtrl").Visibility = "Visible"
				$dsWindow.FindName("FOLDERNAME").Visibility = "Collapsed"
			}
			Else
			{
				$Prop["_NumSchm"].Value = "None" #we need to reset in case a user switches back from existing numbering scheme to manual input
			}
			
			#set the start date = today for project category
			If ($Prop["_Category"].Value -eq $UIString["CAT6"] -and $Prop["_XLTN_DATESTART"] )		
			{
				$Prop["_XLTN_DATESTART"].Value = Get-Date -displayhint date
			}
		}

		"CustomObjectWindow"
		{
			#categories are bound to CO type name
		}
		default
		{
			#nothing for 'unknown' new window type names
		}			
	}
}

function mHelp ([Int] $mHContext) {
	Try
	{
		Switch ($mHContext){
			500 {
				$mHPage = "V.2File.html";
			}
			550 {
				$mHPage = "V.3OfficeFile.html";
			}
			600 {
				$mHPage = "V.1Folder.html";
			}
			700 {
				$mHPage = "V.6CustomObject.html";
			}
			Default {
				$mHPage = "Index.html";
			}
		}
		$mHelpTarget = "C:\ProgramData\Autodesk\Vault 2024\Extensions\DataStandard\HelpFiles\"+$mHPage
		$mhelpfile = Invoke-Item $mHelpTarget
		if (-not $mhelpfile) {
			[Autodesk.DataManagement.Client.Framework.Forms.Library]::ShowError("Help Target not found", "VDS MFG Sample Client")
		}
	}
	Catch
	{
		[Autodesk.DataManagement.Client.Framework.Forms.Library]::ShowError("Help Target not found", "VDS MFG Sample Client")
	}
}
function mResetTemplates
{
	$dsWindow.FindName("TemplateCB").ItemsSource = $dsWindow.DataContext.Templates
}

function mFldrNameValidation
{
	$rootFolder = $vault.DocumentService.GetFolderByPath($Prop["_FolderPath"].Value)
	$mFldExist = mFindFolder $Prop["_FolderName"].Value $rootFolder

	If($mFldExist)
	{
		$dsWindow.FindName("FOLDERNAME").ToolTip = "Foldername exists, select a new unique one."
		$dsWindow.FindName("FOLDERNAME").BorderBrush = "Red"
		$dsWindow.FindName("FOLDERNAME").BorderThickness = "1,1,1,1"
		$dsWindow.FindName("FOLDERNAME").Background = "#FFFFDADA"
		return $false
	}
	Else
	{
		$dsWindow.FindName("FOLDERNAME").ToolTip = "Foldername is valid, press OK to create."
		$dsWindow.FindName("FOLDERNAME").BorderBrush = "#FFABADB3" #the default color
		$dsWindow.FindName("FOLDERNAME").BorderThickness = "0,1,1,0" #the default border top, right
		$dsWindow.FindName("FOLDERNAME").Background = "#FFFFFFFF"
		return $true
	}
}

function mFindFolder($FolderName, $rootFolder)
{
	$FolderPropDefs = $vault.PropertyService.GetPropertyDefinitionsByEntityClassId("FLDR")
    $FolderNamePropDef = $FolderPropDefs | Where-Object {$_.SysName -eq "Name"}
    $srchCond = New-Object 'Autodesk.Connectivity.WebServices.SrchCond'
    $srchCond.PropDefId = $FolderNamePropDef.Id
    $srchCond.PropTyp = "SingleProperty"
    $srchCond.SrchOper = 3 #is equal
    $srchCond.SrchRule = "Must"
    $srchCond.SrchTxt = $FolderName

    $bookmark = ""
    $status = $null
    $totalResults = @()
    while ($null -eq $status -or $totalResults.Count -lt $status.TotalHits)
    {
        $results = $vault.DocumentService.FindFoldersBySearchConditions(@($srchCond),$null, @($rootFolder.Id), $false, [ref]$bookmark, [ref]$status)

        if ($null -ne $results)
        {
            $totalResults += $results
        }
        else {break}
    }
    return $totalResults;
}

function GetTemplateFolders
{
	$xmlpath = "$env:programdata\Autodesk\Vault 2024\Extensions\DataStandard\Vault.Custom\Configuration\ADSK.QS.File.xml"

	if ($_IsOfficeClient) {
		$xmlpath = "$env:programdata\Autodesk\Vault 2024\Extensions\DataStandard\Vault.Custom\Configuration\ADSK.QS.FileOffice.xml"
	}

	$xmldata = [xml](Get-Content $xmlpath)

	[string[]] $folderPath = $xmldata.DocTypeData.DocTypeInfo | ForEach-Object { $_.Path }
	$folders = $vault.DocumentService.FindFoldersByPaths($folderPath)

	return $xmldata.DocTypeData.DocTypeInfo | ForEach-Object {
		$path = $_.Path
		$folder = $folders | Where-Object { $_.FullName -eq $path } | Select-Object -index 0
		if($null -eq $folder)
		{
			return
		}
		return $_
	}
}