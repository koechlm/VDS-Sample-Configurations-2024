
function InitializeWindow
{
	#begin rules applying commonly
    $dsWindow.Title = SetWindowTitle		
    InitializeCategory
    InitializeNumSchm
    InitializeBreadCrumb
    InitializeFileNameValidation
	#end rules applying commonly
	$mWindowName = $dsWindow.Name
	switch($mWindowName)
	{
		"InventorWindow"
		{
			#rules applying for Inventor
		}
		"AutoCADWindow"
		{
			#rules applying for AutoCAD
		}
	}
	$global:expandBreadCrumb = $true	
}

function AddinLoaded
{
	#Executed when DataStandard is loaded in Inventor/AutoCAD
}

function AddinUnloaded
{
	#Executed when DataStandard is unloaded in Inventor/AutoCAD
}

function InitializeCategory()
{
    if ($Prop["_CreateMode"].Value)
    {
		if (-not $Prop["_SaveCopyAsMode"].Value)
		{
            $Prop["_Category"].Value = $UIString["CAT1"]
        }
    }
}

function InitializeNumSchm()
{
	#Adopted from a DocumentService call, which always pulls FILE class numbering schemes
	$global:numSchems = @($vault.NumberingService.GetNumberingSchemes('FILE', 'Activated')) 
    if ($Prop["_CreateMode"].Value)
    {
		if (-not $Prop["_SaveCopyAsMode"].Value)
		{
			$Prop["_Category"].add_PropertyChanged({
				if ($_.PropertyName -eq "Value")
				{
					$numSchm = $numSchems | where {$_.Name -eq $Prop["_Category"].Value}
                    if($numSchm)
					{
                        $Prop["_NumSchm"].Value = $numSchm.Name
                    }
				}	
			})
        }
		else
        {
            $Prop["_NumSchm"].Value = "None"
        }
    }
}

function GetVaultRootFolder()
{
    $mappedRootPath = $Prop["_VaultVirtualPath"].Value + $Prop["_WorkspacePath"].Value
    $mappedRootPath = $mappedRootPath -replace "\\", "/" -replace "//", "/"
    if ($mappedRootPath -eq '')
    {
        $mappedRootPath = '$'
    }
    return $vault.DocumentService.GetFolderByPath($mappedRootPath)
}

function SetWindowTitle
{
	$mWindowName = $dsWindow.Name
    switch($mWindowName)
 	{
  		"InventorFrameWindow"
  		{
   			$windowTitle = $UIString["LBL54"]
  		}
  		"InventorDesignAcceleratorWindow"
  		{
   			$windowTitle = $UIString["LBL50"]
  		}
  		"InventorPipingWindow"
  		{
   			$windowTitle = $UIString["LBL39"]
  		}
  		"InventorHarnessWindow"
  		{
   			$windowTitle = $UIString["LBL44"]
  		}
  		default #applies to InventorWindow and AutoCADWindow
  		{
   			if ($Prop["_CreateMode"].Value)
   			{
    			if ($Prop["_CopyMode"].Value)
    			{
     				$windowTitle = "$($UIString["LBL60"]) - $($Prop["_OriginalFileName"].Value)"
    			}
    			elseif ($Prop["_SaveCopyAsMode"].Value)
    			{
     				$windowTitle = "$($UIString["LBL72"]) - $($Prop["_OriginalFileName"].Value)"
    			}else
    			{
     				$windowTitle = "$($UIString["LBL24"]) - $($Prop["_OriginalFileName"].Value)"
    			}
   			}
   			else
   			{
    			$windowTitle = "$($UIString["LBL25"]) - $($Prop["_FileName"].Value)"
   			} 
  		}
 	}
  	return $windowTitle
}

function GetNumSchms
{
	$specialFiles = @(".DWG",".IDW",".IPN")
    if ($specialFiles -contains $Prop["_FileExt"].Value -and !$Prop["_GenerateFileNumber4SpecialFiles"].Value)
    {
        return $null
    }
	if (-Not $Prop["_EditMode"].Value)
    {
		if ($numSchems.Count -gt 1)
		{
			$numSchems = $numSchems | Sort-Object -Property IsDflt -Descending
		}
        if ($Prop["_SaveCopyAsMode"].Value)
        {
            $noneNumSchm = New-Object 'Autodesk.Connectivity.WebServices.NumSchm'
            $noneNumSchm.Name = $UIString["LBL77"]
            return $numSchems += $noneNumSchm
        }    
        return $numSchems
    }
}

function GetCategories
{
	return $Prop["_Category"].ListValues
}

function OnPostCloseDialog
{
	$mWindowName = $dsWindow.Name
	switch($mWindowName)
	{
		"InventorWindow"
		{
			#rules applying for Inventor
		}
		"AutoCADWindow"
		{
			#rules applying for AutoCAD
			if ($Prop["_CreateMode"]) {
				#the default ACM Titleblocks expect the file name and drawing number as attribute values; adjust property(=attribute) names for custom titleblock definitions
				$dc = $dsWindow.DataContext
				$Prop["GEN-TITLE-DWG"].Value = $dc.PathAndFileNameHandler.FileName
				$Prop["GEN-TITLE-NR"].Value = $dc.PathAndFileNameHandler.FileNameNoExtension
			}
		}
		default
		{
			#rules applying commonly
		}
	}
}
