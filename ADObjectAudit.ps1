##Convert Time from ticks to date/time format
#@{Name='LastLogonTimestamp';Expression={[DateTime]::fromfiletime($_.lastlogontimestamp)}}

#List of objects to collect
$servers = "Server-Name"

#Collects the Last Logon Timestamp, Password Last Set, Operating System, and Operating System Version properties and saves them to the desktop.
$servers | foreach{
    Get-ADObject -SearchBase "ou=_clients,dc=arthrex,dc=local" -Filter * -Properties lastlogontimestamp, pwdlastset,operatingsystem,operatingsystemversion|
    where -Property name -match $_ | select Name,@{Name='LastLogonTimestamp';Expression={[DateTime]::fromfiletime($_.lastlogontimestamp)}}, @{Name='pwdlastset';Expression={[DateTime]::fromfiletime($_.pwdlastset)}},operatingsystem,operatingsystemversion,objectclass,distinguishedname | fl
} | Out-File -FilePath C:\Users\admin_zk11354\Desktop\AuditADObjects.txt
