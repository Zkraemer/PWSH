#create script audit file on desktop
$filePath = "~\Desktop\ModifiedGPOs.txt"

$gposNoAuthUsers = Get-GPO -All | where{ 
    $GPOName = $_.DisplayName 
    $Perms = (Get-GPPermissions $GPOName -All).Trustee.Name 

    if(!($Perms.Contains("Authenticated Users"))){
        "$GPOName"
    }
}


$count = 0
$gposNoAuthUsers | foreach{
    Set-GPPermission -Name $_.displayname -TargetName "Authenticated Users" -TargetType Group -PermissionLevel GpoRead
    Write-Host ("Added `"Authenticated Users`" with `"Read`" permission to {0}" -f $_.DisplayName) -ForegroundColor Cyan
    $_.DisplayName | Out-File -FilePath $filePath -Append 
    $count++
}
Write-Host ("Total number of GPOs updated: {0}" -f $count) -ForegroundColor Yellow

#Test on 1 GPO
<#

$gposNoAuthUsers = Get-GPO -All | where{
    $GPOName = $_.DisplayName
    $Perms = (Get-GPPermissions $GPOName -All).Trustee.Name;
    
    if (!($Perms.Contains("Authenticated Users"))){
        "$GPOName"
    }
} | select -first 1


$gposNoAuthUsers | foreach{
    Set-GPPermission -Name $_.displayname -TargetName "Authenticated Users" -TargetType Group -PermissionLevel GpoRead -WhatIf
    Write-Host ("Added `"Authenticated Users`" with `"Read`" permission to {0}" -f $_.DisplayName) -ForegroundColor Cyan
    $_.DisplayName | Out-File -FilePath $filePath -Append
}

#>
