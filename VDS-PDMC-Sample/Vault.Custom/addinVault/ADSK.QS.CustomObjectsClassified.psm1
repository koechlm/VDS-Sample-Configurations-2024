#region disclaimer
	#===============================================================================
	# PowerShell script sample
	# Author: Markus Koechl
	# Copyright (c) Autodesk 2023
	#
	# THIS SCRIPT/CODE IS PROVIDED "AS IS" WITHOUT WARRANTY OF ANY KIND, EITHER
	# EXPRESSED OR IMPLIED, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED WARRANTIES
	# OF MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE, OR NON-INFRINGEMENT.
	#===============================================================================
#endregion

#region CatalogLookUp
Add-Type @"
public class CatalogData
{
	public string Term_DE {get;set;}
	public string Term_EN {get;set;}	
	public string Term_FR {get;set;}
	public string Term_IT {get;set;}
}
"@

function mInitializeTermCatalog
{
     
	If ($dsWindow.FindName("expTermSearch"))
	{      							
		Try 
		{
			Switch($dsWindow.Name)
			{
				"AutoCADWindow"
				{
					If ($Prop["GEN-TITLE-DES1"]){ $dsWindow.FindName("mSearchTermText").text = $Prop["GEN-TITLE-DES1"].Value}
					If ($Prop["Title"]){ $dsWindow.FindName("mSearchTermText").text = $Prop["Title"].Value}
				}
				"InventorWindow"
				{
					$dsWindow.FindName("mSearchTermText").Text = $Prop["Title"].Value
				}
				default #applies to all Vault windows
				{
					$dsWindow.FindName("mSearchTermText").Text = $Prop["_XLTN_TITLE"].Value
				}
			}
			
			
			If($mTermCatalogInitialized -ne $true)
			{
				If(-not $UIString["ADSK.QS.ClassLevel_00"]) { $UIString = mGetUIStrings } #the psm library might not get the VDS default variable
				mAddCoCombo -_CoName "Segment" #enables classification filter for catalog of terms starting with segment

				$dsWindow.FindName("dataGrdTermsFound").add_SelectionChanged({
					param($sender, $SelectionChangedEventArgs)
					#$dsDiag.Trace(".. TermsFoundSelection")
					IF($dsWindow.FindName("dataGrdTermsFound").SelectedItem){
						$dsWindow.FindName("btnAdopt").IsEnabled = $true
						$dsWindow.FindName("btnAdopt").IsDefault = $true
					}
					Else {
						$dsWindow.FindName("btnAdopt").IsEnabled = $false
						$dsWindow.FindName("btnSearchTerm").IsDefault = $true
					}
				})

				#close the expander as another property is selected 
					$dsWindow.FindName("DSDynamicCategoryProperties").add_GotFocus({
					$dsWindow.FindName("expTermSearch").Visibility = "Collapsed"
					$dsWindow.FindName("expTermSearch").IsExpanded = $false
					$dsWindow.FindName("btnSearchTerm").IsDefault = $false
				})

				$Global:mTermCatalogInitialized = $true
			}
			
			$dsWindow.FindName("expTermSearch").Visibility = "Visible"
			$dsWindow.FindName("expTermSearch").IsExpanded = $true
			$dsWindow.FindName("btnSearchTerm").IsDefault = $true

		}	
		catch { 
			#$dsDiag.Trace("The expander TermCatalog is not present. Contact your VDS administrator.")
			$mErrorMsg = "The expander TermCatalog is not present or couldn't initialize. Contact your VDS administrator."
			[Autodesk.DataManagement.Client.Framework.Forms.Library]::ShowError($mErrorMsg, "VDS Sample Configuration")
		}
	}#if Term Catalog Expander exists
}

function mSearchTerms 
{
	Try {
		#$dsDiag.Trace(">> search COs terms")
		$dsWindow.FindName("dataGrdTermsFound").ItemsSource = $null

		$mSearchText1 = $dsWindow.FindName("mSearchTermText").Text
		If(!$mSearchText1) { $mSearchText1 = "*"}

		# the search conditions depend on the filters set (4 groups, 4 languages; the number has to match
		$_NumConds = 2 #we have one condition as minimum, as we search for custom entities of category "term" 		
		$mBreadCrumb = $dsWindow.FindName("wrpClassification")
		$_t1 = $mBreadCrumb.Children[1].SelectedIndex
		If ($mBreadCrumb.Children[1].SelectedIndex -ge 0) { $_NumConds +=1}
		If ($mBreadCrumb.Children[2].SelectedIndex -ge 0) { $_NumConds +=1}
		If ($mBreadCrumb.Children[3].SelectedIndex -ge 0) { $_NumConds +=1}
		If ($mBreadCrumb.Children[4].SelectedIndex -ge 0) { $_NumConds +=1}

		# check the language columns/properties to search in
		If ($dsWindow.FindName("chkDE").IsChecked -eq $true) { $_NumConds +=1} #default = not checked
		If ($dsWindow.FindName("chkEN").IsChecked -eq $true) { $_NumConds +=1}

		If ($dsWindow.FindName("chkFR").IsChecked -eq $true) { $_NumConds +=1}
		If ($dsWindow.FindName("chkIT").IsChecked -eq $true) { $_NumConds +=1}

		# add all selected languages to search in; apply OR conditions
		$srchConds = New-Object autodesk.Connectivity.WebServices.SrchCond[] $_NumConds
		$_i = 0

		#the default search condition object type is custom object "term"
		$srchConds[$_i]= mCreateClsSearchCond "Category Name" "Term" "AND" #Search in "Category Name" $UIString["ClassTerms_08"] = "Term" $UIString["ClassTerms_00"]
		$_i += 1
		if($_NumConds -gt 2){
			$srchConds[$_i]= mCreateClsSearchCond "Name" $mSearchText1 "OR" #Search in Names = main language $UIString["LBL19"]
			$_i += 1
		}
		Else
		{
			$srchConds[$_i]= mCreateClsSearchCond "Name" $mSearchText1 "AND" #Search in Names = main language $UIString["LBL19"]
			$_i += 1
		}
		
		#add other conditions by settings read from dialog
		If ($dsWindow.FindName("chkDE").IsChecked -eq $true) {
			$srchConds[$_i ]= mCreateClsSearchCond "Term DE" $mSearchText1 "OR" #$UIString["ClassTerms_09"]
			$_i += 1
		}
		If ($dsWindow.FindName("chkEN").IsChecked -eq $true) {
			$srchConds[$_i]= mCreateClsSearchCond "Term EN" $mSearchText1 "OR"  #$UIString["ClassTerms_10"]
			$_i += 1
		}
		If ($dsWindow.FindName("chkFR").IsChecked -eq $true) {
			$srchConds[$_i]= mCreateClsSearchCond "Term FR" $mSearchText1 "OR"  #$UIString["ClassTerms_11"]
			$_i += 1
		}
		If ($dsWindow.FindName("chkIT").IsChecked -eq $true) {
			$srchConds[$_i]= mCreateClsSearchCond "Term IT" $mSearchText1 "OR"  #$UIString["ClassTerms_12"]
			$_i += 1
		}

		# If filters are used limit the search to the classification groups. Apply AND conditions
		If ($mBreadCrumb.Children[1].SelectedIndex -ge 0) {
			$mSearchGroupName = $mBreadCrumb.Children[1].Text
			$srchConds[$_i]= mCreateClsSearchCond "Segment" $mSearchGroupName "AND" #search in Segment class $UIString["Adsk.QS.ClassLevel_00"]
			$_i += 1
		}
				If ($mBreadCrumb.Children[2].SelectedIndex -ge 0) {
			$mSearchGroupName = $mBreadCrumb.Children[2].Text
			$srchConds[$_i]= mCreateClsSearchCond "Main Group" $mSearchGroupName "AND" #$UIString["Adsk.QS.ClassLevel_01"]
			$_i += 1
		}
		If ($mBreadCrumb.Children[3].SelectedIndex -ge 0) {
			$mSearchGroupName = $mBreadCrumb.Children[3].Text
			$srchConds[$_i]= mCreateClsSearchCond "Group" $mSearchGroupName "AND" #$UIString["Adsk.QS.ClassLevel_02"]
			$_i += 1
		}
		If ($mBreadCrumb.Children[4].SelectedIndex -ge 0) {
			$mSearchGroupName = $mBreadCrumb.Children[4].Text
			$srchConds[$_i]= mCreateClsSearchCond "Sub Group" $mSearchGroupName "AND" #$UIString["Adsk.QS.ClassLevel_03"]
			$_i += 1
		}
		$dsDiag.Trace(" search conditions build")

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
				$dsWindow.FindName("txtTermStatusMsg").Text = $UIString["Adsk.QS.Classification_12"]
				$dsWindow.FindName("txtTermStatusMsg").Visibility = "Visible"
			}
			If($mResultPage.Count -ne 0)
			{
				$mResultAll.AddRange($mResultPage)
			}
			else 
			{ 
				$dsWindow.FindName("txtTermStatusMsg").Text = $UIString["ClassTerms_MSG03"]
				$dsWindow.FindName("txtTermStatusMsg").Visibility = "Visible"
				break;
			}

			#limit the search result to the first result page;
			$dsWindow.FindName("txtTermStatusMsg").Text = $UIString["ClassTerms_MSG02"]
			$dsWindow.FindName("txtTermStatusMsg").Visibility = "Visible"
			break; #limit the search result to the first result page; page scrolling not implemented in this snippet release
		}

		$global:_SearchResult = $mResultAll	
		If($_SearchResult.Count -lt 1){		
			Return
		}
		Else{
			$dsWindow.FindName("txtTermStatusMsg").Visibility = "Collapsed"
		}
			# 	retrieve all properties of the COs found
		$_data = @()
	
		$propDefs = $vault.PropertyService.GetPropertyDefinitionsByEntityClassId("CUSTENT")
		$_SearchResult | ForEach-Object{
			$dsDiag.Trace(" ---iterates search result for properties...")
			$properties = $vault.PropertyService.GetPropertiesByEntityIds("CUSTENT",$_.Id) #Properties attached to the CO
			$props = @{}

			foreach ($property in $properties) {
				$dsDiag.Trace("Iiterates properties to get DefIDs...")

				Try {
					$propDef = $propDefs | Where-Object { $_.Id -eq $property.PropDefId }
					$props[$propDef.DispName] = $property.Val
				} 
				catch { $dsDiag.Trace("ERROR ---iterates search result for properties failed !! ---") }
			}

			$dsDiag.Trace(" ---iterates search result for properties finished") 
			#create a row for the element and it's properties
			$row = New-Object CatalogData
			$row.Term_DE = $props["Term DE"]  #$UIString["ClassTerms_09"]
			$row.Term_EN = $props["Term EN"]  #$UIString["ClassTerms_10"]
			$row.Term_FR = $props["Term FR"]  #$UIString["ClassTerms_11"]
			$row.Term_IT = $props["Term IT"]  #$UIString["ClassTerms_12"]
		
			$_data += $row
			$dsDiag.Trace("...iterates search result for properties finished.") 
		}
		$dsWindow.FindName("dataGrdTermsFound").ItemsSource = $_data 
	}
	catch {
		$dsDiag.Trace("ERROR --- in m_SearchTerms function") 
	}

}

function mCreateClsSearchCond ([String] $PropName, [String] $mSearchTxt, [String] $AndOr) {
	$dsDiag.Trace("--SearchCond creation starts... for $PropName and $mSearchTxt ---")
	$srchCond = New-Object autodesk.Connectivity.WebServices.SrchCond
	$propDefs = $vault.PropertyService.GetPropertyDefinitionsByEntityClassId("CUSTENT")
	$propNames = @($PropName) #$UIString["LBL6"]
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

function m_SelectTerm {
	$dsDiag.Trace("Term_DE selected to get value written to Title field")
	try 
	{		
		$mSelectedItem = $dsWindow.FindName("dataGrdTermsFound").SelectedItem

		If ($dsWindow.Name -eq "AutoCADWindow")
		{
			# check language override settings of VDS
			$mLCode = @{}
			$mLCode += mGetDBOverride
			#If override exists, apply it, else continue with $PSUICulture
			If ($mLCode["UI"] -eq "de-DE")
			{
				If ($Prop["GEN-TITLE-DES1"]){ $Prop["GEN-TITLE-DES1"].Value = $mSelectedItem.Term_DE} #AutoCAD Mechanical Title Attribute Name
				If ($Prop["Title"]){ $Prop["Title"].Value = $mSelectedItem.Term_EN} #Vanilla AutoCAD Title Attribute Name
				Try{
					$Prop["Title DE"].Value = $mSelectedItem.Term_DE
				}
				catch{ $dsDiag.Trace("Titel DE does not exist")}
			}
			Else{
				If ($Prop["GEN-TITLE-DES1"]){ $Prop["GEN-TITLE-DES1"].Value = $mSelectedItem.Term_EN} #AutoCAD Mechanical Title Attribute Name
				If ($Prop["Title"]){ $Prop["Title"].Value = $mSelectedItem.Term_EN} #Vanilla AutoCAD Title Attribute Name
				Try{
					$Prop["Title DE"].Value = $mSelectedItem.Term_DE
				}
				catch{ $dsDiag.Trace("Title DE does not exist")}
			}
				Try{
					$Prop["Title FR"].Value = $mSelectedItem.Term_FR
				}
				catch{ $dsDiag.Trace("Title FR does not exist")}
				
				Try{
					$Prop["Title IT"].Value = $mSelectedItem.Term_IT
				}
				catch{ $dsDiag.Trace("Title IT does not exist")}
				
		}
		If ($dsWindow.Name -eq "InventorWindow")
		{
			#region tab-rendering 
			# the tab is rendered with each activation and would re-read sources or require again user input in controls; property values are in runspace memory
			# note - using the tabTerms in different windows (xaml) might require to add a switch node here
			$_temp1 = $dsWindow.FindName("Categories").SelectedIndex
			#endregion

			# check language override settings of VDS
			$mLCode = @{}
			$mLCode += mGetDBOverride
			#If override exists, apply it, else continue with $PSUICulture
			If ($mLCode["UI"] -eq "de-DE")
			{
				$Prop["Title"].Value = $mSelectedItem.Term_EN
				Try{
					$Prop["Title DE"].Value = $mSelectedItem.Term_DE
				}
				catch{ $dsDiag.Trace("Title DE does not exist")}
			} 
			Else
			{
				$Prop["Title"].Value = $mSelectedItem.Term_EN
				Try{
					$Prop["Title DE"].Value = $mSelectedItem.Term_DE
				}
				catch{ $dsDiag.Trace("Title DE does not exist")}
			}	
			Try{
				$Prop["Title FR"].Value = $mSelectedItem.Term_FR
			}
			catch{ $dsDiag.Trace("Title FR does not exist")}
		
			Try{
				$Prop["Title IT"].Value = $mSelectedItem.Term_IT
			}
			catch{ $dsDiag.Trace("Title IT does not exist")}
			
		}
		If ($dsWindow.Name -eq "FileWindow") {
			
			#region tab-rendering 
			# the tab is rendered with each activation and would re-read sources or require again user input in controls; property values are in runspace memory
			# note - using the tabTerms in different windows (xaml) might require to add a switch node here
			$_temp10 = $dsWindow.FindName("DocTypeCombo").SelectedIndex
			$_temp40 = $dsWindow.FindName("NumSchms").IsEnabled
			$_temp41 = $dsWindow.FindName("btnOK").IsEnabled
			#endregion

			$Prop["_XLTN_TITLE"].Value = $mSelectedItem.Term_EN
			Try {
				$Prop["_XLTN_TITLE-DE"].Value = $mSelectedItem.Term_DE
			}
			catch { $dsDiag.Trace("Title DE does not exist")}
			Try {
				$Prop["_XLTN_TITLE-EN"].Value = $mSelectedItem.Term_EN
			}
			catch { $dsDiag.Trace("Title EN does not exist")}
			Try {
				$Prop["_XLTN_TITLE-FR"].Value = $mSelectedItem.Term_FR
			}
			catch { $dsDiag.Trace("Title FR does not exist")}
			Try {
				$Prop["_XLTN_TITLE-IT"].Value = $mSelectedItem.Term_IT
			}
			catch { $dsDiag.Trace("Title IT does not exist")}
		}

		$dsWindow.FindName("btnSearchTerm").IsDefault = $false
		$dsWindow.FindName("btnOK").IsDefault = $true

		#region tab-rendering restore
			If ($_temp1) {	$dsWindow.FindName("Categories").SelectedIndex = $_temp1}
			If ($_temp10) { $dsWindow.FindName("DocTypeCombo").SelectedIndex = $_temp10}
			If ($_temp40) { $dsWindow.FindName("NumSchms").IsEnabled = $_temp40}
			If ($_temp41) { $dsWindow.FindName("btnOK") = $_temp41} 
		#endregion
	}
	Catch 
	{
		$dsDiag.Trace("Error writing term.value(s) to property field")
	}
	
	$dsWindow.FindName("tabProperties").IsSelected = $true
}

#endregion CatalogLookUp

#region BreadCrumb ClassSelection
function mAddCoCombo ([String] $_CoName, $_classes) 
{	
	$children = mgetCustomEntityList -_CoName $_CoName
	If($children -eq $null) { return }
	
	$mBreadCrumb = $dsWindow.FindName("wrpClassification")
	$cmb = New-Object System.Windows.Controls.ComboBox
	$cmb.Name = "cmbClassBreadCrumb_" + $mBreadCrumb.Children.Count.ToString();
	$cmb.DisplayMemberPath = "Name";
	$cmb.Tooltip = $UIString["ClassTerms_TT01"] #"Suche auf Hierarchieebene begrenzen..."
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
		default
		{
			$cmb.IsDropDownOpen = $false
		}
	}
	$cmb.add_SelectionChanged({
			param($sender,$e)
			$dsDiag.Trace("1. SelectionChanged, Sender = $sender, $e")
			mCoComboSelectionChanged -sender $sender
		});
	$mBreadCrumb.RegisterName($cmb.Name, $cmb) #register the name to activate later via indexed name
	$mBreadCrumb.Children.Add($cmb);

	#region EditMode CustomObjectTerm or CustomObjectClass Window
	If ($dsWindow.Name-eq "CustomObjectClassifiedWindow")
	{
		If ($Prop["_EditMode"].Value -eq $true)
		{
			$_cmbNames = @()
			Foreach ($_cmbItem in $cmb.Items) 
			{
				$dsDiag.Trace("---$_cmbItem---")
				$_cmbNames += $_cmbItem.Name
			}
			$dsDiag.Trace("Combo $index Namelist = $_cmbNames")
			If ($_classes[0]) #avoid activation of null ;)
			{
				$_CurrentName = $_classes[0]
				#$dsDiag.Trace("Current Name: $_CurrentName ")
				#get the index of name in array
				$i = 0
				Foreach ($_Name in $_cmbNames) 
				{
					$_1 = $_cmbNames.count
					$_2 = $_cmbNames[$i]
					#$dsDiag.Trace(" Counter: $i von $_1 Value: $_2  and CurrentName: $_CurrentName ")
					If ($_cmbNames[$i] -eq $_CurrentName) 
					{
						$_IndexToActivate = $i
					}
					$i +=1
				}
				#$dsDiag.Trace("Index of current name: $_IndexToActivate ")
				$cmb.SelectedIndex = $_IndexToActivate			
			} #end If classes[0]
			
		}
	}
	#endregion
} # addCoCombo

function mAddCoComboChild ($data) 
{
	$children = @()
	$children = mGetCustomEntityUsesList -sender $data
	$dsDiag.Trace("check data object: $children")
		
	#Filter classification levels and classes
	if(-not $Global:mClassLevelCustentDefIds)
	{
		$Global:mAllCustentPropDefs = $vault.PropertyService.GetPropertyDefinitionsByEntityClassId("CUSTENT")
		$Global:mCustentUdpDefs = $Global:mAllCustentPropDefs | Where-Object { $_.IsSys -eq $false}
		$Global:mCustentDefs = $vault.CustomEntityService.GetAllCustomEntityDefinitions()
		#configuration info - the custom object names used for the classification structure may vary. Align Custent names of your Vault in UIStrings ADSK.WS.ClassLEver_*
		$mClsLevelNames = ("Segment", "Main Group", "Group","Sub Group")
		$Global:mClassLevelCustentDefIds = ($Global:mCustentDefs | Where-Object { $_.DispName -in $mClsLevelNames}).Id
	}

	$mClassLevelObjects = @() #filtered list for the 4 levels
	$mClassLevelObjects += $children | Where-Object {$_.CustEntDefId -in $Global:mClassLevelCustentDefIds}
	$children = $mClassLevelObjects
	
	If($children.count -eq 0) { return }

	$mBreadCrumb = $dsWindow.FindName("wrpClassification")
	$cmb = New-Object System.Windows.Controls.ComboBox
	$cmb.Name = "cmbClassBreadCrumb_" + $mBreadCrumb.Children.Count.ToString();
	$cmb.DisplayMemberPath = "Name";
	$cmb.ItemsSource = @($children)	
	$cmb.BorderThickness = "1,1,1,1"
	$cmb.Margin = "1,0,0,1"
	$cmb.HorizontalContentAlignment = "Center"
	$cmb.MinWidth = 140
	$mWindowName = $dsWindow.Name
		switch($mWindowName)
		{
			"CustomObjectClassifiedWindow"
			{
				If (($Prop["_CreateMode"].Value -eq $true) -or ($_Return -eq "Yes")) {$cmb.IsDropDownOpen = $true}
			}
			default
			{
				$cmb.IsDropDownOpen = $true
			}
		}
	$cmb.add_SelectionChanged({
			param($sender,$e)
			$dsDiag.Trace("next. SelectionChanged, Sender = $sender")
			mCoComboSelectionChanged -sender $sender
		});
	$mBreadCrumb.RegisterName($cmb.Name, $cmb) #register the name to activate later via indexed name
	$mBreadCrumb.Children.Add($cmb)
	$_i = $mBreadCrumb.Children.Count
	$_Label = "lblGroup_" + $_i
	$dsDiag.Trace("Label to display: $_Label - but not longer used")
	# 	$dsWindow.FindName("$_Label").Visibility = "Visible"
	
	#region EditMode for CustomObjectTerm or CustomObjectClassWindow
	If ($dsWindow.Name-eq "CustomObjectClassifiedWindow")
	{
		If ($Prop["_EditMode"].Value -eq $true)
		{
			Try
			{
				$_cmbNames = @()
				Foreach ($_cmbItem in $cmb.Items) 
				{
					$dsDiag.Trace("---$_cmbItem---")
					$_cmbNames += $_cmbItem.Name
				}
				$dsDiag.Trace("Combo $index Namelist = $_cmbNames")
				#get the index of name in array
				If ($_classes[$_i-2]) #avoid activation of null ;)
				{
					$_CurrentName = $_classes[$_i-2] #remember the number of breadcrumb children is +2 (delete button, and the class start with index 0)
					$dsDiag.Trace("Current Name: $_CurrentName ")
					$i = 0
					Foreach ($_Name in $_cmbNames) 
					{
						$_1 = $_cmbNames.count
						$_2 = $_cmbNames[$i]
						$dsDiag.Trace(" Counter: $i von $_1 Value: $_2  and CurrentName: $_CurrentName ")
						If ($_cmbNames[$i] -eq $_CurrentName) 
						{
							$_IndexToActivate = $i
						}
						$i +=1
					}
					$dsDiag.Trace("Index of current name: $_IndexToActivate ")
					$cmb.SelectedIndex = $_IndexToActivate
				} #end
							
			} #end try
		catch 
		{
			$dsDiag.Trace("Error activating an existing index in edit mode.")
		}
	}
	}
	#endregion
} #addCoComboChild

function mgetCustomEntityList ([String] $_CoName) {
	try {
		$dsDiag.Trace(">> mgetCustomEntityList started")
		$srchConds = New-Object autodesk.Connectivity.WebServices.SrchCond[] 1
		$srchCond = New-Object autodesk.Connectivity.WebServices.SrchCond
		$propDefs = $vault.PropertyService.GetPropertyDefinitionsByEntityClassId("CUSTENT")
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
		$dsDiag.Trace(".. mgetCustomEntityList finished - returns $_CustomEnts <<")
		return $_CustomEnts
	}
	catch { 
		$dsDiag.Trace("!! Error in mgetCustomEntityList")
	}
}

function mGetCustomEntityUsesList ($sender) {
	try {
		$dsDiag.Trace(">> mGetCustomEntityUsesList started")
		$mBreadCrumb = $dsWindow.FindName("wrpClassification")
		$_i = $mBreadCrumb.Children.Count -1
		$_CurrentCmbName = "cmbBreadCrumb_" + $mBreadCrumb.Children.Count.ToString()
		$_CurrentClass = $mBreadCrumb.Children[$_i].SelectedValue.Name
		#[System.Windows.MessageBox]::Show("Currentclass: $_CurrentClass and Level# is $_i")
        switch($_i-1)
		        {
			        0 { $mSearchFilter = "Segment"} #$UIString["Adsk.QS.ClassLevel_00"]
			        1 { $mSearchFilter = "Main Group"} #$UIString["Adsk.QS.ClassLevel_01"]
			        2 { $mSearchFilter = "Group"} #$UIString["Adsk.QS.ClassLevel_02"]
					3 { $mSearchFilter = "Sub Group"} #$UIString["Adsk.QS.ClassLevel_03"] 
			        default { $mSearchFilter = "*"}
		        }
		$_customObjects = mgetCustomEntityList -_CoName $mSearchFilter
		$_Parent = $_customObjects | Where-Object { $_.Name -eq $_CurrentClass }
		try {
			$links = $vault.DocumentService.GetLinksByParentIds(@($_Parent.Id),@("CUSTENT"))
			If($links)
			{
				$linkIds = @()
				$links | ForEach-Object { $linkIds += $_.ToEntId }
				$mLinkedCustObjects = $vault.CustomEntityService.GetCustomEntitiesByIds($linkIds);
				#todo: check that we need to filter the list returned
				$dsDiag.Trace(".. mgetCustomEntityUsesList finished - returns $mLinkedCustObjects <<")
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

function mCoComboSelectionChanged ($sender) {
	$mBreadCrumb = $dsWindow.FindName("wrpClassification")
	$position = [int]::Parse($sender.Name.Split('_')[1]);
	$children = $mBreadCrumb.Children.Count - 1
	while($children -gt $position )
	{
		$cmb = $mBreadCrumb.Children[$children]
		$mBreadCrumb.UnregisterName($cmb.Name) #unregister the name to correct for later addition/registration
		$mBreadCrumb.Children.Remove($mBreadCrumb.Children[$children]);
		$children--;
	}
	Try{
		if ($mBreadCrumb.Children[1]) { $Prop["Segment"].Value = $mBreadCrumb.Children[1].SelectedItem.Name }
		if ($mBreadCrumb.Children[2]) { $Prop["Main Group"].Value = $mBreadCrumb.Children[2].SelectedItem.Name }
		else { $Prop["Main Group"].Value = "" }
		if ($mBreadCrumb.Children[3]) { $Prop["Group"].Value = $mBreadCrumb.Children[3].SelectedItem.Name }
		else { $Prop["Group"].Value = "" }
		if ($mBreadCrumb.Children[4]) { $Prop["Sub Group"].Value = $mBreadCrumb.Children[4].SelectedItem.Name }
		else { $Prop["Sub Group"].Value = "" }

		#write the highest level Custent Id to a text file for post-close event
		$value = $mBreadCrumb.Children[$children].SelectedItem.Id
		$value | Out-File $env:TEMP"\mParentId.txt"

	}
	catch{}
	$dsDiag.Trace("---combo selection = $_selected, Position $position")

	#don't continue adding children according the classification group level
	switch($Prop["_Category"].Value)
	{
		"Main Group"
		{
			$dsDiag.Trace("Main group is the object's level; don't add a child. Position $($position)")
			return
		}
		
		"Group"
		{
			if($position -eq 2)
			{
				return
			}
			else
			{
				mAddCoComboChild -sender $sender.SelectedItem
			}
		}
		
		"Sub Group"
		{
			if($position -eq 3)
			{
				return
			}
			else
			{
				mAddCoComboChild -sender $sender.SelectedItem
			}
		}
		default
		{
			mAddCoComboChild -sender $sender.SelectedItem
		}
	}
}

function mResetClassFilter
{
    $dsDiag.Trace(">> Reset Filter started...")
	$mWindowName = $dsWindow.Name
        switch($mWindowName)
		{
			"CustomObjectClassifiedWindow"
			{
				If ($Prop["_EditMode"].Value -eq $true)
				{
					try
					{
						$Global:_Return = [Autodesk.DataManagement.Client.Framework.Forms.Library]::ShowWarning($UIString["ClassTerms_MSG01"], $UIString["ClassTerms_01"], "YesNo")
						If($_Return -eq "No") { return }
					}
					catch
					{
						$dsDiag.Trace("Error - Reset Terms Classification Filter")
					}
			}
				If (($Prop["_CreateMode"].Value -eq $true) -or ($_Return -eq "Yes"))
				{
					$mBreadCrumb = $dsWindow.FindName("wrpClassification")
					$mBreadCrumb.Children[1].SelectedIndex = -1
				}
			}
			default
			{
				$mBreadCrumb = $dsWindow.FindName("wrpClassification")
				$mBreadCrumb.Children[1].SelectedIndex = -1
			}
		}

	$dsDiag.Trace("...Reset Filter finished <<")
}
#endregion BreadCrumb ClassSelection
