#=============================================================================
# PowerShell script sample for Vault Data Standard                            
#			 Autodesk Vault - PDMC-Sample Configuration 2022  								  
# This sample is based on VDS 2023 RTM adding functionality and rules    
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
	#InitializeFileNameValidation #VDS-PDMC-Sample initializes at latest to avoid multiple events by UI changes
	#InitializeCategory #VDS-PDMC-Sample differentiates for Inventor and AutoCAD
	$Global:mCategories = GetCategories
	#InitializeNumSchm #VDS-PDMC-Sample differentiates for Inventor and AutoCAD
	#InitializeBreadCrumb #VDS-PDMC-Sample differentiates Inventor, Inventor C&H, T&P, FG, DA dialogs

	#Copy Parent Project Number to file property "Project Number" if exists; be careful, not all dialogs might have the textbox, e.g. DA, FG,...
	If ($Prop["Project"]) {
		$Global:mPropTrans = mGetPropTranslations
		if ($dsWindow.FindName("txtPath")) {
			mGetProjectFolderPropToCADFile  "Name" $mPropTrans["Project"]
			$dsWindow.FindName("txtPath").add_TextChanged({		
					mGetProjectFolderPropToCADFile  "Name" $mPropTrans["Project"]
				})
		}
	}

	#$dsDiag.ShowLog()
	#$dsDiag.Clear()

	if ($Prop["_CopyMode"].Value -eq $true) { #disabled as it causes another read-only edit dialog on drawing copies
		$_DataContext = $dsWindow.DataContext
		$Prop["Source File"].Value = $_DataContext.PathAndFileNameHandler.OriginalFilename
	}

	$mWindowName = $dsWindow.Name

	if ($mWindowName -eq "InventorWindow" -or $mWindowName -eq "AutoCADWindow") { 
		InitializeRevisionValidation
	}
	#endregion rules applying commonly

	switch ($mWindowName) {
		"InventorWindow" {

			#support given file name and path for Inventor ShrinkWrap file (_SuggestedVaultPath is empty for these)
			$global:mShrnkWrp = $false

			InitializeBreadCrumb

			#set the active user as Inventor Designer
			if ($Prop["Designer"].Value -eq "") {
				$mUser = $vault.AdminService.Session.User
				$Prop["Designer"].Value = $mUser.Name
			}

			#	there are some custom functions to enhance functionality; 2023 version added webservice and explorer extensions to be installed optionally
			$mVdsUtilities = "$($env:programdata)\Autodesk\Vault 2023\Extensions\Autodesk.VdsSampleUtilities\VdsSampleUtilities.dll"
			if (! (Test-Path $mVdsUtilities)) {
				#the basic utility installation only
				[System.Reflection.Assembly]::LoadFrom($Env:ProgramData + '\Autodesk\Vault 2023\Extensions\DataStandard\Vault.Custom\addinVault\VdsSampleUtilities.dll')
			}
			Else {
				#the extended utility activation
				[System.Reflection.Assembly]::LoadFrom($Env:ProgramData + '\Autodesk\Vault 2023\Extensions\Autodesk.VdsSampleUtilities\VdsSampleUtilities.dll')
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
					#create mode is relevant for copies; reset revision data
					ResetRevisionProperties

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
						$_mFdsKeys = $_mInvHelpers.m_GetFdsKeys($Application, @{})

						# some FDS workflows require VDS cancellation; add the conditions to the event handler _Loaded below
						$dsWindow.add_Loaded({
								IF ($mSkipVDS -eq $true) {
									$dsWindow.CancelWindowCommand.Execute($this)
									#$dsDiag.Trace("FDU-VDS EventHandler: Skip Dialog executed")	
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
								$mCatName = GetCategories | Where-Object { $_.Name -eq "Factory Asset" }
								IF ($mCatName) { $Prop["_Category"].Value = "Factory Asset" }
							}
							# skip for publishing the 3D temporary file save event for VDS
							If ($_mFdsKeys.Get_Item("FdsType") -eq "FDS-Asset" -and $Application.SilentOperation -eq $true) { 
								#$dsDiag.Trace(" FDS publishing 3D - using temporary assembly silent mode: need to skip VDS!")
								$global:mSkipVDS = $true
							}
							If ($_mFdsKeys.Get_Item("FdsType") -eq "FDS-Asset" -and $Document.InternalName -ne $Application.ActiveDocument.InternalName) {
								#$dsDiag.Trace(" FDS publishing 3D: ActiveDoc.InternalName different from VDSDoc.Internalname: Verbose VDS")
								$global:mSkipVDS = $true
							}

							# 
							If ($_mFdsKeys.Get_Item("FdsType") -eq "FDS-Layout" -and $_mFdsKeys.Count -eq 1) {
								#$dsDiag.Trace("3DLayout, not synced")
								# only the MSDCE FDS configuration template provides a category for layouts, check for this otherwise continue with the selection done before
								$mCatName = GetCategories | Where-Object { $_.Name -eq "Factory Layout" }
								IF ($mCatName) { $Prop["_Category"].Value = "Factory Layout" }
							}

							# FDU 2019.22.0.2 and later allow to skip dynamically, instead of skipping in general by the SkipVDSon1stSave.IAM template
							If ($_mFdsKeys.Get_Item("FdsType") -eq "FDS-Layout" -and $_mFdsKeys.Count -gt 1 -and $Document.FileSaveCounter -eq 0) {
								#$dsDiag.Trace("3DLayout not saved yet, but already synced")
								$dsWindow.add_Loaded({
										$dsWindow.CancelWindowCommand.Execute($this)
										#$dsDiag.Trace("FDU-VDS EventHandler: Skip Dialog executed")	
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
									$dsDiag.Trace("Set path, filename and properties for IPN: At least one custom property failed, most likely it did not exist and is not part of the cfg ")
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
					$mCat = $Global:mCategories | Where-Object { $_.Name -eq $UIString["MSDCE_CAT11"] } # weldment assembly
					IF ($Prop["_Category"].Value -eq $mCat.Name) { 
						try {
							$Prop["Material"].Value = $Document.ComponentDefinition.WeldBeadMaterial.DisplayName
						}
						catch {
							$dsDiag.Trace("Failed reading weld bead material; most likely the assembly subtype is not an weldment.")
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
			#set the active user as Designer for file property mapping or mechanical title attribute mapping
			$mUser = $vault.AdminService.Session.User
			if ($Prop["GEN-TITLE-NAME"]) { #if($Prop["Designer"])
				$Prop["GEN-TITLE-NAME"].Value = $mUser.Name #	$Prop["Designer"].Value = $mUser.Name
			}

			#workaround 2021.1 and 2022 RTM Acad Date field type issue
			if ($Prop["GEN-TITLE-CHKD"]) {
				$Prop["GEN-TITLE-CHKD"].Typ = "DateTime"
				if ($Prop["GEN-TITLE-CHKD"].Value -eq "") {
					$Prop["GEN-TITLE-CHKD"].Value = Get-Date -Year "2021" -Month "01" -Day "01"
				}
				$Prop["GEN-TITLE-CHKD"].CustomValidation = { $true }
			}
			if ($Prop["GEN-TITLE-ISSD"]) {
				$Prop["GEN-TITLE-ISSD"].Typ = "DateTime"
				if ($Prop["GEN-TITLE-ISSD"].Value -eq "") {
					$Prop["GEN-TITLE-ISSD"].Value = Get-Date -Year "2021" -Month "01" -Day "01"
				}
				$Prop["GEN-TITLE-ISSD"].CustomValidation = { $true }
			}
			#end workaround date type issue

			InitializeBreadCrumb

			switch ($Prop["_CreateMode"].Value) {
				$true {
					#create mode is relevant for copies; reset revision data
					ResetRevisionProperties

					#$dsDiag.Trace(">> CreateMode Section executes...")
					# set the category: VDS-PDMC-Sample = "AutoCAD Drawing"
					$mCatName = $Global:mCategories | Where-Object { $_.Name -eq $UIString["MSDCE_CAT01"] }
					IF ($mCatName) { $Prop["_Category"].Value = $UIString["MSDCE_CAT01"] }
					# in case the current vault is not VDS-PDMC-Sample, but a plain MFG default configuration
					Else {
						$mCatName = $Global:mCategories | Where-Object { $_.Name -eq $UIString["CAT1"] } #"Engineering"
						IF ($mCatName) { $Prop["_Category"].Value = $UIString["CAT1"] }
					}

					#region FDU Support ------------------
					$_FdsUsrData = $Document.UserData #Items FACT_* are added by FDU
					
					#	there are some custom functions to enhance functionality; 2023 version added webservice and explorer extensions to be installed optionally
					$mVdsUtilities = "$($env:programdata)\Autodesk\Vault 2023\Extensions\Autodesk.VdsSampleUtilities\VdsSampleUtilities.dll"
					if (! (Test-Path $mVdsUtilities)) {
						#the basic utility installation only
						[System.Reflection.Assembly]::LoadFrom($Env:ProgramData + '\Autodesk\Vault 2023\Extensions\DataStandard\Vault.Custom\addinVault\VdsSampleUtilities.dll')
					}
					Else {
						#the extended utility activation
						[System.Reflection.Assembly]::LoadFrom($Env:ProgramData + '\Autodesk\Vault 2023\Extensions\Autodesk.VdsSampleUtilities\VdsSampleUtilities.dll')
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

					If ($Prop["_CopyMode"].value -eq $true) {
						#add property reset or other action that apply for AutoCAD only here; there is a _CopyMode section before the switch for Windows.
					}

				}
				$false {
					if ($Prop["_EditMode"].Value -and $Document.IsReadOnly) {
						$dsWindow.FindName("btnOK").IsEnabled = $false
					}
				}
			}
			#endregion VDS-PDMC-Sample
		}
		default {
			#rules applying for other windows not listed before
		}
	} #end switch windows
	
	$global:expandBreadCrumb = $true

	if ($dsWindow.FindName("tabItemProperties")) { mInitializeTabItemProps }

	#region CatalogTerm
	If ($dsWindow.FindName("expTermSearch")) {			
		Try {
			Import-Module -FullyQualifiedName "C:\ProgramData\Autodesk\Vault 2023\Extensions\DataStandard\Vault.Custom\addinVault\ADSK.QS.CustomObjectsClassified.psm1"
		}
		catch {}
	}
	#endregionCatalogTerm

	#region IEC61355
	If ($dsWindow.FindName("expIEC61355")) {			
		Try {
			Import-Module -FullyQualifiedName "C:\ProgramData\Autodesk\Vault 2023\Extensions\DataStandard\Vault.Custom\addinVault\ADSK.QS.IEC61355.psm1"
		}
		catch {}
	}
	#endregion IEC61355

	InitializeFileNameValidation #do this at the end of all other event initializations
	
	#$dsDiag.Trace("... Initialize window end <<")
}#end InitializeWindow

function AddinLoaded {
	#activate or create the user's VDS profile
	$m_File = "$($env:appdata)\Autodesk\DataStandard 2023\Folder2023.xml"
	if (!(Test-Path $m_File)) {
		$source = "$($Env:ProgramData)\Autodesk\Vault 2023\Extensions\DataStandard\Vault.Custom\Folder2023.xml"
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
			$mCatName = $Global:mCategories | Where-Object { $_.Name -eq $UIString["MSDCE_CAT10"] } #assembly, available in VDS-PDMC-Sample Advanced, e.g. INV-Samples Vault
			IF ($mCatName) { 
				$Prop["_Category"].Value = $UIString["MSDCE_CAT10"]
			}
			$mCatName = $Global:mCategories | Where-Object { $_.Name -eq $UIString["MSDCE_CAT02"] }
			IF ($mCatName) { 
				$Prop["_Category"].Value = $UIString["MSDCE_CAT02"] #3D Component, VDS-PDMC-Sample, e.g. MFG-2019-PRO-EN
			}
			Else {
				$mCatName = $Global:mCategories | Where-Object { $_.Name -eq $UIString["CAT1"] } #"Engineering"
				IF ($mCatName) { 
					$Prop["_Category"].Value = $UIString["CAT1"]
				}
			}
			If ($mDocSubType -eq "{28EC8354-9024-440F-A8A2-0E0E55D635B0}") { #weldment assembly
				$mCatName = $Global:mCategories | Where-Object { $_.Name -eq $UIString["MSDCE_CAT11"] } # weldment assembly
				IF ($mCatName) { 
					$Prop["_Category"].Value = $UIString["MSDCE_CAT11"]
					$Prop["Material"].Value = $Document.ComponentDefinition.WeldBeadMaterial.DisplayName
				}
			} 
		}
		'12290' { #part
			$mCatName = $Global:mCategories | Where-Object { $_.Name -eq $UIString["MSDCE_CAT08"] } #Part, available in VDS-PDMC-Sample Advanced, e.g. INV-Samples Vault
			IF ($mCatName) { 
				$Prop["_Category"].Value = $UIString["MSDCE_CAT08"]
			}
			$mCatName = $Global:mCategories | Where-Object { $_.Name -eq $UIString["MSDCE_CAT02"] }
			IF ($mCatName) { 
				$Prop["_Category"].Value = $UIString["MSDCE_CAT02"] #3D Component, VDS-PDMC-Sample, e.g. MFG-2019-PRO-EN
			}
			Else {
				$mCatName = $Global:mCategories | Where-Object { $_.Name -eq $UIString["CAT1"] } #"Engineering"
				IF ($mCatName) { 
					$Prop["_Category"].Value = $UIString["CAT1"]
				}
			}
			If ($mDocSubType -eq "{9C464203-9BAE-11D3-8BAD-0060B0CE6BB4}") {
				$mCatName = $Global:mCategories | Where-Object { $_.Name -eq $UIString["MSDCE_CAT09"] } #sheet metal part, available in VDS-PDMC-Sample Advanced, e.g. INV-Samples Vault
				IF ($mCatName) { 
					$Prop["_Category"].Value = $UIString["MSDCE_CAT09"]
				}
			}
			If ($Document.IsSubstitutePart -eq $true) {
				$mCatName = $Global:mCategories | Where-Object { $_.Name -eq $UIString["MSDCE_CAT12"] } #substitute, available in VDS-PDMC-Sample Advanced, e.g. INV-Samples Vault
				IF ($mCatName) { 
					$Prop["_Category"].Value = $UIString["MSDCE_CAT12"]
				}
			}			
		}
		'12292' { #drawing
			$mCatName = $Global:mCategories | Where-Object { $_.Name -eq $UIString["MSDCE_CAT00"] }
			IF ($mCatName) { $Prop["_Category"].Value = $UIString["MSDCE_CAT00"] }
			Else { # in case the current vault is not VDS-PDMC-Sample, but a plain MFG default configuration
				$mCatName = $Global:mCategories | Where-Object { $_.Name -eq $UIString["CAT1"] } #"Engineering"
				IF ($mCatName) { $Prop["_Category"].Value = $UIString["CAT1"] }
			}
		}
		'12293' { #presentation
			$mCatName = $Global:mCategories | Where-Object { $_.Name -eq $UIString["MSDCE_CAT13"] } #presentation, available in VDS-PDMC-Sample Advanced, e.g. INV-Samples Vault
			IF ($mCatName) { 
				$Prop["_Category"].Value = $UIString["MSDCE_CAT13"]
			}
			$mCatName = $Global:mCategories | Where-Object { $_.Name -eq $UIString["MSDCE_CAT02"] } #3D Component, VDS-PDMC-Sample, e.g. MFG-2019-PRO-EN
			IF ($mCatName) { 
				$Prop["_Category"].Value = $UIString["MSDCE_CAT02"]
			}
			Else {
				$mCatName = $Global:mCategories | Where-Object { $_.Name -eq $UIString["CAT1"] } #"Engineering"
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
			#VDS-PDMC-Sample - there is the use case that we don't need a number: IDW/DWG, IPN and Option Generate new file number = off
			If ($global:mIsInvDocumentationFile -eq $true -and $Prop["_GenerateFileNumber4SpecialFiles"].Value -eq $false -and $Document.ReferencedFiles.Count -gt 0) { 
				return
			}
			
			#Adopted from a DocumentService call, which always pulls FILE class numbering schemes
			[System.Collections.ArrayList]$numSchems = @($vault.NumberingService.GetNumberingSchemes('FILE', 'Activated'))

			$_FilteredNumSchems = @()
			$_Default = $numSchems | Where-Object { $_.IsDflt -eq $true }
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
	$mAllCats = $Prop["_Category"].ListValues #$vault.CategoryService.GetCategoriesByEntityClassId("FILE", $true)
	$mFDSFilteredCats = $mAllCats | Where-Object { $_.Name -ne "Asset Library" }
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
			mWriteLastUsedFolder

			#use document number for part number if not filled yet; cover ACM and Vanilla property configuration
			If ($Prop["GEN-TITLE-DWG"].Value -and $Prop["GEN-TITLE-NR"].Value -eq "") {
				$Prop["GEN-TITLE-NR"].Value = $dsWindow.DataContext.PathAndFileNameHandler.FileNameNoExtension #$Prop["GEN-TITLE-DWG"].Value
			}
			#If ($Prop["DocNumber"].Value -and $Prop["Part Number"].Value -eq "")
			#	{
			#		$Prop["Part Number"].Value = $dsWindow.DataContext.PathAndFileNameHandler.FileNameNoExtension
			#	}
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
		$mHelpTarget = $Env:ProgramData + "\Autodesk\Vault 2023\Extensions\DataStandard\HelpFiles\" + $mHPage
		$mhelpfile = Invoke-Item $mHelpTarget 
	}
	catch {
		[Autodesk.DataManagement.Client.Framework.Forms.Library]::ShowError($UIString["MSDCE_MSG02"], "Vault VDS-Sample Client")
	}
}

function mReadShortCuts {
	if ($Prop["_CreateMode"].Value -eq $true) {
		#$dsDiag.Trace(">> Looking for Shortcuts...")
		$m_Server = ($VaultConnection.Server).Replace(":", "_").Replace("/", "_")
		$m_Vault = $VaultConnection.Vault
		$m_Path = "$($env:appdata)\Autodesk\VaultCommon\Servers\Services_Security_12_16_2021\$($m_Server)\Vaults\$($m_Vault)\Objects\"
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
				if (($_.NavigationContextType -eq "Connectivity.Explorer.Document.DocFolder") -and ($_.NavigationContext.URI -like "*"+$global:CAx_Root + "/*"))
				{
					try
					{
						$_t = $global:m_ScCAD.Add($_.Name, $_.NavigationContext.URI)
					}
					catch {
						$dsDiag.Trace("... ERROR Filtering Shortcuts...")
					}
				}
			}
		}
		#$dsDiag.Trace("... returning Shortcuts")
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
		#$dsWindow.FindName("lstBoxShortCuts").SelectedItem = $null
	}
	catch {
		$dsDiag.Trace("mScClick function - error reading selected value")
	}
	
}

function mAddSc {
	try {
		$mNewScName = $dsWindow.FindName("txtNewShortCut").Text
		mAddShortCutByName ($mNewScName)
		$dsWindow.FindName("lstBoxShortCuts").ItemsSource = mReadShortCuts
	}
	catch {}
}

function mRemoveSc {
	try {
		$_key = $dsWindow.FindName("lstBoxShortCuts").SelectedValue
		mRemoveShortCutByName $_key
		$dsWindow.FindName("lstBoxShortCuts").ItemsSource = mReadShortCuts
	}
	catch { }
}

function mAddShortCutByName([STRING] $mScName)
{
	try #simply check that the name is unique
	{
		#$dsDiag.Trace(">> Start to add ShortCut, check for used name...")
		$global:m_ScCAD.Add($mScName,"Dummy")
		$global:m_ScCAD.Remove($mScName)
	}
	catch #no reason to continue in case of existing name
	{
		[Autodesk.DataManagement.Client.Framework.Forms.Library]::ShowError($UIString["MSDCE_MSG01"], "VDS MFG Sample Client")
		end function
	}

	try 
	{
		#$dsDiag.Trace(">> Continue to add ShortCut, creating new from template...")	
		#read from template
		$m_File = "$($env:appdata)\Autodesk\DataStandard 2023\Folder2023.xml"

		if (Test-Path $m_File)
		{
			#$dsDiag.Trace(">>-- Started to read Folder2023.xml...")
			$global:m_XML = New-Object XML
			$global:m_XML.Load($m_File)
		}
		$mShortCut = $global:m_XML.VDSUserProfile.Shortcut | Where-Object { $_.Name -eq "Template"}
		#clone the template completely and update name attribute and navigationcontext element
		$mNewSc = $mShortCut.Clone() #.CloneNode($true)
		#rename "Template" to new name
		$mNewSc.Name = $mScName 

		#derive the path from current selection
		$breadCrumb = $dsWindow.FindName("BreadCrumb")
		$newURI = "vaultfolderpath:" + $global:CAx_Root
		foreach ($cmb in $breadCrumb.Children) 
		{
			if (($cmb.SelectedItem.Name.Length -gt 0) -and !($cmb.SelectedItem.Name -eq "."))
			{ 
				$newURI = $newURI + "/" + $cmb.SelectedItem.Name
				#$dsDiag.Trace(" - the updated URI  of the shortcut: $newURI")
			}
			else { break}
		}
		
		#hand over the path in shortcut navigation format
		$mNewSc.NavigationContext.URI = $newURI
		#append the new shortcut and save back to file
		$mImpNode = $global:m_ScXML.ImportNode($mNewSc,$true)
		$global:m_ScXML.Shortcuts.AppendChild($mImpNode)
		$global:m_ScXML.Save($mScFile)
		$dsWindow.FindName("txtNewShortCut").Text = ""
		#$dsDiag.Trace("..successfully added ShortCut <<")
		return $true
	}
	catch 
	{
		$dsDiag.Trace("..problem encountered adding ShortCut <<")
		return $false
	}
}

function mRemoveShortCutByName ([STRING] $mScName) {
	try {
		#$dsDiag.Trace(">> Start to remove ShortCut from list")
		$mShortCut = @() #Vault allows multiple shortcuts equally named
		$mShortCut = $global:m_ScXML.Shortcuts.Shortcut | Where-Object { $_.Name -eq $mScName }
		$mShortCut | ForEach-Object {
			$global:m_ScXML.Shortcuts.RemoveChild($_)
		}
		$global:m_ScXML.Save($global:mScFile)
		#$dsDiag.Trace("..successfully removed ShortCut <<")
		return $true
	}
	catch {
		return $false
	}
}

#region functional dialogs
#FrameDocuments[], FrameMemberDocuments[] and SkeletonDocuments[]
function mInitializeFGContext {
	#$dsDiag.Trace(">> Init. DataContext for Frame Window")
	$mFrmDocs = @()
	$mFrmDocs = $dsWindow.DataContext.FrameDocuments
	$mFrmDocs | ForEach-Object {
		#$dsDiag.Trace(">> Frame Assy $mC")
		$mFrmDcProps = $_.Properties.Properties
		$mProp = $mFrmDcProps | Where-Object { $_.Name -eq "Title" }
		$mProp.Value = $UIString["LBL55"]
		$mProp = $mFrmDcProps | Where-Object { $_.Name -eq "Description" }
		$mProp.Value = $UIString["MSDCE_BOMType_01"]
		#$dsDiag.Trace("Frames Assy end <<") 
	}
	$mSkltnDocs = @()
	$mSkltnDocs = $dsWindow.DataContext.SkeletonDocuments
	$mSkltnDocs | ForEach-Object {
		#$dsDiag.Trace(">> Skeleton Assy $mC")
		$mSkltnDcProps = $_.Properties.Properties
		$mProp = $mSkltnDcProps | Where-Object { $_.Name -eq "Title" }
		$mProp.Value = $UIString["LBL56"]
		$mProp = $mSkltnDcProps | Where-Object { $_.Name -eq "Description" }
		$mProp.Value = $UIString["MSDCE_BOMType_04"]
		#$dsDiag.Trace("Skeleton end <<") 
	}
	$mFrmMmbrDocs = @()
	$mFrmMmbrDocs = $dsWindow.DataContext.FrameMemberDocuments
	$mFrmMmbrDocs | ForEach-Object {
		#$dsDiag.Trace(">> FrameMember Assy $mC")
		$mFrmMmbrDcProps = $_.Properties.Properties
		$mProp = $mFrmMmbrDcProps | Where-Object { $_.Name -eq "Title" }
		$mProp.Value = $UIString["MSDCE_FrameMember_01"]
		#$dsDiag.Trace("FrameMembers $mC end <<") 
	}
	#$dsDiag.Trace("end DataContext for Frame Window<<")
}

function mInitializeDAContext {
	#$dsDiag.Trace(">> Init DataContext for DA Window")
	$mDsgnAccAssys = @() 
	$mDsgnAccAssys = $dsWindow.DataContext.DesignAcceleratorAssemblies
	$mDsgnAccAssys | ForEach-Object {
		#$dsDiag.Trace(">> DA Assy $mC")
		$mDsgnAccAssyProps = $_.Properties.Properties
		$mTitleProp = $mDsgnAccAssyProps | Where-Object { $_.Name -eq "Title" }
		$mPartNumProp = $mDsgnAccAssyProps | Where-Object { $_.Name -eq "Part Number" }
		$mTitleProp.Value = $UIString["MSDCE_BOMType_01"]
		$mPartNumProp.Value = "" #delete the value to get the new number
		$mProp = $mDsgnAccAssyProps | Where-Object { $_.Name -eq "Description" }
		$mProp.Value = $UIString["MSDCE_BOMType_01"] + " " + $mPartNumProp.Value
		#$dsDiag.Trace("DA Assy $mC end <<")
	}
	$mDsgnAccParts = $dsWindow.DataContext.DesignAcceleratorParts
	$mDsgnAccParts | ForEach-Object {
		#$dsDiag.Trace(">> DA component $mC")
		$mDsgnAccProps = $_.Properties.Properties
		$mTitleProp = $mDsgnAccProps | Where-Object { $_.Name -eq "Title" }
		$mPartNumProp = $mDsgnAccProps | Where-Object { $_.Name -eq "Part Number" }
		$mTitleProp.Value = $mPartNumProp.Value
		$mPartNumProp.Value = "" #delete the value to get the new number
		$mProp = $mDsgnAccProps | Where-Object { $_.Name -eq "Description" }
		$mProp.Value = $mTitleProp.Value
		#$dsDiag.Trace("DA Component $mC end <<")
	}
 #$dsDiag.Trace("DataContext for DA Window end <<")
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