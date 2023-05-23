#region disclaimer
#=============================================================================
# PowerShell script sample for Vault Data Standard
#
# Copyright (c) Autodesk - All rights reserved.
# 
# THIS SCRIPT/CODE IS PROVIDED "AS IS" WITHOUT WARRANTY OF ANY KIND, EITHER
# EXPRESSED OR IMPLIED, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED WARRANTIES
# OF MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE, OR NON-INFRINGEMENT.
#=============================================================================
#endregion

Add-Type @'
public class mClsDerivate
{
	public byte[] Thumbnail;
	public string Name;
	public string Title;
	public string Description;
	public string State;
	public string CreateDate;
	public bool LReleasedRev;
	public bool LVer;
	public string Comment;
}
'@

function mDerivationTreeUpdateView($fileMasterId)
{
	mDerivativesSelectNothing
		$fileMasterId = $vaultContext.SelectedObject.Id
		$file = $vault.DocumentService.GetLatestFileByMasterId($fileMasterId)

		$mDerivativesSource = @(mGetDerivativeSource($file)) #querying all file versions (historical) of the source
		if($mDerivativesSource.Count -eq 0) { 
			$dsWindow.FindName("mDerivatives").Visibility = "Collapsed"
			$dsWindow.FindName("txtBlck_Notification1").Text = $UIString["DerivationTree_13"]
			$dsWindow.FindName("txtBlck_Notification1").Visibility = "Visible"
			$dsWindow.FindName("SourceTree").IsExpanded = $false
			mDerivativesSelectNothing
		}
		Else{
			$dsWindow.FindName("mDerivatives").ItemsSource = $mDerivativesSource
			$dsWindow.FindName("mDerivatives").Visibility = "Visible"
			$dsWindow.FindName("SourceTree").IsExpanded = $true
			
		}
		$dsWindow.FindName("mDerivatives").add_SelectionChanged({
				mDerivativesClick
			})

		$mDerivativesParallels = @(mGetDerivativeParallels($file)) #querying all file versions (historical) of the source
		if($mDerivativesParallels.Count -eq 0) { 
			$dsWindow.FindName("mDerivatives1").Visibility = "Collapsed"
			$dsWindow.FindName("txtBlck_Notification2").Text = $UIString["DerivationTree_14"]
			$dsWindow.FindName("txtBlck_Notification2").Visibility = "Visible"
			$dsWindow.FindName("ParallelsTree").IsExpanded = $false
			mDerivativesSelectNothing
		}
		Else{
			$dsWindow.FindName("mDerivatives1").ItemsSource = $mDerivativesParallels
			$dsWindow.FindName("mDerivatives1").Visibility = "Visible"
			$dsWindow.FindName("ParallelsTree").IsExpanded = $true
			
		}
		$dsWindow.FindName("mDerivatives1").add_SelectionChanged({
				mDerivatives1Click
			})
		$mDerivativesCopies = @(mGetDerivativeCopies($file)) #querying all file versions (historical) of the source
		if($mDerivativesCopies.Count -eq 0) { 
			$dsWindow.FindName("mDerivatives2").Visibility = "Collapsed"
			$dsWindow.FindName("txtBlck_Notification3").Text = $UIString["DerivationTree_15"]
			$dsWindow.FindName("txtBlck_Notification3").Visibility = "Visible"
			$dsWindow.FindName("DerivedTree").IsExpanded = $false
			mDerivativesSelectNothing
		}
		Else{
			$dsWindow.FindName("mDerivatives2").ItemsSource = $mDerivativesCopies
			$dsWindow.FindName("mDerivatives2").Visibility = "Visible"
			$dsWindow.FindName("DerivedTree").IsExpanded = $true
			
		}
		$dsWindow.FindName("mDerivatives2").add_SelectionChanged({
				mDerivatives2Click
			})
	$dsWindow.FindName("btnUpdate").IsEnabled = $false
}

function mDerivationTreeResetView()
{
	$dsWindow.FindName("mDerivatives").ItemsSource = $null		
	$dsWindow.FindName("mDerivatives").Visibility = "Collapsed"
	$dsWindow.FindName("mDerivatives1").ItemsSource = $null
	$dsWindow.FindName("SourceTree").IsExpanded = $false
	$dsWindow.FindName("mDerivatives1").Visibility = "Collapsed"
	$dsWindow.FindName("mDerivatives2").ItemsSource = $null
	$dsWindow.FindName("ParallelsTree").IsExpanded = $false
	$dsWindow.FindName("mDerivatives2").Visibility = "Collapsed"
	$dsWindow.FindName("DerivedTree").IsExpanded = $false
	$dsWindow.FindName("btnUpdate").IsEnabled = $true
}

function mGetDerivativeSource($mFile) #expects the (master) file object
{
	#region variables
	# change the quoted display name according your Vault Property Definition
		$_SourceFilePropDispName = $UIString["ADSK-GoToNavigation_Prop01"]
	#endregion
	
	$PropDefs = $vault.PropertyService.GetPropertyDefinitionsByEntityClassId("FILE")
	$propDefIds = @()
	$PropDefs | ForEach-Object {
		$propDefIds += $_.Id
	}
	$mFileProps = $vault.PropertyService.GetProperties("FILE",@($mFile.Id),$propDefIds)

	$_Def = $PropDefs | Where-Object {$_.dispName -eq $_SourceFilePropDispName}
	$_Prop = $mFileProps | Where-Object { $_.PropDefId -eq $_Def.Id}
	$mSearchString = $_Prop.Val

	If ($mSearchString.Length -lt 0) 
	{ 
		return
	}

	#$dsDiag.Trace(">> Starting mGetDerivatives for SourceFile ($mSearchString)")
	#region search for file iterations, search conditions Prop[<Source File>] = mFile's Prop[<Source File>].Value, latestonly = false
	# or condition 2 comments contains, in case the source has been renamed after the copy
	
	#build the search
	$_NumConds = 2 # search is required for Prop[SourceFile].Value and the name property (the original file, never has a source value)
	$srchConds = New-Object autodesk.Connectivity.WebServices.SrchCond[] $_NumConds
	$_i = 0
	#the default search condition object type is the property carrying the source file name value
	$srchConds[$_i]= mCreateSearchCond "Name" $mSearchString "OR"
	$_i += 1
	#add another condition for the Name (file name of original file)
	$_Def = $PropDefs | Where-Object {$_.SysName -eq "ClientFileName(Ver)"}
	$mSearchProp = $_Def.DispName
	$srchConds[$_i]= mCreateSearchCond $mSearchProp $mSearchString "OR"
		$_i += 1

	$srchSort = New-Object autodesk.Connectivity.WebServices.SrchSort
	$srchSort.PropDefId = ($PropDefs | Where-Object {$_.SysName -eq "OrigCreateDate"}).Id
	$srchSort.SortAsc = $true

	$mSearchStatus = New-Object autodesk.Connectivity.WebServices.SrchStatus
	$mBookmark = ""     
	$mResultAll = New-Object 'System.Collections.Generic.List[Autodesk.Connectivity.WebServices.File]'
	
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
		$dsWindow.FindName("txtBlck_Notification1").Text = ([String]::Format($UIString["DerivationTree_16"], $mResultAll.Count, $mSearchStatus.TotalHits))
	}
    Else{
        $dsWindow.FindName("txtBlck_Notification1").Visibility = "Collapsed"
    }
	IF($mResultAll.Count -gt 0)
	{
		$mDerivates = mGetResultMeta $mResultAll # @() #the array of each file iterations meta data
		return $mDerivates
	}
}

function mGetResultMeta($mResultAll)
{
	$mDerivates = @() #the array of each file iterations meta data
	$mResultAll | ForEach-Object {
		$mDerivate = New-Object mClsDerivate
		$propDefIds = @()
		$PropDefs | ForEach-Object {
			$propDefIds += $_.Id
		}
		$mFileProps = $vault.PropertyService.GetProperties("FILE",@($_.Id),$propDefIds)
		$_Def = $PropDefs | Where-Object {$_.SysName -eq "Thumbnail"}
		$_Prop = $mFileProps | Where-Object { $_.PropDefId -eq $_Def.Id}
		$mDerivate.Thumbnail = $_Prop.Val
		$_Def = $PropDefs | Where-Object {$_.SysName -eq "ClientFileName(Ver)"}
		$_Prop = $mFileProps | Where-Object { $_.PropDefId -eq $_Def.Id}
		$mDerivate.Name = $_Prop.Val
		$_Def = $PropDefs | Where-Object {$_.SysName -eq "Title"}
		$_Prop = $mFileProps | Where-Object { $_.PropDefId -eq $_Def.Id}
		$mDerivate.Title = $_Prop.Val
		$_Def = $PropDefs | Where-Object {$_.SysName -eq "Description"}
		$_Prop = $mFileProps | Where-Object { $_.PropDefId -eq $_Def.Id}
		$mDerivate.Description = $_Prop.Val
		$_Def = $PropDefs | Where-Object {$_.SysName -eq "State(Ver)"}
		$_Prop = $mFileProps | Where-Object { $_.PropDefId -eq $_Def.Id}
		$mDerivate.State = $_Prop.Val
		$mDerivate.CreateDate = $_.CreateDate
		$_Def = $PropDefs | Where-Object {$_.SysName -eq "LatestVersion"}
		$_Prop = $mFileProps | Where-Object { $_.PropDefId -eq $_Def.Id}
		$mDerivate.LVer = $_Prop.Val
		$_Def = $PropDefs | Where-Object {$_.SysName -eq "LatestReleasedRevision"}
		$_Prop = $mFileProps | Where-Object { $_.PropDefId -eq $_Def.Id}
		$mDerivate.LReleasedRev = $_Prop.Val
		$mDerivate.Comment = $_.Comm

		$mDerivates += $mDerivate
	}
	return $mDerivates
}

function mGetDerivativeParallels($mFile) #expects the (master) file object
{
	#region variables
	# change the quoted display name according your Vault Property Definition
		$_SourceFilePropDispName = $UIString["ADSK-GoToNavigation_Prop01"]
	#endregion
	
	$PropDefs = $vault.PropertyService.GetPropertyDefinitionsByEntityClassId("FILE")
	$propDefIds = @()
	$PropDefs | ForEach-Object {
		$propDefIds += $_.Id
	}
	$mFileProps = $vault.PropertyService.GetProperties("FILE",@($mFile.Id),$propDefIds)

	$_Def = $PropDefs | Where-Object {$_.dispName -eq $_SourceFilePropDispName}
	$_Prop = $mFileProps | Where-Object { $_.PropDefId -eq $_Def.Id}
	$mSearchString = $_Prop.Val

	If ($mSearchString.Length -lt 0) 
	{ 
		return
	}

	#$dsDiag.Trace(">> Starting mGetDerivatives for SourceFile ($mSearchString)")
	#region search for file iterations, search conditions Prop[<Source File>] = mFile's Prop[<Source File>].Value, latestonly = false
	# or condition 2 comments contains, in case the source has been renamed after the copy
	
	#build the search
	$_NumConds = 1 # search is required for Prop[SourceFile].Value and the name property (the original file, never has a source value)
	$srchConds = New-Object autodesk.Connectivity.WebServices.SrchCond[] $_NumConds
	$_i = 0
	#the default search condition object type is the property carrying the source file name value
	$srchConds[$_i]= mCreateSearchCond $_SourceFilePropDispName $mSearchString "OR"
	$_i += 1
	
	$srchSort = New-Object autodesk.Connectivity.WebServices.SrchSort
	$srchSort.PropDefId = ($PropDefs | Where-Object {$_.SysName -eq "OrigCreateDate"}).Id
	$srchSort.SortAsc = $true

	$mSearchStatus = New-Object autodesk.Connectivity.WebServices.SrchStatus
	$mBookmark = ""     
	$mResultAll = New-Object 'System.Collections.Generic.List[Autodesk.Connectivity.WebServices.File]'
	
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
		$dsWindow.FindName("txtBlck_Notification2").Text = ([String]::Format($UIString["DerivationTree_16"], $mResultAll.Count, $mSearchStatus.TotalHits))
	}
	Else { $dsWindow.FindName("txtBlck_Notification2").Visibility = "Collapsed" }
	
	If($mResultAll.Count -gt 0)
	{
		$mResultFiltered = $mResultAll | Where-Object {$_.Name -ne $mFile.Name} # don't list the selected file's versions as parallel copies
		If ($mResultFiltered.Count -gt 0)
		{
			$mDerivates = mGetResultMeta $mResultFiltered # @() #the array of each file iterations meta data
			return $mDerivates
		}
	}
}

function mGetDerivativeCopies($mFile) #expects the (master) file object
{
	#region variables
	# change the quoted display name according your Vault Property Definition
		$_SourceFilePropDispName = $UIString["ADSK-GoToNavigation_Prop01"]
	#endregion
	
	$PropDefs = $vault.PropertyService.GetPropertyDefinitionsByEntityClassId("FILE")
	$propDefIds = @()
	$PropDefs | ForEach-Object {
		$propDefIds += $_.Id
	}
	$mFileProps = $vault.PropertyService.GetProperties("FILE",@($mFile.Id),$propDefIds)

	$_Def = $PropDefs | Where-Object {$_.dispName -eq $_SourceFilePropDispName}
	$_Prop = $mFileProps | Where-Object { $_.PropDefId -eq $_Def.Id}
	$mSearchString = $mFile.Name #$_Prop.Val

	If ($mSearchString.Length -lt 0) 
	{ 
		return
	}

	#$dsDiag.Trace(">> Starting mGetDerivatives for SourceFile ($mSearchString)")
	#region search for file iterations, search conditions Prop[<Source File>] = mFile's Prop[<Source File>].Value, latestonly = false
	# or condition 2 comments contains, in case the source has been renamed after the copy
	
	#build the search
	$_NumConds = 1 # search is required for Prop[SourceFile].Value and the name property (the original file, never has a source value)
	$srchConds = New-Object autodesk.Connectivity.WebServices.SrchCond[] $_NumConds
	$_i = 0
	#the default search condition object type is the property carrying the source file name value
	$srchConds[$_i]= mCreateSearchCond $_SourceFilePropDispName $mSearchString "OR"
	$_i += 1
	
	$srchSort = New-Object autodesk.Connectivity.WebServices.SrchSort
	$srchSort.PropDefId = ($PropDefs | Where-Object {$_.SysName -eq "OrigCreateDate"}).Id
	$srchSort.SortAsc = $true

	$mSearchStatus = New-Object autodesk.Connectivity.WebServices.SrchStatus
	$mBookmark = ""     
	$mResultAll = New-Object 'System.Collections.Generic.List[Autodesk.Connectivity.WebServices.File]'
	
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
		$dsWindow.FindName("txtBlck_Notification3").Text = ([String]::Format($UIString["DerivationTree_16"], $mResultAll.Count, $mSearchStatus.TotalHits))
	}
	Else { $dsWindow.FindName("txtBlck_Notification3").Visibility = "Collapsed" }

	If($mResultAll.Count -gt 0)
	{
		$mDerivates = mGetResultMeta $mResultAll # @() #the array of each file iterations meta data
		return $mDerivates
	}
}

function mSelectedSourceToClipBoard()
{
	$mSelectedItemS = @()
	$mSelectedItemS += $dsWindow.FindName("mDerivatives").SelectedItems
    $mSelectedNames = @()
    Foreach($item in $mSelectedItemS){
        $mSelectedNames += $item.Name
    }
    [Windows.Forms.Clipboard]::SetText($mSelectedNames)
}
function mSelectedParallelsToClipBoard()
{
	$mSelectedItemS = @()
	$mSelectedItemS += $dsWindow.FindName("mDerivatives1").SelectedItems
    $mSelectedNames = @()
    Foreach($item in $mSelectedItemS){
        $mSelectedNames += $item.Name
    }
    [Windows.Forms.Clipboard]::SetText($mSelectedNames)
}
function mSelectedDerivativesToClipBoard()
{
	$mSelectedItemS = @()
	$mSelectedItemS += $dsWindow.FindName("mDerivatives2").SelectedItems
    $mSelectedNames = @()
    Foreach($item in $mSelectedItemS){
        $mSelectedNames += $item.Name
    }
    [Windows.Forms.Clipboard]::SetText($mSelectedNames)
}

function mDerivativesSelectNothing()
{
	$mSelItem = ""
    $mOutFile = "mStrTabClick.txt"
	$mSelItem | Out-File "$($env:appdata)\Autodesk\DataStandard 2023\$($mOutFile)"
}

function mDerivativesClick()
{
	$mSelItem = $dsWindow.FindName("mDerivatives").SelectedItem
    $mOutFile = "mStrTabClick.txt"
	foreach($mItem in $mSelItem)
	{
		$mItem.Name | Out-File "$($env:appdata)\Autodesk\DataStandard 2023\$($mOutFile)"
	}
}

function mDerivatives1Click()
{
	$mSelItem = $dsWindow.FindName("mDerivatives1").SelectedItem
    $mOutFile = "mStrTabClick.txt"
	foreach($mItem in $mSelItem)
	{
		$mItem.Name | Out-File "$($env:appdata)\Autodesk\DataStandard 2023\$($mOutFile)"
	}
}

function mDerivatives2Click()
{
	$mSelItem = $dsWindow.FindName("mDerivatives2").SelectedItem
    $mOutFile = "mStrTabClick.txt"
	foreach($mItem in $mSelItem)
	{
		$mItem.Name | Out-File "$($env:appdata)\Autodesk\DataStandard 2023\$($mOutFile)"
	}
}

function mCreateSearchCond ([String] $PropName, [String] $mSearchTxt, [String] $AndOr) {
	#$dsDiag.Trace("--SearchCond creation starts... for $PropName and $mSearchTxt ---")
	$srchCond = New-Object autodesk.Connectivity.WebServices.SrchCond
	$propDefs = $vault.PropertyService.GetPropertyDefinitionsByEntityClassId("FILE")
	$propNames = @($PropName)
	$propDefIds = @{}
	foreach($name in $propNames) 
	{
		$propDef = $propDefs | Where-Object { $_.dispName -eq $name }
		$propDefIds[$propDef.Id] = $propDef.DispName
	}
	$srchCond.PropDefId = $propDef.Id
	$srchCond.SrchOper = 3
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