#region disclaimer
#=============================================================================
# PowerShell script sample for Vault Data Standard                            
#                                                                             
# Copyright (c) Autodesk, Markus Koechl - All rights reserved.                               
#                                                                             
# THIS SCRIPT/CODE IS PROVIDED "AS IS" WITHOUT WARRANTY OF ANY KIND, EITHER   
# EXPRESSED OR IMPLIED, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED WARRANTIES 
# OF MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE, OR NON-INFRINGEMENT.  
#=============================================================================
#endregion

Add-Type @'
public class mSchedTask
{
	public string SyncType;
	public string Description;
}
'@

function ADSK.QS.ReadSchedTasks()
{
	#$dsDiag.Trace("Reading Scheduled Sync Tasks")
	$Global:mSchedJobs = $vault.JobService.GetScheduledJobs()
	#Filter Scheduled Jobs according current Vault
	$VaultName = $VaultConnection.Vault
	$mVaultId = ($vault.FileStoreVaultService.GetKnowledgeVaultByName($VaultName)).Id
	$Global:mSchedJobs = $Global:mSchedJobs | Where-Object { $_.VaultId -eq $mVaultId} 
	
	$mSchedTasksAll = @()
	$Global:mSchedJobs | ForEach-Object {
		$mSchedTask= New-Object mSchedTask
		$mSchedTask.SyncType = $_.Typ
		$mSchedTask.Description = $_.Descr
		$mSchedTasksAll += $mSchedTask
	}
	$dsWindow.FindName("dataGrdSchedTasks").ItemsSource = $mSchedTasksAll
}

function ADSK.QS.TaskSelectionChanged()
{
	#$dsDiag.Trace("Task Selection Changed")
	If($dsWindow.FindName("dataGrdSchedTasks").SelectedItem)
	{
		$dsWindow.FindName("btnActivateSchedTask").IsEnabled = $true
	}
	Else{ $dsWindow.FindName("btnActivateSchedTask").IsEnabled = $false }
}

function ADSK.QS.ActivateSchedTask()
{
	$mSchedJobSelected = @()
	$mJobsForQueue = @()
	$mSchedJobSelected += $dsWindow.FindName("dataGrdSchedTasks").SelectedItems
	foreach ($item in $mSchedJobSelected)
	{
	   $mJobsForQueue += $Global:mSchedJobs | Where-Object {
					$_.Descr -eq $item.Description
				}
	}
	foreach ($mJobItem in  $mJobsForQueue)
	{
		$mSchedJobParam1 =  New-Object Autodesk.Connectivity.WebServices.JobParam
		$mSchedJobParams = @()
		$mSchedJobParam1.Name = $mJobItem.ParamArray[0].Name
		$mSchedJobParam1.Val = $mJobItem.ParamArray[0].Val
		$mSchedJobParams += $mSchedJobParam1
		$mSchedJobParam2 =  New-Object Autodesk.Connectivity.WebServices.JobParam
		$mSchedJobParam2.Name = $mJobItem.ParamArray[1].Name
		$mSchedJobParam2.Val = $mJobItem.ParamArray[1].Val
		$mSchedJobParams += $mSchedJobParam2
		$mSchedJobId = $mJobItem.Id

		$mJobParams = @()
		$mJobParamSyncJob1 = New-Object Autodesk.Connectivity.WebServices.JobParam
		$mJobParamSyncJob1.Name = $mSchedJobParams[0].Name
		$mJobParamSyncJob1.Val = $mSchedJobParams[0].Val
		#add Param[0]
		$mJobParams += $mJobParamSyncJob1
				
		$mJobParamSyncJob2 = New-Object Autodesk.Connectivity.WebServices.JobParam
		$mJobParamSyncJob2.Name = $mSchedJobParams[1].Name
		$mJobParamSyncJob2.Val = $mSchedJobParams[1].Val
		#add Param[1]
		$mJobParams += $mJobParamSyncJob2

		$mJobParamSyncJob3 = New-Object Autodesk.Connectivity.WebServices.JobParam
		$mJobParamSyncJob3.Name = "ScheduledJobID"
		$mJobParamSyncJob3.Val = $mSchedJobId
		#add Param[2]
		$mJobParams += $mJobParamSyncJob3

		Try{
				$vault.JobService.AddJob($mJobItem.Typ, "(Enforced Now): " + $mJobItem.Descr, $mJobParams, 1)
			}
		catch [System.Exception]
		{		
			[Autodesk.DataManagement.Client.Framework.Forms.Library]::ShowError($error, $UIString["ADSK-ActivateSchedTask-00"])
		}
	}
	$dsWindow.FindName("btnActivateSchedTask").IsEnabled = $false
}