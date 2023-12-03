
Add-Type @'
public class myAssocFile
{
	public string link;
	public string key;
	public string componenttype;
	public string filename;
	public string version;
	public string title;
	public string revision;
	public string description;
}
'@

function GetAssociatedFiles($itemids, $iconLocation)
{
	$dsDiag.Trace(">> Starting GetAssociatedFiles($itemids)")
	$primary = [Autodesk.Connectivity.Webservices.ItemFileLnkTypOpt]::Primary
	$secondary = [Autodesk.Connectivity.Webservices.ItemFileLnkTypOpt]::Secondary
	$tertiary = [Autodesk.Connectivity.Webservices.ItemFileLnkTypOpt]::Tertiary
	$standard = [Autodesk.Connectivity.Webservices.ItemFileLnkTypOpt]::StandardComponent
	$primarysub = [Autodesk.Connectivity.Webservices.ItemFileLnkTypOpt]::PrimarySub
	$secondarysub = [Autodesk.Connectivity.Webservices.ItemFileLnkTypOpt]::SecondarySub
	$assocFiles = $vault.ItemService.GetItemFileAssociationsByItemIds($itemids, $primary -bor $secondary -bor $tertiary -bor $standard -bor $primarysub -bor $secondarysub)
	$PropDefs = $vault.PropertyService.GetPropertyDefinitionsByEntityClassId("FILE")
	$descriptiondef = $PropDefs | Where-Object { $_.SysName -eq "description"}
	$titledef = $PropDefs | Where-Object { $_.SysName -eq "title"}
	$propDefIds = $descriptiondef.Id, $titledef.Id
	$assocFileIds = @()
	$assocFiles | ForEach-Object{
		$assocFileIds += $_.CldFileId
	}
	$myAssocFiles = @()
	$files = @()
	if ($assocFileIds.Count -gt 0 )
	{
		$files = $vault.DocumentService.GetFilesByIds($assocFileIds)
	}
	[System.Collections.Generic.Dictionary[Int,Object]]$fileDic = @{}
	$files | ForEach-Object{
		$fileDic[$_.Id] = $_
	}
	$props = $vault.PropertyService.GetProperties("FILE",$assocFileIds,$propDefIds)
	$assocFiles | ForEach-Object { 
		$file = $fileDic[$_.CldFileId]
		$fileext = $([System.IO.Path]::GetExtension($file.Name)).Substring(1)
		$myFile = New-Object myAssocFile
		$myFile.filename = $file.Name
		$myFile.version = $file.VerNum
		$myFile.revision = $file.FileRev.Label
		$titleprop = $props | Where-Object { ($file.Id -eq $_.EntityId) -and ($_.PropDefId -eq $titledef.Id)}
		$myFile.title = $titleprop.Val
		$descriptionprop = $props | Where-Object { ($file.Id -eq $_.EntityId) -and ($_.PropDefId -eq $descriptiondef.Id)}
		$myFile.description = $descriptionprop.Val
		$path = GetPath $iconLocation $fileext
		$exists = Test-Path $path
		if (-not $exists)
		{
			$path = GetPath $iconLocation "unknown"
		}
		$myFile.Componenttype = $path
		$keypath = GetPath $iconLocation $_.Typ
		$myFile.key = $keypath
		$linkpath = GetPath $iconLocation 'linkedfile'
		$myFile.link = $linkpath
		$myAssocFiles += $myFile
	}
	
	$assocAttachments = $vault.ItemService.GetAttachmentsByItemIds($itemids)
	$attfileIds =@()
	$assocAttachments | ForEach-Object {
		$_.AttmtArray | ForEach-Object {
			$attfileIds += $_.FileId
		}
	}
	if ($attfileIds.Count -gt 0 )
	{
		$attFiles = $vault.DocumentService.GetFilesByIds($attfileIds)
		$attProps = $vault.PropertyService.GetProperties("FILE",$attfileIds,$propDefIds)
		$attFiles | ForEach-Object {
			$fileext = $([System.IO.Path]::GetExtension($_.Name)).Substring(1)
			$myAttFile = New-Object myAssocFile
			$myAttFile.filename = $_.Name
			$myAttFile.version = $_.VerNum
			$myAttFile.revision = $_.FileRev.Label
			$fileId = $_.Id
			$titleprop = $attProps | Where-Object { ($fileId -eq $_.EntityId) -and ($_.PropDefId -eq $titledef.Id)}
			$myAttFile.title = $titleprop.Val
			$descriptionprop = $attProps | Where-Object { ($fileId -eq $_.EntityId) -and ($_.PropDefId -eq $descriptiondef.Id)}
			$myAttFile.description = $descriptionprop.Val

			$path = GetPath $iconLocation $fileext
			$exists = Test-Path $path
			if (-not $exists)
			{
				$path = GetPath $iconLocation "unknown"
			}
			$myAttFile.Componenttype = $path
			$keypath = GetPath $iconLocation 'attachment'
			$myAttFile.link = $keypath
			$myAssocFiles += $myAttFile
		}
	}
	return $myAssocFiles
}

function GetPath($iconLocation,$name)
{
	$iconpath = [string]::Format("Icons\{0}.png", $name)
	return [System.IO.Path]::Combine($iconLocation,$iconpath)
}
