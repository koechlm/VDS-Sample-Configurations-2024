# DISCLAIMER:
# ---------------------------------
# In any case, code, templates, and snippets of this solution are of "work in progress" character.
# Neither Markus Koechl, nor Autodesk represents that these samples are reliable, accurate, complete, or otherwise valid. 
# Accordingly, those configuration samples are provided as is with no warranty of any kind, and you use the applications at your own risk.


function InvertReadOnly
{
	if ($Prop["_ReadOnly"].Value){
		return $false
	}
	else{
		return $true
	}
}

function InitializeRevisionValidation
{
	if (-not $dsWindow.FindName("tabRevision"))
	{
		return
	}

	#copy number if ECO drives the revision
	$mFile = mGetFileObject
	$mEcoFile = $vault.ChangeOrderService.GetChangeOrderFilesByFileMasterId($mFile.MasterId)
	if($mEcoFile -ne $null)
	{
		$mEcoNum = $mEcoFile[0].ChangeOrder.Num
		$Prop["_XLTN_CHANGEDESCR"].Value = $mEcoNum
	}

	#set the display state of XAML controls
	$dsWindow.FindName("grdCustomerApproval").Visibility = "Collapsed"

	#Inventor and AutoCAD Drawings initialize custom property validation only
	if(@($UIString["MSDCE_CAT00"], $UIString["MSDCE_CAT01"]) -contains $Prop["_Category"].Value)
	{
		#set the display state of XAML controls
		
		if($Prop["_XLTN_CUSTAPPRVLREQ"].Value -eq $true)
		{
			$dsWindow.FindName("grdCustomerApproval").Visibility = "Visible"
		}
		else
		{
			$dsWindow.FindName("grdCustomerApproval").Visibility = "Collapsed"
		}

		##don't enforce anything for new or WiP files
		#if($Prop["Initial Approver"].Value -eq $null)
		#{
		#	if($Prop["_XLTN_CHECKEDBY"]) 
		#	{
		#		$Prop["_XLTN_CHECKEDBY"].CustomValidation = { $true }
		#	}
		#	if($Prop["_XLTN_CHECKEDDATE"])
		#	{
		#		$Prop["_XLTN_CHECKEDDATE"].CustomValidation = { $true }
		#	}
		#	if($Prop["_XLTN_ENGAPPRVDBY"])
		#	{
		#		$Prop["_XLTN_ENGAPPRVDBY"].CustomValidation = { $true }
		#	}
		#	if($Prop["_XLTN_ENGAPPRVDDATE"])
		#	{
		#		$Prop["_XLTN_ENGAPPRVDDATE"].CustomValidation = { $true }
		#	}
		#	if($Prop["_XLTN_CHANGEDESCR"])
		#	{
		#		$Prop["_XLTN_CHANGEDESCR"].CustomValidation = { $true }
		#	}

		#	#there is an option to enforce external approval
		#	if($Prop["Customer Approval Required"].Value -eq $true)
		#	{
		#		$Prop["Customer Approved By"].CustomValidation = { $true}
		#		$Prop["Customer Approved Date"].CustomValidation = { $true}
		#	}

		#}

		##enforce revision properties dependent on current state
		##if($Prop["_EditMode"].Value -eq $true)
		##{
		#	#Work in Progress or Quick-Change
		#	if(@($UIString["Adsk.QS.RevTab_05"], $UIString["Adsk.QS.RevTab_04"]) -contains $Prop["_XLTN_STATE"].Value -and $dsWindow.FindName("txtRevision").Text -ne "-")
		#	{
		#		if($Prop["_XLTN_DOCCHCKREQ"])
		#		{
		#			if($Prop["_XLTN_DOCCHCKREQ"].Value -eq "True")
		#			{
		#				if($Prop["_XLTN_CHECKEDBY"]) 
		#				{
		#					$Prop["_XLTN_CHECKEDBY"].CustomValidation = { ValidateRevisionField($Prop["_XLTN_CHECKEDBY"]) }
		#				}
		#			}
		#		}
				
		#		if($Prop["_XLTN_CHECKEDDATE"])
		#		{
		#			$Prop["_XLTN_CHECKEDDATE"].CustomValidation = { $true }
		#		}
		#		if($Prop["_XLTN_ENGAPPRVDBY"])
		#		{
		#			$Prop["_XLTN_ENGAPPRVDBY"].CustomValidation = { $true }
		#		}
		#		if($Prop["_XLTN_ENGAPPRVDDATE"])
		#		{
		#			$Prop["_XLTN_ENGAPPRVDDATE"].CustomValidation = { $true }
		#		}
		#		if($Prop["_XLTN_CHANGEDESCR"])
		#		{
		#			$Prop["_XLTN_CHANGEDESCR"].CustomValidation = { $true }
		#		}

		#		#there is an option to enforce external approval
		#		if($Prop["Customer Approval Required"].Value -eq $true)
		#		{
		#			$Prop["Customer Approved By"].CustomValidation = { ValidateRevisionField($Prop["Customer Approved By"]) }
		#			$Prop["Customer Approved Date"].CustomValidation = { $true}
		#		}
		#		else
		#		{
		#			$Prop["Customer Approved By"].CustomValidation = { $true }
		#			$Prop["Customer Approved Date"].CustomValidation = { $true }
		#		}

		#	} #Work in Progress or Quick-Change

		#	#For Review
		#	if(@($UIString["Adsk.QS.RevTab_03"]) -contains $Prop["_XLTN_STATE"].Value)
		#	{
		#		if($Prop["_XLTN_DOCCHCKREQ"])
		#		{
		#			if($Prop["_XLTN_DOCCHCKREQ"].Value -eq "True")
		#			{
		#				if($Prop["_XLTN_CHECKEDBY"]) 
		#				{
		#					$Prop["_XLTN_CHECKEDBY"].CustomValidation = { ValidateRevisionField($Prop["_XLTN_CHECKEDBY"]) }
		#				}
		#				if($Prop["_XLTN_CHECKEDDATE"])
		#				{
		#					$Prop["_XLTN_CHECKEDDATE"].CustomValidation = { ValidateRevisionField($Prop["_XLTN_CHECKEDDATE"]) }
		#				}
		#			}
		#		}
		#		if($Prop["_XLTN_ENGAPPRVDBY"])
		#		{
		#			$Prop["_XLTN_ENGAPPRVDBY"].CustomValidation = { ValidateRevisionField($Prop["_XLTN_ENGAPPRVDBY"]) }
		#		}
		#		if($Prop["_XLTN_ENGAPPRVDDATE"])
		#		{
		#			$Prop["_XLTN_ENGAPPRVDDATE"].CustomValidation = { ValidateRevisionField($Prop["_XLTN_ENGAPPRVDDATE"]) }
		#		}
		#		if($Prop["_XLTN_CHANGEDESCR"])
		#		{
		#			$Prop["_XLTN_CHANGEDESCR"].CustomValidation = { ValidateRevisionField($Prop["_XLTN_CHANGEDESCR"]) }
		#		}

		#		#there is an option to enforce external approval
		#		if($Prop["Customer Approval Required"].Value -eq $true)
		#		{
		#			$Prop["Customer Approved By"].CustomValidation = { ValidateRevisionField($Prop["Customer Approved By"]) }
		#			$Prop["Customer Approved Date"].CustomValidation = { $true}
		#		}
		#		else
		#		{
		#			$Prop["Customer Approved By"].CustomValidation = { $true }
		#			$Prop["Customer Approved Date"].CustomValidation = { $true }
		#		}

		#	}# For Review

		##} #edit mode

	}#drawing categories

}

function ValidateRevisionField($mProp)
{
	If ($Prop["_CreateMode"].Value -eq $true)
    {
        return $true
    }

	If ($Prop["_EditMode"].Value -eq $true)
	{		
		#$dsDiag.Trace("...EditMode...")
		
		if ($mProp.Value -eq "" -OR $mProp.Value -eq $null)
		{
			#$dsDiag.Trace(" '$($mProp)'...no Value: returning false<<")
			return $false
		}
		else
		{
			#$dsDiag.Trace(" '$($mProp)'...has Value: returning true<<")
			return $true
		}
	}#edit mode

}#function

