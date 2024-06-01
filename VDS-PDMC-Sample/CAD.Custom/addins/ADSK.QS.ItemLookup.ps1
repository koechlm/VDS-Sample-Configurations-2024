# DISCLAIMER:
# ---------------------------------
# In any case, code, templates, and snippets of this solution are of "work in progress" character.
# Neither Markus Koechl, nor Autodesk represents that these samples are reliable, accurate, complete, or otherwise valid. 
# Accordingly, those configuration samples are provided as is with no warranty of any kind, and you use the applications at your own risk.


Add-Type @"
public class itemData
{
	public string Item {get;set;}
	public string Revision {get;set;}
	public string Title {get;set;}
	public string Material {get;set;}
	public string Category {get;set;}
	public string Description {get;set;}
	public string StockNumber {get;set;}
}
"@

function mInitializeItemSearch([STRING] $Context) {
	if ($Prop["_Category"].Value -eq $UIString["Adsk.QS.ItemSearch_14"]) {
		$Context = "Purchased"
	}
	$Global:mPropContext = $Context #used to determine the target fields copying item meta data
	
	If ($Context -eq "Part_Number") { $mCopyTarget = " to " + $UIString["LBL16"] + " / " + $UIString["LBL2"] + " / " + $UIString["LBL3"] }
	If ($Context -eq "Stock_Number") { $mCopyTarget = " to " + $UIString["LBL76"] + " / " + $UIString["LBL75"]	}
	If ($Context -eq "Purchased") { $mCopyTarget = " to " + $UIString["LBL2"] + " / " + $UIString["LBL3"] + " / " + $UIString["LBL76"] }

	$dsWindow.FindName("lblBtnItemDataCopy").Content = $UIString["Adsk.QS.ItemSearch_11"] + $mCopyTarget
	
	#reset data only on demand
	if (-not $dsWindow.FindName("ItemsFound").ItemsSource) {
		$dsWindow.FindName("lblItemMaster").Text = $UIString["Adsk.QS.ItemSearch_00"]
		$dsWindow.FindName("btnItemSearch").IsDefault = $true
		$dsWindow.FindName("btnOK").IsDefault = $false
	}
	else {
		$dsWindow.FindName("lblItemMaster").Text = $UIString["Adsk.QS.ItemSearch_06"]
	}

	#reset data 
	mItemSearchClear
	
	$dsWindow.FindName("txtItemSearchResultMsg").Visibility = "Collapsed"
	$dsWindow.FindName("expItemMasterSearch").Visibility = "Visible"
	$dsWindow.FindName("expItemMasterSearch").IsExpanded = $true



	#close the expander as another property is selected 
	$dsWindow.FindName("DSDynCatPropGrid").add_GotFocus({
			$dsWindow.FindName("expItemMasterSearch").Visibility = "Collapsed"
			$dsWindow.FindName("btnItemSearch").IsDefault = $false
		})

	#avoid repetitive server calls; we'll need the item property definitions several times
	If (-not $Global:mAllItemPropDefs) { $Global:mAllItemPropDefs = $vault.PropertyService.GetPropertyDefinitionsByEntityClassId("ITEM") }
	if (-not $Global:mMaterials) { $Global:mMaterials = mGetItemMaterials }
	if (-not $Global:mItemCategories) { $Global:mItemCategories = mGetItemCategories }

	#pre-set values for category according component type and/or context
	switch ($Context) {
		"Part_Number" {
			#set the item's category to align to CAD component for part and assembly only
			if ($Prop["_Category"].Value -eq $UIString["MSDCE_CAT08"] -or $Prop["_Category"].Value -eq $UIString["MSDCE_CAT10"]) {
				$dsWindow.FindName("cmbItemSearchCategory").Text = $Prop["_Category"].Value 
			}
		}
		"Purchased" {
			#set the item's category to align to CAD component for part and assembly only
			if ($Prop["_Category"].Value -eq $UIString["Adsk.QS.ItemSearch_14"] -or $Prop["_Category"].Value -eq $UIString["Adsk.QS.ItemSearch_14"]) {
				$dsWindow.FindName("cmbItemSearchCategory").Text = $Prop["_Category"].Value 
			}
		}
		"Stock_Number" {
			If (($Global:mItemCategories | Where-Object { $_ -eq $UIString["Adsk.QS.ItemSearch_13"] })) {
				$dsWindow.FindName("cmbItemSearchCategory").Text = $UIString["Adsk.QS.ItemSearch_13"]
			}
			Else {
				$dsWindow.FindName("cmbItemSearchCategory").Text = $UIString["Adsk.QS.ItemSearch_14"] #set the item's category to align to parts
			}
		}
	}

	#fill item material selection
	$dsWindow.FindName("cmbItemSearchMaterial").ItemsSource = $Global:mMaterials
}

function mItemSearchClear {
	#reset search results
	$dsWindow.FindName("lblItemMaster").Text = $UIString["Adsk.QS.ItemSearch_00"]
	$dsWindow.FindName("ItemsFound").ItemsSource = $null
	$dsWindow.FindName("btnItemDataCopy").IsEnabled = $false
	$dsWindow.FindName("ItemsFound").remove_GotFocus({})
	$dsWindow.FindName("txtItemSearchResultMsg").Text = ""
	$dsWindow.FindName("txtItemSearchResultMsg").Visibility = "Collapsed"
	$dsWindow.FindName("btnItemSearch").IsDefault = $true
	$dsWindow.FindName("btnOK").IsDefault = $false
	#reset search criteria
	$dsWindow.FindName("txtItemSearchMultipleProp").Text = ""
	$dsWindow.FindName("txtItemSearchNumber").Text = ""
	$dsWindow.FindName("txtItemSearchTitle").Text = ""
	$dsWindow.FindName("txtItemSearchDescription").Text = ""
	$dsWindow.FindName("cmbItemSearchCategory").Text = ""
	$dsWindow.FindName("cmbItemSearchMaterial").Text = ""
}

function mGetItemsBySearchCriterias() {
	Try {
		#reset existing results and message(s)
		$dsWindow.FindName("ItemsFound").ItemsSource = $null
		$dsWindow.FindName("txtItemSearchResultMsg").Text = ""
		$dsWindow.FindName("txtItemSearchResultMsg").Visibility = "Collapsed"

		$dsWindow.Cursor = "Wait" #search might take some time...

		#collect any possible inputs
		$mSrchCndDic = @{}
		If ($dsWindow.FindName("txtItemSearchMultipleProp").Text) { $mSrchCndDic.Add("MultipleProperties", $dsWindow.FindName("txtItemSearchMultipleProp").Text) }
		If ($dsWindow.FindName("txtItemSearchNumber").Text) { $mSrchCndDic.Add($UIString["Adsk.QS.ItemSearch_04"], $dsWindow.FindName("txtItemSearchNumber").Text) }
		If ($dsWindow.FindName("txtItemSearchTitle").Text) { $mSrchCndDic.Add($UIString["Adsk.QS.ItemSearch_02"], $dsWindow.FindName("txtItemSearchTitle").Text) }
		If ($dsWindow.FindName("txtItemSearchDescription").Text) { $mSrchCndDic.Add($UIString["Adsk.QS.ItemSearch_03"], $dsWindow.FindName("txtItemSearchDescription").Text) }
		#the category combo allows overrides, e.g. Part typed will find Sheet Metal Part and Part categories
		#If($dsWindow.FindName("cmbItemSearchCategory").SelectedValue) { $mSrchCndDic.Add($UIString["Adsk.QS.ItemSearch_05"], $dsWindow.FindName("cmbItemSearchCategory").SelectedValue) }
		If ($dsWindow.FindName("cmbItemSearchCategory").Text) { $mSrchCndDic.Add($UIString["Adsk.QS.ItemSearch_05"], $dsWindow.FindName("cmbItemSearchCategory").Text) }
		If ($dsWindow.FindName("cmbItemSearchMaterial").Text) { $mSrchCndDic.Add($UIString["LBL75"], $dsWindow.FindName("cmbItemSearchMaterial").Text) }

		#create search conditions from inputs
		If (-not $mSrchCndDic.Count -gt 0) {
			return
		}
		$mNumConds = $mSrchCndDic.Count
		$mSrchConds = New-Object autodesk.Connectivity.WebServices.SrchCond[] $mNumConds
		$i = 0
		Foreach ($element in $mSrchCndDic.GetEnumerator()) {
			#differentiate first cond.rule = Must in anycase; if MultipleProp field is used the PropType changes from SingleProperty to AllProperties	
			if ($element.key -eq "MultipleProperties") {
				$mSrchConds[$i] = New-Object autodesk.Connectivity.WebServices.SrchCond
				$mSrchConds[$i].PropDefId = 0
				$mSrchConds[$i].SrchOper = 1 #contains
				$mSrchConds[$i].SrchTxt = $element.Value
				$mSrchConds[$i].PropTyp = "AllProperties"
				$mSrchConds[$i].SrchRule = "Must"
			}
			Else {
				$mSrchConds[$i] = mCreateItemSearchCond -mPropName $element.key -mSearchTxt $element.value -AndOr "AND"
			}
			$i += 1
		}

		$srchSort = New-Object autodesk.Connectivity.WebServices.SrchSort
		$searchStatus = New-Object autodesk.Connectivity.WebServices.SrchStatus
		$bookmark = ""     
		$mResultAll = New-Object 'System.Collections.Generic.List[Autodesk.Connectivity.WebServices.Item]'
	
		while (($searchStatus.TotalHits -eq 0) -or ($mResultAll.Count -lt $searchStatus.TotalHits)) {
			$mResultPage = $vault.ItemService.FindItemRevisionsBySearchConditions($mSrchConds, @($srchSort), $true, [ref]$bookmark, [ref]$searchStatus)
			
			If ($searchStatus.IndxStatus -ne "IndexingComplete" -or $searchStatus -eq "IndexingContent") {
				#check the indexing status; you might return a warning that the result bases on an incomplete index, or even return with a stop/error message, that we need to have a complete index first
				$dsWindow.FindName("txtItemSearchResultMsg").Text = $UIString["Adsk.QS.ItemSearch_08"]
				$dsWindow.FindName("txtItemSearchResultMsg").Visibility = "Visible"
			}
			if ($mResultPage.Count -ne 0) {
				$mResultAll.AddRange($mResultPage)
				$dsWindow.FindName("lblItemMaster").Text = $UIString["Adsk.QS.ItemSearch_06"] #Switch the title to indicate the page's content as result
				$dsWindow.FindName("ItemsFound").add_GotFocus({
						$dsWindow.FindName("btnItemDataCopy").IsEnabled = $true
						$dsWindow.FindName("btnItemDataCopy").ToolTip = $UIString["Adsk.QS.ItemSearch_12"]
					})
				
			}
			else { 
				$dsWindow.FindName("btnItemDataCopy").IsEnabled = $false
				break;
			}
			if ($mResultPage.Count -lt $searchStatus.TotalHits) {
				$dsWindow.FindName("txtItemSearchResultMsg").Text = ([String]::Format($UIString["Adsk.QS.ItemSearch_09"], $mResultAll.Count, $searchStatus.TotalHits))
				$dsWindow.FindName("txtItemSearchResultMsg").Visibility = "Visible"
			}
			Else {
				$dsWindow.FindName("txtItemSearchResultMsg").Text = ""
				$dsWindow.FindName("txtItemSearchResultMsg").Visibility = "Collapsed"
			}
			break; #limit the search result to the first result page; page scrolling not implemented in this snippet release
		}
	
		#derive data set from result do display; items have system properties like number, title, but others require to query the entity properties
		$mResultItemIds = @()
		$mResultAll | ForEach-Object { $mResultItemIds += $_.Id }
		#$mAllItemPropDefs = $vault.PropertyService.GetPropertyDefinitionsByEntityClassId("ITEM")
		$mPropDefs = @() #to be consumed by GetProperties
		$mPropDict = @{} #to be leveraged reading property by Name instead of Def.Id
		$mDefId += ($mAllItemPropDefs | Where-Object { $_.DispName -eq $UIString["Adsk.QS.ItemSearch_03"] }).Id #Description
		$mPropDefs += $mDefID
		$mPropDict.Add($UIString["Adsk.QS.ItemSearch_03"], $mDefID)
		$mDefId = ($mAllItemPropDefs | Where-Object { $_.DispName -eq $UIString["LBL75"] }).Id #Material
		$mPropDefs += $mDefID
		$mPropDict.Add($UIString["LBL75"], $mDefID)
		$mDefId = ($mAllItemPropDefs | Where-Object { $_.DispName -eq $UIString["LBL76"] }).Id #Stock Number
		$mPropDefs += $mDefID
		$mPropDict.Add($UIString["LBL76"], $mDefID)

		$mPropInst = $vault.PropertyService.GetProperties("ITEM", $mResultItemIds, $mPropDefs)
	
		#build the table to display items with properties
		$results = @()
		foreach ($item in $mResultAll) {
			$row = New-Object itemData
			$row.Item = $item.ItemNum
			$row.Revision = $item.RevNum
			$row.Title = $item.Title
			$row.Description = ($mPropInst | Where-Object { $_.EntityId -eq $item.Id -and $_.PropDefId -eq $mPropDict[$UIString["Adsk.QS.ItemSearch_03"]] }).Val
			$row.Material = ($mPropInst | Where-Object { $_.EntityId -eq $item.Id -and $_.PropDefId -eq $mPropDict[$UIString["LBL75"]] }).Val
			$row.Category = $item.Cat.CatName
			$row.StockNumber = ($mPropInst | Where-Object { $_.EntityId -eq $item.Id -and $_.PropDefId -eq $mPropDict[$UIString["LBL76"]] }).Val
			$results += $row
		}
		If ($results) {
			$dsWindow.FindName("ItemsFound").ItemsSource = $results
		}
	} #end try
	catch {}
	finally {
		$dsWindow.Cursor = "" #reset wait cursor
	}
}

function mCreateItemSearchCond ([String] $mPropName, [String] $mSearchTxt, [String] $AndOr) {
	#$dsDiag.Trace("--SearchCond creation starts... for $mPropName and $mSearchTxt ---")
	$srchCond = New-Object autodesk.Connectivity.WebServices.SrchCond
	$propDefs = $Global:mAllItemPropDefs #$vault.PropertyService.GetPropertyDefinitionsByEntityClassId("ITEM")
	$propDef = $propDefs | Where-Object { $_.DispName -eq $mPropName }
	$srchCond.PropDefId = $propDef.Id
	$srchCond.SrchOper = 1
	$srchCond.SrchTxt = $mSearchTxt
	$srchCond.PropTyp = [Autodesk.Connectivity.WebServices.PropertySearchType]::SingleProperty
	
	IF ($AndOr -eq "AND") {
		$srchCond.SrchRule = [Autodesk.Connectivity.WebServices.SearchRuleType]::Must
	}
	Else {
		$srchCond.SrchRule = [Autodesk.Connectivity.WebServices.SearchRuleType]::May
	}
	#$dsDiag.Trace("--SearchCond creation finished. ---")
	return $srchCond
} 

function mCopyItemData {
	$mSelectedItem = $dsWindow.FindName("ItemsFound").SelectedItem
	switch ($Global:mPropContext) {
		"Stock_Number" {
			mSelectStockItem
		}
		"Part_Number" {
			mSelectMakeItem
		}
		"Purchased" {
			mSelectMakeItem
		}
		"default" {}
	}
}

function mSelectMakeItem {
	#$dsDiag.Trace("Item selected to write it's number to the file part number field")
	#If an item is already assigned, overwriting existing Part Number might cause to re-assign the file to another item or at least cause file and item data being out of sync.
	if ($Global:mItemTabInitialized -ne $true) { mGetItemByFileFromVault }
	If ($dsWindow.FindName("txtItemNumber").Text) {
		#don't copy / don't copy without warning
		if ($vault.ItemService.GetItemAutounlinkEnabled() -eq $true) {
			$mMsgResult = [Autodesk.DataManagement.Client.Framework.Forms.Library]::ShowWarning(([String]::Format($UIString["Adsk.QS.ItemSearch_20"], "`n", "`n")), "Vault Data Standard - CAD Client", 'YesNo')
			if ($mMsgResult -eq "No") { return }
		}
		else {
			$mMsgResult = [Autodesk.DataManagement.Client.Framework.Forms.Library]::ShowWarning($UIString["Adsk.QS.ItemSearch_21"], "Vault Data Standard - CAD Client", "YesNo")
			if ($mMsgResult -eq "No") { return }
		}
	}
	
	try {
		$mSelectedItem = $dsWindow.FindName("ItemsFound").SelectedItem

		IF ($dsWindow.Name -eq "AutoCADWindow") {
			#ACM Attribute Name Mapping
			If ($Prop["GEN-TITLE-NR"]) {
				$Prop["GEN-TITLE-NR"].Value = $mSelectedItem.Item 
			}
			if ($Prop["GEN-TITLE-DES1"]) {
				$Prop["GEN-TITLE-DES1"].Value = $mSelectedItem.Title
			}
			if ($Prop["GEN-TITLE-DES2"]) {
				$Prop["GEN-TITLE-DES2"].Value = $mSelectedItem.Description
			}
			if ($Prop["GEN-TITLE-MAT1"]) {
				$Prop["GEN-TITLE-MAT1"].Value = $mSelectedItem.Material
			}
			#the UI Translation is used to get Vanilla property name scheme
			If ($Prop[$UIString["GEN-TITLE-NR"]]) {
				$Prop[$UIString["GEN-TITLE-NR"]].Value = $mSelectedItem.Item 
			}
			if ($Prop[$UIString["GEN-TITLE-DES1"]]) {
				$Prop[$UIString["GEN-TITLE-DES1"]].Value = $mSelectedItem.Title
			}
			if ($Prop[$UIString["GEN-TITLE-DES2"]]) {
				$Prop[$UIString["GEN-TITLE-DES2"]].Value = $mSelectedItem.Description
			}

		}
		IF ($dsWindow.Name -eq "InventorWindow") {
			$Prop["Part Number"].Value = $mSelectedItem.Item 
			$Prop["Title"].Value = $mSelectedItem.Title
			$Prop["Description"].Value = $mSelectedItem.Description
		}
		if ($Global:mPropContext -eq "Purchased") {
			$Prop["Stock Number"].Value = $mSelectedItem.StockNumber #the item's stock number, e.g the purchased part vendor's item number
			# Semifinished designation is custom prop; cautiously try to fill :)			
			#Try { $Prop[$UIString["LBL75"]].Value = $mSelectedItem.Material} Catch{}
		}
		
		$dsWindow.FindName("btnOK").IsDefault = $true
	}
	Catch [System.Exception] {
		[Autodesk.DataManagement.Client.Framework.Forms.Library]::ShowError($error, "VDS Sample Configuration")
		#$dsDiag.Trace("cannot write item number to property field")
	}
}

function mSelectStockItem {
	#stock number is frequently used for semifinished good's number
	try {
		$mSelectedItem = $dsWindow.FindName("ItemsFound").SelectedItem

		IF ($dsWindow.Name -eq "AutoCADWindow") {
			If ($Prop["GEN-TITLE-MAT2"]) { #ACM Attribute Name Mapping
				$Prop["GEN-TITLE-MAT2"].Value = $mSelectedItem.Item 
			}
			If ($Prop[$UIString["GEN-TITLE-MAT2"]]) { #the UI Translation is used to get Vanilla property name scheme
				$Prop[$UIString["GEN-TITLE-MAT2"]].Value = $mSelectedItem.Item 
			}
		}
		IF ($dsWindow.Name -eq "InventorWindow") {
			$Prop["Stock Number"].Value = $mSelectedItem.Item
			# Semifinished designation is custom prop; cautiously try to fill :)
			If ($mSelectedItem.Title) {
				Try { $Prop[$UIString["Adsk.QS.ItemSearch_13"]].Value = $mSelectedItem.Title } Catch {}
			}
			
			Try { $Prop[$UIString["LBL75"]].Value = $mSelectedItem.Material } Catch {}
			Try { $Prop["VLT_Material"].Value = $mSelectedItem.Material } Catch {}
		}

		$dsWindow.FindName("btnOK").IsDefault = $true

	}
	Catch [System.Exception] {
		[Autodesk.DataManagement.Client.Framework.Forms.Library]::ShowError($error)
		#$dsDiag.Trace("cannot write item number to property field")
	}
}

function mGetItemCategories {
	$mItemCats = $vault.CategoryService.GetCategoriesByEntityClassId("ITEM", $true)
	$mItemCatNames = @()
	Foreach ($item in $mItemCats) {
		$mItemCatNames += $item.Name
	}
	return $mItemCatNames
}

function mGetItemMaterials {
	$mDef = $mAllItemPropDefs | Where-Object { $_.DispName -eq $UIString["LBL75"] } #Material
	return $vault.PropertyService.GetPropertyDefinitionInfosByEntityClassId("ITEM", @($mDef.Id)).ListValArray
}


function mInitializeTabItemProps() {
	$dsWindow.FindName("btnAssignedItemRefresh").Visibility = "Collapsed"
	$dsWindow.FindName("txtAssignedItemStatus").Visibility = "Collapsed"
	
	if (-not $Global:mItemTabInitialized) {	
		$dsWindow.FindName("tabItemProperties").add_GotFocus({
				$dsWindow.FindName("expItemMasterSearch").Visibility = "Collapsed" #it's confusing if the item search is still open as it does not apply to the Assigned Item tab
				if ($null -eq $dsWindow.FindName("dtgrdItemProps").ItemsSource) {
					mGetItemByFileFromVault
				}
			})
		$Global:mItemTabInitialized = $true
	}
}


function mGetItemByFileFromVault() {
	#search for the file in Vault
	$result = FindFile -fileName $Prop["_FileName"].Value
	switch ($result.count) {
		0 {
			#$dsDiag.Trace("no file in Vault found")
			$dsWindow.FindName("txtAssignedItemStatus").Visibility = "Visible"
			$dsWindow.FindName("txtAssignedItemStatus").Text = $UIString["Adsk.QS.ItemSearch_17"]
			return $null
		}
		1 {
			#$dsDiag.Trace("1 file in Vault found")
			mInitializeTabItemProps
			#check that the file found maps to the local working folder location; otherwise a duplicate file locally might jeopardize the result
			#return $result
		}
		default {
			#$dsDiag.Trace("More than one file in Vault found")
			mInitializeTabItemProps
		}
	}#end switch
   
	#region get local and Vault path
	$mappedRootPath = $Prop["_VaultVirtualPath"].Value + $Prop["_WorkspacePath"].Value
	$mappedRootPath = $mappedRootPath -replace "\\", "/" -replace "//", "/"
	if ($mappedRootPath -eq '') {
		$mappedRootPath = '$/'
	}
	#$dsDiag.Trace("mapped root: $($mappedRootPath)")
	$mWfVault = $mappedRootPath
					
	#get local path of vault workspace path for Inventor
	If ($dsWindow.Name -eq "InventorWindow") {
		$mCAxRoot = $mappedRootPath.Split("/.")[1]
	}
	if ($dsWindow.Name -eq "AutoCADWindow") {
		$mCAxRoot = ""
	}
	if ($vault.DocumentService.GetEnforceWorkingFolder() -eq "true") {
		$mWF = $vault.DocumentService.GetRequiredWorkingFolderLocation()
	}
	else {
		[Autodesk.DataManagement.Client.Framework.Forms.Library]::ShowError($UIString["Adsk.QS.ItemSearch_22"], "Inventor VDS Client")
		return
	}	
	$mWFCAD = $mWF + $mCAxRoot
	#merge the local path and relative target path of new file in vault
	$mPath = $Prop["_FilePath"].Value.Replace($mWFCAD, "")
	$mPath = $mWfVault + $mPath
	$mPath = $mPath.Replace(".\", "")
	$mPath = $mPath.Replace("\", "/")
	#endregion

	$file = FindLatestFileInVaultByPath($mPath + "/" + $Prop["_FileName"].Value)
	if ($file) {
		#check the accessibility for the current user
		if ($file.Cloaked -eq $true) {
			$dsWindow.FindName("txtAssignedItemStatus").Visibility = "Visible"
			$dsWindow.FindName("txtAssignedItemStatus").Text = $UIString["Adsk.QS.ItemSearch_15"]
			return
		}

		#query for assigned item
		$mFileIteration = $vault.DocumentService.GetLatestFileByMasterId($file.MasterId)
		$items = $vault.ItemService.GetItemsByFileId($mFileIteration.Id)
		$item = $items[0]
		if ($item) {
			#check accessibility for the current user
			if ($item.IsCloaked -eq $true) {
				$dsWindow.FindName("btnAssignedItemRefresh").Visibility = "Visible"
				$dsWindow.FindName("txtAssignedItemStatus").Visibility = "Visible"
				$dsWindow.FindName("txtAssignedItemStatus").Text = $UIString["Adsk.QS.ItemSearch_16"]
			}
			else {
				#retrieve item meta data
				#avoid repetitive server calls; we'll need the item property definitions several times
				If (-not $Global:mAllItemPropDefs) { $Global:mAllItemPropDefs = $vault.PropertyService.GetPropertyDefinitionsByEntityClassId("ITEM") }
				if (-not $Global:mMaterials) { $Global:mMaterials = mGetItemMaterials }
				if (-not $Global:mItemCategories) { $Global:mItemCategories = mGetItemCategories }

				Try {
					#derive data set from result do display; items have system properties like number, title, but others require to query the entity properties
					$mPropDefs = @() #to be consumed by GetProperties
					$mPropDict = @{} #to be leveraged reading property by Name instead of Def.Id
					$mDefId += ($mAllItemPropDefs | Where-Object { $_.DispName -eq $UIString["Adsk.QS.ItemSearch_03"] }).Id #Description
					$mPropDefs += $mDefID
					$mPropDict.Add($UIString["Adsk.QS.ItemSearch_03"], $mDefID)
					$mDefId = ($mAllItemPropDefs | Where-Object { $_.DispName -eq $UIString["LBL75"] }).Id #Material
					$mPropDefs += $mDefID
					$mPropDict.Add($UIString["LBL75"], $mDefID)
		
					$mPropInsts = $vault.PropertyService.GetPropertiesByEntityIds("ITEM", @($item.Id))
					$mPropTable = @{}
					$mPropSysNames = @{}
					$mPropFilter = @("Thumbnail", "CategoryGlyph", "CategoryGlyph(Ver)", "Compliance", "Compliance(Ver)") #system names
					$mPropFilterKeys = @() #to store display names

					Foreach ($PropInst in $mPropInsts) {
						#Key = Property DispName
						$mPropDispName = ($mAllItemPropDefs | Where-Object { $_.Id -eq $PropInst.PropDefId }).DispName
						$mPropSysNames.Add(($mAllItemPropDefs | Where-Object { $_.Id -eq $PropInst.PropDefId }).SysName, $mPropDispName)	#collect the (system) keys of properties to filter later
						if ($mPropFilter -contains ($mAllItemPropDefs | Where-Object { $_.Id -eq $PropInst.PropDefId }).SysName) { $mPropFilterKeys += $mPropDispName }
						#Value = PropInst Value; don't add if the key is part of the filtered ids
						$mPropTable.Add($mPropDispName, $PropInst.Val)
					}
					#Fill the default properties; use the sysnames to get the key (dispname)
					$dsWindow.FindName("ItemThumbnail").Source = $mPropTable.($mPropSysNames["Thumbnail"])
					$dsWindow.FindName("txtItemRevision").Text = $mPropTable.($mPropSysNames["Revision"])
					$dsWindow.FindName("txtItemNumber").Text = $mPropTable.($mPropSysNames["Number"])
					$dsWindow.FindName("txtItemTitle").Text = $mPropTable.($mPropSysNames["Title(Item,CO)"])
					$dsWindow.FindName("txtItemDescription").Text = $mPropTable.($mPropSysNames["Description(Item,CO)"])
					$dsWindow.FindName("txtItemUnits").Text = $mPropTable.($mPropSysNames["Units"])
					$dsWindow.FindName("txtItemCategory").Text = $mPropTable.($mPropSysNames["CategoryName"])
					$dsWindow.FindName("txtItemLfcState").Text = $mPropTable.($mPropSysNames["State"])
					$dsWindow.FindName("txtItemLastUpdatedBy").Text = $mPropTable.($mPropSysNames["LastModifiedUserName"])
					$dsWindow.FindName("txtItemLastUpdatedDate").Text = $mPropTable.($mPropSysNames["ModDate"]).ToString("yyyy/mm/dd hh:mm:ss") #default date time formats

					#filter the dataset and hand over
					Foreach ($Filt in $mPropFilter) {
						$mPropTable.Remove($mPropSysNames[$Filt])
					}
					$mPropTable = $mPropTable.GetEnumerator() | Sort-Object { $_.Key }
					$dsWindow.FindName("dtgrdItemProps").ItemsSource = $mPropTable
				}
				Catch [System.Exception] {		
					[Autodesk.DataManagement.Client.Framework.Forms.Library]::ShowError($error, "VDS Sample Configuration")
				}	
		
			} #else: item is accessible
		}#end item found
		else {
			#$dsWindow.FindName("btnAssignedItemRefresh").Visibility = "Visible"
			$dsWindow.FindName("txtAssignedItemStatus").Visibility = "Visible"
			$dsWindow.FindName("txtAssignedItemStatus").Text = $UIString["Adsk.QS.ItemSearch_18"]
		}

	}#end file found in Vault
   
}