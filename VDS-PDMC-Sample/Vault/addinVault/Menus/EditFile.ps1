
$vaultContext.ForceRefresh = $true
$currentSelected = $vaultContext.CurrentSelectionSet[0]
$fileId=$currentSelected.Id
$dialog = $dsCommands.GetEditDialog($fileId)
$dialog.Execute()

