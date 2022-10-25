#Create List of Parent OUs to search
$domain = "DC=DOMAIN,DC=LOCAL" #The format of domain.local in AD, Change this to match your domain
$parentOUNames = @(
"<#ENTER OU NAMES HERE#>",
"<#ETC#>"
)
$parentOUs = $parentOUNames | foreach {Get-ADOrganizationalUnit -Identity ("OU={0},{1}" -f $_, $domain)} 

#Create a group to store empty OU distinguishedNames and logs
$logs = [System.Collections.ArrayList]::new()
[void]$logs.add("Name;OU;Empty")
$emptyOUCount = 0


#Iterate through each Parent OU to find OUs without Contacts, Users, Groups, or Computers
foreach ($ou in $parentOUs){
    $collection = Get-ChildItem -LiteralPath ("AD:\{0}" -f $ou.DistinguishedName) -Recurse -Force | where -Property objectclass -eq "organizationalUnit" | select -Property Distinguishedname -unique
    $ouDN = $ou.DistinguishedName

    foreach ($item in $collection) {
        $items = Get-ChildItem -LiteralPath ("AD:\{0}" -f $item.distinguishedname) -Recurse -Force
        $itemsObjectClass = $items.objectClass
        $name = ($item.Distinguishedname.split(',')[0]).split('=')[1]

        if (($itemsObjectClass -cnotcontains "computer") -and ($itemsObjectClass -cnotcontains "user") -and ($itemsObjectClass -cnotcontains "group") -and ($itemsObjectClass -cnotcontains "contact")){
            Write-Host ("$name [{0}] is empty" -f $item.Distinguishedname) -ForegroundColor Green
            $items
            [void]$logs.add("$name;{0};Yes" -f $item.Distinguishedname)
            [void]$emptyOUCount ++
        }else{
            [void]$logs.add("$name;{0};No" -f $item.Distinguishedname)          
        }
    }    
}

#Write to a log file on the desktop
Write-Host "Would you like to write results to file? [Y|N]" 
if ((Read-host) -ieq "y"){
    $logPath = "~\desktop\Log_EmptyOUs.log"
    $logs | out-file -filepath $logPath
    $log = get-item $logPath
    Write-host ("Log location: {0}" -f $log.DirectoryName) -ForegroundColor Magenta
}

#Display the Total number of empty OUs
Write-host ("Total number of empty OUs: {0}" -f $emptyOUCount) -ForegroundColor Cyan
