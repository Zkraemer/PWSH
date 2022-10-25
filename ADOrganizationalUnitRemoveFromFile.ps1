##Script is designed to be used in conjunction with ADOrganizationalUnitFindUnused.ps1
##Script can be used with any CSV as long as the appropriate headers and fields are in use.

#Set the path to the file containing OUs to remove
$CSVPath = "~\desktop\Log_EmptyOUs.log"

#Get the contents of the file and assign to a list
#CSV Headers must include "OU" and "Empty" delimiter is set to semicolon ";"
$CSV = Import-Csv -Path $CSVPath -Delimiter ";" 
$emptyOUs = $CSV | where -property Empty -ieq "yes" | select -ExpandProperty ou 
[array]::Reverse($emptyOUs)

Write-Host ("Total number of empty OUs in file: {0}" -f $emptyOUs.count) -ForegroundColor Cyan

#Iterate through each item in the list to remove the OU from Active Directory
$count = 0
foreach ($ou in $emptyOUs){
    $retrievedOU = Get-ADOrganizationalUnit -Identity $ou -Properties protectedfromaccidentaldeletion
    $name = ("{0} [{1}]" -f $retrievedOU.Name, $ou)
    
    #Remove Accidental Deletion Protection on the OU
    if ($retrievedOU.ProtectedFromAccidentalDeletion -eq $true){
        Write-host ("Removing Accidental Deletion Protection from {0}" -f $name) -ForegroundColor Gray
        $retrievedOU | Set-ADOrganizationalUnit -ProtectedFromAccidentalDeletion:$false #-WhatIf
    }
    
    #Delete the OU
    Write-host ("Removing: {0}" -f $name) -ForegroundColor Gray
    $retrievedOU | Remove-ADOrganizationalUnit -Confirm:$false -ErrorAction SilentlyContinue -ErrorVariable $errorVar #-WhatIf
    if ($errorVar -ine $null){
        Write-Warning ("{0} was not removed from AD" -f $name)
    }else{
        Write-Host ("{0} was removed from AD" -f $name) -ForegroundColor Yellow
        $count ++
    }
}

#Display total number of OUs Removed
Write-Host ("Total number of OUs Removed: {0}" -f $count) -ForegroundColor Cyan
