#Credential Build

#Define the Domain
$domainFQDN = Read-Host "Enter FQDN of Domain" 
$domainNETBIOS = $domainFQDN.split('.')[0]

#Define Local User
$localUsername = Read-Host "Enter Local Username"
$localPassword = Read-Host -AsSecureString -Prompt "Enter Local User Password"

#Define Domain User
$domainUsername = ("{0}/{1}" -f $domainNETBIOS, (Read-Host "Enter Domain Username"))
$domainPassword = Read-Host -AsSecureString -Prompt "Enter Domain User Password"

#Define Console User
$conUsername = Read-Host "Enter Console Username"
$conPassword = Read-Host -AsSecureString -Prompt "Enter Console Password"

#Build Secure PSCredential
$localCredential = [System.Management.Automation.PSCredential]::new($localUsername,$localPassword)
$domainCredential = [System.Management.Automation.PSCredential]::new($domainUsername,$domainPassword)
$consoleCredential = [System.Management.Automation.PSCredential]::new($conUsername,$conPassword)
