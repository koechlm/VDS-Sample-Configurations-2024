#=============================================================================
# PowerShell script sample for Vault Data Standard                            
#			 Autodesk Vault - VDS MFG Sample 2024  								  
# This sample is based on VDS 2024 RTM and adds functionality and rules    
#                                                                             
# Copyright (c) Autodesk - All rights reserved.                               
#                                                                             
# THIS SCRIPT/CODE IS PROVIDED "AS IS" WITHOUT WARRANTY OF ANY KIND, EITHER   
# EXPRESSED OR IMPLIED, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED WARRANTIES 
# OF MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE, OR NON-INFRINGEMENT.  
#=============================================================================

function InitializeWindow {

	#region rules applying commonly
	$dsWindow.Title = SetWindowTitle
	#endregion rules applying commonly

	$mWindowName = $dsWindow.Name
	switch ($mWindowName) {
		"InventorWindow" {
			#support given file name and path for Inventor ShrinkWrap file (_SuggestedVaultPath is empty for these)
			$global:mShrnkWrp = $false

			InitializeBreadCrumb

			#set the active user as Inventor Designer
			$mUser = $vault.AdminService.Session.User
			$Prop["Designer"].Value = $mUser.Name

			#	there are some custom functions to enhance functionality; 2024 version added webservice and explorer extensions to be installed optionally
			$mVdsUtilities = "$($env:programdata)\Autodesk\Vault 2024\Extensions\Autodesk.VdsSampleUtilities\VdsSampleUtilities.dll"
			if (! (Test-Path $mVdsUtilities)) {
				#the basic utility installation only
				[System.Reflection.Assembly]::LoadFrom($Env:ProgramData + '\Autodesk\Vault 2024\Extensions\DataStandard\Vault.Custom\addinVault\VdsSampleUtilities.dll')
			}
			Else {
				#the extended utility activation
				[System.Reflection.Assembly]::LoadFrom($Env:ProgramData + '\Autodesk\Vault 2024\Extensions\Autodesk.VdsSampleUtilities\VdsSampleUtilities.dll')
			}

			$_mInvHelpers = New-Object VdsSampleUtilities.InvHelpers 

			#	initialize the context for Drawings or presentation files as these have Vault Option settings		
			if ($Prop["_GenerateFileNumber4SpecialFiles"].Value -eq $true) {
				$dsWindow.FindName("GFN4Special").IsChecked = $true # this checkbox is used by the XAML dialog styles, to enable / disable or show / hide controls
			}

			#enable/disable UI elements for documentation files
			$mInvDocuFileTypes = (".IDW", ".DWG", ".IPN") #to compare that the current new file is one of the special files the option applies to
			if ($mInvDocuFileTypes -contains $Prop["_FileExt"].Value) {
				$global:mIsInvDocumentationFile = $true
				$dsWindow.FindName("chkBxIsInvDocuFileType").IsChecked = $true

				#support empty (no model view) documentation (DWG, IDW, IPN),  or a sketched 2D drawing (DWG, IDW)
				$_ModelFullFileName = $_mInvHelpers.m_GetMainViewModelPath($Application)
				#model documentation; note - during model copy/replace incl. drawing $_ModelFullFileName is null => check number of referenced files instead to differentiate from sketch only drawings.				
				If ($global:mIsInvDocumentationFile -eq $true -and $Prop["_GenerateFileNumber4SpecialFiles"].Value -eq $false -and $Document.ReferencedFiles.Count -gt 0) { 
					$dsWindow.FindName("BreadCrumb").IsEnabled = $false
					$dsWindow.FindName("GroupFolder").Visibility = "Collapsed"
					$dsWindow.FindName("grdShortCutPane").Visibility = "Collapsed"
				}
				#sketched or empty drawing
				Else {
					$Prop["_GenerateFileNumber4SpecialFiles"].Value = $true #override the application settings for 
					$dsWindow.FindName("BreadCrumb").IsEnabled = $true
					$dsWindow.FindName("chkBxIsInvDocuFileType").IsChecked = $false
				}
			}

			#enable option to remove orphaned sheets in drawings
			if (-not $Prop["_SaveCopyAsMode"].Value -eq $true) { #the SaveCopyAs.xaml does not have the option to remove orhaned sheets
				if (@(".DWG", ".IDW") -contains $Prop["_FileExt"].Value) {
					$dsWindow.FindName("RmOrphShts").Visibility = "Visible"
				}
				else {
					$dsWindow.FindName("RmOrphShts").Visibility = "Collapsed"
				}
			}

			switch ($Prop["_CreateMode"].Value) {
				$true {
					#reset the part number for new files as Inventor writes the file name (no extension) as a default.
					If ($Prop["Part Number"]) { #Inventor returns null if the Part Number has no custom value
						if ($Prop["Part Number"].Value -ne "") {
							$Prop["Part Number"].Value = ""
						}
					}
					InitializeInventorCategory
					InitializeInventorNumSchm
					If ($dsWindow.FindName("lstBoxShortCuts")) {
						$dsWindow.FindName("lstBoxShortCuts").add_SelectionChanged({
								mScClick
							})
					}

					#region FDU Support --------------------------------------------------------------------------
					
					# Read FDS related internal meta data; required to manage particular workflows
					If ($_mInvHelpers.m_FDUActive($Application) -ne $false) {
						#[Autodesk.DataManagement.Client.Framework.Forms.Library]::ShowMessage("Active FDU-AddIn detected","VDS MFG Sample", "OK")
						$_mFdsKeys = $_mInvHelpers.m_GetFdsKeys($Application, @{})

						# some FDS workflows require VDS cancellation; add the conditions to the event handler _Loaded below
						$dsWindow.add_Loaded({
								IF ($mSkipVDS -eq $true) {
									$dsWindow.CancelWindowCommand.Execute($this)	
								}
							})

						# FDS workflows with individual settings					
						$dsWindow.FindName("Categories").add_SelectionChanged({
								If ($Prop["_Category"].Value -eq "Factory Asset" -and $Document.FileSaveCounter -eq 0) { #don't localize name according FDU fixed naming
									$paths = @("Factory Asset Library Source")
									mActivateBreadCrumbCmbs $paths
									$dsWindow.FindName("NumSchms").SelectedIndex = 1
								}
							})
				
						If ($_mFdsKeys.ContainsKey("FdsType") -and $Document.FileSaveCounter -eq 0 ) {
							#$dsDiag.Trace(" FDS File Type detected")
							# for new assets we suggest to use the source file folder name, nothing else
							If ($_mFdsKeys.Get_Item("FdsType") -eq "FDS-Asset") {
								# only the MSDCE FDS configuration template provides a category for assets, check for this otherwise continue with the selection done before
								$mCatName = GetCategories | Where { $_.Name -eq "Factory Asset" }
								IF ($mCatName) { $Prop["_Category"].Value = "Factory Asset" }
							}
							# skip for publishing the 3D temporary file save event for VDS
							If ($_mFdsKeys.Get_Item("FdsType") -eq "FDS-Asset" -and $Application.SilentOperation -eq $true) { 
								$global:mSkipVDS = $true
							}
							If ($_mFdsKeys.Get_Item("FdsType") -eq "FDS-Asset" -and $Document.InternalName -ne $Application.ActiveDocument.InternalName) {
								$global:mSkipVDS = $true
							}

							# 
							If ($_mFdsKeys.Get_Item("FdsType") -eq "FDS-Layout" -and $_mFdsKeys.Count -eq 1) {
								# only the MSDCE FDS configuration template provides a category for layouts, check for this otherwise continue with the selection done before
								$mCatName = GetCategories | Where { $_.Name -eq "Factory Layout" }
								IF ($mCatName) { $Prop["_Category"].Value = "Factory Layout" }
							}

							# FDU 2019.22.0.2 and later allow to skip dynamically, instead of skipping in general by the SkipVDSon1stSave.IAM template
							If ($_mFdsKeys.Get_Item("FdsType") -eq "FDS-Layout" -and $_mFdsKeys.Count -gt 1 -and $Document.FileSaveCounter -eq 0) {
								$dsWindow.add_Loaded({
										$dsWindow.CancelWindowCommand.Execute($this)	
									})
							}
						}
					}
					#endregion FDU Support --------------------------------------------------------------------------

					#retrieve 3D model properties (Inventor captures these also, but too late; we are currently before save event transfers model properties to drawing properties) 
					# but don't do this, if the copy mode is active
					if ($Prop["_CopyMode"].Value -eq $false) {	
						if (($Prop["_FileExt"].Value -eq ".IDW") -or ($Prop["_FileExt"].Value -eq ".DWG" )) {
							if ($_ModelFullFileName -ne $null) {
								$Prop["Title"].Value = $_mInvHelpers.m_GetMainViewModelPropValue($Application, $_ModelFullFileName, "Title")
								$Prop["Description"].Value = $_mInvHelpers.m_GetMainViewModelPropValue($Application, $_ModelFullFileName, "Description")
								$_ModelPartNumber = $_mInvHelpers.m_GetMainViewModelPropValue($Application, $_ModelFullFileName, "Part Number")

								if ($_ModelPartNumber -ne $null) { # must not write empty part numbers 
									$Prop["Part Number"].Value = $_ModelPartNumber 
								}
							}
						}

						if ($Prop["_FileExt"].Value -eq ".IPN") {
							
							if ($_ModelFullFileName -ne $null) {
								$Prop["Title"].Value = $_mInvHelpers.m_GetMainViewModelPropValue($Application, $_ModelFullFileName, "Title")
								$Prop["Description"].Value = $_mInvHelpers.m_GetMainViewModelPropValue($Application, $_ModelFullFileName, "Description")
								$Prop["Part Number"].Value = $_mInvHelpers.m_GetMainViewModelPropValue($Application, $_ModelFullFileName, "Part Number")
								$Prop["Stock Number"].Value = $_mInvHelpers.m_GetMainViewModelPropValue($Application, $_ModelFullFileName, "Stock Number")
								# for custom properties there is always a risk that any does not exist
								try {
									$Prop[$_iPropSemiFinished].Value = $_mInvHelpers.m_GetMainViewModelPropValue($Application, $_ModelFullFileName, $_iPropSemiFinished)
									$_t1 = $_mInvHelpers.m_GetMainViewModelPropValue($Application, $_ModelFullFileName, $_iPropSpearWearPart)
									if ($_t1 -ne "") {
										$Prop[$_iPropSpearWearPart].Value = $_t1
									}
								} 
								catch {
									$mErrorMsg = "Set path, filename and properties for IPN: Failed to write a custom property."
									[Autodesk.DataManagement.Client.Framework.Forms.Library]::ShowError($mErrorMsg, "VDS Sample Configuration")
								}
							}
						}

					} # end of copy mode = false check

					#overridden display names will change suggested file names. Reset overrides!
					if ($Prop["_CopyMode"].Value) {
						$Document.DisplayNameOverridden = $false
					}

					if ($Prop["_CopyMode"].Value -and @(".DWG", ".IDW", ".IPN") -contains $Prop["_FileExt"].Value) {
						$Prop["DocNumber"].Value = $Prop["DocNumber"].Value.TrimStart($UIString["CFG2"])
					}
					
				}
				$false { # EditMode = True
					if ((Get-Item $document.FullFileName).IsReadOnly) {
						$dsWindow.FindName("btnOK").IsEnabled = $false
					}

					#VDS MFG Sample - handle weldbead material" 
					$mCat = $Global:mCategories | Where { $_.Name -eq $UIString["MSDCE_CAT11"] } # weldment assembly
					IF ($Prop["_Category"].Value -eq $mCat.Name) { 
						try {
							$Prop["Material"].Value = $Document.ComponentDefinition.WeldBeadMaterial.DisplayName
						}
						catch {
							$mErrorMsg = "Failed reading weld bead material; most likely the assembly subtype is not an weldment."
							[Autodesk.DataManagement.Client.Framework.Forms.Library]::ShowError($mErrorMsg, "VDS Sample Configuration")
						}
					}

				}
				default {

				}
			} #end switch Create / Edit Mode

		}
		"InventorFrameWindow" {
			mInitializeFGContext
		}
		"InventorDesignAcceleratorWindow" {
			mInitializeDAContext
		}
		"InventorPipingWindow" {
			mInitializeTPContext
		}
		"InventorHarnessWindow" {
			mInitializeCHContext
		}
		"AutoCADWindow" {
			InitializeBreadCrumb
			switch ($Prop["_CreateMode"].Value) {
				$true {
					#$dsDiag.Trace(">> CreateMode Section executes...")

					#set the active user as Designer for file property mapping or mechanical title attribute mapping
					$mUser = $vault.AdminService.Session.User
					if ($Prop["GEN-TITLE-NAME"]) { #if($Prop["Designer"])
						$Prop["GEN-TITLE-NAME"].Value = $mUser.Name #	$Prop["Designer"].Value = $mUser.Name
					}
					#set the current date as orig. Create Date
					if ($Prop["GEN-TITLE-DAT"]){
						$Prop["GEN-TITLE-DAT"].Value = (Get-Date).ToString('yyyy-MM-dd')
					}

					# set the category: VDS MFG Sample = "AutoCAD Drawing"
					$mCatName = GetCategories | Where { $_.Name -eq $UIString["MSDCE_CAT01"] }
					IF ($mCatName) { $Prop["_Category"].Value = $UIString["MSDCE_CAT01"] }
					# in case the current vault is not quickstart, but a plain MFG default configuration
					Else {
						$mCatName = GetCategories | Where { $_.Name -eq $UIString["CAT1"] } #"Engineering"
						IF ($mCatName) { $Prop["_Category"].Value = $UIString["CAT1"] }
					}

					#region FDU Support ------------------
					$_FdsUsrData = $Document.UserData #Items FACT_* are added by FDU

					#	there are some custom functions to enhance functionality; 2024 version added webservice and explorer extensions to be installed optionally
					$mVdsUtilities = "$($env:programdata)\Autodesk\Vault 2024\Extensions\Autodesk.VdsSampleUtilities\VdsSampleUtilities.dll"
					if (! (Test-Path $mVdsUtilities)) {
						#the basic utility installation only
						[System.Reflection.Assembly]::LoadFrom($Env:ProgramData + '\Autodesk\Vault 2024\Extensions\DataStandard\Vault.Custom\addinVault\VdsSampleUtilities.dll')
					}
					Else {
						#the extended utility activation
						[System.Reflection.Assembly]::LoadFrom($Env:ProgramData + '\Autodesk\Vault 2024\Extensions\Autodesk.VdsSampleUtilities\VdsSampleUtilities.dll')
					}

					$_mAcadHelpers = New-Object VdsSampleUtilities.AcadHelpers
					$_FdsBlocksInDrawing = $_mAcadHelpers.mFdsDrawing($Application)
					If ($_FdsUsrData.Get_Item("FACT_FactoryDocument") -and $_FdsBlocksInDrawing ) {
						#try to activate category "Factory Layout"
						$Prop["_Category"].Value = "Factory Layout"
					}
					#endregion FDU Support ---------------

					If ($dsWindow.FindName("lstBoxShortCuts")) {
						$dsWindow.FindName("lstBoxShortCuts").add_SelectionChanged({
								mScClick
							})
					}
				}
				$false {
					if ($Prop["_EditMode"].Value -and $Document.IsReadOnly) {
						$dsWindow.FindName("btnOK").IsEnabled = $false
					}
				}
			}

			#endregion VDS MFG Sample
		}
		default {
			#rules applying for other windows not listed before
		}
	} #end switch windows
	
	$global:expandBreadCrumb = $true
	
	InitializeFileNameValidation #do this at the end of all other event initializations
}

function AddinLoaded {
	#Executed when DataStandard is loaded in Inventor/AutoCAD
	$m_File = "$($env:appdata)\Autodesk\DataStandard 2024\Folder2024.xml"
	if (!(Test-Path $m_File)) {
		$source = "$($env:ProgramData)\Autodesk\Vault 2024\Extensions\DataStandard\Vault.Custom\Folder2024.xml"
		Copy-Item $source $m_File
	}
}

function AddinUnloaded {
	#Executed when DataStandard is unloaded in Inventor/AutoCAD
}

function SetWindowTitle {
	$mWindowName = $dsWindow.Name
	switch ($mWindowName) {
		"InventorFrameWindow" {
			$windowTitle = $UIString["LBL54"]
		}
		"InventorDesignAcceleratorWindow" {
			$windowTitle = $UIString["LBL50"]
		}
		"InventorPipingWindow" {
			$windowTitle = $UIString["LBL39"]
		}
		"InventorHarnessWindow" {
			$windowTitle = $UIString["LBL44"]
		}
		"InventorWindow" {
			if ($Prop["_CreateMode"].Value) {
				if ($Prop["_CopyMode"].Value) {
					$windowTitle = "$($UIString["LBL60"]) - $($Prop["_OriginalFileName"].Value)"
				}
				elseif ($Prop["_SaveCopyAsMode"].Value) {
					$windowTitle = "$($UIString["LBL72"]) - $($Prop["_OriginalFileName"].Value)"
				}
				else {
					$windowTitle = "$($UIString["LBL24"]) - $($Prop["_OriginalFileName"].Value)"
				}
			}
			else {
				$windowTitle = "$($UIString["LBL25"]) - $($Prop["_FileName"].Value)"
			}
			if ($Prop["_EditMode"].Value -and (Get-Item $document.FullFileName).IsReadOnly) {
				$windowTitle = "$($UIString["LBL25"]) - $($Prop["_FileName"].Value) - $($UIString["LBL26"])"
				$dsWindow.FindName("btnOK").ToolTip = $UIString["LBL26"]
			}
		}
		"AutoCADWindow" {
			if ($Prop["_CreateMode"].Value) {
				if ($Prop["_CopyMode"].Value) {
					$windowTitle = "$($UIString["LBL60"]) - $($Prop["_OriginalFileName"].Value)"
				}
				elseif ($Prop["_SaveCopyAsMode"].Value) {
					$windowTitle = "$($UIString["LBL72"]) - $($Prop["_OriginalFileName"].Value)"
				}
				else {
					$windowTitle = "$($UIString["LBL24"]) - $($Prop["_OriginalFileName"].Value)"
				}
			}
			else {
				$windowTitle = "$($UIString["LBL25"]) - $($Prop["_FileName"].Value)"
			}
			if ($Prop["_EditMode"].Value -and $Document.IsReadOnly) {
				$windowTitle = "$($UIString["LBL25"]) - $($Prop["_FileName"].Value) - $($UIString["LBL26"])"
				$dsWindow.FindName("btnOK").ToolTip = $UIString["LBL26"]
			}
		}
		default #applies to InventorWindow and AutoCADWindow
		{}
	}
	return $windowTitle
}

function InitializeInventorNumSchm {
	if ($Prop["_SaveCopyAsMode"].Value -eq $true) {
		$Prop["_NumSchm"].Value = $UIString["LBL77"]
	}
	if ($Prop["_Category"].Value -eq $UIString["MSDCE_CAT12"]) { #Substitutes, as reference parts should not retrieve individual new number
		$Prop["_NumSchm"].Value = $UIString["LBL77"]
	}
	if ($dsWindow.Name -eq "InventorFrameWindow") {
		$Prop["_NumSchm"].Value = $UIString["LBL77"]
	}
}

function InitializeInventorCategory {
	$mDocType = $Document.DocumentType
	$mDocSubType = $Document.SubType #differentiate part/sheet metal part and assembly/weldment assembly
	switch ($mDocType) {
		'12291' { #assembly 
			$mCatName = GetCategories | Where { $_.Name -eq $UIString["MSDCE_CAT10"] } #assembly, available in PDMC-Sample Vault
			IF ($mCatName) { 
				$Prop["_Category"].Value = $UIString["MSDCE_CAT10"]
			}
			$mCatName = GetCategories | Where { $_.Name -eq $UIString["MSDCE_CAT02"] }
			IF ($mCatName) { 
				$Prop["_Category"].Value = $UIString["MSDCE_CAT02"] #3D Component, e.g. PDMC-Sample
			}
			Else {
				$mCatName = GetCategories | Where { $_.Name -eq $UIString["CAT1"] } #"Engineering"
				IF ($mCatName) { 
					$Prop["_Category"].Value = $UIString["CAT1"]
				}
			}
			If ($mDocSubType -eq "{28EC8354-9024-440F-A8A2-0E0E55D635B0}") { #weldment assembly
				$mCatName = GetCategories | Where { $_.Name -eq $UIString["MSDCE_CAT11"] } # weldment assembly
				IF ($mCatName) { 
					$Prop["_Category"].Value = $UIString["MSDCE_CAT10"]
				}
			} 
		}
		'12290' { #part
			$mCatName = GetCategories | Where { $_.Name -eq $UIString["MSDCE_CAT08"] } #Part, available PDMC-Sample Vault
			IF ($mCatName) { 
				$Prop["_Category"].Value = $UIString["MSDCE_CAT08"]
			}
			$mCatName = GetCategories | Where { $_.Name -eq $UIString["MSDCE_CAT02"] }
			IF ($mCatName) { 
				$Prop["_Category"].Value = $UIString["MSDCE_CAT02"] #3D Component, available in MFG-Sample Vault
			}
			Else {
				$mCatName = GetCategories | Where { $_.Name -eq $UIString["CAT1"] } #"Engineering"
				IF ($mCatName) { 
					$Prop["_Category"].Value = $UIString["CAT1"]
				}
			}
			If ($mDocSubType -eq "{9C464203-9BAE-11D3-8BAD-0060B0CE6BB4}") {
				$mCatName = GetCategories | Where { $_.Name -eq $UIString["MSDCE_CAT09"] } #sheet metal part, available PDMC-Sample Vault
				IF ($mCatName) { 
					$Prop["_Category"].Value = $UIString["MSDCE_CAT09"]
				}
			}
			If ($Document.IsSubstitutePart -eq $true) { 
				$mCatName = GetCategories | Where { $_.Name -eq $UIString["MSDCE_CAT12"] } #substitute, available PDMC-Sample Vault
				IF ($mCatName) { 
					$Prop["_Category"].Value = $UIString["MSDCE_CAT12"]
				}
			}			
		}
		'12292' { #drawing
			$mCatName = GetCategories | Where { $_.Name -eq $UIString["MSDCE_CAT00"] }
			IF ($mCatName) { $Prop["_Category"].Value = $UIString["MSDCE_CAT00"] }
			Else { # in case the current vault is not MFG-Sample (Quickstart, but a plain MFG default configuration
				$mCatName = GetCategories | Where { $_.Name -eq $UIString["CAT1"] } #"Engineering"
				IF ($mCatName) { $Prop["_Category"].Value = $UIString["CAT1"] }
			}
		}
		'12293' { #presentation
			$mCatName = GetCategories | Where { $_.Name -eq $UIString["MSDCE_CAT13"] } #presentation, available PDMC-Sample Vault
			IF ($mCatName) { 
				$Prop["_Category"].Value = $UIString["MSDCE_CAT13"]
			}
			$mCatName = GetCategories | Where { $_.Name -eq $UIString["MSDCE_CAT02"] } #3D Component, Quickstart, e.g. MFG-2019-PRO-EN
			IF ($mCatName) { 
				$Prop["_Category"].Value = $UIString["MSDCE_CAT02"]
			}
			Else {
				$mCatName = GetCategories | Where { $_.Name -eq $UIString["CAT1"] } #"Engineering"
				IF ($mCatName) { 
					$Prop["_Category"].Value = $UIString["CAT1"]
				}
			}
		}
	} #DocType Switch
}

function GetNumSchms {
	try {
		if (-Not $Prop["_EditMode"].Value) {
			#VDS MFG Sample - there is the use case that we don't need a number: IDW/DWG, IPN and Option Generate new file number = off
			If ($global:mIsInvDocumentationFile -eq $true -and $Prop["_GenerateFileNumber4SpecialFiles"].Value -eq $false -and $Document.ReferencedFiles.Count -gt 0) { 
				return
			}
			#Adopted from a DocumentService call, which always pulls FILE class numbering schemes
			[System.Collections.ArrayList]$numSchems = @($vault.NumberingService.GetNumberingSchemes('FILE', 'Activated'))

			$_FilteredNumSchems = @()
			$_Default = $numSchems | Where { $_.IsDflt -eq $true }
			$_FilteredNumSchems += ($_Default)
			if ($Prop["_NumSchm"].Value) { $Prop["_NumSchm"].Value = $_FilteredNumSchems[0].Name } #note - functional dialogs don't have the property _NumSchm, therefore we conditionally set the value
			$dsWindow.FindName("NumSchms").IsEnabled = $true
			$dsWindow.FindName("NumSchms").SelectedValue = $_FilteredNumSchems[0].Name
			#add the "None" scheme to allow user interactive file name input
			$noneNumSchm = New-Object 'Autodesk.Connectivity.WebServices.NumSchm'
			$noneNumSchm.Name = $UIString["LBL77"] # None 
			$_FilteredNumSchems += $noneNumSchm
			
			#Inventor ShrinkWrap workflows suggest a file name; allow user overrides
			if ($dsWindow.Name -eq "InventorWindow" -and $global:mShrnkWrp -eq $true) {
				if ($Prop["_NumSchm"].Value) { $Prop["_NumSchm"].Value = $_FilteredNumSchems[1].Name } # None 	
			}

			#reverse order for these cases; none is added latest; reverse the list, if None is pre-set to index = 0
			#If($dsWindow.Name-eq "InventorWindow" -and $Prop["DocNumber"].Value -notlike "Assembly*" -and $Prop["_FileExt"].Value -eq ".iam") #you might find better criteria based on then numbering scheme
			#{
			#	$_FilteredNumSchems = $_FilteredNumSchems | Sort-Object -Descending
			#	return $_FilteredNumSchems
			#}
			#If($dsWindow.Name-eq "InventorWindow" -and $Prop["DocNumber"].Value -notlike "Part*" -and $Prop["_FileExt"].Value -eq ".ipt") #you might find better criteria based on then numbering scheme
			#{
			#	$_FilteredNumSchems = $_FilteredNumSchems | Sort-Object -Descending
			#	return $_FilteredNumSchems
			#}
			If ($dsWindow.Name -eq "InventorFrameWindow") { 
				return $_Default
			}
			If ($dsWindow.Name -eq "InventorHarnessWindow") { 
				return $_Default
			}
			If ($dsWindow.Name -eq "InventorPipingWindow") { 
				return $_Default
			}
			If ($dsWindow.Name -eq "InventorDesignAcceleratorWindow") { 
				return $_Default
			}
	
			return $_FilteredNumSchems
		}
	}
	catch [System.Exception] {		
		[Autodesk.DataManagement.Client.Framework.Forms.Library]::ShowError($error, "VDS Sample Configuration")
	}	
}

function GetCategories {
	$mAllCats = $Prop["_Category"].ListValues
	$mFDSFilteredCats = $mAllCats | Where { $_.Name -ne "Asset Library" }
	return $mFDSFilteredCats | Sort-Object -Property "Name" #Ascending is default; no option required
}

function OnPostCloseDialog {
	$mWindowName = $dsWindow.Name
	switch ($mWindowName) {
		"InventorWindow" {
			if ($Prop["_CreateMode"].Value -and !($Prop["_CopyMode"].Value -and !$Prop["_GenerateFileNumber4SpecialFiles"].Value -and @(".DWG", ".IDW", ".IPN") -contains $Prop["_FileExt"].Value)) {
				mWriteLastUsedFolder
			}

			if ($Prop["_CreateMode"].Value -and !$Prop["Part Number"].Value) { #we empty the part number on initialize: if there is no other function to provide part numbers we should apply the Inventor default
				$Prop["Part Number"].Value = $Prop["DocNumber"].Value
			}
			#sketched drawings (no model view) don't get a Part Number from the model, but the part number is not empty and equals the displayname of the new drawing, e.g. "Drawing1"
			if ($Prop["_CreateMode"].Value -and $Document.ReferencedFiles.Count -eq 0 -and @(".DWG", ".IDW", ".IPN") -contains $Prop["_FileExt"].Value) {
				$Prop["Part Number"].Value = $Prop["DocNumber"].Value
			}
			
			#remove orphaned sheets in drawing documents
			if (-not $Prop["_SaveCopyAsMode"].Value -eq $true -or (Get-Item $document.FullFileName).IsReadOnly -eq $true) {
				if (@(".DWG", ".IDW") -contains $Prop["_FileExt"].Value -and $dsWindow.FindName("RmOrphShts").IsChecked -eq $true) {
					if (-not $_mInvHelpers) {
						$_mInvHelpers = New-Object VdsSampleUtilities.InvHelpers
					}
					$result = $_mInvHelpers.m_RemoveOrphanedSheets($Application)
				}
			}
		}

		"AutoCADWindow" {
			$dc = $dsWindow.DataContext
			if ($Prop["_CreateMode"]) {
				mWriteLastUsedFolder
				#the default ACM Titleblocks expect the file name and drawing number as attribute values; adjust property(=attribute) names for custom titleblock definitions
				$Prop["GEN-TITLE-NR"].Value = $dc.PathAndFileNameHandler.FileNameNoExtension
			}
			$Prop["GEN-TITLE-DWG"].Value = $dc.PathAndFileNameHandler.FileName
		}
		default {
			#rules applying for windows non specified
		}
	} #switch Window Name
	
}

function mHelp ([Int] $mHContext) {
	try {
		switch ($mHContext) {
			100 {
				$mHPage = "C.2Inventor.html";
			}
			110 {
				$mHPage = "C.2.11FrameGenerator.html";
			}
			120 {
				$mHPage = "C.2.13DesignAccelerator.html";
			}
			130 {
				$mHPage = "C.2.12TubeandPipe.html";
			}
			140 {
				$mHPage = "C.2.14CableandHarness.html";
			}
			200 {
				$mHPage = "C.3AutoCADAutoCAD.html";
			}
			Default {
				$mHPage = "Index.html";
			}
		}
		$mHelpTarget = $Env:ProgramData + "\Autodesk\Vault 2024\Extensions\DataStandard\HelpFiles\" + $mHPage
		$mhelpfile = Invoke-Item $mHelpTarget 
	}
	catch {
		[Autodesk.DataManagement.Client.Framework.Forms.Library]::ShowError($UIString["MSDCE_MSG02"], "VDS MFG Sample Client")
	}
}

function mReadShortCuts {
	if ($Prop["_CreateMode"].Value -eq $true) {
		#$dsDiag.Trace(">> Looking for Shortcuts...")
		$m_Server = ($VaultConnection.Server).Replace(":", "_").Replace("/", "_")
		$m_Vault = $VaultConnection.Vault
		$m_Path = "$($env:appdata)\Autodesk\VaultCommon\Servers\Services_Security_01_10_2023\$($m_Server)\Vaults\$($m_Vault)\Objects\"
		$global:mScFile = $m_Path + "Shortcuts.xml"
		if (Test-Path $global:mScFile) {
			#$dsDiag.Trace(">> Start reading Shortcuts...")
			$global:m_ScXML = New-Object XML 
			$global:m_ScXML.Load($mScFile)
			$m_ScAll = $m_ScXML.Shortcuts.Shortcut
			#the shortcuts need to get filtered by type of document.folder and path information related to CAD workspace
			$global:m_ScCAD = @{}
			#$dsDiag.Trace("... Filtering Shortcuts...")
			$m_ScAll | ForEach-Object {
				if (($_.NavigationContextType -eq "Connectivity.Explorer.Document.DocFolder") -and ($_.NavigationContext.URI -like "*" + $global:CAx_Root + "/*")) {
					try {
						$_t = $global:m_ScCAD.Add($_.Name, $_.NavigationContext.URI)
					}
					catch {
						$mErrorMsg = "... ERROR Filtering Shortcuts..."
						[Autodesk.DataManagement.Client.Framework.Forms.Library]::ShowError($mErrorMsg, "VDS Sample Configuration")
					}
				}
			}
		}
		return $global:m_ScCAD
	}
}

function mScClick {
	try {
		$_key = $dsWindow.FindName("lstBoxShortCuts").SelectedValue
		$_Val = $global:m_ScCAD.get_item($_key)
		$_SPath = @()
		$_SPath = $_Val.Split("/")

		$m_DesignPathNames = $null
		[System.Collections.ArrayList]$m_DesignPathNames = @()
		#differentiate AutoCAD and Inventor: AutoCAD is able to start in $, but Inventor starts in it's mandatory Workspace folder (IPJ)
		IF ($dsWindow.Name -eq "InventorWindow") { $indexStart = 2 }
		If ($dsWindow.Name -eq "AutoCADWindow") { $indexStart = 1 }
		for ($index = $indexStart; $index -lt $_SPath.Count; $index++) {
			$m_DesignPathNames += $_SPath[$index]
		}
		if ($m_DesignPathNames.Count -eq 1) { $m_DesignPathNames += "." }
		mActivateBreadCrumbCmbs $m_DesignPathNames
		$global:expandBreadCrumb = $true
	}
	catch {
		$mErrorMsg = "Selecting Shortcut - Error on reading/activating shortcut info."
		[Autodesk.DataManagement.Client.Framework.Forms.Library]::ShowError($mErrorMsg, "VDS Sample Configuration")
	}
}

function mAddSc {
	try {
		$mNewScName = $dsWindow.FindName("txtNewShortCut").Text
		mAddShortCutByName ($mNewScName)
		$dsWindow.FindName("lstBoxShortCuts").ItemsSource = mReadShortCuts
	}
	catch {
		$mErrorMsg = "Adding a new shortcut failed. Contact your VDS Administrator"
		[Autodesk.DataManagement.Client.Framework.Forms.Library]::ShowError($mErrorMsg, "VDS Sample Configuration")
	}
}

function mRemoveSc {
	try {
		$_key = $dsWindow.FindName("lstBoxShortCuts").SelectedValue
		mRemoveShortCutByName $_key
		$dsWindow.FindName("lstBoxShortCuts").ItemsSource = mReadShortCuts
	}
	catch {
		$mErrorMsg = "Removing shortcut failed. Contact your VDS Administrator"
		[Autodesk.DataManagement.Client.Framework.Forms.Library]::ShowError($mErrorMsg, "VDS Sample Configuration")
	}
}

function mAddShortCutByName([STRING] $mScName) {
	try { #simply check that the name is unique
		#$dsDiag.Trace(">> Start to add ShortCut, check for used name...")
		$global:m_ScCAD.Add($mScName, "Dummy")
		$global:m_ScCAD.Remove($mScName)
	}
	catch { #no reason to continue in case of existing name
		[Autodesk.DataManagement.Client.Framework.Forms.Library]::ShowError($UIString["MSDCE_MSG01"], "VDS MFG Sample Client")
		end function
	}

	try {
		#$dsDiag.Trace(">> Continue to add ShortCut, creating new from template...")	
		#read from template
		$m_File = "$($env:appdata)\Autodesk\DataStandard 2024\Folder2024.xml"

		if (Test-Path $m_File) {
			#$dsDiag.Trace(">>-- Started to read Folder2024.xml...")
			$global:m_XML = New-Object XML
			$global:m_XML.Load($m_File)
		}
		$mShortCut = $global:m_XML.VDSUserProfile.Shortcut | Where-Object { $_.Name -eq "Template" }
		#clone the template completely and update name attribute and navigationcontext element
		$mNewSc = $mShortCut.Clone() #.CloneNode($true)
		#rename "Template" to new name
		$mNewSc.Name = $mScName 
		
		#derive the path from current selection
		$breadCrumb = $dsWindow.FindName("BreadCrumb")
		$newURI = "vaultfolderpath:" + $global:CAx_Root
		foreach ($cmb in $breadCrumb.Children) {
			if (($cmb.SelectedItem.Name.Length -gt 0) -and !($cmb.SelectedItem.Name -eq ".")) { 
				$newURI = $newURI + "/" + $cmb.SelectedItem.Name
				#$dsDiag.Trace(" - the updated URI  of the shortcut: $newURI")
			}
			else { break }
		}
		
		#hand over the path in shortcut navigation format
		$mNewSc.NavigationContext.URI = $newURI
		#append the new shortcut and save back to file
		$mImpNode = $global:m_ScXML.ImportNode($mNewSc, $true)
		$global:m_ScXML.Shortcuts.AppendChild($mImpNode)
		$global:m_ScXML.Save($mScFile)
		$dsWindow.FindName("txtNewShortCut").Text = ""
		#$dsDiag.Trace("..successfully added ShortCut <<")
		return $true
	}
	catch {
		$mErrorMsg = "Saving the new shortcut failed. Contact your VDS Administrator"
		[Autodesk.DataManagement.Client.Framework.Forms.Library]::ShowError($mErrorMsg, "VDS Sample Configuration")
		return $false
	}
}

function mRemoveShortCutByName ([STRING] $mScName) {
	try {
		#$dsDiag.Trace(">> Start to remove ShortCut from list")
		$mShortCut = @() #Vault allows multiple shortcuts equally named
		$mShortCut = $global:m_ScXML.Shortcuts.Shortcut | where { $_.Name -eq $mScName }
		$mShortCut | ForEach-Object {
			$global:m_ScXML.Shortcuts.RemoveChild($_)
		}
		$global:m_ScXML.Save($global:mScFile)
		#$dsDiag.Trace("..successfully removed ShortCut <<")
		return $true
	}
	catch {
		$mErrorMsg = "Saving the shortcut file failed. Contact your VDS Administrator."
		[Autodesk.DataManagement.Client.Framework.Forms.Library]::ShowError($mErrorMsg, "VDS Sample Configuration")
		return $false
	}
}

#region functional dialogs
#FrameDocuments[], FrameMemberDocuments[] and SkeletonDocuments[]
function mInitializeFGContext {
	$mFrmDocs = @()
	$mFrmDocs = $dsWindow.DataContext.FrameDocuments
	$mFrmDocs | ForEach-Object {
		$mFrmDcProps = $_.Properties.Properties
		$mProp = $mFrmDcProps | Where-Object { $_.Name -eq "Title" }
		$mProp.Value = $UIString["LBL55"]
		$mProp = $mFrmDcProps | Where-Object { $_.Name -eq "Description" }
		$mProp.Value = $UIString["MSDCE_BOMType_01"]
	}
	$mSkltnDocs = @()
	$mSkltnDocs = $dsWindow.DataContext.SkeletonDocuments
	$mSkltnDocs | ForEach-Object {
		$mSkltnDcProps = $_.Properties.Properties
		$mProp = $mSkltnDcProps | Where-Object { $_.Name -eq "Title" }
		$mProp.Value = $UIString["LBL56"]
		$mProp = $mSkltnDcProps | Where-Object { $_.Name -eq "Description" }
		$mProp.Value = $UIString["MSDCE_BOMType_04"]
	}
	$mFrmMmbrDocs = @()
	$mFrmMmbrDocs = $dsWindow.DataContext.FrameMemberDocuments
	$mFrmMmbrDocs | ForEach-Object {
		$mFrmMmbrDcProps = $_.Properties.Properties
		$mProp = $mFrmMmbrDcProps | Where-Object { $_.Name -eq "Title" }
		$mProp.Value = $UIString["MSDCE_FrameMember_01"]
	}
}

function mInitializeDAContext {
	$mDsgnAccAssys = @() 
	$mDsgnAccAssys = $dsWindow.DataContext.DesignAcceleratorAssemblies
	$mDsgnAccAssys | ForEach-Object {
		$mDsgnAccAssyProps = $_.Properties.Properties
		$mTitleProp = $mDsgnAccAssyProps | Where-Object { $_.Name -eq "Title" }
		$mPartNumProp = $mDsgnAccAssyProps | Where-Object { $_.Name -eq "Part Number" }
		$mTitleProp.Value = $UIString["MSDCE_BOMType_01"]
		$mPartNumProp.Value = "" #delete the value to get the new number
		$mProp = $mDsgnAccAssyProps | Where-Object { $_.Name -eq "Description" }
		$mProp.Value = $UIString["MSDCE_BOMType_01"] + " " + $mPartNumProp.Value
	}
	$mDsgnAccParts = $dsWindow.DataContext.DesignAcceleratorParts
	$mDsgnAccParts | ForEach-Object {
		$mDsgnAccProps = $_.Properties.Properties
		$mTitleProp = $mDsgnAccProps | Where-Object { $_.Name -eq "Title" }
		$mPartNumProp = $mDsgnAccProps | Where-Object { $_.Name -eq "Part Number" }
		$mTitleProp.Value = $mPartNumProp.Value
		$mPartNumProp.Value = "" #delete the value to get the new number
		$mProp = $mDsgnAccProps | Where-Object { $_.Name -eq "Description" }
		$mProp.Value = $mTitleProp.Value
	}
}

function mInitializeTPContext {
	$mRunAssys = @()
	$mRunAssys = $dsWindow.DataContext.RunAssemblies
	$mRunAssys | ForEach-Object {
		$mRunAssyProps = $_.Properties.Properties
		$mTitleProp = $mRunAssyProps | Where-Object { $_.Name -eq "Title" } 
		$mTitleProp.Value = $UIString["LBL41"]
		$mPartNumProp = $mRunAssyProps | Where-Object { $_.Name -eq "Part Number" }
		$mPartNumProp.Value = "" #delete the value to get the new number
		$mProp = $mRunAssyProps | Where-Object { $_.Name -eq "Description" }
		$mProp.Value = $UIString["MSDCE_BOMType_01"] + " " + $UIString["MSDCE_TubePipe_01"]
	}
	$mRouteParts = @()
	$mRouteParts = $dsWindow.DataContext.RouteParts
	$mRouteParts | ForEach-Object {
		$mRouteProps = $_.Properties.Properties
		$mTitleProp = $mRouteProps | Where-Object { $_.Name -eq "Title" }
		$mTitleProp.Value = $UIString["LBL42"]
		$mPartNumProp = $mRouteProps | Where-Object { $_.Name -eq "Part Number" }
		$mPartNumProp.Value = "" #delete the value to get the new number
		$mProp = $mRouteProps | Where-Object { $_.Name -eq "Description" }
		$mProp.Value = $UIString["MSDCE_BOMType_00"] + " " + $UIString["LBL42"]
	}
	$mRunComponents = @()
	$mRunComponents = $dsWindow.DataContext.RunComponents
	$mRunComponents | ForEach-Object {
		$mRunCompProps = $_.Properties.Properties
		$mTitleProp = $mRunCompProps | Where-Object { $_.Name -eq "Title" }
		$m_StockProp = $mRunCompProps | Where-Object { $_.Name -eq "Stock Number" }
		$mTitleProp.Value = $UIString["LBL43"]
		$mPartNumProp = $mRunCompProps | Where-Object { $_.Name -eq "Part Number" }
		$m_PL = $mRunCompProps | Where-Object { $_.Name -eq "PL" }
		$mPartNumProp.Value = $m_StockProp.Value + " - " + $m_PL.Value
	}
}

function mInitializeCHContext {
	$mHrnsAssys = @()
	$mHrnsAssys = $dsWindow.DataContext.HarnessAssemblies
	$mHrnsAssys | ForEach-Object {
		$mHrnsAssyProps = $_.Properties.Properties
		$mTitleProp = $mHrnsAssyProps | Where-Object { $_.Name -eq "Title" }
		$mTitleProp.Value = $UIString["LBL45"]
		$mProp = $mHrnsAssyProps | Where-Object { $_.Name -eq "Description" }
		$mProp.Value = $UIString["MSDCE_BOMType_00"] + " " + $UIString["LBL45"]
	}
	$mHrnsParts = @()
	$mHrnsParts = $dsWindow.DataContext.HarnessParts
	$mHrnsParts | ForEach-Object {
		$mHrnsPrtProps = $_.Properties.Properties
		$mTitleProp = $mHrnsPrtProps | Where-Object { $_.Name -eq "Title" }
		$mTitleProp.Value = $UIString["LBL47"]
		$mProp = $mHrnsPrtProps | Where-Object { $_.Name -eq "Description" }
		$mProp.Value = $UIString["MSDCE_BOMType_00"] + " " + $UIString["LBL47"]
	}
}
#endregion functional dialogs

function GetTemplateFolders {
	$xmldata = [xml](Get-Content "$env:programdata\Autodesk\Vault 2024\Extensions\DataStandard\Vault\Configuration\File.xml")

	[string[]] $folderPath = $xmldata.DocTypeData.DocTypeInfo | foreach { $_.Path }
	$folders = $vault.DocumentService.FindFoldersByPaths($folderPath)

	return $xmldata.DocTypeData.DocTypeInfo | foreach {
		$path = $_.Path
		$folder = $folders | where { $_.FullName -eq $path } | Select -index 0
		if ($folder -eq $null) {
			return
		}
		return $_
	}
}