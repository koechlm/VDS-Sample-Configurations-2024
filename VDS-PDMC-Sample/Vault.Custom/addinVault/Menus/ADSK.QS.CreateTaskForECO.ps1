# DISCLAIMER:
# ---------------------------------
# In any case, code, templates, and snippets of this solution are of "work in progress" character.
# Neither Markus Koechl, nor Autodesk represents that these samples are reliable, accurate, complete, or otherwise valid. 
# Accordingly, those configuration samples are provided as is with no warranty of any kind, and you use the applications at your own risk.


#register the current CO context
$vaultContext.ForceRefresh = $true
$selectionSet = $vaultContext.CurrentSelectionSet[0]
$mCoId = $selectionSet.Id

#create a new task, add a link from current CO to it and open for edit
$CustEntSrvc = $vault.CustomEntityService
$mEntityDefs = $CustEntSrvc.GetAllCustomEntityDefinitions()
$mEntDefId = ($mEntityDefs | Where-Object { $_.DispName -eq "Task" }).Id

#create a numbered name for the new task
[System.Collections.ArrayList]$numSchems = @($vault.NumberingService.GetNumberingSchemes('FILE', 'Activated'))
$ns = $numSchems | Where-Object { $_.Name.Equals("ECO-Task") }
if ($ns -ne $null) {
	$NumGenArgs = @($selectionSet.Label)
	$mTaskName = $vault.DocumentService.GenerateFileNumber($ns.SchmID, $NumGenArgs)
}
else {
	$mTaskName = "ECO-Task" #create new number consuming numbering scheme "ECO-Task" if found
}

[Autodesk.Connectivity.WebServices.CustEnt]$task = $CustEntSrvc.AddCustomEntity($mEntDefId, $mTaskName)
$link = $vault.DocumentService.AddLink($task.Id, "CO", $mCoId, "Parent->Child")

$dialog = $dsCommands.GetEditCustomObjectDialog($task.id)
$XamlFile = New-Object CreateObject.WPF.XamlFile "ADSK.QS.CustomObject.xaml", "C:\ProgramData\Autodesk\Vault 2024\Extensions\DataStandard\Vault.Custom\Configuration\ADSK.QS.CustomObject.xaml"
$dialog.XamlFile = $XamlFile

#show the custom object edit dialog
$result = $dialog.Execute()
if ($result) {
	try {
		$contactID = Get-Content "$($env:appdata)\Autodesk\DataStandard 2024\mPersonId.txt"
		if ($contactID -ne $null) { $link3 = $vault.DocumentService.AddLink($dialog.CurrentEntity.Id, "CUSTENT", $contactID, "Task->Person") }
	}
	catch {
		$dsDiag.Trace("CreateTaskForECO.ps1 - AddLink command failed") 
	}
}

#in case cancel / close Window (Window button X), remove last entries as well...
$null | Out-File "$($env:appdata)\Autodesk\DataStandard 2024\mOrganisationId.txt"
$null | Out-File "$($env:appdata)\Autodesk\DataStandard 2024\mPersonId.txt"





