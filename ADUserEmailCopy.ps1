#Get ADUsers Admin_* that do not have email addresses
#Get ADUsers who match Admin_* Names
#Copy Email so that both are the same

$adminUserOU = @("<#Enter Admin User Org Unit Here#>")
$userOU = @("<#Enter User Org Units Here#>")

#get a list of Admin Users
$adminUsers = get-aduser -SearchBase "$adminUserOU" -Filter * -Properties mail | where -Property sAMaccountName -like "Admin_*"

#get a list of regular Users
$Users = get-aduser -SearchBase "$userOU" -Filter * -Properties mail

#Get a list of Admin Users missing email addresses
$usersMissingMailAttribute = $adminUsers | where -Property mail -EQ $null

#Pull the names and remove Admin_ to compare
$usersMissingMailAttributeName = $usersMissingMailAttribute.sAMAccountName | foreach {$_.split("_")[1]}

#for every user Missing an Email address, Find the Email address of their regular user account and assign it to their Admin acount.
$count=0
foreach ($name in $usersMissingMailAttributeName){
    if ($name -in $users.sAMAccountName){
    $mailAddress = get-aduser -SearchBase $userOU -Filter * -Properties mail | where -Property sAMAccountName -eq $name | select -ExpandProperty mail
    $adminUser = get-aduser -SearchBase $adminUserOU -Filter * -Properties mail | where -Property sAMAccountname -like "Admin_$name"
    $adminUser | Set-ADUser -Add @{mail="$mailaddress"} -ErrorAction Continue
    Write-Host ("Admin_{0} now has an Email of: {1}" -f $name,$mailAddress) -ForegroundColor Cyan
    $count++
    }
}
Write-host ("Total number of users modified: {0}" -f $count) -ForegroundColor Yellow

<#Notes

#>
