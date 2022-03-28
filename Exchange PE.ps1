#Get Credentials and store in Variable
$domains = @(
    "1BCT3ID",
    "3ID"
)
$BrigadeDomain = $domains[0]
$DivisionDomain = $domains[1]
$domainUsername = "\TSIAdministrator"
$exchangeUsername = "Exch_Admin"
$password = "Pa55w.rd"
$SecPassword = $password | ConvertTo-SecureString -AsPlainText -Force

$BrigadeDomainCredential= [System.Management.Automation.PSCredential]::new(($BrigadeDomain+$domainUsername),$SecPassword)
$DivisionDomainCredential = [System.Management.Automation.PSCredential]::new(($DivisionDomain+$domainUsername),$SecPassword)
$credential = [System.Management.Automation.PSCredential]::new($exchangeUsername,$SecPassword)

#List VMs
$BrigadePrefix = "1BCT-"
$BrigadeVMs = @(
    "DC1",
    "EXCH",
    "ADMIN"
)
$BrigadeVMNames = $brigadeVMs | foreach {$BrigadePrefix + $_}

$DivisionPrefix = "3ID-"
$DivisionVMs = @(
    "DC1",
    "EXCH",
    "ADMIN"
)
$DivisionVMNames = $DivisionVMs | foreach {$DivisionPrefix + $_}

$VMNames = $DivisionVMNames + $BrigadeVMNames

#Install Windows Features on Admin Devices
$AdminFeatures = @(
    "GPMC",
    "RSAT-AD-Tools",
    "RSAT-ADDS",
    "RSAT-AD-PowerShell"
    "RSAT-DNS-Server"
)

$AdminVMs = $VMNames -like "*[Aa]dmin"

$adminVMs | foreach {
if($_ -like "$BrigadePrefix*"){
    Invoke-Command -Credential $BrigadeDomainCredential -VMName ($AdminVMs -like "$BrigadePrefix*") -ScriptBlock {Install-WindowsFeature -Name $using:AdminFeatures} -AsJob
}elseif($_ -like"$DivisionPrefix*"){
    Invoke-Command -Credential $DivisionDomainCredential -VMName ($AdminVMs -like "$DivisionPrefix*") -ScriptBlock {Install-WindowsFeature -Name $using:AdminFeatures} -AsJob
}else{break}
}


#Validated Users Exist in S6/G6 User OUs
$userAliases = @(
    "june.fax",
    "lila.hylan",
    "lory.vorster",
    "romona.kamaria",
    "tori.fulmer"
)
$DivisionUserPrincipalNames = $userAliases | foreach {("{0}@{1}.army.mil" -f $_,$DivisionDomain)}
$BrigadeUserPrincipalNames = $userAliases | foreach {("{0}@{1}.army.mil" -f $_,$BrigadeDomain)}

$domainControllers = $VMNames -like "*[dD][cC]*"

$domainControllers | foreach {
    if ($_ -like "$BrigadePrefix*"){
        $users = $BrigadeUserPrincipalNames | foreach {Get-ADUser -Filter * -SearchBase ("OU=G6,OU={0},DC={0},DC=Army,DC=MIL" -f $BrigadeDomain) | where -Property userprincipalname -eq $_}
        $usersPrincipalNames = $users | foreach {$_.userprincipalname}

        <#
        TEST SCRIPT FOR ELSE STATEMENT
        $users = $DivisionUserPrincipalNames | foreach {Get-ADUser -Filter * -SearchBase ("OU=G6,OU={0},DC={0},DC=Army,DC=MIL" -f $DivisionDomain) | where -Property userprincipalname -eq $_} | select -first 2
        $usersPrincipalNames = $users | foreach {$_.userprincipalname}
        #>

        if ($userAliases.count -eq $users.Count){
            $compare = Compare-Object -ReferenceObject $BrigadeUserPrincipalNames -DifferenceObject $usersPrincipalNames -IncludeEqual -ExcludeDifferent
            $compare | foreach {Write-host ("{0} is validated" -f $_) -ForegroundColor Green}
        }else{
            
            $compare = Compare-Object -ReferenceObject $BrigadeUserPrincipalNames -DifferenceObject $usersPrincipalNames
            $compare | foreach {Write-Host ("{0} is NOT validated" -f $_) -ForegroundColor Red} 
        }

    }elseif($_ -like "$DivisionPrefix*"){
        $users = $DivisionUserPrincipalNames | foreach {Get-ADUser -Filter * -SearchBase ("OU=G6,OU={0},DC={0},DC=Army,DC=MIL" -f $DivisionDomain) | where -Property userprincipalname -eq $_}
        $usersPrincipalNames = $users | foreach {$_.userprincipalname}

        <#
        TEST SCRIPT FOR ELSE STATEMENT
        $users = $DivisionUserPrincipalNames | foreach {Get-ADUser -Filter * -SearchBase ("OU=G6,OU={0},DC={0},DC=Army,DC=MIL" -f $DivisionDomain) | where -Property userprincipalname -eq $_} | select -first 2
        $usersPrincipalNames = $users | foreach {$_.userprincipalname}
        #>

        if ($userAliases.count -eq $users.Count){
            $compare = Compare-Object -ReferenceObject $DivisionUserPrincipalNames -DifferenceObject $usersPrincipalNames -IncludeEqual -ExcludeDifferent
            $compare | foreach {Write-host ("{0} is validated" -f $_) -ForegroundColor Green}
        }else{
            
            $compare = Compare-Object -ReferenceObject $DivisionUserPrincipalNames -DifferenceObject $usersPrincipalNames
            $compare | foreach {Write-Host ("{0} is NOT validated" -f $_) -ForegroundColor Red} 
        }
    }
}

#Create the Appropriate DNS Records
Add-DnsServerConditionalForwarderZone -MasterServers 10.3.1.1 -ReplicationScope Forest -Name 1BCT3ID.ARMY.MIL -ComputerName DC1

Add-DnsServerResourceRecordMX -MailExchange ("EXCH.{0}.ARMY.MIL" -f $DivisionDomain) -Name "." -Preference 10 -ZoneName ("{0}.ARMY.MIL" -f $DivisionDomain) -ComputerName DC1


