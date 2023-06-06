function InitializeFolderNameValidation
{
    $Prop["_FolderName"].CustomValidation = { mValidateUniqueFldrName } 
}

function mValidateUniqueFldrName 
{
    #in case a numbering scheme is active, the validation is positiv
    if(-not $dsWindow.FindName("DSNumSchmsCtrl").NumSchmFieldsEmpty)
	{
		return $true
    }

    #to check hand-typed folders names, a Vault search is required to check for existing names as the user types
    if($Prop["_FolderName"].Value)
	{
        #the search should start in the current folder location
        $rootFolder = $vault.DocumentService.GetFolderByPath($Prop["_FolderPath"].Value)

        #separate the search into a distinct function "mFindFolder"
		$mFldExist = mFindFolder $Prop["_FolderName"].Value $rootFolder

        if($mFldExist)
		{
            $dsWindow.FindName("FOLDERNAME").BorderBrush = "Red"
            $dsWindow.FindName("FOLDERNAME").ToolTip = "Folder name already exists in this tree, select a new unique one."
			return $false
		}
        Else{
            $dsWindow.FindName("FOLDERNAME").BorderBrush = $null
            $dsWindow.FindName("FOLDERNAME").ToolTip = $null
            return $true
        }
	}
	else
	{
        $dsWindow.FindName("FOLDERNAME").BorderBrush = "Red"
        $dsWindow.FindName("FOLDERNAME").ToolTip = "Folder name must not be empty."
		return $false
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
        $results = $vault.DocumentService.FindFoldersBySearchConditions(@($srchCond),$null, @($rootFolder.Id), $true, [ref]$bookmark, [ref]$status)

        if ($results -ne $null)
        {
            $totalResults += $results
        }
        else {break}
    }
    return $totalResults;
} 