#Get ADUsers Admin_* that do not have email addresses
#Get ADUsers who match Admin_* Names
#Copy Email so that both are the same

#get a list of Admin Users
$adminUsers = get-aduser -SearchBase <#SearchBase#> -Filter * -Properties mail | where -Property distinguishedname -like "CN=Admin_*" | select -Property distinguishedname,name,mail

#get a list of regular Users
$Users = get-aduser -SearchBase <#SearchBase#> -Filter * -Properties mail | select -Property distinguishedname,name,mail

#Get a list of Admin Users missing email addresses
$missingMailAttribute = $adminUsers | where -Property mail -EQ $null

#Pull the names and remove Admin_ to compare
$missingMailAttributeName = $missingMailAttribute.name | foreach {$_.split(",")[0].split("_")[1]}

#for every user Missing an Email address, Find the Email address of their regular user account and assign it to their Admin acount.
foreach ($name in $missingMailAttributeName){
    if ($name -in $users.name){
    $mailAddress = get-aduser -SearchBase <#SearchBase#> -Filter * -Properties mail | where -Property name -eq $name | select -ExpandProperty mail
    $user = get-aduser -SearchBase <#SearchBase#> -Filter * -Properties mail | where -Property name -like "Admin_$name"
    $user | Set-ADUser -Add @{mail="$mailaddress"} -Verbose
    }
}

<#Notes

#>
