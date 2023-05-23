#region disclaimer
#=============================================================================#
# PowerShell script sample for Vault Data Standard                            #
#                                                                             #
# Copyright (c) Autodesk - All rights reserved.                               #
#                                                                             #
# THIS SCRIPT/CODE IS PROVIDED "AS IS" WITHOUT WARRANTY OF ANY KIND, EITHER   #
# EXPRESSED OR IMPLIED, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED WARRANTIES #
# OF MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE, OR NON-INFRINGEMENT.  #
#=============================================================================#
#endregion

function mUwUsdChldrnClick
{
	$mSelItem = $dsWindow.FindName("Uses").SelectedItem
    $mOutFile = "mStrTabClick.txt"
	foreach($mItem in $mSelItem)
	{
		#$dsDiag.Trace("UsesWhereUsed-ChildrenSelection: ($Item.Name)")
		$mItem.Name | Out-File "$($env:appdata)\Autodesk\DataStandard 2023\$($mOutFile)"
	}
}

function mUwUsdPrntClick
{
	$mSelItem = $dsWindow.FindName("WhereUsed").SelectedItem
    $mOutFile = "mStrTabClick.txt"
	foreach($mItem in $mSelItem)
	{
		#$dsDiag.Trace("UsesWhereUsed-WhereUSedSelection: ($Item.Name)")
		$mItem.Name | Out-File "$($env:appdata)\Autodesk\DataStandard 2023\$($mOutFile)"
	}
}

function mUwUsdCopyToClipBoard
{
	$mSelItem = $dsWindow.FindName("WhereUsed").SelectedItem
	[Windows.Forms.Clipboard]::SetText($mSelItem.Name)
}