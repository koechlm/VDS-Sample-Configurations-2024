#==============================================================================#
# (c) 2023 coolOrange s.r.l.                                                   #
#                                                                              #
# THIS SCRIPT/CODE IS PROVIDED "AS IS" WITHOUT WARRANTY OF ANY KIND, EITHER    #
# EXPRESSED OR IMPLIED, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED WARRANTIES  #
# OF MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE, OR NON-INFRINGEMENT.   #
#==============================================================================#

# Required in the powerJobs Settings Dialog to determine the entity type for lifecycle state change triggers
# JobEntityType = CO

Import-Module powerFLC

Write-Host "Starting job '$($job.Name)'..."
$stopwatch = [System.Diagnostics.Stopwatch]::StartNew()

Write-Host "Connecting to Fusion 360 Manage..."
$connected = Connect-FLC -UseSystemUserEmail
if (-not $connected) {
    throw "Connection to Fusion 360 Manage failed! Error: `n $($connected.Error.Message)`n See '$($env:LOCALAPPDATA)\coolOrange\powerFLC\Logs\powerFLC.log' for details"
}
if (-not $workflow) {
    throw "Cannot find workflow configuration with name '$($job.Name)'"
}
$workspace = $flcConnection.Workspaces.Find($workflow.FlcWorkspace)
if (-not $workspace) {
    throw "Workspace $($workflow.FlcWorkspace) cannot be found!"
}
Write-Host "Connected to $($flcConnection.Url) - Workspace: $($workspace.Name)"

$entityUrns = $vault.PropertyService.FindEntityAttributes("FLC.ITEM", "Urn")
$states = @($workspace.WorkflowActions.FromState; $workspace.WorkflowActions.ToState) | Sort-Object -Property * -Unique

$triggerState = $workflow.Settings.'Trigger State'
$lifecycleTransition = $workflow.Settings.'Affected Items Lifecycle Transition'
$workflowAction = $workflow.Settings.'Workflow Action'
$workflowAction1 = $workflow.Settings.'Workflow Acknowledge'
$attachmentsFolder = $workflow.Settings.'Vault Attachments Folder'

if (-not ($states | Where-Object { $_.Name -eq $triggerState })) {
    throw "The configured 'Trigger State'='$triggerState' is not available in the workspace '$($workspace.Name)'"
}
#if (-not ($workspace.LifecycleTransitions | Where-Object { $_.Name -eq $lifecycleTransition })) {
#    throw "The configured 'Affected Items Lifecycle Transition'='$lifecycleTransition' is not available in the workspace '$($workspace.Name)'"
#}
if (-not ($workspace.WorkflowActions | Where-Object { $_.Name -eq $workflowAction })) {
    throw "The configured 'Workflow Action'='$workflowAction' is not available in the workspace '$($workspace.Name)'"
}
if (-not $workflow.Mappings | Where-Object { $_.Name -eq "Item Field Mapping" }) {
    throw "Cannot find mapping configuration for mapping 'Item Field Mapping'"
}
try {
    $vault.DocumentService.GetFolderByPath($attachmentsFolder) | Out-Null
} catch {
    throw "The configured 'Vault Attachments Folder'='$attachmentsFolder' does not exist in Vault"
}
$tempDirectory = "C:\TEMP"

function TimeTriggeredJob{
    $flcChangeOrders = Get-FLCItems -Workspace $workspace.Name -Filter "workflowState=`"$triggerState`""
    Write-Host "$($flcChangeOrders.Count) Change Order item(s) retrieved"

    foreach ($flcChangeOrder in $flcChangeOrders) {
        $flcChangeOrderId = $flcChangeOrder.($workflow.FlcUnique)
        Write-Host "Processing item '$flcChangeOrderId'"

        #create Vault ECOs for Engineering tasks only
        if ($flcChangeOrder.'Engineering Activity' -ne "Yes"){ continue}

        $workingDirectory = Join-Path -Path $tempDirectory -ChildPath $flcChangeOrderId

        $affectedItemsInVault = @()
        $affectedItemsNotInVault = @()
		
		#$relatedItems = $flcChangeOrder | Get-FLCItemAssociations -RelatedItems
		
		#Write-Host "$($relatedItems.Count)"

        $affectedItems = $flcChangeOrder | Get-FLCItemAssociations -AffectedItems
        Write-Host "$($affectedItems.Count) affected item(s) received from Fusion 360 Manage"
        foreach ($flcItem in $affectedItems) {
            $workspaceId = $flcConnection.Workspaces.Find($flcItem.Workspace).Id
            $itemVersionUrns = GetFLCItemVersionUrns -workspace $workspaceId -ItemId $flcItem.Id
            $existingItem = $entityUrns | Where-Object { $_.Val -in $itemVersionUrns } | Select-Object -First 1

            if ($existingItem) {
                $affectedItemsInVault += (Get-VaultItem -ItemId $existingItem.EntityId)._Number
            } else {
                $affectedItemsNotInVault += $flcItem.Number #TODO: change the field 'Number' if not present in your items workspace!
            }
        }

        $attachments = $flcChangeOrder | Get-FLCItemAssociations -Attachments
        Write-Host "$($attachments.Count) attachment(s) received from Fusion 360 Manage"
        $attachmentFileNames = @()
        foreach ($attachment in $attachments) {
            $downloadedFile = $attachment | Save-FLCAttachment -DownloadPath $workingDirectory
            $destinationFullFileName = "$attachmentsFolder/$($flcChangeOrder.$($workflow.FlcUnique))/$($attachment.FileName)"
            $uploadedFile = Add-VaultFile -From $downloadedFile.FullName -To $destinationFullFileName -Force $true
            Write-Host "$($uploadedFile._Name) added to Vault"
            $attachmentFileNames += $uploadedFile._FullPath
        }

        $co = Get-VaultChangeOrder -Number $flcChangeOrder.$($workflow.FlcUnique)
        if(-not $co){
            $co = Add-VaultChangeOrder -Number $flcChangeOrder.$($workflow.FlcUnique)
            $createComment = $true
        }

        $urn = "urn:adsk.plm:tenant.workspace.item:$($flcConnection.Tenant.ToUpper()).$($workspace.Id).$($flcChangeOrder.Id)"
        $vault.PropertyService.SetEntityAttribute($co.Id, "FLC.ITEM", "Urn", $urn)

        $mapping = $workflow.Mappings | Where-Object { $_.Name -eq "Item Field Mapping" }
		$properties = GetMappedVaultChangeOrderValuesFromFlcItem -Mapping $mapping -FLCItem $flcChangeOrder
		$co = Update-VaultChangeOrder -Number $co._Number -ItemRecords $affectedItemsInVault -Attachments $attachmentFileNames @properties

        if ($affectedItemsNotInVault -and $createComment) {
            $message = ([String]::Join([Environment]::NewLine, $affectedItemsNotInVault))
            Add-VaultChangeOrderComment -ChangeOrderName $co._Number -Title "Affected Items not in Vault" -Message $message
            Write-Host "Affected Items not in Vault: $message"
        }

        $updateResult = $flcChangeOrder | Update-FLCItem -WorkflowAction $workflowAction1 -Comment "Updated by powerPLM"
    }
}

function ECOStateChangeJobs {
    Write-Host "Synchronizing $($workspace.Name) - triggered by state change of Vault ECO '$($changeOrder._Number)'"
    $changeOrderUrn = $entityUrns | Where-Object { $_.EntityId -eq $changeOrder.MasterId }
    if (-not $changeOrderUrn) {
        Write-Host "Vault ECO '$($changeOrder.Number)' is not tracked by Fusion 360 Manage!"
        return
    }
    $flcChangeOrder = (Get-FLCItems -Workspace $workspace.Name -Filter "itemId=$(GetFLCItemIdFromUrn -Urn $changeOrderUrn.Val)")[0]
    if (-not $flcChangeOrder) {
        throw "Couldn't find Fusion 360 Manage item with urn='$($changeOrderUrn.Val)' for Vault ECO '$($changeOrder._Number)'"
    }

    $vaultChangeOrderItemRecords = Get-VaultChangeOrderAssociations -Number $changeOrder._Number -Type ItemRecords
    Write-Host "$($vaultChangeOrderItemRecords.Count) item record(s) retrieved from Vault"

    if ($vaultChangeOrderItemRecords) {
		$flcChangeOrderAffectedItems = $flcChangeOrder | Get-FLCItemAssociations -AffectedItems
		Write-Host "$($flcChangeOrderAffectedItems.Count) affected item(s) retrieved from Fusion 360 Manage"
        foreach($vaultItemRecord in $vaultChangeOrderItemRecords) {
            $vaultItemRecordUrn = $entityUrns | Where-Object { $_.EntityId -eq $vaultItemRecord.MasterId }[0]
            if (-not $vaultItemRecordUrn) {
				Write-Host "This Vault ECO's item record $($vaultItemRecord._Number) is not present as Fusion 360 Manage item!"
				continue
			}
			$id = GetFLCItemIdFromUrn -Urn $vaultItemRecordUrn.Val
			$workspaceId = GetFLCWorkspaceIdFromUrn -Urn $vaultItemRecordUrn.Val
            $flcItem = (Get-FLCItems -Workspace $flcConnection.Workspaces[$workspaceId].Name -Filter "itemId=$($id)")[0]

			if (-not ($flcChangeOrderAffectedItems | Where-Object { $_.RootId -eq $flcItem.RootId})) {
				Write-Host "Additional item record found in Vault: $($vaultItemRecord._Number). Adding it to Fusion 360 Manage as affected item..."
				$flcChangeOrderAffectedItems += @{
                    "Id" = $flcItem.Id
                    "Workspace" = $flcItem.Workspace
                   # "LinkedItem_LifecycleTransition" = $lifecycleTransition
                }
			}
        }
        $updateResult = $flcChangeOrder | Update-FLCItem -AffectedItems $flcChangeOrderAffectedItems
        #Show-Inspector('updateResult')
        #if(-not $updateResult) {
            #throw "Cannot add additional affected items to Fusion 360 Manage. Reason: $($Error[0].Exception)"
        #}
    } else {
        Write-Host "No item records found for Vault ECO $($changeOrder._Number)"
    }

    $updateResult = $flcChangeOrder | Update-FLCItem -WorkflowAction $workflowAction -Comment "Updated by powerPLM"
    #if(-not $updateResult){
        #throw "Cannot perform workflow action in Fusion 360 Manage. Reason: $($Error[0].Exception)"
    #}
}

if (-not $changeOrder) {
    TimeTriggeredJob
}else{
    ECOStateChangeJobs
}

$stopwatch.Stop()
Write-Host "Completed job '$($job.Name)' in $([int]$stopwatch.Elapsed.TotalSeconds) Seconds"