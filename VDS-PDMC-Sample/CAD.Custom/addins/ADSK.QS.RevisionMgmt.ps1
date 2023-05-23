#region disclaimer =============================================================================
# PowerShell script sample for Vault Data Standard
#			 Autodesk Vault - VDS-PDMC-Sample 2022
# This sample is based on VDS 2023 RTM and adds functionality and rules
#
# Copyright (c) Autodesk - All rights reserved.
#
# THIS SCRIPT/CODE IS PROVIDED "AS IS" WITHOUT WARRANTY OF ANY KIND, EITHER
# EXPRESSED OR IMPLIED, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED WARRANTIES
# OF MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE, OR NON-INFRINGEMENT.
#endregion =============================================================================

#region - version history

#Version Info - VDS-PDMC-Sample Revision Management 2022.2.0
# removed workarounds required by RTM and 2022.1 and fixed by pre-liminary patch and 2022.2

#Version Info - VDS-PDMC-Sample Revision Management 2022.0.0
# initial version

#endregion

function InvertReadOnly {
	if ($Prop["_EditMode"].Value -eq $true) {
		switch ($dsWindow.Name) {
			"InventorWindow" {
				if ((Get-Item $document.FullFileName).IsReadOnly) {
					return $false
				}
			}

			"AutoCADWindow" {
				if ((Get-Item $document.Name).IsReadOnly) {
					return $false
				}
			}
		}
	
		return $true
		
	} #EditMode
}

function InitializeRevisionValidation {
	if (-not $dsWindow.FindName("tabRevision")) {
		return
	}

	#copy number if ECO drives the revision
	$mFile = mGetVaultFile
	$mEcoFile = $vault.ChangeOrderService.GetChangeOrderFilesByFileMasterId($mFile.MasterId)
	if ($null -ne $mEcoFile) {
		$mEcoNum = $mEcoFile[0].ChangeOrder.Num
		$Prop["Change Descr"].Value = $mEcoNum
	}

	#set the display state of XAML controls
	if (@(".DWG", ".IDW", ".dwg", ".idw") -contains $Prop["_FileExt"].Value) {
		$dsWindow.FindName("grdApproval").Visibility = "Visible"
	}
	else {
		$dsWindow.FindName("grdApproval").Visibility = "Collapsed"
	}

	if (@(".DWG", ".IDW", ".dwg", ".idw") -contains $Prop["_FileExt"].Value -and $Prop["Customer Approval Required"]) {
		if ($Prop["Customer Approval Required"].Value -eq "True") {
			$dsWindow.FindName("grdCustomerApproval").Visibility = "Visible"
		}
		else {
			$dsWindow.FindName("grdCustomerApproval").Visibility = "Collapsed"
		}
	}

	#if the file exists in Vault, state and revision information are available
	$mFile = mGetVaultFile
	if ($mFile) {
		$mFileState = $mFile.FileLfCyc.LfCycStateName
	}
	else { 
		$mFileState = $null
	}
										
	if ($null -ne $mFile) {
		$mFileProperties = @{}
		$mFileProperties = mGetFilePropValues $mFile.Id
		$mPropTrans = @{}
		$mPropTrans = mGetPropTranslations
		$dsWindow.FindName("txtRevision").Text = $mFileProperties.Get_Item($mPropTrans["REVISION"])
		$dsWindow.FindName("txtStatus").Text = $mFileProperties.Get_Item($mPropTrans["STATE"])
		$dsWindow.FindName("txtLfcDef").Text = $mFileProperties.Get_Item($mPropTrans["LIFECLCDEF"])
		$dsWindow.FindName("txtOriginator").Text = $mFileProperties.Get_Item($mPropTrans["ORIGINATOR"])
		$mOrigDate = $mFileProperties.Get_Item($mPropTrans["ORIGCREATEDATE"])
		if ($mOrigDate -ne $NullOrEmpty) {$dsWindow.FindName("txtOrigCreateDate").Text = $mOrigDate.ToString("yyyy-MM-dd HH:mm")}		
		$dsWindow.FindName("LatestRev").IsChecked = $mFileProperties.Get_Item($mPropTrans["LATESTRELREVISION"])
		$dsWindow.FindName("txtInitApprover").Text = $mFileProperties.Get_Item($mPropTrans["INITIALAPPROVER"])
		$mInitDate = $mFileProperties.Get_Item($mPropTrans["INITRELEASEDATE"])
		if ($mInitDate -ne $NullOrEmpty ) {$dsWindow.FindName("txtInitalRelDate").Text = $mInitDate.ToString("yyyy-MM-dd HH:mm")}
		$dsWindow.FindName("txtLatestApprover").Text = $mFileProperties.Get_Item($mPropTrans["LATESTAPPROVER"])
		$mLateDate = $mFileProperties.Get_Item($mPropTrans["LATESTRELEASEDATE"])
		if ($mLateDate -ne $NullOrEmpty) {$dsWindow.FindName("txtLatestRelDate").Text = $mLateDate.ToString("yyyy-MM-dd HH:mm")}
		
		$mInitialApprover = $mFileProperties.Get_Item("Initial Approver") #system property to indicate that the file has been released already
	}

	switch ($dsWindow.Name) {
		"InventorWindow" {
			#$dsDiag.Trace("ExtendedRevision Validation for Inventor starts...")
			if (@(".DWG", ".IDW", ".dwg", ".idw") -contains $Prop["_FileExt"].Value) {

				#new files
				if ($null -eq $mFileState) {
					if ($Prop["Checked By"]) {
						$Prop["Checked By"].CustomValidation = { $true }
					}
					if ($Prop["Date Checked"]) {
						$Prop["Date Checked"].CustomValidation = { $true }
					}
					if ($Prop["Engr Approved By"]) {
						$Prop["Engr Approved By"].CustomValidation = { $true }
					}
					if ($Prop["Engr Date Approved"]) {
						$Prop["Engr Date Approved"].CustomValidation = { $true }
					}
					if ($Prop["Change Descr"]) {
						$Prop["Change Descr"].CustomValidation = { $true }
					}
				}

				# Work in Progress or 'Quick-Change'
				if ($mFileState -eq $UIString["Adsk.QS.RevTab_05"] -or $mFileState -eq $UIString["Adsk.QS.RevTab_04"]) {
					if ($Prop["Checked By"]) {
						$Prop["Checked By"].CustomValidation = { ValidateRevisionField $Prop["Checked By"] }
					}
				}

				#there is an option to enforce external customer approval
				if ($Prop["Customer Approval Required"].Value -eq $true) {
					$Prop["Customer Approved By"].CustomValidation = { $true }
					$Prop["Customer Approved Date"].CustomValidation = { $true }
				}

				# 'For Review'
				if ($mFileState -eq $UIString["Adsk.QS.RevTab_03"]) {
					if ($Prop["Checked By"]) {
						$Prop["Checked By"].CustomValidation = { ValidateRevisionField $Prop["Checked By"] }
					}
					if ($Prop["Date Checked"]) {
						$Prop["Date Checked"].CustomValidation = { ValidateRevisionField $Prop["Date Checked"] }
					}
					if ($Prop["Engr Approved By"]) {
						$Prop["Engr Approved By"].CustomValidation = { ValidateRevisionField $Prop["Engr Approved By"] }
					}
					if ($Prop["Engr Date Approved"]) {
						$Prop["Engr Date Approved"].CustomValidation = { ValidateRevisionField $Prop["Engr Date Approved"] }
					}
					if ($Prop["Change Descr"]) {
						$Prop["Change Descr"].CustomValidation = { ValidateRevisionField $Prop["Change Descr"] }
					}
					#there is an option to enforce external approval
					if ($Prop["Customer Approval Required"].Value -eq $true) {
						$Prop["Customer Approved By"].CustomValidation = { ValidateRevisionField $Prop["Customer Approved By"] }
						$Prop["Customer Approved Date"].CustomValidation = { ValidateRevisionField $Prop["Customer Approved Date"] }
					}
					else {
						$Prop["Customer Approved By"].CustomValidation = { $true }
						$Prop["Customer Approved Date"].CustomValidation = { $true }
					}

				}

			}
		}

		"AutoCADWindow" {
			#AutoCAD Mechanical Block Attributes, 
			if ($Prop["GEN-TITLE-DWG"].Value) {
				#new file
				if ($null -eq $mFileState) {
					if ($Prop["GEN-TITLE-CHKM"]) {
						$Prop["GEN-TITLE-CHKM"].CustomValidation = { $true }
					}
					if ($Prop["GEN-TITLE-CHKD"]) {
						$Prop["GEN-TITLE-CHKD"].CustomValidation = { $true }
					}

					if ($Prop["GEN-TITLE-ISSM"]) {
						$Prop["GEN-TITLE-ISSM"].CustomValidation = { $true }
					}

					if ($Prop["GEN-TITLE-ISSD"]) {
						$Prop["GEN-TITLE-ISSD"].CustomValidation = { $true }
					}

					if ($Prop["Change Descr"]) {
						$Prop["Change Descr"].CustomValidation = { $true }
					}

					#there is an option to enforce external customer approval
					if ($Prop["Customer Approval Required"].Value -eq $true) {
						$Prop["Customer Approved By"].CustomValidation = { $true }
						$Prop["Customer Approved Date"].CustomValidation = { $true }
					}
					else {
						$Prop["Customer Approved By"].CustomValidation = { $true }
						$Prop["Customer Approved Date"].CustomValidation = { $true }
					}

				}

				# Work in Progress or 'Quick-Change'
				if ($mFileState -eq $UIString["Adsk.QS.RevTab_05"] -or $mFileState -eq $UIString["Adsk.QS.RevTab_04"]) {
					if ($Prop["GEN-TITLE-CHKM"]) {
						$Prop["GEN-TITLE-CHKM"].CustomValidation = { ValidateRevisionField $Prop["GEN-TITLE-CHKM"] }
					}

					if ($Prop["GEN-TITLE-CHKD"]) {
						$Prop["GEN-TITLE-CHKD"].CustomValidation = { $true }
					}

					if ($Prop["GEN-TITLE-ISSM"]) {
						$Prop["GEN-TITLE-ISSM"].CustomValidation = { $true }
					}

					if ($Prop["GEN-TITLE-ISSD"]) {
						$Prop["GEN-TITLE-ISSD"].CustomValidation = { $true }
					}

					if ($Prop["Change Descr"]) {
						$Prop["Change Descr"].CustomValidation = { $true }
					}

					#there is an option to enforce external approval
					if ($Prop["Customer Approval Required"].Value -eq $true) {
						$Prop["Customer Approved By"].CustomValidation = { ValidateRevisionField($Prop["Customer Approved By"]) }
						$Prop["Customer Approved Date"].CustomValidation = { $true }
					}
					else {
						$Prop["Customer Approved By"].CustomValidation = { $true }
						$Prop["Customer Approved Date"].CustomValidation = { $true }
					}

				}#work in Progress

				#For Review	
				if ($mFileState -eq $UIString["Adsk.QS.RevTab_03"]) {
					if ($Prop["GEN-TITLE-CHKM"]) {
						$Prop["GEN-TITLE-CHKM"].CustomValidation = { ValidateRevisionField $Prop["GEN-TITLE-CHKM"] }
					}
					if ($Prop["GEN-TITLE-CHKD"]) {
						$Prop["GEN-TITLE-CHKD"].CustomValidation = { ValidateRevisionField $Prop["GEN-TITLE-CHKD"] }
					}
					if ($Prop["GEN-TITLE-ISSM"]) {
						$Prop["GEN-TITLE-ISSM"].CustomValidation = { ValidateRevisionField $Prop["GEN-TITLE-ISSM"] }
					}
					if ($Prop["GEN-TITLE-ISSD"]) {
						$Prop["GEN-TITLE-ISSD"].CustomValidation = { ValidateRevisionField $Prop["GEN-TITLE-ISSD"] }
					}
					if ($Prop["Change Descr"]) {
						$Prop["Change Descr"].CustomValidation = { ValidateRevisionField $Prop["Change Descr"] } #revision table property in PDMC-Sample
					}
					
					#there is an option to enforce external approval
					if ($Prop["Customer Approval Required"].Value -eq $true) {
						$Prop["Customer Approved By"].CustomValidation = { ValidateRevisionField $Prop["Customer Approved By"] }
						$Prop["Customer Approved Date"].CustomValidation = { ValidateRevisionField $Prop["Customer Approved Date"] }
					}
					else {
						$Prop["Customer Approved By"].CustomValidation = { $true }
						$Prop["Customer Approved Date"].CustomValidation = { $true }
					}

				}
		
			}#Mechanical Block Attributes

		}# AutoCAD

	}#switch WindowName
	
}#end function InitializeRevisionValidation


function ValidateRevisionField($mProp) {
	#$dsDiag.Trace(">>Validation runs for '$($mProp.Name)', $($mProp.Typ)")

	If ($Prop["_EditMode"].Value -eq $true) {		
		#$dsDiag.Trace("...EditMode...")

		if ($mProp.Value -eq "" -OR $null -eq $mProp.Value) {
			#$dsDiag.Trace("...no Value: returning false<<")
			$mProp.CustomValidationErrorMessage = "Empty value are not allowed for the current life cylce state!"
			return $false
		}
		else {
			#$dsDiag.Trace("...has Value: returning true<<")
			return $true
		}
	}
	
}


function mGetVaultFile {
	if ($Prop["_CreateMode"].Value -eq $true) {
		return $null
	}
	#we need the current file object
	$_wf = $vaultconnection.WorkingFoldersManager.GetWorkingFolder("$/").FullPath
	$_1 = $Prop["_FilePath"].Value.Replace($_wf, "$/")
	$_2 = $_1.Replace("\", "/")
	$mVaultFilePath = $_2 + "/" + $Prop["_FileName"].Value

	$mFile = $vault.DocumentService.FindLatestFilesByPaths(@($mVaultFilePath))[0]	

	if ($mFile.id -ne -1) {
		return $mFile
	}

	return $null

}

function mGetFilePropValues ([Int64] $mFileId) {
	$mPropInsts = @()
	$mPropInsts += $vault.PropertyService.GetPropertiesByEntityIds("FILE", @($mFileId))
	
	# a PropInst is an Id-Value pair; we migrate it to a (Display-)Name-Value pair
	$mPropNameValueMap = @{}

	$mPropDefs = $vault.PropertyService.GetPropertyDefinitionsByEntityClassId("FILE")
	
	ForEach ($mPropInst in $mPropInsts) {
		$mDispName = ($mPropDefs | Where-Object { $_.Id -eq $mPropInst.PropDefId } ).DispName
		$mPropNameValueMap.Add($mDispName, $mPropInst.Val)
	}
	
	return $mPropNameValueMap
	
}


function ResetRevisionProperties {
	switch ($dsWindow.Name) {
		"InventorWindow" {
			#$dsDiag.Trace("ExtendedRevision Validation for Inventor starts...")
			if (@(".DWG", ".IDW", ".dwg", ".idw") -contains $Prop["_FileExt"].Value) {
				if ($Prop["Checked By"]) {
					$Prop["Checked By"].Value = ""
				}
				if ($Prop["Date Checked"]) {
					$Prop["Date Checked"].Value = ""
				}
				if ($Prop["Engr Approved By"]) {
					$Prop["Engr Approved By"].Value = ""
				}
				if ($Prop["Engr Date Approved"]) {
					$Prop["Engr Date Approved"].Value = ""
				}
			}
		}
		"AutoCADWindow" {
			#AutoCAD Mechanical Block Attribute Template
			if ($Prop["GEN-TITLE-DWG"].Value) {		
				if ($Prop["GEN-TITLE-CHKM"]) {
					$Prop["GEN-TITLE-CHKM"].Value = ""
				}					
				if ($Prop["GEN-TITLE-CHKD"]) {
					$Prop["GEN-TITLE-CHKD"].Value = ""
				}
				if ($Prop["GEN-TITLE-ISSM"]) {
					$Prop["GEN-TITLE-ISSM"].Value = ""
				}
				if ($Prop["GEN-TITLE-ISSD"]) {
					$Prop["GEN-TITLE-ISSD"].Value = ""
				}
			}

		} #AutoCADWindow

	} #switch WindowName

	if ($Prop["Change Descr"]) {
		$Prop["Change Descr"].Value = "First Issue"
	}
	
	if ($Prop["Customer Approval Required"]) {
		$Prop["Customer Approval Required"].Value = "False"
	}

	if ($Prop["Customer Approved By"]) {
		$Prop["Customer Approved By"].Value = ""
	}

	if ($Prop["Customer Approved Date"]) {
		$Prop["Customer Approved Date"].Value = ""
	}

}