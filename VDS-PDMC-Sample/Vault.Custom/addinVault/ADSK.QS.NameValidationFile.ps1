function FindFile($fileName)
{
	#$dsDiag.Trace("FindFile started from validation...")
    $filePropDefs = $vault.PropertyService.GetPropertyDefinitionsByEntityClassId("FILE")
    $fileNamePropDef = $filePropDefs | where {$_.SysName -eq "ClientFileName"}
    $srchCond = New-Object 'Autodesk.Connectivity.WebServices.SrchCond'
    $srchCond.PropDefId = $fileNamePropDef.Id
    $srchCond.PropTyp = "SingleProperty"
    $srchCond.SrchOper = 3 #is equal
    $srchCond.SrchRule = "Must"
    $srchCond.SrchTxt = $fileName

    $bookmark = ""
    $status = $null
    $totalResults = @()
    while ($status -eq $null -or $totalResults.Count -lt $status.TotalHits)
    {
        $results = $vault.DocumentService.FindFilesBySearchConditions(@($srchCond),$null, $null, $false, $true, [ref]$bookmark, [ref]$status)
        if ($results -ne $null)
        {
            $totalResults += $results
        }
        else {break}
    }
	#$dsDiag.Trace("...FindFile returns $($totalResults).")
    return $totalResults;
}

function FindLatestFileInVaultByPath($vaultPath)
{
    $pathWithoutDot = $vaultPath.Replace("/.", "/")
    $pathInVaultFormat = $pathWithoutDot.Replace("\", "/")
    try
    {
        $files = $vault.DocumentService.FindLatestFilesByPaths(@($pathInVaultFormat))
        if ($files.Count -gt 0)
        {
            if ($files[0].Id -ne -1)
            { return $files[0] }
        }
    }
    catch
    {
        #$dsDiag.Inspect()
    }    
    return $null
}
