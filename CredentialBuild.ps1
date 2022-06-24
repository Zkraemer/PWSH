#Credential Build

#Define the Domain
$domainFQDN = Read-Host "Enter FQDN of Domain" 
$domainNETBIOS = $domainFQDN.split('.')[0]

#Define Local User
$localUsername = Read-Host "Enter Local Username"
do {
$localPassword = Read-Host -Prompt "Enter Local User Password" 
$localPasswordConfirm = Read-Host -Prompt "Confirm Local User Password"
If($localPassword -notlike $localPasswordConfirm){
Write-Host "Passwords do not Match! Please try again" -ForegroundColor Red
}else{
$localPasswordSecure = $localPassword | ConvertTo-SecureString -AsPlainText -Force
$localPassword = ""
$localPasswordConfirm = ""
}
}while($localPassword -notlike $localPasswordConfirm)

#Define Domain User
$domainUsername = ("{0}/{1}" -f $domainNETBIOS, (Read-Host "Enter Domain Username"))
do {
$domainPassword = Read-Host -Prompt "Enter Domain User Password" 
$domainPasswordConfirm = Read-Host -Prompt "Confirm Domain User Password"
If($domainPassword -notlike $domainPasswordConfirm){
Write-Host "Passwords do not Match! Please try again" -ForegroundColor Red
}else{
$domainPasswordSecure = $domainPassword | ConvertTo-SecureString -AsPlainText -Force
$domainPassword = ""
$domainPasswordConfirm = ""
}
}while($domainPassword -notlike $domainPasswordConfirm)


#Define Console User
$conUsername = Read-Host "Enter Console Username"
$conPassword = Read-Host -AsSecureString -Prompt "Enter Console Password"
do {
$conPassword = Read-Host -Prompt "Enter Console User Password" 
$conPasswordConfirm = Read-Host -Prompt "Confirm Console User Password"
If($conPassword -notlike $conPasswordConfirm){
Write-Host "Passwords do not Match! Please try again" -ForegroundColor Red
}else{
$conPasswordSecure = $conPassword | ConvertTo-SecureString -AsPlainText -Force
$conPassword = ""
$conPasswordConfirm = ""
}
}while($conPassword -notlike $conPasswordConfirm)

#Build Secure PSCredential
$localCredential = [System.Management.Automation.PSCredential]::new($localUsername,$localPasswordSecure)
$domainCredential = [System.Management.Automation.PSCredential]::new($domainUsername,$domainPasswordSecure)
$consoleCredential = [System.Management.Automation.PSCredential]::new($conUsername,$conPasswordSecure)
