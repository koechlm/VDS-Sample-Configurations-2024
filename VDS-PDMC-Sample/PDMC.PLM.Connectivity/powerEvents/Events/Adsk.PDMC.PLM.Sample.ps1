#==============================================================================#
# (c) 2017 coolOrange s.r.l.                                                   #
#                                                                              #
# THIS SCRIPT/CODE IS PROVIDED "AS IS" WITHOUT WARRANTY OF ANY KIND, EITHER    #
# EXPRESSED OR IMPLIED, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED WARRANTIES  #
# OF MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE, OR NON-INFRINGEMENT.   #
#==============================================================================#

# To enable/disable the restriction of Lifecycle state changes to Files, Items and Change Orders which have been modified by different Vault users, comment/un-comment the following lines.
#Register-VaultEvent -EventName UpdateFileStates_Restrictions -Action $validateProperties
#Register-VaultEvent -EventName UpdateItemStates_Restrictions -Action $validateProperties
#Register-VaultEvent -EventName UpdateChangeOrderState_Restrictions -Action $validatePropertiesForChangeOrder
Register-VaultEvent -EventName CommitItems_Post -Action 'UpdatePLM'
Register-VaultEvent -EventName UpdateFileStates_Post -Action 'PostUpdateFileStates'

function PostUpdateFileStates($files, $successful) {
	if ($successful) {
		#Reference Item Service
		$ItemSvc = $vault.ItemService

		#Create new item and commit
		$updatedItems = @()
		[Autodesk.Connectivity.WebServices.ItemsAndFiles]$mPromoteResult = $null
		$mPromoteFailed = $false
		$mAssignAll = [Autodesk.Connectivity.WebServices.ItemAssignAll]::No
		$mFileIdsToPromote = @()
		foreach ($file in $files) {
			$mFileIdsToPromote += $file.Id
		}
		try {
			$ItemSvc.AddFilesToPromote($mFileIdsToPromote, $mAssignAll, $true)
			[datetime]$mTimeStamp = Get-Date

			[Autodesk.Connectivity.WebServices.GetPromoteOrderResults]$mPromoteOrder = $ItemSvc.GetPromoteComponentOrder([ref]$mTimeStamp)
			if ($mPromoteOrder.PrimaryArray -ne $null -and $mPromoteOrder.PrimaryArray.Length -ne $null) {
				try {
					$ItemSvc.PromoteComponents($mTimeStamp, $mPromoteOrder.PrimaryArray)
				}
				catch {
					$mPromoteFailed = $true
				}
			}
			if ($mPromoteOrder.NonPrimaryArray -ne $null -and $mPromoteOrder.NonPrimaryArray.Length -ne $null) {
				try {
					$ItemSvc.PromoteComponents($mTimeStamp, $mPromoteOrder.NonPrimaryArray)
				}
				catch {
					$mPromoteFailed = $true
				}
			}
			try {
				if ($mPromoteFailed -ne $true) {
					$mPromoteResult = $ItemSvc.GetPromoteComponentsResults($mTimeStamp)
					if ($mPromoteResult.ItemRevArray[0].Locked -ne $true) {
						$updatedItems = $mPromoteResult.ItemRevArray
						$mCurrentItem = $mPromoteResult.ItemRevArray[0]
						$mItemToUpdateCommit = @()
						$mItemToUpdateCommit += $mCurrentItem;
						#commit the changes for the root element only; the reason is as stated before for ItemAssignAll = No
						$ItemSvc.UpdateAndCommitItems($mItemToUpdateCommit);
					}
					else {
						# feedback that the current item assignable already exists and is locked by another process
					}
				}
			}
			catch {
				# is something unhandled left?
			}
		}
		catch {
			if ($updatedItems -ne $null -and $updatedItems.Length > 0) {
				$itemIds = @()
				for ($i = 0; $i -lt $updatedItems.Length; $i++) {
					$itemIds += $updatedItems[$i].Id
				}
				$ItemSvc.UndoEditItems($itemIds)
			}
		}
		finally {
			if ($mPromoteResult -eq $null -and $mPromoteFailed -ne $true) {
				# clear out the promoted item
				$ItemSvc.DeleteUnusedItemNumbers(@($mPromoteResult.ItemRevArray[0].MasterId))
				$ItemSvc.UndoEditItems(@($mPromoteResult.ItemRevArray[0].MasterId))
			}
			if ($mPromoteFailed -eq $true) {
				# feedback that current item might be in edit by another process/user
			}
		}
	}
}


$validateProperties = {
	param(
		$files = @(),
		$items = @()
	)	
	$releasedEntities = @( ($files + $items) | where {
			$newLifecycleState = Get-VaultLifecycleState -LifecycleDefinition $_._NewLifeCycleDefinition -State $_._NewState
			$newLifecycleState.ReleasedState -eq $true
		})

	foreach ( $entity in $releasedEntities ) {
		$lastModifyUser = $null
		if ($entity._EntityType.ServerId -eq "FILE") { 
			$lastModifyUser = $entity._CreateUserName  
		}
		else {
			$lastModifyUser = $entity._LastModifiedUserName
		} 
		$currentUserName = $vault.AdminService.GetUserByUserId($vaultConnection.UserID) | Select-Object -ExpandProperty 'Name'
		if ($lastModifyUser -ne $currentUserName) {
			Add-VaultRestriction -EntityName ($entity._Name) -Message "The state can only be changed to '$($entity._NewState)' by the user who last modified the $($entity._EntityType) (User:  $lastModifyUser)."
		}
	}
}

$validatePropertiesForChangeOrder = {
	param(
		$changeOrder,
		$activity
	)
	$isChangeOrderClosing = (Get-VaultActivity $changeOrder $activity).Name -eq 'Set Effectivity'
	
	if ($isChangeOrderClosing) {
		$lastModifyUser = $changeOrder._LastModifiedUserName
		$currentUserName = $vault.AdminService.GetUserByUserId($vaultConnection.UserID) | Select-Object -ExpandProperty 'Name'
		if ($lastModifyUser -ne $currentUserName) {
			Add-VaultRestriction -EntityName ($changeOrder._Name) -Message "The activity '$activity' can only be accomplished by the user who last modified the ChangeOrder (User:  $lastModifyUser)."
		}
	}
}

function UpdatePLM($items, $successful) {
	if ($successful) {
		foreach ($item in $items) {
			$jobParameters = @{
				"EntityId"      = $item.Id
				"EntityClassId" = $item._EntityTypeID
			}
			Add-VaultJob -Name "Adsk.PDMC.PLM.Sample.UploadItem" -Description "Creates/Updates PLM Item $($item._Number)" -Priority 5 -Parameters $jobParameters 
		} 
	}
}