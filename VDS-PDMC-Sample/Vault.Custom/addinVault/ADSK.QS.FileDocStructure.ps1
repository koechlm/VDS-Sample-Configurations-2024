# DISCLAIMER:
# ---------------------------------
# In any case, code, templates, and snippets of this solution are of "work in progress" character.
# Neither Markus Koechl, nor Autodesk represents that these samples are reliable, accurate, complete, or otherwise valid. 
# Accordingly, those configuration samples are provided as is with no warranty of any kind, and you use the applications at your own risk.


function mUwUsdChldrnClick
{
	$mSelItem = $dsWindow.FindName("Uses").SelectedItem
    $mOutFile = "mStrTabClick.txt"
	foreach($mItem in $mSelItem)
	{
		#$dsDiag.Trace("UsesWhereUsed-ChildrenSelection: ($Item.Name)")
		$mItem.Name | Out-File "$($env:appdata)\Autodesk\DataStandard 2024\$($mOutFile)"
	}
}

function mUwUsdPrntClick
{
	$mSelItem = $dsWindow.FindName("WhereUsed").SelectedItem
    $mOutFile = "mStrTabClick.txt"
	foreach($mItem in $mSelItem)
	{
		#$dsDiag.Trace("UsesWhereUsed-WhereUSedSelection: ($Item.Name)")
		$mItem.Name | Out-File "$($env:appdata)\Autodesk\DataStandard 2024\$($mOutFile)"
	}
}

function mUwUsdCopyToClipBoard
{
	$mSelItem = $dsWindow.FindName("WhereUsed").SelectedItem
	[Windows.Forms.Clipboard]::SetText($mSelItem.Name)
}