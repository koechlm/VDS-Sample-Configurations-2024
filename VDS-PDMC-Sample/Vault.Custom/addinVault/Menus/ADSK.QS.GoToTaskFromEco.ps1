# DISCLAIMER:
# ---------------------------------
# In any case, code, templates, and snippets of this solution are of "work in progress" character.
# Neither Markus Koechl, nor Autodesk represents that these samples are reliable, accurate, complete, or otherwise valid. 
# Accordingly, those configuration samples are provided as is with no warranty of any kind, and you use the applications at your own risk.


#an ECO likely links multiple tasks; the user needs to select one from the list; the selection writes the txt file
$mTargetObject = Get-Content "$($env:appdata)\Autodesk\DataStandard 2024\mECOTabClick.txt"
if (-not $mTargetObject) {
    $result = [Autodesk.DataManagement.Client.Framework.Forms.Library]::ShowError("No Tasks is selected in the ECO-Task Tab. Select a Task first and try again.", "ECO-Tasks")
}
else {
    $mCustent = $vault.CustomEntityService.GetCustomEntitiesByIds(@($mTargetObject))[0]

    #identify custom object definition and unique (system name)
    $custentNumber = $mCustent.Num
    $custentDefId = $mCustent.CustEntDefId
    $custentName = ($vault.CustomEntityService.GetAllCustomEntityDefinitions() | Where-Object { $_.Id -eq $custentDefId }).Name

    #custom objects don't have a pre-defined selectiontypeID, so lets create one
    $selectionTypeId = New-Object Autodesk.Connectivity.Explorer.Extensibility.SelectionTypeId($custentName)
    $location = New-Object Autodesk.Connectivity.Explorer.Extensibility.LocationContext $selectionTypeId, $custentNumber
    $vaultContext.GoToLocation = $location    
}

#clean-up selection
$mSelItem = $null
$mOutFile = "mECOTabClick.txt"

$mSelItem | Out-File "$($env:appdata)\Autodesk\DataStandard 2024\$($mOutFile)"
	