#$vaultContext.ForceRefresh = $true
$selectionSet = $vaultContext.CurrentSelectionSet[0]
$id= $selectionSet.Id
$dialog = $dsCommands.GetCreateCustomObjectDialog($id)

#override the default dialog file assigned
$xamlFile = New-Object CreateObject.WPF.XamlFile "ADSK.QS.CustomObject.xaml", "C:\ProgramData\Autodesk\Vault 2024\Extensions\DataStandard\Vault.Custom\Configuration\ADSK.QS.CustomObject.xaml"
$dialog.XamlFile = $xamlFile

$result = $dialog.Execute()
#$dsDiag.Trace($result)

if ($result)
{
	$entityNumber = $dialog.CurrentEntity.Num
	$entityGuid = $selectionSet.TypeId.EntityClassSubType
	$selectionTypeId = New-Object Autodesk.Connectivity.Explorer.Extensibility.SelectionTypeId $entityGuid
	$location = New-Object Autodesk.Connectivity.Explorer.Extensibility.LocationContext $selectionTypeId, $entityNumber
	$vaultContext.GoToLocation = $location
}