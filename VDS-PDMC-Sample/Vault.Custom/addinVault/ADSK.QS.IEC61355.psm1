# DISCLAIMER:
# ---------------------------------
# In any case, code, templates, and snippets of this solution are of "work in progress" character.
# Neither Markus Koechl, nor Autodesk represents that these samples are reliable, accurate, complete, or otherwise valid. 
# Accordingly, those configuration samples are provided as is with no warranty of any kind, and you use the applications at your own risk.


Add-Type @"
public class IEC61355Data
{
	public string Id {get;set;}
	public string SubClass {get;set;}
	public string Example {get;set;}
	public string Code {get;set;}
	public string SubClassDE {get;set;}
	public string ExampleDE {get;set;}
	public string Favorite {get;set;}
	public string Path {get;set;}
	public string PathCode {get;set;}
}
"@

function mInitializeIEC61355
{            
	If ($dsWindow.FindName("expIEC61355"))
	{      							
		#Try 
		#{	
			If($mIEC61355Initialized -ne $true)
			{
				$Global:NavigatedOrSearched = ""
				#get the property definitions for custom objects
				if(-not $Global:CustentPropDefs) {	$Global:CustentPropDefs = $vault.PropertyService.GetPropertyDefinitionsByEntityClassId("CUSTENT")}

				If(-not $UIString["Adsk.IEC61355.00"]) { $UIString = mGetUIStrings } #the psm library might not get the VDS default variable
				mAddIEC61355Combo -_CoName "Segment" #enables classification level 1

				#Search tab
				$mWindowName = $dsWindow.Name
				if($mWindowName -eq "AutoCADWindow" -or $mWindowName -eq "InventorWindow")
				{
					$mTagPropName = "DCC"
				}
				else
				{
					$mTagPropName = "Document Tag"
				}
				
				if($Prop[$mTagPropName].Value -ne "")
				{
					#activate the search tab if it isn't
					$dsWindow.FindName("tabIEC61355Search").IsSelected = $true
					$dsWindow.FindName("txtSearchIEC61355").Text = $Prop[$mTagPropName].Value
					mSearchIEC61355

					if($dsWindow.FindName("dataGrdIEC61355Found").Items.Count -eq 1)
					{
						$dsWindow.FindName("dataGrdIEC61355Found").SelectedItem = $dsWindow.FindName("dataGrdIEC61355Found").Items[0]
						mApplyIEC61355
					}
				}

				$dsWindow.FindName("dataGrdIEC61355Found").add_SelectionChanged({
					param($sender, $SelectionChangedEventArgs)
					#$dsDiag.Trace(".. TermsFoundSelection")
					IF($dsWindow.FindName("dataGrdIEC61355Found").SelectedItem){
						$dsWindow.FindName("btnIEC61355Adopt").IsEnabled = $true
						$dsWindow.FindName("btnIEC61355Adopt").IsDefault = $true
					}
					Else {
						$dsWindow.FindName("btnIEC61355Adopt").IsEnabled = $false
						if($dsWindow.FindName("btnSearchIEC61355")) { $dsWindow.FindName("btnSearchIEC61355").IsDefault = $true}
					}
				})

				#close the expander as another property is selected 
				$dsWindow.FindName("DSDynCatPropGrid").add_GotFocus({
					$dsWindow.FindName("expIEC61355").Visibility = "Collapsed"
					$dsWindow.FindName("expIEC61355").IsExpanded = $false
					if($dsWindow.FindName("btnSearchIEC61355")) { $dsWindow.FindName("btnSearchIEC61355").IsDefault = $false}
				})

				$Global:mIEC61355Initialized = $true
			}
			
			$dsWindow.FindName("expIEC61355").Visibility = "Visible"
			$dsWindow.FindName("expIEC61355").IsExpanded = $true
			if($dsWindow.FindName("btnSearchIEC61355")) { $dsWindow.FindName("btnSearchIEC61355").IsDefault = $true}

		#}	
		#catch { $dsDiag.Trace("WARNING expander IEC61355 is not present")}
	}#if IEC61355 Expander exists
}


function mSearchIEC61355
{
	#don't mix the result with a previously navigated one
	mResetIEC61355BrdCrmb

	Try {
		#$dsDiag.Trace(">> search COs terms")
		$dsWindow.FindName("dataGrdIEC61355Found").ItemsSource = $null

		$mSearchText1 = $dsWindow.FindName("txtSearchIEC61355").Text

		#search bookmark or all fields
		if($dsWindow.FindName("radioSearchBkmk").IsChecked)
		{
			$srchConds = New-Object autodesk.Connectivity.WebServices.SrchCond[] 3
			$srchConds[0]= mCreateIEC61355SearchCond "Category Name" "Sub Group" "AND"
			$srchConds[1]= mCreateIEC61355SearchCond "Standard" "IEC61355" "AND"
			$srchConds[2]= mCreateIEC61355SearchCond "Bookmark" $mSearchText1 "AND"
		}
		else
		{
			$srchConds = New-Object autodesk.Connectivity.WebServices.SrchCond[] 8
			$srchConds[0]= mCreateIEC61355SearchCond "Category Name" "Sub Group" "AND"
			$srchConds[1]= mCreateIEC61355SearchCond "Standard" "IEC61355" "AND"
			$srchConds[2]= mCreateIEC61355SearchCond "Name" $mSearchText1 "OR"
			$srchConds[3]= mCreateIEC61355SearchCond "Term DE" $mSearchText1 "OR"
			$srchConds[4]= mCreateIEC61355SearchCond "Comments" $mSearchText1 "OR"
			$srchConds[5]= mCreateIEC61355SearchCond "Comments DE" $mSearchText1 "OR"
			$srchConds[6]= mCreateIEC61355SearchCond "Bookmark" $mSearchText1 "OR"
			$srchConds[7]= mCreateIEC61355SearchCond "Code" $mSearchText1 "OR"
		}

		#the default search condition object type is custom object "Group"
		$srchSort = New-Object autodesk.Connectivity.WebServices.SrchSort
		$searchStatus = New-Object autodesk.Connectivity.WebServices.SrchStatus
		$bookmark = ""
		$mResultAll = New-Object 'System.Collections.Generic.List[Autodesk.Connectivity.WebServices.CustEnt]'

		while(($searchStatus.TotalHits -eq 0) -or ($mResultAll.Count -lt $searchStatus.TotalHits))
		{
			$mResultPage = $vault.CustomEntityService.FindCustomEntitiesBySearchConditions($srchConds,@($srchSort),[ref]$bookmark,[ref]$searchStatus)
			If ($searchStatus.IndxStatus -ne "IndexingComplete" -or $searchStatus -eq "IndexingContent")
			{
				#check the indexing status; you might return a warning that the result bases on an incomplete index, or even return with a stop/error message, that we need to have a complete index first
				$dsWindow.FindName("txtIEC61355StatusMsg").Text = $UIString["Adsk.QS.Classification_12"]
				$dsWindow.FindName("txtIEC61355StatusMsg").Visibility = "Visible"
			}
			If($mResultPage.Count -ne 0)
			{
				$mResultAll.AddRange($mResultPage)
			}
			else 
			{ 
				$dsWindow.FindName("txtIEC61355StatusMsg").Text = $UIString["ClassTerms_MSG03"]
				$dsWindow.FindName("txtIEC61355StatusMsg").Visibility = "Visible"
				break;
			}

			#limit the search result to the first result page;
			$dsWindow.FindName("txtIEC61355StatusMsg").Text = $UIString["ClassTerms_MSG02"]
			$dsWindow.FindName("txtIEC61355StatusMsg").Visibility = "Visible"
			break; #limit the search result to the first result page; page scrolling not implemented in this snippet release
		}

		If($mResultAll.Count -lt 1){		
			Return
		}
		Else{
			$dsWindow.FindName("txtIEC61355StatusMsg").Visibility = "Collapsed"
		}
		
		# 	retrieve all properties of the COs found
		$_data = @()
		#derive data set from result do display; items have system properties like number, title, but others require to query the entity properties
		$mResultItemIds = @()
		$mResultAll | ForEach-Object { $mResultItemIds += $_.Id}
		$mPropDefs = @() #to be consumed by GetProperties
		$mPropDict = @{} #to be leveraged reading property by Name instead of Def.Id
		$mDefId += ($Global:CustentPropDefs | Where-Object { $_.DispName -eq "Name"}).Id
		$mPropDefs += $mDefID
		$mPropDict.Add("Name", $mDefID)
		$mDefId = ($Global:CustentPropDefs | Where-Object { $_.DispName -eq "Code"}).Id
		$mPropDefs += $mDefID
		$mPropDict.Add("Code", $mDefID)
		$mDefId = ($Global:CustentPropDefs | Where-Object { $_.DispName -eq "Comments"}).Id
		$mPropDefs += $mDefID
		$mPropDict.Add("Comments", $mDefID)
		$mDefId = ($Global:CustentPropDefs | Where-Object { $_.DispName -eq "Term DE"}).Id
		$mPropDefs += $mDefID
		$mPropDict.Add("Term DE", $mDefID)
		$mDefId = ($Global:CustentPropDefs | Where-Object { $_.DispName -eq "Comments DE"}).Id
		$mPropDefs += $mDefID
		$mPropDict.Add("Comments DE",$mDefID)

		$mPropInst = $vault.PropertyService.GetProperties("CUSTENT", $mResultItemIds, $mPropDefs)

		#build the table to display items with properties
		$Global:mSubClassesPaths = @{}
		foreach($item in $mResultAll)
		{
			#first get the paths to extend the search result for each technical area that a resutl might belong to

			$links_3 = @()
			$mLinkedCustObjects_3 = @()
			$links_3 = $vault.DocumentService.GetLinksByTargetEntityIds(@($item.Id))
			If($links_3)
			{
				$linkIds_3 = @()
				$links_3 | ForEach-Object { $linkIds_3 += $_.ParentId }
				$mLinkedCustObjects_3 = $vault.CustomEntityService.GetCustomEntitiesByIds($linkIds_3);
				if($mLinkedCustObjects_3)
				{
					$mIsoObjects_3 = @()
					$mLinkedCustObjects_3 | ForEach-Object { $mIsoObjects_3 += mConvertCustentsToIEC61355Objects $_ }
				}
			}
			$links_2 = $vault.DocumentService.GetLinksByTargetEntityIds($linkIds_3)
			If($links_2)
			{
				$linkIds_2 = @()
				$links_2 | ForEach-Object { $linkIds_2 += $_.ParentId }
				$mLinkedCustObjects_2 = $vault.CustomEntityService.GetCustomEntitiesByIds($linkIds_2);
				if($mLinkedCustObjects_2)
				{
					$mIsoObjects_2 = @()
					$mLinkedCustObjects_2 | ForEach-Object { $mIsoObjects_2 += mConvertCustentsToIEC61355Objects $_ }
				}
			}
			$links_1 = $vault.DocumentService.GetLinksByTargetEntityIds($linkIds_2)
			If($links_1)
			{
				$linkIds_1 = @()
				$links_1 | ForEach-Object { $linkIds_1 += $_.ParentId }
				$mLinkedCustObjects_1 = $vault.CustomEntityService.GetCustomEntitiesByIds($linkIds_1);
				if($mLinkedCustObjects_1)
				{
					$mIsoObjects_1 = @()
					$mLinkedCustObjects_1 | ForEach-Object { $mIsoObjects_1 += mConvertCustentsToIEC61355Objects $_ }
				}
			}

			#build the data table for all linked paths found of the current subclass found
			if($dsWindow.FindName("radioSearchBkmk").IsChecked)
			{
				$sorted_1 = $mIsoObjects_1 | Where-Object { $_.Code -eq $mSearchText1[0]}
			}
			else
			{
				$sorted_1 = $mIsoObjects_1 | Sort-Object Code
			}

			foreach ($mIso in $sorted_1) { 
				$row = New-Object IEC61355Data
				$row.Id = $item.Id
				$row.SubClass = $item.Name
				$row.Code = ($mPropInst | Where-Object { $_.EntityId -eq $item.Id -and $_.PropDefId -eq $mPropDict["Code"]}).Val
				$row.Example = ($mPropInst | Where-Object { $_.EntityId -eq $item.Id -and $_.PropDefId -eq $mPropDict["Comments"]}).Val
				$row.SubClassDE = ($mPropInst | Where-Object { $_.EntityId -eq $item.Id -and $_.PropDefId -eq $mPropDict["Term DE"]}).Val
				$row.ExampleDE = ($mPropInst | Where-Object { $_.EntityId -eq $item.Id -and $_.PropDefId -eq $mPropDict["Comments DE"]}).Val
				$row.PathCode = "$($mIso.Code) | $($mIsoObjects_2.Code) | $($mIsoObjects_3.Code)"
				$row.Path =  "$($mIso.SubClass) | $($mIsoObjects_2.SubClass) | $($mIsoObjects_3.SubClass)"
				$_data += $row

				$mPathCustents = New-Object Autodesk.Connectivity.WebServices.CustEnt[] 3
				$mPathCustents[0] = $mLinkedCustObjects_1 | Where-Object {$_.Id -eq $mIso.Id}
				$mPathCustents[1] = $mLinkedCustObjects_2[0]
				$mPathCustents[2] = $mLinkedCustObjects_3[0]

				$Global:mSubClassesPaths.Add("$($row.PathCode)-$($row.Code)", $mPathCustents)
			}
		}

		If($_data)
		{
			$dsWindow.FindName("dataGrdIEC61355Found").ItemsSource = $_data
			$Global:NavigatedOrSearched = "Searched"
		}
		else
		{
			$dsWindow.FindName("dataGrdIEC61355Found").ItemsSource = $null
		}
	}
	catch {
		$dsDiag.Trace("ERROR --- in m_SearchIEC61355s function") 
	}

}

function mCreateIEC61355SearchCond ([String] $PropName, [String] $mSearchTxt, [String] $AndOr) {
	$dsDiag.Trace("--SearchCond creation starts... for $PropName and $mSearchTxt ---")
	$srchCond = New-Object autodesk.Connectivity.WebServices.SrchCond
	$propDefs = $Global:CustentPropDefs
	$propNames = @($PropName)
	$propDefIds = @{}
	foreach($name in $propNames) 
	{
		$propDef = $propDefs | Where-Object { $_.dispName -eq $name }
		$propDefIds[$propDef.Id] = $propDef.DispName
	}
	$srchCond.PropDefId = $propDef.Id
	$srchCond.SrchOper = 1
	$srchCond.SrchTxt = $mSearchTxt
	$srchCond.PropTyp = [Autodesk.Connectivity.WebServices.PropertySearchType]::SingleProperty
	
	If ($AndOr -eq "AND") {
		$srchCond.SrchRule = [Autodesk.Connectivity.WebServices.SearchRuleType]::Must
	}
	Else {
		$srchCond.SrchRule = [Autodesk.Connectivity.WebServices.SearchRuleType]::May
	}
	$dsDiag.Trace("--SearchCond creation finished. ---")
	return $srchCond
} 

function mApplyIEC61355
{
	#$dsDiag.Trace("Subclass selected to copy property values")
	$mSelectedCls = $dsWindow.FindName("dataGrdIEC61355Found").SelectedItem
	
	#save to keep user's last used selection
	$value = $dsWindow.FindName("dataGrdIEC61355Found").SelectedItem.SubClass
	$value | Out-File "$($env:appdata)\Autodesk\DataStandard 2022\mIEC61355Id_4.txt"

	#derive the parents tree from the selected object
	$SelectedClsTree = New-Object Autodesk.Connectivity.WebServices.CustEnt[] 3

	#search or selection requires different steps to build the document tag
	if($Global:NavigatedOrSearched -eq "Searched")
	{
		$mkey = "$($mSelectedCls.PathCode)-$($mSelectedCls.Code)"
		$m1 = $Global:mSubClassesPaths[$mkey]
		$SelectedClsTree[0] = $m1[0]
		$SelectedClsTree[1] = $m1[1]
		$SelectedClsTree[2] = $m1[2]
	}
	elseif($Global:NavigatedOrSearched -eq "Navigated")
	{
		$mBreadCrumb = $dsWindow.FindName("wrpIEC61355")	
		$SelectedClsTree[0] = $mBreadCrumb.Children[1].SelectedItem
		$SelectedClsTree[1] = $mBreadCrumb.Children[2].SelectedItem
		$SelectedClsTree[2] = $mBreadCrumb.Children[3].SelectedItem
	}

	$mTreeIsoData =  mConvertCustentsToIEC61355Objects $SelectedClsTree
	$mDCC = $mTreeIsoData[0].Code + $mTreeIsoData[1].Code + $mTreeIsoData[2].Code + $mSelectedCls.Code

	If ($dsWindow.Name -eq "AutoCADWindow" -or $dsWindow.Name -eq "InventorWindow")
	{
		$Prop["DCC"].Value = $mDCC
		$Prop["ART"].Value = $mTreeIsoData[2].SubClassDE
		$Prop["ART_PD_ENG"].Value = $mTreeIsoData[2].SubClass
		$Prop["UUArt_PD_ENG"].Value = $mSelectedCls.SubClass
		$Prop["UUArt"].Value = $mSelectedCls.SubClassDE
	}

	If ($dsWindow.Name -eq "FileWindow") 
	{		
		$Prop["Document Tag"].Value = $mDCC	
		$Prop["Document Type"].Value = $mTreeIsoData[2].SubClass
		$Prop["Document Type DE"].Value = $mTreeIsoData[2].SubClassDE
		$Prop["Document Subtype"].Value = $mSelectedCls.SubClass
		$Prop["Document Subtype DE"].Value = $mSelectedCls.SubClassDE		
	}

	if($dsWindow.FindName("btnSearchIEC61355")) { $dsWindow.FindName("btnSearchIEC61355").IsDefault = $false}
	$dsWindow.FindName("btnOK").IsDefault = $true
	
	#$dsWindow.FindName("tabProperties").IsSelected = $true
}



function mAddIEC61355Combo ([String] $_CoName, $_classes) 
{	
	$children = mGetIEC61355List -_CoName $_CoName
	If($children -eq $null) { return }
	
	$mBreadCrumb = $dsWindow.FindName("wrpIEC61355")
	$cmb = New-Object System.Windows.Controls.ComboBox
	$cmb.Name = "cmbIEC61355BreadCrumb_" + $mBreadCrumb.Children.Count.ToString();
	$cmb.DisplayMemberPath = "Name";
	$cmb.Tooltip = "Select Technical Area"
	$cmb.ItemsSource = @($children)
	#If (($Prop["_CreateMode"].Value -eq $true) -or ($_Return -eq "Yes")) {$cmb.IsDropDownOpen = $true}
	$cmb.MinWidth = 140
	$cmb.HorizontalContentAlignment = "Center"
	$cmb.BorderThickness = "1,1,1,1"
	$cmb.Margin = "1,0,0,1"
	$mWindowName = $dsWindow.Name
	switch($mWindowName)
	{
		"CustomObjectClassifiedWindow"
		{
			If (($Prop["_CreateMode"].Value -eq $true) -or ($_Return -eq "Yes")) {$cmb.IsDropDownOpen = $true}
		}
		"InventorWindow"
		{
			#if($dsWindow.FindName("tabIEC61355Navigate").IsSelected -eq $true)
			#{
				If (($Prop["_CreateMode"].Value -eq $true) -or ($_Return -eq "Yes")) {$cmb.IsDropDownOpen = $true}
			#}
		}
		default
		{
			$cmb.IsDropDownOpen = $false
		}
	}
	$cmb.add_SelectionChanged({
			param($sender,$e)
			$dsDiag.Trace("1. SelectionChanged, Sender = $($sender), $($e)")
			mIEC61355ComboSelectionChanged -sender $sender
		});
	$mBreadCrumb.RegisterName($cmb.Name, $cmb) #register the name to activate later via indexed name
	$mBreadCrumb.Children.Add($cmb);

} # addCoCombo

function mAddIEC61355ComboChild ($data) 
{
	$children = @()
	$children = mGetIEC61355UsesList -sender $data
	
	If($children.count -eq 0) { return }

	$mBreadCrumb = $dsWindow.FindName("wrpIEC61355")
	$cmb = New-Object System.Windows.Controls.ComboBox
	$cmb.Name = "cmbIEC61355BreadCrumb_" + $mBreadCrumb.Children.Count.ToString();
	$cmb.DisplayMemberPath = "Name";
	$cmb.ToolTip = "Select Next Class Level"
	$cmb.ItemsSource = @($children)	
	$cmb.BorderThickness = "1,1,1,1"
	$cmb.Margin = "1,0,0,1"
	$cmb.HorizontalContentAlignment = "Center"
	$cmb.MinWidth = 140
	$cmb.IsDropDownOpen = $true
	
	$mBreadCrumb.RegisterName($cmb.Name, $cmb) #register the name to activate later via indexed name
	$mBreadCrumb.Children.Add($cmb)
	$_i = $mBreadCrumb.Children.Count
	$dsDiag.Trace("Added BreadCrumb Level: $($_i)")

	$cmb.add_SelectionChanged({
			param($sender,$e)
			$dsDiag.Trace("next. SelectionChanged, Sender = $sender")
			mIEC61355ComboSelectionChanged -sender $sender
		});

	
} #addIEC61355ComboChild

function mIEC61355ComboSelectionChanged ($sender) {
	$mBreadCrumb = $dsWindow.FindName("wrpIEC61355")
	$position = [int]::Parse($sender.Name.Split('_')[1]);
	$children = $mBreadCrumb.Children.Count - 1
	#$dsDiag.Trace("Position = $($position), Children = $($children)")
	while($children -gt $position )
	{
		$cmb = $mBreadCrumb.Children[$children]
		$mBreadCrumb.UnregisterName($cmb.Name) #unregister the name to correct for later addition/registration
		$mBreadCrumb.Children.Remove($mBreadCrumb.Children[$children]);
		$children--;
	}

	#write the highest level Custent Id to a text file for post-close event
		$value = $mBreadCrumb.Children[$children].SelectedItem.Name
		$value | Out-File "$($env:appdata)\Autodesk\DataStandard 2022\mIEC61355Id_$($children).txt"

	#don't continue adding children according the classification group level
	if($position -lt 3)
	{
		mAddIEC61355ComboChild -sender $sender.SelectedItem
	}
	else
	{
		$_data = @()
			
		$mResultAll = mGetIEC61355UsesList($sender)
		$_data += mConvertCustentsToIEC61355Objects $mResultAll
		If($_data)
		{
			$dsWindow.FindName("dataGrdIEC61355Found").ItemsSource = $_data
			$Global:NavigatedOrSearched = "Navigated"
		}
		else
		{
			$dsWindow.FindName("dataGrdIEC61355Found").ItemsSource = $null
		}
	}
}

function mResetIEC61355BrdCrmb
{
    $dsDiag.Trace(">> Reset Filter started...")
	
	$mBreadCrumb = $dsWindow.FindName("wrpIEC61355")
	$mBreadCrumb.Children[1].SelectedIndex = -1
	$dsWindow.FindName("dataGrdIEC61355Found").ItemsSource = $null
	
	#$mWindowName = $dsWindow.Name
 #       switch($mWindowName)
	#	{
	#		"InventorWindow"
	#		{
	#			If ($Prop["_EditMode"].Value -eq $true)
	#			{
	#				try
	#				{
	#					$Global:_Return=[System.Windows.MessageBox]::Show($UIString["ClassTerms_MSG01"], $UIString["ClassTerms_01"], 4)
	#					If($_Return -eq "No") { return }
	#				}
	#				catch
	#				{
	#					$dsDiag.Trace("Error - Reset Terms Classification Filter")
	#				}
	#			}
	#			If (($Prop["_CreateMode"].Value -eq $true) -or ($_Return -eq "Yes"))
	#			{
	#				$mBreadCrumb = $dsWindow.FindName("wrpIEC61355")
	#				$mBreadCrumb.Children[1].SelectedIndex = -1
	#				$dsWindow.FindName("dataGrdIEC61355Found").ItemsSource = $null
	#			}
	#		}
	#		default
	#		{
	#			$mBreadCrumb = $dsWindow.FindName("wrpIEC61355")
	#			$mBreadCrumb.Children[1].SelectedIndex = -1
	#		}
	#	}

	$dsDiag.Trace("...Reset Filter finished <<")
}


function mGetIEC61355List ([String] $_CoName) {
	try {
		$dsDiag.Trace(">> mGetIEC61355List started")
		$srchConds = New-Object autodesk.Connectivity.WebServices.SrchCond[] 1
		$srchCond = New-Object autodesk.Connectivity.WebServices.SrchCond

		$propDefs = $Global:CustentPropDefs
		$propNames = @("CustomEntityName")
		$propDefIds = @{}
		foreach($name in $propNames) {
			$propDef = $propDefs | Where-Object { $_.SysName -eq $name }
			$propDefIds[$propDef.Id] = $propDef.DispName
		}
		$srchCond.PropDefId = $propDef.Id
		$srchCond.SrchOper = 3
		$srchCond.SrchTxt = $_CoName
		$srchCond.PropTyp = [Autodesk.Connectivity.WebServices.PropertySearchType]::SingleProperty
		$srchCond.SrchRule = [Autodesk.Connectivity.WebServices.SearchRuleType]::Must
		$srchConds[0] = $srchCond
		$srchSort = New-Object autodesk.Connectivity.WebServices.SrchSort
		$searchStatus = New-Object autodesk.Connectivity.WebServices.SrchStatus
		$bookmark = ""
		$_CustomEnts = $vault.CustomEntityService.FindCustomEntitiesBySearchConditions($srchConds,$null,[ref]$bookmark,[ref]$searchStatus)
		$dsDiag.Trace(".. mGetIEC61355List finished - returns $_CustomEnts <<")
		return $_CustomEnts
	}
	catch { 
		$dsDiag.Trace("!! Error in mGetIEC61355List")
	}
}

function mGetIEC61355UsesList ($sender) {
	try {
		$dsDiag.Trace(">> mGetIEC61355UsesList started")
		$mBreadCrumb = $dsWindow.FindName("wrpIEC61355")
		$_i = $mBreadCrumb.Children.Count -1
		$_CurrentCmbName = "cmbBreadCrumb_" + $mBreadCrumb.Children.Count.ToString()
		$_CurrentClsLevel = $mBreadCrumb.Children[$_i].SelectedValue.Name
		#[System.Windows.MessageBox]::Show("Currentclass: $_CurrentClsLevel and Level# is $_i")
        switch($_i -1)
		        {
			        0 { $mSearchFilter = "Segment"} #$UIString["Adsk.QS.ClassLevel_00"]
			        1 { $mSearchFilter = "Main Group"} #$UIString["Adsk.QS.ClassLevel_01"]
			        2 { $mSearchFilter = "Group"} #$UIString["Adsk.QS.ClassLevel_02"]
					3 { $mSearchFilter = "Sub Group"} #$UIString["Adsk.QS.ClassLevel_03"] 
			        default { $mSearchFilter = "*"}
		        }
		$_customObjects = mGetIEC61355List -_CoName $mSearchFilter
		$_Parent = $_customObjects | Where-Object { $_.Name -eq $_CurrentClsLevel }
		try {
			$links = $vault.DocumentService.GetLinksByParentIds(@($_Parent.Id),@("CUSTENT"))
			If($links)
			{
				$linkIds = @()
				$links | ForEach-Object { $linkIds += $_.ToEntId }
				$mLinkedCustObjects = $vault.CustomEntityService.GetCustomEntitiesByIds($linkIds);
				#todo: check that we need to filter the list returned
				$dsDiag.Trace(".. mGetIEC61355UsesList finished - returns $($mLinkedCustObjects.Count) objects<<")
				return $mLinkedCustObjects #$global:_Groups
			}
			Else{ return}
		}
		catch {
			$dsDiag.Trace("!! Error getting links of Parent Co !!")
			return $null
		}
	}
	catch { $dsDiag.Trace("!! Error in mAddCoComboChild !!") }
}


function mGetIEC61355List2 ([String] $CustentCatName, [String] $Standard) 
{
	#the default search condition object type is custom object "Group"
	$srchConds = New-Object autodesk.Connectivity.WebServices.SrchCond[] 2
	$srchConds[0]= mCreateIEC61355SearchCond "Category Name" $CustentCatName "AND"
	$srchConds[1]= mCreateIEC61355SearchCond "Standard" $Standard "AND"

	$srchSort = New-Object autodesk.Connectivity.WebServices.SrchSort
	$searchStatus = New-Object autodesk.Connectivity.WebServices.SrchStatus
	$bookmark = ""
	$mResultAll = New-Object 'System.Collections.Generic.List[Autodesk.Connectivity.WebServices.CustEnt]'

	while(($searchStatus.TotalHits -eq 0) -or ($mResultAll.Count -lt $searchStatus.TotalHits))
	{
		$mResultPage = $vault.CustomEntityService.FindCustomEntitiesBySearchConditions($srchConds,@($srchSort),[ref]$bookmark,[ref]$searchStatus)
		If ($searchStatus.IndxStatus -ne "IndexingComplete" -or $searchStatus -eq "IndexingContent")
		{
			#check the indexing status; you might return a warning that the result bases on an incomplete index, or even return with a stop/error message, that we need to have a complete index first
			$dsWindow.FindName("txtIEC61355StatusMsg").Text = $UIString["Adsk.QS.Classification_12"]
			$dsWindow.FindName("txtIEC61355StatusMsg").Visibility = "Visible"
		}
		If($mResultPage.Count -ne 0)
		{
			$mResultAll.AddRange($mResultPage)
		}
		else 
		{ 
			$dsWindow.FindName("txtIEC61355StatusMsg").Text = "Technical Area: No matching objects found"
			$dsWindow.FindName("txtIEC61355StatusMsg").Visibility = "Visible"
			break;
		}

		#limit the search result to the first result page;
		$dsWindow.FindName("txtIEC61355StatusMsg").Text = "$($CustentCatName) returns more objects than paging size allows."
		$dsWindow.FindName("txtIEC61355StatusMsg").Visibility = "Visible"
		break; #limit the search result to the first result page; page scrolling not implemented in this snippet release
	}
	
	return mConvertCustentsToIEC61355Objects $mResultAll

}

function mGetIEC61355UsesList2 ([String] $CustomObjectId)
{
		$_Parent = ($vault.CustomEntityService.GetCustomEntitiesByIds(@($CustomObjectId)))[0]

		try {
			$links = $vault.DocumentService.GetLinksByParentIds(@($_Parent.Id),@("CUSTENT"))
			If($links)
			{
				$linkIds = @()
				$links | ForEach-Object { $linkIds += $_.ToEntId }
				$mLinkedCustObjects = $vault.CustomEntityService.GetCustomEntitiesByIds($linkIds);
				#todo: check that we need to filter the list returned
				$dsDiag.Trace(".. mGetIEC61355UsesList finished - returns $($mLinkedCustObjects.Count) objects<<")
				#return $mLinkedCustObjects
				return mConvertCustentsToIEC61355Objects $mLinkedCustObjects
			}
			Else{ return}
		}
		catch {
			$dsDiag.Trace("!! Error getting links of Parent Co !!")
			return $null
		}
}

function mConvertCustentsToIEC61355Objects($Custents)
{
		If($Custents.Count -lt 1){
			Return
		}
		Else{
			$dsWindow.FindName("txtIEC61355StatusMsg").Visibility = "Collapsed"
			$mResultAll = $Custents
		}
		
		# 	retrieve all properties of the COs found
		$_data = @()
		#derive data set from result do display; items have system properties like number, title, but others require to query the entity properties
		$mResultItemIds = @()
		$mResultAll | ForEach-Object { $mResultItemIds += $_.Id}
		$mPropDefs = @() #to be consumed by GetProperties
		$mPropDict = @{} #to be leveraged reading property by Name instead of Def.Id
		$mDefId += ($Global:CustentPropDefs | Where-Object { $_.DispName -eq "Name"}).Id
		$mPropDefs += $mDefID
		$mPropDict.Add("Name", $mDefID)
		$mDefId = ($Global:CustentPropDefs | Where-Object { $_.DispName -eq "Code"}).Id
		$mPropDefs += $mDefID
		$mPropDict.Add("Code", $mDefID)
		$mDefId = ($Global:CustentPropDefs | Where-Object { $_.DispName -eq "Comments"}).Id
		$mPropDefs += $mDefID
		$mPropDict.Add("Comments", $mDefID)
		$mDefId = ($Global:CustentPropDefs | Where-Object { $_.DispName -eq "Term DE"}).Id
		$mPropDefs += $mDefID
		$mPropDict.Add("Term DE", $mDefID)
		$mDefId = ($Global:CustentPropDefs | Where-Object { $_.DispName -eq "Comments DE"}).Id
		$mPropDefs += $mDefID
		$mPropDict.Add("Comments DE",$mDefID)

		$mPropInst = $vault.PropertyService.GetProperties("CUSTENT", $mResultItemIds, $mPropDefs)

		#build the table to display items with properties

		foreach($item in $mResultAll)
		{
			$row = New-Object IEC61355Data
			$row.Id = $item.Id
			$row.SubClass = $item.Name
			$row.Code = ($mPropInst | Where-Object { $_.EntityId -eq $item.Id -and $_.PropDefId -eq $mPropDict["Code"]}).Val
			$row.Example = ($mPropInst | Where-Object { $_.EntityId -eq $item.Id -and $_.PropDefId -eq $mPropDict["Comments"]}).Val
			$row.SubClassDE = ($mPropInst | Where-Object { $_.EntityId -eq $item.Id -and $_.PropDefId -eq $mPropDict["Term DE"]}).Val
			$row.ExampleDE = ($mPropInst | Where-Object { $_.EntityId -eq $item.Id -and $_.PropDefId -eq $mPropDict["Comments DE"]}).Val
			$row.PathCode = "[Tree]"
			$_data += $row
		}
		return $_data
}