# DISCLAIMER:
# ---------------------------------
# In any case, code, templates, and snippets of this solution are of "work in progress" character.
# Neither Markus Koechl, nor Autodesk represents that these samples are reliable, accurate, complete, or otherwise valid. 
# Accordingly, those configuration samples are provided as is with no warranty of any kind, and you use the applications at your own risk.


$_Temp = $dsCommands

# query that the logged in user is allowed to apply this command
$mUserEnabled = Adsk.CheckCfgAdminPermission

If($mUserEnabled -eq $false)
{
	#read UIStrings as these are not a default in the .\Menu\*.ps1 functions runspace
	$UIStrings = mGetUIStrings
	[Autodesk.DataManagement.Client.Framework.Forms.Library]::ShowError($UIStrings["ADSK-GroupMemberOf-00"], $UIStrings["ADSK-MsgBoxTitle"])
	return
}

$dialog = $dsCommands.GetCreateFolderDialog(1)
$xamlFile = New-Object CreateObject.WPF.XamlFile "ADSK.QS.ActivateSchedTask.xaml", "%ProgramData%\Autodesk\Vault 2024\Extensions\DataStandard\Vault.Custom\Configuration\ADSK.QS.ActivateSchedTask.xaml"
$dialog.XamlFile = $xamlFile

$result = $dialog.Execute()


