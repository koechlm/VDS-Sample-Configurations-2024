# DISCLAIMER:
# ---------------------------------
# In any case, code, templates, and snippets of this solution are of "work in progress" character.
# Neither Markus Koechl, nor Autodesk represents that these samples are reliable, accurate, complete, or otherwise valid. 
# Accordingly, those configuration samples are provided as is with no warranty of any kind, and you use the applications at your own risk.


function InitializeBreadCrumb() {
	$mappedRootPath = $Prop["_VaultVirtualPath"].Value + $Prop["_WorkspacePath"].Value
	$mappedRootPath = $mappedRootPath -replace "\\", "/" -replace "//", "/"
	if ($mappedRootPath -eq '') {
		$mappedRootPath = '$'
	}

	$Global:CAx_Root = $mappedRootPath #we need the path for the ShortCut pane functions

	try {
		$rootFolder = $vault.DocumentService.GetFolderByPath($mappedRootPath)
		$root = New-Object PSObject -Property @{ Name = $rootFolder.Name; ID = $rootFolder.Id }
		$global:expandBreadCrumb = $false
		AddCombo -data $root
		$paths = $Prop["_SuggestedVaultPath"].Value.Split('\\', [System.StringSplitOptions]::RemoveEmptyEntries)
	}
	catch [System.Exception] {		
		[Autodesk.DataManagement.Client.Framework.Forms.Library]::ShowError($Error, "Vault VDS-Sample - Initialize Folder Selection")
	}		
		
	# Inventor shrinkwrap workflow; preset the breadcrumb for the given (shrinkwrap feature) path.
	if ($dsWindow.Name -eq "InventorWindow" -and !$paths -and $Document.ComponentDefinition.ReferenceComponents.ShrinkwrapComponents.Count -ne 0) {
		$mFilePath = $Document.FullFileName.Replace($Document.DisplayName, "")	
		$mWrkngFldr = $vaultConnection.WorkingFoldersManager.GetWorkingFolder("$")
		$mVaultPath = "$/" + $mFilePath.Replace($mWrkngFldr, "") -replace "\\", "/" -replace "//", "/"
		$mVaultPath = $mVaultPath.Replace($mappedRootPath, "")
		$paths = @()
		$paths += ($mVaultPath.Split("/", [System.StringSplitOptions]::RemoveEmptyEntries))
		$global:mShrnkWrp = $true
	}

	If (!$paths) { $paths = mReadLastUsedFolder }
	mActivateBreadCrumbCmbs $paths		
}

function mActivateBreadCrumbCmbs ($paths) {
	try {	
		$global:expandBreadCrumb = $false
		for ($i = 0; $i -lt $paths.Count; $i++) {
			$cmb = $dsWindow.FindName("cmbBreadCrumb_" + $i)
			if ($cmb -ne $null) { $cmb.SelectedValue = $paths[$i] }
		}
	}
	catch [System.Exception] {		
		[Autodesk.DataManagement.Client.Framework.Forms.Library]::ShowError($error, "VDS-Sample-Activate Folder Selection")
	}
}

function mReReadBreadCrumbs ($paths) {
	try {
		#unregister existing breadcrumbs'
		$breadCrumb = $dsWindow.FindName("BreadCrumb")
		$children = $breadCrumb.Children.Count - 1
		while ($children -ge 0 ) {
			$cmb = $breadCrumb.Children[$children]
			$breadCrumb.UnregisterName($cmb.Name) #reset the registration to avoid multiple registrations
			$breadCrumb.Children.Remove($cmb)
			$children--
		}	
		#read the latest available folders again
		$rootFolder = $vault.DocumentService.GetFolderByPath($Global:CAx_Root)
		$root = New-Object PSObject -Property @{ Name = $rootFolder.Name; ID = $rootFolder.Id }
		$global:expandBreadCrumb = $false
		AddCombo -data $root

		#activate the new selection
		mActivateBreadCrumbCmbs -paths $paths
	}
	catch [System.Exception] {		
		[Autodesk.DataManagement.Client.Framework.Forms.Library]::ShowError($Error, "Vault VDS-Sample - Re-Initializing Folder Selection")
	}	
}

function GetChildFolders($folder) {
	$ret = @()
	$folders = $vault.DocumentService.GetFoldersByParentId($folder.ID, $false)
	if ($folders -ne $null) {
		foreach ($item in $folders) {
			if (-Not $item.Cloaked) {
				$f = New-Object PSObject -Property @{ Name = $item.Name; ID = $item.Id }	
				$ret += $f
			}
		}
	}
	if ($ret.Count -gt 0) {
		$ret += New-Object PSObject -Property @{ Name = "."; ID = -1 }
	}
	return $ret
}

function GetFullPathFromBreadCrumb($breadCrumb) {
	$path = ""
	foreach ($crumb in $breadCrumb.Children) {
		$path += $crumb.SelectedItem.Name + "\"
	}
	return $path
}

function OnSelectionChanged($sender) {
	$breadCrumb = $dsWindow.FindName("BreadCrumb")
	$position = [int]::Parse($sender.Name.Split('_')[1]);
	$children = $breadCrumb.Children.Count - 1
	while ($children -gt $position ) {
		$cmb = $breadCrumb.Children[$children]
		$breadCrumb.UnregisterName($cmb.Name) #reset the registration to avoid multiple registrations
		$breadCrumb.Children.Remove($cmb)
		$children--
	}
	$path = GetFullPathFromBreadCrumb -breadCrumb $breadCrumb
	$Prop["Folder"].Value = $path
	AddCombo -data $sender.SelectedItem
}


function AddCombo($data) {
	if ($data.Name -eq '.' -or $data.Id -eq -1) {
		return
	}
	$children = GetChildFolders -folder $data
	if ($children -eq $null) { return }
	$breadCrumb = $dsWindow.FindName("BreadCrumb")
	$cmb = New-Object System.Windows.Controls.ComboBox
	$cmb.Name = "cmbBreadCrumb_" + $breadCrumb.Children.Count.ToString();
	$cmb.DisplayMemberPath = "Name"
	$cmb.SelectedValuePath = "Name"
	$cmb.ItemsSource = @($children)
	$cmb.IsDropDownOpen = $global:expandBreadCrumb
	$cmb.add_SelectionChanged({
			param($sender, $e)
			OnSelectionChanged -sender $sender
		});

	$breadCrumb.RegisterName($cmb.Name, $cmb) #register the name to activate later via indexed name
	$breadCrumb.Children.Add($cmb)
}

function mReadLastUsedFolder {
	#------------- The last used project folder is stored in a XML
	$m_File = "$($env:appdata)\Autodesk\DataStandard 2024\Folder2024.xml"
	if (Test-Path $m_File) {
		Try {
			$m_XML = New-Object XML 
			$m_XML.Load($m_File)

			$m_Vault = $m_XML.VDSUserProfile.Vaults.Vault | Where-Object { $_.Name -eq $vaultConnection.Vault }
			if ($m_Vault -eq $null) {
				#create the node for the current Vault
				$mVaultTemplate = $m_XML.VDSUserProfile.Vaults.Vault | Where-Object { $_.Name -eq "Template" }
				#clone the template completely and update name attribute
				$mNewVaultNode = $mVaultTemplate.Clone()
				#rename "Template" to new name
				$mNewVaultNode.Name = $vaultConnection.Vault
				#append the new node to the Vaults and save
				$mImpNode = $m_XML.ImportNode($mNewVaultNode, $true)
				$m_XML.VDSUserProfile.Vaults.AppendChild($mImpNode)
				$m_XML.Save($m_File)
				$m_Vault = $m_XML.VDSUserProfile.Vaults.Vault | Where-Object { $_.Name -eq $vaultConnection.Vault }
			}
			If ($dsWindow.Name -eq "InventorWindow") { $m_xmlNode = $m_Vault.get_Item("LastUsedFolderInv") }
			If ($dsWindow.Name -eq "AutoCADWindow") { $m_xmlNode = $m_Vault.get_Item("LastUsedFolderAcad") }

			$m_Attributes = $m_xmlNode.Attributes
			$m_PathNames = $null
			[System.Collections.ArrayList]$m_PathNames = @()
			foreach ($_Attrib in $m_Attributes) {
				if ($_Attrib.Value -ne "") {
					$m_PathNames += $_Attrib.Value
				}
				Else { break; }	
			}
			if ($m_PathNames.Count -eq 1) { 
				$m_PathNames += "."
			}
		
			return $m_PathNames
		}
		catch {
			[Autodesk.DataManagement.Client.Framework.Forms.Library]::ShowError("Error reading last used folder info", "VDS Sample Configuration")
		}
		
	}
}

function mWriteLastUsedFolder {
	$m_File = "$($env:appdata)\Autodesk\DataStandard 2024\Folder2024.xml"
	if (Test-Path $m_File) {
		try {
			$m_XML = New-Object XML 
			$m_XML.Load($m_File)

			$m_Vault = $m_XML.VDSUserProfile.Vaults.Vault | Where-Object { $_.Name -eq $vaultConnection.Vault }
			If ($dsWindow.Name -eq "InventorWindow") { $m_xmlNode = $m_Vault.get_Item("LastUsedFolderInv") }
			If ($dsWindow.Name -eq "AutoCADWindow") { $m_xmlNode = $m_Vault.get_Item("LastUsedFolderAcad") }

			$m_Attributes = $m_xmlNode.Attributes
			$m_Attributes.RemoveAll()
			$breadCrumb = $dsWindow.FindName("BreadCrumb")
			foreach ($cmb in $breadCrumb.Children) {
				if (!($cmb.SelectedItem.Name -eq "") -and !($cmb.SelectedItem.Name -eq ".")) {
					$m_AttribKey = $cmb.Name
					$m_AttribVal = $cmb.SelectedItem.Name
					$m_xmlNode.SetAttribute($m_AttribKey, $m_AttribVal)
				}	
			}
			$m_XML.Save("$($env:appdata)\Autodesk\DataStandard 2024\Folder2024.xml")
		}
		catch [System.Exception] {		
			[Autodesk.DataManagement.Client.Framework.Forms.Library]::ShowError("Error saving last used folder info", "VDS Sample Configuration")
		}
	}
}

