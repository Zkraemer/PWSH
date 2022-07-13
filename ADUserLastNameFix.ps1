#Get ADUsers that do not have last names
#Copy the last, name in the "First Name" Attribute to the "Last Name" Attribute
#Remove that last, name from the "First Name" Attribute

$userOU = @(
<#Enter OU's you wish to search here#>
)

#get a list of Admin Users with no surname
$UsersNoSurname = $userOU | foreach{get-aduser -SearchBase $_ -Filter * -Properties givenName,surname | where -Property surname -eq $null}
$AdminUsersNoSurname = $UsersNoSurname | foreach{get-aduser -SearchBase $_ -Filter * -Properties givenName,surname | where -Property name -like "Admin*" | select -Property name,givenName,surname} 
Write-Host ("Total of {0} users collected." -f $AdminUsersNoSurname.count) -ForegroundColor Yellow

$count = 0
$AdminUsersNoSurname | foreach {
    $userSurname = $_.givenname.split(" ")[-1]
    $userGivenName = $_.givenname -replace $userSurname
        
    #$_ | Set-ADUser -Surname "$userSurname"
    Write-host ("Set {0} surname to {1}" -f $_.name, $userSurname) -ForegroundColor Cyan 
    
    #$_ | Set-ADUser -GivenName $userGivenName
    Write-host ("Changed {0} givenName to {1}" -f $_.name, $userGivenName) -ForegroundColor DarkYellow
    Write-Host " "

    $count++
}
Write-Host ("Total users modified: {0}" -f $count) -ForegroundColor Yellow

<#Notes

#>
