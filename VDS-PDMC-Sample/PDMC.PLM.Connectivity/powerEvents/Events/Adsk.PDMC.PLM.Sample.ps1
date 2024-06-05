#==============================================================================#
# (c) 2017 coolOrange s.r.l.                                                   #
#                                                                              #
# THIS SCRIPT/CODE IS PROVIDED "AS IS" WITHOUT WARRANTY OF ANY KIND, EITHER    #
# EXPRESSED OR IMPLIED, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED WARRANTIES  #
# OF MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE, OR NON-INFRINGEMENT.   #
#==============================================================================#

Import-Module powerFLC
#Register-VaultEvent -EventName CommitItems_Post -Action 'AddJob_UploadPlmItem'
Register-VaultEvent -EventName UpdateFileStates_Post -Action 'AssignUpdateItem'
Register-VaultEvent -EventName AddFile_Post -Action 'AssignUpdateItem'
#Register-VaultEvent -EventName CheckinFile_Post -Action 'AssignUpdateItem'

function AssignUpdateItem {
	param($file, $parentFolder, $successful)

	if (-not $successful) { return }
	$files = @()
	$files += $file
	#todo: exclude categories that must not get an item assigned and would fail
	$excludeCategories = @("Reference", "Phantom", "Substitute")
	if (-not $excludeCategories -contains $file._Category) {
		CreateItemAndCommit $files $true
	}
	#-validate to create PLM Item immediatly

}

function CreateItemAndCommit($files, $successful) {
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
			if ($null -ne $mPromoteOrder.PrimaryArray -and $null -ne $mPromoteOrder.PrimaryArray.Length) {
				try {
					$ItemSvc.PromoteComponents($mTimeStamp, $mPromoteOrder.PrimaryArray)
				}
				catch {
					$mPromoteFailed = $true
				}
			}
			if ($null -ne $mPromoteOrder.NonPrimaryArray -and $null -ne $mPromoteOrder.NonPrimaryArray.Length) {
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
			if ($null -ne $updatedItems -and $updatedItems.Length -gt 0) {
				$itemIds = @()
				for ($i = 0; $i -lt $updatedItems.Length; $i++) {
					$itemIds += $updatedItems[$i].Id
				}
				$ItemSvc.UndoEditItems($itemIds)
			}
		}
		finally {
			if ($null -eq $mPromoteResult -and $mPromoteFailed -ne $true) {
				# clear out the promoted item
				if ($null -ne $mPromoteResult.ItemRevArray) {
					$ItemSvc.DeleteUnusedItemNumbers(@($mPromoteResult.ItemRevArray[0].MasterId))
					$ItemSvc.UndoEditItems(@($mPromoteResult.ItemRevArray[0].MasterId))<# Action to perform if the condition is true #>
				}
			}
			if ($mPromoteFailed -eq $true) {
				# feedback that current item might be in edit by another process/user
			}
		}
	}
}

function AddJob_UploadPlmItem($items, $successful) {
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