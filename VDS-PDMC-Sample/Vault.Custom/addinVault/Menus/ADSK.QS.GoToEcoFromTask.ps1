# DISCLAIMER:
# ---------------------------------
# In any case, code, templates, and snippets of this solution are of "work in progress" character.
# Neither Markus Koechl, nor Autodesk represents that these samples are reliable, accurate, complete, or otherwise valid. 
# Accordingly, those configuration samples are provided as is with no warranty of any kind, and you use the applications at your own risk.


$entityId = $vaultContext.CurrentSelectionSet[0].Id

$links = $vault.DocumentService.GetLinksByParentIds(@($entityId), @("CO"))
[Autodesk.Connectivity.WebServices.ChangeOrder[]]$mECOs = @()
[Autodesk.Connectivity.WebServices.ChangeOrder[]]$mECOs = $vault.ChangeOrderService.GetChangeOrdersByIds(@($links[0].ToEntId))

if ($mECOs.Count -eq 0) {
    $result = [Autodesk.DataManagement.Client.Framework.Forms.Library]::ShowWarning("This Task is not linked with an ECO. Do you want to switch to Change Orders though?", "ECO-Tasks", "OKCancel")
    if ($result -eq "OK") {
        $selectionTypeId = [Autodesk.Connectivity.Explorer.Extensibility.SelectionTypeId]::ChangeOrder
        $location = New-Object Autodesk.Connectivity.Explorer.Extensibility.LocationContext $selectionTypeId, $path
        $vaultContext.GoToLocation = $location
    }
}
else {
    $path = $mECOs[0].Num
    $selectionTypeId = [Autodesk.Connectivity.Explorer.Extensibility.SelectionTypeId]::ChangeOrder
    $location = New-Object Autodesk.Connectivity.Explorer.Extensibility.LocationContext $selectionTypeId, $path
    $vaultContext.GoToLocation = $location           
}

	