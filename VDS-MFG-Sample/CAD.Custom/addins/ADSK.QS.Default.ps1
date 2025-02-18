# DISCLAIMER:
# ---------------------------------
# In any case, code, templates, and snippets of this solution are of "work in progress" character.
# Neither Markus Koechl, nor Autodesk represents that these samples are reliable, accurate, complete, or otherwise valid. 
# Accordingly, those configuration samples are provided as is with no warranty of any kind, and you use the applications at your own risk.


function InitializeWindow {

	$dsWindow.Title = SetWindowTitle
	$Global:mCategories = GetCategories

	# leverage the current theme variable in theme dependent path names etc.
	$Global:currentTheme = [Autodesk.DataManagement.Client.Framework.Forms.SkinUtils.WinFormsTheme]::Instance.CurrentTheme

	$mWindowName = $dsWindow.Name
	switch ($mWindowName) {
		"InventorWindow" {
			#support given file name and path for Inventor ShrinkWrap file (_SuggestedVaultPath is empty for these)
			$global:mShrnkWrp = $false

			InitializeBreadCrumb

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

			if ($Prop["_CreateMode"].Value -eq $true) {

				#create mode is relevant for copies; reset revision data
				#ResetRevisionProperties #PDMC-Sample configuration only

				#reset the part number for new files as Inventor writes the file name (no extension) as a default.
				If ($Prop["Part Number"]) {
					#Inventor returns null if the Part Number has no custom value
					if ($Prop["Part Number"].Value -ne "") {
						$Prop["Part Number"].Value = ""
					}
				}
				InitializeInventorCategory
				InitializeInventorNumSchm
				#Initialize Shortcuts
				mFillMyScTree

				#set the active user as Inventor Designer
				$mUser = $vault.AdminService.Session.User
				if ($mUser.Name -ne $Prop["Designer"].Value) {
					$Prop["Designer"].Value = $mUser.Name
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
							If ($Prop["_Category"].Value -eq "Factory Asset" -and $Document.FileSaveCounter -eq 0) {
								#don't localize name according FDU fixed naming
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
							$mCatName = $Global:mCategories | Where-Object { $_.Name -eq "Factory Asset" }
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
							$mCatName = $Global:mCategories | Where-Object { $_.Name -eq "Factory Layout" }
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

							if ($_ModelPartNumber -ne $null) {
								# must not write empty part numbers 
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
<# 								$_iPropSpearWearPart = $mPropTrans["SPAREPART"] #available in PDMC-Sample Vault only
								$_t1 = $_mInvHelpers.m_GetMainViewModelPropValue($Application, $_ModelFullFileName, $_iPropSpearWearPart)
								if ($_t1 -ne "") {
									$Prop[$_iPropSpearWearPart].Value = $_t1
								} #>
							} 
							catch {
								$mWarningMsg = "Set path, filename and properties for IPN: Failed to write a custom property."
								[Autodesk.DataManagement.Client.Framework.Forms.Library]::ShowWarning($mWarningMsg, "VDS Sample Configuration", "OK")
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
			Else { 
				# EditMode = True
				if ((Get-Item $document.FullFileName).IsReadOnly) {
					#disable the OK button
					$dsWindow.FindName("btnOK").IsEnabled = $false
				}				
			}
				
			#VDS MFG/PDMC Sample - handle weldbead material" 
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
					if ($mUser.Name -ne $Prop["GEN-TITLE-NAME"].Value) { #if($Prop["Designer"])
						$Prop["GEN-TITLE-NAME"].Value = $mUser.Name #	$Prop["Designer"].Value = $mUser.Name
					}
					#set the current date as orig. Create Date
					if ($Prop["GEN-TITLE-DAT"]){
						$Prop["GEN-TITLE-DAT"].Value = (Get-Date).ToString('yyyy-MM-dd')
					}

					# set the category: VDS MFG Sample = "AutoCAD Drawing"
					$mCatName = $Global:mCategories | Where-Object { $_.Name -eq $UIString["MSDCE_CAT01"] }
					IF ($mCatName) { $Prop["_Category"].Value = $UIString["MSDCE_CAT01"] }
					# in case the current vault is not quickstart, but a plain MFG default configuration
					Else {
						$mCatName = $Global:mCategories | Where-Object { $_.Name -eq $UIString["CAT1"] } #"Engineering"
						IF ($mCatName) { $Prop["_Category"].Value = $UIString["CAT1"] }
					}

					#region FDU Support ------------------
					$_FdsUsrData = $Document.UserData #Items FACT_* are added by FDU

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

					$_mAcadHelpers = New-Object VdsSampleUtilities.AcadHelpers
					$_FdsBlocksInDrawing = $_mAcadHelpers.mFdsDrawing($Application)
					If ($_FdsUsrData.Get_Item("FACT_FactoryDocument") -and $_FdsBlocksInDrawing ) {
						#try to activate category "Factory Layout"
						$Prop["_Category"].Value = "Factory Layout"
					}
					#endregion FDU Support ---------------

					#Initialize Shortcuts
					mFillMyScTree

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
	#activate or create the user's VDS profile
	$m_File = "$($env:appdata)\Autodesk\DataStandard 2024\Folder2024.xml"
	if (!(Test-Path $m_File)) {
		$source = "$($env:ProgramData)\Autodesk\Vault 2024\Extensions\DataStandard\Vault.Custom\Folder2024.xml"
		Copy-Item $source $m_File
	}
}

function AddinUnloaded {
	#Executed when DataStandard is unloaded in Inventor/AutoCAD
}

function GetVaultRootFolder()
{
    $mappedRootPath = $Prop["_VaultVirtualPath"].Value + $Prop["_WorkspacePath"].Value
    $mappedRootPath = $mappedRootPath -replace "\\", "/" -replace "//", "/"
    if ($mappedRootPath -eq '')
    {
        $mappedRootPath = '$'
    }
    return $vault.DocumentService.GetFolderByPath($mappedRootPath)
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
			$mCatName = $Global:mCategories | Where-Object { $_.Name -eq $UIString["MSDCE_CAT10"] } #assembly, available in PDMC-Sample Vault
			IF ($mCatName) { 
				$Prop["_Category"].Value = $UIString["MSDCE_CAT10"]
			}
			$mCatName = $Global:mCategories | Where-Object { $_.Name -eq $UIString["MSDCE_CAT02"] }
			IF ($mCatName) { 
				$Prop["_Category"].Value = $UIString["MSDCE_CAT02"] #3D Component, e.g. PDMC-Sample
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
				}
			} 
		}
		'12290' { #part
			$mCatName = $Global:mCategories | Where-Object { $_.Name -eq $UIString["MSDCE_CAT08"] } #Part, available PDMC-Sample Vault
			IF ($mCatName) { 
				$Prop["_Category"].Value = $UIString["MSDCE_CAT08"]
			}
			$mCatName = $Global:mCategories | Where-Object { $_.Name -eq $UIString["MSDCE_CAT02"] }
			IF ($mCatName) { 
				$Prop["_Category"].Value = $UIString["MSDCE_CAT02"] #3D Component, available in MFG-Sample Vault
			}
			Else {
				$mCatName = $Global:mCategories | Where-Object { $_.Name -eq $UIString["CAT1"] } #"Engineering"
				IF ($mCatName) { 
					$Prop["_Category"].Value = $UIString["CAT1"]
				}
			}
			If ($mDocSubType -eq "{9C464203-9BAE-11D3-8BAD-0060B0CE6BB4}") {
				$mCatName = $Global:mCategories | Where-Object { $_.Name -eq $UIString["MSDCE_CAT09"] } #sheet metal part, available PDMC-Sample Vault
				IF ($mCatName) { 
					$Prop["_Category"].Value = $UIString["MSDCE_CAT09"]
				}
			}
			If ($Document.IsSubstitutePart -eq $true) { 
				$mCatName = $Global:mCategories | Where-Object { $_.Name -eq $UIString["MSDCE_CAT12"] } #substitute, available PDMC-Sample Vault
				IF ($mCatName) { 
					$Prop["_Category"].Value = $UIString["MSDCE_CAT12"]
				}
			}			
		}
		'12292' { #drawing
			$mCatName = $Global:mCategories | Where-Object { $_.Name -eq $UIString["MSDCE_CAT00"] }
			IF ($mCatName) { $Prop["_Category"].Value = $UIString["MSDCE_CAT00"] }
			Else { # in case the current vault is not MFG-Sample (Quickstart, but a plain MFG default configuration
				$mCatName = $Global:mCategories | Where-Object { $_.Name -eq $UIString["CAT1"] } #"Engineering"
				IF ($mCatName) { $Prop["_Category"].Value = $UIString["CAT1"] }
			}
		}
		'12293' { #presentation
			$mCatName = $Global:mCategories | Where-Object { $_.Name -eq $UIString["MSDCE_CAT13"] } #presentation, available PDMC-Sample Vault
			IF ($mCatName) { 
				$Prop["_Category"].Value = $UIString["MSDCE_CAT13"]
			}
			$mCatName = $Global:mCategories | Where-Object { $_.Name -eq $UIString["MSDCE_CAT02"] } #3D Component, Quickstart, e.g. MFG-2019-PRO-EN
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
			#VDS MFG Sample - there is the use case that we don't need a number: IDW/DWG, IPN and Option Generate new file number = off
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
			
			# Inventor Open From ContentCenter -> Custom Part command either gets a file number from Vault or has a standard based file name
			Try {			
				if ($Document.FilePropertySets[6][1]) {
					if ($Document.FilePropertySets[6][1].Value -eq "1") {
						if ($Prop["_NumSchm"].Value) { $Prop["_NumSchm"].Value = $_FilteredNumSchems[1].Name } # None
					}
				}
   			}
			Catch { }

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

		"AutoCADWindow"
		{
			#rules applying for AutoCAD
			if ($Prop["_CreateMode"]) {

				mWriteLastUsedFolder

				#the default ACM Titleblocks expect the file name and drawing number as attribute values; adjust property(=attribute) names for custom titleblock definitions
				$dc = $dsWindow.DataContext
				$Prop["GEN-TITLE-DWG"].Value = $dc.PathAndFileNameHandler.FileName
				$Prop["GEN-TITLE-NR"].Value = $dc.PathAndFileNameHandler.FileNameNoExtension
			}
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

#region Shortcuts
function mFillMyScTree {

	# Define a custom class to represent the tree nodes
	class TreeNode {
		[string]$Name
		[string]$IconSource
		[System.Collections.ArrayList]$Children
		[bool]$DeleteEnabled

		TreeNode([string]$name, [string]$IconSource) {
			$this.Name = $name
			$this.IconSource = $IconSource
			$this.Children = [System.Collections.ArrayList]::new()
			$this.DeleteEnabled = $false
		}

		[void]AddChild([TreeNode]$child) {
			$this.Children.Add($child)
		}
	}	
	
	#create a dictionary saving shortcut name and URI
	$Global:m_ScDict = @{}

	# Get the treeView element from the window
	$treeView = $dsWindow.FindName("ScTree")

	# Create a treeRoot node for the treeView
	$IconSource = "C:\ProgramData\Autodesk\Vault 2024\Extensions\DataStandard\Vault.Custom\Icons" + $Global:currentTheme + "\User_CO_16.png"
	$treeRoot = [TreeNode]::new("UserRoot", "")
	$MyScRoot = [TreeNode]::New("My Shortcuts", $IconSource)

	#read the user shortcuts stored in appdata
	[XML]$mUserScXML = mReadUserShortcuts
	if ($null -ne $mUserScXML) {
		if ($mUserScXML.Shortcuts.ChildNodes.Count -gt 0) {
			foreach ($Node in $mUserScXML.Shortcuts.ChildNodes) {
				mAddTreeNode $Node $MyScRoot $true
			}
		}
	}

	# add the user shortcuts to the tree's root
	$treeRoot.AddChild($MyScRoot)

	# Get the tree for distributed shortcuts
	$IconSource = "C:\ProgramData\Autodesk\Vault 2024\Extensions\DataStandard\Vault.Custom\Icons" + $Global:currentTheme + "\User_Admin_16.png"
	$DstrbScRoot = [TreeNode]::new("Distributed Shortcuts", $IconSource)

	#read the distributed shortcuts stored in the Vault
	$mAdminScXML = [XML]$vault.KnowledgeVaultService.GetVaultOption("AdminShortcuts")
	if ($null -ne $mAdminScXML) {		
		if ($mAdminScXML.AdminShortcuts.ChildNodes.Count -gt 0) {

			foreach ($Node in $mAdminScXML.AdminShortcuts.ChildNodes) {
				mAddTreeNode $Node $DstrbScRoot $false
			}			 
		}		
	}
	
	#add the distributed shortcuts to the tree's root
	$treeRoot.AddChild($DstrbScRoot)
	
	#bind the tree items to the treeview
	$treeView.ItemsSource = $treeRoot.Children

	#enable the click event on tree items
	$dsWindow.FindName("ScTree").add_SelectedItemChanged({
		mClickScTreeItem
	})

}

function mAddTreeNode($XmlNode, $TreeLevel, $EnableDelete) {
	if ($XmlNode.LocalName -eq "Shortcut") {
		if (($XmlNode.NavigationContextType -eq "Connectivity.Explorer.Document.DocFolder") -and ($XmlNode.NavigationContext.URI -like "*"+$global:CAx_Root + "/*")) {
			#add the shortcut to the dictionary for instant read on selection change
			$Global:m_ScDict.Add($XmlNode.Name, $XmlNode.NavigationContext.URI)				
			#create a tree node
			$IconSource = mGetIconSource($XmlNode.ImageMetaData)
			$child = [TreeNode]::new($XmlNode.Name, $IconSource)
			if ($true -eq $EnableDelete) {
				$child.DeleteEnabled = $true
			}			
			$TreeLevel.AddChild($child)
		}
	}
	if ($XmlNode.LocalName -eq "ShortcutGroup") {
		$IconSource = "C:\ProgramData\Autodesk\Vault 2024\Extensions\DataStandard\Vault.Custom\Icons" + $Global:currentTheme + "\FolderClosedMask_16.png"
		if ($XmlNode.HasChildNodes -eq $true) {
			$NextLevel = [TreeNode]::new($XmlNode.Name, $IconSource)
			$XmlNode.ChildNodes | ForEach-Object {
				mAddTreeNode -XmlNode $_ -TreeLevel $NextLevel $EnableDelete
			}
			$child = $NextLevel
		}
		else{
			$child = [TreeNode]::new($XmlNode.Name, $IconSource)
		}
		#add the group to the tree		
		$TreeLevel.AddChild($child)
	}
}

function mGetIconSource {
	param (
		$ImageMetaData
	)

	[string]$ImagePath = "C:\ProgramData\Autodesk\Vault 2024\Extensions\DataStandard\Vault.Custom\Icons" + $Global:currentTheme + "\Unknown_Sc_16x16.png"

	if ($ImageMetaData -like "*.iam?*") {
		return $ImagePath = "C:\ProgramData\Autodesk\Vault 2024\Extensions\DataStandard\Vault.Custom\Icons" + $Global:currentTheme + "\IAM_Sc_16x16.png" 
	}
	if ($ImageMetaData -like'*.ipt?*') {
		return $ImagePath = "C:\ProgramData\Autodesk\Vault 2024\Extensions\DataStandard\Vault.Custom\Icons" + $Global:currentTheme + "\IPT_Sc_16x16.png"
	}
	if ($ImageMetaData -like'*.ipn?*') {
		return $ImagePath = "C:\ProgramData\Autodesk\Vault 2024\Extensions\DataStandard\Vault.Custom\Icons" + $Global:currentTheme + "\IPN_Sc_16x16.png"
	}
	if ($ImageMetaData -like "*.idw?*") {
		return $ImagePath = "C:\ProgramData\Autodesk\Vault 2024\Extensions\DataStandard\Vault.Custom\Icons" + $Global:currentTheme + "\IDW_Sc_16x16.png"
	}
	if ($ImageMetaData -like'*.dwg?*') {
		return $ImagePath = "C:\ProgramData\Autodesk\Vault 2024\Extensions\DataStandard\Vault.Custom\Icons" + $Global:currentTheme + "\DWG_Sc_16x16.png"
	}
	if ($ImageMetaData -like '*TAG=Folder*') {
		$FolderTemplate = "C:\ProgramData\Autodesk\Vault 2024\Extensions\DataStandard\Vault.Custom\Icons" + $Global:currentTheme + "\FolderScToRecolor_16.png"
		#extract ARGB part of ImageMetaData
		$ARGB = [Regex]::Matches($ImageMetaData, "\[A\=\d{1,3}, R\=\d{1,3}, G\=\d{1,3}, B\=\d{1,3}\]")[0].Value.TrimStart("[").TrimEnd(']')
		#create string array for ARGB values
		$ARGBValues = [Regex]::Matches($ARGB, "\d{1,3}")
		#build file name for recolored image
		$FlrdArgbName = "$($env:appdata)\Autodesk\DataStandard 2024\FolderScColored-$($ARGBValues[0].Value)-$($ARGBValues[1].Value)-$($ARGBValues[2].Value)-$($ARGBValues[3].Value)_16.png"		
		#check if file exists and create it if it doesn't
		if (Test-Path $FlrdArgbName)
		{
			return $ImagePath = $FlrdArgbName
		}
		else {
			#create a folder image with the ARGB values applied
			$ImageRecolored = mReplaceColor -ImagePath $FolderTemplate -OldColor ([System.Drawing.Color]::FromArgb(255,255,0,0)) -NewColor ([System.Drawing.Color]::FromArgb($ARGBValues[0].Value, $ARGBValues[1].Value, $ARGBValues[2].Value, $ARGBValues[3].Value))
			#save the recolored image the the user's temp folder
			$ImageRecolored.Save($FlrdArgbName)
			$ImageRecolored.Dispose()
			return $FlrdArgbName
		}	}	
	
	return $ImagePath
}

function mReplaceColor {
    param (
      [string]$ImagePath,
      [System.Drawing.Color]$OldColor,
      [System.Drawing.Color]$NewColor
    )
  
    # Load the image from the file
    $Image = [System.Drawing.Image]::FromFile($ImagePath)
  
    # Create a new bitmap object with the same size as the image
    $Bitmap = New-Object System.Drawing.Bitmap($Image.Width, $Image.Height)
  
    # Loop through each pixel of the image
    for ($x = 0; $x -lt $Image.Width; $x++) {
      for ($y = 0; $y -lt $Image.Height; $y++) {
  
        # Check if the color matches the old color and replace in case
        $PixelColor = $Image.GetPixel($x, $y)
        if ($PixelColor.Name -eq $OldColor.Name) {  
          $Bitmap.SetPixel($x, $y, $NewColor)
        }
        else {  
          # keep the original color
          $Bitmap.SetPixel($x, $y, $PixelColor)
        }
      }
    }
  
    # Dispose the image object and return the new bitmap
    $Image.Dispose()
    return $Bitmap
  }

function mReadUserShortcuts {
	$m_Server = ($VaultConnection.Server).Replace(":", "_").Replace("/", "_")
	$m_Vault = $VaultConnection.Vault
	$m_Path = "$($env:appdata)\Autodesk\VaultCommon\Servers\Services_Security_01_10_2023\$($m_Server)\Vaults\$($m_Vault)\Objects\"
	$global:mScFile = $m_Path + "Shortcuts.xml"
	if (Test-Path $global:mScFile) {
		#$dsDiag.Trace(">> Start reading Shortcuts...")
		$global:m_ScXML = New-Object XML 
		$global:m_ScXML.Load($mScFile)
	}
	return $global:m_ScXML
}


function  mClickScTreeItem {
	try {
		$_key = $dsWindow.FindName("ScTree").SelectedItem.Name
		if ($Global:m_ScDict.ContainsKey($_key)) {
			$_Val = $Global:m_ScDict.get_item($_key)
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
	}
	catch {
		$dsDiag.Trace("mClickScTreeItem function - error reading selected value")
	}
	
}

function mAddSc {
	try {
		$mNewScName = $dsWindow.FindName("txtNewShortCut").Text
		mAddShortCutByName ($mNewScName)		
		#rebuild the tree view to include the new shortcut
		mFillMyScTree
	}
	catch {}
}

function mRemoveSc {
	try {
		$_key = $dsWindow.FindName("ScTree").SelectedItem.Name
		if ($true -eq $dsWindow.FindName("ScTree").SelectedItem.DeleteEnabled) {
			mRemoveShortCutByName $_key
			#rebuild the tree view to include the new shortcut
			mFillMyScTree
		}
	}
	catch { }
}

function mAddShortCutByName([STRING] $mScName)
{
	try #simply check that the name is unique
	{
		#$dsDiag.Trace(">> Start to add ShortCut, check for used name...")
		$Global:m_ScDict.Add($mScName,"Dummy")
		$global:m_ScDict.Remove($mScName)
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
		$m_File = "$($env:appdata)\Autodesk\DataStandard 2024\Folder2024.xml"

		if (Test-Path $m_File)
		{
			#$dsDiag.Trace(">>-- Started to read Folder2024.xml...")
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

		#get the navigation folder's color
		$mFldrPath = $newURI.Replace("vaultfolderpath:", "")	
		$mFldr = $vault.DocumentService.FindFoldersByPaths(@($mFldrPath))		
		$mCatDef = $vault.CategoryService.GetCategoryById($mFldr[0].Cat.CatId)
		$mFldrColor = [System.Drawing.Color]::FromArgb($mCatDef.Color)
		#replace the ARGB colors in the template
		$mImageNode = $mNewSc.ImageMetaData
		$regex = '\[A=(\d+), R=(\d+), G=(\d+), B=(\d+)\]'
		$mImageNode = $mImageNode -replace $regex, "[A=$mFldrColor.A, R=$mFldrColor.R, G=$mFldrColor.G, B=$mFldrColor.B]"
		$mNewSc.ImageMetaData = $mImageNode

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
		#catch all nodes; multiple shortcuts can be equally named
		$mNodesToSelect = "//*[@Name='$($mScName)']"

		$nodes = $global:m_ScXML.SelectNodes($mNodesToSelect)
		$response = [Autodesk.DataManagement.Client.Framework.Forms.Library]::ShowWarning("Are you sure you want to delete this shortcut?", "VDS-Sample-Configuration", "YesNo" )
		if ($response -eq "Yes") {
			foreach ($node in $nodes) {
				$node.ParentNode.RemoveChild($node)
			}
		}
		$global:m_ScXML.Save($global:mScFile)
		return $true
	}
	catch {
		return $false
	}
}
#endregion Shortcuts

