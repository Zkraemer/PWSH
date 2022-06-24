####BEFORE STARTING####
<#
Please place all scripts in the folder on your workstation ~\Documents\WindowsPowerShell\Scripts\
requires the following scripts:
BuildCredentials.ps1
#>

#Configure New Server
$serverName = (Read-Host -Prompt "Enter server Name")
$networkAdapterInterfaceIndex = Get-NetAdapter -Name "Ethernet*" | where -Property Status -eq UP | select -ExpandProperty ifIndex
$serverIPv4Address = (Read-Host -Prompt "Enter server IPv4 Address")
$serverSubnetMask = (Read-Host -Prompt "Enter server Subnet Mask prefix length") #CIDR Notation
$serverDNSAddresses = [System.Collections.ArrayList]::new()

#Rename Server
Rename-Computer -ComputerName $serverName -PassThru -Force
Restart-Computer -Wait -For PowerShell -Timeout 300 -Delay 2

#Configure Network on Server
Get-NetIPAddress -InterfaceIndex $networkAdapterInterfaceIndex -AddressFamily IPv4 | Set-NetIPAddress -IPAddress $serverIPv4Address -PrefixLength $serverSubnetMask
$x=1
$collectDNS = do {
    $serverDNSAddress = Read-Host "Enter DNS Server IPv4 Address $x"
    $serverDNSAddresses.add(($serverDNSAddress))
    $x++
} While($x -le 2)
$x=$null
Get-DnsClientServerAddress -InterfaceIndex $networkAdapterInterfaceIndex -AddressFamily IPv4 | Set-DnsClientServerAddress -ServerAddresses $serverDNSAddresses
Add-Computer
Restart-Computer -Wait -For PowerShell -Timeout 300 -Delay 2

#Store Credentials required for script processes
$PowershellScriptsDir = ("{0}\Documents\WindowsPowerShell\Scripts\" -f $env:USERPROFILE)
cd $PowershellScriptsDir`
"BuildCredentials.ps1"


#Create Safemode Administrator Password for DC
do {
    $safemodeAdministratorPassword = Read-Host "Please Enter the Domain Controllers Safemode Administrator Password"
    $safemodeAdministratorPasswordConfirm = Read-Host "Please Confirm the Domain Controllers Safemode Administrator Password"
    If($safemodeAdministratorPassword -notlike $safemodeAdministratorPasswordConfirm){
        Write-Host "Passwords do not Match! Please try again" -ForegroundColor Red
    }else{
        $safemodeAdministratorPasswordSecure = $safemodeAdministratorPassword | ConvertTo-SecureString -AsPlainText -Force
        $safemodeAdministratorPassword = $null
        $safemodeAdministratorPasswordConfirm = $null
    }
}while($safemodeAdministratorPassword -notlike $safemodeAdministratorPasswordConfirm)

$locationPrefix = @(
"ALC",
"AME",
"ASC",
"AZR",
"INC",
"ISE",
"MUC",
"ONE",
"TOK"
)

#Identify the Primary Domain Controller (FSMO MASTER)
$PrimaryDomainController = "AME-DCT-PRD04"

#Domain Controller Setup
#Get list of Existing DC Names
$existingDCNames = get-adcomputer -Filter * -SearchBase "OU=Domain Controllers, DC=Arthrex, DC=local" | select -Property name

#Create DC Name
$newDCName=[System.Collections.ArrayList]::new()

Foreach ($prefix in $locationPrefix){
 $prefixDCs = $existingDCNames | where name -like ("{0}*" -f $prefix) | select -ExpandProperty name
 $existingDCnumbers = @($prefixDCs | foreach {$_.substring(11)} | Sort-Object -Unique)
 $newNum = [int]$existingDCnumbers[-1]
 $newNum = $newNum+1
 $newNumString = ([string]$newNum).PadLeft(2,'0')

 $newDCName.add(("{0}-DCT-PRD{1}" -f $prefix, $newNumString))

 }

 #Select Available DC Name
 $domainControllerNames = $newDCName | 
 Out-
 #Out-GridView -Title "Select Which DC(s) you would like to Configure" -OutputMode Multiple

 #Install Domain Roles on DC
 $installDomainRoles = {
    $domainControllerRoles = @(
        "AD-Domain-Services",
        "DNS"
    )
    Install-WindowsFeature -Name $domainControllerRoles
}
Invoke-Command -ComputerName $domainControllerNames -ScriptBlock $installDomainRoles -Credential $domainCredential -AsJob

$ConfigureDomainControllers = {
Install-ADDSDomainController -DomainName $using:domainFQDN -Credential $using:domainCredential -SafeModeAdministratorPassword $using:safemodeAdministratorPasswordSecure -SiteName $using:locationPrefix -SkipPreChecks
Write-Host ($env:COMPUTERNAME + " Installed as Domain Controller on TAC") -ForegroundColor Green    
}
Invoke-Command -ComputerName $AllDCVMNames -ScriptBlock $ConfigureDomainControllers -Credential $domainCredential -AsJob
