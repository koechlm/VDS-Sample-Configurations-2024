# DISCLAIMER:
# ---------------------------------
# In any case, code, templates, and snippets of this solution are of "work in progress" character.
# Neither Markus Koechl, nor Autodesk represents that these samples are reliable, accurate, complete, or otherwise valid. 
# Accordingly, those configuration samples are provided as is with no warranty of any kind, and you use the applications at your own risk.


function InitializeFileNameValidation() {
    if ($Prop["_CreateMode"].Value) {
        if ($dsWindow.Name -eq 'InventorWindow') {
            if ($Prop["_SaveCopyAsMode"].Value -eq $true) {
                $dsWindow.FindName("Format").add_SelectionChanged({
                        PreviewExportFileName
                    })
                $dsWindow.FindName("NumSchms").add_SelectionChanged({
                        PreviewExportFileName
                    })
                $dsWindow.FindName("FILENAME").add_LostFocus({
                        PreviewExportFileName
                    })
                $Prop["Folder"].add_PropertyChanged({
                        PreviewExportFileName
                    })
            }
            $Prop["DocNumber"].CustomValidation = { FileNameCustomValidation }
        }
        elseif ($dsWindow.Name -eq 'AutoCADWindow') {
            $Prop["DocNumber"].CustomValidation = { FileNameCustomValidation }
        }        
    }
}

function FileNameCustomValidation {
    $DSNumSchmsCtrl = $dsWindow.FindName("DSNumSchmsCtrl")
    if ($DSNumSchmsCtrl -and -not $DSNumSchmsCtrl.NumSchmFieldsEmpty) {
        return $true
    }
    if ($dsWindow.Name -eq 'InventorWindow') {
        $propertyName = "DocNumber"
    }
    elseif ($dsWindow.Name -eq 'AutoCADWindow') {
        $propertyName = "DocNumber"
    }
    
    $rootFolder = GetVaultRootFolder

    $fileName = $Prop["_FileName"].Value

    if ([string]::IsNullOrEmpty($Prop[$propertyName].Value)) {
        $Prop["$($propertyName)"].CustomValidationErrorMessage = "$($UIString["VAL1"])"
        return $false
    }

    if ($fileName.IndexOfAny([System.IO.Path]::GetInvalidFileNameChars()) -ne -1) {
        $Prop["$($propertyName)"].CustomValidationErrorMessage = "$($UIString["VAL10"])"
        return $false
    }

    $fullFileName = [System.IO.Path]::Combine($Prop["_FilePath"].Value, $fileName)
    if ([System.IO.File]::Exists($fullFileName)) {
        $Prop["$($propertyName)"].CustomValidationErrorMessage = "$($UIString["MSG4"])"
        return $false
    }

    $file = FindLatestFileInVaultByPath($rootFolder.FullName + "/" + $Prop["Folder"].Value.Replace(".\", "") + $Prop["_FileName"].Value)
    if ($file) {
        $fileIteration = New-Object Autodesk.DataManagement.Client.Framework.Vault.Currency.Entities.FileIteration($vaultConnection, $file)
        if ($fileIteration.IsCheckedOut) {
            If (!$fileIteration.IsCheckedOutToCurrentUser) {
                $Prop["$($propertyName)"].CustomValidationErrorMessage = "$($UIString["VAL14"])"
                return $false
            }
            return $true
        }
        return $true
    }
    if ($vault.DocumentService.GetUniqueFileNameRequired()) {    
        $result = FindFile -fileName $Prop["_FileName"].Value
        if ($result) {
            $Prop["$($propertyName)"].CustomValidationErrorMessage = "$($UIString["VAL13"])"
            return $false
        }
    }
    return $true
}

function FindFile($fileName) {
    $filePropDefs = $vault.PropertyService.GetPropertyDefinitionsByEntityClassId("FILE")
    $fileNamePropDef = $filePropDefs | where { $_.SysName -eq "ClientFileName" }
    $srchCond = New-Object 'Autodesk.Connectivity.WebServices.SrchCond'
    $srchCond.PropDefId = $fileNamePropDef.Id
    $srchCond.PropTyp = "SingleProperty"
    $srchCond.SrchOper = 3 #is equal
    $srchCond.SrchRule = "Must"
    $srchCond.SrchTxt = $fileName

    $bookmark = ""
    $status = $null
    $totalResults = @()
    while ($status -eq $null -or $totalResults.Count -lt $status.TotalHits) {
        $results = $vault.DocumentService.FindFilesBySearchConditions(@($srchCond), $null, $null, $false, $true, [ref]$bookmark, [ref]$status)

        if ($results -ne $null) {
            $totalResults += $results
        }
        else { break }
    }
    return $totalResults;
}

function FindLatestFileInVaultByPath($vaultPath) {
    $pathWithoutDot = $vaultPath.Replace("/.", "/")
    $pathInVaultFormat = $pathWithoutDot.Replace("\", "/")
    try {
        $files = $vault.DocumentService.FindLatestFilesByPaths(@($pathInVaultFormat))
        if ($files.Count -gt 0) {
            if ($files[0].Id -ne -1)
            { return $files[0] }
        }
    }
    catch {
        #$dsDiag.Inspect()
    }    
    return $null
}

function PreviewExportFileName() {
    $knownextensions = @("ipt", "iam", "idw", "dwg", "dxf", "pdf", "jt", "stp")
    if (-not $Prop["DocNumber"].Value) {
        return 
    }
    $newFileName = @()
    $newFileName += ($Prop["DocNumber"].Value.Split("."))
    $ext = $newFileName[$newFileName.Count - 1]
    $newExt = $Prop["_FileExt"].Value.ToLower()
    if ($knownextensions -contains $ext) {        
        $Prop["DocNumber"].Value = $Prop["DocNumber"].Value -replace "(.*).$ext(.*)", "`$1$newExt`$2"
    }
    else {
        $Prop["DocNumber"].Value = $Prop["DocNumber"].Value + "$newExt"
    }
}