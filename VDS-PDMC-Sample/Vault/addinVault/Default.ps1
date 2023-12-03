#[System.Reflection.Assembly]::LoadFrom("C:\Program Files (x86)\Autodesk\Autodesk Vault 2024 SDK\bin\Autodesk.Connectivity.WebServices.dll")
#$cred = New-Object Autodesk.Connectivity.WebServicesTools.UserPasswordCredentials("localhost", "Vault", "Administrator", "")
#$vault = New-Object Autodesk.Connectivity.WebServicesTools.WebServiceManager($cred)

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
			foreach ($func in dir function:ValidateFile*) { if(!(&$func)) { return $false } }
			return $true
		}
		"FolderWindow"
		{
			foreach ($func in dir function:ValidateFolder*) { if(!(&$func)) { return $false } }
			return $true
		}
		"CustomObjectWindow"
		{
			foreach ($func in dir function:ValidateCustomObject*) { if(!(&$func)) { return $false } }
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
    InitializeCategory
    InitializeNameValidation
	#end rules applying commonly
	$mWindowName = $dsWindow.Name
	switch($mWindowName)
	{
		"FileWindow"
		{
			#rules applying for File
		}
		"FolderWindow"
		{
			#rules applying for Folder
		}
		"CustomObjectWindow"
		{
			#rules applying for Custom Object
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

function InitializeCategory()
{
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
            $numSchm = $numSchems | where {$_.Name -eq $Prop["_Category"].Value}
            if($numSchm)
			{
                $Prop["_NumSchm"].Value = $numSchm.Name
            }
        }		
    })
}

function InitializeNameValidation()
{
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
	$Prop[$nameProp].CustomValidation = { NameCustomValidation }
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
		if ($Prop["_ReadOnly"].Value) {
		  $windowTitle = "$name -- $($UIString["LBL26"])"
		}
		else {			
		  $windowTitle = "$editFile - $name"
		}
	}
	return $windowTitle
}

function OnLogOn
{
	#Executed when User logs on Vault
	#$vaultUsername can be used to get the username, which is used in Vault on login
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
	
	if ($VaultContext.SelectedObject.TypeId.SelectionContext -eq "FileMaster" -and $xamlFile -eq "CAD BOM.xaml")
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
	$dsDiag.Trace(">> GetNewCustomObjectName")
	if($dsWindow.FindName("DSNumSchmsCtrl").NumSchmFieldsEmpty)
	{	
		$dsDiag.Trace("read text from TextBox CUSTOMOBJECTNAME")
		$customObjectName = $dsWindow.FindName("CUSTOMOBJECTNAME").Text
		$dsDiag.Trace("customObjectName = $customObjectName")
	}
	else{
		$dsDiag.Trace("-> GenerateNumber")
		$customObjectName = $Prop["_GeneratedNumber"].Value
		$dsDiag.Trace("customObjectName = $customObjectName")
	}
	$dsDiag.Trace("<< GetNewCustomObjectName $customObjectName")
	return $customObjectName
}

#Constructs the filename(numschems based or handtyped)and returns it.
function GetNewFileName
{
	$dsDiag.Trace(">> GetNewFileName")
	if($dsWindow.FindName("DSNumSchmsCtrl").NumSchmFieldsEmpty)
	{	
		$dsDiag.Trace("read text from TextBox FILENAME")
		$fileName = $dsWindow.FindName("FILENAME").Text
		$dsDiag.Trace("fileName = $fileName")
	}
	else{
		$dsDiag.Trace("-> GenerateNumber")
		$fileName = $Prop["_GeneratedNumber"].Value
		$dsDiag.Trace("fileName = $fileName")
	}
	$newfileName = $fileName + $Prop["_FileExt"].Value
	$dsDiag.Trace("<< GetNewFileName $newfileName")
	return $newfileName
}

function GetNewFolderName
{
	$dsDiag.Trace(">> GetNewFolderName")
	if($dsWindow.FindName("DSNumSchmsCtrl").NumSchmFieldsEmpty)
	{	
		$dsDiag.Trace("read text from TextBox FOLDERNAME")
		$folderName = $dsWindow.FindName("FOLDERNAME").Text
		$dsDiag.Trace("folderName = $folderName")
	}
	else{
		$dsDiag.Trace("-> GenerateNumber")
		$folderName = $Prop["_GeneratedNumber"].Value
		$dsDiag.Trace("folderName = $folderName")
	}
	$dsDiag.Trace("<< GetNewFolderName $folderName")
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
		return $vault.CategoryService.GetCategoriesByEntityClassId("FILE", $true)
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
			if ($numSchems.Count -gt 1)
			{
				$numSchems = $numSchems | Sort-Object -Property IsDflt -Descending
			}
			return $numSchems
		}
		catch [System.Exception]
		{		
			#[System.Windows.MessageBox]::Show($error)
		}
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
 
function GetTemplateFolders
{
	# *ComponentUpgradeEveryRelease-Client*
	$xmlpath = "$env:programdata\Autodesk\Vault 2024\Extensions\DataStandard\Vault\Configuration\File.xml"

	if ($_IsOfficeClient) {
		$xmlpath = "$env:programdata\Autodesk\Vault 2024\Extensions\DataStandard\Vault\Configuration\FileOffice.xml"
	}
	# *ComponentUpgradeEveryRelease-End*

	$xmldata = [xml](Get-Content $xmlpath)

	[string[]] $folderPath = $xmldata.DocTypeData.DocTypeInfo | foreach { $_.Path }
	$folders = $vault.DocumentService.FindFoldersByPaths($folderPath)

	return $xmldata.DocTypeData.DocTypeInfo | foreach {
		$path = $_.Path
		$folder = $folders | where { $_.FullName -eq $path } | Select -index 0
		if($folder -eq $null)
		{
			return
		}
		return $_
	}
}
