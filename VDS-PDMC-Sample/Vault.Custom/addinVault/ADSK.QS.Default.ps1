
#=============================================================================#
# PowerShell script sample for Vault Data Standard                            
#			 Autodesk Vault - VDS-PDMC-Sample 2022  								  
# This sample is based on VDS 2023 RTM and adds functionality and rules		  
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
		"CustomObjectClassifiedWindow"
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
	if($Prop["_CreateMode"].Value)
	{
		if($Prop["_FolderName"].Value -or !$dsWindow.FindName("DSNumSchmsCtrl").NumSchmFieldsEmpty)
		{
			return mValidateUniqueFldrName
		}
		return $false;
	}
	else{
		return $true
	}	
}

function ValidateCustomObjectName
{
	if($Prop["_CreateMode"].Value)
	{
		if($Prop["_CustomObjectName"].Value -or !$dsWindow.FindName("DSNumSchmsCtrl").NumSchmFieldsEmpty)
		{
			return ValidateCustentName
		}
		return $false;
	}
	else{
		return $true
	}
}

function InitializeTabWindow
{
	#$dsDiag.ShowLog()
	#$dsDiag.Inspect()
}

function InitializeWindow
{	      
        #$dsDiag.ShowLog()
        #$dsDiag.Clear()

	#begin rules applying commonly
	$Prop["_Category"].add_PropertyChanged({
        if ($_.PropertyName -eq "Value")
        {
			m_CategoryChanged
        }		
    })
	#end rules applying commonly

	$mWindowName = $dsWindow.Name
	switch($mWindowName)
	{
		"FileWindow"
		{
			#rules applying for File
			$dsWindow.Title = SetWindowTitle $UIString["LBL24"] $UIString["LBL25"] $Prop["_FileName"].Value

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

			#region VDS-PDMC-Sample to get category from selected template
			#$dsWindow.FindName("DocTypeCombo").add_SelectionChanged({
			#		mResetTemplates #no longer required starting 2022.1?
			#	})

			$dsWindow.FindName("TemplateCB").add_SelectionChanged({
				#update the category = selected template's category
				m_TemplateChanged
			})

			if($dsWindow.FindName("tabItemProperties")) { mInitializeTabItemProps}

			if($dsWindow.FindName("tabClassification")) 
			{ 
				#hide tab for user groups, e.g., group "Trainees", enable for all others
				$clsDisabled =  $false #replace by e.g., Adsk.GroupMemberOf "Trainees"
				if($clsDisabled -eq $true) 
				{
					$dsWindow.FindName("tabClassification").Visibility = "Collapsed" 
				}
				if($clsDisabled -eq $false -and $Prop["_EditMode"].Value -eq $true)
				{
					$dsWindow.FindName("tabClassification").Visibility = "Visible"
					$dsWindow.FindName("tabClassification").add_GotFocus({
						if(-not $Global:mClsTabInitialized)
						{
							mInitializeClassificationTab -ParentType "Dialog" -file $null
						}
					}) #add_GotFocus
				}
				else {
					$dsWindow.FindName("tabClassification").Visibility = "Collapsed" 
				}
			}

			if($dsWindow.FindName("tabRevision")) 
			{
				$dsWindow.FindName("tabRevision").Visibility = "Visible"
								
				InitializeRevisionValidation
				
				$Prop["_Category"].add_PropertyChanged({
					InitializeRevisionValidation
				})
			}
			#endregion VDS-PDMC-Sample
			
		}
		"FolderWindow"
		{
			#rules applying for Folder
			$dsWindow.Title = SetWindowTitle $UIString["LBL29"] $UIString["LBL30"] $Prop["_FolderName"].Value
			if ($Prop["_CreateMode"].Value)
			{
				$Prop["_Category"].Value = $UIString["CAT5"]
			}
			#region VDS-PDMC-Sample - for imported folders easily set title to folder name on edit
			If ($Prop["_EditMode"].Value) {
				If ($Prop["_XLTN_TITLE"]){
					IF ($Prop["_XLTN_TITLE"].Value -eq $null) {
						$Prop["_XLTN_TITLE"].Value = $Prop["Name"].Value
					}
				}
			}
			#endregion VDS-PDMC-Sample
		}
		"CustomObjectWindow"
		{
			#rules applying for Custom Object
			$dsWindow.Title = SetWindowTitle $UIString["LBL61"] $UIString["LBL62"] $Prop["_CustomObjectName"].Value
			if ($Prop["_CreateMode"].Value)
			{
				$Prop["_Category"].Value = $Prop["_CustomObjectDefName"].Value

				#region VDS-PDMC-Sample
					$dsWindow.FindName("Categories").IsEnabled = $false
					$dsWindow.FindName("NumSchms").Visibility = "Collapsed"
					$Prop["_NumSchm"].Value = $Prop["_Category"].Value
				#endregion

				if($Prop["_Category"].Value -eq "Person")
				{
					$dsWindow.FindName("CUSTOMOBJECTNAME").add_LostFocus({
						$Prop["First Name"].Value = ($dsWindow.FindName("CUSTOMOBJECTNAME").Text).Split(" ")[0]
						$Prop["Last Name"].Value = ($dsWindow.FindName("CUSTOMOBJECTNAME").Text).Split(" ")[1]
					})

					$Prop["First Name"].add_PropertyChanged({
						$dsWindow.FindName("CUSTOMOBJECTNAME").Text = $Prop["First Name"].Value + " " + $Prop["Last Name"].Value
					})

					$Prop["Last Name"].add_PropertyChanged({
						$dsWindow.FindName("CUSTOMOBJECTNAME").Text = $Prop["First Name"].Value + " " + $Prop["Last Name"].Value
					})

					$dsWindow.FindName("CUSTOMOBJECTNAME").IsEnabled = $false
					$dsWindow.FindName("CUSTOMOBJECTNAME").ToolTip = "Name derives from First and Last Name."
				}

				if($Prop["_Category"].Value -eq "Organisation")
                {
                    $dsWindow.FindName("CUSTOMOBJECTNAME").add_LostFocus({
                        $Prop["Company"].Value = $dsWindow.FindName("CUSTOMOBJECTNAME").Text
                    })

                   $Prop["Company"].add_PropertyChanged({
                        $dsWindow.FindName("CUSTOMOBJECTNAME").Text = $Prop["Company"].Value
                    })

                   $dsWindow.FindName("CUSTOMOBJECTNAME").IsEnabled = $false
                   $dsWindow.FindName("CUSTOMOBJECTNAME").ToolTip = "Name derives from Company."
                }

			}
		}


		#region CustomObjectClassifiedWindow
		"CustomObjectClassifiedWindow"
		{      
			IF ($Prop["_CreateMode"].Value -eq $true) 
			{
				$Prop["_Category"].Value = $Prop["_CustomObjectDefName"].Value

					$dsWindow.FindName("Categories").IsEnabled = $false
					$dsWindow.FindName("NumSchms").Visibility = "Collapsed"
					$Prop["_NumSchm"].Value = $Prop["_Category"].Value

				#IF($Prop["_XLTN_IDENTNUMBER"]){ $Prop["_XLTN_IDENTNUMBER"].Value = $UIString["LBL27"]}

				$dsWindow.Title = "New $($Prop["_Category"].Value)..."

				#synchronize property with CO name
				if($Prop["_Category"].Value -eq "Class")
				{
					$dsWindow.FindName("CUSTOMOBJECTNAME").add_LostFocus({
						$Prop["Class"].Value = $dsWindow.FindName("CUSTOMOBJECTNAME").Text
					})

					$Prop["Class"].add_PropertyChanged({
						$dsWindow.FindName("CUSTOMOBJECTNAME").Text = $Prop["Class"].Value
					})
				}

				if($Prop["_Category"].Value -eq "Term")
				{
					$dsWindow.FindName("CUSTOMOBJECTNAME").add_LostFocus({
						$Prop["Term EN"].Value = $dsWindow.FindName("CUSTOMOBJECTNAME").Text
					})

					$Prop["Term EN"].add_PropertyChanged({
						$dsWindow.FindName("CUSTOMOBJECTNAME").Text = $Prop["Term EN"].Value
					})
				}
			}

			#region EditMode
			IF ($Prop["_EditMode"].Value -eq $true) 
			{
				if($Prop["_ReadOnly"].Value -eq $true)
				{
					$dsWindow.Title = "Edit $($Prop["_Category"].Value) - $($Prop["Name"].Value) - $($UIString["LBL26"])"
				}
				else
				{
					$dsWindow.Title = "Edit $($Prop["_Category"].Value) - $($Prop["Name"].Value)"
				}

				#read existing classification elements
				$_classes = @()
				Try{ #likely not all properties are used...
					If ($Prop["_XLTN_SEGMENT"].Value.Length -gt 1){
						$_classes += $Prop["_XLTN_SEGMENT"].Value
						If ($Prop["_XLTN_MAINGROUP"].Value.Length -gt 1){
							$_classes += $Prop["_XLTN_MAINGROUP"].Value
							If ($Prop["_XLTN_GROUP"].Value.Length -gt 1){
								$_classes += $Prop["_XLTN_GROUP"].Value
								If ($Prop["_XLTN_SUBGROUP"].Value.Length -gt 1){
									$_classes += $Prop["_XLTN_SUBGROUP"].Value
								}
							}
						}
					}
				}
				catch {}
			}
			#endregion EditMode
			mAddCoCombo -_CoName "Segment" -_classes $_classes #enables classification for class objects
			# ToDo: createmode: activate last used classification
			
		}
		#endregion CustomObjectClassifiedWindow
		
		
		#region GoToInvSibling
		"GoToInvSibling"
		{
			$_t = $Prop["Internal ID"].Value

			$mTargetFile = Get-Content "$($env:appdata)\Autodesk\DataStandard 2024\mStrTabClick.txt"

			#create search conditions for 
			$srchConds = New-Object autodesk.Connectivity.WebServices.SrchCond[] 1
				$srchCond = New-Object autodesk.Connectivity.WebServices.SrchCond
				$propDefs = $vault.PropertyService.GetPropertyDefinitionsByEntityClassId("FILE")
				$propNames = @("Internal ID")
				$propDefIds = @{}
				foreach($name in $propNames) {
					$propDef = $propDefs | Where-Object { $_.DispName -eq $name }
					$propDefIds[$propDef.Id] = $propDef.DispName
				}
				$srchCond.PropDefId = $propDef.Id
				$srchCond.SrchOper = 3
				$srchCond.SrchTxt = $Prop["Internal ID"].Value

				$srchCond.PropTyp = [Autodesk.Connectivity.WebServices.PropertySearchType]::SingleProperty
				$srchCond.SrchRule = [Autodesk.Connectivity.WebServices.SearchRuleType]::Must
				$srchConds[0] = $srchCond
				$srchSort = New-Object autodesk.Connectivity.WebServices.SrchSort
				$mSearchStatus = New-Object autodesk.Connectivity.WebServices.SrchStatus
				$mBookmark = ""     
				$mResultAll = New-Object 'System.Collections.Generic.List[Autodesk.Connectivity.WebServices.File]'
				$mResultFiltered = New-Object 'System.Collections.Generic.List[Autodesk.Connectivity.WebServices.File]'
	
				while(($mSearchStatus.TotalHits -eq 0) -or ($mResultAll.Count -lt $mSearchStatus.TotalHits))
				{
					$mResultPage = $vault.DocumentService.FindFilesBySearchConditions($srchConds,@($srchSort),@(($vault.DocumentService.GetFolderRoot()).Id),$true,$false,[ref]$mBookmark,[ref]$mSearchStatus)
					if($mResultPage.Count -ne 0)
					{
						$mResultAll.AddRange($mResultPage)
					}
					else { break;}
		
					break; #limit the search result to the first result page; page scrolling not implemented in this snippet release
				}

				If($mResultAll.Count -lt $mSearchStatus.TotalHits)
				{
					$dsWindow.FindName("txtBlck_Notification1").Text = ([String]::Format($UIString["ADSK-GoToInvSibl_MSG00"], $mResultAll.Count, $mSearchStatus.TotalHits))
				}
				Else{
					$dsWindow.FindName("txtBlck_Notification1").Visibility = "Collapsed"
				}

				IF($mResultAll.Count -gt 0)
				{
					$mResultFiltered += $mResultAll | Where-Object {$_.Name -ne ($Prop["_FileName"].Value + $Prop["_FileExt"].Value)} # don't list the selected file's versions as parallel copies
					If ($mResultFiltered.Count -gt 0)
					{
						$dsWindow.FindName("mDerivatives1").ItemsSource = @(mGetResultMeta $mResultFiltered) # @() #the array of each file iterations meta data
					}
					$dsWindow.FindName("mDerivatives1").add_SelectionChanged({
						mDerivatives1Click
						If($dsWindow.FindName("mDerivatives1").SelectedItem)
							{
								$dsWindow.FindName("btnGoTo").IsEnabled = $true
							}
						})
				}
				IF($mResultFiltered.Count -lt 1)
				{
					$dsWindow.FindName("txtBlck_Notification1").Visibility = "Visible"
					$dsWindow.FindName("txtBlck_Notification1").Text = $UIString["ADSK-GoToInvSibl_MSG01"]
				}
		}
		#endregion GoToInvSibling

		"ActivateSchedTaskWindow"
		{
			ADSK.QS.ReadSchedTasks
			$dsWindow.FindName("dataGrdSchedTasks").add_SelectionChanged({ ADSK.QS.TaskSelectionChanged})
		}

		"FileImportWindow"
		{
			mInitializeFileImport
		}

		"ReserveNumberWindow"
		{
			$dsWindow.FindName("cmbNumType").add_SelectionChanged({
				mGetNumSchms
			})
		}

	}
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
		return
	}
	if ($VaultContext.SelectedObject.TypeId.SelectionContext -eq "ItemMaster" -and $xamlFile -eq "Associated Files.xaml")
	{
		$items = $vault.ItemService.GetItemsByIds(@($vaultContext.SelectedObject.Id))
		$item = $items[0]
		$itemids = @($item.Id)
		$assocFiles = @(GetAssociatedFiles $itemids $([System.IO.Path]::GetDirectoryName($VaultContext.UserControl.XamlFile)))
		$dsWindow.FindName("AssoicatedFiles").ItemsSource = $assocFiles
		return
	}
	if ($VaultContext.SelectedObject.TypeId.SelectionContext -eq "FileMaster" -and $xamlFile -eq "ADSK.QS.FileDataSheet.xaml")
	{
		$fileMasterId = $vaultContext.SelectedObject.Id
		$file = $vault.DocumentService.GetLatestFileByMasterId($fileMasterId)
		mInitializeClassificationTab -ParentType $null -file $file
		return
	}

	if ($VaultContext.SelectedObject.TypeId.SelectionContext -eq "ItemMaster" -and $xamlFile -eq "ADSK.QS.ItemFileClassification.xaml")
	{
		$items = $vault.ItemService.GetItemsByIds(@($vaultContext.SelectedObject.Id))
		$item = $items[0]
		$itemids = @($item.Id)
		$fileAssoc = $vault.ItemService.GetItemFileAssociationsByItemIds($itemids, "Primary")
		$file = $vault.DocumentService.GetFileById($fileAssoc[0].CldFileId)
		mInitializeClassificationTab -ParentType $null -file $file
		return
	}

	if ($VaultContext.SelectedObject.TypeId.SelectionContext -eq "ChangeOrder" -and $xamlFile -eq "ADSK.QS.EcoParentFolder.xaml") {
		#clear any data from previous selections:
		$dsWindow.FindName("dtgrdParentFolder").ItemsSource = $null
		$dsWindow.FindName("txtCategory").Text = ""
		$dsWindow.FindName("txtName").Text = ""
		$dsWindow.FindName("txtState").Text = ""
		$dsWindow.FindName("txtCreateDate").Text = ""
		$dsWindow.FindName("txtCreatedBy").Text = ""
		$dsWindow.FindName("txtComments").Text = ""

		#get the folder where the ECO has it's primary link to
		$mTargetLnks = @()
		[long]$mEcoParentFldId = $null		
		#filter target linked objects are folders and not custom objects
		$mTargetLnks = $vault.DocumentService.GetLinksByTargetEntityIds(@($VaultContext.SelectedObject.Id)) | Where-Object { $_.ParEntClsId -eq "FLDR" }

		if ($mTargetLnks.Count -gt 0) {
			$mEcoParentFldId = $vault.DocumentService.GetFolderById($mTargetLnks[0].ParentId).Id
			$mFldrProps = New-Object 'system.collections.generic.dictionary[[string],[object]]'
			
			#	there are some custom functions to enhance functionality; 2023 version added webservice and explorer extensions to be installed optionally
			$mVdsUtilities = "$($env:programdata)\Autodesk\Vault 2024\Extensions\Autodesk.VdsSampleUtilities\VdsSampleUtilities.dll"
			if (! (Test-Path $mVdsUtilities)) {
				#the basic utility installation only
				[System.Reflection.Assembly]::LoadFrom($Env:ProgramData + '\Autodesk\Vault 2024\Extensions\DataStandard\Vault.Custom\addinVault\VdsSampleUtilities.dll')
			}
			Else {
				#the extended utility activation
				[System.Reflection.Assembly]::LoadFrom($Env:ProgramData + '\Autodesk\Vault 2024\Extensions\Autodesk.VdsSampleUtilities\VdsSampleUtilities.dll')
			}

			$_mVltHelpers = New-Object VdsSampleUtilities.VltHelpers
			$_mVltHelpers.GetFolderProps($vaultConnection, $mEcoParentFldId, [ref]$mFldrProps)
			$dsWindow.FindName("dtgrdParentFolder").ItemsSource = $mFldrProps
			$dsWindow.FindName("txtCategory").Text = $mFldrProps["Category Name"]
			$dsWindow.FindName("txtName").Text = $mFldrProps["Name"]
			$dsWindow.FindName("txtState").Text = $mFldrProps["State"]
			$dsWindow.FindName("txtCreateDate").Text = $mFldrProps["Create Date"]
			$dsWindow.FindName("txtCreatedBy").Text = $mFldrProps["Created By"]
			$dsWindow.FindName("txtComments").Text = $mFldrProps["Comments"]
		}
		return
	}
		
	if ($VaultContext.SelectedObject.TypeId.SelectionContext -eq "ChangeOrder" -and $xamlFile -eq "ADSK.QS.TaskLinks.xaml")
	{
		$mCoId = $VaultContext.SelectedObject.Id

		#to get links of COs to CUSTENT we need to analyse the CUSTENTS for linked children of type CO
		#get all CUSTENTS of category $_CoName first, then iterate the result and analyse each items links: do they link to the current CO id?
        $_CoName = $UIString["ADSK-LnkdTask-00"]
		$_allCustents = mgetCustomEntityList $_CoName
		$_LinkedCustentIDs = @()
		Foreach ($_Custent in $_allCustents)
		{
			$_AllLinks1 = $vault.DocumentService.GetLinksByParentIds(@($_Custent.Id),@("CO"))
			If($_AllLinks1) #the current custent has links; check that the current ECO is one of these link's target
			{
				$_match = $_AllLinks1 | Where { $_.ToEntId -eq $mCoId }
				If($_match){ $_LinkedCustentIDs += $_Custent.Id}
			}		
		}
		
		#get all detail information of $_LinkedCustentIDs and push to the datagrid
		If($_LinkedCustentIDs.Count -ne 0)
		{
			$_LinkedCustentsMeta = @(mGetAssocCustents $_LinkedCustentIDs)
		}
		$dsWindow.FindName("dataGrdLinks").ItemsSource = $_LinkedCustentsMeta
		$dsWindow.FindName("dataGrdLinks").add_SelectionChanged({
			$dsWindow.FindName("txtComments").Text = $dsWindow.FindName("dataGrdLinks").SelectedItem.Comments
			mTaskClick
		})
		return
	}

	if ($VaultContext.SelectedObject.TypeId.SelectionContext -eq "FileMaster" -and $xamlFile -eq "ADSK.QS.FileItemDataSheet.xaml")
	{
		#clear any data from previous selections:
		mClearItemView
		$fileMasterId = $vaultContext.SelectedObject.Id
		$file = $vault.DocumentService.GetLatestFileByMasterId($fileMasterId)
		#fill item system and user properties
		mFillItemView -file $file
		#fill grid of associated files; primary only Yes/No
		$itemids = @($item.Id)
		$assocFiles = @(mFileItemTabGetAssocFiles $itemids $([System.IO.Path]::GetDirectoryName($VaultContext.UserControl.XamlFile)))
		$dsWindow.FindName("AssociatedFiles").ItemsSource = $assocFiles
		return
	}

	#region Documentstructure Extension
		if ($VaultContext.SelectedObject.TypeId.SelectionContext -eq "FileMaster" -and $xamlFile -eq "ADSK.QS.FileDocStructure.xaml")
		{
			Add-Type -Path 'C:\ProgramData\Autodesk\Vault 2024\Extensions\DataStandard\Vault.Custom\addinVault\UsesWhereUsed.dll'
			$file = $vault.DocumentService.GetLatestFileByMasterId($vaultContext.SelectedObject.Id)
			$treeNode = New-Object UsesWhereUsed.TreeNode($file, $vaultConnection)
			$dsWindow.FindName("Uses").ItemsSource = @($treeNode)

			$dsWindow.FindName("Uses").add_SelectedItemChanged({
				mUwUsdChldrnClick
				#$dsDiag.Trace("Child selected")
			})
			$dsWindow.FindName("WhereUsed").add_SelectedItemChanged({
				mUwUsdPrntClick
				#$dsDiag.Trace("Child selected")
			})
			return
		}
	#endregion documentstructure
	
	#powerPLM Tabs run separated script
	OnTabContextChanged_Fusion360Manage
}

function GetNewCustomObjectName
{
	#region VDS-PDMC-Sample
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

			$UIString["ClassTerms_00"] #CatalogTermsTranslations
			{
				if($dsWindow.FindName("DSNumSchmsCtrl").NumSchmFieldsEmpty -eq $false)
				{
					Try {$Prop["_XLTN_IDENTNUMBER"].Value = $Prop["_GeneratedNumber"].Value}
					catch { $dsDiag.Trace("UDP to save ident number does not exist")}
				}
				$customObjectName = $Prop["_XLTN_TERM"].Value
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
	#endregion VDS-PDMC-Sample
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
		
		#VDS-PDMC-Sample
			If($Prop["_XLTN_PARTNUMBER"]) { $Prop["_XLTN_PARTNUMBER"].Value = $Prop["_GeneratedNumber"].Value }
		#VDS-PDMC-Sample
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
		#region VDS-PDMC-Sample
			$global:mFileCategories = $Prop["_Category"].ListValues #$vault.CategoryService.GetCategoriesByEntityClassId("FILE", $true)
			return $global:mFileCategories | Sort-Object -Property "Name" #Ascending is default; no option required
		#endregion
	}
	elseif ($dsWindow.Name -eq "FolderWindow")
	{
		return $vault.CategoryService.GetCategoriesByEntityClassId("FLDR", $true) | Sort-Object -Property "Name" #Ascending is default; no option required
	}
	elseif ($dsWindow.Name -eq "CustomObjectWindow")
	{
		return $vault.CategoryService.GetCategoriesByEntityClassId("CUSTENT", $true)
	}
	elseif ($dsWindow.Name -eq "CustomObjectClassifiedWindow")
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
				#$numSchems = $numSchems | Sort-Object -Property IsDflt -Descending
				#region VDS-PDMC-Sample
					$mWindowName = $dsWindow.Name
					switch($mWindowName)
					{
						"FileWindow"
						{
							$_FilteredNumSchems = @()
							$_Default = $numSchems | Where { $_.IsDflt -eq $true}
							$_FilteredNumSchems += ($_Default)
							$dsWindow.FindName("NumSchms").IsEnabled = $true
							$noneNumSchm = New-Object 'Autodesk.Connectivity.WebServices.NumSchm'
							$noneNumSchm.Name = $UIString["LBL77"] # None 
							$_FilteredNumSchems += $noneNumSchm
							return $_FilteredNumSchems
						}

						"FolderWindow" 
						{
							#numbering schemes are available for items and files specificly; 
							#for folders we use the file numbering schemes and filter to these, that have a corresponding name in folder categories
							$_FolderCats = $vault.CategoryService.GetCategoriesByEntityClassId("FLDR", $true)
							$_FilteredNumSchems = @()
							Foreach ($item in $_FolderCats) 
							{
								$_temp = $numSchems | Where { $_.Name -eq $item.Name}
								$_FilteredNumSchems += ($_temp)
							}
							#we need an option to unselect a previosly selected numbering; to achieve that we add a virtual one, named "None"
							$noneNumSchm = New-Object 'Autodesk.Connectivity.WebServices.NumSchm'
							$noneNumSchm.Name = "None"
							$_FilteredNumSchems += ($noneNumSchm)

							return $_FilteredNumSchems
						}

						"CustomObjectWindow"
						{
							$_FilteredNumSchems = $numSchems | Where { $_.Name -eq $Prop["_Category"].Value}
							return $_FilteredNumSchems
						}

						"CustomObjectClassifiedWindow"
						{
							$_FilteredNumSchems = $numSchems | Where-Object { $_.Name -eq $Prop["_Category"].Value}
							return $_FilteredNumSchems
						}

						default
						{
							$numSchems = $numSchems | Sort-Object -Property IsDflt -Descending
							return $numSchems
						}
					}
				#region
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
	#$dsDiag.Trace(">> GenerateNumber")
	$selected = $dsWindow.FindName("NumSchms").Text
	if($selected -eq "") { return "na" }

	$ns = $global:numSchems | Where-Object { $_.Name.Equals($selected) }
	switch ($selected) {
		"Sequential" { $NumGenArgs = @(""); break; }
		default      { $NumGenArgs = @(""); break; }
	}
	#$dsDiag.Trace("GenerateFileNumber($($ns.SchmID), $NumGenArgs)")
	$vault.DocumentService.GenerateFileNumber($ns.SchmID, $NumGenArgs)
	#$dsDiag.Trace("<< GenerateNumber")
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
	#$dsDiag.Trace(">> Template Changed ...")
	
	#check if cmbTemplates is empty
	if ($dsWindow.FindName("TemplateCB").ItemsSource.Count -lt 1)
	{
		#$dsDiag.Trace("Template changed exits due to missing templates")
		return
	}

	$mContext = $dsWindow.DataContext
	$mTemplatePath = $mContext.TemplatePath
	$mTemplateFile = $mContext.SelectedTemplate.Name
	$mTemplate = $mTemplatePath + "/" + $mTemplateFile
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

	#region navigation & derivation structure
	If($Prop[($UIString["ADSK-GoToNavigation_Prop01"])]){
		If($mContext.SelectedTemplate)
		{
			$Prop[($UIString["ADSK-GoToNavigation_Prop01"])].Value = $mContext.SelectedTemplate.Name
		}
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
			$DesignCats = @("Drawing Inventor", "Drawing AutoCAD", "Part", "Assembly", "Weldment Assembly", "Sheet Metal Part")
			$OfficeCats = @("Office")
			#VDS-PDMC-Sample uses the default numbering scheme for files; GoTo GetNumSchms function to disable this filter incase you'd like to apply numbering per category for files as well
			If($DesignCats -contains $Prop["_Category"].Value)
			{
				If ($Prop['_XLTN_DESIGNER'].Value -eq $null) 
				{ 
					$Prop['_XLTN_DESIGNER'].Value = $Vault.AdminService.Session.User.Name
				}
			}
			
			if($OfficeCats -contains $Prop["_Category"].Value)
			{
				If ($Prop['_XLTN_AUTHOR'].Value -eq $null) 
				{
					$Prop['_XLTN_AUTHOR'].Value = $Vault.AdminService.Session.User.Name
				}
			}
			
			#Copy Parent Project Number to file property "Project" if exists
			If($Prop["_XLTN_PROJECT"]){
				mGetProjectFolderPropToVaultFile -mFolderSourcePropertyName "Name" -mFileTargetPropertyName $Prop["_XLTN_PROJECT"].Name
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
	} #end switch window
} #end function m_CategoryChanged

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
	}
	Catch
	{
		[Autodesk.DataManagement.Client.Framework.Forms.Library]::ShowError("Help Target not found", "Vault VDS-PDMC-Sample Client")
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
    $FolderNamePropDef = $FolderPropDefs | where {$_.SysName -eq "Name"}
    $srchCond = New-Object 'Autodesk.Connectivity.WebServices.SrchCond'
    $srchCond.PropDefId = $FolderNamePropDef.Id
    $srchCond.PropTyp = "SingleProperty"
    $srchCond.SrchOper = 3 #is equal
    $srchCond.SrchRule = "Must"
    $srchCond.SrchTxt = $FolderName

    $bookmark = ""
    $status = $null
    $totalResults = @()
    while ($status -eq $null -or $totalResults.Count -lt $status.TotalHits)
    {
        $results = $vault.DocumentService.FindFoldersBySearchConditions(@($srchCond),$null, @($rootFolder.Id), $false, [ref]$bookmark, [ref]$status)

        if ($results -ne $null)
        {
            $totalResults += $results
        }
        else {break}
    }
    return $totalResults;
}

#added by 2022 Update 1 - to resolve issue with cloaked template folders for users, Update 2 added support for Vault Office
function GetTemplateFolders
{
	$xmlpath = "$env:programdata\Autodesk\Vault 2024\Extensions\DataStandard\Vault.Custom\Configuration\ADSK.QS.File.xml"

	if ($_IsOfficeClient) {
		$xmlpath = "$env:programdata\Autodesk\Vault 2024\Extensions\DataStandard\Vault.Custom\Configuration\ADSK.QS.FileOffice.xml"
	}

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

