#==============================================================================#
# (c) 2023 coolOrange s.r.l.                                                   #
#                                                                              #
# THIS SCRIPT/CODE IS PROVIDED "AS IS" WITHOUT WARRANTY OF ANY KIND, EITHER    #
# EXPRESSED OR IMPLIED, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED WARRANTIES  #
# OF MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE, OR NON-INFRINGEMENT.   #
#==============================================================================#

Import-Module "$env:POWERJOBS_MODULESDIR/DEPRECATED.powerFLC.Workflows.MappingFunctions.psm1" -Force

function GetVaultName($Entity) {
    return $vaultConnection.Vault
}

function GetVaultServer($Entity) {
    $serverUri = New-Object Uri -ArgumentList $vault.InformationService.Url
    $hostname = $serverUri.Host
    if ($hostname -ieq "localhost") { $hostname = [System.Net.Dns]::GetHostName() }
    return $hostname
}

function GetVaultPersistentId($Entity) {
    $id = $vault.KnowledgeVaultService.GetPersistentIds($Entity._EntityTypeID, @($Entity.Id), [Autodesk.Connectivity.WebServices.EntPersistOpt]::Latest) | Select-Object -First 1
    return $id
}

function GetVaultThickClientLink($Entity) {
    if(-not (($Entity._EntityTypeID -eq "ITEM") -or ($Entity._EntityTypeID -eq "FILE"))) {
        return ""
    }
    if ($Entity.ThickClientHyperLink) {
        return $Entity.ThickClientHyperLink.ToString()
    }
    return GetVaultThickClientLinkCompat $Entity
}

function GetVaultThinClientLink($Entity) {
    if(-not (($Entity._EntityTypeID -eq "ITEM") -or ($Entity._EntityTypeID -eq "FILE"))) {
        return ""
    }
    if ($Entity.ThinClientHyperLink) {
        return $Entity.ThinClientHyperLink.ToString()
    }
    return GetVaultThinClientLinkCompat $Entity
}

function GetItemPositionNumber($Entity) {
    $position = $Entity.Bom_PositionNumber
    if (-not $position) {
        $position = "0"
    }

    $s = ($position -replace "[^-\d]+" , '')
    return [int]$s
}

function GetEntityId($Entity) {
    return $Entity.Id
}
function GetEntityMasterId($Entity) {
    return $Entity.MasterId
}
 
function GetObjectId($Entity) {
    if ($Entity._EntityTypeID -eq "ITEM") {
        $objectId = [System.Web.HttpUtility]::UrlEncode($Entity._Number)
    } elseif ($Entity._EntityTypeID -eq "FILE") {
        $objectId = [System.Web.HttpUtility]::UrlEncode($Entity._FullPath)
    } else {
        return ""
    }
 
    return $objectId
}